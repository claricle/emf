# frozen_string_literal: true

require "weakref"

module NativeLifetimeAcceptance
  ALLOCATIONS = {
    emf_parse: :document, emf_wmf_parse: :wmf_document,
    emf_document_snapshot: :buffer, emf_wmf_document_snapshot: :buffer, emf_record_bytes: :buffer
  }.freeze
  RELEASES = {
    emf_document_free: :document, emf_wmf_document_free: :wmf_document,
    emf_buffer_free: :buffer, emf_error_free: :error
  }.freeze

  # Observe actual Fiddle calls and their returned handles; never invent or reuse handles.
  def observe_native_lifetimes(loader, after_invoke: nil)
    events = { allocated: Hash.new { |hash, key| hash[key] = [] }, freed: Hash.new { |hash, key| hash[key] = [] } }
    allow(loader).to receive(:invoke).and_wrap_original do |original, name, *args|
      result = original.call(name, *args)
      if (kind = ALLOCATIONS[name])
        handle = loader.send(:pointer, args[-2])
        events[:allocated][kind] << handle unless handle.zero?
        error = loader.send(:pointer, args[-1])
        events[:allocated][:error] << error unless error.zero?
      elsif (kind = RELEASES[name])
        events[:freed][kind] << args.first
      end
      after_invoke&.call(name)
      result
    end
    events
  end

  def expect_native_released(events, **counts)
    expect(events[:freed].transform_values(&:tally)).to eq(events[:allocated].transform_values(&:tally))
    expect(events[:allocated].transform_values(&:length)).to eq(counts)
  end

  def retain_native_record(backend, bytes, expose: false)
    metafile = backend.parse(bytes)
    record = metafile.records.first
    wire = record.wire if expose
    [record, wire, WeakRef.new(metafile)]
  end

  def retain_native_wire(backend, bytes)
    metafile = backend.parse(bytes)
    record = metafile.records.first
    [record.wire, WeakRef.new(metafile), WeakRef.new(record)]
  end

  def collect_native_metafile(reference)
    3.times do
      GC.start(full_mark: true, immediate_sweep: true)
      break unless reference.weakref_alive?
    end
    expect(reference.weakref_alive?).to be_falsey
  end
end
