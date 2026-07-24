---
source: [MS-EMF]-240423.docx
chapter_number: 2
chapter_title: "Structures"
word_count: 41109
---

# Structures

The following sections specify **EMF** enumerations, objects, and records.

All character strings specified in this section are encoded in **Unicode** **UTF16-LE** format [UNICODE] unless stated otherwise.

Unreferenced intrinsic types are defined in [MS-DTYP].

## EMF Enumerations

### RecordType Enumeration

The **RecordType** enumeration defines values that uniquely identify records in an **EMF** **metafile**. These values are specified in the **Type** fields of EMF records (section 2.3).

typedef  enum 

{

  EMR_HEADER = 0x00000001,

  EMR_POLYBEZIER = 0x00000002,

  EMR_POLYGON = 0x00000003,

  EMR_POLYLINE = 0x00000004,

  EMR_POLYBEZIERTO = 0x00000005,

  EMR_POLYLINETO = 0x00000006,

  EMR_POLYPOLYLINE = 0x00000007,

  EMR_POLYPOLYGON = 0x00000008,

  EMR_SETWINDOWEXTEX = 0x00000009,

  EMR_SETWINDOWORGEX = 0x0000000A,

  EMR_SETVIEWPORTEXTEX = 0x0000000B,

  EMR_SETVIEWPORTORGEX = 0x0000000C,

  EMR_SETBRUSHORGEX = 0x0000000D,

  EMR_EOF = 0x0000000E,

  EMR_SETPIXELV = 0x0000000F,

  EMR_SETMAPPERFLAGS = 0x00000010,

  EMR_SETMAPMODE = 0x00000011,

  EMR_SETBKMODE = 0x00000012,

  EMR_SETPOLYFILLMODE = 0x00000013,

  EMR_SETROP2 = 0x00000014,

  EMR_SETSTRETCHBLTMODE = 0x00000015,

  EMR_SETTEXTALIGN = 0x00000016,

  EMR_SETCOLORADJUSTMENT = 0x00000017,

  EMR_SETTEXTCOLOR = 0x00000018,

  EMR_SETBKCOLOR = 0x00000019,

  EMR_OFFSETCLIPRGN = 0x0000001A,

  EMR_MOVETOEX = 0x0000001B,

  EMR_SETMETARGN = 0x0000001C,

  EMR_EXCLUDECLIPRECT = 0x0000001D,

  EMR_INTERSECTCLIPRECT = 0x0000001E,

  EMR_SCALEVIEWPORTEXTEX = 0x0000001F,

  EMR_SCALEWINDOWEXTEX = 0x00000020,

  EMR_SAVEDC = 0x00000021,

  EMR_RESTOREDC = 0x00000022,

  EMR_SETWORLDTRANSFORM = 0x00000023,

  EMR_MODIFYWORLDTRANSFORM = 0x00000024,

  EMR_SELECTOBJECT = 0x00000025,

  EMR_CREATEPEN = 0x00000026,

  EMR_CREATEBRUSHINDIRECT = 0x00000027,

  EMR_DELETEOBJECT = 0x00000028,

  EMR_ANGLEARC = 0x00000029,

  EMR_ELLIPSE = 0x0000002A,

  EMR_RECTANGLE = 0x0000002B,

  EMR_ROUNDRECT = 0x0000002C,

  EMR_ARC = 0x0000002D,

  EMR_CHORD = 0x0000002E,

  EMR_PIE = 0x0000002F,

  EMR_SELECTPALETTE = 0x00000030,

  EMR_CREATEPALETTE = 0x00000031,

  EMR_SETPALETTEENTRIES = 0x00000032,

  EMR_RESIZEPALETTE = 0x00000033,

  EMR_REALIZEPALETTE = 0x00000034,

  EMR_EXTFLOODFILL = 0x00000035,

  EMR_LINETO = 0x00000036,

  EMR_ARCTO = 0x00000037,

  EMR_POLYDRAW = 0x00000038,

  EMR_SETARCDIRECTION = 0x00000039,

  EMR_SETMITERLIMIT = 0x0000003A,

  EMR_BEGINPATH = 0x0000003B,

  EMR_ENDPATH = 0x0000003C,

  EMR_CLOSEFIGURE = 0x0000003D,

  EMR_FILLPATH = 0x0000003E,

  EMR_STROKEANDFILLPATH = 0x0000003F,

  EMR_STROKEPATH = 0x00000040,

  EMR_FLATTENPATH = 0x00000041,

  EMR_WIDENPATH = 0x00000042,

  EMR_SELECTCLIPPATH = 0x00000043,

  EMR_ABORTPATH = 0x00000044,

  EMR_COMMENT = 0x00000046,

  EMR_FILLRGN = 0x00000047,

  EMR_FRAMERGN = 0x00000048,

  EMR_INVERTRGN = 0x00000049,

  EMR_PAINTRGN = 0x0000004A,

  EMR_EXTSELECTCLIPRGN = 0x0000004B,

  EMR_BITBLT = 0x0000004C,

  EMR_STRETCHBLT = 0x0000004D,

  EMR_MASKBLT = 0x0000004E,

  EMR_PLGBLT = 0x0000004F,

  EMR_SETDIBITSTODEVICE = 0x00000050,

  EMR_STRETCHDIBITS = 0x00000051,

  EMR_EXTCREATEFONTINDIRECTW = 0x00000052,

  EMR_EXTTEXTOUTA = 0x00000053,

  EMR_EXTTEXTOUTW = 0x00000054,

  EMR_POLYBEZIER16 = 0x00000055,

  EMR_POLYGON16 = 0x00000056,

  EMR_POLYLINE16 = 0x00000057,

  EMR_POLYBEZIERTO16 = 0x00000058,

  EMR_POLYLINETO16 = 0x00000059,

  EMR_POLYPOLYLINE16 = 0x0000005A,

  EMR_POLYPOLYGON16 = 0x0000005B,

  EMR_POLYDRAW16 = 0x0000005C,

  EMR_CREATEMONOBRUSH = 0x0000005D,

  EMR_CREATEDIBPATTERNBRUSHPT = 0x0000005E,

  EMR_EXTCREATEPEN = 0x0000005F,

  EMR_POLYTEXTOUTA = 0x00000060,

  EMR_POLYTEXTOUTW = 0x00000061,

  EMR_SETICMMODE = 0x00000062,

  EMR_CREATECOLORSPACE = 0x00000063,

  EMR_SETCOLORSPACE = 0x00000064,

  EMR_DELETECOLORSPACE = 0x00000065,

  EMR_GLSRECORD = 0x00000066,

  EMR_GLSBOUNDEDRECORD = 0x00000067,

  EMR_PIXELFORMAT = 0x00000068,

  EMR_DRAWESCAPE = 0x00000069,

  EMR_EXTESCAPE = 0x0000006A,

  EMR_SMALLTEXTOUT = 0x0000006C,

  EMR_FORCEUFIMAPPING = 0x0000006D,

  EMR_NAMEDESCAPE = 0x0000006E,

  EMR_COLORCORRECTPALETTE = 0x0000006F,

  EMR_SETICMPROFILEA = 0x00000070,

  EMR_SETICMPROFILEW = 0x00000071,

  EMR_ALPHABLEND = 0x00000072,

  EMR_SETLAYOUT = 0x00000073,

  EMR_TRANSPARENTBLT = 0x00000074,

  EMR_GRADIENTFILL = 0x00000076,

  EMR_SETLINKEDUFIS = 0x00000077,

  EMR_SETTEXTJUSTIFICATION = 0x00000078,

  EMR_COLORMATCHTOTARGETW = 0x00000079,

  EMR_CREATECOLORSPACEW = 0x0000007A

} RecordType;

**EMR_HEADER: **This record defines the start of the metafile and specifies its characteristics; its contents, including the dimensions of the embedded image; the number of records in the metafile; and the resolution of the device on which the embedded image was created. These values make it possible for the metafile to be device-independent.

**EMR_POLYBEZIER: **This record defines one or more **Bezier curves**. Cubic Bezier curves are defined using specified endpoints and control points, and are stroked with the current pen.

**EMR_POLYGON: **This record defines a polygon consisting of two or more vertexes connected by straight lines. The polygon is outlined by using the current pen and filled by using the current brush and polygon fill mode. The polygon is closed automatically by drawing a line from the last vertex to the first.

**EMR_POLYLINE: **This record defines a series of line segments by connecting the points in the specified array.

**EMR_POLYBEZIERTO: **This record defines one or more Bezier curves based upon the current drawing position.

**EMR_POLYLINETO: **This record defines one or more straight lines based upon the current drawing position. A line is drawn from the current drawing position to the first point specified by the points field by using the current pen. For each additional line, drawing is performed from the ending point of the previous line to the next point specified by points.

**EMR_POLYPOLYLINE: **This record defines multiple series of connected line segments. The line segments are drawn by using the current pen. The figures formed by the segments are not filled. The current position is neither used nor updated by this record.

**EMR_POLYPOLYGON: **This record defines a series of closed polygons. Each polygon is outlined by using the current pen and filled by using the current brush and polygon fill mode. The polygons defined by this record can overlap.

**EMR_SETWINDOWEXTEX: **This record defines the window extent.

**EMR_SETWINDOWORGEX: **This record defines the window origin.

**EMR_SETVIEWPORTEXTEX: **This record defines the viewport extent.

**EMR_SETVIEWPORTORGEX: **This record defines the viewport origin.

**EMR_SETBRUSHORGEX: **This record defines the origin of the current brush.

**EMR_EOF: **This record indicates the end of the metafile.

**EMR_SETPIXELV: **This record defines the color of the pixel at the specified logical coordinates.

**EMR_SETMAPPERFLAGS: **This record specifies parameters for the process of matching logical fonts to physical fonts, which is performed by the **font mapper**.

**EMR_SETMAPMODE: **This record defines the **mapping mode**, which defines the unit of measure used to transform **page space** units into **device space** units, and defines the orientation of the device's X and Y axes.

**EMR_SETBKMODE: **This record defines the background mix mode, which is used with text, hatched brushes, and pen styles that are not solid lines.

**EMR_SETPOLYFILLMODE: **This record defines polygon fill mode.

**EMR_SETROP2: **This record defines binary **raster operation** mode.

**EMR_SETSTRETCHBLTMODE:**** **This record defines **bitmap** stretch mode.

**EMR_SETTEXTALIGN: **This record defines text alignment.

**EMR_SETCOLORADJUSTMENT: **This record defines the color adjustment values using the specified values.

**EMR_SETTEXTCOLOR: **This record defines the current text color.

**EMR_SETBKCOLOR: **This record defines the background color.

**EMR_OFFSETCLIPRGN: **This record redefines the current clipping **regi****on** by the specified offsets.

**EMR_MOVETOEX: **This record defines coordinates of the new drawing position in logical units.

**EMR_SETMETARGN: **This record intersects the current clipping region with the current metaregion and saves the combined region as the new current metaregion.

**EMR_EXCLUDECLIPRECT: **This record defines a new clipping region that consists of the current clipping region intersected with the specified rectangle.

**EMR_INTERSECTCLIPRECT: **This record defines a new clipping region from the intersection of the current clipping region and the specified rectangle.

**EMR_SCALEVIEWPORTEXTEX: **This record redefines the viewport using the ratios formed by the specified multiplicands and divisors.

**EMR_SCALEWINDOWEXTEX: **This record redefines the window using the ratios formed by the specified multiplicands and divisors.

**EMR_SAVEDC: **This record saves the current state of the **playback device context** (section 3.1) in an array of states saved by preceding **EMR_SAVEDC** records if any.

**EMR_RESTOREDC: **This record restores the playback device context to the specified state, which was saved by a preceding **EMR_SAVEDC** record (section 2.3.11).

**EMR_SETWORLDTRANSFORM: **This record defines a two-dimensional linear **transform** between **wo****rld space** and page space [MSDN-WRLDPGSPC].

**EMR_MODIFYWORLDTRANSFORM: **This record redefines the world transform by using the specified mode.

**EMR_SELECTOBJECT: **This record selects an object in the playback device context, which is identified by its index in the EMF object table (section 3.1.1.1).

**EMR_CREATEPEN: **This record defines a logical pen (section 2.2.19) that has the specified style, width, and color.

**EMR_CREATEBRUSHINDIRECT: **This record defines a logical brush for filling figures in graphics operations.

**EMR_DELETEOBJECT: **This record deletes a graphics object, clearing its index in the EMF object table.

**EMR_ANGLEARC: **This record defines a line segment of an arc. The line segment is drawn from the current drawing position to the beginning of the arc. The arc is drawn along the perimeter of a circle with the given radius and center. The length of the arc is defined by the given start and sweep angles.

**EMR_ELLIPSE: **This record defines an ellipse. The center of the ellipse is the center of the specified bounding rectangle. The ellipse is outlined by using the current pen and is filled by using the current brush.

**EMR_RECTANGLE: **This record defines a rectangle. The rectangle is outlined by using the current pen and filled by using the current brush.

**EMR_ROUNDRECT: **This record defines a rectangle with rounded corners. The rectangle is outlined by using the current pen and filled by using the current brush.

**EMR_ARC: **This record defines an elliptical arc.

**EMR_CHORD: **This record defines a chord, which is a region bounded by the intersection of an ellipse and a line segment, called a secant. The chord is outlined by using the current pen and filled by using the current brush.

**EMR_PIE: **This record defines a pie-shaped wedge bounded by the intersection of an ellipse and two radials. The pie is outlined by using the current pen and filled by using the current brush.

**EMR_SELECTPALETTE: **This record selects a LogPalette object (section 2.2.17) into the playback device context, identifying it by its index in the EMF object table.

**EMR_CREATEPALETTE: **This record defines a LogPalette object.

**EMR_SETPALETTEENTRIES: **This record defines **RGB** color values in a range of entries in a LogPalette object.

**EMR****_RESIZEPALETTE: **This record increases or decreases the size of a **logical palette**.

**EMR_REALIZEPALETTE: **This record maps entries from the current logical palette to the **system palette**.

**EMR_EXTFLOODFILL: **This record fills an area of the display surface with the current brush.

**EMR_LINETO: **This record defines a line from the current drawing position up to, but not including, the specified point. It resets the current drawing position to the specified point.

**EMR_ARCTO: **This record defines an elliptical arc. It resets the current position to the endpoint of the arc.

**EMR_POLYDRAW: **This record defines a set of line segments and Bezier curves.

**EM****R_SETARCDIRECTION: **This record defines the drawing direction to be used for arc and rectangle operations.

**EMR_SETMITERLIMIT: **This record defines the limit for the length of miter joins.

**EMR_BEGINPATH: **This record opens a **path bracket** for specifying the current **path**.

**EMR_ENDPATH: **This record closes an open path bracket and selects the path into the playback device context.

**EMR_CLOSEFIGURE: **This record closes an open figure in a path.

**EMR_FILLPATH: **This record closes any open figures in the current path bracket and fills its interior by using the current brush and polygon-filling mode.

**EMR_STROKEANDFILLPATH: **This record closes any open figures in a path, strokes the outline of the path by using the current pen, and fills its interior by using the current brush.

**EMR_STROKEPATH: **This record renders the specified path by using the current pen.

**EMR_FLATTENPATH: **This record turns each curve in the path into a sequence of lines.

**EMR_WIDENPATH: **This record redefines the current path bracket as the area that would be painted if the path were stroked using the current pen.

**EMR_SELECTCLIPPATH: **This record specifies a clipping region as the current clipping region combined with the current path bracket, using the specified mode.

**EMR_ABORTPATH: **This record aborts a path bracket or discards the path from a closed path bracket.

**EMR_COMMENT: **This record specifies arbitrary private data.

**EMR_FILLRGN: **This record fills the specified region by using the specified brush.

**EMR_FRAMERGN: **This record draws a border around the specified region using the specified brush.

**EMR_INVERTRGN: **This record inverts the colors in the specified region.

**EMR_PAI****NTRGN: **This record paints the specified region by using the current brush.

**EMR_EXTSELECTCLIPRGN: **This record combines the specified region with the current clipping region, using the specified mode.

**EMR_BITBLT: **This record specifies a block transfer of pixels from a source bitmap to a destination rectangle, optionally in combination with a brush pattern, according to a specified raster operation.

**EMR_STRETCHBLT: **This record specifies a block transfer of pixels from a source bitmap to a destination rectangle, optionally in combination with a brush pattern, according to a specified raster operation, stretching or compressing the output to fit the dimensions of the destination, if necessary.

**EMR_MASKBLT: **This record specifies a block transfer of pixels from a source bitmap to a destination rectangle, optionally in combination with a brush pattern and with the application of a color mask bitmap, according to specified foreground and background raster operations.

**EMR_PLGBLT: **This record specifies a block transfer of pixels from a source bitmap to a destination parallelogram, with the application of a color mask bitmap.

**EMR_SETDIBITSTODEVICE: **This record specifies a block transfer of pixels from specified scanlines of a source bitmap to a destination rectangle.

**EMR_****STRETCHDIBITS: **This record specifies a block transfer of pixels from a source bitmap to a destination rectangle, optionally in combination with a brush pattern, according to a specified raster operation, stretching or compressing the output to fit the dimensions of the destination, if necessary.

**EMR_EXTCREATEFONTINDIRECTW: **This record defines a logical font that has the specified characteristics. The font can subsequently be selected as the current font.

**EMR_EXTTEXTOUTA: **This record draws an **ASCII** text string using the current font and text colors.

**EMR_EXTTEXTOUTW: **This record draws a **Unicode** text string using the current font and text colors.

**EMR_POLYBEZIER16: **This record defines one or more Bezier curves. The curves are drawn using the current pen.

**EMR_POLYGON16: **This record defines a polygon consisting of two or more vertexes connected by straight lines. The polygon is outlined by using the current pen and filled by using the current brush and polygon fill mode. The polygon is closed automatically by drawing a line from the last vertex to the first.

**EMR_POLYLINE16: **This record defines a series of line segments by connecting the points in the specified array.

**EMR_POLYBEZIERTO16: **This record defines one or more Bezier curves based on the current position.

**EMR_POLYLINETO16: **This record defines one or more straight lines based upon the current position. A line is drawn from the current position to the first point specified by the **Points** field by using the current pen. For each additional line, drawing is performed from the ending point of the previous line to the next point specified by **Points**.

**EMR_POLYPOLYLINE16: **This record defines multiple series of connected line segments.

**EMR_POLYPOLYGON16: **This record defines a series of closed polygons. Each polygon is outlined by using the current pen and filled by using the current brush and polygon fill mode. The polygons specified by this record can overlap.

**EMR_POLYDRAW16: **This record defines a set of line segments and Bezier curves.

**EMR_CREATEMONOBRUSH: **This record defines a logical brush with the specified bitmap pattern. The bitmap can be a **device-independent bitmap (DIB)** section bitmap or it can be a device-dependent bitmap.

**EMR_CREATEDIBPATTERNBRUSHPT: **This record defines a logical brush that has the pattern specified by the DIB.

**EMR_EXTCREATEPEN: **This record defines an extended logical pen (section 2.2.20) that has the specified style, width, color, and brush attributes.

**EMR_POLYTEXTOUTA: **This record draws one or more ASCII text strings using the current font and text colors.

**Note: **EMR_POLYTEXTOUTA SHOULD be emulated with a series of EMR_EXTTEXTOUTW records, one per string.<3>

**EMR_POLYTEXTOUTW: **This record draws one or more Unicode text strings using the current font and text colors.

**Note: **EMR_POLYTEXTOUTW SHOULD be emulated with a series of EMR_EXTTEXTOUTW records, one per string.<4>

**EMR_SETICMMODE: **This record specifies the mode of **Image Color Management (ICM)** for graphics operations.<5>

**EMR_CREATECOLORSPACE: **This record creates a logical **color space** object from a **color profile** with a name consisting of ASCII characters.<6>

**EMR_SETCOLORSPACE: **This record defines the current logical color space object for graphics operations.<7>

**EMR_DE****LETECOLORSPACE: **This record deletes a logical color space object.<8>

**Note: **An EMR_DELETEOBJECT record SHOULD be used instead of EMR_DELETECOLORSPACE to delete a logical color space object.<9>

**EMR_GLSRECORD: **This record specifies an **OpenGL** function.<10>

**EMR_GLSBOUNDEDRECORD: **This record specifies an OpenGL function with a bounding rectangle for output.<11>

**EMR_PIXELFORMAT: **This record specifies the pixel format to use for graphics operations.<12>

**EMR_DRAWESCAPE: **This record passes arbitrary information to the driver. The intent is that the information results in drawing being done.

**EMR_EXTESCAPE: **This record passes arbitrary information to the driver. The intent is that the information does not result in drawing being done.

**EMR_SMALLTEXTOUT: **This record outputs a string.

**EMR_FORCEUFIMAPPING: **This record forces the font mapper to match fonts based on their **UniversalFontId** in preference to their **LogFont** information.

**EMR_NAMEDESCAPE: **This record passes arbitrary information to the given named driver.

**EMR_COLORCORRECT****PALETTE: **This record specifies how to correct the entries of a logical palette object using **Windows Color System (WCS)** 1.0 values.<13>

**EMR_SETICMPROFILEA: **This record specifies a color profile in a file with a name consisting of ASCII characters, for graphics output.<14>

**EMR_SETICMPROFILEW: **This record specifies a color profile in a file with a name consisting of Unicode characters, for graphics output.<15>

**EMR_ALPHABLEND: **This record specifies a block transfer of pixels from a source bitmap to a destination rectangle, including **alpha transparency** data, according to a specified blending operation.<16>

**EMR_SETLAYOUT: **This record specifies the order in which text and graphics are drawn.<17>

**EMR_TRANSPARENTBLT: **This record specifies a block transfer of pixels from a source bitmap to a destination rectangle, treating a specified color as transparent, stretching or compressing the output to fit the dimensions of the destination, if necessary.<18>

**EMR_GRADIENTFILL: **This record specifies filling rectangles or triangles with gradients of color.<19>

**EMR_SETLINKEDUFIS: **This record sets the **UniversalFontIds** (section 2.2.27) of linked fonts to use during character lookup.

**EMR_SETTEXTJUSTIFICATION: **This record specifies the amount of extra space to add to break characters for justification purposes.<20>

**EMR_COLORMATCHTOTARGETW: **This record specifies whether to perform **color matching** with a color profile that is specified in a file with a name consisting of Unicode characters.<21>

**EMR_CREATECOLORSPACEW: **This record creates a logical color space object from a color profile with a name consisting of Unicode characters.<22>

### ArcDirection Enumeration

The **ArcDirection **enumeration is used in setting the drawing direction for arcs and rectangles.

typedef  enum 

{

  AD_COUNTERCLOCKWISE = 0x00000001,

  AD_CLOCKWISE = 0x00000002

} ArcDirection;

**AD_COUNTERCLOCKWISE: **Figures drawn counterclockwise.

**AD_CLOCKWISE: **Figures drawn clockwise.

### ArmStyle Enumeration

The ArmStyle enumeration defines values for one of the characteristics in the **PANOSE** system for classifying **typefaces**.

typedef  enum 

{

  PAN_ANY = 0x00,

  PAN_NO_FIT = 0x01,

  PAN_STRAIGHT_ARMS_HORZ = 0x02,

  PAN_STRAIGHT_ARMS_WEDGE = 0x03,

  PAN_STRAIGHT_ARMS_VERT = 0x04,

  PAN_STRAIGHT_ARMS_SINGLE_SERIF = 0x05,

  PAN_STRAIGHT_ARMS_DOUBLE_SERIF = 0x06,

  PAN_BENT_ARMS_HORZ = 0x07,

  PAN_BENT_ARMS_WEDGE = 0x08,

  PAN_BENT_ARMS_VERT = 0x09,

  PAN_BENT_ARMS_SINGLE_SERIF = 0x0A,

  PAN_BENT_ARMS_DOUBLE_SERIF = 0x0B

} ArmStyle;

**PAN_ANY: **Any.

**PAN_NO_FIT: **No fit.

**PAN_STRAIGHT_ARMS_HORZ: **Straight arms/horizontal.

**PAN_STRAIGHT_ARMS_WEDGE: **Straight arms/wedge.

**PAN_STRAIGHT_ARMS_VERT: **Straight arms/vertical.

**PAN_STRAIGHT_ARMS_SINGLE_SERIF: **Straight arms/single-serif.

**PAN_STRAIGHT_ARMS_DOUBLE_SERIF: **Straight arms/double-serif.

**PAN_BENT_ARMS_HORZ: **Nonstraight arms/horizontal.

**PAN_BENT_ARMS_WEDGE: **Nonstraight arms/wedge.

**PAN_BENT_ARMS_VERT: **Nonstraight arms/vertical.

**PAN_BENT_ARMS_SINGLE_SERIF: **Nonstraight arms/single-serif.

**PAN_BENT_ARMS_DOUBLE_SERIF: **Nonstraight arms/double-serif.

### BackgroundMode Enumeration

The **BackgroundMode** enumeration is used to specify the background mode to be used with text, hatched brushes, and pen styles that are not solid. The background mode determines how to combine the background with foreground text, hatched brushes, and pen styles that are not solid lines.

typedef  enum 

{

  TRANSPARENT = 0x0001,

  OPAQUE = 0x0002

} BackgroundMode;

**TRANSPARENT: **Background remains untouched.

**OPAQUE: **Background is filled with the current background color before the text, hatched brush, or pen is drawn.

### ColorAdjustment Enumeration

The ColorAdjustment enumeration is used to specify how the output image is prepared when the stretch mode is **HALFTONE**.

typedef  enum 

{

  CA_NEGATIVE = 0x0001,

  CA_LOG_FILTER = 0x0002

} ColorAdjustment;

**CA****_NEGATIVE: **Specifies that the negative of the original image SHOULD be displayed.

**CA_LOG_FILTER: **Specifies that a logarithmic process SHOULD be applied to the final density of the output colors. This will increase the color contrast when the luminance is low.

### ColorMatchToTarget Enumeration

The **ColorMatchToTarget** enumeration is used to determine whether a **color profile** has been embedded in the **metafile**.

typedef  enum 

{

  COLORMATCHTOTARGET_NOTEMBEDDED = 0x00000000,

  COLORMATCHTOTARGET_EMBEDDED = 0x00000001

} ColorMatchToTarget;

**COLORMATCHTOTARGET_NOTEMBEDDED: **Indicates that a color profile has not been embedded in the metafile.

**COLORMATCHTOTARGET_EMBEDDED: **Indicates that a color profile has been embedded in the metafile.

### ColorSpace Enumeration

The **ColorSpace** enumeration is used to specify when to turn **color proofing** on and off, and when to delete **transforms**.

typedef  enum 

{

  CS_ENABLE = 0x00000001,

  CS_DISABLE = 0x00000002,

  CS_DELETE_TRANSFORM = 0x00000003

} ColorSpace;

**CS_ENABLE: **Maps colors to the target device's **color gamut**. This enables color proofing. All subsequent draw commands render colors as they would appear on the target device.

**CS_DISABLE: **Disables color proofing.

**CS_DELETE_TRANSFORM: **If color management is enabled for the target profile, disables it and deletes the current color transform.

### Contrast Enumeration

The Contrast enumeration defines values for one of the characteristics in the **PANOSE** system for classifying **typefaces**.

typedef  enum 

{

  PAN_ANY = 0x00,

  PAN_NO_FIT = 0x01,

  PAN_CONTRAST_NONE = 0x02,

  PAN_CONTRAST_VERY_LOW = 0x03,

  PAN_CONTRAST_LOW = 0x04,

  PAN_CONTRAST_MEDIUM_LOW = 0x05,

  PAN_CONTRAST_MEDIUM = 0x06,

  PAN_CONTRAST_MEDIUM_HIGH = 0x07,

  PAN_CONTRAST_HIGH = 0x08,

  PAN_CONTRAST_VERY_HIGH = 0x09

} Contrast;

**PAN_ANY: **Any.

**PAN_NO_FIT: **No fit.

**PAN_CONTRAST_NONE: **None.

**PAN_CONTRAST_VERY_LOW: **Very low.

**PAN_CONTRAST_LOW: **Low.

**PAN_CONTRAST_MEDIUM_LOW: **Medium low.

**PAN_CONTRAST_MEDIUM: **Medium.

**PAN_CONTRAST_MEDIUM_HIGH: **Medium high.

**PAN_CONTRAST_HIGH: **High.

**PAN_CONTRAST_VERY_HIGH: **Very high.

### DIBColors Enumeration

The **DIBColors** enumeration defines how to interpret the values in the color table of a **DIB**.

typedef  enum 

{

  DIB_RGB_COLORS = 0x00,

  DIB_PAL_COLORS = 0x01,

  DIB_PAL_INDICES = 0x02

} DIBColors;

**DIB_RGB_COLORS: **The color table contains literal **RGB** values.

**DIB_PAL_COLORS: **The color table consists of an array of 16-bit indexes into the LogPalette object (section 2.2.17) that is currently defined in the **playback device context**.

**DIB_PAL_INDICES: **No color table exists. The pixels in the DIB are indices into the current logical palette in the playback device context.

DIBs are specified by DeviceIndependentBitmap objects ([MS-WMF] section 2.2.2.9).

### EmrComment Enumeration

The **EmrComment **enumeration defines the types of data that a public comment record can contain, as specified in section 2.3.3.4.

typedef  enum 

{

  EMR_COMMENT_WINDOWS_METAFILE = 0x80000001,

  EMR_COMMENT_BEGINGROUP = 0x00000002,

  EMR_COMMENT_ENDGROUP = 0x00000003,

  EMR_COMMENT_MULTIFORMATS = 0x40000004,

  EMR_COMMENT_UNICODE_STRING = 0x00000040,

  EMR_COMMENT_UNICODE_END = 0x00000080

} EmrComment;

**EMR_COMMENT_WINDOWS_METAFILE: **This comment record contains a specification of an image in **WMF** [MS-WMF].

**EMR_COMMENT_BEGINGROUP: **This comment record identifies the beginning of a group of drawing records.

**EMR_COMMENT_ENDGROUP: **This comment record identifies the end of a group of drawing records. 

**EMR_COMMENT_MULTIFORMATS: **This comment record allows multiple definitions of an image to be included in the **metafile**. Using this comment, for example, an application can include encapsulated **PostScript** text as well as an **EMF** definition of an image.

**EMR_COMMENT_UNICODE_STRING: **This comment record is reserved and MUST NOT be used.

**EMR_COMMENT_UNICODE_END: **This comment record is reserved and MUST NOT be used.

### ExtTextOutOptions Enumeration

The ExtTextOutOptions enumeration specifies parameters that control various aspects of the output of text by EMR_SMALLTEXTOUT (section 2.3.5.37) records and in EmrText objects.

typedef  enum 

{

  ETO_OPAQUE = 0x00000002,

  ETO_CLIPPED = 0x00000004,

  ETO_GLYPH_INDEX = 0x00000010,

  ETO_RTLREADING = 0x00000080,

  ETO_NO_RECT = 0x00000100,

  ETO_SMALL_CHARS = 0x00000200,

  ETO_NUMERICSLOCAL = 0x00000400,

  ETO_NUMERICSLATIN = 0x00000800,

  ETO_IGNORELANGUAGE = 0x00001000,

  ETO_PDY = 0x00002000,

  ETO_REVERSE_INDEX_MAP = 0x00010000

} ExtTextOutOptions;

**ETO_OPAQUE: **This bit indicates that the current background color SHOULD be used to fill the rectangle.

**ETO_CLIPPED: **This bit indicates that the text SHOULD be clipped to the rectangle.

**ETO_GLYPH_INDEX: **This bit indicates that the codes for characters in an output text string are indexes of the character glyphs in a **TrueType** font. Glyph indexes are font-specific, so to display the correct characters on playback, the font that is used MUST be identical to the font used to generate the indexes.<23>

**ETO_RTLREADING: **This bit indicates that the text MUST be laid out in right-to-left reading order, instead of the default left-to-right order. This SHOULD be applied only when the font selected into the **playback device context** is either Hebrew or Arabic.<24>

**ETO_NO_RECT: **This bit indicates that the record does not specify a bounding rectangle for the text output.

**ETO_SMALL_CHARS: **This bit indicates that the codes for characters in an output text string are 8 bits, derived from the low bytes of **Unicode** **UTF16-LE** character codes, in which the high byte is assumed to be 0.

**ETO_NUMERICSLOCAL: **This bit indicates that to display numbers, digits appropriate to the locale SHOULD be used.<25>

**ETO_NUMERICSLATIN: **This bit indicates that to display numbers, European digits SHOULD be used.<26>

**ETO_IGNORELANGUAGE: **This bit indicates that no special operating system processing for glyph placement is performed on right-to-left strings; that is, all glyph positioning SHOULD be taken care of by drawing and state records in the **metafile**.<27>

**ETO_PDY: **This bit indicates that both horizontal and vertical character displacement values SHOULD be provided.<28>

**ETO_REVERSE_INDEX_MAP: **This bit is reserved and SHOULD NOT be used.<29>

### FamilyType Enumeration

The FamilyType enumeration defines values for one of the characteristics in the **PANOSE** system for classifying **typefaces**.

typedef  enum 

{

  PAN_ANY = 0x00,

  PAN_NO_FIT = 0x01,

  PAN_FAMILY_TEXT_DISPLAY = 0x02,

  PAN_FAMILY_SCRIPT = 0x03,

  PAN_FAMILY_DECORATIVE = 0x04,

  PAN_FAMILY_PICTORIAL = 0x05

} FamilyType;

**PAN_ANY: **Any.

**PAN_NO_FIT: **No fit.

**PAN_FAMILY_TEXT_DISPLAY: **Text and display.

**PAN_FAMILY_SCRIPT: **Script.

**PAN_FAMILY_DECORATIVE: **Decorative.

**PAN_FAMILY_PICTORIAL: **Pictorial.

### FloodFill Enumeration

The FloodFill enumeration defines values that specify how to determine the area for a flood fill operation.

typedef  enum 

{

  FLOODFILLBORDER = 0x00000000,

  FLOODFILLSURFACE = 0x00000001

} FloodFill;

**FLOODFILLBORDER: **The fill area is bounded by a specific color.

**FLOODFILLSURFACE: **The fill area is defined by a specific color. Filling continues outward in all directions as long as the color is encountered. This style is useful for filling areas with multicolored boundaries.

### FormatSignature Enumeration

The **FormatSignature** enumeration defines values that are used to identify the format of embedded data in **EMF** **metafiles**.

typedef  enum 

{

  ENHMETA_SIGNATURE = 0x464D4520,

  EPS_SIGNATURE = 0x46535045

} FormatSignature;

**ENHMETA_SIGNATURE: **The sequence of **ASCII** characters "FME ", which denotes EMF data. The reverse of the string is " EMF".

**Note: **The space character in the string is significant and MUST be present.

This signature is used in the following structures:

EMR_HEADER records (section 2.3.4.2) to identify the EMF metafile 

The EmrFormat object (section 2.2.4) in EMR_COMMENT_MULTIFORMATS records (section 2.3.3.4.3), to specify embedded EMF records.

**EPS_SIGNATURE: **The value of this member is the sequence of ASCII characters "FSPE", which denotes **encapsulated PostScript (EPS)** data. The reverse of the string is "EPSF".

This signature is used in EmrFormat objects to specify embedded **P****ostScript** data in the EpsData object (section 2.2.6) in EMR_COMMENT_MULTIFORMATS records.

### GradientFill Enumeration

The **GradientFill** enumeration defines the modes for gradient fill operations.

typedef  enum 

{

  GRADIENT_FILL_RECT_H = 0x00000000,

  GRADIENT_FILL_RECT_V = 0x00000001,

  GRADIENT_FILL_TRIANGLE = 0x00000002

} GradientFill;

**GRADIENT_FILL_RECT_H: **Color interpolation along a gradient from the left to the right edges of a rectangle.

**GRADIENT_FILL_RECT_V: **Color interpolation along a gradient from the top to the bottom edges of a rectangle.

**GRADIENT_FILL_TRIANGLE: **Color interpolation between vertexes of a triangle.

### GraphicsMode Enumeration

The **GraphicsMode** enumeration is used to specify how to interpret shape data such as rectangle coordinates.

typedef  enum 

{

  GM_COMPATIBLE = 0x00000001,

  GM_ADVANCED = 0x00000002

} GraphicsMode;

**GM_COMPATIBLE: ****TrueType** text MUST be written from left to right and right side up, even if the rest of the graphics are **rotated** about the x-axis or y-axis because of the current world-to-device **transform**. Only the height of the text SHOULD be scaled.<30>

Arcs MUST be drawn using the current arc direction, but they MUST NOT reflect the current world-to-device transform, which might require a **rotation** along the x-axis or y-axis.

