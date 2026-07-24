---
source: [MS-EMF]-240423.docx
chapter_number: 3
chapter_title: "Structure Examples"
word_count: 35378
---

# Structure Examples

## EMF Metafile Playback

This section describes the data and processing required for rendering the image stored in an **EMF** **metafile**. This process is referred to as “playback” throughout this specification. During metafile playback, the graphics state is maintained in the **playback device context** (section 3.1).

### Abstract Data Model

This section describes a conceptual model of possible data organization that an implementation maintains during the processing of this file format. The description of the organization is provided to facilitate the explanation of that processing. This document does not mandate that implementations adhere to this model, provided their external behavior is consistent with that specified in this document.

The following abstract data model elements are used to maintain the current state of the playback of an **EMF** **metafile**.

**EMF object tab****le (variable): **A table of object metadata that is used to keep track of objects created and used during metafile playback. The **EMF object table** structure is described in section 3.1.1.1.

**Graphics Environment (variable): **The set of drawing parameters and metadata that specify the rendering of the image in the metafile. The **Graphics Environment** is described in section 3.1.1.2.

No part of the abstract data model is assumed to persist across system restarts; however, with this data it would be possible to recover the playback device context and resume metafile playback.

#### EMF Object Table

The **EMF object table** is an element of the state maintained during **EMF** **metafile** playback. It contains data used for managing graphics objects as they are created, activated, used, deactivated, and deleted by the processing of EMF records. 

A possible implementation is described by the following elements.

| Element name | Type | Set by |
| --- | --- | --- |
| **EMFObjectArray** | **EMFObject[]** | Object creation record (section 2.3.7) |
| **EMFObject** | **EMFObject** | Object creation record |

**EMFObjectArray (variable):** An array of **EMFObject **elements. The maximum number of objects is specified in the **Handles** field of the Header object (section 2.2.9) in an EMF_HEADER record (section 2.3.4.2). The table should be large enough for (**Handles** + 1) because element zero in the array is reserved.

**EMFObject (variable): **A graphics object and its associated index.

When a graphics object is created by an object creation record, the record specifies a numerical index. The object can be referenced by its index during metafile processing until the object is deleted. Object indexes start at 1; zero is reserved for references to the metafile itself.

An object manipulation record (section 2.3.8) can use the index of a graphics object to select it into the **playback device context**. This has the effect of activating the object so that it can be used in graphics operations specified by subsequent metafile records. Until the object is activated, it is not used. Later, if a different object of the same type is activated, the former object is deactivated but not deleted. An object is not deleted until an object manipulation record is processed that deletes it.

Before a graphics object is instantiated and activated, a default **stock object** (section 2.1.31) for that type is used in graphics operations.

| Element name | Type | Set by |
| --- | --- | --- |
| **GraphicsObjectIndex** | UINT32 | Object creation record |
| **GraphicsObject** | See element description. | Object creation record |

**GraphicsObjectIndex (4 bytes): **An unsigned integer that specifies the index associated with the **GraphicsObject**, which is used to refer to the object after it is created.

**GraphicsObject (variable): **One of the following structures.

DeviceIndependentBitmap ([MS-WMF] section 2.2.2.9)

LogBrushEx (section 2.2.12)

LogColorSpace ([MS-WMF] section 2.2.2.11)

LogColorSpaceW ([MS-WMF] section 2.2.2.12)

LogFont (section 2.2.13)

LogFontExDv (section 2.2.15)

LogPalette (section 2.2.17)

LogPenEx (section 2.2.20)

The following process can be used to manage graphics objects with the **EMF object table**:

At the start of metafile processing, the **EMFObjectArray **structure is created.

The **EMF object table** needs to be large enough to keep track of objects that are explicitly created as well as stock objects. Each element in the object table contains information that indicates whether an object with that index has been created, a way to access the object, and whether the object is currently active.

When a graphics object is created, the element in the **EMF object table** that corresponds to its index is updated so that it can be accessed later.

When a graphics object is activated, the element in the **EMF object t****able** that corresponds to its index is updated. In addition, the element that was activated before is now deactivated.

When a graphics object is deactivated, the element in the **EMF object table** that corresponds to its index is updated. In addition, the default stock object of that type is now activated.

When a record is encountered that deletes the graphics object, its memory is released, and the EMF object table is updated accordingly. A graphics object can be deleted without first being deactivated. If that happens, the default stock object of that type is now activated.

There are some index values that are reserved:

The index zero is reserved; it refers to the EMF metafile itself.

Indexes that have the most-significant bit set refer to stock objects.

The object state changes of creation, activation, deactivation, and deletion, require management during playback to achieve the expected results in rendering the image stored in the metafile.

#### Graphics Environment

The **Graphics Environment** describes the graphics state maintained during **EMF** **metafile** playback. A possible implementation is described by the following elements.

| Element name | Type | Set by |
| --- | --- | --- |
| **PlaybackStateArray** | **PlaybackState[]** | EMR_SAVEDC (section 2.3.11) |
| **PlaybackState** | UINT8[] | EMF records (section 2.3) |

**PlaybackStateArray:** An array of saved **PlaybackState **elements, any of which can be used by the EMR_RESTOREDC record (section 2.3.11.6) to restore a previous graphics environment.

**PlaybackState:** The **playback device context** at some point in EMF record processing, including region definitions, color profiles, fonts and text properties, and graphics drawing metadata. The elements of the **PlaybackState** are grouped as shown in the following table.

| Element group | Section | Description |
| --- | --- | --- |
| **Regions** | 3.1.1.2.1 | The current clipping regions and related properties |
| **Colors** | 3.1.1.2.2 | The current **color profile** and related properties |
| **Text ** | 3.1.1.2.3 | Properties related to fonts and rendering text |
| **Drawing ** | 3.1.1.2.4 | The graphics properties that determine how drawing commands render the image |

The sections that follow describe the elements in each group as well as the EMF records that set their values. Unreferenced intrinsic types are defined in [MS-DTYP].

##### Regions

The **Regions** group of elements control the output area and clipping properties in the **playback device context**.

| Element name | Type | Set by |
| --- | --- | --- |
| **Clipping** | RegionData (section 2.2.24) | EMR_EXCLUDECLIPRECT (section 2.3.2.1)EMR_EXTSELECTCLIPRGN (section 2.3.2.2)EMR_INTERSECTCLIPRECT (section 2.3.2.3)EMR_OFFSETCIPRGN (section 2.3.2.4) |
| **MetaClipping** | RegionData | EMR_SETMETARGN (section 2.3.2) |
| **Viewport** | UINT8[16] | EMR_SCALEVIEWPORTEXTEX (section 2.3.11.7)EMR_SETVIEWPORTEXTEX (section 2.3.11.28)EMR_SETVIEWPORTORGEX (section 2.3.11.29) |
| **Window** | UINT8[16] | EMR_SCALEWINDOWEXTEX (section 2.3.11.8)EMR_SETWINDOWEXTEX (section 2.3.11.30)EMR_SETWINDOWORGEX (section 2.3.11.31) |

**Clipping:** The current clipping **region**, which with **MetaClipping** defines the bounds of the drawing area. The default value for the **Clipping** element is implementation-specific.<92>

**MetaClipping:** The current metaregion, which with the **Clipping** region defines the bounds of the drawing area.

**Viewport:** A rectangular drawing area using coordinates in the **device space**.

| Element name | Type | Set by |
| --- | --- | --- |
| **Extent** | SizeL ([MS-WMF] section 2.2.2.22) | EMR_SCALEVIEWPORTEXTEXEMR_SETVIEWPORTEXTEX |
| **Origin** | PointL ([MS-WMF] section 2.2.2.15) | EMR_SETVIEWPORTORGEX |

**Extent: **Horizontal and vertical sizes of the drawing area in device units.

**Origin: **Point value of the origin of the drawing area in device units.

**W****indow:** A rectangular drawing area using the coordinates of the **page space**.

| Element name | Type | Set by |
| --- | --- | --- |
| **Extent** | SizeL | EMR_SCALEWINDOWEXTEXEMR_SETWINDOWEXTEX |
| **Origin** | PointL | EMR_SETWINDOWORGEX |

**Extent: **Horizontal and vertical sizes of the drawing area in logical units.

**Origin: **Point value of the origin of the drawing area in logical units.

##### Colors

The **Colors **group of elements define the current state of color management in the **playback device context**.

| Element name | Type | Set by |
| --- | --- | --- |
| **ColorAdjustment** | ColorAdjustment (section 2.2.2) | EMR_SETCOLORADJUSTMENT (section 2.3.11.13) |
| **ColorProfile** | UINT8[] | EMR_COLORMATCHTOTARGETW (section 2.3.11.1)EMR_SETICMPROFILEA (section 2.3.11.15)EMR_SETICMPROFILEW (section 2.3.11.16) |
| **ColorProfileEmbedded** | BOOL | EMR_COLORMATCHTOTARGETW |
| **ColorProofing** | UINT32 | EMR_COLORMATCHTOTARGETW |
| **ColorTransform** | Implementation-dependent | EMR_COLORMATCHTOTARGETW |
| **ICMMode** | UINT32 | EMR_SETICMMODE (section 2.3.11.14) |
| **PixelFormat** | PixelFormatDescriptor (section 2.2.22) | EMR_HEADER (section 2.3.4.2)EMR_PIXELFORMAT (section 2.3.11.5) |

##### Text

The **Text **group of elements define the current font and text properties in the **playback device context**. 

**Text** elements are used by the following **EMF** text drawing records.

EMR_EXTTEXTOUTA (section 2.3.5.7)

EMR_EXTTEXTOUTW (section 2.3.5.8)

EMR_POLYTEXTOUTA (section 2.3.5.32)

EMR_POLYTEXTOUTW (section 2.3.5.33)

EMR_SMALLTEXTOUT (section 2.3.5.37)

| Element name | Type | Set by |
| --- | --- | --- |
| **FontMapperFlags** | UINT32 | EMR_SETMAPPERFLAGS (section 2.3.11.20) |
| **ForceUFIMapping** | UniversalFontId (section 2.2.27) | EMR_FORCEUFIMAPPING (section 2.3.11.2) |
| **LinkedUFIs** | UniversalFontId[] | EMR_SETLINKEDUFIS (section 2.3.11.18) |
| **TextAlignment** | UINT32 | EMR_SETTEXTALIGN (section 2.3.11.25) |
| **TextJustification** | UINT32 [2] | EMR_SETTEXTJUSTIFICATION (section 2.3.11.27) |

##### Drawing

The **Drawing** group of elements define various graphics flags and other metadata values that affect how the image in the **EMF** **metafile** is rendered. 

| Element name | Type | Set by |
| --- | --- | --- |
| **ArcDirection** | UINT32 | EMR_SETARCDIRECTION (section 2.3.11.9) |
| **BackgroundColor** | ColorRef ([MS-WMF] section 2.2.2.8) | EMR_SETBKCOLOR (section 2.3.11.10) |
| **BackgroundMode** | UINT32 | EMR_SETBKMODE (section 2.3.11.11) |
| **BrushOrigin** | PointL | EMR_SETBRUSHORGEX (section 2.3.11.12) |
| **CurrentPosition** | PointL ([MS-WMF] section 2.2.2.15) | EMR_MOVETOEX (section 2.3.11.4) |
| **LayoutMode** | UINT32 | EMR_SETLAYOUT (section 2.3.11.17) |
| **LineCap** | UINT32 |  |
| **LineJoin** | UINT32 |  |
| **MappingMode** | UINT32 | EMR_SETMAPMODE (section 2.3.11.19) |
| **MiterLimit** | UINT32 | EMR_SETMITERLIMIT (section 2.3.11.21) |
| **Path** | PointL[] | Path bracket records (section 2.3.10) |
| **PathBracket** | **Boolean** | Path bracket records |
| **PolyFillMode** | UINT32 | EMR_SETPOLYFILLMODE (section 2.3.11.22) |
| **ROP2** | UINT32 | EMR_SETROP2 (section 2.3.11.23) |
| **StretchBLTMode** | UINT32 | EMR_SETSTRETCHBLTMODE (section 2.3.11.24) |
| **TextColor** | ColorRef | EMR_SETTEXTCOLOR (section 2.3.11.26) |

**ArcDirection:** The drawing direction for arcs and rectangles, from the ArcDirection enumeration (section 2.1.2).

**BackgroundColor:** The color used as background for drawing text, hatched brushes, and pen styles that are not solid lines, depending on the **BackgroundMode** value.

**BackgroundMode:** How to combine the drawing background with the **BackgroundColor** value, from the BackgroundMode enumeration (section 2.1.4).

**BrushOrigin: **The horizontal and vertical origin of the current brush in logical units, which is used as needed to maintain an alignment of patterns on the display surface.

### Byte Ordering

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

Because of the difference in output, **metafile** playback is implemented so that it can read multi-byte values based on the endian method used by the computer that generated the output.

Because metafiles are developed and written on little-endian computers, playback performs this computation on computers that are big-endian.

## EMF Metafile Example

This section describes an example of an **EMF** **metafile**, which when processed renders the following image.

Figure 4: EMF metafile example

The contents of this metafile example are shown in this section in hexadecimal bytes. The far-left column is the byte count; the far-right characters are the interpretation of the bytes in the Latin-1 **ANSI ****Character Set** [ISO/IEC-8859-1]. The sections that follow describe the packets that convey this series of bytes.

00000000:01 00 00 00 D4 00 00 00 00 00 00 00 00 00 00 00 ....Ô...........

00000010:59 00 00 00 59 00 00 00 00 00 00 00 00 00 00 00 Y...Y...........

00000020:42 0C 00 00 41 0C 00 00 20 45 4D 46 00 00 01 00 B...A... EMF....

00000030:FC 37 00 00 16 00 00 00 05 00 00 00 34 00 00 00 ü7..........4...

00000040:6C 00 00 00 00 00 00 00 80 07 00 00 B0 04 00 00 l.......€...°...

00000050:A5 02 00 00 A7 01 00 00 00 00 00 00 00 00 00 00 ¥...§...........

00000060:00 00 00 00 D5 55 0A 00 A5 75 06 00 53 00 61 00 ....ÕU..¥u..S.a.

00000070:6D 00 70 00 6C 00 65 00 20 00 45 00 4D 00 46 00 m.p.l.e. .E.M.F.

00000080:20 00 74 00 68 00 61 00 74 00 20 00 68 00 61 00 .t.h.a.t. .h.a.

00000090:73 00 20 00 61 00 20 00 62 00 72 00 75 00 73 00 s. .a. .b.r.u.s.

000000A0:68 00 20 00 66 00 69 00 6C 00 6C 00 2C 00 20 00 h. .f.i.l.l.,. .

000000B0:62 00 69 00 74 00 6D 00 61 00 70 00 2C 00 20 00 b.i.t.m.a.p.,. .

000000C0:61 00 6E 00 64 00 20 00 74 00 65 00 78 00 74 00 a.n.d. .t.e.x.t.

000000D0:00 00 00 00 27 00 00 00 18 00 00 00 01 00 00 00 ....'...........

000000E0:02 00 00 00 52 47 2A 00 03 00 00 00 25 00 00 00 ....RG*.....%...

000000F0:0C 00 00 00 01 00 00 00 4C 00 00 00 64 00 00 00 ........L...D...

00000100:00 00 00 00 00 00 00 00 59 00 00 00 59 00 00 00 ........Y...Y...

00000110:00 00 00 00 00 00 00 00 5A 00 00 00 5A 00 00 00 ........Z...Z...

00000120:21 00 F0 00 00 00 00 00 00 00 00 00 00 00 80 3F !.ð...........€?

00000130:00 00 00 00 00 00 00 00 00 00 80 3F 00 00 00 00 ..........€?....

00000140:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ................

00000150:00 00 00 00 00 00 00 00 00 00 00 00 25 00 00 00 ............%...

00000160:0C 00 00 00 00 00 00 80 4C 00 00 00 A8 2F 00 00 .......€L...¨/..

00000170:00 00 00 00 2D 00 00 00 59 00 00 00 59 00 00 00 ....-...Y...Y...

00000180:00 00 00 00 2D 00 00 00 5A 00 00 00 2D 00 00 00 ....-...Z...-...

00000190:20 00 CC 00 00 00 00 00 00 00 00 00 00 00 80 3F .Ì...........€?

000001A0:00 00 00 00 00 00 00 00 00 00 80 3F 00 00 00 00 ..........€?....

000001B0:00 00 00 00 FF FF FF 00 00 00 00 00 64 00 00 00 ....ÿÿÿ.....D...

000001C0:28 00 00 00 8C 00 00 00 1C 2F 00 00 28 00 00 00 (...Œ..../..(...

000001D0:59 00 00 00 2D 00 00 00 01 00 18 00 00 00 00 00 Y...-...........

000001E0:1C 2F 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ./..............

000001F0:00 00 00 00 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E ....?_.?_.?_.?_.

00000200:3F 5F 0E 3F 5F 0E 3F 5F 0E 3E 5E 0D 3F 5F 0E 3F ?_.?_.?_.>^.?_.?

00000210:5F 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E _.A^.A^.A^.A^.A^

00000220:0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E .A^.A^.A^.A^.A^.

00000230:41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 40 5D 0D 3D A^.A^.A^.A^.@].=

00000240:59 0C 5A 60 4E AE AE AE BF BF BF C5 C5 C5 C0 C0 Y.Z`N®®®¿¿¿ÅÅÅÀÀ

00000250:C1 B1 B2 B1 A1 A1 A1 A9 AA AA AE AF B0 A2 A2 A2 Á±²±¡¡¡©ªª®¯°¢¢¢

00000260:A6 A6 A4 AF AE AD AC AC AC A6 A6 A6 99 99 99 7D ¦¦¤¯®­¬¬¬¦¦¦™™™}

00000270:7D 7D 66 66 65 5A 5A 59 4F 4F 4F 58 58 58 76 76 }}FFEZZYOOOXXXvv

00000280:76 9E 9E 9E B5 B5 B5 3C 43 2D 32 46 0A 34 4A 0A vžžžµµµ<C-2F.4J.

00000290:34 49 0A 36 4C 0B 3A 52 0B 3F 59 0C 41 5C 0D 42 4I.6L.:R.?Y.A\.B

000002A0:5D 0D 42 5D 0D 44 5D 0D 44 5D 0D 43 5C 0C 43 5C ].B].D].D].C\.C\

000002B0:0C 43 5C 0C 42 5B 0B 43 5C 0C 43 5C 0C 43 5C 0C .C\.B[.C\.C\.C\.

000002C0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 C\.C\.C\.C\.C\.C

000002D0:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C \.C\.C\.C\.C\.C\

000002E0:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C .C\.C\.C\.C\.C\.

000002F0:45 5B 0C 45 5B 0C 45 5C 0A 45 5C 0A 45 5C 0A 00 E[.E[.E\.E\.E\..

00000300:3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F ?_.?_.?_.?_.?_.?

00000310:5F 0E 3F 5F 0E 3E 5E 0D 3F 5F 0E 3F 5F 0E 41 5E _.?_.>^.?_.?_.A^

00000320:0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E .A^.A^.A^.A^.A^.

00000330:41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 A^.A^.A^.A^.A^.A

00000340:5E 0E 41 5E 0E 41 5E 0E 40 5D 0D 39 52 0C 70 73 ^.A^.A^.@].9R.ps.

00000350:6B AD AD AD A8 A8 A8 99 99 98 A6 A6 A6 A6 A7 A7 k­­­¨¨¨™™˜¦¦¦¦§§

00000360:A3 A5 A6 A6 A5 A3 AE A5 9D C9 BB AD A1 9B 95 A2 £¥¦¦¥£®¥□É»­¡›•¢

00000370:9F 9C B3 B1 AF B6 B4 B3 A9 A9 A9 97 93 90 8E 87 Ÿœ³±¯¶´³©©©--"□Ž‡

00000380:81 89 84 7F 81 7E 7A 79 78 76 80 7F 7E 98 98 98 □‰„□~zyxv€~˜˜˜

00000390:BC BC BC 6D 70 65 33 47 0A 37 4D 0B 35 4B 0A 35 ¼¼¼mpE3G.7M.5K.5

000003A0:4B 0B 38 4F 0B 3D 56 0C 41 5B 0D 42 5D 0D 42 5D K.8O.=V.A[.B].B]

000003B0:0D 43 5D 0D 44 5D 0D 43 5C 0C 43 5C 0C 43 5C 0C .C].D].C\.C\.C\.

000003C0:42 5B 0B 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 B[.C\.C\.C\.C\.C

000003D0:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C \.C\.C\.C\.C\.C\

000003E0:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C .C\.C\.C\.C\.C\.

000003F0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 45 5B 0C 45 C\.C\.C\.C\.E[.E

00000400:5B 0C 45 5C 0A 45 5C 0A 45 5C 0A 00 3F 5F 0E 3F [.E\.E\.E\..?_.?

00000410:5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F _.?_.?_.?_.?_.?_

00000420:0E 3E 5E 0D 3F 5F 0E 3F 5F 0E 41 5E 0E 41 5E 0E .>^.?_.?_.A^.A^.

00000430:41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 A^.A^.A^.A^.A^.A

00000440:5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E ^.A^.A^.A^.A^.A^

00000450:0E 41 5E 0E 40 5D 0D 38 51 0E 90 91 8E AC AC AC .A^.@].8Q.□'Ž¬¬¬

00000460:C3 C3 C3 C5 C6 C6 B9 BB BC B3 B0 AD BA AD 9E C8 ÃÃÃÅÆÆ¹»¼³°­º­žÈ

00000470:B4 A0 DB C8 B4 E4 D1 BE C2 B5 A9 82 7E 7A 8C 88 ´ ÛÈ´äÑ¾Âµ©‚~zŒˆ

00000480:84 83 80 7E 98 8F 85 BE AC 9A C9 B6 A3 CC BB A9 „ƒ€~˜□…¾¬šÉ¶£Ì»©

00000490:CD C0 B3 AB A3 9B 80 7E 76 78 76 70 91 8F 8D 84 ÍÀ³«£›€~vxvp'□□„

000004A0:86 80 36 4B 0B 39 50 0B 38 4E 0B 37 4D 0B 38 4F †€6K.9P.8N.7M.8O

000004B0:0B 3C 55 0C 40 5A 0D 42 5D 0D 42 5D 0D 42 5D 0D .<U.@Z.B].B].B].

000004C0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 42 5B 0B 43 C\.C\.C\.C\.B[.C

000004D0:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C \.C\.C\.C\.C\.C\

000004E0:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C .C\.C\.C\.C\.C\.

000004F0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 C\.C\.C\.C\.C\.C

00000500:5C 0C 43 5C 0C 43 5C 0C 45 5B 0A 45 5B 0A 45 5C \.C\.C\.E[.E[.E\

00000510:0A 45 5C 0A 45 5C 0A 00 3F 5F 0E 3F 5F 0E 3F 5F .E\.E\..?_.?_.?_

00000520:0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3E 5E 0D .?_.?_.?_.?_.>^.

00000530:3F 5F 0E 3F 5F 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 ?_.?_.A^.A^.A^.A

00000540:5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E ^.A^.A^.A^.A^.A^

00000550:0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E .A^.A^.A^.A^.A^.

00000560:40 5D 0D 3D 50 1C 94 94 94 A1 A1 A0 C9 CA CA BC @].=P."""¡¡ ÉÊÊ¼

00000570:BB B8 BB AC 9C C4 AD 94 D2 BB A4 E0 CF BD E0 D0 »¸»¬œÄ­"Ò»¤àÏ½àÐ

00000580:BF DA C7 B5 DE CB B8 9A 93 8B 7C 76 70 A2 93 83 ¿ÚÇµÞË¸š"‹|vp¢"ƒ

00000590:C0 AB 95 C6 B2 9D CA B8 A4 D1 C0 AD E0 D2 C4 E8 À«•Æ²□Ê¸¤ÑÀ­àÒÄè

000005A0:DC CF CD C3 B5 8A 85 74 72 72 61 83 82 7E 34 43 ÜÏÍÃµŠ…trrAƒ‚~4C

000005B0:15 3C 54 0C 38 50 0B 38 4E 0B 39 50 0B 3D 55 0C .<T.8P.8N.9P.=U.

000005C0:40 5B 0D 42 5D 0D 42 5D 0D 42 5D 0D 43 5C 0C 43 @[.B].B].B].C\.C

000005D0:5C 0C 43 5C 0C 43 5C 0C 42 5B 0B 43 5C 0C 43 5C \.C\.C\.B[.C\.C\

000005E0:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C .C\.C\.C\.C\.C\.

000005F0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 C\.C\.C\.C\.C\.C

00000600:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C \.C\.C\.C\.C\.C\

00000610:0C 43 5C 0A 45 5C 0A 45 5C 0A 45 5C 0A 45 5C 0A .C\.E\.E\.E\.E\.

00000620:45 5C 0A 00 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E E\..?_.?_.?_.?_.

00000630:3F 5F 0E 3F 5F 0E 3F 5F 0E 3E 5E 0D 3F 5F 0E 3F ?_.?_.?_.>^.?_.?

00000640:5F 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E _.A^.A^.A^.A^.A^

00000650:0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E .A^.A^.A^.A^.A^.

00000660:41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 40 5D 0D 4B A^.A^.A^.A^.@].K

00000670:56 33 B8 B8 B8 B7 B7 B7 A1 A1 A2 BC AC 9B CC B2 V3¸¸¸•••¡¡¢¼¬›Ì²

00000680:97 D6 C3 AE E5 D6 C6 E4 D4 C4 E1 D2 C2 D9 C6 B4 --ÖÃ®åÖÆäÔÄáÒÂÙÆ´

00000690:D7 C3 AD CE BF AF AD 9A 85 BB A5 8D BD A9 93 C3 ×Ã­Î¿¯­š…»¥□½©"Ã

000006A0:AF 9B C8 B5 A2 CE BD AA DC CE C0 E2 D5 C9 E1 D4 ¯›Èµ¢Î½ªÜÎÀâÕÉáÔ

000006B0:C7 D5 C5 B4 B1 A9 95 91 97 7B 4A 57 2D 39 51 0B ÇÕÅ´±©•'--{JW-9Q.

000006C0:38 50 0B 38 50 0B 3A 52 0C 3E 58 0C 41 5C 0D 42 8P.8P.:R.>X.A\.B

000006D0:5D 0D 42 5D 0D 42 5D 0D 41 5C 0C 43 5C 0C 43 5C ].B].B].A\.C\.C\

000006E0:0C 43 5C 0C 42 5B 0B 43 5C 0C 43 5C 0C 43 5C 0C .C\.B[.C\.C\.C\.

000006F0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 C\.C\.C\.C\.C\.C

00000700:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C \.C\.C\.C\.C\.C\

00000710:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5D 0A .C\.C\.C\.C\.C].

00000720:45 5C 0A 45 5C 0A 45 5C 0A 45 5C 0A 45 5C 0A 00 E\.E\.E\.E\.E\..

00000730:3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F ?_.?_.?_.?_.?_.?

00000740:5F 0E 3F 5F 0E 40 5D 0D 3F 5F 0E 3F 5F 0E 41 5E _.?_.@].?_.?_.A^

00000750:0F 41 5E 0F 41 5E 0F 41 5E 0E 41 5E 0E 40 5D 0D .A^.A^.A^.A^.@].

00000760:40 5D 0D 40 5D 0D 41 5E 0E 40 5D 0D 40 5D 0D 40 @].@].A^.@].@].@

00000770:5D 0D 40 5D 0D 41 5E 0E 41 5E 0E 61 6C 44 D0 D0 ].@].A^.A^.AlDÐÐ

00000780:D0 B0 B0 B0 C8 C3 BE DB C8 B3 DC CA B8 EB DD CF Ð°°°ÈÃ¾ÛÈ³ÜÊ¸ëÝÏ

00000790:E8 D9 CA E5 D6 C7 E4 D6 C8 D9 C8 B5 D2 BF AA DD èÙÊåÖÇäÖÈÙÈµÒ¿ªÝ

000007A0:CC BA C7 B3 9E B6 9F 89 BC A7 92 C1 AD 98 C6 B3 ÌºÇ³ž¶Ÿ‰¼§'Á­˜Æ³

000007B0:9F CC BA A8 DB CD BF DD D0 C2 DF D3 C6 E0 D3 C5 ŸÌº¨ÛÍ¿ÝÐÂßÓÆàÓÅ

000007C0:E2 D4 C4 A7 AA 8E 52 62 2B 37 4D 0B 39 51 0B 3B âÔÄ§ªŽRB+7M.9Q.;

000007D0:53 0C 3E 57 0C 40 5A 0D 42 5D 0D 42 5D 0D 42 5D S.>W.@Z.B].B].B]

000007E0:0D 42 5D 0D 44 5D 0D 43 5C 0C 43 5C 0C 45 5B 0D .B].D].C\.C\.E[.

000007F0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 C\.C\.C\.C\.C\.C

00000800:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C \.C\.C\.C\.C\.C\

00000810:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C .C\.C\.C\.C\.C\.

00000820:43 5C 0C 43 5C 0C 43 5C 0C 45 5C 0A 45 5C 0A 45 C\.C\.C\.E\.E\.E

00000830:5C 0A 45 5C 0A 45 5C 0A 45 5B 0C 00 3F 5F 0E 3F \.E\.E\.E[..?_.?

00000840:5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F _.?_.?_.?_.?_.?_

00000850:0E 40 5D 0D 3F 5F 0E 3F 5F 0E 41 5E 0E 41 5E 0F .@].?_.?_.A^.A^.

00000860:41 5E 0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 A^.@].@].@].@].@

00000870:5D 0D 41 5E 0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D ].A^.@].@].@].@]

00000880:0D 41 5E 0E 3F 5B 0D 6A 79 47 D1 D2 CE C5 C2 BF .A^.?[.jyGÑÒÎÅÂ¿

00000890:EF E6 DD E7 D8 CA EE E0 D3 ED DF D2 EA DC CE E9 ïæÝçØÊîàÓíßÒêÜÎé

000008A0:DB CD E1 D1 C1 D6 C3 B0 D7 C4 B1 DA C9 B8 D5 C3 ÛÍáÑÁÖÃ°×Ä±ÚÉ¸ÕÃ

000008B0:B1 B8 A3 8C BC A7 91 C0 AC 97 C5 B1 9D CB B9 A5 ±¸£Œ¼§'À¬--Å±□Ë¹¥

000008C0:D6 C8 B8 CE BF AE D9 CB BD E1 D4 C7 E3 D4 C6 BC ÖÈ¸Î¿®ÙË½áÔÇãÔÆ¼

000008D0:B9 A2 53 63 2C 37 4C 0B 3C 55 0C 3E 58 0C 40 5B ¹¢SC,7L.<U.>X.@[

000008E0:0D 41 5C 0D 42 5D 0D 42 5D 0D 42 5D 0D 42 5D 0D .A\.B].B].B].B].

000008F0:43 5C 0C 43 5C 0C 43 5C 0C 45 5B 0C 43 5C 0C 43 C\.C\.C\.E[.C\.C

00000900:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C \.C\.C\.C\.C\.C\

00000910:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C .C\.C\.C\.C\.C\.

00000920:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 C\.C\.C\.C\.C\.C

00000930:5C 0C 43 5C 0C 45 5C 0A 45 5C 0A 45 5C 0A 45 5C \.C\.E\.E\.E\.E\

00000940:0A 45 5C 0A 45 5B 0C 00 3F 5F 0E 3F 5F 0E 3F 5F .E\.E[..?_.?_.?_

00000950:0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 40 5D 0D .?_.?_.?_.?_.@].

00000960:3F 5F 0E 3F 5F 0E 41 5E 0E 41 5E 0E 40 5D 0D 40 ?_.?_.A^.A^.@].@

00000970:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 41 5E ].@].@].@].@].A^

00000980:0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 41 5E 0E .@].@].@].@].A^.

00000990:40 59 0F 75 84 54 A6 B1 8E DC D9 CE F5 EE E8 E7 @Y.u„T¦±ŽÜÙÎõîèç

000009A0:DA CE E5 D7 C8 EB DD D0 EC DF D2 E4 D5 C4 D8 C8 ÚÎå×ÈëÝÐìßÒäÕÄØÈ

000009B0:B5 D9 CA B8 D9 CB BA D9 C8 B6 D9 C8 B6 C4 B0 9C µÙÊ¸ÙËºÙÈ¶ÙÈ¶Ä°œ

000009C0:BA A5 90 BF AA 95 C3 AF 9B C9 B6 A3 C9 B9 A7 C7 º¥□¿ª•Ã¯›É¶£É¹§Ç

000009D0:B7 A6 D1 C2 B3 DC CF C0 E0 D2 C3 CE C4 B3 5B 69 •¦ÑÂ³ÜÏÀàÒÃÎÄ³[i

000009E0:33 3C 52 0D 40 5A 0D 41 5C 0D 42 5D 0D 42 5D 0D 3<R.@Z.A\.B].B].

000009F0:42 5D 0D 42 5D 0D 41 5C 0C 42 5D 0D 43 5C 0C 43 B].B].A\.B].C\.C

00000A00:5C 0C 43 5C 0C 45 5B 0C 43 5C 0C 43 5C 0C 43 5C \.C\.E[.C\.C\.C\

00000A10:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C .C\.C\.C\.C\.C\.

00000A20:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 C\.C\.C\.C\.C\.C

00000A30:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C \.C\.C\.C\.C\.C\

00000A40:0C 45 5C 0A 45 5C 0A 45 5C 0A 45 5C 0A 45 5C 0A .E\.E\.E\.E\.E\.

00000A50:45 5B 0C 00 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E E[..?_.?_.?_.?_.

00000A60:3F 5F 0E 3F 5F 0E 3F 5F 0E 40 5D 0D 3F 5F 0E 3F ?_.?_.?_.@].?_.?

00000A70:5F 0E 41 5E 0E 41 5E 0E 40 5D 0D 40 5D 0D 40 5D _.A^.A^.@].@].@]

00000A80:0D 40 5D 0D 40 5D 0D 40 5D 0D 41 5E 0E 40 5D 0D .@].@].@].A^.@].

00000A90:40 5D 0D 40 5D 0D 40 5D 0D 41 5E 0E 44 5C 12 8B @].@].@].A^.D\.‹

00000AA0:97 6A 93 A2 76 C8 CA B5 F5 EE E9 E8 DC CF E0 D0 --j"¢vÈÊµõîéèÜÏàÐ

00000AB0:C1 DF D2 C4 E1 BB A1 D4 AC 8E D5 B2 97 D3 A4 84 ÁßÒÄá»¡Ô¬ŽÕ²--Ó¤„

00000AC0:D3 A5 86 D7 C4 B0 D7 C5 B1 CF BB A6 C2 AE 99 C1 Ó¥†×Ä°×Å±Ï»¦Â®™Á

00000AD0:AD 98 C1 AE 99 C5 B0 9B C7 B5 A2 C8 B8 A7 D1 C2 ­˜Á®™Å°›Çµ¢È¸§ÑÂ

00000AE0:B2 E0 D3 C6 E4 D8 CA E2 D5 C6 71 7B 4B 42 58 10 ²àÓÆäØÊâÕÆq{KBX.

00000AF0:42 5D 0D 42 5D 0D 42 5D 0D 42 5D 0D 42 5D 0D 42 B].B].B].B].B].B

00000B00:5D 0D 41 5C 0C 41 5C 0C 43 5C 0C 43 5C 0C 43 5C ].A\.A\.C\.C\.C\

00000B10:0C 45 5B 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C .E[.C\.C\.C\.C\.

00000B20:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 C\.C\.C\.C\.C\.C

00000B30:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C \.C\.C\.C\.C\.C\

00000B40:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 45 5C 0A .C\.C\.C\.C\.E\.

00000B50:45 5C 0A 45 5C 0A 45 5C 0A 45 5C 0A 45 5B 0C 00 E\.E\.E\.E\.E[..

00000B60:3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F ?_.?_.?_.?_.?_.?

00000B70:5F 0E 3F 5F 0E 40 5D 0D 3F 5F 0E 3F 5F 0E 41 5E _.?_.@].?_.?_.A^

00000B80:0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D .@].@].@].@].@].

00000B90:40 5D 0D 40 5D 0D 41 5E 0E 40 5D 0D 40 5D 0D 40 @].@].A^.@].@].@

00000BA0:5D 0D 40 5D 0D 41 5E 0E 4B 60 17 A0 AB 83 92 A2 ].@].A^.K`. «ƒ'¢

00000BB0:73 AC B6 94 F4 ED E7 E2 CF BE DA CA BA D7 C4 B2 s¬¶"ôíçâÏ¾ÚÊº×Ä²

00000BC0:D0 86 58 CA 71 3D C9 69 32 C6 5D 24 C4 54 17 CC Ð†XÊq=Éi2Æ]$ÄT.Ì

