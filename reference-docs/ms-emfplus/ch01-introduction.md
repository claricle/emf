---
source: [MS-EMFPLUS]-240423.docx
chapter_number: 1
chapter_title: "Introduction"
word_count: 5692
---

# Introduction

The Enhanced Metafile Format Plus Extensions (EMF+) file structure specifies a **metafile** format that can store a picture in a device-independent form. The stored picture can be rendered by parsing and processing the metafile.

An **EMF+** metafile is a series of variable-length records, called EMF+ records, which contain graphics drawing commands, object definitions, and properties. The metafile begins with a header record, which includes the metafile version, its size, the resolution of the device on which the picture was created, and the dimensions of the picture. An EMF+ metafile is "played back" when its records are converted to a format understood by a specific graphics device. An image defined in an EMF+ structure maintains its dimensions, shape, and proportions on any output device, including printers, plotters, and desktops, or in the client areas of applications.

Sections 1.7 and 2 of this specification are normative. All other sections and examples in this specification are informative.

## Glossary

This document uses the following terms:

**affine transform**: A matrix operation that consists of a linear **transform** followed by a **translation**. An affine transform can be used to correct perspective distortions by transforming the measurements from **world space** to **device space** coordinates.

**alpha blending**: In computer graphics, the process of combining an image with a background to create the appearance of partial transparency. The extent of blending is determined by the value of the **alpha** component of the color being rendered.

**alpha transparency**: An alpha value is a transparency value represented by a number between zero and one. Each pixel has an alpha value that represents its level of transparency, which is multiplied by the color values to get the final value. Each pixel has an alpha value that represents its level of transparency.

**American National Standards Institute (ANSI) character set**: A character set defined by a code page approved by the American National Standards Institute (ANSI). The term "ANSI" as used to signify Windows code pages is a historical reference and a misnomer that persists in the Windows community. The source of this misnomer stems from the fact that the Windows code page 1252 was originally based on an ANSI draft, which became International Organization for Standardization (ISO) Standard 8859-1 [ISO/IEC-8859-1]. In Windows, the ANSI character set can be any of the following code pages: 1252, 1250, 1251, 1253, 1254, 1255, 1256, 1257, 1258, 874, 932, 936, 949, or 950. For example, "ANSI application" is usually a reference to a non-**Unicode** or code-page-based application. Therefore, "ANSI character set" is often misused to refer to one of the character sets defined by a Windows code page that can be used as an active system code page; for example, character sets defined by code page 1252 or character sets defined by code page 950. Windows is now based on **Unicode**, so the use of ANSI character sets is strongly discouraged unless they are used to interoperate with legacy applications or legacy data.

**anti-aliasing**: The smoothing of the jagged appearance of font characters and lines, which is an artifact of the limited resolution on an output device. The pixels that surround the edges of the character glyph or line are changed to varying shades of color in order to blend the sharp edge into the background.

**ASCII**: The American Standard Code for Information Interchange (ASCII) is an 8-bit character-encoding scheme based on the English alphabet. ASCII codes represent text in computers, communications equipment, and other devices that work with text. ASCII refers to a single 8-bit ASCII character or an array of 8-bit ASCII characters with the high bit of each character set to zero.

**baseline**: The imaginary line to which the bottom of the lowercase "x" character in a font **typeface** is aligned.

**Bezier curve**: A type of curve, defined by a mathematical formula and a number of points greater than or equal to two, which is used in computer graphics and in the mathematical field of numeric analysis. A cubic **Bezier curve** is defined by four points: two endpoints and two control points. The curve does not pass through the control points, but the control points act like magnets, pulling the curve in certain directions and influencing the way the curve bends. With multiple **Bezier curves**, the endpoint of one is the starting point of the next.

**big-endian**: Multiple-byte values that are byte-ordered with the most significant byte stored in the memory location with the lowest address.

**bitmap**: A collection of structures that contain a representation of a graphical image, a logical palette, dimensions and other information.

**black saturation**: The low end of the range of **saturation** for a **color channel**.

