# frozen_string_literal: true

module Emf
  module Backend
    module Ruby
      class << self
        def parse(bytes)
          ResourceLimits.preflight(bytes)
          case Detector.call(bytes)
          when :wmf_apm, :wmf_standard then Wmf::Parser.call(bytes)
          when :emf then Emr::Parser.call(bytes)
          end
        rescue FormatError, ParseError => e
          raise ParseEvidenceBuilder.attach(e, bytes)
        end

        def serialize(metafile)
          case metafile.format
          when :wmf then Wmf::Serializer.call(metafile)
          when :emf, :emf_plus then Emr::Serializer.call(metafile)
          else raise SerializeError, "unknown format: #{metafile.format.inspect}"
          end
        end
      end
    end
    private_constant :Ruby

    class << self
      def parse(bytes)
        selected.parse(bytes)
      end

      def serialize(metafile)
        selected.serialize(metafile)
      end

      private

      def selected
        override = ENV.fetch("EMF_BACKEND", "auto")
        case override
        when "ruby" then Ruby
        when "auto" then native_or_ruby
        when "native" then Native.backend
        else raise ArgumentError, "invalid EMF_BACKEND: #{override.inspect} (expected auto, ruby, or native)"
        end
      end

      def native_or_ruby
        Native.backend
      rescue Native::Unavailable
        Ruby
      end
    end
  end
end
