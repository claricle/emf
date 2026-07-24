---
source: [MS-WMF]-240423.docx
chapter_number: 3
chapter_title: "Structure Examples"
word_count: 5224
---

# Structure Examples

## Metafile Design

### Device Independence

**WMF** **metafiles** are useful for transferring images between applications. Most applications support the **clipboard format** associated with metafiles, called **METAFILEPICT** (for more information, see [MSDN-CLIPFORM]). When treated as a single graphics primitive, a metafile is easy to paste into an application without that application needing to know the specific content of the image. An application can store a metafile in global memory or to disk.

The **mapping mode** of a metafile can be altered during playback. Thus, the image can be scaled arbitrarily, with every component scaling separately, which minimizes the loss of information for the image as a whole, which is not characteristic of **bitmaps**.

To ensure that metafiles can be transported between different computers and applications, any application that creates a metafile needs to ensure that the metafile is device independent and sizable. The following guidelines help ensure that every metafile can be accepted and manipulated by other applications:

Set the mapping mode as one of the first records. Some applications only accept metafiles that are in MM_ANISOTROPIC mode.

Set the **META_SETWINDOWORG** (section 2.3.5.31) and **META_SETWINDOWEXT** (section 2.3.5.30) records. Do not use the **META_SETVIEWPORTEXT** (section 2.3.5.28) or **META_SETVIEWPORTORG** (section 2.3.5.29) record if the user will be able to resize or change the dimensions of the object.

Do not use any of the **region** records, because they are device dependent.

Use **META_STRETCHBLT** (section 2.3.1.5) or **META_STRETCHDIB** (section 2.3.1.6) instead of **META_BITBLT** (section 2.3.1.1).

Terminate the metafile with a **META_EOF** **Record** (section 2.3.2.1) (0x0000).

### Byte Ordering Example

The following code snippet illustrates how the use of the **big-endian** and **little-endian** methods can affect the compatibility of applications.

#include <unistd.h>

#include <sys/stat.h>

#include <fcntl.h>

int main()

{

 int buf; 

 int in; 

 int nread;

 in = open("file.in", O_RDONLY); 

 nread = read(in, (int *) &buf, sizeof(buf));

 printf("First Integer in file.in = %x\n", buf);

 exit(0);

}

In the preceding code, if the first integer word stored in the file.in file on a big-endian computer was the hexadecimal number 0x12345678, the resulting output on that computer would be as follows.

% ./test

First Integer in file.in = 12345678

%

If the file.in file were read by the same program running on a little-endian computer, the resulting output would be as follows.

% ./test

First Integer in file.in = 78563412

%

Because of the difference in output, **metafile** record processing can be implemented so that it can read integers from a file based on the endian method that the output computer uses.

Because metafiles were developed and written with little-endian computers, computers that are big-endian based will have to perform this necessary compensation.

### Mapping Modes

When an application pastes a **WMF** **metafile** from a **clipboard**, the application can determine the size of metafile output. For this to work cleanly between applications, be aware of the following:

The metafile is responsible for specifying the window part of the **mapping mode**.

The player of the metafile is responsible for the viewport part of the mapping mode.

To perform a simple playback of the metafile, an application can perform the following initialization before processing records.

Set the mapping mode to the mode specified in the **METAFILEPICT** structure (for more information, see [MSDN-CLIPFORM]).

Convert the horizontal and vertical extents of the viewport to logical units, if necessary (see the following).

Perform scaling computations, if required (see below).

Set the viewport origin according to the desired placement of the metafile.

If the mapping mode in a metafile is **MM_ANISOTROPIC** or **MM_ISOTROPIC**, coordinate conversion might be required, as mentioned earlier. If the horizontal and vertical extents of the image are given in **MM_HIMETRIC** coordinates, they are converted to pixel values. Before playback, the application sets the viewport origin to the desired location, sets the mapping mode to the specified mode, and computes the viewport extents. If no extents are specified in the METAFILEPICT structure, the application performing the playback can arbitrarily choose a size.

Thus, scaling a metafile that uses the **MM_ANISOTROPIC** or **MM_ISOTROPIC** mapping modes can be performed by changing the viewport extents to the appropriate dimensions before playback. The viewport defines the size of the metafile image. 

To scale metafiles that use any other mapping mode, first convert the metafile to use **MM_ANISOTROPIC** mapping mode. The metafile itself does not need to change, but the mapping mode setup does need to be correct before beginning the playback.