**blur effect**: An **image effect** that is used to remove detail, resulting in an image that appears as if viewed through a translucent lens. A Gaussian blur uses a Gaussian distribution to calculate changes to individual pixels in the image. A Gaussian distribution is a statistical probability distribution that produces a "bell curve".

**box filter**: An **anti-aliasing** algorithm that averages the pixels in a rectangular area to compute a new value for the pixels. It is useful only for reducing the size of images.

**brightness**: The relative lightness or darkness of an image, or of a particular color in an image.

**brightness contrast effect**: An **image effect** that is used to change the **intensity** of an image by expanding or contracting the lightest and darkest areas of an image.

**cardinal spline**: A **spline** with curves that pass smoothly through each of its control points. The degree of curvature is defined by a tension parameter. The curve has no sharp corners or abrupt changes. A complete derivation of the cubic polynomials for the canonical **spline** can be found in [SPLINE77]. See also [PETZOLD] for more information.

**cell height**: A vertical measure of font size, which is the sum of the font height and internal leading. It might not be the same as the distance between two lines of text.

**ClearType**: A font technology developed by Microsoft that can display fractions of pixels of character glyphs and which improves the readability of text on liquid crystal displays (LCDs) and flat-panel monitors.

**closed cardinal spline**: A **cardinal spline** with a curve that passes through the last defined point and connects with the first.

**color balance effect**: An **image effect** that produces optimal color display by adjusting the relative amounts of red, green, and blue in the image.

**color channel**: A component color from which all colors in an image are rendered. In an RGB color space, there are color channels for red, green, and blue. In a grayscale color space, the color channels are black and white. Color channel values typically range from 0 to 255.

**color curve**: A graphical mechanism for displaying and adjusting color measurements of an image. The points on a color curve correspond to the pure colors in a color space.

**color curve effect**: An **image effect** that is used to apply one of eight adjustments to the **color curve** of an image: **exposure**, **density**, **contrast**, **highlight**, **shadow**, **midtone**, **white saturation**, and **black saturation**.

**color lookup table effect**: An **image effect** that is used to make custom color adjustments to images. A lookup table is defined for four individual **color channels**: **alpha** (transparency), red, green, and blue. Each lookup table is an array of 256 bytes that can be set to specific values.

**color mapping**: The process of associating integer color indices with **color channel** values.

**color matrix**: A matrix of floating-point values from zero to one, inclusive, that can be multiplied with a **color vector** to effect a color **transform**. A 4x4 matrix can be used to perform linear **transforms**, and a 5x5 matrix can be used to perform nonlinear **transforms**.

**color matrix effect**: An **image effect** that uses a 5x5 **color matrix** to perform an **affine transform** to the **color vectors** of an image.

**color vector**: An **RGB** plus **alpha** value that represents a specific color and transparency. Each value is in the range of zero to one, inclusive; for red, green and blue, zero means no **intensity** of the color and one means maximum **intensity**.

**color wheel**: An organization of color **hues** around a circle, showing relationships between colors considered to be primary, secondary, and complementary. In an **RGB** color space, red, green, and blue primary colors are arranged at equally spaced points around the circle. Magenta, yellow, and cyan secondary colors and tertiary mixtures are located at intermediate points on the circle. The center is white or gray.

**compositing**: The process that takes place during image rendering, which combines color data from multiple graphics region.

**contrast**: The relative difference between lightness and darkness in an area of an image.

**coordinate space**: A space based on Cartesian coordinates, which provides a means of specifying the location of each point in the space. A two-dimensional coordinate space requires two axes that are perpendicular and equal in length. Three two-dimensional coordinate spaces are generally used to describe an output surface: world, page, and device. To scale device-independent output for a particular physical device, a rectangular area in the world or page coordinate space is mapped into the device coordinate space using a **transform**

**density**: A measure of image opacity; that is, the amount of light that passes through photographic film at a particular location.

