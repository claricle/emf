# frozen_string_literal: true

require "digest"
require "json"
require "rubygems/platform"

module Emf
  module Native
    class LibraryPath
      def initialize(directory = __dir__)
        @directory = directory
      end

      def call
        override = ENV.fetch("EMF_NATIVE_LIBRARY", nil)
        return override unless override.nil?

        manifest_path = File.join(@directory, "platforms.json")
        return unless File.exist?(manifest_path)

        manifest = JSON.parse(File.read(manifest_path))
        validate_manifest(manifest)
        bundled_path(manifest)
      rescue JSON::ParserError, SystemCallError => e
        raise Unavailable, "native backend manifest could not load: #{e.message}"
      end

      private

      def validate_manifest(manifest)
        unless manifest.is_a?(Hash) && component?(manifest["platform"]) && component?(manifest["library"]) &&
               manifest["sha256"].is_a?(String) && manifest["sha256"].match?(/\A[0-9a-f]{64}\z/)
          raise Unavailable, "native backend manifest is invalid"
        end
        raise Unavailable, "native backend manifest platform mismatch" unless compatible_platform?(manifest["platform"])
        return if manifest["abi_version"].is_a?(Integer) && manifest["abi_version"] == 1

        raise Unavailable, "native backend manifest ABI version mismatch (expected 1)"
      end

      def compatible_platform?(platform)
        case Gem::Platform.local
        when Gem::Platform.new(platform) then true
        else false
        end
      end

      def component?(value)
        value.is_a?(String) && value.match?(/\A[a-zA-Z0-9_][a-zA-Z0-9_.-]*\z/)
      end

      def bundled_path(manifest)
        root = File.realpath(@directory)
        path = File.join(root, manifest.fetch("platform"), manifest.fetch("library"))
        unless File.realpath(path).start_with?("#{root}#{File::SEPARATOR}")
          raise Unavailable, "native backend library escapes its installation directory"
        end
        raise Unavailable, "native backend library checksum mismatch" unless Digest::SHA256.file(path).hexdigest == manifest.fetch("sha256")

        path
      end
    end
  end
end
