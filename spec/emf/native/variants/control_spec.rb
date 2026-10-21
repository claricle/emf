# frozen_string_literal: true

require "spec_helper"
require_relative "../../../support/record_variants_examples"
require_relative "../../../support/record_variants_control"

RSpec.describe "Native record variants: stream control and unknown records" do
  it_behaves_like "record variants", RecordVariants::CATALOGS.fetch(:control)
end