**device context**: A collection of properties and objects that defines a dynamic environment for processes on a device. For graphics output, properties include brush style, line style, text layout, foreground and background colors, and mapping mode; and objects include a brush, pen, font, **palette**, **region**, and transform matrix. Multiple device contexts can exist simultaneously, but a single device context specifies the environment for graphics output at a particular point in time.

**device driver**: The software that the system uses to communicate with a device such as a display, printer, mouse, or communications adapter. An abstraction layer that restricts access of applications to various hardware devices on a given computer system. It is often referred to simply as a "driver".

**device space**: The output space for graphics **transforms**. It usually refers to the client area of an application window; however, it can also include the entire desktop, a complete window, or a page of printer or plotter paper. Physical device space dimensions vary according to the dimensions set by the display, printer, or plotter technology.

**device-independent bitmap (DIB)**: A container for bitmapped graphics, which specifies characteristics of the **bitmap** such that it can be created using one application and loaded and displayed in another application, while retaining an identical appearance.

**dithering**: A form of digital **halftoning**.

**em size**: A measure of font size, which is the **cell height** minus the internal leading. An "em" is a term that has been used historically as a unit of typeset size.

**enhanced metafile format (EMF)**: A file format that supports the device-independent definitions of images.

**enhanced metafile format plus extensions (EMF+)**: A file format that supports the device-independent definitions of images.

**enhanced metafile spool format (EMFSPOOL)**: A format that specifies a structure of **enhanced metafile format (EMF)** records used for defining application and device-independent printer spool files.

**Exchangeable Image File Format (EXIF)**: A de facto standard format for storing files containing digital photographic images and audio files. EXIF uses existing formats for data compression, including **JPEG** and TIFF; but it is not supported by older versions of **JPEG**, **PNG**, or **GIF**. EXIF specifies metadata tags for storing information about a photographic image, including camera make and model, shutter speed, exposure compensation, F-stop, the metering system, whether a flash was used, the date and time the photograph was taken, auxiliary lenses that were used, the resolution, and a thumbnail image for previewing the photograph. EXIF is specified in [EXIF].

**exposure**: A measure of the amount of light in which a photographic image is recorded. Overexposed images are lighter than normal; underexposed images are darker than normal.

**font axis**: A property of font design that can assume a linear range of values. In general, a font has multiple axes. For example, a font may define an axis for **weight**, along which range the possible values for that property.

**font family**: A set of fonts that all have common stroke width and serif characteristics. For example, Times Roman and Times Roman Italic are members of the same font family.

**gamma**: A value that describes the way brightness is distributed across the intensity spectrum by a graphics device. Depending on the device, the gamma can have a significant effect on the way colors are perceived. Technically, gamma is an expression of the relationship between input voltage and resulting output intensity. A perfect linear device would have a gamma of 1.0; a monitor or printer typically has a gamma in the range of 1.8 to 2.6, which affects midrange tones. Gamma values are used to implement **gamma correction**. Typically, separate gamma values are used for each component of a color space.

**gamma correction**: In digital imaging, the process of changing the brightness, contrast, or color balance of an image by assigning new values (different colors) to gray or color tones.

**globally unique identifier (GUID)**: A term used interchangeably with universally unique identifier (UUID) in Microsoft protocol technical documents (TDs). Interchanging the usage of these terms does not imply or require a specific algorithm or mechanism to generate the value. Specifically, the use of this term does not imply or require that the algorithms described in [RFC4122] or [C706] must be used for generating the **GUID**. See also universally unique identifier (UUID).

**gradient line**: The line in a color space along which color variation is greatest.

**Graphics Device Interface (GDI)**: An API, supported on 16-bit and 32-bit versions of the operating system, that supports graphics operations and image manipulation on logical graphics objects.

**Graphics Device Interface, Extended (GDI+)**: A Windows API, supported on 32-bit and 64-bit versions of the operating system, that extends **GDI** to include support for Bezier curves, gradient brushes, image effects, and **EMF+** metafiles.

