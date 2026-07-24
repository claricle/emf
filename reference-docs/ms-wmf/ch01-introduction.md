---
source: [MS-WMF]-240423.docx
chapter_number: 1
chapter_title: "Introduction"
word_count: 4062
---

# Introduction

This is a specification of the **Windows metafile format (WMF)** structure, which can store an image in portable form. The stored image can be rendered by parsing and processing the **metafile**.

A WMF metafile is a series of variable-length records, called WMF records, that contain graphics drawing commands, object definitions and properties. The metafile begins with a header record, which includes the metafile version, its size, and the number of objects it defines. A WMF metafile is "played back" when its records are converted to a format understood by a specific graphics device.

## Glossary

This document uses the following terms:

**American National Standards Institute (ANSI) character set**: A character set defined by a code page approved by the American National Standards Institute (ANSI). The term "ANSI" as used to signify Windows code pages is a historical reference and a misnomer that persists in the Windows community. The source of this misnomer stems from the fact that the Windows code page 1252 was originally based on an ANSI draft, which became International Organization for Standardization (ISO) Standard 8859-1 [ISO/IEC-8859-1]. In Windows, the ANSI character set can be any of the following code pages: 1252, 1250, 1251, 1253, 1254, 1255, 1256, 1257, 1258, 874, 932, 936, 949, or 950. For example, "ANSI application" is usually a reference to a non-**Uni****code** or code-page-based application. Therefore, "ANSI character set" is often misused to refer to one of the character sets defined by a Windows code page that can be used as an active system code page; for example, character sets defined by code page 1252 or character sets defined by code page 950. Windows is now based on **Unicode**, so the use of ANSI character sets is strongly discouraged unless they are used to interoperate with legacy applications or legacy data.

**anti-aliasing**: The smoothing of the jagged appearance of font characters and lines, which is an artifact of the limited resolution on an output device. The pixels that surround the edges of the character glyph or line are changed to varying shades of color in order to blend the sharp edge into the background.

**ASCII**: The American Standard Code for Information Interchange (ASCII) is an 8-bit character-encoding scheme based on the English alphabet. ASCII codes represent text in computers, communications equipment, and other devices that work with text. ASCII refers to a single 8-bit ASCII character or an array of 8-bit ASCII characters with the high bit of each character set to zero.

**aspect ratio**: The ratio that is computed by dividing the width of a pixel on a given output device by its height.

**banding**: A printing technique in which an application prints an image by dividing it into a number of bands and sending each band to the printer separately.

**baseline**: The imaginary line to which the bottom of the lowercase "x" character in a font **typeface** is aligned.

**big-endian**: Multiple-byte values that are byte-ordered with the most significant byte stored in the memory location with the lowest address.

**bitmap**: A collection of structures that contain a representation of a graphical image, a **logical palette**, dimensions and other information.

**bottom-up bitmap**: A **bitmap** with an origin at the bottom-left corner.

**chromaticity**: The quality of a color as determined by the magnitudes and relative intensities of its **r****ed green blue (RGB)** components in the **color space**.

**CIEXYZ**: A widely used device-independent color standard developed by the **Commission Internationale de l'Éclairage (CIE)**. The CIEXYZ standard is based on color-matching experiments on human observers. No actual device is expected to produce colors in this **color space**. It is used as a means of converting colors from one **color space** to another. The primary colors in this **color space** are the abstract colors X, Y, and Z.

**ClearType**: A font technology developed by Microsoft that can display fractions of pixels of character glyphs and which improves the readability of text on liquid crystal displays (LCDs) and flat-panel monitors.

**clipboard**: A program provided by the operating system that enables local data transfer between applications by using the cut, copy, and paste operations.

**clipboard format**: An unsigned integer that uniquely identifies the format of a data packet that is stored in a binary large object (BLOB) and can be shared between processes through the operating system clipboard or other means.

**CMYK**: A **color space** used for commercial printing and most color computer printers. In theory, cyan, magenta, and yellow (CMY) can print all colors, but inks are not pure and black comes out muddy. The black (K) ink is required for quality black-and-white printing.

**color profile**: A file that contains information about how to convert colors in the color space and the color gamut of a specific device into a device-independent color space. A device-specific color profile is called a "device profile". For more information on using color and device profiles, see [MSDN-UDP].

**color space**: A system that describes color numerically by mapping color components to a multidimensional coordinate system. The number of dimensions is typically two, three, or four. For example, if colors are expressed as a combination of the three components red, green, and blue, a three-dimensional space can describe all possible colors. Grayscale colors can be mapped to a two-dimensional color space. If transparency is considered a component, four dimensions are appropriate. Also referred to as color model.

