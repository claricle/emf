//! EmfPlusRegion and its preorder binary nodes (2.2.1.8, 2.2.2.40–42).
use super::{path, words, Path, Reader};
use crate::{emf_plus::Error, SerializeFailure};

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RegionNode {
    /// Operation 1..=5; the following preorder nodes contain both children.
    Binary {
        operation: u32,
    },
    /// Raw IEEE coordinate bits.
    Rectangle([u32; 4]),
    Path(Path),
    Empty,
    Infinite,
}

/// Flat preorder storage avoids recursive parsing, writing and destruction.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Region {
    pub version: u32,
    pub nodes: Vec<RegionNode>,
}
impl Region {
    pub(super) fn layout(&self) -> Result<(usize, u64), SerializeFailure> {
        let invalid = || SerializeFailure::Inconsistent { offset: 0 };
        if self.nodes.is_empty() || self.nodes.len() - 1 > u32::MAX as usize {
            return Err(invalid());
        }
        let mut pending = 1usize;
        let mut size = 8usize;
        let mut work = self.nodes.len() as u64;
        for node in &self.nodes {
            if pending == 0 {
                return Err(invalid());
            }
            pending -= 1;
            let payload = match node {
                RegionNode::Binary { operation: 1..=5 } => {
                    pending = pending
                        .checked_add(2)
                        .ok_or(SerializeFailure::SizeOverflow)?;
                    0
                }
                RegionNode::Binary { .. } => return Err(invalid()),
                RegionNode::Rectangle(_) => 16,
                RegionNode::Path(p) => {
                    let (len, units) = p.layout()?;
                    if len > i32::MAX as usize {
                        return Err(SerializeFailure::SizeOverflow);
                    }
                    work = work
                        .checked_add(units)
                        .ok_or(SerializeFailure::SizeOverflow)?;
                    len.checked_add(4).ok_or(SerializeFailure::SizeOverflow)?
                }
                RegionNode::Empty | RegionNode::Infinite => 0,
            };
            size = size
                .checked_add(4)
                .and_then(|n| n.checked_add(payload))
                .ok_or(SerializeFailure::SizeOverflow)?;
        }
        if pending != 0 {
            return Err(invalid());
        }
        Ok((size, work))
    }
    pub(super) fn write(&self, out: &mut Vec<u8>) {
        words(out, &[self.version, (self.nodes.len() - 1) as u32]);
        for node in &self.nodes {
            match node {
                RegionNode::Binary { operation } => words(out, &[*operation]),
                RegionNode::Rectangle(rect) => {
                    words(out, &[0x10000000]);
                    words(out, rect);
                }
                RegionNode::Path(p) => {
                    words(out, &[0x10000001]);
                    let start = out.len();
                    words(out, &[0]);
                    p.write(out);
                    let len = (out.len() - start - 4) as u32;
                    out[start..start + 4].copy_from_slice(&len.to_le_bytes());
                }
                RegionNode::Empty => words(out, &[0x10000002]),
                RegionNode::Infinite => words(out, &[0x10000003]),
            }
        }
    }
}

pub(super) fn read(r: &mut Reader<'_, '_, '_>) -> Result<Option<Region>, Error> {
    let version = r.word()?;
    let count = (r.word()? as usize)
        .checked_add(1)
        .ok_or_else(|| r.error())?;
    r.require_count(count, 4)?;
    let start = r.pos;
    let mut pending = 1usize;
    // Validate known node framing/tree shape before reserving a counted vector.
    // Unknown node payloads lack a size: keep the entire definition opaque.
    for _ in 0..count {
        if pending == 0 {
            return Err(r.error());
        }
        pending -= 1;
        match r.word()? {
            1..=5 => pending = pending.checked_add(2).ok_or_else(|| r.error())?,
            0x10000000 => {
                r.take(16)?;
            }
            0x10000001 => {
                let len = r.word()?;
                if len > i32::MAX as u32 {
                    return Err(r.error());
                }
                r.take(len as usize)?;
            }
            0x10000002 | 0x10000003 => (),
            _ => return Ok(None),
        }
        r.budget.charge_work(1)?;
    }
    if pending != 0 || r.remaining() != 0 {
        return Err(r.error());
    }
    r.pos = start;
    let mut nodes = r.vector(count)?;
    for _ in 0..count {
        nodes.push(match r.word()? {
            operation @ 1..=5 => RegionNode::Binary { operation },
            0x10000000 => RegionNode::Rectangle(r.words()?),
            0x10000001 => {
                let len = r.word()? as usize;
                let bytes = r.bytes;
                let start = r.pos;
                r.take(len)?;
                let mut nested = Reader {
                    bytes: &bytes[start..start + len],
                    pos: 0,
                    index: r.index,
                    budget: r.budget,
                };
                RegionNode::Path(path::read(&mut nested)?)
            }
            0x10000002 => RegionNode::Empty,
            0x10000003 => RegionNode::Infinite,
            _ => unreachable!(), // The framing pass checked the same immutable bytes.
        });
    }
    Ok(Some(Region { version, nodes }))
}
