---
source: [MS-EMFPLUS]-240423.docx
chapter_number: 2
chapter_title: "Structures"
word_count: 41190
---

# Structures

This section specifies the **EMF+** structures and how they are serialized in a **metafile**. EMF+ structures are grouped into the following categories:

| Name | Section | Description |
| --- | --- | --- |
| EMF+ Constants | 2.1 | Specify enumerations, bit flags, and standard identifiers. |
| EMF+ Objects | 2.2 | Specify graphics objects, structure objects, and image effects objects. |
| EMF+ Records | 2.3 | Specify the format of metafile records, which define graphics operations and manage the **playback devi****ce context**. |

This protocol references commonly used data types as defined in [MS-DTYP].

## EMF+ Constants

This section specifies the **EMF+** Constants, which are grouped into the following categories:

| Name | Section | Description |
| --- | --- | --- |
| Enumeration constant types | 2.1.1 | Specify numeric constants used in EMF+ objects and records. |
| Bit Flag constant types | 2.1.2 | Specify properties and options for EMF+ objects and records. |
| Standard Identifier constant types | 2.1.3 | Specify **GUIDs** for EMF+ objects and records. |

### Enumeration Constant Types

The **EMF+** **Enumeration Constants** specify numeric constants that are used in EMF+ objects and records.

The following enumerations are defined:

| Name | Section | Description |
| --- | --- | --- |
| RecordType | 2.1.1.1 | Record types used in EMF+ metafiles. |
| BitmapDataType | 2.1.1.2 | Types of **bitmap** data formats. |
| BrushType | 2.1.1.3 | Types of graphics brushes, which are used to fill graphics regions. |
| CombineMode | 2.1.1.4 | Modes for combining two graphics regions. |
| CompositingMode | 2.1.1.5 | Modes for combining source colors with background colors. The **compositing** mode represents the enable state of **alpha blending**. |
| CompositingQuality | 2.1.1.6 | Levels of quality for creating composite images. |
| CurveAdjustments | 2.1.1.7 | Color curve effects that can be applied to an image. |
| CurveChannel | 2.1.1.8 | Color channels that can be affected by a **color curve effect** adjustment to an image. |
| CustomLineCapDataType | 2.1.1.9 | Types of custom **line cap** data, which specify styles and shapes for the ends of graphics lines. |
| DashedLineCapType | 2.1.1.10 | Types of line caps to use at the ends of dashed lines that are drawn with graphics pens. |
| FilterType | 2.1.1.11 | Types of filtering algorithms that can be used for text and graphics quality enhancement and image rendering. |
| GraphicsVersion | 2.1.1.12 | Versions of operating system graphics that are used to create EMF+ metafiles. |
| HatchStyle | 2.1.1.13 | Hatch patterns used by graphics brushes. A hatch pattern consists of a solid background color and lines drawn over the background. |
| HotkeyPrefix | 2.1.1.14 | Output options for **hotkey prefixes** in graphics text. |
| ImageDataType | 2.1.1.15 | Types of image data formats. |
| InterpolationMode | 2.1.1.16 | Ways to perform **scaling**, including stretching and shrinking. |
| LineCapType | 2.1.1.17 | Types of line caps to use at the ends of lines that are drawn with graphics pens. |
| LineJoinType | 2.1.1.18 | Ways to join two lines that are drawn by the same graphics pen and whose ends meet. |
| LineStyle | 2.1.1.19 | Styles of lines that are drawn with graphics pens. |
| MetafileDataType | 2.1.1.20 | Types of metafiles data that can be embedded in an EMF+ **metafile**. |
| ObjectType | 2.1.1.21 | Types of graphics objects that can be created and used in graphics operations. |
| PathPointType | 2.1.1.22 | Types of points on a graphics **path**. |
| PenAlignment | 2.1.1.23 | The distribution of the width of the pen with respect to the line being drawn. |
| PixelFormat | 2.1.1.24 | Pixel formats that are supported in EMF+ bitmaps. |
| PixelOffsetMode | 2.1.1.25 | How pixels are offset, which specifies the trade-off between rendering speed and quality. |
| RegionNodeDataType | 2.1.1.26 | Types of **region** node data. |
| SmoothingMode | 2.1.1.27 | Types of smoothing to apply to lines, curves and the edges of filled areas to make them appear more continuous or sharply defined. |
| StringAlignment | 2.1.1.28 | Ways to align strings with respect to a text layout rectangle. |
| StringDigitSubstitution | 2.1.1.29 | Ways to substitute digits in a string according to a user's locale or language. |
| StringTrimming | 2.1.1.30 | How to trim characters from a string that is too large for the text layout rectangle. |
| TextRenderingHint | 2.1.1.31 | Types of **text hin****ting** and **anti-aliasing**, which affects the quality of text rendering. |
| UnitType | 2.1.1.32 | Units of measurement in different coordinate systems. |
| WrapMode | 2.1.1.33 | How the pattern from a texture or gradient brush is tiled across a shape or at shape boundaries. |

#### RecordType Enumeration

The RecordType enumeration defines record types used in **EMF+** metafiles.

typedef  enum 

{

  EmfPlusHeader = 0x4001,

  EmfPlusEndOfFile = 0x4002,

  EmfPlusComment = 0x4003,

  EmfPlusGetDC = 0x4004,

  EmfPlusMultiFormatStart = 0x4005,

  EmfPlusMultiFormatSection = 0x4006,

  EmfPlusMultiFormatEnd = 0x4007,

  EmfPlusObject = 0x4008,

  EmfPlusClear = 0x4009,

  EmfPlusFillRects = 0x400A,

  EmfPlusDrawRects = 0x400B,

  EmfPlusFillPolygon = 0x400C,

  EmfPlusDrawLines = 0x400D,

  EmfPlusFillEllipse = 0x400E,

  EmfPlusDrawEllipse = 0x400F,

  EmfPlusFillPie = 0x4010,

  EmfPlusDrawPie = 0x4011,

  EmfPlusDrawArc = 0x4012,

  EmfPlusFillRegion = 0x4013,

  EmfPlusFillPath = 0x4014,

  EmfPlusDrawPath = 0x4015,

  EmfPlusFillClosedCurve = 0x4016,

  EmfPlusDrawClosedCurve = 0x4017,

  EmfPlusDrawCurve = 0x4018,

  EmfPlusDrawBeziers = 0x4019,

  EmfPlusDrawImage = 0x401A,

  EmfPlusDrawImagePoints = 0x401B,

  EmfPlusDrawString = 0x401C,

  EmfPlusSetRenderingOrigin = 0x401D,

  EmfPlusSetAntiAliasMode = 0x401E,

  EmfPlusSetTextRenderingHint = 0x401F,

  EmfPlusSetTextContrast = 0x4020,

  EmfPlusSetInterpolationMode = 0x4021,

  EmfPlusSetPixelOffsetMode = 0x4022,

  EmfPlusSetCompositingMode = 0x4023,

  EmfPlusSetCompositingQuality = 0x4024,

  EmfPlusSave = 0x4025,

  EmfPlusRestore = 0x4026,

  EmfPlusBeginContainer = 0x4027,

  EmfPlusBeginContainerNoParams = 0x4028,

  EmfPlusEndContainer = 0x4029,

  EmfPlusSetWorldTransform = 0x402A,

  EmfPlusResetWorldTransform = 0x402B,

  EmfPlusMultiplyWorldTransform = 0x402C,

  EmfPlusTranslateWorldTransform = 0x402D,

  EmfPlusScaleWorldTransform = 0x402E,

  EmfPlusRotateWorldTransform = 0x402F,

  EmfPlusSetPageTransform = 0x4030,

  EmfPlusResetClip = 0x4031,

  EmfPlusSetClipRect = 0x4032,

  EmfPlusSetClipPath = 0x4033,

  EmfPlusSetClipRegion = 0x4034,

  EmfPlusOffsetClip = 0x4035,

  EmfPlusDrawDriverstring = 0x4036,

  EmfPlusStrokeFillPath = 0x4037,

  EmfPlusSerializableObject = 0x4038,

  EmfPlusSetTSGraphics = 0x4039,

  EmfPlusSetTSClip = 0x403A

} RecordType;

**EmfPlusHeader:  **This record specifies the start of EMF+ data in the **metafile**. It MUST be embedded in the first EMF record after the EMF Header record.

**E****mfPlusEndOfFile:  **This record specifies the end of EMF+ data in the metafile.

**EmfPlusComment:  **This record specifies arbitrary private data.

**EmfPlusGetDC:  **This record specifies that subsequent EMF records ([MS-EMF] section 2.3) encountered in the metafile SHOULD be processed. EMF records cease being processed when the next EMF+ record is encountered.

**EmfPlusMultiFormatStart:  **This record is reserved and MUST NOT be used.

**EmfPlusMultiFormatSection:  **This record is reserved and MUST NOT be used.

**EmfPlusMultiFormatEnd:  **This record is reserved and MUST NOT be used.

**EmfPlusObject:  **This record specifies an object for use in graphics operations.

**EmfPlusClear:  **This record clears the output **coordinate space** and initializes it with a specified background color and transparency.

**EmfPlusFillRects:  **This record defines how to fill the interiors of a series of rectangles, using a specified brush.

**EmfPlusDrawRects:  **This record defines the pen strokes for drawing a series of rectangles.

**EmfPlusFillPolygon:  **This record defines the data to fill the interior of a polygon, using a specified brush.

**EmfPlusDrawLines:  **This record defines the pen strokes for drawing a series of connected lines.

**EmfPlusFillEllipse:  **This record defines how to fill the interiors of an ellipse, using a specified brush.

**EmfPlusDrawEllipse:  **This record defines the pen strokes for drawing an ellipse.

**EmfPlusFillPie:  **This record defines how to fill a section of an interior section of an ellipse using a specified brush.

**EmfPlusDrawPie:  **This record defines pen strokes for drawing a section of an ellipse.

**EmfPlusDrawArc:  **The record defines pen strokes for drawing an arc of an ellipse.

**EmfPlusFillRegion:  **This record defines how to fill the interior of a **region** using a specified brush.

**EmfPlusFillPath:  **The record defines how to fill the interiors of the figures defined in a graphics **path** with a specified brush. A path is an object that defines an arbitrary sequence of lines, curves, and shapes.

**EmfPlusDrawPath:  **The record defines the pen strokes to draw the figures in a graphics path. A path is an object that defines an arbitrary sequence of lines, curves, and shapes.

**EmfPl****usFillClosedCurve:  **This record defines how to fill the interior of a **closed cardinal spline** using a specified brush.

**EmfPlusDrawClosedCurve:  **This record defines the pen and strokes for drawing a closed cardinal spline.

**EmfPlusDrawCurve:  **This record defines the pen strokes for drawing a **cardinal spline**.

**EmfPlusDrawBeziers:  **This record defines the pen strokes for drawing a **Bezier** **spline**.

**EmfPlusDrawImage:  **This record defines a scaled EmfPlusImage object. An image can consist of either **bitmap** or metafile data.

**EmfPlusDrawImagePoints:  **This record defines a scaled EmfPlusImage object inside a parallelogram. An image can consist of either bitmap or metafile data.

**EmfPlusDrawString:  **This record defines a text string based on a font, a layout rectangle, and a format.

**EmfPlusSetRenderingOrigin:  **This record sets the origin of rendering to the specified horizontal and vertical coordinates. This applies to hatch brushes and to 8 and 16 bits per pixel dither patterns.

**EmfPlusSetAntiAliasMode:  **This record defines whether to enable or disable text **anti-aliasing**. Text anti-aliasing is a method of making lines and edges of character glyphs appear smoother when drawn on an output surface.

**EmfPlusSetTextRenderingHint:  **This record defines the process used for rendering text.

**EmfPlusSetTextContrast:  **This record sets text **contrast** according to the specified text **gamma** value.

**EmfPlusSetInterpolationMode:  **This record defines the interpolation mode of an object according to the specified type of image filtering. The interpolation mode influences how **scaling** (stretching and shrinking) is performed.

**EmfPlusSetPixelOffsetMode:  **This record defines the pixel offset mode according to the specified pixel centering value.

**EmfPlusSetCompositingMode:  **This record defines the **compositing** mode according to the state of **alpha blending**, which specifies how source colors are combined with background colors.

**EmfPlusSetCompositingQuality:  **This record defines the compositing quality, which describes the desired level of quality for creating composite images from multiple objects.

**EmfPlusSave:  **This record saves the graphics state, identified by a specified index, on a stack of saved graphics states. Each stack index is associated with a particular saved state, and the index is used by an EmfPlusRestore record to restore the state.

**EmfPlusRestore:  **This record restores the graphics state, identified by a specified index, from a stack of saved graphics states. Each stack index is associated with a particular saved state, and the index is defined by an EmfPlusSave record to save the state.

**EmfPlusBeginContainer:  **This record opens a new graphics state container and specifies a **transform** for it. Graphics containers are used to retain elements of the graphics state.

**EmfPlusBeginContainerNoParams:  **This record opens a new graphics state container.

**EmfPlusEndContainer:  **This record closes a graphics state container that was previously opened by a begin container operation.

**EmfPlusSetWorldTransform:  **This record defines the current **world space** transform in the **playback device context**, according to a specified transform matrix.

**EmfPlusResetWorldTransform:  **This record resets the current world space transform to the identify matrix.

**EmfPlusMultiplyWorldTr****ansform:  **This record multiplies the current world space by a specified transform matrix.

**EmfPlusTranslateWorldTransform:  **This record applies a **translation transform** to the current world space by specified horizontal and vertical distances.

**EmfPlusScaleWorldTransform:  **This record applies a scaling transform to the current world space by specified horizontal and vertical scale factors.

**EmfPlusRotateWorldTransform:  **This record rotates the current world space by a specified angle.

**EmfPlusSetPageTransform:  **This record specifies extra scaling factors for the current world space transform.

**EmfPlusResetClip:  **This record resets the current clipping region for the world space to infinity.

**EmfPlusSetCl****ipRect:  **This record combines the current clipping region with a rectangle.

**EmfPlusSetClipPath:  **This record combines the current clipping region with a graphics path.

**EmfPlusSetClipRegion:  **This record combines the current clipping region with another graphics region.

**EmfPlusOffsetClip:  **This record applies a translation transform on the current clipping region of the world space.

**EmfPlusDrawDriverstring:  **This record specifies text output with character positions.

**EmfPlusStrokeFillPath:  **This record closes any open figures in a path, strokes the outline of the path by using the current pen, and fills its interior by using the current brush.

**EmfPlusSerializableObject:  **This record defines an **image effects** parameter block that has been serialized into a data buffer.

**EmfPlusSetTSGraphics:  **This record specifies the state of a graphics **device context** for a **terminal server**.

**EmfPlusSetTSClip:  **This record specifies clipping areas in the graphics device context for a terminal server.

See section 2.1.1 for the specification of additional enumerations.

#### BitmapDataType Enumeration

The BitmapDataType enumeration defines types of **bitmap** data formats.

typedef  enum 

{

  BitmapDataTypePixel = 0x00000000,

  BitmapDataTypeCompressed = 0x00000001

} BitmapDataType;

**BitmapDataTypePixel:  **A bitmap image with pixel data.

**BitmapDataTypeCompressed:  **An image with compressed data.

Bitmap data is specified by EmfPlusBitmap objects.

See section 2.1.1 for the specification of additional enumerations.

#### BrushType Enumeration

The BrushType enumeration defines types of graphics brushes, which are used to fill graphics regions.

typedef  enum 

{

  BrushTypeSolidColor = 0x00000000,

  BrushTypeHatchFill = 0x00000001,

  BrushTypeTextureFill = 0x00000002,

  BrushTypePathGradient = 0x00000003,

  BrushTypeLinearGradient = 0x00000004

} BrushType;

**BrushTypeSolidColor:  **A solid-color brush, which is characterized by an EmfPlusARGB value.

**BrushTypeHatchFill:  **A hatch brush, which is characterized by a predefined pattern.

**BrushTypeTextureFill:  **A texture brush, which is characterized by an image.

**BrushTypePathGradient:  **A path gradient brush, which is characterized by a color gradient **pat****h** gradient brush data.

**BrushTypeLinearGradient:  BrushData** contains linear gradient brush data.

Graphics brushes are specified by EmfPlusBrush objects.

See section 2.1.1 for the specification of additional enumerations.

#### CombineMode Enumeration

The CombineMode enumeration defines modes for combining two graphics regions. In the following descriptions, the regions to be combined are referred to as the "existing" and "new" regions.

typedef  enum 

{

  CombineModeReplace = 0x00000000,

  CombineModeIntersect = 0x00000001,

  CombineModeUnion = 0x00000002,

  CombineModeXOR = 0x00000003,

  CombineModeExclude = 0x00000004,

  CombineModeComplement = 0x00000005

} CombineMode;

**CombineModeReplace:  **Replace the existing **region** with the new region.

**CombineModeIntersect:  **Replace the existing region with the intersection of the existing region and the new region.

**CombineModeUnion:  **Replace the existing region with the union of the existing and new regions.

**CombineModeXOR:  **Replace the existing region with the XOR of the existing and new regions.

**CombineModeExc****lude:  **Replace the existing region with the part of itself that is not in the new region.

**CombineModeComplement:  **Replace the existing region with the part of the new region that is not in the existing region.

Graphics regions are specified by EmfPlusRegion objects.

See section 2.1.1 for the specification of additional enumerations.

#### CompositingMode Enumeration

The CompositingMode enumeration defines modes for combining source colors with background colors. The **compositing** mode represents the enable state of **alpha blending**.

typedef  enum 

{

  CompositingModeSourceOver = 0x00,

  CompositingModeSourceCopy = 0x01

} CompositingMode;

**CompositingModeSourceOver:  **Enables alpha blending, which specifies that when a color is rendered, it is blended with the background color. The extent of blending is determined by the value of the **alpha** component of the color being rendered.

**Co****mpositingModeSourceCopy:  **Disables alpha blending, which means that when a source color is rendered, it overwrites the background color.

Graphics colors are specified by EmfPlusARGB objects.

See section 2.1.1 for the specification of additional enumerations.

#### CompositingQuality Enumeration

The CompositingQuality enumeration defines levels of quality for creating composite images.<3>

typedef  enum 

{

  CompositingQualityDefault = 0x01,

  CompositingQualityHighSpeed = 0x02,

  CompositingQualityHighQuality = 0x03,

  CompositingQualityGammaCorrected = 0x04,

  CompositingQualityAssumeLinear = 0x05

} CompositingQuality;

**CompositingQualityDefault:  **No **gamma correction** is performed. Gamma correction controls the overall **brightness** and contrast of an image. Without gamma correction, composited images can appear too light or too dark.

**CompositingQualityHighSpeed:  **No gamma correction is performed. **Compositing** speed is favored at the expense of quality. In terms of the result, there is no difference between this value and CompositingQualityDefault.

**CompositingQualityHighQuality:  **Gamma correction is performed. Compositing quality is favored at the expense of speed.

**CompositingQualityGammaCorrected:  **Enable gamma correction for higher-quality compositing with lower speed. In terms of the result, there is no difference between this value and CompositingQualityHighQuality.

**CompositingQualityAssumeLinear:  **No gamma correction is performed; however, using linear values results in better quality than the default at a slightly lower speed.

Graphics colors are specified by EmfPlusARGB objects.

Compositing is done during rendering when source pixels are combined with destination pixels. The compositing quality directly relates to the visual quality of the output and is inversely proportional to the time required for rendering. The higher the quality, the more surrounding pixels need to be taken into account during the compositing operation; hence, the slower the render time.

See section 2.1.1 for the specification of additional enumerations.

#### CurveAdjustments Enumeration

The CurveAdjustments enumeration defines adjustments that can be applied to the **color curve** of an image.

typedef  enum 

{

  AdjustExposure = 0x00000000,

  AdjustDensity = 0x00000001,

  AdjustContrast = 0x00000002,

  AdjustHighlight = 0x00000003,

  AdjustShadow = 0x00000004,

  AdjustMidtone = 0x00000005,

  AdjustWhiteSaturation = 0x00000006,

  AdjustBlackSaturation = 0x00000007

} CurveAdjustments;

**AdjustExposure:  **The simulation of increasing or decreasing the **exposure** of an image.

**AdjustDensity:  **The simulation of increasing or decreasing the **density** of an image.

**AdjustContrast:  **An increase or decrease of the **contrast** of an image.

**AdjustHighlight:  **An increase or decrease of the value of a **color channel** of an image, if that channel already has a value that is above half **intensity**. This adjustment can be used to increase definition in the light areas of an image without affecting the dark areas.

**AdjustShadow:  **An increase or decrease of the value of a color channel of an image, if that channel already has a value that is below half intensity. This adjustment can be used to increase definition in the dark areas of an image without affecting the light areas.

**AdjustMidtone:  **An adjustment that lightens or darkens an image. Color channel values in the middle of the intensity range are altered more than color channel values near the minimum or maximum extremes of intensity. This adjustment can be used to lighten or darken an image without losing the contrast between the darkest and lightest parts of the image.

**AdjustWhiteSaturation:  **An adjustment to the **white saturation** of an image, defined as the maximum value in the range of intensities for a given color channel, whose range is typically 0 to 255.

For example, a white saturation adjustment value of 240 specifies that color channel values in the range 0 to 240 are adjusted so that they spread out over the range 0 to 255, with color channel values greater than 240 set to 255.

**AdjustBlackSaturation:  **An adjustment to the **black saturation** of an image, which is the minimum value in the range of intensities for a given color channel, which is typically 0 to 255.

For example, a black saturation adjustment value of 15 specifies that color channel values in the range 15 to 255 are adjusted so that they spread out over the range 0 to 255, with color channel values less than 15 set to 0.

**Bitmap** images are specified by EmfPlusBitmap objects.

See section 2.1.1 for the specification of additional enumerations.

#### CurveChannel Enumeration

The CurveChannel enumeration defines **color channels** that can be affected by a **color curve effect** adjustment to an image.

typedef  enum 

{

  CurveChannelAll = 0x00000000,

  CurveChannelRed = 0x00000001,

  CurveChannelGreen = 0x00000002,

  CurveChannelBlue = 0x00000003

} CurveChannel;

**CurveChannelAll:  **A color curve adjustment applies to all color channels.

**CurveChannelRed:  **A color curve adjustment applies only to the red color channel.

**CurveChannelGreen:  **A color curve adjustment applies only to the green color channel.

**CurveChannelBlue:  **A color curve adjustment applies only to the blue color channel.

**Bitmap** images are specified by EmfPlusBitmap objects.

See section 2.1.1 for the specification of additional enumerations.

#### CustomLineCapDataType Enumeration

The CustomLineCapDataType enumeration defines types of custom **line cap** data, which specify styles and shapes for the ends of graphics lines.

typedef  enum 

{

  CustomLineCapDataTypeDefault = 0x00000000,

  CustomLineCapDataTypeAdjustableArrow = 0x00000001

} CustomLineCapDataType;

**CustomLineCapDataTypeDefault:**  A default custom line cap.

**CustomLineC****apDataTypeAdjustableArrow:**  An adjustable arrow custom line cap.

Custom line cap data is specified by EmfPlusCustomLineCap objects.

See section 2.1.1 for the specification of additional enumerations.

#### DashedLineCapType Enumeration

The DashedLineCapType enumeration defines types of **line caps** to use at the ends of dashed lines that are drawn with graphics pens.

typedef  enum 

{

  DashedLineCapTypeFlat = 0x00000000,

  DashedLineCapTypeRound = 0x00000002,

  DashedLineCapTypeTriangle = 0x00000003

} DashedLineCapType;

**DashedLineCapTypeFlat:**  A flat dashed line cap.

**DashedLineCapTypeRound:**  A round dashed line cap.

**DashedLineCapTypeTriangle:**  A triangular dashed line cap.

Dashed lines are specified by EmfPlusDashedLineData objects.

See section 2.1.1 for the specification of additional enumerations.

#### FilterType Enumeration

The FilterType enumeration defines types of filtering algorithms that can be used for text and graphics quality enhancement and image rendering.

typedef  enum 

{

  FilterTypeNone = 0x00,

  FilterTypePoint = 0x01,

  FilterTypeLinear = 0x02,

  FilterTypeTriangle = 0x03,

  FilterTypeBox = 0x04,

  FilterTypePyramidalQuad = 0x06,

  FilterTypeGaussianQuad = 0x07

} FilterType;

**FilterTypeNone:  **Filtering is not performed.

**FilterTypePoint:  **Each destination pixel is computed by sampling the nearest pixel from the source image.

**FilterTypeLinear:  **Linear interpolation is performed using the weighted average of a 2x2 area of pixels surrounding the source pixel.

**FilterTypeTriangle:  **Each pixel in the source image contributes equally to the destination image. This is the slowest of filtering algorithms.

**Fi****lterTypeBox:  **A **box filter** algorithm is used, in which each destination pixel is computed by averaging a rectangle of source pixels. This algorithm is useful only when reducing the size of an image.

**FilterTypePyramidalQuad:  **A 4-sample **tent filter** is used.

**FilterTypeGaussianQuad:  **A 4-sample Gaussian filter is used, which creates a **blur effect** on an image.

See section 2.1.1 for the specification of additional enumerations.

#### GraphicsVersion Enumeration

The GraphicsVersion enumeration defines versions of operating system graphics that are used to create **EMF+** metafiles.

typedef  enum 

{

  GraphicsVersion1 = 0x0001,

  GraphicsVersion1_1 = 0x0002

} GraphicsVersion;

**GraphicsVersion1:  ****GDI+** version 1.0.

**GraphicsVersion1_1:  **GDI+ version 1.1.<4>

Graphics versions are specified in EmfPlusGraphicsVersion objects.

See section 2.1.1 for the specification of additional enumerations.

#### HatchStyle Enumeration

The HatchStyle enumeration defines hatch patterns used by graphics brushes. A hatch pattern consists of a solid background color and lines drawn over the background.

typedef  enum 

{

  HatchStyleHorizontal = 0x00000000,

  HatchStyleVertical = 0x00000001,

  HatchStyleForwardDiagonal = 0x00000002,

  HatchStyleBackwardDiagonal = 0x00000003,

  HatchStyleLargeGrid = 0x00000004,

  HatchStyleDiagonalCross = 0x00000005,

  HatchStyle05Percent = 0x00000006,

  HatchStyle10Percent = 0x00000007,

  HatchStyle20Percent = 0x00000008,

  HatchStyle25Percent = 0x00000009,

  HatchStyle30Percent = 0x0000000A,

  HatchStyle40Percent = 0x0000000B,

  HatchStyle50Percent = 0x0000000C,

  HatchStyle60Percent = 0x0000000D,

  HatchStyle70Percent = 0x0000000E,

  HatchStyle75Percent = 0x0000000F,

  HatchStyle80Percent = 0x00000010,

  HatchStyle90Percent = 0x00000011,

  HatchStyleLightDownwardDiagonal = 0x00000012,

  HatchStyleLightUpwardDiagonal = 0x00000013,

  HatchStyleDarkDownwardDiagonal = 0x00000014,

  HatchStyleDarkUpwardDiagonal = 0x00000015,

  HatchStyleWideDownwardDiagonal = 0x00000016,

  HatchStyleWideUpwardDiagonal = 0x00000017,

  HatchStyleLightVertical = 0x00000018,

  HatchStyleLightHorizontal = 0x00000019,

  HatchStyleNarrowVertical = 0x0000001A,

  HatchStyleNarrowHorizontal = 0x0000001B,

  HatchStyleDarkVertical = 0x0000001C,

  HatchStyleDarkHorizontal = 0x0000001D,

  HatchStyleDashedDownwardDiagonal = 0x0000001E,

  HatchStyleDashedUpwardDiagonal = 0x0000001F,

  HatchStyleDashedHorizontal = 0x00000020,

  HatchStyleDashedVertical = 0x00000021,

  HatchStyleSmallConfetti = 0x00000022,

  HatchStyleLargeConfetti = 0x00000023,

  HatchStyleZigZag = 0x00000024,

  HatchStyleWave = 0x00000025,

  HatchStyleDiagonalBrick = 0x00000026,

  HatchStyleHorizontalBrick = 0x00000027,

  HatchStyleWeave = 0x00000028,

  HatchStylePlaid = 0x00000029,

  HatchStyleDivot = 0x0000002A,

  HatchStyleDottedGrid = 0x0000002B,

  HatchStyleDottedDiamond = 0x0000002C,

  HatchStyleShingle = 0x0000002D,

  HatchStyleTrellis = 0x0000002E,

  HatchStyleSphere = 0x0000002F,

  HatchStyleSmallGrid = 0x00000030,

  HatchStyleSmallCheckerBoard = 0x00000031,

  HatchStyleLargeCheckerBoard = 0x00000032,

  HatchStyleOutlinedDiamond = 0x00000033,

  HatchStyleSolidDiamond = 0x00000034

} HatchStyle;

**HatchStyleHorizontal:  **Equally spaced horizontal lines.

**HatchStyleVertical:  **Equally spaced vertical lines.

**HatchStyleForwardDiagonal:  **Lines on a diagonal from upper left to lower right.

**HatchStyleBackwardDiagonal:  **Lines on a diagonal from upper right to lower left.

**HatchStyleLargeGrid:  **Crossing horizontal and vertical lines.

**HatchStyleDiagonalCross:  **Crossing forward diagonal and backward diagonal lines with **anti-aliasing**.

**HatchStyle05Percent:  **A 5-percent hatch, which is the ratio of foreground color to background color equal to 5:100.

**Hatc****hStyle10Percent:  **A 10-percent hatch, which is the ratio of foreground color to background color equal to 10:100.

**HatchStyle20Percent:  **A 20-percent hatch, which is the ratio of foreground color to background color equal to 20:100.

**HatchStyle25Percent:  **A 25-percent hatch, which is the ratio of foreground color to background color equal to 25:100.

**HatchStyle30Percent:  **A 30-percent hatch, which is the ratio of foreground color to background color equal to 30:100.

**HatchStyle40Percent:  **A 40-percent hatch, which is the ratio of foreground color to background color equal to 40:100.

**HatchStyle50Percent:  **A 50-percent hatch, which is the ratio of foreground color to background color equal to 50:100.

**HatchStyle60Percent:  **A 60-percent hatch, which is the ratio of foreground color to background color equal to 60:100.

**HatchStyle70Percent:  **A 70-percent hatch, which is the ratio of foreground color to background color equal to 70:100.

**HatchStyle75Percent:  **A 75-percent hatch, which is the ratio of foreground color to background color equal to 75:100.

**HatchStyle80Percent:  **An 80-percent hatch, which is the ratio of foreground color to background color equal to 80:100.

**HatchStyle90Percent:  **A 90-percent hatch, which is the ratio of foreground color to background color equal to 90:100.

**HatchStyleLightDownwardDiagonal:  **Diagonal lines that slant to the right from top to bottom points with no anti-aliasing. They are spaced 50 percent further apart than lines in the HatchStyleForwardDiagonal pattern

**HatchStyleLightUpwardDiagonal:  **Diagonal lines that slant to the left from top to bottom points with no anti-aliasing. They are spaced 50 percent further apart than lines in the HatchStyleBackwardDiagonal pattern.

**HatchStyleDarkDownwardDiagonal:  **Diagonal lines that slant to the right from top to bottom points with no anti-aliasing. They are spaced 50 percent closer and are twice the width of lines in the HatchStyleForwardDiagonal pattern.

**HatchStyleDarkUpwardDiagonal:  **Diagonal lines that slant to the left from top to bottom points with no anti-aliasing. They are spaced 50 percent closer and are twice the width of lines in the HatchStyleBackwardDiagonal pattern.

**HatchStyleWideDownwardDiagonal:  **Diagonal lines that slant to the right from top to bottom points with no anti-aliasing. They have the same spacing between lines in HatchStyleWideDownwardDiagonal pattern and HatchStyleForwardDiagonal pattern, but HatchStyleWideDownwardDiagonal has the triple line width of HatchStyleForwardDiagonal.

**HatchStyleWideUpwa****rdDiagonal:  **Diagonal lines that slant to the left from top to bottom points with no anti-aliasing. They have the same spacing between lines in HatchStyleWideUpwardDiagonal pattern and HatchStyleBackwardDiagonal pattern, but HatchStyleWideUpwardDiagonal has the triple line width of HatchStyleWideUpwardDiagonal.

**HatchStyleLightVertical:  **Vertical lines that are spaced 50 percent closer together than lines in the HatchStyleVertical pattern.

**HatchStyleLightHorizontal:  **Horizontal lines that are spaced 50 percent closer than lines in the HatchStyleHorizontal pattern.

**HatchStyleNarrowVertical:  **Vertical lines that are spaced 75 percent closer than lines in the HatchStyleVertical pattern; or 25 percent closer than lines in the HatchStyleLightVertical pattern.

**Hatc****hStyleNarrowHorizontal:  **Horizontal lines that are spaced 75 percent closer than lines in the HatchStyleHorizontal pattern; or 25 percent closer than lines in the HatchStyleLightHorizontal pattern.

**HatchStyleDarkVertical:  **Lines that are spaced 50 percent closer than lines in the HatchStyleVertical pattern.

**HatchStyleDarkHorizontal:  **Lines that are spaced 50 percent closer than lines in the HatchStyleHorizontal pattern.

**HatchStyleDashedDownwardDiagonal:  **Dashed diagonal lines that slant to the right from top to bottom points.

**HatchStyleDashedUpwardDiagonal:  **Dashed diagonal lines that slant to the left from top to bottom points.

**HatchStyleDashedHorizontal:  **Dashed horizontal lines.

**HatchStyleDashedVertical:  **Dashed vertical lines.

**HatchStyleSmallConfetti: **** **A pattern of lines that has the appearance of confetti.

**HatchStyleLargeConfetti:  **A pattern of lines that has the appearance of confetti and is composed of larger pieces than the HatchStyleSmallConfetti pattern.

**HatchStyleZigZag:  **Horizontal lines that are composed of zigzags.

**HatchStyleWave:  **Horizontal lines that are composed of tildes.

