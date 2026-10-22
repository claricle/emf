# frozen_string_literal: true

require_relative "emf_plus_common"

# EMF+ framing and control rules beyond emf_plus.rb: fixed Size/DataSize values,
# DataSize consistency, undecodable bodies, the Header signature and
# EndOfFile placement.
module Emf
  module Conformance
    module EmfPlusFraming
      Records = Emf::EmfPlus::Records
      Support = EmfPlusSupport

      # DataSize each record type MUST have (Size is then 12 + DataSize), as stated in MS-EMFPLUS 2.3.x.
      FIXED_DATA_SIZE = {
        Records::OffsetClip => 8, Records::ResetClip => 0, Records::SetClipPath => 0, Records::SetClipRect => 16,
        Records::SetClipRegion => 0, Records::EndOfFile => 0, Records::GetDC => 0, Records::Header => 16,
        Records::Clear => 4, Records::DrawPath => 4, Records::FillPath => 4, Records::FillRegion => 4,
        Records::SetAntiAliasMode => 0, Records::SetCompositingMode => 0, Records::SetCompositingQuality => 0,
        Records::SetInterpolationMode => 0, Records::SetPixelOffsetMode => 0, Records::SetRenderingOrigin => 8,
        Records::SetTextContrast => 0, Records::SetTextRenderingHint => 0, Records::BeginContainer => 36,
        Records::BeginContainerNoParams => 4, Records::EndContainer => 4, Records::Restore => 4, Records::Save => 4,
        Records::MultiplyWorldTransform => 24, Records::ResetWorldTransform => 0, Records::RotateWorldTransform => 4,
        Records::ScaleWorldTransform => 8, Records::SetPageTransform => 4, Records::SetWorldTransform => 24,
        Records::TranslateWorldTransform => 8
      }.transform_keys { |klass| klass::TYPE }.freeze
      # The spec gives SetAntiAliasMode a DataSize only, not a Size.
      SIZE_UNSPECIFIED = [Records::SetAntiAliasMode::TYPE].freeze

      # Records whose Size and DataSize a formula rule states exactly: type => [rule module, check method]. Where that
      # check names a DataSize problem, the generic emfplus.record.data_size and emfplus.record.body_bounds stay silent.
      FORMULA_OWNERS = {
        Records::DrawEllipse::TYPE => %i[EmfPlusDrawing ellipse_size], Records::FillEllipse::TYPE => %i[EmfPlusDrawing ellipse_size],
        Records::DrawDriverString::TYPE => %i[EmfPlusPayloads driver_string_size],
        Records::DrawString::TYPE => %i[EmfPlusPayloads draw_string_size],
        Records::DrawImage::TYPE => %i[EmfPlusPayloads draw_image_size],
        Records::DrawImagePoints::TYPE => %i[EmfPlusPayloads draw_image_size],
        Records::SerializableObject::TYPE => %i[EmfPlusPayloads serializable_size],
        Records::SetTSClip::TYPE => %i[EmfPlusPayloads ts_clip_size], Records::SetTSGraphics::TYPE => %i[EmfPlusPayloads ts_graphics_size]
      }.freeze

      module_function

      def formula_owned?(located)
        owner, check = FORMULA_OWNERS[located.record.type]
        owner && Conformance.const_get(owner).public_send(check, located).to_s.include?("DataSize")
      end

      def fixed_size(located)
        record = located.record
        expected = FIXED_DATA_SIZE[record.type]
        return unless expected

        size = Support.size_of(record)
        data_size = Support.data_size_of(record)
        problems = []
        problems << "DataSize is #{data_size}, MUST be #{expected}" unless data_size == expected
        problems << "Size is #{size}, MUST be #{expected + 12}" unless size == expected + 12 || SIZE_UNSPECIFIED.include?(record.type)
        "#{Support.type_name(record)} #{problems.join(' and ')}" unless problems.empty?
      end

      # A defined record whose fields (padded to 4) decode to fewer bytes than DataSize leaves bytes unaccounted for.
      # DataSize is 32-bit aligned (MS-EMFPLUS 2.3.3), so padding after an odd-length field is not a surplus.
      def data_size_mismatch(located)
        record = located.record
        return unless Support.typed?(record) && !FIXED_DATA_SIZE.key?(record.type)

        used = record.body.num_bytes
        # An unaligned DataSize is emfplus.record.data_size_alignment's; compare what it rounds up to.
        return if ((record.data_size + 3) & ~3) == ((used + 3) & ~3) || formula_owned?(located)

        "#{Support.type_name(record)} DataSize is #{record.data_size} but its fields occupy #{used} bytes"
      end

      def data_size_alignment(located)
        data_size = Support.data_size_of(located.record)
        return if (data_size % 4).zero?

        "#{Support.type_name(located.record)} DataSize #{data_size} is not a multiple of 4"
      end

      def undecodable(located)
        record = located.record
        return if Support.typed?(record) || !Records.registry.key?(record.type) || formula_owned?(located)

        "#{Support.type_name(record)} body does not fit in its DataSize #{record.frame.data_size} " \
          "(a count or length field runs past the record)"
      end

      def header_signature(located)
        record = located.record
        return unless record.is_a?(Records::Header) && !record.valid_signature?

        format("EmfPlusHeader MetafileSignature is 0x%05X, MUST be 0xDBC01", record.graphics_signature)
      end

      def eof_findings(context)
        located = Support.records(context)
        return [] if located.empty?

        eof_at = located.rindex { |item| item.record.is_a?(Records::EndOfFile) }
        return [missing_eof(located.last)] unless eof_at

        eof = located.fetch(eof_at)
        problems = []
        problems << "records follow it in the stream" if eof_at < located.size - 1
        problems << "its EMR_COMMENT is not the record immediately before EMR_EOF" unless last_comment?(context, eof)
        if problems.empty?
          []
        else
          [Support.finding(eof,
                           "EmfPlusEndOfFile MUST be the last EMF+ record, in the EMF record before EMR_EOF; #{problems.join(' and ')}")]
        end
      end

      def missing_eof(last)
        Support.finding(last, "no EmfPlusEndOfFile: the last EMF+ record MUST be EmfPlusEndOfFile")
      end

      def last_comment?(context, eof)
        context.records.size >= 2 && eof.comment_index == context.records.size - 2
      end
    end

    registry = Registry.loading
    EmfPlusSupport.per_record(id: "emfplus.record.fixed_size", citation: "MS-EMFPLUS 2.3", kind: :record_fixed_size) do |located|
      EmfPlusFraming.fixed_size(located)
    end
    EmfPlusSupport.per_record(id: "emfplus.record.data_size", citation: "MS-EMFPLUS 2.3", kind: :record_data_size,
                              tolerant_reason: "the surplus bytes stay in the record's trailing data, so nothing is dropped") do |located|
      EmfPlusFraming.data_size_mismatch(located)
    end
    EmfPlusSupport.per_record(id: "emfplus.record.data_size_alignment", citation: "MS-EMFPLUS 2.3.3",
                              kind: :record_data_size_alignment,
                              tolerant_reason: "DataSize is informational once Size is aligned; the record frames and decodes") do |located|
      EmfPlusFraming.data_size_alignment(located)
    end
    EmfPlusSupport.per_record(id: "emfplus.record.body_bounds", citation: "MS-EMFPLUS 2.3", kind: :record_body_bounds,
                              tolerant_reason: "the record is kept as an unknown record with its bytes intact") do |located|
      EmfPlusFraming.undecodable(located)
    end
    EmfPlusSupport.per_record(id: "emfplus.header.signature", citation: "MS-EMFPLUS 2.2.2.19", kind: :header_signature) do |located|
      EmfPlusFraming.header_signature(located)
    end
    registry.register(id: "emfplus.eof.placement", formats: [:emf_plus], citation: "MS-EMFPLUS 1.3", kind: :eof_placement,
                      tolerant_reason: "records after the EMF+ end of file stay readable and are kept") do |context|
      EmfPlusFraming.eof_findings(context)
    end
  end
end