**Graphics Interchange Format (GIF)**: A compression format that supports device-independent transmission and interchange of bitmapped image data. The format uses a palette of up to 256 distinct colors from the 24-bit **RGB** color space. It also supports animation and a separate palette of 256 colors for each frame. The color limitation makes the GIF format unsuitable for reproducing color photographs and other images with gradients of color, but it is well-suited for simpler images such as graphics with solid areas of color.

**grayscale**: A continuum of shades of gray that are used to represent an image. Continuous-tone images, such as black-and-white photographs, use an almost unlimited number of shades of gray. Conventional computer hardware and software, however, can represent only a limited number of gray shades, typically 16 or 256. Grayscaling is the process of converting a continuous-tone image to an image that a computer can manipulate. Note that grayscaling is different from **dithering**. **Dithering** simulates shades of gray by altering the density and pattern of black and white dots. In grayscaling, each individual dot can have a different shade of gray.

**halftoning**: The process of converting **grayscale**, or continuous-tone graphics or images, to a representation with a discrete number of gray (or tone) levels.

**highlight**: The lightest tones in an image.

**hotkey prefix**: In a graphical user interface, the underlined letter in a word that can be pressed in combination with another key, such as the Alt key, to activate the functionality that the word represents.

**hue**: A color as defined by its name, such as blue. More precisely, hue is defined as the coordinates of a color in a color space, which specify the relative magnitudes along its axes.

**hue saturation lightness effect**: An **image effect** that is used to identify the basic color properties of an image, including **hue**, **saturation**, and **lightness**.

**Image Color Management (ICM)**: Technology that ensures that a color image, graphic, or text object is rendered as closely as possible to its original intent on any device despite differences in imaging technologies and color capabilities between devices.

**image effect**: A graphics process for changing the appearance of an image to produce a specific effect, including applying a **transform**, improving the quality of rendering, emphasizing or hiding a feature, creating a style, accounting for device limitations, and changing colors. The image effects specified in **EMF+** **metafiles** include **blur**, brightness contrast, color balance, **color curv****e**, color lookup table, **color matrix**, hue saturation lightness, levels, **red-eye correction**, sharpen, and **tint**.

**intensity**: The magnitude of a component color in the color space.

**Joint Photographic Experts Group (JPEG)**: A raster graphics file format for displaying high-resolution color graphics. JPEG graphics apply a user-specified compression scheme that can significantly reduce the file sizes of photo-realistic color graphics. A higher level of compression results in lower quality, whereas a lower level of compression results in higher quality. JPEG-format files have a .jpg or .jpeg file name extension.

**language code identifier (LCID)**: A 32-bit number that identifies the user interface human language dialect or variation that is supported by an application or a client computer.

**levels effect**: An **image effect** that is used to apply **highlight**, **midtone**, or **shadow** adjustments to an image. **Highlights** are the light parts of an image, **shadows** are the dark parts, and **midtones** are the colors that occupy the middle of the tonal range between the **highlights** and the **shadows**.

**lightness**: The **brightness** or **intensity** of a color, from dark to light; or more precisely, the magnitude of the coordinates of a point in a color space.

**line cap**: The shape that is used at the end of a line drawn by a graphics pen.

**little-endian**: Multiple-byte values that are byte-ordered with the least significant byte stored in the memory location with the lowest address.

**metafile**: A sequence of record structures that store an image in an application-independent format. Metafile records contain drawing commands, object definitions, and configuration settings. When a metafile is processed, the stored image can be rendered on a display, output to a printer or plotter, stored in memory, or saved to a file or stream.

**midtone**: The tones in an image between **hig****hlight** and **shadow**.

**miter length**: At the intersection of two lines, the distance from the intersection of the line walls on the inside of the line join to the intersection of the line walls on the outside of the line join. The miter length can be large when the angle between two lines is small. If the miter length of the join of an intersection exceeds a specified limit, the join can be beveled to keep it within the limit of the join of the intersection.

**OpenGL**: A software API for graphics hardware that supports the rendering of multidimensional graphical objects. The Microsoft implementation of OpenGL for the Windows operating system provides industry-standard graphics software for creating high-quality still and animated three-dimensional color images. See [OPENGL] for further information.

