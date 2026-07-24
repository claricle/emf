# frozen_string_literal: true

require "bindata"

module Emf
  autoload :VERSION, "emf/version"
  autoload :Error, "emf/error"
  autoload :FormatError, "emf/error"
  autoload :ParseError, "emf/error"
  autoload :SerializeError, "emf/error"
  autoload :Detector, "emf/detector"
  autoload :Binary, "emf/binary"
  autoload :Model, "emf/model"
  autoload :Visitors, "emf/visitors"
  autoload :Wmf, "emf/wmf"
  autoload :Emr, "emf/emr"
  autoload :EmfPlus, "emf/emf_plus"

  class << self
    def parse(bytes)
      case Detector.call(bytes)
      when :wmf_apm, :wmf_standard then Wmf::Parser.call(bytes)
      when :emf then Emr::Parser.call(bytes)
      end
    end

    def parse_file(path)
      parse(File.read(path, mode: "rb"))
    end

    def serialize(metafile)
      case metafile.format
      when :wmf then Wmf::Serializer.call(metafile)
      when :emf, :emf_plus then Emr::Serializer.call(metafile)
      else raise SerializeError, "unknown format: #{metafile.format.inspect}"
      end
    end

    def serialize_file(metafile, path)
      File.binwrite(path, serialize(metafile))
    end

    def detect_format(bytes)
      case Detector.call(bytes)
      when :wmf_apm, :wmf_standard then :wmf
      when :emf then :emf
      end
    end
  end

  # Eager-load the shared bindata primitives so that BinData::RegisteredClasses
  # knows about `rectl`, `point_l`, `color_ref`, etc. before any record class
  # is autoloaded. Referencing the constant triggers the autoload of
  # emf/binary/types, which calls register() for each primitive.
  Binary::Types
end