### Managing Objects

#### WMF Object Table

The **WMF Object Table** is a conceptual element of **W****MF** graphics objects management. **Graphics Objects** (section 2.2.1) include **Brush Objects** (section 2.2.1.1), **Font Objects** (section 2.2.1.2), **Palette Objects** (section 2.2.1.3), **Pen Objects** (section 2.2.1.4), and **Regi****on Objects** (section 2.2.1.5); they can be defined, used, reused, and deleted by records in a WMF **metafile**. This section describes a hypothetical **WMF Object Table** to keep track of graphics objects during the processing of a WMF metafile.

The **WMF Object Table** is simply an array of indexes assigned to graphics object structures defined during the processing of a WMF metafile. The maximum number of indexes needed in a **WMF Object Table** for a given metafile can be computed from the total number of objects defined in the metafile, which is specified by the **NumberOfObjects** field in the WMF **META_HEADER Record** (section 2.3.2.2). An implementation of the **WMF Object Table** will store and manage that number of objects.

Whenever a graphics object is created by one of the **Object Record Types** listed in section 2.3.4, the following actions are implied:

Every object is assigned the lowest available index—that is, the smallest numerical value—in the **WMF Object Table**. This binding happens at object creation, not when the object is used. Moreover, each object table index uniquely refers to an object. Indexes in the **WMF Object Table** always start at 0.

Subsequent WMF records refer to an object by its assigned **WMF Object ****Table** index. However, there is no requirement that every object defined in the metafile will be used.

An object is not used in drawing operations until a **META_SELECTOBJECT Record** (section 2.3.4.10) is received that specifies its **WMF Object Table** index. This record activates the object and makes it current in the **Playback Device Context** section 3.1.5).

Later in the processing of the metafile, another **META_SELECTOBJECT Record** might be encountered that selects a different object of the same object type into the **playback device context**. When that happens, the previously defined object is not deleted, and its index is not returned to the pool of available indexes.

 When a **META_DELETEOBJECT Record** (section 2.3.4.7) is received that specifies this object's particular index, the object's resources are released, the binding to its **WMF Object Table** index is ended, and the index value is returned to the pool of available indexes. The index will be reused, if needed, by a subsequent object created by another **Object Record Type** (section 2.3.4) record.

Thus, graphics object creation, use, and deletion depend on the correct order of records during playback to achieve the expected results.

**Note**  This specification does not mandate that implementations adhere to the implementation of the **WMF Object Table** presented in this section, as long as the implementation of external behavior is compatible with the behavior described in this specification.

#### Object Scaling

A **metafile** that is created by an application and then passed to another application is likely to be scaled. Scaling can alter the desired image in a way that was not anticipated by the originating application, which does not scale the image. Every logical measure defined in a **logical object** is scaled before the object is realized into physical form.

For a logical object such as pens, the width is transformed from logical to physical as an x-scalar value. If the metafile is scaled in y but not in x, the pen width is unchanged. If the metafile is scaled in x but not in y, the pen width does scale. Thus, using a pen of width 1 in a metafile results in a pen that is wider (thick and slow) when the metafile is scaled. If a nominal width pen (width of 1 at all times) is wanted, use 0 as the width because it is not affected by **mapping modes**. A 0-width pen is drawn as having a width of 1.

Font sizing is more complicated. The two values that scale in a logical font are the height and the width. Most applications use a width of 0 to define a font, which results in a physical font with a width that was designed for the given height. As the metafile is stretched in x, the font remains the same size. As the metafile is stretched in y, however, the physical font grows bigger and probably wider. In and of itself, this is not bad, but problems arise when the metafile makes assumptions about the width of the font by placing the characters of a text string individually, using **META_EXTTEXTOUT Record** (section 2.3.3.5) with a width array, or using a **META_TEXTOUT Record** (section 2.3.3.20) for each character. In either case, the x-placement of each character scales with the metafile, but the font's width does not necessarily scale accordingly, which causes characters to overlap or be widely spaced.

The simplest way to overcome this problem is not to place the characters individually but to use **META_TEXTOUT** (or **META_EXTTEXTOUT** with no width array) to output the whole string. The text string remains intact, but its size can change in relation to the rest of the image when x and y are not scaled identically. Another possibility is to define the font with a nonzero width so that it scales in x as well as in y. However, doing so is problematic, because its **bitmapped** fonts might not scale independently in x and y. Scaling a font's width is also possible; unfortunately, any time a font's width is scaled, the look of the **typeface** changes in ways not necessarily intended by the designers, and a typographically "incorrect" typeface results.

