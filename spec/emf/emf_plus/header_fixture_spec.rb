# frozen_string_literal: true

require "spec_helper"

# Corpus census (229 EMF files; 27 carry EMF+ Header records): every Header has
# the D (Dual) flag set, so no EMF+ Only fixture exists to pin. These pin real
# Dual headers of both versions and both V states.
RSpec.describe Emf::EmfPlus::Records::Header, "in corpus fixtures" do
  def header_of(path)
    metafile = Emf.parse_file(File.join("spec/fixtures", path))
    frame = Emf::EmfPlus::Parser.from_metafile(metafile).find { |f| f.type == 0x4001 }
    [frame, Emf::EmfPlus::Records.decode(frame)]
  end

  it "decodes a version 1 Dual header with the video flag set" do
    frame, header = header_of("emf/test-150.emf")

    expect(header).to be_dual.and be_video
    expect(header).to have_attributes(graphics_version: 1, logical_dpi_x: 96, logical_dpi_y: 96)
    expect(header.to_binary).to eq(frame.to_binary)
  end

  it "decodes a version 2 Dual header without the video flag" do
    _, header = header_of("emf-ea/EA-test-file-101.emf")

    expect(header).to be_dual
    expect(header).not_to be_video
    expect(header).to have_attributes(graphics_version: 2, logical_dpi_x: 600, logical_dpi_y: 600)
  end
end
