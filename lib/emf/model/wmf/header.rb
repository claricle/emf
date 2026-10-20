# frozen_string_literal: true

module Emf
  module Model
    module Wmf
      class Header
        def initialize(type:, version:, size_words:, number_of_objects:, max_record_words:, number_of_members:, placeable: nil)
          @type = type
          @version = version
          @size_words = size_words
          @number_of_objects = number_of_objects
          @max_record_words = max_record_words
          @number_of_members = number_of_members
          @placeable = placeable
        end

        attr_reader :type, :version, :size_words, :number_of_objects, :max_record_words, :number_of_members, :placeable
      end

      class PlaceableHeader
        def initialize(handle:, left:, top:, right:, bottom:, inch:, checksum:)
          @handle = handle
          @left = left
          @top = top
          @right = right
          @bottom = bottom
          @inch = inch
          @checksum = checksum
        end

        attr_reader :handle, :checksum
        attr_accessor :left, :top, :right, :bottom, :inch
      end
    end
  end
end