**HatchStyleDiagonalBrick:  **A pattern of lines that has the appearance of layered bricks that slant to the left from top to bottom points.

**HatchStyleHorizontalBrick:  **A pattern of lines that has the appearance of horizontally layered bricks.

**HatchStyleWeave:  **A pattern of lines that has the appearance of a woven material.

**HatchStylePlaid:  **A pattern of lines that has the appearance of a plaid material.

**HatchStyleDivot:  **A pattern of lines that has the appearance of divots.

**HatchStyleDottedGrid:  **Crossing horizontal and vertical lines, each of which is composed of dots.

**HatchStyleDottedDiamond:  **Crossing forward and backward diagonal lines, each of which is composed of dots.

**H****atchStyleShingle:  **A pattern of lines that has the appearance of diagonally layered shingles that slant to the right from top to bottom points.

**HatchStyleTrellis:  **A pattern of lines that has the appearance of a trellis.

**HatchStyleSphere:  **A pattern of lines that has the appearance of spheres laid adjacent to each other.

**HatchStyleSmallGrid:  **Crossing horizontal and vertical lines that are spaced 50 percent closer together than HatchStyleLargeGrid.

**HatchStyleSmallCheckerBoard:  **A pattern of lines that has the appearance of a checkerboard.

**HatchStyleLargeCheckerBoard:  **A pattern of lines that has the appearance of a checkerboard, with squares that are twice the size of the squares in the **HatchStyleSmallCheckerBoard** pattern.

**HatchStyleOutlinedDiamond:  **Crossing forward and backward diagonal lines; the lines are not anti-aliased.

**HatchStyleSolidDiamond:  **A pattern of lines that has the appearance of a checkerboard placed diagonally.

Graphics brushes are specified by EmfPlusBrush objects.

See section 2.1.1 for the specification of additional enumerations.

#### HotkeyPrefix Enumeration

The HotkeyPrefix enumeration defines output options for **hotkey prefixes** in graphics text.

typedef  enum 

{

  HotkeyPrefixNone = 0x00000000,

  HotkeyPrefixShow = 0x00000001,

  HotkeyPrefixHide = 0x00000002

} HotkeyPrefix;

**HotkeyPrefixNone:  **The hotkey prefix SHOULD NOT be displayed.

**HotkeyPrefixShow:  **No hotkey prefix is defined.

**HotkeyPrefixHide:  **The hotkey prefix SHOULD be displayed.

Graphics text is specified by EmfPlusStringFormat objects.

See section 2.1.1 for the specification of additional enumerations.

#### ImageDataType Enumeration

The ImageDataType enumeration defines types of image data formats.

typedef  enum 

{

  ImageDataTypeUnknown = 0x00000000,

  ImageDataTypeBitmap = 0x00000001,

  ImageDataTypeMetafile = 0x00000002

} ImageDataType;

**ImageDataTypeUnknown:  **The type of image is not known.

**ImageDataTypeBitmap:  **A **bitmap** image.

**ImageDataTypeMetafile:  **A **metafile** image.

Graphics images are specified by EmfPlusImage objects.

See section 2.1.1 for the specification of additional enumerations.

#### InterpolationMode Enumeration

The InterpolationMode enumeration defines ways to perform **scaling**, including stretching and shrinking.

typedef  enum 

{

  InterpolationModeDefault = 0x00,

  InterpolationModeLowQuality = 0x01,

  InterpolationModeHighQuality = 0x02,

  InterpolationModeBilinear = 0x03,

  InterpolationModeBicubic = 0x04,

  InterpolationModeNearestNeighbor = 0x05,

  InterpolationModeHighQualityBilinear = 0x06,

  InterpolationModeHighQualityBicubic = 0x07

} InterpolationMode;

**InterpolationModeDefault:  **The default interpolation mode, which is defined as InterpolationModeBilinear.

**InterpolationModeLowQuality:  **A low-quality interpolation mode, which is defined as InterpolationModeNearestNeighbor.

**InterpolationModeHighQ****uality:  **A high-quality interpolation mode, which is defined as InterpolationModeHighQualityBicubic.

**InterpolationModeBilinear:  **Bilinear interpolation, which uses the closest 2x2 neighborhood of known pixels surrounding the interpolated pixel. The weighted average of these 4 known pixel values determines the value to assign to the interpolated pixel. The result is smoother looking than InterpolationModeNearestNeighbor.

**InterpolationModeBicubic:  **Bicubic interpolation, which uses the closest 4x4 neighborhood of known pixels surrounding the interpolated pixel. The weighted average of these 16 known pixel values determines the value to assign to the interpolated pixel. Because the known pixels are likely to be at varying distances from the interpolated pixel, closer pixels are given a higher weight in the calculation. The result is smoother looking than InterpolationModeBilinear.

**InterpolationModeNearestNeighbor:  **Nearest-neighbor interpolation, which uses only the value of the pixel that is closest to the interpolated pixel. This mode simply duplicates or removes pixels, producing the lowest-quality result among these options.

**InterpolationModeHighQualityBilinear:  **Bilinear interpolation with prefiltering.

**InterpolationModeHighQualityBicubic:  **Bicubic interpolation with prefiltering, which produces the highest-quality result among these options.

To stretch an image, each pixel in the original image SHOULD be mapped to a group of pixels in the larger image. To shrink an image, groups of pixels in the original image SHOULD be mapped to single pixels in the smaller image. The effectiveness of the algorithm that performs these mappings determines the quality of a scaled image. Higher-quality interpolation generally uses more data points and requires more processing time than lower-quality interpolation.

See section 2.1.1 for the specification of additional enumerations.

#### LineCapType Enumeration

The LineCapType enumeration defines types of **line caps** to use at the ends of lines that are drawn with graphics pens.

typedef  enum 

{

  LineCapTypeFlat = 0x00000000,

  LineCapTypeSquare = 0x00000001,

  LineCapTypeRound = 0x00000002,

  LineCapTypeTriangle = 0x00000003,

  LineCapTypeNoAnchor = 0x00000010,

  LineCapTypeSquareAnchor = 0x00000011,

  LineCapTypeRoundAnchor = 0x00000012,

  LineCapTypeDiamondAnchor = 0x00000013,

  LineCapTypeArrowAnchor = 0x00000014,

  LineCapTypeAnchorMask = 0x000000F0,

  LineCapTypeCustom = 0x000000FF

} LineCapType;

**LineCapTypeFlat:  **A squared-off line cap. The end of the line MUST be the last point in the line.

**LineCapTypeSquare:  **A square line cap. The center of the square MUST be located at the last point in the line. The width of the square is the line width.

**LineCapTypeRound:  **A circular line cap. The center of the circle MUST be located at the last point in the line. The diameter of the circle is the line width.

**LineCapTypeTrian****gle:  **A triangular line cap. The base of the triangle MUST be located at the last point in the line. The base of the triangle is the line width.

**LineCapTypeNoAnchor:  **The line end is not anchored.

**LineCapTypeSquareAnchor:  **The line end is anchored with a square line cap. The center of the square MUST be located at the last point in the line. The height and width of the square are the line width.

**LineCapTypeRoundAnchor:  **The line end is anchored with a circular line cap. The center of the circle MUST be located at the last point in the line. The circle SHOULD be wider than the line.

**LineCapTypeDiamondAnchor:  **The line end is anchored with a diamond-shaped line cap, which is a square turned at 45 degrees. The center of the diamond MUST be located at the last point in the line. The diamond SHOULD be wider than the line.

**LineCapTypeArrowAnchor:  **The line end is anchored with an arrowhead shape. The arrowhead point MUST be located at the last point in the line. The arrowhead SHOULD be wider than the line.

**LineCapT****ypeAnchorMask:  **Mask used to check whether a line cap is an anchor cap.

**LineCapTypeCustom:  **A custom line cap.

Graphics line caps are specified by EmfPlusPen objects.

See section 2.1.1 for the specification of additional enumerations.

#### LineJoinType Enumeration

The LineJoinType enumeration defines ways to join two lines that are drawn by the same graphics pen and whose ends meet.

typedef  enum 

{

  LineJoinTypeMiter = 0x00000000,

  LineJoinTypeBevel = 0x00000001,

  LineJoinTypeRound = 0x00000002,

  LineJoinTypeMiterClipped = 0x00000003

} LineJoinType;

**LineJoinTypeMiter:  **A mitered line join.

**Line****JoinTypeBevel:  **A beveled line join.

**LineJoinTypeRound:  **A rounded line join.

**LineJoinTypeMiterClipped:  **A clipped mitered line join.

Graphics lines are specified by EmfPlusPen objects. A line join makes the intersection of the two line ends look more continuous.

See section 2.1.1 for the specification of additional enumerations.

#### LineStyle Enumeration

The LineStyle enumeration defines styles of lines that are drawn with graphics pens.

typedef  enum 

{

  LineStyleSolid = 0x00000000,

  LineStyleDash = 0x00000001,

  LineStyleDot = 0x00000002,

  LineStyleDashDot = 0x00000003,

  LineStyleDashDotDot = 0x00000004,

  LineStyleCustom = 0x00000005

} LineStyle;

**LineStyleSolid:  **A solid line.

**LineStyleDash:  **A dashed line.

**LineStyleDot:  **A dotted line.

**LineStyleDashDot:  **An alternating dash-dot line.

**LineStyleDashDotDot:  **An alternating dash-dot-dot line.

**LineStyleCustom:  **A user-defined, custom dashed line.

Graphics lines are specified by EmfPlusPen objects.

See section 2.1.1 for the specification of additional enumerations.

#### MetafileDataType Enumeration

The MetafileDataType enumeration defines types of metafiles data that can be embedded in an **EMF+** **metafile**.

typedef  enum 

{

  MetafileDataTypeWmf = 0x00000001,

  MetafileDataTypeWmfPlaceable = 0x00000002,

  MetafileDataTypeEmf = 0x00000003,

  MetafileDataTypeEmfPlusOnly = 0x00000004,

  MetafileDataTypeEmfPlusDual = 0x00000005

} MetafileDataType;

**MetafileDataTypeWmf:  **The metafile is a **WMF** metafile [MS-WMF] that specifies graphics operations with WMF records.

**MetafileDataTypeWmfPlaceable:  **The metafile is a WMF metafile that specifies graphics operations with WMF records, and which contains additional header information that makes the WMF metafile device-independent.

**MetafileDataTypeEmf:  **The metafile is an **EMF** metafile that specifies graphics operations with EMF records ([MS-EMF] section 2.3).

**MetafileDataTypeEmfPlusOnly:  **The metafile is an EMF+ metafile that specifies graphics operations with EMF+ records only.

**MetafileDataTypeEmfPlusDual:  **The metafile is an EMF+ metafile that specifies graphics operations with both EMF and EMF+ records.

Embedded metafile data is specified by EmfPlusMetafileData objects.

See section 2.1.1 for the specification of additional enumerations.

#### ObjectType Enumeration

The ObjectType enumeration defines types of graphics objects that can be created and used in graphics operations.

typedef  enum 

{

  ObjectTypeInvalid = 0x00000000,

  ObjectTypeBrush = 0x00000001,

  ObjectTypePen = 0x00000002,

  ObjectTypePath = 0x00000003,

  ObjectTypeRegion = 0x00000004,

  ObjectTypeImage = 0x00000005,

  ObjectTypeFont = 0x00000006,

  ObjectTypeStringFormat = 0x00000007,

  ObjectTypeImageAttributes = 0x00000008,

  ObjectTypeCustomLineCap = 0x00000009

} ObjectType;

**ObjectTypeInvalid:  **The object is not a valid object.

**ObjectTypeBrush:  **An EmfPlusBrush object. Brush objects fill graphics regions.

**ObjectTypePen:  **An EmfPlusPen object. Pen objects draw graphics lines.

**ObjectTypePath:  **An EmfPlusPath object. Path objects specify sequences of lines, curves, and shapes.

**ObjectTypeRegion:  **An EmfPlusRegion object. Region objects specify areas of the output surface.

**ObjectTypeImage:  **An EmfPlusImage object. Image objects encapsulate **bitmaps** and metafiles.

**Obje****ctTypeFont:  **An EmfPlusFont object. Font objects specify font properties, including **typeface** style, **em size**, and **font family**.

**ObjectTypeStringFormat:  **An EmfPlusStringFormat object. String format objects specify text layout, including alignment, orientation, tab stops, clipping, and digit substitution for languages that do not use Western European digits.

**ObjectTypeImageAttributes:  **An EmfPlusImageAttributes object. Image attribute objects specify operations on pixels during image rendering, including color adjustment, **grayscale** adjustment, **gamma correction**, and **color mapping**.

**ObjectTypeCustomLineCap:  **An EmfPlusCustomLineCap object. Custom **line cap** objects specify shapes to draw at the ends of a graphics line, including squares, circles, and diamonds.

Graphics objects are specified by EmfPlusObject records.

See section 2.1.1 for the specification of additional enumerations.

#### PathPointType Enumeration

The PathPointType enumeration defines types of points on a graphics **path**.

typedef  enum 

{

  PathPointTypeStart = 0x00,

  PathPointTypeLine = 0x01,

  PathPointTypeBezier = 0x03

} PathPointType;

**PathPointTypeStart:  **The point is the starting point of a path.

**PathPointTypeLine:  **The point is one of the two endpoints of a line.

**PathPointTypeBezier:  **The point is an endpoint or control point of a cubic **Bezier curve**.

Graphics path point types are specified by EmfPlusPathPointType objects.

See section 2.1.1 for the specification of additional enumerations.

#### PenAlignment Enumeration

The PenAlignment enumeration defines the distribution of the width of the pen with respect to the line being drawn.

typedef  enum 

{

  PenAlignmentCenter = 0x00000000,

  PenAlignmentInset = 0x00000001,

  PenAlignmentLeft = 0x00000002,

  PenAlignmentOutset = 0x00000003,

  PenAlignmentRight = 0x00000004

} PenAlignment;

**PenAlignmentCenter:  **The EmfPlusPen object is centered over the theoretical line.

**PenAlignmentInset:  **The pen is positioned on the inside of the theoretical line.

**PenAlignmentLeft:  **The pen is positioned to the left of the theoretical line.

**PenAlignmentOutset:  **The pen is positioned on the outside of the theoretical line.

**PenAlignmentRi****ght:  **The pen is positioned to the right of the theoretical line.

Graphics pens are specified by EmfPlusPen objects. Pen alignment can be visualized by considering a theoretical one-dimensional line drawn between two specified points. The pen alignment determines the proportion of pen width that is orthogonal to the theoretical line.

See section 2.1.1 for the specification of additional enumerations.

#### PixelFormat Enumeration

The PixelFormat enumeration defines pixel formats that are supported in **EMF+** **bitmaps**.

typedef  enum 

{

  PixelFormatUndefined = 0x00000000,

  PixelFormat1bppIndexed = 0x00030101,

  PixelFormat4bppIndexed = 0x00030402,

  PixelFormat8bppIndexed = 0x00030803,

  PixelFormat16bppGrayScale = 0x00101004,

  PixelFormat16bppRGB555 = 0x00021005,

  PixelFormat16bppRGB565 = 0x00021006,

  PixelFormat16bppARGB1555 = 0x00061007,

  PixelFormat24bppRGB = 0x00021808,

  PixelFormat32bppRGB = 0x00022009,

  PixelFormat32bppARGB = 0x0026200A,

  PixelFormat32bppPARGB = 0x000E200B,

  PixelFormat48bppRGB = 0x0010300C,

  PixelFormat64bppARGB = 0x0034400D,

  PixelFormat64bppPARGB = 0x001A400E

} PixelFormat;

**PixelFormatUndefined:  **The format is not specified.

**PixelFormat1bppIndexed:  **The format is monochrome, and a color palette lookup table is used.

**PixelFormat4bppIndexed:  **The format is 16-color, and a color palette lookup table is used.

**PixelFormat8bppIndexed:  **The format is 256-color, and a color palette lookup table is used.

**PixelFormat16bppGrayScale:  **The format is 16 bits per pixel, grayscale.

**PixelFormat16bppRGB555:  **The format is 16 bits per pixel; 5 bits each are used for the red, green, and blue components. The remaining bit is not used.

**PixelFormat16bppRGB565:  **The format is 16 bits per pixel; 5 bits are used for the red component, 6 bits for the green component, and 5 bits for the blue component.

**PixelFormat16bppARGB1555:  **The format is 16 bits per pixel; 1 bit is used for the alpha component, and 5 bits each are used for the red, green, and blue components.

**PixelFormat24bppRGB:  **The format is 24 bits per pixel; 8 bits each are used for the red, green, and blue components.

**PixelFormat32bppRGB:  **The format is 32 bits per pixel; 8 bits each are used for the red, green, and blue components. The remaining 8 bits are not used.

**PixelFormat32bppARGB:  **The format is 32 bits per pixel; 8 bits each are used for the alpha, red, green, and blue components.

**PixelFormat32bppPARGB:  **The format is 32 bits per pixel; 8 bits each are used for the alpha, red, green, and blue components. The red, green, and blue components are premultiplied according to the alpha component.

**PixelFormat48bppRGB:  **The format is 48 bits per pixel; 16 bits each are used for the red, green, and blue components.

**PixelFormat64bppARGB:  **The format is 64 bits per pixel; 16 bits each are used for the alpha, red, green, and blue components.

**P****ixelFormat64bppPARGB:  **The format is 64 bits per pixel; 16 bits each are used for the alpha, red, green, and blue components. The red, green, and blue components are premultiplied according to the alpha component.

Pixel formats are specified by EmfPlusBitmap objects. They are encoded as follows:

Bits 0-7: Enumeration of the pixel format constants, starting at zero.

Bits 8-15: The total number of bits per pixel.

Bit 16: If set, the color value is indexed into a palette.

Bit 17: If set, the color value is in a **GDI**-supported format.

Bit 18: If set, the color value has an alpha component.

Bit 19: If set, the color value has a premultiplied alpha component.

Bit 20: If set, extended colors, 16 bits per channel, are supported.

Bits 21-31: Reserved.

See section 2.1.1 for the specification of additional enumerations.

#### PixelOffsetMode Enumeration

The PixelOffsetMode enumeration defines how pixels are offset, which specifies the trade-off between rendering speed and quality.

typedef  enum 

{

  PixelOffsetModeDefault = 0x00,

  PixelOffsetModeHighSpeed = 0x01,

  PixelOffsetModeHighQuality = 0x02,

  PixelOffsetModeNone = 0x03,

  PixelOffsetModeHalf = 0x04

} PixelOffsetMode;

**PixelOffsetModeDefault:  **Pixels are centered on integer coordinates, specifying speed over quality.

**PixelOffsetModeHighSpeed:  **Pixels are centered on integer coordinates, as with PixelOffsetModeNone. Higher speed at the expense of quality is specified.

**PixelOffsetModeHighQuality:  **Pixels are centered on half-integer coordinates, as with PixelOffsetModeHalf. Higher quality at the expense of speed is specified.

**PixelOffsetModeNone:  **Pixels are centered on the origin, which means that the pixel covers the area from -0.5 to 0.5 on both the x and y axes and its center is at (0,0).

**PixelOffsetModeHalf:  **Pixels are centered on half-integer coordinates, which means that the pixel covers the area from 0 to 1 on both the x and y axes and its center is at (0.5,0.5). By offsetting pixels during rendering, the render quality can be improved at the cost of render speed.

See section 2.1.1 for the specification of additional enumerations.

#### RegionNodeDataType Enumeration

The RegionNodeDataType enumeration defines types of **region** node data.

typedef  enum 

{

  RegionNodeDataTypeAnd = 0x00000001,

  RegionNodeDataTypeOr = 0x00000002,

  RegionNodeDataTypeXor = 0x00000003,

  RegionNodeDataTypeExclude = 0x00000004,

  RegionNodeDataTypeComplement = 0x00000005,

  RegionNodeDataTypeRect = 0x10000000,

  RegionNodeDataTypePath = 0x10000001,

  RegionNodeDataTypeEmpty = 0x10000002,

  RegionNodeDataTypeInfinite = 0x10000003

} RegionNodeDataType;

**RegionNodeDataTypeAnd:  **A region node with child nodes. A Boolean AND operation SHOULD be applied to the left and right child nodes specified by an EmfPlusRegionNodeChildNodes object.

**RegionNodeDataTypeOr:  **A region node with child nodes. A Boolean OR operation SHOULD be applied to the left and right child nodes specified by an EmfPlusRegionNodeChildNodes object.

**RegionNodeDataTypeXor:  **A region node with child nodes. A Boolean XOR operation SHOULD be applied to the left and right child nodes specified by an EmfPlusRegionNodeChildNodes object.

**RegionNodeDataTypeExclude:  **A region node with child nodes. A Boolean operation, defined as "the part of region 1 that is excluded from region 2", SHOULD be applied to the left and right child nodes specified by an EmfPlusRegionNodeChildNodes object.

**RegionNodeDataTypeComplement:  **A region node with child nodes. A Boolean operation, defined as "the part of region 2 that is excluded from region 1", SHOULD be applied to the left and right child nodes specified by an EmfPlusRegionNodeChildNodes object.

**RegionNodeDataTypeRect:  **A region node with no child nodes. The **RegionNodeData** field SHOULD specify a boundary with an EmfPlusRectF object.

**RegionNodeDataTypeP****ath:  **A region node with no child nodes. The **RegionNodeData** field SHOULD specify a boundary with an EmfPlusRegionNodePath object.

**RegionNodeDataTypeEmpty:  **A region node with no child nodes. The **R****egionNodeData** field SHOULD NOT be present.

**RegionNodeDataTypeInfinite:  **A region node with no child nodes, and its bounds are not defined.

Region node data is specified by EmfPlusRegionNode objects.

See section 2.1.1 for the specification of additional enumerations.

#### SmoothingMode Enumeration

The SmoothingMode enumeration defines smoothing modes to apply to lines, curves, and the edges of filled areas to make them appear more continuous or sharply defined.

typedef  enum 

{

  SmoothingModeDefault = 0x00,

  SmoothingModeHighSpeed = 0x01,

  SmoothingModeHighQuality = 0x02,

  SmoothingModeNone = 0x03,

  SmoothingModeAntiAlias8x4 = 0x04,

  SmoothingModeAntiAlias8x8 = 0x05

} SmoothingMode;

**SmoothingModeDefault:  **Default curve smoothing with no **anti-aliasing**.

**SmoothingModeHighSpeed:  **Best performance with no anti-aliasing.

**SmoothingModeHighQuality:  **Best quality with anti-aliasing.

**SmoothingModeNone:  **No curve smoothing and no anti-aliasing.

**SmoothingModeAntiAlias8x4:  **Anti-aliasing using an 8x4 **box filter**.<5>

**SmoothingModeAntiAlias8x8:  **Anti-aliasing using an 8x8 box filter.<6>

See section 2.1.1 for the specification of additional enumerations.

#### StringAlignment Enumeration

The StringAlignment enumeration defines ways to align strings with respect to a text layout rectangle.

typedef  enum 

{

  StringAlignmentNear = 0x00000000,

  StringAlignmentCenter = 0x00000001,

  StringAlignmentFar = 0x00000002

} StringAlignment;

**StringAlignmentNear:  **String alignment is toward the origin of the layout rectangle. This can be used to align characters along a line or to align text within a rectangle. For a right-to-left layout rectangle, the origin SHOULD be at the upper right.

**StringAlignmentCenter:  **The alignment is centered between the origin and extent of the layout rectangle.

**StringAlignmentFar:  **The alignment is to the right side of the layout rectangle.

See section 2.1.1 for the specification of additional enumerations.

#### StringDigitSubstitution Enumeration

The StringDigitSubstitution enumeration defines ways to substitute digits in a string according to a user's locale or language.

typedef  enum 

{

  StringDigitSubstitutionUser = 0x00000000,

  StringDigitSubstitutionNone = 0x00000001,

  StringDigitSubstitutionNational = 0x00000002,

  StringDigitSubstitutionTraditional = 0x00000003

} StringDigitSubstitution;

**StringDigitSubstitutionUser:  **Use an implementation-defined substitution scheme.

**StringDigitSubstitutionNone:  **Disable substitutions.

**StringDigitSubstitutionNational:  **Substitute digits that correspond with the official national language of the user's locale.

**StringDigitSubstitutionTraditional:  **Substitute digits that correspond to the user's native script or language, which can be different from the official national language of the user's locale.

See section 2.1.1 for the specification of additional enumerations.

#### StringTrimming Enumeration

The StringTrimming enumeration defines how to trim characters from a string that is too large for the text layout rectangle.

typedef  enum 

{

  StringTrimmingNone = 0x00000000,

  StringTrimmingCharacter = 0x00000001,

  StringTrimmingWord = 0x00000002,

  StringTrimmingEllipsisCharacter = 0x00000003,

  StringTrimmingEllipsisWord = 0x00000004,

  StringTrimmingEllipsisPath = 0x00000005

} StringTrimming;

**StringTrimmingNone:  **No trimming is done.

**StringTrimmi****ngCharacter:  **The string is broken at the boundary of the last character that is inside the layout rectangle. This is the default.

**StringTrimmingWord:  **The string is broken at the boundary of the last word that is inside the layout rectangle.

**StringTrimmingEllipsisCharacter:  **The string is broken at the boundary of the last character that is inside the layout rectangle, and an ellipsis (...) is inserted after the character.

**StringTrimmingEllipsisWord:  **The string is broken at the boundary of the last word that is inside the layout rectangle, and an ellipsis (...) is inserted after the word.

**StringTrimmingEllipsisPath:  **The center is removed from the string and replaced by an ellipsis. The algorithm keeps as much of the last portion of the string as possible.

See section 2.1.1 for the specification of additional enumerations.

#### TextRenderingHint Enumeration

The TextRenderingHint enumeration defines types of **text hinting** and **anti-aliasing**, which affects the quality of text rendering.

typedef  enum 

{

  TextRenderingHintSystemDefault = 0x00,

  TextRenderingHintSingleBitPerPixelGridFit = 0x01,

  TextRenderingHintSingleBitPerPixel = 0x02,

  TextRenderingHintAntialiasGridFit = 0x03,

  TextRenderingHintAntialias = 0x04,

  TextRenderingHintClearTypeGridFit = 0x05

} TextRenderingHint;

**TextRenderingHintSystemDefault:  **Each text character SHOULD be drawn using whatever font-smoothing settings have been configured on the operating system.

**TextRenderingHintSingleBitPerPixelGridFit:  **Each text character SHOULD be drawn using its glyph **bitmap**. Smoothing MAY be used to improve the appearance of character glyph stems and curvature.

**TextRenderingHintSingleBitPerPixel:  **Each text character SHOULD be drawn using its glyph bitmap. Smoothing is not used.

**TextRenderingHintAntialiasGridFit:  **Each text character SHOULD be drawn using its anti-aliased glyph bitmap with smoothing. The rendering is high quality because of anti-aliasing, but at a higher performance cost.

**TextRen****deringHintAntialias:  **Each text character is drawn using its anti-aliased glyph bitmap without hinting. Better quality results from anti-aliasing, but stem width differences MAY be noticeable because hinting is turned off.

**TextRenderingHintClearTypeGridFit****:  **Each text character SHOULD be drawn using its **ClearType** glyph bitmap with smoothing. This is the highest-quality text hinting setting, which is used to take advantage of ClearType font features.

See section 2.1.1 for the specification of additional enumerations.

#### UnitType Enumeration

The UnitType enumeration defines units of measurement in different coordinate systems.

typedef  enum 

{

  UnitTypeWorld = 0x00,

  UnitTypeDisplay = 0x01,

  UnitTypePixel = 0x02,

  UnitTypePoint = 0x03,

  UnitTypeInch = 0x04,

  UnitTypeDocument = 0x05,

  UnitTypeMillimeter = 0x06

} UnitType;

**UnitTypeWorld:  **A unit of logical distance within the **world space**.

**UnitTypeDisplay:  **A unit of distance based on the characteristics of the physical display.

**UnitTypePixel:  **A unit of 1 pixel.

**UnitTypePoint:  **A unit of 1 printer's point, or 1/72 inch.

**UnitTypeInch:  **A unit of 1 inch.

**UnitTypeDocument:  **A unit of 1/300 inch.

**UnitTypeMillimeter:  **A unit of 1 millimeter.

See section 2.1.1 for the specification of additional enumerations.

#### WrapMode Enumeration

The WrapMode enumeration defines how the pattern from a texture or gradient brush is tiled across a shape or at shape boundaries, when it is smaller than the area being filled.

typedef  enum 

{

  WrapModeTile = 0x00000000,

  WrapModeTileFlipX = 0x00000001,

  WrapModeTileFlipY = 0x00000002,

  WrapModeTileFlipXY = 0x00000003,

  WrapModeClamp = 0x00000004

} WrapMode;

**WrapModeTile:  **Tiles the gradient or texture.

**WrapModeTileFlipX****:  **Reverses the texture or gradient horizontally, and then tiles the texture or gradient.

**WrapModeTileFlipY:  **Reverses the texture or gradient vertically, and then tiles the texture or gradient.

**WrapModeTileFlipXY:  **Reverses the texture or gradient horizontally and vertically, and then tiles the texture or gradient.

**WrapModeClamp:  **Fixes the texture or gradient to the object boundary.

See section 2.1.1 for the specification of additional enumerations.

### Bit Flag Constant Types

The **Bit Flag** constants specify properties and options for **EMF+** objects and records. In general, bit flags can be combined with Boolean OR operations.

The following bit flags are defined:

| Name | Section | Description |
| --- | --- | --- |
| BrushData | 2.1.2.1 | Properties of graphics brushes. |
| CustomLineCapData | 2.1.2.2 | Data for custom **line caps**. |
| DriverStringOptions | 2.1.2.3 | Properties of graphics text positioning and rendering. |
| FontStyle | 2.1.2.4 | Styles of graphics font **typefaces**. |
| PaletteStyle | 2.1.2.5 | Properties of graphics **palettes**. |
| PathPointType | 2.1.2.6 | Type properties of points on graphics paths. |
| PenData | 2.1.2.7 | Properties of graphics pens. |
| StringFormat | 2.1.2.8 | Options for graphics text layout. |

#### BrushData Flags

The BrushData flags specify properties of graphics brushes, including the presence of optional data fields. These flags can be combined to specify multiple options.

| Constant/value | Description |
| --- | --- |
| BrushDataPath0x00000001 | This flag is meaningful in EmfPlusPathGradientBrushData objects.If set, an EmfPlusBoundaryPathData object is specified in the **BoundaryData** field of the brush data object.If clear, an EmfPlusBoundaryPointData object is specified in the **BoundaryData** field of the brush data object. |
| BrushDataTransform0x00000002 | This flag is meaningful in EmfPlusLinearGradientBrushData objects, EmfPlusPathGradientBrushData objects, and EmfPlusTextureBrushData objects.If set, a 2x3 **world space** to **device space** **transform** matrix is specified in the **OptionalData** field of the brush data object. |
| BrushDataPresetColors0x00000004 | This flag is meaningful in EmfPlusLinearGradientBrushData and EmfPlusPathGradientBrushData objects.If set, an EmfPlusBlendColors object is specified in the **OptionalData** field of the brush data object. |
| BrushDataBlendFactorsH0x00000008 | This flag is meaningful in EmfPlusLinearGradientBrushData and EmfPlusPathGradientBrushData objects.If set, an EmfPlusBlendFactors object that specifies a blend pattern along a horizontal gradient is specified in the **OptionalData** field of the brush data object. |
| BrushDataBlendFactorsV0x00000010 | This flag is meaningful in EmfPlusLinearGradientBrushData objects.If set, an EmfPlusBlendFactors object that specifies a blend pattern along a vertical gradient is specified in the **OptionalData** field of the brush data object.<7> |
| BrushDataFocusScales0x00000040 | This flag is meaningful in EmfPlusPathGradientBrushData objects.If set, an EmfPlusFocusScaleData object is specified in the **OptionalData** field of the brush data object. |
| BrushDataIsGammaCorrected0x00000080 | This flag is meaningful in EmfPlusLinearGradientBrushData, EmfPlusPathGradientBrushData, and EmfPlusTextureBrushData objects.If set, the brush MUST already be **gamma corrected**; that is, output brightness and intensity have been corrected to match the input image. |
| BrushDataDoNotTransform0x00000100 | This flag is meaningful in EmfPlusTextureBrushData objects.If set, a world space to device space transform SHOULD NOT be applied to the texture brush. |

Graphics brushes are specified by EmfPlusBrush objects.

See section 2.1.2 for the specification of additional bit flags.

#### CustomLineCapData Flags

The CustomLineCapData flags specify data for custom **line caps**. These flags can be combined to specify multiple options.

| Constant/value | Description |
| --- | --- |
| CustomLineCapDataFillPath0x00000001 | If set, an EmfPlusFillPath object is specified in the **OptionalData** field of the EmfPlusCustomLineCapData object for filling the custom line cap. |
| CustomLineCapDataLinePath0x00000002 | If set, an EmfPlusLinePath object is specified in the **OptionalData** field of the EmfPlusCustomLineCapData object for outlining the custom line cap. |

Custom graphics line caps are specified by EmfPlusCustomLineCap objects.

See section 2.1.2 for the specification of additional bit flags.

#### DriverStringOptions Flags

The DriverStringOptions flags specify properties of graphics text positioning and rendering. These flags can be combined to specify multiple options.

| Constant/value | Description |
| --- | --- |
| DriverStringOptionsCmapLookup0x00000001 | If set, the positions of character glyphs SHOULD be specified in a character map lookup table. If clear, the glyph positions SHOULD be obtained from an array of coordinates. |
| DriverStringOptionsVertical0x00000002 | If set, the string SHOULD be rendered vertically.If clear, the string SHOULD be rendered horizontally. |
| DriverStringOptionsRealizedAdvance0x00000004 | If set, character glyph positions SHOULD be calculated relative to the position of the first glyph.<8>If clear, the glyph positions SHOULD be obtained from an array of coordinates. |
| DriverStringOptionsLimitSubpixel0x00000008 | If set, less memory SHOULD be used to cache anti-aliased glyphs, which produces lower quality text rendering.If clear, more memory SHOULD be used, which produces higher quality text rendering. |

