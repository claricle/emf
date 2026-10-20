# frozen_string_literal: true

module Emf
  module EmfPlus
    # Joins continued EmfPlusObject chunks into logical objects. A chain ends
    # when TotalObjectSize bytes of ObjectData are accumulated, not when the C
    # flag clears: Windows leaves C set on the final chunk. A final chunk with C
    # clear (the layout the spec describes) also ends the chain.
    module ObjectChain
      # One object, possibly spread over several records. Chunk boundaries and
      # source records are kept so `split` can return them unchanged.
      class LogicalObject
        attr_reader :object_type, :emf_object_id, :data, :chunk_sizes

        def initialize(chunks)
          @chunks = chunks.freeze
          @object_type = chunks.first.object_type
          @emf_object_id = chunks.first.emf_object_id
          @data = chunks.map(&:object_data).join.b.freeze
          @chunk_sizes = chunks.map { |chunk| chunk.object_data.bytesize }.freeze
          @chunk_flags = chunks.map(&:flags).freeze
        end

        def total_size = data.bytesize

        # With the original chunk sizes the source records come back as read:
        # padding, offsets and comment indexes included. Other sizes re-chunk
        # the data with zero padding, every chunk continued.
        def split(sizes = chunk_sizes)
          return @chunks.dup if sizes == chunk_sizes

          check_sizes(sizes)
          offset = 0
          sizes.each_with_index.map do |size, index|
            chunk = data.byteslice(offset, size)
            offset += size
            Records.decode(rechunked_frame(chunk, @chunks.fetch(index, @chunks.last)))
          end
        end

        private

        def check_sizes(sizes)
          return if sizes.any? && sizes.all? { |size| size.is_a?(Integer) && size.positive? } && sizes.sum == total_size

          raise ArgumentError, "split sizes #{sizes.inspect} must be positive and sum to #{total_size}"
        end

        def rechunked_frame(chunk, source)
          flags = @chunk_flags.first | Records::Object::CONTINUED_FLAG
          Frame.new(type: Records::Object::TYPE, flags: flags, size: 0, data_size: 0, data: "".b,
                    offset: source.offset, comment_index: source.comment_index)
               .with_data([total_size].pack("V") + chunk)
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
