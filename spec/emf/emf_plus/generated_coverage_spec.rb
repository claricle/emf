# frozen_string_literal: true

require "rbconfig"
require "spec_helper"
require_relative "../../support/emf_plus_generated_fixtures"

# Whole generated EMF files (EMF header + EMR_COMMENT carrying EMF+ + EMR_EOF)
# for the EMF+ types no corpus fixture covers, taken through parse, typed
# decode, byte-identical serialize and a record edit, on both backends.
RSpec.describe "Generated EMF+ whole-file coverage" do
  generator = Emf::SpecSupport::EmfPlusGeneratedFixtures
  records = Emf::EmfPlus::Records
  plus = Emf::EmfPlus

  library = lambda do
    ENV.fetch("EMF_TEST_NATIVE_LIBRARY") do
      ENV.fetch("EMF_NATIVE_LIBRARY") do
        extension = RbConfig::CONFIG.fetch("host_os").include?("darwin") ? "dylib" : "so"
        File.expand_path("../../../emf-rs/target/debug/libemf_ffi.#{extension}", __dir__)
      end
    end
  end

  def frames_of(metafile, errors: nil) = Emf::EmfPlus::Parser.from_metafile(metafile, errors: errors)

  def typed(metafile) = Emf::EmfPlus::Records.decode_all(frames_of(metafile))

  def with_backend(name, library)
    previous = ENV.to_h.slice("EMF_BACKEND", "EMF_NATIVE_LIBRARY")
    ENV["EMF_BACKEND"] = name
    ENV["EMF_NATIVE_LIBRARY"] = library
    yield
  ensure
    %w[EMF_BACKEND EMF_NATIVE_LIBRARY].each { |key| ENV[key] = previous[key] }
  end

  def rebuild(generator, frames, index, replacement)
    pieces = frames.each_with_index.map { |frame, at| [frame.comment_index, at == index ? replacement : frame.to_binary] }
    generator.emf_file(pieces.group_by(&:first).sort.map { |_comment, group| group.map(&:last).join.b })
  end

  expected_types = {
    Clear: [records::Clear],
    SetCompositingMode: [records::SetCompositingMode],
    Save: [records::Save],
    Restore: [records::Restore],
    BeginContainer: [records::BeginContainer],
    BeginContainerNoParams: [records::BeginContainerNoParams],
    EndContainer: [records::EndContainer],
    ScaleWorldTransform: [records::ScaleWorldTransform],
    SetTSGraphics: [records::SetTSGraphics],
    SetTSClip: [records::SetTSClip],
    StrokeFillPath: [records::Unknown],
    CustomLineCap: [records::Object, records::Object],
    BalancedStack: [records::Save, records::BeginContainer, records::BeginContainerNoParams,
                    records::EndContainer, records::EndContainer, records::Restore]
  }

  without_record_edit = %i[CustomLineCap BalancedStack StrokeFillPath].freeze
  stack_convention_variants = %i[reserved_flags_set unmatched_end_container swapped_container_ids].freeze

  %w[ruby native].each do |backend|
    context "with the #{backend} backend" do
      around do |example|
        path = library.call
        skip "build emf-ffi or set EMF_TEST_NATIVE_LIBRARY / EMF_NATIVE_LIBRARY" if backend == "native" && !File.file?(path)
        with_backend(backend, path) { example.run }
      end

      expected_types.each do |name, classes|
        describe name.to_s do
          let(:bytes) { generator.single_comment(*generator.positive_cases.fetch(name)) }
          let(:metafile) { Emf.parse(bytes) }

          it "parses as a clean EMF+ file whose header and EOF frame the case" do
            frames = frames_of(metafile)

            expect(metafile).to be_ok.and have_attributes(format: :emf_plus)
            expect(frames.first.type).to eq(0x4001)
            expect(frames.last.type).to eq(0x4002)
            expect(frames.size).to eq(classes.size + 2)
          end

          it "decodes every record to its typed class and re-encodes identically" do
            decoded = typed(metafile)

            expect(decoded[1..-2].map(&:class)).to eq(classes)
            expect(decoded.map(&:to_binary).join).to eq(metafile.emf_plus)
          end

          it "serializes byte for byte" do
            expect(Emf.serialize(metafile)).to eq(bytes)
          end

          it "exposes the case through the EMF+ stream with the same typed records and bytes" do
            stream = metafile.emf_plus_stream

            expect(stream.errors).to be_empty
            expect(stream.records.map { |handle| handle.record.class }[1..-2]).to eq(classes)
            expect(stream.records.map(&:stream_index)).to eq((0...(classes.size + 2)).to_a)
            expect(stream.to_metafile).to equal(metafile)
            expect(Emf.serialize(stream.to_metafile)).to eq(bytes)
          end

          next if without_record_edit.include?(name)

          it "edits the record through the stream and leaves the rest of the file alone" do
            stream = metafile.emf_plus_stream
            handle = stream.records[1]
            edited = handle.record.with(**generator.example(name).edit)

            result = stream.edit { |editor| editor.replace(handle, edited) }
            reread = Emf.parse(Emf.serialize(result)).emf_plus_stream

            expect(reread.errors).to be_empty
            expect(reread.records[1].record).to be_a(handle.record.class)
            expect(reread.records[1].record.body.snapshot).to eq(edited.body.snapshot)
            expect(reread.records.values_at(0, 2).map { |h| h.record.to_binary })
              .to eq(stream.records.values_at(0, 2).map { |h| h.record.to_binary })
            expect(Emf.serialize(metafile)).to eq(bytes)
          end
        end
      end

      describe "record edits" do
        (expected_types.keys - without_record_edit).each do |name|
          it "edits #{name} through the record API and the file still round trips" do
            bytes = generator.single_comment(*generator.positive_cases.fetch(name))
            frames = frames_of(Emf.parse(bytes))
            original = records.decode(frames[1])
            edited = original.with(**generator.example(name).edit)

            reparsed = Emf.parse(rebuild(generator, frames, 1, edited.to_binary))
            again = typed(reparsed)[1]

            expect(edited.to_binary).not_to eq(original.to_binary)
            expect(again).to be_a(original.class)
            expect(again.body.snapshot).to eq(edited.body.snapshot)
            expect(again.flags).to eq(edited.flags)
            expect(Emf.serialize(reparsed)).to eq(rebuild(generator, frames, 1, edited.to_binary))
            expect(frames_of(reparsed).values_at(0, 2).map(&:to_binary)).to eq(frames.values_at(0, 2).map(&:to_binary))
          end
        end

        it "edits the raw StrokeFillPath frame and keeps its type and flags" do
          bytes = generator.single_comment(generator.stroke_fill_path)
          frames = frames_of(Emf.parse(bytes))
          edited = frames[1].with_data("edited!!".b)

          reparsed = Emf.parse(rebuild(generator, frames, 1, edited.to_binary))
          frame = frames_of(reparsed)[1]

          expect(frame).to have_attributes(type: 0x4037, flags: 0x55AA, data: "edited!!".b)
          expect(Emf.serialize(reparsed)).to eq(rebuild(generator, frames, 1, edited.to_binary))
        end

        it "keeps the balanced stack records in order in the stream, which does no stack validation" do
          stream = Emf.parse(generator.single_comment(*generator.balanced_stack_records)).emf_plus_stream

          expect(stream.errors).to be_empty
          expect(stream.records[1, 6].map { |handle| handle.record.stack_index }).to eq([1, 2, 3, 3, 2, 1])
        end

        it "edits a balanced Save/Restore stack index without touching the containers" do
          bytes = generator.single_comment(*generator.balanced_stack_records)
          frames = frames_of(Emf.parse(bytes))
          edited = records.decode(frames[1]).with(stack_index: 7)

          reparsed = Emf.parse(rebuild(generator, frames, 1, edited.to_binary))

          expect(typed(reparsed)[1, 6].map(&:stack_index)).to eq([7, 2, 3, 3, 2, 1])
        end
      end

      describe "CustomLineCap" do
        let(:bytes) { generator.single_comment(*generator.custom_line_cap_records) }
        let(:metafile) { Emf.parse(bytes) }

        def logical(record) = Emf::EmfPlus::ObjectChain::LogicalObject.new([record])

        it "decodes the standalone cap and the pen's custom start and end caps" do
          cap, pen = typed(metafile)[1, 2].map { |record| plus::Objects.decode(logical(record)) }

          expect(cap).to be_a(plus::Objects::CustomLineCap).and have_attributes(cap_type: 0)
          expect(pen).to be_a(plus::Objects::Pen)
          expect([pen.custom_start_cap, pen.custom_end_cap]).to all(be_a(plus::Objects::CustomLineCap))
          expect(pen.custom_start_cap.data.base_cap).to eq(1)
        end

        it "re-encodes both objects identically" do
          typed(metafile)[1, 2].each_with_index do |record, index|
            expect(plus::Objects.decode(logical(record)).to_binary)
              .to eq([generator.custom_line_cap, generator.pen_with_custom_caps][index])
          end
        end

        it "resolves the cap and the pen from the stream's object table" do
          stream = metafile.emf_plus_stream
          cap = plus::Objects.decode(stream.objects.lookup(1, at: 4))
          pen = plus::Objects.decode(stream.objects.lookup(2, at: 4))

          expect(stream.objects.errors).to be_empty
          expect(stream.objects.lookup(1, at: 1)).to be_nil
          expect(cap).to be_a(plus::Objects::CustomLineCap)
          expect(pen.custom_start_cap.data.base_cap).to eq(1)
        end

        it "edits the cap object through the stream and the new cap resolves" do
          stream = metafile.emf_plus_stream
          handle = stream.records[1]
          edited = handle.record.with(object_data: generator.custom_line_cap(base_cap: 3))

          result = stream.edit { |editor| editor.replace(handle, edited) }
          reread = Emf.parse(Emf.serialize(result)).emf_plus_stream

          expect(plus::Objects.decode(reread.objects.lookup(1, at: 4)).data.base_cap).to eq(3)
          expect(plus::Objects.decode(reread.objects.lookup(2, at: 4)).custom_start_cap.data.base_cap).to eq(1)
        end

        it "edits the cap object data and the new cap decodes" do
          frames = frames_of(metafile)
          edited = records.decode(frames[1]).with(object_data: generator.custom_line_cap(base_cap: 3))

          reparsed = Emf.parse(rebuild(generator, frames, 1, edited.to_binary))
          cap = plus::Objects.decode(logical(typed(reparsed)[1]))

          expect(cap.data.base_cap).to eq(3)
          expect(Emf.serialize(reparsed)).to eq(rebuild(generator, frames, 1, edited.to_binary))
        end
      end

      describe "the combined file spread over several comments" do
        let(:bytes) { generator.combined_file }
        let(:metafile) { Emf.parse(bytes) }

        it "keeps every record, every comment and every byte" do
          decoded = typed(metafile)

          expect(metafile).to be_ok
          expect(metafile.records.size).to eq(generator.all_records.each_slice(4).count + 1)
          expect(decoded.size).to eq(generator.all_records.size + 2)
          expect(decoded.map(&:to_binary).join).to eq(metafile.emf_plus)
          expect(Emf.serialize(metafile)).to eq(bytes)
        end

        it "lays the stream over every comment and edits one record without touching the other segments" do
          stream = metafile.emf_plus_stream
          handle = stream.records.find { |h| h.record.is_a?(records::SetCompositingMode) }
          edited = handle.record.with(**generator.example(:SetCompositingMode).edit)

          result = stream.edit { |editor| editor.replace(handle, edited) }
          reread = Emf.parse(Emf.serialize(result)).emf_plus_stream
          others = (0...stream.segments.size).reject { |index| index == handle.segment_index }

          expect(stream.errors).to be_empty
          expect(stream.segments.size).to eq(generator.all_records.each_slice(4).count)
          expect(Emf.serialize(stream.to_metafile)).to eq(bytes)
          expect(reread.records[handle.stream_index].record.body.snapshot).to eq(edited.body.snapshot)
          expect(others.map { |index| reread.segments[index].payload }).to eq(others.map { |index| stream.segments[index].payload })
        end
      end

      describe "negative variants" do
        let(:cases) { generator.negative_cases }

        def framing(bytes)
          errors = []
          metafile = Emf.parse(bytes)
          [metafile, frames_of(metafile, errors: errors), errors]
        end

        framing_failures = {
          truncated_record: [/truncated EMF\+ record \(Size 64/, [0x4001]],
          data_size_beyond_size: [/DataSize 40 exceeds Size 16 - 12/, [0x4001]]
        }
        framing_failures.each do |name, (message, types)|
          it "#{name}: records a framing error, keeps the frames before it and the file bytes" do
            bytes = cases.fetch(name)
            metafile, frames, errors = framing(bytes)

            expect(errors.map(&:message)).to match([message])
            expect(frames.map(&:type)).to eq(types)
            expect(metafile).to be_ok
            expect(Emf.serialize(metafile)).to eq(bytes)
            expect { plus::Parser.call(metafile.emf_plus) }.to raise_error(Emf::ParseError, message)
          end
        end

        it "data_size_short: frames the record, but the typed decode rejects the empty body" do
          bytes = cases.fetch(:data_size_short)
          metafile, frames, errors = framing(bytes)

          expect(errors).to be_empty
          expect(frames[1]).to have_attributes(type: 0x4025, data_size: 0, size: 16)
          expect { records.decode(frames[1]) }.to raise_error(Emf::ParseError, /malformed Save body/)
          expect(frames.map(&:to_binary).join).to eq(metafile.emf_plus)
          expect(Emf.serialize(metafile)).to eq(bytes)
        end

        it "reports each framing failure and the bytes through the stream" do
          expected = { truncated_record: [/truncated EMF\+ record/, 1], data_size_beyond_size: [/DataSize 40 exceeds/, 1],
                       data_size_short: [/malformed Save body/, 3] }
          expected.each do |name, (message, count)|
            stream = Emf.parse(cases.fetch(name)).emf_plus_stream

            expect(stream.errors.map(&:message)).to match([message])
            expect(stream.records.size).to eq(count)
            expect(Emf.serialize(stream.to_metafile)).to eq(cases.fetch(name))
          end
        end

        it "reports no stream error for the variants that only break stack conventions" do
          stack_convention_variants.each do |name|
            stream = Emf.parse(cases.fetch(name)).emf_plus_stream

            expect(stream.errors).to be_empty, name.to_s
            expect(Emf.serialize(stream.to_metafile)).to eq(cases.fetch(name))
          end
        end

        it "reserved_flags_set: preserves the flags and re-encodes identically" do
          bytes = cases.fetch(:reserved_flags_set)
          metafile, _frames, errors = framing(bytes)
          save, mode = typed(metafile)[1, 2]

          expect(errors).to be_empty
          expect([save.flags, mode.flags]).to eq([0xFFFF, 0xFFFF])
          expect(mode.compositing_mode).to eq(0xFF)
          expect(typed(metafile).map(&:to_binary).join).to eq(metafile.emf_plus)
          expect(Emf.serialize(metafile)).to eq(bytes)
        end

        it "unmatched_end_container: keeps stack ids that match no Save or Begin without error" do
          bytes = cases.fetch(:unmatched_end_container)
          metafile, _frames, errors = framing(bytes)

          expect(errors).to be_empty
          expect(typed(metafile)[1, 2].map(&:stack_index)).to eq([9, 5])
          expect(Emf.serialize(metafile)).to eq(bytes)
        end

        it "swapped_container_ids: keeps non-nested End ids in order without error" do
          bytes = cases.fetch(:swapped_container_ids)
          metafile, _frames, errors = framing(bytes)

          expect(errors).to be_empty
          expect(typed(metafile)[1, 4].map(&:stack_index)).to eq([1, 2, 1, 2])
          expect(Emf.serialize(metafile)).to eq(bytes)
        end
      end
    end
  end

  describe "backend parity" do
    let(:files) { generator.positive_cases.transform_values { |recs| generator.single_comment(*recs) }.merge(generator.negative_cases) }

    def observe(bytes)
      metafile = Emf.parse(bytes)
      [Emf.serialize(metafile), metafile.emf_plus, metafile.format, metafile.records.size, metafile.errors.map(&:message)]
    end

    it "gives the native backend the same observations as Ruby on every generated file" do
      path = library.call
      skip "build emf-ffi or set EMF_TEST_NATIVE_LIBRARY / EMF_NATIVE_LIBRARY" unless File.file?(path)

      ruby = with_backend("ruby", path) { files.transform_values { |bytes| observe(bytes) } }
      native = with_backend("native", path) { files.transform_values { |bytes| observe(bytes) } }

      expect(native).to eq(ruby)
    end
  end
end
