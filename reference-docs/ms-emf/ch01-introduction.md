---
source: [MS-EMF]-240423.docx
chapter_number: 1
chapter_title: "Introduction"
word_count: 4813
---

# Introduction

**Enhanced metafile format (EMF)** is a file format that is used to store portable representations of graphical images. EMF **metafiles** contain sequential records that are parsed and processed to render the stored image on any output device.

Sections 1.7 and 2 of this specification are normative. All other sections and examples in this specification are informative.

## Glossary

This document uses the following terms:

**28.4 bit FIX notation**: A notation for representing the location of a point on a device surface to within one-sixteenth of a pixel. Each point coordinate is a 32-bit value, of which the 28 higher-order bits are the signed integral part and the 4 lower-order bits are the unsigned fractional part, in one-sixteenth units of distance. For example, the number 0x0000003C is a coordinate value of 3.75, because the fractional part is 12 sixteenths, or 0.75.

**alpha transparency**: An alpha value is a transparency value represented by a number between zero and one. Each pixel has an alpha value that represents its level of transparency, which is multiplied by the color values to get the final value. Each pixel has an alpha value that represents its level of transparency.

**American National Standards Institute (ANSI) character set**: A character set defined by a code page approved by the American National Standards Institute (ANSI). The term "ANSI" as used to signify Windows code pages is a historical reference and a misnomer that persists in the Windows community. The source of this misnomer stems from the fact that the Windows code page 1252 was originally based on an ANSI draft, which became International Organization for Standardization (ISO) Standard 8859-1 [ISO/IEC-8859-1]. In Windows, the ANSI character set can be any of the following code pages: 1252, 1250, 1251, 1253, 1254, 1255, 1256, 1257, 1258, 874, 932, 936, 949, or 950. For example, "ANSI application" is usually a reference to a non-**Unicode** or code-page-based application. Therefore, "ANSI character set" is often misused to refer to one of the character sets defined by a Windows code page that can be used as an active system code page; for example, character sets defined by code page 1252 or character sets defined by code page 950. Windows is now based on **Unicode**, so the use of ANSI character sets is strongly discouraged unless they are used to interoperate with legacy applications or legacy data.

**anisotropic**: Refers to the properties of an image, such as the scaling of logical units to device units, which are not the same regardless of the direction (x-axis versus y-axis) that is measured. Contrast with **isotropic**.

**ASCII**: The American Standard Code for Information Interchange (ASCII) is an 8-bit character-encoding scheme based on the English alphabet. ASCII codes represent text in computers, communications equipment, and other devices that work with text. ASCII refers to a single 8-bit ASCII character or an array of 8-bit ASCII characters with the high bit of each character set to zero.

**aspect ratio**: The ratio that is computed by dividing the width of a pixel on a given output device by its height.

**baseline**: The imaginary line to which the bottom of the lowercase "x" character in a font **typeface** is aligned.

**Bezier curve**: A type of curve, defined by a mathematical formula and a number of points greater than or equal to two, which is used in computer graphics and in the mathematical field of numeric analysis. A cubic **Bezier curve** is defined by four points: two endpoints and two control points. The curve does not pass through the control points, but the control points act like magnets, pulling the curve in certain directions and influencing the way the curve bends. With multiple **Bezier curves**, the endpoint of one is the starting point of the next.

**big-endian**: Multiple-byte values that are byte-ordered with the most significant byte stored in the memory location with the lowest address.

**bitmap**: A collection of structures that contain a representation of a graphical image, a **logical palette**, dimensions and other information.

**Boolean**: An operation or expression that can be evaluated only as either true or false.

**brightness**: The relative lightness or darkness of an image, or of a particular color in an image.

**cell height**: A vertical measure of font size, which is the sum of the font height and internal leading. It might not be the same as the distance between two lines of text.

**Color correction**: Altering the colors in an image in order to print or display it such that the colors correctly match reality.

**color gamut**: The entire range of colors that is available on a particular graphics output device such as a display or printer.

**color mapping**: The process of associating integer color indices with color channel values.

**color matching**: The conversion of a color, sent from its original color space, to its visually closest color in the destination color space. See also **Image Color Management (ICM)**.

**color plane**: In **bitmap** graphics, all pixel information for a single color. See also color channel.

**color profile**: A file that contains information about how to convert colors in the color space and the color gamut of a specific device into a device-independent color space. A device-specific color profile is called a "device profile". For more information on using color and device profiles, see [MSDN-UDP].

