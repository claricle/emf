# frozen_string_literal: true

module Emf
  module Native
    module PaletteFields
      def self.call(payload, family, raw)
        klass = [Emr::Binary::Records::SelectPalette, Emr::Binary::Records::CreatePalette,
                 Emr::Binary::Records::SetPaletteEntries, Emr::Binary::Records::ResizePalette,
                 Emr::Binary::Records::RealizePalette].fetch(family - 82)
        return array_fields(payload, family, raw, klass) if [83, 84].include?(family)

        fixed = { 82 => 4, 85 => 8, 86 => 0 }.fetch(family)
        raise FormatError, "invalid native palette payload" unless payload.bytesize == fixed && raw.bytesize >= fixed + 8

        fields = { trailing: raw.byteslice((fixed + 8)..) }
        fields[:ih_pal] = payload.unpack1("V") if fixed.positive?
        fields[:entry_count] = payload.byteslice(4, 4).unpack1("V") if family == 85
        [klass, fields]
      end

      def self.palette_counts_valid?(family, scalar, count)
        family != 83 || (scalar <= 0xFFFF && count <= 0xFFFF)
      end

      def self.array_fields(payload, family, raw, klass)
        raise FormatError, "invalid native palette array payload" if payload.bytesize < 16

        handle, scalar, count = payload.unpack("V2Q<")
        fixed = family == 83 ? 16 : 20
        valid = payload.bytesize == 16 + (count * 4) && raw.bytesize >= fixed + (count * 4)
        valid &&= palette_counts_valid?(family, scalar, count)
        raise FormatError, "invalid native palette array length" unless valid

        ResourceLimits::EmfRecords.check_count(count) if family == 84

        entries = payload.byteslice(16..).unpack("C*").each_slice(4).map do |red, green, blue, flags|
          { red: red, green: green, blue: blue, flags: flags }
        end
        fields = { ih_pal: handle, entry_count: count, palette_entries: entries, trailing: raw.byteslice((fixed + (count * 4))..) }
        fields[family == 83 ? :version : :start] = scalar
        [klass, fields]
      end
    end
  end
end