The world-to-device transform is modified by changing the window and viewport extents and origins, using the EMR_SETWINDOWEXTEX (section 2.3.11.30) and EMR_SETVIEWPORTEXTEX (section 2.3.11.28) records, and the EMR_SETWINDOWORGEX (section 2.3.11.31) and EMR_SETVIEWPORTORGEX (section 2.3.11.29) records, respectively.

The world-to-device transform can be changed by EMR_MODIFYWORLDTRANSFORM (section 2.3.12.1) and EMR_SETWORLDTRANSFORM (section 2.3.12.2) records.

In **GM_COMPATIBLE** graphics mode, bottom and rightmost edges MUST be excluded when rectangles are drawn.

**GM_ADVANCED: **TrueType text output SHOULD<31> fully conform to the current world-to-device transform.

Arcs MUST be drawn in the counterclockwise direction in **world space**; however, both arc control points and the arcs themselves MUST reflect the current world-to-device transform.

The world-to-device transform can be modified directly by EMR_MODIFYWORLDTRANSFORM and EMR_SETWORLDTRANSFORM records, or indirectly by changing the window and viewport extents and origins, using the EMR_SETWINDOWEXTEX and EMR_SETVIEWPORTEXTEX records, and the EMR_SETWINDOWORGEX and EMR_SETVIEWPORTORGEX records, respectively.

In **GM_ADVANCED** graphics mode, bottom and rightmost edges MUST be included when rectangles are drawn.

### HatchStyle Enumeration

The **HatchStyle** enumeration is an extension to the **WMF** **HatchStyle** enumeration ([MS-WMF] section 2.1.1.12).

typedef  enum 

{

  HS_SOLIDCLR = 0x0006,

  HS_DITHEREDCLR = 0x0007,

  HS_SOLIDTEXTCLR = 0x0008,

  HS_DITHEREDTEXTCLR = 0x0009,

  HS_SOLIDBKCLR = 0x000A,

  HS_DITHEREDBKCLR = 0x000B

} HatchStyle;

**HS_SOLIDCLR: **The hatch is not a pattern, but is a solid color.

**HS_DITHEREDCLR: **The hatch is not a pattern, but is a dithered color.

**HS_SOLIDTEXTCLR: **The hatch is not a pattern, but is a solid color, defined by the current text (foreground) color.

**HS_DITHEREDTEXTCLR: **The hatch is not a pattern, but is a dithered color, defined by the current text (foreground) color.

**HS_SOLIDBKCLR: **The hatch is not a pattern, but is a solid color, defined by the current background color.

**HS_DITHEREDBKCLR: **The hatch is not a pattern, but is a dithered color, defined by the current background color.

### ICMMode Enumeration

The **ICMMode** enumeration defines values that specify when to turn on and off **Image Color Management (ICM)**.<32>

typedef  enum 

{

  ICM_OFF = 0x01,

  ICM_ON = 0x02,

  ICM_QUERY = 0x03,

  ICM_DONE_OUTSIDEDC = 0x04

} ICMMode;

**ICM_OFF: **Turns off ICM; turns on old-style **color correction** of **halftones**.

**ICM_ON: **Turns on ICM; turns off old-style color correction of halftones.

**ICM_QUERY: **Queries the current state of color management.

**ICM_DONE_OUTSIDEDC: **Turns off both ICM and old-style color correction of halftones. 

### Illuminant Enumeration

The **Illuminant** enumeration defines values that specify the illuminant value of an image, which determines the standard light source under which the image is viewed so that the color can be adjusted appropriately.

typedef  enum 

{

  ILLUMINANT_DEVICE_DEFAULT = 0x00,

  ILLUMINANT_TUNGSTEN = 0x01,

  ILLUMINANT_B = 0x02,

  ILLUMINANT_DAYLIGHT = 0x03,

  ILLUMINANT_D50 = 0x04,

  ILLUMINANT_D55 = 0x05,

  ILLUMINANT_D65 = 0x06,

  ILLUMINANT_D75 = 0x07,

  ILLUMINANT_FLUORESCENT = 0x08

} Illuminant;

**ILLUMINANT_DEVICE_DEFAULT: **Device's default. Standard used by output devices.

**ILLUMINANT_TUNGSTEN: **Tungsten lamp.

**ILLUMINANT_B: **Noon sunlight.

**ILLUMINANT_DAYLIGHT: **Daylight.

**ILLUMINANT_D50: **Normal print.

**ILLUMINANT_D55: **Bond paper print.

**ILLUMINANT_D65: **Standard daylight. Standard for CRTs and pictures.

**ILLUMINANT_D75: **Northern daylight.

**ILLUMINANT_FLUORESCENT: **Cool white lamp.

### Letterform Enumeration

The **Letterform** enumeration defines values for one of the characteristics in the **PANOSE** system for classifying **typefaces**.

typedef  enum 

{

  PAN_ANY = 0x00,

  PAN_NO_FIT = 0x01,

  PAN_LETT_NORMAL_CONTACT = 0x02,

  PAN_LETT_NORMAL_WEIGHTED = 0x03,

  PAN_LETT_NORMAL_BOXED = 0x04,

  PAN_LETT_NORMAL_FLATTENED = 0x05,

  PAN_LETT_NORMAL_ROUNDED = 0x06,

  PAN_LETT_NORMAL_OFF_CENTER = 0x07,

  PAN_LETT_NORMAL_SQUARE = 0x08,

  PAN_LETT_OBLIQUE_CONTACT = 0x09,

  PAN_LETT_OBLIQUE_WEIGHTED = 0x0A,

  PAN_LETT_OBLIQUE_BOXED = 0x0B,

  PAN_LETT_OBLIQUE_FLATTENED = 0x0C,

  PAN_LETT_OBLIQUE_ROUNDED = 0x0D,

  PAN_LETT_OBLIQUE_OFF_CENTER = 0x0E,

  PAN_LETT_OBLIQUE_SQUARE = 0x0F

} Letterform;

**PAN_ANY: **Any.

**PAN_NO_FIT: **No fit.

**PAN_LETT_NORMAL_CONTACT: **Normal/contact.

**PAN_LETT_NORMAL_WEIGHTED: **Normal/weighted.

**PAN_LETT_NORMAL_BOXED: **Normal/boxed.

**PAN_LETT_NORMAL_FLATTENED: **Normal/flattened.

**PAN_LETT_NORMAL_ROUNDED: **Normal/rounded.

**PAN_LETT_NORMAL_OFF_CENTER: **Normal/off center.

**PAN_LETT_NORMAL_SQUARE: **Normal/square

**PAN_LETT_OBLIQUE_CONTACT: **Oblique/contact.

**PAN_LETT_OBLIQUE_WEIGHTED: **Oblique/weighted.

**PAN_LETT_OBLIQUE_BOXED: **Oblique/boxed.

**PAN_LETT_OBLIQUE_FLATTENED: **Oblique/flattened.

**PAN_LETT_OBLIQUE_ROUNDED: **Oblique/rounded.

**PAN_LETT_OBLIQUE_OFF_CENTER: **Oblique/off center.

**PAN_LETT_OBLIQUE_SQUARE: **Oblique/square.

### MapMode Enumeration

The **MapMode** enumeration is used to define the unit of measure for transforming **page sp****ace** units into **device space** units and for defining the orientation of the drawing axes.

typedef  enum 

{

  MM_TEXT = 0x01,

  MM_LOMETRIC = 0x02,

  MM_HIMETRIC = 0x03,

  MM_LOENGLISH = 0x04,

  MM_HIENGLISH = 0x05,

  MM_TWIPS = 0x06,

  MM_ISOTROPIC = 0x07,

  MM_ANISOTROPIC = 0x08

} MapMode;

**MM_TEXT: **Each logical unit is mapped to one device pixel. Positive x is to the right; positive y is down.

**MM_LOMETRIC: **Each logical unit is mapped to 0.1 millimeter. Positive x is to the right; positive y is up.

**MM_HIMETRIC: **Each logical unit is mapped to 0.01 millimeter. Positive x is to the right; positive y is up.

**MM_LOENGLISH: **Each logical unit is mapped to 0.01 inch. Positive x is to the right; positive y is up.

**MM_HIENGLISH: **Each logical unit is mapped to 0.001 inch. Positive x is to the right; positive y is up.

**MM_TWIPS: **Each logical unit is mapped to one-twentieth of a printer's point (1/1440 inch, also called a "twip"). Positive x is to the right; positive y is up.

**MM_ISOTROPIC: **Logical units are **isotropic**; that is, they are mapped to arbitrary units with equally scaled axes. Thus, one unit along the x-axis is equal to one unit along the y-axis. The EMR_SETWINDOWEXTEX (section 2.3.11.30) and EMR_SETVIEWPORTEXTEX (section 2.3.11.28) records are used to specify the units and the orientation of the axes.

Adjustments MUST be made as necessary to ensure that the x and y units remain the same size. For example, when the window extent is set, the viewport MUST be adjusted to keep the units isotropic.

**MM_ANISOTROPIC: **Logical units are **anisotropic**; that is, they are mapped to arbitrary units with arbitrarily scaled axes. The EMR_SETWINDOWEXTEX and EMR_SETVIEWPORTEXTEX records are used to specify the units, orientation, and scaling of the axes.

### MetafileVersion Enumeration

The **MetafileVersion** enumeration defines the interoperability version for **EMF** **metafile**. 

typedef  enum 

{

  META_FORMAT_ENHANCED = 0x00010000

} MetafileVersion;

**META_FORMAT_ENHANCED: **Specifies EMF metafile interoperability.

### MidLine Enumeration

The **MidLine** enumeration defines values for one of the characteristics in the **PANOSE** system for classifying **typefaces**.

typedef  enum 

{

  PAN_ANY = 0x00,

  PAN_NO_FIT = 0x01,

  PAN_MIDLINE_STANDARD_TRIMMED = 0x02,

  PAN_MIDLINE_STANDARD_POINTED = 0x03,

  PAN_MIDLINE_STANDARD_SERIFED = 0x04,

  PAN_MIDLINE_HIGH_TRIMMED = 0x05,

  PAN_MIDLINE_HIGH_POINTED = 0x06,

  PAN_MIDLINE_HIGH_SERIFED = 0x07,

  PAN_MIDLINE_CONSTANT_TRIMMED = 0x08,

  PAN_MIDLINE_CONSTANT_POINTED = 0x09,

  PAN_MIDLINE_CONSTANT_SERIFED = 0x0A,

  PAN_MIDLINE_LOW_TRIMMED = 0x0B,

  PAN_MIDLINE_LOW_POINTED = 0x0C,

  PAN_MIDLINE_LOW_SERIFED = 0x0D

} MidLine;

**PAN_ANY: **Any.

**PAN_NO_F****IT: **No fit.

**PAN_MIDLINE_STANDARD_TRIMMED: **Standard/trimmed.

**PAN_MIDLINE_STANDARD_POINTED: **Standard/pointed.

**PAN_MIDLINE_STANDARD_SERIFED: **Standard/serifed.

**PAN_MIDLINE_HIGH_TRIMMED: **High/trimmed.

**PAN_MIDLINE_HIGH_POINTED: **High/pointed.

**PAN_MIDLINE_HIGH_SERIFED: **High/serifed.

**PAN_MIDLINE_CONSTANT_TRIMMED: **Constant/trimmed.

**PAN_MIDLINE_CONSTANT_POINTED: **Constant/pointed.

**PAN_MIDLINE_CONSTANT_SERIFED: **Constant/serifed.

**PAN_MIDLINE_LOW_TRIMMED: **Low/trimmed.

**PAN_MIDLINE_LOW_POINTED: **Low/pointed.

**PAN_MIDLINE_LOW_SERIFED: **Low/serifed.

### ModifyWorldTransformMode Enumeration

The **ModifyWorldTransformMode** enumeration defines modes for changing the **world-space** to **page-space** **transform** that is currently defined in the **playback device context**.

typedef  enum 

{

  MWT_IDENTITY = 0x01,

  MWT_LEFTMULTIPLY = 0x02,

  MWT_RIGHTMULTIPLY = 0x03,

  MWT_SET = 0x04

} ModifyWorldTransformMode;

**MWT_IDENTITY: **Reset the current transform using the identity matrix. In this mode, the specified transform data is ignored.

**MWT_LEFTMULTIPLY: **Multiply the current transform. In this mode, the specified transform data is the left multiplicand, and the current transform is the right multiplicand.

**MWT_RIGHTMULTIPLY: **Multiply the current transform. In this mode, the specified transform data is the right multiplicand, and the current transform is the left multiplicand.

**MWT_SET: **Set** **the current transform to the specified transform data.

The transform data is specified as an XForm object (section 2.2.28).

For more information concerning transforms and **coordinate spaces**, see [MSDN-WRLDPGSPC].

### PenStyle Enumeration

The **PenStyle** enumeration defines the attributes of pens that can be used in graphics operations. A pen style is a combination of pen type, line style, **line cap**, and **line join**.

typedef  enum

{

  PS_COSMETIC = 0x00000000,

  PS_ENDCAP_ROUND = 0x00000000,

  PS_JOIN_ROUND = 0x00000000,

  PS_SOLID = 0x00000000,

  PS_DASH = 0x00000001,

  PS_DOT = 0x00000002,

  PS_DASHDOT = 0x00000003,

  PS_DASHDOTDOT = 0x00000004,

  PS_NULL = 0x00000005,

  PS_INSIDEFRAME = 0x00000006,

  PS_USERSTYLE = 0x00000007,

  PS_ALTERNATE = 0x00000008,

  PS_ENDCAP_SQUARE = 0x00000100,

  PS_ENDCAP_FLAT = 0x00000200,

  PS_JOIN_BEVEL = 0x00001000,

  PS_JOIN_MITER = 0x00002000,

  PS_GEOMETRIC = 0x00010000

} PenStyle;

**PS_COSMETIC: **A pen type that specifies a line with a width of one logical unit and a style that is a solid color.

**PS_ENDCAP_ROUND: **A line cap that specifies round ends.

**PS_JOIN_ROUND: **A line join that specifies round joins.

**PS_SOLID: **A line style that is a solid color.

**PS_DASH: **A line style that is dashed.

**PS_DOT: **A line style that is dotted.

**PS_DASHDOT: **A line style that consists of alternating dashes and dots.

**PS_DASHDOTDOT: **A line style that consists of dashes and double dots.

**PS_NULL: **A line style that is invisible.

**PS_INSIDEFRAME: **A line style that is a solid color. When this style is specified in a drawing record that takes a bounding rectangle, the dimensions of the figure are shrunk so that it fits entirely in the bounding rectangle, considering the width of the pen.

**PS_USERSTYLE: **A line style that is defined by a styling array, which specifies the lengths of dashes and gaps in the line.

**PS_ALTERNATE: **A line style in which every other pixel is set. This style is applicable only to a pen type of **PS_COSMETIC**.

**PS_ENDCAP_SQUARE: **A line cap that specifies square ends.

**PS_ENDCAP_FLAT: **A line cap that specifies flat ends.

**PS_JOIN_BEVEL: **A line join that specifies beveled joins.

**PS_JOIN_MITER: **A line join that specifies mitered joins when the lengths of the joins are within the current **miter length** limit. If the lengths of the joins exceed the miter limit, beveled joins are specified.

The miter length limit is a **metafile** state property that is set by the EMR_SETMITERLIMIT record (section 2.3.11.21).

**PS_GEOMETRIC: **A pen type that specifies a line with a width that is measured in logical units and a style that can contain any of the attributes of a brush.

### Point Enumeration

The Point enumeration is used to specify how a point is to be used in a drawing call.

typedef  enum 

{

  PT_CLOSEFIGURE = 0x01,

  PT_LINETO = 0x02,

  PT_BEZIERTO = 0x04,

  PT_MOVETO = 0x06

} Point;

**PT_CLOSEFIGURE: **A **PT_LINETO** or **PT_BEZIERTO** type can be combined with this value by using the bitwise operator OR to indicate that the corresponding point is the last point in a figure and the figure is closed.

The current position is set to the ending point of the closing line.

**PT_LINETO: **Specifies that a line is to be drawn from the current position to this point, which then becomes the new current position.

**PT_BEZIERTO: **Specifies that this point is a control point or ending point for a **Bezier curve**.

**PT_BEZIERT****O** types always occur in sets of three. The current position defines the starting point for the Bezier curve. The first two **PT_BEZIERTO** points are the control points, and the third **PT_BEZIERTO** point is the ending point. The ending point becomes the new current position. If there are not three consecutive **PT_BEZIERTO** points, an error results.

**PT_MOVETO: **Specifies that this point starts a disjoint figure. This point becomes the new current position.

### PolygonFillMode Enumeration

The PolygonFillMode enumeration defines values that specify how to calculate the **region** of a polygon that is to be filled.

typedef  enum 

{

  ALTERNATE = 0x01,

  WINDING = 0x02

} PolygonFillMode;

**ALTERNATE: **Selects alternate mode (fills the area between odd-numbered and even-numbered polygon sides on each scan line).

**WINDING: **Selects winding mode (fills any region with a nonzero winding value).

### Proportion Enumeration

The Proportion enumeration defines values for one of the characteristics in the **PANOSE** system for classifying **typefa****ces**.

typedef  enum 

{

  PAN_ANY = 0x00,

  PAN_NO_FIT = 0x01,

  PAN_PROP_OLD_STYLE = 0x02,

  PAN_PROP_MODERN = 0x03,

  PAN_PROP_EVEN_WIDTH = 0x04,

  PAN_PROP_EXPANDED = 0x05,

  PAN_PROP_CONDENSED = 0x06,

  PAN_PROP_VERY_EXPANDED = 0x07,

  PAN_PROP_VERY_CONDENSED = 0x08,

  PAN_PROP_MONOSPACED = 0x09

} Proportion;

**PAN_ANY: **Any.

**PAN_NO_FIT: **No fit.

**PAN_PROP_OLD_STYLE: **Old style.

**PAN_PROP_MODERN: **Modern.

**PAN_PROP_EVEN_WIDTH: **Even width.

**PAN_PROP_EXPANDED: **Expanded.

**PAN_PROP_CONDENSED: **Condensed.

**PAN_PROP_VERY_EXPANDED: **Very expanded.

**PAN_PROP_VERY_CONDENSED: **Very condensed.

**PAN_PROP_MONOSPACED: **Monospaced.

### RegionMode Enumeration

The **RegionMode** enumeration defines values that are used with EMR_SELECTCLIPPATH and EMR_EXTSELECTCLIPRGN, specifying the current **path bra****cket** or a new **region** that is being combined with the current clipping region.

typedef  enum 

{

  RGN_AND = 0x01,

  RGN_OR = 0x02,

  RGN_XOR = 0x03,

  RGN_DIFF = 0x04,

  RGN_COPY = 0x05

} RegionMode;

**RGN_AND: **The new clipping region includes the intersection (overlapping areas) of the current clipping region and the current path bracket (or new region).

**RGN_OR: **The new clipping region includes the union (combined areas) of the current clipping region and the current path bracket (or new region).

**RGN_XOR: **The new clipping region includes the union of the current clipping region and the current path bracket (or new region) but without the overlapping areas.

**RGN_DIFF: **The new clipping region includes the areas of the current clipping region with those of the current path bracket (or new region) excluded.

**RGN_COPY: **The new clipping region is the current path bracket (or the new region).

### SerifType Enumeration

The SerifType enumeration defines values for one of the characteristics in the **PANOSE** system for classifying **typefaces**.

typedef  enum 

{

  PAN_ANY = 0x00,

  PAN_NO_FIT = 0x01,

  PAN_SERIF_COVE = 0x02,

  PAN_SERIF_OBTUSE_COVE = 0x03,

  PAN_SERIF_SQUARE_COVE = 0x04,

  PAN_SERIF_OBTUSE_SQUARE_COVE = 0x05,

  PAN_SERIF_SQUARE = 0x06,

  PAN_SERIF_THIN = 0x07,

  PAN_SERIF_BONE = 0x08,

  PAN_SERIF_EXAGGERATED = 0x09,

  PAN_SERIF_TRIANGLE = 0x0A,

  PAN_SERIF_NORMAL_SANS = 0x0B,

  PAN_SERIF_OBTUSE_SANS = 0x0C,

  PAN_SERIF_PERP_SANS = 0x0D,

  PAN_SERIF_FLARED = 0x0E,

  PAN_SERIF_ROUNDED = 0x0F

} SerifType;

**PAN_ANY: **Any.

**PAN_NO_FIT: **No fit.

**PAN_SERIF_COVE: **Cove.

**PAN_SERIF_OBTUSE_COVE: **Obtuse cove.

**PAN_SERIF_SQUARE_COVE: **Square cove.

**PAN_SERIF_OBTUSE_SQUARE_COVE: **Obtuse square cove.

**PAN_SERIF_SQUARE: **Square.

**PAN_SERIF_THIN: **Thin.

**PAN_SERIF_BONE: **Bone.

**PAN_SERIF_EXAGGERATED: **Exaggerated.

**PAN_SERIF_TRIANGLE: **Triangle.

**PAN_SERIF_NORMAL_SANS: **Normal sans.

**PAN_SERIF_OBTUSE_SANS: **Obtuse sans.

**PAN_SERIF_PERP_SANS: **Perp sans.

**PAN_SERIF_FLARED: **Flared.

**PAN_SERIF_ROUNDED: **Rounded.

### StockObject Enumeration

The **StockObje****ct** enumeration specifies the indexes of predefined logical graphics objects that can be used in graphics operations.

The specific structures of **stock objects** are implementation-dependent; however, the properties of stock objects SHOULD be equivalent to the properties of explicitly created objects of the same type. These properties are specified where possible for the stock objects defined in this enumeration.

typedef  enum 

{

  WHITE_BRUSH = 0x80000000,

  LTGRAY_BRUSH = 0x80000001,

  GRAY_BRUSH = 0x80000002,

  DKGRAY_BRUSH = 0x80000003,

  BLACK_BRUSH = 0x80000004,

  NULL_BRUSH = 0x80000005,

  WHITE_PEN = 0x80000006,

  BLACK_PEN = 0x80000007,

  NULL_PEN = 0x80000008,

  OEM_FIXED_FONT = 0x8000000A,

  ANSI_FIXED_FONT = 0x8000000B,

  ANSI_VAR_FONT = 0x8000000C,

  SYSTEM_FONT = 0x8000000D,

  DEVICE_DEFAULT_FONT = 0x8000000E,

  DEFAULT_PALETTE = 0x8000000F,

  SYSTEM_FIXED_FONT = 0x80000010,

  DEFAULT_GUI_FONT = 0x80000011,

  DC_BRUSH = 0x80000012,

  DC_PEN = 0x80000013

} StockObject;

**WHITE_BRUSH: **A white, solid-color brush that is equivalent to a logical brush (LogBrushEx object, section 2.2.12) with the following properties:

**BrushStyle**: BS_SOLID from the BrushStyle enumeration ([MS-WMF] section 2.1.1.4)

**Color**: 0x00FFFFFF in a ColorRef object ([MS-WMF] section 2.2.2.8)

**LTGRAY_BRUSH: **A light gray, solid-color brush that is equivalent to a logical brush with the following properties:

**BrushStyle**: BS_SOLID

**Color**: 0x00C0C0C0

**GRAY_BRUSH: **A gray, solid-color brush that is equivalent to a logical brush with the following properties:

**BrushStyle**: BS_SOLID

**Color**: 0x00808080

**DKGRAY_BRUSH: **A dark gray, solid color brush that is equivalent to a logical brush with the following properties:

**BrushStyle**: BS_SOLID

**Color**: 0x00404040

**BLACK_BRUSH: **A black, solid color brush that is equivalent to a logical brush with the following properties:

**BrushStyle**: BS_SOLID

**Color**: 0x00000000

**NULL_BRUSH: **A null brush that is equivalent to a logical brush with the following properties:

**BrushStyle**: BS_NULL

**WHITE_PEN: **A white, solid-color pen that is equivalent to a logical pen (LogPen object, section 2.2.19) with the following properties:

**PenStyle**: PS_COSMETIC + PS_SOLID from the PenStyle enumeration (section 2.1.25)

**ColorRef**: 0x00FFFFFF in a ColorRef object.

**BLACK_PEN: **A black, solid-color pen that is equivalent to a logical pen with the following properties:

**PenStyle**: PS_COSMETIC + PS_SOLID

**ColorRef**: 0x00000000

**NULL_PEN: **A null pen that is equivalent to a logical pen with the following properties:

**PenStyle**: PS_NULL

**OEM_FIXED_FONT: **A fixed-width, **OEM character set** font that is equivalent to a LogFont object (section 2.2.13) with the following properties:

**Charset**: OEM_CHARSET from the CharacterSet enumeration ([MS-WMF] section 2.1.1.5)

**PitchAndFamily**: **FF_DONTCARE** (FamilyFont enumeration, [MS-WMF] section 2.1.1.8) + **FIXED_PITCH** (PitchFont enumeration, [MS-WMF] section 2.1.1.24)

**ANSI_FIXED_FONT: **A fixed-width font that is equivalent to a LogFont object with the following properties:<33>

**Charset**: ANSI_CHARSET

**PitchAndFamily**: FF_DONTCARE + FIXED_PITCH

**ANSI_V****AR_FONT: **A variable-width font that is equivalent to a logical font with the following properties:<34>

**Charset**: ANSI_CHARSET

**PitchAndFamily**: FF_DONTCARE + VARIABLE_PITCH

**SYSTEM_FONT: **A font that is guaranteed to be available in the operating system. The actual font that is specified by this value is implementation-dependent.<35>

**DEVICE_DEFAULT_FONT: **The default font that is provided by the graphics device driver for the current output device. The actual font that is specified by this value is implementation-dependent.<36>

**DEFAULT_PALETTE: **The default **palette** that is defined for the current output device. The actual palette that is specified by this value is implementation-dependent.<37>

**SYSTEM_FIXED_FONT: **A fixed-width font that is guaranteed to be available in the operating system. The actual font that is specified by this value is implementation-dependent.

**DEFAULT_GUI_FONT: **The default font that is used for user interface objects such as menus and dialog boxes. The actual font that is specified by this value is implementation-dependent.<38>

**DC_BRUSH: **The solid-color brush that is currently selected in the **playback device context**. The default SHOULD<39> be WHITE_BRUSH.

**DC_PEN: **The solid-color pen that is currently selected in the playback device context. The default SHOULD<40> be BLACK_PEN.

During **metafile** processing, stock object indexes can be used by object manipulation records (section 2.3.8) in the same way as indexes of graphics objects that are explicitly created by object creation records (section 2.3.7). The index of a stock object can be distinguished from the index of an explicit object by the value of the most-significant bit. If that bit is set, the object is a stock object; if the bit is clear, the object was created by a previous metafile record.

### StretchMode Enumeration

The **StretchMode** enumeration is used to specify how color data is added to or removed from **b****itmaps** that are stretched or compressed.<41>

typedef  enum 

{

  STRETCH_ANDSCANS = 0x01,

  STRETCH_ORSCANS = 0x02,

  STRETCH_DELETESCANS = 0x03,

  STRETCH_HALFTONE = 0x04

} StretchMode;

**STRE****TCH_ANDSCANS: **Performs a **Boolean** AND operation using the color values for the eliminated and existing pixels. If the bitmap is a monochrome bitmap, this mode preserves black pixels at the expense of white pixels.

**STRETCH_ORSCANS: **Performs a Boolean OR operation using the color values for the eliminated and existing pixels. If the bitmap is a monochrome bitmap, this mode preserves white pixels at the expense of black pixels.

**STRETCH_DELETESCANS: **Deletes the pixels. This mode deletes all eliminated lines of pixels without trying to preserve their information.

**STRETCH_HALFTONE: **Maps pixels from the source rectangle into blocks of pixels in the destination rectangle. The average color over the destination block of pixels approximates the color of the source pixels.

After setting the **STRETCH_HALFTONE** stretching mode, the brush origin SHOULD be defined by an EMR_SETBRUSHORGEX record. If it fails to do so, brush misalignment can occur.

### StrokeVariation Enumeration

The StrokeVariation enumeration defines values for one of the characteristics in the **PANOS****E** system for classifying **typefaces**.

typedef  enum 

{

  PAN_ANY = 0x00,

  PAN_NO_FIT = 0x01,

  PAN_STROKE_GRADUAL_DIAG = 0x02,

  PAN_STROKE_GRADUAL_TRAN = 0x03,

  PAN_STROKE_GRADUAL_VERT = 0x04,

  PAN_STROKE_GRADUAL_HORZ = 0x05,

  PAN_STROKE_RAPID_VERT = 0x06,

  PAN_STROKE_RAPID_HORZ = 0x07,

  PAN_STROKE_INSTANT_VERT = 0x08

} StrokeVariation;

**PAN_ANY: **Any.

**PAN_NO_FIT: **No fit.

**PAN_STROKE_GRADUAL_DIAG: **Gradual/diagonal.

**PAN_STROKE_GRADUAL_TRAN: **Gradual/transitional.

**PAN_STROKE_GRADUAL_VERT: **Gradual/vertical.

**PAN_STROKE_GRADUAL_HORZ: **Gradual/horizontal.

**PAN_STROKE_RAPID_VERT: **Rapid/vertical.

**PAN_STROKE_RAPID_HORZ: **Rapid/horizontal.

**PAN_STROKE_INSTANT_VERT: **Instant/vertical.

### Weight Enumeration

The Weight enumeration defines values for one of the characteristics in the **PANOSE** system for classifying **typeface****s**.

typedef  enum 

{

  PAN_ANY = 0x00,

  PAN_NO_FIT = 0x01,

  PAN_WEIGHT_VERY_LIGHT = 0x02,

  PAN_WEIGHT_LIGHT = 0x03,

  PAN_WEIGHT_THIN = 0x04,

  PAN_WEIGHT_BOOK = 0x05,

  PAN_WEIGHT_MEDIUM = 0x06,

  PAN_WEIGHT_DEMI = 0x07,

  PAN_WEIGHT_BOLD = 0x08,

  PAN_WEIGHT_HEAVY = 0x09,

  PAN_WEIGHT_BLACK = 0x0A,

  PAN_WEIGHT_NORD = 0x0B

} Weight;

**PAN_ANY: **Any.

**PAN_NO_FIT: **No fit.

**PAN_WEIGHT_VERY_LIGHT: **Very light.

**PAN_WEIGHT_LIGHT: **Light.

**PAN_WEIGHT_THIN: **Thin.

**PAN_WEIGHT_BOOK: **Book.

**PAN_WEIGHT_MEDIUM: **Medium.

**PAN_WEIGHT_DEMI: **Demi.

**PAN_WEIGHT_BOLD: **Bold.

**PAN_WEIGHT_HEAVY: **Heavy.

**PAN_WEIGHT_BLACK: **Black.

**PAN_WEIGHT_NORD: **Nord.

### XHeight Enumeration

The XHeight enumeration defines values for one of the characteristics in the **PANOSE** system for classifying **typefaces**.

typedef  enum 

{

  PAN_ANY = 0x00,

  PAN_NO_FIT = 0x01,

  PAN_XHEIGHT_CONSTANT_SMALL = 0x02,

  PAN_XHEIGHT_CONSTANT_STD = 0x03,

  PAN_XHEIGHT_CONSTANT_LARGE = 0x04,

  PAN_XHEIGHT_DUCKING_SMALL = 0x05,

  PAN_XHEIGHT_DUCKING_STD = 0x06,

  PAN_XHEIGHT_DUCKING_LARGE = 0x07

} XHeight;

**PAN_ANY: **Any.

**PAN_NO_FIT: **No fit.

**PAN_XHEIGHT_CONSTANT_SMALL: **Constant/small.

**PAN_XHEIGHT_CONSTANT_STD: **Constant/standard.

**PAN_XHEIGHT_CONSTANT_LARGE: **Constant/large.

**PAN_XHEIGHT_DUCKING_SMALL: ****Ducking**/small

**PAN_XHEIGHT_DUCKING_STD: **Ducking/standard.

**PAN_XHEIGHT_DUCKING_LARGE: **Ducking/large.

## EMF Objects

### BitFIX28_4 Object

The BitFIX28_4 object defines a numeric value in **28.4 bit FIX notation**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| IntValue | FracValue |

**IntValue (28 bits): **The signed, integral part of the number.

**FracValue (4 bits): **The unsigned fractional part of the number, in units of one-sixteenth.

The real number represented by this object is computed as follows:

IntValue + (FracValue / 16)

### ColorAdjustment Object

The ColorAdjustment object defines values for adjusting the colors in source **bitmaps** in bit-block transfers.<42>

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Size | Values |
| IlluminantIndex | RedGamma |
| GreenGamma | BlueGamma |
| ReferenceBlack | ReferenceWhite |
| Contrast | Brightness |
| Colorfulness | RedGreenTint |

**Size (2 bytes): **An unsigned integer that specifies the size in bytes of this object. This value is 0x0018.

**Values (2 bytes): **An unsigned integer that specifies how to prepare the output image. This field can be set to NULL or to any combination of values in the ColorAdjustment enumeration (section 2.1.5).

**IlluminantIndex (2 bytes): **An unsigned integer that specifies the type of standard light source under which the image is viewed, from the Illuminant enumeration (section 2.1.19).

**RedGamma (2 b****ytes): **An unsigned integer that specifies the nth power **gamma correction** value for the red primary of the source colors. This value SHOULD be in the range from 2,500 to 65,000.<43> A value of 10,000 means gamma correction MUST NOT be performed.

**GreenGamma (2 bytes): **An unsigned integer that specifies the nth power gamma correction value for the green primary of the source colors. This value SHOULD be in the range from 2,500 to 65,000. A value of 10,000 means gamma correction MUST NOT be performed.

**BlueGamma (2 bytes): **An unsigned integer that specifies the nth power gamma correction value for the blue primary of the source colors. This value SHOULD be in the range from 2,500 to 65,000. A value of 10,000 means gamma correction MUST NOT be performed.

**ReferenceBlack (2 bytes): **An unsigned integer that specifies the black reference for the source colors. Any colors that are darker than this are treated as black. This value SHOULD be in the range from zero to 4,000.

**ReferenceWhite (2 bytes): **An unsigned integer that specifies the white reference for the source colors. Any colors that are lighter than this are treated as white. This value SHOULD be in the range from 6,000 to 10,000.

**Contrast (2 bytes): **A signed integer that specifies the amount of **contrast** to be applied to the source object. This value SHOULD be in the range from –100 to 100. A value of zero means contrast adjustment MUST NOT be performed.

**Brightness (2 bytes): **A signed integer that specifies the amount of **brightness** to be applied to the source object. This value SHOULD be in the range from –100 to 100. A value of zero means brightness adjustment MUST NOT be performed.

**Colorfulness (2 bytes): **A signed integer that specifies the amount of **colorfulness** to be applied to the source object. This value SHOULD be in the range from –100 to 100. A value of zero means colorfulness adjustment MUST NOT be performed.

**RedGreenTint (2 bytes): **A signed integer that specifies the amount of red or green **tint** adjustment to be applied to the source object. This value SHOULD be in the range from –100 to 100. Positive numbers adjust towards red and negative numbers adjust towards green. A value of zero means tint adjustment MUST NOT be performed.

The ColorAdjustment object is used in bit-block transfers performed by EMR_STRETCHBLT and EMR_STRETCHDIBITS records when the StretchMode enumeration (section 2.1.32) value is **STRETCH_HALFTONE**. The color adjustment values can apply a color filter or lighten or darken an image.

An EMR_SETCOLORADJUSTMENT record (section 2.3.11.13) sets the current ColorAdjustment object in the **playback device context**. That ColorAdjustment object affects all subsequent EMR_STRETCHBLT and EMR_STRETCHDIBITS records until a different ColorAdjustment object is specified by another EMR_SETCOLORADJUSTMENT record, or until the object is removed by a EMR_DELETEOBJECT record.

### DesignVector Object

The DesignVector (section 2.2.3) object defines the **design vector**, which specifies values for the **font axes** of a **multiple master** font.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Signature |
| NumAxes |
| Values (variable, optional) |
| ... |

**Signature (4 bytes): **An unsigned integer that MUST be set to the value 0x08007664.

**NumAxes (4 bytes): **An unsigned integer that specifies the number of elements in the **Values** array. It MUST be in the range 0 to 16, inclusive.

**Values (variable, optional): **An array of 32-bit signed integers that specify the values of the font axes of a multiple master, **OpenType** font. The maximum number of values in the array is 16.

### EmrFormat Object

The EmrFormat object contains information that identifies the format of image data in an EMR_COMMENT_MULTIFORMATS record (section 2.3.3.4.3).

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Signature |
| Version |
| SizeData |
| offData |

