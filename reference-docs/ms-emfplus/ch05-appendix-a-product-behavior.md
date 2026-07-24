---
source: [MS-EMFPLUS]-240423.docx
chapter_number: 5
chapter_title: "Appendix A: Product Behavior"
word_count: 920
---

# Appendix A: Product Behavior

The information in this specification is applicable to the following Microsoft products or supplemental software. References to product versions include updates to those products.

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

<1> Section 1.3.1: The following table shows how the two cases of embedded EMF+ records are processed on different versions of Windows.

| Metafile type | Processed by | Case I | Case II |
| --- | --- | --- | --- |
| EMF+ only | Windows NT 3.1 operating system, Windows NT 3.5 operating system, Windows NT 3.51 operating system, and Windows NT 4.0 operating system | No records are processed. | No records are processed. |
| EMF+ only | Windows 2000, Windows XP, Windows Server 2003, Windows Vista, Windows Server 2008, Windows 7, Windows Server 2008 R2 operating system, Windows 8, Windows Server 2012 operating system, Windows 8.1, Windows Server 2012 R2 operating system, and Windows 10 | EMF records 3 through N are ignored; EMF+ records are processed. | EMF records 3 through N are ignored; EMF+ records are processed. |
| EMF+ dual | Windows NT 3.1, Windows NT 3.5, Windows NT 3.51, and Windows NT 4.0 | EMF records 3 through N are processed; EMF+ records are ignored. | EMF records 3 through N are processed; EMF+ records are ignored. |
| EMF+ dual | Windows 2000, Windows XP, Windows Server 2003, Windows Vista, Windows Server 2008, Windows 7, Windows Server 2008 R2, Windows 8, Windows Server 2012, Windows 8.1, Windows Server 2012 R2, and Windows 10 | EMF records 3 through N are ignored; EMF+ records are processed. | EMF records 3 through N are processed; EMF+ records are processed. |

<2> Section 1.4: Windows applications that use the **GDI+** API [MSDN-GDI+] can create **EMF** metafiles [MS-EMF] that contain **EMF+** records (section 2.3).

<3> Section 2.1.1.6: Windows treats any invalid values as CompositingQualityDefault.

<4> Section 2.1.1.12: GDI+ version 1.1 is not supported on Windows 2000.

<5> Section 2.1.1.27: **SmoothingModeAntiAlias8x4** is not supported on Windows 2000.

<6> Section 2.1.1.27: **SmoothingModeAntiAlias8x8** is not supported on Windows 2000.

<7> Section 2.1.2.1: Windows-based GDI+ ignores blend factors for BrushDataBlendFactorsV.

<8> Section 2.1.2.3: Windows does not write this flag value to EMF+ metafiles.

<9> Section 2.1.2.8: In Windows, this flag is set to specify that GDI+ is used to render text instead of **GDI**.

<10> Section 2.1.3.1: Windows produces corrupt records when the ColorCurve effect is used.

<11> Section 2.2.1.3: Windows never uses unit type **UnitTyp****eDisplay** for this field.

<12> Section 2.2.2.19: If the graphics version number is GraphicsVersion1, the metafile was created using Windows GDI+ 1.0.

If the graphics version number is GraphicsVersion1_1, the metafile was created using Windows GDI+ 1.1.

<13> Section 2.2.2.24: When **Reserved1** is not the same as **StartColor** and **Reserved2** is not the same as **EndColor**, nothing will be rendered.

<14> Section 2.2.2.24: When **Reserved1** is not the same as **StartColor** and **Reserved2** is not the same as **EndColor**, nothing will be rendered.

<15> Section 2.2.2.25: In Windows-based GDI+, the result of BrushDataBlendFactorsV alone is the same as if no blend factor was used.

<16> Section 2.2.2.25: In Windows-based GDI+, when both BrushDataBlendFactorsV and BrushDataBlendFactorsH are set, the result is the same as if BrushDataBlendFactorsH alone is set.

<17> Section 2.2.3: Image Effects Objects (section 2.2.3) are only supported by GDI+ 1.1.

<18> Section 2.2.3.6: The client treats this value as 1.0.

<19> Section 2.3.2.1: Windows sets this field to an arbitrary value between 0x0000 and 0x0003, inclusive.

<20> Section 2.3.4.3: In Windows, if the **P** flag is set, the **C** flag is clear.

<21> Section 2.3.4.4: In Windows, if the **P** flag is set, the **C** flag is clear.

<22> Section 2.3.4.9: In Windows, if the **P** flag is set, the **C** flag is clear.

<23> Section 2.3.4.10: In Windows, if the **P** flag is set, the **C** flag is clear.

<24> Section 2.3.4.15: In Windows, if the **P** flag is set, the **C** flag is clear.

<25> Section 2.3.4.19: In Windows, if the **P** flag is set, the **C** flag is clear.

<26> Section 2.3.5.2: The EmfPlusSerializableObject record type is only supported by GDI+ 1.1.

<27> Section 2.3.6.1: Smoothing with **anti-aliasing** that uses a **box filter** algorithm is not supported on Windows 2000.

<28> Section 2.3.7.1: Windows never writes those values to the **PageUnit** field, but they are accepted with undefined results.

<29> Section 2.3.8: Windows does not generate the EmfPlusSetTSClip record.

<30> Section 2.3.8: Windows does not generate the EmfPlusSetTSGraphics record.

<31> Section 2.3.8.1: The EmfPlusSetTSClip record type is only supported by GDI+ 1.1.

<32> Section 2.3.8.2: The EmfPlusSetTSGraphics record type is only supported by GDI+ 1.1.

<33> Section 2.3.9.5: Windows never writes those values to the **Page****Unit** field, but they are accepted with undefined results.