Graphics text output is specified in EmfPlusDrawDriverString records.

See section 2.1.2 for the specification of additional bit flags.

#### FontStyle Flags

The FontStyle flags specify styles of graphics font **typefaces**. These flags can be combined to specify multiple options.

| Constant/value | Description |
| --- | --- |
| FontStyleBold0x00000001 | If set, the font typeface is rendered with a heavier weight or thickness.If clear, the font typeface is rendered with a normal thickness. |
| FontStyleItalic0x00000002 | If set, the font typeface is rendered with the vertical stems of the characters at an increased angle or slant relative to the **baseline**.If clear, the font typeface is rendered with the vertical stems of the characters at a normal angle. |
| FontStyleUnderline0x00000004 | If set, the font typeface is rendered with a line underneath the baseline of the characters.If clear, the font typeface is rendered without a line underneath the baseline. |
| FontStyleStrikeout0x00000008 | If set, the font typeface is rendered with a line parallel to the baseline drawn through the middle of the characters.If clear, the font typeface is rendered without a line through the characters. |

Graphics font typefaces are specified by EmfPlusFont objects.

See section 2.1.2 for the specification of additional bit flags.

#### PaletteStyle Flags

The PaletteStyle flags specify properties of graphics **palettes**. These flags can be combined to specify multiple options.

| Constant/value | Description |
| --- | --- |
| PaletteStyleHasAlpha0x00000001 | If set, one or more of the palette entries MUST contain **alpha** transparency information. |
| PaletteStyleGrayScale0x00000002 | If set, the palette MUST contain only **grayscale** entries. |
| PaletteStyleHalftone0x00000004 | If set, the palette MUST contain discrete color values that can be used for **halftoning**. |

Graphics palettes are specified by EmfPlusPalette objects.

See section 2.1.2 for the specification of additional bit flags.

#### PathPointType Flags

The PathPointType flags specify type properties of points on graphics paths. These flags can be combined to specify multiple options.

| Constant/value | Description |
| --- | --- |
| PathPointTypeDashMode0x01 | A line segment that passes through the point is dashed. |
| PathPointTypePathMarker0x02 | The point is a position marker. |
| PathPointTypeCloseSubpath0x08 | The point is the endpoint of a subpath. |

Graphics paths are specified by EmfPlusPath objects.

See section 2.1.2 for the specification of additional bit flags.

#### PenData Flags

The PenData flags specify properties of graphics pens, including the presence of optional data fields. These flags can be combined to specify multiple options.

| Constant/value | Description |
| --- | --- |
| PenDataTransform0x00000001 | If set, a 2x3 **transform** matrix is specified in the **OptionalData** field of an EmfPlusPenData object. |
| PenDataStartCap0x00000002 | If set, the style of a starting **line cap** is specified in the **OptionalData** field of an EmfPlusPenData object. |
| PenDataEndCap0x00000004 | Indicates whether the style of an ending line cap is specified in the **OptionalData** field of an EmfPlusPenData object. |
| PenDataJoin0x00000008 | Indicates whether a line join type is specified in the **OptionalData** field of an EmfPlusPenData object. |
| PenDataMiterLimit0x00000010 | Indicates whether a miter limit is specified in the **OptionalData** field of an EmfPlusPenData object. |
| PenDataLineStyle0x00000020 | Indicates whether a line style is specified in the **OptionalData** field of an EmfPlusPenData object. |
| PenDataDashedLineCap0x00000040 | Indicates whether a dashed line cap is specified in the **OptionalData** field of an EmfPlusPenData object. |
| PenDataDashedLineOffset0x00000080 | Indicates whether a dashed line offset is specified in the **OptionalData** field of an EmfPlusPenData object. |
| PenDataDashedLine0x00000100 | Indicates whether an EmfPlusDashedLineData object is specified in the **OptionalData** field of an EmfPlusPenData object. |
| PenDataNonCenter0x00000200 | Indicates whether a pen alignment is specified in the **OptionalData** field of an EmfPlusPenData object. |
| PenDataCompoundLine0x00000400 | Indicates whether the length and content of a EmfPlusCompoundLineData object are present in the **OptionalData** field of an EmfPlusPenData object. |
| PenDataCustomStartCap0x00000800 | Indicates whether an EmfPlusCustomStartCapData object is specified in the **OptionalData** field of an EmfPlusPenData object. |
| PenDataCustomEndCap0x00001000 | Indicates whether an EmfPlusCustomEndCapData object is specified in the **OptionalData** field of an EmfPlusPenData object. |

Graphics pens are specified by EmfPlusPen objects.

See section 2.1.2 for the specification of additional bit flags.

#### StringFormat Flags

The StringFormat flags specify options for graphics text layout, including direction, clipping and font handling. These flags can be combined to specify multiple options.

| Constant/value | Description |
| --- | --- |
| StringFormatDirectionRightToLeft0x00000001 | If set, the reading order of the string SHOULD be right to left. For horizontal text, this means that characters are read from right to left. For vertical text, this means that columns are read from right to left.If clear, horizontal or vertical text SHOULD be read from left to right. |
| StringFormatDirectionVertical0x00000002 | If set, individual lines of text SHOULD be drawn vertically on the display device.If clear, individual lines of text SHOULD be drawn horizontally, with each new line below the previous line. |
| StringFormatNoFitBlackBox0x00000004 | If set, parts of characters MUST be allowed to overhang the text layout rectangle.If clear, characters that overhang the boundaries of the text layout rectangle MUST be repositioned to avoid overhang.An italic, "f" is an example of a character that can have overhanging parts. |
| StringFormatDisplayFormatControl0x00000020 | If set, control characters SHOULD appear in the output as representative **Unicode** glyphs. |
| StringFormatNoFontFallback0x00000400 | If set, an alternate font SHOULD be used for characters that are not supported in the requested font.If clear, a character missing from the requested font SHOULD appear as a "font missing" character, which MAY be an open square. |
| StringFormatMeasureTrailingSpaces0x00000800 | If set, the space at the end of each line MUST be included in measurements of string length.If clear, the space at the end of each line MUST be excluded from measurements of string length. |
| StringFormatNoWrap0x00001000 | If set, a string that extends past the end of the text layout rectangle MUST NOT be wrapped to the next line.If clear, a string that extends past the end of the text layout rectangle MUST be broken at the last word boundary within the bounding rectangle, and the remainder of the string MUST be wrapped to the next line. |
| StringFormatLineLimit0x00002000 | If set, whole lines of text SHOULD be output and SHOULD NOT be clipped by the string's layout rectangle.If clear, text layout SHOULD continue until all lines are output, or until additional lines would not be visible as a result of clipping.This flag can be used either to deny or allow a line of text to be partially obscured by a layout rectangle that is not a multiple of line height. For all text to be visible, a layout rectangle at least as tall as the height of one line. |
| StringFormatNoClip0x00004000 | If set, text extending outside the string layout rectangle SHOULD be allowed to show.If clear, all text that extends outside the layout rectangle SHOULD be clipped. |
| StringFormatBypassGDI0x80000000 | This flag MAY be used to specify an implementation-specific process for rendering text.<9> |

Graphics text layout is specified by EmfPlusStringFormat objects.

See section 2.1.2 for the specification of additional bit flags.

### Standard Identifier Constant Types

The Standard Identifier Constants specify values used in **EMF+** objects and records.

The following types of standard identifiers are defined:

| Name | Section | Description |
| --- | --- | --- |
| ImageEffects Identifiers | 2.1.3.1 | **GUIDs** that identify **image effects** capabilities supported by graphics devices. |

#### ImageEffects Identifiers

The ImageEffects identifiers define standard **GUIDs** for specifying graphics **image effects**. These identifiers are used by **device drivers** to publish their levels of support for these effects. The identifier constants are defined using the GUID curly-braced string representation ([MS-DTYP] section 2.3.4.3).

| Constant/value | Description |
| --- | --- |
| BlurEffectGuid{633C80A4-1843-482B-9EF2-BE2834C5FDD4} | The **blur effect**. |
| BrightnessContrastEffectGuid{D3A1DBE1-8EC4-4C17-9F4C-EA97AD1C343D} | The **bri****ghtness contrast effect**. |
| ColorBalanceEffectGuid{537E597D-251E-48DA-9664-29CA496B70F8} | The **color balance effect**. |
| ColorCurveEffectGuid{DD6A0022-58E4-4A67-9D9B-D48EB881A53D} | The **color curve effect**.<10> |
| ColorLookupTableEffectGuid{A7CE72A9-0F7F-40D7-B3CC-D0C02D5C3212} | The **color lookup table effect**. |
| ColorMatrixEffectGuid{718F2615-7933-40E3-A511-5F68FE14DD74} | The **color matrix effect**. |
| HueSaturationLightnessEffectGuid{8B2DD6C3-EB07-4D87-A5F0-7108E26A9C5F} | The **hue saturation lightness effect**. |
| LevelsEffectGuid{99C354EC-2A31-4F3A-8C34-17A803B33A25} | The **levels effect**. |
| RedEyeCorrectionEffectGuid{74D29D05-69A4-4266-9549-3CC52836B632} | The **red-eye correction effect**. |
| SharpenEffectGuid{63CBF3EE-C526-402C-8F71-62C540BF5142} | The **sharpen effect**. |
| TintEffectGuid{1077AF00-2848-4441-9489-44AD4C2D7A2C} | The **tint effect**. |

Image effects identifiers and Image Effects Parameter Blocks are specified by EmfPlusSerializableObject records for EmfPlusDrawImagePoints records.

## EMF+ Objects

This section specifies **EMF+** objects, which are grouped into the following categories:

| Name | Section | Description |
| --- | --- | --- |
| Graphics object types | 2.2.1 | Specify parameters for graphics output. They are part of the **play****back device context** and are persistent during the playback of an EMF+ **metafile**. |
| Structure object types | 2.2.2 | Specify containers for data structures that are embedded in EMF+ objects and records. Structure objects, unlike graphics objects, are not explicitly created; they are components that make up more complex structures. |
| Image Effects object types | 2.2.3 | Specify parameters for graphics **image effects**, which can be applied to **bitmap** images. |

### Graphics Object Types

The **Graphics Objects** specify parameters for graphics output. They are part of the **playback device context** and are persistent during the playback of an **EMF+** **metafile**.

The following types of graphics objects are defined:

| Name | Section | Description |
| --- | --- | --- |
| EmfPlusBrush | 2.2.1.1 | A graphics brush for the filling of figures. |
| EmfPlusCustomLineCap | 2.2.1.2 | The shape to use at the ends of a line drawn by a graphics pen. |
| EmfPlusFont | 2.2.1.3 | Properties that determine the appearance of text, including **typeface**, size, and style. |
| EmfPlusImage | 2.2.1.4 | A graphics image in the form of a **bitmap** or metafile. |
| EmfPlusImageAttributes | 2.2.1.5 | How bitmap and metafile image colors are manipulated during rendering. |
| EmfPlusPath | 2.2.1.6 | A series of line and curve segments. |
| EmfPlusPen | 2.2.1.7 | A graphics pen for the drawing of lines. |
| EmfPlusRegion | 2.2.1.8 | Line and curve segments that define a nonrectilinear shape. |
| EmfPlusStringFormat | 2.2.1.9 | Text layout, display manipulations, and language identification. |

Graphics objects are explicitly created by EmfPlusObject records (section 2.3.5.1), and they can be used in any number of graphics operations. An implementation is responsible for keeping track of graphics objects during playback of the metafile. A conceptual model for managing EMF+ graphics objects is described in Managing Graphics Objects (section 3.1.2).

#### EmfPlusBrush Object

The **EmfPlusBrush** object specifies a graphics brush for filling regions.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Version |
| Type |
| BrushData (variable) |
| ... |

**Version (4 bytes): **An EmfPlusGraphicsVersion object (section 2.2.2.19) that specifies the version of operating system graphics that was used to create this object.

**Type (4 bytes): **An unsigned integer that specifies the type of brush, which determines the contents of the **BrushData** field. This value is defined in the BrushType enumeration (section 2.1.1.3).

**BrushData (variable): **Variable-length data that defines the brush object specified in the **Type** field. The content and format of the data can be different for every brush type.

This object is generic and is used to specify different types of brush data, including the following objects:

EmfPlusHatchBrushData object (section 2.2.2.20)

EmfPlusLinearGradientBrushData object (section 2.2.2.24)

EmfPlusPathGradientBrushData object (section 2.2.2.29)

EmfPlusSolidBrushData object (section 2.2.2.43)

EmfPlusTextureBrushData object (section 2.2.2.45)

See section 2.2.1 for the specification of additional graphics objects.

#### EmfPlusCustomLineCap Object

The **EmfPlusCustomLineCap** object specifies the shape to use at the ends of a line drawn by a graphics pen.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Version |
| Type |
| CustomLineCapData (variable) |
| ... |

**Version (4 bytes): **An EmfPlusGraphicsVersion object (section 2.2.2.19) that specifies the version of operating system graphics that was used to create this object.

**Type (4 bytes): **A signed integer that specifies the type of custom **line cap** object, which determines the contents of the **CustomLineCapData** field. This value is defined in the CustomLineCapDataType enumeration (section 2.1.1.9).

**C****ustomLineCapData (variable): **Variable-length data that defines the custom line cap data object specified in the **Type** field. The content and format of the data can be different for every custom line cap type.

This object is generic and is used to specify different types of custom line cap data, including:

An EmfPlusCustomLineCapArrowData object (section 2.2.2.12); and

An EmfPlusCustomLineCapData object (section 2.2.2.13).

See section 2.2.1 for the specification of additional graphics objects.

#### EmfPlusFont Object

The **EmfPlusFont** object specifies properties that determine the appearance of text, including **typeface**, size, and style.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Version |
| EmSize |
| SizeUnit |
| FontStyleFlags |
| Reserved |
| Length |
| FamilyName (variable) |
| ... |

**Version (4 bytes): **An EmfPlusGraphicsVersion object (section 2.2.2.19) that specifies the version of operating system graphics that was used to create this object.

**EmSize (4 bytes): **A floating-point value that specifies the **em size** of the font in units specified by the **SizeUnit** field.

**SizeUnit (4 bytes): **An unsigned integer that specifies the units used for the **EmSize** field. These are typically the units that were employed when designing the font. The value is in the UnitType enumeration (section 2.1.1.32).<11>

**FontStyleFlags (4 bytes): **A signed integer that specifies attributes of the character glyphs that affect the appearance of the font, such as bold and italic. This value is composed of FontStyle flags (section 2.1.2.4).

**Reserved (4 bytes): **An unsigned integer that is reserved and MUST be ignored.

**Length (4 bytes): **An unsigned integer that specifies the number of characters in the **FamilyName** field.

**FamilyName (variable): **A string of **Length** **Unicode** characters that contains the name of the **font family**.

See section 2.2.1 for the specification of additional graphics objects.

#### EmfPlusImage Object

The **EmfPlusImage** object specifies a graphics image in the form of a **bitmap** or **metafile**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Version |
| Type |
| ImageData (variable) |
| ... |

**Version (4 bytes): **An EmfPlusGraphicsVersion object (section 2.2.2.19) that specifies the version of operating system graphics that was used to create this object.

**Type (4 bytes): **An unsigned integer that specifies the type of data in the **ImageData** field. This value is defined in the ImageDataType enumeration (section 2.1.1.15).

**ImageDat****a (variable): **Variable-length data that defines the image data specified in the **Type** field. The content and format of the data can be different for every image type.

This object is generic and is used to specify different types of image data, including:

An EmfPlusBitmap object (section 2.2.2.2); and

An EmfPlusMetafile object (section 2.2.2.27).

See section 2.2.1 for the specification of additional graphics objects.

#### EmfPlusImageAttributes Object

The **EmfPlusImageAttributes** object specifies how **bitmap** image colors are manipulated during rendering.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Version |
| Reserved1 |
| WrapMode |
| ClampColor |
| ObjectClamp |
| Reserved2 |

**Version (4 bytes): **An EmfPlusGraphicsVersion object (section 2.2.2.19) that specifies the version of operating system graphics that was used to create this object.

**Reserved1 (4 bytes): **A field that is not used and MUST be ignored.

**WrapMode (4 bytes): **An unsigned integer that specifies how to handle edge conditions with a value from the WrapMode enumeration (section 2.1.1.33).

**ClampColor (4 bytes): **An EmfPlusARGB object (section 2.2.2.1) that specifies the edge color to use when the **WrapMode** value is **WrapModeClamp**. This color is visible when the source rectangle processed by an EmfPlusDrawImage record (section 2.3.4.8) is larger than the image itself.

**ObjectClamp (4 bytes): **A signed integer that specifies the object clamping behavior. It is not used until this object is applied to an image being drawn. This value MUST be one of the values defined in the following table.

| Value | Meaning |
| --- | --- |
| RectClamp0x00000000 | The object is clamped to a rectangle. |
| BitmapClamp0x00000001 | The object is clamped to a bitmap. |

**Reserved2 (4 bytes): **A value that SHOULD be set to zero and MUST be ignored upon receipt.

See section 2.2.1 for the specification of additional graphics objects.

#### EmfPlusPath Object

The **Em****fPlusPath** object specifies a series of line and curve segments that form a graphics path. The order for Bezier data points is the start point, control point 1, control point 2, and end point. For more information see [MSDN-DrawBeziers]. 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Version |
| PathPointCount |
| PathPointFlags |
| PathPoints (variable) |
| ... |
| PathPointTypes (variable) |
| ... |
| AlignmentPadding (variable) |
| ... |

**Version (4 bytes): **An EmfPlusGraphicsVersion object (section 2.2.2.19) that specifies the version of operating system graphics that was used to create this object.

**PathPointCount (4 bytes): **An unsigned integer that specifies the number of points and associated point types that are defined by this object.

**PathPointFlags (4 bytes): **An unsigned integer that specifies how to interpret the points and associated point types that are defined by this object.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | R | 0 | 0 | C | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

**R (1 bit):** If this flag is set, the **C **flag is undefined and MUST be ignored. The **R** flag specifies whether the **PathPoints** are relative or absolute locations in the **coordinate space**, and whether the **PathPointTypes** are run-length encoded. See **PathPoints** and **PathPointTypes** for details.

**C (1 bit): **If the **R** flag is clear, this flag specifies the type of objects in the **PathPoints** array. See **PathPoints** and **PathPointTypes** for details.

**PathPoints (variable): **An array of **PathPointCount** points that specify the **path**. The type of objects in this array is specified by the **PathPointFlags** field, as follows:

If the **R** flag is set, the points are relative locations specified by EmfPlusPointR objects (section 2.2.2.37).

If the **R** flag is clear and the **C** flag is set, the points are absolute locations specified by EmfPlusPoint objects (section 2.2.2.35).

If the **R** flag is clear and the **C** flag is clear, the points are absolute locations specified by EmfPlusPointF objects (section 2.2.2.36).

**PathPointTypes (variable): **An array of **PathPointCount** objects that specifies how the points in the **PathP****oints** field are used to draw the path. The type of objects in this array is specified by the **PathPointFlags** field, as follows:

If the **R** flag is set, the point types are specified by EmfPlusPathPointTypeRLE objects (section 2.2.2.32), which use **run-length encoding (RLE) compression** ([MS-WMF] section 3.1.6).

If the **R** flag is clear, the point types are specified by EmfPlusPathPointType objects (section 2.2.2.31).

**AlignmentPadding (variable): **An optional array of up to 3 bytes that pads the record so that its total size is a multiple of 4 bytes. This field MUST be ignored.

See section 2.2.1 for the specification of additional graphics objects.

#### EmfPlusPen Object

The **EmfPlusPen** object specifies a graphics pen for the drawing of lines.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Version |
| Type |
| PenData (variable) |
| ... |
| BrushObject (variable) |
| ... |

**Version (4 bytes): **An EmfPlusGraphicsVersion object (section 2.2.2.19) that specifies the version of operating system graphics that was used to create this object.

**Type (4 bytes): **This field MUST be set to zero.

**Pen****Data (variable): **An EmfPlusPenData object (section 2.2.2.33) that specifies properties of the graphics pen.

**BrushObject (variable): **An EmfPlusBrush object (section 2.2.1.1) that specifies a graphics brush associated with the pen.

See section 2.2.1 for the specification of additional graphics objects.

#### EmfPlusRegion Object

The **EmfPlusRegion** object specifies line and curve segments that define a nonrectilinear shape.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Version |
| RegionNodeCount |
| RegionNode (variable) |
| ... |

**Version (4 bytes): **An EmfPlusGraphicsVersion object (section 2.2.2.19) that specifies the version of operating system graphics that was used to create this object.

**RegionNodeCount**** (4 bytes): **An unsigned integer that specifies the number of child nodes in the **RegionNode** field.

**RegionNode (variable): **An array of **RegionNodeCount**+1 EmfPlusRegionNode objects (section 2.2.2.40). Regions are specified as a binary tree of **region** nodes, and each node MUST either be a terminal node or specify one or two child nodes. RegionNode MUST contain at least one element.

See section 2.2.1 for the specification of additional graphics objects.

#### EmfPlusStringFormat Object

The **EmfPlusStringFormat** object specifies text layout, display manipulations, and language identification.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Version |
| StringFormatFlags |
| Language |
| StringAlignment |
| LineAlign |
| DigitSubstitution |
| DigitLanguage |
| FirstTabOffset |
| HotkeyPrefix |
| LeadingMargin |
| TrailingMargin |
| Tracking |
| Trimming |
| TabStopCount |
| RangeCount |
| StringFormatData (variable) |
| ... |

**Version (4 bytes): **An EmfPlusGraphicsVersion object (section 2.2.2.19) that specifies the version of operating system graphics that was used to create this object.

**StringFormatFlags (4 bytes): **An unsigned integer that specifies text layout options for formatting, clipping and font handling. This value is composed of StringFormat flags (section 2.1.2.8).

**Language (4 bytes): **An EmfPlusLanguageIdentifier object (section 2.2.2.23) that specifies the language to use for the string. 

**StringAlignment (4 bytes): **An unsigned integer that specifies how to align the string horizontally in the layout rectangle. This value is defined in the StringAlignment enumeration (section 2.1.1.28).

**LineAlign (4 bytes): **An unsigned integer that specifies how to align the string vertically in the layout rectangle. This value is defined in the StringAlignment enumeration.

**DigitSubstitution (4 by****tes): **An unsigned integer that specifies how to substitute numeric digits in the string according to a locale or language. This value is defined in the StringDigitSubstitution enumeration (section 2.1.1.29).

**DigitLanguage (4 bytes): **An EmfPlusLanguageIdentifier object that specifies the language to use for numeric digits in the string. For example, if this string contains Arabic digits, this field MUST contain a language identifier that specifies an Arabic language.

**FirstTabOffset (4 bytes): **A floating-point value that specifies the number of spaces between the beginning of a text line and the first tab stop.

**HotkeyPrefix (4 bytes): **A signed integer that specifies the type of processing that is performed on a string when a keyboard shortcut prefix (that is, an ampersand) is encountered. Basically, this field specifies whether to display keyboard shortcut prefixes that relate to text. The value is defined in the HotkeyPrefix enumeration (section 2.1.1.14).

**LeadingMargin (4 bytes): **A floating-point value that specifies the length of the space to add to the starting position of a string. The default is 1/6 inch; for typographic fonts, the default value is 0.

**TrailingMargin (4 bytes): **A floating-point value that specifies the length of the space to leave following a string. The default is 1/6 inch; for typographic fonts, the default value is 0.

**Tracking (4 bytes): **A floating-point value that specifies the ratio of the horizontal space allotted to each character in a specified string to the font-defined width of the character. Large values for this property specify ample space between characters; values less than 1 can produce character overlap. The default is 1.03; for typographic fonts, the default value is 1.00.

**Trimming (4 bytes): **How to trim characters from a string that is too large to fit into a layout rectangle. This value is defined in the StringTrimming enumeration (section 2.1.1.30).

**TabStopCount (4 bytes): **A signed integer that specifies the number of tab stops defined in the **StringFormatData** field.

**RangeCount (4 bytes): **A signed integer that specifies the number of EmfPlusCharacterRange object (section 2.2.2.8) defined in the **StringFormatData** field.

**StringFormatData (variable): **An EmfPlusStringFormatData object (section 2.2.2.44) that specifies optional text layout data.

See section 2.2.1 for the specification of additional graphics objects.

### Structure Object Types

The **Structure Objects** specify containers for data structures that are embedded in **EMF+** **metafile** records. Structure objects, unlike graphics objects, are not explicitly created; they are components that make up more complex structures.

The following types of structure objects are defined.

| Name | Section | Description |
| --- | --- | --- |
| EmfPlusARGB | 2.2.2.1 | A color as a combination of **RGB** and **alpha**. |
| EmfPlusBitmap | 2.2.2.2 | A **bitmap** image. |
| EmfPlusBitmapData | 2.2.2.3 | A bitmap image with pixel data. |
| EmfPlusBlendColors | 2.2.2.4 | Positions and colors for the blend pattern of a gradient brush. |
| EmfPlusBlendFactors | 2.2.2.5 | Positions and factors for the blend pattern of a gradient brush. |
| EmfPlusBoundaryPathData | 2.2.2.6 | A **path** boundary for a gradient brush. |
| EmfPlusBoundaryPointData | 2.2.2.7 | A **closed cardinal spline** boundary for a gradient brush. |
| EmfPlusCharacterRange | 2.2.2.8 | A range of character positions for a text string. |
| EmfPlusCompoundLineData | 2.2.2.9 | Line and space data for a compound line. |
| EmfPlusCompressedImage | 2.2.2.10 | An image with compressed data. |
| EmfPlusCustomEndCapData | 2.2.2.11 | A custom line cap for the end of a line. |
| EmfPlusCustomLineCapArrowData | 2.2.2.12 | Adjustable arrow data for a custom line cap. |
| EmfPlusCustomLineCapData | 2.2.2.13 | Default data for a custom line cap. |
| EmfPlusCustomLineCapOptionalData | 2.2.2.14 | Optional fill and outline data for a custom line cap. |
| EmfPlusCustomStartCapData | 2.2.2.15 | A custom line cap for the start of a line. |
| EmfPlusDashedLineData | 2.2.2.16 | Properties of a dashed line for a graphics pen. |
| EmfPlusFillPath | 2.2.2.17 | A graphics path for filling a custom line cap. |
| EmfPlusFocusScaleData | 2.2.2.18 | Focus scales for the blend pattern of a path gradient brush. |
| EmfPlusGraphicsVersion | 2.2.2.19 | The version of operating system graphics that is used to create an EMF+ metafile. |
| EmfPlusHatchBrushData | 2.2.2.20 | A hatch pattern for a graphics brush. |
| EmfPlusInteger7 | 2.2.2.21 | A 7-bit signed integer in an 8-bit field. |
| EmfPlusInteger15 | 2.2.2.22 | A 15-bit signed integer in a 16-bit field. |
| EmfPlusLanguageIdentifier | 2.2.2.23 | Language identifiers that correspond to natural languages in a locale. |
| EmfPlusLinearGradientBrushData | 2.2.2.24 | A linear gradient for a graphics brush. |
| EmfPlusLinearGradientBrushOptionalData | 2.2.2.25 | Optional data for a linear gradient brush. |
| EmfPlusLinePath | 2.2.2.26 | A graphics path for outlining a custom line cap. |
| EmfPlusMetafile | 2.2.2.27 | A metafile that contains a graphics image. |
| EmfPlusPalette | 2.2.2.28 | The colors that make up a **palette**. |
| EmfPlusPathGradientBrushData | 2.2.2.29 | A path gradient for a graphics brush. |
| EmfPlusPathGradientBrushOptionalData | 2.2.2.30 | Optional data for a path gradient brush. |
| EmfPlusPathPointType | 2.2.2.31 | A type value associated with a point on a graphics path. |
| EmfPlusPathPointTypeRLE | 2.2.2.32 | Type values associated with points on a graphics path using **RLE compression** ([MS-WMF] section 3.1.6). |
| EmfPlusPenData | 2.2.2.33 | Properties of a graphics pen. |
| EmfPlusPenOptionalData | 2.2.2.34 | Optional data for a graphics pen. |
| EmfPlusPoint | 2.2.2.35 | An ordered pair of integer (X,Y) values that defines an absolute location in a **coordinate space**. |
| EmfPlusPointF | 2.2.2.36 | An ordered pair of floating-point (X,Y) values that defines an absolute location in a coordinate space. |
| EmfPlusPointR | 2.2.2.37 | An ordered pair of integer (X,Y) values that defines a relative location in a coordinate space. |
| EmfPlusRect | 2.2.2.38 | A rectangle origin, height, and width as integers. |
| EmfPlusRectF | 2.2.2.39 | A rectangle origin, height, and width as floating-point values. |
| EmfPlusRegionNode | 2.2.2.40 | A node of a graphics **region**. |
| EmfPlusRegionNodeChildNodes | 2.2.2.41 | The child nodes of a graphics region. |
| EmfPlusRegionNodePath | 2.2.2.42 | A graphics path for drawing the boundary of a region node. |
| EmfPlusSolidBrushData | 2.2.2.43 | A solid color for a graphics brush. |
| EmfPlusStringFormatData | 2.2.2.44 | Tab stops and character positions for a graphics string. |
| EmfPlusTextureBrushData | 2.2.2.45 | A texture image for a graphics brush. |
| EmfPlusTextureBrushOptionalData | 2.2.2.46 | Optional data for a texture brush. |
| EmfPlusTransformMatrix | 2.2.2.47 | A **world space** to **device space** **transform**. |

#### EmfPlusARGB Object

The **EmfPlusARGB** object specifies a color as a combination of red, green, blue. and **alpha**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Blue | Green | Red | Alpha |

**Blue (1 byte): **An unsigned integer that specifies the relative intensity of blue.

**Green (1 byte): **An unsigned integer that specifies the relative intensity of green.

**Red (1 byte): **An unsigned integer that specifies the relative intensity of red.

**Alpha (1 byte): **An unsigned integer that specifies the transparency of the background, ranging from 0 for completely transparent to 0xFF for completely opaque.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusBitmap Object

The **EmfPlusBitmap** object specifies a **bitmap** that contains a graphics image.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Width |
| Height |
| Stride |
| PixelFormat |
| Type |
| BitmapData (variable) |
| ... |

**Width (4 bytes): **A signed integer that specifies the width in pixels of the area occupied by the bitmap.

If the image is compressed, according to the **Type** field, this value is undefined and MUST be ignored.

**Height (4 bytes): **A signed integer that specifies the height in pixels of the area occupied by the bitmap.

If the image is compressed, according to the **Type** field, this value is undefined and MUST be ignored.

**Stride (4 bytes): **A signed integer that specifies the byte offset between the beginning of one scan-line and the next. This value is the number of bytes per pixel, which is specified in the **PixelFormat** field, multiplied by the width in pixels, which is specified in the **Width** field. The value of this field MUST be a multiple of four.

If the image is compressed, according to the **Type** field, this value is undefined and MUST be ignored.

**PixelFormat (4 bytes): **An unsigned integer that specifies the format of the pixels that make up the bitmap image. The supported pixel formats are specified in the PixelFormat enumeration (section 2.1.1.24).

If the image is compressed, according to the **Type** field, this value is undefined and MUST be ignored.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | X | X | X | X | X | X | X | X | X | N | E | P | A | G | I | BitsPerPixel | Index |

**X (1 bit): **Reserved and MUST be ignored.

**N (1 bit): **If set, the pixel format is "canonical", which means that 32 bits per pixel are supported, with 24 bits for color components and an 8-bit **alpha** channel.

If clear, the pixel format is not canonical.

**E (1 bit): **If set, the pixel format supports extended colors in 16 bits per channel.

If clear, extended colors are not supported.

**P (1 b****it): **If set, each color component in the pixel has been premultiplied by the pixel's alpha transparency value.

If clear, each color component is multiplied by the pixel's alpha transparency value when the source pixel is blended with the destination pixel.

**A (1 bit): **If set, the pixel format includes an alpha transparency component.

If clear, the pixel format does not include a component that specifies transparency.

**G (1 bit): **If set, the pixel format is supported in Windows **GDI**.

If clear, the pixel format is not supported in Windows GDI.

**I (1 bit): **If set, the pixel values are indexes into a **palette**.

If clear, the pixel values are actual colors.

**BitsPerPixel (1 byte): **The total number of bits per pixel.

**Index (1 byte): **The pixel format enumeration index.

**Type (4 bytes): **An unsigned integer that specifies the type of data in the **BitmapData** field. This value is defined in the BitmapDataType enumeration (section 2.1.1.2).

**BitmapData (variable): **Variable-length data that defines the bitmap data object specified in the **Type** field. The content and format of the data can be different for every bitmap type.

Graphics images are specified by EmfPlusImage objects (section 2.2.1.4). An EmfPlusBitmap object MUST be present in the **ImageData** field of an EmfPlusImage object if ImageTypeBitmap is specified in its **Type** field.

This object is generic and is used to specify different types of bitmap data, including:

An EmfPlusBitmapData object (section 2.2.2.3); and

An EmfPlusCompressedImage object (section 2.2.2.10).

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusBitmapData Object

The **EmfPlusBitmapData** object specifies a **bitmap** image with pixel data.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Colors (variable) |
| ... |
| PixelData (variable) |
| ... |

**Colors (variable): **An optional EmfPlusPalette object (section 2.2.2.28), which specifies the **palette** of colors used in the pixel data. This field MUST be present if the **I** flag is set in the **PixelFormat** field of the EmfPlusBitmap object (section 2.2.2.2).

**PixelData (variable): **An array of bytes that specify the pixel data. The size and format of this data can be computed from fields in the EmfPlusBitmap object, including the pixel format from the PixelFormat enumeration (section 2.1.1.24).

Bitmaps are specified by EmfPlusBitmap objects. An EmfPlusBitmapData object MUST be present in the **BitmapData** field of an EmfPlusBitmap object if BitmapDataTypePixel is specified in its **T****ype** field.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusBlendColors Object