**color table**: An array of data that maps pixel values into a **color space**.

**Commission Internationale de l'Eclairage (CIE)**: An international Commission on Illumination in Vienna, Austria (www.cie.co.at) that sets standards for all aspects of lighting and illumination, including colorimetry, photometry, and the measurement of visible and invisible radiation.

**device context**: A collection of properties and objects that defines a dynamic environment for processes on a device. For graphics output, properties include brush style, line style, text layout, foreground and background colors, and **mapping mode**; and objects include a brush, pen, font, **palette**, **region**, and transform matrix. Multiple device contexts can exist simultaneously, but a single device context specifies the environment for graphics output at a particular point in time.

**device-independent bitmap (DIB)**: A container for bitmapped graphics, which specifies characteristics of the **bitmap** such that it can be created using one application and loaded and displayed in another application, while retaining an identical appearance.

**dithering**: A form of digital halftoning.

**encapsulated PostScript (EPS)**: A file of **PostScript** raw data that describes the appearance of a single page. Although EPS data can describe text, graphics, and images; the primary purpose of an EPS file is to be encapsulated within another **PostScript** page definition.

**enhanced metafile format (EMF)**: A file format that supports the device-independent definitions of images.

**font association**: The automatic pairing of a font that contains ideographs with a font that does not contain ideographs. Font association is used to maintain font attributes across changes in locale and allows the user to enter ideographic characters regardless of which font is selected.

**font embedding**: The process of attaching a font to a document so that the font can be used wherever the document is used, regardless of whether the font is installed on the system.

**font mapper**: An operating system component that maps specified font attributes to available, installed fonts on the system.

**gamma**: A value that describes the way brightness is distributed across the intensity spectrum by a graphics device. Depending on the device, the gamma can have a significant effect on the way colors are perceived. Technically, gamma is an expression of the relationship between input voltage and resulting output intensity. A perfect linear device would have a gamma of 1.0; a monitor or printer typically has a gamma in the range of 1.8 to 2.6, which affects midrange tones. Gamma values are used to implement gamma correction. Typically, separate gamma values are used for each component of a **color space**.

**Graphics Device Interface (GDI)**: An API, supported on 16-bit and 32-bit versions of the operating system, that supports graphics operations and image manipulation on logical graphics objects.

**International Color Consortium (ICC)**: A group established in 1993 by eight industry vendors for the purpose of creating, promoting, and encouraging the standardization and evolution of an open, vendor-neutral, cross-platform color management system architecture and components. The outcome of this cooperation was the development of the ICC profile specification. Version 4 of the specification is now widely used and has recently been approved as International Standard ISO 15076.

**isotropic**: Refers to the properties of an image, such as the scaling of logical units to device units, which are the same regardless of the direction (x-axis versus y-axis) that is measured. Contrast with anisotropic.

**Joint Photographic Experts Group (JPEG)**: A raster graphics file format for displaying high-resolution color graphics. JPEG graphics apply a user-specified compression scheme that can significantly reduce the file sizes of photo-realistic color graphics. A higher level of compression results in lower quality, whereas a lower level of compression results in higher quality. JPEG-format files have a .jpg or .jpeg file name extension.

**little-endian**: Multiple-byte values that are byte-ordered with the least significant byte stored in the memory location with the lowest address.

**logical object**: A graphics object that is defined with device-independent parameters, without assuming device specifics, such as color format or resolution.

**logical palette**: A **palette** that defines colors as device-independent values. Unlike the **system palette**, which has predefined, device-specific color definitions, a logical palette contains color values that can be defined entirely by an application. A logical palette entry is mapped to the **system palette** entry in order for the custom colors to appear when the application is run.

**mapping mode**: The way in which logical (device-independent) coordinates are mapped to device space (device-specific) coordinates. It also specifies the orientation of the axes and size of the units used for drawing operations.

**metafile**: A sequence of record structures that store an image in an application-independent format. Metafile records contain drawing commands, object definitions, and configuration settings. When a metafile is processed, the stored image can be rendered on a display, output to a printer or plotter, stored in memory, or saved to a file or stream.

**METAFILEPICT**: A structure that defines the **metafile** picture format. **METAFILEPICT** is used for exchanging **metafile** data through the **clipboard**. See [MSDN-METAFILEPICT] and [MSDN-CLIPFORM] for further information.

