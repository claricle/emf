# frozen_string_literal: true

module Emf
  module Wmf
    autoload :Parser, "emf/wmf/parser"
    autoload :Serializer, "emf/wmf/serializer"
    autoload :Binary, "emf/wmf/binary"
    autoload :Dib, "emf/wmf/dib"
    autoload :Bitmap16, "emf/wmf/dib"
    autoload :BitmapImage, "emf/wmf/dib"
    autoload :EscapeViews, "emf/wmf/escape_views"
    autoload :EmbeddedEmf, "emf/wmf/embedded_emf"
    autoload :Evidence, "emf/wmf/evidence"
    autoload :Recovery, "emf/wmf/recovery"
  end
end