The **EmfPlusBlendColo****rs** object specifies positions and colors for the blend pattern of a gradient brush.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PositionCount |
| BlendPositions (variable) |
| ... |
| BlendColors (variable) |
| ... |

**PositionCount (4 bytes): **An unsigned integer that specifies the number of positions in the **BlendPositions** field and colors in the **BlendColors** field.

**BlendPositions (variable): **An array of **PositionCount** 32-bit floating-point values that specify proportions of distance along the **gradient line**.

Each element MUST be a number between 0.0 and 1.0 inclusive. For a linear gradient brush, 0.0 represents the starting point and 1.0 represents the ending point. For a path gradient brush, 0.0 represents the midpoint and 1.0 represents an endpoint.

**BlendColors (variable): **An array of **PositionCount** EmfPlusARGB objects (section 2.2.2.5) that specify colors at the positions defined in the **BlendPositions** field.

Gradient brushes are specified by EmfPlusLinearGradientBrushData objects (section 2.2.2.24) and EmfPlusPathGradientBrushData objects (section 2.2.2.29). Blend patterns are used to smoothly shade the interiors of shapes filled by gradient brushes. and can be defined by arrays of positions and colors or positions and factors. Positions and factors are specified by EmfPlusBlendFactors objects (section 2.2.2.5).

An EmfPlusBlendColors object MUST be present in the **OptionalData** field of an EmfPlusLinearGradientBrushData object, if the BrushDataPresetColors flag is set in its **BrushDataFlags** field.

An EmfPlusBlendColors object MUST be present in the **OptionalData** field of an EmfPlusPathGradientBrushData object, if the BrushDataPresetColors flag is set in its **BrushDataFlags** field.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusBlendFactors Object

The **EmfPlusBlendFactors** object specifies positions and factors for the blend pattern of a gradient brush.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PositionCount |
| BlendPositions (variable) |
| ... |
| BlendFactors (variable) |
| ... |

**PositionCount (4 bytes): **An unsigned integer that specifies the number of positions in the **BlendPositions** field and factors in the **BlendFactors** field.

**BlendPositions (variable): **An array of **PositionCount** 32-bit floating-point values that specify proportions of distance along the **gradi****ent line**.

Each value MUST be a number between 0.0 and 1.0 inclusive. There MUST be at least two positions specified: the first position, which is always 0.0f, and the last position, which is always 1.0f. Each position in **BlendPositions** is generally greater than the preceding position. For a linear gradient brush, 0.0 represents the starting point and 1.0 represents the ending point. For a path gradient brush, 0.0 represents the midpoint and 1.0 represents an endpoint.

**BlendFactors (variable): **An array of **PositionCount** 32-bit floating-point values that specify proportions of colors at the positions defined in the **BlendPositions** field. Each value MUST be a number between 0.0 and 1.0 inclusive.

For a linear gradient brush, 0.0 represents 0% starting color and 100% ending color, and 1.0 represents 100% starting color and 0% ending color. For a path gradient brush, 0.0 represents 0% midpoint color and 100% endpoint color, and 1.0 represents 100% midpoint color and 0% endpoint color.

For example, if a linear gradient brush specifies a position of 0.2 and a factor of 0.3 along a gradient line that is 100 pixels long, the color that is 20 pixels along that line consists of 30 percent starting color and 70 percent ending color.

Gradient brushes are specified by EmfPlusLinearGradientBrushData objects (section 2.2.2.24) and EmfPlusPathGradientBrushData objects (section 2.2.2.29). Blend patterns are used to smoothly shade the interiors of shapes filled by gradient brushes. and can be defined by arrays of positions and colors or positions and factors. Positions and colors are specified by EmfPlusBlendColors objects (section 2.2.2.4).

An EmfPlusBlendFactors object MUST be present in the **OptionalData** field of an EmfPlusLinearGradientBrushData or EmfPlusPathGradientBrushData object if either of the flags BrushDataBlendFactorsH or BrushDataBlendFactorsV is set in its **BrushDataFlags** field.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusBoundaryPathData Object

The **EmfPlusBoundaryPathData** object specifies a graphics **path** boundary for a gradient brush.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BoundaryPathSize |
| BoundaryPathData (variable) |
| ... |

**BoundaryPathSize (4 bytes): **A signed integer that specifies the size in bytes of the **BoundaryPathData** field.

**BoundaryPathData (variable): **An EmfPlusPath object (section 2.2.1.6), which specifies the boundary of the brush.

Boundary path data is specified in the **BoundaryData** field of an EmfPlusPathGradientBrushData object (section 2.2.2.29).

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusBoundaryPointData Object

The **EmfPlusBoundaryPointData** object specifies a **closed cardinal spline** boundary for a gradient brush.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BoundaryPointCount |
| BoundaryPointData (variable) |
| ... |

**BoundaryPointCount (4 bytes): **A signed integer that specifies the number of points in the **BoundaryPointData** field.

**BoundaryPointData (variable): **An array of **BoundaryPointCount** EmfPlusPointF objects (section 2.2.2.36) that specify the boundary of the brush.

Boundary point data is specified in the **BoundaryData** field of an EmfPlusPathGradientBrushData object (section 2.2.2.29).

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusCharacterRange Object

The **EmfPlusCharacterRange** object specifies a range of character positions for a text string.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| First |
| Length |

**First (4 bytes): **A signed integer that specifies the first position of this range.

**Length (4 bytes): **A signed integer that specifies the number of positions in this range.

Graphics strings are specified by EmfPlusStringFormat objects (section 2.2.1.9).

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusCompoundLineData Object

The **EmfPlusCompoundLineData** object specifies line and space data for a compound line.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| CompoundLineDataSize |
| CompoundLineData (variable) |
| ... |

**CompoundLineDataSize (4 bytes): **An unsigned integer that specifies the number of elements in the **CompoundLineData** field.

**CompoundLineData (variable): **An array of **CompoundLineDataSize** 32-bit floating-point values that specify the compound line of a pen. The elements MUST be in increasing order, and their values MUST be between 0.0 and 1.0, inclusive.

Graphics pens are specified by EmfPlusPen objects (section 2.2.1.7). An EmfPlusCompoundLineData object MUST be present in the **OptionalData** field of an EmfPlusPenData object (section 2.2.2.33), if the PenDataCompoundLineData flag (section 2.1.2.7) is set in its **PenDataFlags** field.

A compound line is made up of a pattern of alternating parallel lines and spaces of varying widths. The values in the array specify the starting points of each component of the compound line relative to the total width. The first value specifies where the first line component begins as a fraction of the distance across the width of the pen. The second value specifies where the first space component begins as a fraction of the distance across the width of the pen. The final value in the array specifies where the last line component ends.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusCompressedImage Object

The **EmfPlusCompressedImage** object specifies an image with compressed data.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| CompressedImageData (variable) |
| ... |

**CompressedImageData (variable): **An array of bytes, which specify the compressed image. The type of compression is determined from the data itself.

**Bitmaps** are specified by EmfPlusBitmap objects (section 2.2.2.2). An EmfPlusCompressedImage object MUST be present in the **BitmapData** field of an EmfPlusBitmap object if the BitmapDataTypeCompressed value (section 2.1.1.2) is specified in its **Type** field.

This object is generic and is used for different types of compressed data, including:

**Exchangeable Image File Format (EXIF)** [EXIF];

**Graphics Interchange Format (GIF)** [GIF];

**Joint Photographic Experts Group (JPEG)** [JFIF];

**Portable Network Grap****hics (PNG)** [RFC2083] [W3C-PNG]; and

**Tag Image File Format (TIFF)** [RFC3302] [TIFF].

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusCustomEndCapData Object

The **EmfPlusCustomEndCapData** object specifies a custom line cap for the end of a line.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| CustomEndCapSize |
| CustomEndCap (variable) |
| ... |

**CustomEndCapSize (4 bytes): **An unsigned integer that specifies the size in bytes of the **CustomEndCap** field.

**CustomEndCap (variable): **A custom line cap that defines the shape to draw at the end of a line. It can be any of various shapes, including a square, circle, or diamond.

Custom line caps are specified by EmfPlusCustomLineCap objects (section 2.2.1.2). An EmfPlusCustomEndCapData object MUST be present in the **OptionalData** field of an EmfPlusPenData object (section 2.2.2.33), if the **PenDataEndCap** flag (section 2.1.2.7) is set in its **PenDataFlags** field.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusCustomLineCapArrowData Object

The **EmfPlusCustomLineCapArrowData** object specifies adjustable arrow data for a custom line cap.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Width |
| Height |
| MiddleInset |
| FillState |
| LineStartCap |
| LineEndCap |
| LineJoin |
| LineMiterLimit |
| WidthScale |
| FillHotSpot |
| ... |
| LineHotSpot |
| ... |

**Width (4 bytes): **A floating-point value that specifies the width of the arrow cap.

The width of the arrow cap is scaled by the width of the EmfPlusPen object (section 2.2.1.7) that is used to draw the line being capped. For example, when drawing a capped line with a pen that has a width of 5 pixels, and the adjustable arrow cap object has a width of 3, the actual arrow cap is drawn 15 pixels wide.

**Height (4 bytes): **A floating-point value that specifies the height of the arrow cap.

The height of the arrow cap is scaled by the width of the EmfPlusPen object that is used to draw the line being capped. For example, when drawing a capped line with a pen that has a width of 5 pixels, and the adjustable arrow cap object has a height of 3, the actual arrow cap is drawn 15 pixels high.

**Mid****dleInset (4 bytes): **A floating-point value that specifies the number of pixels between the outline of the arrow cap and the fill of the arrow cap.

**FillState (4 bytes): **A Boolean value that specifies whether the arrow cap is filled. If the arrow cap is not filled, only the outline is drawn.

**LineStartCap (4 bytes): **An unsigned integer that specifies the value in the LineCapType enumeration (section 2.1.1.17) that indicates the line cap to be used at the start of the line to be drawn.

**LineEndCap (4 bytes): **An unsigned integer that specifies the value in the LineCapType enumeration that indicates the line cap to be used at the end of the line to be drawn.

**LineJoin (4 bytes): **An unsigned integer that specifies the value in the LineJoinType enumeration (section 2.1.1.18) that specifies how to join two lines that are drawn by the same pen and whose ends meet. At the intersection of the two line ends, a line join makes the connection look more continuous.

**LineMiterLimit (4 bytes): **A floating-point value that specifies the limit of the thickness of the join on a mitered corner by setting the maximum allowed ratio of **miter length** to line width.

**WidthScale (4 bytes): **A floating-point value that specifies the amount by which to scale an EmfPlusCustomLineCap object (section 2.2.1.2) with respect to the width of the graphics pen that is used to draw the lines.

**FillHotSpot (8 bytes): **An EmfPlusPointF object (section 2.2.2.36) that is not currently used. It MUST be set to {0.0, 0.0}.

**LineHotSpot (8 bytes): **An EmfPlusPointF object that is not currently used. It MUST be set to {0.0, 0.0}.

Custom line caps are specified by EmfPlusCustomLineCap objects (section 2.2.1.2).

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusCustomLineCapData Object

The **EmfPlusCustomLineCapData** object specifies default data for a custom line cap.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| CustomLineCapDataFlags |
| BaseCap |
| BaseInset |
| StrokeStartCap |
| StrokeEndCap |
| StrokeJoin |
| StrokeMiterLimit |
| WidthScale |
| FillHotSpot |
| ... |
| StrokeHotSpot |
| ... |
| OptionalData (variable) |
| ... |

**CustomLineCapDataFlags (4 bytes): **An unsigned integer that specifies the data in the **OptionalData** field. This value is composed of CustomLineCapData flags (section 2.1.2.2).

**BaseCap (4 bytes): **An unsigned integer that specifies the value from the LineCapType enumeration (section 2.1.1.17) on which the custom line cap is based.

**BaseInset (4 bytes): **A floating-point value that specifies the distance between the beginning of the line cap and the end of the line.

**StrokeStartCap (4 bytes): **An unsigned integer that specifies the value in the LineCapType enumeration that indicates the line cap used at the start of the line to be drawn.

**StrokeEn****dCap (4 bytes): **An unsigned integer that specifies the value in the LineCapType enumeration that indicates what line cap is to be used at the end of the line to be drawn.

**StrokeJoin (4 bytes): **An unsigned integer that specifies the value in the LineJoinType enumeration (section 2.1.1.18) that specifies how to join two lines that are drawn by the same pen and whose ends meet. At the intersection of the two line ends, a line join makes the connection look more continuous.

**StrokeMiterLimit (4 bytes): **A floating-point value that contains the limit of the thickness of the join on a mitered corner by setting the maximum allowed ratio of **miter l****ength** to line width.

**WidthScale (4 bytes): **A floating-point value that specifies the amount by which to scale the custom line cap with respect to the width of the EmfPlusPen object (section 2.2.1.7) that is used to draw the lines.

**FillHotSpot (8 bytes): **An EmfPlusPointF object (section 2.2.2.36) that is not currently used. It MUST be set to {0.0, 0.0}.

**StrokeHotSpot (8 bytes): **An EmfPlusPointF object that is not currently used. It MUST be set to {0.0, 0.0}.

**OptionalData (variable): **An optional EmfPlusCustomLineCapOptionalData object (section 2.2.2.14) that specifies additional data for the custom graphics line cap. The specific contents of this field are determined by the value of the **CustomLineCapDataFlags** field.

Custom line caps are specified by EmfPlusCustomLineCap objects (section 2.2.1.2).

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusCustomLineCapOptionalData Object

The **EmfPlusCustomLineCapOptionalData** object specifies optional fill and outline data for a custom line cap.

**Note: **Each field specified for this object is optional and might not be present in the **OptionalData** field of an EmfPlusCustomLineCapData object (section 2.2.2.13), depending on the CustomLineCapData flags (section 2.1.2.2) set in its **CustomLineCapDataFlags** field. Although it is not practical to represent every possible combination of fields present or absent, this section specifies their relative order in the object. The implementer is responsible for determining which fields are actually present in a given **metafile** record, and for unmarshaling the data for individual fields separately and appropriately.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FillData (variable) |
| ... |
| OutlineData (variable) |
| ... |

**FillData (variable): **An optional EmfPlusFillPath object (section 2.2.2.17) that specifies the **path** for filling a custom graphics line cap. This field MUST be present if the CustomLineCapDataFillPath flag is set in the **CustomLineCapDataFlags** field of the EmfPlusCustomLineCapData object.

**OutlineData (variable): **An optional EmfPlusLinePath object (section 2.2.2.26) that specifies the path for outlining a custom graphics line cap. This field MUST be present if the CustomLineCapDataLinePath flag is set in the **CustomLineCapDataFlags** field of the EmfPlusCustomLineCapData object.

Custom line caps are specified by EmfPlusCustomLineCap objects (section 2.2.1.2).

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusCustomStartCapData Object

The **EmfPlusCustomStartCapData** object specifies a custom line cap for the start of a line.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| CustomStartCapSize |
| CustomStartCap (variable) |
| ... |

**CustomStartCapSize (4 bytes): **An unsigned integer that specifies the size in bytes of the **CustomStartCap** field.

**CustomStartCap (variable): **A custom graphics line cap that defines the shape to draw at the start of a line. It can be any of various shapes, including a square, circle or diamond.

Custom line caps are specified by EmfPlusCustomLineCap objects (section 2.2.1.2). If the PenDataStartCap flag (section 2.1.2.7) is set in its **PenDataFlags** field, an EmfPlusCustomStartCapData object MUST be present in the **OptionalData** field of an EmfPlusPenData object (section 2.2.2.33).

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusDashedLineData Object

The **EmfPlusDashedLineData** object specifies properties of a dashed line for a graphics pen.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DashedLineDataSize |
| DashedLineData (variable) |
| ... |

**DashedLineDataSize (4 bytes): **An unsigned integer that specifies the number of elements in the **DashedLineData** field.

**DashedLineData (variable): **An array of **DashedLineDataSize** 32-bit floating-point values that specify the lengths of the dashes and spaces in a dashed line.

Graphics pens are specified by EmfPlusPen objects (section 2.2.1.7). An EmfPlusDashedLineData object MUST be present in the **OptionalData** field of an EmfPlusPenData object (section 2.2.2.33), if the PenDataDashedLine flag (section 2.1.2.7) is set in its **PenDataFlags** field.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusFillPath Object

The **EmfPlusFillPath** object specifies a graphics path for filling a custom line cap.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FillPathLength |
| FillPath (variable) |
| ... |

**FillPathLength (4 bytes): **A signed integer that specifies the length in bytes of the **FillPath** field.

**FillPath (variable): **An EmfPlusPath object (section 2.2.1.6), which specifies the area to fill.

Custom line caps are specified by EmfPlusCustomLineCap objects (section 2.2.1.2). An EmfPlusFillPath object (section 2.2.2.17) MUST be present if the **CustomLineCapDataFillPath** flag is set in the **CustomLineCapDataFlags** field of an EmfPlusCustomLineCapData object (section 2.2.2.13).

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusFocusScaleData Object

The **EmfPlusFocusScaleData** object specifies focus scales for the blend pattern of a path gradient brush.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FocusScaleCount |
| FocusScaleX |
| FocusScaleY |

**FocusScaleCount (4 bytes): **An unsigned integer that specifies the number of focus scales. This value MUST be 2.

**FocusScaleX (4 bytes): **A floating-point value that defines the horizontal focus scale. The focus scale MUST be a value between 0.0 and 1.0, exclusive.

**FocusScaleY (4 bytes): **A floating-point value that defines the vertical focus scale. The focus scale MUST be a value between 0.0 and 1.0, exclusive.

By default, the center color of a path gradient brush is displayed only at the center point of an area bounded by a **path**. Focus scales specify an inner path inside that area, and the center color is displayed everywhere inside it. The inner path is the boundary path scaled by horizontal and vertical scale factors.

For example, focus scales of {0.2, 0.3} specifies a path that is the boundary path scaled by a factor of 0.2 horizontally and 0.3 vertically. The area inside the scaled path MUST be filled with the center color. Between the inner and outer boundaries, the color MUST change gradually from the center color to the boundary color.

An EmfPlusFocusScaleData object MUST be present in the **OptionalData** field of an EmfPlusPathGradientBrushData object (section 2.2.2.29), if the BrushDataFocusScales flag (section 2.1.2.1) is set in its **BrushDataFlags** field.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusGraphicsVersion Object

The **EmfPlusGraphicsVersion** object specifies the version of operating system graphics that is used to create an **EMF+** **metafile**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| MetafileSignature | GraphicsVersion |

**MetafileSignature (20 bits): **A value that identifies the type of metafile. The value for an EMF+ metafile is 0xDBC01.

**GraphicsVersion (12 bits): **The version of operating system graphics. This value is defined in the GraphicsVersion enumeration (section 2.1.1.12).<12>

Graphics versions are vendor-extensible; however, to ensure inter-operability, any such extension MUST be implemented in both clients and servers of EMF+ metafiles.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusHatchBrushData Object

The **EmfPlusHatchBrushData** object specifies a hatch pattern for a graphics brush.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| HatchStyle |
| ForeColor |
| BackColor |

**HatchStyle (4 bytes): **An unsigned integer that specifies the brush hatch style. It is defined in the HatchStyle enumeration (section 2.1.1.13).

**ForeColor (4 bytes): **An EmfPlusARGB object (section 2.2.2.1) that specifies the color used to draw the lines of the hatch pattern.

**BackColor (4 bytes): **An EmfPlusARGB object that specifies the color used to paint the background of the hatch pattern.

Graphics brushes are specified by EmfPlusBrush objects (section 2.2.1.1). A hatch brush paints a background and draws a pattern of lines, dots, dashes, squares, and crosshatch lines over this background. The hatch brush defines two colors: one for the background and one for the pattern over the background. The color of the background is called the background color, and the color of the pattern is called the foreground color.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusInteger7 Object

The **EmfPlusInteger7** object specifies a 7-bit signed integer in an 8-bit field.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | Value |

**Value (7 bits): **A 7-bit signed integer between -64 and 63, inclusive.

EmfPlusInteger7 objects are used to specify point coordinates in EmfPlusPointR objects (section 2.2.2.37).

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusInteger15 Object

The **EmfPlusInteger15** object specifies a 15-bit signed integer in a 16-bit field.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Value |

**Value (15 bits): **A 15-bit signed integer between -16,384 and 16,383, inclusive.

EmfPlusInteger15 objects are used to specify point coordinates in EmfPlusPointR objects (section 2.2.2.37).

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusLanguageIdentifier Object

The **EmfPlusLanguageIdentifier** object specifies a **language code identifier (LCID)** that corresponds to the natural language in a locale, including countries, geographical regions, and administrative districts. Each object is an encoding of a primary language and sublanguage identifier, as shown in the following bit field table.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SubLanguageId | PrimaryLanguageId |

**SubLanguageId (6 bits): **The country, geographic region or administrative district for the natural language specified in the **PrimaryLanguageId** field.

Sublanguage identifiers are vendor extensible. Vendor-defined sublanguage identifiers MUST be in the range 0x20 to 0x3F, inclusive.

**PrimaryLanguageId (10 bits): **The natural language.

Primary language identifiers are vendor extensible. Vendor-defined primary language identifiers MUST be in the range 0x0200 to 0x03FF, inclusive.

The encoded LCID values are defined in [MS-LCID] section 2.2.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusLinearGradientBrushData Object

The **EmfPlusLinearGradientBrushData** object specifies a linear gradient for a graphics brush.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BrushDataFlags |
| WrapMode |
| RectF |
| ... |
| ... |
| ... |
| StartColor |
| EndColor |
| Reserved1 |
| Reserved2 |
| OptionalData (variable) |
| ... |

**BrushDataFlags (4 bytes): **An unsigned integer that specifies the data in the **OptionalData** field. This value MUST be composed of BrushData flags (section 2.1.2.1). The following flags are relevant to a linear gradient brush:

| Name | Value |
| --- | --- |
| BrushDataTransform | 0x00000002 |
| BrushDataPresetColors | 0x00000004 |
| BrushDataBlendFactorsH | 0x00000008 |
| BrushDataBlendFactorsV | 0x00000010 |
| BrushDataIsGammaCorrected | 0x00000080 |

**WrapMode (4 bytes): **A signed integer from the WrapMode enumeration (section 2.1.1.33) that specifies whether to paint the area outside the boundary of the brush. When painting outside the boundary, the wrap mode specifies how the color gradient is repeated.

**RectF (16 bytes): **An EmfPlusRectF object (section 2.2.2.39) that specifies the starting and ending points of the **gradient line**. The upper-left corner of the rectangle is the starting point. The lower-right corner is the ending point.

**StartColor (4 bytes): **An EmfPlusARGB object (section 2.2.2.1) that specifies the color at the starting boundary point of the linear gradient brush.

**EndColor (4 bytes): **An EmfPlusARGB object that specifies the color at the ending boundary point of the linear gradient brush.

**Reserved1 (4 bytes): **This field is reserved and SHOULD<13> be ignored.

**Reserved2 (4 bytes): **This field is reserved and SHOULD<14> be ignored.

**OptionalData (var****iable): **An optional EmfPlusLinearGradientBrushOptionalData object (section 2.2.2.25) that specifies additional data for the linear gradient brush. The specific contents of this field are determined by the value of the **BrushDataFlags** field.

Graphics brushes are specified by EmfPlusBrush objects (section 2.2.1.1). A linear gradient brush paints a color gradient in which the color changes gradually along a gradient line from a starting boundary point to an ending boundary point, which are specified by the diagonal of a rectangle in the **RectF** field.

**Gamma correction** controls the overall **brightness** and **intensity** of an image. Uncorrected images can look either bleached out or too dark. Varying the amount of gamma correction changes not only the brightness but also the ratios of red to green to blue. The need for gamma correction arises because an output device might not render colors in the same intensity as the input image.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusLinearGradientBrushOptionalData Object

The **EmfPlusL****inearGradientBrushOptionalData** object specifies optional data for a linear gradient brush.

**Note: **Each field of this object is optional and might not be present in the **OptionalData** field of an EmfPlusLinearGradientBrushData object (section 2.2.2.24), depending on the BrushData flags (section 2.1.2.1) set in its **BrushDataFlags** field. Although it is not practical to represent every possible combination of fields present or absent, this section specifies their relative order in the object. The implementer is responsible for determining which fields are actually present in a given **metafile** record, and for unmarshaling the data for individual fields separately and appropriately.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TransformMatrix (24 bytes, optional) |
| ... |
| ... |
| ... |
| BlendPattern (variable) |
| ... |

**TransformMatrix (24 bytes): **An optional EmfPlusTransformMatrix object (section 2.2.2.47) that specifies a **world space** to **device space** **transform** for the linear gradient brush. This field MUST be present if the **BrushDataTransform** flag is set in the **BrushDat****aFlags** field of the EmfPlusLinearGradientBrushData object.

**BlendPattern (variable): **An optional blend pattern for the linear gradient brush. If this field is present, it MUST contain either an EmfPlusBlendColors object (section 2.2.2.4), or one or two EmfPlusBlendFactors objects (section 2.2.2.5), but it MUST NOT contain both. The table below shows the valid combinations of flags in the **Br****ushDataFlags** field of the EmfPlusLinearGradientBrushData object and the corresponding blend patterns:

| PresetColors | BlendFactorsH | BlendFactorsV | Blend Pattern |
| --- | --- | --- | --- |
| Clear | Clear | Clear | This field MUST NOT be present in the EmfPlusLinearGradientBrushOptionalData object. |
| Set | Clear | Clear | An EmfPlusBlendColors object MUST be present. |
| Clear | Set | Clear | An EmfPlusBlendFactors object along the horizontal **gradient line** MUST be present. |
| Clear | Clear | Set | An EmfPlusBlendFactors object along the vertical gradient line MUST be present.<15> |
| Clear | Set | Set | An EmfPlusBlendFactors object along the vertical gradient line and an EmfPlusBlendFactors object along the horizontal gradient line MUST be present.<16> |

Graphics brushes are specified by EmfPlusBrush objects (section 2.2.1.1).

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusLinePath Object

The **EmfPlusLinePath** object specifies a graphics path for outlining a custom line cap.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| LinePathLength |
| LinePath (variable) |
| ... |

**LinePathLength (4 bytes): **A signed integer that defines the length in bytes of the **LinePath** field.

**LinePath (variable): **An EmfPlusPath object (section 2.2.1.6) that defines the outline.

Custom line caps are specified by EmfPlusCustomLineCap objects (section 2.2.1.2). An EmfPlusLinePath object MUST be present if the CustomLineCapDataLinePath flag (section 2.1.2.2) is set in the **CustomLineCapDataFlags** field of an EmfPlusCustomLineCapData object (section 2.2.2.13).

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusMetafile Object

