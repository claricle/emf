//! DIB ⇄ PNG bitmap transformer.
//!
//! This crate is the only place where the DIB and PNG models meet. The DIB
//! model supplies the pixel surface; the PNG model supplies the byte
//! emission; nothing here re-implements either format. Byte parity with the
//! Ruby ground truth (emfsvg's `DibDecoder` → `PngEncoder` chain) is the
//! contract, enforced by the captured-corpus tests.
//!
//! Scope note: BI_JPEG pass-through requires a JPEG model, which does not
//! exist yet; the transformer reports it as undecoded (`None`) and the
//! renderer keeps its `image/jpg` href path. BI_PNG pass-through goes
//! through the PNG model (strict decode + serialize), which round-trips the
//! embedded bytes identically.
use dib_model::{decode as dib_decode, Decoded};
use png_model::encode_rgba8;

/// Convert a DIB payload to PNG bytes, byte-exact against the Ruby
/// `DibDecoder.decode(dib, bits_offset: ...) → PngEncoder.encode` chain.
///
/// * `bits_offset` — the record's cb_bmi (padded-form pixel start).
/// * `mono_palette` — the 1-bpp brush text/bk-color override.
///
/// Returns `None` where the Ruby chain has no pixels (undecoded header or
/// compression, or a JPEG pass-through with no JPEG model yet).
pub fn dib_to_png(
    dib: &[u8],
    bits_offset: Option<usize>,
    mono_palette: Option<[[u8; 4]; 2]>,
) -> Option<Vec<u8>> {
    match dib_decode(dib, bits_offset, mono_palette)? {
        Decoded::Rgba(surface) => encode_rgba8(
            u32::try_from(surface.width).ok()?,
            u32::try_from(surface.height).ok()?,
            &surface.rgba,
        )
        .ok(),
        Decoded::Png(bytes) => {
            // The Ruby chain passes embedded PNG bytes through verbatim; the
            // model path decodes strictly and re-serializes, which is
            // byte-stable. If the payload is not a valid PNG, pass it
            // through raw, exactly as Ruby does.
            match png_model::Png::decode(&bytes) {
                Ok(model) => Some(model.serialize()),
                Err(_) => Some(bytes),
            }
        }
        Decoded::Jpeg(_) => None,
    }
}

/// Convert PNG bytes to a DIB payload (BI_RGB, 32-bpp, bottom-up BGRA),
/// byte-exact against the Ruby `PngDecoder` → `DibEncoder` chain.
pub fn png_to_dib(png: &[u8]) -> Option<Vec<u8>> {
    let model = png_model::Png::decode(png).ok()?;
    let surface = png_model::surface::surface(&model).ok()?;
    Some(dib_model::encode_rgba_as_bgra_rgb32(
        i64::from(surface.width).try_into().ok()?,
        i64::from(surface.height).try_into().ok()?,
        &surface.rgba,
    ))
}

#[cfg(test)]
mod tests {
    use super::{dib_to_png, png_to_dib};
    use dib_model::encode_rgba_as_bgra_rgb32;
    use png_model::{encode_rgba8, surface, Png};

    #[test]
    fn round_trip_dib_through_png_and_back() {
        let mut rgba = Vec::new();
        for y in 0..4u8 {
            for x in 0..5u8 {
                rgba.extend_from_slice(&[x * 40, y * 50, 90, 255]);
            }
        }
        let dib = encode_rgba_as_bgra_rgb32(5, 4, &rgba);
        let png = dib_to_png(&dib, None, None).expect("dib to png");
        let back = png_to_dib(&png).expect("png to dib");
        assert_eq!(back, dib);
    }

    #[test]
    fn undecoded_compressions_are_none() {
        // BI_RLE8 (compression 1): the Ruby chain returns nil.
        let mut dib = vec![0u8; 40];
        let w = 2u32.to_le_bytes();
        dib[16..20].copy_from_slice(&w); // compression = 1
        assert_eq!(dib_to_png(&dib, None, None), None);
    }

    #[test]
    fn png_pass_through_reaches_the_png_model() {
        let png =
            encode_rgba8(2, 2, &[1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4]).expect("encode");
        // A BI_PNG DIB whose payload after the header is the PNG bytes.
        let mut dib = vec![0u8; 40];
        dib[0..4].copy_from_slice(&(40u32).to_le_bytes());
        dib[4..8].copy_from_slice(&2i32.to_le_bytes());
        dib[8..12].copy_from_slice(&2i32.to_le_bytes());
        dib[16..20].copy_from_slice(&5u32.to_le_bytes()); // BI_PNG
        dib.extend_from_slice(&png);
        assert_eq!(dib_to_png(&dib, None, None).expect("pass through"), png);
    }

    #[test]
    fn surface_matches_through_both_models() {
        let rgba = [
            10u8, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160,
        ];
        let png = encode_rgba8(2, 2, &rgba).expect("encode");
        let model = Png::decode(&png).expect("decode");
        let decoded = surface::surface(&model).expect("surface");
        assert_eq!(decoded.rgba, rgba);
    }
}
