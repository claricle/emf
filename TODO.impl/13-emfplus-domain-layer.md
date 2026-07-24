# TODO 13 — EMF+ domain layer

**Priority:** P1
**Depends on:** 04, 12
**Status:** pending

## Context

Mirror of TODO 10 (EMF domain) but for EMF+. Translate each `EmfPlus::Binary::Records::*` wire record into a semantic `Emf::Model::EmfPlus::Records::*` domain record.

## Outcomes

- One domain class per PMR_* record type (~58).
- Each follows the pattern from TODO 10: `attr_reader`, `from_wire`, `to_wire`, `accept(visitor)`, value equality.
- `Emf::Model::EmfPlus::Header` wraps the wire header.

## Naming

Wire: `Emf::EmfPlus::Binary::Records::FillRects`
Domain: `Emf::Model::EmfPlus::Records::FillRects`

## Pattern

Same as TODO 10. Each visit_* method registered with `Emf::Model::Visitor.register_visit(:visit_emfplus_fill_rects)`.

## Files

```
lib/emf/model/emf_plus.rb
lib/emf/model/emf_plus/header.rb
lib/emf/model/emf_plus/records.rb
lib/emf/model/emf_plus/records/*.rb           # ~58 files
spec/emf/model/emf_plus/records/*_spec.rb
```

## Done when

- [ ] All ~58 PMR_* record types have a domain class.
- [ ] `Emf::Model::EmfPlus::Header` exposes semantic fields.
- [ ] All from_wire / to_wire round-trip.
- [ ] All visit_* methods registered.
- [ ] All specs green.
