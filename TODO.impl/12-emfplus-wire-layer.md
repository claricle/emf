# TODO 12 — EMF+ wire layer (~60 EMF+ records)

**Priority:** P1
**Depends on:** 03
**Status:** pending

## Context

EMF+ is a separate record set that travels inside EMF `EMR_COMMENT` records with identifier `0x2B464D45` ("EMF+"). It has its own header (EMF+ Header), object table, and ~58 record types (`U_PMR_*` in `libUEMF-0.2.5/upmf.h`). The MS-EMFPLUS spec is the authoritative reference.

EMF+ is more capable than EMF (anti-aliased graphics, gradients, image effects, compressed images), but also more complex. libemf2svg parses its structure but renders nothing. We will faithfully parse it so emfsvg can render in the future.

## Outcomes

- `lib/emf/emf_plus/binary/header.rb` declares the EMF+ Header struct (`Type`, `Size`, `Flags`, plus `EmfPlusFlags`, `DpiX`, `DpiY`).
- `lib/emf/emf_plus/binary/records.rb` declares the autoload list + `TYPE_TO_NAME` registry for all 58+ PMR_* types.
- `lib/emf/emf_plus/binary/records/*.rb` declares one bindata class per PMR_* type.
- All records round-trip.

## PMR_* type catalog

From MS-EMFPLUS section 2.3 (RecordType enumeration):

- 0x4001 Header
- 0x4002 Object
- 0x4003 Clear
- 0x4004 FillRects
- 0x4005 DrawRects
- 0x4006 FillPolygon
- 0x4007 DrawLines
- 0x4008 FillEllipse
- 0x4009 DrawEllipse
- 0x400A FillPie
- 0x400B DrawPie
- 0x400C DrawArc
- 0x400D FillRegion
- 0x400E DrawRegion
- 0x400F FillPath
- 0x4010 DrawPath
- 0x4011 FillClosedCurve
- 0x4012 DrawClosedCurve
- 0x4013 DrawCurve
- 0x4014 DrawBeziers
- 0x4015 DrawImage
- 0x4016 DrawImagePoints
- 0x4017 DrawString
- 0x4018 SetRenderingOrigin
- 0x4019 SetAntiAliasMode
- 0x401A SetTextRenderingHint
- 0x401B SetTextContrast
- 0x401C SetInterpolationMode
- 0x401D SetPixelOffsetMode
- 0x401E SetCompositingMode
- 0x401F SetCompositingQuality
- 0x4020 Save
- 0x4021 Restore
- 0x4022 BeginContainer
- 0x4023 BeginContainerNoParams
- 0x4024 EndContainer
- 0x4025 SetWorldTransform
- 0x4026 ResetWorldTransform
- 0x4027 MultiplyWorldTransform
- 0x4028 TranslateWorldTransform
- 0x4029 ScaleWorldTransform
- 0x402A RotateWorldTransform
- 0x402B SetPageTransform
- 0x402C ResetClip
- 0x402D SetClipRect
- 0x402E SetClipPath
- 0x402F SetClipRegion
- 0x4030 OffsetClip
- 0x4031 DrawDriverString
- 0x4032 ObjectRecordType (mask)
- 0x4033 SerializableObject
- 0x4034 SetTSClip
- 0x4035 SetTSGraphics

The high bit (`0x4000`) is the EMF+ "record flag". The type field is `Type & 0x3FFF` for the actual code.

## Bindata pattern

```ruby
# lib/emf/emf_plus/binary/record.rb
module Emf
  module EmfPlus
    module Binary
      class Record < BinData::Record
        endian :little
        uint16 :type
        uint16 :flags
        uint32 :size, value: -> { num_bytes }
        uint32 :data_size
      end
    end
  end
end
```

Each PMR_* record subclass adds its specific fields after the 12-byte common header.

## Files

```
lib/emf/emf_plus.rb
lib/emf/emf_plus/binary.rb
lib/emf/emf_plus/binary/header.rb
lib/emf/emf_plus/binary/record.rb            # 12-byte common header
lib/emf/emf_plus/binary/records.rb
lib/emf/emf_plus/binary/records/*.rb         # ~58 files
spec/emf/emf_plus/binary/*_spec.rb
```

## Verification

Per-record round-trip, same pattern as TODO 09.

## Done when

- [ ] All ~58 PMR_* types have a wire class.
- [ ] Registry lookup works for all known type codes.
- [ ] All round-trip specs pass.
- [ ] No doubles, no `require_relative`, no `respond_to?` for typing.
