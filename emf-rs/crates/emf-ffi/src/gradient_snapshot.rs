use super::{point, rect, u32_field, u64_field, wire_len, Error};
use emf_core::{GradientFill, GradientMesh};

pub(super) fn len(value: &GradientFill) -> Result<usize, Error> {
    let count = match &value.mesh {
        GradientMesh::Rectangles { rectangles, .. } => rectangles.len(),
        GradientMesh::Triangles(triangles) => triangles.len(),
    };
    value
        .vertices
        .len()
        .checked_mul(16)
        .and_then(|n| count.checked_mul(12).and_then(|m| n.checked_add(m)))
        .and_then(|n| n.checked_add(36))
        .ok_or(Error::SizeOverflow)
}

pub(super) fn encode(out: &mut Vec<u8>, value: &GradientFill) -> Result<(), Error> {
    rect(out, value.bounds);
    let (mode, count) = match &value.mesh {
        GradientMesh::Rectangles {
            vertical,
            rectangles,
            ..
        } => (u32::from(*vertical), rectangles.len()),
        GradientMesh::Triangles(triangles) => (2, triangles.len()),
    };
    u32_field(out, mode);
    u64_field(out, wire_len(value.vertices.len())?);
    u64_field(out, wire_len(count)?);
    for vertex in &value.vertices {
        point(out, vertex.position);
        for channel in [vertex.red, vertex.green, vertex.blue, vertex.alpha] {
            out.extend_from_slice(&channel.to_le_bytes());
        }
    }
    match &value.mesh {
        GradientMesh::Rectangles {
            rectangles,
            padding,
            ..
        } => {
            for indices in rectangles {
                for index in indices {
                    u32_field(out, *index);
                }
            }
            for word in padding {
                u32_field(out, *word);
            }
        }
        GradientMesh::Triangles(triangles) => {
            for indices in triangles {
                for index in indices {
                    u32_field(out, *index);
                }
            }
        }
    }
    Ok(())
}
