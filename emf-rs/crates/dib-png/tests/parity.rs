//! Corpus parity: replay the captured Ruby ground truth.
//!
//! Fixtures were produced by `scripts/capture_dib_png_fixtures.rb`, which
//! runs emfsvg's real renderer over the parity corpus with hooks on
//! `Emfsvg::DibDecoder` and `Emfsvg::PngEncoder` and writes every
//! decode call (input bytes, bits_offset, mono_palette) together with the
//! PNG bytes the Ruby chain emitted. Each fixture directory holds:
//!
//! * `dib.bin` — the exact bytes passed to `DibDecoder.decode`
//! * `meta.json` — `bits_offset`, `mono_palette`, decoded dims/color_type,
//!   and the SHA-256 of the Ruby decoder's RGBA surface for the emitted PNG
//! * `expected.png` — the Ruby `PngEncoder.encode` output (rgba case)
//! * `passthrough.bin` — the raw embedded PNG bytes (BI_PNG case)
//!
//! The transformer must reproduce all of them byte for byte.
use dib_png::{dib_to_png, png_to_dib};
use std::fs;
use std::path::{Path, PathBuf};

fn fixture_dirs() -> Vec<PathBuf> {
    let mut out: Vec<PathBuf> = fs::read_dir(fixture_root())
        .expect("fixture root present")
        .map(|entry| entry.expect("dir entry").path())
        .filter(|path| path.join("meta.json").exists())
        .collect();
    out.sort();
    assert!(!out.is_empty(), "no fixtures found");
    out
}

fn fixture_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/capture")
}

#[test]
fn sha256_helper_matches_known_vectors() {
    assert_eq!(
        sha256_hex(b"abc"),
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    );
    assert_eq!(
        sha256_hex(&[0u8; 16]),
        "374708fff7719dd5979ec875d56cd2286f6d3cf7ec317a3b25632aab28ec37bb"
    );
}

fn sha256_hex(data: &[u8]) -> String {
    sha256(data).iter().map(|b| format!("{b:02x}")).collect()
}

/// Compact SHA-256 (FIPS 180-4) so the fixture replay needs no digest
/// dependency; verified against the capture script's Ruby Digest::SHA256.
fn sha256(data: &[u8]) -> [u8; 32] {
    const K: [u32; 64] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4,
        0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe,
        0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f,
        0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
        0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc,
        0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
        0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116,
        0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7,
        0xc67178f2,
    ];
    let bit_len = (data.len() as u64).wrapping_mul(8);
    let mut msg = data.to_vec();
    msg.push(0x80);
    while msg.len() % 64 != 56 {
        msg.push(0);
    }
    msg.extend_from_slice(&bit_len.to_be_bytes());
    let mut h: [u32; 8] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab,
        0x5be0cd19,
    ];
    for block in msg.chunks_exact(64) {
        let mut w = [0u32; 64];
        for (i, word) in block.chunks_exact(4).enumerate() {
            w[i] = u32::from_be_bytes([word[0], word[1], word[2], word[3]]);
        }
        for i in 16..64 {
            let s0 = w[i - 15].rotate_right(7) ^ w[i - 15].rotate_right(18) ^ (w[i - 15] >> 3);
            let s1 = w[i - 2].rotate_right(17) ^ w[i - 2].rotate_right(19) ^ (w[i - 2] >> 10);
            w[i] = w[i - 16]
                .wrapping_add(s0)
                .wrapping_add(w[i - 7])
                .wrapping_add(s1);
        }
        let (mut a, mut b, mut c, mut d, mut e, mut f, mut g, mut hh) =
            (h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7]);
        for i in 0..64 {
            let s1 = e.rotate_right(6) ^ e.rotate_right(11) ^ e.rotate_right(25);
            let ch = (e & f) ^ ((!e) & g);
            let t1 = hh
                .wrapping_add(s1)
                .wrapping_add(ch)
                .wrapping_add(K[i])
                .wrapping_add(w[i]);
            let s0 = a.rotate_right(2) ^ a.rotate_right(13) ^ a.rotate_right(22);
            let maj = (a & b) ^ (a & c) ^ (b & c);
            let t2 = s0.wrapping_add(maj);
            hh = g;
            g = f;
            f = e;
            e = d.wrapping_add(t1);
            d = c;
            c = b;
            b = a;
            a = t1.wrapping_add(t2);
        }
        h[0] = h[0].wrapping_add(a);
        h[1] = h[1].wrapping_add(b);
        h[2] = h[2].wrapping_add(c);
        h[3] = h[3].wrapping_add(d);
        h[4] = h[4].wrapping_add(e);
        h[5] = h[5].wrapping_add(f);
        h[6] = h[6].wrapping_add(g);
        h[7] = h[7].wrapping_add(hh);
    }
    let mut out = [0u8; 32];
    for (i, word) in h.iter().enumerate() {
        out[i * 4..i * 4 + 4].copy_from_slice(&word.to_be_bytes());
    }
    out
}