00000BD0:86 5D D5 C5 B2 D2 BC A6 C9 B3 9D C2 AD 96 C1 AC †]ÕÅ²Ò¼¦É³□Â­–Á¬

00000BE0:97 C8 B1 9A D9 C8 B6 D3 C4 B4 D1 C3 B3 DE D1 C4 --È±šÙÈ¶ÓÄ´ÑÃ³ÞÑÄ

00000BF0:E0 D3 C5 E3 D5 C6 A3 A4 81 48 5E 13 42 5D 0D 42 àÓÅãÕÆ£¤□H^.B].B

00000C00:5D 0D 42 5D 0D 42 5D 0D 42 5D 0D 42 5D 0D 41 5C ].B].B].B].B].A\

00000C10:0C 41 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 45 5B 0C .A\.C\.C\.C\.E[.

00000C20:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 C\.C\.C\.C\.C\.C

00000C30:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C \.C\.C\.C\.C\.C\

00000C40:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C .C\.C\.C\.C\.C\.

00000C50:43 5C 0C 43 5C 0C 43 5C 0C 45 5C 0A 45 5C 0A 45 C\.C\.C\.E\.E\.E

00000C60:5C 0A 45 5C 0A 45 5C 0A 45 5B 0C 00 3F 5F 0E 3F \.E\.E\.E[..?_.?

00000C70:5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F _.?_.?_.?_.?_.?_

00000C80:0E 40 5D 0D 3E 5E 0D 3E 5E 0D 40 5D 0D 40 5D 0D .@].>^.>^.@].@].

00000C90:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 @].@].@].@].@].@

00000CA0:5D 0D 41 5E 0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D ].A^.@].@].@].@]

00000CB0:0D 41 5E 0E 52 64 1F A4 AF 8A 95 A3 75 B3 AC 84 .A^.RD.¤¯Š•£u³¬„

00000CC0:DC AB 87 D7 A3 7D DB CD BD D2 A1 7F CD 76 42 CB Ü«‡×£}ÛÍ½Ò¡ÍvBË

00000CD0:71 3C C9 69 32 C7 62 2A C5 5B 20 C3 54 19 D8 AD q<Éi2ÇB*Å[ ÃT.Ø­

00000CE0:90 E2 D7 CA D3 BE A9 CA B6 A0 D0 BD AA D1 BD A9 □â×ÊÓ¾©Ê¶ Ð½ªÑ½©

00000CF0:DD CD BD DD D0 C2 D0 C1 B1 DA CD BE DE D1 C3 DB ÝÍ½ÝÐÂÐÁ±ÚÍ¾ÞÑÃÛ

00000D00:CD BC 91 9A 6E 4E 62 18 42 5D 0D 42 5D 0D 42 5D Í¼'šnNB.B].B].B]

00000D10:0D 42 5D 0D 42 5E 0B 41 5C 0C 41 5C 0C 41 5C 0C .B].B^.A\.A\.A\.

00000D20:43 5C 0C 43 5C 0C 43 5C 0C 45 5B 0C 43 5C 0C 43 C\.C\.C\.E[.C\.C

00000D30:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C \.C\.C\.C\.C\.C\

00000D40:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C .C\.C\.C\.C\.C\.

00000D50:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 C\.C\.C\.C\.C\.C

00000D60:5C 0C 43 5C 0C 45 5C 0A 45 5C 0A 45 5C 0A 45 5C \.C\.E\.E\.E\.E\

00000D70:0A 45 5C 0A 45 5B 0C 00 3F 5F 0E 3F 5F 0E 3F 5F .E\.E[..?_.?_.?_

00000D80:0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 40 5D 0D .?_.?_.?_.?_.@].

00000D90:3E 5D 0D 3E 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 >].>].@].@].@].@

00000DA0:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D ].@].@].@].@].@]

00000DB0:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0E .@].@].@].@].@].

00000DC0:58 67 26 A4 B1 8B B8 B1 8A D6 9F 74 D5 98 6B D7 Xg&¤±‹¸±ŠÖŸtÕ˜k×

00000DD0:A4 7F DD CF BF D2 90 66 CD 77 43 CA 6E 38 C8 65 ¤ÝÏ¿Ò□FÍwCÊn8ÈE

00000DE0:2C C6 60 27 C6 5B 21 C3 56 1B CB 71 40 DD C8 B6 ,Æ`'Æ[!ÃV.Ëq@ÝÈ¶

00000DF0:D5 C3 AF E1 D2 C2 DF D0 C1 D9 C8 B7 E1 D3 C4 E4 ÕÃ¯áÒÂßÐÁÙÈ•áÓÄä

00000E00:D8 CA D1 C2 B2 E0 D4 C7 E7 DA CD AD AA 90 6F 7F ØÊÑÂ²àÔÇçÚÍ­ª□o

00000E10:47 52 63 1F 41 5B 0D 41 5C 0C 41 5C 0C 42 5D 0D GRC.A[.A\.A\.B].

00000E20:42 5D 0B 41 5C 0C 41 5C 0C 41 5B 0C 42 5B 0C 43 B].A\.A\.A[.B[.C

00000E30:5B 0C 43 5C 0C 43 5B 0B 43 5C 0C 43 5C 0C 43 5B [.C\.C[.C\.C\.C[

00000E40:0C 43 5B 0C 43 5B 0C 43 5C 0C 43 5C 0C 43 5C 0C .C[.C[.C\.C\.C\.

00000E50:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 C\.C\.C\.C\.C\.C

00000E60:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C \.C\.C\.C\.C\.C\

00000E70:0C 44 5C 0A 44 5C 0A 45 5B 0A 45 5B 0A 45 5B 0A .D\.D\.E[.E[.E[.

00000E80:45 5B 0B 00 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E E[..?_.?_.?_.?_.

00000E90:3F 5F 0E 3F 5F 0E 3F 5F 0E 40 5D 0D 40 5D 0D 40 ?_.?_.?_.@].@].@

00000EA0:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D ].@].@].@].@].@]

00000EB0:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 41 5E 0E .@].@].@].@].A^.

00000EC0:40 5D 0D 40 5D 0D 40 5D 0D 42 5C 0E 60 6E 33 A9 @].@].@].B\.`n3©

00000ED0:B6 91 CD B0 8B D7 A2 78 D6 99 6D D9 A8 86 E2 D7 ¶'Í°‹×¢xÖ™mÙ¨†â×

00000EE0:CA DE BC A2 CC 78 44 D0 85 57 D2 8B 61 CC 74 42 ÊÞ¼¢ÌxDÐ…WÒ‹AÌtB

00000EF0:CC 76 46 CD 7D 4F CC 76 47 CF 9C 7A D8 C9 B7 DF ÌvFÍ}OÌvGÏœzØÉ•ß

00000F00:D0 C0 DF CF BF DD CE BE E4 D7 C9 EB E0 D4 D1 C3 ÐÀßÏ¿ÝÎ¾ä×ÉëàÔÑÃ

00000F10:B3 DC CF C1 F1 E6 DA C8 C0 AE 72 80 4F 56 66 24 ³ÜÏÁñæÚÈÀ®r€OVF$

00000F20:42 5B 0E 41 5C 0C 41 5C 0C 42 5D 0D 43 5C 0C 43 B[.A\.A\.B].C\.C

00000F30:5C 0C 43 5C 0C 43 5B 0D 42 5A 0C 43 5B 0D 43 5C \.C\.C[.BZ.C[.C\

00000F40:0C 42 5B 0B 43 5C 0C 43 5C 0C 43 5B 0D 43 5B 0D .B[.C\.C\.C[.C[.

00000F50:43 5B 0D 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 C[.C\.C\.C\.C\.C

00000F60:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C \.C\.C\.C\.C\.C\

00000F70:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C .C\.C\.C\.C\.C\.

00000F80:43 5C 0C 45 5B 0C 45 5B 0C 45 5B 0C 45 5C 0A 00 C\.E[.E[.E[.E\..

00000F90:3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F ?_.?_.?_.?_.?_.?

00000FA0:5F 0E 3F 5F 0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D _.?_.@].@].@].@]

00000FB0:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D .@].@].@].@].@].

00000FC0:40 5D 0D 40 5D 0D 40 5D 0D 41 5E 0E 40 5D 0D 40 @].@].@].A^.@].@

00000FD0:5D 0D 40 5D 0D 43 5C 10 78 82 4C B9 BF 9C D8 AB ].@].C\.x‚L¹¿œØ«

00000FE0:84 D6 A3 7A D6 A2 7C DE BE A5 E7 DA CD E8 DA CB „Ö£zÖ¢|Þ¾¥çÚÍèÚË

00000FF0:DA AA 89 E7 D9 CC DB AE 91 C7 63 2B C6 5D 24 C4 Úª‰çÙÌÛ®'ÇC+Æ]$Ä

00001000:56 1B C2 51 15 D1 A2 83 E1 D4 C5 E1 D2 C2 E1 D1 V.ÂQ.Ñ¢ƒáÔÅáÒÂáÑ

00001010:C2 D1 C0 AD D1 C2 B1 E2 D6 C9 D3 C5 B5 D4 C6 B7 ÂÑÀ­ÑÂ±âÖÉÓÅµÔÆ•

00001020:E2 D6 C8 EA DE D2 95 9A 76 5B 6B 2A 44 5C 0F 41 âÖÈêÞÒ•šv[k*D\.A

00001030:5C 0C 41 5C 0C 41 5C 0C 43 5C 0C 43 5C 0C 43 5C \.A\.A\.C\.C\.C\

00001040:0C 43 5B 0D 42 5A 0C 43 5B 0D 43 5C 0C 42 5B 0B .C[.BZ.C[.C\.B[.

00001050:43 5C 0C 43 5C 0C 43 5B 0D 43 5B 0D 43 5B 0D 43 C\.C\.C[.C[.C[.C

00001060:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C \.C\.C\.C\.C\.C\

00001070:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C .C\.C\.C\.C\.C\.

00001080:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 45 C\.C\.C\.C\.C\.E

00001090:5B 0C 45 5B 0C 45 5B 0C 45 5C 0A 00 3F 5F 0E 3F [.E[.E[.E\..?_.?

000010A0:5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F _.?_.?_.?_.?_.?_

000010B0:0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D .@].@].@].@].@].

000010C0:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 @].@].@].@].@].@

000010D0:5D 0D 40 5D 0D 41 5E 0E 40 5D 0D 40 5D 0D 40 5D ].@].A^.@].@].@]

000010E0:0D 47 5E 13 8E 97 67 C4 BF 9F CE A9 81 CA B7 99 .G^.Ž--gÄ¿ŸÎ©□Ê•™

000010F0:E4 DA CF DB CC BC E9 DA CC E8 DA CC E9 DB CE E5 äÚÏÛÌ¼éÚÌèÚÌéÛÎå

00001100:CF BE CB 73 40 C6 5F 26 C6 5C 22 C3 52 15 CA 75 Ï¾Ës@Æ_&Æ\"ÃR.Êu

00001110:45 D9 CA B9 E6 D8 CA E3 D5 C6 D1 BF AE C3 AF 9A EÙÊ¹æØÊãÕÆÑ¿®Ã¯š

00001120:CE BE AD D1 C3 B3 CC BD AD D2 C4 B5 D9 CC BD DD Î¾­ÑÃ³Ì½­ÒÄµÙÌ½Ý

00001130:CE BF CE C6 B3 6A 78 3A 47 5C 11 41 5C 0C 41 5C Î¿ÎÆ³jx:G\.A\.A\

00001140:0C 42 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5B 0D .B\.C\.C\.C\.C[.

00001150:42 5A 0C 43 5B 0D 43 5C 0C 42 5B 0B 43 5C 0C 43 BZ.C[.C\.B[.C\.C

00001160:5C 0C 43 5B 0D 43 5B 0D 43 5B 0D 43 5C 0C 43 5C \.C[.C[.C[.C\.C\

00001170:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C .C\.C\.C\.C\.C\.

00001180:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 C\.C\.C\.C\.C\.C

00001190:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 45 5B 0C 45 5B \.C\.C\.C\.E[.E[

000011A0:0C 45 5B 0C 45 5C 0A 00 3F 5F 0E 3F 5F 0E 3F 5F .E[.E\..?_.?_.?_

000011B0:0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 40 5D 0D .?_.?_.?_.?_.@].

000011C0:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 @].@].@].@].@].@

000011D0:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D ].@].@].@].@].@]

000011E0:0D 41 5E 0E 40 5D 0D 40 5D 0D 40 5D 0D 4C 61 17 .A^.@].@].@].LA.

000011F0:9C A5 7A D1 BF 9E D6 A5 7D E2 BD 9F E3 CF BE DB œ¥zÑ¿žÖ¥}â½ŸãÏ¾Û

00001200:CB BB E9 DA CC E8 D9 CB EA DF D3 DC B0 93 C7 63 Ë»éÚÌèÙËêßÓÜ°"ÇC

00001210:29 C5 5C 22 C5 59 1F C5 5B 21 DD BC A4 DE D2 C4 )Å\"ÅY.Å[!Ý¼¤ÞÒÄ

00001220:E6 D8 CA E8 DA CC CD BB A9 C6 B3 9F CE BD AB CA æØÊèÚÌÍ»©Æ³ŸÎ½«Ê

00001230:B8 A5 CF BE AC D5 C4 B2 BD B4 9D AB AC 8B B6 BA ¸¥Ï¾¬ÕÄ²½´□«¬‹¶º

00001240:9A 78 86 4D 4A 5E 14 43 5C 0C 43 5C 0C 43 5C 0C šx†MJ^.C\.C\.C\.

00001250:43 5C 0C 43 5C 0C 43 5C 0C 43 5B 0D 42 5A 0C 43 C\.C\.C\.C[.BZ.C

00001260:5B 0D 43 5C 0C 42 5B 0B 43 5C 0C 43 5C 0C 43 5B [.C\.B[.C\.C\.C[

00001270:0D 42 5A 0C 43 5B 0D 43 5C 0C 43 5C 0C 43 5C 0C .BZ.C[.C\.C\.C\.

00001280:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 C\.C\.C\.C\.C\.C

00001290:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C \.C\.C\.C\.C\.C\

000012A0:0C 43 5C 0C 43 5C 0C 45 5B 0C 45 5B 0C 45 5B 0C .C\.C\.E[.E[.E[.

000012B0:45 5C 0A 00 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E E\..?_.?_.?_.?_.

000012C0:3F 5F 0E 3F 5F 0E 3F 5F 0E 40 5D 0D 40 5D 0D 40 ?_.?_.?_.@].@].@

000012D0:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D ].@].@].@].@].@]

000012E0:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 41 5E 0E .@].@].@].@].A^.

000012F0:40 5D 0D 40 5D 0D 40 5D 0D 53 64 1D A2 AA 82 D7 @].@].@].SD.¢ª‚×

00001300:BC 99 D8 A7 7F DA A8 81 E3 CE BB E1 D2 C3 E8 D9 ¼™Ø§Ú¨□ãÎ»áÒÃèÙ

00001310:CC E8 D9 CB E4 D6 C7 E6 D7 C9 E2 BC A3 D2 84 57 ÌèÙËäÖÇæ×Éâ¼£Ò„W

00001320:C5 56 1A D4 9A 76 E6 DE D2 E0 D0 C1 E3 D5 C6 F0 ÅV.ÔšvæÞÒàÐÁãÕÆð

00001330:E4 D7 E1 D2 C3 CA B7 A4 D1 C1 B0 C9 B7 A3 D0 BD ä×áÒÃÊ•¤ÑÁ°É•£Ð½

00001340:A9 D8 C6 B2 B5 AC 92 7B 89 53 75 89 4D 70 82 46 ©ØÆ²µ¬'{‰Su‰Mp‚F

00001350:53 61 1C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 SA.C\.C\.C\.C\.C

00001360:5C 0C 43 5C 0C 43 5B 0D 42 5A 0C 43 5B 0D 43 5C \.C\.C[.BZ.C[.C\

00001370:0C 42 5B 0B 43 5C 0C 43 5C 0C 43 5B 0D 42 5A 0C .B[.C\.C\.C[.BZ.

00001380:42 5A 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 BZ.C\.C\.C\.C\.C

00001390:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C \.C\.C\.C\.C\.C\

000013A0:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C .C\.C\.C\.C\.C\.

000013B0:43 5C 0C 45 5B 0C 45 5B 0C 45 5B 0C 45 5C 0A 00 C\.E[.E[.E[.E\..

000013C0:3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F ?_.?_.?_.?_.?_.?

000013D0:5F 0E 3F 5F 0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D _.?_.@].@].@].@]

000013E0:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D .@].@].@].@].@].

000013F0:40 5D 0D 40 5D 0D 40 5D 0D 41 5E 0E 40 5D 0D 40 @].@].@].A^.@].@

00001400:5D 0D 41 5D 0E 59 67 24 A9 B2 8C D1 BB 98 D7 A5 ].A].Yg$©²ŒÑ»˜×¥

00001410:7C D4 B0 8D DE D4 C5 DA CA BB DE D1 C5 DB D0 C3 |Ô°□ÞÔÅÚÊ»ÞÑÅÛÐÃ

00001420:DC CE BF E4 D5 C5 EC E2 D7 F0 E5 D9 E4 C4 AE D7 ÜÎ¿äÕÅìâ×ðåÙäÄ®×

00001430:C8 B9 D4 C7 BA D8 C9 BB E0 D2 C4 E9 DD D0 E3 D4 È¹ÔÇºØÉ»àÒÄéÝÐãÔ

00001440:C6 CF BD AB D2 C3 B3 C2 B2 A1 C6 B6 A3 CD BA A7 ÆÏ½«ÒÃ³Â²¡Æ¶£Íº§

00001450:CD BD A7 8B 97 65 7D 8E 55 74 85 49 5A 66 21 44 Í½§‹--E}ŽUt…IZF!D

00001460:5C 0E 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C \.C\.C\.C\.C\.C\

00001470:0C 43 5B 0D 42 5A 0C 43 5B 0D 43 5C 0C 42 5B 0B .C[.BZ.C[.C\.B[.

00001480:43 5C 0C 43 5C 0C 43 5B 0D 42 5A 0C 42 5A 0C 42 C\.C\.C[.BZ.BZ.B

00001490:5B 0B 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C [.C\.C\.C\.C\.C\

000014A0:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C .C\.C\.C\.C\.C\.

000014B0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 45 C\.C\.C\.C\.C\.E

000014C0:5B 0C 45 5B 0C 45 5B 0C 45 5C 0A 00 3F 5F 0E 3F [.E[.E[.E\..?_.?

000014D0:5F 0E 3F 5F 0C 3F 5F 0C 3F 5F 0C 3F 5F 0E 40 5E _.?_.?_.?_.?_.@^

000014E0:0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D .@].@].@].@].@].

000014F0:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 @].@].@].@].@].@

00001500:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 43 5D ].@].@].@].@].C]

00001510:0F 69 71 33 B3 BC 99 CD BA 96 D6 A4 79 A2 9B 72 .iq3³¼™Íº–Ö¤y¢›r

00001520:B3 AE 91 DE D0 C2 D9 C2 AF CE 9D 7C CF 8E 64 CE ³®'ÞÐÂÙÂ¯Î□|ÏŽDÎ

00001530:7D 4C D6 AB 8D DD D4 C9 DB D1 C6 DB CF C2 D8 CA }LÖ«□ÝÔÉÛÑÆÛÏÂØÊ

00001540:BC CF C1 B2 D1 C4 B6 DB CF C3 D6 C8 BB C6 B6 A5 ¼ÏÁ²ÑÄ¶ÛÏÃÖÈ»Æ¶¥

00001550:CF C2 B4 D4 C8 BC A1 9B 81 69 6C 3C 60 63 2E 6C ÏÂ´ÔÈ¼¡›□il<`C.l

00001560:77 41 7A 88 54 74 83 4B 60 6C 27 45 5C 0E 43 5C wAzˆTtƒK`l'E\.C\

00001570:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5B 0D .C\.C\.C\.C\.C[.

00001580:42 5A 0C 43 5B 0D 43 5C 0C 42 5B 0B 43 5C 0C 43 BZ.C[.C\.B[.C\.C

00001590:5C 0C 43 5B 0D 44 5A 0C 44 5A 0C 44 5B 0B 43 5C \.C[.DZ.DZ.D[.C\

000015A0:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C .C\.C\.C\.C\.C\.

000015B0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 C\.C\.C\.C\.C\.C

000015C0:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5B 0C 43 5B \.C\.C\.C\.C[.C[

000015D0:0C 45 5B 0C 43 5C 0A 00 3F 5F 0E 3F 5F 0E 3F 60 .E[.C\..?_.?_.?`

000015E0:0C 3F 60 0C 3F 60 0C 3F 5F 0E 41 5E 0E 40 5D 0D .?`.?`.?_.A^.@].

000015F0:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 @].@].@].@].@].@

00001600:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D ].@].@].@].@].@]

00001610:0D 40 5D 0D 40 5D 0D 40 5D 0D 45 5E 10 7D 82 48 .@].@].@].E^.}‚H

00001620:BE C5 A4 B9 B0 8A BA B2 93 D1 C9 B6 DB AC 89 E6 ¾Å¤¹°Šº²"ÑÉ¶Û¬‰æ

00001630:CC B7 E8 D2 C0 D1 85 55 CC 75 41 CA 6C 36 C6 6E Ì•èÒÀÑ…UÌuAÊl6Æn

00001640:3B B5 A4 8E D2 C6 B8 E7 D8 C9 E5 D6 C7 E0 D1 C2 ;µ¤ŽÒÆ¸çØÉåÖÇàÑÂ

00001650:DA CC BD DB CD C0 D3 C6 B7 BE AF A0 D0 C3 B5 E9 ÚÌ½ÛÍÀÓÆ•¾¯ ÐÃµé

00001660:DE D2 EA E2 D6 C3 BE A9 8B 89 64 61 66 34 65 6D ÞÒêâÖÃ¾©‹‰DAF4Em

00001670:3E 68 76 45 63 6C 2D 47 5D 0F 43 5C 0C 43 5C 0C >hvECl-G].C\.C\.

00001680:43 5C 0C 43 5C 0C 43 5C 0C 43 5B 0D 42 5A 0C 43 C\.C\.C\.C[.BZ.C

00001690:5B 0D 43 5C 0C 42 5B 0B 43 5C 0C 43 5C 0C 43 5B [.C\.B[.C\.C\.C[

000016A0:0D 45 5B 0D 45 5B 0C 45 5B 0C 43 5C 0C 42 5B 0B .E[.E[.E[.C\.B[.

000016B0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 C\.C\.C\.C\.C\.C

000016C0:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C \.C\.C\.C\.C\.C\

000016D0:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 45 5B 0C .C\.C\.C\.C\.E[.

000016E0:43 5D 0A 00 3F 5F 0E 3F 5F 0E 3F 60 0C 3F 60 0C C]..?_.?_.?`.?`.

000016F0:3F 60 0C 3F 5F 0E 41 5E 0E 40 5D 0D 40 5D 0D 40 ?`.?_.A^.@].@].@

00001700:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D ].@].@].@].@].@]

00001710:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D .@].@].@].@].@].

00001720:40 5D 0D 40 5D 0D 47 5E 12 91 93 61 BC C2 A1 C3 @].@].G^.'"A¼Â¡Ã

00001730:C4 AB E8 E0 D4 DF B4 93 D4 96 68 DE B2 93 E0 BB Ä«èàÔß´"Ô–hÞ²"à»

00001740:A0 CF 81 50 CD 7A 48 CB 71 3C C8 63 2A D3 9A 75 Ï□PÍzHËq<ÈC*Óšu

00001750:E1 D5 C7 DB CB BB D8 C7 B7 D7 C6 B5 D8 C7 B6 D8 áÕÇÛË»ØÇ•×ÆµØÇ¶Ø

00001760:C7 B6 D3 C1 AF C5 B2 9E DB CD BE E9 DE D3 EF E5 Ç¶ÓÁ¯Å²žÛÍ¾éÞÓïå

00001770:DB F6 EE E4 FA F0 E7 E3 D8 CA BB B0 9A A1 9D 83 ÛöîäúðçãØÊ»°š¡□ƒ

00001780:71 74 3B 4A 5E 12 43 5C 0C 43 5C 0C 43 5C 0C 43 qt;J^.C\.C\.C\.C

