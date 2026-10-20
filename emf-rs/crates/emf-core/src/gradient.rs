//! EMR_GRADIENTFILL vertices and rectangle/triangle meshes (MS-EMF 2.3.5.12).
use crate::limits::{try_vec_with_capacity, Budget};
use crate::{ParseFailure, Point, Reader, RecordData, Rect};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct TriVertex {
    pub position: Point,
    pub red: u16,
    pub green: u16,
    pub blue: u16,
    /// Retained even though GradientFill ignores alpha.
    pub alpha: u16,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GradientMesh {
    Rectangles {
        vertical: bool,
        rectangles: Vec<[u32; 2]>,
        /// One ignored wire word per rectangle, after the complete index array.
        padding: Vec<u32>,
    },
    Triangles(Vec<[u32; 3]>),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct GradientFill {
    pub bounds: Rect,
    pub vertices: Vec<TriVertex>,
    pub mesh: GradientMesh,
}
impl GradientFill {
    pub(crate) fn count(&self) -> usize {
        match &self.mesh {
            GradientMesh::Rectangles { rectangles, .. } => rectangles.len(),
            GradientMesh::Triangles(triangles) => triangles.len(),
        }
    }
    pub(crate) fn payload_len(&self) -> Option<usize> {
        u32::try_from(self.vertices.len()).ok()?;
        u32::try_from(self.count()).ok()?;
        28usize
            .checked_add(self.vertices.len().checked_mul(16)?)?
            .checked_add(self.count().checked_mul(12)?)
    }
    pub(crate) fn valid(&self) -> bool {
        let valid = |i: &u32| (*i as usize) < self.vertices.len();
        match &self.mesh {
            GradientMesh::Rectangles {
                rectangles,
                padding,
                ..
            } => rectangles.len() == padding.len() && rectangles.iter().flatten().all(valid),
            GradientMesh::Triangles(triangles) => triangles.iter().flatten().all(valid),
        }
    }
    pub(crate) fn append(&self, out: &mut Vec<u8>) {
        let word = |out: &mut Vec<u8>, value: u32| out.extend_from_slice(&value.to_le_bytes());
        for v in [
            self.bounds.left,
            self.bounds.top,
            self.bounds.right,
            self.bounds.bottom,
        ] {
            word(out, v as u32);
        }
        word(out, self.vertices.len() as u32);
        word(out, self.count() as u32);
        word(
            out,
            match &self.mesh {
                GradientMesh::Rectangles { vertical, .. } => u32::from(*vertical),
                GradientMesh::Triangles(_) => 2,
            },
        );
        for v in &self.vertices {
            word(out, v.position.x as u32);
            word(out, v.position.y as u32);
            for c in [v.red, v.green, v.blue, v.alpha] {
                out.extend_from_slice(&c.to_le_bytes());
            }
        }
        match &self.mesh {
            GradientMesh::Rectangles {
                rectangles,
                padding,
                ..
            } => {
                for indices in rectangles {
                    for i in indices {
                        word(out, *i);
                    }
                }
                for p in padding {
                    word(out, *p);
                }
            }
            GradientMesh::Triangles(triangles) => {
                for indices in triangles {
                    for i in indices {
                        word(out, *i);
                    }
                }
            }
        }
    }
}
pub(crate) fn decode(
    payload: &[u8],
    budget: &mut Budget<'_>,
) -> Result<(RecordData, usize), ParseFailure> {
    let raw = || Ok((RecordData::Raw, 0));
    if payload.len() < 28 {
        return raw();
    }
    let mut r = Reader::new(payload);
    let bounds = Rect {
        left: r.i32()?,
        top: r.i32()?,
        right: r.i32()?,
        bottom: r.i32()?,
    };
    let nv = r.u32()? as usize;
    let nm = r.u32()? as usize;
    let mode = r.u32()?;
    let Some(len) = nv
        .checked_mul(16)
        .and_then(|n| nm.checked_mul(12)?.checked_add(n)?.checked_add(28))
    else {
        return raw();
    };
    if mode > 2 || len > payload.len() {
        return raw();
    }
    // Reserve work before scanning indexes or allocating the model.
    budget.charge_work((nv as u64) + (nm as u64))?;
    let index_start = 28 + nv * 16;
    let index_count = nm * if mode == 2 { 3 } else { 2 };
    let mut indices = Reader::new(&payload[index_start..index_start + index_count * 4]);
    for _ in 0..index_count {
        if indices.u32()? as usize >= nv {
            return raw();
        }
    }
    budget.charge_alloc(
        nv.checked_mul(std::mem::size_of::<TriVertex>())
            .and_then(|n| nm.checked_mul(12)?.checked_add(n))
            .ok_or(ParseFailure::ArithmeticOverflow { offset: 0 })?,
    )?;
    let mut vertices = try_vec_with_capacity(nv)?;
    for _ in 0..nv {
        vertices.push(TriVertex {
            position: Point {
                x: r.i32()?,
                y: r.i32()?,
            },
            red: r.u16()?,
            green: r.u16()?,
            blue: r.u16()?,
            alpha: r.u16()?,
        });
    }
    let mesh = if mode == 2 {
        let mut triangles = try_vec_with_capacity(nm)?;
        for _ in 0..nm {
            triangles.push([r.u32()?, r.u32()?, r.u32()?]);
        }
        GradientMesh::Triangles(triangles)
    } else {
        let mut rectangles = try_vec_with_capacity(nm)?;
        let mut padding = try_vec_with_capacity(nm)?;
        for _ in 0..nm {
            rectangles.push([r.u32()?, r.u32()?]);
        }
        for _ in 0..nm {
            padding.push(r.u32()?);
        }
        GradientMesh::Rectangles {
            vertical: mode == 1,
            rectangles,
            padding,
        }
    };
    Ok((
        RecordData::GradientFill(GradientFill {
            bounds,
            vertices,
            mesh,
        }),
        len,
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{LimitKind, ParseLimits};

    #[test]
    fn index_validation_cannot_bypass_the_work_limit() {
        let mut payload = vec![0; 28 + 16 + 12];
        payload[16..20].copy_from_slice(&1u32.to_le_bytes());
        payload[20..24].copy_from_slice(&1u32.to_le_bytes());
        payload[24..28].copy_from_slice(&2u32.to_le_bytes());
        // Invalid first index would recover as Raw if validation ran first.
        payload[44..48].copy_from_slice(&1u32.to_le_bytes());
        let mut limits = ParseLimits {
            max_work_units: 1,
            ..ParseLimits::default()
        };
        assert!(matches!(
            decode(&payload, &mut Budget::new(&limits)),
            Err(ParseFailure::LimitExceeded {
                kind: LimitKind::WorkUnits,
                requested: 2,
                ..
            })
        ));
        limits.max_work_units = 2;
        assert_eq!(
            decode(&payload, &mut Budget::new(&limits)).unwrap(),
            (RecordData::Raw, 0)
        );
    }
}
