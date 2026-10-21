# frozen_string_literal: true

require "spec_helper"

RSpec.describe "EMF+ records spanning EMR_COMMENT_EMFPLUS boundaries" do
  # MS-EMFPLUS 1.3: "multiple EMF+ records can be embedded in a single EMF
  # record"; MS-EMF 2.3.3.2: the comment holds "one or more EMF+ records".
  # Only EmfPlusObject (C flag, ch02 EmfPlusObject Record) continues across
  # records, so a plain record cut at a comment end is malformed, not split.
  let(:whole) { [0x402A, 0, 24 + 12, 24].pack("vvVV") + ("\0" * 24) }
  it "names the overrun and the comment in the diagnostic" do
    errors = []
    comment_bytes = whole[0, 20]
    Emf::EmfPlus::Parser.call(comment_bytes, errors: errors, comment_index: 7)
    expect(errors.first).to be_a(Emf::ParseError)
    expect(errors.first.message).to include("overruns EMR_COMMENT_EMFPLUS record 7 by 16 bytes", "cannot span comments")
  end

  it "keeps the unindexed message for a plain byte string" do
    errors = []
    Emf::EmfPlus::Parser.call(whole[0, 20], errors: errors)
    expect(errors.first.message).to start_with("truncated EMF+ record (Size 36, 20 bytes left)")
  end
end