/// `bits_offset` reaches JSON either as a number or as a string (Bindata
/// integers stringify), and must never be silently dropped.
fn offset_value(value: Option<&serde_json::Value>) -> Option<usize> {
    let value = value?;
    let raw = if let Some(n) = value.as_u64() {
        n
    } else {
        value.as_str()?.trim().parse::<u64>().ok()?
    };
    usize::try_from(raw).ok()
}

fn mono_palette(meta: &serde_json::Value) -> Option<[[u8; 4]; 2]> {
    let value = meta.get("mono_palette")?;
    let outer = value.as_array()?;
    if outer.len() != 2 {
        return None;
    }
    let mut out = [[0u8; 4]; 2];
    for (i, entry) in outer.iter().enumerate() {
        let channels = entry.as_array()?;
        for (j, channel) in channels.iter().enumerate() {
            out[i][j] = u8::try_from(channel.as_u64()?).ok()?;
        }
    }
    Some(out)
}

#[test]
fn transformer_is_byte_exact_against_the_ruby_chain() {
    let dirs = fixture_dirs();
    let mut rgba = 0;
    let mut passthrough = 0;
    let mut jpeg = 0;
    let mut failures: Vec<String> = Vec::new();
    for dir in &dirs {
        let name = dir.file_name().unwrap().to_string_lossy().to_string();
        let dib = fs::read(dir.join("dib.bin")).expect("dib.bin");
        let meta: serde_json::Value =
            serde_json::from_str(&fs::read_to_string(dir.join("meta.json")).expect("meta.json"))
                .expect("meta json");
        let bits_offset = offset_value(meta.get("bits_offset"));
        let mono = mono_palette(&meta);
        let actual = dib_to_png(&dib, bits_offset, mono);
        let color_type = meta
            .get("color_type")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        match color_type.as_str() {
            "rgba" => {
                rgba += 1;
                let expected = fs::read(dir.join("expected.png")).expect("expected.png");
                match actual {
                    Some(bytes) if bytes == expected => {}
                    other => failures.push(format!(
                        "{name}: rgba mismatch (got {} bytes, want {})",
                        other.as_ref().map_or(0, Vec::len),
                        expected.len()
                    )),
                }
            }
            "png" => {
                passthrough += 1;
                let expected = fs::read(dir.join("passthrough.bin")).expect("passthrough.bin");
                match actual {
                    Some(bytes) if bytes == expected => {}
                    other => failures.push(format!(
                        "{name}: passthrough mismatch (got {:?}, want {} bytes)",
                        other.as_ref().map(|b| b.len()),
                        expected.len()
                    )),
                }
            }
            _ => {
                jpeg += 1;
                if actual.is_some() {
                    failures.push(format!("{name}: jpeg pass-through must be None"));
                }
            }
        }
    }
    assert!(
        failures.is_empty(),
        "{} of {} fixtures diverged:\n{}",
        failures.len(),
        dirs.len(),
        failures.join("\n")
    );
    println!("byte-exact: {rgba} rgba, {passthrough} png pass-through, {jpeg} jpeg (None)");
}

