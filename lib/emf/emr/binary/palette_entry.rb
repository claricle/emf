# frozen_string_literal: true

require "bindata"

module Emf
  module Emr
    module Binary
      class EmrPaletteEntry < BinData::Record
        uint8 :red
        uint8 :green
        uint8 :blue
        uint8 :flags
      end
    end
  end
end

BinData::RegisteredClasses.register("emr_palette_entry", Emf::Emr::Binary::EmrPaletteEntry)
