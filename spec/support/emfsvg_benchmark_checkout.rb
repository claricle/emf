# frozen_string_literal: true

require "open3"

module EmfsvgBenchmarkCheckout
  def create_emfsvg_checkout(directory)
    FileUtils.mkdir_p(File.join(directory, "lib"))
    FileUtils.mkdir_p(File.join(directory, "spec/fixtures/golden"))
    File.write(File.join(directory, "lib/emfsvg.rb"), <<~SOURCE)
      require "emf"
      module Emfsvg
        def self.from_bytes(bytes)
          "<svg>\#{Emf.parse(bytes).records.size}</svg>"
        end
        def self.from_file(path)
          from_bytes(File.binread(path))
        end
      end
    SOURCE
    File.write(File.join(directory, "spec/golden_spec.rb"), "# golden contract\n")
    fixture = File.join(ParserBenchmark::ROOT, "spec/fixtures/simple/image1.emf")
    File.write(File.join(directory, "spec/fixtures/golden/image1.svg"), "<svg>#{Emf.parse_file(fixture).records.size}</svg>")
    commands = [["init", "-q"], ["add", "."], ["-c", "user.name=Benchmark", "-c", "user.email=benchmark@example.test",
                                               "commit", "-qm", "fixture"]]
    commands.each do |args|
      output, status = Open3.capture2e("git", *args, chdir: directory)
      raise output unless status.success?
    end
    Open3.capture2("git", "rev-parse", "HEAD", chdir: directory).first.strip
  end
end