00001790:5C 0C 43 5C 0C 43 5B 0D 42 5A 0C 43 5B 0D 43 5C \.C\.C[.BZ.C[.C\

000017A0:0C 42 5B 0B 43 5B 0C 43 5B 0C 43 5C 0C 45 5B 0C .B[.C[.C[.C\.E[.

000017B0:44 5A 0B 44 5A 0B 42 5B 0B 42 5B 0B 43 5C 0C 43 DZ.DZ.B[.B[.C\.C

000017C0:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C \.C\.C\.C\.C\.C\

000017D0:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C .C\.C\.C\.C\.C\.

000017E0:43 5C 0C 43 5C 0C 43 5C 0C 45 5B 0C 43 5C 0A 00 C\.C\.C\.E[.C\..

000017F0:3F 5F 0E 3F 5F 0E 3F 60 0C 3F 60 0C 3F 60 0C 3F ?_.?_.?`.?`.?`.?

00001800:5F 0E 41 5E 0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D _.A^.@].@].@].@]

00001810:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D .@].@].@].@].@].

00001820:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 @].@].@].@].@].@

00001830:5D 0D 4E 60 17 9B 9C 6F BB C2 9E D7 D5 C2 E0 C0 ].N`.›œo»Âž×ÕÂàÀ

00001840:A6 D7 A0 76 D6 9C 72 D8 A1 7A D4 95 6A D0 82 51 ¦× vÖœrØ¡zÔ•jÐ‚Q

00001850:CD 7A 47 CA 6D 38 D7 A7 88 DB BF AA D9 C9 B8 D3 ÍzGÊm8×§ˆÛ¿ªÙÉ¸Ó

00001860:C3 B2 D0 BF AC D0 BE AC D1 C0 AE CF BD AA C6 B3 Ã²Ð¿¬Ð¾¬ÑÀ®Ï½ªÆ³

00001870:9F D1 BF AD E2 D5 C7 E6 DC D0 EA DF D4 E9 DE D3 ŸÑ¿­âÕÇæÜÐêßÔéÞÓ

00001880:E4 D8 CC DC CE C0 D1 C0 AF CC BD AA 73 79 3E 50 äØÌÜÎÀÑÀ¯Ì½ªsy>P

00001890:5F 17 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C _.C\.C\.C\.C\.C\

000018A0:0C 43 5B 0D 42 5A 0C 43 5B 0D 43 5C 0C 42 5B 0B .C[.BZ.C[.C\.B[.

000018B0:43 5B 0D 43 5B 0D 43 5C 0C 45 5B 0C 44 5A 0B 44 C[.C[.C\.E[.DZ.D

000018C0:5A 0B 42 5B 0B 42 5B 0B 43 5C 0C 43 5C 0C 43 5C Z.B[.B[.C\.C\.C\

000018D0:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C .C\.C\.C\.C\.C\.

000018E0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 C\.C\.C\.C\.C\.C

000018F0:5C 0C 43 5C 0C 45 5B 0C 45 5C 0A 00 3F 5F 0E 3F \.C\.E[.E\..?_.?

00001900:5F 0E 3F 60 0C 3F 60 0C 3F 60 0C 3F 5F 0E 41 5E _.?`.?`.?`.?_.A^

00001910:0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D .@].@].@].@].@].

00001920:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 @].@].@].@].@].@

00001930:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 57 64 ].@].@].@].@].WD

00001940:1E A5 A5 7C B8 BE 9B D4 D1 BF E2 C5 AD D8 A2 78 .¥¥|¸¾›ÔÑ¿âÅ­Ø¢x

00001950:D7 9E 74 D8 A4 7E D2 8C 5E D0 83 53 CC 74 40 D1 ×žtØ¤~ÒŒ^ÐƒSÌt@Ñ

00001960:8D 62 DE D0 C2 DC CE C0 D4 C2 B1 CF BD AB D1 BF □BÞÐÂÜÎÀÔÂ±Ï½«Ñ¿

00001970:AD D4 C3 B2 D4 C3 B1 CF BE AB D1 BF AD DC CC BC ­ÔÃ²ÔÃ±Ï¾«Ñ¿­ÜÌ¼

00001980:DE D0 C3 DF D3 C6 DD D0 C3 DC CF C1 DF D3 C5 DA ÞÐÃßÓÆÝÐÃÜÏÁßÓÅÚ

00001990:CC BF D3 C5 B6 90 8D 58 60 6D 27 56 64 1E 43 5C Ì¿ÓÅ¶□□X`m'VD.C\

000019A0:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5B 0D .C\.C\.C\.C\.C[.

000019B0:42 5A 0C 43 5B 0D 43 5C 0C 42 5B 0B 43 5B 0D 43 BZ.C[.C\.B[.C[.C

000019C0:5B 0D 43 5C 0C 44 5A 0B 44 5A 0B 44 5A 0B 42 5B [.C\.DZ.DZ.DZ.B[

000019D0:0B 42 5B 0B 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C .B[.C\.C\.C\.C\.

000019E0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 C\.C\.C\.C\.C\.C

000019F0:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C \.C\.C\.C\.C\.C\

00001A00:0C 45 5B 0C 45 5C 0A 00 3F 5F 0E 3F 5F 0E 3F 60 .E[.E\..?_.?_.?`

00001A10:0C 3F 60 0C 3F 60 0C 3F 5F 0E 41 5E 0E 40 5D 0D .?`.?`.?_.A^.@].

00001A20:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 @].@].@].@].@].@

00001A30:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D ].@].@].@].@].@]

00001A40:0D 40 5D 0D 40 5D 0D 40 5D 0D 62 6B 26 B0 B1 8C .@].@].@].Bk&°±Œ

00001A50:BB BE A0 E3 DD D0 E8 D7 C8 D8 A2 7A D7 A4 7D D5 »¾ ãÝÐè×ÈØ¢z×¤}Õ

00001A60:9C 74 D1 87 57 CE 7C 4A D0 88 5C D7 C2 AF D4 C5 œtÑ‡WÎ|JÐˆ\×Â¯ÔÅ

00001A70:B5 D5 C4 B2 D9 C9 B8 DD CD BD DC CC BC DA C9 B9 µÕÄ²ÙÉ¸ÝÍ½ÜÌ¼ÚÉ¹

00001A80:D7 C6 B6 D7 C6 B5 DF D0 C0 D7 C7 B6 D7 C8 B9 D5 ×Æ¶×ÆµßÐÀ×Ç¶×È¹Õ

00001A90:C7 B9 D9 CB BD E5 DA CD E4 D9 CC E0 D3 C6 D7 CD Ç¹ÙË½åÚÍäÙÌàÓÆ×Í

00001AA0:BD 7C 84 48 5B 6A 1F 5C 67 21 43 5C 0C 43 5C 0C ½|„H[j.\g!C\.C\.

00001AB0:43 5C 0C 43 5C 0C 43 5C 0C 43 5B 0D 42 5A 0C 43 C\.C\.C\.C[.BZ.C

00001AC0:5B 0D 43 5C 0C 42 5B 0B 43 5B 0D 42 5A 0C 42 5B [.C\.B[.C[.BZ.B[

00001AD0:0B 44 5A 0B 44 5A 0B 44 5A 0B 42 5B 0B 42 5B 0B .DZ.DZ.DZ.B[.B[.

00001AE0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 C\.C\.C\.C\.C\.C

00001AF0:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C \.C\.C\.C\.C\.C\

00001B00:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 45 5B 0C .C\.C\.C\.C\.E[.

00001B10:45 5C 0A 00 3F 5F 0E 3F 5F 0E 3F 60 0C 3F 60 0C E\..?_.?_.?`.?`.

00001B20:3F 60 0C 3F 5F 0E 41 5E 0E 40 5D 0D 40 5D 0D 40 ?`.?_.A^.@].@].@

00001B30:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D ].@].@].@].@].@]

00001B40:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D .@].@].@].@].@].

00001B50:40 5D 0D 41 5D 0D 6D 73 32 B9 BA 9B D6 D1 BF EC @].A].ms2¹º›ÖÑ¿ì

00001B60:E3 DA EE E7 DF E1 C0 A5 D7 AB 88 D7 A3 7E DA A7 ãÚîçßáÀ¥×«ˆ×£~Ú§

00001B70:84 DD B1 94 D9 C4 B1 D4 C5 B4 DB CB BB E9 DB CD „Ý±"ÙÄ±ÔÅ´ÛË»éÛÍ

00001B80:E9 DB CE E3 D5 C6 DE CF BF DC CD BC DF CF C0 E1 éÛÎãÕÆÞÏ¿ÜÍ¼ßÏÀá

00001B90:D1 C2 DF CF C0 DA CA B9 D6 C7 B8 D5 C7 B9 E8 DC ÑÂßÏÀÚÊ¹ÖÇ¸ÕÇ¹èÜ

00001BA0:D1 E8 DC D1 E4 D8 CC E5 D9 CC B2 AD 93 7D 89 53 ÑèÜÑäØÌåÙÌ²­"}‰S.

00001BB0:6A 77 32 60 6A 24 44 5C 0C 43 5C 0C 43 5C 0C 43 jw2`j$D\.C\.C\.C

00001BC0:5C 0C 43 5C 0C 43 5B 0D 42 5A 0C 43 5B 0D 43 5C \.C\.C[.BZ.C[.C\

00001BD0:0C 42 5B 0B 42 5A 0C 42 5A 0C 42 5B 0B 44 5A 0B .B[.BZ.BZ.B[.DZ.

00001BE0:44 5A 0B 44 5A 0B 42 5B 0B 42 5B 0B 43 5C 0C 43 DZ.DZ.B[.B[.C\.C

00001BF0:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C \.C\.C\.C\.C\.C\

00001C00:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C .C\.C\.C\.C\.C\.

00001C10:43 5C 0C 43 5C 0C 43 5C 0C 45 5B 0C 45 5C 0A 00 C\.C\.C\.E[.E\..

00001C20:40 5D 0D 41 5E 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F @].A^.?_.?_.?_.?

00001C30:5F 0E 41 5E 0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D _.A^.@].@].@].@]

00001C40:0D 41 5E 0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D .A^.@].@].@].@].

00001C50:41 5E 0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 41 A^.@].@].@].@].A

00001C60:5E 0F 77 79 3C CC CA B4 EB E2 D9 ED E4 DB EF E7 ^.wy<ÌÊ´ëâÙíäÛïç

00001C70:E0 EF E7 DE DE CC BB DD CD BC E8 DB CD E9 DC CF àïçÞÞÌ»ÝÍ¼èÛÍéÜÏ

00001C80:DC CD BD E5 D6 C7 F1 E4 D8 F0 E3 D6 EA DC CE E5 ÜÍ½åÖÇñäØðãÖêÜÎå

00001C90:D6 C7 E1 D2 C2 DF CF C0 DF CF C0 DD CD BD D9 C8 ÖÇáÒÂßÏÀßÏÀÝÍ½ÙÈ

00001CA0:B8 D7 C6 B5 E0 D3 C6 E6 DB CF EB E0 D5 E1 D5 C8 ¸×ÆµàÓÆæÛÏëàÕáÕÈ

00001CB0:DF D3 C7 E4 D8 CB A7 A3 88 77 82 4F 77 86 4B 6B ßÓÇäØË§£ˆw‚Ow†Kk

00001CC0:71 30 44 5D 0E 41 5C 0C 43 5C 0C 43 5C 0C 43 5C q0D].A\.C\.C\.C\

00001CD0:0C 43 5C 0C 43 5C 0C 43 5B 0D 43 5B 0D 43 5B 0D .C\.C\.C[.C[.C[.

00001CE0:42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 44 5A 0B 44 B[.B[.B[.B[.DZ.D

00001CF0:5A 0B 42 5B 0B 42 5B 0B 44 5A 0B 43 5C 0C 43 5C Z.B[.B[.DZ.C\.C\

00001D00:0C 43 5D 0A 43 5D 0A 43 5D 0A 43 5C 0C 43 5C 0C .C].C].C].C\.C\.

00001D10:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 C\.C\.C\.C\.C\.C

00001D20:5C 0C 43 5C 0C 42 5B 0B 44 5B 09 00 40 5D 0D 41 \.C\.B[.D[..@].A

00001D30:5E 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 41 5E ^.?_.?_.?_.?_.A^

00001D40:0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 41 5E 0E .@].@].@].@].A^.

00001D50:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 @].@].@].@].@].@

00001D60:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 47 5F 13 80 7F ].@].@].@].G_.€

00001D70:46 DE DA C9 EF E6 DD EE E5 DD F0 E8 E0 F1 E8 E0 FÞÚÉïæÝîåÝðèàñèà

00001D80:E2 D2 C3 DE CD BD E3 D3 C3 E3 D4 C5 E2 D3 C5 E6 âÒÃÞÍ½ãÓÃãÔÅâÓÅæ

00001D90:D9 CA E5 D7 C9 E7 DA CB E9 DA CC E5 D6 C8 E2 D3 ÙÊå×ÉçÚËéÚÌåÖÈâÓ

00001DA0:C4 E0 D1 C2 DA CA B9 D3 C2 B1 CF BD AA CC B9 A6 ÄàÑÂÚÊ¹ÓÂ±Ï½ªÌ¹¦

00001DB0:D6 C7 B8 E1 D5 C9 E7 DB CF DF D3 C6 E0 D3 C7 DE ÖÇ¸áÕÉçÛÏßÓÆàÓÇÞ

00001DC0:D1 C5 D4 C9 B9 7F 85 5B 75 83 4A 74 78 3A 4A 5F ÑÅÔÉ¹…[uƒJtx:J_

00001DD0:14 41 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C .A\.C\.C\.C\.C\.

00001DE0:42 5B 0B 42 5B 0C 42 5B 0C 43 5B 0C 42 5B 0B 42 B[.B[.B[.C[.B[.B

00001DF0:5B 0B 42 5B 0B 42 5B 0B 43 5A 0B 43 5A 0B 42 5B [.B[.B[.CZ.CZ.B[

00001E00:0B 42 5B 0B 44 5A 0B 43 5C 0C 43 5C 0C 43 5D 0A .B[.DZ.C\.C\.C].

00001E10:43 5D 0A 43 5D 0A 43 5C 0C 43 5C 0C 43 5C 0C 43 C].C].C\.C\.C\.C

00001E20:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C \.C\.C\.C\.C\.C\

00001E30:0C 42 5B 0B 44 5B 09 00 40 5D 0D 41 5E 0E 3F 5F .B[.D[..@].A^.?_

00001E40:0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 41 5E 0E 40 5D 0D .?_.?_.?_.A^.@].

00001E50:40 5D 0D 40 5D 0D 40 5D 0D 41 5E 0E 40 5D 0D 40 @].@].@].A^.@].@

00001E60:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D ].@].@].@].@].@]

00001E70:0D 40 5D 0D 40 5D 0D 4B 61 15 8E 8B 57 CF CE B6 .@].@].KA.Ž‹WÏÎ¶

00001E80:EA E2 D6 F0 E7 DF F1 E9 E1 F1 E8 E0 E4 D5 C5 E1 êâÖðçßñéáñèàäÕÅá

00001E90:D1 C0 E0 D0 C0 E0 D0 C2 E4 D5 C6 E3 D4 C5 E3 D4 ÑÀàÐÀàÐÂäÕÆãÔÅãÔ

00001EA0:C5 E5 D6 C8 E8 DB CD EB DD D0 EB DD CF E8 DA CC ÅåÖÈèÛÍëÝÐëÝÏèÚÌ

00001EB0:E0 D1 C2 D7 C6 B5 CE BB A9 C9 B5 A2 D3 C4 B5 D3 àÑÂ×ÆµÎ»©Éµ¢ÓÄµÓ

00001EC0:C4 B6 DA CD BF E1 D5 C9 E3 D7 CB DD D1 C4 EA DF Ä¶ÚÍ¿áÕÉã×ËÝÑÄêß

00001ED0:D4 B7 B4 9C 77 85 4D 76 7D 3E 4F 61 17 41 5C 0C Ô•´œw…Mv}>OA.A\.

00001EE0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 42 5B 0B 42 C\.C\.C\.C\.B[.B

00001EF0:5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B [.B[.B[.B[.B[.B[

00001F00:0B 42 5B 0B 42 5B 0B 42 5B 0B 43 5A 0B 43 5A 0B .B[.B[.B[.CZ.CZ.

00001F10:44 5A 0B 43 5C 0C 43 5C 0C 43 5D 0A 43 5D 0A 43 DZ.C\.C\.C].C].C

00001F20:5D 0A 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C ].C\.C\.C\.C\.C\

00001F30:0C 43 5C 0C 43 5C 0C 43 5C 0C 42 5B 0B 43 5A 0B .C\.C\.C\.B[.CZ.

00001F40:44 5B 09 00 40 5D 0D 40 5D 0D 3F 5F 0E 3F 5F 0E D[..@].@].?_.?_.

00001F50:3F 5F 0E 3F 5F 0E 40 5D 0D 40 5D 0D 40 5D 0D 40 ?_.?_.@].@].@].@

00001F60:5D 0D 40 5D 0D 41 5E 0E 40 5D 0D 40 5D 0D 40 5D ].@].A^.@].@].@]

00001F70:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D .@].@].@].@].@].

00001F80:40 5D 0D 50 63 1A A3 9F 71 CA C9 B1 E0 D9 CB F1 @].PC.£ŸqÊÉ±àÙËñ

00001F90:E8 E0 F2 EA E2 F2 E9 E0 E7 D8 C8 E4 D4 C4 E1 D0 èàòêâòéàçØÈäÔÄáÐ

00001FA0:C1 E4 D5 C6 DD CD BD D7 C6 B6 DE CF BF E5 D6 C8 ÁäÕÆÝÍ½×Æ¶ÞÏ¿åÖÈ

00001FB0:EB DE D0 F0 E3 D6 F1 E5 D8 F0 E3 D6 ED DF D3 E9 ëÞÐðãÖñåØðãÖíßÓé

00001FC0:DB CD E8 DA CC E3 D4 C5 E3 D7 CA E4 D8 CC D9 CB ÛÍèÚÌãÔÅã×ÊäØÌÙË

00001FD0:BD D9 CB BD E0 D3 C7 DF D3 C6 E7 DC D0 E1 D8 C8 ½ÙË½àÓÇßÓÆçÜÐáØÈ

00001FE0:80 8D 56 7A 82 45 55 64 1B 41 5C 0C 43 5C 0C 43 €□Vz‚EUD.A\.C\.C

00001FF0:5C 0C 43 5C 0C 42 5B 0B 42 5B 0B 42 5B 0B 42 5B \.C\.B[.B[.B[.B[

00002000:0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B .B[.B[.B[.B[.B[.

00002010:42 5B 0B 42 5B 0B 44 5A 0B 44 5A 0B 44 5A 0B 43 B[.B[.DZ.DZ.DZ.C

00002020:5C 0C 43 5C 0C 43 5D 0A 43 5D 0A 43 5D 0A 43 5C \.C\.C].C].C].C\

00002030:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C .C\.C\.C\.C\.C\.

00002040:43 5C 0C 43 5C 0C 43 5A 0B 44 5A 0B 44 5B 09 00 C\.C\.CZ.DZ.D[..

00002050:40 5D 0D 40 5D 0D 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F @].@].?_.?_.?_.?

00002060:5F 0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D _.@].@].@].@].@]

00002070:0D 41 5E 0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D .A^.@].@].@].@].

00002080:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 58 @].@].@].@].@].X

00002090:67 20 B2 AF 88 D8 D4 C5 F0 E7 DE F1 E9 E1 F3 EC g ²¯ˆØÔÅðçÞñéáóì

000020A0:E4 F3 E9 E1 E9 DA CB E6 D6 C7 E4 D4 C4 E6 D8 C9 äóéáéÚËæÖÇäÔÄæØÉ

000020B0:DF D0 C0 D5 C4 B3 DB CB BA E5 D7 C9 EB DD D0 EF ßÐÀÕÄ³ÛËºå×ÉëÝÐï

000020C0:E2 D5 F1 E4 D8 F0 E4 D7 ED DF D2 EE E1 D4 E6 D8 âÕñäØðä×íßÒîáÔæØ

000020D0:C9 C1 AE 98 CA B9 A8 E8 DC D1 EC E1 D7 E7 DC D0 ÉÁ®˜Ê¹¨èÜÑìá×çÜÐ

000020E0:DD D0 C3 D4 C6 B7 D8 CB BC AE AC 8B 79 87 4D 7B ÝÐÃÔÆ•ØË¼®¬‹y‡M{

000020F0:84 4A 5C 67 20 41 5C 0C 43 5C 0C 43 5C 0C 43 5C „J\g A\.C\.C\.C\

00002100:0C 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B .B[.B[.B[.B[.B[.

00002110:42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 B[.B[.B[.B[.B[.B

00002120:5B 0B 44 5A 0B 44 5A 0B 44 5A 0B 43 5C 0C 43 5C [.DZ.DZ.DZ.C\.C\

00002130:0C 43 5D 0A 43 5D 0A 43 5D 0A 43 5C 0C 43 5C 0C .C].C].C].C\.C\.

00002140:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 42 C\.C\.C\.C\.C\.B

00002150:5B 0B 44 5A 0B 44 5A 0B 44 5B 09 00 40 5D 0D 40 [.DZ.DZ.D[..@].@

00002160:5D 0D 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 40 5D ].?_.?_.?_.?_.@]

00002170:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 41 5E 0E .@].@].@].@].A^.

00002180:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 @].@].@].@].@].@

00002190:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 64 6C 29 C3 BD ].@].@].@].Dl)Ã½

000021A0:A0 F4 EC E3 F2 E9 E0 F3 EA E2 F5 EE E6 F3 EA E1 ôìãòéàóêâõîæóêá

000021B0:EB DC CD E8 D9 CA E5 D5 C6 E4 D4 C5 E3 D3 C3 D9 ëÜÍèÙÊåÕÆäÔÅãÓÃÙ

000021C0:C8 B8 D3 C1 AF DC CC BC EB DD D0 EF E2 D6 F2 E5 È¸ÓÁ¯ÜÌ¼ëÝÐïâÖòå

000021D0:DA F2 E5 D9 F4 E7 DB EA DC CE C7 B3 A0 B7 A2 8B ÚòåÙôçÛêÜÎÇ³ •¢‹

000021E0:D1 C2 B3 EB E0 D6 E6 DA CF EA E0 D5 EF E4 DB E8 ÑÂ³ëàÖæÚÏêàÕïäÛè

000021F0:DC D1 D0 C5 B4 8A 8F 63 7C 8B 51 79 85 4A 64 69 ÜÑÐÅ´Š□C|‹Qy…JDi

00002200:27 41 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 42 5B 0B 'A\.C\.C\.C\.B[.

00002210:42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 B[.B[.B[.B[.B[.B

00002220:5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 44 5A [.B[.B[.B[.B[.DZ

00002230:0B 44 5A 0B 44 5A 0B 43 5C 0C 43 5C 0C 43 5D 0A .DZ.DZ.C\.C\.C].

00002240:43 5D 0A 43 5D 0A 43 5C 0C 43 5C 0C 43 5C 0C 43 C].C].C\.C\.C\.C

00002250:5C 0C 43 5C 0C 43 5C 0C 42 5B 0B 44 5A 0B 44 5A \.C\.C\.B[.DZ.DZ

00002260:0B 44 5A 0B 44 5B 09 00 40 5D 0D 40 5D 0D 3F 5E .DZ.D[..@].@].?^

00002270:0D 3F 5E 0D 3F 5E 0D 3F 5E 0D 40 5D 0D 40 5D 0D .?^.?^.?^.@].@].

00002280:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 @].@].@].@].@].@

00002290:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D ].@].@].@].@].@]

000022A0:0D 3F 5C 0C 40 5C 0D 72 74 35 CC C5 AC F4 EC E4 .?\.@\.rt5ÌÅ¬ôìä

000022B0:F1 E9 E0 F6 EE E6 F5 EE E6 F2 E9 DE ED DE CF EB ñéàöîæõîæòéÞíÞÏë

000022C0:DC CE E3 D3 C3 D8 C7 B4 DB CB BA DF D0 BF D9 C8 ÜÎãÓÃØÇ´ÛËºßÐ¿ÙÈ

000022D0:B7 D9 C8 B7 ED DE D0 F4 E6 D9 F9 ED E0 FD F0 E4 •ÙÈ•íÞÐôæÙùíàýðä

000022E0:FF F3 E7 E0 CF BD CA B6 A1 C7 B3 9D F3 E7 DC F4 ÿóçàÏ½Ê¶¡Ç³□óçÜô

000022F0:EA E0 E7 DD D0 E7 DC D0 E8 DD D2 EF E5 DB F0 E7 êàçÝÐçÜÐèÝÒïåÛðç

00002300:DD A5 A6 81 7C 8A 50 76 83 47 6F 71 31 43 5C 0E Ý¥¦□|ŠPvƒGoq1C\.

00002310:43 5C 0C 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 C\.B[.B[.B[.B[.B

00002320:5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B [.B[.B[.B[.B[.B[

00002330:0B 42 5B 0B 42 5B 0B 42 5B 0B 44 5A 0B 44 5A 0B .B[.B[.B[.DZ.DZ.

00002340:43 5A 0B 42 5B 0B 42 5B 0B 43 5C 0A 43 5C 0A 43 CZ.B[.B[.C\.C\.C

00002350:5C 0A 43 5C 0C 43 5C 0C 43 5C 0B 43 5C 0B 43 5C \.C\.C\.C\.C\.C\

00002360:0C 43 5B 0C 42 5A 0A 43 59 0A 44 5A 0B 44 5A 0B .C[.BZ.CY.DZ.DZ.

00002370:43 5B 09 00 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D C[..@].@].@].@].

00002380:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 @].@].@].@].@].@

00002390:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D ].@].@].@].@].@]

000023A0:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 3F 5C 0C .@].@].@].@].?\.

000023B0:43 5E 0F 80 7E 41 D3 CD BA F2 E9 E0 F4 EB E2 F4 C^.€~AÓÍºòéàôëâô

000023C0:EA E1 F0 E8 DF E5 D9 CD DD CE BE E4 D5 C7 DC CD êáðèßåÙÍÝÎ¾äÕÇÜÍ

000023D0:BF D9 CA BB D9 CA BB DA CC BD D2 C4 B6 CC BF B2 ¿ÙÊ»ÙÊ»ÚÌ½ÒÄ¶Ì¿²

000023E0:CC C1 B5 C8 BD B2 C3 B9 AF C0 B6 AB BA AE A2 AA ÌÁµÈ½²Ã¹¯À¶«º®¢ª

000023F0:9A 8B A6 95 84 BB AD 9E D7 CE C5 D5 CA BF D3 C6 š‹¦•„»­ž×ÎÅÕÊ¿ÓÆ

00002400:B9 DC CF C1 E5 D7 C9 EB DF D2 E6 DC CF 8D 92 67 ¹ÜÏÁå×ÉëßÒæÜÏ□'g

00002410:7A 87 4D 73 82 45 79 79 39 49 5E 11 43 5C 0C 42 z‡Ms‚Eyy9I^.C\.B

00002420:5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B [.B[.B[.B[.B[.B[

00002430:0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B .B[.B[.B[.B[.B[.

00002440:42 5B 0B 42 5B 0B 44 5A 0B 44 5A 0B 42 5B 0B 42 B[.B[.DZ.DZ.B[.B

00002450:5B 0B 42 5B 0B 43 5C 0C 43 5C 0C 43 5C 0C 43 5C [.B[.C\.C\.C\.C\

00002460:0C 43 5C 0C 43 5D 0A 43 5D 0A 43 5C 0C 44 5A 0B .C\.C].C].C\.DZ.

00002470:43 59 0A 43 59 0A 44 5A 0B 44 5A 0B 42 5C 09 00 CY.CY.DZ.DZ.B\..

00002480:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 @].@].@].@].@].@

00002490:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D ].@].@].@].@].@]

000024A0:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D .@].@].@].@].@].

000024B0:40 5D 0D 40 5D 0D 40 5D 0D 3F 5C 0C 45 5F 11 90 @].@].@].?\.E_.□

000024C0:8A 4F EA E1 D5 E8 DF D7 E7 DF D6 E7 E1 DA E5 E0 ŠOêáÕèß×çßÖçáÚåà

000024D0:DB E6 E3 DF EA E8 E5 F0 EE ED F2 F2 F1 F1 F1 F1 Ûæãßêèåðîíòòññññ

000024E0:F0 F0 F0 EB EB EB E3 E4 E4 D7 D7 D8 C2 C3 C4 A8 ðððëëëãää××ØÂÃÄ¨

000024F0:A9 AA 8B 8B 8C 6C 6C 6D 53 54 55 45 45 46 3E 3F ©ª‹‹ŒllmSTUEEF>?

00002500:3F 3B 3B 3B 3C 3B 3A 41 40 3F 4A 48 46 5B 57 54 ?;;;<;:A@?JHF[WT

00002510:78 72 6C 9C 94 8B B4 AB A2 A2 9F 86 95 9C 6F 7A xrlœ"‹´«¢¢Ÿ†•œoz

00002520:8A 4F 7B 7D 3D 4B 5F 13 43 5C 0C 42 5B 0B 42 5B ŠO{}=K_.C\.B[.B[

00002530:0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B .B[.B[.B[.B[.B[.

00002540:42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 B[.B[.B[.B[.B[.B

00002550:5B 0B 44 5A 0B 44 5A 0B 42 5B 0B 42 5B 0B 42 5B [.DZ.DZ.B[.B[.B[

00002560:0B 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C .C\.C\.C\.C\.C\.

00002570:43 5D 0A 43 5D 0A 43 5C 0C 44 5A 0B 43 59 0A 43 C].C].C\.DZ.CY.C

00002580:59 0A 44 5A 0B 44 5A 0B 42 5C 09 00 40 5D 0D 40 Y.DZ.DZ.B\..@].@

00002590:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D ].@].@].@].@].@]

000025A0:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D .@].@].@].@].@].

000025B0:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 @].@].@].@].@].@

000025C0:5D 0D 40 5D 0D 3F 5C 0C 52 64 1D A1 92 80 C5 C5 ].@].?\.RD.¡'€ÅÅ

000025D0:C4 D2 D2 D2 E1 E2 E3 EB EC ED F2 F2 F3 F5 F5 F5 ÄÒÒÒáâãëìíòòóõõõ

000025E0:F7 F7 F6 F6 F6 F6 F5 F4 F3 F4 F3 F1 F1 EF EE F1 ÷÷ööööõôóôóññïîñ

000025F0:EF ED ED EC EA E7 E5 E3 DF DE DC D2 D1 D0 C4 C2 ïííìêçåãßÞÜÒÑÐÄÂ

00002600:C0 B7 B5 B2 AB A9 A6 A0 9D 9B 93 90 8D 89 88 87 À•µ²«©¦ □›"□□‰ˆ‡

00002610:7E 7E 7F 72 72 71 6B 6A 6A 69 69 6A 69 6A 6B 6F ~~rrqkjjiijijko

00002620:71 73 83 86 89 A2 A3 A5 BB BA BA C4 C7 BF AE A4 qsƒ†‰¢£¥»ººÄÇ¿®¤

00002630:81 55 64 1C 43 5C 0C 42 5B 0B 42 5B 0B 42 5B 0B □UD.C\.B[.B[.B[.

00002640:42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 B[.B[.B[.B[.B[.B

00002650:5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 44 5A [.B[.B[.B[.B[.DZ

00002660:0B 44 5A 0B 42 5B 0B 42 5B 0B 42 5B 0B 43 5C 0C .DZ.B[.B[.B[.C\.

00002670:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5D 0A 43 C\.C\.C\.C\.C].C

00002680:5D 0A 43 5C 0C 44 5A 0B 44 5A 0B 43 59 0A 43 59 ].C\.DZ.DZ.CY.CY

00002690:0A 44 5A 0B 42 5C 09 00 40 5D 0D 40 5D 0D 40 5D .DZ.B\..@].@].@]

000026A0:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D .@].@].@].@].@].

000026B0:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 @].@].@].@].@].@

000026C0:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D ].@].@].@].@].@]

000026D0:0D 3F 5C 0C 75 82 5E 9E A0 A2 C6 C7 C8 DE DE DE .?\.u‚^ž ¢ÆÇÈÞÞÞ

000026E0:EA E9 E8 F2 F1 F0 F5 F3 F0 F5 F3 F0 F1 ED E9 EB êéèòñðõóðõóðñíéë

000026F0:E6 E0 E9 E3 DD E6 E1 DA E0 DB D6 E9 E5 DD F6 F4 æàéãÝæáÚàÛÖéåÝöô

00002700:F3 E9 E5 E1 E4 DF DA DC D7 D0 D2 CA C1 D4 CC C4 óéåáäßÚÜ×ÐÒÊÁÔÌÄ

00002710:DB D4 CC E2 DC D5 D4 CC C3 CF C7 BC F3 EF EB DF ÛÔÌâÜÕÔÌÃÏÇ¼óïëß

00002720:D9 D2 D9 D2 CB DC D7 D1 DB D8 D4 C9 C4 B8 B8 AF ÙÒÙÒËÜ×ÑÛØÔÉÄ¸¸¯

00002730:96 C3 BF B7 D0 D0 D0 D0 D1 D2 CF D1 D3 86 8F 6D –Ã¿•ÐÐÐÐÑÒÏÑÓ†□m

00002740:43 5C 0C 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 C\.B[.B[.B[.B[.B

00002750:5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B [.B[.B[.B[.B[.B[

00002760:0B 42 5B 0B 42 5B 0B 42 5B 0B 44 5A 0B 44 5A 0B .B[.B[.B[.DZ.DZ.

00002770:42 5B 0B 42 5B 0B 42 5B 0B 43 5C 0C 43 5C 0C 43 B[.B[.B[.C\.C\.C

00002780:5C 0C 43 5C 0C 43 5C 0C 43 5D 0A 43 5D 0A 44 5A \.C\.C\.C].C].DZ

00002790:0B 44 5A 0B 44 5A 0B 43 59 0A 43 59 0A 44 5A 0B .DZ.DZ.CY.CY.DZ.

000027A0:42 5C 09 00 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D B\..@].@].@].@].

000027B0:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 @].@].@].@].@].@

000027C0:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D ].@].@].@].@].@]

000027D0:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 3F 5C 0C .@].@].@].@].?\.

000027E0:89 91 7B AD AC AC AD A4 84 A2 97 5E A7 9B 5F EE ‰'{­¬¬­¤„¢--^§›_î

000027F0:E9 DA FC FC FC F8 F6 F4 EE E9 E4 E5 DE D7 E6 E1 éÚüüüøöôîéäåÞ×æá

00002800:DB E4 E0 DB B8 AA 7D B7 AD 7C FF FF FF F2 F2 F2 ÛäàÛ¸ª}•­|ÿÿÿòòò

00002810:E5 E1 DD DE D9 D3 D6 CF C8 DB D6 D0 DB D6 D0 D9 åáÝÞÙÓÖÏÈÛÖÐÛÖÐÙ

00002820:D3 CD D1 CA C2 BE B4 A8 BA AF A3 C6 BD B3 CE C6 ÓÍÑÊÂ¾´¨º¯£Æ½³ÎÆ

00002830:BE D1 CD C7 C5 B8 99 9A 8F 4D 91 88 43 9A 90 4E ¾ÑÍÇÅ¸™š□M'ˆCš□N

00002840:A5 99 61 B2 A9 8B CB CB CC 9D A4 90 43 5C 0C 42 ¥™A²©‹ËËÌ□¤□C\.B

00002850:5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B [.B[.B[.B[.B[.B[

00002860:0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B .B[.B[.B[.B[.B[.

00002870:42 5B 0B 42 5B 0B 44 5A 0B 44 5A 0B 42 5B 0B 42 B[.B[.DZ.DZ.B[.B

00002880:5B 0B 42 5B 0B 43 5C 0C 43 5C 0C 43 5C 0C 43 5C [.B[.C\.C\.C\.C\

00002890:0C 43 5C 0C 43 5D 0A 43 5D 0A 44 5A 0B 44 5A 0B .C\.C].C].DZ.DZ.

000028A0:43 59 0A 43 59 0A 43 59 0A 44 5A 0B 42 5C 09 00 CY.CY.CY.DZ.B\..

000028B0:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 @].@].@].@].@].@

000028C0:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D ].@].@].@].@].@]

000028D0:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D .@].@].@].@].@].

000028E0:40 5D 0D 40 5D 0D 40 5D 0D 3F 5C 0C 90 99 7F 7D @].@].@].?\.□™}

000028F0:7C 7C 73 70 69 83 7D 64 93 88 5F A6 9C 78 EA E8 ||spiƒ}D"ˆ_¦œxêè

00002900:E4 FB F9 F7 E7 E1 DA E1 D9 D1 D9 D0 BF AB 9F 68 äûù÷çáÚáÙÑÙÐ¿«Ÿh

00002910:8D 84 3E 99 8F 4C C8 BB 90 E6 E0 CA F3 F0 EB E9 □„>™□LÈ»□æàÊóðëé

00002920:E5 E1 E0 DA D4 E6 E2 DE DD D7 D2 CE C7 BF DF DA åáàÚÔæâÞÝ×ÒÎÇ¿ßÚ

00002930:D5 E1 DC D7 D5 CE C6 D6 CF C7 CC C3 B4 BC B1 99 ÕáÜ×ÕÎÆÖÏÇÌÃ´¼±™

00002940:96 8A 54 8C 80 47 90 84 56 8E 83 5D 89 82 6C 9A –ŠTŒ€G□„VŽƒ]‰‚lš

00002950:97 91 B2 B2 B3 92 9B 80 43 5C 0C 42 5B 0B 42 5B --'²²³'›€C\.B[.B[

00002960:0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B .B[.B[.B[.B[.B[.

00002970:42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 B[.B[.B[.B[.B[.B

00002980:5B 0B 44 5A 0B 44 5A 0B 42 5B 0B 42 5B 0B 42 5B [.DZ.DZ.B[.B[.B[

00002990:0B 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C .C\.C\.C\.C\.C\.

000029A0:43 5D 0A 42 5C 09 44 5A 0B 44 5A 0B 43 59 0A 43 C].B\.DZ.DZ.CY.C

000029B0:59 0A 44 5A 0B 44 5A 0B 42 5C 09 00 40 5D 0B 40 Y.DZ.DZ.B\..@].@

000029C0:5D 0B 40 5E 0C 40 5E 0C 40 5E 0C 40 5E 0C 40 5E ].@^.@^.@^.@^.@^

000029D0:0C 40 5D 0B 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D .@].@].@].@].@].

000029E0:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 @].@].@].@].@].@

000029F0:5D 0D 40 5D 0D 3F 5C 0C 49 63 1A 85 94 6B A3 A7 ].@].?\.IC.…"k£§

00002A00:9E 9F A1 A3 9E A1 A5 A3 A4 A6 B9 B8 B7 EA E7 E5 žŸ¡£ž¡¥£¤¦¹¸•êçå

00002A10:DF D6 CD CE C8 C2 B6 B0 A3 A8 9F 81 A7 9F 81 A2 ßÖÍÎÈÂ¶°£¨Ÿ□§Ÿ□¢

00002A20:98 77 9A 8F 66 9A 91 6B A2 9B 84 B5 B4 AB D4 D1 ˜wš□Fš'k¢›„µ´«ÔÑ

00002A30:CD DE D9 D3 DE D8 D1 D0 C9 C1 D0 CA C4 DF DD DC ÍÞÙÓÞØÑÐÉÁÐÊÄßÝÜ

00002A40:E4 E1 DE CB C8 C6 7E 7A 71 57 52 49 56 53 50 5B äáÞËÈÆ~zqWRIVSP[

00002A50:5C 5E 6E 71 74 86 88 8B A0 A1 A3 A6 AB A0 82 8F \^nqt†ˆ‹ ¡£¦« ‚□

00002A60:66 4C 63 18 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B FLC.B[.B[.B[.B[.

00002A70:42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 B[.B[.B[.B[.B[.B

00002A80:5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 44 5A [.B[.B[.B[.B[.DZ

00002A90:0B 44 5A 0B 42 5B 0B 42 5B 0B 42 5B 0B 43 5C 0C .DZ.B[.B[.B[.C\.

00002AA0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5B 09 43 C\.C\.C\.C\.C[.C

00002AB0:5B 09 44 5A 09 44 5A 0B 43 59 0A 43 59 0A 43 59 [.DZ.DZ.CY.CY.CY

00002AC0:0A 43 59 0A 43 5A 0A 00 40 5D 0D 40 5E 0E 41 5E .CY.CZ..@].@^.A^

00002AD0:0E 41 5E 0E 41 5E 0E 41 5E 0E 40 5D 0D 40 5D 0D .A^.A^.A^.@].@].

00002AE0:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 3F @].@].@].@].@].?

00002AF0:5C 0C 3F 5C 0C 3F 5C 0C 3F 5C 0C 40 5D 0D 40 5D \.?\.?\.?\.@].@]

00002B00:0D 40 5D 0D 3F 5C 0C 3F 5C 0C 44 60 13 58 70 2E .@].?\.?\.D`.Xp.

00002B10:73 85 53 84 92 6B 8F 99 7C A6 AC 9A B7 B8 AE B9 s…S„'k□™|¦¬š•¸®¹

00002B20:B9 B8 BB BD BE BA BD BF B8 BB BD B5 B8 BB B0 B3 ¹¸»½¾º½¿¸»½µ¸»°³

00002B30:B6 A9 AB AD 9D 9E 9F 8F 8F 90 86 86 86 87 86 86 ¶©«­□žŸ□□□†††‡††

00002B40:B5 B1 AD DE D8 D1 BB B5 AF 6C 6C 6C 79 79 79 6F µ±­ÞØÑ»µ¯lllyyyo

00002B50:6F 6F 71 72 71 7A 7C 76 7D 83 73 7C 86 68 7B 86 ooqrqz|v}ƒs|†h{†

00002B60:60 6F 7E 4D 57 6B 2A 46 5E 11 43 5C 0C 43 5D 0A `o~MWk*F^.C\.C].

00002B70:42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 B[.B[.B[.B[.B[.B

00002B80:5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B [.B[.B[.B[.B[.B[

00002B90:0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5A 0B 42 5A 0B .B[.B[.B[.BZ.BZ.

00002BA0:42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 43 5C 0C 43 B[.B[.B[.B[.C\.C

00002BB0:5C 0A 43 5C 0A 43 5C 0A 44 5B 09 44 5A 0A 44 5A \.C\.C\.D[.DZ.DZ

00002BC0:0A 44 5A 0B 44 5A 0B 43 59 0A 43 59 0A 43 59 0A .DZ.DZ.CY.CY.CY.

00002BD0:44 5A 0B 00 3E 5E 0D 3F 5D 0D 3F 5D 0D 40 5E 0E DZ..>^.?].?].@^.

00002BE0:41 5E 0E 40 5D 0D 40 5D 0D 3F 5C 0C 40 5D 0C 40 A^.@].@].?\.@].@

00002BF0:5D 0C 40 5D 0C 40 5D 0C 3F 5C 0B 3F 5C 0B 3F 5C ].@].@].?\.?\.?\

00002C00:0B 3F 5C 0B 40 5D 0D 40 5D 0D 40 5D 0D 3F 5C 0C .?\.@].@].@].?\.

00002C10:3F 5C 0C 3F 5C 0C 40 5D 0D 40 5D 0D 40 5D 0D 40 ?\.?\.@].@].@].@

00002C20:5D 0D 40 5D 0D 41 5C 0C 48 62 16 52 69 23 58 6E ].@].A\.HB.Ri#Xn

00002C30:2D 5D 72 34 61 75 3A 64 77 3F 67 79 42 68 7A 44 -]r4Au:Dw?gyBhzD

00002C40:69 7B 46 69 7A 46 68 78 44 66 77 42 64 75 40 8C i{FizFhxDFwBDu@Œ

00002C50:96 6D C0 BE B0 51 62 2B 57 6B 2D 58 6D 2C 51 67 –mÀ¾°QB+Wk-Xm,Qg

00002C60:22 49 60 15 41 5B 0B 41 5B 0B 41 5B 0B 41 5B 0B "I`.A[.A[.A[.A[.

00002C70:41 5B 0B 40 5B 0B 40 5B 0B 40 5C 09 42 5B 0A 42 A[.@[.@[.@\.B[.B

00002C80:5B 0A 42 5B 0A 42 5B 0A 42 5B 0A 42 5B 0A 42 5B [.B[.B[.B[.B[.B[

00002C90:0A 41 5A 0A 42 5A 0C 42 5A 0C 42 5A 0C 42 5B 0B .AZ.BZ.BZ.BZ.B[.

00002CA0:42 5B 0B 42 5B 0B 42 5B 0A 42 5B 0A 44 5A 0B 44 B[.B[.B[.B[.DZ.D

00002CB0:5A 0B 44 5A 0A 44 5A 0A 44 5A 0A 45 5B 0B 45 5B Z.DZ.DZ.DZ.E[.E[

00002CC0:0B 45 5B 0B 44 5A 09 44 5A 09 44 5A 0B 44 5A 0B .E[.DZ.DZ.DZ.DZ.

00002CD0:44 5A 0B 44 5A 0B 43 59 0A 43 59 0A 43 5B 09 00 DZ.DZ.CY.CY.C[..

00002CE0:3F 5F 0D 3F 5F 0D 3F 5F 0D 3F 5F 0D 40 5E 0D 40 ?_.?_.?_.?_.@^.@

00002CF0:5E 0D 40 5E 0D 40 5E 0D 40 5F 0C 40 5F 0C 40 5F ^.@^.@^.@_.@_.@_

00002D00:0C 40 5F 0C 3F 5E 0B 3F 5E 0B 40 5E 0B 40 5E 0B .@_.?^.?^.@^.@^.

00002D10:40 5D 0C 40 5D 0C 40 5D 0C 40 5D 0C 40 5D 0C 40 @].@].@].@].@].@

00002D20:5D 0C 40 5D 0C 40 5D 0C 40 5D 0C 40 5D 0C 40 5D ].@].@].@].@].@]

00002D30:0C 41 5D 0C 41 5C 0B 41 5C 0B 41 5C 0B 41 5C 0B .A].A\.A\.A\.A\.

00002D40:41 5D 0C 41 5D 0C 41 5D 0C 40 5C 0B 40 5C 0B 40 A].A].A].@\.@\.@

00002D50:5C 0B 40 5C 0B 40 5C 0C 41 5C 0C 41 5C 0C 5A 70 \.@\.@\.A\.A\.Zp

00002D60:2B 41 5C 0C 41 5C 0C 41 5C 0C 41 5C 0C 41 5C 0C +A\.A\.A\.A\.A\.

00002D70:41 5C 0B 41 5C 0B 41 5C 0B 41 5C 0B 41 5C 0B 41 A\.A\.A\.A\.A\.A

00002D80:5C 0B 41 5C 0B 41 5D 0B 42 5D 0A 42 5D 0A 42 5D \.A\.A].B].B].B]

00002D90:0A 42 5D 0A 42 5D 0A 42 5D 0A 42 5D 0A 42 5D 0A .B].B].B].B].B].

00002DA0:42 5C 0B 42 5C 0B 42 5C 0B 42 5C 0B 42 5C 0B 43 B\.B\.B\.B\.B\.C

00002DB0:5C 0B 43 5D 0A 43 5D 0A 44 5C 0B 44 5C 0B 44 5C \.C].C].D\.D\.D\

00002DC0:0A 44 5C 0A 44 5C 0A 44 5C 0A 44 5C 0A 44 5C 0A .D\.D\.D\.D\.D\.

00002DD0:43 5B 0A 43 5B 0A 43 5B 0A 43 5B 0A 43 5B 0A 43 C[.C[.C[.C[.C[.C

00002DE0:5B 0A 43 5B 0A 43 5B 0A 43 5D 09 00 3F 61 0C 40 [.C[.C[.C]..?A.@

00002DF0:62 0D 40 62 0D 3F 61 0C 3F 61 0C 3F 61 0C 3F 61 B.@B.?A.?A.?A.?A

00002E00:0C 3F 61 0C 3F 61 0C 3F 61 0C 3F 61 0C 3F 61 0C .?A.?A.?A.?A.?A.

00002E10:3F 60 0C 3F 60 0C 40 60 0C 40 60 0C 40 60 0C 40 ?`.?`.@`.@`.@`.@

00002E20:60 0C 3F 5F 0C 3F 5F 0C 3F 5F 0C 40 60 0C 40 60 `.?_.?_.?_.@`.@`

00002E30:0C 40 60 0C 3F 5F 0B 3F 5F 0B 3F 5F 0C 41 5F 0C .@`.?_.?_.?_.A_.

00002E40:41 5E 0B 41 5E 0B 42 5F 0C 42 5F 0C 40 60 0C 40 A^.A^.B_.B_.@`.@

00002E50:60 0C 40 60 0C 3F 5F 0B 3F 5F 0B 3F 5F 0B 3F 5F `.@`.?_.?_.?_.?_

00002E60:0B 3F 5F 0B 42 5F 0C 42 5F 0C 41 5E 0B 41 5E 0B .?_.B_.B_.A^.A^.

00002E70:41 5E 0B 41 5E 0B 41 5E 0B 41 5F 0C 41 5E 0B 41 A^.A^.A^.A_.A^.A

00002E80:5E 0B 41 5E 0B 41 5E 0B 41 5E 0B 41 5F 0B 41 5F ^.A^.A^.A^.A_.A_

00002E90:0B 41 5F 0A 41 5F 0B 41 5F 0B 41 5F 0B 41 5F 0B .A_.A_.A_.A_.A_.

00002EA0:41 5F 0B 41 5F 0B 41 5F 0B 41 5F 0B 42 5F 0B 42 A_.A_.A_.A_.B_.B

00002EB0:5F 0B 41 5F 0B 41 5F 0B 41 5F 0B 43 5F 0B 43 5E _.A_.A_.A_.C_.C^

00002EC0:0A 43 5E 0A 43 5F 0B 43 5F 0B 43 5F 0B 43 5F 0B .C^.C_.C_.C_.C_.

00002ED0:43 5F 0B 43 5F 0A 43 5F 0A 43 5F 0A 42 5E 09 42 C_.C_.C_.C_.B^.B

00002EE0:5E 09 42 5E 09 42 5E 09 42 5E 09 42 5E 09 42 5E ^.B^.B^.B^.B^.B^

00002EF0:09 42 5E 09 42 5E 09 00 3F 64 0B 3F 64 0B 3F 64 .B^.B^..?D.?D.?D

00002F00:0B 3F 64 0B 3F 64 0B 3F 64 0B 3F 64 0B 3F 64 0B .?D.?D.?D.?D.?D.

00002F10:3F 64 0C 3F 64 0C 3F 64 0C 3F 62 0C 40 62 0C 40 ?D.?D.?D.?B.@B.@

00002F20:62 0C 40 62 0C 40 62 0C 40 62 0C 40 62 0C 3F 62 B.@B.@B.@B.@B.?B

00002F30:0C 3F 62 0C 40 63 0C 40 63 0D 40 62 0C 40 62 0C .?B.@C.@C.@B.@B.

00002F40:3F 62 0B 3F 62 0B 3F 62 0C 40 62 0C 40 62 0C 41 ?B.?B.?B.@B.@B.A

00002F50:62 0C 41 63 0D 40 62 0C 40 63 0A 40 63 0A 40 63 B.AC.@B.@C.@C.@C

00002F60:0A 3F 62 0C 3F 62 0C 3F 62 0C 3F 62 0C 3F 62 0C .?B.?B.?B.?B.?B.

00002F70:40 61 0B 40 61 0B 40 61 0B 40 61 0B 40 61 0B 40 @A.@A.@A.@A.@A.@

00002F80:61 0B 40 61 0B 41 62 0C 40 61 0B 40 61 0B 40 61 A.@A.AB.@A.@A.@A

00002F90:0B 40 61 0B 40 61 0B 40 61 0B 40 61 0B 40 61 0B .@A.@A.@A.@A.@A.

00002FA0:40 61 0B 40 61 0B 40 61 0B 40 61 0B 40 61 0B 40 @A.@A.@A.@A.@A.@

00002FB0:61 0B 40 61 0B 40 61 0B 40 61 0B 40 61 0B 40 61 A.@A.@A.@A.@A.@A

00002FC0:0B 40 62 09 40 62 09 40 62 09 42 61 09 42 61 09 .@B.@B.@B.BA.BA.

00002FD0:42 61 09 42 61 09 42 61 09 42 61 09 42 61 09 42 BA.BA.BA.BA.BA.B

00002FE0:61 09 42 61 09 42 61 09 40 62 09 42 61 09 42 61 A.BA.BA.@B.BA.BA

00002FF0:09 42 61 09 42 61 09 42 61 09 42 61 09 42 61 09 .BA.BA.BA.BA.BA.

00003000:42 61 09 00 3D 60 0F 3D 60 0F 3D 60 0F 3D 60 0F BA..=`.=`.=`.=`.

00003010:3D 60 0F 3D 60 0F 3D 60 0F 3D 60 0F 3D 60 0F 3D =`.=`.=`.=`.=`.=

00003020:60 0F 3D 60 0F 3D 60 0F 3D 60 0F 3D 60 0F 3D 60 `.=`.=`.=`.=`.=`

00003030:0F 3D 60 0F 3D 61 0E 3D 61 0E 3C 60 0D 3C 60 0D .=`.=A.=A.<`.<`.

00003040:3D 61 0E 3D 61 0E 3D 61 0E 3D 61 0E 3D 61 0E 3D =A.=A.=A.=A.=A.=

00003050:61 0E 3D 61 0E 3D 61 0E 3D 61 0E 3D 61 0E 3D 61 A.=A.=A.=A.=A.=A

00003060:0E 3D 61 0E 3D 61 0E 3D 61 0E 3D 61 0E 3D 61 0E .=A.=A.=A.=A.=A.

00003070:3C 60 0D 3E 5F 0D 3E 5F 0D 3E 5F 0D 3E 5F 0D 3E <`.>_.>_.>_.>_.>

00003080:5F 0D 3E 5F 0D 3E 5F 0D 3E 5F 0D 3E 5F 0D 3E 5F _.>_.>_.>_.>_.>_

00003090:0D 3E 5F 0D 3E 5F 0D 3E 5F 0D 3E 5F 0D 3E 5F 0D .>_.>_.>_.>_.>_.

000030A0:3E 5F 0D 3E 5F 0D 3E 5F 0D 3E 5F 0D 3E 5F 0D 3E >_.>_.>_.>_.>_.>

000030B0:5F 0D 3E 5F 0D 3E 5F 0D 3F 5F 0D 3F 5F 0D 3F 5F _.>_.>_.?_.?_.?_

000030C0:0D 3F 5F 0D 3E 5F 0D 3E 5F 0D 3E 5F 0D 3E 5F 0D .?_.>_.>_.>_.>_.

000030D0:3E 60 0B 3D 5F 0A 3E 5F 0A 3E 5F 0A 3F 60 0B 3F >`.=_.>_.>_.?`.?

000030E0:60 0B 3F 60 0B 3F 60 0B 3F 60 0B 3F 60 0B 3F 60 `.?`.?`.?`.?`.?`

000030F0:0B 3F 60 0B 3E 60 0B 3E 60 0B 3E 60 0B 3F 60 0B .?`.>`.>`.>`.?`.

00003100:3F 60 0B 3F 60 0B 3F 5F 0D 3F 5F 0D 3D 5F 0A 00 ?`.?`.?_.?_.=_..

00003110:12 00 00 00 0C 00 00 00 01 00 00 00 52 00 00 00 ............R...

00003120:70 01 00 00 02 00 00 00 F3 FF FF FF 00 00 00 00 p.......óÿÿÿ....

00003130:4E 0C 00 00 4E 0C 00 00 C8 00 00 00 00 00 00 01 N...N...È.......

00003140:04 00 00 02 41 00 72 00 69 00 61 00 6C 00 00 00 ....A.r.i.A.l...

00003150:00 00 00 00 00 00 00 00 00 00 00 00 0C 45 00 00 .............E..

00003160:BC 16 E8 FE FE 07 00 00 20 00 CC 00 00 00 00 00 ¼.èþþ... .Ì.....

00003170:4C 00 00 00 FE 07 00 00 DA 16 01 B8 FF FF FF FF L...þ...Ú..¸ÿÿÿÿ

00003180:00 00 00 00 00 00 00 00 F0 F6 13 00 00 00 00 00 ........ðö......

00003190:0E 20 05 27 00 00 00 00 28 00 00 00 00 00 00 00 . .'....(.......

000031A0:1C 2F 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ./..............

000031B0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ................

000031C0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ................

000031D0:00 00 00 00 00 00 00 00 28 00 00 00 FF FF FF 00 ........(...ÿÿÿ.

000031E0:1C 2F 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ./..............

000031F0:58 00 00 00 2C 00 00 00 00 00 00 00 00 00 00 00 X...,...........

00003200:00 00 80 3F 00 00 00 00 00 00 00 00 00 00 80 3F ..€?..........€?

00003210:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ................

00003220:D0 C5 35 00 00 00 00 00 28 00 00 00 59 00 00 00 ÐÅ5.....(...Y...

00003230:2D 00 00 00 01 00 18 00 00 00 00 00 1C 2F 00 00 -............/..

00003240:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ................

00003250:10 00 90 01 00 00 00 00 25 00 00 00 00 00 00 00 ..□.....%.......

00003260:D3 3F EC FE FE 07 00 00 79 0D 21 11 00 00 00 00 Ó?ìþþ...y.!.....

00003270:10 00 90 01 00 00 00 00 00 00 00 00 59 00 00 00 ..□.........Y...

00003280:2D 00 00 00 64 76 00 08 00 00 00 00 25 00 00 00 -...Dv......%...

00003290:0C 00 00 00 02 00 00 00 54 00 00 00 A0 00 00 00 ........T... ...

000032A0:00 00 00 00 00 00 00 00 FF FF FF FF FF FF FF FF ........ÿÿÿÿÿÿÿÿ

000032B0:01 00 00 00 AB 0A 0D 42 00 00 0D 42 12 00 00 00 ....«..B...B....

000032C0:05 00 00 00 0E 00 00 00 4C 00 00 00 00 00 00 00 ........L.......

000032D0:00 00 00 00 00 00 00 00 FF FF FF FF FF FF FF FF ........ÿÿÿÿÿÿÿÿ

000032E0:68 00 00 00 53 00 69 00 6D 00 70 00 6C 00 65 00 h...S.i.m.p.l.E.

000032F0:20 00 53 00 61 00 6D 00 70 00 6C 00 65 00 00 00 .S.A.m.p.l.E...

00003300:09 00 00 00 03 00 00 00 0B 00 00 00 07 00 00 00 ................

00003310:03 00 00 00 07 00 00 00 04 00 00 00 09 00 00 00 ................

00003320:07 00 00 00 0B 00 00 00 07 00 00 00 03 00 00 00 ................

00003330:07 00 00 00 09 00 00 00 52 00 00 00 70 01 00 00 ........R...p...

00003340:03 00 00 00 F3 FF FF FF 00 00 00 00 4E 0C 00 00 ....óÿÿÿ....N...

00003350:4E 0C 00 00 C8 00 00 00 00 00 00 00 04 00 00 02 N...È...........

00003360:4D 00 69 00 63 00 72 00 6F 00 73 00 6F 00 66 00 M.i.C.r.o.s.o.F.

00003370:74 00 20 00 53 00 61 00 6E 00 73 00 20 00 53 00 t. .S.A.n.s. .S.

00003380:65 00 72 00 69 00 66 00 00 00 00 00 00 00 00 00 E.r.i.F.........

00003390:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ................

000033A0:00 00 00 00 28 00 00 00 59 00 00 00 2D 00 00 00 ....(...Y...-...

000033B0:01 00 18 00 00 00 00 00 1C 2F 00 00 00 00 00 00 ........./......

000033C0:00 00 00 00 00 00 00 00 00 00 00 00 10 00 90 01 ..............□.

000033D0:00 00 00 00 25 00 00 00 00 00 00 00 D3 3F EC FE ....%.......Ó?ìþ

000033E0:FE 07 00 00 79 0D 21 11 00 00 00 00 10 00 90 01 þ...y.!.......□.

000033F0:00 00 00 00 00 00 00 00 59 00 00 00 2D 00 00 00 ........Y...-...

00003400:64 76 00 08 00 00 00 00 00 00 00 00 00 08 0D 00 Dv..............

00003410:0D 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ................

00003420:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ................

00003430:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ................

00003440:00 00 00 00 92 A0 CD 02 00 00 00 00 CA BE CD 02 ....' Í.....Ê¾Í.

00003450:00 00 00 00 00 00 00 00 00 00 00 00 FF FF 5A FE ............ÿÿZþ

00003460:00 00 00 00 00 00 00 00 00 00 00 00 95 F1 53 FE ............•ñSþ

00003470:FE 07 00 00 BE 06 5A FE FE 07 00 00 87 F2 53 FE þ...¾.Zþþ...‡òSþ

00003480:FE 07 00 00 C4 04 5A FE FE 07 00 00 79 0D 21 11 þ...Ä.Zþþ...y.!.

00003490:00 00 00 00 01 00 00 00 00 00 00 00 F0 02 5A FE ............ð.Zþ

000034A0:64 76 00 08 00 00 00 00 25 00 00 00 0C 00 00 00 Dv......%.......

000034B0:03 00 00 00 52 00 00 00 70 01 00 00 04 00 00 00 ....R...p.......

000034C0:F2 FF FF FF 00 00 00 00 4E 0C 00 00 4E 0C 00 00 òÿÿÿ....N...N...

000034D0:C8 00 00 00 00 00 00 00 04 00 00 02 4D 00 69 00 È...........M.i.

000034E0:63 00 72 00 6F 00 73 00 6F 00 66 00 74 00 20 00 C.r.o.s.o.F.t. .

000034F0:53 00 61 00 6E 00 73 00 20 00 53 00 65 00 72 00 S.A.n.s. .S.E.r.

00003500:69 00 66 00 00 00 00 00 00 00 00 00 00 00 00 00 i.F.............

00003510:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ................

00003520:C8 F1 13 00 00 00 00 00 10 00 90 01 00 00 00 00 Èñ........□.....

00003530:20 AC CF 02 00 00 00 00 10 00 00 00 06 00 00 00 ¬Ï.............

00003540:06 00 00 00 04 00 00 00 01 00 00 00 01 00 00 00 ................

00003550:01 00 00 00 01 00 00 00 0D 00 00 00 00 00 00 00 ................

00003560:03 00 00 00 00 08 00 00 3B 09 00 00 00 00 00 00 ........;.......

00003570:A0 E8 07 02 00 00 00 00 03 00 00 00 FE 07 00 00 è..........þ...

00003580:90 01 00 00 4D 00 69 00 63 00 72 00 6F 00 73 00 □...M.i.C.r.o.s.

00003590:6F 00 66 00 74 00 20 00 53 00 61 00 00 00 73 00 o.F.t. .S.A...s.

000035A0:20 00 53 00 65 00 72 00 69 00 66 00 00 00 00 00 .S.E.r.i.F.....

000035B0:00 00 00 00 00 00 00 00 FF FF 5A FE 00 00 00 00 ........ÿÿZþ....

000035C0:40 02 5A FE FE 07 00 00 9D 04 00 00 00 00 00 00 @.Zþþ...□.......

000035D0:FF FF FF FF FF FF FF FF 01 00 00 00 00 00 00 00 ÿÿÿÿÿÿÿÿ........

000035E0:20 AC CF 02 00 00 00 00 00 00 07 02 00 00 00 00 ¬Ï.............

000035F0:10 AC CF 02 00 00 00 00 26 36 E3 76 00 00 00 00 .¬Ï.....&6ãv....

00003600:00 00 07 02 00 00 00 00 01 00 00 00 00 27 00 00 .............'..

00003610:00 00 00 00 00 00 00 00 20 AC CF 02 64 76 00 08 ........ ¬Ï.Dv..

00003620:00 00 00 00 25 00 00 00 0C 00 00 00 04 00 00 00 ....%...........

00003630:28 00 00 00 0C 00 00 00 03 00 00 00 52 00 00 00 (...........R...

00003640:70 01 00 00 03 00 00 00 13 00 00 00 00 00 00 00 p...............

00003650:4E 0C 00 00 4E 0C 00 00 C8 00 00 00 00 00 00 00 N...N...È.......

00003660:04 00 00 02 4D 00 69 00 63 00 72 00 6F 00 73 00 ....M.i.C.r.o.s.

00003670:6F 00 66 00 74 00 20 00 53 00 61 00 6E 00 73 00 o.F.t. .S.A.n.s.

00003680:20 00 53 00 65 00 72 00 69 00 66 00 00 00 00 00 .S.E.r.i.F.....

00003690:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ................

000036A0:00 00 00 00 00 00 73 00 20 00 53 00 65 00 72 00 ......s. .S.E.r.

000036B0:69 00 66 00 00 00 00 00 00 00 00 00 00 00 00 00 i.F.............

000036C0:FF FF 5A FE 00 00 00 00 40 02 5A FE FE 07 00 00 ÿÿZþ....@.Zþþ...

000036D0:9D 04 00 00 00 00 00 00 FF FF FF FF FF FF FF FF □.......ÿÿÿÿÿÿÿÿ

000036E0:01 00 00 00 00 00 00 00 20 AC CF 02 00 00 00 00 ........ ¬Ï.....

000036F0:00 00 07 02 00 00 00 00 40 02 5A FE FE 07 00 00 ........@.Zþþ...

00003700:F3 14 00 00 00 00 00 00 F3 14 0A 1E 00 00 00 00 ó.......ó.......

00003710:94 8A E8 FE FE 07 00 00 04 00 00 00 00 00 00 00 "Šèþþ...........

00003720:65 58 53 FE 00 00 00 00 00 00 00 00 00 00 00 00 EXSþ............

00003730:00 F5 13 00 00 00 00 00 03 01 56 E5 89 1A 00 00 .õ........Vå‰...

00003740:55 00 00 00 00 00 00 00 00 00 00 00 04 00 00 00 U...............

00003750:00 00 00 00 FE 07 00 00 79 0D 21 11 00 00 00 00 ....þ...y.!.....

00003760:40 02 5A FE 00 00 00 00 26 06 5A FE FE 07 00 00 @.Zþ....&.Zþþ...

00003770:08 F5 13 00 00 00 00 00 00 F5 13 00 00 00 00 00 .õ.......õ......

00003780:07 CB 54 FE FE 07 00 00 79 0D 21 11 00 00 00 00 .ËTþþ...y.!.....

00003790:04 00 00 00 00 00 00 00 24 07 5A FE FE 07 00 00 ........$.Zþþ...

000037A0:01 00 00 00 64 76 00 08 00 00 00 00 25 00 00 00 ....Dv......%...

000037B0:0C 00 00 00 03 00 00 00 25 00 00 00 0C 00 00 00 ........%.......

000037C0:02 00 00 00 28 00 00 00 0C 00 00 00 04 00 00 00 ....(...........

000037D0:28 00 00 00 0C 00 00 00 03 00 00 00 25 00 00 00 (...........%...

000037E0:0C 00 00 00 0D 00 00 80 0E 00 00 00 14 00 00 00 .......€........

000037F0:00 00 00 00 10 00 00 00 14 00 00 00             ............ 

### EMR_HEADER Example

This section provides an example of an EMR_HEADER record (section 2.3.4.2).

00000000:01 00 00 00 D4 00 00 00 00 00 00 00 00 00 00 00

00000010:59 00 00 00 59 00 00 00 00 00 00 00 00 00 00 00

00000020:42 0C 00 00 41 0C 00 00 20 45 4D 46 00 00 01 00

00000030:FC 37 00 00 16 00 00 00 05 00 00 00 34 00 00 00

00000040:6C 00 00 00 00 00 00 00 80 07 00 00 B0 04 00 00

00000050:A5 02 00 00 A7 01 00 00 00 00 00 00 00 00 00 00

00000060:00 00 00 00 D5 55 0A 00 A5 75 06 00 53 00 61 00

00000070:6D 00 70 00 6C 00 65 00 20 00 45 00 4D 00 46 00

00000080:20 00 74 00 68 00 61 00 74 00 20 00 68 00 61 00

00000090:73 00 20 00 61 00 20 00 62 00 72 00 75 00 73 00

000000A0:68 00 20 00 66 00 69 00 6C 00 6C 00 2C 00 20 00

000000B0:62 00 69 00 74 00 6D 00 61 00 70 00 2C 00 20 00

000000C0:61 00 6E 00 64 00 20 00 74 00 65 00 78 00 74 00

000000D0:00 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000001) |
| Size (0x000000D4) |
| Bounds (0x00000000) |
| ... (0x00000000) |
| ... (0x00000059) |
| ... (0x00000059) |
| Frame (0x00000000) |
| ... (0x00000000) |
| ... (0x00000C42) |
| ... (0x00000C31) |

**Type (4 ****bytes)**: 0x00000001 identifies the record type as EMR_HEADER.

**Size (4 bytes)**: 0x000000D4 is the record size in bytes.

**Bounds (16 bytes)**: 0x00000000, 0x00000000, 0x00000059, 0x00000059 specify the rectangular **inclusive-inclusive** bounds of the smallest rectangle that can be drawn around the image stored in the **metafile** in logical units.

**Frame (16 bytes)**: 0x00000000, 0x00000000, 0x00000C42, 0x00000C31 specify the rectangular inclusive-inclusive dimensions, in .01 millimeter units, of a rectangle that surrounds the image stored in the metafile.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Signature (0x464D4520) |
| Version (0x00010000) |
| Byte (0x000037FC) |
| Records (0x00000016) |
| Handles (0x0005) | Reserved (0x0000) |
| nDescription (0x00000034) |
| offDescription (0x0000006C) |
| PalEntries (0x00000000) |

**Signature (4 bytes)**: 0x464D4520 is the record signature, which consists of the **ASCII** string "EMF".

**Version (4 bytes)**: 0x00010000 specifies **EMF** metafile interoperability.

**Bytes (4 bytes)**: 0x000037FC specifies the size of the metafile in bytes.

**Records (4 bytes)**: 0x00000016 specifies the number of records in the metafile.

**Handles (2 bytes)**: 0x0005 specifies the number of graphics objects that are created during the processing of the metafile. These objects are referenced by their indexes in metafile records. Index values for created objects start at 1. This value can be used to compute the size needed for the EMF object table (section 3.1.1.1).

**Reserved (2 bytes)**: 0x0000 is ignored.

**nDescription (4 bytes)**: 0x00000034 specifies the number of characters in the array that contains the description of the metafile's contents.

**offDescription (4 bytes)**: 0x0000006C specifies the offset from the beginning of this record to the array that contains the description of the metafile's contents.

**PalEntries (4 bytes)**: 0x00000000 specifies the number of entries in the metafile **palette**. The location of the palette is specified in the EMR_EOF record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Device (0x00000780) |
| ... (0x00000780) |
| Millimeters (0x000002A5) |
| ... (0x000001A7) |
| cbPixelFormat (0x00000000) |
| offPixelFormat (0x00000000) |
| bOpenGL (0x00000000) |
| MicrometersX (0x000A55D5) |
| MicrometersY (0x000675A5) |
| EmfDescription ("Sample EMF that has a brush fill, bitmap, and text") |

**Device (8 bytes)**: 0x00000780, 0x00000780 specify the size of the reference device, in pixels.

**Millimeters (8 bytes)**: 0x000002A5, 0x000001A7 specify the size of the reference device, in millimeters.

**cbPixelFormat (4 bytes)**: 0x00000000 specifies the size of the PixelFormatDescriptor (section 2.2.22) structure. This value indicates that no pixel format is defined.

**offPixelFormat (4 bytes)**: 0x00000000 specifies the offset to the PixelFormatDescriptor in the metafile. In this case, no pixel format structure is present.

**bOpenGL (4 bytes)**: 0x00000000 specifies that no **OpenGL** commands are present in the metafile.

**Micrometers (8 bytes)**: 0x000A55D5, 0x000675A5 specify the horizontal and vertical size of the reference device, in micrometers.

**EmfDescription (4 bytes)**: "Sample EMF that has a brush fill, bitmap, and text".

### EMR_CREATEBRUSHINDIRECT Example

This section provides an example of an EMR_CREATEBRUSHINDIRECT record (section 2.3.7.1).

000000D0:            27 00 00 00 18 00 00 00 01 00 00 00

000000E0:02 00 00 00 52 47 2A 00 03 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000027) |
| Size (0x00000018) |
| ihBrush (0x00000001) |
| LogBrush (0x00000002) (12 bytes) |
| ... (0x0052472A) |
| ... (0x00000003) |

**Type (4 bytes)**: 0x00000027 identifies this record type as EMR_CREATEBRUSHINDIRECT.

**Size (4 bytes)**: 0x00000018 specifies the size of this record in bytes.

**ihBrush (4 bytes)**: 0x00000001 specifies the index of this brush object in the EMF object table (section 3.1.1.1).

**LogBrush (12 bytes)**: A LogBrushEx object (section 2.2.12) that contains brush data.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BrushStyle (0x00000002) |
| Color (0x0052472A) |
| BrushHatch (0x00000003) |

**BrushStyle (4 bytes)**: 0x00000002 specifies a hatch brush style, from the **BrushStyle** enumeration ([MS-WMF] section 2.1.1.4).

**Color (4 ****bytes)**: 0x0052472A is a **ColorRef** object ([MS-WMF] section 2.2.2.8) that specifies the brush color value.

**BrushHatch (4 bytes)**: 0x00000003 specifies the brush hatch. Its interpretation depends on the value of **BrushStyle**. In this case, it specifies a 45-degree upward, left-to-right hatch pattern.

### EMR_SELECTOBJECT Example 1

This section provides an example of an EMR_SELECTOBJECT record (section 2.3.8.5).

000000E0:                                    25 00 00 00

000000F0:0C 00 00 00 01 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000025) |
| Size (0x0000000C) |
| ihObject (0x00000001) |

**Type (4 bytes)**: 0x00000025 identifies this record type as EMR_SELECTOBJECT.

**Size (4 bytes)**: 0x0000000C specifies the size of this record in bytes.

**ihObject (4 bytes)**: 0x00000001 specifies the index of an object in the EMF object table.

### EMR_BITBLT Example 1

This section provides an example of an EMR_BITBLT record (section 2.3.1.2).

000000F0:                        4C 00 00 00 64 00 00 00

00000100:00 00 00 00 00 00 00 00 59 00 00 00 59 00 00 00

00000110:00 00 00 00 00 00 00 00 5A 00 00 00 5A 00 00 00

00000120:21 00 F0 00 00 00 00 00 00 00 00 00 00 00 80 3F

00000130:00 00 00 00 00 00 00 00 00 00 80 3F 00 00 00 00

00000140:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00

00000150:00 00 00 00 00 00 00 00 00 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x0000004C) |
| Size (0x00000064) |
| Bounds (0x00000000) |
| ... (0x00000000) |
| ... (0x00000059) |
| ... (0x00000059) |
| xDest (0x00000000) |
| yDest (0x00000000) |
| cxDest (0x00000059) |
| cyDest (0x00000059) |

**Type (4 bytes)**: 0x0000004C identifies this record type as EMR_BITBLT.

**Size (4 bytes)**: 0x00000064 specifies the size of this record in bytes.

**Bounds (16 bytes)**: 0x00000000, 0x00000000, 0x00000059, 0x00000059 specify the bounding rectangle in logical units.

**xDest (4 bytes)**: 0x00000000 specifies the logical x-coordinate of the upper-left corner of the destination rectangle.

**yDest (4 bytes)**: 0x00000000 specifies the logical y-coordinate of the upper-left corner of the destination rectangle.

**cxDest (4 bytes)**: 0x0000005A specifies the logical width of the destination rectangle.

**cyDest (4 bytes)**: 0x0000005A specifies the logical height of the destination rectangle.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BitBlitRasterOperation (0x00F00021) |
| xSrc (0x00000000) |
| ySrc (0x00000000) |
| xformSrc (0x3F800000) (24 bytes) |
| ... (0x00000000) |
| ... (0x00000000) |
| ... (0x3F800000) |
| ... (0x00000000) |
| ... (0x00000059) |

**BitBlitRasterOperation (4 bytes)**: 0x00F00021 specifies the **raster operation** code from the **Ternary Raster Operation** enumeration ([MS-WMF] section 2.1.1.31). This code defines how the color data of the source rectangle is to be combined with the color data of the destination rectangle to achieve the final color.

**xSrc (4 bytes)**: 0x00000000 specifies the logical x-coordinate of the upper-left corner of the source rectangle.

**ySrc (4 bytes)**: 0x00000000 specifies the logical y-coordinate of the upper-left corner of the source rectangle.

**xformSrc (24 bytes)**: 0x3F800000, 0x00000000, 0x00000000, 0x3F800000, 0x00000000, 0x00000000 specify the **world-space** to **page-space** **transform**. For more information on **coordinate spaces**, see [MSDN-WRLDPGSPC].

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BkColorSrc (0x00000000) |
| UsageSrc (0x00000000) |
| offBmiSrc (0x00000000) |
| cbBmiSrc (0x00000000) |
| offBitsSrc (0x00000000) |
| cbBitsSrc (0x00000000) |

**BkColorSrc (4 bytes)**: 0x00000000 specifies the background **RGB** color.

**UsageSrc (4 bytes)**: 0x00000000 specifies the value of the **Colors** field of the **DeviceIndependentBitmap** object ([MS-WMF] section 2.2.2.9) from the DIBColors enumeration (section 2.1.9).

**offBmiSrc (4 bytes)**: 0x00000000 specifies the offset to the source **DeviceIndependentBitmap** object.

**cbBmiSrc (4 bytes)**: 0x00000000 specifies the size of the source **DeviceIndependentBitmap** object.

**offBitsSrc (4 bytes)**: 0x00000000 specifies the offset to the source **bitmap** bits.

**cbBitsSrc (4 bytes)**: 0x00000000 specifies the size of the source bitmap bits.

### EMR_SELECTOBJECT Example 2

This section provides an example of an EMR_SELECTOBJECT record (section 2.3.8.5).

00000150:                                    25 00 00 00

00000160:0C 00 00 00 00 00 00 80 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000025) |
| Size (0x0000000C) |
| ihObject (0x80000000 = WHITE BRUSH) |

**Type (4 bytes)**: 0x00000025 identifies this record type as EMR_SELECTOBJECT.

**Size ****(4 bytes)**: 0x0000000C specifies the size of this record in bytes.

**ihObject (4 bytes)**: 0x80000000 specifies the index of an object in the EMF object table.

### EMR_BITBLT Example 2

This section provides an example of an EMR_BITBLT record (section 2.3.1.2).

00000160:                        4C 00 00 00 A8 2F 00 00

00000170:00 00 00 00 2D 00 00 00 59 00 00 00 59 00 00 00

00000180:00 00 00 00 2D 00 00 00 5A 00 00 00 2D 00 00 00

00000190:20 00 CC 00 00 00 00 00 00 00 00 00 00 00 80 3F

000001A0:00 00 00 00 00 00 00 00 00 00 80 3F 00 00 00 00

000001B0:00 00 00 00 FF FF FF 00 00 00 00 00 64 00 00 00

000001C0:28 00 00 00 8C 00 00 00 1C 2F 00 00 28 00 00 00

000001D0:59 00 00 00 2D 00 00 00 01 00 18 00 00 00 00 00

000001E0:1C 2F 00 00 00 00 00 00 00 00 00 00 00 00 00 00

000001F0:00 00 00 00 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E

00000200:3F 5F 0E 3F 5F 0E 3F 5F 0E 3E 5E 0D 3F 5F 0E 3F

00000210:5F 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E

00000220:0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E

00000230:41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 40 5D 0D 3D

00000240:59 0C 5A 60 4E AE AE AE BF BF BF C5 C5 C5 C0 C0

00000250:C1 B1 B2 B1 A1 A1 A1 A9 AA AA AE AF B0 A2 A2 A2

00000260:A6 A6 A4 AF AE AD AC AC AC A6 A6 A6 99 99 99 7D

00000270:7D 7D 66 66 65 5A 5A 59 4F 4F 4F 58 58 58 76 76

00000280:76 9E 9E 9E B5 B5 B5 3C 43 2D 32 46 0A 34 4A 0A

00000290:34 49 0A 36 4C 0B 3A 52 0B 3F 59 0C 41 5C 0D 42

000002A0:5D 0D 42 5D 0D 44 5D 0D 44 5D 0D 43 5C 0C 43 5C

000002B0:0C 43 5C 0C 42 5B 0B 43 5C 0C 43 5C 0C 43 5C 0C

000002C0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43

000002D0:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C

000002E0:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C

000002F0:45 5B 0C 45 5B 0C 45 5C 0A 45 5C 0A 45 5C 0A 00

00000300:3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F

00000310:5F 0E 3F 5F 0E 3E 5E 0D 3F 5F 0E 3F 5F 0E 41 5E

00000320:0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E

00000330:41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41

00000340:5E 0E 41 5E 0E 41 5E 0E 40 5D 0D 39 52 0C 70 73

00000350:6B AD AD AD A8 A8 A8 99 99 98 A6 A6 A6 A6 A7 A7

00000360:A3 A5 A6 A6 A5 A3 AE A5 9D C9 BB AD A1 9B 95 A2

00000370:9F 9C B3 B1 AF B6 B4 B3 A9 A9 A9 97 93 90 8E 87

00000380:81 89 84 7F 81 7E 7A 79 78 76 80 7F 7E 98 98 98

00000390:BC BC BC 6D 70 65 33 47 0A 37 4D 0B 35 4B 0A 35

000003A0:4B 0B 38 4F 0B 3D 56 0C 41 5B 0D 42 5D 0D 42 5D

000003B0:0D 43 5D 0D 44 5D 0D 43 5C 0C 43 5C 0C 43 5C 0C

000003C0:42 5B 0B 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43

000003D0:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C

000003E0:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C

000003F0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 45 5B 0C 45

00000400:5B 0C 45 5C 0A 45 5C 0A 45 5C 0A 00 3F 5F 0E 3F

00000410:5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F

00000420:0E 3E 5E 0D 3F 5F 0E 3F 5F 0E 41 5E 0E 41 5E 0E

00000430:41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41

00000440:5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E

00000450:0E 41 5E 0E 40 5D 0D 38 51 0E 90 91 8E AC AC AC

00000460:C3 C3 C3 C5 C6 C6 B9 BB BC B3 B0 AD BA AD 9E C8

00000470:B4 A0 DB C8 B4 E4 D1 BE C2 B5 A9 82 7E 7A 8C 88

00000480:84 83 80 7E 98 8F 85 BE AC 9A C9 B6 A3 CC BB A9

00000490:CD C0 B3 AB A3 9B 80 7E 76 78 76 70 91 8F 8D 84

000004A0:86 80 36 4B 0B 39 50 0B 38 4E 0B 37 4D 0B 38 4F

000004B0:0B 3C 55 0C 40 5A 0D 42 5D 0D 42 5D 0D 42 5D 0D

000004C0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 42 5B 0B 43

000004D0:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C

000004E0:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C

000004F0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43

00000500:5C 0C 43 5C 0C 43 5C 0C 45 5B 0A 45 5B 0A 45 5C

00000510:0A 45 5C 0A 45 5C 0A 00 3F 5F 0E 3F 5F 0E 3F 5F

00000520:0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3E 5E 0D

00000530:3F 5F 0E 3F 5F 0E 41 5E 0E 41 5E 0E 41 5E 0E 41

00000540:5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E

00000550:0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E

00000560:40 5D 0D 3D 50 1C 94 94 94 A1 A1 A0 C9 CA CA BC

00000570:BB B8 BB AC 9C C4 AD 94 D2 BB A4 E0 CF BD E0 D0

00000580:BF DA C7 B5 DE CB B8 9A 93 8B 7C 76 70 A2 93 83

00000590:C0 AB 95 C6 B2 9D CA B8 A4 D1 C0 AD E0 D2 C4 E8

000005A0:DC CF CD C3 B5 8A 85 74 72 72 61 83 82 7E 34 43

000005B0:15 3C 54 0C 38 50 0B 38 4E 0B 39 50 0B 3D 55 0C

000005C0:40 5B 0D 42 5D 0D 42 5D 0D 42 5D 0D 43 5C 0C 43

000005D0:5C 0C 43 5C 0C 43 5C 0C 42 5B 0B 43 5C 0C 43 5C

000005E0:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C

000005F0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43

00000600:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C

00000610:0C 43 5C 0A 45 5C 0A 45 5C 0A 45 5C 0A 45 5C 0A

00000620:45 5C 0A 00 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E

00000630:3F 5F 0E 3F 5F 0E 3F 5F 0E 3E 5E 0D 3F 5F 0E 3F

00000640:5F 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E

00000650:0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E

00000660:41 5E 0E 41 5E 0E 41 5E 0E 41 5E 0E 40 5D 0D 4B

00000670:56 33 B8 B8 B8 B7 B7 B7 A1 A1 A2 BC AC 9B CC B2

00000680:97 D6 C3 AE E5 D6 C6 E4 D4 C4 E1 D2 C2 D9 C6 B4

00000690:D7 C3 AD CE BF AF AD 9A 85 BB A5 8D BD A9 93 C3

000006A0:AF 9B C8 B5 A2 CE BD AA DC CE C0 E2 D5 C9 E1 D4

000006B0:C7 D5 C5 B4 B1 A9 95 91 97 7B 4A 57 2D 39 51 0B

000006C0:38 50 0B 38 50 0B 3A 52 0C 3E 58 0C 41 5C 0D 42

000006D0:5D 0D 42 5D 0D 42 5D 0D 41 5C 0C 43 5C 0C 43 5C

000006E0:0C 43 5C 0C 42 5B 0B 43 5C 0C 43 5C 0C 43 5C 0C

000006F0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43

00000700:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C

00000710:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5D 0A

00000720:45 5C 0A 45 5C 0A 45 5C 0A 45 5C 0A 45 5C 0A 00

00000730:3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F

00000740:5F 0E 3F 5F 0E 40 5D 0D 3F 5F 0E 3F 5F 0E 41 5E

00000750:0F 41 5E 0F 41 5E 0F 41 5E 0E 41 5E 0E 40 5D 0D

00000760:40 5D 0D 40 5D 0D 41 5E 0E 40 5D 0D 40 5D 0D 40

00000770:5D 0D 40 5D 0D 41 5E 0E 41 5E 0E 61 6C 44 D0 D0

00000780:D0 B0 B0 B0 C8 C3 BE DB C8 B3 DC CA B8 EB DD CF

00000790:E8 D9 CA E5 D6 C7 E4 D6 C8 D9 C8 B5 D2 BF AA DD

000007A0:CC BA C7 B3 9E B6 9F 89 BC A7 92 C1 AD 98 C6 B3

000007B0:9F CC BA A8 DB CD BF DD D0 C2 DF D3 C6 E0 D3 C5

000007C0:E2 D4 C4 A7 AA 8E 52 62 2B 37 4D 0B 39 51 0B 3B

000007D0:53 0C 3E 57 0C 40 5A 0D 42 5D 0D 42 5D 0D 42 5D

000007E0:0D 42 5D 0D 44 5D 0D 43 5C 0C 43 5C 0C 45 5B 0D

000007F0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43

00000800:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C

00000810:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C

00000820:43 5C 0C 43 5C 0C 43 5C 0C 45 5C 0A 45 5C 0A 45

00000830:5C 0A 45 5C 0A 45 5C 0A 45 5B 0C 00 3F 5F 0E 3F

00000840:5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F

00000850:0E 40 5D 0D 3F 5F 0E 3F 5F 0E 41 5E 0E 41 5E 0F

00000860:41 5E 0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40

00000870:5D 0D 41 5E 0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D

00000880:0D 41 5E 0E 3F 5B 0D 6A 79 47 D1 D2 CE C5 C2 BF

00000890:EF E6 DD E7 D8 CA EE E0 D3 ED DF D2 EA DC CE E9

000008A0:DB CD E1 D1 C1 D6 C3 B0 D7 C4 B1 DA C9 B8 D5 C3

000008B0:B1 B8 A3 8C BC A7 91 C0 AC 97 C5 B1 9D CB B9 A5

000008C0:D6 C8 B8 CE BF AE D9 CB BD E1 D4 C7 E3 D4 C6 BC

000008D0:B9 A2 53 63 2C 37 4C 0B 3C 55 0C 3E 58 0C 40 5B

000008E0:0D 41 5C 0D 42 5D 0D 42 5D 0D 42 5D 0D 42 5D 0D

000008F0:43 5C 0C 43 5C 0C 43 5C 0C 45 5B 0C 43 5C 0C 43

00000900:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C

00000910:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C

00000920:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43

00000930:5C 0C 43 5C 0C 45 5C 0A 45 5C 0A 45 5C 0A 45 5C

00000940:0A 45 5C 0A 45 5B 0C 00 3F 5F 0E 3F 5F 0E 3F 5F

00000950:0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 40 5D 0D

00000960:3F 5F 0E 3F 5F 0E 41 5E 0E 41 5E 0E 40 5D 0D 40

00000970:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 41 5E

00000980:0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 41 5E 0E

00000990:40 59 0F 75 84 54 A6 B1 8E DC D9 CE F5 EE E8 E7

000009A0:DA CE E5 D7 C8 EB DD D0 EC DF D2 E4 D5 C4 D8 C8

000009B0:B5 D9 CA B8 D9 CB BA D9 C8 B6 D9 C8 B6 C4 B0 9C

000009C0:BA A5 90 BF AA 95 C3 AF 9B C9 B6 A3 C9 B9 A7 C7

000009D0:B7 A6 D1 C2 B3 DC CF C0 E0 D2 C3 CE C4 B3 5B 69

000009E0:33 3C 52 0D 40 5A 0D 41 5C 0D 42 5D 0D 42 5D 0D

000009F0:42 5D 0D 42 5D 0D 41 5C 0C 42 5D 0D 43 5C 0C 43

00000A00:5C 0C 43 5C 0C 45 5B 0C 43 5C 0C 43 5C 0C 43 5C

00000A10:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C

00000A20:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43

00000A30:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C

00000A40:0C 45 5C 0A 45 5C 0A 45 5C 0A 45 5C 0A 45 5C 0A

00000A50:45 5B 0C 00 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E

00000A60:3F 5F 0E 3F 5F 0E 3F 5F 0E 40 5D 0D 3F 5F 0E 3F

00000A70:5F 0E 41 5E 0E 41 5E 0E 40 5D 0D 40 5D 0D 40 5D

00000A80:0D 40 5D 0D 40 5D 0D 40 5D 0D 41 5E 0E 40 5D 0D

00000A90:40 5D 0D 40 5D 0D 40 5D 0D 41 5E 0E 44 5C 12 8B

00000AA0:97 6A 93 A2 76 C8 CA B5 F5 EE E9 E8 DC CF E0 D0

00000AB0:C1 DF D2 C4 E1 BB A1 D4 AC 8E D5 B2 97 D3 A4 84

00000AC0:D3 A5 86 D7 C4 B0 D7 C5 B1 CF BB A6 C2 AE 99 C1

00000AD0:AD 98 C1 AE 99 C5 B0 9B C7 B5 A2 C8 B8 A7 D1 C2

00000AE0:B2 E0 D3 C6 E4 D8 CA E2 D5 C6 71 7B 4B 42 58 10

00000AF0:42 5D 0D 42 5D 0D 42 5D 0D 42 5D 0D 42 5D 0D 42

00000B00:5D 0D 41 5C 0C 41 5C 0C 43 5C 0C 43 5C 0C 43 5C

00000B10:0C 45 5B 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C

00000B20:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43

00000B30:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C

00000B40:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 45 5C 0A

00000B50:45 5C 0A 45 5C 0A 45 5C 0A 45 5C 0A 45 5B 0C 00

00000B60:3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F

00000B70:5F 0E 3F 5F 0E 40 5D 0D 3F 5F 0E 3F 5F 0E 41 5E

00000B80:0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D

00000B90:40 5D 0D 40 5D 0D 41 5E 0E 40 5D 0D 40 5D 0D 40

00000BA0:5D 0D 40 5D 0D 41 5E 0E 4B 60 17 A0 AB 83 92 A2

00000BB0:73 AC B6 94 F4 ED E7 E2 CF BE DA CA BA D7 C4 B2

00000BC0:D0 86 58 CA 71 3D C9 69 32 C6 5D 24 C4 54 17 CC

00000BD0:86 5D D5 C5 B2 D2 BC A6 C9 B3 9D C2 AD 96 C1 AC

00000BE0:97 C8 B1 9A D9 C8 B6 D3 C4 B4 D1 C3 B3 DE D1 C4

00000BF0:E0 D3 C5 E3 D5 C6 A3 A4 81 48 5E 13 42 5D 0D 42

00000C00:5D 0D 42 5D 0D 42 5D 0D 42 5D 0D 42 5D 0D 41 5C

00000C10:0C 41 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 45 5B 0C

00000C20:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43

00000C30:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C

00000C40:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C

00000C50:43 5C 0C 43 5C 0C 43 5C 0C 45 5C 0A 45 5C 0A 45

00000C60:5C 0A 45 5C 0A 45 5C 0A 45 5B 0C 00 3F 5F 0E 3F

00000C70:5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F

00000C80:0E 40 5D 0D 3E 5E 0D 3E 5E 0D 40 5D 0D 40 5D 0D

00000C90:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40

00000CA0:5D 0D 41 5E 0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D

00000CB0:0D 41 5E 0E 52 64 1F A4 AF 8A 95 A3 75 B3 AC 84

00000CC0:DC AB 87 D7 A3 7D DB CD BD D2 A1 7F CD 76 42 CB

00000CD0:71 3C C9 69 32 C7 62 2A C5 5B 20 C3 54 19 D8 AD

00000CE0:90 E2 D7 CA D3 BE A9 CA B6 A0 D0 BD AA D1 BD A9

00000CF0:DD CD BD DD D0 C2 D0 C1 B1 DA CD BE DE D1 C3 DB

00000D00:CD BC 91 9A 6E 4E 62 18 42 5D 0D 42 5D 0D 42 5D

00000D10:0D 42 5D 0D 42 5E 0B 41 5C 0C 41 5C 0C 41 5C 0C

00000D20:43 5C 0C 43 5C 0C 43 5C 0C 45 5B 0C 43 5C 0C 43

00000D30:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C

00000D40:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C

00000D50:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43

00000D60:5C 0C 43 5C 0C 45 5C 0A 45 5C 0A 45 5C 0A 45 5C

00000D70:0A 45 5C 0A 45 5B 0C 00 3F 5F 0E 3F 5F 0E 3F 5F

00000D80:0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 40 5D 0D

00000D90:3E 5D 0D 3E 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40

00000DA0:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D

00000DB0:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0E

00000DC0:58 67 26 A4 B1 8B B8 B1 8A D6 9F 74 D5 98 6B D7

00000DD0:A4 7F DD CF BF D2 90 66 CD 77 43 CA 6E 38 C8 65

00000DE0:2C C6 60 27 C6 5B 21 C3 56 1B CB 71 40 DD C8 B6

00000DF0:D5 C3 AF E1 D2 C2 DF D0 C1 D9 C8 B7 E1 D3 C4 E4

00000E00:D8 CA D1 C2 B2 E0 D4 C7 E7 DA CD AD AA 90 6F 7F

00000E10:47 52 63 1F 41 5B 0D 41 5C 0C 41 5C 0C 42 5D 0D

00000E20:42 5D 0B 41 5C 0C 41 5C 0C 41 5B 0C 42 5B 0C 43

00000E30:5B 0C 43 5C 0C 43 5B 0B 43 5C 0C 43 5C 0C 43 5B

00000E40:0C 43 5B 0C 43 5B 0C 43 5C 0C 43 5C 0C 43 5C 0C

00000E50:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43

00000E60:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C

00000E70:0C 44 5C 0A 44 5C 0A 45 5B 0A 45 5B 0A 45 5B 0A

00000E80:45 5B 0B 00 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E

00000E90:3F 5F 0E 3F 5F 0E 3F 5F 0E 40 5D 0D 40 5D 0D 40

00000EA0:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D

00000EB0:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 41 5E 0E

00000EC0:40 5D 0D 40 5D 0D 40 5D 0D 42 5C 0E 60 6E 33 A9

00000ED0:B6 91 CD B0 8B D7 A2 78 D6 99 6D D9 A8 86 E2 D7

00000EE0:CA DE BC A2 CC 78 44 D0 85 57 D2 8B 61 CC 74 42

00000EF0:CC 76 46 CD 7D 4F CC 76 47 CF 9C 7A D8 C9 B7 DF

00000F00:D0 C0 DF CF BF DD CE BE E4 D7 C9 EB E0 D4 D1 C3

00000F10:B3 DC CF C1 F1 E6 DA C8 C0 AE 72 80 4F 56 66 24

00000F20:42 5B 0E 41 5C 0C 41 5C 0C 42 5D 0D 43 5C 0C 43

00000F30:5C 0C 43 5C 0C 43 5B 0D 42 5A 0C 43 5B 0D 43 5C

00000F40:0C 42 5B 0B 43 5C 0C 43 5C 0C 43 5B 0D 43 5B 0D

00000F50:43 5B 0D 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43

00000F60:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C

00000F70:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C

00000F80:43 5C 0C 45 5B 0C 45 5B 0C 45 5B 0C 45 5C 0A 00

00000F90:3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F

00000FA0:5F 0E 3F 5F 0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D

00000FB0:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D

00000FC0:40 5D 0D 40 5D 0D 40 5D 0D 41 5E 0E 40 5D 0D 40

00000FD0:5D 0D 40 5D 0D 43 5C 10 78 82 4C B9 BF 9C D8 AB

00000FE0:84 D6 A3 7A D6 A2 7C DE BE A5 E7 DA CD E8 DA CB

00000FF0:DA AA 89 E7 D9 CC DB AE 91 C7 63 2B C6 5D 24 C4

00001000:56 1B C2 51 15 D1 A2 83 E1 D4 C5 E1 D2 C2 E1 D1

00001010:C2 D1 C0 AD D1 C2 B1 E2 D6 C9 D3 C5 B5 D4 C6 B7

00001020:E2 D6 C8 EA DE D2 95 9A 76 5B 6B 2A 44 5C 0F 41

00001030:5C 0C 41 5C 0C 41 5C 0C 43 5C 0C 43 5C 0C 43 5C

00001040:0C 43 5B 0D 42 5A 0C 43 5B 0D 43 5C 0C 42 5B 0B

00001050:43 5C 0C 43 5C 0C 43 5B 0D 43 5B 0D 43 5B 0D 43

00001060:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C

00001070:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C

00001080:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 45

00001090:5B 0C 45 5B 0C 45 5B 0C 45 5C 0A 00 3F 5F 0E 3F

000010A0:5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F

000010B0:0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D

000010C0:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40

000010D0:5D 0D 40 5D 0D 41 5E 0E 40 5D 0D 40 5D 0D 40 5D

000010E0:0D 47 5E 13 8E 97 67 C4 BF 9F CE A9 81 CA B7 99

000010F0:E4 DA CF DB CC BC E9 DA CC E8 DA CC E9 DB CE E5

00001100:CF BE CB 73 40 C6 5F 26 C6 5C 22 C3 52 15 CA 75

00001110:45 D9 CA B9 E6 D8 CA E3 D5 C6 D1 BF AE C3 AF 9A

00001120:CE BE AD D1 C3 B3 CC BD AD D2 C4 B5 D9 CC BD DD

00001130:CE BF CE C6 B3 6A 78 3A 47 5C 11 41 5C 0C 41 5C

00001140:0C 42 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5B 0D

00001150:42 5A 0C 43 5B 0D 43 5C 0C 42 5B 0B 43 5C 0C 43

00001160:5C 0C 43 5B 0D 43 5B 0D 43 5B 0D 43 5C 0C 43 5C

00001170:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C

00001180:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43

00001190:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 45 5B 0C 45 5B

000011A0:0C 45 5B 0C 45 5C 0A 00 3F 5F 0E 3F 5F 0E 3F 5F

000011B0:0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 40 5D 0D

000011C0:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40

000011D0:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D

000011E0:0D 41 5E 0E 40 5D 0D 40 5D 0D 40 5D 0D 4C 61 17

000011F0:9C A5 7A D1 BF 9E D6 A5 7D E2 BD 9F E3 CF BE DB

00001200:CB BB E9 DA CC E8 D9 CB EA DF D3 DC B0 93 C7 63

00001210:29 C5 5C 22 C5 59 1F C5 5B 21 DD BC A4 DE D2 C4

00001220:E6 D8 CA E8 DA CC CD BB A9 C6 B3 9F CE BD AB CA

00001230:B8 A5 CF BE AC D5 C4 B2 BD B4 9D AB AC 8B B6 BA

00001240:9A 78 86 4D 4A 5E 14 43 5C 0C 43 5C 0C 43 5C 0C

00001250:43 5C 0C 43 5C 0C 43 5C 0C 43 5B 0D 42 5A 0C 43

00001260:5B 0D 43 5C 0C 42 5B 0B 43 5C 0C 43 5C 0C 43 5B

00001270:0D 42 5A 0C 43 5B 0D 43 5C 0C 43 5C 0C 43 5C 0C

00001280:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43

00001290:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C

000012A0:0C 43 5C 0C 43 5C 0C 45 5B 0C 45 5B 0C 45 5B 0C

000012B0:45 5C 0A 00 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E

000012C0:3F 5F 0E 3F 5F 0E 3F 5F 0E 40 5D 0D 40 5D 0D 40

000012D0:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D

000012E0:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 41 5E 0E

000012F0:40 5D 0D 40 5D 0D 40 5D 0D 53 64 1D A2 AA 82 D7

00001300:BC 99 D8 A7 7F DA A8 81 E3 CE BB E1 D2 C3 E8 D9

00001310:CC E8 D9 CB E4 D6 C7 E6 D7 C9 E2 BC A3 D2 84 57

00001320:C5 56 1A D4 9A 76 E6 DE D2 E0 D0 C1 E3 D5 C6 F0

00001330:E4 D7 E1 D2 C3 CA B7 A4 D1 C1 B0 C9 B7 A3 D0 BD

00001340:A9 D8 C6 B2 B5 AC 92 7B 89 53 75 89 4D 70 82 46

00001350:53 61 1C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43

00001360:5C 0C 43 5C 0C 43 5B 0D 42 5A 0C 43 5B 0D 43 5C

00001370:0C 42 5B 0B 43 5C 0C 43 5C 0C 43 5B 0D 42 5A 0C

00001380:42 5A 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43

00001390:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C

000013A0:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C

000013B0:43 5C 0C 45 5B 0C 45 5B 0C 45 5B 0C 45 5C 0A 00

000013C0:3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F

000013D0:5F 0E 3F 5F 0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D

000013E0:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D

000013F0:40 5D 0D 40 5D 0D 40 5D 0D 41 5E 0E 40 5D 0D 40

00001400:5D 0D 41 5D 0E 59 67 24 A9 B2 8C D1 BB 98 D7 A5

00001410:7C D4 B0 8D DE D4 C5 DA CA BB DE D1 C5 DB D0 C3

00001420:DC CE BF E4 D5 C5 EC E2 D7 F0 E5 D9 E4 C4 AE D7

00001430:C8 B9 D4 C7 BA D8 C9 BB E0 D2 C4 E9 DD D0 E3 D4

00001440:C6 CF BD AB D2 C3 B3 C2 B2 A1 C6 B6 A3 CD BA A7

00001450:CD BD A7 8B 97 65 7D 8E 55 74 85 49 5A 66 21 44

00001460:5C 0E 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C

00001470:0C 43 5B 0D 42 5A 0C 43 5B 0D 43 5C 0C 42 5B 0B

00001480:43 5C 0C 43 5C 0C 43 5B 0D 42 5A 0C 42 5A 0C 42

00001490:5B 0B 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C

000014A0:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C

000014B0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 45

000014C0:5B 0C 45 5B 0C 45 5B 0C 45 5C 0A 00 3F 5F 0E 3F

000014D0:5F 0E 3F 5F 0C 3F 5F 0C 3F 5F 0C 3F 5F 0E 40 5E

000014E0:0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D

000014F0:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40

00001500:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 43 5D

00001510:0F 69 71 33 B3 BC 99 CD BA 96 D6 A4 79 A2 9B 72

00001520:B3 AE 91 DE D0 C2 D9 C2 AF CE 9D 7C CF 8E 64 CE

00001530:7D 4C D6 AB 8D DD D4 C9 DB D1 C6 DB CF C2 D8 CA

00001540:BC CF C1 B2 D1 C4 B6 DB CF C3 D6 C8 BB C6 B6 A5

00001550:CF C2 B4 D4 C8 BC A1 9B 81 69 6C 3C 60 63 2E 6C

00001560:77 41 7A 88 54 74 83 4B 60 6C 27 45 5C 0E 43 5C

00001570:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5B 0D

00001580:42 5A 0C 43 5B 0D 43 5C 0C 42 5B 0B 43 5C 0C 43

00001590:5C 0C 43 5B 0D 44 5A 0C 44 5A 0C 44 5B 0B 43 5C

000015A0:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C

000015B0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43

000015C0:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5B 0C 43 5B 

000015D0:0C 45 5B 0C 43 5C 0A 00 3F 5F 0E 3F 5F 0E 3F 60 

000015E0:0C 3F 60 0C 3F 60 0C 3F 5F 0E 41 5E 0E 40 5D 0D 

000015F0:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 

00001600:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 

00001610:0D 40 5D 0D 40 5D 0D 40 5D 0D 45 5E 10 7D 82 48 

00001620:BE C5 A4 B9 B0 8A BA B2 93 D1 C9 B6 DB AC 89 E6 

00001630:CC B7 E8 D2 C0 D1 85 55 CC 75 41 CA 6C 36 C6 6E 

00001640:3B B5 A4 8E D2 C6 B8 E7 D8 C9 E5 D6 C7 E0 D1 C2 

00001650:DA CC BD DB CD C0 D3 C6 B7 BE AF A0 D0 C3 B5 E9 

00001660:DE D2 EA E2 D6 C3 BE A9 8B 89 64 61 66 34 65 6D 

00001670:3E 68 76 45 63 6C 2D 47 5D 0F 43 5C 0C 43 5C 0C 

00001680:43 5C 0C 43 5C 0C 43 5C 0C 43 5B 0D 42 5A 0C 43

00001690:5B 0D 43 5C 0C 42 5B 0B 43 5C 0C 43 5C 0C 43 5B 

000016A0:0D 45 5B 0D 45 5B 0C 45 5B 0C 43 5C 0C 42 5B 0B 

000016B0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 

000016C0:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 

000016D0:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 45 5B 0C

000016E0:43 5D 0A 00 3F 5F 0E 3F 5F 0E 3F 60 0C 3F 60 0C

000016F0:3F 60 0C 3F 5F 0E 41 5E 0E 40 5D 0D 40 5D 0D 40

00001700:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 

00001710:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 

00001720:40 5D 0D 40 5D 0D 47 5E 12 91 93 61 BC C2 A1 C3 

00001730:C4 AB E8 E0 D4 DF B4 93 D4 96 68 DE B2 93 E0 BB 

00001740:A0 CF 81 50 CD 7A 48 CB 71 3C C8 63 2A D3 9A 75

00001750:E1 D5 C7 DB CB BB D8 C7 B7 D7 C6 B5 D8 C7 B6 D8 

00001760:C7 B6 D3 C1 AF C5 B2 9E DB CD BE E9 DE D3 EF E5 

00001770:DB F6 EE E4 FA F0 E7 E3 D8 CA BB B0 9A A1 9D 83 

00001780:71 74 3B 4A 5E 12 43 5C 0C 43 5C 0C 43 5C 0C 43 

00001790:5C 0C 43 5C 0C 43 5B 0D 42 5A 0C 43 5B 0D 43 5C 

000017A0:0C 42 5B 0B 43 5B 0C 43 5B 0C 43 5C 0C 45 5B 0C 

000017B0:44 5A 0B 44 5A 0B 42 5B 0B 42 5B 0B 43 5C 0C 43 

000017C0:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 

000017D0:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 

000017E0:43 5C 0C 43 5C 0C 43 5C 0C 45 5B 0C 43 5C 0A 00 

000017F0:3F 5F 0E 3F 5F 0E 3F 60 0C 3F 60 0C 3F 60 0C 3F 

00001800:5F 0E 41 5E 0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 

00001810:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 

00001820:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 

00001830:5D 0D 4E 60 17 9B 9C 6F BB C2 9E D7 D5 C2 E0 C0 

00001840:A6 D7 A0 76 D6 9C 72 D8 A1 7A D4 95 6A D0 82 51 

00001850:CD 7A 47 CA 6D 38 D7 A7 88 DB BF AA D9 C9 B8 D3 

00001860:C3 B2 D0 BF AC D0 BE AC D1 C0 AE CF BD AA C6 B3 

00001870:9F D1 BF AD E2 D5 C7 E6 DC D0 EA DF D4 E9 DE D3 

00001880:E4 D8 CC DC CE C0 D1 C0 AF CC BD AA 73 79 3E 50 

00001890:5F 17 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 

000018A0:0C 43 5B 0D 42 5A 0C 43 5B 0D 43 5C 0C 42 5B 0B

000018B0:43 5B 0D 43 5B 0D 43 5C 0C 45 5B 0C 44 5A 0B 44 

000018C0:5A 0B 42 5B 0B 42 5B 0B 43 5C 0C 43 5C 0C 43 5C 

000018D0:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 

000018E0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 

000018F0:5C 0C 43 5C 0C 45 5B 0C 45 5C 0A 00 3F 5F 0E 3F 

00001900:5F 0E 3F 60 0C 3F 60 0C 3F 60 0C 3F 5F 0E 41 5E 

00001910:0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 

00001920:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 

00001930:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 57 64 

00001940:1E A5 A5 7C B8 BE 9B D4 D1 BF E2 C5 AD D8 A2 78 

00001950:D7 9E 74 D8 A4 7E D2 8C 5E D0 83 53 CC 74 40 D1 

00001960:8D 62 DE D0 C2 DC CE C0 D4 C2 B1 CF BD AB D1 BF 

00001970:AD D4 C3 B2 D4 C3 B1 CF BE AB D1 BF AD DC CC BC 

00001980:DE D0 C3 DF D3 C6 DD D0 C3 DC CF C1 DF D3 C5 DA 

00001990:CC BF D3 C5 B6 90 8D 58 60 6D 27 56 64 1E 43 5C 

000019A0:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5B 0D 

000019B0:42 5A 0C 43 5B 0D 43 5C 0C 42 5B 0B 43 5B 0D 43 

000019C0:5B 0D 43 5C 0C 44 5A 0B 44 5A 0B 44 5A 0B 42 5B 

000019D0:0B 42 5B 0B 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 

000019E0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 

000019F0:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 

00001A00:0C 45 5B 0C 45 5C 0A 00 3F 5F 0E 3F 5F 0E 3F 60 

00001A10:0C 3F 60 0C 3F 60 0C 3F 5F 0E 41 5E 0E 40 5D 0D 

00001A20:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 

00001A30:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 

00001A40:0D 40 5D 0D 40 5D 0D 40 5D 0D 62 6B 26 B0 B1 8C 

00001A50:BB BE A0 E3 DD D0 E8 D7 C8 D8 A2 7A D7 A4 7D D5 

00001A60:9C 74 D1 87 57 CE 7C 4A D0 88 5C D7 C2 AF D4 C5 

00001A70:B5 D5 C4 B2 D9 C9 B8 DD CD BD DC CC BC DA C9 B9 

00001A80:D7 C6 B6 D7 C6 B5 DF D0 C0 D7 C7 B6 D7 C8 B9 D5 

00001A90:C7 B9 D9 CB BD E5 DA CD E4 D9 CC E0 D3 C6 D7 CD 

00001AA0:BD 7C 84 48 5B 6A 1F 5C 67 21 43 5C 0C 43 5C 0C 

00001AB0:43 5C 0C 43 5C 0C 43 5C 0C 43 5B 0D 42 5A 0C 43 

00001AC0:5B 0D 43 5C 0C 42 5B 0B 43 5B 0D 42 5A 0C 42 5B 

00001AD0:0B 44 5A 0B 44 5A 0B 44 5A 0B 42 5B 0B 42 5B 0B 

00001AE0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 

00001AF0:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 

00001B00:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 45 5B 0C 

00001B10:45 5C 0A 00 3F 5F 0E 3F 5F 0E 3F 60 0C 3F 60 0C 

00001B20:3F 60 0C 3F 5F 0E 41 5E 0E 40 5D 0D 40 5D 0D 40 

00001B30:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 

00001B40:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 

00001B50:40 5D 0D 41 5D 0D 6D 73 32 B9 BA 9B D6 D1 BF EC 

00001B60:E3 DA EE E7 DF E1 C0 A5 D7 AB 88 D7 A3 7E DA A7 

00001B70:84 DD B1 94 D9 C4 B1 D4 C5 B4 DB CB BB E9 DB CD 

00001B80:E9 DB CE E3 D5 C6 DE CF BF DC CD BC DF CF C0 E1 

00001B90:D1 C2 DF CF C0 DA CA B9 D6 C7 B8 D5 C7 B9 E8 DC 

00001BA0:D1 E8 DC D1 E4 D8 CC E5 D9 CC B2 AD 93 7D 89 53 

00001BB0:6A 77 32 60 6A 24 44 5C 0C 43 5C 0C 43 5C 0C 43 

00001BC0:5C 0C 43 5C 0C 43 5B 0D 42 5A 0C 43 5B 0D 43 5C 

00001BD0:0C 42 5B 0B 42 5A 0C 42 5A 0C 42 5B 0B 44 5A 0B 

00001BE0:44 5A 0B 44 5A 0B 42 5B 0B 42 5B 0B 43 5C 0C 43 

00001BF0:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 

00001C00:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 

00001C10:43 5C 0C 43 5C 0C 43 5C 0C 45 5B 0C 45 5C 0A 00

00001C20:40 5D 0D 41 5E 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 

00001C30:5F 0E 41 5E 0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 

00001C40:0D 41 5E 0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D

00001C50:41 5E 0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 41 

00001C60:5E 0F 77 79 3C CC CA B4 EB E2 D9 ED E4 DB EF E7 

00001C70:E0 EF E7 DE DE CC BB DD CD BC E8 DB CD E9 DC CF 

00001C80:DC CD BD E5 D6 C7 F1 E4 D8 F0 E3 D6 EA DC CE E5 

00001C90:D6 C7 E1 D2 C2 DF CF C0 DF CF C0 DD CD BD D9 C8 

00001CA0:B8 D7 C6 B5 E0 D3 C6 E6 DB CF EB E0 D5 E1 D5 C8 

00001CB0:DF D3 C7 E4 D8 CB A7 A3 88 77 82 4F 77 86 4B 6B 

00001CC0:71 30 44 5D 0E 41 5C 0C 43 5C 0C 43 5C 0C 43 5C 

00001CD0:0C 43 5C 0C 43 5C 0C 43 5B 0D 43 5B 0D 43 5B 0D 

00001CE0:42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 44 5A 0B 44 

00001CF0:5A 0B 42 5B 0B 42 5B 0B 44 5A 0B 43 5C 0C 43 5C 

00001D00:0C 43 5D 0A 43 5D 0A 43 5D 0A 43 5C 0C 43 5C 0C 

00001D10:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 

00001D20:5C 0C 43 5C 0C 42 5B 0B 44 5B 09 00 40 5D 0D 41 

00001D30:5E 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 41 5E 

00001D40:0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 41 5E 0E 

00001D50:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 

00001D60:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 47 5F 13 80 7F 

00001D70:46 DE DA C9 EF E6 DD EE E5 DD F0 E8 E0 F1 E8 E0 

00001D80:E2 D2 C3 DE CD BD E3 D3 C3 E3 D4 C5 E2 D3 C5 E6 

00001D90:D9 CA E5 D7 C9 E7 DA CB E9 DA CC E5 D6 C8 E2 D3 

00001DA0:C4 E0 D1 C2 DA CA B9 D3 C2 B1 CF BD AA CC B9 A6 

00001DB0:D6 C7 B8 E1 D5 C9 E7 DB CF DF D3 C6 E0 D3 C7 DE 

00001DC0:D1 C5 D4 C9 B9 7F 85 5B 75 83 4A 74 78 3A 4A 5F 

00001DD0:14 41 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 

00001DE0:42 5B 0B 42 5B 0C 42 5B 0C 43 5B 0C 42 5B 0B 42 

00001DF0:5B 0B 42 5B 0B 42 5B 0B 43 5A 0B 43 5A 0B 42 5B 

00001E00:0B 42 5B 0B 44 5A 0B 43 5C 0C 43 5C 0C 43 5D 0A

00001E10:43 5D 0A 43 5D 0A 43 5C 0C 43 5C 0C 43 5C 0C 43

00001E20:5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 

00001E30:0C 42 5B 0B 44 5B 09 00 40 5D 0D 41 5E 0E 3F 5F 

00001E40:0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 41 5E 0E 40 5D 0D

00001E50:40 5D 0D 40 5D 0D 40 5D 0D 41 5E 0E 40 5D 0D 40 

00001E60:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 

00001E70:0D 40 5D 0D 40 5D 0D 4B 61 15 8E 8B 57 CF CE B6 

00001E80:EA E2 D6 F0 E7 DF F1 E9 E1 F1 E8 E0 E4 D5 C5 E1 

00001E90:D1 C0 E0 D0 C0 E0 D0 C2 E4 D5 C6 E3 D4 C5 E3 D4 

00001EA0:C5 E5 D6 C8 E8 DB CD EB DD D0 EB DD CF E8 DA CC 

00001EB0:E0 D1 C2 D7 C6 B5 CE BB A9 C9 B5 A2 D3 C4 B5 D3 

00001EC0:C4 B6 DA CD BF E1 D5 C9 E3 D7 CB DD D1 C4 EA DF 

00001ED0:D4 B7 B4 9C 77 85 4D 76 7D 3E 4F 61 17 41 5C 0C 

00001EE0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 42 5B 0B 42 

00001EF0:5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 

00001F00:0B 42 5B 0B 42 5B 0B 42 5B 0B 43 5A 0B 43 5A 0B

00001F10:44 5A 0B 43 5C 0C 43 5C 0C 43 5D 0A 43 5D 0A 43 

00001F20:5D 0A 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 

00001F30:0C 43 5C 0C 43 5C 0C 43 5C 0C 42 5B 0B 43 5A 0B 

00001F40:44 5B 09 00 40 5D 0D 40 5D 0D 3F 5F 0E 3F 5F 0E 

00001F50:3F 5F 0E 3F 5F 0E 40 5D 0D 40 5D 0D 40 5D 0D 40 

00001F60:5D 0D 40 5D 0D 41 5E 0E 40 5D 0D 40 5D 0D 40 5D 

00001F70:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 

00001F80:40 5D 0D 50 63 1A A3 9F 71 CA C9 B1 E0 D9 CB F1 

00001F90:E8 E0 F2 EA E2 F2 E9 E0 E7 D8 C8 E4 D4 C4 E1 D0 

00001FA0:C1 E4 D5 C6 DD CD BD D7 C6 B6 DE CF BF E5 D6 C8 

00001FB0:EB DE D0 F0 E3 D6 F1 E5 D8 F0 E3 D6 ED DF D3 E9 

00001FC0:DB CD E8 DA CC E3 D4 C5 E3 D7 CA E4 D8 CC D9 CB 

00001FD0:BD D9 CB BD E0 D3 C7 DF D3 C6 E7 DC D0 E1 D8 C8 

00001FE0:80 8D 56 7A 82 45 55 64 1B 41 5C 0C 43 5C 0C 43 

00001FF0:5C 0C 43 5C 0C 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 

00002000:0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 

00002010:42 5B 0B 42 5B 0B 44 5A 0B 44 5A 0B 44 5A 0B 43 

00002020:5C 0C 43 5C 0C 43 5D 0A 43 5D 0A 43 5D 0A 43 5C 

00002030:0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C

00002040:43 5C 0C 43 5C 0C 43 5A 0B 44 5A 0B 44 5B 09 00

00002050:40 5D 0D 40 5D 0D 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F

00002060:5F 0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 

00002070:0D 41 5E 0E 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 

00002080:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 58 

00002090:67 20 B2 AF 88 D8 D4 C5 F0 E7 DE F1 E9 E1 F3 EC 

000020A0:E4 F3 E9 E1 E9 DA CB E6 D6 C7 E4 D4 C4 E6 D8 C9 

000020B0:DF D0 C0 D5 C4 B3 DB CB BA E5 D7 C9 EB DD D0 EF 

000020C0:E2 D5 F1 E4 D8 F0 E4 D7 ED DF D2 EE E1 D4 E6 D8 

000020D0:C9 C1 AE 98 CA B9 A8 E8 DC D1 EC E1 D7 E7 DC D0 

000020E0:DD D0 C3 D4 C6 B7 D8 CB BC AE AC 8B 79 87 4D 7B 

000020F0:84 4A 5C 67 20 41 5C 0C 43 5C 0C 43 5C 0C 43 5C 

00002100:0C 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 

00002110:42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 

00002120:5B 0B 44 5A 0B 44 5A 0B 44 5A 0B 43 5C 0C 43 5C 

00002130:0C 43 5D 0A 43 5D 0A 43 5D 0A 43 5C 0C 43 5C 0C 

00002140:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 42 

00002150:5B 0B 44 5A 0B 44 5A 0B 44 5B 09 00 40 5D 0D 40 

00002160:5D 0D 3F 5F 0E 3F 5F 0E 3F 5F 0E 3F 5F 0E 40 5D 

00002170:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 41 5E 0E

00002180:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 

00002190:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 64 6C 29 C3 BD

000021A0:A0 F4 EC E3 F2 E9 E0 F3 EA E2 F5 EE E6 F3 EA E1 

000021B0:EB DC CD E8 D9 CA E5 D5 C6 E4 D4 C5 E3 D3 C3 D9 

000021C0:C8 B8 D3 C1 AF DC CC BC EB DD D0 EF E2 D6 F2 E5 

000021D0:DA F2 E5 D9 F4 E7 DB EA DC CE C7 B3 A0 B7 A2 8B 

000021E0:D1 C2 B3 EB E0 D6 E6 DA CF EA E0 D5 EF E4 DB E8 

000021F0:DC D1 D0 C5 B4 8A 8F 63 7C 8B 51 79 85 4A 64 69 

00002200:27 41 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 42 5B 0B 

00002210:42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 

00002220:5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 44 5A 

00002230:0B 44 5A 0B 44 5A 0B 43 5C 0C 43 5C 0C 43 5D 0A 

00002240:43 5D 0A 43 5D 0A 43 5C 0C 43 5C 0C 43 5C 0C 43 

00002250:5C 0C 43 5C 0C 43 5C 0C 42 5B 0B 44 5A 0B 44 5A 

00002260:0B 44 5A 0B 44 5B 09 00 40 5D 0D 40 5D 0D 3F 5E 

00002270:0D 3F 5E 0D 3F 5E 0D 3F 5E 0D 40 5D 0D 40 5D 0D 

00002280:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 

00002290:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 

000022A0:0D 3F 5C 0C 40 5C 0D 72 74 35 CC C5 AC F4 EC E4 

000022B0:F1 E9 E0 F6 EE E6 F5 EE E6 F2 E9 DE ED DE CF EB 

000022C0:DC CE E3 D3 C3 D8 C7 B4 DB CB BA DF D0 BF D9 C8 

000022D0:B7 D9 C8 B7 ED DE D0 F4 E6 D9 F9 ED E0 FD F0 E4 

000022E0:FF F3 E7 E0 CF BD CA B6 A1 C7 B3 9D F3 E7 DC F4 

000022F0:EA E0 E7 DD D0 E7 DC D0 E8 DD D2 EF E5 DB F0 E7 

00002300:DD A5 A6 81 7C 8A 50 76 83 47 6F 71 31 43 5C 0E 

00002310:43 5C 0C 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 

00002320:5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 

00002330:0B 42 5B 0B 42 5B 0B 42 5B 0B 44 5A 0B 44 5A 0B 

00002340:43 5A 0B 42 5B 0B 42 5B 0B 43 5C 0A 43 5C 0A 43 

00002350:5C 0A 43 5C 0C 43 5C 0C 43 5C 0B 43 5C 0B 43 5C 

00002360:0C 43 5B 0C 42 5A 0A 43 59 0A 44 5A 0B 44 5A 0B 

00002370:43 5B 09 00 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 

00002380:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 

00002390:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 

000023A0:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 3F 5C 0C 

000023B0:43 5E 0F 80 7E 41 D3 CD BA F2 E9 E0 F4 EB E2 F4 

000023C0:EA E1 F0 E8 DF E5 D9 CD DD CE BE E4 D5 C7 DC CD 

000023D0:BF D9 CA BB D9 CA BB DA CC BD D2 C4 B6 CC BF B2 

000023E0:CC C1 B5 C8 BD B2 C3 B9 AF C0 B6 AB BA AE A2 AA 

000023F0:9A 8B A6 95 84 BB AD 9E D7 CE C5 D5 CA BF D3 C6 

00002400:B9 DC CF C1 E5 D7 C9 EB DF D2 E6 DC CF 8D 92 67 

00002410:7A 87 4D 73 82 45 79 79 39 49 5E 11 43 5C 0C 42 

00002420:5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 

00002430:0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 

00002440:42 5B 0B 42 5B 0B 44 5A 0B 44 5A 0B 42 5B 0B 42

00002450:5B 0B 42 5B 0B 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 

00002460:0C 43 5C 0C 43 5D 0A 43 5D 0A 43 5C 0C 44 5A 0B 

00002470:43 59 0A 43 59 0A 44 5A 0B 44 5A 0B 42 5C 09 00 

00002480:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 

00002490:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 

000024A0:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 

000024B0:40 5D 0D 40 5D 0D 40 5D 0D 3F 5C 0C 45 5F 11 90 

000024C0:8A 4F EA E1 D5 E8 DF D7 E7 DF D6 E7 E1 DA E5 E0 

000024D0:DB E6 E3 DF EA E8 E5 F0 EE ED F2 F2 F1 F1 F1 F1 

000024E0:F0 F0 F0 EB EB EB E3 E4 E4 D7 D7 D8 C2 C3 C4 A8 

000024F0:A9 AA 8B 8B 8C 6C 6C 6D 53 54 55 45 45 46 3E 3F 

00002500:3F 3B 3B 3B 3C 3B 3A 41 40 3F 4A 48 46 5B 57 54 

00002510:78 72 6C 9C 94 8B B4 AB A2 A2 9F 86 95 9C 6F 7A 

00002520:8A 4F 7B 7D 3D 4B 5F 13 43 5C 0C 42 5B 0B 42 5B 

00002530:0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 

00002540:42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42

00002550:5B 0B 44 5A 0B 44 5A 0B 42 5B 0B 42 5B 0B 42 5B 

00002560:0B 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C

00002570:43 5D 0A 43 5D 0A 43 5C 0C 44 5A 0B 43 59 0A 43 

00002580:59 0A 44 5A 0B 44 5A 0B 42 5C 09 00 40 5D 0D 40

00002590:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 

000025A0:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 

000025B0:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 

000025C0:5D 0D 40 5D 0D 3F 5C 0C 52 64 1D A1 92 80 C5 C5

000025D0:C4 D2 D2 D2 E1 E2 E3 EB EC ED F2 F2 F3 F5 F5 F5 

000025E0:F7 F7 F6 F6 F6 F6 F5 F4 F3 F4 F3 F1 F1 EF EE F1 

000025F0:EF ED ED EC EA E7 E5 E3 DF DE DC D2 D1 D0 C4 C2 

00002600:C0 B7 B5 B2 AB A9 A6 A0 9D 9B 93 90 8D 89 88 87 

00002610:7E 7E 7F 72 72 71 6B 6A 6A 69 69 6A 69 6A 6B 6F 

00002620:71 73 83 86 89 A2 A3 A5 BB BA BA C4 C7 BF AE A4 

00002630:81 55 64 1C 43 5C 0C 42 5B 0B 42 5B 0B 42 5B 0B 

00002640:42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 

00002650:5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 44 5A 

00002660:0B 44 5A 0B 42 5B 0B 42 5B 0B 42 5B 0B 43 5C 0C 

00002670:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5D 0A 43 

00002680:5D 0A 43 5C 0C 44 5A 0B 44 5A 0B 43 59 0A 43 59 

00002690:0A 44 5A 0B 42 5C 09 00 40 5D 0D 40 5D 0D 40 5D 

000026A0:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 

000026B0:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 

000026C0:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 

000026D0:0D 3F 5C 0C 75 82 5E 9E A0 A2 C6 C7 C8 DE DE DE 

000026E0:EA E9 E8 F2 F1 F0 F5 F3 F0 F5 F3 F0 F1 ED E9 EB 

000026F0:E6 E0 E9 E3 DD E6 E1 DA E0 DB D6 E9 E5 DD F6 F4 

00002700:F3 E9 E5 E1 E4 DF DA DC D7 D0 D2 CA C1 D4 CC C4 

00002710:DB D4 CC E2 DC D5 D4 CC C3 CF C7 BC F3 EF EB DF 

00002720:D9 D2 D9 D2 CB DC D7 D1 DB D8 D4 C9 C4 B8 B8 AF

00002730:96 C3 BF B7 D0 D0 D0 D0 D1 D2 CF D1 D3 86 8F 6D 

00002740:43 5C 0C 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 

00002750:5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 

00002760:0B 42 5B 0B 42 5B 0B 42 5B 0B 44 5A 0B 44 5A 0B 

00002770:42 5B 0B 42 5B 0B 42 5B 0B 43 5C 0C 43 5C 0C 43 

00002780:5C 0C 43 5C 0C 43 5C 0C 43 5D 0A 43 5D 0A 44 5A 

00002790:0B 44 5A 0B 44 5A 0B 43 59 0A 43 59 0A 44 5A 0B 

000027A0:42 5C 09 00 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 

000027B0:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 

000027C0:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 

000027D0:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 3F 5C 0C 

000027E0:89 91 7B AD AC AC AD A4 84 A2 97 5E A7 9B 5F EE 

000027F0:E9 DA FC FC FC F8 F6 F4 EE E9 E4 E5 DE D7 E6 E1 

00002800:DB E4 E0 DB B8 AA 7D B7 AD 7C FF FF FF F2 F2 F2

00002810:E5 E1 DD DE D9 D3 D6 CF C8 DB D6 D0 DB D6 D0 D9 

00002820:D3 CD D1 CA C2 BE B4 A8 BA AF A3 C6 BD B3 CE C6 

00002830:BE D1 CD C7 C5 B8 99 9A 8F 4D 91 88 43 9A 90 4E 

00002840:A5 99 61 B2 A9 8B CB CB CC 9D A4 90 43 5C 0C 42 

00002850:5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 

00002860:0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 

00002870:42 5B 0B 42 5B 0B 44 5A 0B 44 5A 0B 42 5B 0B 42 

00002880:5B 0B 42 5B 0B 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 

00002890:0C 43 5C 0C 43 5D 0A 43 5D 0A 44 5A 0B 44 5A 0B 

000028A0:43 59 0A 43 59 0A 43 59 0A 44 5A 0B 42 5C 09 00 

000028B0:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 

000028C0:5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 

000028D0:0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 

000028E0:40 5D 0D 40 5D 0D 40 5D 0D 3F 5C 0C 90 99 7F 7D 

000028F0:7C 7C 73 70 69 83 7D 64 93 88 5F A6 9C 78 EA E8 

00002900:E4 FB F9 F7 E7 E1 DA E1 D9 D1 D9 D0 BF AB 9F 68 

00002910:8D 84 3E 99 8F 4C C8 BB 90 E6 E0 CA F3 F0 EB E9 

00002920:E5 E1 E0 DA D4 E6 E2 DE DD D7 D2 CE C7 BF DF DA 

00002930:D5 E1 DC D7 D5 CE C6 D6 CF C7 CC C3 B4 BC B1 99 

00002940:96 8A 54 8C 80 47 90 84 56 8E 83 5D 89 82 6C 9A 

00002950:97 91 B2 B2 B3 92 9B 80 43 5C 0C 42 5B 0B 42 5B 

00002960:0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 

00002970:42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 

00002980:5B 0B 44 5A 0B 44 5A 0B 42 5B 0B 42 5B 0B 42 5B 

00002990:0B 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 

000029A0:43 5D 0A 42 5C 09 44 5A 0B 44 5A 0B 43 59 0A 43

000029B0:59 0A 44 5A 0B 44 5A 0B 42 5C 09 00 40 5D 0B 40 

000029C0:5D 0B 40 5E 0C 40 5E 0C 40 5E 0C 40 5E 0C 40 5E 

000029D0:0C 40 5D 0B 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 

000029E0:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 

000029F0:5D 0D 40 5D 0D 3F 5C 0C 49 63 1A 85 94 6B A3 A7 

00002A00:9E 9F A1 A3 9E A1 A5 A3 A4 A6 B9 B8 B7 EA E7 E5 

00002A10:DF D6 CD CE C8 C2 B6 B0 A3 A8 9F 81 A7 9F 81 A2 

00002A20:98 77 9A 8F 66 9A 91 6B A2 9B 84 B5 B4 AB D4 D1 

00002A30:CD DE D9 D3 DE D8 D1 D0 C9 C1 D0 CA C4 DF DD DC 

00002A40:E4 E1 DE CB C8 C6 7E 7A 71 57 52 49 56 53 50 5B 

00002A50:5C 5E 6E 71 74 86 88 8B A0 A1 A3 A6 AB A0 82 8F 

00002A60:66 4C 63 18 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 

00002A70:42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 

00002A80:5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 44 5A 

00002A90:0B 44 5A 0B 42 5B 0B 42 5B 0B 42 5B 0B 43 5C 0C 

00002AA0:43 5C 0C 43 5C 0C 43 5C 0C 43 5C 0C 43 5B 09 43 

00002AB0:5B 09 44 5A 09 44 5A 0B 43 59 0A 43 59 0A 43 59 

00002AC0:0A 43 59 0A 43 5A 0A 00 40 5D 0D 40 5E 0E 41 5E 

00002AD0:0E 41 5E 0E 41 5E 0E 41 5E 0E 40 5D 0D 40 5D 0D 

00002AE0:40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 40 5D 0D 3F 

00002AF0:5C 0C 3F 5C 0C 3F 5C 0C 3F 5C 0C 40 5D 0D 40 5D

00002B00:0D 40 5D 0D 3F 5C 0C 3F 5C 0C 44 60 13 58 70 2E 

00002B10:73 85 53 84 92 6B 8F 99 7C A6 AC 9A B7 B8 AE B9 

00002B20:B9 B8 BB BD BE BA BD BF B8 BB BD B5 B8 BB B0 B3 

00002B30:B6 A9 AB AD 9D 9E 9F 8F 8F 90 86 86 86 87 86 86 

00002B40:B5 B1 AD DE D8 D1 BB B5 AF 6C 6C 6C 79 79 79 6F

00002B50:6F 6F 71 72 71 7A 7C 76 7D 83 73 7C 86 68 7B 86

00002B60:60 6F 7E 4D 57 6B 2A 46 5E 11 43 5C 0C 43 5D 0A 

00002B70:42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42

00002B80:5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5B 

00002B90:0B 42 5B 0B 42 5B 0B 42 5B 0B 42 5A 0B 42 5A 0B 

00002BA0:42 5B 0B 42 5B 0B 42 5B 0B 42 5B 0B 43 5C 0C 43 

00002BB0:5C 0A 43 5C 0A 43 5C 0A 44 5B 09 44 5A 0A 44 5A 

00002BC0:0A 44 5A 0B 44 5A 0B 43 59 0A 43 59 0A 43 59 0A 

00002BD0:44 5A 0B 00 3E 5E 0D 3F 5D 0D 3F 5D 0D 40 5E 0E 

00002BE0:41 5E 0E 40 5D 0D 40 5D 0D 3F 5C 0C 40 5D 0C 40 

00002BF0:5D 0C 40 5D 0C 40 5D 0C 3F 5C 0B 3F 5C 0B 3F 5C 

00002C00:0B 3F 5C 0B 40 5D 0D 40 5D 0D 40 5D 0D 3F 5C 0C 

00002C10:3F 5C 0C 3F 5C 0C 40 5D 0D 40 5D 0D 40 5D 0D 40 

00002C20:5D 0D 40 5D 0D 41 5C 0C 48 62 16 52 69 23 58 6E 

00002C30:2D 5D 72 34 61 75 3A 64 77 3F 67 79 42 68 7A 44 

00002C40:69 7B 46 69 7A 46 68 78 44 66 77 42 64 75 40 8C 

00002C50:96 6D C0 BE B0 51 62 2B 57 6B 2D 58 6D 2C 51 67 

00002C60:22 49 60 15 41 5B 0B 41 5B 0B 41 5B 0B 41 5B 0B 

00002C70:41 5B 0B 40 5B 0B 40 5B 0B 40 5C 09 42 5B 0A 42 

00002C80:5B 0A 42 5B 0A 42 5B 0A 42 5B 0A 42 5B 0A 42 5B 

00002C90:0A 41 5A 0A 42 5A 0C 42 5A 0C 42 5A 0C 42 5B 0B 

00002CA0:42 5B 0B 42 5B 0B 42 5B 0A 42 5B 0A 44 5A 0B 44 

00002CB0:5A 0B 44 5A 0A 44 5A 0A 44 5A 0A 45 5B 0B 45 5B 

00002CC0:0B 45 5B 0B 44 5A 09 44 5A 09 44 5A 0B 44 5A 0B 

00002CD0:44 5A 0B 44 5A 0B 43 59 0A 43 59 0A 43 5B 09 00 

00002CE0:3F 5F 0D 3F 5F 0D 3F 5F 0D 3F 5F 0D 40 5E 0D 40 

00002CF0:5E 0D 40 5E 0D 40 5E 0D 40 5F 0C 40 5F 0C 40 5F 

00002D00:0C 40 5F 0C 3F 5E 0B 3F 5E 0B 40 5E 0B 40 5E 0B 

00002D10:40 5D 0C 40 5D 0C 40 5D 0C 40 5D 0C 40 5D 0C 40 

00002D20:5D 0C 40 5D 0C 40 5D 0C 40 5D 0C 40 5D 0C 40 5D 

00002D30:0C 41 5D 0C 41 5C 0B 41 5C 0B 41 5C 0B 41 5C 0B 

00002D40:41 5D 0C 41 5D 0C 41 5D 0C 40 5C 0B 40 5C 0B 40 

00002D50:5C 0B 40 5C 0B 40 5C 0C 41 5C 0C 41 5C 0C 5A 70 

00002D60:2B 41 5C 0C 41 5C 0C 41 5C 0C 41 5C 0C 41 5C 0C 

00002D70:41 5C 0B 41 5C 0B 41 5C 0B 41 5C 0B 41 5C 0B 41 

00002D80:5C 0B 41 5C 0B 41 5D 0B 42 5D 0A 42 5D 0A 42 5D 

00002D90:0A 42 5D 0A 42 5D 0A 42 5D 0A 42 5D 0A 42 5D 0A 

00002DA0:42 5C 0B 42 5C 0B 42 5C 0B 42 5C 0B 42 5C 0B 43 

00002DB0:5C 0B 43 5D 0A 43 5D 0A 44 5C 0B 44 5C 0B 44 5C 

00002DC0:0A 44 5C 0A 44 5C 0A 44 5C 0A 44 5C 0A 44 5C 0A 

00002DD0:43 5B 0A 43 5B 0A 43 5B 0A 43 5B 0A 43 5B 0A 43 

00002DE0:5B 0A 43 5B 0A 43 5B 0A 43 5D 09 00 3F 61 0C 40 

00002DF0:62 0D 40 62 0D 3F 61 0C 3F 61 0C 3F 61 0C 3F 61 

00002E00:0C 3F 61 0C 3F 61 0C 3F 61 0C 3F 61 0C 3F 61 0C 

00002E10:3F 60 0C 3F 60 0C 40 60 0C 40 60 0C 40 60 0C 40 

00002E20:60 0C 3F 5F 0C 3F 5F 0C 3F 5F 0C 40 60 0C 40 60 

00002E30:0C 40 60 0C 3F 5F 0B 3F 5F 0B 3F 5F 0C 41 5F 0C 

00002E40:41 5E 0B 41 5E 0B 42 5F 0C 42 5F 0C 40 60 0C 40 

00002E50:60 0C 40 60 0C 3F 5F 0B 3F 5F 0B 3F 5F 0B 3F 5F 

00002E60:0B 3F 5F 0B 42 5F 0C 42 5F 0C 41 5E 0B 41 5E 0B 

00002E70:41 5E 0B 41 5E 0B 41 5E 0B 41 5F 0C 41 5E 0B 41 

00002E80:5E 0B 41 5E 0B 41 5E 0B 41 5E 0B 41 5F 0B 41 5F 

00002E90:0B 41 5F 0A 41 5F 0B 41 5F 0B 41 5F 0B 41 5F 0B 

00002EA0:41 5F 0B 41 5F 0B 41 5F 0B 41 5F 0B 42 5F 0B 42 

00002EB0:5F 0B 41 5F 0B 41 5F 0B 41 5F 0B 43 5F 0B 43 5E 

00002EC0:0A 43 5E 0A 43 5F 0B 43 5F 0B 43 5F 0B 43 5F 0B 

00002ED0:43 5F 0B 43 5F 0A 43 5F 0A 43 5F 0A 42 5E 09 42 

00002EE0:5E 09 42 5E 09 42 5E 09 42 5E 09 42 5E 09 42 5E 

00002EF0:09 42 5E 09 42 5E 09 00 3F 64 0B 3F 64 0B 3F 64 

00002F00:0B 3F 64 0B 3F 64 0B 3F 64 0B 3F 64 0B 3F 64 0B 

00002F10:3F 64 0C 3F 64 0C 3F 64 0C 3F 62 0C 40 62 0C 40 

00002F20:62 0C 40 62 0C 40 62 0C 40 62 0C 40 62 0C 3F 62 

00002F30:0C 3F 62 0C 40 63 0C 40 63 0D 40 62 0C 40 62 0C 

00002F40:3F 62 0B 3F 62 0B 3F 62 0C 40 62 0C 40 62 0C 41 

00002F50:62 0C 41 63 0D 40 62 0C 40 63 0A 40 63 0A 40 63 

00002F60:0A 3F 62 0C 3F 62 0C 3F 62 0C 3F 62 0C 3F 62 0C 

00002F70:40 61 0B 40 61 0B 40 61 0B 40 61 0B 40 61 0B 40 

00002F80:61 0B 40 61 0B 41 62 0C 40 61 0B 40 61 0B 40 61 

00002F90:0B 40 61 0B 40 61 0B 40 61 0B 40 61 0B 40 61 0B 

00002FA0:40 61 0B 40 61 0B 40 61 0B 40 61 0B 40 61 0B 40 

00002FB0:61 0B 40 61 0B 40 61 0B 40 61 0B 40 61 0B 40 61 

00002FC0:0B 40 62 09 40 62 09 40 62 09 42 61 09 42 61 09 

00002FD0:42 61 09 42 61 09 42 61 09 42 61 09 42 61 09 42 

00002FE0:61 09 42 61 09 42 61 09 40 62 09 42 61 09 42 61 

00002FF0:09 42 61 09 42 61 09 42 61 09 42 61 09 42 61 09 

00003000:42 61 09 00 3D 60 0F 3D 60 0F 3D 60 0F 3D 60 0F 

00003010:3D 60 0F 3D 60 0F 3D 60 0F 3D 60 0F 3D 60 0F 3D 

00003020:60 0F 3D 60 0F 3D 60 0F 3D 60 0F 3D 60 0F 3D 60 

00003030:0F 3D 60 0F 3D 61 0E 3D 61 0E 3C 60 0D 3C 60 0D

00003040:3D 61 0E 3D 61 0E 3D 61 0E 3D 61 0E 3D 61 0E 3D 

00003050:61 0E 3D 61 0E 3D 61 0E 3D 61 0E 3D 61 0E 3D 61 

00003060:0E 3D 61 0E 3D 61 0E 3D 61 0E 3D 61 0E 3D 61 0E 

00003070:3C 60 0D 3E 5F 0D 3E 5F 0D 3E 5F 0D 3E 5F 0D 3E 

00003080:5F 0D 3E 5F 0D 3E 5F 0D 3E 5F 0D 3E 5F 0D 3E 5F 

00003090:0D 3E 5F 0D 3E 5F 0D 3E 5F 0D 3E 5F 0D 3E 5F 0D 

000030A0:3E 5F 0D 3E 5F 0D 3E 5F 0D 3E 5F 0D 3E 5F 0D 3E 

000030B0:5F 0D 3E 5F 0D 3E 5F 0D 3F 5F 0D 3F 5F 0D 3F 5F 

000030C0:0D 3F 5F 0D 3E 5F 0D 3E 5F 0D 3E 5F 0D 3E 5F 0D 

000030D0:3E 60 0B 3D 5F 0A 3E 5F 0A 3E 5F 0A 3F 60 0B 3F 

000030E0:60 0B 3F 60 0B 3F 60 0B 3F 60 0B 3F 60 0B 3F 60 

000030F0:0B 3F 60 0B 3E 60 0B 3E 60 0B 3E 60 0B 3F 60 0B 

00003100:3F 60 0B 3F 60 0B 3F 5F 0D 3F 5F 0D 3D 5F 0A 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x0000004C) |
| Size (0x00002FA8) |
| Bounds (0x00000000) |
| ... (0x0000002D) |
| ... (0x00000059) |
| ... (0x00000059) |
| xDest (0x00000000) |
| yDest (0x0000002D) |
| cxDest (0x0000005A) |
| cyDest (0x0000002D) |

**Type (4 bytes)**: 0x0000004C identifies this record type as EMR_BITBLT.

**Size (4 bytes)**: 0x00002FA8 specifies the size of this record in bytes.

**Bounds (16 bytes)**: 0x00000000, 0x00000002D, 0x00000059, 0x00000059 specifies the bounding rectangle in logical units.

**xDest (4 bytes)**: 0x00000000 specifies the logical x-coordinate of the upper-left corner of the destination rectangle.

**yDest (4 bytes)**: 0x0000002D specifies the logical y-coordinate of the upper-left corner of the destination rectangle.

**cxDest (4 bytes)**: 0x0000005A specifies the logical width of the destination rectangle.

**cyDest (4 bytes)**: 0x0000002D specifies the logical height of the destination rectangle.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BitBlitRasterOperation (0x00CC0020) |
| xSrc (0x00000000) |
| ySrc (0x00000000) |
| xformSrc (0x3F800000) (24 bytes) |
| ... (0x00000000) |
| ... (0x00000000) |
| ... (0x3F800000) |
| ... (0x00000000) |
| ... (0x00000000) |

**BitBlitRasterOperation (4 bytes)**: 0x00CC0020 specifies the **raster operation** code from the **Ternary Raster Operation** enumeration ([MS-WMF] section 2.1.1.31). This code defines how the color data of the source rectangle is to be combined with the color data of the destination rectangle to achieve the final color.

**xSrc (4 bytes)**: 0x00000000 specifies the logical x-coordinate of the upper-left corner of the source rectangle.

**ySrc (4 bytes)**: 0x00000000 specifies the logical y-coordinate of the upper-left corner of the source rectangle.

**xformSrc (24 bytes)**: 0x3F800000, 0x00000000, 0x00000000, 0x3F800000, 0x00000000, 0x00000000 specify the **world-space** to **page-space** **transform**. For more information about **coordinate spaces**, see [MSDN-WRLDPGSPC].

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BkColorSrc (0x00FFFFFF) |
| UsageSrc (0x00000000) |
| offBmiSrc (0x00000064) |
| cbBmiSrc (0x00000000) |
| offBitsSrc (0x0000008C) |
| cbBitsSrc (0x00002F1C) |

**BkColorSrc (4 bytes)**: 0x00FFFFFF specifies the background **RGB** color.

**UsageSrc (4 bytes)**: 0x00000000 specifies the value of the **Colors** field of the **DeviceIndependentBitmap** object ([MS-WMF] section 2.2.2.9) from the DIBColors enumeration (section 2.1.9).

**offBmiSrc (4 bytes)**: 0x00000064 specifies the offset to the source **DeviceIndependentBitmap** object.

**cbBmiSrc (4 bytes)**: 0x00000000 specifies the size of the source **DeviceIndependentBitmap** object.

**offBitsSrc (4 bytes)**: 0x0000008C specifies the offset to the source **bitmap** bits.

**cbBitsSrc (4 bytes)**: 0x00002F1C specifies the size of the source bitmap bits.

### EMR_SETBKMODE Example

This section provides an example of an EMR_SETBKMODE record (section 2.3.11.11).

00003110:12 00 00 00 0C 00 00 00 01 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000012) |
| Size (0x0000000C) |
| Mode (0x00000001) |

**Type (4 bytes)**: 0x00000012 identifies this record type as EMR_SETBKMODE.

**Size (4 bytes)**: 0x0000000C specifies the size of this record in bytes.

**Mode (4 bytes)**: 0x00000001 specifies the background color value.

### EMR_EXTCREATEFONTINDIRECTW Example 1

This section provides an example of an EMR_EXTCREATEFONTINDIRECTW record (section 2.3.7.8).

00003110:                                    52 00 00 00 

00003120:70 01 00 00 02 00 00 00 F3 FF FF FF 00 00 00 00 

00003130:4E 0C 00 00 4E 0C 00 00 C8 00 00 00 00 00 00 01 

00003140:04 00 00 02 41 00 72 00 69 00 61 00 6C 00 00 00 

00003150:00 00 00 00 00 00 00 00 00 00 00 00 0C 45 00 00 

00003160:BC 16 E8 FE FE 07 00 00 20 00 CC 00 00 00 00 00 

00003170:4C 00 00 00 FE 07 00 00 DA 16 01 B8 FF FF FF FF 

00003180:00 00 00 00 00 00 00 00 F0 F6 13 00 00 00 00 00 

00003190:0E 20 05 27 00 00 00 00 28 00 00 00 00 00 00 00 

000031A0:1C 2F 00 00 00 00 00 00 00 00 00 00 00 00 00 00 

000031B0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 

000031C0:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 

000031D0:00 00 00 00 00 00 00 00 28 00 00 00 FF FF FF 00 

000031E0:1C 2F 00 00 00 00 00 00 00 00 00 00 00 00 00 00 

000031F0:58 00 00 00 2C 00 00 00 00 00 00 00 00 00 00 00 

00003200:00 00 80 3F 00 00 00 00 00 00 00 00 00 00 80 3F

00003210:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 

00003220:D0 C5 35 00 00 00 00 00 28 00 00 00 59 00 00 00 

00003230:2D 00 00 00 01 00 18 00 00 00 00 00 1C 2F 00 00 

00003240:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 

00003250:10 00 90 01 00 00 00 00 25 00 00 00 00 00 00 00 

00003260:D3 3F EC FE FE 07 00 00 79 0D 21 11 00 00 00 00 

00003270:10 00 90 01 00 00 00 00 00 00 00 00 59 00 00 00

00003280:2D 00 00 00 64 76 00 08 00 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000052) |
| Size (0x00000170) |
| ihFonts (0x00000002) |
| elw (360 bytes) |
| ... |
| ... |
| ... |
| ... |

**Type (4 bytes)**: 0x00000052 identifies this record type as EMR_EXTCREATEFONTINDIRECTW.

**Size (4 bytes)**: 0x00000170 specifies the size of this record in bytes.

**ihFonts (4 bytes)**: 0x00000002 specifies the object index that is assigned to the font.

**elw (360 byt****es)**: To determine the type of logical font object in this field, an algorithm (section 2.3.7.8) is applied, which indicates this is a LogFontExDv object (section 2.2.15).

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Height (0xFFFFFFF3) |
| Width (0x00000000) |
| Escapement (0x00000C4E) |
| Orientation (0x00000C4E) |
| Weight 0x000000C8) |
| Italic (0x00) | Underline (0x00) | StrikeOut (0x00) | CharSet (0x01) |
| OutPrecision (0x04) | ClipPrecision (0x00) | Quality (0x00) | PitchAndFamily (0x02) |
| Facename ("Arial") (68 bytes) |
| ... |
| ... |
| ... |

**Height (4 bytes)**: 0xFFFFFFF3 has an absolute value of 13, which specifies the character height for this font, in logical units.

**Width (4 bytes)**: 0x00000000 specifies a computed font width. The aspect ratio of the device is matched against the digitization aspect ratio of the font to find the closest match, determined by the absolute value of the difference.

**Escapement (4 bytes)**: 0x00000C4E specifies an angle of 315 degrees between the **baseline** of a row of text and the x-axis of the device.

**Orientation (4 bytes)**: 0x00000C4E specifies an angle of 315 degrees between each character's baseline and the x-axis of the device.

**Weight (4 bytes)**: 0x000000C8 specifies that the **weight** of the font is 200, in the range 0 through 1000, from lightest to darkest, with 400 (0x00000190) considered normal.

**Italic (1 ****byte)**: 0x00 specifies that the font is not italic.

**Underline (1 byte)**: 0x00 specifies that the font is not underlined.

**Strikeout (1 byte)**: 0x00 specifies that the font characters do not have a strike-out graphic.

**CharSet (1 byte)**: 0x01 specifies the default character set, from the CharacterSet enumeration ([MS-WMF] section 2.1.1.5).

**OutPrecision (1 byte)**: 0x04 specifies the output precision, which is how closely the output is expected to match the requested font properties, from the OutPrecision enumeration ([MS-WMF] section 2.1.1.21). The value 0x04 specifies a **TrueType** font, if there is a choice between multiple fonts with the same name.

**ClipPrecision (1 byte)**: 0x00 specifies the clipping precision, which is how to clip characters that are partially outside the clipping **regions**, from the ClipPrecision flags ([MS-WMF] section 2.1.2.1). The value 0x00 specifies default clipping behavior.

**Quality (1 byte)**: 0x00 specifies default output quality, from the FontQuality enumeration ([MS-WMF] section 2.1.1.10).

**PitchAndFamily (1 byte)**: 0x02 specifies a variable-pitch font, and no preference for font family, from the PitchAndFamily object ([MS-WMF] section 2.2.2.14).

**Facename (68 bytes)**: "Arial" specifies the **typeface** name of the font in **Unicode** characters.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FullName ("") (132 bytes) |
| ... |
| ... |
| ... |
| Style ("") (68 bytes) |
| ... |
| ... |
| ... |
| Script ("") (68 bytes) |
| ... |
| ... |
| ... |
| Signature (0x08007664) |
| NumAxes (0x00000000) |

**FullName (132 bytes)**: An empty string specifies the font's full name.

**Style (68 bytes)**: An empty string describes the font's style.

**Script (68 bytes)**: An empty string describes the font's character set.

**Signatu****re (4 bytes)**: 0x08007664 specifies the signature of a DesignVector object (section 2.2.3).

**NumAxes (4 bytes)**: 0x00000000 specifies the number of **font axes** described in the DesignVector object.

### EMR_SELECTOBJECT Example 3

This section provides an example of an EMR_SELECTOBJECT record (section 2.3.8.5).

00003280:                                    25 00 00 00 

00003290:0C 00 00 00 02 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000025) |
| Size (0x0000000C) |
| ihObject (0x00000002) |

**Type (4 bytes)**: 0x00000025 identifies this record type as EMR_SELECTOBJECT.

**Size (4 bytes)**: 0x0000000C specifies the size of this record in bytes.

**ihObject (4 bytes)**: 0x00000002 specifies the index of an object in the EMF object table.

### EMR_EXTTEXTOUTW Example

This section provides an example of an EMR_EXTTEXTOUTW record (section 2.3.5.8).

00003290:                        54 00 00 00 A0 00 00 00

000032A0:00 00 00 00 00 00 00 00 FF FF FF FF FF FF FF FF

000032B0:01 00 00 00 AB 0A 0D 42 00 00 0D 42 12 00 00 00

000032C0:05 00 00 00 0E 00 00 00 4C 00 00 00 00 00 00 00

000032D0:00 00 00 00 00 00 00 00 FF FF FF FF FF FF FF FF

000032E0:68 00 00 00 53 00 69 00 6D 00 70 00 6C 00 65 00

000032F0:20 00 53 00 61 00 6D 00 70 00 6C 00 65 00 00 00

00003300:09 00 00 00 03 00 00 00 0B 00 00 00 07 00 00 00

00003310:03 00 00 00 07 00 00 00 04 00 00 00 09 00 00 00

00003320:07 00 00 00 0B 00 00 00 07 00 00 00 03 00 00 00

00003330:07 00 00 00 09 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000054) |
| Size (0x000000A0) |
| Bounds (0x00000000) |
| ... (0x00000000) |
| ... (0xFFFFFFFF) |
| ... (0xFFFFFFFF) |
| iGraphicsMode (0x00000001) |
| exScale (35.260418) |
| eyScale (35.250000) |
| aemrtext (variable) |
| ... |

**Type (4 bytes)**: 0x00000054 identifies this record type as EMR_EXTTEXTOUTW.

**Size (4 bytes)**: 0x000000A0 specifies the size of this record in bytes.

**Bounds (16 bytes)**: 0x00000000, 0x00000000, 0xFFFFFFFF, 0xFFFFFFFF values are not used.

**iGraphicsMode (4 bytes)**: 0x00000001 specifies the current graphics mode.

**exScale (4 bytes)**: 35.260418 specifies the X scale from page units to .01mm units if graphics mode is **GM_COMPATIBLE**.

**eyScale (4 bytes)**: 35.250000 specifies the Y scale from page units to .01mm units if graphics mode is **GM_COMPATIBLE**.

**aemrtext (variable)**: An array of EmrText objects (section 2.2.5) that specifies the properties of the strings to be output, and where to find the output strings and spacing values.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Reference (0x00000012) |
| ... (0x00000005) |
| Chars (0x0000000E) |
| offString (0x0000004C) |
| Options (0x00000000) |
| Rectangle (0x00000000) |
| ... (0x00000000) |
| ... (0xFFFFFFFF) |
| ... (0xFFFFFFFF) |
| offDx (0x00000068) |
| text ("Simple Sample") |

**Reference**** (8 bytes)**: 0x00000012, 0x00000005 specify the coordinates of the reference point used to position the string.

**Chars (4 bytes)**: 0x0000000E specifies the number of characters in the string.

**offString (4 bytes)**: 0x0000004C specifies the offset to the string in bytes, from the start of the EMR_EXTTEXTOUTW record.

**Options (4 bytes)**: 0x00000000 specifies that the **Rectangle** field is not used.

**Rectangle (16 bytes)**: 0x00000000, 0x00000000, 0xFFFFFFFF, 0xFFFFFFFF values are not used.

**offDx (4 bytes)**: 0x00000068 specifies the offset to an intercharacter spacing array in bytes, from the start of the EMR_EXTTEXTOUTW record.

**text (4 bytes)**: "Simple Sample".

### EMR_EXTCREATEFONTINDIRECTW Example 2

This section provides an example of an EMR_EXTCREATEFONTINDIRECTW record (section 2.3.7.8).

00003330:                        52 00 00 00 70 01 00 00

00003340:03 00 00 00 F3 FF FF FF 00 00 00 00 4E 0C 00 00

00003350:4E 0C 00 00 C8 00 00 00 00 00 00 00 04 00 00 02

00003360:4D 00 69 00 63 00 72 00 6F 00 73 00 6F 00 66 00

00003370:74 00 20 00 53 00 61 00 6E 00 73 00 20 00 53 00 

00003380:65 00 72 00 69 00 66 00 00 00 00 00 00 00 00 00 

00003390:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 

000033A0:00 00 00 00 28 00 00 00 59 00 00 00 2D 00 00 00 

000033B0:01 00 18 00 00 00 00 00 1C 2F 00 00 00 00 00 00

000033C0:00 00 00 00 00 00 00 00 00 00 00 00 10 00 90 01 

000033D0:00 00 00 00 25 00 00 00 00 00 00 00 D3 3F EC FE 

000033E0:FE 07 00 00 79 0D 21 11 00 00 00 00 10 00 90 01

000033F0:00 00 00 00 00 00 00 00 59 00 00 00 2D 00 00 00 

00003400:64 76 00 08 00 00 00 00 00 00 00 00 00 08 0D 00 

00003410:0D 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 

00003420:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 

00003430:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 

00003440:00 00 00 00 92 A0 CD 02 00 00 00 00 CA BE CD 02 

00003450:00 00 00 00 00 00 00 00 00 00 00 00 FF FF 5A FE 

00003460:00 00 00 00 00 00 00 00 00 00 00 00 95 F1 53 FE

00003470:FE 07 00 00 BE 06 5A FE FE 07 00 00 87 F2 53 FE 

00003480:FE 07 00 00 C4 04 5A FE FE 07 00 00 79 0D 21 11 

00003490:00 00 00 00 01 00 00 00 00 00 00 00 F0 02 5A FE 

000034A0:64 76 00 08 00 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000052) |
| Size (0x00000170) |
| ihFonts (0x00000003) |
| elw (360 bytes) |
| ... |
| ... |
| ... |
| ... |

**Type (4 bytes)**: 0x00000052 identifies this record type as EMR_EXTCREATEFONTINDIRECTW.

**Size (4 bytes)**: 0x00000170 specifies the size of this record in bytes.

**ihFonts (4 bytes)**: 0x00000003 specifies the object index that is assigned to the font.

**elw (360 bytes)**: To determine the type of logical font object in this field, an algorithm (section 2.3.7.8) is applied, which indicates this is a LogFontExDv object (section 2.2.15).

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Height (0xFFFFFFF3) |
| Width (0x00000000) |
| Escapement (0x00000C4E) |
| Orientation (0x00000C4E) |
| Weight 0x000000C8) |
| Italic (0x00) | Underline (0x00) | StrikeOut (0x00) | CharSet (0x00) |
| OutPrecision (0x04) | ClipPrecision (0x00) | Quality (0x00) | PitchAndFamily (0x02) |
| Facename ("Microsoft Sans Serif") (68 bytes) |
| ... |
| ... |
| ... |

**Height (4 bytes)**: 0xFFFFFFF3 has an absolute value of 13, which specifies the character height for this font in logical units.

**Width (4 bytes)**: 0x00000000 specifies a computed font width. The aspect ratio of the device is matched against the digitization aspect ratio of the font to find the closest match, determined by the absolute value of the difference.

**Escapement (4 bytes)**: 0x00000C4E specifies an angle of 315 degrees between the **baseline** of a row of text and the x-axis of the device.

**Orientation (4 bytes)**: 0x00000C4E specifies an angle of 315 degrees between each character's baseline and the x-axis of the device.

**Weight (4 bytes)**: 0x000000C8 specifies that the **weight** of the font is 200, in the range 0 through 1000, from lightest to darkest, with 400 (0x00000190) considered normal.

**Italic (1 byte)**: 0x00 specifies that the font is not italic.

**Underline (1 byte)**: 0x00 specifies that the font is not underlined.

**Strikeout (1 byte)**: 0x00 specifies that the font characters do not have a strike-out graphic.

**CharSet (1 byte)**: 0x00 specifies the **ANSI_CHARSET**, as defined in the CharacterSet enumeration ([MS-WMF] section 2.1.1.5).

**OutPrecision (1 byte)**: 0x04 specifies the output precision, which is how closely the output is expected to match the requested font properties, from the OutPrecision enumeration ([MS-WMF] section 2.1.1.21). The value 0x04 specifies a **TrueType** font, if there is a choice between multiple fonts with the same name.

**ClipPrecision (1 byte)**: 0x00 specifies the clipping precision, which is how to clip characters that are partially outside the clipping **region**, from the ClipPrecision flags ([MS-WMF] section 2.1.2.1). The value 0x00 specifies default clipping behavior.

**Quality (1 byte)**: 0x00 specifies default output quality, from the FontQuality enumeration ([MS-WMF] section 2.1.1.10).

**PitchAndFamily (1 byte)**: 0x02 specifies a variable-pitch font, and no preference for font family, from the PitchAndFamily object ([MS-WMF] section 2.2.2.14).

**Facename (68 bytes)**: "Microsoft Sans Serif" specifies the **typeface** name of the font in **Unicode** characters.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FullName ("") (132 bytes) |
| ... |
| ... |
| ... |
| Style ("") (68 bytes) |
| ... |
| ... |
| ... |
| Script ("") (68 bytes) |
| ... |
| ... |
| ... |
| Signature (0x80007664) |
| NumAxes (0x00000000) |

**FullName (132 bytes)**: An empty string specifies the font's full name.

**Style (68 bytes)**: An empty string describes the font's style.

**Script (68 bytes)**: An empty string describes the font's character set.

**Signature (4 bytes)**: 0x08007664 specifies the signature of a DesignVector object (section 2.2.3).

**NumAxes (4 bytes)**: 0x00000000 specifies the number of **font axes** described in the DesignVector object.

### EMR_SELECTOBJECT Example 4

This section provides an example of an EMR_SELECTOBJECT record (section 2.3.8.5).

000034A0:                        25 00 00 00 0C 00 00 00

000034B0:03 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000025) |
| Size (0x0000000C) |
| ihObject (0x00000003) |

**Type (4 bytes)**: Identifies this record type as EMR_SELECTOBJECT.

**Size (4 bytes)**: Specifies the size of this record in bytes.

**ihObject (4 bytes)**: Specifies the index of an object in the EMF object table.

### EMR_EXTCREATEFONTINDIRECTW Example 3

This section provides an example of an EMR_EXTCREATEFONTINDIRECTW record (section 2.3.7.8).

000034B0:            52 00 00 00 70 01 00 00 04 00 00 00 

000034C0:F2 FF FF FF 00 00 00 00 4E 0C 00 00 4E 0C 00 00 

000034D0:C8 00 00 00 00 00 00 00 04 00 00 02 4D 00 69 00 

000034E0:63 00 72 00 6F 00 73 00 6F 00 66 00 74 00 20 00 

000034F0:53 00 61 00 6E 00 73 00 20 00 53 00 65 00 72 00 

00003500:69 00 66 00 00 00 00 00 00 00 00 00 00 00 00 00 

00003510:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00

00003520:C8 F1 13 00 00 00 00 00 10 00 90 01 00 00 00 00 

00003530:20 AC CF 02 00 00 00 00 10 00 00 00 06 00 00 00 

00003540:06 00 00 00 04 00 00 00 01 00 00 00 01 00 00 00 

00003550:01 00 00 00 01 00 00 00 0D 00 00 00 00 00 00 00 

00003560:03 00 00 00 00 08 00 00 3B 09 00 00 00 00 00 00

00003570:A0 E8 07 02 00 00 00 00 03 00 00 00 FE 07 00 00 

00003580:90 01 00 00 4D 00 69 00 63 00 72 00 6F 00 73 00 

00003590:6F 00 66 00 74 00 20 00 53 00 61 00 00 00 73 00 

000035A0:20 00 53 00 65 00 72 00 69 00 66 00 00 00 00 00 

000035B0:00 00 00 00 00 00 00 00 FF FF 5A FE 00 00 00 00

000035C0:40 02 5A FE FE 07 00 00 9D 04 00 00 00 00 00 00

000035D0:FF FF FF FF FF FF FF FF 01 00 00 00 00 00 00 00 

000035E0:20 AC CF 02 00 00 00 00 00 00 07 02 00 00 00 00

000035F0:10 AC CF 02 00 00 00 00 26 36 E3 76 00 00 00 00

00003600:00 00 07 02 00 00 00 00 01 00 00 00 00 27 00 00 

00003610:00 00 00 00 00 00 00 00 20 AC CF 02 64 76 00 08 

00003620:00 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000052) |
| Size (0x00000170) |
| ihFonts (0x00000004) |
| elw (360 bytes) |
| ... |
| ... |
| ... |
| ... |

**Type (4 bytes)**: 0x00000052 identifies this record type as EMR_EXTCREATEFONTINDIRECTW.

**Size (4 bytes)**: 0x00000170 specifies the size of this record in bytes.

**ihFonts (4 bytes)**: 0x00000004 specifies the object index that is assigned to the font.

**elw (360 bytes)**: To determine the type of logical font object in this field, an algorithm (section 2.3.7.8) is applied, which indicates this is a LogFontExDv object (section 2.2.15).

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Height (0xFFFFFFF2) |
| Width (0x00000000) |
| Escapement (0x00000C4E) |
| Orientation (0x00000C4E) |
| Weight 0x000000C8) |
| Italic (0x00) | Underline (0x00) | StrikeOut (0x00) | CharSet (0x00) |
| OutPrecision (0x04) | ClipPrecision (0x00) | Quality (0x00) | PitchAndFamily (0x02) |
| Facename ("Microsoft Sans Serif") (68 bytes) |
| ... |
| ... |
| ... |

**Height (4 bytes)**: 0xFFFFFFF2 has an absolute value of 14, which specifies the character height for this font in logical units.

**Width (4 bytes)**: 0x00000000 specifies a computed font width. The aspect ratio of the device is matched against the digitization aspect ratio of the font to find the closest match, determined by the absolute value of the difference.

**Escap****ement (4 bytes)**: 0x00000C4E specifies an angle of 315 degrees between the **baseline** of a row of text and the x-axis of the device.

**Orientation (4 bytes)**: 0x00000C4E specifies an angle of 315 degrees between each character's baseline and the x-axis of the device.

**Weight (4 bytes)**: 0x000000C8 specifies that the **weight** of the font is 200, in the range 0 through 1000, from lightest to darkest, with 400 (0x00000190) considered normal.

**Italic (1 byte)**: 0x00 specifies that the font is not italic.

**Underline (1 byte)**: 0x00 specifies that the font is not underlined.

**Strikeout (1 byte)**: 0x00 specifies that the font characters do not have a strike-out graphic.

**CharSet (1 byte)**: 0x00 specifies the **ANSI_CHARSET**, as defined in the CharacterSet enumeration ([MS-WMF] section 2.1.1.5).

**OutPrecision (1 byte)**: 0x04 specifies the output precision, which is how closely the output is expected to match the requested font properties, from the OutPrecision enumeration ([MS-WMF] section 2.1.1.21). The value 0x04 specifies a **True****Type** font, if there is a choice between multiple fonts with the same name.

**ClipPrecision (1 byte)**: 0x00 specifies the clipping precision, which is how to clip characters that are partially outside the clipping **region**, from the ClipPrecision flags ([MS-WMF] section 2.1.2.1). The value 0x00 specifies default clipping behavior.

**Quality (1 byte)**: 0x00 specifies default output quality, from the FontQuality enumeration ([MS-WMF] section 2.1.1.10).

**Pitc****hAndFamily (1 byte)**: 0x02 specifies a variable-pitch font, and no preference for font family, from the PitchAndFamily object ([MS-WMF] section 2.2.2.14).

**Facename (68 bytes)**: "Microsoft Sans Serif" specifies the **typeface** name of the font in **Unicode** characters.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FullName ("") (132 bytes) |
| ... |
| ... |
| ... |
| Style ("") (68 bytes) |
| ... |
| ... |
| ... |
| Script ("") (68 bytes) |
| ... |
| ... |
| ... |
| Signature (0x80007664) |
| NumAxes (0x00000000) |

**FullName (132 bytes)**: An empty string specifies the font's full name.

**Style (68 bytes)**: An empty string describes the font's style.

**Script (68 ****bytes)**: An empty string describes the font's character set.

**Signature (4 bytes)**: 0x08007664 specifies the signature of a DesignVector object (section 2.2.3).

**NumAxes (4 bytes)**: 0x00000000 specifies the number of **font axes** described in the DesignVector object.

### EMR_SELECTOBJECT Example 5

This section provides an example of an EMR_SELECTOBJECT record (section 2.3.8.5).

00003620:            25 00 00 00 0C 00 00 00 04 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000025) |
| Size (0x0000000C) |
| ihObject (0x00000004) |

**Type (4 bytes)**: Identifies this record type as EMR_SELECTOBJECT.

**Size (4 bytes)**: Specifies the size of this record in bytes.

**ihObject (4 bytes)**: Specifies the index of an object in the EMF object table.

### EMR_DELETEOBJECT Example 1

This section provides an example of an EMR_DELETEOBJECT record (section 2.3.8.3).

00003630:28 00 00 00 0C 00 00 00 03 00 00 00  

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000028) |
| Size (0x0000000C) |
| ihObject (0x00000003) |

**Type (4 bytes)**: Identifies this record type as EMR_DELETEOBJECT.

**Size ****(4 bytes)**: Specifies the size of this record in bytes.

**ihObject (4 bytes)**: Specifies the index of the object to be deleted.

### EMR_EXTCREATEFONTINDIRECTW Example 4

This section provides an example of an EMR_EXTCREATEFONTINDIRECTW record (section 2.3.7.8).

00003630:                                    52 00 00 00

00003640:70 01 00 00 03 00 00 00 13 00 00 00 00 00 00 00

00003650:4E 0C 00 00 4E 0C 00 00 C8 00 00 00 00 00 00 00

00003660:04 00 00 02 4D 00 69 00 63 00 72 00 6F 00 73 00 

00003670:6F 00 66 00 74 00 20 00 53 00 61 00 6E 00 73 00

00003680:20 00 53 00 65 00 72 00 69 00 66 00 00 00 00 00 

00003690:00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 

000036A0:00 00 00 00 00 00 73 00 20 00 53 00 65 00 72 00 

000036B0:69 00 66 00 00 00 00 00 00 00 00 00 00 00 00 00 

000036C0:FF FF 5A FE 00 00 00 00 40 02 5A FE FE 07 00 00 

000036D0:9D 04 00 00 00 00 00 00 FF FF FF FF FF FF FF FF 

000036E0:01 00 00 00 00 00 00 00 20 AC CF 02 00 00 00 00 

000036F0:00 00 07 02 00 00 00 00 40 02 5A FE FE 07 00 00 

00003700:F3 14 00 00 00 00 00 00 F3 14 0A 1E 00 00 00 00 

00003710:94 8A E8 FE FE 07 00 00 04 00 00 00 00 00 00 00 

00003720:65 58 53 FE 00 00 00 00 00 00 00 00 00 00 00 00 

00003730:00 F5 13 00 00 00 00 00 03 01 56 E5 89 1A 00 00 

00003740:55 00 00 00 00 00 00 00 00 00 00 00 04 00 00 00

00003750:00 00 00 00 FE 07 00 00 79 0D 21 11 00 00 00 00 

00003760:40 02 5A FE 00 00 00 00 26 06 5A FE FE 07 00 00 

00003770:08 F5 13 00 00 00 00 00 00 F5 13 00 00 00 00 00 

00003780:07 CB 54 FE FE 07 00 00 79 0D 21 11 00 00 00 00 

00003790:04 00 00 00 00 00 00 00 24 07 5A FE FE 07 00 00 

000037A0:01 00 00 00 64 76 00 08 00 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000052) |
| Size (0x00000170) |
| ihFonts (0x00000003) |
| elw (360 bytes) |
| ... |
| ... |
| ... |
| ... |

**Type (4 bytes)**: 0x00000052 identifies this record type as EMR_EXTCREATEFONTINDIRECTW.

**Size (4 bytes)**: 0x00000170 specifies the size of this record in bytes.

**ihFonts (4 bytes)**: 0x00000003 specifies the object index that is assigned to the font.

**elw (360 bytes)**: To determine the type of logical font object in this field, an algorithm (section 2.3.7.8) is applied, which indicates this is a LogFontExDv object (section 2.2.15).

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Height (0x00000013) |
| Width (0x00000000) |
| Escapement (0x00000C4E) |
| Orientation (0x00000C4E) |
| Weight 0x000000C8) |
| Italic (0x00) | Underline (0x00) | StrikeOut (0x00) | CharSet (0x01) |
| OutPrecision (0x04) | ClipPrecision (0x00) | Quality (0x00) | PitchAndFamily (0x02) |
| Facename ("Microsoft Sans Serif") (68 bytes) |
| ... |
| ... |
| ... |

**Height (4 bytes)**: 0x00000013 specifies the **cell height** for this font, in logical units.

**Width (4 bytes)**: 0x00000000 specifies a computed font width. The **aspect ratio** of the device is matched against the digitization aspect ratio of the font to find the closest match, determined by the absolute value of the difference.

**Escapement (4 bytes)**: 0x00000C4E specifies an angle of 315 degrees between the **baseline** of a row of text and the x-axis of the device.

**Orientation (4 bytes)**: 0x00000C4E specifies an angle of 315 degrees between each character's baseline and the x-axis of the device.

**Weight (4 bytes)**: 0x000000C8 specifies that the **weight** of the font is 200, in the range 0 through 1000, from lightest to darkest, with 400 (0x00000190) considered normal.

**Italic (1 byte)**: 0x00 specifies that the font is not italic.

**Underline (1 byte)**: 0x00 specifies that the font is not underlined.

**Strikeout (1 byte)**: 0x00 specifies that the font characters do not have a strike-out graphic.

**CharSet (1 byte)**: 0x00 specifies the **ANSI_CHARSET**, as defined in the CharacterSet enumeration ([MS-WMF] section 2.1.1.5).

**O****utPrecision (1 byte)**: 0x04 specifies the output precision, which is how closely the output is expected to match the requested font properties, from the OutPrecision enumeration ([MS-WMF] section 2.1.1.21). The value 0x04 specifies a **TrueType** font, if there is a choice between multiple fonts with the same name.

**ClipPrecision (1 byte)**: 0x00 specifies the clipping precision, which is how to clip characters that are partially outside the clipping **region**, from the ClipPrecision flags ([MS-WMF] section 2.1.2.1). The value 0x00 specifies default clipping behavior.

**Quality (1 byte)**: 0x00 specifies default output quality, from the FontQuality enumeration ([MS-WMF] section 2.1.1.10).

**PitchAndFamily (1 byte)**: 0x02 specifies a variable-pitch font, and no preference for font family, from the PitchAndFamily object ([MS-WMF] section 2.2.2.14).

**Facename (68 bytes)**: "Microsoft Sans Serif" specifies the **typeface** name of the font in **Unicode** characters.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FullName ("") (132 bytes) |
| ... |
| ... |
| ... |
| Style ("") (68 bytes) |
| ... |
| ... |
| ... |
| Script ("") (68 bytes) |
| ... |
| ... |
| ... |
| Signature (0x80007664) |
| NumAxes (0x00000000) |

**FullName (132 bytes)**: An empty string specifies the font's full name.

**Style (68 bytes)**: An empty string describes the font's style.

**Script (68 bytes)**: An empty string describes the font's character set.

**Signature (4 bytes)**: 0x08007664 specifies the signature of a DesignVector object (section 2.2.3).

**NumAxes (4 bytes)**: 0x00000000 specifies the number of **font axes** described in the DesignVector object.

### EMR_SELECTOBJECT Example 6

This section provides an example of an EMR_SELECTOBJECT record (section 2.3.8.5).

000037A0:                                    25 00 00 00 

000037B0:0c 00 00 00 03 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000025) |
| Size (0x0000000C) |
| ihObject (0x00000003) |