**color proofing**: The process of previewing, or proofing colors, which were developed on one device, on a different device.

**color space**: A mapping of color components to a multidimensional coordinate system. The number of dimensions is generally two, three, or four. For example, if colors are expressed as a combination of the three components red, green, and blue, a three-dimensional space is sufficient to describe all possible colors. If transparency is considered one of the components of an RGB color, four dimensions are appropriate.

**color table**: An array of data that maps pixel values into a **color space**.

**colorfulnes****s**: A concept referring to the perceived **intensity** of a specific color, the difference between a color against gray.

**compositing**: The process that takes place during image rendering, which combines color data from multiple graphics region.

**contrast**: The relative difference between lightness and darkness in an area of an image.

**coordinate space**: A space based on Cartesian coordinates, which provides a means of specifying the location of each point in the space. A two-dimensional coordinate space requires two axes that are perpendicular and equal in length. Three two-dimensional coordinate spaces are generally used to describe an output surface: world, page, and device. To scale device-independent output for a particular physical device, a rectangular area in the world or page coordinate space is mapped into the device coordinate space using a **transform**

**design vector**: A set of specific values for the font axes of a **multiple master** font.

**device context**: A collection of properties and objects that defines a dynamic environment for processes on a device. For graphics output, properties include brush style, line style, text layout, foreground and background colors, and **mapping mode**; and objects include a brush, pen, font, **palette**, **region**, and transform matrix. Multiple device contexts can exist simultaneously, but a single device context specifies the environment for graphics output at a particular point in time.

**device space**: The output space for graphics **transforms**. It usually refers to the client area of an application window; however, it can also include the entire desktop, a complete window, or a page of printer or plotter paper. Physical device space dimensions vary according to the dimensions set by the display, printer, or plotter technology.

**device-independent bitmap (DIB)**: A container for bitmapped graphics, which specifies characteristics of the **bitmap** such that it can be created using one application and loaded and displayed in another application, while retaining an identical appearance.

**dithering**: A form of digital halftoning.

**ducking**: A ducking font is one that has been designed to be short enough to fit under diacritical marks or accent marks.

**em size**: A measure of font size, which is the **cell height** minus the **internal leading**. An "em" is a term that has been used historically as a unit of typeset size.

**encapsulated PostScript (EPS)**: A file of **PostScript** raw data that describes the appearance of a single page. Although EPS data can describe text, graphics, and images; the primary purpose of an EPS file is to be encapsulated within another **PostScript** page definition.

**enhanced metafile format (EMF)**: A file format that supports the device-independent definitions of images.

**enhanced metafile format plus extensions (EMF+)**: A file format that supports the device-independent definitions of images.

**enhanced metafile spool format (EMFSPOOL)**: A format that specifies a structure of **enhanced metafile format (EMF)** records used for defining application and device-independent printer spool files.

**font axis**: A property of font design that can assume a linear range of values. In general, a font has multiple axes. For example, a font may define an axis for **weight**, along which range the possible values for that property.

**font hinting**: The use of mathematical operations to manipulate the appearance of an outline font so that it lines up with a **rasterized** grid. At small resolutions, with or without anti-aliasing, hinting is critical for producing clear, legible text for human readers.

**font mapper**: An operating system component that maps specified font attributes to available, installed fonts on the system.

**gamma correction**: In digital imaging, the process of changing the brightness, contrast, or color balance of an image by assigning new values (different colors) to gray or color tones.

**Graphics Device Interface (GDI)**: An API, supported on 16-bit and 32-bit versions of the operating system, that supports graphics operations and image manipulation on logical graphics objects.

**Graphics Device Interface, Extended (GDI+)**: A Windows API, supported on 32-bit and 64-bit versions of the operating system, that extends **GDI** to include support for Bezier curves, gradient brushes, image effects, and **EMF+** metafiles.

**halftone**: A color representation consisting of a discrete gray or tone level.

**Image Color Management (****ICM)**: Technology that ensures that a color image, graphic, or text object is rendered as closely as possible to its original intent on any device despite differences in imaging technologies and color capabilities between devices.

**inclusive-inclusive**: When referring to the bounds of a rectangle that consist of two coordinates—one coordinate for one corner and the other coordinate for the opposite corner **inclusive-inclusive** means that the coordinates are part of the rectangle. If not **inclusive-inclusive**, the coordinates are not part of the rectangle and instead are one logical unit outside the bounds of the rectangle along both coordinate axes.