### Playback Device Context

The **playback device context** is an abstract data structure that defines the state of graphics at any point in time during playback of a **WMF** **metafile**. The graphics state includes:

A complete set of **Graphics Objects** (section 2.2.1), including a brush, font, palette, pen, and region, which are created and managed by WMF **Object Record Types** (section 2.3.4).

A set of selected **Structure Objects** (section 2.2.2), which define parameters of the output surface. These elements of the playback device context are not explicitly created by any record, but they can be modified.

A vector of graphics properties, which are numerical values that specify modes and parameters for graphics operations.

Although the state defined by the playback device context can be modified by WMF records, there is no guarantee that every graphics object and property will be explicitly initialized by records in a given metafile before any output takes place. Thus, whenever a metafile is played back, it is necessary to define initial conditions consisting of a set of default values for the playback device context. These initial conditions are dependent on multiple factors, including the operating system and the device that is the destination for output.<67>

The following table lists the graphics objects that are defined in the playback device context.

| Graphics object | Created by record(s) | Used by record(s) | Notes |
| --- | --- | --- | --- |
| **Brush Object** (section 2.2.1.1) | **META_CREATEBRUSHINDIRECT Record** (section 2.3.4.1)**META_CREATEPATTERNBRUSH Record** (section 2.3.4.4)**META_DIBCREATEPATTERNBRUSH Record** (section 2.3.4.8) | **Bitmap Record Types** (section 2.3.1), when the **raster operation** involves a brush.**Drawing Record Types** (section 2.3.3) that perform area filling. | This object is not used until it is specified in a **META_SELECTOBJECT Record** (section 2.3.4.10).The default is a solid color brush **stock object**. |
| **Font Object** (section 2.2.1.2) | **META_CREATEFONTINDIRECT Recor**d (section 2.3.4.2) | **META_EXTT****EXTOUT Record** (section 2.3.3.5)**META_TEXTOUT Record** (section 2.3.3.20) | This object is not used until it is specified in a **META_SELECTOBJ****ECT Record** (section 2.3.4.10).The default is a stock object. |
| **Palette Object** (section 2.2.1.3) | **META_ANIMATEPALETTE Record** (section 2.3.5.1)**META_CREATEPALETTE Record** (section 2.3.4.3)**META_RESIZEPALETTE Record** (section 2.3.5.9)**META_SETPALENTRIES Record** (section 2.3.5.19) | **META_REALIZEPALETTE Record** (section 2.3.5.8) | This object is not used until it is specified in a **META_SELECTPALETTE Record** (section 2.3.4.11).The default is a stock object. |
| **Pen Object** (section 2.2.1.4) | **META_CREATEPENINDIRECT Record** (section 2.3.4.5) | **Drawing Record Types** (section 2.3.3) that perform line drawing. | This object is not used until it is specified in a **META_SELECTOBJECT Record** (section 2.3.4.10).The default is a stock object. |
| **Region Obj****ect** (section 2.2.1.5) | **META_CREATEREGION Record** (section 2.3.4.6)**META_EXCLUDECLIPRECT Record** (section 2.3.5.2)**META_INTERSECTCLIPRECT Record** (section 2.3.5.3)**META_OFFSETCLIPRGN Record** (section 2.3.5.5) | **Bitmap Record Types** (section 2.3.1)**Drawing Record Types** (section 2.3.3) that allow clipping. | This object is not used until it is specified in a **META_SELECTCLIPREGION Record** (section 2.3.4.9).The default is the entire drawing surface. |

The following table lists the structure objects that are defined in the playback device context.

