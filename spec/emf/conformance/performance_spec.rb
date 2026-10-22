# frozen_string_literal: true

require "spec_helper"

# Bound on lens cost (issue #37 plan finding 9). Measured 2026-10-22 on the dev machine, cold process,
# strict profile, ruby backend, largest file under spec/fixtures (test-155.emf, 5.7 MB, 53 records):
# 0.19 s, 0.31 s, 0.19 s over three runs. The budget is 2 s, about 6.5x the slowest run, so a slow CI
# runner passes and only an order-of-magnitude regression (for example a rule going quadratic) fails.
RSpec.describe "Emf::Conformance performance" do
  let(:budget_seconds) { 2.0 }
  let(:largest) do
    root = File.expand_path("../../fixtures", __dir__)
    Dir[File.join(root, "**", "*")].select { |path| File.file?(path) }.max_by { |path| File.size(path) }
  end

  it "checks the largest fixture under strict within the wall-clock budget" do
    bytes = File.binread(largest)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    report = Emf::Conformance.check(bytes, profile: :strict)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    expect(report.to_h).to include("tool" => "emf") # it produced a real report, not an early exit
    expect(elapsed).to be < budget_seconds
  end
end
