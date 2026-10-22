# frozen_string_literal: true

module Emf
  # Backend-neutral account of the check that rejected an input before a metafile model existed.
  #
  #   check    - Symbol naming the failed check (stable vocabulary; see Detector, Emr and Wmf::Evidence)
  #   offset   - byte offset in the input where the failing field or record starts
  #   declared - what the input states (a size, count, checksum, type), nil when it states nothing comparable
  #   actual   - what was found or required instead (bytes available, computed checksum, minimum size), nil when
  #              the check is a domain test with no single comparable value
  #
  # Units are bytes unless the check name says words. Reachable as `error.evidence` on Emf::FormatError and
  # Emf::ParseError raised by either backend; nil when a rejection has no neutral description.
  ParseEvidence = Struct.new(:check, :offset, :declared, :actual, keyword_init: true)

  module ParseEvidenceBuilder
    EMF_MAGIC_OFFSET = Detector::EMF_MAGIC_OFFSET

    module_function

    # Returns `error` with evidence attached when it can be derived from its message and the input.
    def attach(error, bytes)
      return error if error.evidence

      error.with_evidence(derive(error, bytes))
    end

    def derive(error, bytes)
      from_detector(error.message, bytes) || from_emf_header(error.message, bytes) || Wmf::Evidence.from_error(error, bytes)
    end

    def from_detector(message, bytes)
      case message
      when /\Ainput too short/
        ParseEvidence.new(check: :input_too_short, offset: 0, declared: 4, actual: bytes.bytesize)
      when /\Aunrecognised format \(signature=1/
        ParseEvidence.new(check: :emf_magic_missing, offset: EMF_MAGIC_OFFSET, declared: Detector::EMF_MAGIC,
                          actual: bytes.bytesize >= EMF_MAGIC_OFFSET + 4 ? bytes.unpack1("V", offset: EMF_MAGIC_OFFSET) : nil)
      when /\Aunrecognised format/
        ParseEvidence.new(check: :unrecognised_signature, offset: 0, declared: bytes.unpack1("V"), actual: nil)
      end
    end

    def from_emf_header(message, bytes)
      case message
      when /\Ainput too large/
        ParseEvidence.new(check: :emf_input_too_large, offset: 0, declared: Emr::Parser::MAX_INPUT_BYTES, actual: bytes.bytesize)
      when /\AEMF header nSize too small/
        ParseEvidence.new(check: :emf_header_size_too_small, offset: 4, declared: bytes.unpack1("V", offset: 4), actual: 8)
      when /\Atruncated EMF header \(claimed/
        ParseEvidence.new(check: :emf_header_truncated, offset: 0, declared: bytes.unpack1("V", offset: 4), actual: bytes.bytesize)
      when /\AEMF header nSize \d+ cannot hold its fields/
        ParseEvidence.new(check: :emf_header_cannot_hold_fields, offset: 4, declared: bytes.unpack1("V", offset: 4), actual: nil)
      end
    end
  end
end
