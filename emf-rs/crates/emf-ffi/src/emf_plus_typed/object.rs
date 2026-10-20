//! Object normalization shares the checked size/write traversal with other families.
use super::Sink;
use crate::Failure;
use emf_core::emf_plus::*;

impl Sink<'_, '_, '_> {
    pub fn object_fragment(
        &mut self,
        fragment: &ObjectFragment,
        definition: &ObjectDefinition,
        value: Option<&ObjectData>,
    ) -> Result<(), Failure> {
        self.optional(fragment.total_size)?;
        self.count(definition.first_record)?;
        self.count(definition.last_record)?;
        self.word(u32::from(value.is_some()))?;
        if let Some(value) = value {
            self.word(definition.id as u32)?;
            self.word(definition.object_type as u32)?;
            self.object(value)?;
        }
        Ok(())
    }
    fn word_array(&mut self, values: &[u32]) -> Result<(), Failure> {
        self.count(values.len())?;
        self.words(values)
    }
    fn pairs(&mut self, values: &[[u32; 2]]) -> Result<(), Failure> {
        self.count(values.len())?;
        for value in values {
            self.words(value)?;
        }
        Ok(())
    }
    fn optional_words<const N: usize>(&mut self, value: Option<&[u32; N]>) -> Result<(), Failure> {
        self.word(u32::from(value.is_some()))?;
        if let Some(value) = value {
            self.words(value)?;
        }
        Ok(())
    }
    fn optional_array(&mut self, value: Option<&Vec<u32>>) -> Result<(), Failure> {
        self.word(u32::from(value.is_some()))?;
        if let Some(value) = value {
            self.word_array(value)?;
        }
        Ok(())
    }
    fn path(&mut self, value: &Path) -> Result<(), Failure> {
        self.words(&[value.version, value.flags])?;
        self.points(&value.points)?;
        match &value.point_types {
            PathPointTypes::Plain(types) => {
                self.word(0)?;
                self.padding(types)?;
            }
            PathPointTypes::RunLength(runs) => {
                self.word(1)?;
                self.count(runs.len())?;
                for run in runs {
                    self.bytes(&[run.header, run.point_type])?;
                }
            }
        }
        self.padding(&value.alignment_padding)
    }
    fn cap(&mut self, value: &CustomLineCap) -> Result<(), Failure> {
        self.word(value.version)?;
        match &value.data {
            CustomLineCapData::Default(v) => {
                self.word(0)?;
                self.words(&[
                    v.flags,
                    v.base_cap,
                    v.base_inset,
                    v.stroke_start_cap,
                    v.stroke_end_cap,
                    v.stroke_join,
                    v.stroke_miter_limit,
                    v.width_scale,
                ])?;
                self.words(&v.fill_hot_spot)?;
                self.words(&v.stroke_hot_spot)?;
                for path in [&v.fill_path, &v.line_path] {
                    self.word(u32::from(path.is_some()))?;
                    if let Some(path) = path {
                        self.path(path)?;
                    }
                }
            }
            CustomLineCapData::AdjustableArrow(v) => {
                self.word(1)?;
                self.words(&[
                    v.width,
                    v.height,
                    v.middle_inset,
                    v.fill_state,
                    v.line_start_cap,
                    v.line_end_cap,
                    v.line_join,
                    v.line_miter_limit,
                    v.width_scale,
                ])?;
                self.words(&v.fill_hot_spot)?;
                self.words(&v.line_hot_spot)?;
            }
        }
        Ok(())
    }
    fn linear(&mut self, v: &LinearGradient) -> Result<(), Failure> {
        self.words(&[v.flags, v.wrap_mode as u32])?;
        self.words(&v.rectangle)?;
        self.words(&[v.start_color, v.end_color])?;
        self.words(&v.reserved)?;
        self.optional_words(v.transform.as_ref())?;
        self.count(v.blends.len())?;
        for blend in &v.blends {
            self.pairs(blend)?;
        }
        Ok(())
    }
    fn gradient(&mut self, v: &PathGradient) -> Result<(), Failure> {
        self.words(&[v.flags, v.wrap_mode as u32, v.center_color])?;
        self.words(&v.center_point)?;
        self.word_array(&v.surrounding_colors)?;
        match &v.boundary {
            GradientBoundary::Path(path) => {
                self.word(0)?;
                self.path(path)?;
            }
            GradientBoundary::Points(points) => {
                self.word(1)?;
                self.pairs(points)?;
            }
        }
        self.optional_words(v.transform.as_ref())?;
        self.word(u32::from(v.blend.is_some()))?;
        if let Some(blend) = &v.blend {
            self.pairs(blend)?;
        }
        self.optional_words(v.focus_scales.as_ref())
    }
    fn palette(&mut self, value: Option<&Palette>) -> Result<(), Failure> {
        self.word(u32::from(value.is_some()))?;
        if let Some(v) = value {
            self.word(v.style_flags)?;
            self.word_array(&v.entries)?;
        }
        Ok(())
    }
    fn pixel_bitmap(&mut self, v: &PixelBitmap) -> Result<(), Failure> {
        self.words(&[
            v.version,
            v.width as u32,
            v.height as u32,
            v.stride as u32,
            v.pixel_format,
        ])?;
        self.palette(v.palette.as_ref())?;
        self.padding(&v.pixels)
    }
    fn image(&mut self, v: &TextureImage) -> Result<(), Failure> {
        match v {
            TextureImage::PixelBitmap(v) => {
                self.word(1)?;
                self.pixel_bitmap(v)
            }
            TextureImage::Bitmap {
                version,
                width,
                height,
                stride,
                pixel_format,
                bitmap_type,
                data,
            } => {
                self.word(2)?;
                self.words(&[
                    *version,
                    *width as u32,
                    *height as u32,
                    *stride as u32,
                    *pixel_format,
                    *bitmap_type,
                ])?;
                self.padding(data)
            }
            TextureImage::Metafile {
                version,
                metafile_type,
                data,
                suffix,
            } => {
                self.word(3)?;
                self.words(&[*version, *metafile_type])?;
                self.padding(data)?;
                self.padding(suffix)
            }
        }
    }
    fn texture(&mut self, v: &Texture) -> Result<(), Failure> {
        self.words(&[v.flags, v.wrap_mode as u32])?;
        self.optional_words(v.transform.as_ref())?;
        self.word(u32::from(v.image.is_some()))?;
        if let Some(image) = &v.image {
            self.image(image)?;
        }
        Ok(())
    }
    fn pen(&mut self, v: &Pen) -> Result<(), Failure> {
        self.words(&[v.version, v.flags, v.unit, v.width])?;
        self.optional_words(v.transform.as_ref())?;
        for value in [
            v.start_cap.map(|n| n as u32),
            v.end_cap.map(|n| n as u32),
            v.join.map(|n| n as u32),
            v.miter_limit,
            v.line_style.map(|n| n as u32),
            v.dashed_line_cap.map(|n| n as u32),
            v.dash_offset,
        ] {
            self.optional(value)?;
        }
        self.optional_array(v.dash_pattern.as_ref())?;
        self.optional(v.alignment.map(|n| n as u32))?;
        self.optional_array(v.compound_line.as_ref())?;
        self.count(v.custom_caps.len())?;
        for cap in &v.custom_caps {
            self.cap(cap)?;
        }
        self.word(v.brush.version)?;
        match &v.brush.data {
            PenBrushData::Solid { argb } => self.words(&[0, *argb]),
            PenBrushData::Hatch {
                style,
                foreground,
                background,
            } => self.words(&[1, *style, *foreground, *background]),
            PenBrushData::Texture(v) => {
                self.word(2)?;
                self.texture(v)
            }
            PenBrushData::PathGradient(v) => {
                self.word(3)?;
                self.gradient(v)
            }
            PenBrushData::LinearGradient(v) => {
                self.word(4)?;
                self.linear(v)
            }
        }
    }
    fn object(&mut self, v: &ObjectData) -> Result<(), Failure> {
        self.word(match v {
            ObjectData::Opaque { .. } => 0,
            ObjectData::SolidBrush { .. } => 1,
            ObjectData::HatchBrush { .. } => 2,
            ObjectData::TextureBrush { .. } => 3,
            ObjectData::PathGradientBrush { .. } => 4,
            ObjectData::LinearGradientBrush { .. } => 5,
            ObjectData::Pen(_) => 6,
            ObjectData::Path(_) => 7,
            ObjectData::Region(_) => 8,
            ObjectData::Font { .. } => 9,
            ObjectData::StringFormat(_) => 10,
            ObjectData::ImageAttributes { .. } => 11,
            ObjectData::PixelBitmap(_) => 12,
            ObjectData::BitmapImage { .. } => 13,
            ObjectData::MetafileImage { .. } => 14,
            ObjectData::CustomLineCap(_) => 15,
        })?;
        match v {
            ObjectData::Opaque { object_type, bytes } => {
                self.word(*object_type as u32)?;
                self.padding(bytes)
            }
            ObjectData::SolidBrush { version, argb } => self.words(&[*version, *argb]),
            ObjectData::HatchBrush {
                version,
                style,
                foreground,
                background,
            } => self.words(&[*version, *style, *foreground, *background]),
            ObjectData::TextureBrush { version, data } => {
                self.word(*version)?;
                self.texture(data)
            }
            ObjectData::PathGradientBrush { version, data } => {
                self.word(*version)?;
                self.gradient(data)
            }
            ObjectData::LinearGradientBrush { version, data } => {
                self.word(*version)?;
                self.linear(data)
            }
            ObjectData::Pen(v) => self.pen(v),
            ObjectData::Path(v) => self.path(v),
            ObjectData::CustomLineCap(v) => self.cap(v),
            ObjectData::Region(v) => {
                self.word(v.version)?;
                self.count(v.nodes.len())?;
                for node in &v.nodes {
                    match node {
                        RegionNode::Binary { operation } => self.words(&[1, *operation])?,
                        RegionNode::Rectangle(rectangle) => {
                            self.word(2)?;
                            self.words(rectangle)?;
                        }
                        RegionNode::Path(path) => {
                            self.word(3)?;
                            self.path(path)?;
                        }
                        RegionNode::Empty => self.word(4)?,
                        RegionNode::Infinite => self.word(5)?,
                    }
                }
                Ok(())
            }
            ObjectData::Font {
                version,
                em_size,
                size_unit,
                style,
                reserved,
                family_name,
                suffix,
            } => {
                self.words(&[*version, *em_size, *size_unit, *style as u32, *reserved])?;
                self.count(family_name.len())?;
                for value in family_name {
                    self.bytes(&value.to_le_bytes())?;
                }
                self.padding(suffix)
            }
            ObjectData::StringFormat(v) => {
                self.words(&[
                    v.version,
                    v.flags,
                    v.language,
                    v.alignment,
                    v.line_alignment,
                    v.digit_substitution,
                    v.digit_language,
                    v.first_tab_offset,
                    v.hotkey_prefix as u32,
                    v.leading_margin,
                    v.trailing_margin,
                    v.tracking,
                    v.trimming,
                ])?;
                self.word_array(&v.tab_stops)?;
                self.count(v.character_ranges.len())?;
                for range in &v.character_ranges {
                    self.words(&[range[0] as u32, range[1] as u32])?;
                }
                Ok(())
            }
            ObjectData::ImageAttributes {
                version,
                reserved1,
                wrap_mode,
                clamp_argb,
                object_clamp,
                reserved2,
            } => self.words(&[
                *version,
                *reserved1,
                *wrap_mode,
                *clamp_argb,
                *object_clamp as u32,
                *reserved2,
            ]),
            ObjectData::PixelBitmap(v) => self.pixel_bitmap(v),
            ObjectData::BitmapImage {
                version,
                width,
                height,
                stride,
                pixel_format,
                bitmap_type,
                data,
            } => {
                self.words(&[
                    *version,
                    *width as u32,
                    *height as u32,
                    *stride as u32,
                    *pixel_format,
                    *bitmap_type,
                ])?;
                self.padding(data)
            }
            ObjectData::MetafileImage {
                version,
                metafile_type,
                data,
                suffix,
            } => {
                self.words(&[*version, *metafile_type])?;
                self.padding(data)?;
                self.padding(suffix)
            }
        }
    }
}