**page space**: A logical coordinate system used for graphics operations. It is determined by the mapping mode. Page space is defined with device-independent units, such as pixels.

**palette**: An array of values, each element of which contains the definition of a color. The color elements in a palette are often indexed so that clients can refer to the colors, each of which can occupy 24 bits or more, by a number that requires less storage space.

**path**: A graphics object that is a container for a series of line and curve segments, and **regions** in an image.

**playback device context**: The **device context** that defines the current graphics state during playback of the **metafile**. Although the data in a **metafile** can be device-independent, playback is always associated with an output device with specific properties, such as resolution, color support, and so on.

**Portable Net****work Graphics (PNG)**: A bitmap graphics file format that uses lossless data compression and supports variable transparency of images (alpha channels) and control of image brightness on different computers (gamma correction). PNG-format files have a .png file name extension.

**raster operation**: The process of combining the bits in a source **bitmap** with the bits in a destination **bitmap** and in a specified pattern, to achieve a particular graphical output.

**red-eye correction effect**: An **image effect** that is used to correct the red eyes that sometimes occur in flash photographs as a result of the reflection of light from the flash.

**red-green-blue (RGB)**: A color model that describes color information in terms of the red (R), green (G), and blue (B) intensities in a color.

**reflection transform**: A **transform** that is used to create a mirror image of an object with respect to either the horizontal or vertical axis.

**region**: A graphics object that is nonrectilinear in shape and is defined by an array of scanlines.

**rotation**: A transform that is used to rotate an object. When rotation occurs, the points that make up the object are rotated with respect to the coordinate space origin.

**run-length encoding (RLE) compression**: A form of data compression in which repeated values are represented by a count and a single instance of the value. RLE compression can significantly reduce disk and memory space requirements.

**saturation**: The "purity" of a **hue**; or, more precisely, the **intensity** of one **color channel** relative to the **intensity** of the other **color channels**. Maximum saturation occurs when the **intensity** of a particular **color channel** is maximum and the intensities of the other **color channels** are minimum. Minimum saturation occurs when the intensities of all **color channels** are the same.

**scaling transform**: A **transform** that is used to stretch or compress an object horizontally or vertically.

**shadow**: The darkest tones in an image.

**sharpen effect**: An **image effect** that is used to adjust the sharpness of an image. Sharpening increases image **contrast** by enhancing the definition of the image edges.

**shear transform**: A **transform** that is used to shear or cut an object. There are two components of a shear **transform**: The first alters the vertical lines in an object, and the second alters the horizontal lines.

**spline**: A sequence of individual curves joined to form a larger curve. A spline is specified by an array of points and a tension parameter.

**Tag Image File Format (TIFF)**: A format for bitmapped image data that comes from scanners, frame grabbers, and photo-retouching applications. It supports the exchange of image data between applications, taking advantage of the varying capabilities of imaging devices. TIFF supports a number of compression schemes that allow the choice of the best space or time tradeoff for applications. For more information see [RFC3302] and [TIFF].

**tent filter**: A filtering algorithm in which pixels around a target pixel are weighted linearly based on their distance from the center of the target pixel.

**ter****minal server**: The computer on which nearly all computing resources reside that are used in a terminal services networking environment. The terminal server receives and processes keystrokes and mouse movements that take place on the client computer. The terminal server displays the desktop and running applications within a window on the client computer.

**text hinting**: A mathematical process for adjusting the display of a font so that it lines up with a grid of pixels. At small screen sizes, hinting produces clearer text.

**tint**: The amount of a neutral color, such as black or white, that is mixed with another color. Changing the tint increases or decreases the **lightness** and **saturation**, and leaves the **hue** unchanged.

**tint effect**: An **image effect** that is used to apply a **tint** to an image. A **tint** is created by adding white to a color.

**transform**: An algorithm that transforms the size, orientation, and shape of objects that are copied from one **coordinate space** into another. Although a transform affects an object as a whole, it is applied to each point, or to each line, in the object.