**intensity**: The magnitude of a component color in the color space.

**internal leading**: The amount of space inside a character cell, within the bounds set by the font ascent. Accent marks can occur in this area.

**isotropic**: Refers to the properties of an image, such as the scaling of logical units to device units, which are the same regardless of the direction (x-axis versus y-axis) that is measured. Contrast with **anisotropic**.

**Joint Photographi****c Experts Group (JPEG)**: A raster graphics file format for displaying high-resolution color graphics. JPEG graphics apply a user-specified compression scheme that can significantly reduce the file sizes of photo-realistic color graphics. A higher level of compression results in lower quality, whereas a lower level of compression results in higher quality. JPEG-format files have a .jpg or .jpeg file name extension.

**line cap**: The shape that is used at the end of a line drawn by a graphics pen.

**line join**: The shape to use at the intersection of two lines drawn by a graphics pen.

**little-endian**: Multiple-byte values that are byte-ordered with the least significant byte stored in the memory location with the lowest address.

**logical palette**: A **palette** that defines colors as device-independent values. Unlike the **system palette**, which has predefined, device-specific color definitions, a logical palette contains color values that can be defined entirely by an application. A logical palette entry is mapped to the **system palette** entry in order for the custom colors to appear when the application is run.

**mapping mode**: The way in which logical (device-independent) coordinates are mapped to **device space** (device-specific) coordinates. It also specifies the orientation of the axes and size of the units used for drawing operations.

**metafile**: A sequence of record structures that store an image in an application-independent format. Metafile records contain drawing commands, object definitions, and configuration settings. When a metafile is processed, the stored image can be rendered on a display, output to a printer or plotter, stored in memory, or saved to a file or stream.

**miter length**: At the intersection of two lines, the distance from the intersection of the line walls on the inside of the **line join** to the intersection of the line walls on the outside of the **line join**. The miter length can be large when the angle between two lines is small. If the miter length of the join of an intersection exceeds a specified limit, the join can be beveled to keep it within the limit of the join of the intersection.

**monoscopic**: The property of an image that conveys a lack of the illusion of depth, as if the image were two-dimensional.

**multiple master**: A font technology that is a variation of the **PostScript** **Type 1 font** format. Because multiple master fonts are outline fonts, changing their size does not affect the quality of their output. Multiple master technology supports the creation of an unlimited number of custom variations of a font, called instances, as well as the emulation of **typefaces** that might not be present on the user's system.

**OpenGL**: A software API for graphics hardware that supports the rendering of multidimensional graphical objects. The Microsoft implementation of OpenGL for the Windows operating system provides industry-standard graphics software for creating high-quality still and animated three-dimensional color images. See [OPENGL] for further information.

**OpenType**: A **Unicode**-based font technology that is an extension to **TrueType** and **Type 1 font** technologies. OpenType allows **PostScript** and **TrueType** glyph definitions to reside in a common container format.

**original equipment manufacturer (OEM) character set**: A character encoding used where the mappings between characters is dependent upon the code page configured on the machine, typically by the manufacturer.

**packed DIB**: A **device-independent bitmap (DIB)** in which the bit array immediately follows the header (see [MS-WMF] section 2.2.2.9).

**page space**: A logical coordinate system used for graphics operations. It is determined by the **mapping mode**. Page space is defined with device-independent units, such as pixels.

**palette**: An array of values, each element of which contains the definition of a color. The color elements in a palette are often indexed so that clients can refer to the colors, each of which can occupy 24 bits or more, by a number that requires less storage space.

**PANOSE**: A classification system for font **typefaces** that is based on certain specific visual characteristics of the font, including **weight** (emphasis) and serif style.

**path**: A graphics object that is a container for a series of line and curve segments, and **regions** in an image.

**path bracket**: A series of **paths** that composes a larger figure. A path bracket specifies the current **path** that is defined in the **playback device context**.

**pitch**: A property of a font that describes the horizontal density of characters in a font; that is, the number of characters that can fit in a given unit of space. When all the characters in a font have the same width, the font is called "fixed-pitch"; if characters can have various widths, the font is "variable-pitch". Times New Roman is a variable-pitch font; it is easy to see that the characters in the font have different widths. For example, the width of a lowercase "i" is visibly less than the width of an uppercase "W".

**playback device context**: The **device context** that defines the current graphics state during playback of the **metafile**. Although the data in a **metafile** can be device-independent, playback is always associated with an output device with specific properties, such as resolution, color support, and so on.

