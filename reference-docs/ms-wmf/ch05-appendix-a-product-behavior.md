---
source: [MS-WMF]-240423.docx
chapter_number: 5
chapter_title: "Appendix A: Product Behavior"
word_count: 1949
---

# Appendix A: Product Behavior

The information in this specification is applicable to the following Microsoft products or supplemental software. References to product versions include updates to those products.

Windows NT 3.1 operating system

Windows NT 3.5 operating system

Windows NT 3.51 operating system

Windows 95 operating system

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

<1> Section 1.4: Windows NT 3.1, Windows NT 3.51, Windows NT Server 4.0 operating system, and Windows 95: **WMF** is used primarily with the **Win16** and **Win32s** APIs.

<2> Section 2.1.1.1: Windows NT 3.1, Windows NT 3.51, Windows 95, Windows NT 4.0, Windows 98, and Windows Millennium Edition: This record type is not supported.

<3> Section 2.1.1.1: For most WMF record types, the high-order byte of the **RecordFunction** field signifies the minimum number of 16-bit parameters, ideally specified in the WMF record; however, the value is not reliable for that purpose.

<4> Section 2.1.1.3: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 95, and Windows NT 4.0: Neither **JPEG** nor **PNG** format is supported.

<5> Section 2.1.1.4: In Windows implementations, **BS_HOLLOW** was added as a duplicate symbolic name for **BS_NULL**, because **BS_NULL** was too easily mistaken for a NULL pointer.

**BS_HOLLOW** is used by an application when **GDI** requires a non-NULL brush parameter, but the application requires that no brush be used.

<6> Section 2.1.1.5: Windows NT 3.1 and Windows NT 3.51: This value is not supported.

<7> Section 2.1.1.10: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51: **Anti-aliasing** is not supported.

<8> Section 2.1.1.10: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51: Anti-aliasing is not supported.

<9> Section 2.1.1.10: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 95, Windows NT 4.0, Windows 98, Windows Millennium Edition, and Windows 2000: **ClearType** is not supported.

<10> Section 2.1.1.11: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51: This functionality is not supported.

<11> Section 2.1.1.13: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 95, Windows NT 4.0, Windows 98, and Windows Millennium Edition: This functionality is not supported.

<12> Section 2.1.1.14: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51: This functionality is not supported.

<13> Section 2.1.1.15: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 95, and Windows NT 4.0: This functionality is not supported.

<14> Section 2.1.1.17: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 95, Windows NT 4.0, Windows 98, and Windows Millennium Edition: This functionality is not supported.

<15> Section 2.1.1.17: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 95, Windows NT 4.0, Windows 98, and Windows Millennium Edition: This functionality is not supported.

<16> Section 2.1.1.17: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 95, Windows NT 4.0, Windows 98, and Windows Millennium Edition: This functionality is not supported.

<17> Section 2.1.1.17: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 95, Windows NT 4.0, Windows 98, and Windows Millennium Edition: This functionality is not supported.

<18> Section 2.1.1.17: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 95, Windows NT 4.0, Windows 98, and Windows Millennium Edition: This functionality is not supported.

<19> Section 2.1.1.17: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 95, Windows NT 4.0, Windows 98, and Windows Millennium Edition: This functionality is not supported.

<20> Section 2.1.1.17: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 95, Windows NT 4.0, Windows 98, Windows Millennium Edition, Windows 2000, Windows XP, and Windows Server 2003: This functionality is not supported.

<21> Section 2.1.1.17: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 95, Windows NT 4.0, Windows 98, and Windows Millennium Edition: This functionality is not supported.

<22> Section 2.1.1.26: In Windows implementations, the **PostScript** **printer driver** uses a default line join style of **PostScriptFlatCap**.

<23> Section 2.1.1.28: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 95, Windows 98, and Windows Millennium Edition: This functionality is not supported.

<24> Section 2.1.1.28: Windows NT 4.0 and Windows 2000: This functionality is not supported.

<25> Section 2.1.1.28: Windows NT 4.0 and Windows 2000: This functionality is not supported.

<26> Section 2.1.1.29: In Windows implementations, the PostScript printer driver uses a default line join style of **PostScriptMiterJoin**.

<27> Section 2.1.1.30: Windows 95 and Windows 98: The symbolic name "STRETCH_ANDSCANS" is synonymous with this value.

<28> Section 2.1.1.30: Windows 95 and Windows 98: The symbolic name "STRETCH_ORSCANS" is synonymous with this value.

<29> Section 2.1.1.30: Windows 95 and Windows 98: The symbolic name "STRETCH_DELETESCANS" is synonymous with this value.

<30> Section 2.1.1.30: Windows 95 and Windows 98: The symbolic name "STRETCH_HALFTONE" is synonymous with this value.

<31> Section 2.1.2.1: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows NT 4.0, Windows 2000, and Windows XP: This value is always returned when enumerating fonts.

