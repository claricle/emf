# TODO 01 — Bootstrap gem skeleton

**Priority:** P0
**Depends on:** —
**Status:** pending

## Context

The repository at `/Users/mulgogi/src/claricle/emf/` currently contains only `README.adoc` (committed) plus untracked `spec/fixtures/` and `reference-docs/`. Before any parsing code lands, we need the gem scaffolding so every later TODO can assume a working `bundle exec rspec` and `bundle exec rubocop`.

## Outcomes

- A valid Ruby gem named `emf`, version `0.1.0`, BSD-2-Clause licensed.
- `bundle exec rspec` runs (and passes with a trivial "Emf is a module" spec).
- `bundle exec rubocop` runs clean on `lib/` and `spec/`.
- `bundle exec rake build` produces `pkg/emf-0.1.0.gem`.
- `bin/console` drops into an IRB session with `Emf` loaded.
- `exe/emf` exists as an executable stub (subcommand wiring lands in TODO 19).
- The directory tree from the plan's "Directory structure" section exists (empty files OK for now, with autoload-friendly placeholders).
- `lib/emf.rb` declares all top-level autoloads (`:Model`, `:Wmf`, `:Emf`, `:EmfPlus`, `:Error`, `:Visitors`, `:Binary`) and the public API surface (which delegates to per-format parsers and is implemented in TODO 15).
- No `require_relative` anywhere. No `require` of internal paths. All internal loading via `autoload`.
- `.rubocop.yml` enables frozen string literals, targets Ruby 3.1+, enables performance cops, **does NOT** disable `Gemspec/RequireMFA`.

## Files to create

```
emf.gemspec
Gemfile
Rakefile
.rspec
.rubocop.yml
.ruby-version          # 3.1.0
CODE_OF_CONDUCT.md
LICENSE.txt            # BSD-2-Clause
bin/console
bin/setup
exe/emf                # stub with --version and --help only
lib/emf.rb
lib/emf/version.rb
lib/emf/error.rb
lib/emf/binary.rb      # namespace autoload
lib/emf/binary/types.rb
lib/emf/binary/codec.rb
lib/emf/model.rb       # namespace autoload
lib/emf/model/metafile.rb
lib/emf/model/record.rb
lib/emf/model/geometry.rb
lib/emf/model/visitor.rb
lib/emf/visitors.rb
lib/emf/wmf.rb
lib/emf/emf.rb
lib/emf/emf_plus.rb
spec/spec_helper.rb
spec/emf_spec.rb       # trivial "is a module" spec
spec/support/fixture_path.rb
```

## Critical design constraints

- **Autoload everywhere.** Each `lib/emf/<dir>.rb` namespace file autoloads its children. Example:

  ```ruby
  # lib/emf.rb
  require "bindata"

  module Emf
    autoload :VERSION, "emf/version"
    autoload :Error, "emf/error"
    autoload :Binary, "emf/binary"
    autoload :Model, "emf/model"
    autoload :Visitors, "emf/visitors"
    autoload :Wmf, "emf/wmf"
    autoload :Emf, "emf/emf"
    autoload :EmfPlus, "emf/emf_plus"
  end
  ```

  ```ruby
  # lib/emf/model.rb
  module Emf
    module Model
      autoload :Metafile, "emf/model/metafile"
      autoload :Record, "emf/model/record"
      autoload :Geometry, "emf/model/geometry"
      autoload :Visitor, "emf/model/visitor"
    end
  end
  ```

- **Public API on `Emf` module** is reserved for TODO 15. Here, define `Emf.parse`, `Emf.parse_file`, `Emf.serialize`, `Emf.serialize_file`, `Emf.detect_format` as methods that raise `Emf::Error, "not yet implemented — see TODO 15"`. This keeps the public surface stable from day one.

- **Error hierarchy** lives in `lib/emf/error.rb`:

  ```
  Emf::Error                           (StandardError)
    Emf::FormatError                   (bad magic / unrecognised)
    Emf::ParseError                    (record-level; has .offset, .record_code, .message)
    Emf::SerializeError
  ```

  `ParseError` is a value-like exception: `attr_reader :offset, :record_code`.

- **`bin/console`** should `require "bundler/setup"` and `require "emf"` then start IRB. No `require_relative`.

- **`bin/setup`** is the canonical Bundler bootstrap script.

- **`exe/emf`** is a Ruby executable with `#!/usr/bin/env ruby` shebang. It loads `Emf` and routes to subcommands. For now: `info`, `dump`, `validate`, `version` — all print "not implemented yet" except `version`.

- **Gemspec:**
  - `name = "emf"`
  - `version = Emf::VERSION`
  - `required_ruby_version = ">= 3.1.0"`
  - `add_runtime_dependency "bindata", "~> 2.4"`
  - `add_development_dependency "rspec", "~> 3.13"`
  - `add_development_dependency "rspec-collection_matchers"`
  - `add_development_dependency "rubocop", "~> 1.65"`
  - `add_development_dependency "rubocop-performance", "~> 1.21"`
  - `add_development_dependency "rubyzip", "~> 2.3"`  (for TODO 02 converter)
  - `add_development_dependency "nokogiri", "~> 1.16"` (for TODO 02 converter)
  - `files = Dir.glob("lib/**/*.rb") + %w[README.adoc LICENSE.txt]` (do NOT include fixtures — they live in spec/)
  - `bindir = "exe"`, `executables = %w[emf]`

## Verification

```bash
bundle install
bundle exec rspec                       # passes the trivial spec
bundle exec rubocop                     # clean
bundle exec rake build                  # produces pkg/emf-0.1.0.gem
ruby -Ilib -e 'require "emf"; p Emf::VERSION'   # prints "0.1.0"
ruby -Ilib -e 'require "emf"; Emf.parse("x")' rescue puts $!.class   # Emf::Error
./exe/emf version                       # prints "emf 0.1.0"
grep -rE "require_relative|require [\"']\\." lib/  | head   # empty
grep -rE "\\bdouble\\b|instance_double" spec/  | head        # empty
```

## Done when

- [ ] All files listed above exist.
- [ ] `bundle exec rspec` is green.
- [ ] `bundle exec rubocop` is clean.
- [ ] `bundle exec rake build` succeeds.
- [ ] `bin/console` loads `Emf`.
- [ ] No `require_relative` in `lib/`.
- [ ] PR opened against `main` (not committed to main).
