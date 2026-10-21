# frozen_string_literal: true

require "spec_helper"
require_relative "../../../support/record_variants_examples"
require_relative "../../../support/record_variants_opaque"

RSpec.describe "Native record variants: body-backed escape, GLS, UFI and color records" do
  it_behaves_like "record variants", %w[
    DrawEscape ExtEscape NamedEscape GlsRecord GlsBoundedRecord PixelFormat ForceUfiMapping SetLinkedUfis
    ColorCorrectPalette SetColorAdjustment SetColorspace DeleteColorspace CreateColorspace CreateColorspaceW
    SetIcmProfileA SetIcmProfileW ColorMatchToTargetW
  ]
end
