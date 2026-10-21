# frozen_string_literal: true

module Emf
  module EmfPlus
    autoload :Parser, "emf/emf_plus/parser"
    autoload :Serializer, "emf/emf_plus/serializer"
    autoload :Binary, "emf/emf_plus/binary"
    autoload :Frame, "emf/emf_plus/frame"
    autoload :Records, "emf/emf_plus/records"
    autoload :ObjectChain, "emf/emf_plus/object_chain"
    autoload :ObjectTable, "emf/emf_plus/object_table"
    autoload :Objects, "emf/emf_plus/objects"
    autoload :Effects, "emf/emf_plus/effects"
    autoload :Stream, "emf/emf_plus/stream"
    autoload :StaleStreamError, "emf/error"
    autoload :Links, "emf/emf_plus/links"
  end
end
