---
source: [MS-EMF]-240423.docx
chapter_number: 5
chapter_title: "Appendix A: Product Behavior"
word_count: 2434
---

# Appendix A: Product Behavior

The information in this specification is applicable to the following Microsoft products or supplemental software. References to product versions include updates to those products.

Windows NT 3.1 operating system

Windows NT 3.5 operating system

Windows NT 3.51 operating system

Windows NT 4.0 operating system

Windows 98 operating system

Windows Millennium Edition operating system

Windows 2000 operating system

Windows XP operating system

Windows Server 2003 operating system

Windows Vista operating system

Windows Server 2008 operating system

Windows 7 operating system

Windows Server 2008 R2 operating system

Windows 8 operating system

Windows Server 2012 operating system

Windows 8.1 operating system

Windows Server 2012 R2 operating system

Windows 10 operating system

Windows Server 2016 operating system

Windows Server operating system

Windows Server 2019 operating system

Windows Server 2022 operating system

Windows 11 operating system

Windows Server 2025 operating system 

Exceptions, if any, are noted in this section. If an update version, service pack or Knowledge Base (KB) number appears with a product name, the behavior changed in that update. The new behavior also applies to subsequent updates unless otherwise specified. If a product edition appears with the product version, behavior is different in that product edition.

Unless otherwise specified, any statement of optional behavior in this specification that is prescribed using the terms "SHOULD" or "SHOULD NOT" implies product behavior in accordance with the SHOULD or SHOULD NOT prescription. Unless otherwise specified, the term "MAY" implies that the product does not follow the prescription.

<1> Section 1.3.1: **EMF** **metafiles** have changed over the years with the evolution of Windows operating systems. They were introduced with 32-bit Windows and replaced the 16-bit **WMF** metafile [MS-WMF] as the Windows standard.

<2> Section 1.4: Windows applications that use the **GDI+** API [MSDN-GDI+] can create EMF metafiles that contain **EMF+** records ([MS-EMFPLUS] section 2.3).

<3> Section 2.1.1: Windows NT 3.1 is the only Windows version in which **GDI** uses EMR_POLYTEXTOUTA records for text output. All other versions emulate EMR_POLYTEXTOUTA with EMR_EXTTEXTOUTW records.

<4> Section 2.1.1: Windows NT 3.1 is the only Windows version in which GDI uses EMR_POLYTEXTOUTW records for text output. All other versions emulate EMR_POLYTEXTOUTW with EMR_EXTTEXTOUTW records.

<5> Section 2.1.1: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51 do not support EMR_SETICMMODE.

<6> Section 2.1.1: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51 do not support EMR_CREATECOLORSPACE.

<7> Section 2.1.1: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51 do not support EMR_SETCOLORSPACE.

<8> Section 2.1.1: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51 do not support EMR_DELETECOLORSPACE.

<9> Section 2.1.1: Windows uses an EMR_DELETEOBJECT record to delete a logical color space object.

<10> Section 2.1.1: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51 do not support EMR_GLSRECORD.

<11> Section 2.1.1: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51 do not support EMR_GLSBOUNDEDRECORD.

<12> Section 2.1.1: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51 do not support EMR_PIXELFORMAT.

<13> Section 2.1.1: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, and Windows NT 4.0 do not support **EMR_COLORCORRECTPALETTE**.

<14> Section 2.1.1: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, and Windows NT 4.0 do not support **EMR_SETICMPROFILEA**.

<15> Section 2.1.1: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, and Windows NT 4.0 do not support **EMR_SETICMPROFILEW**.

<16> Section 2.1.1: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, and Windows NT 4.0 do not support **EMR_ALPHABLEND**.

<17> Section 2.1.1: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, and Windows NT 4.0 do not support **EMR_SETLAYOUT**.

<18> Section 2.1.1: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, and Windows NT 4.0 do not support **EMR_TRANSPARENTBLT**.

<19> Section 2.1.1: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, and Windows NT 4.0 do not support **EMR_GRADIENTFILL**.

