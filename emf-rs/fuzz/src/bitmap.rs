//! Real fuzz entries for the bitmap parsers, shared with the stable corpus
//! driver: DIB pixel decode plus structural parse/serialize, and PNG strict
//! decode plus pixel surface and re-encode.
use dib_model;
use png_model;

/// Input cap for bitmap fuzzing; surfaces are sized from header fields, so
/// keep the pixel budget bounded.
pub const MAX_BITMAP_INPUT: usize = 1024 * 1024;

/// Pixel-surface budget for fuzzing: header-declared dimensions beyond this
/// are allocation-hostile and add no parser coverage.
const MAX_PIXEL_BYTES: usize = 64 * 1024 * 1024;

fn within_pixel_budget(data: &[u8]) -> bool {
    if data.len() < 40 {
        return true;
    }
    let header = dib_model::BitmapInfoHeader::parse(data);
    i64::from(header.width.unsigned_abs()) * i64::from(header.height.unsigned_abs()) * 4
        <= MAX_PIXEL_BYTES as i64
}

pub fn dib(data: &[u8]) {
    let _ = dib_model::decode(data, None, None);
    let _ = dib_model::decode(data, Some(data.len() / 2), None);
    if let Ok(image) = dib_model::DibImage::parse(data) {
        let bytes = dib_model::serialize_image(&image);
        let reparsed = dib_model::DibImage::parse(&bytes).expect("serialized DIB reparses");
        assert_eq!(reparsed, image);
    }
    let _ = dib_model::decode_rle8(data, None);
    let _ = dib_model::decode_rle4(data, None);
    let _ = dib_model::decode_bitfields(data, None);
    if !within_pixel_budget(data) {
        return;
    }
    let _ = dib_model::decode(data, None, None);
    let _ = dib_model::decode(data, Some(data.len() / 2), None);
}

pub fn png(data: &[u8]) {
    if data.len() > MAX_BITMAP_INPUT {
        return;
    }
    if let Ok(model) = png_model::Png::decode(data) {
        assert_eq!(model.serialize(), data);
        if let Ok(surface) = png_model::surface::surface(&model) {
            if surface.width <= 4096 && surface.height <= 4096 {
                let encoded = png_model::encode_rgba8(surface.width, surface.height, &surface.rgba);
                if let Ok(bytes) = encoded {
                    let reparsed = png_model::Png::decode(&bytes).expect("encoded PNG reparses");
                    let round = png_model::surface::surface(&reparsed).expect("encoded decodes");
                    assert_eq!(round.rgba, surface.rgba);
                }
            }
        }
    }
}
