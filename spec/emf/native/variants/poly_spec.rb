# frozen_string_literal: true

require "spec_helper"
require_relative "../../../support/record_variants_examples"
require_relative "../../../support/record_variants_poly"

RSpec.describe "Native record variants: point and polygon records" do
  it_behaves_like "record variants", RecordVariants::CATALOGS.fetch(:poly)
end
