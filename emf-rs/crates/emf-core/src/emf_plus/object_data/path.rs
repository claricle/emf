//! EmfPlusPath (2.2.1.6), including PointTypeRLE (2.2.2.32).
use super::{words, Reader};
use crate::{
    emf_plus::{Error, PointData, RelativeCoordinate},
    SerializeFailure,
};

/// One encoded run; the header retains the Bezier bit, fixed bit and six-bit
/// count exactly. Runs stay compressed rather than allocating expanded types.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct PathPointRun {
    pub header: u8,
    pub point_type: u8,
}
impl PathPointRun {
    pub fn count(self) -> u8 {
        self.header & 0x3f
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum PathPointTypes {
    Plain(Vec<u8>),
    RunLength(Vec<PathPointRun>),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Path {
    pub version: u32,
    /// R=0x0800, C=0x4000; all other bits remain unmodified.
    pub flags: u32,
    pub points: PointData,
    pub point_types: PathPointTypes,
    pub alignment_padding: Vec<u8>,
}
impl Path {
    pub(super) fn layout(&self) -> Result<(usize, u64), SerializeFailure> {
        let invalid = || SerializeFailure::Inconsistent { offset: 0 };
        let count = self.points.count();
        if count > u32::MAX as usize || !self.points.valid(self.flags as u16) {
            return Err(invalid());
        }
        let (types_len, types_work) = match &self.point_types {
            PathPointTypes::Plain(v) if self.flags & 0x0800 == 0 && v.len() == count => {
                (v.len(), v.len())
            }
            PathPointTypes::RunLength(v) if self.flags & 0x0800 != 0 => {
                let mut total = 0usize;
                for run in v {
                    if run.count() == 0 {
                        return Err(invalid());
                    }
                    total = total
                        .checked_add(run.count() as usize)
                        .ok_or(SerializeFailure::SizeOverflow)?;
                }
                if total != count {
                    return Err(invalid());
                }
                (
                    v.len()
                        .checked_mul(2)
                        .ok_or(SerializeFailure::SizeOverflow)?,
                    v.len(),
                )
            }
            _ => return Err(invalid()),
        };
        let size = 12usize
            .checked_add(self.points.len())
            .and_then(|n| n.checked_add(types_len))
            .ok_or(SerializeFailure::SizeOverflow)?;
        if self.alignment_padding.len() != (4 - size % 4) % 4 {
            return Err(invalid());
        }
        Ok((
            size.checked_add(self.alignment_padding.len())
                .ok_or(SerializeFailure::SizeOverflow)?,
            (count as u64)
                .checked_add(types_work as u64)
                .ok_or(SerializeFailure::SizeOverflow)?,
        ))
    }
    pub(super) fn write(&self, out: &mut Vec<u8>) {
        words(out, &[self.version, self.points.count() as u32, self.flags]);
        self.points.write(out);
        match &self.point_types {
            PathPointTypes::Plain(v) => out.extend_from_slice(v),
            PathPointTypes::RunLength(v) => {
                for run in v {
                    out.extend_from_slice(&[run.header, run.point_type]);
                }
            }
        }
        out.extend_from_slice(&self.alignment_padding);
    }
}

fn relative(r: &mut Reader<'_, '_, '_>) -> Result<RelativeCoordinate, Error> {
    let lead = r.take(1)?[0];
    Ok(if lead & 0x80 == 0 {
        RelativeCoordinate::Seven(((lead << 1) as i8) >> 1)
    } else {
        let raw = ((lead as u16 & 0x7f) << 8) | r.take(1)?[0] as u16;
        RelativeCoordinate::Fifteen(((raw << 1) as i16) >> 1)
    })
}

pub(super) fn read(r: &mut Reader<'_, '_, '_>) -> Result<Path, Error> {
    let version = r.word()?;
    let count = r.word()? as usize;
    let flags = r.word()?;
    let relative_points = flags & 0x0800 != 0;
    let compressed = flags & 0x4000 != 0;
    // Validate the minimum coordinate bytes before any count-based allocation.
    r.require_count(
        count,
        if relative_points {
            2
        } else if compressed {
            4
        } else {
            8
        },
    )?;
    let points = if relative_points {
        let mut v = r.vector(count)?;
        for _ in 0..count {
            v.push([relative(r)?, relative(r)?]);
        }
        PointData::Relative(v)
    } else if compressed {
        let mut v = r.vector(count)?;
        for _ in 0..count {
            v.push([
                i16::from_le_bytes(r.take(2)?.try_into().unwrap()),
                i16::from_le_bytes(r.take(2)?.try_into().unwrap()),
            ]);
        }
        PointData::Integer(v)
    } else {
        let mut v = r.vector(count)?;
        for _ in 0..count {
            v.push([r.word()?, r.word()?]);
        }
        PointData::Float(v)
    };
    let point_types = if relative_points {
        // First validate the complete run sequence without expanding or allocating.
        let start = r.pos;
        let mut total = 0usize;
        let mut runs = 0usize;
        while total < count {
            let run = r.take(2)?;
            let n = (run[0] & 0x3f) as usize;
            if n == 0 || n > count - total {
                return Err(r.error());
            }
            total += n;
            runs += 1;
            r.budget.charge_work(1)?;
        }
        let mut v = r.vector(runs)?;
        for run in r.bytes[start..r.pos].chunks_exact(2) {
            v.push(PathPointRun {
                header: run[0],
                point_type: run[1],
            });
        }
        PathPointTypes::RunLength(v)
    } else {
        PathPointTypes::Plain(r.bytes(count)?)
    };
    if r.remaining() != (4 - r.pos % 4) % 4 {
        return Err(r.error());
    }
    let alignment_padding = r.rest()?;
    Ok(Path {
        version,
        flags,
        points,
        point_types,
        alignment_padding,
    })
}
