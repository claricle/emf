//! Normalized variable-sized payloads; one traversal defines both sizing and writing.
mod object;
use super::emf_plus_snapshot::overflow;
use crate::Failure;
use emf_core::emf_plus::{
    Drawing, Effect, ImageSource, PointData, Rectangle, RelativeCoordinate, TSGraphics, Text,
};

pub(super) struct Sink<'a, 'b, 'c> {
    pub budget: &'b mut emf_core::ParseBudget<'c>,
    pub len: usize,
    pub out: Option<&'a mut Vec<u8>>,
}
impl Sink<'_, '_, '_> {
    fn bytes(&mut self, bytes: &[u8]) -> Result<(), Failure> {
        self.budget
            .charge_work(1 + (bytes.len() as u64).div_ceil(16))?;
        self.len = self.len.checked_add(bytes.len()).ok_or_else(overflow)?;
        if let Some(out) = &mut self.out {
            out.extend_from_slice(bytes);
        }
        Ok(())
    }
    fn word(&mut self, value: u32) -> Result<(), Failure> {
        self.bytes(&value.to_le_bytes())
    }
    fn count(&mut self, value: usize) -> Result<(), Failure> {
        self.bytes(&(value as u64).to_le_bytes())
    }
    fn words(&mut self, values: &[u32]) -> Result<(), Failure> {
        for &value in values {
            self.word(value)?;
        }
        Ok(())
    }
    fn optional(&mut self, value: Option<u32>) -> Result<(), Failure> {
        self.word(u32::from(value.is_some()))?;
        self.word(value.unwrap_or(0))
    }
    fn rectangle(&mut self, rectangle: &Rectangle) -> Result<(), Failure> {
        match rectangle {
            Rectangle::Float(values) => {
                self.word(0)?;
                self.words(values)
            }
            Rectangle::Integer(values) => {
                self.word(1)?;
                for &value in values {
                    self.word(value as i32 as u32)?;
                }
                Ok(())
            }
        }
    }
    fn points(&mut self, points: &PointData) -> Result<(), Failure> {
        self.word(match points {
            PointData::Float(_) => 0,
            PointData::Integer(_) => 1,
            PointData::Relative(_) => 2,
        })?;
        self.count(points.count())?;
        match points {
            PointData::Float(values) => {
                for value in values {
                    self.words(value)?;
                }
            }
            PointData::Integer(values) => {
                for point in values {
                    for &value in point {
                        self.word(value as i32 as u32)?;
                    }
                }
            }
            PointData::Relative(values) => {
                for point in values {
                    for value in point {
                        let (width, value) = match value {
                            RelativeCoordinate::Seven(n) => (7, *n as i32),
                            RelativeCoordinate::Fifteen(n) => (15, *n as i32),
                        };
                        self.word(width)?;
                        self.word(value as u32)?;
                    }
                }
            }
        }
        Ok(())
    }
    fn padding(&mut self, padding: &[u8]) -> Result<(), Failure> {
        self.count(padding.len())?;
        self.bytes(padding)
    }
    fn source(&mut self, source: &ImageSource) -> Result<(), Failure> {
        self.word(source.attributes_id)?;
        self.word(source.unit as u32)?;
        self.words(&source.rectangle)
    }
    pub fn drawing(&mut self, drawing: &Drawing) -> Result<(), Failure> {
        match drawing {
            Drawing::Rectangles { brush, rectangles } => {
                self.word(1)?;
                self.optional(*brush)?;
                self.count(rectangles.len())?;
                for rectangle in rectangles {
                    self.rectangle(rectangle)?;
                }
            }
            Drawing::Ellipse { brush, rectangle } => {
                self.word(2)?;
                self.optional(*brush)?;
                self.rectangle(rectangle)?;
            }
            Drawing::Arc {
                brush,
                start_angle,
                sweep_angle,
                rectangle,
            } => {
                self.word(3)?;
                self.optional(*brush)?;
                self.words(&[*start_angle, *sweep_angle])?;
                self.rectangle(rectangle)?;
            }
            Drawing::Points {
                brush,
                points,
                data_padding,
            } => {
                self.word(4)?;
                self.optional(*brush)?;
                self.points(points)?;
                self.padding(data_padding)?;
            }
            Drawing::Curve {
                brush,
                tension,
                range,
                points,
                data_padding,
            } => {
                self.word(5)?;
                self.optional(*brush)?;
                self.word(*tension)?;
                self.word(u32::from(range.is_some()))?;
                self.words(&range.unwrap_or([0; 2]))?;
                self.points(points)?;
                self.padding(data_padding)?;
            }
            Drawing::ImageRect {
                source,
                destination,
            } => {
                self.word(6)?;
                self.source(source)?;
                self.rectangle(destination)?;
            }
            Drawing::ImagePoints {
                source,
                points,
                data_padding,
            } => {
                self.word(7)?;
                self.source(source)?;
                self.points(points)?;
                self.padding(data_padding)?;
            }
            Drawing::ObjectReference { value } => {
                self.word(8)?;
                self.word(*value)?;
            }
        }
        Ok(())
    }
    pub fn effect(&mut self, effect: &Effect) -> Result<(), Failure> {
        self.word(match effect {
            Effect::Unknown { .. } => 0,
            Effect::Blur { .. } => 1,
            Effect::BrightnessContrast { .. } => 2,
            Effect::ColorBalance { .. } => 3,
            Effect::ColorCurve { .. } => 4,
            Effect::ColorLookupTable { .. } => 5,
            Effect::ColorMatrix { .. } => 6,
            Effect::HueSaturationLightness { .. } => 7,
            Effect::Levels { .. } => 8,
            Effect::RedEyeCorrection { .. } => 9,
            Effect::Sharpen { .. } => 10,
            Effect::Tint { .. } => 11,
        })?;
        self.bytes(&effect.guid())?;
        match effect {
            Effect::Blur {
                radius,
                expand_edge,
            } => self.words(&[*radius, *expand_edge]),
            Effect::BrightnessContrast {
                brightness,
                contrast,
            } => self.words(&[*brightness as u32, *contrast as u32]),
            Effect::ColorBalance {
                cyan_red,
                magenta_green,
                yellow_blue,
            } => self.words(&[*cyan_red as u32, *magenta_green as u32, *yellow_blue as u32]),
            Effect::ColorCurve {
                adjustment,
                channel,
                intensity,
            } => self.words(&[*adjustment, *channel, *intensity as u32]),
            Effect::ColorLookupTable { tables } => {
                self.count(tables.len())?;
                for table in tables {
                    self.bytes(table)?;
                }
                Ok(())
            }
            Effect::ColorMatrix { matrix } => self.words(matrix),
            Effect::HueSaturationLightness {
                hue,
                saturation,
                lightness,
            } => self.words(&[*hue as u32, *saturation as u32, *lightness as u32]),
            Effect::Levels {
                highlight,
                midtone,
                shadow,
            } => self.words(&[*highlight as u32, *midtone as u32, *shadow as u32]),
            Effect::RedEyeCorrection { areas } => {
                self.count(areas.len())?;
                for area in areas {
                    for value in area {
                        self.word(*value as u32)?;
                    }
                }
                Ok(())
            }
            Effect::Sharpen { radius, amount } => self.words(&[*radius, *amount]),
            Effect::Tint { hue, amount } => self.words(&[*hue as u32, *amount as u32]),
            Effect::Unknown { buffer, .. } => self.padding(buffer),
        }
    }
    pub fn ts_graphics(&mut self, graphics: &TSGraphics) -> Result<(), Failure> {
        self.words(&[
            graphics.anti_alias_mode as u32,
            graphics.text_render_hint as u32,
            graphics.compositing_mode as u32,
            graphics.compositing_quality as u32,
            graphics.render_origin[0] as i32 as u32,
            graphics.render_origin[1] as i32 as u32,
            graphics.text_contrast as u32,
            graphics.filter_type as u32,
            graphics.pixel_offset as u32,
        ])?;
        self.words(&graphics.world_to_device)?;
        self.word(u32::from(graphics.palette.is_some()))?;
        if let Some(palette) = &graphics.palette {
            self.word(palette.style_flags)?;
            self.count(palette.entries.len())?;
            self.words(&palette.entries)?;
        }
        Ok(())
    }
    pub fn text(&mut self, text: &Text) -> Result<(), Failure> {
        match text {
            Text::String {
                brush,
                format_id,
                layout,
                utf16,
                data_padding,
            } => {
                self.word(1)?;
                self.words(&[*brush, *format_id])?;
                self.words(layout)?;
                self.count(utf16.len())?;
                for value in utf16 {
                    self.bytes(&value.to_le_bytes())?;
                }
                self.padding(data_padding)?;
            }
            Text::Driver {
                brush,
                options,
                glyphs,
                positions,
                matrix,
                data_padding,
            } => {
                self.word(2)?;
                self.words(&[*brush, *options])?;
                self.count(glyphs.len())?;
                for value in glyphs {
                    self.bytes(&value.to_le_bytes())?;
                }
                self.count(positions.len())?;
                for value in positions {
                    self.words(value)?;
                }
                self.word(u32::from(matrix.is_some()))?;
                if let Some(matrix) = matrix {
                    self.words(matrix)?;
                }
                self.padding(data_padding)?;
            }
        }
        Ok(())
    }
}