<20> Section 2.1.1: Windows GDI uses an EMR_EXTTEXTOUTW record (section 2.3.5.8) to perform this function.

<21> Section 2.1.1: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, and Windows NT 4.0 do not support **EMR_COLORMATCHTOTARGETW**.

<22> Section 2.1.1: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, and Windows NT 4.0 do not support **EMR_CREATECOLORSPACEW**.

<23> Section 2.1.11: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 98, and Windows Millennium Edition: Do not support the **ETO_GLYPH_INDEX** flag used for bitmap and **vector fonts**—in addition to **TrueType** fonts—to indicate that no further language processing is necessary and that GDI processes the string directly. See [MSDN-GDI+] for more information.

<24> Section 2.1.11: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 98, and Windows Millennium Edition: Do not support the **ETO_RTLREADING** flag used to indicate right-to-left reading order.

<25> Section 2.1.11: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 98, and Windows Millennium Edition: Do not support the **ETO_NUMERICSLOCAL** flag used to indicate the display of numeric digits appropriate to the locale.

<26> Section 2.1.11: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 98, and Windows Millennium Edition: Do not support the **ETO_NUMERICSLATIN** flag used to indicate the display of numeric digits appropriate to Europe.

<27> Section 2.1.11: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 98, and Windows Millennium Edition: Do not support the **ETO_IGNORELANGUAGE** flag used to indicate that international scripting support is not used, which might cause no text to be output.

<28> Section 2.1.11: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 98, Windows Millennium Edition, Windows NT 4.0, and Windows 2000: Do not support the **ETO_PDY** flag used to indicate that both horizontal and vertical character displacement values are provided.

<29> Section 2.1.11: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 98, Windows Millennium Edition, Windows NT 4.0, and Windows 2000: Do not support the **ETO_REVERSE_INDEX_MAP** flag.

<30> Section 2.1.16: **GM_COMPATIBLE** graphics mode is used for compatibility between 16-bit and 32-bit systems.

<31> Section 2.1.16: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 98, Windows Millennium Edition, Windows NT 4.0, and Windows 2000: **GM_ADVANCED** is not supported.

<32> Section 2.1.18: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 98, and Windows Millennium Edition: Do not support **Image Color Management (****ICM)**.

<33> Section 2.1.31: On Windows, this is the "Courier" font.

<34> Section 2.1.31: On Windows, this is the "MS Sans Serif" font.

<35> Section 2.1.31: On Windows, this is the "Tahoma" font and is used to draw menu text and dialog box controls.

Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows NT 4.0, Windows 98, and Windows Millennium Edition: The system font is "MS Sans Serif".

<36> Section 2.1.31: On Windows, this value is considered equivalent to SYSTEM_FONT for the purposes of the screen display of metafiles.

Windows 98 and Windows Millennium Edition: This value is not supported.

<37> Section 2.1.31: On Windows, this **palette** consists of the static colors in the **system palette**.

<38> Section 2.1.31: On Windows, the default user interface font is "Tahoma".

Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows NT 4.0, Windows 98, and Windows Millennium Edition: The default user interface font is "MS Sans Serif".

<39> Section 2.1.31: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows NT 4.0, Windows 98, and Windows Millennium Edition: The default brush is undefined.

<40> Section 2.1.31: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows NT 4.0, Windows 98, and Windows Millennium Edition: The default pen is undefined.

<41> Section 2.1.32: Windows also uses the following symbolic names for the StretchMode enumeration; their meanings are exactly the same as the members with the same values.

#define BLACKONWHITE                 1

#define WHITEONBLACK                 2

#define COLORONCOLOR                 3

#define HALFTONE                     4

<42> Section 2.2.2: Windows 98 and Windows Millennium Edition do not support the ColorAdjustment object.

<43> Section 2.2.2: Windows can generate ColorAdjustment objects with values outside their valid ranges. Such objects are ignored.

