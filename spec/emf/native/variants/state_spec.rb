# frozen_string_literal: true

require "spec_helper"
require_relative "../../../support/record_variants_examples"
require_relative "../../../support/record_variants_state"

RSpec.describe "Native record variants: state, transform and path control" do
  it_behaves_like "record variants", RecordVariants::CATALOGS.fetch(:state)
end
