# frozen_string_literal: true

module Emf
  module SpecSupport
    # The README of spec/fixtures/emf-corrupted is the malformation label; the bytes are the truth (a few
    # labels are inaccurate, see the per-file notes). For each file:
    #   strict        requirement ids that MUST appear under the strict profile AND name the corruption itself
    #                 (producer-wide findings such as emf.object.pen_cosmetic_width may appear too);
    #   evidence      optional regexp the message of a strict diagnostic must match, so the id is anchored to the
    #                 corrupted record and not to an incidental finding elsewhere in the file;
    #   undetectable  instead of strict: the id of a not_checkable manifest row proving no stream property
    #                 distinguishes the corruption. A row has strict ids or undetectable, never neither;
    #   tolerant_valid the expected tolerant validity;
    #   pending       why a more precise naming rule is still missing.
    module CorpusOracle
      Row = Struct.new(:strict, :tolerant_valid, :pending, :undetectable, :evidence, keyword_init: true)

      def self.row(strict, tolerant_valid: true, pending: nil, undetectable: nil, evidence: nil)
        Row.new(strict: strict, tolerant_valid: tolerant_valid, pending: pending, undetectable: undetectable, evidence: evidence)
      end

      UNPARSEABLE = ["emf.parse.unparseable"].freeze

      FILES = {
        "bad_corrupted_2014-12-02-215338.emf" => row(UNPARSEABLE, tolerant_valid: false),
        "bad_corrupted_2014-12-02-215339.emf" => row(["emf.dc.restore_depth"]),
        # EXTTEXTOUTW at 46984 with a wild offString: recovered as Raw, and its string is out of bounds.
        "bad_corrupted_2014-12-02-215358.emf" => row(%w[emf.exttextout.string_bounds]),
        "bad_corrupted_2014-12-02-215400.emf" => row(["emf.header.description_bounds"]),
        "bad_corrupted_2014-12-02-215425.emf" => row(["emf.record.array_exceeds_size"]),
        "bad_corrupted_2014-12-02-215428.emf" => row(UNPARSEABLE, tolerant_valid: false),
        "bad_corrupted_2014-12-07-140817.emf" => row(
          [], undetectable: "emf.select_object.corpus_corruption",
              pending: "all 28 SELECTOBJECT records are consistent; no stream property names the corruption"
        ),
        "bad_corrupted_2014-12-07-160856.emf" => row(["emf.path.end_unopened"]),
        # Image object record (flags 0x328) at EMF+ offset 72360 whose DataSize bytes 72368..72371 read
        # 28 00 00 ef (4009754664) instead of 0x28: the PMR_Object the README names.
        "bad_corrupted_2014-12-07-163010.emf" => row(["emfplus.stream.framing"], evidence: /DataSize 4009754664 exceeds Size 52/),
        "bad_corrupted_2014-12-07-235709.emf" => row(%w[emf.exttextout.string_bounds]),
        "bad_corrupted_2014-12-09-002112.emf" => row(["emf.record.exttextout_fixed_part"], evidence: /EXTTEXTOUTA Size 12/),
        # README says EMR_HEADER; the header is intact. The one byte that differs from spec/fixtures/emf/test-039.emf
        # is offset 99368: the type of a 12-byte EMR_SELECTOBJECT (0x25) became 0x52, EMR_EXTCREATEFONTINDIRECTW.
        "bad_corrupted_2014-12-13-105759.emf" => row(["emf.object.font_size"], evidence: /EXTCREATEFONTINDIRECTW Size 12/),
        # README says nHandles; the header is intact (Handles 3 as in spec/fixtures/emf/test-000.emf). The one byte
        # that differs from test-000 is offset 1044: the Size of a 12-byte EMR_SETICMMODE (type 98 at 1040) became 8.
        "bad_corrupted_2014-12-13-132605.emf" => row(["emf.record.fixed_size_raw"], evidence: /SETICMMODE.*Size is 8/),
        "bad_corrupted_2014-12-13-133727.emf" => row(["emf.header.handles"]),
        "bad_corrupted_2014-12-14-080539.emf" => row(["emf.header.description_bounds"]),
        # A string with an unpaired UTF-16 surrogate in the EXTTEXTOUTW at 1756.
        "bad_corrupted_2016-02-02-210039.emf" => row(["emf.exttextout.string_encoding"], evidence: /unpaired surrogate/),
        # The bitmap BMI header of the BITBLT at 28580 holds pixel-like bytes where xPelsPerMeter..ClrImportant
        # belong: ColorUsed reads 0x55C70000 (1439105024); no earlier record of the file has a nonzero ColorUsed.
        # The original is not in the corpus, so the replaced bytes cannot be diffed (28712..28715).
        "bad_corrupted_2016-02-02-220639.emf" => row(["emf.bitmap.color_table"], evidence: /ColorUsed 1439105024/),
        "bad_corrupted_2016-02-02-225639.emf" => row(["emf.bitmap.bmi_header_size"], pending: "no rel4 width/stride rule yet"),
        "bad_corrupted_2017-02-11-230400.emf" => row(["emf.comment.data_size"]),
        "bad_corrupted_2017-02-12-010400.emf" => row(["emfplus.record.unknown_type"]),
        # README says font index encoding; the one byte that differs from spec/fixtures/emf/test-014.emf is offset
        # 440: the type of a 12-byte EMR_SETROP2 (0x14) became 0x54, EMR_EXTTEXTOUTW, so EmrText cannot fit.
        "bad_corrupted_2017-05-12-074000.emf" => row(["emf.record.exttextout_fixed_part"], evidence: /EXTTEXTOUTW Size 12/)
      }.freeze

      # The 1.5 MiB recovery file; checking it must finish within this many seconds.
      LARGE_FILE = "bad_corrupted_2014-12-09-002112.emf"
      LARGE_FILE_BUDGET_SECONDS = 60
    end
  end
end
