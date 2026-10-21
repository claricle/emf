# frozen_string_literal: true

require "spec_helper"
require "json"
require "stringio"
require "tmpdir"
require_relative "../../bench/check_regression"

RSpec.describe CheckRegression do
  let(:tmpdir) { Dir.mktmpdir("check-regression") }
  let(:ms) { 1_000_000 }
  let(:workload) { "spec/fixtures/simple/image1.emf#parse" }
  let(:policy_data) do
    { "schema_version" => 1, "status" => "informational",
      "runner" => { "os" => nil }, "sampling" => { "warmups" => 5, "min_samples" => 20, "min_baseline_runs" => 2 },
      "alert_ratio" => 0.10, "absolute_floor_ms" => { "default" => 1.0, "per_workload" => {} },
      "noise_bound" => { "max_relative_spread" => 0.05 } }
  end

  after { FileUtils.remove_entry(tmpdir) }

  # Synthetic report: 20 samples centred on median_ms (spread of +-0.1 ms).
  def report(median_ms, overrides = {})
    samples = Array.new(20) { |i| ((median_ms * ms) + ((i - 10) * 10_000)).to_i }
    { "kind" => "emf-parser-stage-baseline", "backend" => "ruby",
      "method" => { "timing" => { "clock" => "monotonic" }, "file_io" => "excluded", "gc_policy" => "gc" },
      "environment" => { "os" => { "sysname" => "Linux", "machine" => "x86_64" }, "cpu_model" => "cpu", "cpu_count" => 4,
                         "ruby" => { "platform" => "x86_64-linux" } },
      "inputs" => { "manifest_sha256" => "m" },
      "fixtures" => [{ "path" => "spec/fixtures/simple/image1.emf", "sha256" => "aa", "status" => "ok",
                       "stages" => { "parse" => { "samples_ns" => samples } } }] }.merge(overrides)
  end

  def run_with(baselines, candidate, policy: policy_data)
    write = lambda do |name, data|
      File.join(tmpdir, name).tap { |p| File.write(p, data.is_a?(String) ? data : JSON.generate(data)) }
    end
    argv = baselines.each_with_index.flat_map { |b, i| ["--baseline", write.call("b#{i}.json", b)] }
    argv += ["--candidate", write.call("c.json", candidate), "--policy", write.call("p.json", policy)]
    out = StringIO.new
    err = StringIO.new
    status = described_class.run(argv, out: out, err: err)
    [status, out.string.empty? ? nil : JSON.parse(out.string), err.string]
  end

  def verdict(result) = result.fetch("workloads").first

  it "reports ok when the candidate is within the alert ratio" do
    status, result, = run_with([report(10.0), report(10.1)], report(10.5))
    expect([status, verdict(result)["verdict"]]).to eq([0, "ok"])
  end

  it "alerts when the median exceeds the ratio and the floor, and flags it blocking-eligible" do
    status, result, = run_with([report(10.0), report(10.1)], report(12.0))
    expect([status, verdict(result)["verdict"], verdict(result)["blocking_eligible"]]).to eq([0, "alert", true])
  end

  it "alerts but is not blocking-eligible when the delta is below the absolute floor" do
    policy = policy_data.merge("absolute_floor_ms" => { "default" => 5.0, "per_workload" => {} })
    _, result, = run_with([report(10.0), report(10.1)], report(12.0), policy: policy)
    expect(verdict(result)).to include("verdict" => "alert", "reason" => "below absolute floor", "blocking_eligible" => false)
  end

  it "uses a per-workload floor over the default" do
    policy = policy_data.merge("absolute_floor_ms" => { "default" => 5.0, "per_workload" => { workload => 0.5 } })
    _, result, = run_with([report(10.0), report(10.1)], report(12.0), policy: policy)
    expect(verdict(result)["blocking_eligible"]).to be(true)
  end

  it "is inconclusive when baseline runs vary more than the noise bound" do
    _, result, = run_with([report(10.0), report(11.0)], report(14.0))
    expect(verdict(result)).to include("verdict" => "inconclusive")
    expect(verdict(result)["reason"]).to include("exceeds noise bound")
  end

  it "is inconclusive when the absolute floor is uncalibrated" do
    policy = policy_data.merge("absolute_floor_ms" => { "default" => nil, "per_workload" => {} })
    _, result, = run_with([report(10.0), report(10.1)], report(12.0), policy: policy)
    expect(verdict(result)).to include("verdict" => "inconclusive", "reason" => "absolute floor uncalibrated")
  end

  it "is inconclusive when the noise bound is uncalibrated or only one baseline exists" do
    policy = policy_data.merge("noise_bound" => { "max_relative_spread" => nil })
    _, uncalibrated, = run_with([report(10.0), report(10.1)], report(12.0), policy: policy)
    _, single, = run_with([report(10.0)], report(12.0))
    expect([verdict(uncalibrated)["reason"], verdict(single)["reason"]])
      .to eq(["noise bound uncalibrated", "fewer than 2 baseline runs"])
  end

  it "is inconclusive with too few samples" do
    short = report(10.0)
    short["fixtures"][0]["stages"]["parse"]["samples_ns"] = [10 * ms] * 3
    _, result, = run_with([report(10.0), report(10.1)], short)
    expect(verdict(result)["reason"]).to eq("fewer than 20 samples")
  end

  {
    "backend" => { "backend" => "native" },
    "machine" => { "environment" => { "cpu_model" => "other", "cpu_count" => 4, "os" => {}, "ruby" => {} } },
    "timing boundary" => { "method" => { "timing" => { "clock" => "wall" }, "file_io" => "excluded", "gc_policy" => "gc" } }
  }.each do |name, override|
    it "refuses a #{name} mismatch as incomparable with status 3" do
      status, result, = run_with([report(10.0), report(10.1)], report(10.0, override))
      expect(status).to eq(3)
      expect(result["identity_mismatches"]).not_to be_empty
      expect(result["workloads"]).to be_empty
    end
  end

  it "marks a workload incomparable when the fixture sha256 differs" do
    candidate = report(10.0)
    candidate["fixtures"][0]["sha256"] = "bb"
    status, result, = run_with([report(10.0), report(10.1)], candidate)
    expect([status, verdict(result)["verdict"]]).to eq([3, "incomparable"])
  end

  it "exits 2 with a message for malformed input" do
    expect(run_with([report(10.0)], "not json").then { |s, r, e| [s, r, e] }).to match([2, nil, /c\.json/])
    expect(run_with([{ "kind" => "other" }], report(10.0))[0]).to eq(2)
    expect(run_with([report(10.0)], report(10.0), policy: policy_data.merge("status" => "bogus"))[0]).to eq(2)
    expect(described_class.run([], out: StringIO.new, err: StringIO.new)).to eq(2)
  end

  it "never fails on an alert or inconclusive result while the policy is informational" do
    statuses = [report(20.0), report(10.0)].map { |c| run_with([report(10.0), report(10.1)], c)[0] }
    expect(statuses).to eq([0, 0])
  end

  context "with a blocking policy" do
    let(:blocking) do
      policy_data.merge("status" => "blocking", "runner" => { "os" => "linux" })
    end

    it "exits 1 on a blocking-eligible alert and 0 when within ratio" do
      expect(run_with([report(10.0), report(10.1)], report(12.0), policy: blocking)[0]).to eq(1)
      expect(run_with([report(10.0), report(10.1)], report(10.0), policy: blocking)[0]).to eq(0)
    end

    it "rejects an uncalibrated or unset-runner blocking policy as malformed" do
      unset = blocking.merge("runner" => { "os" => nil })
      uncalibrated = blocking.merge("noise_bound" => { "max_relative_spread" => nil })
      expect([unset, uncalibrated].map { |p| run_with([report(10.0)], report(10.0), policy: p)[0] }).to eq([2, 2])
    end
  end

  it "ships an informational policy with every calibration field unset" do
    policy = JSON.parse(File.read(File.expand_path("../../bench/performance-policy.json", __dir__)))
    expect(described_class::Policy.new(policy)).not_to be_blocking
    expect(policy.dig("sampling", "min_samples")).to be >= 20
    expect([policy.dig("noise_bound", "max_relative_spread"), policy.dig("absolute_floor_ms", "default")]).to eq([nil, nil])
    expect(policy.fetch("runner").values.compact).to be_empty
  end
end