**translation ****transform**: A **transform** that is used to shift each point in an object vertically, horizontally, or both, by a specified amount.

**TrueType**: A scalable font technology that renders fonts for both the printer and the screen.  Each TrueType font contains its own algorithms for converting printer outlines into screen **bitmaps**, which means both the outline and **bitmap** information is rasterized from the same font data. The lower-level language embedded within the TrueType font allows great flexibility in its design. Both TrueType and Type 1 font technologies are part of the OpenType format.

**typeface**: The primary design of a set of printed characters such as Courier, Helvetica, and Times Roman. The terms typeface and font are sometimes used interchangeably. A font is the particular implementation and variation of the typeface such as normal, bold, or italics. The distinguishing characteristic of a typeface is often the presence or absence of serifs.

**Unicode**: A character encoding standard developed by the Unicode Consortium that represents almost all of the written languages of the world. The **Unicode** standard [UNICODE5.0.0/2007] provides three forms (UTF-8, UTF-16, and UTF-32) and seven schemes (UTF-8, UTF-16, UTF-16 BE, UTF-16 LE, UTF-32, UTF-32 LE, and UTF-32 BE).

**weight**: The property of a font that specifies the degree of emphasis or boldness of the characters.

**white saturation**: The high end of the range of **saturation** for a **color channel**.

**Windows metafile format (WMF)**: A file format used by Windows that supports the definition of images, including a format for clip art in word-processing documents.

**world space**: The most abstract logical **coordinate space** for graphics **transforms**. It allows **scaling**, **translation**, **rotation**, **shearing**, and **reflection**.

**MAY, SHOULD, MUST, SHOULD NOT, MUST NOT:** These terms (in all caps) are used as defined in [RFC2119]. All statements of optional behavior use either MAY, SHOULD, or SHOULD NOT.

## References

Links to a document in the Microsoft Open Specifications library point to the correct section in the most recently published version of the referenced document. However, because individual documents in the library are not updated at the same time, the section numbers in the documents may not match. You can confirm the correct section numbering by checking the Errata.  

### Normative References

We conduct frequent surveys of the normative references to assure their continued availability. If you have any issue with finding a normative reference, please contact dochelp@microsoft.com. We will assist you in finding the relevant information. 

[EXIF] Standard of Japan Electronics and Information Technology Industries Association (JEITA), "Exif Exchange Image File Format, Version 2.2", Version 2.2, February, 2014, https://www.loc.gov/preservation/digital/formats/fdd/fdd000146.shtml

[GIF] Compuserve, Inc., "Graphics Interchange Format", 1989, http://www.piclist.com/techref/fileext/gif/gif89a.htm

[IEC-RGB] International Electrotechnical Commission, "Colour Measurement and Management in Multimedia Systems and Equipment - Part 2-1: Default RGB Colour Space - sRGB", October 1999, http://webstore.iec.ch/webstore/webstore.nsf/artnum/025408

[ISO/IEC-8859-1] International Organization for Standardization, "Information Technology -- 8-Bit Single-Byte Coded Graphic Character Sets -- Part 1: Latin Alphabet No. 1", ISO/IEC 8859-1, 1998, http://www.iso.org/iso/home/store/catalogue_tc/catalogue_detail.htm?csnumber=28245

**Note **There is a charge to download the specification.

[JFIF] Hamilton, E., "JPEG File Interchange Format, Version 1.02", September 1992, http://www.w3.org/Graphics/JPEG/jfif.txt

[MS-DTYP] Microsoft Corporation, "Windows Data Types".

[MS-EMF] Microsoft Corporation, "Enhanced Metafile Format".

[MS-LCID] Microsoft Corporation, "Windows Language Code Identifier (LCID) Reference".

[MS-WMF] Microsoft Corporation, "Windows Metafile Format".

[RFC2083] Boutell, T., et al., "PNG (Portable Network Graphics) Specification Version 1.0", RFC 2083, March 1997, https://www.rfc-editor.org/info/rfc2083