| Structure object | Description | Data type | Modified by record(s) |
| --- | --- | --- | --- |
| Background text color | The color used as background for text. | **ColorRef Object** (section 2.2.2.8) | **META_SETBKCOLOR Record** (section 2.3.5.14) |
| Drawing position | The (x,y) coordinates of the current drawing position in the output window | **PointS Object** (section 2.2.2.16) | **META_MOVETO Record** (section 2.3.5.4) |
| Foreground text color | The color used for text. | **ColorRef Object** (section 2.2.2.8) | **META_SETTEXTCOLOR Record** (section 2.3.5.26) |
| Output surface | An array of pixels in a device-independent format that correspond to the logical units of the output surface. | **DeviceIndependentBitmap Object** (section 2.2.2.9) | **Bitmap Record Types** (section 2.3.1) |
| Viewport extent | The horizontal and veritical dimensions of the visible part of the output window | **PointS Object** (section 2.2.2.16) | **META_SCALEVIEWPORTEXT Record** (section 2.3.5.12)**META_SETVIEWPORTEXT Record** (section 2.3.5.28) |
| Viewport origin | The (x,y) coordinates of the left, top corner of the visible part of the output window. | **PointS Object** (section 2.2.2.16) | **META_OFFSETVIEWPORTORG ****Record** (section 2.3.5.6)**META_SETVIEWPORTORG Record** (section 2.3.5.29) |
| Window extent | The horizontal and vertical dimensions of the output window on the output surface. | **PointS Object** (section 2.2.2.16) | **META_SCALEWINDOWEXT Record** (section 2.3.5.13)**META_SETWINDOWEXT Record** (section 2.3.5.30) |
| Window origin | The (x,y) coordinates of the left, top corner of the output window on the output surface. | **PointS Object** (section 2.2.2.16) | **META_OFFSETWINDOWORG Record** (section 2.3.5.7)**META_SETWINDOWORG Record** (section 2.3.5.31) |

The following table lists the graphics properties that are defined in the playback device context.

| Property | Description | Modified by record(s) |
| --- | --- | --- |
| Background mix mode | The mode for combining pens, text, hatched brushes, and interiors of filled objects with background colors on the output surface. | **META_SETBKMODE Record** (section 2.3.5.15) |
| Break extra space | The total extra space to be added to a line of text for justification. | **META_SETTEXTJUSTIFICATION Record** (section 2.3.5.27) |
| Font matching mode | A Boolean value that specifies whether the **font mapper** attempts to match a font **aspect ratio** to the current device aspect ratio. | **META_SETMAPPERFLAGS Record** (section 2.3.5.18) |
| Foreground mix mode | The mode for combining pens and interiors of filled objects with foreground colors on the output surface. | **META_SETROP2 Record** (section 2.3.5.22) |
| Layout mode | The direction in which text and graphics are drawn. | **META_SETLAYOUT Record** (section 2.3.5.16) |
| Mapping mode | How logical units are mapped to physical units. | **META_SETMAPMODE Record** (section 2.3.5.17) |
| Polygon fill mode | The method used for filling a polygon. | **META_SETPOLYFILLMODE Record** (section 2.3.5.20) |
| Stretchblt mode | How the system combines rows or columns of pixels when shrinking a bitmap. | **META_SETSTRETCHBLTMODE Record** (section 2.3.5.23) |
| Text alignment mode | The relationship between a reference point and a bounding rectangle, for text alignment. | **META_SETTEXTALIGN Record** (section 2.3.5.24) |
| Text extra space | The amount of extra space to add to each character when writing a line of text. | **META_SETTEXTCHAREXTRA Record** (section 2.3.5.25) |

**Note**  This specification does not mandate that implementations adhere to the implementation of the playback device context presented in this section, as long as the implementation of external behavior is compatible with the behavior described in this specification.

### Run-Length Encoding (RLE) Compression

 In general, **run-length encoding (RLE) compression** makes it possible to specify an arbitrary number of identical values without a proportional increase in storage requirements. The compressed format usually defines a run count and a value, and expansion amounts to replicating that value a number of times equal to the run count.

Metafile records can contain **bitmaps** that are compressed with an enhanced RLE compression algorithm. Compression of bitmaps that are defined with 4 and 8 bits per pixel are described in the sections which follow.

#### Bitmaps with 4 Bits per Pixel

When the **Compression** field of a **BitmapInfoHeader Object** (section 2.2.2.3) is **BI_RLE4**, an **RLE compression** algorithm is used to compress a 4-bit **bitmap**. This format specifies encoded and absolute modes, and either mode can occur anywhere in a given bitmap.

Encoded mode involves two bytes. If the first byte of a pair is greater than zero, it specifies the number of consecutive pixels to be drawn using the two color indexes that are contained in the high-order and low-order bits of the second byte.

The first pixel is drawn using the color specified by the high-order 4 bits, the second is drawn using the color in the low-order 4 bits, the third is drawn using the color in the high-order 4 bits, and so on, until all the pixels specified by the first byte have been drawn.

