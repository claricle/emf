# frozen_string_literal: true

module Emf
  module EmfPlus
    # Typed bodies for the ObjectData carried by EmfPlusObject records.
    # Object types without a class keep their bytes in Objects::Opaque.
    module Objects
      autoload :Opaque, "emf/emf_plus/objects/opaque"
      autoload :Typed, "emf/emf_plus/objects/typed"
      autoload :Font, "emf/emf_plus/objects/font"
      autoload :StringFormat, "emf/emf_plus/objects/string_format"
      autoload :ImageAttributes, "emf/emf_plus/objects/image_attributes"
      autoload :Brush, "emf/emf_plus/objects/brush"
      autoload :Path, "emf/emf_plus/objects/path"
      autoload :Region, "emf/emf_plus/objects/region"
      autoload :Image, "emf/emf_plus/objects/image"
      autoload :Parts, "emf/emf_plus/objects/parts"
      autoload :Pen, "emf/emf_plus/objects/pen"
      autoload :CustomLineCap, "emf/emf_plus/objects/custom_line_cap"

      BRUSH = 1
      PEN = 2
      PATH = 3
      REGION = 4
      IMAGE = 5
      FONT = 6
      STRING_FORMAT = 7
      IMAGE_ATTRIBUTES = 8
      CUSTOM_LINE_CAP = 9
      TYPED = {
        BRUSH => :Brush, PEN => :Pen, PATH => :Path, REGION => :Region, IMAGE => :Image,
        FONT => :Font, STRING_FORMAT => :StringFormat, IMAGE_ATTRIBUTES => :ImageAttributes,
        CUSTOM_LINE_CAP => :CustomLineCap
      }.freeze
      private_constant :TYPED

      module_function

      # `logical` is an ObjectChain::LogicalObject.
      def decode(logical)
        name = TYPED[logical.object_type]
        name ? const_get(name).new(logical) : Opaque.new(logical)
      end
    end
  end
end