**Signature (4 bytes): **An unsigned integer that specifies the format of the image data. This value is in the FormatSignature enumeration (section 2.1.14).

**Version (4 bytes): **An unsigned integer that specifies the format version number. If the **Signature** field specifies **encapsulated PostScript (EPS)**, this value is 0x00000001; otherwise, this value is ignored.

**SizeData (4 bytes): **An unsigned integer that specifies the size of the data in bytes.

**offData (4 bytes): **An unsigned integer that specifies the offset to the data from the start of the **identifier** field in an EMR_COMMENT_PUBLIC record (section 2.3.3.4). The offset MUST be 32-bit aligned.

### EmrText Object

The **EmrText** object contains values for text output.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Reference |
| ... |
| Chars |
| offString |
| Options |
| Rectangle (optional) |
| ... |
| ... |
| ... |
| offDx |
| StringBuffer (variable) |
| ... |
| ... |
| ... |
| DxBuffer (variable, optional) |
| ... |
| ... |
| ... |

**Reference (8 bytes): **A PointL object ([MS-WMF] section 2.2.2.15) that specifies the coordinates of the reference point used to position the string. The reference point is defined by the last EMR_SETTEXTALIGN record (section 2.3.11.25). If no such record has been set, the default alignment is (TA_LEFT, TA_TOP), which is specified using TextAlignmentMode flags ([MS-WMF] section 2.1.2.3).

**Chars (4 bytes): **An unsigned integer that specifies the number of characters in the string.

**offString (4 bytes): **An unsigned integer that specifies the offset to the output string in bytes, from the start of the record in which this object is contained. This value is 8- or 16-bit aligned, according to the character format.

**Options (4 bytes): **An unsigned integer that specifies how to use the rectangle specified in the **Rectangle** field. This field can be a combination of more than one ExtTextOutOptions enumeration (section 2.1.11) values.

**Rectangle (16 bytes, optional): **A RectL object ([MS-WMF] section 2.2.2.19) that defines a clipping and/or opaquing rectangle in logical units. This rectangle is applied to the text output performed by the containing record.<44>

**offDx (4 bytes): **An unsigned integer that specifies the offset to an intercharacter spacing array in bytes, from the start of the record in which this object is contained. This value is 32-bit aligned.

**StringBuffer (variable): **The character string buffer.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UndefinedSpace1 (variable, optional) |
| ... |
| OutputString (variable) |
| ... |

**UndefinedSpace1 (variable, optional): **The number of unused bytes. The **OutputString** field is not required to follow immediately the preceding portion of this structure.

**OutputString (variable): **An array of characters that specify the string to output. The location of this field is specified by the value of **offString** in bytes from the start of this record. The number of characters is specified by the value of **Chars**.

**DxBuffer (variable, optional): **The character spacing buffer.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UndefinedSpace2 (variable, optional) |
| ... |
| OutputDx (variable) |
| ... |

**UndefinedSpace2 (variable, optional): **The number of unused bytes. The **OutputDx** field is not required to follow immediately the preceding portion of this structure.

**OutputDx (variable): **An array of 32-bit unsigned integers that specify the output spacing between the origins of adjacent character cells in logical units. The location of this field is specified by the value of **offDx** in bytes from the start of this record. If spacing is defined, this field contains the same number of values as characters in the output string.

If the Options field of the EmrText object contains the ETO_PDY flag, then this buffer contains twice as many values as there are characters in the output string, one horizontal and one vertical offset for each, in that order.

If ETO_RTLREADING is specified, characters are laid right to left instead of left to right. No other options affect the interpretation of this field.

The size and encoding of the characters in the **OutputString** is determined by the type of record that contains this object, as follows:

EMR_EXTTEXTOUTA (section 2.3.5.7) and EMR_POLYTEXTOUTA (section 2.3.5.32) records: 8-bit **ASCII** characters.

EMR_EXTTEXTOUTW (section 2.3.5.8) and EMR_POLYTEXTOUTW (section 2.3.5.33) records: 16-bit **Unicode** **UTF16-LE** characters.

### EpsData Object

The EpsData object is a container for **EPS** data.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SizeData |
| Version |
| Points (24 bytes) |
| ... |
| ... |
| ... |
| PostScriptData (variable) |
| ... |

**SizeData (4 bytes): **An unsigned integer that specifies the total size of this object in bytes.

**Version (4 bytes): **An unsigned integer that specifies the **PostScript** language level. This value is 0x00000001.

**Points (24 bytes): **An array of three Point28_4 objects (section 2.2.23) that defines the coordinates of the output parallelogram using **28.4 bit FIX notation**.

The upper-left corner of the parallelogram is the first point in this array, the upper-right corner is the second point, and the lower-left corner is the third point. The lower-right corner of the parallelogram is computed from the first three points (A, B, and C) by treating them as vectors.

D = B + C A

**PostScrip****tData (variable): **An array of bytes of PostScript data. The length of this array can be computed from the **SizeData** field. This data MAY be used to render an image.<45>

An EpsData object can be used to embed a PostScript image in an **EMF** **metafile** as follows:

An EMF metafile contains an EMR_COMMENT_MULTIFORMATS record (section 2.3.3.4.3).

The EMR_COMMENT_MULTIFORMATS record specifies an **aFormats** field that contains an EmrFormat object (section 2.2.4).

The EmrFormat object specifies a **Signature** field that is set to **EPS_SIGNATURE** from the FormatSignature enumeration (section 2.1.14).

The **EPS_SIGNATURE** value specifies that the **FormatData** field in the EMR_COMMENT_MULTIFORMATS record contains an EpsData object.

The EmrFormat object also specifies an **offData** field that indicates where the EpsData object is in the **FormatData** field in the EMR_COMMENT_MULTIFORMATS record.

### GradientRectangle Object

The GradientRectangle object defines a rectangle using TriVertex objects (section 2.2.26) in an EMR_GRADIENTFILL record (section 2.3.5.12).

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UpperLeft |
| LowerRight |

**UpperLeft (4 bytes): **An index into an array of TriVertex objects that specifies the upper-left vertex of a rectangle. The index MUST be smaller than the size of the array, as defined by the **nVer** field of the EMR_GRADIENTFILL record.

**LowerRight (4 bytes): **An index into an array of TriVertex objects that specifies the lower-right vertex of a rectangle. The index MUST be smaller than the size of the array, as defined by the **nVer** field of the EMR_GRADIENTFILL record.

### GradientTriangle Object

The GradientTriangle object defines a triangle using TriVertex objects (section 2.2.26) in an EMR_GRADIENTFILL record (section 2.3.5.12).

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Vertex1 |
| Vertex2 |
| Vertex3 |

**Vertex1 (4 bytes): **An index into an array of TriVertex objects that specifies a vertex of a triangle. The index MUST be smaller than the size of the array, as defined by the **nVer** field of the EMR_GRADIENTFILL record.

**Vertex2 (4 bytes): **An index into an array of TriVertex objects that specifies a vertex of a triangle. The index MUST be smaller than the size of the array, as defined by the **nVer** field of the EMR_GRADIENTFILL record.

**Vertex3 (4 bytes): **An index into an array of TriVertex objects that specifies a vertex of a triangle. The index MUST be smaller than the size of the array, as defined by the **nVer** field of the EMR_GRADIENTFILL record.

### Header Object

The Header object defines the **EMF** **metafile** header. It specifies properties of the device on which the image in the metafile was created. 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Bounds |
| ... |
| ... |
| ... |
| Frame |
| ... |
| ... |
| ... |
| RecordSignature |
| Version |
| Bytes |
| Records |
| Handles | Reserved |
| nDescription |
| offDescription |
| nPalEntries |
| Device |
| ... |
| Millimeters |
| ... |

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the rectangular **inclusive-inclusive** bounds in logical units of the smallest rectangle that can be drawn around the image stored in the metafile.

**Frame (****16 bytes): **A RectL object that specifies the rectangular inclusive-inclusive dimensions, in .01 millimeter units, of a rectangle that surrounds the image stored in the metafile.

**RecordSignature (4 bytes): **An unsigned integer that specifies the record signature. This MUST be **ENHMETA_SIGNATURE**, from the FormatSignature enumeration (section 2.1.14).

**Version (4 bytes): **An unsigned integer that specifies the EMF version for interoperability. This MAY be 0x00010000.

**Bytes (4 bytes): **An unsigned integer that specifies the size of the metafile in bytes.

**Records (4 bytes): **An unsigned integer that specifies the number of records in the metafile.

**Handles (2 bytes): **An unsigned integer that specifies the number of graphics objects that are used during the processing of the metafile.

**Reserved (2 bytes): **An unsigned integer that MUST be 0x0000 and MUST be ignored.

**nDescription (4 bytes): **An unsigned integer that specifies the number of characters in the array that contains the description of the metafile's contents. This is zero if there is no description string.

**offDescription (4 bytes): **An unsigned integer that specifies the offset from the beginning of this record to the array that contains the description of the metafile's contents.

**nPalEntries (4 bytes): **An unsigned integer that specifies the number of entries in the metafile **palette**. The palette is located in the EMR_EOF record.

**Device (8 bytes): **A SizeL object ([MS-WMF] section 2.2.2.22) that specifies the size of the reference device, in pixels.

**Millimeters (8 bytes): **A SizeL object that specifies the size of the reference device, in millimeters.

### HeaderExtension1 Object

The HeaderExtension1 object defines the first extension to the **EMF** **metafile** header. It adds support for a PixelFormatDescriptor object (section 2.2.22) and **OpenGL** [OPENGL] records (section 2.3.9). 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cbPixelFormat |
| offPixelFormat |
| bOpenGL |

**cbPixelFormat (4 bytes): **An unsigned integer that specifies the size of the PixelFormatDescriptor object. This value is 0x00000000 if no pixel format is set.

**offPixelFormat (4 bytes): **An unsigned integer that specifies the offset to the PixelFormatDescriptor object. This value is 0x00000000 if no pixel format is set.

**bOpenGL (4 bytes): **An unsigned integer that indicates whether OpenGL commands are present in the metafile.

| Value | Meaning |
| --- | --- |
| 0x00000000 | OpenGL records are not present in the metafile. |
| 0x00000001 | OpenGL records are present in the metafile. |

### HeaderExtension2 Object

The HeaderExtension2 object defines the second extension to the **EMF** **metafile** header. It adds the ability to measure device surfaces in micrometers, which enhances the resolution and scalability of EMF metafiles.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| MicrometersX |
| MicrometersY |

**MicrometersX (4 bytes): **The 32-bit horizontal size of the display device for which the metafile image was generated, in micrometers.

**MicrometersY (4 bytes): **The 32-bit vertical size of the display device for which the metafile image was generated, in micrometers.

### LogBrushEx Object

The **LogBrushEx** object defines the style, color, and pattern of a device-independent brush.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BrushStyle |
| Color |
| BrushHatch |

**BrushStyle (4 bytes): **An unsigned integer that specifies the brush style. The value MUST be an enumeration from BrushStyle enumeration ([MS-WMF] section 2.1.1.4). The style values that are supported in this structure are listed later in this section. The BS_NULL style SHOULD be used to specify a brush that has no effect.

**Color (4 bytes): **A 32-bit ColorRef object ([MS-WMF] section 2.2.2.8) that specifies a color. The interpretation of this field depends on the value of **BrushStyle**, as explained in the following table. 

**BrushHatch (4 bytes): **A 32-bit unsigned field that contains the brush hatch data. Its interpretation depends on the value of **BrushStyle**, as explained in the following table.

The following table shows the relationship between the **BrushStyle**, **Color**, and **BrushHatch** fields in a LogBrushEx object. Only supported brush styles are listed.

| BrushStyle | Color | BrushHatch |
| --- | --- | --- |
| **BS_SOLID** | A ColorRef object, which specifies the color of the brush. | Not used and SHOULD be ignored. |
| **BS_NULL** | Not used and SHOULD be ignored. | Not used and SHOULD be ignored. |
| **BS_HATCHED** | A ColorRef object, which specifies the foreground color of the hatch pattern. | A value from the HatchStyle enumeration (section 2.1.17), which specifies the orientation of lines used to create the hatch. |

### LogFont Object

The LogFont object specifies the basic attributes of a logical font.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Height |
| Width |
| Escapement |
| Orientation |
| Weight |
| Italic | Underline | StrikeOut | CharSet |
| OutPrecision | ClipPrecision | Quality | PitchAndFamily |
| Facename (64 bytes) |
| ... |
| ... |
| ... |

**Height (4 bytes): **A signed integer that specifies the height of the font's character cell in logical units. The character height value, also known as the **em size**, is the character **cell height** value minus the **internal leading** value. The **font mapper** SHOULD interpret the value specified in the **Height** field in the following manner.

| Value | Meaning |
| --- | --- |
| 0x00000000 < *value* | The font mapper transforms this value into device units and matches it against the cell height of the available fonts. |
| 0x00000000 | The font mapper uses a default height value when it searches for a match. |
| *value* < 0x00000000 | The font mapper transforms this value into device units and matches its absolute value against the character height of the available fonts. |

For all height comparisons, the font mapper SHOULD look for the largest font that does not exceed the requested size.

**Width (4 bytes): **A signed integer that specifies the average width of characters in the font in logical units. If the **Width** field value is zero, an appropriate value SHOULD<46> be calculated from other values in this object to find a font that has the typographer's intended **aspect ratio**.

**Escapement (4 bytes): **A signed integer that specifies the angle, in tenths of degrees, between the escapement vector and the x-axis of the device. The escapement vector is parallel to the **baseli****ne** of a row of text.

When the graphics mode is set to **GM_ADVANCED**, the escapement angle of the string can be specified independently of the orientation angle of the string's characters. Graphics modes are specified in section 2.1.16

**Orientation (4 bytes): **A signed integer that specifies the angle, in tenths of degrees, between each character's baseline and the x-axis of the device.

**Weight (4 bytes): **A signed integer that specifies the **weight** of the font in the range zero through 1000. For example, 400 is normal and 700 is bold. If this value is zero, a default weight can be used.<47>

**Italic (1 byte): **An unsigned integer that specifies an italic font if set to 0x01; otherwise, it MUST be set to 0x00.

**Underline (1 byte): **An unsigned integer that specifies an underlined font if set to 0x01; otherwise, it MUST be set to 0x00.

**StrikeOut (1 byte): **An unsigned integer that specifies a strikeout font if set to 0x01; otherwise, it MUST be set to 0x00.

**CharSet (1 byte): **An unsigned integer that specifies the set of character glyphs. It MUST be a value in the CharacterSet enumeration ([MS-WMF] section 2.1.1.5). If the character set is unknown, **metafile** processing SHOULD NOT attempt to translate or interpret strings that are rendered with that font.

If a **typeface** name is specified in the **Facename** field, the **CharSet** field value MUST match the character set of that typeface.

**OutPrec****ision (1 byte): **An unsigned integer that specifies the output precision. The output precision defines how closely the font is required to match the requested height, width, character orientation, escapement, **pitch**, and font type. It MUST be a value from the OutPrecision enumeration ([MS-WMF] section 2.1.1.21).

Applications can use the output precision to control how the font mapper chooses a font when the operating system contains more than one font with a specified name. For example, if an operating system contains a font named **Symbol** in **rasterized** and **TrueType** forms, an output precision value of **OUT_TT_PRECIS** forces the font mapper to choose the TrueType version. A value of **OUT_TT_ONLY_PRECIS** forces the font mapper to choose a TrueType font, even if it is necessary to substitute a TrueType font with another name.

**ClipPrecisi****on (1 byte): **An unsigned integer that specifies the clipping precision. The clipping precision defines how to clip characters that are partially outside the clipping **region**. It can be one or more of the ClipPrecision Flags ([MS-WMF] section 2.1.2.1).

**Quality (1 byte): **An unsigned integer that specifies the output quality. The output quality defines how closely to attempt to match the logical-font attributes to those of an actual physical font. It MUST be one of the values in the FontQuality enumeration ([MS-WMF] section 2.1.1.10).

**PitchAndFamily (1 byte): **A PitchAndFamily object ([MS-WMF] section 2.2.2.14) that specifies the pitch and family of the font. Font families describe the look of a font in a general way. They are intended for specifying a font when the specified typeface is not available.

**Facename (64 bytes): **A string of no more than 32 **Unicode** characters that specifies the typeface name of the font. If the length of this string is less than 32 characters, a terminating NULL MUST be present, after which the remainder of this field MUST be ignored.

### LogFontEx Object

The LogFontEx object specifies the extended attributes of a logical font.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| LogFont (92 bytes) |
| ... |
| ... |
| ... |
| FullName (128 bytes) |
| ... |
| ... |
| ... |
| Style (64 bytes) |
| ... |
| ... |
| ... |
| Script (64 bytes) |
| ... |
| ... |
| ... |

**LogFont (92 bytes): **A LogFont (section 2.2.13) object that specifies the basic attributes of the logical font.

**FullName (128 bytes): **A string of 64 **Unicode** characters that contains the font's full name. If the length of this string is less than 64 characters, a terminating NULL MUST be present, after which the remainder of this field MUST be ignored.

**Sty****le (64 bytes): **A string of 32 Unicode characters that defines the font's style. If the length of this string is less than 32 characters, a terminating NULL MUST be present, after which the remainder of this field MUST be ignored.

**Script (64 bytes): **A string of 32 Unicode characters that defines the character set of the font. If the length of this string is less than 32 characters, a terminating NULL MUST be present, after which the remainder of this field MUST be ignored.

### LogFontExDv Object

The LogFontExDv object specifies the **design vector** for an extended logical font.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| LogFontEx (348 bytes) |
| ... |
| ... |
| ... |
| DesignVector (variable) |
| ... |

**LogFontEx (348 bytes): **A LogFontEx object (section 2.2.14) that specifies the extended attributes of the logical font.

**DesignVec****tor (variable): **A DesignVector object (section 2.2.3). This field MUST NOT be longer than 72 bytes.

A design vector SHOULD be specified only for a **multiple master** **OpenType** font.

### LogFontPanose Object

The LogFontPanose object specifies the **PANOSE** characteristics of a logical font.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| LogFont (92 bytes) |
| ... |
| ... |
| ... |
| FullName (128 bytes) |
| ... |
| ... |
| ... |
| Style (64 bytes) |
| ... |
| ... |
| ... |
| Version |
| StyleSize |
| Match |
| Reserved |
| VendorId |
| Culture |
| Panose |
| ... |
| ... | Padding |

**LogFont (92 bytes): **A LogFont (section 2.2.13) object that specifies the basic attributes of the logical font.

**FullName (128 bytes): **A string of 64 **Unicode** characters that defines the font's full name. If the length of this string is less than 64 characters, a terminating NULL MUST be present, after which the remainder of this field MUST be ignored.

**Style (64 bytes): **A string of 32 Unicode characters that defines the font's style. If the length of this string is less than 32 characters, a terminating NULL MUST be present, after which the remainder of this field MUST be ignored.

**Version (4 bytes): **This field MUST be ignored.

**StyleSize (4 bytes): **An unsigned integer that specifies the point size at which **font hinting** is performed. If set to zero, font hinting is performed at the point size corresponding to the **Height** field in the LogFont object in the **LogFont** field.

**Match (4 bytes): **This field MUST be ignored.

**Reserved (4 bytes): **An unsigned integer that MUST be set to zero and MUST be ignored.

**Ven****dorId (4 bytes): **This field MUST be ignored.

**Culture (4 bytes): **An unsigned integer that MUST be set to zero and MUST be ignored.

**Panose (10 bytes): **A Panose object (section 2.2.21) that specifies the PANOSE characteristics of the logical font. If all fields of this object are zero, it MUST be ignored.

**Padding (2 bytes): **A field that exists only to ensure 32-bit alignment of this structure. It MUST be ignored.

### LogPalette Object

The **LogPalette** object specifies a **logical_palette** that contains device-independent color definitions.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Version | NumberOfEntries |
| PaletteEntries (variable) |
| ... |

**Version (2 bytes): **An unsigned integer that specifies the version number of the system. This value is 0x0300.

**NumberOfEntries (2 bytes): **An unsigned integer that specifies the number of entries in the **PaletteEntries** field.

**PaletteEntries (variable): **An array of LogPaletteEntry objects (section 2.2.18) that defines the color and usage of each entry in the logical_palette.

**EMF** MUST define colors as device-independent values because the **metafile** itself is device-independent.

### LogPaletteEntry Object

The **LogPaletteEntry** object defines the values that make up a single entry in a LogPalette object (section 2.2.17).

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Reserved | Blue | Green | Red |

**Reserved (1 byte): **An unsigned integer that MUST NOT be used and MUST be ignored.

**Blue (1 byte): **An unsigned integer that defines the blue **intensity** value for the entry.

**Green (1 byte): **An unsigned integer that defines the green intensity value for the entry.

**Red (1 byte): **An unsigned integer that defines the red intensity value for the entry.

**EMF** MUST define colors as device-independent values because the **metafile** itself is device-independent.

### LogPen Object

The **LogPen** object defines the style, width, and color of a logical pen.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PenStyle |
| Width |
| ... |
| ColorRef |

**PenStyle (4 bytes): **An unsigned integer that specifies a value from the PenStyle enumeration (section 2.1.25).

**Width (8 bytes): **A PointL object ([MS-WMF] section 2.2.2.15) that specifies the width of the pen by the value of its **x** field. The value of its **y** field MUST be ignored.

If the pen type in the **PenStyle** field is PS_GEOMETRIC, this value is the width in logical units; otherwise, the width is specified in device units. If the pen type in the **PenStyle** field is PS_COSMETIC, this value MUST be 0x00000001.

**ColorRef (4 bytes): **A **ColorRef** object ([MS-WMF] section 2.2.2.8) that specifies the pen color value.

### LogPenEx Object

The **LogPenEx** object specifies the style, width, and color of an extended logical pen.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PenStyle |
| Width |
| BrushStyle |
| ColorRef |
| BrushHatch |
| NumStyleEntries |
| StyleEntry (variable, optional) |
| ... |

**PenStyle (4 bytes): **An unsigned integer that specifies the pen style. This value is defined from the PenStyle enumeration (section 2.1.25).

The pen style is a combination of pen type, line style, **line cap**, and **line join**.

**Width (4 bytes): **An unsigned integer that specifies the width of the line drawn by the pen.

If the pen type in the **PenStyle** field is PS_GEOMETRIC, this value is the width in logical units; otherwise, the width is specified in device units. If the pen type in the **PenStyle** field is PS_COSMETIC, this value MUST be 0x00000001.

**BrushStyle (4 bytes): **An unsigned integer that specifies a brush style for the pen from the BrushStyle enumeration ([MS-WMF] section 2.1.1.4). 

If the pen type in the **PenStyle** field is PS_GEOMETRIC, this value is either BS_SOLID or BS_HATCHED. The value of this field can be BS_NULL, but only if the line style specified in **PenStyle** is PS_NULL. The BS_NULL style SHOULD be used to specify a brush that has no effect.

**ColorRef (4 bytes): **A ColorRef object ([MS-WMF] section 2.2.2.8). The interpretation of this field depends on the **BrushStyle** value, as shown in the table later in this section.

**BrushHatch (4 bytes): **The brush hatch pattern. The definition of this field depends on the **BrushStyle** value, as shown in the table later in this section.

**NumStyleEntries (4 bytes): **The number of elements in the array specified in the **StyleEntry** field. This value SHOULD be zero if **PenStyle** does not specify PS_USERSTYLE.

**StyleEntry (v****ariable, optional): **An array of 32-bit unsigned integers that defines the lengths of dashes and gaps in the line drawn by this pen when the value of **PenStyle** is PS_USERSTYLE. The array contains the number of entries specified by **NumStyleEntries**, but it is used as if it repeated indefinitely.

The first entry in the **StyleEntry **array specifies the length of the first dash. The second entry specifies the length of the first gap. Thereafter, lengths of dashes and gaps alternate.

If the pen type in the **PenStyle** field is PS_GEOMETRIC, lengths are specified in logical units; otherwise, they are specified in device units.

The LogPenEx object includes the specification of brush attributes, so it can be used to draw lines that consist of custom or predefined patterns. The following table shows the relationship between the **BrushStyle**, **ColorRef**, and **BrushHatch** fields in this object. Only supported brush styles are listed.

| BrushStyle | ColorRef | BrushHatch |
| --- | --- | --- |
| **BS_SOLID** | A ColorRef object that specifies the color of lines drawn by the pen. | Not used and is ignored. |
| **BS_NULL** | Not used and is ignored. | Not used and is ignored. |
| **BS_HATCHED** | A ColorRef object that specifies the foreground color of the hatch pattern. | A value from the HatchStyle enumeration (section 2.1.17) that specifies the orientation of lines used to create the hatch. If **PS_GEOMETRIC** is not set in the **PenStyle** field, this field MUST be either **HS_SOLIDTEXTCLR (0x0008)** or **HS_SOLIDBKCLR (0x000A)**. |
| **BS_PATTERN** | The low-order 16-bits is a value from the ColorUsage enumeration ([MS-WMF] section 2.1.1.6). | Not used and is ignored. |
| **BS_DIBPATTERN** | The low-order 16 bits is a value from the ColorUsage enumeration. | Not used and is ignored. |
| **BS_DIBPATTERNPT** | The low-order word is be a value from the ColorUsage enumeration. | Not used and is ignored. |

### Panose Object

The Panose object describes the PANOSE font-classification values for a TrueType font. These characteristics are used to associate the font with other fonts of similar appearance but different names.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FamilyType | SerifStyle | Weight | Proportion |
| Contrast | StrokeVariation | ArmStyle | Letterform |
| Midline | XHeight |

**FamilyType (1 byte): **An unsigned integer that specifies the family type. This value is in the FamilyType (section 2.1.12) enumeration table.

**SerifStyle (1 byte): **An unsigned integer that specifies the serif style. This value is in the SerifType (section 2.1.30) enumeration table.

**Weight (1 byte): **An unsigned integer that specifies the **weight** of the font. This value is in the Weight (section 2.1.34) enumeration table.

**Proportion (1 byte): **An unsigned integer that specifies the proportion of the font. This value is in the Proportion (section 2.1.28) enumeration table.

**Contrast (1 byte): **An unsigned integer that specifies the contrast of the font. This value is in the Contrast (section 2.1.8) enumeration table.

**StrokeVariation (1 byte): **An unsigned integer that specifies the stroke variation for the font. This value is in the StrokeVariation (section 2.1.33) enumeration table.

**ArmStyle (1 byte): **An unsigned integer that specifies the arm style of the font. This value is in the ArmStyle (section 2.1.3) enumeration table.

**Letterform (1 byte): **An unsigned integer that specifies the letterform of the font. This value is in the Letterform (section 2.1.20) enumeration table.

**Midline (1 byte): **An unsigned integer that specifies the midline of the font. This value is in the MidLine (section 2.1.23) enumeration table.

**XHeight (1 byte): **An unsigned integer that specifies the x height of the font. This value is in the XHeight (section 2.1.35) enumeration table.

### PixelFormatDescriptor Object

The **PixelFormatDescriptor** object specifies the pixel format of a drawing surface.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| nSize | nVersion |
| dwFlags |
| iPixelType | cColorBits | cRedBits | cRedShift |
| cGreenBits | cGreenShift | cBlueBits | cBlueShift |
| cAlphaBits | cAlphaShift | cAccumBits | cAccumRedBits |
| cAccumGreenBits | cAccumBlueBits | cAccumAlphaBits | cDepthBits |
| cStencilBits | cAuxBuffers | iLayerType | bReserved |
| dwLayerMask |
| dwVisibleMask |
| dwDamageMask |

**nSize (2 bytes): **An unsigned integer that specifies the size in bytes, of this data structure.

**nVersion (2 bytes): **An unsigned integer that MUST be set to 0x0001.

**dwFlags (4 bytes): **A set of bit flags that specify properties of the pixel buffer that is used for output to the drawing surface. These properties are not all mutually exclusive; combinations of flags are allowed, except where noted otherwise.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| P | F | S O | G | M | W | S | D | C | D A | D S | A | S L | S C | S E | S P | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | S D | D D | D P | 0 |

The following bit flag constants are defined.

| Value | Description |
| --- | --- |
| DPFD_DOUBLEBUFFER | The pixel buffer is double-buffered. This flag and **PFD_SUPPORT_GDI** MUST NOT both be set. |
| SPFD_STEREO | The pixel buffer MAY be **stereoscopic**; that is, it MAY specify a **color plane** that is used to create the illusion of depth in an image.<48> |
| WPFD_DRAW_TO_WINDOW | The pixel buffer can draw to a window or device surface. |
| MPFD_DRAW_TO_BITMAP | The pixel buffer can draw to a memory **bitmap**. |
| GPFD_SUPPORT_GDI | This flag SHOULD be clear, but it MAY be set. <49> The **PFD_SUPPORT_GDI** flag and **PFD_DOUBLEBUFFER** MUST NOT both be set. |
| SOPFD_SUPPORT_OPENGL | The pixel buffer supports **OpenGL** [OPENGL] drawing. |
| FPFD_GENERIC_FORMAT | The pixel format is natively supported by the operating system; this is known as the "generic" implementation.<50> If clear, the pixel format is supported by a device driver or hardware. |
| PPFD_NEED_PALETTE | The buffer uses **RGBA** pixels on a palette-managed device. A LogPalette object (section 2.2.17) is required to achieve the best results for this pixel type. Colors in the **palette** SHOULD be specified according to the values of the **cRedBits**, **cRedShift**, **cGreenBits**, **cGreenShift**, **cBlueBits**, and **cBlueShift** fields. |
| SPPFD_NEED_SYSTEM_PALETTE | The output device supports one hardware palette in 256-color mode only. For such systems to use hardware acceleration, the hardware palette MUST be in a fixed order (for example, 3-3-2) when in RGBA mode, or MUST match the LogPalette object when in **color table** mode. |
| SEPFD_SWAP_EXCHANGE | The contents of the back buffer have been exchanged with the contents of the front buffer in a double-buffered color plane. |
| SCPFD_SWAP_COPY | The contents of the back buffer have been copied to the front buffer in a double-buffered color plane. The contents of the back buffer have not been affected. |
| SLPFD_SWAP_LAYER_BUFFERS | A device can swap individual color planes with pixel formats that include double-buffered overlay or underlay color planes. Otherwise all color planes are swapped together as a group. |
| APFD_GENERIC_ACCELERATED | The pixel format is supported by a device driver that accelerates the generic implementation. If this flag is clear and the **PFD_GENERIC_FORMAT** flag is set, the pixel format is supported by the generic implementation only. |
| DSPFD_SUPPORT_DIRECTDRAW | The pixel buffer supports DirectDraw drawing, which allows applications to have low-level control of the output drawing surface. |
| DAPFD_DIRECT3D_ACCELERATED | The pixel buffer supports Direct3D drawing, which accellerated rendering in three dimensions. |
| CPFD_SUPPORT_COMPOSITION | The pixel buffer supports **compositing**, which indicates that source pixels MAY overwrite or be combined with background pixels.<51> |
| DPPFD_DEPTH_DONTCARE | The pixel buffer is not required to include a color plane for depth effects. |
| DDPFD_DOUBLEBUFFER_DONTCARE | The pixel buffer can be either single or double buffered. |
| SDPFD_STEREO_DONTCARE | The pixel buffer MAY be either **monoscopic** or stereoscopic. |

**iPixelType (1 byte): **The type of pixel data.

| Value | Meaning |
| --- | --- |
| PFD_TYPE_RGBA0x00 | The pixel format is RGBA. |
| PFD_TYPE_COLORINDEX0x01 | Each pixel is an index in a color table. |

**cColorBits (1 byte): **The number of bits per pixel for RGBA pixel types, excluding the **alpha** bitplanes. For color table pixels, it is the size of each color table index.

**cRedBits (1 byte): **Specifies the number of red bitplanes in each RGBA color buffer.

**cRedShift (1 byte): **Specifies the shift count in bits for red bitplanes in each RGBA color buffer.

**cGreenBits (1 byte): **Specifies the number of green bitplanes in each RGBA color buffer.

**cGreenShift (1 byte): **Specifies the shift count for green bitplanes in each RGBA color buffer.

**cBlueBits (1 byte): **Specifies the number of blue bitplanes in each RGBA color buffer.

**cBlueShift (1 byte): **Specifies the shift count for blue bitplanes in each RGBA color buffer.

**cAlphaBits (1 byte): **Specifies the number of alpha bitplanes in each RGBA color buffer.<52>

**cAlphaShift (1 byte): **Specifies the shift count for alpha bitplanes in each RGBA color buffer.<53>

**cAccumBits (1 byte): **Specifies the total number of bitplanes in the accumulation buffer.

**cAccumRedBits (1 byte): **Specifies the number of red bitplanes in the accumulation buffer.

**cAccumGreenBits (1 byte): **Specifies the number of green bitplanes in the accumulation buffer.

**cAccumBlueBits (1 byte): **Specifies the number of blue bitplanes in the accumulation buffer.

**cAccumAlphaBits (1 byte): **Specifies the number of alpha bitplanes in the accumulation buffer.<54>

**cDepthBits (1 byte): **Specifies the depth of the depth (z-axis) buffer.

**cStencilBits (1 byte): **Specifies the depth of the stencil buffer.

**cAuxBuffers (1 byte): **Specifies the number of auxiliary buffers. Auxiliary buffers are not supported.

**iLayerType (1 byte): **This field MAY be ignored.

**bReserved (1 byte): **Specifies the number of overlay and underlay planes. Bits 0 through 3 specify up to 15 overlay planes and bits 4 through 7 specify up to 15 underlay planes.

**dwLayerMask (4 bytes): **This field MAY be ignored.

**dwVisibleMask (4 bytes): **Specifies the transparent color or index of an underlay plane. When the pixel type is RGBA, **dwVisibleMask** is a transparent **RGB** color value. When the pixel type is color index, it is a transparent index value.

**dwDamageMask (4 bytes): **This field SHOULD be ignored.

The PixelFormatDescriptor object is used in EMR_HEADER records (section 2.3.4.2) to specify the pixel format of the output surface.

### Point28_4 Object

The Point28_4 object represents the location of a point on a device surface with coordinates in **28.4 bit FIX notation**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| x |
| y |

**x (4 bytes): **A BitFIX28_4 object (section 2.2.1) that represents the horizontal coordinate of the point.

**y (4 bytes): **A BitFIX28_4 object that represents the vertical coordinate of the point.

### RegionData Object

The **RegionData** object specifies data that defines a region, which is made of non-overlapping rectangles.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RegionDataHeader (32 bytes) |
| ... |
| ... |
| ... |
| Data (variable) |
| ... |

**RegionDataHeader (32 bytes): **A 256-bit RegionDataHeader object (section 2.2.25) that defines the contents of the **Data** field.

**Data (variable): **An array of RectL objects ([MS-WMF] section 2.2.2.19); the objects are merged to create the **region**.

### RegionDataHeader Object

The **RegionDat****aHeader** object defines the properties of a RegionData (section 2.2.24) object.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Size |
| Type |
| CountRects |
| RgnSize |
| Bounds |
| ... |
| ... |
| ... |

**Size (4 bytes): **An unsigned integer that specifies the size of this object in bytes. This value is 0x00000020.

**Type (4 bytes): **An unsigned integer that specifies the **region** type. This value is 0x00000001.

**CountRects (4 bytes): **An unsigned integer that specifies the number of rectangles in this region.

**RgnSize (4 bytes): **An unsigned integer that specifies the size of the buffer of rectangles in bytes.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19), which specifies the bounds of the region.

### TriVertex Object

The TriVertex object specifies color and position information for the definition of a rectangle or triangle vertex.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| x |
| y |
| Red | Green |
| Blue | Alpha |

**x (4 bytes): **A signed integer that specifies the horizontal position, in logical units.

**y (4 bytes): **A signed integer that specifies the vertical position, in logical units.

**Red (2 bytes): **An unsigned integer that specifies the red color value for the point.

**Green (2 bytes): **An unsigned integer that specifies the green color value for the point.

**Blue (2 bytes): **An unsigned integer that specifies the blue color value for the point.

**Alpha (2 bytes): **An unsigned integer that specifies the **alpha transparency** value for the point.

### UniversalFontId Object

The **UniversalFontId** object defines a mechanism for identifying fonts in **EMF** **metafiles**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Checksum |
| Index |

**Checksum (4 bytes): **An unsigned integer that is the checksum of the font. The checksum value has the following meanings.