If the first byte of a pair is zero and the second byte is 0x02 or less, the second byte is an escape value that can denote the end of a line, the end of the bitmap, or a relative pixel position, as follows.

| Second byte value | Meaning |
| --- | --- |
| 0x00 | End of line |
| 0x01 | End of bitmap |
| 0x02 | Delta |

When a delta is specified, the 2 bytes following the escape value contain unsigned values indicating the horizontal and vertical offsets of the next pixel relative to the current position.

In absolute mode, the first byte is zero, and the second byte is a value in the range 0x03 through 0xFF. The second byte contains the number of 4-bit color indexes that follow. Subsequent bytes contain color indexes in their high- and low-order 4 bits, one color index for each pixel. In absolute mode, each run is aligned on a word boundary.

The following example shows the hexadecimal contents of a 4-bit compressed bitmap:

 03 04 05 06 00 06 45 56 67 00 04 78 00 02 05 01 

 04 78 00 00 09 1E 00 01 

This bitmap is interpreted as follows:

03 04: Encoded mode, specifying 3 pixels with the values 0x0, 0x4, and 0x0.

05 06: Encoded mode, specifying 5 pixels with the values 0x0, 0x6, 0x0, 0x6, and 0x0.

00 06 45 56 67 00: Absolute mode, specifying 6 pixels with the values 0x4, 0x5, 0x5, 0x6, 0x6, and 0x7, padded to a word boundary.

04 78: Encoded mode, specifying 4 pixels with the values 0x7, 0x8, 0x7, and 0x8.

00 02 05 01: Encoded mode, specifying a new relative position 5 pixels to the right and one line down.

04 78: Encoded mode, specifying 4 pixels with the values 0x7, 0x8, 0x7, and 0x8.

00 00: Encoded mode, specifying the end of a line.

09 1E: Encoded mode, specifying 9 pixels with the values 0x1, 0xE, 0x1, 0xE, 0x1, 0xE, 0x1, 0xE, and 0x1.

00 01: Encoded mode, specifying the end of the bitmap.

Now, suppose the bitmap has a width of 32 pixels and a height of 4 lines, and pixel values that are not specified are 0x00 by default. The resulting expended bitmap would be as follows. 

 04 00 60 60 45 56 67 78 78 00 00 00 00 00 00 00

 00 00 00 00 00 00 00 00 00 00 00 07 87 80 00 00

 1E 1E 1E 1E 10 00 00 00 00 00 00 00 00 00 00 00

 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 

#### Bitmaps with 8 Bits per Pixel

When the **Compression** field of a **BitmapInfo****Header Object** (section 2.2.2.3) is **BI_RLE8**, an **RLE compression** algorithm is used to compress an 8-bit **bitmap**. This format specifies encoded and absolute modes, and either mode can occur anywhere in a given bitmap.

Encoded mode involves two bytes. If the first byte of a pair is greater than zero, it specifies the number of consecutive pixels to be drawn using the color index that is contained in the second byte.

If the first byte of a pair is zero and the second byte is 0x02 or less, the second byte is an escape value that can denote the end of a line, the end of the bitmap, or a relative pixel position, as follows.

| Second byte value | Meaning |
| --- | --- |
| 0x00 | End of line |
| 0x01 | End of bitmap |
| 0x02 | Delta |

When a delta is specified, the 2 bytes following the escape value contain unsigned values indicating the horizontal and vertical offsets of the next pixel relative to the current position.

In absolute mode, the first byte is zero, and the second byte is a value in the range 0x03 through 0xFF. The second byte represents the number of bytes that follow, each of which contains the color index of a single pixel. In absolute mode, each run is aligned on a word boundary.

The following example shows the hexadecimal contents of an 8-bit compressed bitmap.

 03 04 05 06 00 03 45 56 67 00 02 78 00 02 05 01 

 02 78 00 00 09 1E 00 01 

This bitmap is interpreted as follows:

03 04: Encoded mode, specifying 3 pixels with the value 0x04.

05 06: Encoded mode, specifying 5 pixels with the value 0x06.

00 03 45 56 67 00: Absolute mode, specifying 3 pixels with the values 0x45, 0x56, and 0x67, padded to a word boundary.

02 78: Encoded mode, specifying 2 pixels with the value 0x78.

00 02 05 01: Encoded mode, specifying a new relative position 5 pixels to the right and 1 line down.