**Portable Network Graphics (PNG)**: A bitmap graphics file format that uses lossless data compression and supports variable transparency of images (alpha channels) and control of image brightness on different computers (gamma correction). PNG-format files have a .png file name extension.

**PostScript**: A page description language developed by Adobe Systems that is primarily used for printing documents on laser printers. It is the standard for desktop publishing.

**print server**: A machine that hosts the print system and all its different components.

**printer driver**: The interface component between the operating system and the printer device. It is responsible for processing the application data into a page description language (PDL) that can be interpreted by the printer device.

**raster operation**: The process of combining the bits in a source **bitmap** with the bits in a destination **bitmap** and in a specified pattern, to achieve a particular graphical output.

**rasterized font**: A font produced with rasterization. Such fonts are not scalable; they define glyph **bitmaps** at specific sizes. Because of this, the appearance of rasterized fonts does not improve in proportion to the resolution of an output device. When magnified, the visual quality of a rasterized font decreases significantly compared to a **vector font**.

**rasterizer**: A program that converts geometric shapes into matrixes of discrete pixel settings on a graphics object such as a font.

**red-gree****n-blue (RGB)**: A color model that describes color information in terms of the red (R), green (G), and blue (B) intensities in a color.

**red-green-blue-alpha (RGBA)**: A color model that describes color information in terms of the red (R), green (G), blue (B), and alpha (A) intensities that comprise a color.

**reflection transform**: A **transform** that is used to create a mirror image of an object with respect to either the horizontal or vertical axis.

**region**: A graphics object that is nonrectilinear in shape and is defined by an array of scanlines.

**rotation**: A transform that is used to rotate an object. When rotation occurs, the points that make up the object are rotated with respect to the coordinate space origin.

**rotation transform**: A **transform** that is used to rotate an object. When rotation occurs, the points that make up an object are rotated with respect to the **coordinate space** origin.

**scaling transform**: A **transform** that is used to stretch or compress an object horizontally or vertically.

**shear transform**: A **transform** that is used to shear or cut an object. There are two components of a shear **transform**: The first alters the vertical lines in an object, and the second alters the horizontal lines.

**stereoscopic**: The property of an image that gives the illusion of depth, as if the image were three-dimensional. The pixels that compose such an image can include a **color plane** that is designed to add that illusion.

**stock object**: A predefined graphics object. Stock objects are standard, commonly used objects, such as a black brush and pen. The set of predefined stock objects is specified in [MS-EMF] section 2.1.31. Stock objects are neither created nor deleted.

**system palette**: The **palette** that is actually in use to reproduce colors on a device such as a computer screen. A system palette has predefined, device-specific colors that are used by default, so that individual applications do not have to set them up.

**tint**: The amount of a neutral color, such as black or white, that is mixed with another color. Changing the tint increases or decreases the lightness and saturation, and leaves the hue unchanged.

**transform**: An algorithm that transforms the size, orientation, and shape of objects that are copied from one **coordinate space** into another. Although a transform affects an object as a whole, it is applied to each point, or to each line, in the object.

**translation transform**: A **transform** that is used to shift each point in an object vertically, horizontally, or both, by a specified amount.

**TrueType**: A scalable font technology that renders fonts for both the printer and the screen.  Each TrueType font contains its own algorithms for converting printer outlines into screen **bitma****ps**, which means both the outline and **bitmap** information is **rasterized** from the same font data. The lower-level language embedded within the TrueType font allows great flexibility in its design. Both TrueType and **Type 1 font** technologies are part of the **OpenType** format.

**Type 1 font**: A public, standard type format originally developed for use with **PostScript** printers. Type 1 fonts contain two components—the outline font, used for printing; and the **bitmap** font set, used for screen display.

**typeface**: The primary design of a set of printed characters such as Courier, Helvetica, and Times Roman. The terms typeface and font are sometimes used interchangeably. A font is the particular implementation and variation of the typeface such as normal, bold, or italics. The distinguishing characteristic of a typeface is often the presence or absence of serifs.

**Unicode**: A character encoding standard developed by the Unicode Consortium that represents almost all of the written languages of the world. The **Unicode** standard [UNICODE5.0.0/2007] provides three forms (UTF-8, UTF-16, and UTF-32) and seven schemes (UTF-8, UTF-16, UTF-16 BE, UTF-16 LE, UTF-32, UTF-32 LE, and UTF-32 BE).

