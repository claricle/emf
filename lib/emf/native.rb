# frozen_string_literal: true

module Emf
  module Native
    class Unavailable < Error; end

    def self.backend
      require_relative "native/library_path"
      path = LibraryPath.new.call
      raise Unavailable, "native backend is not installed (set EMF_NATIVE_LIBRARY)" if path.nil? || path.empty?

      require_relative "native/loader"
      require_relative "native/snapshot"
      require_relative "native/header"
      require_relative "native/hydrator"
      require_relative "native/header_errors"
      Adapter.new(Loader.new(path))
    rescue LoadError => e
      raise Unavailable, "native backend dependencies could not load: #{e.message}"
    end

    class Adapter
      def initialize(loader)
        @loader = loader
      end

      def parse(bytes)
        input = bytes.b
        return parse_wmf(input) if %i[wmf_apm wmf_standard].include?(Detector.call(input))

        parse_emf(input)
      end

      def parse_emf(input)
        @loader.document(input) do |document|
          snapshot = Snapshot.new(@loader.snapshot(document))
          Hydrator.new(snapshot, input).call
        end
      rescue FormatError => e
        raise HeaderErrors.translate(e, input)
      end

      def parse_wmf(input)
        require_relative "native/wmf_snapshot"
        require_relative "native/wmf_hydrator"
        @loader.wmf_document(input) do |document|
          snapshot = WmfSnapshot.new(@loader.wmf_snapshot(document))
          WmfHydrator.new(snapshot, input).call
        end
      end

      def serialize(metafile)
        case metafile.format
        when :emf, :emf_plus then Emr::Serializer.call(metafile)
        when :wmf then Wmf::Serializer.call(metafile)
        else raise SerializeError, "native backend cannot serialize #{metafile.format.inspect}"
        end
      end
    end
  end
end