#[test]
fn png_round_trip_is_byte_stable_on_every_fixture() {
    let dirs = fixture_dirs();
    let mut checked = 0;
    let mut skipped = 0;
    for dir in &dirs {
        let png_path = dir.join("expected.png");
        let png_path = if png_path.exists() {
            png_path
        } else {
            dir.join("passthrough.bin")
        };
        if !png_path.exists() {
            continue;
        }
        let bytes = fs::read(png_path).expect("png bytes");
        // BI_PNG pass-through bytes are carried verbatim by Ruby without
        // validation; only strictly decodable streams are model round-trips.
        let Ok(model) = png_model::Png::decode(&bytes) else {
            skipped += 1;
            continue;
        };
        assert_eq!(
            model.serialize(),
            bytes,
            "round trip diverged for {}",
            dir.file_name().unwrap().to_string_lossy()
        );
        checked += 1;
    }
    println!("png round trip stable on {checked} fixtures ({skipped} not strictly decodable)");
}

#[test]
fn png_pixels_match_the_ruby_decoder_sha() {
    let dirs = fixture_dirs();
    let mut checked = 0;
    let mut failures: Vec<String> = Vec::new();
    for dir in &dirs {
        let name = dir.file_name().unwrap().to_string_lossy().to_string();
        let meta: serde_json::Value =
            serde_json::from_str(&fs::read_to_string(dir.join("meta.json")).expect("meta.json"))
                .expect("meta json");
        let Some(digest) = meta.get("decoded_rgba_sha256").and_then(|v| v.as_str()) else {
            continue;
        };
        let png_path = dir.join("expected.png");
        assert!(png_path.exists(), "{name} has decoded digest without png");
        let bytes = fs::read(png_path).expect("expected.png");
        let model = png_model::Png::decode(&bytes).expect("strict decode");
        let surface = png_model::surface::surface(&model).expect("surface");
        assert_eq!(
            surface.width,
            u32::try_from(meta["decoded_width"].as_i64().unwrap_or(-1)).unwrap_or(0),
            "{name} decoded width"
        );
        assert_eq!(
            surface.height,
            u32::try_from(meta["decoded_height"].as_i64().unwrap_or(-1)).unwrap_or(0),
            "{name} decoded height"
        );
        if sha256_hex(&surface.rgba) != digest {
            failures.push(name);
        }
        checked += 1;
    }
    assert!(
        failures.is_empty(),
        "{} of {checked} pixel surfaces diverge from the Ruby decoder: {}",
        failures.len(),
        failures.join(", ")
    );
    println!("pixel-exact vs Ruby PngDecoder on {checked} fixtures");
}

#[test]
fn dib_structural_round_trip_is_byte_stable() {
    let dirs = fixture_dirs();
    let mut checked = 0;
    let mut skipped = 0;
    for dir in &dirs {
        let dib = fs::read(dir.join("dib.bin")).expect("dib.bin");
        let Ok(image) = dib_model::DibImage::parse(&dib) else {
            skipped += 1;
            continue;
        };
        assert_eq!(
            dib_model::serialize_image(&image),
            dib,
            "structural round trip diverged for {}",
            dir.file_name().unwrap().to_string_lossy()
        );
        checked += 1;
    }
    println!("dib structural round trip stable on {checked} fixtures ({skipped} outside the zoo)");
}

#[test]
fn png_to_dib_round_trips_through_dib_to_png() {
    let dirs = fixture_dirs();
    let mut checked = 0;
    for dir in &dirs {
        let png_path = dir.join("expected.png");
        if !png_path.exists() {
            continue;
        }
        let bytes = fs::read(png_path).expect("expected.png");
        let Some(dib) = png_to_dib(&bytes) else {
            continue;
        };
        // The BI_RGB 32-bpp BGRA encoding is alpha-faithful, so the reverse
        // transformer reproduces the same PNG unless the source carries a
        // fully transparent surface (the alpha-zero rule forces opaque).
        let alpha_any_nonzero = bytes.len() >= 26
            && png_model::Png::decode(&bytes)
                .ok()
                .and_then(|model| png_model::surface::surface(&model).ok())
                .is_some_and(|surface| surface.rgba.iter().skip(3).step_by(4).any(|a| *a != 0));
        if !alpha_any_nonzero {
            continue;
        }
        let regenerated = dib_to_png(&dib, None, None).expect("dib to png");
        assert_eq!(
            regenerated,
            bytes,
            "png -> dib -> png diverged for {}",
            dir.file_name().unwrap().to_string_lossy()
        );
        checked += 1;
    }
    println!("png->dib->png stable on {checked} fixtures");
}
