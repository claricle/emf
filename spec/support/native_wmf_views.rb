# frozen_string_literal: true

require "fiddle"
require_relative "native_wmf_view_decoder"

# Calls the Rust typed-view exports (emf_wmf_record_view, emf_wmf_embedded_emf) so Rust
# semantics can be compared with Emf::Wmf::{Dib,Bitmap16,BitmapImage,EscapeViews,EmbeddedEmf}.
class NativeWmfViews
  POINTER = Fiddle::TYPE_VOIDP

  def initialize(library_path)
    @library = Fiddle.dlopen(library_path)
    @parse = function("emf_wmf_parse", [POINTER, Fiddle::TYPE_LONG_LONG, POINTER, POINTER, POINTER], Fiddle::TYPE_INT)
    @free = function("emf_wmf_document_free", [POINTER], Fiddle::TYPE_VOID)
    @record_view = function("emf_wmf_record_view", [POINTER, Fiddle::TYPE_LONG_LONG, POINTER, POINTER, POINTER], Fiddle::TYPE_INT)
    @embedded = function("emf_wmf_embedded_emf", [POINTER, POINTER, POINTER, POINTER], Fiddle::TYPE_INT)
    @view = function("emf_buffer_view", [POINTER, POINTER, POINTER], Fiddle::TYPE_INT)
    @buffer_free = function("emf_buffer_free", [POINTER], Fiddle::TYPE_VOID)
  end

  # Yields a Session bound to a live Rust document for bytes.
  def open(bytes)
    out = slot
    status = @parse.call(bytes, bytes.bytesize, 0, out, 0)
    raise "emf_wmf_parse failed (#{status})" unless status.zero?

    handle = out[0, 8].unpack1("J")
    yield Session.new(self, handle)
  ensure
    @free.call(handle) if handle && handle != 0
  end

  def record_views(handle, index)
    NativeWmfViewDecoder.new.record(call_buffer { |out| @record_view.call(handle, index, 0, out, 0) })
  end

  def embedded_sequences(handle)
    NativeWmfViewDecoder.new.sequences(call_buffer { |out| @embedded.call(handle, 0, out, 0) })
  end

  Session = Struct.new(:views, :handle) do
    def record_views(index) = views.record_views(handle, index)
    def embedded_sequences = views.embedded_sequences(handle)
  end

  private

  def function(name, arguments, result)
    Fiddle::Function.new(@library[name], arguments, result)
  end

  def slot
    Fiddle::Pointer["\0" * 8]
  end

  def call_buffer
    out = slot
    status = yield out
    raise "native view call failed (#{status})" unless status.zero?

    buffer = out[0, 8].unpack1("J")
    data = slot
    length = slot
    raise "emf_buffer_view failed" unless @view.call(buffer, data, length).zero?

    Fiddle::Pointer.new(data[0, 8].unpack1("J"))[0, length[0, 8].unpack1("Q")].b
  ensure
    @buffer_free.call(buffer) if buffer && buffer != 0
  end
end
