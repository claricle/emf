# frozen_string_literal: true

require "spec_helper"

RSpec.describe Emf::Model::Visitor do
  it "auto-registers a visit method as a no-op default" do
    record_class = Class.new(Emf::Model::Record) do
      Emf::Model::Visitor.register_visit(:visit_emf_spec_dummy, self)

      def type_id = 99

      def accept(visitor)
        visitor.visit_emf_spec_dummy(self)
      end
    end

    base = Emf::Model::Visitor.new
    expect(base).to respond_to(:visit_emf_spec_dummy)
    expect { base.visit_emf_spec_dummy(record_class.new) }.not_to raise_error
    expect(base.visit_emf_spec_dummy(record_class.new)).to be_nil
  end

  it "lets a subclass override a visit method" do
    record_class = Class.new(Emf::Model::Record) do
      Emf::Model::Visitor.register_visit(:visit_emf_spec_dummy2, self)

      def type_id = 99

      def accept(visitor)
        visitor.visit_emf_spec_dummy2(self)
      end
    end

    sub = Class.new(Emf::Model::Visitor) do
      attr_reader :tally

      def initialize
        @tally = 0
      end

      def visit_emf_spec_dummy2(_record)
        @tally += 1
      end
    end.new

    sub.visit(record_class.new)
    sub.visit(record_class.new)
    expect(sub.tally).to eq(2)
  end

  it "walks every record in a metafile via visit_all" do
    record_a = Class.new(Emf::Model::Record) do
      Emf::Model::Visitor.register_visit(:visit_emf_spec_a, self)
      def type_id = 1
      def accept(v) = v.visit_emf_spec_a(self)
    end.new

    record_b = Class.new(Emf::Model::Record) do
      Emf::Model::Visitor.register_visit(:visit_emf_spec_b, self)
      def type_id = 2
      def accept(v) = v.visit_emf_spec_b(self)
    end.new

    counter = Class.new(Emf::Model::Visitor) do
      attr_reader :count

      def initialize = @count = 0
      def visit_emf_spec_a(_) = @count += 1
      def visit_emf_spec_b(_) = @count += 1
    end.new

    mf = Emf::Model::Metafile.new(format: :emf, header: nil, records: [record_a, record_b, record_a])
    counter.visit_all(mf)
    expect(counter.count).to eq(3)
  end
end
