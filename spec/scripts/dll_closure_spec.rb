# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require_relative "../../script/platform_probe/dll_closure"

RSpec.describe DllClosure do
  # Minimal PE: one .idata section holding the import descriptors and their names.
  def pe_with_imports(names, magic: 0x20b)
    fixed = magic == 0x20b ? 112 : 96
    idata = idata_section(names)
    header = dos_header + pe_headers(fixed + 128) + optional_header(magic, fixed, idata.bytesize)
    section = ".idata\0\0".b + [idata.bytesize, 0x1000, idata.bytesize, 0x400, 0, 0, 0, 0, 0].pack("VVVVVVvvV")
    image = header + section
    image + ("\0" * (0x400 - image.bytesize)) + idata
  end

  def dos_header = "MZ".b + ("\0" * 0x3a) + [0x40].pack("V")

  def pe_headers(optional_size)
    "PE\0\0".b + [0x8664, 1, 0, 0, 0, optional_size, 0x2022].pack("vvVVVvv")
  end

  def optional_header(magic, fixed, idata_size)
    directories = ("\0" * 128).b
    directories[8, 8] = [0x1000, idata_size].pack("VV")
    [magic].pack("v") + ("\0" * (fixed - 2)) + directories
  end

  def idata_section(names)
    cursor = (names.size + 1) * 20
    descriptors = names.map do |name|
      [0, 0, 0, 0x1000 + cursor, 0].pack("V5").tap { cursor += name.bytesize + 1 }
    end
    descriptors.join.b + ("\0" * 20) + names.map { |n| "#{n}\0" }.join.b
  end

  around do |example|
    Dir.mktmpdir("emf-dll-closure-spec") do |directory|
      @directory = directory
      example.run
    end
  end

  def write_dll(names, **options)
    File.join(@directory, "emf_ffi.dll").tap { |path| File.binwrite(path, pe_with_imports(names, **options)) }
  end

  it "reads imported DLL names from PE32+ and PE32 images" do
    [0x20b, 0x10b].each do |magic|
      reader = described_class::ImportReader.new(pe_with_imports(%w[KERNEL32.dll libunwind.dll], magic: magic))
      expect(reader.names).to eq(%w[KERNEL32.dll libunwind.dll])
    end
  end

  it "accepts a DLL importing only system DLLs" do
    dll = write_dll(%w[KERNEL32.dll ntdll.dll api-ms-win-crt-heap-l1-1-0.dll bcrypt.dll])

    expect(described_class.missing(dll)).to eq([])
  end

  it "names a non-system import" do
    dll = write_dll(%w[KERNEL32.dll libunwind.dll])

    expect(described_class.missing(dll)).to eq(["libunwind.dll"])
  end

  it "accepts a non-system import shipped beside the DLL" do
    dll = write_dll(%w[KERNEL32.dll libunwind.dll])
    File.binwrite(File.join(@directory, "libunwind.dll"), "")

    expect(described_class.missing(dll)).to eq([])
  end

  it "exits non-zero and names the import from the command line" do
    dll = write_dll(%w[KERNEL32.dll libunwind.dll])

    expect { expect(described_class.main([dll])).to eq(1) }.to output(/libunwind\.dll/).to_stderr
  end

  it "rejects a file that is not a PE image" do
    path = File.join(@directory, "bad.dll")
    File.binwrite(path, "\x7fELF".b + ("\0" * 100))

    expect { expect(described_class.main([path])).to eq(1) }.to output(/not a PE image/).to_stderr
  end
end