**n-up printing**: The act of arranging multiple logical pages on a physical sheet of paper.

**OpenType**: A **Unicode**-based font technology that is an extension to **TrueType** and **Type 1 font** technologies. OpenType allows **PostScript** and **TrueType** glyph definitions to reside in a common container format.

**outline font**: A font that is defined with mathematical equations, which makes it possible for a printer or other output device to generate the characters at any size.  In addition to being arbitrarily scalable, the appearance of an outline font improves in proportion to the resolution of an output device. **TrueType** and **PostScript** are examples of outline font technology.

**packed bitmap**: A **device-independent bitmap (DIB)** in which the bit array immediately follows a BitmapInfoHeader object.

**p****age space**: A logical coordinate system used for graphics operations. It is determined by the **mapping mode**. Page space is defined with device-independent units, such as pixels.

**palette**: An array of values, each element of which contains the definition of a color. The color elements in a palette are often indexed so that clients can refer to the colors, each of which can occupy 24 bits or more, by a number that requires less storage space.

**path**: A graphics object that is a container for a series of line and curve segments, and **regions** in an image.

**pitch**: A property of a font that describes the horizontal density of characters in a font; that is, the number of characters that can fit in a given unit of space. When all the characters in a font have the same width, the font is called "fixed-pitch"; if characters can have various widths, the font is "variable-pitch". Times New Roman is a variable-pitch font; it is easy to see that the characters in the font have different widths. For example, the width of a lowercase "i" is visibly less than the width of an uppercase "W".

**playback device context**: The **device context** that defines the current graphics state during playback of the **metafile**. Although the data in a **metafile** can be device-independent, playback is always associated with an output device with specific properties, such as resolution, color support, and so on.

**Portable Network Graphics (PNG)**: A bitmap graphics file format that uses lossless data compression and supports variable transparency of images (alpha channels) and control of image brightness on different computers (gamma correction). PNG-format files have a .png file name extension.

**PostScript**: A page description language developed by Adobe Systems that is primarily used for printing documents on laser printers. It is the standard for desktop publishing.

**Predecessor Change List (PCL)**: A set of change numbers that specify the latest versions of a messaging object in all replicas that were integrated into the current version. It is used for conflict detection.

**print job**: The rendered page description language (PDL) output data sent to a print device for a particular application or user request.

**Printer Control Language (PCL)**: A page description language (PDL) developed by Hewlett Packard for its laser and ink-jet printers.

**printer driver**: The interface component between the operating system and the printer device. It is responsible for processing the application data into a page description language (PDL) that can be interpreted by the printer device.

**raster operation**: The process of combining the bits in a source **bitmap** with the bits in a destination **bitmap** and in a specified pattern, to achieve a particular graphical output.

**rasterized font**: A font produced with rasterization. Such fonts are not scalable; they define glyph **bitmaps** at specific sizes. Because of this, the appearance of rasterized fonts does not improve in proportion to the resolution of an output device. When magnified, the visual quality of a rasterized font decreases significantly compared to a **vector font**.

**raw mode**: Refers to a spool file format that requires no further processing; it is ready to be received by the printer for which the data was formatted.

**red green blue (RGB)**: An additive color model in which red, green, and blue are combined in various ways to reproduce other colors.

**red-green-blue (RGB)**: A color model that describes color information in terms of the red (R), green (G), and blue (B) intensities in a color.

**region**: A graphics object that is nonrectilinear in shape and is defined by an array of scanlines.

**Reverse Polish Notation (RPN)**: A mathematical notation wherein each operator follows all of its operands. Also known as postfix notation.

**run-length encoding (RLE) ****compression**: A form of data compression in which repeated values are represented by a count and a single instance of the value. RLE compression can significantly reduce disk and memory space requirements.

**scanline**: A row of pixels in a **rasterized** image or **bitmap**. Multiple scanlines can be used to define the boundaries and to fill any polygon or shape.

**sRGB**: A standard, predefined **color space** that is portable across all devices and allows accurate color matching with little overhead. sRGB was developed by Hewlett-Packard and Microsoft and is specified in [IEC-RGB]. It is available to users of Windows. Windows NT 3.1 operating system, Windows NT 3.5 operating system, Windows NT 3.51 operating system, Windows 95 operating system, and Windows NT 4.0 operating system: **sRGB** color management technology is not available.

**stock object**: A predefined graphics object. Stock objects are standard, commonly used objects, such as a black brush and pen. The set of predefined stock objects is specified in [MS-EMF] section 2.1.31. Stock objects are neither created nor deleted.