02 78: Encoded mode, specifying 2 pixels with the value 0x78.

00 00: Encoded mode, specifying the end of a line.

09 1E: Encoded mode, specifying 9 pixels with the value 1E.

00 01: Encoded mode, specifying the end of the bitmap.

Now, suppose the bitmap has a width of 32 pixels and a height of 4 lines, and pixel values that are not specified are 0x00 by default. The resulting expended bitmap would be as follows. 

 04 04 04 06 06 06 06 06 45 56 67 78 78 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00

 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 78 78 00 00 00 00 00 00 00 00 00 00 00 00

 1E 1E 1E 1E 1E 1E 1E 1E 1E 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00

 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 

## WMF Metafile Example

This section provides an example of a **metafile** which, when processed, renders the following image.

Figure 2: WMF metafile example

The contents of this metafile example are shown in the following in hexadecimal bytes. The far-left column is the byte count; the far-right characters are the interpretation of the bytes in the Latin-1 **ANSI Character Set**, as specified in [ISO/IEC-8859-1]. The sections that follow describe the packets that convey this series of bytes.

00000000: 01 00 09 00 00 03 36 00 00 00 02 00 0C 00 00 00 …...6.........

00000010: 00 00 08 00 00 00 FA 02 04 00 00 00 00 00 00 00 ......ú.........

00000020: FF 00 04 00 00 00 2D 01 00 00 07 00 00 00 FC 02 ÿ.....-.......ü.

00000030: 02 00 00 FF 00 FF 04 00 04 00 00 00 2C 01 01 00 ...ÿ.ÿ......,...

00000040: 07 00 00 00 1B 04 46 00 96 00 00 00 00 00 0C 00 ......F.–.......

00000050: 00 00 21 05 0C 00 48 65 6C 6C 6F 20 50 65 6F 70 ..!...Hello Peop

00000060: 6C 65 0A 00 0A 00 03 00 00 00 00 00             le..........

**Note**  When a **WMF** metafile is processed, the order in which graphics are rendered corresponds to the order of records in the metafile. This can create challenges for devices that have layers. For example, **Printer Command Language (PCL)** defines a graphics layer and a text layer. The text layer in **PCL** is always drawn on top of the graphics layer. Thus, when converting from metafile format to PCL, the converter, to generate the correct output, either detects text/graphic overlaps and sends the text down as graphics, or always sends the text as graphics.

The sections that follow provide definitions of the WMF header and records that correspond to this metafile. The **WMF Object Table** (section 3.1.4.1) refers to an indexed table of **WMF Objects** (section 2.2) that are defined in the metafile.

### META_HEADER Example

This section provides an example of a **META_HEADER Record** (section 2.3.2.2), which is always the first record in the **metafile**.

00000000: 01 00 09 00 00 03 36 00 00 00 02 00 0C 00 00 00

00000010: 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x0001) | HeaderSize (0x0009) |
| Version (0x0300) | Size (0x00000036) |
| ... | NumberOfObjects (0x0002) |
| MaxRecord (0x0000000C) |
| NumberOfMembers (0x0000) |

**Type (2 bytes):** 0x0001 specifies the type of metafile from the **MetafileType Enumeration** (section 2.1.1.18) to be a metafile stored in memory.

**HeaderSize (2 bytes):** 0x0009 specifies the number of **WORD **structures, defined in [MS-DTYP] section 2.2.61, in this record, which is equivalent to 18 (0x0012) bytes.

**Version (2 bytes):** 0x0300 specifies the metafile version from the **MetafileVersion Enumeration** (section 2.1.1.19) to be a **WMF** metafile that supports **DIBs**.

**Size (4 bytes):** 0x00000036 specifies the number of **WORDs** in the entire metafile, which is equivalent to 108 (0x0000006C) bytes.

**NumberOfObjec****ts (2 bytes):** 0x0002 specifies the number of graphics objects that are defined in the metafile.

**MaxRecord (4 bytes):** 0x0000000C specifies the size in **WORDs** of the largest record in the metafile, which is equivalent to 24 (0x00000018) bytes.

**NumberOfMembers**** (2 bytes):** 0x0000 is not used.

**Note  **Based on the value of the **NumberOfObjects** field, a **WMF Object Table** (section 3.1.4.1) can be created that is large enough for 2 objects.

### META_CREATEPENINDIRECT Example

This section provides an example of a **META_CREATEPENDIRECT Record **(section 2.3.4.5).

