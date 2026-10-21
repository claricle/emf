# frozen_string_literal: true

module Emf
  module EmfPlus
    class Stream
      # The Links view of a stream's records: GetDC spans, effect links by draw
      # handle and link diagnostics.
      class LinkIndex
        # A record handle seen through the framed-record interface Links reads.
        Frame = Struct.new(:handle, :comment_index) do
          def type = handle.record.type
          def flags = handle.record.flags
          def offset = handle.offset
        end
        private_constant :Frame

        attr_reader :dc_spans, :errors

        def initialize(source, handles, segments)
          frames = handles.map { |handle| Frame.new(handle, segments[handle.segment_index].record_index) }
          links, @errors = Links.effect_links(frames)
          @effects = links.to_h { |link| [link.draw.handle.stream_index, link.effect.handle] }.freeze
          @dc_spans = Links.get_dc_spans(source, frames).freeze
        end

        def effect_for(handle) = @effects[handle.stream_index]
      end
    end
  end
end
