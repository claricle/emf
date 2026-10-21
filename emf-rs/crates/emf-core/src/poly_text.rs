//! Owned PolyTextOut entries and COLORADJUSTMENT wire fields.
use crate::error::{ParseFailure, SerializeFailure};
use crate::limits::Budget;
use crate::model::{Float32, Point, RecordData, Rect};
use crate::reader::Reader;

/// All twelve COLORADJUSTMENT words, including unknown flag/illuminant values.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ColorAdjustment {
    pub adjustment_size: u16,
    pub values: u16,
    pub illuminant_index: u16,
    pub red_gamma: u16,
    pub green_gamma: u16,
    pub blue_gamma: u16,
    pub reference_black: u16,
    pub reference_white: u16,
    pub contrast: i16,
    pub brightness: i16,
    pub colorfulness: i16,
    pub red_green_tint: i16,
}

/// One EMRTEXT descriptor and its detached buffers. Text units and spacing
/// values retain their wire bits; W does not require well-formed UTF-16.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PolyTextEntry<T> {
    pub reference: Point,
    pub options: u32,
    /// Absent exactly when ETO_NO_RECT is set.
    pub rectangle: Option<Rect>,
    pub text: Vec<T>,
    /// ETO_PDY uses two values per text unit; other entries use one.
    pub dx: Option<Vec<u32>>,
    pub string_present: bool,
    pub string_padding: Vec<u8>,
    pub dx_padding: Vec<u8>,
    pub dx_first: bool,
}

/// PolyTextOutA/W. Encoding derives entry counts and buffer offsets. On edits,
/// buffers are rebuilt in entry order, retaining each buffer's preceding unused
/// bytes and adding alignment only where needed. Unchanged records use source
/// bytes, preserving arbitrary original buffer ordering. Malformed spans retain
/// their complete source through Raw recovery.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PolyTextOut<T> {
    pub bounds: Rect,
    pub graphics_mode: u32,
    pub ex_scale: Float32,
    pub ey_scale: Float32,
    pub entries: Vec<PolyTextEntry<T>>,
}

impl<T> PolyTextOut<T> {
    pub(crate) fn valid(&self) -> bool {
        self.entries.iter().all(|entry| {
            entry.rectangle.is_none() == (entry.options & 0x100 != 0)
                && entry.dx.as_ref().map_or(true, |dx| {
                    entry.text.len().checked_mul(if entry.options & 0x2000 != 0 { 2 } else { 1 }) == Some(dx.len())
                })
                && (entry.dx.is_some() || (entry.dx_padding.is_empty() && !entry.dx_first))
                && (entry.string_present || entry.string_padding.is_empty())
        })
    }

    fn table_end(&self) -> Option<usize> {
        u32::try_from(self.entries.len()).ok()?;
        self.entries.iter().try_fold(40usize, |end, entry| {
            u32::try_from(entry.text.len()).ok()?;
            end.checked_add(if entry.rectangle.is_some() { 40 } else { 24 })
        })
    }

    // Visit all present buffers in encoding order without allocating an offset table.
    fn buffers(&self, mut visit: impl FnMut(usize, bool, usize)) -> Option<usize> {
        let mut end = self.table_end()?;
        for (index, entry) in self.entries.iter().enumerate() {
            for is_dx in [entry.dx_first, !entry.dx_first] {
                let (present, padding, count, width) = if is_dx {
                    (entry.dx.is_some(), entry.dx_padding.len(), entry.dx.as_ref().map_or(0, Vec::len), 4)
                } else {
                    (entry.string_present || !entry.text.is_empty(), entry.string_padding.len(), entry.text.len(), std::mem::size_of::<T>())
                };
                if present {
                    end = end.checked_add(padding)?;
                    end = end.checked_add((width - end % width) % width)?;
                    u32::try_from(end).ok()?;
                    visit(index, is_dx, end);
                    end = end.checked_add(count.checked_mul(width)?)?;
                }
            }
        }
        u32::try_from(end).ok()?;
        Some(end)
    }

    pub(crate) fn encoded_len(&self) -> Option<usize> { self.buffers(|_, _, _| {}) }

    pub(crate) fn work_len(&self) -> Option<usize> {
        self.entries.iter().try_fold(self.entries.len(), |work, entry| {
            work.checked_add(entry.text.len())?
                .checked_add(entry.dx.as_ref().map_or(0, Vec::len))?
                .checked_add(entry.string_padding.len().div_ceil(16))?
                .checked_add(entry.dx_padding.len().div_ceil(16))
        })
    }
}

