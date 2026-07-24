# TODO 19 — `exe/emf` CLI

**Priority:** P1
**Depends on:** 18
**Status:** pending

## Context

The `exe/emf` executable is the user-facing tool. It wraps the public API in subcommands. Replaces the role `emf2svg-conv` plays in the C library.

## Outcomes

- `exe/emf` (Ruby, executable) with subcommands:
  - `version` — print version
  - `info FILE` — print metafile header info (format, bounds, device size, record count, error count)
  - `dump FILE` — print full record dump via `Emf::Visitors::Dump`
  - `validate FILE` — parse and report errors (exit 0 if `ok?`, exit 1 if `has_errors?`, exit 2 on `FormatError`)
  - `stats FILE` — print record-type histogram via `Emf::Visitors::Stats`
  - `round-trip FILE [--out PATH]` — parse, serialize, optionally write to PATH
  - `help [SUBCOMMAND]`
- Uses `optparse` from stdlib (no extra deps).
- Exit codes follow Unix convention.
- Man-page-quality help text.

## Pattern

```ruby
#! /usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "emf"

module Emf
  module CLI
    module_function

    def run(argv)
      command = argv.shift
      case command
      when "version" then puts "emf #{Emf::VERSION}"
      when "info" then info(argv)
      when "dump" then dump(argv)
      when "validate" then validate(argv)
      when "stats" then stats(argv)
      when "round-trip" then round_trip(argv)
      when "help", nil then help(argv)
      else abort "unknown subcommand: #{command} (see `emf help`)"
      end
    end

    def info(argv)
      path = argv.shift or abort "usage: emf info FILE"
      mf = Emf.parse_file(path)
      puts "Format:   #{mf.format}"
      puts "Bounds:   #{header_bounds(mf)}"
      puts "Records:  #{mf.records.length}"
      puts "Errors:   #{mf.errors.length}"
      puts "EMF+:     #{mf.emf_plus ? 'present' : 'absent'}"
    end
    # ...
  end
end

Emf::CLI.run(ARGV)
```

## Files

```
exe/emf                            # rewrite stub from TODO 01
lib/emf/cli.rb                     # CLI module (separates logic from script)
spec/emf/cli_spec.rb               # uses Open3 to invoke the exe
```

## Verification

```ruby
RSpec.describe "exe/emf" do
  let(:exe) { File.expand_path("../exe/emf", __dir__) }

  it "prints version" do
    out, status = Open3.capture2("ruby", exe, "version")
    expect(status.exitstatus).to eq(0)
    expect(out).to match(/^emf \d+\.\d+\.\d+/)
  end

  it "prints info for a known fixture" do
    out, status = Open3.capture2("ruby", exe, "info", "spec/fixtures/simple/image1.emf")
    expect(status.exitstatus).to eq(0)
    expect(out).to include("Format:   :emf")
  end

  it "validate exits non-zero on corrupted" do
    _, status = Open3.capture2("ruby", exe, "validate",
      "spec/fixtures/emf-corrupted/" + Dir.children("spec/fixtures/emf-corrupted").first { _1.end_with?(".emf") })
    expect(status.exitstatus).to be > 0
  end
end
```

## Done when

- [ ] All subcommands implemented.
- [ ] Help text is useful.
- [ ] Exit codes are correct.
- [ ] CLI spec exercises each subcommand.
- [ ] No doubles, no `require_relative`.