The **EmfPlusMetafileData** object specifies a **metafile** that contains a graphics image.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| MetafileDataSize |
| MetafileData (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that specifies the type of metafile that is embedded in the **MetafileData** field. This value is defined in the MetafileDataType enumeration (section 2.1.1.20).

**MetafileDataSize (4 bytes): **An unsigned integer that specifies the size in bytes of the metafile data in the **M****etafileData** field.

**MetafileData (variable): **Variable-length data that specifies the embedded metafile. The content and format of the data can be different for each metafile type.

Graphics images are specified by EmfPlusImage objects (section 2.2.1.4). An EmfPlusMetafile object MUST be present in the **ImageData** field of an EmfPlusImage object if ImageTypeMetafile is specified in its **Type** field.

This object is generic and is used for different types of data, including:

A **WMF** metafile [MS-WMF];

A WMF metafile which can be placed;

An **EMF** metafile [MS-EMF];

An **EMF+** metafile that specifies graphics operations with EMF+ records only; and

An EMF+ metafile that specifies graphics operations with both EMF+ and EMF records ([MS-EMF] section 2.3).

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusPalette Object

The **EmfPlusPalette** object specifies the colors that make up a **palette**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PaletteStyleFlags |
| PaletteCount |
| PaletteEntries (variable) |
| ... |

**PaletteStyleFlags (4 bytes): **An unsigned integer that specifies the attributes of data in the palette. This value MUST be composed of PaletteStyle flags (section 2.1.2.5).

**PaletteCount (4 bytes): **An unsigned integer that specifies the number of entries in the **PaletteEntries** array.

**PaletteEntries (variable): **An array of **PaletteCount** EmfPlusARGB objects (section 2.2.2.1) that specify the data in the palette.

See section 2.2.2 for the specification of additional graphics objects.

#### EmfPlusPathGradientBrushData Object

The **EmfPlusPa****thGradientBrushData** object specifies a path gradient for a graphics brush.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BrushDataFlags |
| WrapMode |
| CenterColor |
| CenterPointF |
| ... |
| SurroundingColorCount |
| SurroundingColor (variable) |
| ... |
| BoundaryData (variable) |
| ... |
| OptionalData (variable) |
| ... |

**BrushDataFlags (4 bytes): **An unsigned integer that specifies the data in the **OptionalData** field. This value is composed of BrushData flags (section 2.1.2.1). The following flags are relevant to a path gradient brush:

| Name | Value |
| --- | --- |
| BrushDataPath | 0x00000001 |
| BrushDataTransform | 0x00000002 |
| BrushDataPresetColors | 0x00000004 |
| BrushDataBlendFactorsH | 0x00000008 |
| BrushDataFocusScales | 0x00000040 |
| BrushDataIsGammaCorrected | 0x00000080 |

**WrapMode (4 bytes): **A signed integer from the WrapMode enumeration (section 2.1.1.33) that specifies whether to paint the area outside the boundary of the brush. When painting outside the boundary, the wrap mode specifies how the color gradient is repeated.

**CenterColor (4 bytes): **An EmfPlusARGB object (section 2.2.2.1) that specifies the center color of the path gradient brush, which is the color that appears at the center point of the brush. The color of the brush changes gradually from the boundary color to the center color as it moves from the boundary to the center point.

**CenterPointF (8 bytes): **An EmfPlusPointF object (section 2.2.2.36) that specifies the center point of the path gradient brush, which can be any location inside or outside the boundary. The color of the brush changes gradually from the boundary color to the center color as it moves from the boundary to the center point.

**SurroundingColorCount (4 bytes): **An unsigned integer that specifies the number of colors specified in the **Surrou****ndingColor** field. The surrounding colors are colors specified for discrete points on the boundary of the brush.

**SurroundingColor (variable): **An array of **SurroundingColorCount** EmfPlusARGB objects that specify the colors for discrete points on the boundary of the brush.

**BoundaryData (variable): **The boundary of the path gradient brush, which is specified by either a **path** or a **closed cardi****nal spline**. If the BrushDataPath flag is set in the **BrushDataFlags** field, this field MUST contain an EmfPlusBoundaryPathData object (section 2.2.2.6); otherwise, this field MUST contain an EmfPlusBoundaryPointData object (section 2.2.2.7).

**OptionalData (variable): **An optional EmfPlusPathGradientBrushOptionalData object (section 2.2.2.30) that specifies additional data for the path gradient brush. The specific contents of this field are determined by the value of the **BrushDataFlags** field.

Graphics brushes are specified by EmfPlusBrush objects (section 2.2.1.1). A path gradient brush paints a color gradient in which the color changes gradually along a **gradient line** from the center point outward to the boundary, which are specified by either a closed cardinal spline or a path in the **BoundaryData** field.

**Gamma correction** controls the overall **brightness** and **intensity** of an image. Uncorrected images can look either bleached out or too dark. Varying the amount of gamma correction changes not only the brightness but also the ratios of red to green to blue. The need for gamma correction arises because an output device might not render colors in the same intensity as the input image.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusPathGradientBrushOptionalData Object

The **EmfPlusPathGradientBrushOptionalData** object specifies optional data for a path gradient brush.

**Note: **Each field of this object is optional and might not be present in the **OptionalData** field of an EmfPlusPathGradientBrushData object (section 2.2.2.29), depending on the BrushData flags (section 2.1.2.1) set in its **BrushDataFlags** field. Although it is not practical to represent every possible combination of fields present or absent, this section specifies their relative order in the object. The implementer is responsible for determining which fields are actually present in a given **metafile** record, and for unmarshaling the data for individual fields separately and appropriately.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TransformMatrix (24 bytes, optional) |
| ... |
| ... |
| ... |
| BlendPattern (variable) |
| ... |
| FocusScaleData (optional) |
| ... |
| ... |

**TransformMatrix (24 bytes): **An optional EmfPlusTransformMatrix object (section 2.2.2.47) that specifies a **world space** to **device space** **transform** for the path gradient brush. This field MUST be present if the **BrushDataTransform** flag is set in the **BrushDataFlags** field of the EmfPlusPathGradientBrushData object.

**BlendPattern (variable): **An optional blend pattern for the path gradient brush. If this field is present, it MUST contain either an EmfPlusBlendColors object (section 2.2.2.4), or an EmfPlusBlendFactors object (section 2.2.2.5), but it MUST NOT contain both. The table below shows the valid combinations of flags in the **BrushDataFlags** field of the EmfPlusPathGradientBrushData object and the corresponding blend patterns:

| PresetColors | BlendFactorsH | Blend Patterns |
| --- | --- | --- |
| Clear | Clear | This field MUST NOT be present. |
| Set | Clear | An EmfPlusBlendColors object MUST be present. |
| Clear | Set | An EmfPlusBlendFactors object MUST be present. |

**FocusScaleData (12 bytes): **An optional EmfPlusFocusScaleData object (section 2.2.2.18) that specifies focus scales for the path gradient brush. This field MUST be present if the **BrushDataFocusScal****es** flag is set in the **BrushDataFlags** field of the EmfPlusPathGradientBrushData object.

Graphics brushes are specified by EmfPlusBrush objects (section 2.2.1.1).

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusPathPointType Object

The **EmfPlusPathPointType** object specifies a type value associated with a point on a graphics **path**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Flags | Type |

**Flags (4 bits): **A flag field that specifies properties of the path point. This value is one or more of the PathPointType flags (section 2.1.2.6).

**Type (4 bits): **An unsigned integer path point type. This value is defined in the PathPointType enumeration (section 2.1.1.22).

Graphics paths are specified by EmfPlusPath objects (section 2.2.1.6). Every point on a graphics path MUST have a type value associated with it.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusPathPointTypeRLE Object

The **EmfPlusPathPointTypeRLE** object specifies type values associated with points on a graphics **path** using **RLE compression** ([MS-WMF] section 3.1.6).

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| B | 1 | RunCount | PointType |

**B (1 bit): **If set, the path points are on a **Bezier curve**.

If clear, the path points are on a graphics line.

**RunCount (6 bits): **The run count, which is the number of path points to be associated with the type in the **PointType** field.

**PointType (1 byte): **An EmfPlusPathPointType object (section 2.2.2.31) that specifies the type to associate with the path points.

Graphics paths are specified by EmfPlusPath objects (section 2.2.1.6). Every point on a graphics path MUST have a type value associated with it.

RLE compression makes it possible to specify an arbitrary number of identical values without a proportional increase in storage requirements.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusPenData Object

The **EmfPlusPenData** object specifies properties of a graphics pen.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PenDataFlags |
| PenUnit |
| PenWidth |
| OptionalData (variable) |
| ... |

**PenDataFlags (4 bytes): **An unsigned integer that specifies the data in the **OptionalData** field. This value is composed of PenData flags (section 2.1.2.7).

**PenUnit (4 bytes): **An unsigned integer that specifies the measuring units for the pen. The value is from the UnitType enumeration (section 2.1.1.32).

**PenWidth (4 bytes): **A floating-point value that specifies the width of the line drawn by the pen in the units specified by the **PenUnit** field. If a zero width is specified, a minimum value is used, which is determined by the units.

**OptionalData (variable): **An optional EmfPlusPenOptionalData object (section 2.2.2.34) that specifies additional data for the pen object. The specific contents of this field are determined by the value of the **PenDataFlags** field.

Graphics pens are specified by EmfPlusPen objects (section 2.2.1.7).

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusPenOptionalData Object

The **EmfPlusPenOptionalData **object specifies optional data for a graphics pen.

**Note: **Each field of this object is optional and might not be present in the **OptionalData** field of an EmfPlusPenData object (section 2.2.2.33), depending on the PenData flags (section 2.1.2.7) set in its **PenDataFlags** field. Although it is not practical to represent every possible combination of fields present or absent, this section specifies their relative order in the object. The implementer is responsible for determining which fields are actually present in a given **metafil****e** record, and for unmarshaling the data for individual fields separately and appropriately.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TransformMatrix (24 bytes, optional) |
| ... |
| ... |
| ... |
| StartCap (optional) |
| EndCap (optional) |
| Join (optional) |
| MiterLimit (optional) |
| LineStyle (optional) |
| DashedLineCapType (optional) |
| DashOffset (optional) |
| DashedLineData (variable) |
| ... |
| PenAlignment (optional) |
| CompoundLineData (variable) |
| ... |
| CustomStartCapData (variable) |
| ... |
| CustomEndCapData (variable) |
| ... |

**TransformMatrix (24 bytes): **An optional EmfPlusTransformMatrix object (section 2.2.2.47) that specifies a **world space** to **device space** **transform** for the pen. This field MUST be present if the **PenDataTransform** flag is set in the **PenDataFlags** field of the EmfPlusPenData object.

**StartCap (4 bytes): **An optional signed integer that specifies the shape for the start of a line in the **CustomStartCapData** field. This field MUST be present if the PenDataStartCap flag is set in the **PenDataFlags** field of the EmfPlusPenData object, and the value is defined in the LineCapType enumeration (section 2.1.1.17).

**EndCap (4 bytes): **An optional signed integer that specifies the shape for the end of a line in the **CustomEndCapData** field. This field MUST be present if the PenDataEndCap flag is set in the **PenDataFlags** field of the EmfPlusPenData object, and the value is defined in the LineCapType enumeration.

**Join (4 bytes): **An optional signed integer that specifies how to join two lines that are drawn by the same pen and whose ends meet. This field MUST be present if the PenDataJoin flag is set in the **PenDataFlags** field of the EmfPlusPenData object, and the value is defined in the LineJoinType enumeration (section 2.1.1.18).

**MiterLimit (4 bytes): **An optional floating-point value that specifies the miter limit, which is the maximum allowed ratio of miter length to line width. The miter length is the distance from the intersection of the line walls on the inside the join to the intersection of the line walls outside the join. The miter length can be large when the angle between two lines is small. This field MUST be present if the PenDataMiterLimit flag is set in the **PenDataFlags** field of the EmfPlusPenData object.

**LineStyle (4 bytes): **An optional signed integer that specifies the style used for lines drawn with this pen object. This field MUST be present if the PenDataLineStyle flag is set in the **PenDataFlags** field of the EmfPlusPenData object, and the value is defined in the LineStyle enumeration (section 2.1.1.19).

**DashedLineCapType (4 ****bytes): **An optional signed integer that specifies the shape for both ends of each dash in a dashed line. This field MUST be present if the PenDataDashedLineCap flag is set in the **PenDataFlags** field of the EmfPlusPenData object, and the value is defined in the DashedLineCapType enumeration (section 2.1.1.10).

**DashOffset (4 bytes): **An optional floating-point value that specifies the distance from the start of a line to the start of the first space in a dashed line pattern. This field MUST be present if the PenDataDashedLineOffset flag is set in the **PenDataFlags** field of the EmfPlusPenData object.

**DashedLineData (variable): **An optional EmfPlusDashedLineData object (section 2.2.2.16) that specifies the lengths of dashes and spaces in a custom dashed line. This field MUST be present if the PenDataDashedLine flag is set in the **PenDataFlags** field of the EmfPlusPenData object.

**PenAlignment (4 bytes): **An optional signed integer that specifies the distribution of the pen width with respect to the coordinates of the line being drawn. This field MUST be present if the PenDataNonCenter flag is set in the **PenDataFlags** field of the EmfPlusPenData object, and the value is defined in the PenAlignment enumeration (section 2.1.1.23).

For example, consider the placement of a line. If the starting and ending coordinates of the line are defined, it is possible to think of a theoretical line between the two points that is zero width. Center alignment means that the pen width is distributed as evenly as possible on either side of that theoretical line.

**CompoundLineData (variable): **An optional EmfPlusCompoundLineData object (section 2.2.2.9) that specifies an array of 32-bit floating-point values that define the compound line of a pen, which is made up of parallel lines and spaces. This field MUST be present if the PenDataCompoundLine flag is set in the **PenDataFlags** field of the EmfPlusPenData object.

**CustomStartCapData (variable): **An optional EmfPlusCustomStartCapData object (section 2.2.2.15) that defines the custom start-cap shape, which is the shape to use at the start of a line drawn with this pen. It can be any of various shapes, such as a square, circle, or diamond. This field MUST be present if the **PenDataCustomStar****tCap** flag is set in the **PenDataFlags** field of the EmfPlusPenData object.

**CustomEndCapData (variable): **An optional EmfPlusCustomEndCapData object (section 2.2.2.11) that defines the custom end-cap shape, which is the shape to use at the end of a line drawn with this pen. It can be any of various shapes, such as a square, circle, or diamond. This field MUST be present if the **PenDataCustomEndCap** flag is set in the **PenDataFlags** field of the EmfPlusPenData object.

Graphics pens are specified by EmfPlusPen objects (section 2.2.1.7).

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusPoint Object

The **EmfPlusPoint** object specifies an ordered pair of integer (X,Y) values that define an absolute location in a **coordinate space**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | Y |

**X (2 bytes): **A signed integer that defines the horizontal coordinate.

**Y (2 bytes): **A signed integer that defines the vertical coordinate.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusPointF Object

The **EmfPlusPointF** object specifies an ordered pair of floating-point (X,Y) values that define an absolute location in a **coordinate space**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X |
| Y |

**X (4 bytes): **A floating-point value that specifies the horizontal coordinate.

**Y (4 bytes): **A floating-point value that specifies the vertical coordinate.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusPointR Object

The **EmfPlusPointR** object specifies an ordered pair of integer (X,Y) values that define a relative location in a **coordinate**** space**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X (variable) |
| ... |
| Y (variable) |
| ... |

**X (variable): **A signed integer that specifies the horizontal coordinate. This value MUST be specified by either an EmfPlusInteger7 object (section 2.2.2.21) or an EmfPlusInteger15 object (section 2.2.2.22).

**Y (variable): **A signed integer that specifies the vertical coordinate. This value MUST be specified by either an EmfPlusInteger7 object or an EmfPlusInteger15 object.

**Note: **The object that specifies the horizontal coordinate is not required to be the same type as the object that specifies the vertical coordinate; that is, one can be 7 bits and the other can be 15 bits.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusRect Object

The **EmfPlusRect** object specifies a rectangle origin, height, and width as integers.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | Y |
| Width | Height |

**X (2 bytes): **A signed integer that specifies the horizontal coordinate of the upper-left corner of the rectangle.

**Y (2 bytes): **A signed integer that specifies the vertical coordinate of the upper-left corner of the rectangle.

**Width (2 bytes): **A signed integer that specifies the width of the rectangle.

**Height (2 bytes): **A signed integer that specifies the height of the rectangle.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusRectF Object

The **EmfPlusRectF** object specifies a rectangle's origin, height, and width as floating-point values.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X |
| Y |
| Width |
| Height |

**X (4 bytes): **A floating-point value that specifies the horizontal coordinate of the upper-left corner of the rectangle.

**Y (4 bytes): **A floating-point value that specifies the vertical coordinate of the upper-left corner of the rectangle.

**Width (4 bytes): **A floating-point value that specifies the width of the rectangle.

**Height (4 bytes): **A floating-point value that specifies the height of the rectangle.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusRegionNode Object

The **EmfPlusRegionNode** object specifies nodes of a graphics **region**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| RegionNodeData (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that specifies the type of data in the **RegionNodeData** field. This value is defined in the RegionNodeDataType enumeration (section 2.1.1.26).

**RegionNodeData (variable): **Optional, variable-length data that defines the region node data object specified in the **Type** field. The content and format of the data can be different for every region node type. This field MUST NOT be present if the node type is RegionNodeDataTypeEmpty or RegionNodeDataTypeInfinite.

Graphics regions are specified by EmfPlusRegion objects (section 2.2.1.8), which define a binary tree of region nodes. Each node MUST either be a terminal node or specify additional region nodes.

This object is generic and is used to specify different types of region node data, including:

An EmfPlusRegionNodePath object (section 2.2.2.42), for a terminal node;

An EmfPlusRectF object (section 2.2.2.39), for a terminal node; and

An EmfPlusRegionNodeChildNodes object (section 2.2.2.41), for a non-terminal node.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusRegionNodeChildNodes Object

The **EmfPlusRegionNodeChildNodes** object specifies child nodes of a graphics **region** node.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Left (variable) |
| ... |
| Right (variable) |
| ... |

**Left (variable): **An EmfPlusRegionNode object (section 2.2.2.40) that specifies the left child node of this region node.

**Right (variable): **An EmfPlusRegionNode object that defines the right child node of this region node.

Graphics region nodes are specified with EmfPlusRegionNode objects.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusRegionNodePath Object

The **EmfPlusRegionNodePath** object specifies a graphics path for drawing the boundary of a **region** node.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RegionNodePathLength |
| RegionNodePath (variable) |
| ... |

**RegionNodePathLength (4 bytes): **A signed integer that specifies the length in bytes of the **RegionNodePath** field.

**RegionNodePath (variable): **An EmfPlusPath object (section 2.2.1.6) that specifies the boundary of the region node.

Region nodes are specified by EmfPlusRegion objects (section 2.2.1.8). An EmfPlusRegionNodePath object MUST be present in the **RegionNodeData** field of an EmfPlusRegionNode object (section 2.2.2.40) if its **Type** field is set to the **RegionNodeDataTypePath** value from the RegionNodeDataType enumeration (section 2.1.1.26).

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusSolidBrushData Object

The **EmfPlusSolidBrushData** object specifies a solid color for a graphics brush.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SolidColor |

**SolidColor (4 bytes): **An EmfPlusARGB object (section 2.2.2.1) that specifies the color of the brush.

Graphics brushes are specified by EmfPlusBrush objects (section 2.2.1.1). A solid color brush paints a background in a solid color.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusStringFormatData Object

The **EmfPlusStringFormatData** object specifies tab stops and character positions for a graphics string.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TabStops (variable) |
| ... |
| CharRange (variable) |
| ... |

**TabStops (variable): **An optional array of 32-bit floating-point values that specify the optional tab stop locations for this object. Each tab stop value represents the number of spaces between tab stops or, for the first tab stop, the number of spaces between the beginning of a line of text and the first tab stop.

This field MUST be present if the value of the **TabStopCount** field in the EmfPlusStringFormat object (section 2.2.1.9) is greater than 0.

**CharRange (variable): **An optional array of **RangeCount** EmfPlusCharacterRange objects (section 2.2.2.8) that specify the range of character positions within a string of text. The bounding **region** is defined by the area of the display that is occupied by a group of characters specified by the character range.

This field MUST be present if the value of the **RangeCount** field in the EmfPlusStringFormat object is greater than 0.

Graphics strings are specified by EmfPlusStringFormat objects.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusTextureBrushData Object

The **EmfPlusTextureBrushData** object specifies a texture image for a graphics brush.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BrushDataFlags |
| WrapMode |
| OptionalData (variable) |
| ... |

**BrushDataFlags (4 bytes): **An unsigned integer that specifies the data in the **OptionalData** field. This value MUST be composed of BrushData flags (section 2.1.2.1). The following flags are relevant to a texture brush:

| Name | Value |
| --- | --- |
| BrushDataTransform | 0x00000002 |
| BrushDataIsGammaCorrected | 0x00000080 |
| BrushDataDoNotTransform | 0x00000100 |

**WrapMode (4 bytes): **A signed integer from the WrapMode enumeration (section 2.1.1.33) that specifies how to repeat the texture image across a shape, when the image is smaller than the area being filled.

**OptionalData (variable): **An optional EmfPlusTextureBrushOptionalData object (section 2.2.2.46) that specifies additional data for the texture brush. The specific contents of this field are determined by the value of the **BrushDataFlags** field.

Graphics brushes are specified by EmfPlusBrush objects (section 2.2.1.1). A texture brush paints an image, which in this context is called a "texture". The texture consists of either a portion of an image or a scaled version of an image, which is specified by an EmfPlusImage object (section 2.2.1.4) in the **OptionalData** field.

**Gamma correction** controls the overall **brightness** and **intensity** of an image. Uncorrected images can look either bleached out or too dark. Varying the amount of gamma correction changes not only the brightness but also the ratios of red to green to blue. The need for gamma correction arises because an output device might not render colors in the same intensity as the input image.

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusTextureBrushOptionalData Object

The **EmfPlusTextureBrushOptionalData** object specifies optional data for a texture brush.

**Note: **Each field of this object is optional and might not be present in the **OptionalData** field of an EmfPlusTextureBrushData object (section 2.2.2.45), depending on the BrushData flags (section 2.1.2.1) set in its **BrushDataFlags** field. Although it is not practical to represent every possible combination of fields present or absent, this section specifies their relative order in the object. The implementer is responsible for determining which fields are actually present in a given **metafile** record, and for unmarshaling the data for individual fields separately and appropriately.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TransformMatrix (24 bytes, optional) |
| ... |
| ... |
| ... |
| ImageObject (variable) |
| ... |

**TransformMatrix (24 bytes): **An optional EmfPlusTransformMatrix object (section 2.2.2.47) that specifies a **world space** to **device space** **transform** for the texture brush. This field MUST be present if the **BrushDataTransform** flag is set in the **BrushDataFlags** field of the EmfPlusTextureBrushData object.

**ImageObject (variable): **An optional EmfPlusImage object (section 2.2.1.4) that specifies the brush texture. This field MUST be present if the size of the EmfPlusObject record (section 2.3.5.1) that defines this texture brush is large enough to accommodate an EmfPlusImage object in addition to the required fields of the EmfPlusTextureBrushData object and optionally an EmfPlusTransformMatrix object.

Graphics brushes are specified by EmfPlusBrush objects (section 2.2.1.1).

See section 2.2.2 for the specification of additional structure objects.

#### EmfPlusTransformMatrix Object

The **EmfPlusTransformMatrix** object specifies a **world space** to **device space** **transform**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TransformMatrix (24 bytes) |
| ... |
| ... |
| ... |

**TransformMatrix (24 bytes): **An **affine transform**, which requires a 2x2 matrix for a linear transformation and a 1x2 matrix for a **tran****slation**. These values map to the coordinates of the transform matrix as follows:

**TransformMatrix[0]** Corresponds to m11, which is the coordinate of the first row and first column of the 2x2 matrix.

**TransformMatrix[1]** Corresponds to m12, which is the coordinate of the first row and second column of the 2x2 matrix.

**TransformMatrix[2]** Corresponds to m21, which is the coordinate of the second row and first column of the 2x2 matrix.

**TransformMatrix[3]** Corresponds to m22, which is the coordinate of the second row and second column of the 2x2 matrix.

**TransformMatrix[4]** Corresponds to dx, which is the horizontal displacement in the 1x2 matrix.

**TransformMatrix[5]** Corresponds to dy, which is the vertical displacement in the 1x2 matrix.

See section 2.2.2 for the specification of additional structure objects.

### Image Effects Object Types

The **Image Effects Objects** specify parameters for graphics **image effects**, which can be applied to **bitmap** images.<17>

Parameters are specified for the following image effects:

| Name | Section | Description |
| --- | --- | --- |
| BlurEffect | 2.2.3.1 | A decrease in the difference in **intensity** between pixels in an image. |
| BrightnessContrastEffect | 2.2.3.2 | An expansion or contraction of the lightest and darkest areas of an image. |
| ColorBalanceEffect | 2.2.3.3 | Adjustments to the relative amounts of red, green, and blue in an image. |
| ColorCurveEffect | 2.2.3.4 | One of eight adjustments to an image, including **exposure**, **density**, **contrast**, **highlight**, **shadow**, **midtone**, **white saturation**, or **black satura****tion**. |
| ColorLookupTableEffect | 2.2.3.5 | Adjustments to the colors in an image. |
| ColorMatrixEffect | 2.2.3.6 | An **affine transform** to be applied to an image. |
| HueSaturationLightnessEffect | 2.2.3.7 | Adjustments to the **hue**, **saturation**, and **lightness** of an image. |
| LevelsEffect | 2.2.3.8 | Adjustments to the highlights, midtones, and shadows of an image. |
| RedEyeCorrectionEffect | 2.2.3.9 | Areas of an image to which a **red-eye correction effect** is applied. |
| SharpenEffect | 2.2.3.10 | An increase in the difference in intensity between pixels in an image. |
| TintEffect | 2.2.3.11 | An addition of black or white to a specified hue in an image. |

#### BlurEffect Object

The **BlurEffect** object specifies a decrease in the difference in intensity between pixels in an image.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BlurRadius |
| ExpandEdge |

**BlurRadius (4 bytes): **A floating-point value that specifies the **blur** radius in pixels, which determines the number of pixels involved in calculating the new value of a given pixel. This value MUST be in the range 0.0 through 255.0.

As this value increases, the number of pixels involved in the calculation increases, and the resulting **bitmap** SHOULD become more blurry.

**ExpandEdge (4 bytes): **A Boolean value that specifies whether the bitmap expands by an amount equal to the value of the **BlurRadius** to produce soft edges. This value MUST be one of the following:

| Value | Meaning |
| --- | --- |
| FALSE0x00000000 | The size of the bitmap MUST NOT change, and its soft edges SHOULD be clipped to the size of the **BlurRadius**. |
| TRUE0x00000001 | The size of the bitmap SHOULD expand by an amount equal to the **BlurRadius** to produce soft edges. |

Bitmap images are specified by EmfPlusBitmap objects (section 2.2.2.2).

See section 2.2.3 for the specification of additional image effects parameter objects.

#### BrightnessContrastEffect Object

The **Brightness****ContrastEffect** object specifies an expansion or contraction of the lightest and darkest areas of an image.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BrightnessLevel |
| ContrastLevel |

**BrightnessLevel (4 bytes): **A signed integer that specifies the **brightness** level. This value MUST be in the range -255 through 255, with effects as follows:

| Value | Meaning |
| --- | --- |
| -255 ≤ *value* < 0 | As the value decreases, the brightness of the image SHOULD decrease. |
| 0 | A value of 0 specifies that the brightness MUST NOT change. |
| 0 < *value* ≤ 255 | As the value increases, the brightness of the image SHOULD increase. |

**ContrastLevel (4 bytes): **A signed integer that specifies the **contrast** level. This value MUST be in the range -100 through 100, with effects as follows:

| Value | Meaning |
| --- | --- |
| -100 ≤ *value* < 0 | As the value decreases, the contrast of the image SHOULD decrease. |
| 0 | A value of 0 specifies that the contrast MUST NOT change. |
| 0 < *value* ≤ 100 | As the value increases, the contrast of the image SHOULD increase. |

**Bitmap** images are specified by EmfPlusBitmap objects (section 2.2.2.2).

See section 2.2.3 for the specification of additional image effects parameter objects.

#### ColorBalanceEffect Object

The **ColorBalanceEffect** object specifies adjustments to the relative amounts of red, green, and blue in an image.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| CyanRed |
| MagentaGreen |
| YellowBlue |

**CyanRed (4 bytes): **A signed integer that specifies a change in the amount of red in the image. This value MUST be in the range -100 through 100, with effects as follows:

| Value | Meaning |
| --- | --- |
| -100 ≤ *value* < 0 | As the value decreases, the amount of red in the image SHOULD decrease and the amount of cyan SHOULD increase. |
| 0 | A value of 0 specifies that the amounts of red and cyan MUST NOT change. |
| 0 < *value* ≤ 100 | As the value increases, the amount of red in the image SHOULD increase and the amount of cyan SHOULD decrease. |

**MagentaGreen (4 bytes): **A signed integer that specifies a change in the amount of green in the image. This value MUST be in the range -100 through 100, with effects as follows:

| Value | Meaning |
| --- | --- |
| -100 ≤ *value* < 0 | As the value decreases, the amount of green in the image SHOULD decrease and the amount of magenta SHOULD increase. |
| 0 | A value of 0 specifies that the amounts of green and magenta MUST NOT change. |
| 0 < *value* ≤ 100 | As the value increases, the amount of green in the image SHOULD increase and the amount of magenta SHOULD decrease. |

**YellowBlue (4 bytes): **A signed integer that specifies a change in the amount of blue in the image. This value MUST be in the range -100 through 100, with effects as follows:

| Value | Meaning |
| --- | --- |
| -100 ≤ *value* < 0 | As the value decreases, the amount of blue in the image SHOULD decrease and the amount of yellow SHOULD increase. |
| 0 | A value of 0 specifies that the amounts of blue and yellow MUST NOT change. |
| 0 < *value* ≤ 100 | As the value increases, the amount of blue in the image SHOULD increase and the amount of yellow SHOULD decrease. |

**Bitmap** images are specified by EmfPlusBitmap objects (section 2.2.2.2).

See section 2.2.3 for the specification of additional image effects parameter objects.

#### ColorCurveEffect Object

The **ColorCurveEffect** object specifies one of eight adjustments to the **color curve** of an image.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| CurveAdjustment |
| CurveChannel |
| AdjustmentIntensity |

**CurveAdjustment (4 bytes): **An unsigned integer that specifies the curve adjustment to apply to the colors in **bitmap**. This value is defined in the CurveAdjustments enumeration (section 2.1.1.7).

**CurveChannel (4 bytes): **An unsigned integer that specifies the **color channel** to which the curve adjustment applies. This value is defined in the CurveChannel enumeration (section 2.1.1.8).

**AdjustmentIntensity (4 bytes): **A signed integer that specifies the **intensity** of the curve adjustment to the color channel specified by **CurveChannel**. The ranges of meaningful values for this field vary according to the **CurveAdjustment** value, as follows:

**Exposure** adjustment range:

| Value | Meaning |
| --- | --- |
| -255 ≤ *value* < 0 | As the value decreases, the exposure of the image SHOULD decrease. |
| 0 | A value of 0 specifies that the exposure MUST NOT change. |
| 0 < *value* ≤ 255 | As the value increases, the exposure of the image SHOULD increase. |

**Density** adjustment range:

| Value | Meaning |
| --- | --- |
| -255 ≤ *value* < 0 | As the value decreases, the density of the image SHOULD decrease, resulting in a darker image. |
| 0 | A value of 0 specifies that the density MUST NOT change. |
| 0 < *value* ≤ 255 | As the value increases, the density of the image SHOULD increase. |

**Contrast** adjustment range:

| Value | Meaning |
| --- | --- |
| -100 ≤ *value* < 0 | As the value decreases, the contrast of the image SHOULD decrease. |
| 0 | A value of 0 specifies that the contrast MUST NOT change. |
| 0 < *value* ≤ 100 | As the value increases, the contrast of the image SHOULD increase. |

**Highlight** adjustment range:

| Value | Meaning |
| --- | --- |
| -100 ≤ *value* < 0 | As the value decreases, the light areas of the image SHOULD appear darker. |
| 0 | A value of 0 specifies that the highlight MUST NOT change. |
| 0 < *value* ≤ 100 | As the value increases, the light areas of the image SHOULD appear lighter. |

**Shadow** adjustment range:

| Value | Meaning |
| --- | --- |
| -100 ≤ *value* < 0 | As the value decreases, the dark areas of the image SHOULD appear darker. |
| 0 | A value of 0 specifies that the shadow MUST NOT change. |
| 0 < *value* ≤ 100 | As the value increases, the dark areas of the image SHOULD appear lighter. |

**Midtone** adjustment range:

| Value | Meaning |
| --- | --- |
| -100 ≤ *value* < 0 | As the value decreases, the midtones of the image SHOULD appear darker. |
| 0 | A value of 0 specifies that the midtone MUST NOT change. |
| 0 < *value* ≤ 100 | As the value increases, the midtones of the image SHOULD appear lighter. |

**White saturation** adjustment range:

| Value | Meaning |
| --- | --- |
| 0 — 255 | As the value increases, the upper limit of the range of color channel intensities increases. |

**Black saturation** adjustment range:

| Value | Meaning |
| --- | --- |
| 0 — 255 | As the value increases, the lower limit of the range of color channel intensities increases. |

Bitmap images are specified by EmfPlusBitmap objects (section 2.2.2.2).

See section 2.2.3 for the specification of additional image effects parameter objects.

#### ColorLookupTableEffect Object

The **ColorLookupTableEffect** object specifies adjustments to the colors in an image.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BlueLookupTable (256 bytes) |
| ... |
| ... |
| ... |
| GreenLookupTable (256 bytes) |
| ... |
| ... |
| ... |
| RedLookupTable (256 bytes) |
| ... |
| ... |
| ... |
| AlphaLookupTable (256 bytes) |
| ... |
| ... |
| ... |

**BlueLookupTable (256 bytes): **An array of 256 bytes that specifies the adjustment for the blue **color channel**.

**GreenLookupTable (256 bytes): **An array of 256 bytes that specifies the adjustment for the green color channel.

**Red****LookupTable (256 bytes): **An array of 256 bytes that specifies the adjustment for the red color channel.

**AlphaLookupTable (256 bytes): **An array of 256 bytes that specifies the adjustment for the **alpha** color channel.

**Bitmap** images are specified by EmfPlusBitmap objects (section 2.2.2.2).

See section 2.2.3 for the specification of additional image effects parameter objects.

#### ColorMatrixEffect Object

The **ColorMatrixEffect** object specifies an **affine transform** to be applied to an image.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Matrix_N_0 (20 bytes) |
| ... |
| ... |
| ... |
| Matrix_N_1 (20 bytes) |
| ... |
| ... |
| ... |
| Matrix_N_2 (20 bytes) |
| ... |
| ... |
| ... |
| Matrix_N_3 (20 bytes) |
| ... |
| ... |
| ... |
| Matrix_N_4 (20 bytes) |
| ... |
| ... |
| ... |

**Matrix_N_0 (20 bytes): **Matrix[N][0] of the 5x5 **color matrix**. This row is used for transforms.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Matrix_0_0 |
| Matrix_1_0 |
| Matrix_2_0 |
| Matrix_3_0 |
| Matrix_4_0 |

**Matrix_0_0 (4 bytes): **Matrix[0][0], which is the factor for the color red.

**Matrix_1_0 (4 bytes): **Matrix[1][0].

**Matrix_2_0 (4 bytes): **Matrix[2][0].

**Matrix_3_0 (4 bytes): **Matrix[3][0].

**Matrix_4_0 (4 bytes): **Matrix[4][0]. This value MUST be 0.0.

**Matrix_N_1 (20 bytes): **Matrix[N][1] of the 5x5 color matrix. This row is used for transforms.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Matrix_0_1 |
| Matrix_1_1 |
| Matrix_2_1 |
| Matrix_3_1 |
| Matrix_4_1 |

**Matrix_0_1 (4 bytes): **Matrix[0][1].

**Matrix_1_1 (4 bytes): **Matrix[1][1], which is the factor for the color green.

**Matrix_2_1 (4 bytes): **Matrix[2][1].

**Matrix_3_1 (4 bytes): **Matrix[3][1].

**Matrix_4_1 (4 bytes): **Matrix[4][1]. This value MUST be 0.0.

**Matrix_N_2 (20 bytes): **Matrix[N][2] of the 5x5 color matrix. This row is used for transforms.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Matrix_0_2 |
| Matrix_1_2 |
| Matrix_2_2 |
| Matrix_3_2 |
| Matrix_4_2 |

**Matrix_0_2 (4 bytes): **Matrix[0][2].

**Matrix_1_2 (4 bytes): **Matrix[1][2].

**Matrix_2_2 (4 bytes): **Matrix[2][2], which is the factor for the color blue.

**Matrix_3_2 (4 bytes): **Matrix[3][2].

**Matrix_4_2 (4 bytes): **Matrix[4][2]. This value MUST be 0.0.

**Matrix_N_3 (20 bytes): **Matrix[N][3] of the 5x5 color matrix. This row is used for transforms.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Matrix_0_3 |
| Matrix_1_3 |
| Matrix_2_3 |
| Matrix_3_3 |
| Matrix_4_3 |

**Matrix_0_3 (4 bytes): **Matrix[0][3].

**Matrix_1_3 (4 bytes): **Matrix[1][3].

**Matrix_2_3 (4 bytes): **Matrix[2][3].

**Matrix_3_3 (4 bytes): **Matrix[3][3], which is the factor for the **alpha** (transparency) value.

**Matrix_4_3 (4 bytes): **Matrix[4][3]. This value MUST be 0.0.

**Matrix_N_4 (20 bytes): **Matrix[N][4] of the 5x5 color matrix. This row is used for color **translations**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Matrix_0_4 |
| Matrix_1_4 |
| Matrix_2_4 |
| Matrix_3_4 |
| Matrix_4_4 |

**Matrix_0_4 (4 bytes): **Matrix[0][4].

**Matrix_1_4 (4 bytes): **Matrix[1][4].

**Matrix_2_4 (4 bytes): **Matrix[2][4].

**Matrix_3_4 (4 bytes): **Matrix[3][4].

**Matrix_4_4 (4 bytes): **Matrix[4][4]. This value SHOULD be 1.0.<18>

**Bitmap** images are specified by EmfPlusBitmap objects (section 2.2.2.2). A **color matrix effect** is performed by multiplying a **color vector** by a ColorMatrixEffect object. A 5x5 color matrix can perform a linear **transform**, including **reflection**, **rotation**, **shearing**, or **scaling** followed by a translation.

See section 2.2.3 for the specification of additional image effects parameter objects.

#### HueSaturationLightnessEffect Object

The **HueSaturationLightnessEffect** object specifies adjustments to the **hue**, **saturation**, and **lightness** of an image.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| HueLevel |
| SaturationLevel |
| LightnessLevel |

**HueLevel (4 bytes): **The adjustment to the hue.

| Value | Meaning |
| --- | --- |
| -180 ≤ *value* < 0 | Negative values specify clockwise rotation on the **color wheel**. |
| 0 | A value of 0 specifies that the hue MUST NOT change. |
| 0 < *value* ≤ 180 | Positive values specify counter-clockwise rotation on the color wheel. |

**SaturationLevel (4 bytes): **The adjustment to the saturation.

| Value | Meaning |
| --- | --- |
| -100 ≤ *value* < 0 | Negative values specify decreasing saturation. |
| 0 | A value of 0 specifies that the saturation MUST NOT change. |
| 0 < *value* ≤ 100 | Positive values specify increasing saturation. |

**LightnessLevel (4 bytes): **The adjustment to the lightness.

| Value | Meaning |
| --- | --- |
| -100 ≤ *value* < 0 | Negative values specify decreasing lightness. |
| 0 | A value of 0 specifies that the lightness MUST NOT change. |
| 0 < *value* ≤ 100 | Positive values specify increasing lightness. |

**Bitmap** images are specified by EmfPlusBitmap objects (section 2.2.2.2).

See section 2.2.3 for the specification of additional image effects parameter objects.

#### LevelsEffect Object

The LevelsEffect object specifies adjustments to the **highlights**, **midtones**, and **shadows** of an image.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Highlight |
| MidTone |
| Shadow |

**Highlight (4 bytes): **How much to lighten the highlights of an image. The **color channel** values at the high end of the **intensity** range are altered more than values near the middle or low ends, which means an image can be lightened without losing the contrast between the darker portions of the image.

| Value | Meaning |
| --- | --- |
| 0 ≤ *value* < 100 | Highlights with a percent of intensity above this threshold SHOULD be increased. |
| 100 | Highlights MUST NOT change. |

**MidTone (4 bytes): **How much to lighten or darken the midtones of an image. Color channel values in the middle of the intensity range are altered more than values near the high or low ends, which means an image can be lightened or darkened without losing the contrast between the darkest and lightest portions of the image.

| Value | Meaning |
| --- | --- |
| -100 ≤ *value* < 0 | Midtones are made darker. |
| 0 | Midtones MUST NOT change. |
| 0 < *value* ≤ 100 | Midtones are made lighter. |

**Shadow (4 bytes): **How much to darken the shadows of an image. Color channel values at the low end of the intensity range are altered more than values near the middle or high ends, which means an image can be darkened without losing the contrast between the lighter portions of the image.

| Value | Meaning |
| --- | --- |
| 0 | Shadows MUST NOT change. |
| 0 < *value* ≤ 100 | Shadows with a percent of intensity below this threshold are made darker. |

**Bitmap** images are specified by EmfPlusBitmap objects (section 2.2.2.2).

See section 2.2.3 for the specification of additional image effects parameter objects.

#### RedEyeCorrectionEffect Object

The **RedEyeCorrectionEffect** object specifies areas of an image to which a **red-eye correction** is applied.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| NumberOfAreas |
| Areas (variable) |
| ... |

**NumberOfAreas (4 bytes): **A signed integer that specifies the number of rectangles in the **Areas** field.

**Areas (variable): **An array of **NumberOfAreas** **WMF** RectL objects ([MS-WMF] section 2.2.2.19). Each rectangle specifies an area of the **bitmap** image to which the red-eye correction effect SHOULD be applied.

Bitmap images are specified by EmfPlusBitmap objects (section 2.2.2.2).

See section 2.2.3 for the specification of additional image effects parameter objects.

#### SharpenEffect Object

The **SharpenEffect** object specifies an increase in the difference in intensity between pixels in an image.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Radius |
| Amount |

**Radius (4 bytes): **A floating-point value that specifies the **sharpening** radius in pixels, which determines the number of pixels involved in calculating the new value of a given pixel.

As this value increases, the number of pixels involved in the calculation increases, and the resulting **bitmap** SHOULD become sharper.

**Amount (4 bytes): **A floating-point value that specifies the difference in intensity between a given pixel and the surrounding pixels.

| Value | Meaning |
| --- | --- |
| 0 | Sharpening MUST NOT be performed. |
| 0 < *value* ≤ 100 | As this value increases, the difference in intensity between pixels SHOULD increase. |

Bitmap images are specified by EmfPlusBitmap objects (section 2.2.2.2).

See section 2.2.3 for the specification of additional image effects parameter objects.

#### TintEffect Object

The **TintEffect** object specifies an addition of black or white to a specified **hue** in an image.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Hue |
| Amount |

**Hue (4 bytes): **A signed integer that specifies the hue to which the **tint effect** is applied.

| Value | Meaning |
| --- | --- |
| -180 ≤ *value* < 0 | The color at a specified counter-clockwise rotation of the **color wheel**, starting from blue. |
| 0 | A value of 0 specifies the color blue on the color wheel. |
| 0 < *value* ≤ 180 | The color at a specified clockwise rotation of the color wheel, starting from blue. |

**Amount (4 bytes): **A signed integer that specifies how much the hue is strengthened or weakened.

| Value | Meaning |
| --- | --- |
| -100 ≤ *value* < 0 | Negative values specify how much the hue is weakened, which equates to the addition of black. |
| 0 | A value of 0 specifies that the **tint** MUST NOT change. |
| 0 < *value* ≤ 100 | Positive values specify how much the hue is strengthened, which equates to the addition of white. |

**Bitmap** images are specified by EmfPlusBitmap objects (section 2.2.2.2).

See section 2.2.3 for the specification of additional image effects parameter objects.

## EMF+ Records

This section specifies the Records, which are grouped into the following categories:

| Name | Section | Description |
| --- | --- | --- |
| Clipping record types | 2.3.1 | Specify clipping regions and operations. |
| Comment record types | 2.3.2 | Specify arbitrary private data in the **EMF+** **metafile**. |
| Control record types | 2.3.3 | Specify global parameters for EMF+ metafile processing. |
| Drawing record types | 2.3.4 | Specify graphics output. |
| Object record types | 2.3.5 | Define reusable graphics objects. |
| Property record types | 2.3.6 | Specify properties of the **playback device context**. |
| State record types | 2.3.7 | Specify operations on the state of the playback device context. |
| Terminal Server record types | 2.3.8 | Specify graphics processing on a **terminal server**. |
| Transform record types | 2.3.9 | Specify properties and transforms on **coordinate spaces**. |

### Clipping Record Types

The **Clipping Record** types specify clipping regions and operations. The following are **EMF+** clipping record types:

| Name | Section | Description |
| --- | --- | --- |
| EmfPlusOffsetClip | 2.3.1.1 | Applies a **translation** **transform** on the current clipping **region** for the **world space**. |
| EmfPlusResetClip | 2.3.1.2 | Resets the current clipping region for the world space to infinity. |
| EmfPlusSetClipPath | 2.3.1.3 | Combines the current clipping region with a graphics **path**. |
| EmfPlusSetClipRect | 2.3.1.4 | Combines the current clipping region with a rectangle. |
| EmfPlusSetClipRegion | 2.3.1.5 | Combines the current clipping region with another graphics region. |

The generic structure of EMF+ clipping records is specified as follows:

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| RecordData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies the record type. The clipping record types are listed below. See the table above for descriptions of these records.

| Name | Value |
| --- | --- |
| EmfPlusResetClip | 0x4031 |
| EmfPlusSetClipRect | 0x4032 |
| EmfPlusSetClipPath | 0x4033 |
| EmfPlusSetClipRegion | 0x4034 |
| EmfPlusOffsetClip | 0x4035 |

**Flags (2 bytes): **An unsigned integer that contains information for some records on how the operation is to be performed and on the structure of the record.

**Size (4 bytes): **An unsigned integer that defines the 32-bit–aligned size of the entire record in bytes, including the 12-byte record header and the record-specific data.

**DataSize (4 bytes): **An unsigned integer that defines the 32-bit–aligned number of bytes of data in the **RecordData** field that follows. This number does not include the 12-byte record header.

**RecordData (variable): **An optional, variable-length array of bytes that, if present, defines the data specific to individual records. For specifications of the additional information, if any, contained within this field, see individual record definitions.

#### EmfPlusOffsetClip Record

The EmfPlusOffsetClip record applies a **translation** **transform** on the current clipping **region** for the **world space**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| dx |
| dy |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusOffsetClip from the RecordType enumeration. The value MUST be 0x4035.

**Flags (2 bytes): **An unsigned integer that is reserved and MUST be ignored.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned size of the entire record in bytes, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x00000014.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of data in the record-specific data that follows. This number does not include the size of the invariant part of this record. For this record type, the value MUST be 0x00000008.

**dx (4 bytes)****: **A floating-point value that specifies the horizontal offset for the translation.

**dy (4 bytes): **A floating-point value that specifies the vertical offset for the translation.

The new current clipping region is set to the result of the translation transform.

See section 2.3.1 for the specification of additional clipping record types.

#### EmfPlusResetClip Record

The EmfPlusResetClip record resets the current clipping **region** for the **world space** to infinity.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusResetClip from the RecordType enumeration. The value MUST be 0x4031.

**Flags (2 bytes): **An unsigned integer that is reserved and MUST be ignored.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned size of the entire record in bytes, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x0000000C.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of data in the record-specific data that follows. This number does not include the size of the invariant part of this record. For this record type, the value MUST be 0x00000000.

See section 2.3.1 for the specification of additional clipping record types.

#### EmfPlusSetClipPath Record

The EmfPlusSetClipPath record combines the current clipping **region** with a graphics **path**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusSetClipPath from the RecordType enumeration. The value MUST be 0x4033.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | X | X | X | CM | ObjectID |

**X (1 bit): **Reserved and MUST be ignored.

**CM (4 bits): **The logical operation for combining two regions. See the CombineMode enumeration for the meanings of the values.

**ObjectI****D (1 byte): **The index of an EmfPlusPath object in the **EMF+** Object Table (section 3.1.2). The value MUST be zero to 63, inclusive.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned size of the entire record in bytes, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x0000000C.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of data in the record-specific data that follows. This number does not include the size of the invariant part of this record. For this record type, the value MUST be 0x00000000.

The new current clipping region is set to the result of the CombineMode operation.

See section 2.3.1 for the specification of additional clipping record types.

#### EmfPlusSetClipRect Record

The EmfPlusSetClipRect record combines the current clipping **region** with a rectangle.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| ClipRect |
| ... |
| ... |
| ... |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusSetClipRect from the RecordType enumeration. The value MUST be 0x4032.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | X | X | X | CM | X | X | X | X | X | X | X | X |

**X (1 bit): **Reserved and MUST be ignored.

**CM (4 bits): **The logical operation for combining two regions. See the CombineMode enumeration for the meanings of the values.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned size of the entire record in bytes, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x0000001C.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of data in the record-specific data that follows. This number does not include the size of the invariant part of this record. For this record type, the value MUST be 0x00000010.

**ClipRect (16 bytes): **An EmfPlusRectF object that defines the rectangle to use in the CombineMode operation.

The new current clipping region is set to the result of the CombineMode operation.

See section 2.3.1 for the specification of additional clipping record types.

#### EmfPlusSetClipRegion Record

The EmfPlusSetClipRegion record combines the current clipping **region** with another graphics region.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |

**Type (2 bytes): **An unsigned integer that identifies this record type as **EmfPlusSetClipRegion** from the RecordType enumeration. The value MUST be 0x4034.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | X | X | X | CM | ObjectID |

**X (1 bit): **Reserved and MUST be ignored.

**CM (4 bits): **The logical operation for combining two regions. See the CombineMode enumeration for the meanings of the values.

**ObjectI****D (1 byte): **The index of an EmfPlusRegion object in the EMF+ Object Table. The value MUST be zero to 63, inclusive.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned size of the entire record in bytes, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x0000000C.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of data in the record-specific data that follows. This number does not include the size of the invariant part of this record. For this record type, the value MUST be 0x00000000.

The new current clipping region is set to the result of performing the CombineMode operation on the previous current clipping region and the specified EmfPlusRegion object.

See section 2.3.1 for the specification of additional clipping record types.

### Comment Record Types

The Comment record type defines a format for specifying arbitrary private data. 

| Name | Section | Description |
| --- | --- | --- |
| EmfPlusComment | 2.3.2.1 | Specifies arbitrary private data. |

#### EmfPlusComment Record

The EmfPlusComment record specifies arbitrary private data.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| PrivateData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusComment from the RecordType enumeration. The value MUST be 0x4003.

**Flags (2 bytes): **An unsigned integer that is not used. This field SHOULD be set to zero and MUST be ignored upon receipt.<19>

**Size (4 bytes): **An unsigned integer that specifies the 32-bit–aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, it MUST be computed as follows:

Size = DataSize + 0x0000000C

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit–aligned number of bytes of record-specific data that follows.

**PrivateData (variable): **A **DataSize**-length byte array of private data.

### Control Record Types

The control record types specify global parameters for **EMF+** **metafile** processing. The following are EMF+ control record types:

| Name | Section | Description |
| --- | --- | --- |
| EmfPlusEndOfFile | 2.3.3.1 | Specifies the end of EMF+ data in the metafile. |
| EmfPlusGetDC | 2.3.3.2 | Specifies the processing of subsequent **EMF** records ([MS-EMF] section 2.3) encountered in the metafile. |
| EmfPlusHeader | 2.3.3.3 | Specifies the start of EMF+ data in the metafile. |

The generic structure of EMF+ control records is specified as follows:

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| RecordData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies the record type. The control record types are listed below. See the table above for descriptions of these records.

| Name | Value |
| --- | --- |
| EmfPlusHeader | 0x4001 |
| EmfPlusEndOfFile | 0x4002 |
| EmfPlusGetDC | 0x4004 |

**Flags (2 bytes): **An unsigned integer that contains information for some records on how the operation is to be performed and on the structure of the record.

**Size (4 bytes): **An unsigned integer that defines the 32-bit–aligned size of the entire record in bytes, including the 12-byte record header and the record-specific data.

**DataSize (4 bytes): **An unsigned integer that defines the 32-bit–aligned number of bytes of data in the **RecordData** field that follows. This number does not include the 12-byte record header.

**RecordData (variable): **An optional, variable-length array of bytes that, if present, defines the data specific to individual records. For specifications of the additional information, if any, which is contained within this field, see individual record definitions.

#### EmfPlusEndOfFile Record

The EmfPlusEndOfFile record specifies the end of **EMF+** data in the **metafile**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusEndOfFile from the RecordType enumeration. The value MUST be 0x4002.

**Flags (2 bytes): **An unsigned integer that is not used. This field SHOULD be set to zero and MUST be ignored upon receipt.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x0000000C.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of data in the record-specific data that follows. For this record type, the value MUST be 0x00000000.

See section 2.3.3 for the specification of additional control record types.

#### EmfPlusGetDC Record

The EmfPlusGetDC record specifies that subsequent EMF records ([MS-EMF] section 2.3) encountered in the **metafile** SHOULD be processed.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusGetDC from the RecordType enumeration. The value MUST be 0x4004.

**Flags (2 bytes): **An unsigned integer that is not used. This field SHOULD be set to zero and MUST be ignored upon receipt.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned size of the entire record in bytes, including the 12-byte record header and the record-specific buffer data. For this record type, the value is 0x0000000C.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of data in the record-specific data that follows. This number does not include the size of the invariant part of this record. For this record type, the value is 0x00000000.

EMF records cease being processed when the next EMF+ record is encountered.

See section 2.3.3 for the specification of additional control record types.

#### EmfPlusHeader Record

The EmfPlusHeader record specifies the start of **EMF+** data in the **metafile**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| Version |
| EmfPlusFlags |
| LogicalDpiX |
| LogicalDpiY |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusHeader from the RecordType enumeration. The value MUST be 0x4001.

**Flags (2 bytes): **An unsigned integer that provides information about the structure of the metafile.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | X | X | X | X | X | X | X | X | X | X | X | X | X | X | D |

**X (1 bit): **Reserved and MUST be ignored.

**D (1 bit): **If set, this flag indicates that this metafile is **EMF+ Dual**, which means that it contains two sets of records, each of which completely specifies the graphics content. If clear, the graphics content is specified by EMF+ records, and possibly EMF records ([MS-EMF] section 2.3) that are preceded by an EmfPlusGetDC record. If this flag is set, EMF records alone SHOULD suffice to define the graphics content. Note that whether the **EMF+ Dual** flag is set or not, some EMF records are always present, namely EMF control records and the EMF records that contain EMF+ records.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned size of the entire record in bytes, including the 12-byte record header and record-specific data. For this record type, the value is 0x0000001C.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of data in the record-specific data that follows. This number does not include the size of the invariant part of this record. For this record type, the value is 0x00000010.

**Version (4 bytes): **An EmfPlusGraphicsVersion object that specifies the version of operating system graphics that was used to create this metafile.

**EmfPlusFlags (4 bytes): **An unsigned integer that contains information about how this metafile was recorded.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X | V |

**X (1 bit): **Reserved and MUST be ignored.

**V (1 bit): **If set, this flag indicates that the metafile was recorded with a reference **device context** for a video display. If clear, the metafile was recorded with a reference device context for a printer.

**LogicalDpiX (4 bytes): **An unsigned integer that specifies the horizontal resolution for which the metafile was recorded, in units of pixels per inch.

**LogicalDpiY (4 bytes): **An unsigned integer that specifies the vertical resolution for which the metafile was recorded, in units of lines per inch.

The EmfPlusHeader record MUST be embedded in an **EMF** EMR_COMMENT_EMFPLUS record, which MUST be the record immediately following the EMF header in the metafile.

See section 2.3.3 for the specification of additional control record types.

### Drawing Record Types

The drawing record types specify graphics output. The following are **EMF+** drawing record types:

| Name | Section | Description |
| --- | --- | --- |
| EmfPlusClear | 2.3.4.1 | Clears the output **coordinate space** and initializes it with a background color and transparency. |
| EmfPlusDrawArc | 2.3.4.2 | Draws the arc of an ellipse. |
| EmfPlusDrawBeziers | 2.3.4.3 | Draws a sequence of connected **Bezier curves**. |
| EmfPlusDrawClosedCurve | 2.3.4.4 | Draws a **closed cardinal spline**. |
| EmfPlusDrawCurve | 2.3.4.5 | Draws a **cardinal spline**. |
| EmfPlusDrawDriverString | 2.3.4.6 | Outputs text with character positions. |
| EmfPlusDrawEllipse | 2.3.4.7 | Draws an ellipse. |
| EmfPlusDrawImage | 2.3.4.8 | Draws a scaled image. |
| EmfPlusDrawImagePoints | 2.3.4.9 | Draws a scaled image inside a parallelogram. |
| EmfPlusDrawLines | 2.3.4.10 | Draws a series of connected lines. |
| EmfPlusDrawPath | 2.3.4.11 | Draws a graphics **path**. |
| EmfPlusDrawPie | 2.3.4.12 | Draws a section of the interior of an ellipse. |
| EmfPlusDrawRects | 2.3.4.13 | Draws a series of rectangles. |
| EmfPlusDrawString | 2.3.4.14 | Outputs text with string formatting. |
| EmfPlusFillClosedCurve | 2.3.4.15 | Draws the interior of a closed cardinal spline. |
| EmfPlusFillEllipse | 2.3.4.16 | Draws the interior of an ellipse. |
| EmfPlusFillPath | 2.3.4.17 | Draws the interior of a graphics path. |
| EmfPlusFillPie | 2.3.4.18 | Draws a section of the interior of an ellipse. |
| EmfPlusFillPolygon | 2.3.4.19 | Draws the interior of a polygon. |
| EmfPlusFillRects | 2.3.4.20 | Draws the interiors of a series of rectangles. |
| EmfPlusFillRegion | 2.3.4.21 | Draws the interior of a graphics **region**. |

The generic structure of EMF+ drawing records is specified as follows:

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| RecordData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies the record type. The drawing record types are listed below. See the table above for descriptions of these records.

| Name | Value |
| --- | --- |
| EmfPlusClear | 0x4009 |
| EmfPlusFillRects | 0x400A |
| EmfPlusDrawRects | 0x400B |
| EmfPlusFillPolygon | 0x400C |
| EmfPlusDrawLines | 0x400D |
| EmfPlusFillEllipse | 0x400E |
| EmfPlusDrawEllipse | 0x400F |
| EmfPlusFillPie | 0x4010 |
| EmfPlusDrawPie | 0x4011 |
| EmfPlusDrawArc | 0x4012 |
| EmfPlusFillRegion | 0x4013 |
| EmfPlusFillPath | 0x4014 |
| EmfPlusDrawPath | 0x4015 |
| EmfPlusFillClosedCurve | 0x4016 |
| EmfPlusDrawClosedCurve | 0x4017 |
| EmfPlusDrawCurve | 0x4018 |
| EmfPlusDrawBeziers | 0x4019 |
| EmfPlusDrawImage | 0x401A |
| EmfPlusDrawImagePoints | 0x401B |
| EmfPlusDrawString | 0x401C |
| EmfPlusDrawDriverString | 0x4036 |

**Flags (2 bytes): **An unsigned integer that contains information for some records on how the operation is to be performed and on the structure of the record.

**Siz****e (4 bytes): **An unsigned integer that defines the 32-bit-aligned size of the entire record in bytes, including the 12-byte record header and the record-specific data.

**DataSize (4 bytes): **An unsigned integer that defines the 32-bit-aligned number of bytes of data in the **RecordData** field that follows. This number does not include the 12-byte record header.

**RecordData (variable): **An optional, variable-length array of bytes that, if present, defines the data specific to individual records. For specifications of the additional information, if any, which is contained within this field, see individual record definitions.

#### EmfPlusClear Record

The EmfPlusClear record clears the output **coordinate space** and initializes it with a background color and transparency.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| Color |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusClear from the RecordType enumeration. The value MUST be 0x4009.

**Flags (2 bytes): **An unsigned integer that is not used. This field SHOULD be set to zero and MUST be ignored upon receipt.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, it MUST be 0x00000010.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, it MUST be 0x00000004.

**Color (4 bytes): **An EmfPlusARGB object that defines the color to paint the screen. All colors are specified in [IEC-RGB], unless otherwise noted.

See section 2.3.4 for the specification of additional drawing record types.

#### EmfPlusDrawArc Record

The EmfPlusDrawArc record specifies drawing the arc of an ellipse.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| StartAngle |
| SweepAngle |
| RectData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusDrawArc from the RecordType enumeration. The value MUST be 0x4012.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | C | X | X | X | X | X | X | ObjectID |

**X (1 bit): **Reserved and MUST be ignored.

**C (1 bit): **This bit indicates whether the data in the **RectData** field is compressed.

If set, **RectData** contains an EmfPlusRect object. If clear, **RectData** contains an EmfPlusRectF object.

**ObjectID (1 byte): **The index of an EmfPlusPen object in the EMF+ Object Table to draw the arc. The value MUST be zero to 63, inclusive.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be one of the following:

| Value | Meaning |
| --- | --- |
| 0x0000001C | If the **C** bit is set in the **Flags** field. |
| 0x00000024 | If the **C** bit is clear in the **Flags** field. |

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be one of the following:

| Value | Meaning |
| --- | --- |
| 0x00000010 | If the **C** bit is set in the **Flags** field. |
| 0x00000018 | If the **C** bit is clear in the **Flags** field. |

**StartAngle (4 bytes): **A non-negative floating-point value that specifies the angle between the x-axis and the starting point of the arc. Any value is acceptable, but it MUST be interpreted modulo 360, with the result that is used being in the range 0.0 inclusive to 360.0 exclusive.

**SweepAngle (4 bytes): **A floating-point value that specifies the extent of the arc to draw, as an angle in degrees measured from the starting point defined by the **StartAngle** value. Any value is acceptable, but it MUST be clamped to -360.0 to 360.0 inclusive. A positive value indicates that the sweep is defined in a clockwise direction, and a negative value indicates that the sweep is defined in a counter-clockwise direction.

**RectData (variable): **Either an EmfPlusRect or EmfPlusRectF object that defines the bounding box of the ellipse that is collinear with the arc. This rectangle defines the position, size, and shape of the arc. The type of object in this field is specified by the value of the **Flags** field.

See section 2.3.4 for the specification of additional drawing record types.

#### EmfPlusDrawBeziers Record

The EmfPlusDrawBeziers record specifies drawing a sequence of connected **Bezier curves**. The order for Bezier data points is the start point, control point 1, control point 2 and end point. For more information see [MSDN-DrawBeziers]. 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| Count |
| PointData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusDrawBeziers from the RecordType enumeration. The value MUST be 0x4019.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | C | X | X | P | X | X | X | ObjectID |

**X (1 bit): **Reserved and MUST be ignored.

**C (1 bit): **This bit indicates whether the **PointData** field specifies compressed data.

If set, **PointData** specifies absolute locations in the **coordinate space** with 16-bit signed integer coordinates. If clear, **PointData** specifies absolute locations in the coordinate space with 32-bit floating-point coordinates.

**Note: **If the **P** flag (below) is set, this flag is undefined and MUST be ignored.

**P (1 bit): **This bit indicates whether the **PointData** field specifies relative or absolute locations.

If set, each element in **PointData** specifies a location in the coordinate space that is relative to the location specified by the previous element in the array. In the case of the first element in **PointData**, a previous location at coordinates (0,0) is assumed. If clear, **PointData** specifies absolute locations according to the **C** flag.

**Note: **If this flag is set, the **C** flag (above) is undefined and MUST be ignored.<20>

**ObjectID (1 byte): **The index of an EmfPlusPen object in the EMF+ Object Table to draw the Bezier curves. The value MUST be zero to 63, inclusive.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record. At least 4 points MUST be specified.

| Value | Meaning |
| --- | --- |
| 0x00000018 ≤ *value* | If the **P** bit is set in the **Flags** field, the minimum **Size** is computed as follows:Size = (Count * 0x00000002) + 0x00000010 |
| 0x00000020 ≤ *value* | If the **P** bit is clear and the **C** bit is set in the **Flags** field, **Size** is computed as follows:Size = (Count * 0x00000004) + 0x00000010 |
| 0x00000030 ≤ *value* | If the **P** bit is clear and the **C** bit is clear in the **Flags** field, **Size** is computed as follows:Size = (Count * 0x00000008) + 0x00000010 |

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record. At least 4 points MUST be specified.

| Value | Meaning |
| --- | --- |
| 0x0000000C ≤ *value* | If the **P** bit is set in the **Flags** field, the minimum **DataSize** is computed as follows:DataSize = (Count * 0x00000002) + 0x00000004 |
| 0x00000014 ≤ *value* | If the **P** bit is clear and the **C** bit is set in the **Flags** field, **DataSize** is computed as follows:DataSize = (Count * 0x00000004) + 0x00000004 |
| 0x00000024 ≤ *value* | If the **P** bit is clear and the **C** bit is clear in the **Flags** field, **DataSize** is computed as follows:DataSize = (Count * 0x00000008) + 0x00000004 |

**Count (4 bytes): **An unsigned integer that specifies the number of points in the **PointData** array. At least 4 points MUST be specified.

**PointData (variable): **An array of **Count** points that specify the starting, ending, and control points of the Bezier curves. The ending coordinate of one Bezier curve is the starting coordinate of the next. The control points are used for producing the Bezier effect.

The type of data in this array is specified by the **Flags** field, as follows:

| Data Type | Meaning |
| --- | --- |
| EmfPlusPointR object | If the **P** flag is set in the **Flags**, the points specify relative locations. |
| EmfPlusPointF object | If the **P** and **C** bits are clear in the **Flags** field, the points specify absolute locations. |
| EmfPlusPoint object | If the **P** bit is clear and the **C** bit is set in the **Flags** field, the points specify relative locations. |

A Bezier curve does not pass through its control points. The control points act as magnets, pulling the curve in certain directions to influence the way the lines bend.

See section 2.3.4 for the specification of additional drawing record types.

#### EmfPlusDrawClosedCurve Record

The EmfPlusDrawClosedCurve record specifies drawing a **closed cardinal spline**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| Tension |
| Count |
| PointData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusDrawClosedCurve from the RecordType enumeration. The value MUST be 0x4017.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | C | X | X | P | X | X | X | ObjectID |

**X (1 bit): **Reserved and MUST be ignored.

**C (1 bit): **This bit indicates whether the **PointData** field specifies compressed data.

If set, **PointData** specifies locations in the **coordinate space** with 16-bit signed integer coordinates. If clear, **PointData** specifies locations in the coordinate space with 32-bit floating-point coordinates.

**Note: **If the **P** flag (below) is set, this flag is undefined and MUST be ignored.

**P (1 bit): **This bit indicates whether the **PointData** field specifies relative or absolute locations.

If set, each element in **PointData** specifies a location in the coordinate space that is relative to the location specified by the previous element in the array. In the case of the first element in **PointData**, a previous location at coordinates (0,0) is assumed. If clear, **PointData** specifies absolute locations according to the **C** flag.

**Note: **If this flag is set, the **C** flag (above) is undefined and MUST be ignored.<21>

**ObjectID (1 byte): **The index of an EmfPlusPen object in the EMF+ Object Table to draw the closed curve. The value MUST be zero to 63, inclusive.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record. At least 3 points MUST be specified.

| Value | Meaning |
| --- | --- |
| 0x0000001C ≤ *value* | If the **P** bit is set in the **Flags** field, the minimum **Size** is computed as follows:Size = ((((Count * 0x00000002) + 0x00000014 + 0x00000003) / 4) * 4) |
| 0x00000020 ≤ *value* | If the **P** bit is clear and the **C** bit is set in the **Flags** field, **Size** is computed as follows:Size = (Count * 0x00000004) + 0x00000014 |
| 0x0000002C ≤ *value* | If the **P** bit is clear and the **C** bit is clear in the **Flags** field, **Size** is computed as follows:Size = (Count * 0x00000008) + 0x00000014 |

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data in the record. At least 3 points MUST be specified.

| Value | Meaning |
| --- | --- |
| 0x00000010 ≤ *value* | If the **P** bit is set in the **Flags** field, the minimum **DataSize** is computed as follows:DataSize = ((((Count * 0x00000002) + 0x0000008 + 0x00000003) / 4) * 4) |
| 0x00000014 ≤ *value* | If the **P** bit is clear and the **C** bit is set in the **Flags** field, **DataSize** is computed as follows:DataSize = (Count * 0x00000004) + 0x00000008 |
| 0x00000020 ≤ *value* | If the **P** bit is clear and the **C** bit is clear in the **Flags** field, **DataSize** is computed as follows:DataSize = (Count * 0x00000008) + 0x00000008 |

**Tension (4 bytes): **A floating-point value that specifies how tightly the **spline** bends as it passes through the points. A value of 0 specifies that the spline is a sequence of straight lines. As the value increases, the curve becomes more rounded. For more information, see [SPLINE77] and [PETZOLD].

**Count (4 bytes): **An unsigned integer that specifies the number of points in the **PointData** field. At least 3 points MUST be specified.

**PointData (variable): **An array of **Count** points that specify the endpoints of the lines that define the spline. In a closed cardinal spline, the curve continues through the last point in the **PointData** array and connects with the first point in the array.

The type of data in this array is specified by the **Flags** field, as follows:

| Data Type | Meaning |
| --- | --- |
| EmfPlusPointR object | If the **P** bit is set in the **Flags** field, the points specify relative locations. |
| EmfPlusPoint object | If the **P** bit is clear and the **C** bit is set in the **Flags** field, the points specify absolute locations with 16-bit coordinates. |
| EmfPlusPointF object | If the **P** and **C** bits are clear in the **Flags** field, the points specify absolute locations with 32-bit coordinates. |

See section 2.3.4 for the specification of additional drawing record types.

#### EmfPlusDrawCurve Record

The EmfPlusDrawCurve record specifies drawing a **cardinal spline**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| Tension |
| Offset |
| NumSegments |
| Count |
| PointData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusDrawCurve from the RecordType enumeration. The value MUST be 0x4018.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | C | X | X | X | X | X | X | ObjectID |

**X (1 bit): **Reserved and MUST be ignored.

**C (1 bit): **This bit indicates whether the data in the **PointData** field is compressed.

If set, **PointData** contains an array of EmfPlusPoint objects. If clear, **PointData** contains an array of EmfPlusPointF objects.

**ObjectID (1 byte): **The index of an EmfPlusPen object in the EMF+ Object Table to draw the curve. The value MUST be zero to 63, inclusive.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data.

At least 2 **PointData** elements MUST be specified in this record.

| Value | Meaning |
| --- | --- |
| 0x00000024 ≤ *value* | If the **C** bit is set in the **Flags** field, **Count** points with 16-bit signed integer values are defined in the **PointData** field. In this case, **Size** MUST be computed as follows:Size = (Count * 0x00000004) + 0x0000001C |
| 0x0000002C ≤ *value* | If the **C** bit is clear in the **Flags** field, **Count** points with 32-bit floating-point values are defined in the **PointData** field. In this case, **Size** MUST be computed as follows:Size = (Count * 0x00000008) + 0x0000001C |

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows.

At least 2 **PointData** elements MUST be specified in this record.

| Value | Meaning |
| --- | --- |
| 0x00000018 ≤ *value* | If the **C** bit is set in the **Flags** field, **Count** points with 16-bit signed integer values are defined in the **PointData** field. In this case, **DataSize** MUST be computed as follows:DataSize = (Count * 0x00000004) + 0x00000010 |
| 0x00000020 ≤ *value* | If the **C** bit is clear in the **Flags** field, **Count** points with 32-bit floating-point values are defined in the **PointData** field. In this case, **DataSize** MUST be computed as follows:DataSize = (Count * 0x00000008) + 0x00000010 |

**Tension (4 bytes): **A floating-point value that specifies how tightly the **spline** bends as it passes through the points. A value of 0 specifies that the spline is a sequence of straight lines. As the value increases, the curve becomes more rounded. For more information, see [SPLINE77] and [PETZOLD].

**Offset (4 bytes): **An unsigned integer that specifies the element in the **PointData** array that defines the starting point of the spline.

**NumSegments (4 bytes): **An unsigned integer that specifies the number of line segments making up the spline.

**Count (4 bytes): **An unsigned integer that specifies the number of points in the **PointData** array. The minimum number of points for drawing a curve is 2—the starting and ending points.

**PointData (variable): **An array of either 16-bit signed integers or 32-bit floating-point values of **Count** length that defines the coordinates of the endpoints of the lines to be stroked.

See section 2.3.4 for the specification of additional drawing record types.

#### EmfPlusDrawDriverString Record

The EmfPlusDrawDriverString record specifies text output with character positions.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| BrushId |
| DriverStringOptionsFlags |
| MatrixPresent |
| GlyphCount |
| Glyphs (variable) |
| ... |
| GlyphPos (variable) |
| ... |
| TransformMatrix (24 bytes, optional) |
| ... |
| ... |
| ... |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusDrawDriverString from the RecordType enumeration. The value MUST be 0x4036.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| S | X | X | X | X | X | X | X | ObjectID |

**S (1 bit): **This bit indicates the type of data in the **BrushId** field. 

If set, **BrushId** specifies the color value in an EmfPlusARGB object. If clear, **BrushId** contains the EMF+ Object Table index of an EmfPlusBrush object.

**X (1 bit): **Reserved and MUST be ignored.

**ObjectID (1 byte): **The EMF+ Object Table index of an EmfPlusFont object to render the text. The value MUST be zero to 63, inclusive.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data.

| Value | Meaning |
| --- | --- |
| 0x0000001C ≤ *value* | When glyphs are provided, but no transform matrix is specified in the **TransformMatrix** field, the size of the record is computed as follows:Size = (GlyphCount * 0x0000000A) + 0x0000001C |
| 0x00000034 ≤ *value* | When glyphs are provided, and a transform matrix is specified in the **TransformMatrix** field, the size of the record is computed as follows:Size = (GlyphCount * 0x0000000A) + 0x00000034 |

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows.

| Value | Meaning |
| --- | --- |
| 0x00000010 ≤ *value* | When glyphs are provided, but no transform matrix is specified in the **TransformMatrix** field, the size of the data is computed as follows:DataSize = (GlyphCount * 0x0000000A) + 0x00000010 |
| 0x00000028 ≤ *value* | When glyphs are provided, and a transform matrix is specified in the **TransformMatrix** field, the size of the data is computed as follows:DataSize = (GlyphCount * 0x0000000A) + 0x00000028 |

**BrushId (4 bytes): **An unsigned integer that specifies either the foreground color of the text or a graphics brush, depending on the value of the **S** flag in the **Flags**.

**DriverStringOptionsFlags (4 bytes): **An unsigned integer that specifies the spacing, orientation, and quality of rendering for the string. This value MUST be composed of DriverStringOptions flags.

**MatrixPresent (4 bytes): **An unsigned integer that specifies whether a transform matrix is present in the **TransformMatrix** field.

| Value | Meaning |
| --- | --- |
| 0x00000000 | The transform matrix is not present in the record. |
| 0x00000001 | The transform matrix is present in the record. |

**GlyphCount (4 bytes): **An unsigned integer that specifies number of glyphs in the string.

**Glyphs (variable): **An array of 16-bit values that define the text string to draw.

If the **DriverStringOptionsCmapLookup** flag in the **DriverStringOptionsFlags** field is set, each value in this array specifies a **Unicode** character. Otherwise, each value specifies an index to a character glyph in the EmfPlusFont object specified by the **ObjectId** value in **Flags** field.

**GlyphPos (variable): **An array of EmfPlusPointF objects that specify the output position of each character glyph. There MUST be **GlyphCount** elements, which have a one-to-one correspondence with the elements in the **Glyphs** array.

Glyph positions are calculated from the position of the first glyph if the DriverStringOptionsRealizedAdvance flag in DriverStringOptions flags is set. In this case, **GlyphPos** specifies the position of the first glyph only.

**TransformMatrix (24 bytes): **An optional EmfPlusTransformMatrix object that specifies the transformation to apply to each value in the text array. The presence of this data is determined from the **MatrixPresent** field.

See section 2.3.4 for the specification of additional drawing record types.

#### EmfPlusDrawEllipse Record

The EmfPlusDrawEllipse record specifies drawing an ellipse.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| RectData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusDrawEllipse from the RecordType enumeration. The value MUST be 0x400F.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | C | X | X | X | X | X | X | ObjectID |

**X (1 bit): **Reserved and MUST be ignored.

**C (1 bit): **This bit indicates whether the data in the **RectData** field is compressed.

If set, **RectData** contains an EmfPlusRect object. If clear, **RectData** contains an EmfPlusRectF object.

**ObjectID (1 byte): **The index of an EmfPlusPen object in the EMF+ Object Table to draw the ellipse. The value MUST be zero to 63, inclusive.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be one of the following:

| Value | Meaning |
| --- | --- |
| 0x00000014 | If the **C** bit is set in the **Flags** field. |
| 0x0000001C | If the **C** bit is clear in the **Flags** field. |

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be one of the following:

| Value | Meaning |
| --- | --- |
| 0x00000008 | If the **C** bit is set in the **Flags** field. |
| 0x00000010 | If the **C** bit is clear in the **Flags** field. |

**RectData (variable): **Either an EmfPlusRect or EmfPlusRectF object that defines the bounding box of the ellipse.

See section 2.3.4 for the specification of additional drawing record types.

#### EmfPlusDrawImage Record

The EmfPlusDrawImage record specifies drawing a scaled image.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| ImageAttributesID |
| SrcUnit |
| SrcRect |
| ... |
| ... |
| ... |
| RectData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusDrawImage from the RecordType enumeration. The value MUST be 0x401A.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | C | X | X | X | X | X | X | ObjectID |

**X (1 bit): **Reserved and MUST be ignored.

**C (1 bit): **This bit indicates whether the data in the **RectData** field is compressed.

If set, **RectData** contains an EmfPlusRect object. If clear, **RectData** contains an EmfPlusRectF object.

**ObjectID (1 byte): **The index of an EmfPlusImage object in the EMF+ Object Table, which specifies the image to render. The value MUST be zero to 63, inclusive.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be one of the following:

| Value | Meaning |
| --- | --- |
| 0x0000002C | If the **C** bit is set in the **Flags** field. |
| 0x00000034 | If the **C** bit is clear in the **Flags** field. |

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be one of the following:

| Value | Meaning |
| --- | --- |
| 0x00000020 | If the **C** bit is set in the **Flags** field. |
| 0x00000028 | If the **C** bit is clear in the **Flags** field. |

**ImageAttributesID (4 bytes): **An unsigned integer that specifies the index of an optional EmfPlusImageAttributes object in the EMF+ Object Table.

**SrcUnit (4 bytes): **A signed integer that specifies the units of the **SrcRect** field. It MUST be the **UnitTypePixel** member of the UnitType enumeration.

**SrcRect (16 bytes): **An EmfPlusRectF object that specifies a portion of the image to be rendered. The portion of the image specified by this rectangle is scaled to fit the destination rectangle specified by the **RectData** field.

**RectData (variable): **Either an EmfPlusRect or EmfPlusRectF object that defines the bounding box of the image. The portion of the image specified by the **SrcRect** field is scaled to fit this rectangle.

An EmfPlusImage object can specify either a **bitmap** or a **metafile**.

Colors in an image can be manipulated during rendering. They can be corrected, darkened, lightened, and removed.

See section 2.3.4 for the specification of additional drawing record types.

#### EmfPlusDrawImagePoints Record

The EmfPlusDrawImagePoints record specifies drawing a scaled image inside a parallelogram.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| ImageAttributesID |
| SrcUnit |
| SrcRect |
| ... |
| ... |
| ... |
| Count |
| PointData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusDrawImagePoints from the RecordType enumeration. The value MUST be 0x401B.

**Flags (2**** bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | C | E | X | P | X | X | X | ObjectID |

**X (1 bit): **Reserved and MUST be ignored.

**C (1 bit): **This bit indicates whether the **PointData** field specifies compressed data.

If set, **PointData** specifies absolute locations in the **coordinate space** with 16-bit signed integer coordinates. If clear, **PointData** specifies absolute locations in the coordinate space with 32-bit floating-point coordinates.

**Note: **If the **P** flag (below) is set, this flag is undefined and MUST be ignored.

**E (1 bit): **This bit indicates that the rendering of the image includes applying an effect.

If set, an object of the **Effect** class MUST have been specified in an earlier EmfPlusSerializableObject record.

**P (1 bit): **This bit indicates whether the **PointData** field specifies relative or absolute locations.

If set, each element in **PointData** specifies a location in the coordinate space that is relative to the location specified by the previous element in the array. In the case of the first element in **PointData**, a previous location at coordinates (0,0) is assumed. If clear, **PointData** specifies absolute locations according to the **C** flag.

**Note: **If this flag is set, the **C** flag (above) is undefined and MUST be ignored.<22>

**ObjectID (1 byte): **The index of an EmfPlusImage object in the EMF+ Object Table, which specifies the image to render. The value MUST be zero to 63, inclusive.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record. For this record type, the value MUST be one of the following.

| Value | Meaning |
| --- | --- |
| 0x00000030 | If the **P** bit is set in the **Flags** field. |
| 0x00000034 | If the **P** bit is clear and the **C** bit is set in the **Flags** field. |
| 0x00000040 | If the **P** bit is clear and the **C** bit is clear in the **Flags** field. |

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be one of the following.

| Value | Meaning |
| --- | --- |
| 0x00000024 | If the **P** bit is set in the **Flags** field. |
| 0x00000028 | If the **P** bit is clear and the **C** bit is set in the **Flags** field. |
| 0x00000034 | If the **P** bit is clear and the **C** bit is clear in the **Flags** field. |

**ImageAttributesID (4 bytes): **An unsigned integer that contains the index of the optional EmfPlusImageAttributes object in the EMF+ Object Table.

**SrcUnit (4 bytes): **A signed integer that defines the units of the **SrcRect** field. It MUST be the **UnitPixel** value of the UnitType enumeration.

**SrcRect (16 bytes): **An EmfPlusRectF object that defines a portion of the image to be rendered.

**Count (4 bytes): **An unsigned integer that specifies the number of points in the **PointData** array. Exactly 3 points MUST be specified.

**PointData (variable): **An array of **Count** points that specify three points of a parallelogram. The three points represent the upper-left, upper-right, and lower-left corners of the parallelogram. The fourth point of the parallelogram is extrapolated from the first three. The portion of the image specified by the **SrcRect** field SHOULD have **scaling** and **shearing** transforms applied if necessary to fit inside the parallelogram.

The type of data in this array is specified by the **Flags** field, as follows.

| Data Type | Meaning |
| --- | --- |
| EmfPlusPointR object | If the **P** flag is set in the **Flags**, the points specify relative locations. |
| EmfPlusPoint object | If the **P** bit is clear and the **C** bit is set in the **Flags** field, the points specify absolute locations with 16-bit signed integer values. |
| EmfPlusPointF object | If the **P** bit is clear and the **C** bit is clear in the **Flags** field, the points specify absolute locations with 32-bit floating-point values. |

An EmfPlusImage can specify either a **bitmap** or **metafile**.

Colors in an image can be manipulated during rendering. They can be corrected, darkened, lightened, and removed.

See section 2.3.4 for the specification of additional drawing record types.

#### EmfPlusDrawLines Record

The EmfPlusDrawlLines record specifies drawing a series of connected lines.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| Count |
| PointData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusDrawlLines from the RecordType enumeration. The value MUST be 0x400D.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | C | L | X | P | X | X | X | ObjectID |

**X (1 bit): **Reserved and MUST be ignored.

**C (1 bit): **This bit indicates whether the **PointData** field specifies compressed data.

If set, **PointData** specifies absolute locations in the **coordinate space** with 16-bit signed integer coordinates. If clear, **PointData** specifies absolute locations in the coordinate space with 32-bit floating-point coordinates.

**Note: **If the **P** flag (below) is set, this flag is undefined and MUST be ignored.

**L (1 bit): **This bit indicates whether to draw an extra line between the last point and the first point, to close the shape.

**P (1 bit): **This bit indicates whether the **PointData** field specifies relative or absolute locations.

If set, each element in **PointData** specifies a location in the coordinate space that is relative to the location specified by the previous element in the array. In the case of the first element in **PointData**, a previous location at coordinates (0,0) is assumed. If clear, **PointData** specifies absolute locations according to the **C** flag.

**Note: **If this flag is set, the **C** flag (above) is undefined and MUST be ignored.<23>

**ObjectID (1 byte): **The index of an EmfPlusPen object in the EMF+ Object Table to draw the lines. The value MUST be zero to 63, inclusive.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record. For this record type, the value MUST be one of the following.

| Value | Meaning |
| --- | --- |
| 0x00000014 ≤ *value* | If the **P** bit is set in the **Flags** field, the minimum **Size** is computed as follows:Size = (Count * 0x00000002) + 0x00000010 |
| 0x00000018 ≤ *value* | If the **P** bit is clear and the **C** bit is set in the **Flags** field, **Size** is computed as follows:Size = (Count * 0x00000004) + 0x00000010 |
| 0x00000020 ≤ *value* | If the **P** bit is clear and the **C** bit is clear in the **Flags** field, **Size** is computed as follows:Size = (Count * 0x00000008) + 0x00000010 |

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be one of the following.

| Value | Meaning |
| --- | --- |
| 0x00000008 ≤ *value* | If the **P** bit is set in the **Flags** field, the minimum **DataSize** is computed as follows:DataSize = (Count * 0x00000002) + 0x00000004 |
| 0x0000000C ≤ *value* | If the **P** bit is clear and the **C** bit is set in the **Flags** field, **DataSize** is computed as follows:DataSize = (Count * 0x00000004) + 0x00000004 |
| 0x00000014 ≤ *value* | If the **P** bit is clear and the **C** bit is clear in the **Flags** field, **DataSize** is computed as follows:DataSize = (Count * 0x00000008) + 0x00000004 |

**Count (4 bytes): **An unsigned integer that specifies the number of points in the **PointData** array. At least 2 points MUST be specified.

**PointData (variable): **An array of **Count** points that specify the starting and ending points of the lines to be drawn.

The type of data in this array is specified by the **Flags** field, as follows.

| Data Type | Meaning |
| --- | --- |
| EmfPlusPointR object | If the **P** flag is set in the **Flags**, the points specify relative locations. |
| EmfPlusPoint object | If the **P** bit is clear and the **C** bit is set in the **Flags** field, the points specify absolute locations with 16-bit signed integer values. |
| EmfPlusPointF object | If the **P** bit is clear and the **C** bit is clear in the **Flags** field, the points specify absolute locations with 32-bit floating-point values. |

See section 2.3.4 for the specification of additional drawing record types.

#### EmfPlusDrawPath Record

The EmfPlusDrawPath record specifies drawing a graphics **path**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| PenId |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusDrawPath from the RecordType enumeration. The value MUST be 0x4015.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | X | X | X | X | X | X | X | ObjectId |

**X (1 bit): **Reserved and MUST be ignored.

**ObjectId (1 byte): **The index of the EmfPlusPath object to draw, in the EMF+ Object Table. The value MUST be zero to 63, inclusive.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x00000010.

**DataSize**** (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value is 0x00000004.

**PenId (4 bytes): **An unsigned integer that specifies an index in the EMF+ Object Table for an EmfPlusPen object to use for drawing the EmfPlusPath. The value MUST be zero to 63, inclusive.

See section 2.3.4 for the specification of additional drawing record types.

#### EmfPlusDrawPie Record

The EmfPlusDrawPie record specifies drawing a section of the interior of an ellipse.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| StartAngle |
| SweepAngle |
| RectData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusDrawPie from the RecordType enumeration. The value MUST be 0x4011.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | C | X | X | X | X | X | X | ObjectID |

**X (1 bit): **Reserved and MUST be ignored.

**C (1 bit): **This bit indicates whether the data in the **RectData** field is compressed.

If set, **RectData** contains an EmfPlusRect object. If clear, **RectData** contains an EmfPlusRectF object.

**ObjectID (1 byte): **The index of an EmfPlusPen object in the EMF+ Object Table to draw the pie. The value MUST be zero to 63, inclusive.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be one of the following:

| Value | Meaning |
| --- | --- |
| 0x0000001C | If the **C** bit is set in the **Flags** field. |
| 0x00000024 | If the **C** bit is clear in the **Flags** field. |

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be one of the following:

| Value | Meaning |
| --- | --- |
| 0x00000010 | If the **C** bit is set in the **Flags** field. |
| 0x00000018 | If the **C** bit is clear in the **Flags** field. |

**StartAngle (4 bytes): **A non-negative floating-point value that specifies the angle between the x-axis and the starting point of the pie wedge. Any value is acceptable, but it MUST be interpreted modulo 360, with the result that is used being in the range 0.0 inclusive to 360.0 exclusive.

**SweepAngle (4 bytes): **A floating-point value that specifies the extent of the arc that defines the pie wedge to draw, as an angle in degrees measured from the starting point defined by the **StartAngle** value. Any value is acceptable, but it MUST be clamped to -360.0 to 360.0 inclusive. A positive value indicates that the sweep is defined in a clockwise direction, and a negative value indicates that the sweep is defined in a counter-clockwise direction.

**RectData (variable): **Either an EmfPlusRect or EmfPlusRectF object that defines the bounding box of the ellipse that contains the pie wedge. This rectangle defines the position, size, and shape of the pie. The type of object in this field is specified by the value of the **Flags** field.

See section 2.3.4 for the specification of additional drawing record types.

#### EmfPlusDrawRects Record

The EmfPlusDrawRects record specifies drawing a series of rectangles.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| Count |
| RectData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusDrawRects from the RecordType enumeration. The value MUST be 0x400B.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | C | X | X | X | X | X | X | ObjectID |

**X (1 bit): **Reserved and MUST be ignored.

**C (1 bit): **This bit indicates whether the data in the **RectData** field is compressed.

If set, **RectData** contains an EmfPlusRect object. If clear, **RectData** contains an EmfPlusRectF object.

**ObjectID (1 byte): **The index of an EmfPlusPen object in the EMF+ Object Table to draw the rectangles. The value MUST be zero to 63, inclusive.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data.

At least 1 **RectData** array element MUST be specified in this record.

| Value | Meaning |
| --- | --- |
| 0x00000018 ≤ *value* | If the **C** bit is set in the **Flags** field, **Size** MUST be computed as follows:Size = (Count * 0x00000008) + 0x00000010 |
| 0x00000020 ≤ *value* | If the **C** bit is clear in the **Flags** field, **Size** MUST be computed as follows:Size = (Count * 0x00000010) + 0x00000010 |

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows.

At least 1 **RectData** array element MUST be specified in this record.

| Value | Meaning |
| --- | --- |
| 0x0000000C ≤ *value* | If the **C** bit is set in the **Flags** field, **DataSize** MUST be computed as follows:DataSize = (Count * 0x00000008) + 0x00000004 |
| 0x00000014 ≤ *value* | If the **C** bit is clear in the **Flags** field, **DataSize** MUST be computed as follows:DataSize = (Count * 0x00000010) + 0x00000004 |

**Count (4 bytes): **An unsigned integer that specifies the number of rectangles in the **RectData** member.

**RectData (variable): **An array of either an EmfPlusRect or EmfPlusRectF objects of **Count** length that defines the rectangle data.

See section 2.3.4 for the specification of additional drawing record types.

#### EmfPlusDrawString Record

The **EmfPlusDrawString** record specifies text output with string formatting.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| BrushId |
| FormatID |
| Length |
| LayoutRect |
| ... |
| ... |
| ... |
| StringData (variable) |
| ... |
| AlignmentPadding (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusDrawString from the RecordType enumeration. The value MUST be 0x401C.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| S | X | X | X | X | X | X | X | ObjectID |

**S (1 bit): **This bit indicates the type of data in the **BrushId** field.

If set, **BrushId** specifies a color as an EmfPlusARGB object. If clear, **BrushId** contains the index of an EmfPlusBrush object in the EMF+ Object Table.

**X (1 bit): **Reserved and MUST be ignored.

**ObjectID (1 byte): **The index of an EmfPlusFont object in the EMF+ Object Table to render the text. The value MUST be zero to 63, inclusive.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header, record-specific data, and any extra alignment padding.

| Value | Meaning |
| --- | --- |
| 0x0000002A ≤ *value* | The size of the record is computed as follows:Size = (Length * 0x00000002) + 0x00000028 (+ AlignmentPaddingSize where AlignmentPaddingSize is the number of bytes in AlignmentPadding) |

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data and any extra alignment padding that follows.

| Value | Meaning |
| --- | --- |
| 0x0000001E ≤ *value* | The size of the data is computed as follows:DataSize = (Length * 0x00000002) + 0x0000001C (+ AlignmentPaddingSize where AlignmentPaddingSize is the number of bytes in AlignmentPadding) |

**BrushId (4 bytes): **An unsigned integer that specifies the brush, the content of which is determined by the **S** bit in the **Flags** field. This definition is used to paint the foreground text color; that is, just the glyphs themselves.

**FormatID (4 bytes): **An unsigned integer that specifies the index of an optional EmfPlusStringFormat object in the EMF+ Object Table. This object specifies text layout information and display manipulations to be applied to a string.

**Length (4 bytes): **An unsigned integer that specifies the number of characters in the string.

**LayoutRect (16 bytes): **An EmfPlusRectF object that defines the bounding area of the destination that will receive the string.

**StringData (variable): **An array of 16-bit **Unicode** characters that specifies the string to be drawn.

**AlignmentPadding (variable): **An optional array of up to 3 bytes that pads the record-specific data so that **DataSize** is a multiple of 4 bytes. This field MUST be ignored.

See section 2.3.4 for the specification of additional drawing record types.

#### EmfPlusFillClosedCurve Record

The EmfPlusFillClosedCurve record specifies filling the interior of a **closed cardinal spline**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| BrushId |
| Tension |
| Count |
| PointData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusFillClosedCurve from the RecordType enumeration. The value MUST be 0x4016.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| S | C | W | X | P | X | X | X | X | X | X | X | X | X | X | X |

**S (1 bit): **This bit indicates the type of data in the **BrushId** field.

If set, **BrushId** specifies a color as an EmfPlusARGB object. If clear, **BrushId** contains the index of an EmfPlusBrush object in the EMF+ Object Table.

**C (1 bit): **This bit indicates whether the **PointData** field specifies compressed data.

If set, **PointData** specifies absolute locations in the **coordinate space** with 16-bit signed integer coordinates. If clear, **PointData** specifies absolute locations in the coordinate space with 32-bit floating-point coordinates.

**Note: **If the **P** flag (below) is set, this flag is undefined and MUST be ignored.

**W (1 bit): **This bit indicates how to perform the fill operation.

If set, the fill is a "winding" fill. If clear, the fill is an "alternate" fill.

**X (1 bit): **Reserved and MUST be ignored.

**P (1 bit): **This bit indicates whether the **PointData** field specifies relative or absolute locations.

If set, each element in **PointData** specifies a location in the coordinate space that is relative to the location specified by the previous element in the array. In the case of the first element in **PointData**, a previous location at coordinates (0,0) is assumed. If clear, **PointData** specifies absolute locations according to the **C** flag.

**Note: **If this flag is set, the **C** flag (above) is undefined and MUST be ignored.<24>

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record. At least 3 points MUST be specified.

| Value | Meaning |
| --- | --- |
| 0x00000020 ≤ *value* | If the **P** bit is set in the **Flags** field, the minimum **Size** is computed as follows:Size = ((((Count * 0x00000002) + 0x00000018 + 0x00000003) / 4) * 4) |
| 0x00000024 ≤ *value* | If the **P** bit is clear and the **C** bit is set in the **Flags** field, **Size** is computed as follows:Size = (Count * 0x00000004) + 0x00000018 |
| 0x00000030 ≤ *value* | If the **P** bit is clear and the **C** bit is clear in the **Flags** field, **Size** is computed as follows:Size = (Count * 0x00000008) + 0x00000018 |

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record. At least 3 points MUST be specified.

| Value | Meaning |
| --- | --- |
| 0x00000014 ≤ *value* | If the **P** bit is set in the **Flags** field, the minimum **DataSize** is computed as follows:DataSize = ((((Count * 0x00000002) + 0x0000000C + 0x00000003) / 4) * 4) |
| 0x00000018 ≤ *value* | If the **P** bit is clear and the **C** bit is set in the **Flags** field, **DataSize** is computed as follows:DataSize = (Count * 0x00000004) + 0x0000000C |
| 0x00000024 ≤ *value* | If the **P** bit is clear and the **C** bit is clear in the **Flags** field, **DataSize** is computed as follows:DataSize = (Count * 0x00000008) + 0x0000000C |

**BrushId (4 bytes): **An unsigned integer that specifies the EmfPlusBrush, the content of which is determined by the **S** bit in the **Flags** field. This brush is used to fill the interior of the closed cardinal spline.

**Tension (4 bytes): **A floating-point value that specifies how tightly the **spline** bends as it passes through the points. A value of 0.0 specifies that the spline is a sequence of straight lines. As the value increases, the curve becomes more rounded. For more information, see [SPLINE77] and [PETZOLD].

**Count (4 bytes): **An unsigned integer that specifies the number of points in the **PointData** field. At least 3 points MUST be specified.

**PointData (variable): **An array of **Count** points that specify the endpoints of the lines that define the spline. In a closed cardinal spline, the curve continues through the last point in the **PointData** array and connects with the first point in the array.

The type of data in this array is specified by the **Flags** field, as follows:

| Data Type | Meaning |
| --- | --- |
| EmfPlusPointR object | If the **P** flag is set in the **Flags**, the points specify relative locations. |
| EmfPlusPoint object | If the **P** bit is clear and the **C** bit is set in the **Flags** field, the points specify absolute locations with 16-bit signed integer values. |
| EmfPlusPointF object | If the **P** bit is clear and the **C** bit is clear in the **Flags** field, the points specify absolute locations with 32-bit floating-point values. |

An "alternate" fill operation fills areas according to the "even-odd parity" rule. According to this rule, a test point can be determined to be inside or outside a closed curve as follows: Draw a line from the test point to a point that is distant from the curve. If that line crosses the curve an odd number of times, the test point is inside the curve; otherwise, the test point is outside the curve.

A "winding" fill operation fills areas according to the "non-zero" rule. According to this rule, a test point can be de11termined to be inside or outside a closed curve as follows: Draw a line from a test point to a point that is distant from the curve. Count the number of times the curve crosses the test line from left to right, and count the number of times the curve crosses the test line from right to left. If those two numbers are the same, the test point is outside the curve; otherwise, the test point is inside the curve.

See section 2.3.4 for the specification of additional drawing record types.

#### EmfPlusFillEllipse Record

The EmfPlusFillEllipse record specifies filling the interior of an ellipse.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| BrushId |
| RectData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusFillEllipse from the RecordType enumeration. The value MUST be 0x400E.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| S | C | X | X | X | X | X | X | X | X | X | X | X | X | X | X |

**S (1 bit): **This bit specifies the type of data in the **BrushId** field.

If set, **BrushId** specifies a color as an EmfPlusARGB object. If clear, **BrushId** contains the index of an EmfPlusBrush object in the EMF+ Object Table.

**C (1 bit): **This bit indicates whether the data in the **RectData** field is compressed.

If set, **RectData** contains an EmfPlusRect object. If clear, **RectData** contains an EmfPlusRectF object.

**X (1 bit): **Reserved and MUST be ignored.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be one of the following:

| Value | Meaning |
| --- | --- |
| 0x00000018 | If the **C** bit is set in the **Flags** field. |
| 0x00000020 | If the **C** bit is clear in the **Flags** field. |

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be one of the following:

| Value | Meaning |
| --- | --- |
| 0x0000000C | If the **C** bit is set in the **Flags** field. |
| 0x00000014 | If the **C** bit is clear in the **Flags** field. |

**BrushId (4 bytes): **An unsigned integer that specifies the brush, the content of which is determined by the **S** bit in the **Flags** field. This definition is used to fill the interior of the ellipse.

**RectData (variable): **Either an EmfPlusRect or EmfPlusRectF object that defines the bounding box of the ellipse.

See section 2.3.4 for the specification of additional drawing record types.

#### EmfPlusFillPath Record

The EmfPlusFillPath record specifies filling the interior of a graphics **path**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| BrushId |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusFillPath from the RecordType enumeration. The value MUST be 0x4014.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| S | X | X | X | X | X | X | X | ObjectId |

**S (1 bit): **This bit indicates the type of data in the **BrushId** field.

If set, **BrushId** specifies a color as an EmfPlusARGB object. If clear, **BrushId** contains the index of an EmfPlusBrush object in the EMF+ Object Table.

**X (1 bit): **Reserved and MUST be ignored.

**ObjectId (1 byte): **The index of the EmfPlusPath object to fill, in the EMF+ Object Table. The value MUST be zero to 63, inclusive.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x00000010.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of data of record-specific data that follows. For this record type, the value MUST be 0x00000004.

**BrushId (4 bytes): **An unsigned integer that defines the brush, the content of which is determined by the **S** bit in the **Flags** field.

See section 2.3.4 for the specification of additional drawing record types.

#### EmfPlusFillPie Record

The EmfPlusFillPie record specifies filling a section of the interior of an ellipse.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| BrushId |
| StartAngle |
| SweepAngle |
| RectData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusFillPie from the RecordType enumeration. The value MUST be 0x4010.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| S | C | X | X | X | X | X | X | X | X | X | X | X | X | X | X |

**S (1 bit): **This bit indicates the type of data in the **BrushId** field.

If set, **BrushId** specifies a color as an EmfPlusARGB object. If clear, **BrushId** contains the index of an EmfPlusBrush object in the EMF+ Object Table.

**C (1 bit): **This bit indicates whether the data in the **RectData** field is compressed.

If set, **RectData** contains an EmfPlusRect object. If clear, **RectData** contains an EmfPlusRectF object.

**X (1 bit): **Reserved and MUST be ignored.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be one of the following:

| Value | Meaning |
| --- | --- |
| 0x00000020 | If the **C** bit is set in the **Flags** field. |
| 0x00000028 | If the **C** bit is clear in the **Flags** field. |

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be one of the following:

| Value | Meaning |
| --- | --- |
| 0x00000014 | If the **C** bit is set in the **Flags** field. |
| 0x0000001C | If the **C** bit is clear in the **Flags** field. |

**BrushId (4 bytes): **An unsigned integer that defines the brush, the content of which is determined by the **S** bit in the **Flags** field.

**StartAngle (4 bytes): **A non-negative floating-point value that specifies the angle between the x-axis and the starting point of the pie wedge. Any value is acceptable, but it MUST be interpreted modulo 360, with the result that is used being in the range 0.0 inclusive to 360.0 exclusive.

**SweepAngle (4 bytes): **A floating-point value that specifies the extent of the arc that defines the pie wedge to fill, as an angle in degrees measured from the starting point defined by the **StartAngle** value. Any value is acceptable, but it MUST be clamped to -360.0 to 360.0 inclusive. A positive value indicates that the sweep is defined in a clockwise direction, and a negative value indicates that the sweep is defined in a counter-clockwise direction.

**RectData (variable): **Either an EmfPlusRect or EmfPlusRectF object that defines the bounding box of the ellipse that contains the pie wedge. This rectangle defines the position, size, and shape of the pie. The type of object in this field is specified by the value of the **Flags** field.

See section 2.3.4 for the specification of additional drawing record types.

#### EmfPlusFillPolygon Record

The EmfPlusFillPolygon record specifies filling the interior of a polygon.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| BrushId |
| Count |
| PointData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusFillPolygon from the RecordType enumeration. The value MUST be 0x400C.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| S | C | X | X | P | X | X | X | X | X | X | X | X | X | X | X |

**S (1 bit): **This bit indicates the type of data in the **BrushId** field.

If set, **BrushId** specifies a color as an EmfPlusARGB object. If clear, **BrushId** contains the index of an EmfPlusBrush object in the EMF+ Object Table.

**C (1 bit): **This bit indicates whether the **PointData** field specifies compressed data.

If set, **PointData** specifies absolute locations in the **coordinate space** with 16-bit signed integer coordinates. If clear, **PointData** specifies absolute locations in the coordinate space with 32-bit floating-point coordinates.

**Note: **If the **P** flag (below) is set, this flag is undefined and MUST be ignored.

**X (1 bit): **Reserved and MUST be ignored.

**P (1 bit): **This bit indicates whether the **PointData** field specifies relative or absolute locations.

If set, each element in **PointData** specifies a location in the coordinate space that is relative to the location specified by the previous element in the array. In the case of the first element in **PointData**, a previous location at coordinates (0,0) is assumed. If clear, **PointData** specifies absolute locations according to the **C** flag.

**Note: **If this flag is set, the **C** flag (above) is undefined and MUST be ignored.<25>

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record. At least 3 points MUST be specified.

| Value | Meaning |
| --- | --- |
| 0x0000001C ≤ *value* | If the **P** bit is set in the **Flags** field, the minimum **Size** is computed as follows:Size = ((((Count * 0x00000002) + 0x00000014 + 0x00000003) / 4) * 4) |
| 0x00000020 ≤ *value* | If the **P** bit is clear and the **C** bit is set in the **Flags** field, **Size** is computed as follows:Size = (Count * 0x00000004) + 0x00000014 |
| 0x0000002C ≤ *value* | If the **P** bit is clear and the **C** bit is clear in the **Flags** field, **Size** is computed as follows:Size = (Count * 0x00000008) + 0x00000014 |

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data in the record. At least 3 points MUST be specified.

| Value | Meaning |
| --- | --- |
| 0x00000010 ≤ *value* | If the **P** bit is set in the **Flags** field, the minimum **DataSize** is computed as follows:DataSize = ((((Count * 0x00000002) + 0x0000008 + 0x00000003) / 4) * 4) |
| 0x00000014 ≤ *value* | If the **P** bit is clear and the **C** bit is set in the **Flags** field, **DataSize** is computed as follows:DataSize = (Count * 0x00000004) + 0x00000008 |
| 0x00000020 ≤ *value* | If the **P** bit is clear and the **C** bit is clear in the **Flags** field, **DataSize** is computed as follows:DataSize = (Count * 0x00000008) + 0x00000008 |

**BrushId (4 bytes): **An unsigned integer that defines the brush, the content of which is determined by the **S** bit in the **Flags** field.

**Count (4 bytes): **An unsigned integer that specifies the number of points in the **PointData** field. At least 3 points MUST be specified.

**PointData (variable): **An array of **Count** points that define the vertices of the polygon. The first two points in the array specify the first side of the polygon. Each additional point specifies a new side, the vertices of which include the point and the previous point. If the last point and the first point do not coincide, they specify the last side of the polygon.

The type of data in this array is specified by the **Flags** field, as follows:

| Data Type | Meaning |
| --- | --- |
| EmfPlusPointR object | If the **P** flag is set in the **Flags**, the points specify relative locations. |
| EmfPlusPoint object | If the **P** bit is clear and the **C** bit is set in the **Flags** field, the points specify absolute locations with 16-bit signed integer values. |
| EmfPlusPointF object | If the **P** bit is clear and the **C** bit is clear in the **Flags** field, the points specify absolute locations with 32-bit floating-point values. |

See section 2.3.4 for the specification of additional drawing record types.

#### EmfPlusFillRects Record

The EmfPlusFillRects record specifies filling the interiors of a series of rectangles.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| BrushId |
| Count |
| RectData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusFillRects from the RecordType enumeration. The value MUST be set to 0x400A

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| S | C | X | X | X | X | X | X | X | X | X | X | X | X | X | X |

**S (1 bit): **This bit specifies the type of data in the **BrushId** field.

If set, **BrushId** specifies a color as an EmfPlusARGB object. If clear, **BrushId** contains the index of an EmfPlusBrush object in the EMF+ Object Table.

**C (1 bit): **This bit indicates whether the data in the **RectData** field is compressed.

If set, **RectData** contains an EmfPlusRect object. If clear, **RectData** contains an EmfPlusRectF object.

**X (1 bit): **Reserved and MUST be ignored.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data.

At least 1 **RectData** array element MUST be specified in this record.

| Value | Meaning |
| --- | --- |
| 0x0000001C ≤ *value* | If the **C** bit is set in the **Flags** field, **Size** MUST be computed as follows:Size = (Count * 0x00000008) + 0x00000014 |
| 0x00000024 ≤ *value* | If the **C** bit is clear in the **Flags** field, **Size** MUST be computed as follows:Size = (Count * 0x00000010) + 0x00000014 |

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows.

At least 1 **RectData** array element MUST be specified in this record.

| Value | Meaning |
| --- | --- |
| 0x00000010 ≤ *value* | If the **C** bit is set in the **Flags** field, **DataSize** MUST be computed as follows:DataSize = (Count * 0x00000008) + 0x00000008 |
| 0x00000018 ≤ *value* | If the **C** bit is clear in the **Flags** field, **DataSize** MUST be computed as follows:DataSize = (Count * 0x00000010) + 0x00000008 |

**BrushId (4 bytes): **An unsigned integer that defines the brush, the content of which is determined by the **S** bit in the **Flags** field.

**Count (4 bytes): **An unsigned integer that specifies the number of rectangles in the **RectData** field.

**RectData (variable): **An array of either an EmfPlusRect or EmfPlusRectF objects of **Count** length that defines the rectangle data.

See section 2.3.4 for the specification of additional drawing record types.

#### EmfPlusFillRegion Record

The EmfPlusFillRegion record specifies filling the interior of a graphics **region**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| BrushId |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusFillRegion from the RecordType enumeration. The value MUST be 0x4013

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| S | X | X | X | X | X | X | X | ObjectId |

**S (1 bit): **This bit specifies the type of data in the **BrushId** field.

If set, **BrushId** specifies a color as an EmfPlusARGB object. If clear, **BrushId** contains the index of an EmfPlusBrush object in the EMF+ Object Table.

**X (1 bit): **Reserved and MUST be ignored.

**ObjectId (1 byte): **The index of the EmfPlusRegion object to fill, in the EMF+ Object Table. The value MUST be zero to 63, inclusive.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned size of the entire record in bytes, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x00000010.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be 0x00000004.

**BrushId (4 bytes): **An unsigned integer that defines the brush, the content of which is determined by the **S** bit in the **Flags** field.

See section 2.3.4 for the specification of additional drawing record types.

### Object Record Types

The Object Record Types define reusable graphics objects. The following are **EMF+** object record types:

| Name | Section | Description |
| --- | --- | --- |
| EmfPlusObject | 2.3.5.1 | Defines an object for use in graphics operations. |
| EmfPlusSerializableObject | 2.3.5.2 | Defines an object that has been serialized into a data buffer. |

The generic structure of EMF+ object records is specified as follows:

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| RecordData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies the record type. The object record types are listed below. See the table above for descriptions of these records.

| Name | Value |
| --- | --- |
| EmfPlusObject | 0x4008 |
| EmfPlusSerializableObject | 0x4038 |

**Flags (2 bytes): **An unsigned integer that contains information for some records on how the operation is to be performed and on the structure of the record.

**Size (4 bytes): **An unsigned integer that defines the 32-bit-aligned size of the entire record in bytes, including the 12-byte record header and the record-specific data.

**DataSize (4 bytes): **An unsigned integer that defines the 32-bit-aligned number of bytes of data in the **RecordData** field that follows. This number does not include the 12-byte record header.

**RecordData (variable): **An optional, variable-length array of bytes that, if present, defines the data specific to individual records. For specifications of the additional information, if any, which is contained within this field, see individual record definitions.

#### EmfPlusObject Record

The EmfPlusObject record specifies an object for use in graphics operations. The object definition can span multiple records, which is indicated by the value of the **Flags** field.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| TotalObjectSize (optional) |
| DataSize |
| ObjectData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that defines this record type as EmfPlusObject from the RecordType enumeration. The value MUST be 0x4008.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| C | ObjectType | ObjectID |

**C (1 bit): **Indicates that the object definition continues on in the next EmfPlusObject record. This flag is never set in the final record that defines the object.

**ObjectType (7 bits): **The type of object to be created by this record, from the ObjectType enumeration.

**ObjectID (1 byte): **The index in the EMF+ Object Table to associate with the object created by this record. The value MUST be zero to 63, inclusive.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned size of the entire record in bytes, including the 12-byte record header and the record-specific buffer data.

**TotalObjectSize (4 bytes): **If the record is continuable, when the continue bit is set, this field will be present. Continuing objects have multiple EMF+ records starting with EmfPlusContineudObjectRecord.  Each EmfPlusContinuedObjectRecord will contain a **TotalObjectSize**.  Once **TotalObjectSize** number of bytes has been read, the next EMF+ record will not be treated as part of the continuing object.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of data in the record-specific data that follows. This number does not include the size of the invariant part of this record. For this record type, the value varies based on the size of object.

**ObjectData (variable): **An array of bytes that contains data for the type of object specified in the **Flags** field. The content and format of the data can be different for each object type. See the individual object definitions in section 2.2.1 for additional information.

The EmfPlusObject record is generic; it is used for all types of objects. Values that are specific to particular object types are contained in the **ObjectData** field. A conceptual model for managing graphics objects is described in Managing Graphics Objects.

See section 2.3.5 for the specification of additional object record types.

#### EmfPlusSerializableObject Record

The EmfPlusSerializableObject record defines an **image effects** parameter block that has been serialized into a data buffer.<26>

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| ObjectGUID |
| ... |
| ... |
| ... |
| BufferSize |
| Buffer (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusSerializableObject from the RecordType enumeration. The value MUST be 0x4038.

**Flags (2 bytes): **An unsigned integer that is not used. This field SHOULD be set to zero and MUST be ignored upon receipt.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be computed as follows:

Size = BufferSize + 0x00000020

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be computed as follows:

DataSize = BufferSize + 0x00000014

**ObjectGUID (16 bytes): **The **GUID** packet representation value ([MS-DTYP] section 2.3.4.2) for the image effect. This MUST correspond to one of the ImageEffects identifiers.

**BufferSize (4 bytes): **An unsigned integer that specifies the size in bytes of the 32-bit-aligned **Buffer** field.

**Buffer (variable): **An array of **BufferSize** bytes that contain the serialized image effects parameter block that corresponds to the GUID in the **ObjectGUID** field. This MUST be one of the Image Effects objects.

See section 2.3.5 for the specification of additional object record types.

### Property Record Types

**Property Record Types** specify properties of the **pla****yback device context**. The following are **EMF+** property record types:

| Name | Section | Description |
| --- | --- | --- |
| EmfPlusSetAntiAliasMode | 2.3.6.1 | Sets the **anti-aliasing** mode for text output. |
| EmfPlusSetCompositingMode | 2.3.6.2 | Sets how source colors are combined with background colors. |
| EmfPlusSetCompositingQuality | 2.3.6.3 | Sets the desired level of quality for creating composite images from multiple objects. |
| EmfPlusSetInterpolationMode | 2.3.6.4 | Sets how image **scaling**, including stretching and shrinking, is performed. |
| EmfPlusSetPixelOffsetMode | 2.3.6.5 | Sets how pixels are centered with respect to the coordinates of the drawing surface. |
| EmfPlusSetRenderingOrigin | 2.3.6.6 | Sets the rendering origin for graphics output. |
| EmfPlusSetTextContrast | 2.3.6.7 | Sets text contrast according to the **gamma correction** value. |
| EmfPlusSetTextRenderingHint | 2.3.6.8 | Sets the quality of text rendering, including the type of anti-aliasing. |

The generic structure of EMF+ property records is specified as follows:

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| RecordData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies the record type. The property record types are listed below. See the table above for descriptions of these records.

| Name | Value |
| --- | --- |
| EmfPlusSetRenderingOrigin | 0x401D |
| EmfPlusSetAntiAliasMode | 0x401E |
| EmfPlusSetTextRenderingHint | 0x401F |
| EmfPlusSetTextContrast | 0x4020 |
| EmfPlusSetInterpolationMode | 0x4021 |
| EmfPlusSetPixelOffsetMode | 0x4022 |
| EmfPlusSetCompositingMode | 0x4023 |
| EmfPlusSetCompositingQuality | 0x4024 |

**Flags (2 bytes): **An unsigned integer that contains information for some records on how the operation is to be performed and on the structure of the record.

**Size (4 bytes): **An unsigned integer that defines the 32-bit-aligned size of the entire record in bytes, including the 12-byte record header and the record-specific data.

**DataSize (4 bytes): **An unsigned integer that defines the 32-bit-aligned number of bytes of data in the **RecordData** field that follows. This number does not include the 12-byte record header.

**RecordData (variable): **An optional, variable-length array of bytes that, if present, defines the data specific to individual records. For specifications of the additional information, if any, which is contained within this field, see individual record definitions.

#### EmfPlusSetAntiAliasMode Record

The **EmfPlusSetAntiAliasMode** record specifies the **anti-aliasing** mode for text output.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusSetAntiAliasMode from the RecordType enumeration. The value MUST be 0x401E.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | X | X | X | X | X | X | X | SmoothingMode | A |

**X (1 bit): **Reserved and MUST be ignored.

**SmoothingMode (7 bits): **The smoothing mode value, from the SmoothingMode enumeration.<27>

**A (1 bit): **If set, anti-aliasing SHOULD be performed.

If clear, anti-aliasing SHOULD NOT be performed.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned size of the entire record in bytes, including the 12-byte record header and the record-specific buffer data.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of data in the record-specific data that follows. This number does not include the size of the invariant part of this record. For this record type, the value MUST be 0x00000000.

See section 2.3.6 for the specification of additional property record types.

#### EmfPlusSetCompositingMode Record

The **EmfPlusSetCompositingMode** record specifies how source colors are combined with background colors. 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusSetCompositingMode from the RecordType enumeration. The value MUST be 0x4023.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | X | X | X | X | X | X | X | CompositingMode |

**X (1 bit): **Reserved and MUST be ignored.

**CompositingMode (1 byte): **The **compositing** mode value, from the CompositingMode enumeration. Compositing can be expressed as the state of **alpha blending**, which can either be on or off.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x0000000C.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be 0x00000000.

See section 2.3.6 for the specification of additional property record types.

#### EmfPlusSetCompositingQuality Record

The **EmfPlusSetCompositingQuality** record specifies the desired level of quality for creating composite images from multiple objects.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusSetCompositingQuality from the RecordType enumeration. The value MUST be 0x4024.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | X | X | X | X | X | X | X | CompositingQuality |

**X (1 bit): **Reserved and MUST be ignored.

**CompositingQuality (1 byte): **The **compositing** quality value, from the CompositingQuality enumeration.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x0000000C.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be 0x00000000.

See section 2.3.6 for the specification of additional property record types.

#### EmfPlusSetInterpolationMode Record

The **EmfPlusSetInterpolationMode** record specifies how image scaling, including stretching and shrinking, is performed.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusSetInterpolationMode from the RecordType enumeration. The value MUST be 0x4021.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | X | X | X | X | X | X | X | InterpolationMode |

**X (1 bit): **Reserved and MUST be ignored.

**InterpolationMode (1 byte): **The interpolation mode value, from the InterpolationMode enumeration.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x0000000C.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be 0x00000000.

See section 2.3.6 for the specification of additional property record types.

#### EmfPlusSetPixelOffsetMode Record

The **EmfPlusSetPixelOffsetMode** record specifies how pixels are centered with respect to the coordinates of the drawing surface.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusSetPixelOffsetMode from the RecordType enumeration. The value MUST be 0x4022.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | X | X | X | X | X | X | X | PixelOffsetMode |

**X (1 bit): **Reserved and MUST be ignored.

**PixelOffsetMode (1 byte): **The pixel offset mode value, from the PixelOffsetMode enumeration.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x0000000C.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be 0x00000000.

See section 2.3.6 for the specification of additional property record types.

#### EmfPlusSetRenderingOrigin Record

The **EmfPlusSetRenderingOrigin **record specifies the rendering origin for graphics output.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| x |
| y |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusSetRenderingOrigin from the RecordType enumeration. The value MUST be 0x401D.

**Flags (2 bytes): **An unsigned integer that is not used. This field SHOULD be set to zero and MUST be ignored upon receipt.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x00000014.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be 0x00000008.

**x (4 bytes): **A signed integer that defines the horizontal coordinate value of the rendering origin.

**y (4 bytes): **A signed integer that defines the vertical coordinate value of the rendering origin.

See section 2.3.6 for the specification of additional property record types.

#### EmfPlusSetTextContrast Record

The **EmfPlusSetTextContrast** record specifies text contrast according to the **gamma correction** value.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusSetTextContrast from the RecordType enumeration. The value MUST be 0x4020.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | X | X | X | TextContrast |

**X (1 bit): **Reserved and MUST be ignored.

**TextContrast (12 bits): **The gamma correction value X 1000, which will be applied to subsequent text rendering operations. The allowable range is 1000 to 2200, representing text **gamma** values of 1.0 to 2.2.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x0000000C.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be 0x00000000.

See section 2.3.6 for the specification of additional property record types.

#### EmfPlusSetTextRenderingHint Record

The **EmfPlusSetTextRenderingHint** record specifies the quality of text rendering, including the type of **anti-aliasing**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusSetTextRenderingHint from the RecordType enumeration. The value MUST be 0x401F.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | X | X | X | X | X | X | X | TextRenderingHint |

**X (1 bit): **Reserved and MUST be ignored.

**TextRenderingHint (1 byte): **The text rendering hint value, from the TextRenderingHint enumeration, which specifies the quality to use in subsequent text rendering.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x0000000C.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be 0x00000000.

See section 2.3.6 for the specification of additional property record types.

### State Record Types

The State Record Types specify operations on the state of the **playback device context**. The following are **EMF+** state record types:

| Name | Section | Description |
| --- | --- | --- |
| EmfPlusBeginContainer | 2.3.7.1 | Starts a new graphics state container with a transformation. |
| EmfPlusBeginContainerNoParams | 2.3.7.2 | Starts a new graphics state container. |
| EmfPlusEndContainer | 2.3.7.3 | Closes a graphics state container that was previously opened by a begin container operation. |
| EmfPlusRestore | 2.3.7.4 | Restores a saved graphics state. |
| EmfPlusSave | 2.3.7.5 | Saves the current graphics state. |

The generic structure of EMF+ state records is specified as follows:

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| RecordData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies the record type. The state record types are listed below. See the table above for descriptions of these records.

| Name | Value |
| --- | --- |
| EmfPlusSave | 0x4025 |
| EmfPlusRestore | 0x4026 |
| EmfPlusBeginContainer | 0x4027 |
| EmfPlusBeginContainerNoParams | 0x4028 |
| EmfPlusEndContainer | 0x4029 |

**Flags (2 bytes): **An unsigned integer that contains information for some records on how the operation is to be performed and on the structure of the record.

**Size (4 bytes): **An unsigned integer that defines the 32-bit-aligned size of the entire record in bytes, including the 12-byte record header and the record-specific data.

**DataSize (4 bytes): **An unsigned integer that defines the 32-bit-aligned number of bytes of data in the **RecordData** field that follows. This number does not include the 12-byte record header.

**RecordData (variable): **An optional, variable-length array of bytes that, if present, defines the data specific to individual records. For specifications of the additional information, if any, which is contained within this field, see individual record definitions.

#### EmfPlusBeginContainer Record

The EmfPlusBeginContainer record opens a new graphics state container and specifies a **transform** for it.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| DestRect |
| ... |
| ... |
| ... |
| SrcRect |
| ... |
| ... |
| ... |
| StackIndex |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusBeginContainer from the RecordType enumeration. The value MUST be 0x4027.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PageUnit | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

**PageUnit (1 byte): **The unit of measure for **page space** coordinates, from the UnitType enumeration. This value SHOULD NOT be **UnitTypeDisplay** or **UnitTypeWorld**.<28>

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x00000030.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be 0x00000024.

**DestRect (16 bytes): **An EmfPlusRectF object that, with **SrcRect**, specifies a transform for the container. This transformation results in **SrcRect** when applied to **Des****tRect**.

**SrcRect (16 bytes): **An EmfPlusRectF rectangle that, with **DestRect**, specifies a transform for the container. This transformation results in **SrcRect** when applied to **DestRect**.

**StackIndex (4 bytes): **An unsigned integer that specifies an index to associate with the graphics state container. The index MUST be referenced by a subsequent EmfPlusEndContainer to close the graphics state container.

Each graphics state container MUST be added to an array of saved graphics containers. The graphics state container is not written to the **EMF+** **metafile**, so its format can be determined by the implementation.

See section 2.3.7 for the specification of additional state record types.

#### EmfPlusBeginContainerNoParams Record

The EmfPlusBeginContainerNoParams record opens a new graphics state container.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| StackIndex |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusBeginContainerNoParams from the RecordType enumeration. The value MUST be 0x4028.

**Flags (2 bytes): **An unsigned integer that is not used. This field SHOULD be set to zero and MUST be ignored upon receipt.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x00000010.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be 0x00000004.

**StackIndex (4 bytes): **An unsigned integer that specifies an index to associate with the graphics state container. The index MUST be referenced by a subsequent EmfPlusEndContainer record to close the graphics state container.

Each graphics state container MUST be added to an array of saved graphics containers. The graphics state container is not written to the **EMF+** **metafile**, so its format can be determined by the implementation.

See section 2.3.7 for the specification of additional state record types.

#### EmfPlusEndContainer Record

The EmfPlusEndContainer record closes a graphics state container that was previously opened by a begin container operation.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| StackIndex |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusEndContainer from the RecordType enumeration. The value MUST be 0x4029.

**Flags (2 bytes): **An unsigned integer that is not used. This field SHOULD be set to zero and MUST be ignored upon receipt.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, this value is 0x00000010.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, this value is 0x00000004.

**StackIndex (4 by****tes): **An unsigned integer that specifies the index of a graphics state container. The index MUST match the value associated with a graphics state container opened by a previous EmfPlusBeginContainer or EmfPlusBeginContainerNoParams record.

Each graphics state container MUST be added to an array of saved graphics containers. The graphics state container is not written to the **EMF+** **metafile**, so its format can be determined by the implementation.

See section 2.3.7 for the specification of additional state record types.

#### EmfPlusRestore Record

The EmfPlusRestore record restores the graphics state, identified by a specified index, from a stack of saved graphics states.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| StackIndex |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusRestore from the RecordType enumeration. The value MUST be 0x4026.

**Flags (2 bytes): **An unsigned integer that is not used. This field SHOULD be set to zero and MUST be ignored upon receipt.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of records in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x00000010.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be 0x00000004.

**StackIndex (4 bytes): **An unsigned integer that specifies the level associated with a graphics state. The level value was assigned to the graphics state by a previous EmfPlusSave record.

Each graphics state MUST be popped off a stack of saved graphics states. The graphics state information is not written to the **EMF+** **metafile**, so its format can be determined by the implementation.

See section 2.3.7 for the specification of additional state record types.

#### EmfPlusSave Record

The EmfPlusSave record saves the graphics state, identified by a specified index, on a stack of saved graphics states.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| StackIndex |

**Type (2 bytes): **An unsigned integer that identifies this record type as **EmfPlusSave** from the RecordType enumeration. The value MUST be 0x4025.

**Flags (2 bytes): **An unsigned integer that is not used. This field SHOULD be set to zero and MUST be ignored upon receipt.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of records in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x00000010.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be 0x00000004.

**StackIndex (4 bytes): **An unsigned integer that specifies a level to associate with the graphics state. The level value can be used by a subsequent EmfPlusRestore record to retrieve the graphics state.

Each saved graphics state MUST be pushed onto a stack of saved graphics states. The graphics state information is not written to the **EMF+** **metafile**, so its format can be determined by the implementation.

See section 2.3.7 for the specification of additional state record types.

### Terminal Server Record Types

The Terminal Server Record Types specify graphics processing on a **terminal server**. The following are **EMF+** terminal server record types.

| Name | Section | Description |
| --- | --- | --- |
| EmfPlusSetTSClip | 2.3.8.1 | Specifies clipping areas in the graphics **device context** for a terminal server.<29> |
| EmfPlusSetTSGraphics | 2.3.8.2 | Specifies the state of a graphics device context for a terminal server.<30> |

The generic structure of EMF+ terminal server records is specified as follows.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| RecordData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies the record type. The terminal server types are listed below. See the table above for descriptions of these records.

| Name | Value |
| --- | --- |
| EmfPlusSetTSGraphics | 0x4039 |
| EmfPlusSetTSClip | 0x403A |

**Flags (2 bytes): **An unsigned integer that contains information for some records on how the operation is to be performed and on the structure of the record.

**Size (4 bytes): **An unsigned integer that defines the 32-bit-aligned size of the entire record in bytes, including the 12-byte record header and the record-specific data.

**DataSize (4 bytes): **An unsigned integer that defines the 32-bit-aligned number of bytes of data in the **RecordData** field that follows. This number does not include the 12-byte record header.

**RecordData (variable): **An optional, variable-length array of bytes that, if present, defines the data specific to individual records. For specifications of the additional information, if any, which is contained within this field, see individual record definitions.

#### EmfPlusSetTSClip Record

The **EmfPlus****SetTSClip** record specifies clipping areas in the graphics **device context** for a **terminal server**.<31>

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| Rects (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusSetTSClip from the RecordType enumeration. The value MUST be 0x403A.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| C | NumRects |

**C (1 bit): **The format of the rectangle data in the **Rects** field. If set, each rectangle is defined in 4 bytes. If clear, each rectangle is defined in 8 bytes.

**NumRects (15 bits): **The number of rectangles that are defined in the **Rect** field.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. The computation of this value is determined by the **C** bit in the **Flags** field, as shown in the following table.

| C bit value | Meaning |
| --- | --- |
| 0 | **NumRects** rectangles, consisting of 8 bytes each, are defined in the **Rects** field, and **Size** is computed as follows:Size = (NumRects * 0x00000008) + 0x0000000C |
| 1 | **NumRects** rectangles, consisting of 4 bytes each, are defined in the **Rects** field, and **Size** is computed as follows:Size = (NumRects * 0x00000004) + 0x0000000C |

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. The computation of this value is determined by the **C** bit in the **Flags** field, as shown in the following table.

| C bit value | Meaning |
| --- | --- |
| 0 | **NumRects** rectangles, consisting of 8 bytes each, are defined in the **Rects** field, and **DataSize** is computed as follows:DataSize = NumRects * 0x00000008 |
| 1 | **NumRects** rectangles, consisting of 4 bytes each, are defined in the **Rects** field, and **DataSize** is computed as follows:DataSize = NumRects * 0x00000004 |

**Rects (variable): **An array of **NumRects** rectangles that define clipping areas. The format of this data is determined by the **C** bit in the **Flags** field.

The compression scheme for data in this record uses the following algorithm. Each point of each rectangle is encoded in either a single byte or 2 bytes. If the point is encoded in a single byte, the high bit (0x80) of the byte MUST be set, and the value is a signed number represented by the lower 7 bits. If the high bit is not set, then the value is encoded in 2 bytes, with the high-order byte encoded in the 7 lower bits of the first byte, and the low-order byte value encoded in the second byte.

Each point is encoded as the difference between the point in the current rectangle and the point in the previous rectangle. The bottom point of the rectangle is encoded as the difference between the bottom coordinate and the top coordinate on the current rectangle.

See section 2.3.8 for the specification of additional terminal server record types.

#### EmfPlusSetTSGraphics Record

The EmfPlusSetTSGraphics record specifies the state of a graphics **device context** for a **terminal server**. <32>

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| AntiAliasMode | TextRenderHint | CompositingMode | CompositingQuality |
| RenderOriginX | RenderOriginY |
| TextContrast | FilterType | PixelOffset |
| WorldToDevice (24 bytes) |
| ... |
| ... |
| ... |
| Palette (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusSetTSGraphics from the RecordType enumeration. The value MUST be 0x4039.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | X | X | X | X | X | X | X | X | X | X | X | X | X | V | T |

**X (1 bit): **Reserved and MUST be ignored.

**V (1 bit): **If set, the **palette** contains only the basic VGA colors.

**T (1 bit): **If set, this record contains an EmfPlusPalette object in the **Palette** field following the graphics state data.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned size of the entire record in bytes, including the 12-byte record header and record-specific data. This value MUST be 0x00000030 plus the size of the **Palette** field.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. This value MUST be 0x00000024 plus the size of the **Palette** field.

**AntiAliasMode (1 byt****e): **An unsigned integer that specifies the quality of line rendering, including the type of line **anti-aliasing**. It is defined in the SmoothingMode enumeration.

**TextRenderHint (1 byte): **An unsigned integer that specifies the quality of text rendering, including the type of text anti-aliasing. It is defined in the TextRenderingHint enumeration.

**CompositingMode (1 byte): **An unsigned integer that specifies how source colors are combined with background colors. It MUST be a value in the CompositingMode enumeration.

**Compositin****gQuality (1 byte): **An unsigned integer that specifies the degree of smoothing to apply to lines, curves and the edges of filled areas to make them appear more continuous or sharply defined. It MUST be a value in the CompositingQuality enumeration.

**RenderOriginX (2 bytes): **A signed integer, which is the horizontal coordinate of the origin for rendering **halftoning** and **dithering** matrixes.

**RenderOriginY (2 bytes): **A signed integer, which is the vertical coordinate of the origin for rendering halftoning and dithering matrixes.

**TextContrast (2 bytes): **An unsigned integer that specifies the **gamma correction** value used for rendering anti-aliased and **ClearType** text. This value MUST be in the range 0 to 12, inclusive.

**FilterType (1 byte): **An unsigned integer that specifies how **scaling**, including stretching and shrinking, is performed. It MUST be a value in the FilterType enumeration.

**PixelOffset (1 byte): **An unsigned integer that specifies the overall quality of the image and text-rendering process. It MUST be a value in the PixelOffsetMode enumeration.

**WorldToDevice (24 bytes): **An 192-bit EmfPlusTransformMatrix object that specifies the **world space** to **device space** transforms.

**Palette (variable): **An optional EmfPlusPalette object.

See section 2.3.8 for the specification of additional terminal server record types.

### Transform Record Types

The Transform Record Types specify properties and transforms on **coordinate spa****ces**. The following are **EMF+** **transform** record types:

| Name | Section | Description |
| --- | --- | --- |
| EmfPlusMultiplyWorldTransform | 2.3.9.1 | Multiplies the current **world space** transform by a specified transform matrix. |
| EmfPlusResetWorldTransform | 2.3.9.2 | Resets the current world space transform to the identify matrix. |
| EmfPlusRotateWorldTransform | 2.3.9.3 | Performs a **rotation** on the current world space transform. |
| EmfPlusScaleWorldTransform | 2.3.9.4 | Performs a **scaling** on the current world space transform. |
| EmfPlusSetPageTransform | 2.3.9.5 | Specifies scaling factors and units for converting **page space** coordinates to **device space** coordinates. |
| EmfPlusSetWorldTransform | 2.3.9.6 | Specifies the current world space transform according to the values in a specified transform matrix. |
| EmfPlusTranslateWorldTransform | 2.3.9.7 | Performs a **translation** on the current world space transform. |

The generic structure of EMF+ transform records is specified as follows:

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| RecordData (variable) |
| ... |

**Type (2 bytes): **An unsigned integer that identifies the record type. The transform record types are listed below. See the table above for descriptions of these records.

| Name | Value |
| --- | --- |
| EmfPlusSetWorldTransform | 0x402A |
| EmfPlusResetWorldTransform | 0x402B |
| EmfPlusMultiplyWorldTransform | 0x402C |
| EmfPlusTranslateWorldTransform | 0x402D |
| EmfPlusScaleWorldTransform | 0x402E |
| EmfPlusRotateWorldTransform | 0x402F |
| EmfPlusSetPageTransform | 0x4030 |

**Flags (2 bytes): **An unsigned integer that contains information for some records on how the operation is to be performed and on the structure of the record.

**Size (4 bytes): **An unsigned integer that defines the 32-bit-aligned size of the entire record in bytes, including the 12-byte record header and the record-specific data.

**DataSize (4 bytes): **An unsigned integer that defines the 32-bit-aligned number of bytes of data in the **RecordData** field that follows. This number does not include the 12-byte record header.

**RecordData (variable): **An optional, variable-length array of bytes that, if present, defines the data specific to individual records. For specifications of the additional information, if any, which is contained within this field, see individual record definitions.

#### EmfPlusMultiplyWorldTransform Record

The EmfPlusMultiplyWorldTransform record multiplies the current **world space** **transform** by a specified transform matrix.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| MatrixData (24 bytes) |
| ... |
| ... |
| ... |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusMultiplyWorldTransform from the RecordType enumeration. The value MUST be 0x402C.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | X | A | X | X | X | X | X | X | X | X | X | X | X | X | X |

**X (1 bit): **Reserved and MUST be ignored.

**A (1 bit): **If set, the transform matrix is post-multiplied. If clear, it is pre-multiplied.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, this value MUST be 0x00000024.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data. For this record type, this value MUST be 0x00000018.

**MatrixData (24 bytes): **An EmfPlusTransformMatrix object that defines the multiplication matrix.

See section 2.3.9 for the specification of additional transform record types.

#### EmfPlusResetWorldTransform Record

The EmfPlusResetWorldTransform record resets the current **world space** **transform** to the identify matrix.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusResetWorldTransform from the RecordType enumeration. The value MUST be 0x402B.

**Flags (2 bytes): **An unsigned integer that is not used. This field SHOULD be set to zero and MUST be ignored upon receipt.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x0000000C.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be 0x00000000.

See section 2.3.9 for the specification of additional transform record types.

#### EmfPlusRotateWorldTransform Record

The EmfPlusRotateWorldTransform record performs a **rotation** on the current **world space** **transform**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| Angle |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusRotateWorldTransform from the RecordType enumeration. The value MUST be 0x402F.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | X | A | X | X | X | X | X | X | X | X | X | X | X | X | X |

**X (1 bit): **Reserved and MUST be ignored.

**A (1 bit): **If set, the transform matrix is post-multiplied. If clear, it is pre-multiplied.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x00000010.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be 0x00000004.

**Angle (4 bytes): **A floating-point value that specifies the angle of rotation in degrees. The operation is performed by constructing a new transform matrix from the following diagram.

Figure 3: Rotation Transform Matrix

The current world space transform is multiplied by this matrix, and the result becomes the new current world space transform. The **Flags** field determines the order of multiplication.

See section 2.3.9 for the specification of additional transform record types.

#### EmfPlusScaleWorldTransform Record

The EmfPlusScaleWorldTransform record performs a **scaling** on the current **world space** **transform**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| Sx |
| Sy |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusScaleWorldTransform from the RecordType enumeration. The value MUST be 0x402E.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | X | A | X | X | X | X | X | X | X | X | X | X | X | X | X |

**X (1 bit): **Reserved and MUST be ignored.

**A (1 bit): **If set, the transform matrix is post-multiplied. If clear, it is pre-multiplied.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x00000014.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be 0x00000008.

**Sx (4 bytes): **A floating-point value that defines the horizontal scale factor. The scaling is performed by constructing a new transform matrix from the **Sx** and **Sy** field values, as shown in the following table.

Figure 4: Scale Transform Matrix

**Sy (4 bytes): **A floating-point value that defines the vertical scale factor.

See section 2.3.9 for the specification of additional transform record types.

#### EmfPlusSetPageTransform Record

The EmfPlusSetPageTransform record specifies **scaling** factors and units for converting **page space** coordinates to **device space** coordinates.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| PageScale |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusSetPageTransform from the RecordType enumeration. The value MUST be 0x4030.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | PageUnit |

**PageUnit (1 byte): **The unit of measure for page space coordinates, from the UnitType enumeration. This value SHOULD NOT be **UnitTypeDisplay** or **UnitTypeWorld**.<33>

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x00000010.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be 0x00000004.

**PageScale (4 bytes): **A floating-point value that specifies the scale factor for converting page space coordinates to device space coordinates.

See section 2.3.9 for the specification of additional transform record types.

#### EmfPlusSetWorldTransform Record

The EmfPlusSetWorldTransform record sets the world transform according to the values in a specified transform matrix.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| MatrixData (24 bytes) |
| ... |
| ... |
| ... |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusSetWorldTransform from the RecordType enumeration. The value MUST be 0x402A.

**Flags (2 bytes): **An unsigned integer that is not used. This field SHOULD be set to zero and MUST be ignored upon receipt.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x00000024.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be 0x00000018.

**MatrixData (24 bytes): **An EmfPlusTransformMatrix object that defines the new current world transform.

See section 2.3.9 for the specification of additional transform record types.

#### EmfPlusTranslateWorldTransform Record

The EmfPlusTranslateWorldTransform record performs a **translation** on the current **world ****space** **transform**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type | Flags |
| Size |
| DataSize |
| dx |
| dy |

**Type (2 bytes): **An unsigned integer that identifies this record type as EmfPlusTranslateWorldTransform from the RecordType enumeration. The value MUST be 0x402D.

**Flags (2 bytes): **An unsigned integer that provides information about how the operation is to be performed, and about the structure of the record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X | X | A | X | X | X | X | X | X | X | X | X | X | X | X | X |

**X (1 bit): **Reserved and MUST be ignored.

**A (1 bit): **If set, the transform matrix is post-multiplied. If clear, it is pre-multiplied.

**Size (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes in the entire record, including the 12-byte record header and record-specific data. For this record type, the value MUST be 0x00000014.

**DataSize (4 bytes): **An unsigned integer that specifies the 32-bit-aligned number of bytes of record-specific data that follows. For this record type, the value MUST be 0x00000008.

**dx (4 bytes): **A floating-point value that defines the horizontal distance. The translation is performed by constructing a new world transform matrix from the **dx** and **dy** fields.

**dy (4 bytes): **A floating-point value that defines the vertical distance value.

See section 2.3.9 for the specification of additional transform record types.