00000010:       08 00 00 00 FA 02 04 00 00 00 00 00 00 00

00000020: FF 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RecordSize (0x00000008) |
| RecordFunction (0x02FA) | Pen Object |
| ... |
| ... |

**RecordSize (4 bytes):** 0x00000008 specifies the number of **WORD **structures, defined in [MS-DTYP] section 2.2.61, in this record, which is equivalent to 16 (0x00000010) bytes.

**RecordFunction (2 bytes):** 0x02FA specifies a **META_CREATEPENINDIRECT** record from the **RecordT****ype Enumeration** (section 2.1.1.1).

**Pen Object (10 bytes):** A **Pen Object** (section 2.2.1.4) that defines the pen to create.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PenStyle (0x0004) | PointS Object |
| ... | ColorRef Object |
| ... |

**PenStyle (2 bytes):** 0x0004 specifies the PS_DASHDOTDOT style from the **PenStyle Enumeration** (section 2.1.1.23).

**PointS Object (4 bytes):** A **PointS Object** (section 2.2.2.16) that specifies the width of the pen.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| x (0x0000) | y (0x0000) |

**x (2 bytes):** 0x0000 specifies the width of the pen to be the default, which is 1 pixel.

**y (2 bytes):** 0x0000 is not used.

**ColorRef Object (4 bytes):** A **ColorRef Object** (section 2.2.2.8) that specifies a green pen color.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Reserved (0x00) | Blue (0x00) | Green (0xFF) | Red (0x00) |

**Reserved (1 byte):** 0x00 is not used.

**Blue (1 byte):** 0x00 specifies no blue.

**Green (1 byte):** 0xFF specifies full intensity of green.

**Red (1 byte):** 0x00 specifies no red.

**Note  **The **Pen Object** created by processing this record is assigned index 0 in the **WMF Object Table** (section 3.1.4.1).

### META_SELECTOBJECT Example 1

This section provides an example of a **META_SELECTOBJECT Record** (section 2.3.4.10).

00000020:       04 00 00 00 2D 01 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RecordSize (0x00000004) |
| RecordFunction (0x012D) | ObjectIndex (0x0000) |

**RecordSize (4 bytes):** 0x00000004 specifies the number of **WORD **structures, defined in [MS-DTYP] section 2.2.61, in this record, which is equivalent to 8 (0x00000008) bytes.

**RecordFunction (2 bytes):** 0x012D specifies the type of this record from the **RecordType Enumeration **(section 2.1.1.1) to be **META_SELECTOBJECT**.

**ObjectIndex (2 bytes):** 0x0000 specifies the index in the **WMF Object Table** (section 3.1.4.1) of the object being selected, which is the **Pen Object** (section 2.2.1.4) created in the previous record.

### META_CREATEBRUSHINDIRECT Example

This section provides an example of a **META_CREATEBRUSHINDIRECT Record** (section 2.3.4.1).

00000020:                               07 00 00 00 FC 02

00000030: 02 00 00 FF 00 FF 04 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RecordSize (0x00000007) |
| RecordFunction (0x02FC) | LogBrush Object (0x0000) |
| ... |
| ... |

**RecordSize (4 bytes):** 0x00000007 specifies the number of **WORD **structures, defined in [MS-DTYP] section 2.2.61, in this record, which is equivalent to 14 (0x0000000E) bytes.

**RecordFunction (2 bytes):** 0x02FC specifies a **META_CREATEBRUSHINDIRECT** record from the **RecordType Enumeration** (section 2.1.1.1).

**LogBrush Object (8 bytes):** A **LogBrush Object** (section 2.2.2.10) that defines the brush to create.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BrushStyle (0x0002) | ColorRef Object |
| ... | BrushHatch (0x0004) |

**BrushStyle (2 bytes):** 0x0002 specifies the BS_HATCHED style from the **BrushStyle Enumeration** (section 2.1.1.4).

**ColorRef Object (4 bytes):** A **ColorRef Object** (section 2.2.2.8) that specifies a magenta brush color.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Reserved (0x00) | Blue (0xFF) | Green (0x00) | Red (0xFF) |

**Reserved (1 byte):** 0x00 is not used.

**Blue (1 byte):** 0xFF specifies full intensity blue.

**Green (1 byte):** 0x00 specifies no green.

**Red (1 byte):** 0xFF specifies full intensity red.

