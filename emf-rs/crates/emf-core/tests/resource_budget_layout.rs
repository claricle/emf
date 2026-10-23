//! Conformance for the layout-dependent allocation charges replayed by Ruby.
//!
//! Most widths are exact native layouts mirrored by Ruby. The font charge is
//! deliberately conservative: supported compilers use either 392 or 400 bytes.
//! Its compile-time guard also prevents under-accounting in non-test builds.
//! Other layout changes still require updating both backends and parity evidence.

#[cfg(target_pointer_width = "64")]
use emf_core::{Diagnostic, FontRecord, PolyTextEntry, RecordSpan, TriVertex};
#[cfg(target_pointer_width = "64")]
use std::mem::size_of;

#[test]
#[cfg(target_pointer_width = "64")]
fn native_allocation_layout_matches_ruby_resource_budget() {
    assert_eq!(size_of::<RecordSpan>(), 336, "RecordSpan layout changed");
    assert_eq!(size_of::<Diagnostic>(), 32, "Diagnostic layout changed");
    assert!(
        size_of::<FontRecord>() <= 400,
        "FontRecord exceeds its portable charge"
    );
    assert_eq!(
        size_of::<PolyTextEntry<u8>>(),
        136,
        "PolyTextEntry<u8> layout changed"
    );
    assert_eq!(
        size_of::<PolyTextEntry<u16>>(),
        136,
        "PolyTextEntry<u16> layout changed"
    );
    assert_eq!(
        size_of::<(usize, usize, usize, bool)>(),
        32,
        "poly-text span layout changed"
    );
    assert_eq!(size_of::<TriVertex>(), 16, "TriVertex layout changed");
}
