//! Families 104/105: bounds[4*i32], mode:u32, scales[2*u32 bits], count:u64;
//! each entry: reference[2*i32], options:u32, has_rect:u32, rect[4*i32],
//! text_count:u64, has_dx:u32, dx_count:u64, then text units and dx:u32[].
//! Family 106: twelve little-endian COLORADJUSTMENT words (last four signed).
//! Gaps/suffix remain in raw source; Ruby validates semantic values against it.
use super::{add_len, point, rect, u32_field, u64_field, wire_len, Error};
use emf_core::{ColorAdjustment, PolyTextOut, Rect};
pub(super) fn len<T>(text: &PolyTextOut<T>) -> Result<usize, Error> {
    let mut len = 36;
    for entry in &text.entries {
        add_len(&mut len, 52)?;
        add_len(&mut len, entry.text.len().checked_mul(std::mem::size_of::<T>()).ok_or(Error::SizeOverflow)?)?;
        add_len(&mut len, entry.dx.as_ref().map_or(0, Vec::len).checked_mul(4).ok_or(Error::SizeOverflow)?)?;
    }
    Ok(len)
}
pub(super) fn encode<T>(out: &mut Vec<u8>, text: &PolyTextOut<T>, unit: fn(&mut Vec<u8>, &T)) -> Result<(), Error> {
    rect(out, text.bounds); u32_field(out, text.graphics_mode);
    u32_field(out, text.ex_scale.to_bits()); u32_field(out, text.ey_scale.to_bits());
    u64_field(out, wire_len(text.entries.len())?);
    for entry in &text.entries {
        point(out, entry.reference); u32_field(out, entry.options);
        u32_field(out, u32::from(entry.rectangle.is_some()));
        rect(out, entry.rectangle.unwrap_or(Rect {left:0,top:0,right:0,bottom:0}));
        u64_field(out, wire_len(entry.text.len())?);
        u32_field(out, u32::from(entry.dx.is_some()));
        u64_field(out, wire_len(entry.dx.as_ref().map_or(0, Vec::len))?);
        for value in &entry.text { unit(out, value); }
        if let Some(dx) = &entry.dx { for value in dx { u32_field(out, *value); } }
    }
    Ok(())
}
pub(super) fn color(out: &mut Vec<u8>, c: &ColorAdjustment) {
    for v in [c.adjustment_size,c.values,c.illuminant_index,c.red_gamma,c.green_gamma,c.blue_gamma,c.reference_black,c.reference_white,c.contrast as u16,c.brightness as u16,c.colorfulness as u16,c.red_green_tint as u16] { out.extend_from_slice(&v.to_le_bytes()); }
}