**BrushHatch (2 bytes):** 0x0004 specifies the hatch style from the **HatchStyle Enumeration** (section 2.1.1.12), a horizontal and vertical cross-hatch.

**Note  **The **Brush Object** created by processing this record is assigned index 1 in the **WMF Object Table** (section 3.1.4.1).

### META_SELECTOBJECT Example 2

This section provides an example of a **META_SELECTOBJECT Record** (section 2.3.4.10).

00000030:                         04 00 00 00 2D 01 01 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RecordSize (0x00000004) |
| RecordFunction (0x012D) | ObjectIndex (0x0001) |

**RecordSize (4 bytes):** 0x00000004 specifies the number of **WORD **structures, defined in [MS-DTYP] section 2.2.61, in this record, which is equivalent to 8 (0x00000008) bytes.

**RecordFunction (2 bytes):** 0x012D specifies the type of this record from the **RecordType Enumeration** (section 2.1.1.1) to be **META_SELECTOBJECT**.

**ObjectIndex (2 bytes):** 0x0001 specifies the index in the **WMF Object Table** (section 3.1.4.1) of the object being selected, which is the **Brush Object** (section 2.2.1.1) created in the previous record.

### META_RECTANGLE Example

This section provides an example of a **META_RECTANGLE Record** (section 2.3.3.17).

00000040: 07 00 00 00 1B 04 46 00 96 00 00 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RecordSize (0x00000007) |
| RecordFunction (0x041B) | BottomRect (0x0046) |
| RightRect (0x0096) | TopRect (0x0000) |
| LeftRect (0x0000) |

**RecordSize (4 bytes):** 0x0000007 specifies the number of **WORD **structures, defined in [MS-DTYP] section 2.2.61, in this record, which is equivalent to 14 (0x0000000E) bytes.

**RecordFunction (2 bytes):** 0x041B defines the type of this record from the **RecordType Enumeration** (section 2.1.1.1) to be **META_RECTANGLE**.

**BottomRect (2 bytes):** 0x0046 defines the y-coordinate, in logical units, of the lower-right corner of the rectangle.

**RightRec****t (2 bytes):** 0x0096 defines the x-coordinate, in logical units, of the lower-right corner of the rectangle.

**TopRect (2 bytes):** 0x0000 defines the y-coordinate, in logical units, of the upper-left corner of the rectangle.

**LeftRect (2 bytes):** 0x0000 defines the x-coordinate, in logical units, of the upper-left corner of the rectangle.

### META_TEXTOUT Example

This section provides an example of a **META_TEXTOUT Record** (section 2.3.3.20).

0000004E:                                           0C 00

00000050: 00 00 21 05 0C 00 48 65 6C 6C 6F 20 50 65 6F 70

00000060: 6C 65 0A 00 0A 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RecordSize (0x0000000C) |
| RecordFunction (0x0521) | StringLength (0x000C) |
| String "Hello People" (12 bytes) |
| ... |
| ... |
| YStart (0x000A) | XStart (0x000A) |

**RecordSize (4 bytes):** 0x0000000C specifies the number of **WORD **structures, defined in [MS-DTYP] section 2.2.61, in this record, which is equivalent to 24 (0x00000018) bytes.

**RecordFunction (2 bytes):** 0x0521 specifies the type of this record from the **RecordType Enum****eration** (section 2.1.1.1) to be **META_TEXTOUT**.

**StringLength (2 bytes):** 0x000C specifies the length of the string in bytes.

**String (12 bytes):** "Hello People" specifies the text to be drawn.

**YStart (****2 bytes):** 0x000A specifies the vertical (y-axis) coordinate, in logical units, of the point where drawing is to start.

**XStart (2 bytes):** 0x000A specifies the horizontal (x-axis) coordinate, in logical units, of the point where drawing is to start.

### META_EOF Example

This section provides an example of a **META_EOF Record** (section 2.3.2.1), which is always the last record in the **metafile**.

00000060:                   03 00 00 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RecordSize (0x00000003) |
| RecordFunction (0x0000 |

**RecordSize (4 bytes):** 0x00000003 specifies the number of **WORD **structures, defined in [MS-DTYP] section 2.2.61, in this record, which is equivalent to 6 (0x00000006) bytes.

**RecordFunction (**2 bytes): 0x0000 specifies the type of this record from the **RecordType Enumeration** (section 2.1.1.1) to be **META_EOF**.