**Type (4 bytes)**: 0x00000025 identifies this record type as EMR_SELECTOBJECT.

**Size (4 bytes)**: 0x0000000C specifies the size of this record in bytes.

**ihObject (4 bytes)**: 0x00000003 specifies the index of an object in the EMF object table.

### EMR_SELECTOBJECT Example 7

This section provides an example of an EMR_SELECTOBJECT record (section 2.3.8.5).

000037B0:                        25 00 00 00 0C 00 00 00 

000037C0:02 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000025) |
| Size (0x0000000C) |
| ihObject (0x00000002) |

**Type (4 bytes)**: 0x00000025 identifies this record type as EMR_SELECTOBJECT.

**Size (4 bytes)**: 0x0000000C specifies the size of this record in bytes.

**ihObject (4 bytes)**: 0x00000002 specifies the index of an object in the EMF object table.

### EMR_DELETEOBJECT Example 2

This section provides an example of an EMR_DELETEOBJECT record (section 2.3.8.3).

000037C0:            28 00 00 00 0C 00 00 00 04 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000028) |
| Size (0x0000000C) |
| ihObject (0x00000004) |

**Type (4 bytes)**: 0x00000028 identifies this record type as EMR_DELETEOBJECT.

**Size (4 bytes)**: 0x0000000C specifies the size of this record in bytes.