**UTF-16LE (Unicode Transformation Format, 16-bits, ****little-endian)**: The encoding scheme specified in [UNICODE5.0.0/2007] section 2.6 for encoding Unicode characters as a sequence of 16-bit codes, each encoded as two 8-bit bytes with the least-significant byte first.

**vector font**: A font that is defined with geometrical primitives such as points, lines, curves, and polygons, which are all based on mathematical equations instead of collections of discrete pixel settings. Vector fonts can be rendered in high quality at arbitrary sizes. Outline fonts are vector fonts. Contrast with **rasterized fonts**.

**weight**: The property of a font that specifies the degree of emphasis or boldness of the characters.

**Windows Color System (WCS)**: Color management technology that ensures a color image, graphic, or text object is rendered as closely as possible to its original intent on any device, despite differences in imaging technologies and color capabilities between devices. WCS is a superset of **ICM** APIs and functionality and includes a variety of new functions that provide significant improvements in flexibility, transparency, predictability, and extensibility for vendors. Windows NT 3.1 operating system Windows NT 3.5 operating system, Windows NT 3.51 operating system, Windows 98 operating system, and Windows Millennium Edition operating system do not support **WCS** color management.

**Windows metafile fo****rmat (WMF)**: A file format used by Windows that supports the definition of images, including a format for clip art in word-processing documents.

**world space**: The most abstract logical **coordinate ****space** for graphics **transforms**. It allows **scaling**, **translation**, **rotation**, **shearing**, and **reflection**.

**MAY, SHOULD, MUST, SHOULD NOT, MUST ****NOT:** These terms (in all caps) are used as defined in [RFC2119]. All statements of optional behavior use either MAY, SHOULD, or SHOULD NOT.

## References

Links to a document in the Microsoft Open Specifications library point to the correct section in the most recently published version of the referenced document. However, because individual documents in the library are not updated at the same time, the section numbers in the documents may not match. You can confirm the correct section numbering by checking the Errata.  

### Normative References

We conduct frequent surveys of the normative references to assure their continued availability. If you have any issue with finding a normative reference, please contact dochelp@microsoft.com. We will assist you in finding the relevant information. 

[ISO/IEC-8859-1] International Organization for Standardization, "Information Technology -- 8-Bit Single-Byte Coded Graphic Character Sets -- Part 1: Latin Alphabet No. 1", ISO/IEC 8859-1, 1998, http://www.iso.org/iso/home/store/catalogue_tc/catalogue_detail.htm?csnumber=28245

**Note **There is a charge to download the specification.

[MS-DTYP] Microsoft Corporation, "Windows Data Types".

[MS-WMF] Microsoft Corporation, "Windows Metafile Format".

[RFC2119] Bradner, S., "Key words for use in RFCs to Indicate Requirement Levels", BCP 14, RFC 2119, March 1997, https://www.rfc-editor.org/info/rfc2119

[UNICODE] The Unicode Consortium, "The Unicode Consortium Home Page", http://www.unicode.org/

### Informative References

[DEVMODE] Microsoft Corporation, "DEVMODE structure", http://msdn.microsoft.com/en-us/library/dd183565(VS.85).aspx

[MS-EMFPLUS] Microsoft Corporation, "Enhanced Metafile Format Plus Extensions".

[MS-EMFSPOOL] Microsoft Corporation, "Enhanced Metafile Spool Format".

[MSDN-GDI+] Microsoft Corporation, "GDI+", https://learn.microsoft.com/en-us/windows/desktop/gdiplus/-gdiplus-gdi-start

[MSDN-WindowsGDI] Microsoft Corporation, "Windows GDI", http://msdn.microsoft.com/en-us/library/dd145203.aspxx

[MSDN-WRLDPGSPC] Microsoft Corporation, "World-Space to Page-Space Transformations", http://msdn.microsoft.com/en-us/library/ms532657.aspx

[OPENGL] Segal, M. and Akeley, K., "The OpenGL Graphics System: A Specification, Version 2.1", December 2006, http://www.opengl.org/registry/doc/glspec21.20061201.pdf

## Overview

An **EMF** **metafile** is a sequence of variable-length records that contain drawing commands, object definitions, and graphics properties to render a graphical image on any output device. 

When an EMF metafile is "played back" on a specific device, the resulting image maintains the same dimensions, shape, proportions, color, and so on, as the original, regardless of how the metafile was created. At any given point in the playback, the state of the graphics environment is defined by the **playback device context**.

### Metafile Structure

