# frozen_string_literal: true

module Emf
  module EmfPlus
    # Typed views over framed EMF+ records. Types without a class decode to
    # Records::Unknown, which keeps the frame so nothing is dropped.
    module Records
      autoload :Base, "emf/emf_plus/records/base"
      autoload :Unknown, "emf/emf_plus/records/unknown"
      autoload :Header, "emf/emf_plus/records/header"
      autoload :EndOfFile, "emf/emf_plus/records/end_of_file"
      autoload :Comment, "emf/emf_plus/records/comment"
      autoload :GetDC, "emf/emf_plus/records/get_dc"
      autoload :Object, "emf/emf_plus/records/object"

      module_function

      def registry
        @registry ||= [Header, EndOfFile, Comment, GetDC, Object].to_h { |klass| [klass::TYPE, klass] }.freeze
      end

      def decode(frame)
        registry.fetch(frame.type, Unknown).new(frame)
      end

      def decode_all(frames)
        frames.map { |frame| decode(frame) }
      end
    end
  end
end
