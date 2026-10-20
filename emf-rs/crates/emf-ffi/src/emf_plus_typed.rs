//! Normalized variable-sized payloads; one traversal defines both sizing and writing.
use super::emf_plus_snapshot::overflow;
use crate::Failure;
use emf_core::emf_plus::{Drawing, ImageSource, PointData, Rectangle, RelativeCoordinate, Text};

pub(super) struct Sink<'a> {
    pub len: usize,
    pub out: Option<&'a mut Vec<u8>>,
}
impl Sink<'_> {
    fn bytes(&mut self, bytes: &[u8]) -> Result<(), Failure> {
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