<32> Section 2.1.2.1: This value is supported in the following Windows versions: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 95, Windows NT 4.0, Windows 98, Windows Millennium Edition, Windows 2000, Windows XP, and Windows Server 2003.

<33> Section 2.1.2.1: This value is supported in the following Windows versions: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, and Windows NT 4.0.

**Font association** is turned off in Windows 2000, Windows XP, and Windows Server 2003.

<34> Section 2.1.2.2: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51: This function is not supported.

<35> Section 2.1.2.2: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51: This function is not supported.

<36> Section 2.1.2.2: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51: This function is not supported.

<37> Section 2.1.2.2: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51: This function is not supported.

<38> Section 2.1.2.2: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 95, Windows NT 4.0, Windows 98, and Windows Millennium Edition: This function is not supported.

<39> Section 2.1.2.3: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51: This function is not supported.

<40> Section 2.2.1.2: All Windows versions: mapping the logical font size to the available physical fonts occurs the first time the logical font needs to be used in a drawing operation.

For the MM_TEXT **mapping mode**, the following formula can be used to compute the height of a font with a specified point size.

Height = -MulDiv(PointSize, GetDeviceCaps(hDC, LOGPIXELSY), 72);

<41> Section 2.2.1.5: Windows sets this field to 0x0000.

<42> Section 2.2.1.5: Windows sets this field to an arbitrary value.

<43> Section 2.2.2.2: Although Windows processes **BitmapCoreHeader objects** in **DIBs**, it does not write them to WMF **metafiles**

<44> Section 2.2.2.3: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 95, and Windows NT 4.0: Neither JPEG nor PNG format is supported.

<45> Section 2.2.2.3: Windows implementations might write a nonzero value to this field, but it is ignored when the metafile is parsed.

<46> Section 2.2.2.4: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51: This structure is not supported.

<47> Section 2.2.2.5: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 95, and Windows NT 4.0: This structure is not supported.

<48> Section 2.2.2.10: In Windows implementations, **BS_HOLLOW** was added as a duplicate symbolic name for **BS_NULL**, because **BS_NULL** was too easily mistaken for a NULL pointer.

**BS_HOLLOW** is used by an application when GDI requires a non-NULL brush parameter, but the application requires that no brush be used.

<49> Section 2.2.2.10: In the following Windows versions, a solid-color black brush is not created by default when a **BrushS****tyle Enumeration** (section 2.1.1.4) table value of BS_PATTERN or BS_DIBPATTERNPT is present: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 95, Windows NT 4.0, Windows 98, Windows Millennium Edition, Windows 2000, Windows XP, and Windows Server 2003.

The default brush creation behavior on these versions of Windows is undefined.

<50> Section 2.3.1.4: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 95, and Windows NT 4.0: This format is not supported.

<51> Section 2.3.1.4: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 95, and Windows NT 4.0: This format is not supported.

<52> Section 2.3.1.6: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 95, and Windows NT 4.0: This format is not supported.

<53> Section 2.3.1.6: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 95, and Windows NT 4.0: This format is not supported.

<54> Section 2.3.2.2: Metafiles created by Windows contain the value METAVERSION300.

<55> Section 2.3.2.3: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, and Windows 95: This feature is not supported.

<56> Section 2.3.4.1: In the following Windows versions, a solid-color black brush is not created by default when a **BrushStyle Enumeration** (section 2.1.1.4) table value of BS_PATTERN or BS_DIBPATTERNPT is present: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, Windows 95, Windows NT 4.0, Windows 98, Windows Millennium Edition, Windows 2000, Windows XP, and Windows Server 2003.

The default brush creation behavior on these versions of Windows is undefined.

<57> Section 2.3.4.4: The META_CREATEPATTERNBRUSH record type is deprecated. No version of Windows emits this record. Playback implementation of this record in Windows is intended solely for compatibility purposes so that Windows metafiles containing this record can be rendered.

<58> Section 2.3.5.15: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51 implementations do not write this field to WMF metafiles.

<59> Section 2.3.5.16: Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, and Windows NT 4.0 implementations do not support this record type.

<60> Section 2.3.5.20: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51 implementations do not write this field to WMF metafiles.

<61> Section 2.3.5.22: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51 implementations do not write this field to WMF metafiles.

<62> Section 2.3.5.23: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51 implementations do not write this field to WMF metafiles.

<63> Section 2.3.5.24: Windows NT 3.1, Windows NT 3.5, and Windows NT 3.51 implementations do not write this field to WMF metafiles.

<64> Section 2.3.6.6: Windows 95, Windows 98, and Windows Millennium Edition implementations set this field to the fill mode value (section 2.1.1.25).

<65> Section 2.3.6.11: Any bytes that exceed the **ByteCount** field are ignored by the client.

<66> Section 2.3.6.25: Windows does not check this value.

<67> Section 3.1.5: Windows applications use the Graphics Device Interface (GDI) to obtain a **device context** for performing output to a device. When the device context is created, the default values for graphics objects and properties are set up by the system and the driver for the device.
