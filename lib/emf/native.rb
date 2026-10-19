# frozen_string_literal: true

module Emf
  module Native
    class Unavailable < Error; end

    def self.backend
      path = ENV.fetch("EMF_NATIVE_LIBRARY", nil)
      raise Unavailable, "native backend is not installed (set EMF_NATIVE_LIBRARY)" if path.nil? || path.empty?

      require_relative "native/loader"
      require_relative "native/snapshot"
      require_relative "native/header"
      require_relative "native/hydrator"
      Adapter.new(Loader.new(path))
    rescue LoadError => e
      raise Unavailable, "native backend dependencies could not load: #{e.message}"
    end

    class Adapter
      def initialize(loader)
        @loader = loader
      end

      def parse(bytes)
        @loader.document(bytes) do |document|
          snapshot = Snapshot.new(@loader.snapshot(document))
          Hydrator.new(snapshot, ->(index) { @loader.record_bytes(document, index) }).call
        end
      end

      def serialize(metafile)
        case metafile.format
        when :emf, :emf_plus then Emr::Serializer.call(metafile)
        else raise SerializeError, "native backend cannot serialize #{metafile.format.inspect}"
        end
      end
    end
  end
end