| Value | Meaning |
| --- | --- |
| 0x00000000 | The object is a device font. |
| 0x00000001 | The object is a **Type 1 font** that has been installed on the client machine and is enumerated by the **PostScript** **printer driver** as a device font. |
| 0x00000002 | The object is not a font but is a Type 1 **rasterizer**. |
| 3 ≤ *value* | The object is a **bitmap**, vector, or **TrueType** font, or a Type 1 **rasterized font** that was created by a Type 1 rasterizer. A checksum value SHOULD be computed for the font and compared to the value in this field. If it matches, it is considered to be the same as the font referenced by this metafile record. If it does not match, the system **font mapper** MAY use a default mechanism to select a back-up font.<55> |

If a checksum value is computed, it SHOULD be computed using the following algorithm.

For the purpose of this computation, the font is considered simply to be a stream of bytes that is external to this EMF record. Any larger file structure in which the font might reside is system-dependent or implementation-dependent.

ULONG ComputeFileviewCheckSum(PVOID pvView, ULONG cjView)

{

    ULONG sum;

    PULONG pulCur,pulEnd;

    pulCur = (PULONG) pvView;

    for (sum = 0, pulEnd = pulCur + cjView / sizeof(ULONG); 

        pulCur < pulEnd; pulCur += 1)

    {

        sum += 256 * sum + *pulCur;

    }

    return ( sum < 2 ) ? 2 : sum;

}

**pvView**: A pointer to the start of the font.

**cjView**: The length of the font in bytes.

**Index (4 bytes): **An unsigned integer that is an index associated with the font object. The meaning of this field is determined by the type of font.

### XForm Object

The **XFor****m** object defines a two-dimensional, linear **transform** matrix.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| M11 |
| M12 |
| M21 |
| M22 |
| Dx |
| Dy |

**M11 (4 bytes): **A FLOAT matrix value.

**M12 (4 bytes): **A FLOAT matrix value.

**M21 (4 bytes): **A FLOAT matrix value.

**M22 (4 bytes): **A FLOAT matrix value.

**Dx (4 bytes): **A FLOAT value that contains a horizontal **translation** component, in logical units.

**Dy (4 bytes): **A FLOAT value that contains a vertical translation component, in logical units.

The following equations specify how the matrix values are used to transform a point (X,Y) to a new point (X',Y'):

X' = M11 * X + M21 * Y + Dx

Y' = M12 * X + M22 * Y + Dy

For more information concerning transforms and **coordinate spaces**, see [MSDN-WRLDPGSPC].

## EMF Records

This section specifies the **EMF** **metafile** records, which have been grouped into the following categories.

| Name | Section | Description |
| --- | --- | --- |
| Bitmap record types | 2.3.1 | Manage and output **bitmap** images. |
| Clipping record types | 2.3.2 | Specify and manage clipping regions. |
| Comment record types | 2.3.3 | Define formats for specifying arbitrary private data, embedding records in other metafile formats, and adding new or special-purpose commands. |
| Control record types | 2.3.4 | Define the start and end of an EMF metafile and its properties. |
| Drawing record types | 2.3.5 | Perform graphics drawing. |
| Escape record types | 2.3.6 | Execute **printer driver** functions. |
| Object creation record types | 2.3.7 | Create graphics objects. |
| Object manipulation record types | 2.3.8 | Manage and modify graphics objects. |
| OpenGL record types | 2.3.9 | Specify metafile records generated by **OpenGL** [OPENGL]. |
| Path bracket record types | 2.3.10 | Specify and manipulate paths in **path brackets**. |
| State record types | 2.3.11 | Specify and manage graphics properties. |
| Transform record types | 2.3.12 | Specify and modify **world-space** to **page-space** **transforms**. |

All EMF records MUST be multiples of 4 bytes in length; hence, each record starts on a 32-bit offset from the start of the metafile. To ensure each subsequent record also starts on a 32-bit boundary, an **AlignmentPadding** field is used, if necessary. The contents of **AlignmentPadding** fields are indeterminate and MUST be ignored. In general, such fields are shown only in the generic definitions of record categories.

To ensure maximum compatibility, implementations need to allow for record truncation for unused fields at the end of an EMF record. If there are extra data at the end of the record undocumented by this specification, these data MUST be ignored.

### Bitmap Record Types

The **Bitmap** record types perform block transfers of **bitmap** images.

The following are the bitmap record types.

| Name | Section | Description |
| --- | --- | --- |
| EMR_ALPHABLEND | 2.3.1.1 | Specifies a block transfer of pixels from a source bitmap to a destination rectangle, including **alpha transparency** data, according to a specified blending operation. |
| EMR_BITBLT | 2.3.1.2 | Specifies a block transfer of pixels from a source bitmap to a destination rectangle, optionally in combination with a brush pattern, according to a specified **raster operation**. |
| EMR_MASKBLT | 2.3.1.3 | Specifies a block transfer of pixels from a source bitmap to a destination rectangle, optionally in combination with a brush pattern and with the application of a color mask bitmap, according to specified foreground and background raster operations. |
| EMR_PLGBLT | 2.3.1.4 | Specifies a block transfer of pixels from a source bitmap to a destination parallelogram, with the application of a color mask bitmap. |
| EMR_SETDIBITSTODEVICE | 2.3.1.5 | Specifies a block transfer of pixels from specified scanlines of a source bitmap to a destination rectangle. |
| EMR_STRETCHBLT | 2.3.1.6 | Specifies a block transfer of pixels from a source bitmap to a destination rectangle, optionally in combination with a brush pattern, according to a specified raster operation, stretching or compressing the output to fit the dimensions of the destination, if necessary. |
| EMR_STRETCHDIBITS | 2.3.1.7 | Specifies a block transfer of pixels from a source bitmap to a destination rectangle, optionally in combination with a brush pattern, according to a specified raster operation, stretching or compressing the output to fit the dimensions of the destination, if necessary. |
| EMR_TRANSPARENTBLT | 2.3.1.8 | Specifies a block transfer of pixels from a source bitmap to a destination rectangle, treating a specified color as transparent, stretching or compressing the output to fit the dimensions of the destination, if necessary. |

