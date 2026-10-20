# frozen_string_literal: true

module Emf
  module EmfPlus
    class Stream
      # Builds the edited Metafile: dirty segments' comments are rewritten, every
      # other record is reused, and the header size follows the byte change.
      class Rebuild
        def initialize(source, dirty_segments)
          @source = source
          @dirty_segments = dirty_segments
        end

        def call
          records = @source.records.dup
          delta = @dirty_segments.sum { |segment| rewrite_comment(records, segment) }
          Model::Metafile.new(format: @source.format, header: resized_header(delta), records: records,
                              errors: @source.errors, emf_plus: emf_plus_of(records), trailing: @source.trailing)
        end

        private

        # Replaces the segment's comment in `records`; returns the change in bytes.
        def rewrite_comment(records, segment)
          original = @source.records[segment.record_index]
          wire = segment.comment_wire(original.wire)
          records[segment.record_index] = Model::Emr::Records::WireAdapter.new(wire: wire, offset: original.offset)
          wire.n_size - original.wire.n_size
        end

        def resized_header(delta)
          return @source.header if delta.zero?

          wire = @source.header.to_wire
          wire.n_bytes = @source.header.n_bytes + delta
          Model::Emr::Header.from_wire(wire)
        end

        def emf_plus_of(records)
          records.filter_map do |record|
            Emf::Emr::Parser.extract_emf_plus(record.wire) if record.wire.is_a?(Emf::Emr::Binary::Records::Comment)
          end.join.b
        end
      end
    end
  end
end