<44> Section 2.2.5: In Windows implementations, this is the clipping and/or opaquing rectangle that is passed to GDI methods **ExtTextOutA** and **ExtTextOutW**.

<45> Section 2.2.6: Windows does not parse the **PostScript** data in an EpsData object; the data is handed off to the graphics **printer driver** if the driver supports PostScript printing.

<46> Section 2.2.13: In Windows implementations, the **aspec****t ratio** of the device is matched against the digitization aspect ratios of the available fonts to find the closest match, determined by the absolute value of the difference.

<47> Section 2.2.13: Windows uses a **weight** value of 400 by default.

| Value | Weight |
| --- | --- |
| Thin | 100 |
| Extra Light (Ultra Light) | 200 |
| Light | 300 |
| Normal (Regular) | 400 |
| Medium | 500 |
| Semi-Bold (Demi-Bold) | 600 |
| Bold | 700 |
| Extra Bold (Ultra Bold) | 800 |
| Heavy (Black) | 900 |

<48> Section 2.2.22: Windows implementations do not support this flag.

<49> Section 2.2.22: Windows can use this flag to indicate that the pixel format specified by this structure is supported by GDI. See [MSDN-GDI+] for more information.

Windows can also use this flag to specify single-buffering for the pixel buffer.

<50> Section 2.2.22: Windows uses this flag to indicate that the pixel pixel format is supported by GDI.

<51> Section 2.2.22: Windows uses this with **OpenGL** drawing only.

Windows NT 3.1, Windows NT 3.51, Windows NT 4.0, Windows 98, Windows 2000, Windows Millennium Edition, Windows XP, and Windows Server 2003 do not support this flag.

<52> Section 2.2.22: Windows does not support **alpha** bitplanes.

<53> Section 2.2.22: Windows does not support alpha bitplanes.

<54> Section 2.2.22: Windows does not support alpha bitplanes.

<55> Section 2.2.27: In this case, Windows uses the logical font that is currently selected in the **playback device context**.

<56> Section 2.3.1.1: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, and Windows NT 4.0 do not support **EMR_ALPHABLEND**.

<57> Section 2.3.1.3: Windows might set this to a non-zero value.

<58> Section 2.3.1.8: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, and Windows NT 4.0 do not support **EMR_TRANSPARENTBLT**.

<59> Section 2.3.1.8: Windows uses the EMR_ALPHABLEND record (section 2.3.1.1) to specify a block transfer of a 32 bits-per-pixel **bitmap** with alpha transparency.

<60> Section 2.3.3.1: Windows NT 3.1, Windows NT 3.51, and Windows NT 4.0 ignore EMR_COMMENT records.

<61> Section 2.3.3.4.3: On playback, the first graphics format recognized by Windows is used to render the image.

<62> Section 2.3.4.2: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 98, and Windows Millennium Edition: EMF header extension 1 is not supported.

<63> Section 2.3.4.2: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 98, Windows Millennium Edition, Windows NT 4.0, and Windows 2000: EMF header extension 2 is not supported.

<64> Section 2.3.5.7: Windows GDI emulates EMR_EXTTEXTOUTA with an EMR_EXTTEXTOUTW record.

<65> Section 2.3.5.10:  The Windows playback implementation computes the bounding **region** from the sum of all the rectangles specified by the **RegionData** object in the **RgnData** field.

<66> Section 2.3.5.11:  The Windows playback implementation computes the bounding region from the sum of all the rectangles specified by **RgnData** field.

<67> Section 2.3.5.12: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, and Windows NT 4.0 do not support EMR_GRADIENTFILL.

<68> Section 2.3.5.12: Windows uses true colors in 24-bits-per-pixel (bpp) and 32-bpp formats, and **dithering** in 4-bpp, 8-bpp, and 16-bpp formats.

<69> Section 2.3.5.14:  The Windows playback implementation computes the bounding region from the sum of all the rectangles specified by the **RgnData** field.