[RFC2119] Bradner, S., "Key words for use in RFCs to Indicate Requirement Levels", BCP 14, RFC 2119, March 1997, https://www.rfc-editor.org/info/rfc2119

[RFC3302] Parsons, G., and Rafferty, J., "Tag Image File Format (TIFF) - image/tiff MIME Sub-Type Registration", RFC 3302, September 2002, https://www.rfc-editor.org/info/rfc3302

[TIFF] Adobe Developers Association, "TIFF 6.0 Specification", June 1992, https://www.itu.int/itudoc/itu-t/com16/tiff-fx/docs/tiff6.pdf

[W3C-PNG] World Wide Web Consortium, "Portable Network Graphics (PNG) Specification, Second Edition", November 2003, http://www.w3.org/TR/PNG

### Informative References

[MS-EMFSPOOL] Microsoft Corporation, "Enhanced Metafile Spool Format".

[MSDN-DrawBeziers] Microsoft Corporation, "Graphics.DrawBeziers(const Pen*, const PointF*, INT) method", http://msdn.microsoft.com/en-us/library/windows/desktop/ms536147(v=vs.85).aspx

[MSDN-GDI+] Microsoft Corporation, "GDI+", https://learn.microsoft.com/en-us/windows/desktop/gdiplus/-gdiplus-gdi-start

[PETZOLD] Petzold, C., "Programming Windows, Fifth Edition", Microsoft Press, 1998, ISBN: 157231995X.

[SPLINE77] Smith, A., "Spline Tutorial Notes - Technical Memo No. 77", SIGGRAPH '83 Tutorial Notes: Introduction to Computer Animation, pp. 64-75, July, 1983.

## Overview

### Metafile Structure

**EMF+** defines a set of graphical images and text using commands, objects, and properties similar to Windows **GDI+** [MSDN-GDI+]. EMF+ metafiles are portable, device-independent containers for graphical images, and they are used for sending commands and objects to output devices, such as displays and printers, which support the drawing of images and text. The device or media that receives such a **metafile** can be located on a network, or it can be connected directly to the computer running the operating system on which the metafile is created.

EMF+ metafiles are actually a form of **EMF** metafile in which EMF+ records (section 2.3) are embedded in EMF records ([MS-EMF] section 2.3). Embedding EMF+ records in EMF metafiles is possible because of the EMF capability to embed arbitrary private data in certain types of records. This is illustrated by the figure that follows. Note that multiple EMF+ records can be embedded in a single EMF record.

The EMF record in which arbitrary private data can be embedded is called an **EMF comment record** (EMR_COMMENT_EMFPLUS, [MS-EMF] section 2.3.3.2).

As shown in the following figure, the first EMF+ record in the metafile, the **EMF+ header record** (EmfPlusHeader, section 2.3.3.3), is embedded within the first EMF record following the **EMF header record** (EMR_HEADER, [MS-EMF] section 2.3.4.2); and the last EMF+ record, the **EMF+ end of file re****cord** (EmfPlusEndOfFile, section 2.3.3.1), is embedded within the EMF record immediately preceding the **EMF end of file record** (EMR_EOF, [MS-EMF] section 2.3.4.1).

Figure 1: EMF+ metafiles

In the EMF metafile in this figure, Case I shows a group of EMF+ records, followed by some EMF records, followed by another group of EMF+ records; and Case II shows a group of EMF+ records terminated by an EMF+ **get device context** record (EmfPlusGetDC,** **section 2.3.3.2), followed by some EMF records, followed by another group of EMF+ records. The presence or absence of the get device context record can determine how the metafile is processed.

The structure of an EMF+ metafile is such that EMF+ records are embedded in EMF records, meaning that the following EMF records are always present:

EMF header: Required for all types of metafiles

EMF comment: Required to contain EMF+ records

EMF end of file: Required for all types of metafiles

The EMF+ header record contains flags that distinguish between the following two different types of EMF+ metafiles.<1>

