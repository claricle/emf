# frozen_string_literal: true

require "spec_helper"
require_relative "../../../support/record_variants_examples"
require_relative "../../../support/record_variants_region"

RSpec.describe "Native record variants: region, clip and path paint records" do
  it_behaves_like "record variants", RecordVariants::CATALOGS.fetch(:region)
end
