# frozen_string_literal: true

require_relative "record_variants"

# Runs one synthetic input through a backend and reduces it to comparable data.
module RecordVariants
  Observed = Struct.new(:metafile, :section, :serialized, :errors, :wire, :wire_bytes, :parsed_lazily)

  # Canonical field walk that tolerates diagnostics, used for malformed controls.
  class Section < BackendParity::ParseSection
    def initialize(source)
      super
      @model = NativeCorpusParity::ValueModelWalker.new(@wire)
    end
  end

  module Runner
    module_function

    def with_backend(backend, library)
      previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
      ENV["EMF_BACKEND"] = backend
      ENV["EMF_NATIVE_LIBRARY"] = library
      yield
    ensure
      %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
    end

    def observe(bytes, backend, library)
      with_backend(backend, library) do
        metafile = Emf.parse(bytes)
        record = metafile.records.first
        # Both backends now parse lazily; the native backend's sources live under Emf::Native.
        lazy = record&.instance_variable_get(:@wire_source).class.name.to_s.start_with?("Emf::Native::")
        serialized = Emf.serialize(metafile)
        wire = record&.wire
        Observed.new(metafile, normalized(Section.new(bytes).call(metafile)), serialized, metafile.errors, wire,
                     wire&.to_binary_s, lazy)
      end
    end

    def reparse(observed, backend, library)
      with_backend(backend, library) do
        normalized(Section.new(observed.serialized).call(Emf.parse(observed.serialized)))
      end
    end

    # Diagnostic wording is backend specific (native reports numeric codes);
    # class, offset and record code are the shared contract.
    def normalized(section)
      section.merge("errors" => section.fetch("errors").map { |error| error.slice("class", "offset", "record_code") })
    end

    def value_of(wire, path)
      path.scan(/[^.\[\]]+/).reduce(wire) do |node, part|
        call = part.match(/\A(\w+)\((\d+)\)\z/)
        if call then node.public_send(call[1], call[2].to_i)
        elsif part.match?(/\A\d+\z/) then node[part.to_i]
        else node.public_send(part)
        end
      end
    end

    def comparable(value, expected)
      case expected
      when Integer then value.to_i
      when Float then value.to_f
      when String then value.to_s.b
      else value
      end
    end
  end
end
