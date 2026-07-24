# frozen_string_literal: true

require "tmpdir"
require "zip"

require "spec_helper"
$LOAD_PATH.unshift(File.expand_path("../../scripts", __dir__))
require "convert_docs"

RSpec.describe Emf::Scripts::DocxToMarkdown do
  # Build a tiny synthetic .docx with two Heading1 chapters, a Heading2, a
  # paragraph, and a table. The real .docx files are 4-5 MB of OOXML — we
  # cannot use them in unit tests. This synthetic doc verifies the converter
  # wiring without bundling a fixture.
  def build_synthetic_docx(dir)
    path = File.join(dir, "synthetic.docx")
    Zip::File.open(path, Zip::File::CREATE) do |zip|
      zip.get_output_stream("word/document.xml") do |io|
        io.write(<<~XML)
          <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
          <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:body>
              <w:p>
                <w:pPr><w:pStyle w:val="Heading1"/></w:pPr>
                <w:r><w:t>Introduction</w:t></w:r>
              </w:p>
              <w:p>
                <w:pPr><w:pStyle w:val="Heading2"/></w:pPr>
                <w:r><w:t>Background</w:t></w:r>
              </w:p>
              <w:p>
                <w:r><w:t>This is a normal paragraph.</w:t></w:r>
              </w:p>
              <w:tbl>
                <w:tr>
                  <w:tc><w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc>
                  <w:tc><w:p><w:r><w:t>B</w:t></w:r></w:p></w:tc>
                </w:tr>
                <w:tr>
                  <w:tc><w:p><w:r><w:t>1</w:t></w:r></w:p></w:tc>
                  <w:tc><w:p><w:r><w:t>2</w:t></w:r></w:p></w:tc>
                </w:tr>
              </w:tbl>
              <w:p>
                <w:pPr><w:pStyle w:val="Heading1"/></w:pPr>
                <w:r><w:t>Structures</w:t></w:r>
              </w:p>
              <w:p>
                <w:r><w:t>More text.</w:t></w:r>
              </w:p>
            </w:body>
          </w:document>
        XML
      end
      zip.get_output_stream("[Content_Types].xml") { |io| io.write("<Types/>") }
    end
    path
  end

  let(:out_dir) { Dir.mktmpdir }
  let(:docx_path) { build_synthetic_docx(out_dir) }

  before { described_class.new(docx_path, out_dir).call }

  after { FileUtils.rm_rf(out_dir) }

  it "splits the docx into one file per Heading1" do
    files = Dir.children(out_dir).select { |f| f.end_with?(".md") } - ["INDEX.md"]
    expect(files.length).to eq(2)
  end

  it "writes an INDEX.md" do
    index = File.read(File.join(out_dir, "INDEX.md"))
    expect(index).to include("Introduction")
    expect(index).to include("Structures")
  end

  it "renders sub-headings as markdown" do
    intro = File.read(File.join(out_dir, "ch01-introduction.md"))
    expect(intro).to include("# Introduction")
    expect(intro).to include("## Background")
    expect(intro).to include("This is a normal paragraph.")
  end

  it "renders tables as GFM" do
    intro = File.read(File.join(out_dir, "ch01-introduction.md"))
    expect(intro).to include("| A | B |")
    expect(intro).to include("| --- | --- |")
    expect(intro).to include("| 1 | 2 |")
  end
end
