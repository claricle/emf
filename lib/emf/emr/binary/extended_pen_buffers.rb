# frozen_string_literal: true

require "bindata"

module Emf
  module Emr
    module Binary
      class ExtendedPenBuffers < BinData::Record
        mandatory_parameters :fixed_size, :first_offset, :first_length, :second_offset, :second_length
        string :first_padding, read_length: -> { [eval_parameter(:first_offset) - eval_parameter(:fixed_size), 0].max }
        string :first_bitmap, read_length: :first_length
        string :second_padding, read_length: lambda {
          finish = [eval_parameter(:first_offset), eval_parameter(:fixed_size)].max + eval_parameter(:first_length)
          [eval_parameter(:second_offset) - finish, 0].max
        }
        string :second_bitmap, read_length: :second_length
        rest :trailing
      end
    end
  end
end

BinData::RegisteredClasses.register("extended_pen_buffers", Emf::Emr::Binary::ExtendedPenBuffers)
