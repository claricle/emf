# frozen_string_literal: true

require "spec_helper"
require_relative "../../../support/record_variants_examples"
require_relative "../../../support/record_variants_text"

RSpec.describe "Native record variants: text records" do
  it_behaves_like "record variants", %w[ExtTextOutW ExtTextOutA PolyTextOutA PolyTextOutW SmallTextOut]
end
