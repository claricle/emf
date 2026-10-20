//! Uncompressed terminal-server clipping (MS-EMFPLUS 2.3.8.1).
use super::Error;
use crate::limits::{try_vec_with_capacity, Budget};

/// Four signed wire values per rectangle. Values remain in wire order: this
/// view does not resolve delta coordinates or interpret clipping geometry.
/// Compressed (C-set) records remain opaque because the specification's fixed
/// four-byte size and variable one/two-byte encoding descriptions conflict.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TSClip {
    pub rectangles: Vec<[i16; 4]>,
}
impl TSClip {
    pub(crate) fn valid(&self, kind: u16, flags: u16) -> bool {
        kind == 0x403a && flags & 0x8000 == 0 && usize::from(flags) == self.rectangles.len()
    }
    pub(crate) fn len(&self) -> usize {
        self.rectangles.len().saturating_mul(8)
    }
    pub(crate) fn write(&self, out: &mut Vec<u8>) {
        for rectangle in &self.rectangles {
            for value in rectangle {
                out.extend(value.to_le_bytes());
            }
        }
    }
}
pub(crate) fn decode(
    bytes: &[u8],
    flags: u16,
    offset: usize,
    budget: &mut Budget<'_>,
) -> Result<TSClip, Error> {
    let count = usize::from(flags);
    if bytes.len() != count * 8 {
        return Err(Error::InvalidRecord {
            offset,
            reason: "invalid terminal-server clip count/layout",
        });
    }
    budget.charge_alloc(count * std::mem::size_of::<[i16; 4]>())?;
    budget.charge_work(count as u64)?;
    let mut rectangles = try_vec_with_capacity(count)?;
    for rectangle in bytes.chunks_exact(8) {
        rectangles.push(std::array::from_fn(|i| {
            i16::from_le_bytes(rectangle[i * 2..i * 2 + 2].try_into().unwrap())
        }));
    }
    Ok(TSClip { rectangles })
}
