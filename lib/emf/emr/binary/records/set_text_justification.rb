# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"
require "emf/emr/binary/state_record_body"

module Emf
  module Emr
    module Binary
      module Records
        class SetTextJustification < Emf::Emr::Binary::Record
          include StateRecordBody

          BODY_SIZE = 8

          int32 :n_break_extra
          int32 :n_break_count
          rest :trailing
        end
      end
    end
  end
end
