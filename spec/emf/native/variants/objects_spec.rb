# frozen_string_literal: true

require "spec_helper"
require_relative "../../../support/record_variants_examples"
require_relative "../../../support/record_variants_objects"

RSpec.describe "Native record variants: object and palette records" do
  it_behaves_like "record variants", RecordVariants::CATALOGS.fetch(:objects)
end
