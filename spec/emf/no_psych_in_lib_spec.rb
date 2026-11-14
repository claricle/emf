# frozen_string_literal: true

require "spec_helper"

RSpec.describe "lib/ YAML handling" do
  # Yeptris::Psych is allowed; a bare YAML or Psych constant is not.
  forbidden = [
    /\brequire\s*\(?\s*["'](?:yaml|psych)["']/,
    /(?<![\w:])(?:YAML|Psych)\b/
  ]

  it "keeps require \"yaml\", require \"psych\" and the YAML/Psych constants out of lib/" do
    offenders = Dir[File.expand_path("../../lib/**/*.rb", __dir__)].flat_map do |path|
      File.foreach(path).with_index(1).filter_map do |line, number|
        next if line.lstrip.start_with?("#")

        "#{path}:#{number}: #{line.strip}" if forbidden.any? { |pattern| line.match?(pattern) }
      end
    end

    expect(offenders).to be_empty
  end
end