<70> Section 2.3.5.32: Windows NT 3.1 is the only Windows version in which GDI uses EMR_POLYTEXTOUTA records for text output. All other versions emulate EMR_POLYTEXTOUTA with EMR_EXTTEXTOUTW records.

<71> Section 2.3.5.33: Windows NT 3.1 is the only Windows version in which GDI uses EMR_POLYTEXTOUTW records for text output. All other versions emulate EMR_POLYTEXTOUTW with EMR_EXTTEXTOUTW records.

<72> Section 2.3.7.2: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51 do not support **EMR_CREATECOLORSPACE**.

<73> Section 2.3.7.3: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51 do not support **EMR_CREATECOLORSPACEW**.

<74> Section 2.3.7.8: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, and Windows NT 4.0 metafiles contain a LogFont object in this field.

<75> Section 2.3.7.8: On Microsoft Windows, if the size of the **elw** field is less than the size of a **LogFontPanose** object, Windows GDI copies the data from the **elw** field into a zero-initialized **LogFontPanose** object and processes this new **LogFontPanose** object as input instead.

<76> Section 2.3.8.1: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, and Windows NT 4.0 do not support **EMR_COLO****RCORRECTPALETTE**.

<77> Section 2.3.8.2: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51 do not support **EMR_DELETECOLORSPACE**.

<78> Section 2.3.8.4: Windows GDI does not perform parameter validation on this value, which can lead to the generation of EMF metafiles that contain invalid EMR_RESIZEPALETTE records. Windows ignores such invalid records when processing metafiles.

<79> Section 2.3.8.7: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51 do not support **EMR_SETCOLORSPACE**.

<80> Section 2.3.9: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 98, and Windows Millennium Edition: OpenGL records are not supported.

<81> Section 2.3.11.1: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, and Windows NT 4.0 do not support **EMR_COLORMATCHTOTARGETW**.

<82> Section 2.3.11.1: On Windows NT 4.0, Windows 2000, Windows XP, and Windows Server 2003, **WCS** is not enabled in the playback device context before applying the current color transform.

<83> Section 2.3.11.3:  The Windows playback implementation computes the bounding rectangle of the region from the sum of all the rectangles specified by the **RegionData** object.

<84> Section 2.3.11.5: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51 do not support **EMR_PIXELFORMAT**.

<85> Section 2.3.11.14: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51 do not support **EMR_SETICMMODE**.

<86> Section 2.3.11.15: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, and Windows NT 4.0 do not support **EMR_SETICMPROFILEA**.

<87> Section 2.3.11.16: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, and Windows NT 4.0 do not support **EMR_SETICMPROFILEW**.

<88> Section 2.3.11.17: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, and Windows NT 4.0 do not support **EMR_SETLAYOUT**.

<89> Section 2.3.11.20:  Only Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, and Windows NT 4.0 support **EMR_SETMAPPERFLAGS**.

<90> Section 2.3.11.21: Windows GDI accepts a FLOAT value for the **miter length** limit value.

<91> Section 2.3.11.27: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows NT 4.0, Windows 98, and Windows Millennium Edition do not support the EMR_SETTEXTJUSTIFICATION record type.

<92> Section 3.1.1.2.1:  During metafile playback, before a clipping region is defined an EMF record, Windows uses a default based on the type of **device context**. in the following table, the referenced functions are described in [MSDN-WindowsGDI] unless stated otherwise.

| Device context type | Created by | Default clipping region |
| --- | --- | --- |
| Window DC | GetDC | Area of the window passed to GetDC |
| Memory DC compatible with a specified output device | CreateCompatibleDC withCreateCompatibleBitmap | Area of the compatible bitmap |
| Monitor DC | MonitorEnumProc fromEnumDisplayMonitors | Area of the display monitor |
| Printer DC | CreateDC | (**dmPelsWidth** X **dmPelsHeight**) of the DEVMODE structure [DEVMODE] input to CreateDC |
| Metafile DC | CreateMetaFile or CreateEnhMetaFile | None |
