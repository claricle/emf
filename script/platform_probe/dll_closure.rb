# frozen_string_literal: true

# Usage: ruby dll_closure.rb DLL
# Fails when a Windows DLL imports a DLL that is neither a Windows system DLL
# nor shipped in the same directory, because a user's machine will not have it.
module DllClosure
  SYSTEM_DLLS = %w[
    advapi32 bcrypt combase crypt32 gdi32 iphlpapi kernel32 kernelbase msvcrt
    ncrypt ntdll ole32 oleaut32 rpcrt4 secur32 shell32 shlwapi synchronization
    ucrtbase user32 userenv ws2_32
  ].map { |name| "#{name}.dll" }.freeze
  SYSTEM_PATTERNS = [/\Aapi-ms-win-.*\.dll\z/, /\Aext-ms-win-.*\.dll\z/].freeze
  IMPORT_DIRECTORIES = { import: [1, 20, 12], delay_import: [13, 32, 4] }.freeze

  class MalformedPe < StandardError; end

  # Reads the DLL names a PE image imports, including delay-load imports.
  class ImportReader
    def initialize(bytes)
      @bytes = bytes.b
      @pe = u32(0x3c)
      raise MalformedPe, "not a PE image" unless @bytes[0, 2] == "MZ" && @bytes[@pe, 4] == "PE\0\0".b
    end

    def names
      IMPORT_DIRECTORIES.values.flat_map { |index, size, name_at| directory_names(index, size, name_at) }
    end

    private

    def directory_names(index, size, name_at)
      rva = u32(data_directory + (index * 8))
      return [] if rva.zero?

      read_descriptors(offset_of(rva), size, name_at)
    end

    def read_descriptors(offset, size, name_at)
      names = []
      while u32(offset).positive? || u32(offset + name_at).positive?
        names << c_string(offset_of(u32(offset + name_at)))
        offset += size
      end
      names
    end

    def data_directory
      optional = @pe + 24
      case u16(optional)
      when 0x10b then optional + 96
      when 0x20b then optional + 112
      else raise MalformedPe, "unknown optional header magic"
      end
    end

    def offset_of(rva)
      sections.each do |virtual, span, raw|
        return rva - virtual + raw if rva >= virtual && rva < virtual + span
      end
      raise MalformedPe, "RVA 0x#{rva.to_s(16)} outside every section"
    end

    def sections
      table = @pe + 24 + u16(@pe + 20)
      Array.new(u16(@pe + 6)) do |i|
        entry = table + (i * 40)
        [u32(entry + 12), [u32(entry + 8), u32(entry + 16)].max, u32(entry + 20)]
      end
    end

    def c_string(offset)
      @bytes[offset..].unpack1("Z*")
    end

    def u16(offset) = field(offset, 2, "v")
    def u32(offset) = field(offset, 4, "V")

    def field(offset, width, directive)
      chunk = @bytes[offset, width]
      raise MalformedPe, "truncated PE image" unless chunk && chunk.bytesize == width

      chunk.unpack1(directive)
    end
  end

  def self.system_dll?(name)
    SYSTEM_DLLS.include?(name) || SYSTEM_PATTERNS.any? { |pattern| pattern.match?(name) }
  end

  # Imported DLL names (lowercased) that neither Windows nor the DLL's own directory provides.
  def self.missing(dll)
    shipped = Dir.children(File.dirname(dll)).map(&:downcase)
    ImportReader.new(File.binread(dll)).names.map(&:downcase).uniq
                .reject { |name| system_dll?(name) || shipped.include?(name) }
  end

  def self.main(argv)
    dll = argv.fetch(0) { abort "usage: dll_closure.rb DLL" }
    missing = missing(dll)
    if missing.empty?
      puts "dll_closure=ok #{File.basename(dll)} imports only system or shipped DLLs"
      return 0
    end
    warn "#{File.basename(dll)} imports DLLs absent from a clean Windows machine: #{missing.join(', ')}"
    1
  rescue MalformedPe => e
    warn "#{dll}: #{e.message}"
    1
  end
end

exit DllClosure.main(ARGV) if $PROGRAM_NAME == __FILE__
