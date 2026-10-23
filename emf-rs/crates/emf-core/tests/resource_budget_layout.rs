//! Conformance for the layout-dependent allocation charges replayed by Ruby.
//!
//! These `repr(Rust)` sizes were observed in the arm64-darwin native artifact;
//! they are not a stable ABI guarantee across compilers or targets. On supported
//! 64-bit targets this test must fail if a layout changes, requiring the Ruby
//! `ResourceBudget::LAYOUT` constants and native parity evidence to be updated.

#[cfg(target_pointer_width = "64")]
use emf_core::{Diagnostic, FontRecord, PolyTextEntry, RecordSpan, TriVertex};
#[cfg(target_pointer_width = "64")]
use std::mem::size_of;

#[test]
#[cfg(target_pointer_width = "64")]
fn native_allocation_layout_matches_ruby_resource_budget() {
    assert_eq!(size_of::<RecordSpan>(), 336, "RecordSpan layout changed");
    assert_eq!(size_of::<Diagnostic>(), 32, "Diagnostic layout changed");
    assert_eq!(size_of::<FontRecord>(), 392, "FontRecord layout changed");
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
