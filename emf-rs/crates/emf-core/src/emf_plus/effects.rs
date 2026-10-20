//! Serialized image effects (MS-EMFPLUS 2.3.5.2 and 2.2.3).
use super::Error;
use crate::limits::{try_vec_with_capacity, Budget};

/// Effect parameters retain raw float, Boolean and enum bits. Numeric rendering
/// ranges are not interpreted. GUID and BufferSize derive from the selected variant.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Effect {
    Blur {
        radius: u32,
        expand_edge: u32,
    },
    BrightnessContrast {
        brightness: i32,
        contrast: i32,
    },
    ColorBalance {
        cyan_red: i32,
        magenta_green: i32,
        yellow_blue: i32,
    },
    ColorCurve {
        adjustment: u32,
        channel: u32,
        intensity: i32,
    },
    /// Exactly four tables in blue, green, red, alpha wire order.
    ColorLookupTable {
        tables: Vec<[u8; 256]>,
    },
    /// Raw float words in wire order: Matrix[0..5][0], then Matrix[0..5][1], etc.
    ColorMatrix {
        matrix: [u32; 25],
    },
    HueSaturationLightness {
        hue: i32,
        saturation: i32,
        lightness: i32,
    },
    Levels {
        highlight: i32,
        midtone: i32,
        shadow: i32,
    },
    /// Signed RectL left/top/right/bottom coordinates; no pixel expansion.
    RedEyeCorrection {
        areas: Vec<[i32; 4]>,
    },
    Sharpen {
        radius: u32,
        amount: u32,
    },
    Tint {
        hue: i32,
        amount: i32,
    },
    Unknown {
        guid: [u8; 16],
        buffer: Vec<u8>,
    },
}
const GUIDS: [[u8; 16]; 11] = [
    [
        0xa4, 0x80, 0x3c, 0x63, 0x43, 0x18, 0x2b, 0x48, 0x9e, 0xf2, 0xbe, 0x28, 0x34, 0xc5, 0xfd,
        0xd4,
    ],
    [
        0xe1, 0xdb, 0xa1, 0xd3, 0xc4, 0x8e, 0x17, 0x4c, 0x9f, 0x4c, 0xea, 0x97, 0xad, 0x1c, 0x34,
        0x3d,
    ],
    [
        0x7d, 0x59, 0x7e, 0x53, 0x1e, 0x25, 0xda, 0x48, 0x96, 0x64, 0x29, 0xca, 0x49, 0x6b, 0x70,
        0xf8,
    ],
    [
        0x22, 0x00, 0x6a, 0xdd, 0xe4, 0x58, 0x67, 0x4a, 0x9d, 0x9b, 0xd4, 0x8e, 0xb8, 0x81, 0xa5,
        0x3d,
    ],
    [
        0xa9, 0x72, 0xce, 0xa7, 0x7f, 0x0f, 0xd7, 0x40, 0xb3, 0xcc, 0xd0, 0xc0, 0x2d, 0x5c, 0x32,
        0x12,
    ],
    [
        0x15, 0x26, 0x8f, 0x71, 0x33, 0x79, 0xe3, 0x40, 0xa5, 0x11, 0x5f, 0x68, 0xfe, 0x14, 0xdd,
        0x74,
    ],
    [
        0xc3, 0xd6, 0x2d, 0x8b, 0x07, 0xeb, 0x87, 0x4d, 0xa5, 0xf0, 0x71, 0x08, 0xe2, 0x6a, 0x9c,
        0x5f,
    ],
    [
        0xec, 0x54, 0xc3, 0x99, 0x31, 0x2a, 0x3a, 0x4f, 0x8c, 0x34, 0x17, 0xa8, 0x03, 0xb3, 0x3a,
        0x25,
    ],
    [
        0x05, 0x9d, 0xd2, 0x74, 0xa4, 0x69, 0x66, 0x42, 0x95, 0x49, 0x3c, 0xc5, 0x28, 0x36, 0xb6,
        0x32,
    ],
    [
        0xee, 0xf3, 0xcb, 0x63, 0x26, 0xc5, 0x2c, 0x40, 0x8f, 0x71, 0x62, 0xc5, 0x40, 0xbf, 0x51,
        0x42,
    ],
    [
        0x00, 0xaf, 0x77, 0x10, 0x48, 0x28, 0x41, 0x44, 0x94, 0x89, 0x44, 0xad, 0x4c, 0x2d, 0x7a,
        0x2c,
    ],
];
impl Effect {
    pub fn guid(&self) -> [u8; 16] {
        match self {
            Self::Blur { .. } => GUIDS[0],
            Self::BrightnessContrast { .. } => GUIDS[1],
            Self::ColorBalance { .. } => GUIDS[2],
            Self::ColorCurve { .. } => GUIDS[3],
            Self::ColorLookupTable { .. } => GUIDS[4],
            Self::ColorMatrix { .. } => GUIDS[5],
            Self::HueSaturationLightness { .. } => GUIDS[6],
            Self::Levels { .. } => GUIDS[7],
            Self::RedEyeCorrection { .. } => GUIDS[8],
            Self::Sharpen { .. } => GUIDS[9],
            Self::Tint { .. } => GUIDS[10],
            Self::Unknown { guid, .. } => *guid,
        }
    }
    pub(crate) fn element_work(&self) -> u64 {
        match self {
            Self::ColorLookupTable { tables } => (tables.len() as u64).saturating_mul(256),
            Self::RedEyeCorrection { areas } => areas.len() as u64,
            Self::Unknown { buffer, .. } => (buffer.len() as u64).div_ceil(16),
            _ => 0,
        }
    }
    fn buffer_len(&self) -> usize {
        match self {
            Self::Blur { .. }
            | Self::BrightnessContrast { .. }
            | Self::Sharpen { .. }
            | Self::Tint { .. } => 8,
            Self::ColorBalance { .. }
            | Self::ColorCurve { .. }
            | Self::HueSaturationLightness { .. }
            | Self::Levels { .. } => 12,
            Self::ColorLookupTable { tables } => tables.len().saturating_mul(256),
            Self::ColorMatrix { .. } => 100,
            Self::RedEyeCorrection { areas } => areas.len().saturating_mul(16).saturating_add(4),
            Self::Unknown { buffer, .. } => buffer.len(),
        }
    }
    pub(crate) fn len(&self) -> usize {
        self.buffer_len().saturating_add(20)
    }
    pub(crate) fn valid(&self, kind: u16) -> bool {
        kind == 0x4038
            && self.buffer_len() <= u32::MAX as usize
            && match self {
                Self::ColorLookupTable { tables } => tables.len() == 4,
                Self::RedEyeCorrection { areas } => areas.len() <= i32::MAX as usize,
                Self::Unknown { guid, buffer } => !GUIDS.contains(guid) && buffer.len() % 4 == 0,
                _ => true,
            }
    }
    pub(crate) fn write(&self, out: &mut Vec<u8>) {
        out.extend_from_slice(&self.guid());
        words(out, &[self.buffer_len() as u32]);
        match self {
            Self::Blur {
                radius,
                expand_edge,
            } => words(out, &[*radius, *expand_edge]),
            Self::BrightnessContrast {
                brightness,
                contrast,
            } => words(out, &[*brightness as u32, *contrast as u32]),
            Self::ColorBalance {
                cyan_red,
                magenta_green,
                yellow_blue,
            } => words(
                out,
                &[*cyan_red as u32, *magenta_green as u32, *yellow_blue as u32],
            ),
            Self::ColorCurve {
                adjustment,
                channel,
                intensity,
            } => words(out, &[*adjustment, *channel, *intensity as u32]),
            Self::ColorLookupTable { tables } => {
                for table in tables {
                    out.extend_from_slice(table);
                }
            }
            Self::ColorMatrix { matrix } => words(out, matrix),
            Self::HueSaturationLightness {
                hue,
                saturation,
                lightness,
            } => words(out, &[*hue as u32, *saturation as u32, *lightness as u32]),
            Self::Levels {
                highlight,
                midtone,
                shadow,
            } => words(out, &[*highlight as u32, *midtone as u32, *shadow as u32]),
            Self::RedEyeCorrection { areas } => {
                words(out, &[areas.len() as u32]);
                for a in areas {
                    for n in a {
                        words(out, &[*n as u32]);
                    }
                }
            }
            Self::Sharpen { radius, amount } => words(out, &[*radius, *amount]),
            Self::Tint { hue, amount } => words(out, &[*hue as u32, *amount as u32]),
            Self::Unknown { buffer, .. } => out.extend_from_slice(buffer),
        }
    }
}
fn words(out: &mut Vec<u8>, v: &[u32]) {
    for n in v {
        out.extend_from_slice(&n.to_le_bytes());
    }
}
pub(crate) fn decode(
    bytes: &[u8],
    offset: usize,
    budget: &mut Budget<'_>,
) -> Result<Effect, Error> {
    let invalid = || Error::InvalidRecord {
        offset,
        reason: "invalid serialized effect count/layout",
    };
    if bytes.len() < 20 {
        return Err(invalid());
    }
    let guid: [u8; 16] = bytes[..16].try_into().unwrap();
    let len = u32::from_le_bytes(bytes[16..20].try_into().unwrap()) as usize;
    if len % 4 != 0 || len != bytes.len() - 20 {
        return Err(invalid());
    }
    let b = &bytes[20..];
    let index = GUIDS.iter().position(|g| *g == guid);
    let fixed_len = match index {
        Some(0 | 1 | 9 | 10) => Some(8),
        Some(2 | 3 | 6 | 7) => Some(12),
        Some(4) => Some(1024),
        Some(5) => Some(100),
        _ => None,
    };
    if fixed_len.is_some_and(|n| n != b.len()) {
        return Err(invalid());
    }
    let word = |i: usize| u32::from_le_bytes(b[i * 4..i * 4 + 4].try_into().unwrap());
    Ok(match index {
        Some(0) => Effect::Blur {
            radius: word(0),
            expand_edge: word(1),
        },
        Some(1) => Effect::BrightnessContrast {
            brightness: word(0) as i32,
            contrast: word(1) as i32,
        },
        Some(2) => Effect::ColorBalance {
            cyan_red: word(0) as i32,
            magenta_green: word(1) as i32,
            yellow_blue: word(2) as i32,
        },
        Some(3) => Effect::ColorCurve {
            adjustment: word(0),
            channel: word(1),
            intensity: word(2) as i32,
        },
        Some(4) => {
            budget.charge_alloc(1024)?;
            budget.charge_work(1024)?;
            let mut tables = try_vec_with_capacity(4)?;
            for t in b.chunks_exact(256) {
                tables.push(t.try_into().unwrap());
            }
            Effect::ColorLookupTable { tables }
        }
        Some(5) => Effect::ColorMatrix {
            matrix: std::array::from_fn(word),
        },
        Some(6) => Effect::HueSaturationLightness {
            hue: word(0) as i32,
            saturation: word(1) as i32,
            lightness: word(2) as i32,
        },
        Some(7) => Effect::Levels {
            highlight: word(0) as i32,
            midtone: word(1) as i32,
            shadow: word(2) as i32,
        },
        Some(8) => {
            if b.len() < 4 || word(0) > i32::MAX as u32 {
                return Err(invalid());
            }
            let count = word(0) as usize;
            if count != (b.len() - 4) / 16 || (b.len() - 4) % 16 != 0 {
                return Err(invalid());
            }
            // Validate wire availability before charging or reserving the counted array.
            budget.charge_alloc(b.len() - 4)?;
            budget.charge_work(count as u64)?;
            let mut areas = try_vec_with_capacity(count)?;
            for i in 0..count {
                areas.push(std::array::from_fn(|j| word(1 + i * 4 + j) as i32));
            }
            Effect::RedEyeCorrection { areas }
        }
        Some(9) => Effect::Sharpen {
            radius: word(0),
            amount: word(1),
        },
        Some(10) => Effect::Tint {
            hue: word(0) as i32,
            amount: word(1) as i32,
        },
        _ => {
            budget.charge_alloc(b.len())?;
            budget.charge_work((b.len() as u64).div_ceil(16))?;
            let mut buffer = try_vec_with_capacity(b.len())?;
            buffer.extend_from_slice(b);
            Effect::Unknown { guid, buffer }
        }
    })
}
