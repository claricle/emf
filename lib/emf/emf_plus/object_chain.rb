# frozen_string_literal: true

module Emf
  module EmfPlus
    # Joins continued EmfPlusObject chunks into logical objects. A chain ends
    # when TotalObjectSize bytes of ObjectData are accumulated, not when the C
    # flag clears: Windows leaves C set on the final chunk. A final chunk with C
    # clear (the layout the spec describes) also ends the chain.
    module ObjectChain
      # One object, possibly spread over several records. Chunk boundaries and
      # flags are kept so `split` can reproduce the original records.
      class LogicalObject
        attr_reader :object_type, :emf_object_id, :data, :chunk_sizes

        def initialize(chunks)
          @object_type = chunks.first.object_type
          @emf_object_id = chunks.first.emf_object_id
          @data = chunks.map(&:object_data).join.b.freeze
          @chunk_sizes = chunks.map { |chunk| chunk.object_data.bytesize }.freeze
          @chunk_flags = chunks.map(&:flags).freeze
        end

        def total_size = data.bytesize

        def split(sizes = chunk_sizes)
          offset = 0
          sizes.each_with_index.map do |size, index|
            chunk = data.byteslice(offset, size)
            offset += size
            Records.decode(Parser.call(chunk_record(chunk, @chunk_flags.fetch(index, @chunk_flags.first))).first)
          end
        end

        private

        def chunk_record(chunk, flags)
          continued = flags.anybits?(Records::Object::CONTINUED_FLAG)
          body = (continued ? [total_size].pack("V") : "".b) + chunk
          padded = body + ("\0" * (-body.bytesize % 4))
          [Records::Object::TYPE, flags, 12 + padded.bytesize, body.bytesize].pack("vvVV") + padded
        end
      end

      module_function

      # Returns the records with each object (single or chained) as a
      # LogicalObject; every other record passes through unchanged.
      def call(records)
        entries = []
        queue = records.dup
        until queue.empty?
          record = queue.shift
          entries << (record.is_a?(Records::Object) ? LogicalObject.new(take_chain(record, queue)) : record)
        end
        entries
      end

      def take_chain(first, queue)
        return [first] unless first.continued?

        chunks = [first]
        accumulated = first.object_data.bytesize
        while accumulated < first.total_object_size
          chunk = next_chunk(first, chunks.last, queue.shift)
          chunks << chunk
          accumulated += chunk.object_data.bytesize
          break unless chunk.continued?
        end
        unless accumulated == first.total_object_size
          fail_chain(first,
                     "chain holds #{accumulated} bytes, TotalObjectSize is #{first.total_object_size}")
        end
        chunks
      end

      def next_chunk(first, previous, candidate)
        matches = candidate.is_a?(Records::Object) &&
                  candidate.object_type == first.object_type && candidate.emf_object_id == first.emf_object_id &&
                  (!candidate.continued? || candidate.total_object_size == first.total_object_size)
        fail_chain(previous, "continued EmfPlusObject chain not completed by a matching chunk") unless matches
        candidate
      end

      def fail_chain(record, message)
        raise ParseError.new(offset: record.offset, record_code: record.type,
                             message: "#{message} (chain started near offset #{record.offset})")
      end
    end
  end
end