**system palette**: The **palette** that is actually in use to reproduce colors on a device such as a computer screen. A system palette has predefined, device-specific colors that are used by default, so that individual applications do not have to set them up.

**top-down bitmap**: A **bitmap** with an origin at the upper-left corner.

**tri-stimulus**: The generation of color using three color components.

**TrueType**: A scalable font technology that renders fonts for both the printer and the screen.  Each TrueType font contains its own algorithms for converting printer outlines into screen **bitmaps**, which means both the outline and **bitmap** information is **rasterized** from the same font data. The lower-level language embedded within the TrueType font allows great flexibility in its design. Both TrueType and **Type 1 font** technologies are part of the **OpenType** format.

**twip**: A unit of measurement that is used in typesetting and desktop publishing. It equals one-twentieth of a printer's point, or 1/1440 of an inch.

**Type 1 font**: A public, standard type format originally developed for use with **PostScript** printers. Type 1 fonts contain two components—the **outline font**, used for printing; and the **bitmap** font set, used for screen display.

**typeface**: The primary design of a set of printed characters such as Courier, Helvetica, and Times Roman. The terms typeface and font are sometimes used interchangeably. A font is the particular implementation and variation of the typeface such as normal, bold, or italics. The distinguishing characteristic of a typeface is often the presence or absence of serifs.

**Unicode**: A character encoding standard developed by the Unicode Consortium that represents almost all of the written languages of the world. The **Unicode** standard [UNICODE5.0.0/2007] provides three forms (UTF-8, UTF-16, and UTF-32) and seven schemes (UTF-8, UTF-16, UTF-16 BE, UTF-16 LE, UTF-32, UTF-32 LE, and UTF-32 BE).

**UTF-16LE (Unicode Transformation Format, 16-bits, little-endian)**: The encoding scheme specified in [UNICODE5.0.0/2007] section 2.6 for encoding Unicode characters as a sequence of 16-bit codes, each encoded as two 8-bit bytes with the least-significant byte first.

**vector font**: A font that is defined with geometrical primitives such as points, lines, curves, and polygons, which are all based on mathematical equations instead of collections of discrete pixel settings. Vector fonts can be rendered in high quality at arbitrary sizes. **Outline fonts** are vector fonts. Contrast with **rasterized fonts**.

**white point**: A set of **tri-stimulus** values that define the color "white" in graphics image rendering. Depending on the application, different definitions of white might be needed to produce acceptable results. For example, consider a photograph taken indoors using incandescent lights, which are relatively orange compared to daylight: Defining "white" as daylight will give unacceptable results when attempting to color-correct such a photograph.

**Windows metafile format (WMF)**: A file format used by Windows that supports the definition of images, including a format for clip art in word-processing documents.

**XML Paper Specification (XPS)**: An XML-based document format. **XML Paper Specification (XPS)** specifies the set of conventions for the use of XML and other widely available technologies to describe the content and appearance of paginated documents. For more information, see [MSFT-XMLPAPER].

**MA****Y, SHOULD, MUST, SHOULD NOT, MUST NOT:** These terms (in all caps) are used as defined in [RFC2119]. All statements of optional behavior use either MAY, SHOULD, or SHOULD NOT.

## References

Links to a document in the Microsoft Open Specifications library point to the correct section in the most recently published version of the referenced document. However, because individual documents in the library are not updated at the same time, the section numbers in the documents may not match. You can confirm the correct section numbering by checking the Errata.  

### Normative References

We conduct frequent surveys of the normative references to assure their continued availability. If you have any issue with finding a normative reference, please contact dochelp@microsoft.com. We will assist you in finding the relevant information. 

[ISO/IEC-8859-1] International Organization for Standardization, "Information Technology -- 8-Bit Single-Byte Coded Graphic Character Sets -- Part 1: Latin Alphabet No. 1", ISO/IEC 8859-1, 1998, http://www.iso.org/iso/home/store/catalogue_tc/catalogue_detail.htm?csnumber=28245

**Note **There is a charge to download the specification.

[JFIF] Hamilton, E., "JPEG File Interchange Format, Version 1.02", September 1992, http://www.w3.org/Graphics/JPEG/jfif.txt

[MS-DTYP] Microsoft Corporation, "Windows Data Types".

[RFC2083] Boutell, T., et al., "PNG (Portable Network Graphics) Specification Version 1.0", RFC 2083, March 1997, https://www.rfc-editor.org/info/rfc2083