An EMF metafile begins with a EMR_HEADER record (section 2.3.4.2), which includes the metafile version, its size, the resolution of the device on which the picture was created, and it ends with an EMR_EOF record (section 2.3.4.1). Between them are records that specify the rendering of the image.

The following diagram depicts the structures of different versions of EMF metafiles, which are:

**Original**: The original version of EMF defined a file container for the device-independent specification of images.<1>

**Extension 1**: The second version and first extension added a pixel format record and support for **OpenGL** commands, enhancing the device independence and flexibility of EMF.

**Extension 2**: The third version and second extension added the capability to measure distances on device surfaces by using the Metric system, enhancing the accuracy and scalability of EMF.

Figure 1: EMF metafile versions

EMF metafiles can be considered to have three parts:

**EMF header**: An EMR_HEADER record (section 2.3.4.2), possibly with extensions. It contains information concerning the structure and contents of the metafile, including an optional description string and pixel format descriptor.

**EMF records:** A sequence of drawing orders, property settings, and object definitions (section 2.3). At least one record is present, not counting the header and end-of-file.

**EMF end-of-file**: The EMR_EOF record (section 2.3.4.1), which is the last record in the EMF metafile.

EMF records are contiguous because the information that is available for traversing the metafile from record to record depends on it. From any given EMF record, except EMR_EOF, the length of that record can be used to move to the next record in the metafile.

### Graphics Objects

Graphics objects are used by the drawing and painting operations specified in an **EMF** **metafile**. They are created by object creation records (section 2.3.7) during the metafile playback and saved for later use.

When needed, a graphics object is be retrieved and selected into the **playback device context** by using an EMR_SELECTOBJECT record (section 2.3.8.5).

The types of reusable objects include:

Brushes (2.2.12)

Color spaces ([MS-WMF] sections 2.2.2.11 and 2.2.2.12)

Fonts (sections 2.2.13, 2.2.14, 2.2.15, and 2.2.16)

Palettes (section 2.2.17)

Pens (sections 2.2.19 and 2.2.20)

**Stock objects** are used until graphics objects are created. 

### Byte Ordering

Data in **metafile** records is stored in **little-endian** format.

Some computer architectures number bytes in a binary word from left to right, which is referred to as **big-e****ndian**. The byte numbering used for bitfields in this specification is big-endian. Other architectures number the bytes in a binary word from right to left, which is referred to as little-endian. The byte numbering used for enumerations, objects, and records in this specification is little-endian.

Using the big-endian and little-endian methods, the number 0x12345678 would be stored as shown in the following table.

| Byte order | Byte 0 | Byte 1 | Byte 2 | Byte 3 |
| --- | --- | --- | --- | --- |
| Big-endian | 0x12 | 0x34 | 0x56 | 0x78 |
| Little-endian | 0x78 | 0x56 | 0x34 | 0x12 |

For an example of how the use of the big-endian and little-endian methods can affect the compatibility of applications, see section 3.1.2.

## Relationship to Protocols and Other Structures

Several related **metafile** formats can be used together for device-independent printing. Their relationships are:

**Enhanced metafile spool format (EMFSPOOL)** records ([MS-EMFSPOOL] section 2.2) can contain EMF records.

**Enhanced metafile format (EMF)** records (section 2.3) can contain EMF+ records.<2>

**Enhanced metafile format plus extensions (EMF+)** records ([MS-EMFPLUS] section 2.3) can contain **Windows metafile format (WMF)** records ([MS-WMF] section 2.3).

This is illustrated qualitatively in the following figure.

Figure 2: Relationships of metafile record types

## Applicability Statement

**EMF** **metafiles** are portable containers for graphical output. The graphics format supported by EMF is applicable to rendering output on all devices, including displays, printers, and plotters.

## Versioning and Localization

This specification covers versioning issues in the following areas:

**Versioning:** The **EMF** structure has been revised twice. The different versions are:

Original: The first version of the EMF structure, supporting records that define drawing commands and graphics objects.

Extension 1: Added support for **OpenGL** records and an optional internal pixel format descriptor.

Extension 2: Added the capability of measuring display dimensions in micrometers.

**Localization:** This structure defines no locale-specific processes or data.

## Vendor-Extensible Fields

**EMF** **metafiles** define a mechanism for the encapsulation of arbitrary vendor-defined data. The EMR_COMMENT record (section 2.3.3.1) can contain arbitrary private data that is unknown to EMF. This data is meaningful only to applications that can decode the format of the data.