Metafiles identified as **EMF+ Only** can contain both EMF+ records and EMF records. All EMF+ records are used to render the image. The EMF records that are part of the drawing are those preceded by an EMF+ get device context record—case II in the figure above. EMF record processing stops when the next EMF+ record of any type is encountered.

If a system that cannot play back EMF+ records attempts to play the metafile by using only EMF records, the drawing might be incomplete. If a system performs EMF+ playback mode as expected, then no EMF drawing records are processed unless they are preceded by an EMF+ get device context record. For example, in case I, an EMF+ Only playback mode would process the EMF control records and none of the EMF drawing records. As a result, EMF records alone are not sufficient to render a drawing that was recorded in an EMF+ Only metafile.

Metafiles identified as **EMF+ Dual** can also contain both EMF+ records and EMF records. The EMF+ Dual flag indicates that the metafile contains a complete set of EMF records sufficient to correctly render the entire drawing on a system that cannot playback EMF+ records. This feature makes it possible to render an image with different levels of graphics support in the operating system. However, only one or the other type of records is processed. All records are enumerated sequentially. For EMF playback, the metafile player only uses EMF records and ignores EMF+ records. For EMF+ playback, the metafile is played as if it is EMF+ Only.

Regardless of the EMF+ Dual flag setting, EMF records that follow an EMF+ get device context record are played, until the next EMF+ record, EMF header record, or EMF end of file record.

**Note: **EMF+ is not considered an extension to the EMF feature set; that is, EMF+ does not define new EMF records. EMF+ is semantically a completely separate, independent format. EMF+ records define graphical images and text using commands, objects, and properties of GDI+.

### Byte Ordering

Data in the **EMF+** **metafile** records are stored in **little-endian** format.

Some computer architectures number bytes in a binary word from left to right, which is referred to as **big-endian**. The byte numbering used for bitfields in this specification is big-endian. Other architectures number the bytes in a binary word from right to left, which is referred to as little-endian. The byte numbering used for enumerations, objects, and records in this specification is little-endian.

Using the big-endian and little-endian methods, the number 0x12345678 would be stored as shown in the following table.

| Byte order | Byte 0 | Byte 1 | Byte 2 | Byte 3 |
| --- | --- | --- | --- | --- |
| Big-endian | 0x12 | 0x34 | 0x56 | 0x78 |
| Little-endian | 0x78 | 0x56 | 0x34 | 0x12 |

## Relationship to Protocols and Other Structures

Several related **metafile** formats can be used together for device-independent printing. Their relationships are as follows:

**Enhanced metafile spool format (EMFSPOOL)** records ([MS-EMFSPOOL] section 2.2) can contain EMF records.

**Enhanced metafile format (EMF)** records ([MS-EMF] section 2.3) can contain EMF+ records.<2>

**Enhanced metafile format plus extensions (EMF+)** records (section 2.3) can contain **Windows metafile format (WMF)** records ([MS-WMF] section 2.3).

This is illustrated qualitatively in the following figure:

Figure 2: Relationships of metafile record types

## Applicability Statement

Structures that are compliant with the EMF+ can be used as portable, system-independent containers for images. The graphics supported in **EMF+** metafiles are applicable to document content representation, including printing and plotting.

## Versioning and Localization

This specification covers versioning issues in the following areas:

**Structure Versions**: Multiple versions of the **EMF+** metafiles exist. For more information, see the GraphicsVersion enumeration.

**Localization**: EMF+ structures contain the following locale-specific data:

Language identifiers that correspond to natural languages in locales, including countries, geographical regions, and administrative districts. For details, see [MS-LCID] section 2.1.

String digit substitution values specify how to substitute digits in a string according to a locale or language. For more information, see the StringDigitSubstitute enumeration.

## Vendor-Extensible Fields

The EMF+ **metafile** format includes the following vendor-extensible fields:

Arbitrary private data in an EmfPlusComment record

The graphics version in an EmfPlusGraphicsVersion object

The language identifier in an EmfPlusLanguageIdentifier object

Digit substitution in an EmfPlusStringFormat object
