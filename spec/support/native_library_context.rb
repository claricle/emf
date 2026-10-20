# frozen_string_literal: true

# Unset EMF_TEST_NATIVE_LIBRARY skips; a configured path that is not a file fails.
RSpec.shared_context "with native library" do
  let(:library) { ENV.fetch("EMF_TEST_NATIVE_LIBRARY", nil) }

  before do
    skip "set EMF_TEST_NATIVE_LIBRARY to run native specs" if library.nil?
    expect(File.file?(library)).to be(true), "EMF_TEST_NATIVE_LIBRARY is not a file: #{library}"
  end
end