The generic structure of bitmap records is specified as follows.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| BitmapRecordBuffer (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that defines the type of record. The bitmap record types are listed in the following table. See the preceding table for descriptions of these record types.

| Name | Value |
| --- | --- |
| EMR_BITBLT | 0x0000004C |
| EMR_STRETCHBLT | 0x0000004D |
| EMR_MASKBLT | 0x0000004E |
| EMR_PLGBLT | 0x0000004F |
| EMR_SETDIBITSTODEVICE | 0x00000050 |
| EMR_STRETCHDIBITS | 0x00000051 |
| EMR_ALPHABLEND | 0x00000072 |
| EMR_TRANSPARENTBLT | 0x00000074 |

**Size (4 bytes): **An unsigned integer that specifies the size in bytes of this record in the **metafile**. This value MUST be a multiple of 4 bytes.

**BitmapRecordBuffer (variable): **An array of bytes that contains the remainder of the bitmap record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BitmapRecordParm (variable) |
| ... |
| AlignmentPadding (variable, optional) |
| ... |

**BitmapRecordParm (variable): **An array of bytes that contains the parameters for the bitmap record.

**AlignmentPadding (variable, optional):** An array of up to 3 bytes that pads the record so that its total size is a multiple of 4 bytes. This field MUST be ignored.

The following notes apply generally to **EMF** bitmap block transfers, unless specified otherwise:

Source and mask bitmaps are in **DIB** format. DIBs are specified by DeviceIndependentBitmap objects ([MS-WMF] section 2.2.2.9).

The clipping **regions** used by bitmap records are maintained in a **Regions** state element (section 3.1.1.2.1) in the **playback device context** (section 3.1).

If the color format of the source or pattern bitmap does not match the color format of the destination, the source pr pattern bits MUST be converted to the destination format prior to performing the block transfer.

If the source and destination rectangles are not the same size, the source bitmap MUST be expanded or compressed to match the destination rectangle. This stretching function is performed according to a property from the StretchMode enumeration (section 2.1.32).

If an XForm object (section 2.2.28) is specified, a **worl****d-space** to **page-space** **transform** SHOULD be applied to the source bitmap. **Scaling**, **translation**, and **reflection transforms** SHOULD be supported, and **rotation** and **shear transforms** MAY be supported.

For more information concerning transforms and **coordinate spaces**, see [MSDN-WRLDPGSPC].

See section 2.3 for more EMF record types.

#### EMR_ALPHABLEND Record

The **EMR_ALPHABLEND** record specifies a block transfer of pixels from a source **bitmap** to a destination rectangle, including **al****pha transparency** data, according to a specified blending operation.<56>

Fields not specified in this section are specified in section 2.3.1.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| xDest |
| yDest |
| cxDest |
| cyDest |
| BLENDFUNCTION |
| xSrc |
| ySrc |
| XformSrc (24 bytes) |
| ... |
| ... |
| ... |
| BkColorSrc |
| UsageSrc |
| offBmiSrc |
| cbBmiSrc |
| offBitsSrc |
| cbBitsSrc |
| cxSrc |
| cySrc |
| BitmapBuffer (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_ALPHABLEND**. This value is 0x00000072.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the destination bounding rectangle in logical coordinates. If the intersection of this rectangle with the current clipping **regions** (section 3.1.1.2.1) in the **playback device context** (section 3.1) is empty, this record has no effect.

**xDest (4 bytes): **A signed integer that specifies the logical x-coordinate of the upper-left corner of the destination rectangle.

**yDest (4 bytes): **A signed integer that specifies the logical y-coordinate of the upper-left corner of the destination rectangle.

**cxDest (4 bytes): **A signed integer that specifies the logical width of the destination rectangle. This value MUST be greater than zero.

**cyDest (4 bytes): **A signed integer that specifies the logical height of the destination rectangle. This value MUST be greater than zero.

**BLENDFUNCTION (4 bytes): **A structure that specifies the blending operations for source and destination bitmaps.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BlendOperation | BlendFlags | SrcConstantAlpha | AlphaFormat |

**BlendOperation (1 byte): **The blend operation code. The only source and destination blend operation that has been defined is 0x00, which specifies that the source bitmap MUST be combined with the destination bitmap based on the alpha transparency values of the source pixels. See the following equations for details.

**BlendFlags (1 byte): **This value is 0x00 and MUST be ignored.

**SrcConstantAlpha (1 byte): **An unsigned integer that specifies alpha transparency, which determines the blend of the source and destination bitmaps. This value MUST be used on the entire source bitmap. The minimum alpha transparency value, zero, corresponds to completely transparent; the maximum value, 0xFF, corresponds to completely opaque. In effect, a value of 0xFF specifies that the per-pixel alpha values determine the blend of the source and destination bitmaps. See the equations later in this section for details.

**AlphaFormat (1 byte): **A structure that specifies how source and destination pixels are interpreted with respect to alpha transparency.

| Value | Meaning |
| --- | --- |
| 0x00 | The pixels in the source bitmap do not specify alpha transparency. In this case, the **SrcConstantAlpha** value determines the blend of the source and destination bitmaps. Note that in the following equations **SrcConstantAlpha** is divided by 255, which produces a value in the range 0 to 1. |
| AC_SRC_ALPHA0x01 | Indicates that the source bitmap is 32 bits-per-pixel and specifies an alpha transparency value for each pixel. |

**xSrc (4 bytes): **A signed integer that specifies the logical x-coordinate of the upper-left corner of the source rectangle.

**ySrc (4 bytes): **A signed integer that specifies the logical y-coordinate of the upper-left corner of the source rectangle.

**XformSrc (24 bytes): **An XForm object (section 2.2.28) that specifies a **world-space** to **page-space** **transform** to apply to the source bitmap.

**BkColorSrc (4 bytes): **A ColorRef object ([MS-WMF] section 2.2.2.8) that specifies the background color of the source bitmap.

**UsageSrc (4 bytes): **An unsigned integer that specifies how to interpret values in the **color table** in the source bitmap header. This value is in the DIBColors enumeration (section 2.1.9).

**offBmiSrc (4 bytes): **An unsigned integer that specifies the offset in bytes from the start of this record to the source bitmap header in the **BitmapBuffer** field.

**cbBmiSrc (4 bytes): **An unsigned integer that specifies the size in bytes of the source bitmap header.

**offBitsSrc (4 bytes): **An unsigned integer that specifies the offset in bytes from the start of this record to the source bitmap bits in the **BitmapBuffer** field.

**cbBitsSrc (4 bytes): **An unsigned integer that specifies the size in bytes of the source bitmap bits.

**cxSrc (4 bytes): **A signed integer that specifies the logical width of the source rectangle. This value MUST be greater than zero.

**cySrc (4 bytes): **A signed integer that specifies the logical height of the source rectangle. This value MUST be greater than zero.

**BitmapBuffer**** (variable): **A buffer containing the source bitmap, which is not required to be contiguous with the fixed portion of the **EMR_ALPHABLEND** record. Thus, fields in this buffer that are labeled "UndefinedSpace" are optional and MUST be ignored.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UndefinedSpace1 (variable, optional) |
| ... |
| BmiSrc (variable) |
| ... |
| UndefinedSpace2 (variable, optional) |
| ... |
| BitsSrc (variable) |
| ... |

**BmiSrc (variable): **The source bitmap header.

**BitsSrc (variable): **The source bitmap bits.

The following equations show how destination pixels are computed from source pixels using **BLENDFUNCTION**. In the equations, "dst" refers to the destination bitmap, and "src" refers to the source bitmap. The color and transparency values of the source and destination pixels are denoted by "Red", "Green", "Blue", and "Alpha".

**Case I**: The **AlphaFormat** value is 0, which means the **SrcConstantAlpha** value MUST be used to blend the source and destination bitmaps, as follows.

dst.Red = src.Red * (SrcConstantAlpha/255.0) +

    dst.Red * (1.0 - (SrcConstantAlpha/255.0))

dst.Green = src.Green * (SrcConstantAlpha/255.0) +

    dst.Green * (1.0 - (SrcConstantAlpha/255.0))

dst.Blue = src.Blue * (SrcConstantAlpha/255.0) +

    dst.Blue * (1.0 - (SrcConstantAlpha/255.0))

If the destination bitmap has an alpha channel, then it is blended as follows.

dst.Alpha = src.Alpha * (SrcConstantAlpha/255.0) +

    dst.Alpha * (1.0 - (SrcConstantAlpha/255.0))

Note that if **SrcConstantAlpha** is 0xFF, these equations reduce to a simple source copy to the destination.

**Case II**: The **AlphaFormat** value is **AC_SRC_ALPHA**, which means the source pixels MUST be premultiplied by **SrcConstantAlpha**, and then the blend MUST be based on the per-pixel source alpha channel, as follows.

src.Red = src.Red * (SrcConstantAlpha/255.0)

src.Green = src.Green * (SrcConstantAlpha/255.0)

src.Blue = src.Blue * (SrcConstantAlpha/255.0)

dst.Red = src.Red  + (1.0 - (src.Alpha/255.0)) * dst.Red

dst.Green = src.Green + (1.0 - (src.Alpha/255.0)) * dst.Green

dst.Blue = src.Blue + (1.0 - (src.Alpha/255.0)) * dst.Blue

If the destination bitmap has an alpha channel, it is blended as follows.

src.Alpha = src.Alpha * (SrcConstantAlpha)/255.0)

dst.Alpha = src.Alpha + (1.0 - (src.Alpha/255.0)) * dst.Alpha

If **SrcConstantAlpha** is 0xFF, there is in effect no premultiplication of the source values.

See section 2.3.1 for more bitmap record types.

#### EMR_BITBLT Record

The EMR_BITBLT record specifies a block transfer of pixels from a source **bitmap** to a destination rectangle, optionally in combination with a brush pattern, according to a specified **raster operation**.

Fields not specified in this section are specified in section 2.3.1.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| xDest |
| yDest |
| cxDest |
| cyDest |
| BitBltRasterOperation |
| xSrc |
| ySrc |
| XformSrc (24 bytes) |
| ... |
| ... |
| ... |
| BkColorSrc |
| UsageSrc |
| offBmiSrc |
| cbBmiSrc |
| offBitsSrc |
| cbBitsSrc |
| BitmapBuffer (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_BITBLT. This value is 0x0000004C.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the destination bounding rectangle in logical coordinates. If the intersection of this rectangle with the current clipping **regions** (section 3.1.1.2.1) in the **playback device context** (section 3.1) is empty, this record has no effect.

**xDest (4 bytes): **A signed integer that specifies the logical x-coordinate of the upper-left corner of the destination rectangle.

**yDest (4 bytes): **A signed integer that specifies the logical y-coordinate of the upper-left corner of the destination rectangle.

**cxDest (4 bytes): **A signed integer that specifies the logical width of the source and destination rectangles.

**cyDest (4 bytes): **A signed integer that specifies the logical height of the source and destination rectangles.

**BitBltRasterOperation (4 bytes): **An unsigned integer that specifies the raster operation code. This code defines how the color data of the source rectangle is to be combined with the color data of the destination rectangle and optionally a brush pattern, to achieve the final color. 

This value is in the Ternary Raster Operation enumeration ([MS-WMF] section 2.1.1.31).

**xSrc (4 bytes): **A signed integer that specifies the logical x-coordinate of the upper-left corner of the source rectangle.

**ySrc (4 bytes): **A signed integer that specifies the logical y-coordinate of the upper-left corner of the source rectangle.

**XformSrc (24 bytes): **An XForm object (section 2.2.28) that specifies a **world-space** to **page-space** **transform** to apply to the source bitmap.

**BkColorSrc (4 bytes): **A ColorRef object ([MS-WMF] section 2.2.2.8) that specifies the background color of the source bitmap.

**UsageSrc (4 bytes): **An unsigned integer that specifies how to interpret values in the **color table** in the source bitmap header. This value is in the DIBColors enumeration (section 2.1.9).

**offBmiSrc (4 bytes): **An unsigned integer that specifies the offset in bytes, from the start of this record to the source bitmap header in the **BitmapBuffer** field.

**cbBmiSrc (4 bytes): **An unsigned integer that specifies the size in bytes, of the source bitmap header.

**offBitsSrc (4 bytes): **An unsigned integer that specifies the offset in bytes, from the start of this record to the source bitmap bits in the **BitmapBuffer** field.

**cbBitsSrc (4 bytes): **An unsigned integer that specifies the size in bytes, of the source bitmap bits. 

**BitmapBuffer (variable): **A buffer containing the source bitmap, which is not required to be contiguous with the fixed portion of the EMR_BITBLT record. Thus, fields in this buffer that are labeled "UndefinedSpace" are optional and MUST be ignored.

If the raster operation specified by **BitBl****tRasterOperation** does not require a source bitmap, the source bitmap can be omitted.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UndefinedSpace1 (variable, optional) |
| ... |
| BmiSrc (variable) |
| ... |
| UndefinedSpace2 (variable, optional) |
| ... |
| BitsSrc (variable) |
| ... |

**BmiSrc (variable): **The source bitmap header.

**BitsSrc (variable): **The source bitmap bits.

See section 2.3.1 for more bitmap record types.

#### EMR_MASKBLT Record

The EMR_MASKBLT record specifies a block transfer of pixels from a source **bitmap** to a destination rectangle, optionally in combination with a brush pattern and with the application of a color mask bitmap, according to specified foreground and background **raster operations**.

Fields not specified in this section are specified in section 2.3.1.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| xDest |
| yDest |
| cxDest |
| cyDest |
| ROP4 |
| xSrc |
| ySrc |
| XformSrc (24 bytes) |
| ... |
| ... |
| ... |
| BkColorSrc |
| UsageSrc |
| offBmiSrc |
| cbBmiSrc |
| offBitsSrc |
| cbBitsSrc |
| xMask |
| yMask |
| UsageMask |
| offBmiMask |
| cbBmiMask |
| offBitsMask |
| cbBitsMask |
| BitmapBuffer (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_MASKBLT**. This value is 0x0000004E.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the destination bounding rectangle in logical coordinates. If the intersection of this rectangle with the current clipping **regions** (section 3.1.1.2.1) in the **playback device context** (section 3.1) is empty, this record has no effect.

**xDest (4 bytes): **A signed integer that specifies the logical x-coordinate of the upper-left corner of the destination rectangle.

**yDest (4 bytes): **A signed integer that specifies the logical y-coordinate of the upper-left corner of the destination rectangle.

**cxDest (4 bytes): **A signed integer that specifies the logical width of the destination rectangle.

**cyDest (4 ****bytes): **A signed integer that specifies the logical height of the destination rectangle.

**ROP4 (4 bytes): **A quaternary raster operation, which specifies ternary raster operations for the foreground and background colors of a bitmap. These values define how the color data of the source rectangle is to be combined with the color data of the destination rectangle.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Reserved | BackgroundROP3 | ForegroundROP3 |

**Reserved (2 bytes): **This field SHOULD be 0x0000 and MUST be ignored.<57>

**BackgroundROP3 (1 byte): **The unsigned, most-significant 8 bits of a 24-bit ternary raster operation value from the Ternary Raster Operation enumeration ([MS-WMF] section 2.1.1.31). This code defines how to combine the background color data of the source and destination bitmaps and brush pattern.

**ForegroundROP3 (1 byte): **The unsigned, most-significant 8 bits of a 24-bit ternary raster operation value from the Ternary Raster Operation enumeration. This code defines how to combine the foreground color data of the source and destination bitmaps and brush pattern.

**xSrc (4 bytes): **A signed integer that specifies the logical x-coordinate of the upper-left corner of the source rectangle.

**ySrc (4 bytes): **A signed integer that specifies the logical y-coordinate of the upper-left corner of the source rectangle.

**XformSrc (24 bytes): **An XForm object (section 2.2.28) that specifies a **world-space** to **page-space** **transform** to apply to the source bitmap.

**BkColorSrc (4 bytes): **A ColorRef object ([MS-WMF] section 2.2.2.8) that specifies the background color of the source bitmap.

**UsageSrc (4 bytes): **An unsigned integer that specifies how to interpret values in the **color table** in the source bitmap header. This value is in the DIBColors enumeration (section 2.1.9).

**offBmiSrc (4 bytes): **An unsigned integer that specifies the offset in bytes, from the start of this record to the source bitmap header in the **BitmapBuffer** field.

**cbBmiSrc (4 bytes): **An unsigned integer that specifies the size in bytes of the source bitmap header.

**offBitsSrc (4 bytes): **An unsigned integer that specifies the offset in bytes, from the start of this record to the source bitmap bits in the **BitmapBuffer** field.

**cbBitsSrc (4 bytes): **An unsigned integer that specifies the size in bytes, of the source bitmap bits. 

**xMask (4 bytes): **A signed integer that specifies the logical x-coordinate of the upper-left corner of the mask bitmap.

**yMask (4 bytes): **A signed integer that specifies the logical y-coordinate of the upper-left corner of the mask bitmap.

**UsageMask (4 bytes): **An unsigned integer that specifies how to interpret values in the color table in the mask bitmap header. This value is in the DIBColors enumeration.

**offBmiMask (4 bytes): **An unsigned integer that specifies the offset in bytes, from the start of this record to the mask bitmap header in the **BitmapBuffer** field.

**cbBmiMask (4 bytes): **An unsigned integer that specifies the size in bytes, of the mask bitmap header.

**offBitsMask (4 bytes): **An unsigned integer that specifies the offset in bytes, from the start of this record to the mask bitmap bits in the **BitmapBuffer** field.

**cbBitsMask (4 bytes): **An unsigned integer that specifies the size in bytes, of the mask bitmap bits. 

**BitmapBuffer (variable): **A buffer containing the source and mask bitmaps, which are not required to be contiguous with the fixed portion of the EMR_MASKBLT record or with each other. Thus, fields in this buffer that are labeled "UndefinedSpace" are optional and MUST be ignored.

**Note: **The source and mask bitmaps can be present in this buffer in any order.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UndefinedSpace1 (variable, optional) |
| ... |
| BmiSrc (variable) |
| ... |
| UndefinedSpace2 (variable, optional) |
| ... |
| BitsSrc (variable) |
| ... |
| UndefinedSpace3 (variable, optional) |
| ... |
| BmiMask (variable) |
| ... |
| UndefinedSpace4 (variable, optional) |
| ... |
| BitsMask (variable) |
| ... |

**BmiSrc (variable): **The source bitmap header.

**BitsSrc (variable): **The source bitmap bits.

**BmiMask (variable): **The mask bitmap header.

**BitsMask (variable): **The mask bitmap bits.

The mask bitmap MUST be monochrome; that is, each pixel value MUST be zero or one. A pixel value of one in the mask indicates that the color of the corresponding pixel in the source bitmap SHOULD be copied to the destination. A value of zero in the mask indicates that the destination pixel color SHOULD NOT be changed. If the mask rectangle is smaller than the source and destination rectangles, the mask pattern MUST be replicated as necessary.

See section 2.3.1 for more bitmap record types.

#### EMR_PLGBLT Record

The EMR_PLGBLT record specifies a block transfer of pixels from a source **bitmap** to a destination parallelogram, with the application of a color mask bitmap.

Fields not specified in this section are specified in section 2.3.1.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| aptlDest (24 bytes) |
| ... |
| ... |
| ... |
| xSrc |
| ySrc |
| cxSrc |
| cySrc |
| XformSrc (24 bytes) |
| ... |
| ... |
| ... |
| BkColorSrc |
| UsageSrc |
| offBmiSrc |
| cbBmiSrc |
| offBitsSrc |
| cbBitsSrc |
| xMask |
| yMask |
| UsageMask |
| offBmiMask |
| cbBmiMask |
| offBitsMask |
| cbBitsMask |
| BitmapBuffer (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_PLGBLT**. This value is 0x0000004F.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the destination bounding rectangle in logical coordinates. If the intersection of this rectangle with the current clipping **regions** (section 3.1.1.2.1) in the **playback device context** (section 3.1) is empty, this record has no effect.

**aptlDest (24 bytes): **An array of three PointL objects ([MS-WMF] section 2.2.2.15) that specifies three corners a parallelogram destination area for the block transfer.

The upper-left corner of the source rectangle is mapped to the first point in this array, the upper-right corner to the second point, and the lower-left corner to the third point. The lower-right corner of the source rectangle is mapped to the implicit fourth point in the parallelogram, which is computed from the first three points (A, B, and C) by treating them as vectors.

D = B + C A

**xSrc (4 bytes): **A signed integer that specifies the logical x-coordinate of the upper-left corner of the source rectangle.

**ySrc (4 bytes): **A signed integer that specifies the logical y-coordinate of the upper-left corner of the source rectangle.

**cxSrc (4 bytes): **A signed integer that specifies the logical width of the source rectangle.

**cySrc (4 bytes): **A signed integer that specifies the logical height of the source rectangle.

**XformSrc (24 bytes): **An XForm object (section 2.2.28) that specifies a **world-space** to **page-space** **transform** to apply to the source bitmap.

**BkColorSrc (4 bytes): **A ColorRef object ([MS-WMF] section 2.2.2.8) that specifies the background color of the source bitmap.

**UsageSrc (4 bytes): **An unsigned integer that specifies how to interpret values in the **color table** in the source bitmap header. This value is in the DIBColors enumeration (section 2.1.9).

**offBmiSrc (4 bytes): **An unsigned integer that specifies the offset in bytes, from the start of this record to the source bitmap header in the **BitmapBuffer** field.

**cbBmiSrc (4 bytes): **An unsigned integer that specifies the size in bytes, of the source bitmap header.

**offBitsSrc (4 bytes): **An unsigned integer that specifies the offset in bytes, from the start of this record to the source bitmap bits in the **BitmapBuffer** field.

**cbBitsSrc (4 bytes): **An unsigned integer that specifies the size in bytes, of the source bitmap.

**xMask (4 bytes): **A signed integer that specifies the logical x-coordinate of the upper-left corner of the mask bitmap.

**yMask (4 byt****es): **A signed integer that specifies the logical y-coordinate of the upper-left corner of the mask bitmap.

**UsageMask (4 bytes): **An unsigned integer that specifies how to interpret values in the color table in the mask bitmap header. This value is in the DIBColors enumeration.

**offBmiMask (4 bytes): **An unsigned integer that specifies the offset in bytes, from the start of this record to the header of the mask bitmap in the **BitmapBuffer** field.

**cbBmiMask (4 bytes): **An unsigned integer that specifies the size in bytes, of the mask bitmap header.

**offBitsMask (4 bytes): **An unsigned integer that specifies the offset in bytes, from the start of this record to the mask bitmap bits in the **BitmapBuffer** field.

**cbBitsMask (4 b****ytes): **An unsigned integer that specifies the size in bytes, of the mask bitmap bits.

**BitmapBuffer (variable): **A buffer containing the source and mask bitmaps, which are not required to be contiguous with the fixed portion of the EMR_PLGBLT record or with each other. Thus, fields in this buffer that are labeled "UndefinedSpace" are optional and MUST be ignored.

**Note: **The source and mask bitmaps can be present in this buffer in any order.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UndefinedSpace1 (variable, optional) |
| ... |
| BmiSrc (variable) |
| ... |
| UndefinedSpace2 (variable, optional) |
| ... |
| BitsSrc (variable) |
| ... |
| UndefinedSpace3 (variable, optional) |
| ... |
| BmiMask (variable) |
| ... |
| UndefinedSpace4 (variable, optional) |
| ... |
| BitsMask (variable) |
| ... |

**BmiSrc (variable): **The source bitmap header.

**BitsSrc (variable): **The source bitmap bits.

**BmiMask (variable): **The mask bitmap header.

**BitsMask (variable): **The mask bitmap bits.

The mask bitmap MUST be monochrome; that is, each pixel value MUST be zero or one. A pixel value of one in the mask indicates that the color of the corresponding pixel in the source bitmap SHOULD be copied to the destination. A value of zero in the mask indicates that the destination pixel color SHOULD NOT be changed. If the mask rectangle is smaller than the source and destination rectangles, the mask pattern MUST be replicated as necessary.

See section 2.3.1 for more bitmap record types.

#### EMR_SETDIBITSTODEVICE Record

The EMR_SETDIBITSTODEVICE record specifies a block transfer of pixels from specified scanlines of a source **bitmap** to a destination rectangle.

Fields not specified in this section are specified in section 2.3.1.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| xDest |
| yDest |
| xSrc |
| ySrc |
| cxSrc |
| cySrc |
| offBmiSrc |
| cbBmiSrc |
| offBitsSrc |
| cbBitsSrc |
| UsageSrc |
| iStartScan |
| cScans |
| BitmapBuffer (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_SETDIBITSTODEVICE**. This value is 0x00000050.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the destination bounding rectangle in logical coordinates. If the intersection of this rectangle with the current clipping **regions** (section 3.1.1.2.1) in the **playback device context** (section 3.1) is empty, this record has no effect.

**xDest (4 bytes): **A signed integer that specifies the logical x-coordinate of the upper-left corner of the destination rectangle.

**yDest (4 bytes): **A signed integer that specifies the logical y-coordinate of the upper-left corner of the destination rectangle.

**xSrc (4 bytes): **A signed integer that specifies the x-coordinate in pixels of the lower-left corner of the source rectangle.

**ySrc (4 bytes): **A signed integer that specifies the y-coordinate in pixels of the lower-left corner of the source rectangle.

**cxSrc (4 bytes): **A signed integer that specifies the width in pixels of the source rectangle.

**cySrc (4 bytes): **A signed integer that specifies the height in pixels of the source rectangle.

**offBmiSrc (4 bytes): **An unsigned integer that specifies the offset in bytes, from the start of this record to the source bitmap header in the **BitmapBuffer** field.

**cbBmiSrc (4 bytes): **An unsigned integer that specifies the size in bytes, of the source bitmap header.

**offBitsSrc (4 bytes): **An unsigned integer that specifies the offset in bytes, from the start of this record to the source bitmap bits in the **BitmapBuffer** field.

**cbBitsSrc (4 bytes): **An unsigned integer that specifies the size in bytes, of the source bitmap bits.

**UsageSrc (4 bytes): **An unsigned integer that specifies how to interpret values in the **color table** in the source bitmap header. This value is in the DIBColors enumeration (section 2.1.9).

**iStartScan (4 bytes): **An unsigned integer that specifies the first scan line in the array.

**cScans (4 bytes): **An unsigned integer that specifies the number of scan lines.

**BitmapBuffer (variable): **A buffer containing the source bitmap, which is not required to be contiguous with the fixed portion of the EMR_SETDIBITSTODEVICE record. Thus, fields in this buffer that are labeled "UndefinedSpace" are optional and MUST be ignored.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UndefinedSpace1 (variable, optional) |
| ... |
| BmiSrc (variable) |
| ... |
| UndefinedSpace2 (variable, optional) |
| ... |
| BitsSrc (variable) |
| ... |

**BmiSrc (variable): **The source bitmap header.

**BitsSrc (variable): **The source bitmap bits.

This record supports source images in **JPEG** and **PNG** format. The **Compressio****n** field in the source bitmap header specifies the image format.

See section 2.3.1 for more bitmap record types.

#### EMR_STRETCHBLT Record

The EMR_STRETCHBLT record specifies a block transfer of pixels from a source **bitmap** to a destination rectangle, optionally in combination with a brush pattern, according to a specified **raster operation**, stretching or compressing the output to fit the dimensions of the destination, if necessary.

Fields not specified in this section are specified in section 2.3.1.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| xDest |
| yDest |
| cxDest |
| cyDest |
| BitBltRasterOperation |
| xSrc |
| ySrc |
| XformSrc (24 bytes) |
| ... |
| ... |
| ... |
| BkColorSrc |
| UsageSrc |
| offBmiSrc |
| cbBmiSrc |
| offBitsSrc |
| cbBitsSrc |
| cxSrc |
| cySrc |
| BitmapBuffer (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_STRETCHBLT**. This value is 0x0000004D.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the destination bounding rectangle in logical coordinates. If the intersection of this rectangle with the current clipping **regions** (section 3.1.1.2.1) in the **playback device context** (section 3.1) is empty, this record has no effect.

**xDest (4 bytes): **A signed integer that specifies the logical x-coordinate of the upper-left corner of the destination rectangle.

**yDest (4 bytes): **A signed integer that specifies the logical y-coordinate of the upper-left corner of the destination rectangle.

**cxDest (4 bytes): **A signed integer that specifies the logical width of the destination rectangle.

**cyDest (4 bytes): **A signed integer that specifies the logical height of the destination rectangle.

**BitBltRasterOperation (4 bytes):**** **An unsigned integer that specifies the raster operation code. This code defines how the color data of the source rectangle is to be combined with the color data of the destination rectangle and optionally a brush pattern, to achieve the final color.

This value is in the Ternary Raster Operation enumeration ([MS-WMF] section 2.1.1.31).

**xSrc (4 bytes): **A signed integer that specifies the logical x-coordinate of the upper-left corner of the source rectangle.

**ySrc (4 bytes): **A signed integer that specifies the logical y-coordinate of the upper-left corner of the source rectangle.

**XformSrc (24 bytes): **An XForm object (section 2.2.28) that specifies a **world-space** to **page-space** **transform** to apply to the source bitmap.

**BkColorSrc (4 bytes): **A ColorRef object ([MS-WMF] section 2.2.2.8) that specifies the background color of the source bitmap.

**UsageSrc (4 bytes): **An unsigned integer that specifies how to interpret values in the **color table** in the source bitmap header. This value is in the DIBColors enumeration (section 2.1.9).

**offBmiSrc (4 bytes): **An unsigned integer that specifies the offset in bytes, from the start of this record to the source bitmap header.

**cbBmiSrc (4 bytes): **An unsigned integer that specifies the size in bytes, of the source bitmap header.

**offBitsSrc (4 bytes): **An unsigned integer that specifies the offset in bytes, from the start of this record to the source bitmap bits.

**cbBitsSrc (****4 bytes): **An unsigned integer that specifies the size in bytes, of the source bitmap bits.

**cxSrc (4 bytes): **A signed integer that specifies the logical width of the source rectangle.

**cySrc (4 bytes): **A signed integer that specifies the logical height of the source rectangle.

**BitmapBuffer (variable): **A buffer containing the source bitmap, which is not required to be contiguous with the fixed portion of the EMR_STRETCHBLT record. Thus, fields in this buffer that are labeled "UndefinedSpace" are optional and MUST be ignored.

If the raster operation specified by **BitBltRasterOperation** does not require a source bitmap, the source bitmap can be omitted.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UndefinedSpace1 (variable, optional) |
| ... |
| BmiSrc (variable) |
| ... |
| UndefinedSpace2 (variable, optional) |
| ... |
| BitsSrc (variable) |
| ... |

**BmiSrc (variable): **The source bitmap header.

**BitsSrc (variable): **The source bitmap bits.

See section 2.3.1 for more bitmap record types.

#### EMR_STRETCHDIBITS Record

The EMR_STRETCHDIBITS record specifies a block transfer of pixels from a source **bitmap** to a destination rectangle, optionally in combination with a brush pattern, according to a specified **raster operation**, stretching or compressing the output to fit the dimensions of the destination, if necessary.

Fields not specified in this section are specified in section 2.3.1.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| xDest |
| yDest |
| xSrc |
| ySrc |
| cxSrc |
| cySrc |
| offBmiSrc |
| cbBmiSrc |
| offBitsSrc |
| cbBitsSrc |
| UsageSrc |
| BitBltRasterOperation |
| cxDest |
| cyDest |
| BitmapBuffer (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_STRETCHDIBITS**. This value is 0x00000051.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the destination bounding rectangle in logical coordinates. If the intersection of this rectangle with the current clipping **regions** (section 3.1.1.2.1) in the **playback device**** context** (section 3.1) is empty, this record has no effect.

**xDest (4 bytes): **A signed integer that specifies the logical x-coordinate of the upper-left corner of the destination rectangle.

**yDest (****4 bytes): **A signed integer that specifies the logical y-coordinate of the upper-left corner of the destination rectangle.

**xSrc (4 bytes): **A signed integer that specifies the x-coordinate in pixels of the upper-left corner of the source rectangle.

**ySrc (4 b****ytes): **A signed integer that specifies the y-coordinate in pixels of the upper-left corner of the source rectangle.

**cxSrc (4 bytes): **A signed integer that specifies the width in pixels of the source rectangle.

**cySrc (4 bytes): **A signed integer that specifies the height in pixels of the source rectangle.

**offBmiSrc (4 bytes): **An unsigned integer that specifies the offset in bytes from the start of this record to the source bitmap header.

**cbBmiSrc (4 bytes): **An unsigned integer that specifies the size in bytes, of the source bitmap header.

**offBitsSrc (4 bytes): **An unsigned integer that specifies the offset in bytes, from the start of this record to the source bitmap bits.

**cbBitsSrc (4 bytes): **An unsigned integer that specifies the size in bytes, of the source bitmap bits.

**UsageSrc (4 bytes): **An unsigned integer that specifies how to interpret values in the **color table** in the source bitmap header. This value is in the DIBColors enumeration (section 2.1.9).

**BitBltRasterOperation (4 bytes): **An unsigned integer that specifies a raster operation code. These codes define how the color data of the source rectangle is to be combined with the color data of the destination rectangle and optionally a brush pattern, to achieve the final color.

This value is in the Ternary Raster Operation enumeration ([MS-WMF] section 2.1.1.31).

**cxDest (4 bytes): **A signed integer that specifies the logical width of the destination rectangle.

**cyDest (4 bytes): **A signed integer that specifies the logical height of the destination rectangle.

**BitmapBuffer (variable): **A buffer containing the source bitmap, which is not required to be contiguous with the fixed portion of the EMR_STRETCHDIBITS record. Thus, fields in this buffer that are labeled "UndefinedSpace" are optional and MUST be ignored.

If the raster operation specified by **BitBltRasterOperation** does not require a source bitmap, the source bitmap can be omitted.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UndefinedSpace1 (variable, optional) |
| ... |
| BmiSrc (variable) |
| ... |
| UndefinedSpace2 (variable, optional) |
| ... |
| BitsSrc (variable) |
| ... |

**BmiSrc (variable): **The source bitmap header.

**BitsSrc (variable): **The source bitmap bits.

This record supports source images in **JPEG** and **PNG** formats. The **Compression** field in the source bitmap header specifies the image format.

If the signs of the source and destination height and width fields differ, this record specifies a mirror-image copy of the source bitmap to the destination. That is, if **cxSrc** and **cxDest** have different signs, a mirror image of the source bitmap along the x-axis is specified. If **cySrc** and **cyDest** have different signs, a mirror image of the source bitmap along the y-axis is specified.

See section 2.3.1 for more bitmap record types.

#### EMR_TRANSPARENTBLT Record

The EMR_TRANSPARENTBLT record specifies a block transfer of pixels from a source **bitmap** to a destination rectangle, treating a specified color as transparent, stretching or compressing the output to fit the dimensions of the destination, if necessary.<58>

Fields not specified in this section are specified in section 2.3.1.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| xDest |
| yDest |
| cxDest |
| cyDest |
| TransparentColor |
| xSrc |
| ySrc |
| XformSrc (24 bytes) |
| ... |
| ... |
| ... |
| BkColorSrc |
| UsageSrc |
| offBmiSrc |
| cbBmiSrc |
| offBitsSrc |
| cbBitsSrc |
| cxSrc |
| cySrc |
| BitmapBuffer (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_TRANSPARENTBLT**. This value is 0x00000074.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the destination bounding rectangle in logical coordinates. If the intersection of this rectangle with the current clipping **regions** (section 3.1.1.2.1) in the **playback device context** (section 3.1) is empty, this record has no effect.

**xDest (4 bytes): **A signed integer that specifies the logical x-coordinate of the upper-left corner of the destination rectangle.

**yDest (4 bytes): **A signed integer that specifies the logical y-coordinate of the upper-left corner of the destination rectangle.

**cxDest (4 bytes): **A signed integer that specifies the logical width of the destination rectangle.

**cyDest (4 bytes): **A signed integer that specifies the logical height of the destination rectangle.

**TransparentColor (4 bytes): **A ColorRef object ([MS-WMF] section 2.2.2.8) that specifies the color in the source bitmap to be treated as transparent.

**xSrc (4 bytes): **A signed integer that specifies the logical x-coordinate of the upper-left corner of the source rectangle.

**ySrc (4 bytes): **A signed integer that specifies the logical y-coordinate of the upper-left corner of the source rectangle.

**XformSrc (24 bytes): **An XForm object (section 2.2.28) that specifies a **world-space** to **page-space** **transform** to apply to the source bitmap.

**BkColorSrc (4 bytes): **A ColorRef object that specifies the background color of the source bitmap.

**UsageSrc (4 bytes): **An unsigned integer that specifies how to interpret values in the **color table** in the source bitmap header. This value is in the DIBColors enumeration (section 2.1.9).

**offBmiSrc (4 bytes): **An unsigned integer that specifies the offset in bytes, from the start of this record to the source bitmap header.

**cbBmiSrc (4 bytes****): **An unsigned integer that specifies the size in bytes, of the source bitmap header.

**offBitsSrc (4 bytes): **An unsigned integer that specifies the offset in bytes, from the start of this record to the source bitmap bits.

**cbBitsSrc (4 bytes): **An unsigned integer that specifies the size in bytes, of the source bitmap bits. 

**cxSrc (4 bytes): **A signed integer that specifies the logical width of the source rectangle.

**cySrc (4 bytes): **A signed integer that specifies the logical height of the source rectangle.

**BitmapBuffer (variable): **A buffer containing the source bitmap, which is not required to be contiguous with the fixed portion of the EMR_TRANSPARENTBLT record. Thus, fields in this buffer that are labeled "UndefinedSpace" are optional and MUST be ignored.

If the source bitmap color format is 32 bits-per-pixel, only the **alpha transparency** value in each pixel SHOULD be copied to the destination.<59>

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UndefinedSpace1 (variable, optional) |
| ... |
| BmiSrc (variable) |
| ... |
| UndefinedSpace2 (variable, optional) |
| ... |
| BitsSrc (variable) |
| ... |

**BmiSrc (variable): **The source bitmap header.

**BitsSrc (variable): **The source bitmap bits.

See section 2.3.1 for more bitmap record types.

### Clipping Record Types

The **Clipping** record types define and manage clipping regions. The clipping **regions** used by clipping record types are part of the **Regions** state element (section 3.1.1.2.1) in the **playback device context** (section 3.1).

**Note: **The EMR_SETMETARGN record does not specify parameters.

The following are the clipping record types.

| Name | Section | Description |
| --- | --- | --- |
| EMR_EXCLUDECLIPRECT | 2.3.2.1 | Specifies a clipping region that consists of the current clipping region minus the specified rectangle. |
| EMR_EXTSELECTCLIPRGN | 2.3.2.2 | Combines the specified region with the current clipping region, using the specified mode. |
| EMR_INTERSECTCLIPRECT | 2.3.2.3 | Specifies a clipping region from the intersection of the current clipping region and the specified rectangle. |
| EMR_OFFSETCLIPRGN | 2.3.2.4 | Specifies a clipping region as the current clipping region moved by a specified offset. |
| EMR_SELECTCLIPPATH | 2.3.2.5 | Specifies a clipping region as the current clipping region combined with the current **path bracket**, using the specified mode. |
| EMR_SETMETARGN | 2.3.2 | If the current metaregion is null, it is set to the current clipping region. Otherwise, the current metaregion is intersected with the current clipping region, and the result is the new metaregion.After the operation, the current clipping region is set to null.During playback, drawing occurs only within the intersection of the metaregion and clipping region.This **EMF** record specifies no parameters. |

The generic structure of clipping records is specified as follows.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ClippingRecordBuffer (variable, optional) |
| ... |

**Type (4 bytes): **An unsigned integer that defines the type of record. The clipping record types are listed in the following table. See the preceding table for descriptions of these record types.

| Name | Value |
| --- | --- |
| EMR_OFFSETCLIPRGN | 0x0000001A |
| EMR_SETMETARGN | 0x0000001C |
| EMR_EXCLUDECLIPRECT | 0x0000001D |
| EMR_INTERSECTCLIPRECT | 0x0000001E |
| EMR_SELECTCLIPPATH | 0x00000043 |
| EMR_EXTSELECTCLIPRGN | 0x0000004B |

**Size (4 bytes): **An unsigned integer that specifies the size in bytes of this record in the **metafile**. This value MUST be a multiple of 4 bytes.

**ClippingRecordBuffer (variable, optional): **An array of bytes that contains the data for the clipping record. The size of this field is a multiple of 4 bytes.

The EMR_SETMETARGN record does not contain this field.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ClippingRecordParm (variable) |
| ... |
| AlignmentPadding (variable, optional) |
| ... |

**ClippingRecordParm (variable): **An array of bytes that contains the parameters for the clipping record.

**AlignmentPadding (variable, optional): **An array of up to 3 bytes that pads the record so that its total size is a multiple of 4 bytes. This field MUST be ignored.

See section 2.3 for more EMF record types.

#### EMR_EXCLUDECLIPRECT Record

The **EMR_EXCLUDECLIPRECT** record excludes the specified rectangle from the current clipping **region**.

Fields not specified in this section are specified in section 2.3.2.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Clip |
| ... |
| ... |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_EXCLUDECLIPRECT. This value is 0x0000001D.

**Clip (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies a rectangle in logical units.

The result of the intersection is saved as the new current clipping region. The lower and right edges of the specified rectangle MUST NOT be excluded from clipping.

See section 2.3.2 for more clipping record types.

#### EMR_EXTSELECTCLIPRGN Record

The EMR_EXTSELECTCLIPRGN record combines the specified **region** with the current clipping region using the specified mode.

Fields not specified in this section are specified in section 2.3.2.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| RgnDataSize |
| RegionMode |
| RgnData (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_EXTSELECTCLIPRGN. This value is 0x0000004B.

**RgnDataSize (4 bytes): **An unsigned integer that specifies the size of the **RgnData** field in bytes.

**RegionMode (4 bytes): **An unsigned integer that specifies the way to use the region. This value is in the RegionMode (section 2.1.29) enumeration.

**RgnData (variable): **An array of bytes that specifies a **RegionData** object (section 2.2.24) in logical units. If **Region****Mode** is **RGN_COPY**, this data can be omitted and the clipping region SHOULD be set to the default clipping region.

See section 2.3.2 for more clipping record types.

#### EMR_INTERSECTCLIPRECT Record

The EMR_INTERSECTCLIPRECT record specifies a new clipping **region** from the intersection of the current clipping region and the specified rectangle.

Fields not specified in this section are specified in section 2.3.2.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Clip |
| ... |
| ... |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_INTERSECTCLIPRECT**. This value is 0x0000001E.

**Clip (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the rectangle in logical units.

The lower and right edges of the specified rectangle are excluded from the clipping region.

See section 2.3.2 for more clipping record types.

#### EMR_OFFSETCLIPRGN Record

The EMR_OFFSETCLIPRGN record moves the current clipping **region** in the **playback device context** by the specified offsets.

Fields not specified in this section are specified in section 2.3.2.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Offset |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_OFFSETCLIPRGN. This value is 0x0000001A.

**Offset (8 bytes): **A PointL object ([MS-WMF] section 2.2.2.15) that specifies the horizontal and vertical offsets in logical units.

See section 2.3.2 for more clipping record types.

#### EMR_SELECTCLIPPATH Record

The **EMR_SELECTCLIPPATH** record sets the current clipping **region** in the **playback device context** to the current clipping region combined with current **path bracket**.

Fields not specified in this section are specified in section 2.3.2.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| RegionMode |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_SELECTCLIPPATH. This value is 0x00000043.

**RegionMode (4 bytes): **An unsigned integer that specifies how to combine the current clipping region with the current path bracket. This value is in the RegionMode enumeration (section 2.1.29).

See section 2.3.2 for more clipping record types.

### Comment Record Types

The **Comment** record types define formats for specifying arbitrary private data, embedding records in other **m****etafile** formats, and adding new or special-purpose commands.

The following are **EMF** comment record types.

| Name | Section | Description |
| --- | --- | --- |
| EMR_COMMENT | 2.3.3.1 | Contains arbitrary private data. |
| EMR_COMMENT_EMFPLUS | 2.3.3.2 | Contains embedded **EMF+** records ([MS-EMFPLUS] section 2.3). |
| EMR_COMMENT_EMFSPOOL | 2.3.3.3 | Contains embedded **EMFSPOOL** records ([MS-EMFSPOOL] section 2.2). |
| EMR_COMMENT_PUBLIC | 2.3.3.4 | Specifies extensions to EMF processing. |

The generic structure of comment records is specified as follows.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| DataSize |
| CommentRecordBuffer (variable) |
| ... |

**Type (4 bytes): **An unsigned integer from the RecordType enumeration (section 2.1.1) that identifies this record as a comment record. This value is 0x00000046. 

**Size (4 bytes): **An unsigned integer that specifies the size in bytes of this record in the metafile. This value MUST be a multiple of 4 bytes. 

**DataSize (4 bytes): **An unsigned integer that specifies the size in bytes, of the **CommentIdentifier** and **CommentRecordParm** fields in the **RecordBuffer** field that follows. It MUST NOT include the size of itself or the size of the **AlignmentPadding** field, if present. 

**CommentRecordBuffer (variable): **An array of bytes that contains the remainder of the comment record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| CommentIdentifier (optional) |
| CommentRecordParm (variable) |
| ... |
| AlignmentPadding (variable, optional) |
| ... |

**CommentIdentifier (4 bytes, optional): **An unsigned integer that identifies the type of comment record. See the preceding table for descriptions of these record types.

Valid comment identifier values are listed in the following table. If this field contains any other value, the comment record is processed as an EMR_COMMENT record.

| Name | Value |
| --- | --- |
| EMR_COMMENT_EMFSPOOL | 0x00000000 |
| EMR_COMMENT_EMFPLUS | 0x2B464D45 |
| EMR_COMMENT_PUBLIC | 0x43494447 |

**CommentRecordParm (variable): **An array of bytes that contains the parameters for the comment record.

**AlignmentPadding (variable, optional): **An array of up to 3 bytes that pads the record so that its total size is a multiple of 4 bytes. This field MUST be ignored.

See section 2.3 for more EMF record types. 

#### EMR_COMMENT Record

The **EMR_COMMENT** record contains arbitrary private data.

Fields not specified in this section are specified in section 2.3.3.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| DataSize |
| PrivateData (variable, optional) |
| ... |

**PrivateData (variable, optional): **An array of bytes that specifies the private data. The first 32-bit field of this data MUST NOT be one of the predefined comment identifier values specified in section 2.3.3.

Private data is unknown to **EMF**; it is meaningful only to applications that know the format of the data and how to use it. EMR_COMMENT private data records MAY<60> be ignored.

See section 2.3.3 for more comment record types.

#### EMR_COMMENT_EMFPLUS Record

The **EMR_COMMENT_EMFPLUS** record contains embedded **EMF+** records ([MS-EMFPLUS] section 2.3).

Fields not specified in this section are specified in section 2.3.3.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| DataSize |
| CommentIdentifier |
| EMFPlusRecords (variable) |
| ... |

**CommentIdentifier (4 bytes): **An unsigned integer that identifies this comment record as containing EMF+ records. The value 0x2B464D45, which is the **ASCII** string "+FME", identifies this as an EMR_COMMENT_EMFPLUS record.

**EMFPlusRecords (variable): **An array of bytes that contains one or more EMF+ records.

See section 2.3.3 for more comment record types.

#### EMR_COMMENT_EMFSPOOL Record

The **EMR_COMMENT_EMFSPOOL** record contains embedded **EMFSPOOL** records ([MS-EMFSPOOL] section 2.2).

Fields not specified in this section are specified in section 2.3.3.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| DataSize |
| CommentIdentifier |
| EMFSpoolRecordIdentifier |
| EMFSpoolRecords (variable) |
| ... |

**CommentIdentifier (4 bytes): **An unsigned integer that identifies this comment record as containing EMFSPOOL records. The value 0x00000000 identifies this as an EMR_COMMENT_EMFSPOOL record.

**EMFSpoolRecordIdentifier (4 bytes): **An unsigned integer that identifies the type of EMR_COMMENT_EMFSPOOL record. The value 0x544F4E46, which is the **ASCII** string "TONE", identifies this as an EMFSPOOL font definition record ([MS-EMFSPOOL] section 2.2.3.3).

**EMFSpoolRecords (variable): **An array of bytes that contain one or more font definition records.

See section 2.3.3 for more comment record types.

#### EMR_COMMENT_PUBLIC Record Types

The **EMR_COMMENT_PUBLIC** record types specify extensions to **EMF** processing.

Following are the EMF public comment record types that have been defined.

| Name | Section | Description |
| --- | --- | --- |
| EMR_COMMENT_BEGINGROUP | 2.3.3.4.1 | Specifies the beginning of a group of drawing records. |
| EMR_COMMENT_ENDGROUP | 2.3.3.4.2 | Specifies the end of a group of drawing records. |
| EMR_COMMENT_MULTIFORMATS | 2.3.3.4.3 | Specifies an image in multiple graphics formats. |
| EMR_COMMENT_WINDOW_METAFILE | 2.3.3.4.4 | Specifies an image in an embedded **WMF** **metafile**. |

The generic structure of EMR_COMMENT_PUBLIC records is specified as follows.

Fields not specified in this section are specified in section 2.3.3.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| DataSize |
| CommentIdentifier |
| PublicCommentIdentifier |
| PublicCommentRecordBuffer (variable, optional) |
| ... |

**CommentIdentifier (4 bytes): **An unsigned integer that identifies this comment record as specifying public data. The value 0x43494447, which is the **ASCII** string "CIDG", identifies this as an EMR_COMMENT_PUBLIC record.

**Public****CommentIdentifier (4 bytes): **An unsigned integer that identifies the type of public comment record. This SHOULD be one of the values listed in the preceding table, which are specified in the EmrComment enumeration (section 2.1.10), unless additional public comment record types have been implemented on the **print server**.

**PublicCommentRecordBuffer (variable, optional): **An array of bytes that contains the remainder of the public comment record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PublicCommentRecordParm (variable) |
| ... |
| AlignmentPadding (variable, optional) |
| ... |

**PublicCommentRecordParm (variable): **An array of bytes that contains the parameters for the public comment record.

**AlignmentPadding (variable, optional): **An array of up to 3 bytes that pads the record so that its total size is a multiple of 4 bytes. This field MUST be ignored.

See section 2.3.3 for more comment record types.

##### EMR_COMMENT_BEGINGROUP Record

The **EMR_COMMENT_BEGINGROUP** record specifies the beginning of a group of drawing records.

Fields not specified in this section are specified in section 2.3.3 or 2.3.3.4.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| DataSize |
| CommentIdentifier |
| PublicCommentIdentifier |
| Rectangle |
| ... |
| ... |
| ... |
| nDescription |
| Description (variable, optional) |
| ... |

**PublicCommentIdentifier (4 bytes): **An unsigned integer that identifies the type of public comment record as EMR_COMMENT_BEGINGROUP from the EmrComment enumeration (section 2.1.10). This value is 0x00000002.

**Rectangle (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the output rectangle in logical coordinates.

**nDescription (4 bytes): **The number of **Unicode** characters in the optional description string that follows.

**Description (variable, optional): **A null-terminated Unicode string that describes this group of records.

This record MUST be followed by a corresponding EMR_COMMENT_ENDGROUP record (section 2.3.3.4.2). These record groups can be nested.

See section 2.3.3.4 for more public comment record types.

##### EMR_COMMENT_ENDGROUP Record

The **EMR_COMMENT_ENDGROUP** record specifies the end of a group of drawing records.

Fields not specified in this section are specified in section 2.3.3 or 2.3.3.4.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| DataSize |
| CommentIdentifier |
| PublicCommentIdentifier |

**PublicCommentIdentifier (4 bytes): **An unsigned integer that identifies the type of public comment record as EMR_COMMENT_ENDGROUP from the EmrComment enumeration (section 2.1.10). This value is 0x00000003.

This record MUST be preceded by a corresponding. EMR_COMMENT_BEGINGROUP (section 2.3.3.4.1). These records can be nested.

See section 2.3.3.4 for more public comment record types.

##### EMR_COMMENT_MULTIFORMATS Record

The **EMR_COMMENT_MULTIFORMATS** record specifies an image in multiple graphics formats.

Fields not specified in this section are specified in section 2.3.3 or 2.3.3.4.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| DataSize |
| CommentIdentifier |
| PublicCommentIdentifier |
| OutputRect |
| ... |
| ... |
| ... |
| CountFormats |
| aFormats (variable) |
| ... |
| FormatData (variable) |
| ... |

**PublicCommentIdentifier (4 bytes): **An unsigned integer that identifies the type of public comment record as EMR_COMMENT_MULTIFORMATS from the EmrComment enumeration (section 2.1.10). This value is 0x40000004.

**OutputRect (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the output rectangle, in logical coordinates.

**CountFormats (4 bytes): **An unsigned integer that specifies the number of graphics formats contained in this record.

**aFormats (variable): **A **CountFormats** length array of graphics formats, specified by EmrFormat objects (section 2.2.4) in order of preference.

**FormatData (variable): **The image data for all graphics formats contained in this record.

The size of the data for each image is specified by the **DataSize** field in the corresponding EmrFormat object. Thus, the total size of this field is the sum of **DataSize** values in all EmrFormat objects.

The graphics format of the data for each image is specified by the **Signature** field in the corresponding EmrFormat object.

For example, an application can use this record type to specify an image in **EPS** format using EpsData objects (section 2.2.6). Subsequently, the **PostScript** version of the image can be rendered if that graphics format is supported by the **printer driver** on the playback system.<61>

See section 2.3.3.4 for more public comment record types.

##### EMR_COMMENT_WINDOWS_METAFILE Record

The **EMR_COMMENT_WINDOWS_METAFILE** record specifies an image in an embedded **WMF** **metafile**.

Fields not specified in this section are specified in section 2.3.3 or 2.3.3.4.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| DataSize |
| CommentIdentifier |
| PublicCommentIdentifier |
| Version | Reserved |
| Checksum |
| Flags |
| WinMetafileSize |
| WinMetafile (variable) |
| ... |

**PublicCommentIdentifier (4 bytes): **An unsigned integer that identifies the type of public comment record as EMR_COMMENT_WINDOWS_METAFILE from the EmrComment enumeration (section 2.1.10). This value is 0x80000001.

**Version (2 bytes): **An unsigned integer that specifies the WMF metafile version in terms of support for DIBs, from the MetafileVersion enumeration ([MS-WMF] section 2.1.1.19).

**Reserved (2 bytes): **A value that MUST be 0x0000 and MUST be ignored.

**Checksum (4 bytes): **An unsigned integer that specifies the checksum for this record.

**Flags (4 byt****es): **A value that MUST be 0x00000000 and MUST be ignored.

**WinMetafileSize (4 bytes): **An unsigned integer that specifies the size in bytes, of the **WinMetafile** field.

**WinMetafile (variable): **A buffer that contains the WMF metafile.

See section 2.3.3.4 for more public comment record types.

### Control Record Types

The **Control **record types define the start and end of an **EMF** **metafile** and its properties.

The following are EMF control record types.

| Name | Section | Description |
| --- | --- | --- |
| EMR_EOF | 2.3.4.1 | Indicates the end of the metafile and specifies a **palette**. |
| EMR_HEADER | 2.3.4.2 | Indicates the start of the metafile and specifies properties of the device on which the metafile was created. |

The generic structure of control records is specified as follows.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| RecordBuffer (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that defines the type of record. The control record types are listed in the following table. See the preceding table for descriptions of these record types.

| Name | Value |
| --- | --- |
| EMR_HEADER | 0x00000001 |
| EMR_EOF | 0x0000000E |

**Size (4 bytes): **An unsigned integer that specifies the size in bytes of this record in the metafile. This value MUST be a multiple of 4 bytes. 

**RecordBuffer (variable): **An array of bytes that contains the remainder of the control record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ControlRecordParm (variable) |
| ... |
| AlignmentPadding (variable, optional) |
| ... |

**ControlRecordParm (variable): **An array of bytes that contains the parameters for the control record.

**AlignmentPadding (variable, optional): **An array of up to 3 bytes that pads the record so that its total size is a multiple of 4 bytes. This field MUST be ignored.

See section 2.3 for more EMF record types. 

#### EMR_EOF Record

The **EMR_EOF **record indicates the end of the **metafile** and specifies a **palette**.

Fields not specified in this section are specified in section 2.3.4.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| nPalEntries |
| offPalEntries |
| PaletteBuffer (variable, optional) |
| ... |
| SizeLast |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_EOF. This value is 0x0000000E.

**nPalEntries (4 bytes): **An unsigned integer that specifies the number of palette entries.

**offPalEntries (4 bytes): **An unsigned integer that specifies the offset to the palette entries from the start of this record.

**PaletteBuffer (variable, optional): **An array of bytes that contains palette data, which is not required to be contiguous with the fixed-length portion of the EMR_EOF record. Thus, fields in this buffer that are labeled "UndefinedSpace" are optional and MUST be ignored.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UndefinedSpace1 (variable, optional) |
| ... |
| PaletteEntries (variable) |
| ... |
| UndefinedSpace2 (variable, optional) |
| ... |

**PaletteEntries (variable): **An array of LogPaletteEntry objects (section 2.2.18) that specifies the palette data.

**SizeLast (4 bytes): **An unsigned integer that MUST be the same as **Size** and MUST be the last field of the record and hence the metafile. LogPaletteEntry objects, if they exist, MUST precede this field.

See section 2.3.4 for more control record types.

#### EMR_HEADER Record Types

The **EMR_HEADER **record is the starting point of an **EMF** **metaf****ile**. It specifies properties of the device on which the image in the metafile was recorded; this information in the header record makes it possible for EMF metafiles to be independent of any specific output device.

The following are the EMR_HEADER record types.

| Name | Section | Description |
| --- | --- | --- |
| EmfMetafileHeader | 2.3.4.2.1 | The original EMF header record. |
| EmfMetafileHeaderExtension1 | 2.3.4.2.2 | The header record defined in the first extension to EMF, which added support for **OpenGL** records and an optional internal pixel format descriptor.<62> |
| EmfMetafileHeaderExtension2 | 2.3.4.2.3 | The header record defined in the second extension to EMF, which added the capability of measuring display dimensions in micrometers.<63> |

EMF metafiles SHOULD be created with an **EmfMetafileHeaderExtension2** header record.

The generic structure of EMR_HEADER records is specified as follows.

Fields not specified in this section are specified in section 2.3.4. 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| EmfHeader (80 bytes) |
| ... |
| ... |
| ... |
| EmfHeaderRecordBuffer (variable, optional) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_HEADER**. This value is 0x00000001. 

**EmfHeader (80 bytes): **A Header object (section 2.2.9), which contains information about the content and structure of the metafile. 

**EmfHeaderRecordBuffer (variable, optional): **An array of bytes that contains the remainder of the EMF header record. 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| EmfHeaderRecordParm (variable) |
| ... |
| AlignmentPadding (variable, optional) |
| ... |

**EmfHeaderRecordParm (variable): **An array of bytes that contains additional parameters for the EMF header record.

**AlignmentPadding (variable, optional): **An array of up to 3 bytes that pads the record so that its total size is a multiple of 4 bytes. This field MUST be ignored.

The value of the **Size** field can be used to distinguish between the different EMR_HEADER record types listed earlier in this section. There are three possible headers: 

The EmfMetafileHeader record. The fixed-size part of this header is 88 bytes, and it contains a Header object (section 2.2.9). 

The EmfMetafileHeaderExtension1 record. The fixed-size part of this header is 100 bytes, and it contains a Header object and a HeaderExtension1 object (section 2.2.10). 

The EmfMetafileHeaderExtension2 record. The fixed-size part of this header is 108 bytes, and it contains a Header object, a HeaderExtension1 object, and a HeaderExtension2 object (section 2.2.11). 

There are one or two optional, variable-length fields that are possible in each header: a description string and a pixel format field. In all three types of headers, the fixed-size part comes first, followed by the variable-length fields.

The algorithm shown in the following figure computes a non-negative integer variable called **HeaderSize** from the offsets and lengths of the variable-length data. The type of header is determined from that value. 

Figure 3: Header type determination algorithm

After applying the algorithm, consider the value of **HeaderSize** field:

 If **HeaderSize** >= 108, the record type is EmfMetafileHeaderExtension2. 

 If **HeaderSize** >= 100, the record type is EmfMetafileHeaderExtension1. 

 Otherwise, the record type is EmfMetafileHeader. 

 See section 2.3.4 for more control record types. 

##### EmfMetafileHeader Record

The **EmfMetafileHeader **record is the header record used in the original version of **EMF** **metafiles**.

Fields not specified in this section are specified in section 2.3.4 or 2.3.4.2.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| EmfHeader (80 bytes) |
| ... |
| ... |
| ... |
| EmfDescriptionBuffer (variable, optional) |
| ... |

**EmfDescriptionBuffer (variable, optional): **An array of bytes that contains the EMF description string, which is not required to be contiguous with the fixed portion of this record. Thus, the undefined space field in this buffer is optional and MUST be ignored.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UndefinedSpace (variable, optional) |
| ... |
| EmfDescription (variable) |
| ... |

**EmfDescription (variable): **A null-terminated **Unicode** **UTF16-LE** string of arbitrary length and content. Its location in the record and number of characters are specified by the **offDescription** and **nDescription** fields, respectively, in **EmfHea****der**. If the value of either field is zero, no description string is present.

The value of the **Size** field can be used to distinguish between the different EMR_HEADER record types. See the flowchart in section 2.3.4.2 for details.

See section 2.3.4.2 for more header record types.

##### EmfMetafileHeaderExtension1 Record

The **EmfMetafileHeaderExtension1 **record is the header record used in the first extension to **EMF** **metafiles**. Following the **EmfHeaderExtension1** field, the remaining fields are optional and can be present in any order.

Fields not specified in this section are specified in section 2.3.4 or 2.3.4.2.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| EmfHeader (80 bytes) |
| ... |
| ... |
| ... |
| EmfHeaderExtension1 |
| ... |
| ... |
| EmfDescriptionBuffer (variable, optional) |
| ... |
| EmfPixelFormatBuffer (variable, optional) |
| ... |

**EmfHeaderExtension1 (12 bytes): **A HeaderExtension1 object (section 2.2.10), which specifies additional information about the image in the metafile.

**EmfDescriptionBuffer (variable, optional): **An array of bytes that contains the EMF description string, which is not required to be contiguous with the fixed-length part of this record. Thus, the undefined space field in this buffer is optional and MUST be ignored.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UndefinedSpace (variable, optional) |
| ... |
| EmfDescription (variable) |
| ... |

**EmfDescription (variable): **A null-terminated **Unicode** **UTF16****-LE** string of arbitrary length and content. Its location in the record and number of characters are specified by the **offDescription** and **nDescription** fields, respectively, in **EmfHeader**. If the value of either field is zero, no description string is present.

**EmfPixelFormatBuffer (variable, optional): **An array of bytes that contains the EMF pixel format descriptor. It is not required to be contiguous with the **EmfHeaderExtension1** or **EmfDescription** fields. Thus, the undefined space field in this buffer is optional and MUST be ignored.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UndefinedSpace2 (variable, optional) |
| ... |
| EmfPixelFormat (40 bytes) |
| ... |
| ... |
| ... |

**EmfPixelFormat (40 bytes): **A PixelFormatDescriptor object (section 2.2.22), which specifies the pixel format that was defined when the metafile was recorded. Its size and location in the record are specified by the **cbPixelFormat** and **offPixelFormat** fields, respectively, in **EmfHeaderExtension1**. If the value of either field is zero, no pixel format descriptor is present.

**Note: **No single structure definition can accurately represent every possible combination of optional fields. Therefore, the implementer is responsible for writing software that determines which fields are present in each metafile and for unmarshaling the contents of each field appropriately.

The value of the **Size** field can be used to distinguish between the different EMR_HEADER record types. See the flowchart in section 2.3.4.2 for details.

##### EmfMetafileHeaderExtension2 Record

The **Em****fMetafileHeaderExtension2** record is the header record used in the second extension to **EMF** **metafiles**. Following the **EmfHeaderExtensio****n2** field, the remaining fields are optional and can be present in any order.

Fields not specified in this section are specified in section 2.3.4 or 2.3.4.2.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| EmfHeader (80 bytes) |
| ... |
| ... |
| ... |
| EmfHeaderExtension1 |
| ... |
| ... |
| EmfHeaderExtension2 |
| ... |
| EmfDescriptionBuffer (variable, optional) |
| ... |
| EmfPixelFormatBuffer (variable, optional) |
| ... |

**EmfHeaderExtension1 (12 bytes): **A HeaderExtension1 object (section 2.2.10), which specifies additional information about the image in the metafile.

**EmfHeaderExtension2 (8 bytes): **A HeaderExtension2 object (section 2.2.11), which specifies additional information about the image in the metafile.

**EmfDescriptionBuffer (variable, optional): **An array of bytes that contains the EMF description string, which is not required to be contiguous with the fixed portion of the EmfMetafileHeaderExtension2 record. Thus, the undefined space field in this buffer is optional and MUST be ignored.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UndefinedSpace1 (variable, optional) |
| ... |
| EmfDescription (variable) |
| ... |

**EmfDescription (variable): **A null-terminated **Unicode** **UTF16-LE** string of arbitrary length and content. Its location in the record and number of characters are specified by the **offDescription** and **nDescription** fields, respectively, in **EmfHeader**. If the value of either field is zero, no description string is present.

**EmfPixelFormatBuffer (variable, optional): **An array of bytes that contains the EMF pixel format descriptor, which is not required to be contiguous with the fixed portion of the EmfMetafileHeaderExtension2 record or with the EMF description string. Thus, the field in this buffer that is labeled "UndefinedSpace" is optional and MUST be ignored.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UndefinedSpace2 (variable, optional) |
| ... |
| EmfPixelFormat (40 bytes) |
| ... |
| ... |
| ... |

**EmfPixelFormat (40 bytes): **A PixelFormatDescriptor object (section 2.2.22) that specifies the last pixel format that was defined when the metafile was recorded. Its size and location in the record are specified by the **cbPixelFormat** and **offPixelFormat** fields, respectively, in **EmfHeaderExtension1**. If the value of either field is zero, no pixel format descriptor is present.

**Note: **No single structure definition can accurately represent every possible combination of optional fields. Therefore, the implementer is responsible for writing software that determines which fields are present in each metafile, and for unmarshaling the contents of each field appropriately.

The value of the **Size** field can be used to distinguish between the different EMR_HEADER record types. See the flowchart in section 2.3.4.2 for details.

### Drawing Record Types

The **Drawing **record types perform graphics drawing and painting functions. The clipping **regions** used by drawing records are maintained in the **Regions** state element (section 3.1.1.2.1) in the **playback device context** (section 3.1).

The following are **EMF** drawing record types.

| Name | Section | Description |
| --- | --- | --- |
| EMR_ANGLEARC | 2.3.5.1 | Draws a line segment of an arc. |
| EMR_ARC | 2.3.5.2 | Draws an elliptical arc. |
| EMR_ARCTO | 2.3.5.3 | Draws an elliptical arc, resetting the current drawing position to the endpoint of the arc. |
| EMR_CHORD | 2.3.5.4 | Draws a chord, which is a region bounded by the intersection of an ellipse and a line segment, called a secant. |
| EMR_ELLIPSE | 2.3.5.5 | Draws an ellipse. |
| EMR_EXTFLOODFILL | 2.3.5.1 | Draws a line segment of an arc. |
| EMR_EXTTEXTOUTA | 2.3.5.7 | Draws an **ASCII** text string using the current font and text colors. |
| EMR_EXTTEXTOUTW | 2.3.5.8 | Draws a **Unicode** text string using the current font and text colors. |
| EMR_FILLPATH | 2.3.5.9 | Closes any open figures in the current **path bracket** and fills the path's interior with the current brush. |
| EMR_FILLRGN | 2.3.5.10 | Fills the specified region with the specified brush. |
| EMR_FRAMERGN | 2.3.5.11 | Draws a border around the specified region with the specified brush. |
| EMR_GRADIENTFILL | 2.3.5.12 | Fills the specified rectangle and triangle structures. |
| EMR_LINETO | 2.3.5.13 | Draws a line from the current position up to, but not including, the specified point. This record resets the current position to that point. |
| EMR_PAINTRGN | 2.3.5.14 | Paints the specified region with the current brush. |
| EMR_PIE | 2.3.5.15 | Draws a pie-shaped wedge bounded by the intersection of an ellipse and two radials. |
| EMR_POLYBEZIER | 2.3.5.16 | Draws one or more **Bezier curves**. The cubic Bezier curves are defined with the endpoints and control points specified in this record. |
| EMR_POLYBEZIER16 | 2.3.5.17 | Draws one or more Bezier curves with the current pen. |
| EMR_POLYBEZIERTO | 2.3.5.18 | Draws one or more Bezier curves based on the current position. |
| EMR_POLYBEZIERTO16 | 2.3.5.19 | Draws one or more Bezier curves based on the current position. |
| EMR_POLYDRAW | 2.3.5.20 | Draws a set of line segments and Bezier curves. |
| EMR_POLYDRAW16 | 2.3.5.21 | Draws a set of line segments and Bezier curves. |
| EMR_POLYGON | 2.3.5.22 | Draws a polygon consisting of two or more vertexes connected by straight lines. |
| EMR_POLYGON16 | 2.3.5.23 | Draws a polygon consisting of two or more vertexes connected by straight lines. |
| EMR_POLYLINE | 2.3.5.24 | Draws a series of line segments by connecting the points in the specified array. |
| EMR_POLYLINE16 | 2.3.5.25 | Draws a series of line segments by connecting the points in the specified array. |
| EMR_POLYLINETO | 2.3.5.26 | Draws one or more straight lines based upon the current position. |
| EMR_POLYLINETO16 | 2.3.5.27 | Draws one or more straight lines based upon the current position. |
| EMR_POLYPOLYGON | 2.3.5.28 | Paints a series of closed polygons. Each polygon is outlined with the current pen and filled with the current brush and polygon fill mode. |
| EMR_POLYPOLYGON16 | 2.3.5.29 | Paints a series of closed polygons. Each polygon is outlined with the current pen and filled with the current brush and polygon fill mode. |
| EMR_POLYPOLYLINE | 2.3.5.30 | Draws multiple series of connected line segments. |
| EMR_POLYPOLYLINE16 | 2.3.5.31 | Draws multiple series of connected line segments. |
| EMR_POLYTEXTOUTA | 2.3.5.32 | Draws one or more ASCII text strings using the current font and text colors. |
| EMR_POLYTEXTOUTW | 2.3.5.33 | Draws one or more Unicode text strings using the current font and text colors. |
| EMR_RECTANGLE | 2.3.5.34 | Draws a rectangle. The rectangle is outlined with the current pen and filled with the current brush. |
| EMR_ROUNDRECT | 2.3.5.35 | Draws a rectangle with rounded corners. |
| EMR_SETPIXELV | 2.3.5.36 | Defines the color of the pixel at the specified logical coordinates. |
| EMR_SMALLTEXTOUT | 2.3.5.37 | Outputs a string. |
| EMR_STROKEANDFILLPATH | 2.3.5.38 | Closes any open figures in a path, draws the outline of the path with the current pen, and fills its interior with the current brush. |
| EMR_STROKEPATH | 2.3.5.39 | Draws the specified path with the current pen. |

The generic structure of drawing records is specified as follows.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| DrawingRecordBuffer (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that defines the type of record. The drawing record types are listed in the following table. See the preceding table for descriptions of these records.

| Name | Value |
| --- | --- |
| EMR_POLYBEZIER | 0x00000002 |
| EMR_POLYGON | 0x00000003 |
| EMR_POLYBEZIERTO | 0x00000005 |
| EMR_POLYLINETO | 0x00000006 |
| EMR_POLYPOLYLINE | 0x00000007 |
| EMR_POLYPOLYGON | 0x00000008 |
| EMR_SETPIXELV | 0x0000000F |
| EMR_ANGLEARC | 0x00000029 |
| EMR_ELLIPSE | 0x0000002A |
| EMR_RECTANGLE | 0x0000002B |
| EMR_ROUNDRECT | 0x0000002C |
| EMR_ARC | 0x0000002D |
| EMR_CHORD | 0x0000002E |
| EMR_PIE | 0x0000002F |
| EMR_EXTFLOODFILL | 0x00000035 |
| EMR_LINETO | 0x00000036 |
| EMR_ARCTO | 0x00000037 |
| EMR_POLYDRAW | 0x00000038 |
| EMR_FILLPATH | 0x0000003E |
| EMR_STROKEANDFILLPATH | 0x0000003F |
| EMR_STROKEPATH | 0x00000040 |
| EMR_FILLRGN | 0x00000047 |
| EMR_FRAMERGN | 0x00000048 |
| EMR_PAINTRGN | 0x0000004A |
| EMR_EXTTEXTOUTA | 0x00000053 |
| EMR_EXTTEXTOUTW | 0x00000054 |
| EMR_POLYBEZIER16 | 0x00000055 |
| EMR_POLYGON16 | 0x00000056 |
| EMR_POLYLINE16 | 0x00000057 |
| EMR_POLYBEZIERTO16 | 0x00000058 |
| EMR_POLYLINETO16 | 0x00000059 |
| EMR_POLYPOLYLINE16 | 0x0000005A |
| EMR_POLYPOLYGON16 | 0x0000005B |
| EMR_POLYDRAW16 | 0x0000005C |
| EMR_POLYTEXTOUTA | 0x00000060 |
| EMR_POLYTEXTOUTW | 0x00000061 |
| EMR_SMALLTEXTOUT | 0x0000006C |
| EMR_GRADIENTFILL | 0x00000076 |

**Size (4 bytes): **An unsigned integer that specifies the size in bytes of this record in the **metafile**. This value MUST be a multiple of 4 bytes.

**DrawingRecordBuffer (variable): **An array of bytes that contains the remainder of the drawing record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DrawingRecordParm (variable) |
| ... |
| AlignmentPadding (variable, optional) |
| ... |

**DrawingRecordParm (variable): **An array of bytes that contains the parameters for the drawing record.

**AlignmentPadding (variable, optional): **An array of up to 3 bytes that pads the record so that its total size is a multiple of 4 bytes. This field MUST be ignored.

See section 2.3 for more EMF record types.

#### EMR_ANGLEARC Record

The EMR_ANGLEARC record specifies a line segment of an arc. The line segment is drawn from the current position to the beginning of the arc. The arc is drawn along the perimeter of a circle with the given radius and center. The length of the arc is defined by the given start and sweep angles.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Center |
| ... |
| Radius |
| StartAngle |
| SweepAngle |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_ANGLEARC**. This value is 0x00000029.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Center (8 bytes): **A PointL object ([MS-WMF] section 2.2.2.15), which specifies the logical coordinates of the circle's center.

**Radius (4 bytes): **An unsigned integer that specifies the circle's radius, in logical units.

**StartAngle (4 bytes): **A 32-bit float that specifies the arc's start angle, in degrees.

**SweepAngle (4 bytes): **A 32-bit float that specifies the arc's sweep angle, in degrees.

The arc is drawn by recording an imaginary circle around the specified center point with the specified radius. The starting point of the arc is determined by measuring counterclockwise from the x-axis of the circle by the number of degrees in the start angle. The ending point is similarly located by measuring counterclockwise from the starting point by the number of degrees in the sweep angle.

If the sweep angle is greater than 360 degrees, the arc is swept multiple times.

This record specifies lines by using the current pen. The figure is not filled.

See section 2.3.5 for more drawing record types.

#### EMR_ARC Record

The EMR_ARC record specifies an elliptical arc.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Box |
| ... |
| ... |
| ... |
| Start |
| ... |
| End |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_ARC**. This value is 0x0000002D.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Box (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19), which specifies the **inclusive-inclusive** bounding rectangle in logical units.

**Start (8 bytes): **A PointL object ([MS-WMF] section 2.2.2.15), which specifies the coordinates in logical units of the ending point of the radial line defining the starting point of the arc.

**End (8 bytes): **A PointL object that specifies the coordinates in logical units of the ending point of the radial line defining the ending point of the arc.

See section 2.3.5 for more drawing record types.

#### EMR_ARCTO Record

The EMR_ARCTO record specifies an elliptical arc. It resets the current drawing position to the endpoint of the arc.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Box |
| ... |
| ... |
| ... |
| Start |
| ... |
| End |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_ARCTO**. This value is 0x00000037.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Box (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19), which specifies the **inclusive-inclusive** bounding rectangle in logical units.

**Start (8 byte****s): **A PointL object ([MS-WMF] section 2.2.2.15), which specifies the coordinates, in logical units, of the first radial ending point, in logical units.

**End (8 bytes): **A PointL object that specifies the coordinates of the second radial ending point, in logical units.

See section 2.3.5 for more drawing record types.

#### EMR_CHORD Record

The EMR_CHORD record specifies a chord, which is a **region** bounded by the intersection of an ellipse and a line segment, called a secant. The chord is outlined by using the current pen and filled by using the current brush.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Box |
| ... |
| ... |
| ... |
| Start |
| ... |
| End |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_CHORD**. This value is 0x0000002E.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Box (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19), which specifies the **inclusive-incl****usive** bounding rectangle in logical units.

**Start (8 bytes): **A PointL object ([MS-WMF] section 2.2.2.15), which specifies the coordinates, in logical units, of the endpoint of the radial defining the beginning of the chord.

**End (8 bytes): **A PointL object that specifies the logical coordinates of the endpoint of the radial defining the end of the chord.

The curve of the chord is defined by an ellipse that fits the specified bounding rectangle. The curve begins at the point where the ellipse intersects the first radial and extends counterclockwise to the point where the ellipse intersects the second radial. The chord is closed by drawing a line from the intersection of the first radial and the curve to the intersection of the second radial and the curve.

If the starting point and ending point of the curve are the same, a complete ellipse is drawn.

The current drawing position is neither used nor updated by processing this record.

See section 2.3.5 for more drawing record types.

#### EMR_ELLIPSE Record

The EMR_ELLIPSE record specifies an ellipse. The center of the ellipse is the center of the specified bounding rectangle. The ellipse is outlined by using the current pen and is filled by using the current brush.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Box |
| ... |
| ... |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_ELLIPSE**. This value is 0x0000002A.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Box (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19), which specifies the **inclusive-inclusive** bounding rectangle in logical units.

See section 2.3.5 for more drawing record types.

#### EMR_EXTFLOODFILL Record

The EMR_EXTFLOODFILL record fills an area of the display surface with the current brush.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Start |
| ... |
| Color |
| FloodFillMode |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_EXTFLOODFILL**. This value is 0x00000035.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Start (8 bytes): **A PointL object ([MS-WMF] section 2.2.2.15), which specifies the coordinates, in logical units, where filling begins.

**Color (4 bytes): **A **ColorRef** object ([MS-WMF] section 2.2.2.8), which is used with the **FloodFillMode** to determine the area to fill.

**FloodFillMode (4 bytes): **An unsigned integer that specifies how to use the **Color** value to determine the area for the flood fill operation. This value is in the FloodFill enumeration (section 2.1.13).

See section 2.3.5 for more drawing record types.

#### EMR_EXTTEXTOUTA Record

The **EMR_****EXTTEXTOUTA **record draws an **ASCII** text string using the current font and text colors.

Fields not specified in this section are specified in section 2.3.5.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| iGraphicsMode |
| exScale |
| eyScale |
| aEmrText (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies the record type as EMR_EXTTEXTOUTA from the RecordType enumeration (section 2.1.1). This value is 0x00000053.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19), which is not used and MUST be ignored on receipt.

**iGraphicsMode (4 bytes): **An unsigned integer that specifies the graphics mode from the GraphicsMode enumeration (section 2.1.16).

**exScale (4 bytes): **A FLOAT value that specifies the scale factor to apply along the X axis to convert from **page space** units to .01mm units. This SHOULD be used only if the graphics mode specified by **iGraphicsMode** is GM_COMPATIBLE.

**eyScale (4 bytes): **A FLOAT value that specifies the scale factor to apply along the Y axis to convert from page space units to .01mm units. This SHOULD be used only if the graphics mode specified by **iGraphicsMode** is GM_COMPATIBLE.

**aEmrText (variable): **An EmrText object (section 2.2.5) that specifies the output string in 8-bit ASCII characters, text attributes, and spacing values.

The font and text colors used for output are specified by the state of the current graphics environment (section 3.1.1.2). A rectangle for clipping and/or opaquing can be defined in the EmrText object in the **aEmrText** field.

This record SHOULD<64> be emulated with an EMR_EXTTEXTOUTW record (section 2.3.5.8), which requires the ASCII text string in the EmrText object to be converted to **Unicode** **UTF16-LE** encoding.

See section 2.3.5 for more drawing record types.

#### EMR_EXTTEXTOUTW Record

The EMR_EXTTEXTOUTW record draws a **Unicode** text string using the current font and text colors.

Fields not specified in this section are specified in section 2.3.5.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| iGraphicsMode |
| exScale |
| eyScale |
| wEmrText (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies the record type as **EMR_EXTTEXTOUTW** from the RecordType enumeration (section 2.1.1). This value is 0x00000054.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19). It is not used and MUST be ignored on receipt.

**iG****raphicsMode (4 bytes): **An unsigned integer that specifies the current graphics mode from the GraphicsMode enumeration (section 2.1.16).

**exScale (4 bytes): **A FLOAT value that specifies the scale factor to apply along the X axis to convert from **page space** units to .01mm units. This is used only if the graphics mode specified by **iGraphicsMode** is **GM_COMPATIBLE**.

**eyScale (4 bytes): **A FLOAT value that specifies the scale factor to apply along the Y axis to convert from page space units to .01mm units. This is used only if the graphics mode specified by **iGraphicsMode** is **GM_COMPATIBLE**.

**wEmrText (variable): **An EmrText object (section 2.2.5) that specifies the output string in Unicode **UTF16-LE** characters, with text attributes and spacing values.

The font and text colors used for output are specified by properties in the current state of EMF metafile playback (section 3.1). A rectangle for clipping and/or opaquing can be defined in the EmrText object that is specified in the **aEmrText** field.

See section 2.3.5 for more drawing record types.

#### EMR_FILLPATH Record

The EMR_FILLPATH record closes any open figures in the current **path bracket** and fills the path's interior by using the current brush and polygon-filling mode.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_FILLPATH**. This value is 0x0000003E.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19), which specifies the bounding rectangle in logical units.

See section 2.3.5 for more drawing record types.

#### EMR_FILLRGN Record

The EMR_FILLRGN record fills the specified **region** by using the specified brush. The current clipping regions used by this record are maintained in a **Regions** state element (section 3.1.1.2.1) in the **playback device context** (section 3.1).

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| RgnDataSize |
| ihBrush |
| RgnData (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_FILLRGN**. This value is 0x00000047.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the destination bounding rectangle in logical units. If the intersection of this rectangle with the current clipping region is empty, this record has no effect.

**RgnDataSize (4 bytes): **An unsigned integer that specifies the size of region data in bytes.

**ihBrush (4 bytes): **An unsigned integer that specifies the index of the brush in the EMF object table (section 3.1.1.1) for filling the region.

**RgnData (variable): **A **RgnDataSize** length array of bytes that specifies the output region in a **RegionData** object (section 2.2.24). The bounds specified by the **RegionDataHeader** field of this object MAY<65> be used as the bounding region when this record is processed.

See section 2.3.5 for more drawing record types.

#### EMR_FRAMERGN Record

The EMR_FRAMERGN record draws a border around the specified **region** using the specified brush. The current clipping regions used by this record are maintained in a **Regio****ns** state element (section 3.1.1.2.1) in the **playback device context** (section 3.1).

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| RgnDataSize |
| ihBrush |
| Width |
| Height |
| RgnData (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_FRAMERGN**. This value is 0x00000048.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the destination bounding rectangle in logical coordinates. If the intersection of this rectangle with the current clipping region is empty, this record has no effect.

**RgnDataSize (4 bytes): **An unsigned integer that specifies the size of region data in bytes.

**ihBrush (4 bytes): **An unsigned integer that specifies the index of the brush in the EMF object table index.

**Width (4 bytes): **A signed integer that specifies the width of the vertical brush stroke, in logical units.

**Height (4 bytes): **A signed integer that specifies the height of the horizontal brush stroke, in logical units.

**RgnData (variable): **A **RgnDataSize** length array of bytes that specifies the output region in a **RegionData** object (section 2.2.24). The bounds specified by the **RegionDataHeader** field of this object MAY<66> be used as the bounding region when this record is processed.

See section 2.3.5 for more drawing record types.

#### EMR_GRADIENTFILL Record

The **EMR_GRADIENTFILL** record specifies filling rectangles or triangles with gradients of color.<67>

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| nVer |
| nTri |
| ulMode |
| VertexData (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_GRADIENTFILL. This value is 0x00000076.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Bounds (16 b****ytes): **A RectL object ([MS-WMF] section 2.2.2.19), which specifies the **inclusive-inclusive** bounding rectangle in logical units.

**nVer (4 bytes): **An unsigned integer that specifies the number of vertexes.

**nTri (4 bytes): **An unsigned integer that specifies the number of rectangles or triangles to fill.

**ulMode (4 bytes): **An unsigned integer that specifies the gradient fill mode. This value is in the GradientFill enumeration (section 2.1.15).

**VertexData (variable): **Objects that specify the vertexes of either rectangles or triangles and the colors that correspond to them.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| VertexObjects (variable) |
| ... |
| VertexIndexes (variable) |
| ... |
| VertexPadding (variable, optional) |
| ... |

**VertexObjects (variable): **An array of **nVer** TriVertex objects (section 2.2.26). Each object specifies the position and color of a vertex of either a rectangle or a triangle, depending on the value of the **ulMode** field.

**VertexIndexes (variable)****: **An array of **nTri** GradientRectangle objects (section 2.2.7) or GradientTriangle objects (section 2.2.8), depending on the value of the **ulMode** field. Each object specifies indexes into the array of TriVertex objects in the **VertexObjects** field.

**VertexPadding (variable, optional): **An array of **nTri** times four bytes that MUST be present if the value of the **ulMode** field indicates GradientRectangle objects (section 2.2.7). If the value of the **ulMode** field indicates GradientTriangle objects (section 2.2.8), no **VertexPadding** is present. This field MUST be ignored.

An EMR_GRADIENTFILL record that specifies that the three vertexes of a triangle SHOULD fill the figure with smooth gradients of colors.<68>

An EMR_GRADIENTFILL record that specifies that the upper-left and lower-right vertexes of a rectangle SHOULD fill the figure with smooth gradients of color. There are two gradient fill modes in the GradientFill enumeration that can be used when drawing a rectangle. In **GRADIENT_FILL_RECT_H** mode, the rectangle is filled from left to right. In **GRADIENT_FILL_RECT_V** mode, the rectangle is filled from top to bottom.

An EMR_GRADIENTFILL record MUST ignore the **Alpha** fields in the TriVertex objects. An EMR_ALPHABLEND record (section 2.3.1.1) that immediately follows the EMR_GRADIENTFILL record can be used to apply an **alpha transparency** gradient to the filled area.

See section 2.3.5 for more drawing record types.

#### EMR_LINETO Record

The EMR_LINETO record specifies a line from the current drawing position up to, but not including, the specified point. It resets the current position to the specified point.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Point |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_LINETO**. This value is 0x00000036.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Point (8 bytes): **A PointL object ([MS-WMF] section 2.2.2.15), which specifies the coordinates of the line's endpoint.

See section 2.3.5 for more drawing record types.

#### EMR_PAINTRGN Record

The EMR_PAINTRGN record paints the specified **region** by using the current brush. The current clipping regions used by this record are maintained in a **Regions** state element (section 3.1.1.2.1) in the **playback device context** (section 3.1).

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| RgnDataSize |
| RgnData (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_PAINTRGN**. This value is 0x0000004A.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the destination bounding rectangle in logical coordinates. If the intersection of this rectangle with the current clipping region is empty, this record has no effect.

**RgnDataSize (4 bytes): **An unsigned integer that specifies the size of the **RgnData **field data in bytes.

**RgnData (variable): **An array of bytes that specifies the output region in a **RegionData** object (section 2.2.24). The bounds specified by the **RegionDataHeader** field of that object MAY<69> be used as the bounding rectangle of the region when this record is processed.

See section 2.3.5 for more drawing record types.

#### EMR_PIE Record

The EMR_PIE record specifies a pie-shaped wedge bounded by the intersection of an ellipse and two radials. The pie is outlined by using the current pen and filled by using the current brush.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Box |
| ... |
| ... |
| ... |
| Start |
| ... |
| End |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_PIE**. This value is 0x0000002F.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Box (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19), which specifies the **inclusive-inclusive** bounding rectangle in logical units.

**Start (8 bytes): **A PointL object ([MS-WMF] section 2.2.2.15), which specifies the coordinates, in logical units, of the endpoint of the first radial.

**End (8 bytes): **A PointL object that specifies the coordinates, in logical units, of the endpoint of the second radial.

The curve of the pie is defined by an ellipse that fits the specified bounding rectangle. The curve begins at the point where the ellipse intersects the first radial and extends counterclockwise to the point where the ellipse intersects the second radial.

The current drawing position is neither used nor updated by this record.

See section 2.3.5 for more drawing record types.

#### EMR_POLYBEZIER Record

The EMR_POLYBEZIER record specifies one or more **Bezier curves**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| Count |
| aPoints (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_POLYBEZIER**. This value is 0x00000002.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the bounding rectangle in logical units.

**Count (4 bytes): **An unsigned integer that specifies the number of points in the **aPoints** array. This value MUST be one more than three times the number of curves to be drawn because each Bezier curve requires two control points and an endpoint, and the initial curve requires an additional starting point.

| Line width | Device supports wideline | Maximum points allowed |
| --- | --- | --- |
| 1 | n/a | 16K |
| > 1 | yes | 16K |
| > 1 | no | 1360 |

Any extra points MUST be ignored.

**aPoints (variable): **An array of PointL objects ([MS-WMF] section 2.2.2.15) that specify the endpoints and control points of the Bezier curves in logical units.

Cubic Bezier curves are defined using the endpoints and control points specified by the **aPoints** field. The first curve is drawn from the first point to the fourth point, using the second and third points as control points. Each subsequent curve in the sequence needs exactly three more points: the ending point of the previous curve is used as the starting point, the next two points in the sequence are control points, and the third is the ending point.

The cubic Bezier curves SHOULD be drawn using the current pen.

See section 2.3.5 for more drawing record types.

#### EMR_POLYBEZIER16 Record

The EMR_POLYBEZIER16 record specifies one or more Bezier curves. The curves are drawn using the current pen.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| Count |
| aPoints (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_POLYBEZIER16**. This value is 0x00000055.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19), which specifies the **inclusive-inclusive** bounding rectangle in logical units.

**Count (4 bytes): **An unsigned integer that specifies the total number of points. This value MUST be one more than three times the number of curves to be drawn because each **Bezier curve** requires two control points and an endpoint, and the initial curve requires an additional starting point.

**aPoints (variable): **An array of **PointS** objects ([MS-WMF] section 2.2.2.16), which specify the points of the Bezier curves in logical units.

See section 2.3.5 for more drawing record types.

#### EMR_POLYBEZIERTO Record

The EMR_POLYBEZIERTO record specifies one or more **Bezier curves** based upon the current drawing position.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| Count |
| aPoints (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_POLYBEZIERTO**. This value is 0x00000005.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the bounding rectangle in logical units.

**Count (4 bytes): **An unsigned integer that specifies the number of points in the **aPoints** array. The first curve MUST be drawn from the current position to the third point by using the first two points as control points. For each subsequent curve, exactly three more points MUST be specified, and the ending point of the previous curve MUST be used as the starting point for the next.

| Line width | Device supports wideline | Maximum points allowed |
| --- | --- | --- |
| 1 | n/a | 16K |
| > 1 | yes | 16K |
| > 1 | no | 1360 |

Any extra points MUST be ignored.

**aPoints (variable): **An array of PointL objects ([MS-WMF] section 2.2.2.15), which specify the endpoints and control points of the Bezier curves in logical units.

The Bezier curves SHOULD be drawn using the current pen.

See section 2.3.5 for more drawing record types.

#### EMR_POLYBEZIERTO16 Record

The EMR_POLYBEZIERTO16 record specifies one or more Bezier curves based on the current drawing position.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| Count |
| aPoints (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_POLYBEZIERTO16**. This value is 0x00000058.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the bounding rectangle in logical units.

**Count (4 b****ytes): **An unsigned integer that specifies the total number of points. The first curve is drawn from the current position to the third point by using the first two points as control points. For each subsequent curve, three more points MUST be specified, and the ending point of the previous curve MUST be used as the starting point for the next.

**aPoints (variable): **An array of **PointS** objects ([MS-WMF] section 2.2.2.16), which specify the points of the **Bezier curves** in logical units.

See section 2.3.5 for more drawing record types.

#### EMR_POLYDRAW Record

The EMR_POLYDRAW record specifies a set of line segments and **Bezier curves**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| Count |
| aPoints (variable) |
| ... |
| abTypes (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_POLYDRAW**. This value is 0x00000038.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Bounds (16 bytes): **A RectL object, specified in [MS-WMF] section 2.2.2.19, which specifies the bounding rectangle in logical units.

**Count (4 bytes): **An unsigned integer that specifies the number of points in the **aPoints** field.

**aPoints (variable): **An array of PointL objects ([MS-WMF] section 2.2.2.15), which specify the points in logical units.

**abTypes (variable): **A **Count** length array of byte values that specifies how each point in the **aPoints** array is used. This value is in the Point (section 2.1.26) enumeration.

See section 2.3.5 for more drawing record types.

#### EMR_POLYDRAW16 Record

The EMR_POLYDRAW16 record specifies a set of line segments and Bezier curves.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| Count |
| aPoints (variable) |
| ... |
| abTypes (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_POLYDRAW16**. This value is 0x0000005C.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Bounds (16 bytes): **A RectL object, specified in [MS-WMF] section 2.2.2.19, which specifies the bounding rectangle in logical units.

**Count (4 bytes): **An unsigned integer that specifies the number of points.

**aPoints (variable): **A **Count** length array of **PointS** objects, specified in [MS-WMF] section 2.2.2.16, which specifies the array of points.

**abTypes (variable): **A **Count** length array of bytes that specifies the point types. This value is in the Point (section 2.1.26) enumeration.

See section 2.3.5 for more drawing record types.

#### EMR_POLYGON Record

The EMR_POLYGON record specifies a polygon consisting of two or more vertexes connected by straight lines.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| Count |
| aPoints (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_POLYGON**. This value is 0x00000003.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the bounding rectangle in logical units.

**Count (4 bytes): **An unsigned integer that specifies the number of points in the **aPoints** array.

| Line width | Device supports wideline | Maximum points allowed |
| --- | --- | --- |
| 1 | n/a | 16K |
| > 1 | yes | 16K |
| > 1 | no | 1360 |

Any extra points MUST be ignored.

**aPoints (variable): **A **Count** length array of PointL objects ([MS-WMF] section 2.2.2.15) that specifies the vertexes of the polygon in logical units.

The polygon SHOULD be outlined using the current pen and filled using the current brush and polygon fill mode. The polygon SHOULD be closed automatically by drawing a line from the last vertex to the first.

See section 2.3.5 for more drawing record types.

#### EMR_POLYGON16 Record

The EMR_POLYGON16 record specifies a polygon consisting of two or more vertexes connected by straight lines. The polygon is outlined by using the current pen and filled by using the current brush and polygon fill mode. The polygon is closed automatically by drawing a line from the last vertex to the first.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| Count |
| aPoints (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_POLYGON16**. This value is 0x00000056.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Bounds (16 bytes): **A RectL object, specified in [MS-WMF] section 2.2.2.19, which specifies the bounding rectangle in logical units.

**Count (4 bytes): **An unsigned integer that specifies the total number of points.

**aPoints (variable): **A **Count** length array of **PointS** objects, specified in [MS-WMF] section 2.2.2.16, which specifies the array of points.

See section 2.3.5 for more drawing record types.

#### EMR_POLYLINE Record

The EMR_POLYLINE record specifies a series of line segments by connecting the points in the specified array.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| Count |
| aPoints (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_POLYLINE**. This value is 0x00000004.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the bounding rectangle in logical units.

**Count (4 bytes): **An unsigned integer that specifies the number of points in the **aPoints** array.

| Line width | Device supports wideline | Maximum points allowed |
| --- | --- | --- |
| 1 | n/a | 16K |
| > 1 | yes | 16K |
| > 1 | no | 1360 |

Any extra points MUST be ignored.

**aPoints (variable): **A **Count** length array of PointL objects ([MS-WMF] section 2.2.2.15) that specifies the point data, in logical units.

The line segments SHOULD be drawn using the current pen.

See section 2.3.5 for more drawing record types.

#### EMR_POLYLINE16 Record

The EMR_POLYLINE16 record specifies a series of line segments by connecting the points in the specified array.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| Count |
| aPoints (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_POLYLINE16**. This value is 0x00000057.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Bounds (16 bytes): **A RectL object, specified in [MS-WMF] section 2.2.2.19, which specifies the bounding rectangle in logical units.

**Count (4 bytes): **An unsigned integer that specifies the total number of points.

**aPoints (variable): **A **C****ount** length array of **PointS** objects, specified in [MS-WMF] section 2.2.2.16, which specifies the array of points.

See section 2.3.5 for more drawing record types.

#### EMR_POLYLINETO Record

The EMR_POLYLINETO record specifies one or more straight lines based upon the current drawing position.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| Count |
| aPoints (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_POLYLINETO**. This value is 0x00000006.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Bounds (16 bytes): **A RectL object, specified in [MS-WMF] section 2.2.2.19, which specifies the bounding rectangle in logical units.

**Count (4 bytes): **An unsigned integer that specifies the number of points in the **aPoints** array.

| Line width | Device supports wideline | Maximum points allowed |
| --- | --- | --- |
| 1 | n/a | 16K |
| > 1 | yes | 16K |
| > 1 | no | 1360 |

Any extra points MUST be ignored.

**aPoints (variable): **A **Count** length array of PointL objects ([MS-WMF] section 2.2.2.15, which specifies the point data, in logical units.

A line SHOULD be drawn from the current position to the first point specified by the **aPoints** field using the current pen. Each additional line SHOULD be drawn from the ending point of the previous line to the next point specified by **aPoints**.

See section 2.3.5 for more drawing record types.

#### EMR_POLYLINETO16 Record

The EMR_POLYLINETO16 record specifies one or more straight lines based upon the current drawing position.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| Count |
| aPoints (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_POLYLINETO16**. This value is 0x00000059.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19, which specifies the bounding rectangle in logical units.

**Count (4 bytes): **An unsigned integer that specifies the number of points.

**aPoints (variab****le): **A **Count** length array of **PointS** objects ([MS-WMF] section 2.2.2.16, which specifies the array of points.

A line is drawn from the current drawing position to the first point specified by the **aPoints** field by using the current pen. For each additional line, drawing is performed from the ending point of the previous line to the next point specified by **aPoints**.

See section 2.3.5 for more drawing record types.

#### EMR_POLYPOLYGON Record

The EMR_POLYPOLYGON record specifies a series of closed polygons.

Fields not specified in this section are specified in section 2.3.5.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| NumberOfPolygons |
| Count |
| PolygonPointCount (variable) |
| ... |
| aPoints (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_POLYPOLYGON**. This value is 0x00000008.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the bounding rectangle in logical units.

**NumberOfPolygons ****(4 bytes): **An unsigned integer that specifies the number of polygons.

**Count (4 bytes): **An unsigned integer that specifies the total number of points in all polygons.

| Line width | Device supports wideline | Maximum points allowed |
| --- | --- | --- |
| 1 | n/a | 16K |
| > 1 | yes | 16K |
| > 1 | no | 1360 |

Any extra points MUST be ignored. To draw a line with more points, the data SHOULD be divided into groups that have less than the maximum number of points, and an EMR_POLYPOLYGON operation SHOULD be performed for each group of points.

**PolygonPoi****ntCount (variable): **An array of 32-bit unsigned integers that specifies the point count for each polygon.

**aPoints (variable): **An array of PointL objects ([MS-WMF] section 2.2.2.15) that specifies the points for all polygons in logical units. The number of points is specified by the **Count** field value.

Each polygon SHOULD be outlined using the current pen, and filled using the current brush and polygon fill mode that are defined in the **playback dev****ice context**. The polygons defined by this record can overlap.

See section 2.3.5 for more drawing record types.

#### EMR_POLYPOLYGON16 Record

The EMR_POLYPOLYGON16 record specifies a series of closed polygons. Each polygon is outlined using the current pen, and filled using the current brush and polygon fill mode. The polygons drawn by this record can overlap.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| NumberOfPolygons |
| Count |
| PolygonPointCount (variable) |
| ... |
| aPoints (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_POLYPOLYGON16**. This value is 0x0000005B.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19), which specifies the bounding rectangle in logical units.

**NumberOfP****olygons (4 bytes): **An unsigned integer that specifies the number of polygons.

**Count (4 bytes): **An unsigned integer that specifies the total number of points in all polygons.

**PolygonPointCount (variable): **A **NumberOfPolygons** length array of 32-bit unsigned integers that specifies the point counts for each polygon.

**aPoints (variable): **A **Count** length array of **PointS** objects ([MS-WMF] section 2.2.2.16), which specifies the array of points.

See section 2.3.5 for more drawing record types.

#### EMR_POLYPOLYLINE Record

The EMR_POLYPOLYLINE record draws multiple series of connected line segments.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| NumberOfPolylines |
| Count |
| aPolylinePointCount (variable) |
| ... |
| aPoints (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_POLYPOLYLINE**. This value is 0x00000007.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the bounding rectangle in logical units.

**NumberOfPolylines (4 bytes): **An unsigned integer that specifies the number of polylines, which is the number of elements in the **aPolylinePointCount** array.

**Count (4 bytes): **An unsigned integer that specifies the total number of points in all polylines, which is the number of elements in the **aPoints** array.

| Line width | Device supports wideline | Maximum points allowed |
| --- | --- | --- |
| 1 | n/a | 16K |
| > 1 | yes | 16K |
| > 1 | no | 1360 |

Any extra points MUST be ignored.

**aPolylinePointCount (variable): **A **NumberOfPolylines**-length array of 32-bit unsigned integers that specify the point counts for all polylines. Each value MUST be >= 0x00000002.

Each point count refers to a number of consecutive elements in the **aPoints** array.

**aPoints (variable): **A **Count**-length array of PointL objects ([MS-WMF] section 2.2.2.15) that specify the point data, in logical units.

The line segments SHOULD be drawn using the current pen. The figures formed by the segments SHOULD NOT filled. The current drawing position SHOULD neither be used nor updated by this record.

See section 2.3.5 for more drawing record types.

#### EMR_POLYPOLYLINE16 Record

The EMR_POLYPOLYLINE16 record specifies multiple series of connected line segments.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| NumberOfPolylines |
| Count |
| PolylinePointCount (variable) |
| ... |
| aPoints (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_POLYPOLYLINE16**. This value is 0x0000005A.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19), which specifies the bounding rectangle in logical units.

**NumberOfPolylines (4 bytes): **An unsigned integer that specifies the number of polylines.

**Count (4 bytes): **An unsigned integer that specifies the total number of points in all polylines.

**PolylinePointCount (variable): **A **NumberOfPolylines** length array of 32-bit unsigned integers that specifies the point counts for each polyline.

**aPoints (variable): **A **Count** length array of **PointS** objects ([MS-WMF] section 2.2.2.16), which specifies the array of points.

See section 2.3.5 for more drawing record types.

#### EMR_POLYTEXTOUTA Record

The EMR_POLYTEXTOUTA record draws one or more **ASCII** text strings using the current font and text colors.

Fields not specified in this section are specified in section 2.3.5.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| iGraphicsMode |
| exScale |
| eyScale |
| cStrings |
| aEmrText (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_POLYTEXTOUTA**. This value is 0x00000060.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19), which specifies the bounding rectangle in logical units.

**iGraphicsMode (4 bytes): **An unsigned integer that specifies the current graphics mode, from the GraphicsMode enumeration (section 2.1.16).

**exScale (4 bytes): **A FLOAT value that specifies the X scale from page units to .01mm units if graphics mode is **GM_COMPATIBLE**.

**eyScale (4 bytes): **A FLOAT value that specifies the Y scale from page units to .01mm units if graphics mode is **GM_COMPATIBLE**.

**cStrings (4 bytes): **An unsigned integer that specifies the number of **EmrText** objects.

**aEmrText (variable): **An array of EmrText objects (section 2.2.5) that specify the output strings in 8-bit ASCII characters, with text attributes, and spacing values. The number of EmrText objects is specified by **cStrings**.

The font and text colors used for output are specified by properties in the current state of EMF metafile playback (section 3.1).

EMR_POLYTEXTOUTA SHOULD<70> be emulated with a series of EMR_EXTTEXTOUTW records (section 2.3.5.7), one per string. This requires the ASCII text string in each EmrText object to be converted to **Unicode** **UTF16-LE** encoding.

See section 2.3.5 for more drawing record types.

#### EMR_POLYTEXTOUTW Record

The EMR_POLYTEXTOUTW record draws one or more **Unicode** text strings using the current font and text colors.

Fields not specified in this section are specified in section 2.3.5.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| iGraphicsMode |
| exScale |
| eyScale |
| cStrings |
| wEmrText (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_POLYTEXTOUTW**. This value is 0x00000061.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19), which specifies the bounding rectangle in logical units.

**iGraphicsMode (4 bytes): **An unsigned integer that specifies the current graphics mode. Graphics modes are specified in section 2.1.16.

**exScale (4 bytes): **A FLOAT value that specifies the X scale from page units to .01mm units if graphics mode is **GM_COMPATIBLE**.

**eyScale (4 bytes): **A FLOAT value that specifies the X scale from page units to .01mm units if graphics mode is **GM_COMPATIBLE**.

**cStrings (4 bytes): **An unsigned integer that specifies the number of **EmrText** objects.

**wEmrText (variable): **An array of EmrText objects (section 2.2.5) that specify the output strings in Unicode **UTF16-LE** characters, with text attributes and spacing values. The number of EmrText objects is specified by **cStrings**.

The font and text colors used for output are specified by properties in the current state of the **playback device context**.

EMR_POLYTEXTOUTW SHOULD be emulated with a series of EMR_EXTTEXTOUTW records (section 2.3.5.7), one per string.<71>

See section 2.3.5 for more drawing record types.

#### EMR_RECTANGLE Record

The EMR_RECTANGLE record draws a rectangle. The rectangle is outlined by using the current pen and filled by using the current brush.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Box |
| ... |
| ... |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_RECTANGLE**. This value is 0x0000002B.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Box (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19), which specifies the **inclusive-inclusive** rectangle to draw.

The current drawing position is neither used nor updated by this record.

If a **PS_NULL** pen is used, the dimensions of the rectangle are 1 pixel less in height and 1 pixel less in width.

See section 2.3.5 for more drawing record types.

#### EMR_ROUNDRECT Record

The EMR_ROUNDRECT record specifies a rectangle with rounded corners. The rectangle is outlined by using the current pen and filled by using the current brush.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Box |
| ... |
| ... |
| ... |
| Corner |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_ROUNDRECT**. This value is 0x0000002C.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Box (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19), which specifies the **inclusive-inclusive** bounding rectangle, in logical coordinates.

**Corner (8 bytes): **A 64-bit **SizeL** object ([MS-WMF] section 2.2.2.22), which specifies the **width** and **height**, in logical coordinates, of the ellipse used to draw the rounded corners.

See section 2.3.5 for more drawing record types.

#### EMR_SETPIXELV Record

The EMR_SETPIXELV record defines the color of the pixel at the specified logical coordinates.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Pixel |
| ... |
| Color |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_SETPIXELV**. This value is 0x0000000F.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Pixel (8 bytes): **A PointL object ([MS-WMF] section 2.2.2.15) that specifies the logical coordinates for the pixel.

**Color (4 bytes): **A 32-bit ColorRef object ([MS-WMF] section 2.2.2.8) that specifies the pixel color.

See section 2.3.5 for more drawing record types.

#### EMR_SMALLTEXTOUT Record

The EMR_SMALLTEXTOUT record outputs a string.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| x |
| y |
| cChars |
| fuOptions |
| iGraphicsMode |
| exScale |
| eyScale |
| Bounds (optional) |
| ... |
| ... |
| ... |
| TextString (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_SMALLTEXTOUT**. This value is 0x0000006C.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**x (4 bytes): **A signed integer specifying the x-coordinate of where to place the string.

**y (4 bytes): **A signed integer specifying the y-coordinate of where to place the string.

**cChars (4 bytes): **An unsigned integer specifying the number of 16-bit characters in the string. The string is NOT null-terminated.

**fuOptions (4 bytes): **An unsigned integer specifying the text output options to use. These options are specified by one or a combination of values from the ExtTextOutOptions enumeration (section 2.1.11).

**iGraphicsMode (4 bytes): **An unsigned integer specifying the graphics mode, from the GraphicsMode enumeration (section 2.1.16).

**exScale (4 bytes): **A FLOAT value that specifies how much to scale the text in the x-direction.

**eyScale (4 bytes): **A FLOAT value that specifies how much to scale the text in the y-direction.

**Bounds (16 bytes, optional): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the bounding rectangle in logical units.

**TextString (variable): **A string that contains the text string to draw, in either 8-bit or 16-bit character codes, according to the value of the **fuOptions** field.

If **ETO_SMALL_CHARS** is set in the **fuOptions** field, **TextString** contains 8-bit codes for characters, derived from the low bytes of **Unicode** **UTF16-LE** character codes, in which the high byte is assumed to be 0.

If **ETO_NO_RECT** is set in the **fuOptions** field, the **Bounds** field is not included in the record.

See section 2.3.5 for more drawing record types.

#### EMR_STROKEANDFILLPATH Record

The EMR_STROKEANDFILLPATH record closes any open figures in a path, strokes the outline of the path by using the current pen, and fills its interior by using the current brush.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_STROKEANDFILLPATH**. This value is 0x0000003F.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the bounding rectangle in logical units.

See section 2.3.5 for more drawing record types.

#### EMR_STROKEPATH Record

The EMR_STROKEPATH record renders the specified path by using the current pen.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_STROKEPATH**. This value is 0x00000040.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the bounding rectangle in logical units.

See section 2.3.5 for more drawing record types.

### Escape Record Types

The **Escape **record types execute **printer driver** functions. 

The following are **EMF** escape record types.

| Name | Section | Description |
| --- | --- | --- |
| EMR_DRAWESCAPE | 2.3.6.1 | Passes arbitrary information to the printer driver. The intent is that the information results in drawing being done. |
| EMR_EXTESCAPE | 2.3.6.2 | Passes arbitrary information to the printer driver. The intent is that the information does not result in drawing being done. |
| EMR_NAMEDESCAPE | 2.3.6.3 | Passes arbitrary information to the given named printer driver. |

The generic structure of escape records is specified as follows.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| iEscape |
| EscapeRecordBuffer (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that defines the type of the record. The escape record types are listed in the following table. See the preceding table for descriptions of these records.

| Name | Value |
| --- | --- |
| EMR_DRAWESCAPE | 0x00000069 |
| EMR_EXTESCAPE | 0x0000006A |
| EMR_NAMEDESCAPE | 0x0000006E |

**Size (4 bytes): **An unsigned integer that specifies the size in bytes of this record in the **metafile**. This value MUST be a multiple of 4 bytes.

**iEscape (4 bytes): **An unsigned integer that specifies the printer driver escape to execute. This MUST be one of the values in the MetafileEscapes enumeration ([MS-WMF] section 2.1.1.17).

**EscapeRecordBuffer (variable): **An array of bytes that contains the remainder of the escape record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| EscapeRecordParm (variable) |
| ... |
| AlignmentPadding (variable, optional) |
| ... |

**EscapeRecordParm (variable): **An array of bytes that contains the parameters for the escape record.

**AlignmentPadding (variable, optional): **An array of up to 3 bytes that pads the record so that its total size is a multiple of 4 bytes. This field MUST be ignored.

See section 2.3 for more EMF record types.

#### EMR_DRAWESCAPE Record

The EMR_DRAWESCAPE record passes arbitrary information to a **printer driver**. The intent is that the information results in drawing being done.

Fields not specified in this section are specified in section 2.3.6.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| iEscape |
| cjIn |
| Data (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type from the RecordType enumeration (section 2.1.1). It MUST be **EMR_DRAWESCAPE**, which is 0x00000069.

**cjIn (4 bytes): **An unsigned integer specifying the number of bytes to pass to the printer driver.

**Data (variable): **The data to pass to the printer driver. There MUST be **cjIn** bytes available.

See section 2.3.6 for more escape record types.

#### EMR_EXTESCAPE Record

The EMR_EXTESCAPE record passes arbitrary information to a **printer driver**. The intent is that the information does not result in drawing being done.

Fields not specified in this section are specified in section 2.3.6.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| iEscape |
| cjIn |
| Data (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type from the RecordType enumeration (section 2.1.1). This value is 0x0000006A.

**cjIn (4 bytes): **An unsigned integer specifying the number of bytes to pass to the printer driver.

**Data (variable): **The data to pass to the printer driver. There MUST be **cjIn** bytes available.

See section 2.3.6 for more escape record types.

#### EMR_NAMEDESCAPE Record

The **EMR_NAMEDESCAPE **record passes arbitrary information to a named **printer driver**.

Fields not specified in this section are specified in section 2.3.6.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| iEscape |
| cjDriver |
| cjIn |
| DriverName (variable) |
| ... |
| Data (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type from the RecordType enumeration (section 2.1.1). It MUST be EMR_NAMEDESCAPE, which is 0x0000006E.

**cjDriver (4 bytes): **An unsigned integer that specifies the number of bytes in the **DriverName** field. This value MUST be an even number. 

**cjIn (4 bytes): **An unsigned integer specifying the number of bytes in the **Data** field to pass to the printer driver.

**DriverName (variable): **A null-terminated string of **Unicode** characters that specifies the name of the printer driver to receive data.

**Data (variable): **The data to pass to the printer driver.

See section 2.3.6 for more escape record types.

### Object Creation Record Types

The **Object Creation** record types create graphics objects.

The following are **EMF** object creation record types.

| Name | Section | Description |
| --- | --- | --- |
| EMR_CREATEBRUSHINDIRECT | 2.3.7.1 | Defines a logical brush with a LogBrushEx object (section 2.2.12). |
| EMR_CREATECOLORSPACE | 2.3.7.2 | Defines a logical **color space** with a LogColorSpace object ([MS-WMF] section 2.2.2.11). |
| EMR_CREATECOLORSPACEW | 2.3.7.3 | Defines a logical color space with a LogColorSpaceW object ([MS-WMF] section 2.2.2.12). |
| EMR_CREATEDIBPATTERNBRUSHPT | 2.3.7.4 | Defines a pattern brush with a DeviceIndependentBitmap object ([MS-WMF] section 2.2.2.9). |
| EMR_CREATEMONOBRUSH | 2.3.7.5 | Defines a monochrome pattern brush with a monochrome DeviceIndependentBitmap object. |
| EMR_CREATEPALETTE | 2.3.7.6 | Defines a **logical palette** with a LogPalette object (section 2.2.17). |
| EMR_CREATEPEN | 2.3.7.7 | Defines a logical pen with a LogPen object (section 2.2.19). |
| EMR_EXTCREATEFONTINDIRECTW | 2.3.7.8 | Defines a logical font with either a LogFont object (section 2.2.13) or LogFontExDv object (section 2.2.15). |
| EMR_EXTCREATEPEN | 2.3.7.9 | Defines a logical pen with a LogPenEx object (section 2.2.20) and optional DeviceIndependentBitmap object. |

The generic structure of object creation records is specified as follows.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ObjectRecordBuffer (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that defines the type of record. The object creation record types are listed in the following table. See the preceding table for descriptions of these record types.

| Name | Value |
| --- | --- |
| EMR_CREATEMONOBRUSH | 0x0000005D |
| EMR_CREATEDIBPATTERNBRUSHPT | 0x0000005E |
| EMR_EXTCREATEPEN | 0x0000005F |
| EMR_CREATECOLORSPACEW | 0x0000007A |
| EMR_CREATEPEN | 0x00000026 |
| EMR_CREATEBRUSHINDIRECT | 0x00000027 |
| EMR_CREATEPALETTE | 0x00000031 |
| EMR_EXTCREATEFONTINDIRECTW | 0x00000052 |
| EMR_CREATECOLORSPACE | 0x00000063 |

**Size (4 bytes): **An unsigned integer that specifies the size in bytes of this record in the **metafile**. This value MUST be a multiple of 4 bytes.

**Object****RecordBuffer (variable): **An array of bytes that contains the remainder of the object creation record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ObjectRecordParm (variable) |
| ... |
| AlignmentPadding (variable, optional) |
| ... |

**ObjectRecordParm (variable): **An array of bytes that contains the parameters for the object creation record.

**AlignmentPadding (variable, optional): **An array of up to 3 bytes that pads the record so that its total size is a multiple of 4 bytes. This field MUST be ignored.

See section 2.3 for more EMF record types.

#### EMR_CREATEBRUSHINDIRECT Record

The **EMR_CREATEBRUSHINDIRECT** record defines a logical brush for graphics operations.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ihBrush |
| LogBrush |
| ... |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_CREATEBRUSHINDIRECT. This value is 0x00000027.

**Size (4 bytes): **An unsigned integer that specifies the size in bytes, of this record. This value is 0x00000018.

**ihBrush (4 bytes): **An unsigned integer that specifies the index of the logical brush object in the EMF object table (section 3.1.1.1). This index is used to refer to the object, so it can be reused or modified.

**LogB****rush (12 bytes): **A LogBrushEx object (section 2.2.12) that specifies the style, color, and pattern of the logical brush. The **BrushStyle** field in this object MUST be BS_SOLID, BS_HATCHED, or BS_NULL.

See section 2.3.7 for more object creation record types.

#### EMR_CREATECOLORSPACE Record

The **EMR_CREATECOLORSPACE** record creates a logical **color space** object from a **color profile** with a name consisting of **ASCII** characters.<72>

Fields not specified in this section are specified in section 2.3.7.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ihCS |
| lcs (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_CREATECOLORSPACE**. This value is 0x00000063.

**ihCS (4 bytes): **An unsigned integer that specifies the index of the logical color space object in the **EMF object table** (section 3.1.1.1). This index MUST be saved so that this object can be reused or modified.

**lcs (variable): **A LogColorSpace object ([MS-WMF] section 2.2.2.11), which can specify the name of a color profile in ASCII characters.

The logical color space object defined by this record can be selected into the **playback device context** by an EMR_SETCOLORSPACE record (section 2.3.8.7), which defines the logical color space to use in subsequent graphics operations.

See section 2.3.7 for more object creation record types.

#### EMR_CREATECOLORSPACEW Record

The EMR_CREATECOLORSPACEW record creates a logical **color space** object from a **color profile** with a name consisting of **Unicode** characters.<73>

Fields not specified in this section are specified in section 2.3.7.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ihCS |
| lcs (variable) |
| ... |
| dwFlags |
| cbData |
| Data (variable, optional) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_CREATECOLORSPACEW**. This value is 0x0000007A.

**ihCS (4 bytes): **An unsigned integer that specifies the index of the logical color space object in the **EMF object table** (section 3.1.1.1). This index MUST be saved so that this object can be reused or modified.

**lcs (variable): **A LogColorSpaceW object ([MS-WMF] section 2.2.2.12) that can specify the name of a color profile in Unicode **UTF16-LE** characters.

**dwFlags (4 bytes): **An unsigned integer that provides information about the data in this record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | C |

**C (1 bit): **If set, the **Data** field contains color profile data.

**cbData (4 bytes): **An unsigned integer that specifies the size in bytes, of the **Data** field.

**Data (variable, optional): **An array of bytes that specifies color profile data. When **cbData** is zero, this field is optional and is ignored.

The logical color space object defined by this record can be selected into the **playback device context** by an EMR_SETCOLORSPACE record (section 2.3.8.7), which defines the logical color spaceto use in subsequent graphics operations.

See section 2.3.7 for more object creation record types.

#### EMR_CREATEDIBPATTERNBRUSHPT Record

The EMR_CREATEDIBPATTERNBRUSHPT record defines a pattern brush for graphics operations. The pattern is specified by a **DIB**.

Fields not specified in this section are specified in section 2.3.7.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ihBrush |
| Usage |
| offBmi |
| cbBmi |
| offBits |
| cbBits |
| BitmapBuffer (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_CREATEDIBPATTERNBRUSHPT. This value is 0x0000005E.

**ihBrush (4 bytes): **An unsigned integer that specifies the index of the pattern brush object in the **EMF object table** (section 3.1.1.1). This index MUST be saved so that this object can be reused or modified.

**Usage (4 bytes): **An unsigned integer that specifies how to interpret values in the **color table** in the DIB header. This value is in the DIBColors enumeration (section 2.1.9).

**offBmi (4 bytes): **An unsigned integer that specifies the offset from the start of this record to the DIB header.

**cbBmi (4 bytes): **An unsigned integer that specifies the size of the DIB header.

**offBits (4 bytes): **An unsigned integer that specifies the offset from the start of this record to the DIB bits.

**cbBits (4 bytes): **An unsigned integer that specifies the size of the DIB bits.

**BitmapBuffer (variable): **A buffer containing a **packed DIB** in the form of a DeviceIndependentBitmap object ([MS-WMF] section 2.2.2.9). It is not required to be contiguous with the fixed portion of this record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UndefinedSpace (variable, optional) |
| ... |
| BmiSrc (variable) |
| ... |
| BitsSrc (variable) |
| ... |

**UndefinedSpace (variable, optional): **An array of bytes that MUST be ignored.

**BmiSrc (variable): **The DIB header, which is the **DibHeaderInfo** field of a DeviceIndependentBitmap object.

**BitsSrc (variable): **The DIB bits, which is the **aData** field of a DeviceIndependentBitmap object.

The pattern brush object defined by this record can be selected into the **playback device context** by an EMR_SELECTOBJECT record (section 2.3.8.5), which specifies the pattern brush to use in subsequent graphics operations.

See section 2.3.7 for more object creation record types.

#### EMR_CREATEMONOBRUSH Record

The **EMR_CREATEMONOBRUSH **record defines a monochrome pattern brush for graphics operations. The pattern is specified by a monochrome **DIB**.

Fields not specified in this section are specified in section 2.3.7.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ihBrush |
| Usage |
| offBmi |
| cbBmi |
| offBits |
| cbBits |
| BitmapBuffer (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_CREATEMONOBRUSH**. This value is 0x0000005D.

**ihBrush (4 bytes): **An unsigned integer that specifies the index of the monochrome pattern brush object in the EMF object table (section 3.1.1.1). This index MUST be saved so that this object can be reused or modified.

**Usage (4 bytes): **An unsigned integer that specifies how to interpret values in the **color table** in the DIB header. This value is in the DIBColors enumeration (section 2.1.9).

**offBmi (4 bytes): **An unsigned integer that specifies the offset from the start of this record to the DIB header.

**cbBmi (4 bytes): **An unsigned integer that specifies the size of the DIB header.

**offBits (4 bytes): **An unsigned integer that specifies the offset from the start of this record to the DIB bits.

**cbBits (4 bytes): **An unsigned integer that specifies the size of the DIB bits.

**BitmapBuffer (variable): **A buffer containing a **packed DIB** in the form of a monochrome DeviceIndependentBitmap object ([MS-WMF] section 2.2.2.9). It is not required to be contiguous with the fixed portion of this record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UndefinedSpace (variable, optional) |
| ... |
| BmiSrc (variable) |
| ... |
| BitsSrc (variable) |
| ... |

**UndefinedSpace (variable, optional): **An array of bytes that MUST be ignored.

**BmiSrc (variable): **The DIB header, which is the **DibHeaderInfo** field of a DeviceIndependentBitmap object.

**BitsSrc (variable): **The DIB bits, which is the **aData** field of a DeviceIndependentBitmap object.

The monochrome pattern brush object defined by this record can be selected into the **playback device context** by an EMR_SELECTOBJECT record (section 2.3.8.5), which specifies the pattern brush to use in subsequent graphics operations.

See section 2.3.7 for more object creation record types.

#### EMR_CREATEPALETTE Record

The EMR_CREATEPALETTE record defines a **logical palette** for graphics operations.

Fields not specified in this section are specified in section 2.3.7.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ihPal |
| LogPalette (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_CREATEPALETTE**. This value is 0x00000031.

**ihPal (4 bytes): **An unsigned integer that specifies the index of the logical palette object in the EMF object table (section 3.1.1.1). This index MUST be saved so that this object can be reused or modified.

**LogPalette (variable): **A LogPalette object (section 2.2.17). The **Version** field of this object MUST be set to 0x0300. If the **NumberOfEntries** value in this object is zero, processing of this record MUST fail.

The logical palette defined by this record can be selected into the **playback device context** by an EMR_SELECTPALETTE record (section 2.3.8.6), which specifies the logical palette to use in subsequent graphics operations.

See section 2.3.7 for more object creation record types.

#### EMR_CREATEPEN Record

The EMR_CREATEPEN record defines a logical pen for graphics operations.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ihPen |
| LogPen |
| ... |
| ... |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_CREATEPEN**. This value is 0x00000026.

**Size (4 bytes): **An unsigned integer that specifies the size in bytes, of this record. This value is 0x0000001C.

**ihPen (4 bytes): **An unsigned integer that specifies the index of the logical pen object in the EMF object table (section 3.1.1.1). This index MUST be saved so that this object can be reused or modified.

**LogPen (16 bytes): **A LogPen object (section 2.2.19) that specifies the style, width, and color of the logical pen.

The logical pen object defined by this record can be selected into the **playback device context** by an EMR_SELECTOBJECT record (section 2.3.8.5), which specifies the logical pen to use in subsequent graphics operations.

See section 2.3.7 for more object creation record types.

#### EMR_EXTCREATEFONTINDIRECTW Record

The **EMR_EXTCREATEFONTINDIRECTW** record defines a logical font for graphics operations.

Fields not specified in this section are specified in section 2.3.7.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ihFonts |
| elw (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_EXTCREATEFONTINDIRECTW**. This value is 0x00000052.

**ihFonts (4 bytes): **An unsigned integer that specifies the index of the logical font object in the **EMF object table **(section 3.1.1.1). This index MUST be saved so that this object can be reused or modified.

**elw (variable): **A LogFontExDv object (section 2.2.15), which specifies the logical font. A LogFont object (section 2.2.13) MAY<74> be present instead. The process for determining the type of object in this field is described below.

The logical font object defined by this record can be selected into the **playback device context** by an EMR_SELECTOBJECT record (section 2.3.8.5), which specifies the logical font to use in subsequent graphics operations.

The type of logical font object in the **elw** field of this record is determined by the following algorithm (all size and length values are in bytes):

First, note that the size in bytes of the static part of this record—that is, the sum of the sizes of its **Type**, **Size**, and **ihFonts** fields—is 12.

Next, note that because the size in bytes of the entire record is present in its **Siz****e** field, the size in bytes of the variable-length **elw** field can be computed as follows.

Size - 12

The size of the **elw** field must be equal to or greater than the size of a **LogFontPanose** object.<75>

If the size of the **elw** field is equal to the size of a **LogFontPanose** object (section 2.2.16), **elw** MUST be treated as a fixed-length **LogFontPanose** object.

If the size of the **elw** field is greater than the size of a **LogFontPanose** object, then **elw** MUST be treated as a variable-length **LogFontExDv** object.

The size of a LogFontPanose object is 0x0140 (320 decimal). It is determined by adding up the sizes of its fields, as follows:

**LogFont**: The size of a LogFont object is 0x005C (92 decimal). It is determined by adding up the sizes of its fields, as follows:

Fields from **Height** through **PitchAndFamily**: 0x001C (28 decimal).

**Facename**: The length is 32 16-bit characters: 0x0040 (64 decimal).

**Fullname**: The length is 64 16-bit characters: 0x0080 (128 decimal).

**Style**: The length is 32 16-bit characters: 0x0040 (64 decimal).

Fields from **Version** through **Culture**: 0x0018 (24 decimal).

**Panose**: The exact length of this field is 0x000A, but it MUST be padded by two additional bytes for 32-bit alignment, so for the purposes of this computation the length is 0x000C (12 decimal).

See section 2.3.7 for more object creation record types.

#### EMR_EXTCREATEPEN Record

The **EMR_EXTCREATEPEN** record defines an extended logical pen for graphics operations. An optional **DIB** can be specified to use as the line style.

Fields not specified in this section are specified in section 2.3.7.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ihPen |
| offBmi |
| cbBmi |
| offBits |
| cbBits |
| elp (variable) |
| ... |
| BitmapBuffer (variable, optional) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_EXTCREATEPEN**. This value is 0x0000005F.

**ihPen (4 bytes): **An unsigned integer that specifies the index of the extended logical pen object in the **EMF object table** (section 3.1.1.1). This index MUST be saved so that this object can be reused or modified.

**offBmi (4 bytes): **An unsigned integer that specifies the offset from the start of this record to the DIB header if the record contains a DIB.

**cbBmi (4 bytes): **An unsigned integer that specifies the size of the DIB header if the record contains a DIB.

**offBits (4 bytes): **An unsigned integer that specifies the offset from the start of this record to the DIB bits if the record contains a DIB.

**cbBits (4 bytes): **An unsigned integer that specifies the size of the DIB bits if the record contains a DIB.

**elp (variable): **A LogPenEx object (section 2.2.20) that specifies an extended logical pen with attributes including an optional line style array.

**BitmapBuffer (variable, optional): **An array of bytes containing a **packed DIB** in the form of a DeviceIndependentBitmap object ([MS-WMF] section 2.2.2.9). It is not required to be contiguous with the fixed portion of this record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UndefinedSpace (variable, optional) |
| ... |
| BmiSrc (variable) |
| ... |
| BitsSrc (variable) |
| ... |

**UndefinedSpace (variable, optional): **An array of bytes that MUST be ignored.

**BmiSrc (variable): **The DIB header, which is the **DibHeaderInfo** field of a DeviceIndependentBitmap object.

**BitsSrc (variable): **The DIB bits, which is the **aData** field of a DeviceIndependentBitmap object.

The extended logical pen object defined by this record can be selected into the **playback device context** by an EMR_SELECTOBJECT record (section 2.3.8.5), which specifies the logical pen to use in subsequent graphics operations.

See section 2.3.7 for more object creation record types.

### Object Manipulation Record Types

The **Object Manipulation** record types manage and modify graphics objects.

The following are **EMF** object manipulation record types.

| Name | Section | Description |
| --- | --- | --- |
| EMR_COLORCORRECTPALETTE | 2.3.8.1 | Specifies how to correct the entries of a LogPalette object (section 2.2.17) by using **WCS** values. |
| EMR_DELETECOLORSPACE | 2.3.8.2 | Specifies how to delete a logical color space from the EMF object table (section 3.1.1.1). |
| EMR_DELETEOBJECT | 2.3.8.3 | Specifies the index of the object to be deleted from the EMF object table. |
| EMR_RESIZEPALETTE | 2.3.8.4 | Increases or decreases the size of an existing LogPalette object. |
| EMR_SELECTOBJECT | 2.3.8.5 | Specifies an existing object based on its index in the EMF object table and selects it into the **playback device context** |
| EMR_SELECTPALETTE | 2.3.8.6 | Selects the specified LogPalette object into the playback device context. |
| EMR_SETCOLORSPACE | 2.3.8.7 | Specifies a logical color space, based on its index in the EMF object table. |
| EMR_SETPALETTEENTRIES | 2.3.8.8 | Defines **RGB** color values in a range of entries for an existing LogPalette object. |

The generic structure of object manipulation records is specified as follows.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ObjectRecordBuffer (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that defines the type of record. The object manipulation record types are listed in the following table. See the preceding table for descriptions of these record types.

| Name | Value |
| --- | --- |
| EMR_SELECTOBJECT | 0x00000025 |
| EMR_DELETEOBJECT | 0x00000028 |
| EMR_SELECTPALETTE | 0x00000030 |
| EMR_SETPALETTEENTRIES | 0x00000032 |
| EMR_RESIZEPALETTE | 0x00000033 |
| EMR_SETCOLORSPACE | 0x00000064 |
| EMR_DELETECOLORSPACE | 0x00000065 |
| EMR_COLORCORRECTPALETTE | 0x0000006F |

**Size (4 bytes): **An unsigned integer that specifies the size in bytes of this record in the **metafile**. This value MUST be a multiple of 4 bytes.

**ObjectRecordBuffer (variable): **An array of bytes that contains the remainder of the object manipulation record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ObjectRecordParm (variable) |
| ... |
| AlignmentPadding (variable, optional) |
| ... |

**ObjectRecordParm (variable): **An array of bytes that contains the parameters for the object manipulation record.

**AlignmentPadding (variable, optional): **An array of up to 3 bytes that pads the record so that its total size is a multiple of 4 bytes. This field MUST be ignored.

See section 2.3 for more EMF record types.

#### EMR_COLORCORRECTPALETTE Record

The **EMR_COLORCORRECTPALETTE** record specifies the correction of entries of a **logical palette** object using **WCS**.<76>

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ihPalette |
| nFirstEntry |
| nPalEntries |
| nReserved |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_COLORCORRECTPALETTE**. This value is 0x0000006F.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes. This value is 0x00000018.

**ihPalette (4 bytes): **An unsigned integer that specifies the index of a logical palette object (section 2.2.17) in the **EMF object table** (section 3.1.1.1).

**nFirstEntry (4 bytes): **An unsigned integer that specifies the index of the first entry to correct.

**nPalEntries (4 bytes): **An unsigned integer that specifies the number of **palette** entries to correct.

**nReserved (4 bytes): **An unsigned integer that is undefined and unused.

See section 2.3.8 for more object manipulation record types.

#### EMR_DELETECOLORSPACE Record

The **EMR_DELETECOLORSPACE** record deletes a logical **color space** object.<77>

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ihCS |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_DELETECOLORSPACE**. This value is 0x00000065.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**ihCS (4 bytes): **An unsigned integer that specifies the index of a logical color space object in the EMF object table (section 3.1.1.1).

The color space is specified by either a LogColorSpace or LogColorSpaceW object ([MS-WMF] sections 2.2.2.11 and 2.2.2.12, respectively). If the deleted color space is currently selected into the **playback device context**, the default object MUST be restored.

An EMR_DELETEOBJECT record (section 2.3.8.3) SHOULD be used instead of this record to delete a logical color space object.

See section 2.3.8 for more object manipulation record types.

#### EMR_DELETEOBJECT Record

The **EMR_DELETEOBJECT** record deletes a graphics object, which is specified by its index in the EMF object table (section 3.1.1.1).

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ihObject |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_DELETEOBJECT**. This value is 0x00000028.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**ihObject (4 bytes): **An unsigned integer that specifies the index of a graphics object in the EMF object table.

This value MUST NOT be 0, which is a reserved index that refers to the **EMF** **metafile** itself; and it MUST NOT be the index of a **stock object**, which cannot be deleted. Stock object indexes are specified in the StockObject (section 2.1.31) enumeration.

The object specified by this record MUST be deleted from the EMF object table. If the deleted object is currently selected into the **playback device context**, the default object MUST be restored.

See section 2.3.8 for more object manipulation record types.

#### EMR_RESIZEPALETTE Record

The **EMR_RESIZEPALETTE** record increases or decreases the size of an existing LogPalette object (section 2.2.17).

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ihPal |
| NumberOfEntries |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_RESIZEPALETTE**. This value is 0x00000033.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**ihPal (4 bytes): **An unsigned integer that specifies the index of the **palette** object in the EMF object table (section 3.1.1.1).

**NumberOfEntries (4 bytes****): **An unsigned integer that specifies the number of entries in the palette after resizing. The value MUST be <= 0x00000400 and > 0x00000000.<78>

The new size of the LogPalette object MUST be reflected in the **NumberOfEntries** field in that structure.

See section 2.3.8 for more object manipulation record types.

#### EMR_SELECTOBJECT Record

The **EMR_SELECTOBJECT **record selects a graphics object into the **playback device context**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ihObject |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_SELECTOBJECT**. This value is 0x00000025.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**ihObject (4 bytes): **An unsigned integer that specifies either the index of a graphics object in the EMF object table (section 3.1.1.1) or the index of a **stock object** in the StockObject enumeration (section 2.1.31).

The object index MUST NOT be zero, which is reserved and refers to the **EMF** **metafile** itself.

The object specified by this record MUST be used in subsequent EMF drawing operations, until another EMR_SELECTOBJECT record changes the object of that type or the object is deleted.

See section 2.3.8 for more object manipulation record types.

#### EMR_SELECTPALETTE Record

The **EMR_SELECTPALETTE** record selects a **logical palette** into the **playback device context**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ihPal |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_SELECTPALETTE. This value is 0x00000030.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes. This value is 0x0000000C.

**ihPal (4 bytes): **An unsigned integer that specifies either the index of a LogPalette object (section 2.2.17) in the EMF object table (section 3.1.1.1) or the value DEFAULT_PALETTE from the StockObject enumeration (section 2.1.31), which is the index of a stock **palette**.

The object index MUST NOT be zero, which is reserved and refers to the **EMF** **metafile** itself.

The palette specified by this record MUST be used in subsequent EMF drawing operations, until another EMR_SELECTPALETTE record changes the object or the object is deleted.

See section 2.3.8 for more object manipulation record types.

#### EMR_SETCOLORSPACE Record

The **EMR_SETCOLORSPACE** record selects a logical **color space** into the **playback device context**.<79>

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ihCS |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_SETCOLORSPACE**. This value is 0x00000064.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes. This value is 0x0000000C.

**ihCS (4 bytes): **An unsigned integer that specifies the index of a logical color space object in the EMF object table (section 3.1.1.1).

This object is either a LogColorSpace or LogColorSpaceW object ([MS-WMF] sections 2.2.2.11 and 2.2.2.12, respectively).

The color space specified by this record MUST be used in subsequent EMF drawing operations, until another EMR_SETCOLORSPACE record changes the object or the object is deleted.

See section 2.3.8 for more object manipulation record types.

#### EMR_SETPALETTEENTRIES Record

The **EMR_SETPALETTEENTRIES** record defines **RGB** color values in a range of entries for an existing **logical palette**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ihPal |
| Start |
| NumberofEntries |
| aPalEntries (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_SETPALETTEENTRIES. This value is 0x00000032.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**ihPal (4 bytes): **An unsigned integer that specifies an index of a LogPalette object (section 2.2.17) in the EMF object table (section 3.1.1.1).

**Start (4 bytes): **An unsigned integer that specifies the index in the palette of the first entry to set.

**NumberofEntries (4 bytes): **An unsigned integer that specifies the number of entries in the **aPalEntries** array.

**aPalEntries (variable): **An array of LogPaletteEntry objects (section 2.2.18) that specify the **palette** data.

See section 2.3.8 for more object manipulation record types.

### OpenGL Record Types

The **OpenGL** record types specify **OpenGL** functions [OPENGL].

The following are **EMF** OpenGL record types.<80>

| Name | Section | Description |
| --- | --- | --- |
| EMR_GLSBOUNDEDRECORD | 2.3.9.1 | Specifies an OpenGL function with a bounding rectangle for output. |
| EMR_GLSRECORD | 2.3.9.2 | Specifies an OpenGL function. |

The generic structure of OpenGL records is specified as follows.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| OpenGLRecordBuffer (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that defines the type of record. The OpenGL record types are listed in the following table. See the preceding table for descriptions of these record types.

| Name | Value |
| --- | --- |
| EMR_GLSRECORD | 0x00000066 |
| EMR_GLSBOUNDEDRECORD | 0x00000067 |

**Size (4 bytes): **An unsigned integer that specifies the size in bytes of this record in the **metafile**. This value MUST be a multiple of 4 bytes. 

**OpenG****LRecordBuffer (variable): **An array of bytes that contains the remainder of the OpenGL record. 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| OpenGLRecordParm (variable) |
| ... |
| AlignmentPadding (variable, optional) |
| ... |

**OpenGLRecordParm (variable): **An array of bytes that contains the parameters for the OpenGL record. 

**AlignmentPadding (variable, optional): **An array of up to 3 bytes that pads the record so that its total size is a multiple of 4 bytes. This field MUST be ignored.

See section 2.3 for more EMF record types. 

#### EMR_GLSBOUNDEDRECORD Record

The **EMR_GLSBOUNDEDRECORD** record specifies an **OpenGL** function with a bounding rectangle for output.

Fields not specified in this section are specified in section 2.3.1.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| cbData |
| Data (variable, optional) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_GLSBOUNDEDRECORD. This value is 0x00000067.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that defines a bounding rectangle in logical units, for output produced by executing the OpenGL function.

**cbData (4 ****bytes): **An unsigned integer that specifies the size of the **Data** field in bytes. If this value is zero, no data is attached to this record.

**Data (variable, optional): **An array of bytes that specifies data for the OpenGL function.

See section 2.3.9 for more OpenGL record types.

#### EMR_GLSRECORD Record

The **EMR_GLSRECORD** record specifies an **OpenGL** function.

Fields not specified in this section are specified in section 2.3.1.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| cbData |
| Data (variable, optional) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_GLSRECORD. This value is 0x00000066.

**cbData (4 bytes): **An unsigned integer that specifies the size in bytes, of the **Data** field. If this value is zero, no data is attached to this record.

**Data (variable, optional): **An array of bytes that specifies data for the OpenGL function.

See section 2.3.9 for more OpenGL record types.

### Path Bracket Record Types

The **Path Bracket** record types are used to construct a **path bracket**, which defines the current **path** in the **playback device context**.

**Note: **None of the path bracket records specify parameters.

The following are the path bracket record types.

| Name | Description |
| --- | --- |
| EMR_ABORTPATH | This record closes path bracket construction and discards the current path. |
| EMR_BEGINPATH | This record opens path bracket construction.Once path bracket construction is open, an application can begin specifying records to define the points that lie in the path. Path bracket construction MUST be closed by an EMR_ABORTPATH or EMR_ENDPATH record.When an application processes an EMR_BEGINPATH record, path bracket construction MUST NOT be open. |
| EMR_CLOSEFIGURE | This record closes the figure in path bracket construction.Processing the EMR_CLOSEFIGURE record closes the figure by drawing a line from the current drawing position to the first point of the figure, and then it connects the lines by using the current **line join**. If the figure is closed by processing an EMR_LINETO record (section 2.3.5.13) instead of this record, the current **line cap** is used to create the corner instead of the line join. The line parameters are specified by the **PenStyle** field in the current LogPen (section 2.2.19) and LogPenEx (section 2.2.20) objects.The EMR_CLOSEFIGURE record SHOULD be used only if there is an open figure in the path bracket. A figure in a path is open unless it is explicitly closed by processing this record. A figure can be open even if the current point is the same as the starting point.After processing the EMR_CLOSEFIGURE record, adding a line or curve to the path bracket starts a new figure. |
| EMR_ENDPATH | This record closes path bracket construction and selects the path into the playback device context. |
| EMR_FLATTENPATH | This record transforms each curve in the current path into a sequence of lines. |
| EMR_WIDENPATH | This record redefines the current path as the area that would be painted if its path were drawn using the current pen. |

The generic structure of path bracket records is specified as follows.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |

**Type (4 bytes): **An unsigned integer that defines the type of the record. The types of records that specify no parameters are listed in the following table. See the preceding table for descriptions of these records.

| Name | Value |
| --- | --- |
| EMR_BEGINPATH | 0x0000003B |
| EMR_ENDPATH | 0x0000003C |
| EMR_CLOSEFIGURE | 0x0000003D |
| EMR_FLATTENPATH | 0x00000041 |
| EMR_WIDENPATH | 0x00000042 |
| EMR_ABORTPATH | 0x00000044 |

**Size (4 bytes): **An unsigned integer that specifies the size in bytes of this record in the **metafile**. For path bracket records, this value is 0x00000008

See section 2.3 for more EMF record types.

### State Record Types

The **State** record types specify graphics properties that define the **playback device context** during the processing of **EMF** **metafile** records. For more information about the state used for metafile playback, see the Abstract Data Model section 3.1.1.

**No****te: **The EMR_REALIZEPALETTE and EMR_SAVEDC records do not specify parameters.

The following are EMF state record types.

| Name | Section | Description |
| --- | --- | --- |
| EMR_COLORMATCHTOTARGETW | 2.3.11.1 | Specifies how to preview colors as they would appear on the target device. |
| EMR_FORCEUFIMAPPING | 2.3.11.2 | Forces the **font mapper** to match fonts based on their **UniversalFontId** in preference to LogFont (section 2.2.13). |
| EMR_INVERTRGN | 2.3.11.3 | Inverts the colors in the specified **region**. |
| EMR_MOVETOEX | 2.3.11.4 | Specifies the coordinates of a new drawing position, in logical units. |
| EMR_PIXELFORMAT | 2.3.11.5 | Specifies the pixel format. |
| EMR_REALIZEPALETTE | 2.3.11 | This record maps **palette** entries from the current LogPalette object (section 2.2.17) to the system_palette.This record specifies no parameters. |
| EMR_RESTOREDC | 2.3.11.6 | Restores the playback device context to the specified state, which was saved by a preceding **EMR_SAVEDC** record. |
| EMR_SAVEDC | 2.3.11 | Saves the current state of the playback device context in an array of states saved by preceding **EMR_SAVEDC** records if any.An **EMR_RESTOREDC** record is used to restore the state.This record specifies no parameters. |
| EMR_SCALEVIEWPORTEXTEX | 2.3.11.7 | Specifies the viewport by using the ratios formed by the specified multiplicands and divisors. |
| EMR_SCALEWINDOWEXTEX | 2.3.11.8 | Specifies the window by using the ratios formed by the specified multiplicands and divisors. |
| EMR_SETARCDIRECTION | 2.3.11.9 | Specifies the drawing direction to be used for arc and rectangle output. |
| EMR_SETBKCOLOR | 2.3.11.10 | Specifies the background color. |
| EMR_SETBKMODE | 2.3.11.11 | Specifies the background mode, which determines how to combine the background with foreground text, hatched brushes, and pen styles that are not solid lines. |
| EMR_SETBRUSHORGEX | 2.3.11.12 | Specifies the origin of the current brush. |
| EMR_SETCOLORADJUSTMENT | 2.3.11.13 | Specifies color adjustment values to use in **bitmap** stretching. |
| EMR_SETICMMODE | 2.3.11.14 | Specifies **ICM** to be enabled, disabled, or queried. |
| EMR_SETICMPROFILEA | 2.3.11.15 | Specifies how to set a specified **color profile** as the output profile. |
| EMR_SETICMPROFILEW | 2.3.11.16 | Specifies how to set a specified color profile as the output profile. |
| EMR_SETLAYOUT | 2.3.11.17 | Specifies the layout of the playback device context. |
| EMR_SETLINKEDUFIS | 2.3.11.18 | Sets the **UniversalFontId** (section 2.2.27) of the linked fonts to use during character lookup. |
| EMR_SETMAPMODE | 2.3.11.19 | Specifies the **mapping mode**. |
| EMR_SETMAPPERFLAGS | 2.3.11.20 | Specifies the algorithm the font mapper uses when it maps logical fonts to physical fonts. |
| EMR_SETMITERLIMIT | 2.3.11.21 | Specifies the limit for the length of miter joins. |
| EMR_SETPOLYFILLMODE | 2.3.11.22 | Defines polygon fill mode. |
| EMR_SETROP2 | 2.3.11.23 | Defines a binary **raster operation** mode. |
| EMR_SETSTRETCHBLTMODE | 2.3.11.24 | Specifies bitmap stretch mode. |
| EMR_SETTEXTALIGN | 2.3.11.25 | Specifies text alignment. |
| EMR_SETTEXTCOLOR | 2.3.11.26 | Defines the current text color. |
| EMR_SETTEXTJUSTIFICATION | 2.3.11.27 | Sets the amount of extra space to add to break characters for justification purposes. |
| EMR_SETVIEWPORTEXTEX | 2.3.11.28 | Defines the viewport extent. |
| EMR_SETVIEWPORTORGEX | 2.3.11.29 | Defines the viewport origin. |
| EMR_SETWINDOWEXTEX | 2.3.11.30 | Defines the window extent. |
| EMR_SETWINDOWORGEX | 2.3.11.31 | Defines the window origin. |

The generic structure of state records is specified as follows.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| StateRecordBuffer (variable, optional) |
| ... |

**Type (4 bytes): **An unsigned integer that defines the type of record. The state record types are listed in the following table. See the preceding table for descriptions of these record types.

| Name | Value |
| --- | --- |
| EMR_SETWINDOWORGEX | 0x0000000A |
| EMR_SETVIEWPORTEXTEX | 0x0000000B |
| EMR_SETVIEWPORTORGEX | 0x0000000C |
| EMR_SETBRUSHORGEX | 0x0000000D |
| EMR_SETCOLORADJUSTMENT | 0x00000017 |
| EMR_MOVETOEX | 0x0000001B |
| EMR_SCALEVIEWPORTEXTEX | 0x0000001F |
| EMR_SETWINDOWEXTEX | 0x00000009 |
| EMR_SETMAPPERFLAGS | 0x00000010 |
| EMR_SETMAPMODE | 0x00000011 |
| EMR_SETBKMODE | 0x00000012 |
| EMR_SETPOLYFILLMODE | 0x00000013 |
| EMR_SETROP2 | 0x00000014 |
| EMR_SETSTRETCHBLTMODE | 0x00000015 |
| EMR_SETTEXTALIGN | 0x00000016 |
| EMR_SETTEXTCOLOR | 0x00000018 |
| EMR_SETBKCOLOR | 0x00000019 |
| EMR_SCALEWINDOWEXTEX | 0x00000020 |
| EMR_SAVEDC | 0x00000021 |
| EMR_RESTOREDC | 0x00000022 |
| EMR_REALIZEPALETTE | 0x00000034 |
| EMR_SETARCDIRECTION | 0x00000039 |
| EMR_SETMITERLIMIT | 0x0000003A |
| EMR_INVERTRGN | 0x00000049 |
| EMR_SETICMMODE | 0x00000062 |
| EMR_PIXELFORMAT | 0x00000068 |
| EMR_FORCEUFIMAPPING | 0x0000006D |
| EMR_SETICMPROFILEA | 0x00000070 |
| EMR_SETICMPROFILEW | 0x00000071 |
| EMR_SETLAYOUT | 0x00000073 |
| EMR_SETLINKEDUFIS | 0x00000077 |
| EMR_SETTEXTJUSTIFICATION | 0x00000078 |
| EMR_COLORMATCHTOTARGETW | 0x00000079 |

**Size (4 bytes): **An unsigned integer that specifies the size in bytes of this record in the metafile. This value MUST be a multiple of 4 bytes.

**StateRecordBuffer (variable, optional): **An array of bytes that contains the remainder of the state record.

The EMR_REALIZEPALETTE and EMR_SAVEDC records do not contain this field.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| StateRecordParm (variable) |
| ... |
| AlignmentPadding (variable, optional) |
| ... |

**StateRecordParm (variable): **An array of bytes that contains the parameters for the state record.

**AlignmentPadding (variable, optional): **An array of up to 3 bytes that pads the record so that its total size is a multiple of 4 bytes. This field MUST be ignored.

See section 2.3 for more EMF record types.

#### EMR_COLORMATCHTOTARGETW Record

The **EMR_COLORMATCHTOTARGETW** record specifies whether to perform **color matching** with a **color profile** that is specified in a file with a name consisting of **Unicode** characters.<81>

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| dwAction |
| dwFlags |
| cbName |
| cbData |
| Data (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_COLORMATCHTOTARGETW. This value is 0x00000079.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**dwAction (4 bytes): **An unsigned integer that specifies a value from the ColorSpace enumeration (section 2.1.7).

**dwFlags (4 bytes): **An unsigned integer that specifies a value from the ColorMatchToTarget enumeration (section 2.1.6).

**cbName (4 bytes): **An unsigned integer that specifies the number of bytes in the Unicode **UTF16-LE** name of the target color profile.

**cbData (4 bytes): **An unsigned integer that specifies the size of the raw data of the target color profile in the **Data** field.

**Data (variable): **An array of size (**cbName** + **cbData**) bytes, which specifies the UTF16-LE name and raw data of the target color profile. 

An EMR_COLORMATCHTOTARGETW record can be used to control whether to apply the current color **transform** to subsequent graphics operations. If the **dwAction** field value is **CS_ENABLE**, **color mapping** is enabled, and the current color transform SHOULD be applied. If **dwAction** is set to **CS_DISAB****LE**, the color transform SHOULD NOT be applied.

Before applying the current color transform, **WCS** SHOULD be enabled in the **playback de****vice context**.<82>

While color mapping to the target is enabled by a **dwAction** value of **CS_ENABLE**, changes to the **color space** or **color gamut** mapping are not applied. However, those changes MUST take effect when color mapping to the target is disabled.

The **dwAction** field SHOULD NOT be set to **CS_DELETE_TRANSFORM** unless color management has already been enabled with an EMR_SETICMMODE record (section 2.3.11.14).

See section 2.3.11 for more state record types.

#### EMR_FORCEUFIMAPPING Record

The **EMR_FORCEUFIMAPPING** record forces the font mapper to match fonts based on their **UniversalFontId** in preference to their LogFont (section 2.2.13) information.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ufi |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_FORCEUFIMAPPING. This value is 0x0000006D.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**ufi (8 bytes): **The font id to use, specified as a UniversalFontId (section 2.2.27). 

See section 2.3.5 for more drawing record types.

#### EMR_INVERTRGN Record

The **EMR_INVERTRGN** record inverts the colors in the specified **region**. The current clipping regions used by this record are maintained in a **Regions** state element (section 3.1.1.2.1) in the **playback device context** (section 3.1).

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 |  | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Bounds |
| ... |
| ... |
| ... |
| RgnDataSize |
| RgnData (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_INVERTRGN. This value is 0x00000049.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Bounds (16 bytes): **A RectL object ([MS-WMF] section 2.2.2.19) that specifies the destination bounding rectangle in logical coordinates. If the intersection of this rectangle with the current clipping region is empty, this record has no effect.

**RgnDataSize (4 bytes): **An unsigned integer that specifies the size of region data in bytes.

**RgnData (variable): **A **RgnDataSize** length array of bytes that specifies the output region in a **RegionData** object (section 2.2.24). The bounds specified by the **RegionDataHeader** field of this object MAY<83> be used as the bounding rectangle of the region when this record is processed.

If the output surface is monochrome, this record SHOULD convert white pixels to black and black pixels to white. For color output, the inversion is dependent on the type of technology used to generate the colors.

See section 2.3.11 for more state record types.

#### EMR_MOVETOEX Record

The EMR_MOVETOEX record specifies the coordinates of s new drawing position in logical units.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Offset |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_MOVETOEX**. This value is 0x0000001B.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Offset (8 bytes): **A PointL object ([MS-WMF] section 2.2.2.15), which specifies coordinates of the new drawing position in logical units.

See section 2.3.11 for more state record types.

#### EMR_PIXELFORMAT Record

The EMR_PIXELFORMAT record specifies the pixel format to use for graphics operations.<84>

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| pfd (40 bytes) |
| ... |
| ... |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_PIXELFORMAT**. This value is 0x00000068.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**pfd (40 bytes): **A PixelFormatDescriptor object (section 2.2.22) that specifies pixel format data.

See section 2.3.11 for more state record types.

#### EMR_RESTOREDC Record

The **EMR_RESTOREDC** record restores the **playback device context** to the specified state. The playback device context is restored by popping state information off a stack that was created by a prior EMR_SAVEDC** **record (section 2.3.11).

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| SavedDC |

**Type (4 bytes): **An unsigned integer that identifies the record type as **EMR_RESTOREDC**. This value is 0x00000022.

**Size (4 bytes): **An unsigned integer that specifies the size of the record in bytes. This value is 0x0000000C.

**SavedDC (4 bytes): **A signed integer that specifies the saved state to restore relative to the current state. This value MUST be negative; –1 represents the state that was most recently saved on the stack, –2 the one before that, etc. 

The stack can contain state information for multiple instances of the playback device context. When a state is restored, all state instances that were saved more recently MUST be discarded.

See section 2.3.11 for more state record types.

#### EMR_SCALEVIEWPORTEXTEX Record

The **EMR_SCALEVIEWPORTEXTEX** record specifies the current viewport in the **playback device context** by using ratios formed by the specified multiplicands and divisors.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| xNum |
| xDenom |
| yNum |
| yDenom |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_SCALEVIEWPORTEXTEX. This value is 0x0000001F.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**xNum (4 bytes): **A signed integer that specifies the horizontal multiplicand. Cannot be zero.

**xDenom (4 bytes): **A signed integer that specifies the horizontal divisor. Cannot be zero.

**yNum (4 bytes): **A signed integer that specifies the vertical multiplicand. Cannot be zero.

**yDenom (4 bytes): **A signed integer that specifies the vertical divisor. Cannot be zero.

The extent MUST NOT be changed if the current **mapping mode** (section 2.1.21) is fixed scale. Only MM_ISOTROPIC and MM_ANISOTROPIC are not fixed scale. 

The new viewport extent is computed as follows.

xNewWE = (xOldWE * xNum) / xDenom

yNewWE = (yOldWE * yNum) / yDenom

See section 2.3.11 for more state record types.

#### EMR_SCALEWINDOWEXTEX Record

The **EMR_SCALEWINDOWEXTEX** record specifies the current window in the **playback device context** by using ratios formed by the specified multiplicands and divisors.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| xNum |
| xDenom |
| yNum |
| yDenom |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_SCALEWINDOWEXTEX. This value is 0x00000020.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**xNum (4 bytes): **A signed integer that specifies the horizontal multiplicand. MUST NOT be zero.

**xDenom (4 bytes): **A signed integer that specifies the horizontal divisor. MUST NOT be zero.

**yNu****m (4 bytes): **A signed integer that specifies the vertical multiplicand. MUST NOT be zero.

**yDenom (4 bytes): **A signed integer that specifies the vertical divisor. MUST NOT be zero.

The extent MUST NOT be changed if the current **mapping mode** (section 2.1.21) is fixed scale. Only MM_ISOTROPIC and MM_ANISOTROPIC are not fixed scale. 

The new window extent is computed as follows.

xNewWE = (xOldWE * xNum) / xDenom

yNewWE = (yOldWE * yNum) / yDenom

See section 2.3.11 for more state record types.

#### EMR_SETARCDIRECTION Record

The **EMR_SETARCDIRECTION** record specifies the drawing direction to be used for arc and rectangle output.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ArcDirection |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_SETARCDIRECTION. This value is 0x00000039.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes. This value is 0x0000000C.

**ArcDirection (4 bytes): **An unsigned integer that specifies the arc direction. This value is in the ArcDirection enumeration (section 2.1.2). The default direction is counterclockwise.

The arc direction affects the direction in which the following records draw:

EMR_ARC (section 2.3.5.2)

EMR_ARCTO (section 2.3.5.3)

EMR_CHORD (section 2.3.5.4)

EMR_ELLIPSE (section 2.3.5.5)

EMR_PIE (section 2.3.5.15)

EMR_RECTANGLE (section 2.3.5.34)

EMR_ROUNDRECT (section 2.3.5.35)

See section 2.3.11 for more state record types.

#### EMR_SETBKCOLOR Record

The **EMR_SETBKCOLOR** record specifies the background color for text output.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Color |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_SETBKCOLOR. This value is 0x00000019.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Color (4 bytes): **A ColorRef object ([MS-WMF] section 2.2.2.8), which specifies the background color value.

See section 2.3.11 for more state record types.

#### EMR_SETBKMODE Record

The **EMR_SETBKMODE** record specifies the background mix mode to use with text, hatched brushes, and pens that are not solid lines.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| BackgroundMode |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_SETBKMODE. This value is 0x00000012.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**BackgroundMode (4 bytes): **An unsigned integer that specifies the background mode, from the BackgroundMode enumeration (section 2.1.4).

See section 2.3.11 for more state record types.

#### EMR_SETBRUSHORGEX Record

The **EMR_SETBRUSHORGEX** record specifies the origin of the current brush.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Origin |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_SETBRUSHORGEX. This value is 0x0000000D.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Origin (8 bytes): **A PointL object ([MS-WMF] section 2.2.2.15), which specifies the horizontal and vertical origin of the current brush in logical units.

See section 2.3.11 for more state record types.

#### EMR_SETCOLORADJUSTMENT Record

The **EMR_SETCOLORADJUSTMENT** record specifies color adjustment properties in the **playback device context**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ColorAdjustment (24 bytes) |
| ... |
| ... |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_SETCOLORADJUSTMENT**. This value is 0x00000017.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes. This value is 0x00000020.

**ColorAdjustment (24 bytes): **A ColorAdjustment object (section 2.2.2) that specifies color adjustment values.

Color adjustment values are used to adjust the input color of the source **bitmap** for graphics operations performed by EMR_STRETCHBLT and EMR_STRETCHDIBITS records when **STRETCH_HALFTONE** mode is set from the StretchMode enumeration (section 2.1.32). 

 The ColorAdjustment object specified by this record MUST be used in graphics operations that require a ColorAdjustment object, until a different ColorAdjustment object is specified by another EMR_SETCOLORADJUSTMENT record, or until the object is removed by a EMR_DELETEOBJECT record.

See section 2.3.11 more state record types.

#### EMR_SETICMMODE Record

The **EMR_SETICMMODE** record specifies the mode of **Image Color Management (ICM)** for graphics operations.<85>

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ICMMode |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_SETICMMODE**. This value is 0x00000062.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes. This value is 0x0000000C.

**ICMMode (4 bytes): **An unsigned integer that specifies whether to enable or disable ICM, from the ICMMode enumeration (section 2.1.18).

When ICM mode is enabled in the **playback device context**, colors specified in EMF records SHOULD be **color matched**, whereas the default **color profile** SHOULD be used when a bit-block transfer is performed. If the default color profile is not desired, ICM mode SHOULD be turned off before performing the bit-block transfer.

See section 2.3.11 for more state record types.

#### EMR_SETICMPROFILEA Record

The **EMR_SETICMPROFILEA** record specifies a **color profile** in a file with a name consisting of **ASCII** characters, for graphics output.<86>

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| dwFlags |
| cbName |
| cbData |
| Data (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_SETICMPROFILEA. This value is 0x00000070.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**dwFlags (4 bytes): **An unsigned integer that contains color profile flags.

**cbName (4 bytes): **An unsigned integer that specifies the number of bytes in the ASCII name of the desired color profile.

**cbData (4 bytes): **An unsigned integer that specifies the size of the color profile data, if it is contained in the **Data** field.

**Data (variable): **An array of size (**cbName** + **cbData**) in bytes, which specifies the ASCII name and raw data of the desired color profile.

See section 2.3.11 for more state record types.

#### EMR_SETICMPROFILEW Record

The **EMR_SETICMPROFILEW** record specifies a **color profile** in a file with a name consisting of **Unic****ode** characters, for graphics output.<87>

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| dwFlags |
| cbName |
| cbData |
| Data (variable) |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_SETICMPROFILEW**. This value is 0x00000071.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**dwFlags (4 bytes): **An unsigned integer that contains color profile flags.

**cbName (4 bytes): **An unsigned integer that specifies the number of bytes in the Unicode **UTF16-LE** name of the desired color profile.

**cbData (4 bytes): **An unsigned integer that specifies the size of color profile data, if attached.

**Data (variable): **An array of size (**cbName** + **cbData**) in bytes, which specifies the UTF16-LE name and raw data of the desired color profile.

See section 2.3.11 for more state record types.

#### EMR_SETLAYOUT Record

The **EMR_SETLAYOUT** record specifies the order in which text and graphics are drawn.<88>

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| LayoutMode |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_SETLAYOUT. This value is 0x00000073.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes. This value is 0x0000000C.

**LayoutMode (4 bytes): **An unsigned integer that specifies the layout mode as follows: 

| Value | Meaning |
| --- | --- |
| LAYOUT_LTR0x00000000 | Sets the default horizontal layout to be left-to-right. This is the default mode for English and European locales. |
| LAYOUT_RTL0x00000001 | Sets the default horizontal layout to be right-to-left. This mode is required for some languages, including Arabic and Hebrew. |
| LAYOUT_BITMAPORIENTATIONPRESERVED0x00000008 | Disables mirroring of bitmaps that are drawn by bitmap records (section 2.3.1) when the layout mode is right-to-left. |

See section 2.3.11 for more state record types.

#### EMR_SETLINKEDUFIS Record

The **EMR_SETLINKEDUFIS** record sets the **UniversalFontIds** (section 2.2.27) of linked fonts to use during character lookup.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| uNumLinkedUFI |
| ufis (variable) |
| ... |
| Reserved |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_SETLINKEDUFIS**. This value is 0x00000077.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**uNumLinkedUFI (4 bytes): **An unsigned integer specifying the number of UFIs to follow.

**ufis (variable): **An array of **uNumLinkedU****FI** elements of type UniversalFontId (section 2.2.27), which specifies the identifiers of the linked fonts.

**Reserved (8 bytes): **This field is reserved and MUST be ignored.

See section 2.3.11 for more state record types.

#### EMR_SETMAPMODE Record

The **EMR_SETMAPMODE** record specifies the current **mapping mode**, which specifies the unit of measure used to transform **page space** units into **device space** units, and also specifies the orientation of the device's x-axis and y-axis.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| MapMode |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_SETMAPMODE**. This value is 0x00000011.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**MapMode (4 bytes): **An unsigned integer from the MapMode enumeration (section 2.1.21).

**MM_TEXT** mode allows applications to work in device pixels, whose size varies from device to device.

The **MM_HIENGLISH**, **MM_HIMETRIC**, **MM_LOENGLISH**, **MM_LOMETRIC**, and **MM_TWIPS** modes are useful for applications drawing in physically meaningful units such as inches or millimeters.

**MM_ISOTROPIC** mode ensures a 1:1 aspect ratio.

**M****M_ANISOTROPIC** mode allows the x-coordinates and y-coordinates to be adjusted independently.

See section 2.3.11 for more state record types.

#### EMR_SETMAPPERFLAGS Record

The **EMR_SETMAPPERFLAGS** record specifies parameters for the process of matching logical fonts to physical fonts, which is performed by the **font mapper**.<89>

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Flags |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_SETMAPPERFLAGS. This value is 0x00000010.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes. This value is 0x0000000C.

**Flags (4 bytes): **An unsigned integer that specifies parameters for the font matching process.

| Value | Meaning |
| --- | --- |
| 0x00000000 | The font mapper is not limited to fonts that match the **aspect ratio** of the output device. |
| 0x00000001 | The font mapper SHOULD select only fonts that match the aspect ratio of the output device. |

See section 2.3.11 for more state record types.

#### EMR_SETMITERLIMIT Record

The EMR_SETMITERLIMIT record specifies the limit for the length of miter joins.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| MiterLimit |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_SETMITERLIMIT**. This value is 0x0000003A.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**MiterLimit (4 bytes): **An unsigned integer that specifies the new **miter length** limit.<90>

See section 2.3.11 for more state record types.

#### EMR_SETPOLYFILLMODE Record

The **EMR_SETPOLYFILLMODE** record defines polygon fill mode.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| PolygonFillMode |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_SETPOLYFILLMODE. This value is 0x00000013.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**PolygonFillMode (4 bytes): **An unsigned integer that specifies the polygon fill mode and is in the PolygonFillMode (section 2.1.27) enumeration.

In general, the modes differ only in cases where a complex, overlapping polygon MUST be filled; for example, a five-sided polygon that forms a five-pointed star with a pentagon in the center. In such cases, ALTERNATE mode SHOULD fill every other enclosed **region** within the polygon (the points of the star), but WINDING mode SHOULD fill all regions (the points of the star and the pentagon).

When the fill mode is ALTERNATE, the area between odd-numbered and even-numbered polygon sides on each scan line SHOULD be filled. That is, the area between the first and second side SHOULD be filled, and between the third and fourth side, and so on.

When the fill mode is WINDING, any region that has a nonzero winding value SHOULD be filled. The winding value is the number of times a pen used to draw the polygon would go around the region. The direction of each edge of the polygon is significant.

See section 2.3.11 for more state record types.

#### EMR_SETROP2 Record

The EMR_SETROP2 record defines a binary **raster oper****ation** mode.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| ROP2Mode |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_SETROP2**. This value is 0x00000014.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**ROP2Mode (4 bytes): **An unsigned integer that specifies the raster operation mode and is in the Binary Raster Op enumeration ([MS-WMF] section 2.1.1.2).

Binary raster operation mix modes define how to combine source and destination colors when drawing with the current pen. The mix modes are binary raster operation codes, representing all possible **Boolean** functions of two variables, using the binary operations AND, OR, and XOR (exclusive OR), and the unary operation NOT. The mix mode is for raster devices only; it is not available for vector devices.

See section 2.3.11 for more state record types.

#### EMR_SETSTRETCHBLTMODE Record

The EMR_SETSTRETCHBLTMODE record specifies **bitmap** stretch mode.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| StretchMode |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_SETSTRETCHBLTMODE**. This value is 0x00000015.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**StretchMode (4 bytes): **An unsigned integer that specifies the stretch mode and MAY be in the StretchMode enumeration.

The stretching mode specifies how to combine rows or columns of a bitmap with existing pixels on the display device that the EMR_STRETCHBLT record is processed on.

The **STRETCH_ANDSCANS** and **STRETCH_ORSCANS** modes are typically used to preserve foreground pixels in monochrome bitmaps. The **STRETCH_DELETESCANS** mode is typically used to preserve color in color bitmaps.

The **STRETCH_HALFTONE** mode is slower and requires more processing of the source image than the other three modes, but produces higher quality images. Also note that an EMR_SETBRUSHORGEX SHOULD be encountered after setting the **STRETCH_HALFTONE** mode to avoid brush misalignment.

See section 2.3.11 for more state record types.

#### EMR_SETTEXTALIGN Record

The **EMR_SETTEXTALIGN** record specifies text alignment for text drawing.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| TextAlignmentMode |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_SETTEXTALIGN. This value is 0x00000016.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**TextAlignmentMode (4 bytes): **An unsigned integer that specifies text alignment by using a mask of text alignment flags. These are either TextAlignmentMode flags ([MS-WMF] section 2.1.2.3) for text with a horizontal baseline, or VerticalTextAlignmentMode flags ([MS-WMF] section 2.1.2.4) for text with a vertical baseline. Only one value can be chosen from those that affect horizontal and vertical alignment.

The EMR_SMALLTEXTOUT, EMR_EXTTEXTOUTA, and EMR_EXTTEXTOUTW records (section 2.3.5) use text alignment values to position a string of text on the output medium. The values specify the relationship between a reference point and a rectangle that bounds the text. The reference point is either the current drawing position or a point passed to a text output record.

The rectangle that bounds the text is formed by the character cells in the text string.

See section 2.3.11 for more state record types.

#### EMR_SETTEXTCOLOR Record

The **EMR_SETTEXTCOLOR** record defines the current text foreground color.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Color |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_SETTEXTCOLOR. This value is 0x00000018.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Color (4 bytes): **A ColorRef object ([MS-WMF] section 2.2.2.8) that specifies the text foreground color.

See section 2.3.11 for more state record types.

#### EMR_SETTEXTJUSTIFICATION Record

The **EMR_SETTEXTJUSTIFICATION** record specifies the amount of extra space to add to break characters for text justification.<91>

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| nBreakExtra |
| nBreakCount |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_SETTEXTJUSTIFICATION. This value is 0x00000078.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**nBreakExtra (4 bytes): **A signed integer that specifies the total amount of extra space to add in logical units.

**nBreakCount (4 bytes): **A signed integer that specifies the number of break characters.

Instead of using this record, an implementation SHOULD use EMR_EXTTEXTOUTW (section 2.3.5.8) to perform this function.

See section 2.3.11 for more state record types.

#### EMR_SETVIEWPORTEXTEX Record

The **EMR_SETVIEWPORTEXTEX** record defines the viewport extent.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Extent |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_SETVIEWPORTEXTEX. This value is 0x0000000B.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Extent (8 bytes): **A SizeL object ([MS-WMF] section 2.2.2.22) that specifies the horizontal and vertical extents in device units.

See section 2.3.11 for more state record types.

#### EMR_SETVIEWPORTORGEX Record

The **EMR_SETVIEWPORTORGEX** record defines the viewport origin.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Origin |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_SETVIEWPORTORGEX. This value is 0x0000000C.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Origin (8 bytes): **A PointL object ([MS-WMF] section 2.2.2.15) that specifies the window horizontal and vertical origin in device units.

See section 2.3.11 for more state record types.

#### EMR_SETWINDOWEXTEX Record

The **EMR_SETWINDOWEXTEX** record defines the window extent.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Extent |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_SETWINDOWEXTEX. This value is 0x00000009.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Extent (8 bytes): **A SizeL object ([MS-WMF] section 2.2.2.22) that specifies the horizontal and vertical extents in logical units.

See section 2.3.11 for more state record types.

#### EMR_SETWINDOWORGEX Record

The **EMR_SETWINDOWORGEX** record defines the window origin.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Origin |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as EMR_SETWINDOWORGEX. This value is 0x0000000A.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes.

**Origin (8 bytes): **A PointL object ([MS-WMF] section 2.2.2.15) that specifies the window horizontal and vertical origin in logical units.

See section 2.3.11 for more state record types.

### Transform Record Types

The transform record types specify and modify **world-space** to **page-space** **transforms**.

The following are **EMF** transform record types.

| Name | Section | Description |
| --- | --- | --- |
| EMR_MODIFYWORLDTRANSFORM | 2.3.12.1 | Modifies the current world-space to page-space transform. |
| EMR_SETWORLDTRANSFORM | 2.3.12.2 | Specifies a two-dimensional linear transform between world space and page space. |

The generic structure of EMF transform records is specified as follows.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Xform (24 bytes) |
| ... |
| ... |
| ... |
| TransformData (optional) |

**Type (4 bytes): **An unsigned integer that defines the type of record. The transform record types are listed in the following table. See the preceding table for descriptions of these record types.

| Name | Value |
| --- | --- |
| EMR_SETWORLDTRANSFORM | 0x00000023 |
| EMR_MODIFYWORLDTRANSFORM | 0x00000024 |

**Size (4 bytes): **An unsigned integer that specifies the size in bytes of this record in the **metafile**. This value MUST be a multiple of 4 bytes. 

**Xform (24 bytes): **An XForm object (section 2.2.28), which defines a world-space to page-space transform.

**TransformData (4 bytes, optional): **An unsigned integer that specifies an additional parameter for the record.

 See section 2.3 for more EMF record types. 

#### EMR_MODIFYWORLDTRANSFORM Record

The EMR_MODIFYWORLDTRANSFORM record modifies the current **world-space** to **page-space** **transform** in the **playback devi****ce context**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Xform (24 bytes) |
| ... |
| ... |
| ... |
| ModifyWorldTransformMode |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_MODIFYWORLDTRANSFORM**. This value is 0x00000024.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes. This value is 0x00000024.

**Xform (24 bytes): **An XForm object (section 2.2.28) that defines a two-dimensional linear transform in logical units. This transform is used according to the **ModifyWorldTransformMode** to define a new value for the world-space to page-space transform in the playback device context.

**ModifyWorldTransformMode (4 bytes): **An unsigned integer that specifies how the transform specified in **Xform** is used. This value is in the ModifyWorldTransformMode enumeration (section 2.1.24).

For more information concerning transforms and **coordinate spaces**, see [MSDN-WRLDPGSPC]. See section 2.3.12 for more transform record types.

#### EMR_SETWORLDTRANSFORM Record

The EMR_SETWORLDTRANSFORM record specifies a **transform** for the current **world-space** to **page-space** transform in the **playback d****evice context**.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type |
| Size |
| Xform (24 bytes) |
| ... |
| ... |
| ... |

**Type (4 bytes): **An unsigned integer that identifies this record type as **EMR_SETWORLDTRANSFORM**. This value is 0x00000023.

**Size (4 bytes): **An unsigned integer that specifies the size of this record in bytes. This value is 0x00000020.

**Xform (24 bytes): **An XForm object (section 2.2.28) that specifies a two-dimensional linear transform in logical units. This transform defines a new value for the current world-space to page-space transform.

For more information concerning transforms and **coordinate spaces**, see [MSDN-WRLDPGSPC]. See section 2.3.12 for more transform record types.
