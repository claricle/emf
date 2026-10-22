# frozen_string_literal: true

module Emf
  module SpecSupport
    # The record-type inventories the manifest completeness gate compares against.
    #   EMF   - every constant of Emf::Emr::Binary::TypeCodes (MS-EMF 2.1.1 RecordType, 119 types)
    #   EMF+  - the Records classes that carry a TYPE, plus StrokeFillPath (0x4037), which has no
    #           class (it parses as Records::Unknown); 55 defined types, 0x4005-0x4007 reserved
    #   WMF   - the MS-WMF 2.1.1.1 RecordType table emf-07 extracted (70 names with function codes).
    #           The "115 layouts" of TODO.conformance/04 count META_HEADER, META_PLACEABLE and every
    #           escape subtype separately; those are not RecordType entries and are not gated here.
    module RecordInventories
      module_function

      def emf = Emf::Emr::Binary::TypeCodes.constants.to_h { |name| ["EMR_#{name}", Emf::Emr::Binary::TypeCodes.const_get(name)] }

      def emf_plus
        records = Emf::EmfPlus::Records
        typed = records.constants.map { |name| [name, records.const_get(name)] }
                       .select { |_, klass| klass.is_a?(Class) && klass.const_defined?(:TYPE, false) }
        typed.to_h { |name, klass| ["EmfPlus#{name}", klass::TYPE] }.merge("EmfPlusStrokeFillPath" => 0x4037)
      end

      WMF_RECORD_TYPES = {
        "META_ANIMATEPALETTE" => 0x0436,
        "META_ARC" => 0x0817,
        "META_BITBLT" => 0x0922,
        "META_CHORD" => 0x0830,
        "META_CREATEBRUSHINDIRECT" => 0x02FC,
        "META_CREATEFONTINDIRECT" => 0x02FB,
        "META_CREATEPALETTE" => 0x00F7,
        "META_CREATEPATTERNBRUSH" => 0x01F9,
        "META_CREATEPENINDIRECT" => 0x02FA,
        "META_CREATEREGION" => 0x06FF,
        "META_DELETEOBJECT" => 0x01F0,
        "META_DIBBITBLT" => 0x0940,
        "META_DIBCREATEPATTERNBRUSH" => 0x0142,
        "META_DIBSTRETCHBLT" => 0x0B41,
        "META_ELLIPSE" => 0x0418,
        "META_EOF" => 0x0000,
        "META_ESCAPE" => 0x0626,
        "META_ESCAPE_ENHANCED_METAFILE" => 0x000F,
        "META_EXCLUDECLIPRECT" => 0x0415,
        "META_EXTFLOODFILL" => 0x0548,
        "META_EXTTEXTOUT" => 0x0A32,
        "META_FILLREGION" => 0x0228,
        "META_FLOODFILL" => 0x0419,
        "META_FRAMEREGION" => 0x0429,
        "META_INTERSECTCLIPRECT" => 0x0416,
        "META_INVERTREGION" => 0x012A,
        "META_LINETO" => 0x0213,
        "META_MOVETO" => 0x0214,
        "META_OFFSETCLIPRGN" => 0x0220,
        "META_OFFSETVIEWPORTORG" => 0x0211,
        "META_OFFSETWINDOWORG" => 0x020F,
        "META_PAINTREGION" => 0x012B,
        "META_PATBLT" => 0x061D,
        "META_PIE" => 0x081A,
        "META_POLYGON" => 0x0324,
        "META_POLYLINE" => 0x0325,
        "META_POLYPOLYGON" => 0x0538,
        "META_REALIZEPALETTE" => 0x0035,
        "META_RECTANGLE" => 0x041B,
        "META_RESIZEPALETTE" => 0x0139,
        "META_RESTOREDC" => 0x0127,
        "META_ROUNDRECT" => 0x061C,
        "META_SAVEDC" => 0x001E,
        "META_SCALEVIEWPORTEXT" => 0x0412,
        "META_SCALEWINDOWEXT" => 0x0410,
        "META_SELECTCLIPREGION" => 0x012C,
        "META_SELECTOBJECT" => 0x012D,
        "META_SELECTPALETTE" => 0x0234,
        "META_SETBKCOLOR" => 0x0201,
        "META_SETBKMODE" => 0x0102,
        "META_SETDIBTODEV" => 0x0D33,
        "META_SETLAYOUT" => 0x0149,
        "META_SETMAPMODE" => 0x0103,
        "META_SETMAPPERFLAGS" => 0x0231,
        "META_SETPALENTRIES" => 0x0037,
        "META_SETPIXEL" => 0x041F,
        "META_SETPOLYFILLMODE" => 0x0106,
        "META_SETRELABS" => 0x0105,
        "META_SETSTRETCHBLTMODE" => 0x0107,
        "META_SETTEXTALIGN" => 0x012E,
        "META_SETTEXTCHAREXTRA" => 0x0108,
        "META_SETTEXTCOLOR" => 0x0209,
        "META_SETTEXTJUSTIFICATION" => 0x020A,
        "META_SETVIEWPORTEXT" => 0x020E,
        "META_SETVIEWPORTORG" => 0x020D,
        "META_SETWINDOWEXT" => 0x020C,
        "META_SETWINDOWORG" => 0x020B,
        "META_STRETCHBLT" => 0x0B23,
        "META_STRETCHDIB" => 0x0F43,
        "META_TEXTOUT" => 0x0521
      }.freeze

      def wmf = WMF_RECORD_TYPES
    end
  end
end
