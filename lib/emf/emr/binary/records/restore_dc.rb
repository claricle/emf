# frozen_string_literal: true

require "bindata"
require "emf/emr/binary/record"

module Emf
  module Emr
    module Binary
      module Records
        # EMR_RESTOREDC: iType, nSize, int32 SavedDC (relative or absolute index).
        class RestoreDc < Emf::Emr::Binary::Record
          int32 :saved_dc
        end
      end
    end
  end
end