[RFC2119] Bradner, S., "Key words for use in RFCs to Indicate Requirement Levels", BCP 14, RFC 2119, March 1997, https://www.rfc-editor.org/info/rfc2119

[W3C-PNG] World Wide Web Consortium, "Portable Network Graphics (PNG) Specification, Second Edition", November 2003, http://www.w3.org/TR/PNG

### Informative References

[MS-EMF] Microsoft Corporation, "Enhanced Metafile Format".

[MSDN-CLIPFORM] Microsoft Corporation, "Clipboard Formats", http://msdn.microsoft.com/en-us/library/ms649013.aspx

## Overview

### Metafile Structure

**WMF** specifies structures for defining a graphical image. A WMF **metafile** contains drawing commands, property definitions, and graphics objects in a series of WMF records. In effect, a WMF metafile is a digital recording of an image, and the recording can be played back to reproduce that image. Because WMF metafiles are application-independent, they can be shared among applications and used for image storage.

Original WMF metafiles were device-specific; that is, the graphical images they contained would only be rendered correctly if played back on the output device for which they were recorded. To overcome this limitation, "placeable" WMF metafiles were developed, which contain an extension to the standard header with information about the placement and scaling of the image.

The following figure illustrates the high-level structures of the original and placeable forms of WMF metafile.

Figure 1: Structures of original and placeable Windows metafiles

The **META_HEADER Record** (section 2.3.2.2) contains information that defines the characteristics of the metafile, including:

The type of the metafile

The version of the metafile

The size of the metafile

The number of objects defined in the metafile

The size of the largest single record in the metafile

The **META_PLACEABLE Record** (section 2.3.2.3) contains extended information concerning the image, including:

A bounding rectangle

Logical unit size, for scaling

A checksum, for validation

WMF records have a generic format, which is specified in section 2.3. Every WMF record contains the following information:

The record size

The record function

Parameters, if any, for the record function

All WMF metafiles are terminated by a **META_EOF Record** (section 2.3.2.1).

### Graphics Objects

Graphics objects include the brushes, fonts, palettes, pens, and regions, which are used in the drawing and painting operations specified in the records of a **WMF** **metafile**. They can be defined in metafile records prior to the records that specify their use; that is, they are designed to have a lifetime outside the processing of a particular record and to be reusable during the course of playing back the metafile. The structure of WMF graphics objects is specified in section 2.2.1.

Throughout this specification, it is assumed that these reusable graphics objects are available when needed for the processing of particular metafile records. This implies that they are stored or managed in some fashion; the store of available objects is referred to in the text as the **WMF Object Table**, which is described in section 3.1.4.1. The exact characteristics of the object store are determined by the particular implementations that parse and write the metafiles. 

Records that specify drawing and painting operations can occur in a WMF metafile prior to the definition of any graphics objects. Thus, it is assumed that an initial state exists that specifies default graphics properties of the **playback device context**, including default graphics objects. Information concerning the playback device context is provided in section 3.1.5.

### Byte Ordering

Data in **WMF** **metafile** records is stored in **little-endian** format.

Some computer architectures number bytes in a binary word from left to right, which is referred to as **big-endian**. The byte numbering used for bitfields in this specification is big-endian. Other architectures number the bytes in a binary word from right to left, which is referred to as little-endian. The byte numbering used for enumerations, objects, and records in this specification is little-endian.

Using big-endian and little-endian methods, the number 0x12345678 would be stored as shown in the following.

| Byte order | Byte 0 | Byte 1 | Byte 2 | Byte 3 |
| --- | --- | --- | --- | --- |
| Big-endian | 0x12 | 0x34 | 0x56 | 0x78 |
| Little-endian | 0x78 | 0x56 | 0x34 | 0x12 |

## Relationship to Protocols and Other Structures

**WMF** is not dependent on any protocols or other structures. WMF defines a design and layout based on 16-bit operating systems.<1>

On 32-bit systems and for print spooling, it has been replaced by **EMF**, described in [MS-EMF].

## Applicability Statement

Structures that are compliant with **WMF** are portable, application-independent containers for images. The graphics supported in WMF **metafiles** are applicable to document content representation, including printing and plotting.

## Versioning and Localization

This specification covers versioning issues in the following areas:

**Structure Versions**: There is only one version of the WMF structure.

**Localization**: This structure defines no locale-specific processes or data.

## Vendor-Extensible Fields

The **WMF** defines a mechanism for the encapsulation of arbitrary, vendor-defined data. See section 2.3.6.1 for details.