**ihObject (4 bytes)**: 0x00000004 specifies the index of the object to be deleted.

### EMR_DELETEOBJECT Example 3

This section provides an example of an EMR_DELETEOBJECT record (section 2.3.8.3).

000037D0:28 00 00 00 0C 00 00 00 03 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000028) |
| Size (0x0000000C) |
| ihObject (0x00000003) |

**Type (4 bytes)**: 0x00000028 identifies this record type as EMR_DELETEOBJECT.

**Size (4 bytes)**: 0x0000000C specifies the size of this record in bytes.

**ihObject (4 bytes)**: 0x00000003 specifies the index of the object to be deleted.

### EMR_SELECTOBJECT Example 8

This section provides an example of an EMR_SELECTOBJECT record (section 2.3.8.5).

000037D0:                                    25 00 00 00 

000037E0:0c 00 00 00 0D 00 00 80 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000025) |
| Size (0x0000000C) |
| ihObject (0x8000000D = SYSTEM_FONT) |

**Type (4 bytes)**: 0x00000025 identifies this record type as EMR_SELECTOBJECT.

**Size (4 bytes)**: 0x0000000C specifies the size of this record in bytes.

**ihObject (4 bytes)**: 0x8000000D specifies the index of an object in the EMF object table.

### EMR_EOF Example

This section provides an example of an EMR_EOF record (section 2.3.4.1).

000037E0:                        0E 00 00 00 14 00 00 00 

000037F0:00 00 00 00 10 00 00 00 14 00 00 00  

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x0000000E) |
| Size (0x00000014) |
| nPalEntries (0x00000000) |
| offPalEntries (0x00000010) |
| SizeLast (0x00000014) |

**Type (4 bytes)**: 0x0000000E identifies this record type as EMR_EOF.

**Size (4 bytes)**: 0x00000014 specifies the size of this record in bytes.

**nPalEntries (4 bytes)**: 0x00000000 specifies the number of **palette** entries.

**offPalEntries (4 bytes)**: 0x00000010 specifies the offset to the palette entries.

**SizeLast (4 bytes)**: 0x00000014 is the same as the **Size** value. It is the last field in the **metafile**.