pub(crate) trait Unit: Sized {
    fn read(reader: &mut Reader<'_>) -> Result<Self, ParseFailure>;
    fn write(&self, out: &mut Vec<u8>);
    fn record(text: PolyTextOut<Self>) -> RecordData;
}
impl Unit for u8 {
    fn read(reader: &mut Reader<'_>) -> Result<Self, ParseFailure> { Ok(reader.take(1)?[0]) }
    fn write(&self, out: &mut Vec<u8>) { out.push(*self); }
    fn record(text: PolyTextOut<Self>) -> RecordData { RecordData::PolyTextOutA(text) }
}
impl Unit for u16 {
    fn read(reader: &mut Reader<'_>) -> Result<Self, ParseFailure> { reader.u16() }
    fn write(&self, out: &mut Vec<u8>) { out.extend_from_slice(&self.to_le_bytes()); }
    fn record(text: PolyTextOut<Self>) -> RecordData { RecordData::PolyTextOutW(text) }
}
fn rect(r: &mut Reader<'_>) -> Result<Rect, ParseFailure> {
    Ok(Rect { left: r.i32()?, top: r.i32()?, right: r.i32()?, bottom: r.i32()? })
}

pub(crate) fn decode<T: Unit>(payload: &[u8], budget: &mut Budget<'_>) -> Result<(RecordData, usize), ParseFailure> {
    let raw = || Ok((RecordData::Raw, 0));
    if payload.len() < 32 { return raw(); }
    let mut r = Reader::new(payload);
    let bounds = rect(&mut r)?;
    let graphics_mode = r.u32()?;
    let ex_scale = Float32::from_bits(r.u32()?);
    let ey_scale = Float32::from_bits(r.u32()?);
    let count = r.u32()? as usize;
    if count > r.remaining() / 24 { return raw(); }
    budget.charge_work(count as u64)?;
    // First pass validates the complete variable-width table without allocation.
    let mut table = Reader::new(&payload[32..]);
    for _ in 0..count {
        if table.remaining() < 24 { return raw(); }
        table.skip(16)?;
        let options = table.u32()?;
        let rest = if options & 0x100 == 0 { 20 } else { 4 };
        if table.remaining() < rest { return raw(); }
        table.skip(rest)?;
    }
    let fixed = 32 + table.position();
    let mut entries = budget.vector::<PolyTextEntry<T>>(count)?;
    // Sorted spans assign every unused byte to one buffer and reject overlaps.
    let Some(span_count) = count.checked_mul(2) else { return raw(); };
    let mut spans = budget.vector::<(usize, usize, usize, bool)>(span_count)?;
    for index in 0..count {
        let reference = Point { x: r.i32()?, y: r.i32()? };
        let chars = r.u32()? as usize;
        let string = r.u32()? as usize;
        let options = r.u32()?;
        let rectangle = if options & 0x100 == 0 { Some(rect(&mut r)?) } else { None };
        let dx_offset = r.u32()? as usize;
        let width = std::mem::size_of::<T>();
        let Some(string_len) = chars.checked_mul(width) else { return raw(); };
        let Some(dx_count) = chars.checked_mul(if options & 0x2000 != 0 { 2 } else { 1 }) else { return raw(); };
        let Some(dx_len) = dx_count.checked_mul(4) else { return raw(); };
        let span = |offset: usize, len: usize, alignment: usize| {
            let start = offset.checked_sub(8)?;
            let end = start.checked_add(len)?;
            (start >= fixed && offset % alignment == 0 && end <= payload.len()).then_some((start, end))
        };
        let string_range = if string == 0 && chars == 0 { None } else {
            let Some(range) = span(string, string_len, width) else { return raw(); };
            spans.push((range.0, range.1, index, false));
            Some(range)
        };
        let dx_range = if dx_offset == 0 { None } else {
            let Some(range) = span(dx_offset, dx_len, 4) else { return raw(); };
            spans.push((range.0, range.1, index, true));
            Some(range)
        };
        budget.charge_work(chars as u64)?;
        let mut text = budget.vector(chars)?;
        if let Some((start, end)) = string_range {
            let mut buffer = Reader::new(&payload[start..end]);
            for _ in 0..chars { text.push(T::read(&mut buffer)?); }
        }
        let dx = if let Some((start, end)) = dx_range {
            budget.charge_work(dx_count as u64)?;
            let mut values = budget.vector(dx_count)?;
            let mut buffer = Reader::new(&payload[start..end]);
            for _ in 0..dx_count { values.push(buffer.u32()?); }
            Some(values)
        } else { None };
        entries.push(PolyTextEntry { reference, options, rectangle, text, dx,
            string_present: string_range.is_some(), string_padding: Vec::new(), dx_padding: Vec::new(),
            dx_first: match (string_range, dx_range) { (Some(a), Some(b)) => b.0 < a.0, (None, Some(_)) => true, _ => false } });
    }
    // Bound sorting work as well as the temporary span vector.
    budget.charge_work((spans.len() as u64).saturating_mul(usize::BITS as u64 - spans.len().leading_zeros() as u64))?;
    spans.sort_unstable();
    let mut end = fixed;
    for (start, stop, index, is_dx) in spans {
        if start < end { return raw(); }
        let unused = &payload[end..start];
        budget.charge_work((unused.len() as u64).div_ceil(16))?;
        let mut padding = budget.vector(unused.len())?;
        padding.extend_from_slice(unused);
        if is_dx { entries[index].dx_padding = padding; } else { entries[index].string_padding = padding; }
        end = stop;
    }
    Ok((T::record(PolyTextOut { bounds, graphics_mode, ex_scale, ey_scale, entries }), end))
}

fn word(out: &mut Vec<u8>, value: u32) { out.extend_from_slice(&value.to_le_bytes()); }
fn write_rect(out: &mut Vec<u8>, r: Rect) { for v in [r.left, r.top, r.right, r.bottom] { word(out, v as u32); } }
pub(crate) fn encode<T: Unit>(out: &mut Vec<u8>, start: usize, text: &PolyTextOut<T>) -> Result<(), SerializeFailure> {
    let end = text.encoded_len().ok_or(SerializeFailure::SizeOverflow)?;
    write_rect(out, text.bounds);
    word(out, text.graphics_mode);
    word(out, text.ex_scale.to_bits());
    word(out, text.ey_scale.to_bits());
    word(out, text.entries.len() as u32);
    for entry in &text.entries {
        word(out, entry.reference.x as u32);
        word(out, entry.reference.y as u32);
        word(out, entry.text.len() as u32);
        word(out, 0);
        word(out, entry.options);
        if let Some(r) = entry.rectangle { write_rect(out, r); }
        word(out, 0);
    }
    let mut descriptor = start + 40;
    let mut last_index = 0;
    text.buffers(|index, is_dx, offset| {
        while last_index < index {
            descriptor += if text.entries[last_index].rectangle.is_some() { 40 } else { 24 };
            last_index += 1;
        }
        let entry = &text.entries[index];
        let field = descriptor + if is_dx { if entry.rectangle.is_some() { 36 } else { 20 } } else { 12 };
        out[field..field + 4].copy_from_slice(&(offset as u32).to_le_bytes());
        out.extend_from_slice(if is_dx { &entry.dx_padding } else { &entry.string_padding });
        out.resize(start + offset, 0);
        if is_dx { for value in entry.dx.as_ref().unwrap() { word(out, *value); } }
        else { for unit in &entry.text { unit.write(out); } }
    }).ok_or(SerializeFailure::SizeOverflow)?;
    debug_assert_eq!(out.len(), start + end);
    Ok(())
}

pub(crate) fn decode_color(payload: &[u8]) -> Result<(RecordData, usize), ParseFailure> {
    if payload.len() < 24 { return Ok((RecordData::Raw, 0)); }
    let mut r = Reader::new(payload);
    Ok((RecordData::SetColorAdjustment(ColorAdjustment {
        adjustment_size: r.u16()?, values: r.u16()?, illuminant_index: r.u16()?,
        red_gamma: r.u16()?, green_gamma: r.u16()?, blue_gamma: r.u16()?,
        reference_black: r.u16()?, reference_white: r.u16()?,
        contrast: r.u16()? as i16, brightness: r.u16()? as i16,
        colorfulness: r.u16()? as i16, red_green_tint: r.u16()? as i16,
    }), 24))
}
pub(crate) fn encode_color(out: &mut Vec<u8>, c: &ColorAdjustment) {
    for v in [c.adjustment_size, c.values, c.illuminant_index, c.red_gamma, c.green_gamma,
        c.blue_gamma, c.reference_black, c.reference_white, c.contrast as u16,
        c.brightness as u16, c.colorfulness as u16, c.red_green_tint as u16] {
        out.extend_from_slice(&v.to_le_bytes());
    }
}
