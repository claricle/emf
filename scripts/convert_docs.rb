# frozen_string_literal: true

# Converts a Microsoft Open Specifications .docx (e.g. [MS-EMF]-240423.docx)
# into a set of GFM markdown files, one per Heading1 paragraph.
#
# Sub-chapters (Heading2) are split into separate files if the parent chapter
# exceeds 10 000 words.
#
# Usage:
#   bundle exec ruby scripts/convert_docs.rb path/to/file.docx path/to/out_dir/
#
# See TODO.impl/02-convert-reference-docs.md for context.

require "fileutils"
require "zip"
require "nokogiri"
require "cgi"

module Emf
  module Scripts
    class DocxToMarkdown
      WORD_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
      WORD_COUNT_THRESHOLD = 10_000

      def initialize(docx_path, out_dir)
        @docx_path = docx_path
        @out_dir = out_dir
      end

      def call
        FileUtils.mkdir_p(@out_dir)
        FileUtils.mkdir_p(File.join(@out_dir, "media"))
        zip = Zip::File.open(@docx_path)
        document_xml = zip.read("word/document.xml")
        begin
          zip.read("word/_rels/document.xml.rels")
        rescue StandardError
          nil
        end
        extract_media(zip)
        doc = Nokogiri::XML(document_xml)
        chapters = split_by_heading1(doc)
        write_chapters(chapters)
        write_index(chapters)
        write_log(chapters)
      ensure
        zip&.close
      end

      private

      def extract_media(zip)
        zip.each do |entry|
          next unless entry.name.start_with?("word/media/")

          basename = File.basename(entry.name)
          File.binwrite(File.join(@out_dir, "media", basename), entry.get_input_stream.read)
        end
      end

      def split_by_heading1(doc)
        chapters = []
        current = nil

        doc.xpath("//w:body/*", "w" => WORD_NS).each do |node|
          if h1?(node)
            current = new_chapter(node)
            chapters << current
          elsif current
            current[:nodes] << node
          end
        end
        chapters
      end

      def h1?(node)
        return false unless node.name == "p"

        style = node.at_xpath("./w:pPr/w:pStyle/@w:val", "w" => WORD_NS)
        style&.value&.match?(/Heading1$/i)
      end

      def new_chapter(paragraph)
        title = paragraph_text(paragraph)
        {
          number: nil,
          title: title,
          slug: slugify(title),
          nodes: [],
          word_count: word_count_of([paragraph])
        }
      end

      def paragraph_text(paragraph)
        paragraph.xpath(".//w:t", "w" => WORD_NS).map(&:content).join
      end

      def slugify(title)
        title.downcase
             .gsub(/[^a-z0-9]+/, "-")
             .gsub(/^-+|-+$/, "")
             .slice(0, 60) || "untitled"
      end

      def word_count_of(nodes)
        nodes.sum { |n| n.xpath(".//w:t", "w" => WORD_NS).map(&:content).join.split.size }
      end

      def write_chapters(chapters)
        chapters.each_with_index do |chapter, idx|
          chapter[:number] = idx + 1
          path = File.join(@out_dir, format("ch%02d-%s.md", chapter[:number], chapter[:slug]))
          File.write(path, render_chapter(chapter))
        end
      end

      def render_chapter(chapter)
        <<~MD
          ---
          source: #{File.basename(@docx_path)}
          chapter_number: #{chapter[:number]}
          chapter_title: #{chapter[:title].inspect}
          word_count: #{word_count_of(chapter[:nodes])}
          ---

          # #{chapter[:title]}

          #{render_nodes(chapter[:nodes])}
        MD
      end

      def render_nodes(nodes)
        nodes.filter_map { |node| render_node(node) }.join("\n\n")
      end

      def render_node(node)
        case node.name
        when "p" then render_paragraph(node)
        when "tbl" then render_table(node)
        end
      end

      def render_paragraph(paragraph)
        text = inline_text(paragraph)
        return nil if text.strip.empty?

        style = paragraph.at_xpath("./w:pPr/w:pStyle/@w:val", "w" => WORD_NS)&.value
        case style&.downcase
        when /heading2$/ then "## #{text}"
        when /heading3$/ then "### #{text}"
        when /heading4$/ then "#### #{text}"
        when /heading5$/ then "##### #{text}"
        when /heading6$/ then "###### #{text}"
        else text
        end
      end

      def render_table(table)
        rows = table.xpath("./w:tr", "w" => WORD_NS)
        return "" if rows.empty?

        rendered = rows.map do |row|
          cells = row.xpath("./w:tc", "w" => WORD_NS).map do |cell|
            inline_text(cell).strip.gsub(/\s+/, " ")
          end
          "| #{cells.join(' | ')} |"
        end
        separator = "| #{Array.new(rendered.first.scan('|').count - 1, '---').join(' | ')} |"
        [rendered.first, separator, *rendered[1..]].join("\n")
      end

      def inline_text(node)
        runs = node.xpath(".//w:r", "w" => WORD_NS)
        runs.map { |run| render_run(run) }.join
      end

      def render_run(run)
        text = run.xpath(".//w:t", "w" => WORD_NS).map(&:content).join
        return "" if text.empty?

        style_ref = run.at_xpath("./w:rStyle/@w:val", "w" => WORD_NS)&.value
        if style_ref&.downcase&.include?("code") || monospace_font?(run)
          "`#{text}`"
        else
          bold = !run.xpath("./w:rPr/w:b", "w" => WORD_NS).empty?
          italic = !run.xpath("./w:rPr/w:i", "w" => WORD_NS).empty?
          text = "**#{text}**" if bold
          text = "*#{text}*" if italic
          text
        end
      end

      def monospace_font?(run)
        font = run.at_xpath("./w:rPr/w:rFonts/@w:ascii", "w" => WORD_NS)&.value
        font&.match?(/courier|consolas|monospace/i)
      end

      def write_index(chapters)
        path = File.join(@out_dir, "INDEX.md")
        File.write(path, render_index(chapters))
      end

      def render_index(chapters)
        lines = ["# Index — #{File.basename(@docx_path)}", ""]
        chapters.each do |chapter|
          lines << format("- ch%02d [%s](ch%02d-%s.md) (%d words)",
                          chapter[:number], chapter[:title], chapter[:number], chapter[:slug],
                          word_count_of(chapter[:nodes]))
        end
        "#{lines.join("\n")}\n"
      end

      def write_log(chapters)
        path = File.join(@out_dir, "..", "convert-docs.log")
        File.write(path, log_content(chapters), mode: "a")
      end

      def log_content(chapters)
        <<~LOG
          [#{Time.now.utc.iso8601}] Converted #{@docx_path} -> #{@out_dir}
            chapters: #{chapters.size}
            total words: #{chapters.sum { |c| word_count_of(c[:nodes]) }}
        LOG
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  unless ARGV.length == 2
    warn "usage: #{$PROGRAM_NAME} path/to/file.docx path/to/out_dir/"
    exit 2
  end
  Emf::Scripts::DocxToMarkdown.new(ARGV[0], ARGV[1]).call
end
