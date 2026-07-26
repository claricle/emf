---
source: [MS-EMFPLUS]-240423.docx
chapter_number: 3
chapter_title: "Structure Examples"
word_count: 15541
---

# Structure Examples

The following sections present examples that illustrate the function of EMF+ Extensions structures.

## Metafile Design

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

In the preceding code, if the first integer word stored in the file.in file on a big-endian computer was the hexadecimal number 0x12345678, the resulting output on that computer would be as follows:

% ./test

First Integer in file.in = 12345678

%

If the file.in file was read by the same program running on a little-endian computer, the resulting output would be as follows:

% ./test

First Integer in file.in = 78563412

%

Because of the difference in output, **metafile** record processing needs to be implemented so that it can read integers from a file based on the endian method that the output computer uses.

Because metafiles were developed and written with little-endian computers, machines that are big-endian based will have to perform this necessary compensation.

### Managing Graphics Objects

This section describes a conceptual model for managing graphics objects that an **EMF+** implementation can maintain during metafile playback. The described organization is provided to facilitate the explanation of the file format. This specification does not mandate that implementations adhere to this model as long as their external behavior is consistent with that defined in this specification.

The EmfPlusObject record (section 2.3.5.1) creates graphics objects of the types defined in the ObjectType enumeration (section 2.1.1.21), and the objects themselves are specified in Graphics Objects (section 2.2.1). Once created, graphics objects can be reused any number of times in graphics operations.

An implementation is responsible for keeping track of graphics objects during metafile playback. A model for managing graphics objects is described below. This model minimizes the space needed by the graphics object table during playback.

Create a hash table for graphics objects used in metafile playback.

Grow the hash table as objects are created by the EmfPlusObject record; each new entry in the table receives an object and its index.

When a metafile record refers to an object, it specifies the object's index. Use this index as a key into the hash table to retrieve the object.

When a new object is created that has the same index as an existing object, replace the hash table entry of the existing object with one for the new object.

## EMF+ Metafile Example

This section provides an example of a **metafile**, which when processed renders the following image:

Figure 5: EMF+ Metafile Example

The contents of this metafile example are shown below in hexadecimal bytes. The far-left column is the byte offset from the start of the metafile; the far-right characters are the interpretation of the byte values in the Latin-1 **ANSI character set** [ISO/IEC-8859-1]. The sections that follow describe the metafile records that convey this series of bytes.

00000000: 01 00 00 00 6C 00 00 00 FF FF FF FF FF FF FF FF  ...l...ÿÿÿÿÿÿÿÿ

00000010: 64 00 00 00 6B 00 00 00 00 00 00 00 00 00 00 00 d...k...........

00000020: F0 07 00 00 77 08 00 00 20 45 4D 46 00 00 01 00 ð..w .. EMF.. .

00000030: 5C 0A 00 00 4C 00 00 00 02 00 00 00 00 00 00 00 \...L... .......

00000040: 00 00 00 00 00 00 00 00 40 06 00 00 B0 04 00 00 ........@ ..° ..

00000050: 40 01 00 00 F0 00 00 00 00 00 00 00 00 00 00 00 @ ..ð...........

00000060: 00 00 00 00 00 E2 04 00 80 A9 03 00 46 00 00 00 .....â .€© .F...

00000070: 2C 00 00 00 20 00 00 00 45 4D 46 2B 01 40 01 00 ,... ...EMF+ @ .

00000080: 1C 00 00 00 10 00 00 00 02 10 C0 DB 01 00 00 00  ... ...  ÀÛ ...

00000090: 66 00 00 00 6C 00 00 00 21 00 00 00 08 00 00 00 f...l...!... ...

000000A0: 62 00 00 00 0C 00 00 00 01 00 00 00 21 00 00 00 b....... ...!...

000000B0: 08 00 00 00 62 00 00 00 0C 00 00 00 01 00 00 00  ...b....... ...

000000C0: 21 00 00 00 08 00 00 00 21 00 00 00 08 00 00 00 !... ...!... ...

000000D0: 73 00 00 00 0C 00 00 00 00 00 00 00 1C 00 00 00 s........... ...

000000E0: 08 00 00 00 25 00 00 00 0C 00 00 00 00 00 00 80  ...%..........€

000000F0: 25 00 00 00 0C 00 00 00 07 00 00 80 25 00 00 00 %.........€%...

00000100: 0C 00 00 00 0E 00 00 80 30 00 00 00 0C 00 00 00 .......€0.......

00000110: 0F 00 00 80 19 00 00 00 0C 00 00 00 FF FF FF 00  ..€ .......ÿÿÿ.

00000120: 18 00 00 00 0C 00 00 00 00 00 00 00 12 00 00 00  ........... ...

00000130: 0C 00 00 00 02 00 00 00 13 00 00 00 0C 00 00 00 .... ... .......

00000140: 01 00 00 00 14 00 00 00 0C 00 00 00 0D 00 00 00  ... ...........

00000150: 15 00 00 00 0C 00 00 00 01 00 00 00 16 00 00 00  ....... ... ...

00000160: 0C 00 00 00 00 00 00 00 0D 00 00 00 10 00 00 00 ............ ...

00000170: 00 00 00 00 00 00 00 00 3A 00 00 00 0C 00 00 00 ........:.......

00000180: 0A 00 00 00 1B 00 00 00 10 00 00 00 00 00 00 00 .... ... .......

00000190: 00 00 00 00 23 00 00 00 20 00 00 00 87 C3 81 3F ....#... ...‡Ã□?

000001A0: 00 00 00 00 00 00 00 00 7A BD 80 3F 00 00 00 80 ........z½€?...€

000001B0: 00 00 00 80 24 00 00 00 24 00 00 00 87 C3 81 3F ...€$...$...‡Ã□?

000001C0: 00 00 00 00 00 00 00 00 7A BD 80 3F 00 00 00 80 ........z½€?...€

000001D0: 00 00 00 80 04 00 00 00 73 00 00 00 0C 00 00 00 ...€ ...s.......

000001E0: 00 00 00 00 0D 00 00 00 10 00 00 00 00 00 00 00 ........ .......

000001F0: 00 00 00 00 52 00 00 00 70 01 00 00 01 00 00 00 ....R...p .. ...

00000200: 10 00 00 00 07 00 00 00 00 00 00 00 00 00 00 00  ..............

00000210: BC 02 00 00 00 00 00 00 07 02 02 22 53 00 79 00 ¼ ......  "S.y.

00000220: 73 00 74 00 65 00 6D 00 00 00 00 00 00 00 00 00 s.t.e.m.........

00000230: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ................

00000240: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ................

00000250: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ................

00000260: B1 E6 31 7C BC FE 12 00 21 00 00 00 00 00 13 00 ±æ1|¼þ .!..... .

00000270: 00 00 2E 00 54 E1 12 00 BC FE 12 00 14 E1 12 00 ....Tá .¼þ . á .

00000280: 00 00 00 00 F4 F4 12 00 34 B8 F9 77 68 26 F4 77 ....ôô .4¸ùwh&ôw

00000290: FF FF FF FF AD 97 F7 77 7F 99 F7 77 70 E1 12 00 ÿÿÿÿ­—÷w™÷wpá .

000002A0: 21 00 00 00 01 00 00 00 FC 8B CE 02 38 A6 17 00 !... ...ü‹Î 8¦ .

000002B0: 7F 99 F7 77 B0 DA 4F 00 63 DE 5D 00 3E 08 5A 00 ™÷w°ÚO.cÞ].> Z.

000002C0: 68 99 5A 00 F5 82 54 00 1A 91 54 00 8F 9B C7 77 h™Z.õ‚T. 'T.□›Çw

000002D0: BD 93 54 00 6F 9D 54 00 94 E5 54 00 00 00 54 00 ½"T.o□T."åT...T.

000002E0: AF 58 56 00 6B 50 56 00 B4 3A 55 00 05 39 55 00 ¯XV.kPV.':U. 9U.

000002F0: 09 35 55 00 64 C4 4F 00 00 82 41 00 FF 44 41 00 .5U.dÄO..‚A.ÿDA.

00000300: 12 4E 41 00 E1 4B 41 00 1D 1E 31 7C 4B 16 31 7C  NA.áKA.  1|K 1|

00000310: DA EF 30 7C 49 F4 30 7C EA A3 37 7C 00 00 D5 77 Úï0|Iô0|ê£7|..Õw

00000320: A5 DC D5 77 46 46 D3 77 D7 96 D3 77 97 ED 31 7C ¥ÜÕwFFÓw×–Ów—í1|

00000330: B1 E6 31 7C 00 00 2E 01 10 E2 12 00 68 8B CE 02 ±æ1|...  â .h‹Î 

00000340: 08 ED F8 77 68 8B CE 02 00 00 2E 01 01 00 00 00  íøwh‹Î ...  ...

00000350: 00 00 2E 01 C4 04 F9 77 27 05 F9 77 64 76 00 08 ... Ä ùw' ùwdv. 

00000360: 00 00 00 00 25 00 00 00 0C 00 00 00 01 00 00 00 ....%....... ...

00000370: 25 00 00 00 0C 00 00 00 0E 00 00 80 28 00 00 00 %..........€(...

00000380: 0C 00 00 00 01 00 00 00 46 00 00 00 88 02 00 00 .... ...F...ˆ ..

00000390: 7C 02 00 00 45 4D 46 2B 1E 40 0B 00 0C 00 00 00 | ..EMF+ @......

000003A0: 00 00 00 00 24 40 02 00 0C 00 00 00 00 00 00 00 ....$@ .........

000003B0: 21 40 07 00 0C 00 00 00 00 00 00 00 22 40 03 00 !@........."@ .

000003C0: 0C 00 00 00 00 00 00 00 1F 40 05 00 0C 00 00 00 ........¬@ .....

000003D0: 00 00 00 00 2C 40 00 00 24 00 00 00 18 00 00 00 ....,@..$... ...

000003E0: 00 00 80 3F 00 00 00 00 00 00 00 00 00 00 80 3F ..€?..........€?

000003F0: 00 00 00 80 00 00 00 80 25 40 00 00 10 00 00 00 ...€...€%@.. ...

00000400: 04 00 00 00 00 00 00 00 2C 40 00 00 24 00 00 00  .......,@..$...

00000410: 18 00 00 00 00 00 80 3F 00 00 00 00 00 00 00 00  .....€?........

00000420: 00 00 80 3F 00 00 00 00 00 00 00 00 2A 40 00 00 ..€?........*@..

00000430: 24 00 00 00 18 00 00 00 00 00 80 3F 00 00 00 00 $... .....€?....

00000440: 00 00 00 00 00 00 80 3F 00 00 00 80 00 00 00 80 ......€?...€...€

00000450: 28 40 00 00 10 00 00 00 04 00 00 00 01 00 00 00 (@.. ... ... ...

00000460: 1E 40 0B 00 0C 00 00 00 00 00 00 00 24 40 02 00  @..........$@ .

00000470: 0C 00 00 00 00 00 00 00 21 40 07 00 0C 00 00 00 ........!@.....

00000480: 00 00 00 00 22 40 03 00 0C 00 00 00 00 00 00 00 ...."@ .........

00000490: 1F 40 05 00 0C 00 00 00 00 00 00 00 30 40 02 00 ¬@ .........0@ .

000004A0: 10 00 00 00 04 00 00 00 00 00 80 3F 2A 40 00 00  ... .....€?*@..

000004B0: 24 00 00 00 18 00 00 00 00 00 80 3F 00 00 00 00 $... .....€?....

000004C0: 00 00 00 00 00 00 80 3F 00 00 00 80 00 00 00 80 ......€?...€...€

000004D0: 2A 40 00 00 24 00 00 00 18 00 00 00 00 00 80 3F *@..$... .....€?

000004E0: 00 00 00 00 00 00 00 00 00 00 80 3F 00 00 00 80 ..........€?...€

000004F0: 00 00 00 80 2A 40 00 00 24 00 00 00 18 00 00 00 ...€*@..$... ...

00000500: 0D 74 DA 3A 00 00 00 00 00 00 00 00 0D 74 DA 3A .tÚ:.........tÚ:

00000510: 00 00 00 80 00 00 00 80 2A 40 00 00 24 00 00 00 ...€...€*@..$...

00000520: 18 00 00 00 92 5F 2C 3E 00 00 00 00 00 00 00 00  ...'_,>........

00000530: EB 51 38 3E 00 00 00 80 00 00 00 80 08 40 00 03 ëQ8>...€...€ @. 

00000540: C4 00 00 00 B8 00 00 00 02 10 C0 DB 13 00 00 00 Ä...¸...  ÀÛ ...

00000550: 00 00 00 00 FC 7F F5 43 CF FF FF BF 9D 8E 08 44 ....üõCÏÿÿ¿□Ž D

00000560: 1E 01 00 C0 FE BF 13 44 EB 15 2B 42 FF BF 13 44   .Àþ¿ Dë +Bÿ¿ D

00000570: FC FF C3 42 FF BF 13 44 FE FF C3 42 FF BF 13 44 üÿÃBÿ¿ DþÿÃBÿ¿ D

00000580: 01 00 C4 42 FF BF 13 44 03 00 C4 42 FF BF 13 44  .ÄBÿ¿ D .ÄBÿ¿ D

00000590: FF FF F5 43 FF BF 13 44 9F CE 08 44 9F 8E 08 44 ÿÿõCÿ¿ DŸÎ DŸŽ D

000005A0: FF FF 13 44 00 80 F5 43 FF FF 13 44 05 00 C2 42 ÿÿ D.€õCÿÿ D .ÂB

000005B0: FF FF 13 44 16 16 27 42 00 00 14 44 72 FF 3F C0 ÿÿ D  'B.. Drÿ?À

000005C0: 9F CE 08 44 E8 FF 3F C0 01 00 F6 43 10 00 40 C0 ŸÎ Dèÿ?À .öC .@À

000005D0: 04 00 C4 42 64 00 40 C0 17 16 2B 42 FA 15 27 42  .ÄBd.@À  +Bú 'B

000005E0: E8 FE FF BF F6 FF C1 42 26 00 00 C0 00 03 03 03 èþÿ¿öÿÁB&..À.   

000005F0: 03 03 03 01 03 03 03 01 03 03 03 01 03 03 83 BF               ƒ¿

00000600: 14 40 00 80 10 00 00 00 04 00 00 00 FF FF FF 00  @.€ ... ...ÿÿÿ.

00000610: 46 00 00 00 50 00 00 00 44 00 00 00 45 4D 46 2B F...P...D...EMF+

00000620: 08 40 01 02 30 00 00 00 24 00 00 00 02 10 C0 DB  @  0...$...  ÀÛ

00000630: 00 00 00 00 80 00 00 00 02 00 00 00 00 00 80 3F ....€... .....€?

00000640: 00 00 00 00 02 10 C0 DB 00 00 00 00 00 00 00 FF ....  ÀÛ.......ÿ

00000650: 15 40 00 00 10 00 00 00 04 00 00 00 01 00 00 00  @.. ... ... ...

00000660: 22 00 00 00 0C 00 00 00 FF FF FF FF 22 00 00 00 ".......ÿÿÿÿ"...

00000670: 0C 00 00 00 FF FF FF FF 25 00 00 00 0C 00 00 00 ....ÿÿÿÿ%.......

00000680: 0D 00 00 80 22 00 00 00 0C 00 00 00 FF FF FF FF ...€".......ÿÿÿÿ

00000690: 21 00 00 00 08 00 00 00 73 00 00 00 0C 00 00 00 !... ...s.......

000006A0: 00 00 00 00 1C 00 00 00 08 00 00 00 25 00 00 00 .... ... ...%...

000006B0: 0C 00 00 00 00 00 00 80 25 00 00 00 0C 00 00 00 .......€%.......

000006C0: 07 00 00 80 25 00 00 00 0C 00 00 00 0E 00 00 80 ..€%..........€

000006D0: 30 00 00 00 0C 00 00 00 0F 00 00 80 19 00 00 00 0....... ..€ ...

000006E0: 0C 00 00 00 FF FF FF 00 18 00 00 00 0C 00 00 00 ....ÿÿÿ. .......

000006F0: 00 00 00 00 12 00 00 00 0C 00 00 00 02 00 00 00 .... ....... ...

00000700: 13 00 00 00 0C 00 00 00 01 00 00 00 14 00 00 00  ....... ... ...

00000710: 0C 00 00 00 0D 00 00 00 15 00 00 00 0C 00 00 00 ........ .......

00000720: 01 00 00 00 16 00 00 00 0C 00 00 00 00 00 00 00  ... ...........

00000730: 0D 00 00 00 10 00 00 00 00 00 00 00 00 00 00 00 .... ...........

00000740: 3A 00 00 00 0C 00 00 00 0A 00 00 00 1B 00 00 00 :........... ...

00000750: 10 00 00 00 00 00 00 00 00 00 00 00 23 00 00 00  ...........#...

00000760: 20 00 00 00 87 C3 81 3F 00 00 00 00 00 00 00 00  ...‡Ã□?........

00000770: 7A BD 80 3F 00 00 00 80 00 00 00 80 24 00 00 00 z½€?...€...€$...

00000780: 24 00 00 00 87 C3 81 3F 00 00 00 00 00 00 00 00 $...‡Ã□?........

00000790: 7A BD 80 3F 00 00 00 80 00 00 00 80 04 00 00 00 z½€?...€...€ ...

000007A0: 73 00 00 00 0C 00 00 00 00 00 00 00 46 00 00 00 s...........F...

000007B0: 60 00 00 00 52 00 00 00 47 44 49 43 02 00 00 00 `...R...GDIC ...

000007C0: 00 00 00 00 00 00 00 00 66 00 00 00 6C 00 00 00 ........f...l...

000007D0: 1B 00 00 00 41 00 70 00 70 00 4E 00 61 00 6D 00  ...A.p.p.N.a.m.

000007E0: 65 00 00 00 49 00 6D 00 61 00 67 00 65 00 20 00 e...I.m.a.g.e. .

000007F0: 44 00 65 00 73 00 63 00 72 00 69 00 70 00 74 00 D.e.s.c.r.i.p.t.

00000800: 69 00 6F 00 6E 00 00 00 00 00 00 00 23 00 00 00 i.o.n.......#...

00000810: 20 00 00 00 FF FF 7F 3F 00 00 00 00 00 00 00 00  ...ÿÿ?........

00000820: FD FF 7F 3F 00 00 00 00 00 00 00 00 24 00 00 00 ýÿ?........$...

00000830: 24 00 00 00 FF FF 7F 3F 00 00 00 00 00 00 00 00 $...ÿÿ?........

00000840: FD FF 7F 3F 00 00 00 00 00 00 00 00 04 00 00 00 ýÿ?........ ...

00000850: 23 00 00 00 20 00 00 00 FF FF 7F 3F 00 00 00 00 #... ...ÿÿ?....

00000860: 00 00 00 00 FD FF 7F 3F 00 00 00 00 00 00 00 00 ....ýÿ?........

00000870: 24 00 00 00 24 00 00 00 FF FF 7F 3F 00 00 00 00 $...$...ÿÿ?....

00000880: 00 00 00 00 FD FF 7F 3F 00 00 00 00 00 00 00 00 ....ýÿ?........

00000890: 04 00 00 00 23 00 00 00 20 00 00 00 0D 74 DA 3A  ...#... ....tÚ:

000008A0: 00 00 00 00 00 00 00 00 0C 74 DA 3A 00 00 00 00 .........tÚ:....

000008B0: 00 00 00 00 24 00 00 00 24 00 00 00 0D 74 DA 3A ....$...$....tÚ:

000008C0: 00 00 00 00 00 00 00 00 0C 74 DA 3A 00 00 00 00 .........tÚ:....

000008D0: 00 00 00 00 04 00 00 00 23 00 00 00 20 00 00 00 .... ...#... ...

000008E0: 92 5F 2C 3E 00 00 00 00 00 00 00 00 E9 51 38 3E '_,>........éQ8>

000008F0: 00 00 00 00 00 00 00 00 24 00 00 00 24 00 00 00 ........$...$...

00000900: 92 5F 2C 3E 00 00 00 00 00 00 00 00 E9 51 38 3E '_,>........éQ8>

00000910: 00 00 00 00 00 00 00 00 04 00 00 00 25 00 00 00 ........ ...%...

00000920: 0C 00 00 00 05 00 00 80 2C 00 00 00 20 00 00 00 .... ..€,... ...

00000930: FD FF FF FF FE FF FF FF 4F 02 00 00 50 02 00 00 ýÿÿÿþÿÿÿO ..P ..

00000940: C8 00 00 00 C8 00 00 00 46 00 00 00 14 00 00 00 È...È...F... ...

00000950: 08 00 00 00 47 44 49 43 03 00 00 00 22 00 00 00  ...GDIC ..."...

00000960: 0C 00 00 00 FF FF FF FF 46 00 00 00 54 00 00 00 ....ÿÿÿÿF...T...

00000970: 48 00 00 00 45 4D 46 2B 29 40 00 00 10 00 00 00 H...EMF+)@.. ...

00000980: 04 00 00 00 01 00 00 00 26 40 00 00 10 00 00 00  ... ...&@.. ...

00000990: 04 00 00 00 00 00 00 00 2A 40 00 00 24 00 00 00  .......*@..$...

000009A0: 18 00 00 00 00 00 80 3F 00 00 00 00 00 00 00 00  .....€?........

000009B0: 00 00 80 3F 00 00 00 00 00 00 00 00 4C 00 00 00 ..€?........L...

000009C0: 64 00 00 00 FF FF FF FF FF FF FF FF 64 00 00 00 d...ÿÿÿÿÿÿÿÿd...

000009D0: 6B 00 00 00 FF FF FF FF FF FF FF FF 66 00 00 00 k...ÿÿÿÿÿÿÿÿf...

000009E0: 6D 00 00 00 29 00 AA 00 00 00 00 00 00 00 00 00 m...).ª.........

000009F0: 00 00 80 3F 00 00 00 00 00 00 00 00 00 00 80 3F ..€?..........€?

00000A00: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ................

00000A10: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ................

00000A20: 22 00 00 00 0C 00 00 00 FF FF FF FF 46 00 00 00 ".......ÿÿÿÿF...

00000A30: 1C 00 00 00 10 00 00 00 45 4D 46 2B 02 40 00 00  ... ...EMF+ @..

00000A40: 0C 00 00 00 00 00 00 00 0E 00 00 00 14 00 00 00 ............ ...

00000A50: 00 00 00 00 10 00 00 00 14 00 00 00 

The sections that follow provide definitions of the header and records that correspond to this metafile. These sections describe each record as it appears in the hexadecimal representation of the example, and the records have been interpreted for the convenience of the reader; however, to reflect the exact order of records in the metafile, some record types appear more than once, and, in some cases, the repeated instances can be identical.

### EMR_HEADER Example

This section provides an example of the **EMF** EMR_HEADER record with Extension 2 ([MS-EMF] section 2.3.4.2.3).

00000000: 01 00 00 00 6C 00 00 00 FF FF FF FF FF FF FF FF

00000010: 64 00 00 00 6B 00 00 00 00 00 00 00 00 00 00 00

00000020: F0 07 00 00 77 08 00 00 20 45 4D 46 00 00 01 00

00000030: 5C 0A 00 00 4C 00 00 00 02 00 00 00 00 00 00 00

00000040: 00 00 00 00 00 00 00 00 40 06 00 00 B0 04 00 00

00000050: 40 01 00 00 F0 00 00 00 00 00 00 00 00 00 00 00

00000060: 00 00 00 00 00 E2 04 00 80 A9 03 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000001) |
| Size (0x0000006C) |
| Bounds (0xFFFFFFFF) |
| ... (0xFFFFFFFF) |
| ... (0x00000064) |
| ... (0x0000006B) |
| Frame (0x00000000) |
| ... (0x00000000) |
| ... (0x000007F0) |
| ... (0x00000877) |

**Type (4 bytes): **0x00000001 identifies the record type as EMR_HEADER.

**Size (4 bytes): **0x0000006C specifies the record size in bytes, 108.

**Bounds (16 bytes): **(0xFFFFFFFF, 0xFFFFFFFF, 0x00000064, 0x0000006B) specifies the rectangular inclusive-inclusive bounds in device units of the smallest rectangle that can be drawn around the image stored in the **metafile**.

**Frame (16 bytes): **(0x00000000, 0x00000000, 0x000007F0, 0x00000877) specifies the rectangular inclusive-inclusive dimensions, in .01 millimeter units, of a rectangle that surrounds the image stored in the metafile.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Signature (0x464D4520) |
| Version (0x00010000) |
| Bytes (0x00000A5C) |
| Records (0x0000004C) |
| Handles (0x0002) | Reserved (0x0000) |
| nDescription (0x00000000) |
| offDescription (0x00000000) |
| nPalEntries (0x00000000) |

**Signature (4 bytes):** 0x464D4520 specifies the record signature, which consists of the **ASCII** string " EMF".

**Version (4 bytes):** 0x00010000 specifies EMF metafile interoperability.

**Bytes (4 bytes):** 0x00000A5C specifies the size of the metafile in bytes.

**Records (4 bytes):** 0x0000004C specifies the number of records in the metafile

**Handles (2 bytes):** 0x0002 specifies the number of indexes that will need to be defined during the processing of the metafile. These indexes correspond to graphics objects that are used in drawing commands. Index zero is reserved for references to the metafile itself.

**Reserv****ed (2 bytes):** 0x0000 is not used.

**nDescription (4 bytes):** 0x00000000 specifies the number of characters in the array that contains the description of the metafile's contents. Zero indicates there is no description string.

**offDescription (4 bytes):** 0x00000000 specifies the offset from the beginning of this record to the array that contains the description of the metafile's contents.

**nPalEntries (4 bytes):** 0x00000000 specifies the number of entries in the metafile **palette**. The location of the palette is specified in the EMF end-of-file record (EMR_EOF, [MS-EMF] section 2.3.4.1).

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Device (0x00000640) |
| ... (0x000004B0) |
| Millimeters (0x00000140) |
| ... (0x000000F0) |
| cbPixelFormat (0x00000000) |
| offPixelFormat (0x00000000) |
| bOpenGL (0x00000000) |
| MicrometersX (0x0004E200) |
| MicrometersY (0x0003A900) |

**Device (8 bytes):** (0x00000640, 0x000004B0) specifies the size of the reference device in pixels.

**Millimeters (8 bytes):** (0x00000140, 0x000000F0) specifies the size of the reference device in millimeters.

**cbPixelFormat (4 bytes):** 0x00000000 specifies the size of the EMF PixelFormatDescriptor object ([MS-EMF] section 2.2.22). This value indicates that no pixel format is defined.

**offPixelFormat (4 bytes):** 0x00000000 specifies the offset to the PixelFormatDescriptor in the metafile. In this case, no pixel format structure is present.

**bOpenGL (4 bytes):** 0x00000000 specifies that no EMF **OpenGL** records ([MS-EMF] section 2.3.9) are present in the metafile.

**MicrometersX (4 bytes):** 0x0004E200 specifies the horizontal size of the reference device in micrometers.

**MicrometersY (4 bytes):** 0x0003A900 specifies the vertical size of the reference device in micrometers.

### EMR_COMMENT_EMFPLUS Example 1

This section provides an example of the **EMF** EMR_COMMENT_EMFPLUS record ([MS-EMF] section 2.3.3.2).

00000060:                                     46 00 00 00 

00000070: 2C 00 00 00 20 00 00 00 45 4D 46 2B

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000046) |
| Size (0x0000002C) |
| DataSize (0x00000020) |
| EMFPlusSignature ("EMF+") |

**Type (4 bytes): **0x00000046 identifies the record type as an EMF comment record.

**Size (4 bytes): **0x0000002C specifies the size of this record in bytes, including embedded EMF+ records.

**DataSize (4 bytes): **0x00000020 specifies the size of the **EMF+** data in bytes.

**EMFPlusSignat****ure (4 bytes): **"EMF+" identifies the comment record type as EMR_COMMENT_EMFPLUS.

The embedded EMF+ records are presented in the sections that follow.

#### EmfPlusHeader Example

This section provides an example of the EmfPlusHeader record (section 2.3.3.3).

00000070:                                     01 40 01 00 

00000080: 1C 00 00 00 10 00 00 00 02 10 C0 DB 01 00 00 00 

00000090: 66 00 00 00 6C 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x4001) | Flags (0x0001) |
| Size (0x0000001C) |
| DataSize (0x00000010) |
| Version (0xDBC01002) |
| EmfPlusFlags (0x00000001) |
| LogicalDpiX (0x00000066) |
| LogicalDpiY (0x0000006C) |

**Type (2 bytes):** 0x4001 identifies the record type as EmfPlusHeader.

**Flags (2 bytes):** 0x0001 specifies that the metafile is **EMF+ Dual**.

**Size (4 bytes):** 0x0000001C specifies the 32-bit-aligned size of the entire record in bytes, including the 12-byte record header and the record-specific buffer data.

**DataSize (4 bytes):** 0x00000010 specifies the number of bytes of data in the **RecordData** member that follows. This number does not include the size of the invariant part of this record.

**Version (4 bytes): **0xDBC01002 specifies the version of operating systems graphics that was used to create the **metafile** (EmfPlusGraphicsVersion object).

**EmfPlusFlags (4 bytes):** 0x00000001 specifies the additional information about how this metafile was recorded. If the value is set to 0x00000001, the metafile was recorded with a reference **playback device context** for a video display.

**LogicalDpiX (4 bytes):** 0x00000066 specifies the dots per inch (DPI) in the horizontal direction of the drawing surface for which the metafile was created.

**LogicalDpiY (4 bytes):** 0x0000006C specifies the dots per inch (DPI) in the vertical direction of the drawing surface for which the metafile was created.

### EMR_SAVEDC Example 1

This section provides an example of the **EMF** EMR_SAVEDC record ([MS-EMF] section 2.3.11).

00000090:                         21 00 00 00 08 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000021) |
| Size (0x00000008) |

**Type (4 bytes):** 0x00000021 identifies the record type as EMR_SAVEDC.

**Size (4 bytes):** 0x00000008 specifies the size of this record in bytes.

### EMR_SETICMMODE Example 1

This section provides an example of the **EMF** EMR_SETICMMODE record ([MS-EMF] section 2.3.11.14).

000000A0: 62 00 00 00 0C 00 00 00 01 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000062) |
| Size (0x0000000C) |
| ICMMode (0x00000001) |

**Type (4 bytes):** 0x00000062 identifies the record type as EMR_SETICMMODE.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**ICMMode (4 bytes):** 0x00000001 specifies turning off **Image Color Management (ICM)**. This value is defined in the EMF ICMMode enumeration.

### EMR_SAVEDC Example 2

This section provides an example of the **EMF** EMR_SAVEDC record ([MS-EMF] section 2.3.11).

000000A0:                                    21 00 00 00 

000000B0: 08 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000021) |
| Size (0x00000008) |

**Type (4 ****bytes):** 0x00000021 identifies the record type as EMR_SAVEDC.

**Size (4 bytes):** 0x00000008 specifies the size of this record in bytes.

### EMR_SETICMMODE Example 2

This section provides an example of the **EMF** EMR_SETICMMODE record ([MS-EMF] section 2.3.11.14).

000000B0:             62 00 00 00 0C 00 00 00 01 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000062) |
| Size (0x0000000C) |
| ICMMode (0x00000001) |

**Type (4 bytes):** 0x00000062 identifies the record type as EMR_SETICMMODE.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**ICMMode (4 bytes):** 0x00000001 specifies turning off **Image Color Management (ICM)**. This value is defined in the EMF ICMMode enumeration.

### EMR_SAVEDC Example 3

This section provides an example of the **EMF** EMR_SAVEDC record ([MS-EMF] section 2.3.11).

000000C0: 21 00 00 00 08 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000021) |
| Size (0x00000008) |

**Type (4 bytes):** 0x00000021 identifies the record type as EMR_SAVEDC.

**Size (4 bytes):** 0x00000008 specifies the size of this record in bytes.

### EMR_SETLAYOUT Example 1

This section provides an example of the **EMF** EMR_SETLAYOUT record ([MS-EMF] section 2.3.11.17).

000000D0: 73 00 00 00 0C 00 00 00 00 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000073) |
| Size (0x0000000C) |
| LayoutMode (0x00000000) |

**Type (4 bytes):** 0x00000073 identifies the record type as EMR_SETLAYOUT.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**LayoutMode (4 bytes):** 0x00000000 specifies left-to-right horizontal layout.

### EMR_SETMETARGN Example 1

This section provides an example of the **EMF** EMR_SETMETARGN record ([MS-EMF] section 2.3.2).

000000D0:                                    1C 00 00 00  

000000E0: 08 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x0000001C) |
| Size (0x00000008) |

**Type (4 bytes):** 0x0000001C identifies the record type as EMR_SETMETARGN.

**Size (4 bytes):** 0x00000008 specifies the size of this record.

### EMR_SELECTOBJECT Example 1

This section provides an example of the **EMF** EMR_SELECTOBJECT record ([MS-EMF] section 2.3.8.5).

000000E0:             25 00 00 00 0C 00 00 00 00 00 00 80

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000025) |
| Size (0x0000000C) |
| ihObject (0x80000000=WHITE_BRUSH) |

**Type (4 bytes):** 0x00000025 identifies the record type as EMR_SELECTOBJECT.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**ihObject (4 bytes):** 0x80000000 specifies the index of an object in the EMF+ Object Table (section 3.1.2).

### EMR_SELECTOBJECT Example 2

This section provides an example of the **EMF** EMR_SELECTOBJECT record ([MS-EMF] section 2.3.8.5).

000000F0: 25 00 00 00 0C 00 00 00 07 00 00 80

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000025) |
| Size (0x0000000C) |
| ihObject (0x80000007=BLACK_PEN) |

**Type (4 ****bytes):** 0x00000025 identifies the record type as EMR_SELECTOBJECT.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**ihObject (4 bytes):** 0x80000007 specifies the index of an object in the EMF+ Object Table (section 3.1.2).

### EMR_SELECTOBJECT Example 3

This section provides an example of the **EMF** EMR_SELECTOBJECT record ([MS-EMF] section 2.3.8.5).

000000F0:                            25 00 00 00 

00000100: 0C 00 00 00 0E 00 00 80

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000025) |
| Size (0x0000000C) |
| ihObject (0x8000000E=DEVICE_DEFAULT_FONT) |

**Type (4 bytes):** 0x00000025 identifies the record type as EMR_SELECTOBJECT.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**ihObject (4 bytes):** 0x8000000E specifies the index of an object in the EMF+ Object Table (section 3.1.2).

### EMR_SELECTPALETTE Example 1

This section provides an example of the **EMF** EMR_SELECTPALETTE record ([MS-EMF] section 2.3.8.6).

00000100:                30 00 00 00 0C 00 00 00 

00000110: 0F 00 00 80

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000030) |
| Size (0x0000000C) |
| ihPal (0x8000000F) |

**Type (4 bytes):** 0x00000030 identifies the record type as EMR_SELECTPALETTE.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**ihPal (4 bytes):** 0x8000000F specifies the palette index. The palette can be selected in background mode only.

### EMR_SETBKCOLOR Example 1

This section provides an example of the **EMF** EMR_SETBKCOLOR record ([MS-EMF] section 2.3.11.10).

00000110:    19 00 00 00 0C 00 00 00 FF FF FF 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000019) |
| Size (0x0000000C) |
| Color (0x00FFFFFF) |

**Type (4 bytes):** 0x00000019 identifies the record type as EMR_SETBKCOLOR.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**Color (4 bytes):** 0x00FFFFFF specifies the background color value with the **WMF** ColorRef object ([MS-WMF] section 2.2.2.8).

### EMR_SETTEXTCOLOR Example 1

This section provides an example of the **EMF** EMR_SETTEXTCOLOR record ([MS-EMF] section 2.3.11.26).

00000120: 18 00 00 00 0C 00 00 00 00 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000018) |
| Size (0x0000000C) |
| Color (0x00000000) |

**Type (4 bytes):** 0x00000018 identifies the record type as EMR_SETTEXTCOLOR.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**Color (4 bytes):** 0x00000000 specifies the text color value in the form specified using the **WMF** ColorRef object ([MS-WMF] section 2.2.2.8).

### EMR_SETBKMODE Example 1

This section provides an example of the **EMF** EMR_SETBKMODE record ([MS-EMF] section 2.3.11.11).

00000120:                            12 00 00 00 

00000130: 0C 00 00 00 02 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000012) |
| Size (0x0000000C) |
| BackgroundMode (0x00000002) |

**Type (4 bytes):** 0x00000012 identifies the record type as EMR_SETBKMODE.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**BackgroundMode (4 bytes):** 0x00000002 specifies **OPAQUE** background mode. This value is defined in the EMF BackgroundMode enumeration.

### EMR_SETPOLYFILLMODE Example 1

This section provides an example of the **EMF** EMR_SETPOLYFILLMODE record ([MS-EMF] section 2.3.11.22).

00000130:                13 00 00 00 0C 00 00 00 

00000140: 01 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000013) |
| Size (0x0000000C) |
| PolygonFillMode (0x00000001) |

**Type (4 bytes):** 0x00000013 identifies the record type as EMR_SETPOLYFILLMODE.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**PolygonFillMode (4 bytes):** 0x00000001 specifies **ALTERNATE** polygon fill mode. This value is defined in the EMF PolygonFillMode enumeration.

### EMR_SETROP2 Example 1

This section provides an example of the **EMF** EMR_SETROP2 record ([MS-EMF] section 2.3.11.23).

00000140:    14 00 00 00 0C 00 00 00 0D 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000014) |
| Size (0x0000000C) |
| ROP2Mode (0x0000000D) |

**Type (4 bytes):** 0x00000014 identifies the record type as EMR_SETROP2.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**ROP2Mode (4 bytes):** 0x0000000D specifies the **R2_COPYPEN** raster operation mode. This value is defined in the **WMF** BinaryRasterOperation enumeration ([MS-WMF] section 2.1.1.2).

### EMR_SETSTRETCHBLTMODE Example 1

This section provides an example of the **EMF** EMR_SETSTRETCHBLTMODE record ([MS-EMF] section 2.3.11.24).

00000150: 15 00 00 00 0C 00 00 00 01 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000015) |
| Size (0x0000000C) |
| StretchMode (0x00000001) |

**Type (4 bytes):** 0x00000015 identifies the record type as EMR_SETSTRETCHBLTMODE.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**StretchMode (4 bytes):** 0x00000001 specifies a Boolean AND operation using the color values for the eliminated and existing pixels, from the EMF StretchMode enumeration.

### EMR_SETTEXTALIGN Example 1

This section provides an example of the **EMF** EMR_SETTEXTALIGN record ([MS-EMF] section 2.3.11.25).

00000150:                            16 00 00 00 

00000160: 0C 00 00 00 00 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000016) |
| Size (0x0000000C) |
| TextAlignmentMode (0x00000000) |

**Type (4 bytes):** 0x00000016 identifies the record type as EMR_SETTEXTALIGN.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**TextAlignmentMode (4 bytes):** 0x00000000 specifies text alignment using a mask of **WMF** TextAlignmentMode or VerticalTextAlignmentMode flags ([MS-WMF] sections 2.1.2.3 and 2.1.2.4). Only one flag can be chosen from those that affect horizontal and vertical alignment. In addition, only one of the two flags that alter the current position can be chosen.

### EMR_SETBRUSHORGEX Example 1

This section provides an example of the **EMF** EMR_SETBRUSHORGEX record ([MS-EMF] section 2.3.11.12).

00000160:                         0D 00 00 00 10 00 00 00 

00000170: 00 00 00 00 00 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x0000000D) |
| Size (0x00000010) |
| Origin (0x00000000) |
| ... (0x00000000) |

**Type (4 bytes):** 0x0000000D identifies the record type as EMR_SETBRUSHORGEX.

**Size (4 bytes):** 0x00000010 specifies the size of this record in bytes.

**Origin (8 bytes):** (0x00000000, 0x00000000) specifies the brush horizontal and vertical origin in device units.

### EMR_SETMITERLIMIT Example 1

This section provides an example of the **EMF** EMR_SETMITERLIMIT record ([MS-EMF] section 2.3.11.21).

00000170:                         3A 00 00 00 0C 00 00 00 

00000180: 0A 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x0000003A) |
| Size (0x0000000C) |
| MiterLimit (0x0000000A) |

**Type (4 bytes):** 0x0000003A identifies the record type as EMR_SETMITERLIMIT.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**MiterLimit (4 bytes):** 0x0000000A specifies a **miter length** limit of 10 logical units.

### EMR_MOVETOEX Example 1

This section provides an example of the **EMF** EMR_MOVETOEX record ([MS-EMF] section 2.3.11.4).

00000180:             1B 00 00 00 10 00 00 00 00 00 00 00 

00000190: 00 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x0000001B) |
| Size (0x00000010) |
| Offset (0x00000000) |
| ... (0x00000000) |

**Type (4 bytes):** 0x0000001B identifies the record type as EMR_MOVETOEX.

**Size (4 bytes):** 0x00000010 specifies the size of this record in bytes.

**Offset (8 bytes):** (0x00000000, 0x00000000) specifies coordinates of the new current position in logical units.

### EMR_SETWORLDTRANSFORM Example 1

This section provides an example of the **EMF** EMR_SETWORLDTRANSFORM record ([MS-EMF] section 2.3.12.2).

00000190:             23 00 00 00 20 00 00 00 87 C3 81 3F 

000001A0: 00 00 00 00 00 00 00 00 7A BD 80 3F 00 00 00 80

000001B0: 00 00 00 80  

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000023) |
| Size (0x00000020) |
| Xform (0x3F81C387) (24 bytes) |
| ... (0x00000000) |
| ... (0x00000000) |
| ... (0x3F80BD7A) |
| ... (0x80000000) |
| ... (0x80000000) |

**Type (4 bytes):** 0x00000023 identifies the record type as EMR_SETWORLDTRANSFORM.

**Size (4 bytes):** 0x00000020 specifies the size of this record in bytes.

**Xform (24 bytes):** (1.005782, 0.000000, 0.000000, 1.013780, 0.000000, 0.000000) an EMF XForm object ([MS-EMF] section 2.2.28), which specifies the **world space** to **page space** transformation.

### EMR_MODIFYWORLDTRANSFORM Example 1

This section provides an example of the **EMF** EMR_MODIFYWORLDTRANSFORM record ([MS-EMF] section 2.3.12.1).

                      24 00 00 00 24 00 00 00 87 C3 81 3F 

000001C0: 00 00 00 00 00 00 00 00 7A BD 80 3F 00 00 00 80

000001D0: 00 00 00 80 04 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000024) |
| Size (0x00000024) |
| Xform (0x3F81C387) (24 bytes) |
| ... (0x00000000) |
| ... (0x00000000) |
| ... (0x3F80BD7A) |
| ... (0x80000000) |
| ... (0x80000000) |
| ModifyWorldTransformMode (0x00000004) |

**Type (4 bytes):** 0x00000024 identifies the record type as EMR_MODIFYWORLDTRANSFORM.

**Size (4 bytes):** 0x00000024 specifies the size of this record in bytes.

**Xform (24 bytes):** (1.005782, 0.000000, 0.000000, 1.013780, 0.000000, 0.000000) an EMF XForm object ([MS-EMF] section 2.2.28), which specifies the **world space** to **page space** transformation.

**ModifyWorldTransformMode (4 bytes):** 0x00000004 specifies that this record performs the function of an EMF EMR_SETWORLDTRANSFORM record ([MS-EMF] section 2.3.12.2). This value is defined in the EMF ModifyWorldTransformMode enumeration ([MS-EMF] section 2.1.24).

### EMR_SETLAYOUT Example 2

This section provides an example of the **EMF** EMR_SETLAYOUT record ([MS-EMF] section 2.3.11.17).

000001D0:                          73 00 00 00 0C 00 00 00 

000001E0: 00 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000073) |
| Size (0x0000000C) |
| LayoutMode (0x00000000) |

**Type (4 bytes):** 0x00000073 identifies the record type as EMR_SETLAYOUT.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**LayoutMode (4 bytes):** 0x00000000 specifies left-to-right horizontal layout.

### EMR_SETBRUSHORGEX Example 2

This section provides an example of the **EMF** EMR_SETBRUSHORGEX record ([MS-EMF] section 2.3.11.12).

000001E0:              0D 00 00 00 10 00 00 00 00 00 00 00 

000001F0: 00 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x0000000D) |
| Size (0x00000010) |
| Origin (0x00000000) |
| ... (0x00000000) |

**Type (4 bytes):** 0x0000000D identifies the record type as EMR_SETBRUSHORGEX.

**Size (4 bytes):** 0x00000010 specifies the size of this record in bytes.

**Origin (8 bytes):** (0x00000000, 0x00000000) specifies the brush horizontal and vertical origin in device units.

### EMR_EXTCREATEFONTINDIRECTW Example

This section provides an example of the **EMF** EMR_EXTCREATEFONTINDIRECTW record ([MS-EMF] section 2.3.7.8).

000001F0:             52 00 00 00 70 01 00 00 01 00 00 00

00000200: 10 00 00 00 07 00 00 00 00 00 00 00 00 00 00 00

00000210: BC 02 00 00 00 00 00 00 07 02 02 22 53 00 79 00

00000220: 73 00 74 00 65 00 6D 00 00 00 00 00 00 00 00 00

00000230: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00

00000240: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00

00000250: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00

00000260: B1 E6 31 7C BC FE 12 00 21 00 00 00 00 00 13 00

00000270: 00 00 2E 00 54 E1 12 00 BC FE 12 00 14 E1 12 00

00000280: 00 00 00 00 F4 F4 12 00 34 B8 F9 77 68 26 F4 77

00000290: FF FF FF FF AD 97 F7 77 7F 99 F7 77 70 E1 12 00

000002A0: 21 00 00 00 01 00 00 00 FC 8B CE 02 38 A6 17 00

000002B0: 7F 99 F7 77 B0 DA 4F 00 63 DE 5D 00 3E 08 5A 00

000002C0: 68 99 5A 00 F5 82 54 00 1A 91 54 00 8F 9B C7 77

000002D0: BD 93 54 00 6F 9D 54 00 94 E5 54 00 00 00 54 00

000002E0: AF 58 56 00 6B 50 56 00 B4 3A 55 00 05 39 55 00

000002F0: 09 35 55 00 64 C4 4F 00 00 82 41 00 FF 44 41 00

00000300: 12 4E 41 00 E1 4B 41 00 1D 1E 31 7C 4B 16 31 7C

00000310: DA EF 30 7C 49 F4 30 7C EA A3 37 7C 00 00 D5 77

00000320: A5 DC D5 77 46 46 D3 77 D7 96 D3 77 97 ED 31 7C

00000330: B1 E6 31 7C 00 00 2E 01 10 E2 12 00 68 8B CE 02

00000340: 08 ED F8 77 68 8B CE 02 00 00 2E 01 01 00 00 00

00000350: 00 00 2E 01 C4 04 F9 77 27 05 F9 77 64 76 00 08

00000360: 00 00 00 00                     

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000052) |
| Size (0x00000170) |
| ihFonts (0x00000001) |
| elw (360 bytes) |
| ... |
| ... |
| ... |

**Type (4 bytes):** 0x00000052 identifies the record type as EMR_EXTCREATEFONTINDIRECTW.

**Size (4 bytes):** 0x00000170 specifies the size of this record in bytes.

**ihFonts (4 bytes):** 0x00000001 specifies the object index in the EMF+ Object Table (section 3.1.2) to assign to the font.

**elw (360 bytes)** the logical font, which is an EMF LogFontExDv object ([MS-EMF] section 2.2.15).

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Height (0x00000010) |
| Width (0x00000007) |
| Escapement (0x00000000) |
| Orientation (0x00000000) |
| Weight (0x0000002BC) |
| Italic (0x00) | Underline (0x00) | StrikeOut (0x00) | CharSet (0x00) |
| OutPrecision (0x07) | ClipPrecision (0x02) | Quality (0x02) | PitchAndFamily (0x22) |
| Facename ("System") (68 bytes) |
| ... |
| ... |
| ... |

**Height (4 bytes):** 0x00000010 specifies the **cell height** for this font in logical units.

**Width (4 bytes):** 0x00000007 specifies the average character width for this font in logical units.

**Escapement (4 bytes):** 0x00000000 specifies an angle of 0 degrees between the **baseline** of a row of text and the x-axis of the device.

**Orientation (4 bytes):** 0x00000000 specifies an angle of 0 degrees between the baseline of each character and the x-axis of the device.

**Weight (4 bytes):** 0x0000002BC specifies that the **weight** of the font is 700, in the range 0 through 1000, from lightest to darkest, with 400 (0x00000190) considered normal.

**Italic (1 byte):** 0x00 specifies that the font is not italic.

**Underline (1 byte):** 0x00 specifies that the font is not underlined.

**StrikeOut (1 byte):** 0x00 specifies that the font characters do not have a strike-out graphic.

**Ch****arSet (1 byte):** 0x00 specifies the **ANSI_CHARSET**, as defined in the **WMF** CharacterSet enumeration ([MS-WMF] section 2.1.1.5).

**OutPrecision (1 byte):** 0x07 specifies the output precision, which is how closely the output matches the requested font properties, from the WMF OutPrecision enumeration ([MS-WMF] section 2.1.1.21). The value 0x07 specifies a **TrueType** font.

**ClipPrecision (1 byte):** 0x02 specifies the clipping precision, which is how to clip characters that are partially outside the clipping region, from the WMF ClipPrecision Flags ([MS-WMF] section 2.1.2.1). The value 0x02 is used for vector and TrueType fonts.

**Quality (1 byte):** 0x02 specifies proof output quality, from the WMF FontQuality enumeration ([MS-WMF] section 2.1.1.10).

**PitchAndFamily (1 byte):** 0x22 specifies a variable-pitch font with no serifs, from the WMF FamilyFont and PitchFont enumerations ([MS-WMF] sections 2.1.1.8 and 2.1.1.24).

**Facename (68 bytes):** "System" specifies the **typeface** name of the font in **Unicode** characters.

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

**FullName (132 bytes):** An empty string specifies the full name of the font.

**Style (68 bytes):** An empty string describes the style of the font.

**Script (68 bytes):** An empty string describes the character set of the font.

**Signature (4 bytes):** 0x80007664 specifies the signature of an EMF DesignVector object ([MS-EMF] section 2.2.3).

**NumAxes (4 bytes):** 0x00000000 specifies the number of **font axes** described in the DesignVector object.

### EMR_SELECTOBJECT Example 4

This section provides an example of the **EMF** EMR_SELECTOBJECT record ([MS-EMF] section 2.3.8.5).

00000360:     25 00 00 00 0C 00 00 00 01 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000025) |
| Size (0x0000000C) |
| ihObject (0x00000001) |

**Type (4 bytes):** 0x00000025 identifies the record type as EMR_SELECTOBJECT.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**ihObject (4 bytes):** 0x00000001 specifies the index of an object in the EMF+ Object Table (section 3.1.2).

### EMR_SELECTOBJECT Example 5

This section provides an example of the **EMF** EMR_SELECTOBJECT record ([MS-EMF] section 2.3.8.5).

00000370: 25 00 00 00 0C 00 00 00 0E 00 00 80  

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000025) |
| Size (0x0000000C) |
| ihObject (0x8000000E=DEVICE_DEFAULT_FONT) |

**Type (4 bytes):** 0x00000025 identifies the record type as EMR_SELECTOBJECT.

**Size (4 ****bytes):** 0x0000000C specifies the size of this record in bytes.

**ihObject (4 bytes):** 0x8000000E specifies the index of an object in the EMF+ Object Table (section 3.1.2).

### EMR_DELETEOBJECT Example

This section provides an example of the **EMF** EMR_DELETEOBJECT record ([MS-EMF] section 2.3.8.3).

00000370:                           28 00 00 00 

00000380: 0C 00 00 00 01 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000028) |
| Size (0x0000000C) |
| ihObject (0x00000001) |

**Type (4 bytes):** 0x00000028 identifies the record type as EMR_DELETEOBJECT.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**ihObject (4 bytes):** 0x00000001 specifies the object in the EMF+ Object Table (section 3.1.2) to be deleted.

### EMR_COMMENT_EMFPLUS Example 2

This section provides an example of the **EMF** EMR_COMMENT_EMFPLUS record ([MS-EMF] section 2.3.3.2).

00000380:                         46 00 00 00 88 02 00 00

00000390: 7C 02 00 00 45 4D 46 2B

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000046) |
| Size (0x00000288) |
| DataSize (0x0000027C) |
| EMFPlusSignature ("EMF+") |

**Type (4 bytes):** 0x00000046 identifies the record type as an EMF comment record.

**Size (4 bytes):** 0x00000288 specifies the size of this record in bytes, including embedded EMF+ records.

**DataSize (4 bytes):** 0x0000027C specifies the size of the **EMF+** data in bytes.

**EMFPlusSignature (4 bytes):** "EMF+" identifies the comment record type as EMR_COMMENT_EMFPLUS.

The embedded EMF+ records are presented in the sections that follow.

#### EmfPlusSetAntiAliasMode Example 1

This section provides an example of the EmfPlusSetAntiAliasMode record (section 2.3.6.1).

00000390:                     1E 40 0B 00 0C 00 00 00

000003A0: 00 00 00 00  

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x401E) | Flags (0x000B) |
| Size (0x0000000C) |
| DataSize (0x00000000) |

**Type (2 bytes):** 0x401E identifies the record type as EmfPlusSetAntiAliasMode.

**Flags (2 bytes):** 0x000B specifies **anti-aliasing** with an 8x8 **box filte****r**.

**Size (4 bytes):** 0x0000000C specifies the size in bytes of this record.

**DataSize (4 bytes):** 0x00000000 specifies the size in bytes of record-specific data in this record, and in this case, there is none.

#### EmfPlusSetCompositingQuality Example 1

This section provides an example of the EmfPlusSetCompositingQuality record (section 2.3.6.3).

000003A0:             24 40 02 00 0C 00 00 00 00 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x4024) | Flags (0x0002) |
| Size (0x0000000C) |
| DataSize (0x00000000) |

**Type (2 bytes):** 0x4024 identifies the record type as EmfPlusSetCompositingQuality.

**Flags (2 bytes):** 0x0002 specifies CompositingQualityHighSpeed from the CompositingQuality enumeration.

**Size (4 bytes):** 0x0000000C specifies the size in bytes of this record.

**DataSize (4 by****tes):** 0x00000000 specifies the size in bytes of record-specific data in this record, and in this case there is none.

#### EmfPlusSetInterpolationMode Example 1

This section provides an example of the EmfPlusSetInterpolationMode record (section 2.3.6.4).

000003B0: 21 40 07 00 0C 00 00 00 00 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x4021) | Flags (0x0007) |
| Size (0x0000000C) |
| DataSize (0x00000000) |

**Type (2 bytes):** 0x4021 identifies the record type as EmfPlusSetInterpolationMode.

**Flags (2 bytes):** 0x0007 specifies InterpolationModeHighQualityBicubic from the InterpolationMode enumeration (section 2.1.1.16).

**Size (4 bytes):** 0x0000000C specifies the size in bytes of this record.

**DataSize (4 ****bytes):** 0x00000000 specifies the size in bytes of record-specific data in this record, and in this case there is none.

#### EmfPlusSetPixelOffsetMode Example 1

This section provides an example of the EmfPlusSetPixelOffsetMode record (section 2.3.6.5).

000003B0:                         22 40 03 00

000003C0: 0C 00 00 00 00 00 00 00  

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x4022) | Flags (0x0003) |
| Size (0x0000000C) |
| DataSize (0x00000000) |

**Type (2 bytes):** 0x4022 identifies the record type as EmfPlusSetPixelOffsetMode.

**Flags (2 bytes):** 0x0003 specifies PixelOffsetModeNone from the PixelOffsetMode enumeration.

**Size (4 bytes):** 0x0000000C specifies the size in bytes of this record.

**DataSize (4 bytes):** 0x00000000 specifies the size in bytes of record-specific data in this record, and in this case there is none.

#### EmfPlusSetTextRenderingHint Example 1

This section provides an example of the EmfPlusSetTextRenderingHint record (section 2.3.6.8).

000003C0:              1F 40 05 00 0C 00 00 00

000003D0: 00 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x401F) | Flags (0x0005) |
| Size (0x0000000C) |
| DataSize (0x00000000) |

**Type (2 bytes):** 0x401F identifies the record type as EmfPlusSetTextRenderingHint.

**Flags (2 bytes):** 0x0005 specifies TextRenderingHintClearTypeGridFit from the TextRenderingHint enumeration.

**Size (4 bytes):** 0x0000000C specifies the size in bytes of this record.

**DataSize (4 bytes):** 0x00000000 specifies the size in bytes of record-specific data in this record, and in this case, there is none.

#### EmfPlusMultiplyWorldTransform Example 1

This section provides an example of the EmfPlusMultiplyWorldTransform record (section 2.3.9.1).

000003D0:             2C 40 00 00 24 00 00 00 18 00 00 00

000003E0: 00 00 80 3F 00 00 00 00 00 00 00 00 00 00 80 3F

000003F0: 00 00 00 80 00 00 00 80 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x402C) | Flags (0x0000) |
| Size (0x00000024) |
| DataSize (0x00000018) |
| MatrixData (0x3F800000) (24 bytes) |
| ... (0x00000000) |
| ... (0x00000000) |
| ... (0x3F800000) |
| ... (0x80000000) |
| ... (0x80000000) |

**Type (2 bytes):** 0x402C identifies the record type as EmfPlusMultiplyWorldTransform.

**Flags (2 bytes):** 0x0000 specifies pre-multiplication of the **transform** matrix.

**Size (4 bytes):** 0x00000024 specifies the size in bytes of the entire record.

**DataSize (4 bytes):** 0x00000018 specifies the size in bytes of the record-specific data that follows.

**MatrixData (24 bytes):** An EmfPlusTransformMatrix object (section 2.2.2.47) that contains the multiplication matrix.

#### EmfPlusSave Example

This section provides an example of the EmfPlusSave record (section 2.3.7.5).

000003F0:                         25 40 00 00 10 00 00 00

00000400: 04 00 00 00 00 00 00 00  

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x4025) | Flags (0x0000) |
| Size (0x00000010) |
| DataSize (0x00000004) |
| StackIndex (0x00000000) |

**Type (2 bytes):** 0x4025 identifies the record type as EmfPlusSave.

**Flags (2 bytes):** 0x0000 This field is undefined for this record type.

**Size (4 bytes):** 0x00000010 specifies the 32-bit-aligned size of the entire record in bytes, including the 12-byte record header and the record-specific buffer data.

**DataSize (4 bytes):** 0x00000004 specifies the 32-bit-aligned number of bytes of data in the **PointData** member that follows. This number does not include the size of the invariant part of this record.

**StackIndex (4 bytes):** 0x00000000 specifies the identifier used by the corresponding EmfPlusRestore operation (section 2.3.7.4) to retrieve the graphics state from the correct save level on the graphics state stack.

#### EmfPlusMultiplyWorldTransform Example 2

This section provides an example of the EmfPlusMultiplyWorldTransform record (section 2.3.9.1).

00000400:                         2C 40 00 00 24 00 00 00 

00000410: 18 00 00 00 00 00 80 3F 00 00 00 00 00 00 00 00

00000420: 00 00 80 3F 00 00 00 00 00 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x402C) | Flags (0x0000) |
| Size (0x00000024) |
| DataSize (0x00000018) |
| MatrixData (0x3F800000) (24 bytes) |
| ... (0x00000000) |
| ... (0x00000000) |
| ... (0x3F800000) |
| ... (0x00000000) |
| ... (0x00000000) |

**Type (2 bytes):** 0x402C identifies the record type as EmfPlusMultiplyWorldTransform.

**Flags (2 bytes):** 0x0000 specifies pre-multiplication of the **transform** matrix.

**Size (4 bytes):** 0x00000024 specifies the size in bytes of the entire record.

**DataSize (4 bytes):** 0x00000018 specifies the size in bytes of the record-specific data that follows.

**MatrixData (24 bytes):** An EmfPlusTransformMatrix object (section 2.2.2.47) that contains the multiplication matrix.

#### EmfPlusSetWorldTransform Example 1

This section provides an example of the EmfPlusSetWorldTransform record (section 2.3.9.6).

00000420:                                     2A 40 00 00 

00000430: 24 00 00 00 18 00 00 00 00 00 80 3F 00 00 00 00

00000440: 00 00 00 00 00 00 80 3F 00 00 00 80 00 00 00 80

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x402A) | Flags (0x0000) |
| Size (0x00000024) |
| DataSize (0x00000018) |
| MatrixData (0x3F800000) (24 bytes) |
| ... (0x00000000) |
| ... (0x00000000) |
| ... (0x3F800000) |
| ... (0x80000000) |
| ... (0x80000000) |

**Type (2 bytes):** 0x402A identifies the record type as EmfPlusSetWorldTransform.

**Flags (2 bytes):** 0x0000 This field is undefined for this record type.

**Size (4 bytes):** 0x00000024 specifies the size in bytes of this record.

**DataSize (4 bytes):** 0x00000018 specifies the size in bytes of record-specific data in this record.

**MatrixData (24 bytes):** An EmfPlusTransformMatrix object (section 2.2.2.47), which specifies the world transform.

#### EmfPlusBeginContainerNoParams Example

This section provides an example of the EmfPlusBeginContainerNoParams record (section 2.3.7.2).

00000450: 28 40 00 00 10 00 00 00 04 00 00 00 01 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x4028) | Flags (0x0000) |
| Size (0x00000010) |
| DataSize (0x00000004) |
| StackIndex (0x00000001) |

**Type (2 bytes):** 0x4028 identifies the record type as EmfPlusBeginContainerNoParams.

**Flags (2 bytes):** 0x0000 is undefined for this record type.

**Size (4 bytes):** 0x00000010 specifies the size in bytes of the entire record.

**DataSize (4 bytes):** 0x00000004 specifies the size in bytes of the record-specific data that follows.

**StackIndex (4 bytes):** 0x00000001 specifies the identifier used to reference the container in future records. It will match a **StackIndex** value in a subsequent EmfPlusEndContainer record (section 2.3.7.3) that will end the container.

#### EmfPlusSetAntiAliasMode Example 2

This section provides an example of the EmfPlusSetAntiAliasMode record (section 2.3.6.1).

00000460: 1E 40 0B 00 0C 00 00 00 00 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x401E) | Flags (0x000B) |
| Size (0x0000000C) |
| DataSize (0x00000000) |

**Type (2 bytes):** 0x401E identifies the record type as EmfPlusSetAntiAliasMode.

**Flags (2 bytes):** 0x000B specifies **anti-aliasing** with an 8x8 **box filter**.

**Size (4 bytes):** 0x0000000C specifies the size in bytes of this record.

**DataSize (4 bytes):** 0x00000000 specifies the size in bytes of record-specific data in this record, and in this case there is none.

#### EmfPlusSetCompositingQuality Example 2

This section provides an example of the EmfPlusSetCompositingQuality record (section 2.3.6.3).

00000460:                         24 40 02 00

00000470: 0C 00 00 00 00 00 00 00  

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x4024) | Flags (0x0002) |
| Size (0x0000000C) |
| DataSize (0x00000000) |

**Type (2 bytes):** 0x4024 identifies the record type as EmfPlusSetCompositingQuality.

**Flags (2 bytes):** 0x0002 specifies CompositingQualityHighSpeed from the CompositingQuality enumeration.

**Size (4 bytes):** 0x0000000C specifies the size in bytes of this record.

**DataSize (4 bytes):** 0x00000000 specifies the size in bytes of record-specific data in this record, and in this case there is none.

#### EmfPlusSetInterpolationMode Example 2

This section provides an example of the EmfPlusSetInterpolationMode record (section 2.3.6.4).

00000470:                      21 40 07 00 0C 00 00 00

00000480: 00 00 00 00  

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x4021) | Flags (0x0007) |
| Size (0x0000000C) |
| DataSize (0x00000000) |

**Type (2 bytes):** 0x4021 identifies the record type as EmfPlusSetInterpolationMode.

**Flags (2 bytes):** 0x0007 specifies InterpolationModeHighQualityBicubic from the InterpolationMode enumeration (section 2.1.1.16).

**Size (4 bytes):** 0x0000000C specifies the size in bytes of this record.

**DataSize (4 bytes):** 0x00000000 specifies the size in bytes of record-specific data in this record, and in this case there is none.

#### EmfPlusSetPixelOffsetMode Example 2

This section provides an example of the EmfPlusSetPixelOffsetMode record (section 2.3.6.5).

00000480:             22 40 03 00 0C 00 00 00 00 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x4022) | Flags (0x0003) |
| Size (0x0000000C) |
| DataSize (0x00000000) |

**Type (2 bytes):** 0x4022 identifies the record type as EmfPlusSetPixelOffsetMode.

**Flags (2 bytes):** 0x0003 specifies PixelOffsetModeNone from the PixelOffsetMode enumeration (section 2.1.1.25).

**Size (4 bytes):** 0x0000000C specifies the size in bytes of this record.

**DataSize (4 by****tes):** 0x00000000 specifies the size in bytes of record-specific data in this record, and in this case there is none.

#### EmfPlusSetTextRenderingHint Example 2

This section provides an example of the EmfPlusSetTextRenderingHint record (section 2.3.6.8).

00000490: 1F 40 05 00 0C 00 00 00 00 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x401F) | Flags (0x0005) |
| Size (0x0000000C) |
| DataSize (0x00000000) |

**Type (2 bytes):** 0x401F identifies the record type as EmfPlusSetTextRenderingHint.

**Flags (2 bytes):** 0x0005 specifies TextRenderingHintClearTypeGridFit from the TextRenderingHint enumeration (section 2.1.1.31).

**Size (4 bytes):** 0x0000000C specifies the size in bytes of this record.

**DataSize (4 ****bytes):** 0x00000000 specifies the size in bytes of record-specific data in this record, and in this case, there is none.

#### EmfPlusSetPageTransform Example

This section provides an example of the EmfPlusSetPageTransform record (section 2.3.9.5).

00000490:                                     30 40 02 00

000004A0: 10 00 00 00 04 00 00 00 00 00 80 3F 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x4030) | Flags (0x0002) |
| Size (0x00000010) |
| DataSize (0x00000004) |
| PageScale (0x3F800000) |

**Type (2 bytes):** 0x4030 identifies the record type as EmfPlusSetPageTransform.

**Flags (2 bytes):** 0x0002 specifies UnitPixel from the UnitType enumeration.

**Size (4 bytes):** 0x00000010 specifies the size in bytes of this record.

**DataSize (4 bytes):** 0x00000004 specifies the size in bytes of the record-specific data in this record.

**PageScale (4 bytes):** 0x3F800000 specifies the floating-point scale factor for converting **page space** coordinates to **device space** coordinates.

#### EmfPlusSetWorldTransform Example 2

This section provides an example of the EmfPlusSetWorldTransform record (section 2.3.9.6).

000004A0:                                     2A 40 00 00

000004B0: 24 00 00 00 18 00 00 00 00 00 80 3F 00 00 00 00

000004C0: 00 00 00 00 00 00 80 3F 00 00 00 80 00 00 00 80

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x402A) | Flags (0x0000) |
| Size (0x00000024) |
| DataSize (0x00000018) |
| MatrixData (0x3F800000) (24 bytes) |
| ... (0x00000000) |
| ... (0x00000000) |
| ... (0x3F800000) |
| ... (0x80000000) |
| ... (0x80000000) |

**Type (2 bytes):** 0x402A identifies the record type as EmfPlusSetWorldTransform.

**Flags (2 bytes):** 0x0000 is undefined for this record type.

**Size (4 bytes):** 0x00000024 specifies the size in bytes of the entire record.

**DataSize (4 bytes):** 0x00000018 specifies the size in bytes of the **MatrixData** field that follows.

**MatrixData (24 bytes):** An EmfPlusTransformMatrix object (section 2.2.2.47) that contains the **world-space** **transform**.

#### EmfPlusSetWorldTransform Example 3

This section provides an example of the EmfPlusSetWorldTransform record (section 2.3.9.6).

000004D0: 2A 40 00 00 24 00 00 00 18 00 00 00 00 00 80 3F

000004E0: 00 00 00 00 00 00 00 00 00 00 80 3F 00 00 00 80

000004F0: 00 00 00 80

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x402A) | Flags (0x0000) |
| Size (0x00000024) |
| DataSize (0x00000018) |
| MatrixData (0x3F800000) (24 bytes) |
| ... (0x00000000) |
| ... (0x00000000) |
| ... (0x3F800000) |
| ... (0x80000000) |
| ... (0x80000000) |

**Type (2 bytes):** 0x402A identifies the record type as EmfPlusSetWorldTransform.

**Flags (2 bytes):** 0x0000 is undefined for this record type.

**Size (4 bytes):** 0x00000024 specifies the size in bytes of the entire record.

**DataSize (4 bytes):** 0x00000018 specifies the size in bytes of the **MatrixData** field that follows.

**MatrixData (24 bytes):** An EmfPlusTransformMatrix object (section 2.2.2.47) that contains the **world-space** **transform**.

#### EmfPlusSetWorldTransform Example 4

This section provides an example of the EmfPlusSetWorldTransform record (section 2.3.9.6).

000004F0:             2A 40 00 00 24 00 00 00 18 00 00 00

00000500: 0D 74 DA 3A 00 00 00 00 00 00 00 00 0D 74 DA 3A

00000510: 00 00 00 80 00 00 00 80

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x402A) | Flags (0x0000) |
| Size (0x00000024) |
| DataSize (0x00000018) |
| MatrixData (0x3ADA740D) (24 bytes) |
| ... (0x00000000) |
| ... (0x00000000) |
| ... (0x3ADA740D) |
| ... (0x80000000) |
| ... (0x80000000) |

**Type (2 bytes):** 0x402A identifies the record type as EmfPlusSetWorldTransform. 

**Flags (2 bytes):** 0x0000 is undefined for this record type.

**Size (4 bytes):** 0x00000024 specifies the size in bytes of the entire record.

**DataSize (4 bytes):** 0x00000018 specifies the size in bytes of the **MatrixData** field that follows.

**MatrixData (24 bytes):** An EmfPlusTransformMatrix object (section 2.2.2.47) that contains the **world-space** **transform**.

#### EmfPlusSetWorldTransform Example 5

This section provides an example of the EmfPlusSetWorldTransform record (section 2.3.9.6).

00000510:                         2A 40 00 00 24 00 00 00

00000520: 18 00 00 00 92 5F 2C 3E 00 00 00 00 00 00 00 00 

00000530: EB 51 38 3E 00 00 00 80 00 00 00 80 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x402A) | Flags (0x0000) |
| Size (0x00000024) |
| DataSize (0x00000018) |
| MatrixData (0x3E2C5F92) (24 bytes) |
| ... (0x00000000) |
| ... (0x00000000) |
| ... (0x3D3851EB) |
| ... (0x80000000) |
| ... (0x80000000) |

**Type (2 bytes):** 0x402A identifies the record type as EmfPlusSetWorldTransform. 

**Flags (2 bytes):** 0x0000 is undefined for this record type.

**Size (4 bytes):** 0x00000024 specifies the size in bytes of the entire record.

**DataSize (4 bytes):** 0x00000018 specifies the size in bytes of the **MatrixData** field that follows. 

**MatrixData (24 bytes):** An EmfPlusTransformMatrix object (section 2.2.2.47) that contains the **world-space** **transform**.

#### EmfPlusObject Example

This section provides an example of the EmfPlusObject record (section 2.3.5.1).

00000530:                                     08 40 00 03

00000540: C4 00 00 00 B8 00 00 00 02 10 C0 DB 13 00 00 00

00000550: 00 00 00 00 FC 7F F5 43 CF FF FF BF 9D 8E 08 44

00000560: 1E 01 00 C0 FE BF 13 44 EB 15 2B 42 FF BF 13 44

00000570: FC FF C3 42 FF BF 13 44 FE FF C3 42 FF BF 13 44

00000580: 01 00 C4 42 FF BF 13 44 03 00 C4 42 FF BF 13 44

00000590: FF FF F5 43 FF BF 13 44 9F CE 08 44 9F 8E 08 44

000005A0: FF FF 13 44 00 80 F5 43 FF FF 13 44 05 00 C2 42

000005B0: FF FF 13 44 16 16 27 42 00 00 14 44 72 FF 3F C0

000005C0: 9F CE 08 44 E8 FF 3F C0 01 00 F6 43 10 00 40 C0

000005D0: 04 00 C4 42 64 00 40 C0 17 16 2B 42 FA 15 27 42

000005E0: E8 FE FF BF F6 FF C1 42 26 00 00 C0 00 03 03 03

000005F0: 03 03 03 01 03 03 03 01 03 03 03 01 03 03 83 BF

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x4008) | Flags (0x0300) |
| Size (0x000000C4) |
| DataSize (0x000000B8) |
| ObjectTypePath |

**Type (2 bytes):** 0x4008 identifies the record type as EmfPlusObject.

**Flags (2 bytes):** 0x0300 specifies an EmfPlusPath object (section 2.2.1.6) from the ObjectType enumeration (section 2.1.1.21), and index 0x00 for the graphics object in the EMF+ Object Table (section 3.1.2).

**Size (4 bytes):** 0x000000C4 specifies the size in bytes of the entire record.

**DataSize (4 bytes):** 0x000000B8 specifies the size in bytes of the record-specific data that follows.

**ObjectTypePath**** (4 bytes):** An EmfPlusPath object.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Version (0xDBC01002) |
| PathPointCount (0x00000013) |
| PathPointFlags (0x00000000) |
| PathPoints (FC 7F F5 43 CF FF FF BF 9D 8E 08 44 1E 01 00 C0 FE BF 13 44 EB 15 2B 42 FF BF 13 44 FC FF C3 42 FF BF 13 44 FE FF C3 42 FF BF 13 44 01 00 C4 42 FF BF 13 44 03 00 C4 42 FF BF 13 44 FF FF F5 43 FF BF 13 44 9F CE 08 44 9F 8E 08 44 FF FF 13 44 00 80 F5 43 FF FF 13 44 05 00 C2 42 FF FF 13 44 16 16 27 42 00 00 14 44 72 FF 3F C0 9F CE 08 44 E8 FF 3F C0 01 00 F6 43 10 00 40 C0 04 00 C4 42 64 00 40 C0 17 16 2B 42 FA 15 27 42 E8 FE FF BF F6 FF C1 42 26 00 00 C0) (variable) |
| ... |
| PathPointTypes (0x00, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x01, 0x03, 0x03,0x03, 0x01, 0x03, 0x03, 0x03, 0x01, 0x03, 0x03, 0x83) (variable) |
| ... |
| AlignmentPadding (0xBF) |

**Version (4 bytes):** 0xDBC01002 specifies the graphics version that was used to create the EmfPlusPath object in this record. The value 0xDBC01002 corresponds to **GDI+** version 1.1.

**PathPointCount (4 bytes):** 0x00000013 specifies the number of elements in the **PathPoints** and **PathPointTypes** arrays.

**PathPointFlags (4 ****bytes):** 0x00000000 specifies that the path point type values are not compressed.

**PathPoints (variable): **An array of **PathPointCount** EmfPlusPointF objects (section 2.2.2.36) that specify the endpoints and control points of the lines and **Bezier curves** that define the **path**.

**PathPointTypes (variable):** An array of **PathPointCount** bytes that specify the point types and flags for the data points in the path. Point types determine how the points are used to draw the path and are values in the PathPointType enumeration (section 2.1.1.22).

**AlignmentPadding (4 bytes):** An extra byte that makes the total size of this record a multiple of 4 bytes. The value of this field is indeterminate and is ignored.

#### EmfPlusFillPath Example

This section provides an example of the EmfPlusFillPath record (section 2.3.4.17).

00000600: 14 40 00 80 10 00 00 00 04 00 00 00 FF FF FF 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x4014) | Flags (0x8000) |
| Size (0x00000010) |
| DataSize (0x00000004) |
| BrushId (0x00FFFFFF) |

**Type (2 bytes):** 0x4014 identifies the record type as EmfPlusFillPath. 

**Flags (2 bytes):** 0x8000 specifies that a solid color is specified in the **BrushId** field.

**Size (4 bytes):** 0x00000010 specifies the size in bytes of the entire record.

**DataSize (4 bytes):** 0x00000004 specifies the size in bytes of the **BrushID** field that follows.

**BrushId (4 by****tes):** 0x00FFFFFF specifies the fill color, which is white.

### EMR_COMMENT_EMFPLUS Example 3

This section provides an example of the **EMF** EMR_COMMENT_EMFPLUS record ([MS-EMF] section 2.3.3.2).

00000610: 46 00 00 00 50 00 00 00 44 00 00 00 45 4D 46 2B 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000046) |
| Size (0x00000050) |
| DataSize (0x00000044) |
| EMFPlusSignature ("EMF+") |

**Type (2 bytes):** 0x00000046 identifies the record type as an EMF comment record.

**Size (2 bytes):** 0x00000050 specifies the size of this record in bytes, including embedded EMF+ records.

**DataSize (4 bytes):** 0x00000044 specifies the size of the **EMF+** data in bytes.

**EMFPlusSignature (4 bytes):** "EMF+" identifies the comment record type as EMR_COMMENT_EMFPLUS.

The embedded EMF+ records are presented in the sections that follow.

#### EmfPlusObject Example

This section provides an example of the EmfPlusObject record (section 2.3.5.1).

00000620: 08 40 01 02 30 00 00 00 24 00 00 00 02 10 C0 DB

00000630: 00 00 00 00 80 00 00 00 02 00 00 00 00 00 80 3F

00000640: 00 00 00 00 02 10 C0 DB 00 00 00 00 00 00 00 FF

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x4008) | Flags (0x0201) |
| Size (0x00000030) |
| DataSize (0x00000024) |
| ObjectTypePen |

**Type (2 bytes):** 0x4008 identifies the record type as EmfPlusObject.

**Flags (2 bytes):** 0x0201 specifies an EmfPlusPen object (section 2.2.1.7) from the ObjectType enumeration (section 2.1.1.21), and index 0x01 for the graphics object in the EMF+ Object Table (section 3.1.2).

**Size (4 bytes):** 0x00000030 specifies the size in bytes of the entire record.

**DataSize (4 bytes):** 0x00000024 specifies the size in bytes of the record-specific data that follows.

**ObjectTypePen (4 bytes):** An EmfPlusPen object that specifies the graphics pen defined by this object record.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Version (0xDBC01002) |
| Type (0x00000000) |
| PenData (variable) |
| ... |
| BrushObject (variable) |
| ... |

**Version (4 bytes):** 0xDBC01002 specifies the graphics version that was used to create the EmfPlusPen object in this record. The value 0xDBC01002 corresponds to **GDI+** version 1.1.

**Type (4 bytes):** 0x00000000 is not used.

**PenData (variable):** An EmfPlusPenData object (section 2.2.2.33) that specifies the characteristics of the graphics pen, including both required and optional fields.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PenDataFlags (0x00000080) |
| PerUnit (0x00000002) |
| PenWidth (0x3F800000) |
| OptionalData (0x00000000) |

**PenDataFlags (4 bytes):** 0x00000080 specifies that a dashed-line offset value is present in the **OptionalData** field of this object. This is a value from the PenData flags (section 2.1.2.7).

**PenUnit**** (4 bytes):** 0x00000002 specifies a unit of one pixel for the pen, from the UnitType enumeration (section 2.1.1.32).

**PenWidth (4 bytes):** 0x3F800000 specifies a floating-point value that is the width of the stroke drawn by the pen, in the units specified by the **PenUnit** field.

**OptionalData (4 bytes):** 0x00000000 specifies a zero dashed-line offset.

**BrushObject (variable):** An EmfPlusBrush object (section 2.2.1.1) that specifies the graphics brush associated with the pen.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Version (0xDBC01002) |
| Type (0x00000000) |
| BrushData (0xFF000000) |

**Version (4 bytes):** 0xDBC01002 specifies the graphics version that was used to create the EmfPlusBrush object in this record.

**Type (4 bytes):** 0x00000000 specifies a solid color brush from the BrushType enumeration (section 2.1.1.3).

**BrushData (4 bytes):** 0xFF000000 specifies a blue brush color.

#### EmfPlusDrawPath Example

This section provides an example of the EmfPlusDrawPath record (section 2.3.4.11).

00000650: 15 40 00 00 10 00 00 00 04 00 00 00 01 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x4015) | Flags (0x0000) |
| Size (0x00000010) |
| DataSize (0x00000004) |
| PenId (0x00000001) |

**Type (2 bytes):** 0x4015 identifies the record type as EmfPlusDrawPath.

**Flags (2 bytes):** 0x0000 specifies the graphics object identifier and object type.

**Size (4 bytes):**  0x00000010 specifies the 32-bit-aligned size of the entire record in bytes, including the 12-byte record header and the record-specific buffer data.

**DataSize (4 bytes):** 0x00000004 specifies the 32-bit-aligned number of bytes of data in the **RecordData** member that follows. This number does not include the size of the invariant part of this record. 

**PenId (4 bytes):** 0x00000001 specifies the index into the EMF+ Object Table (section 3.1.2) for the EmfPlusPen object (section 2.2.1.7) to use.

### EMR_RESTOREDC Example 1

This section provides an example of the **EMF** EMR_RESTOREDC record ([MS-EMF] section 2.3.11.6).

00000660: 22 00 00 00 0C 00 00 00 FF FF FF FF

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000022) |
| Size (0x0000000C) |
| SavedDC (0xFFFFFFFF) |

**Type (4 bytes):** 0x00000022 identifies the record type as EMR_RESTOREDC.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**SavedDC (4 bytes):** 0xFFFFFFFF specifies the most recently saved state.

### EMR_RESTOREDC Example 2

This section provides an example of the **EMF** EMR_RESTOREDC record ([MS-EMF] section 2.3.11.6).

00000660:                             22 00 00 00

00000670: 0C 00 00 00 FF FF FF FF

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000022) |
| Size (0x0000000C) |
| SavedDC (0xFFFFFFFF) |

**Type (4 bytes):** 0x00000022 identifies the record type as EMR_RESTOREDC.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**SavedDC (4 bytes):** 0xFFFFFFFF specifies the most recently saved state.

### EMR_SELECTOBJECT Example 6

This section provides an example of the **EMF** EMR_SELECTOBJECT record ([MS-EMF] section 2.3.8.5).

00000670:                    25 00 00 00 0C 00 00 00

00000680: 0D 00 00 80

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000025) |
| Size (0x0000000C) |
| ihObject (0x8000000D=SYSTEM_FONT) |

**Type (4 bytes):** 0x00000025 identifies the record type as EMR_SELECTOBJECT.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**ihObject (4 bytes):** 0x8000000D specifies the index of an object in the EMF+ Object Table (section 3.1.2).

### EMR_RESTOREDC Example 3

This section provides an example of the **EMF** EMR_RESTOREDC record ([MS-EMF] section 2.3.11.6).

00000680:  22 00 00 00 0C 00 00 00 FF FF FF FF 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000022) |
| Size (0x0000000C) |
| SavedDC (0xFFFFFFFF) |

**Type (4 bytes):** 0x00000022 identifies the record type as EMR_RESTOREDC.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**SavedDC (4 bytes):** 0xFFFFFFFF specifies the most recently saved state.

### EMR_SAVEDC Example 4

This section provides an example of the **EMF** EMR_SAVEDC record ([MS-EMF] section 2.3.11).

00000690: 21 00 00 00 08 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000021) |
| Size (0x00000008) |

**Type (4 bytes):** 0x00000021 identifies the record type as EMR_SAVEDC.

**Size (4 bytes):** 0x00000008 specifies the size of this record in bytes.

### EMR_SETLAYOUT Example 3

This section provides an example of the **EMF** EMR_SETLAYOUT record ([MS-EMF] section 2.3.11.17).

00000690:                    73 00 00 00 0C 00 00 00

000006A0: 00 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000073) |
| Size (0x0000000C) |
| LayoutMode (0x00000000) |

**Type (4 bytes):** 0x00000073 identifies the record type as EMR_SETLAYOUT.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**LayoutMode (4 bytes):** 0x00000000 specifies left-to-right horizontal layout.

### EMR_SETMETARGN Example 2

This section provides an example of the **EMF** EMR_SETMETARGN record ([MS-EMF] section 2.3.2).

000006A0:             1C 00 00 00 08 00 00 00  

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x0000001C) |
| Size (0x00000008) |

**Type (4 bytes):** 0x0000001C identifies the record type as EMR_SETMETARGN.

**Size (4 bytes):** 0x00000008 specifies the size of this record.

### EMR_SELECTOBJECT Example 7

This section provides an example of the **EMF** EMR_SELECTOBJECT record ([MS-EMF] section 2.3.8.5).

000006A0:                         25 00 00 00 

000006B0: 0C 00 00 00 00 00 00 80 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000025) |
| Size (0x0000000C) |
| ihObject (0x80000000=WHITE_BRUSH) |

**Type (4 bytes):** 0x00000025 identifies the record type as EMR_SELECTOBJECT.

**Size (4 ****bytes):** 0x0000000C specifies the size of this record in bytes.

**ihObject (4 bytes):** 0x80000000 specifies the index of an object in the EMF+ Object Table (section 3.1.2).

### EMR_SELECTOBJECT Example 8

This section provides an example of the **EMF** EMR_SELECTOBJECT record ([MS-EMF] section 2.3.8.5).

000006B0:                25 00 00 00 0C 00 00 00 

000006C0: 07 00 00 80   

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000025) |
| Size (0x0000000C) |
| ihObject (0x80000007=BLACK_PEN) |

**Type (4 bytes):** 0x00000025 identifies the record type as EMR_SELECTOBJECT.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**ihObject (4 bytes):** 0x80000007 specifies the index of an object in the EMF+ Object Table (section 3.1.2).

### EMR_SELECTOBJECT Example 9

This section provides an example of the **EMF** EMR_SELECTOBJECT record ([MS-EMF] section 2.3.8.5).

000006C0: 25 00 00 00 0C 00 00 00 0E 00 00 80

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000025) |
| Size (0x0000000C) |
| ihObject (0x8000000E=DEVICE_DEFAULT_FONT) |

**Type (4 bytes):** 0x00000025 identifies the record type as EMR_SELECTOBJECT.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**ihObject**** (4 bytes):** 0x8000000E specifies the index of an object in the EMF+ Object Table (section 3.1.2).

### EMR_SELECTPALETTE Example 2

This section provides an example of the **EMF** EMR_SELECTPALETTE record ([MS-EMF] section 2.3.8.6).

000006D0: 30 00 00 00 0C 00 00 00 0F 00 00 80

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000030) |
| Size (0x0000000C) |
| ihPal (0x8000000F) |

**Type (4 bytes):** 0x00000030 identifies the record type as EMR_SELECTPALETTE.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**ihPal (4 bytes):** 0x8000000F specifies the palette index. The palette can be selected in background mode only.

### EMR_SETBKCOLOR Example 2

This section provides an example of the **EMF** EMR_SETBKCOLOR record ([MS-EMF] section 2.3.11.10).

000006D0:                           19 00 00 00 

000006E0: 0C 00 00 00 FF FF FF 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000019) |
| Size (0x0000000C) |
| Color (0x00FFFFFF) |

**Type** **(4 bytes):** 0x00000019 identifies the record type as EMR_SETBKCOLOR.

**Size (4 bytes):** 0x0000000C specifies the size of this record in bytes.

**Color** **(4 bytes): **0x00FFFFFF specifies the background color value of the **WMF** ColorRef object ([MS-WMF] section 2.2.2.8).

### EMR_SETTEXTCOLOR Example 2

This section provides an example of the **EMF** EMR_SETTEXTCOLOR record ([MS-EMF] section 2.3.11.26).

000006E0:                 18 00 00 00 0C 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000018) |
| Size (0x0000000C) |
| Color (0x00000000) |

**Type** **(4 bytes): **0x00000018 identifies the record type as EMR_SETTEXTCOLOR.

**Size** **(4 bytes): **0x0000000C specifies the size of this record in bytes.

**Color** **(4 bytes): **0x00000000 specifies the text color value.

### EMR_SETBKMODE Example 2

This section provides an example of the **EMF** EMR_SETBKMODE record ([MS-EMF] section 2.3.11.11).

000006F0:             12 00 00 00 0C 00 00 00 02 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000012) |
| Size (0x0000000C) |
| BackgroundMode (0x00000002) |

**Type** **(4 bytes): **0x00000012 identifies the record type as EMR_SETBKMODE.

**Size** **(4 bytes): **0x0000000C specifies the size of this record in bytes.

**BackgroundMode** **(4 bytes): **0x00000002 specifies **OPAQUE** background mode. This value is defined in the EMF BackgroundMode enumeration ([MS-EMF] section 2.1.4).

### EMR_SETPOLYFILLMODE Example 2

This section provides an example of the **EMF** EMR_SETPOLYFILLMODE record ([MS-EMF] section 2.3.11.22).

00000700: 13 00 00 00 0C 00 00 00 01 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000013) |
| Size (0x0000000C) |
| PolygonFillMode (0x00000001) |

**Type** **(4 bytes): **0x00000013 identifies the record type as EMR_SETPOLYFILLMODE.

**Size** **(4 bytes): **0x0000000C specifies the size of this record in bytes.

**PolygonFillMode** **(4 bytes): **0x00000001 specifies **ALTERNATE** polygon fill mode. This value is defined in the EMF PolygonFillMode enumeration ([MS-EMF] section 2.1.27).

### EMR_SETROP2 Example 2

This section provides an example of the **EMF** EMR_SETROP2 record ([MS-EMF] section 2.3.11.23).

00000700:                          14 00 00 00 

00000710: 0C 00 00 00 0D 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000014) |
| Size (0x0000000C) |
| ROP2Mode (0x0000000D) |

**Type** **(4 bytes): **0x00000014 identifies the record type as EMR_SETROP2.

**Size** **(4 bytes): **0x0000000C specifies the size of this record in bytes.

**ROP2Mode** **(4 bytes): **0x0000000D specifies the **R2_COPYPEN** raster operation mode. This value is defined in the **WMF** BinaryRasterOperation enumeration ([MS-WMF] section 2.1.1.2).

### EMR_SETSTRETCHBLTMODE Example 2

This section provides an example of the **EMF** EMR_SETSTRETCHBLTMODE record ([MS-EMF] section 2.3.11.24).

00000710:                      15 00 00 00 0C 00 00 00 

00000720: 01 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000015) |
| Size (0x0000000C) |
| StretchMode (0x00000001) |

**Type** **(4 bytes): **0x00000015 identifies the record type as EMR_SETSTRETCHBLTMODE.

**Size** **(4 bytes): **0x0000000C specifies the size of this record in bytes.

**StretchMode** **(4 bytes): **0x00000001 specifies a Boolean AND operation using the color values for the eliminated and existing pixels, from the EMF StretchMode enumeration ([MS-EMF] section 2.1.32).

### EMR_SETTEXTALIGN Example 2

This section provides an example of the **EMF** EMR_SETTEXTALIGN record ([MS-EMF] section 2.3.11.25).

00000720:                 16 00 00 00 0C 00 00 00 00 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000016) |
| Size (0x0000000C) |
| TextAlignmentMode (0x00000000) |

**Type** **(4 bytes): **0x00000016 identifies the record type as EMR_SETTEXTALIGN.

**Size** **(4 bytes): **0x0000000C specifies the size of this record in bytes.

**TextAlignmentMode** **(4 bytes): **0x00000000 specifies text alignment using a mask of **WMF** TextAlignmentMode flags or VerticalTextAlignmentMode flags ([MS-WMF] sections 2.1.2.3 and 2.1.2.4). Only one flag can be chosen from those that affect horizontal and vertical alignment. In addition, only one of the two flags that alter the current position can be chosen.

### EMR_SETBRUSHORGEX Example 3

This section provides an example of the **EMF** EMR_SETBRUSHORGEX record ([MS-EMF] section 2.3.11.12).

00000730: 0D 00 00 00 10 00 00 00 00 00 00 00 00 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x0000000D) |
| Size (0x00000010) |
| Origin (0x00000000) |
| ... (0x00000000) |

**Type** **(4 bytes): **0x0000000D identifies the record type as EMR_SETBRUSHORGEX.

**Size** **(4 bytes): **0x00000010 specifies the size of this record in bytes.

**Origin** **(8 bytes): **(0x00000000, 0x00000000) specifies the brush horizontal and vertical origin in device units.

### EMR_SETMITERLIMIT Example 2

This section provides an example of the **EMF** EMR_SETMITERLIMIT record ([MS-EMF] section 2.3.11.21).

00000740: 3A 00 00 00 0C 00 00 00 0A 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x0000003A) |
| Size (0x0000000C) |
| MiterLimit (0x0000000A) |

**Type** **(4 bytes): **0x0000003A identifies the record type as EMR_SETMITERLIMIT.

**Size** **(4 bytes): **0x0000000C specifies the size of this record in bytes.

**MiterLimit** **(4 bytes): **0x0000000A specifies a **miter length** limit of 10 logical units.

### EMR_MOVETOEX Example 2

This section provides an example of the **EMF** EMR_MOVETOEX record ([MS-EMF] section 2.3.11.4).

00000740:                                     1B 00 00 00 

00000750: 10 00 00 00 00 00 00 00 00 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x0000001B) |
| Size (0x00000010) |
| Offset (0x00000000) |
| ... (0x00000000) |

**Type** **(4 bytes): **0x0000001B identifies the record type as EMR_MOVETOEX.

**Size** **(4 bytes): **0x00000010 specifies the size of this record in bytes.

**Offset** **(8 bytes): **(0x00000000, 0x00000000) specifies coordinates of the new current position in logical units.

### EMR_SETWORLDTRANSFORM Example 2

This section provides an example of the **EMF** EMR_SETWORLDTRANSFORM ([MS-EMF] section 2.3.12.2).

00000750:                                     23 00 00 00

00000760: 20 00 00 00 87 C3 81 3F 00 00 00 00 00 00 00 00

00000770: 7A BD 80 3F 00 00 00 80 00 00 00 80 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000023) |
| Size (0x00000020) |
| Xform (0x3F81C387) (24 bytes) |
| ... (0x00000000) |
| ... (0x00000000) |
| ... (0x3F80BD7A) |
| ... (0x80000000) |
| ... (0x80000000) |

**Type** **(4 bytes): **0x00000023 identifies the record type as EMR_SETWORLDTRANSFORM.

**Size** **(4 bytes): **0x00000020 specifies the size of this record in bytes.

**Xform** **(24 bytes): **(1.005782, 0.000000, 0.000000, 1.013780, 0.000000, 0.000000) an EMF XForm object ([MS-EMF] section 2.2.28), which specifies the **world space** to **page space** transformation.

### EMR_MODIFYWORLDTRANSFORM Example 2

This section provides an example of the **EMF** EMR_MODIFYWORLDTRANSFORM record ([MS-EMF] section 2.3.12.1).

00000780: 24 00 00 00 87 C3 81 3F 00 00 00 00 00 00 00 00

00000790: 7A BD 80 3F 00 00 00 80 00 00 00 80 04 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000024) |
| Size (0x00000024) |
| Xform (0x3F81C387) (24 bytes) |
| ... (0x00000000) |
| ... (0x00000000) |
| ... (0x3F80BD7A) |
| ... (0x80000000) |
| ... (0x80000000) |
| ModifyWorldTransformMode (0x00000004) |

**Type** **(4 bytes): **0x00000024 identifies the record type as EMR_MODIFYWORLDTRANSFORM.

**Size** **(4 bytes): **0x00000024 specifies the size of this record in bytes.

**Xform** **(24 bytes): **(1.005782, 0.000000, 0.000000, 1.013780, 0.000000, 0.000000) an EMF XForm object ([MS-EMF] section 2.2.28), which specifies the **world space** to **page space** transformation.

**ModifyWorldTransformMode** **(4 bytes): **0x00000004 specifies that this record performs the function of an EMF EMR_SETWORLDTRANSFORM record ([MS-EMF] section 2.3.12.2). This value is defined in the EMF ModifyWorldTransformMode enumeration ([MS-EMF] section 2.1.24).

### EMR_SETLAYOUT Example 4

This section provides an example of the **EMF** EMR_SETLAYOUT record ([MS-EMF] section 2.3.11.17).

000007A0: 73 00 00 00 0C 00 00 00 00 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000073) |
| Size (0x0000000C) |
| LayoutMode (0x00000000) |

**Type**: 0x00000073 identifies the record type as EMR_SETLAYOUT.

**Size**: 0x0000000C specifies the size of this record in bytes.

**LayoutMode**: 0x00000000 specifies left-to-right horizontal layout.

### EMR_COMMENT_BEGINGROUP Example

This section provides an example of the **EMF** EMR_COMMENT_BEGINGROUP record ([MS-EMF] section 2.3.3.4.1).

000007A0:                                     46 00 00 00

000007B0: 60 00 00 00 52 00 00 00 47 44 49 43 02 00 00 00

000007C0: 00 00 00 00 00 00 00 00 66 00 00 00 6C 00 00 00

000007D0: 1B 00 00 00 41 00 70 00 70 00 4E 00 61 00 6D 00

000007E0: 65 00 00 00 49 00 6D 00 61 00 67 00 65 00 20 00

000007F0: 44 00 65 00 73 00 63 00 72 00 69 00 70 00 74 00

00000800: 69 00 6F 00 6E 00 00 00 00 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000046) |
| Size (0x00000060) |
| DataSize (0x00000052) |
| Identifier ("GDIC") |
| CommentType (0x00000002) |
| OutputRect (0x00000000) |
| ... (0x00000000) |
| ... (0x00000066) |
| ... (0x0000006C) |
| nDescription (0x0000001B) |
| Description ("AppName Image Description") (60 bytes) |
| ... |
| ... |
| ... |

**Type** **(4 bytes): **0x00000046 identifies the record type as EMF comment ([MS-EMF] section 2.3.3).

**Size** **(4 bytes): **0x00000060 specifies the size of this record in bytes.

**DataSize** **(4 bytes): **0x00000052 specifies the size of the following fields and data in bytes.

**Identifier** **(4 bytes): **"GDIC" identifies this record as EMF EMR_COMMENT_PUBLIC ([MS-EMF] section 2.3.3.4).

**CommentType** **(4 bytes): **0x00000002 identifies the type of EMR_COMMENT_PUBLIC record as EMR_COMMENT_BEGINGROUP, from the EMF EmrComment enumeration ([MS-EMF] section 2.1.10).

**OutputRect** **(16 bytes): **(0x00000000, 0x00000000, 0x00000066, 0x0000006C) defines a **WMF** RectL object ([MS-WMF] section 2.2.2.19), which defines the bounding rectangle for output in logical units.

**nDescription** **(4 bytes): **0x0000001B specifies the number of **Unicode** characters in the description string.

**Description** **(60 bytes): **"AppName Image Description".

### EMR_SETWORLDTRANSFORM Example 3

This section provides an example of the **EMF** EMR_SETWORLDTRANSFORM record ([MS-EMF] section 2.3.12.2).

00000800:                                     23 00 00 00

00000810: 20 00 00 00 FF FF 7F 3F 00 00 00 00 00 00 00 00

00000820: FD FF 7F 3F 00 00 00 00 00 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000023) |
| Size (0x00000020) |
| Xform (0x3F7FFFFF) (24 bytes) |
| ... (0x00000000) |
| ... (0x00000000) |
| ... (0x3F7FFFFD) |
| ... (0x00000000) |
| ... (0x00000000) |

**Type** **(4 bytes): **0x00000023 identifies the record type as EMR_SETWORLDTRANSFORM.

**Size** **(4 bytes): **0x00000020 specifies the size of this record in bytes.

**Xform** **(24 bytes): **(1.000000, 0.000000, 0.000000, 1.000000, 0.000000, 0.000000) an EMF XForm object ([MS-EMF] section 2.2.28), which specifies the **world space** to **page space** transformation.

### EMR_MODIFYWORLDTRANSFORM Example 3

This section provides an example of the **EMF** EMR_MODIFYWORLDTRANSFORM record ([MS-EMF] section 2.3.12.1).

00000820:                                     24 00 00 00

00000830: 24 00 00 00 FF FF 7F 3F 00 00 00 00 00 00 00 00

00000840: FD FF 7F 3F 00 00 00 00 00 00 00 00 04 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000024) |
| Size (0x00000024) |
| Xform (0x3F7FFFFF) (24 bytes) |
| ... (0x00000000) |
| ... (0x00000000) |
| ... (0x3F7FFFFD) |
| ... (0x00000000) |
| ... (0x00000000) |
| ModifyWorldTransformMode (0x00000004) |

**Type** **(4 bytes): **0x00000024 identifies the record type as EMR_MODIFYWORLDTRANSFORM.

**Size** **(4 bytes): **0x00000024 specifies the size of this record in bytes.

**Xform** **(24 bytes): **(1.000000, 0.000000, 0.000000, 1.000000, 0.000000, 0.000000) an EMF XForm object ([MS-EMF] section 2.2.28), which specifies the **world space** to **page space** transformation.

**ModifyWorldTransformMode** **(4 bytes): **0x00000004 specifies that this record performs the function of an EMF EMR_SETWORLDTRANSFORM record ([MS-EMF] section 2.3.12.2). This value is defined in the EMF ModifyWorldTransformMode enumeration ([MS-EMF] section 2.1.24).

### EMR_MODIFYWORLDTRANSFORM Example 4

This section provides an example of the **EMF** EMR_MODIFYWORLDTRANSFORM record ([MS-EMF] section 2.3.12.1).

000008B0:             24 00 00 00 24 00 00 00 0D 74 DA 3A

000008C0: 00 00 00 00 00 00 00 00 0C 74 DA 3A 00 00 00 00

000008D0: 00 00 00 00 04 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000024) |
| Size (0x00000024) |
| Xform (0x3ADA740D) (24 bytes) |
| ... (0x00000000) |
| ... (0x00000000) |
| ... (0x3ADA740C) |
| ... (0x00000000) |
| ... (0x00000000) |
| ModifyWorldTransformMode (0x00000004) |

**Type** **(4 bytes): **0x00000024 identifies the record type as EMR_MODIFYWORLDTRANSFORM.

**Size** **(4 bytes): **0x00000024 specifies the size of this record in bytes.

**Xform** **(24 bytes): **(0.001667, 0.000000, 0.000000, 0.001667, 0.000000, 0.000000,) an EMF XForm object ([MS-EMF] section 2.2.28), which specifies the **world space** to **page space** transformation.

**ModifyWorldTransformMode** **(4 bytes): **0x00000004 specifies that this record performs the function of an EMF EMR_SETWORLDTRANSFORM record ([MS-EMF] section 2.3.12.2). This value is defined in the EMF ModifyWorldTransformMode enumeration ([MS-EMF] section 2.1.24).

### EMR_MODIFYWORLDTRANSFORM Example 5

This section provides an example of the **EMF** EMR_MODIFYWORLDTRANSFORM record ([MS-EMF] section 2.3.12.1).

000008F0:                         24 00 00 00 24 00 00 00

00000900: 92 5F 2C 3E 00 00 00 00 00 00 00 00 E9 51 38 3E

00000910: 00 00 00 00 00 00 00 00 04 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000024) |
| Size (0x00000024) |
| Xform (0x3E2C5F92) (24 bytes) |
| ... (0x00000000) |
| ... (0x00000000) |
| ... (0x3E3851E9) |
| ... (0x00000000) |
| ... (0x00000000) |
| ModifyWorldTransformMode (0x00000004) |

**Type** **(4 bytes): **0x00000024 identifies the record type as EMR_MODIFYWORLDTRANSFORM.

**Size** **(4 bytes): **0x00000024 specifies the size of this record in bytes.

**Xform** **(24 bytes): **(0.180000, 0.000000, 0.000000, 0.168333, 0.000000, 0.000000) an EMF XForm object ([MS-EMF] section 2.2.28), which specifies the **world space** to **page space** transformation.

**ModifyWorldTransformMode** **(4 bytes): **0x00000004 specifies that this record performs the function of an EMF EMR_SETWORLDTRANSFORM record ([MS-EMF] section 2.3.12.2). This value is defined in the EMF ModifyWorldTransformMode enumeration ([MS-EMF] section 2.1.24).

### EMR_SELECTOBJECT Example 10

This section provides an example of the **EMF** EMR_SELECTOBJECT record ([MS-EMF] section 2.3.8.5).

00000910:                         25 00 00 00

00000920: 0C 00 00 00 05 00 00 80 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000025) |
| Size (0x0000000C) |
| ihObject (0x80000005=NULL_BRUSH) |

**Type** **(4 bytes): **0x00000025 identifies the record type as EMR_SELECTOBJECT.

**Size** **(4 bytes): **0x0000000C specifies the size of this record in bytes.

**ihObject** **(4 bytes): **0x80000005 specifies the index of an object in the EMF+ Object Table (section 3.1.2).

### EMR_ROUNDRECT Example

This section provides an example of the **EMF** EMR_ROUNDRECT record ([MS-EMF] section 2.3.5.35).

00000920:                         2C 00 00 00 20 00 00 00 

00000930: FD FF FF FF FE FF FF FF 4F 02 00 00 50 02 00 00

00000940: C8 00 00 00 C8 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x0000002C) |
| Size (0x00000020) |
| Box (0xFFFFFFFD) |
| ... (0xFFFFFFFE) |
| ... (0x0000024F) |
| ... (0x00000250) |
| Corner (0x000000C8) |
| ... (0x000000C8) |

**Type** **(4 bytes): **0x0000002C identifies the record type as EMR_ROUNDRECT.

**Size** **(4 bytes): **0x00000020 specifies the size of this record in bytes.

**Box** **(16 bytes): **(0xFFFFFFFD, 0xFFFFFFFE, 0x0000024F, 0x00000250) defines the inclusive-inclusive bounding rectangle in logical coordinates.

**Corner** **(8 bytes): **(0x000000C8, 0x000000C8) specifies the width and height, in logical coordinates, of the ellipse used to draw the rounded corners.

### EMR_COMMENT_ENDGROUP Example

This section provides an example of the **EMF** EMR_COMMENT_ENDGROUP record ([MS-EMF] section 2.3.3.4.2).

00000940:                               46 00 00 00 14 00 00 00 

00000950: 08 00 00 00 47 44 49 43 03 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000046) |
| Size (0x00000014) |
| DataSize (0x00000008) |
| Identifier ("GDIC") |
| CommentType (0x00000003) |

**Type** **(4 bytes): **0x00000046 identifies the record type as EMF comment ([MS-EMF] section 2.3.3).

**Size** **(4 bytes): **0x00000014 specifies the size of this record in bytes.

**DataSize** **(4 bytes): **0x00000008 specifies the size of the following fields and data in bytes.

**Identifier** **(4 bytes): **"GDIC" identifies this record as EMR_COMMENT_PUBLIC ([MS-EMF] section 2.3.3.4).

**CommentType** **(4 bytes): **0x00000003 identifies the type of EMR_COMMENT_PUBLIC record as EMR_COMMENT_ENDGROUP, from the EMF EmrComment enumeration ([MS-EMF] section 2.1.10).

### EMR_RESTOREDC Example 4

This section provides an example of the **EMF** EMR_RESTOREDC record ([MS-EMF] section 2.3.11.6).

00000950:                              22 00 00 00 

00000960: 0C 00 00 00 FF FF FF FF

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000022) |
| Size (0x0000000C) |
| SavedDC (0xFFFFFFFF) |

**Type** **(4 bytes): **0x00000022 identifies the record type as EMR_RESTOREDC.

**Size** **(4 bytes): **0x0000000C specifies the size of this record in bytes.

**SavedDC** **(4 bytes): **0xFFFFFFFF specifies the most recently saved state.

### EMR_COMMENT_EMFPLUS Example 4

This section provides an example of the **EMF** EMR_COMMENT_EMFPLUS record ([MS-EMF] section 2.3.3.2).

00000960:                         46 00 00 00 54 00 00 00

00000970: 48 00 00 00 45 4D 46 2B

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000046) |
| Size (0x00000054) |
| DataSize (0x00000048) |
| EMFPlusSignature ("EMF+") |

**Type** **(4 bytes): **0x00000046 identifies the record type as EMF comment ([MS-EMF] section 2.3.3).

**Size** **(4 bytes): **0x00000054 specifies the size of this record in bytes, including embedded EMF+ records.

**DataSize** **(4 bytes): **0x00000048 specifies the size of the **EMF+** data in bytes.

**EMFPlusSignature** **(4 bytes): **"EMF+" identifies the comment record type as EMR_COMMENT_EMFPLUS.

The embedded EMF+ records are presented in the sections that follow.

#### EmfPlusEndContainer Example

This section provides an example of the EmfPlusEndContainer record (section 2.3.7.3).

00000970:                         40 00 00 10 00 00 00

00000980: 04 00 00 00 01 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x4029) | Flags (0x0000) |
| Size (0x00000010) |
| DataSize (0x00000004) |
| StackIndex (0x00000001) |

**Type** **(2 bytes): **0x4029 identifies the record type as EmfPlusEndContainer.

**Flags** **(2 bytes): **0x0000 This field is undefined for this record type.

**Size** **(4 bytes): **0x00000010 specifies the 32-bit-aligned size of the entire record in bytes, including the 12-byte record header and the record-specific buffer data.

**DataSize** **(4 bytes): **0x00000004 specifies the 32-bit-aligned number of bytes of data in the **PointData** member that follows. This number does not include the size of the invariant part of this record.

**StackIndex** **(4 bytes): **0x00000001 specifies the identifier used to reference the container in future records.

#### EmfPlusRestore Example

This section provides an example of the EmfPlusRestore record (section 2.3.7.4).

00000980:                         26 40 00 00 10 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x4026) | Flags (0x0000) |
| Size (0x00000010) |
| DataSize (0x00000004) |
| StackIndex (0x00000000) |

**Type** **(2 bytes): **0x4026 identifies the record type as EmfPlusRestore.

**Flags** **(2 bytes): **0x0000 This value is undefined for this record type.

**Size** **(4 bytes): **0x00000010 specifies the 32-bit-aligned size of the entire record in bytes, including the 12-byte record header and the record-specific buffer data.

**DataSize** **(4 bytes): **0x00000004 specifies the 32-bit-aligned number of bytes of data in the **PointData** member that follows. This number does not include the size of the invariant part of this record. 

**StackIndex** **(4 bytes): **0x00000000 specifies the identifier used to retrieve the graphics state from the correct save level on the graphics state stack.

#### EmfPlusSetWorldTransform Example

This section provides an example of the EmfPlusSetWorldTransform record (section 2.3.9.6).

00000990:                         2A 40 00 00 24 00 00 00

000009A0: 18 00 00 00 00 00 80 3F 00 00 00 00 00 00 00 00

000009B0: 00 00 80 3F 00 00 00 00 00 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x402A) | Flags (0x0000) |
| Size (0x00000024) |
| DataSize (0x00000018) |
| MatrixData (0x3F800000) (24 bytes) |
| ... (0x00000000) |
| ... (0x00000000) |
| ... (0x3F800000) |
| ... (0x00000000) |
| ... (0x00000000) |

**Type** **(2 bytes): **0x402A identifies the record type as EmfPlusSetWorldTransform.

**Flags** **(2 bytes): **0x0000 is undefined for this record type.

**Size** **(4 bytes): **0x00000024 specifies the size in bytes of the entire record.

**DataSize** **(4 bytes): **0x00000018 specifies the size in bytes of the **MatrixData** field that follows. 

**MatrixData** **(24 bytes): **An EmfPlusTransformMatrix object (section 2.2.2.47) that contains the **world space** **transform**.

### EMR_BITBLT Example

This section provides an example of the **EMF** EMR_BITBLT record ([MS-EMF] section 2.3.1.2).

000009B0:                                     4C 00 00 00

000009C0: 64 00 00 00 FF FF FF FF FF FF FF FF 64 00 00 00

000009D0: 6B 00 00 00 FF FF FF FF FF FF FF FF 66 00 00 00

000009E0: 6D 00 00 00 29 00 AA 00 00 00 00 00 00 00 00 00

000009F0: 00 00 80 3F 00 00 00 00 00 00 00 00 00 00 80 3F

00000A00: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00

00000A10: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x0000004C) |
| Size (0x00000064) |
| Bounds (0xFFFFFFFF) |
| ... (0xFFFFFFFF) |
| ... (0x00000064) |
| ... (0x0000006B) |
| xDest (0xFFFFFFFF) |
| yDest (0xFFFFFFFF) |
| cxDest (0x00000066) |
| cyDest (0x0000006D) |
| BitBlitRasterOperation (0x00AA0029) |
| xSrc (0x00000000) |
| ySrc (0x00000000) |
| xformSrc (0x3F800000) (24 bytes) |
| ... (0x00000000) |
| ... (0x00000000) |
| ... (0x3F800000) |
| ... (0x00000000) |
| ... (0x00000000) |
| BkColorSrc (0x00000000) |

**Type** **(4 bytes): **0x0000004C identifies the record type as EMR_BITBLT.

**Size** **(4 bytes): **0x00000064 specifies the size of this record in bytes.

**Bounds** **(16 bytes): **(0xFFFFFFFF, 0xFFFFFFFF, 0x00000064, 0x0000006B) defines the bounding rectangle in device units.

**xDest** **(4 bytes): **0xFFFFFFFF specifies the logical x-coordinate of the upper-left corner of the destination rectangle.

**yDest** **(4 bytes): **0xFFFFFFFF specifies the logical y-coordinate of the upper-left corner of the destination rectangle.

**cxDest** **(4 bytes): **0x00000066 specifies the logical width of the destination rectangle.

**cyDest** **(4 bytes): **0x0000006D specifies the logical height of the destination rectangle.

**BitBlitRasterOperation** **(4 bytes): **0x00AA0029 specifies the **raster operation** code. These codes define how the color data of the source rectangle is to be combined with the color data of the destination rectangle to achieve the final color. This value is defined in the **WMF** TernaryRasterOperation enumeration ([MS-WMF] section 2.1.1.31).

**xSrc** **(4 bytes): **0x00000000 specifies the logical x-coordinate of the upper-left corner of the source rectangle.

**ySrc** **(4 bytes): **0x00000000 specifies the logical y-coordinate of the upper-left corner of the source rectangle.

**xformSrc** **(24 bytes): **(0x3F800000, 0x00000000, 0x00000000, 0x3F800000, 0x00000000, 0x00000000) defines the **world space** to **page space** transformation of the source **bitmap**.

**BkColorSrc** **(4 bytes): **0x00000000 specifies the background color of the source bitmap.

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| UsageSrc (0x00000000) |
| offBmiSrc (0x00000000) |
| cbBmiSrc (0x00000000) |
| offBitsSrc (0x00000000) |
| cbBitsSrc (0x00000000) |

**UsageSrc** **(4 bytes): **0x00000000 specifies that the color table in the WMF DeviceIndependentBitmap object ([MS-WMF] section 2.2.2.9) header contains **RGB** values. This value is defined in the EMF DIBColors enumeration ([MS-EMF] section 2.1.9).

**offBmiSrc** **(4 bytes): **0x00000000 specifies the offset to the source **device-independent bitmap (DIB)** object header.

**cbBmiSrc** **(4 bytes): **0x00000000 specifies the size of the source DIB object header.

**offBitsSrc** **(4 byte****s): **0x00000000 specifies the offset to the source bitmap bits.

**cbBitsSrc** **(4 bytes): **0x00000000 specifies the size of the source bitmap bits.

### EMR_RESTOREDC Example 5

This section provides an example of the **EMF** EMR_RESTOREDC record ([MS-EMF] section 2.3.11.6).

00000A20: 22 00 00 00 0C 00 00 00 FF FF FF FF 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000022) |
| Size (0x0000000C) |
| SavedDC (0xFFFFFFFF) |

**Type** **(4 bytes): **0x00000022 identifies the record type as EMR_RESTOREDC.

**Size** **(4 bytes): **0x0000000C specifies the size of this record in bytes.

**SavedDC** **(4 bytes): **0xFFFFFFFF specifies the most recently saved state.

### EMR_COMMENT_EMFPLUS Example 5

This section provides an example of the **EMF** EMR_COMMENT_EMFPLUS record ([MS-EMF] section 2.3.3.2).

00000A20:                                     46 00 00 00

00000A30: 1C 00 00 00 10 00 00 00 45 4D 46 2B

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x00000046) |
| Size (0x0000001C) |
| DataSize (0x00000010) |
| EMFPlusSignature (0x2B464D45 = "EMF+") |

**Type** **(4 bytes): **0x00000046 identifies the record type as EMF comment ([MS-EMF] section 2.3.3).

**Size** **(4 bytes): **0x0000001C specifies the size of this record in bytes, including embedded EMF+ records.

**DataSize** **(4 bytes): **0x00000010 specifies the size of the **EMF+** data in bytes.

**EMFPlusSignature** **(4 bytes): **"EMF+" identifies the comment record type as EMR_COMMENT_EMFPLUS.

The embedded EMF+ records are presented in the sections that follow.

#### EmfPlusEndOfFile Example

This section provides an example of the EmfPlusEndOfFile record (section 2.3.3.1).

00000A30:                                     02 40 00 00

00000A40: 0C 00 00 00 00 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x4002) | Flags (0x0000) |
| Size (0x0000000C) |
| DataSize (0x00000000) |

**Type** **(2 bytes): **0x4002 identifies the record type as EmfPlusEndOfFile.

**Flags** **(2 bytes): **0x0000 is not used by this record type.

**Size** **(4 bytes): **0x0000000C specifies the 32-bit-aligned size of this record in bytes.

**DataSize** **(4 bytes): **0x00000000 specifies that no bytes of data follow.

### EMR_EOF Example

This section provides an example of the **EMF** EMR_EOF record ([MS-EMF] section 2.3.4.1).

00000A40:                   0E 00 00 00 14 00 00 00

00000A50: 00 00 00 00 10 00 00 00 14 00 00 00 

| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 20 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 30 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Type (0x0000000E) |
| Size (0x00000014) |
| nPalEntries (0x00000000) |
| offPalEntries (0x00000000) |
| PaletteEntries (0x00000010) |
| SizeLast (0x00000014) |

**Type** **(4 bytes): **0x0000000E identifies the record type as EMR_EOF.

**Size** **(4 bytes): **0x00000014 specifies the size of this record in bytes.

**nPalEntries** **(4 bytes): **0x00000000 specifies the number of **palette** entries.

**offPalEntries** **(4 bytes): **0x00000000 is ignored, as no palette entries are defined.

**PaletteEntries** **(4 bytes): **0x00000010 is ignored, as no palette entries are defined.

**SizeLast** **(4 ****bytes): **0x00000014 specifies a value that is the same as **Size**, and is the last field of the **metafile**.

## EMF+ String Drawing Example

This section provides an example of **EMF+** string drawing as generated by **GDI+** functions.

The following GDI+ example generates an EmfPlusDrawString record (section 2.3.4.14) and EmfPlusFont and EmfPlusStringFormatData objects (sections 2.2.1.3 and 2.2.2.44).

GdiplusStartupInput gdiplusStartupInput;

GdiplusStartupOutput gdiplusStartupOutput;

ULONG_PTR gdiplusToken = 0;

int CALLBACK WinMain( HINSTANCE, HINSTANCE, LPSTR, int )

{

    // InitializeGdiPlus

    GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, &gdiplusStartupOutput);

    HDC DeviceContext = GetDC( nullptr );

    Metafile File( L"DrawString.emf", DeviceContext, EmfTypeEmfPlusOnly, L"DrawString Demo" );

    Graphics RenderTarget( &File );

    FontFamily Family( L"Arial" );

    Font EffectiveFont( &Family, 40.0f, FontStyle::FontStyleUnderline, UnitPixel );

    RectF LayoutRect( 0, 0, 100, 100 );

    Gdiplus::StringFormat Format( 0, 0 );

    Format.SetAlignment( Gdiplus::StringAlignment::StringAlignmentFar );

    Gdiplus::Rect GradientRect( 0, 0, 100, 100 );

    Gdiplus::LinearGradientBrush

        TestBrush( GradientRect,

                   Gdiplus::Color( 0xff, 0x00, 0x00 ),

                   Gdiplus::Color( 0x00, 0x00, 0xff ),

                   0.0f );

    const wchar_t HelloWorld[] = L"Hello World 1 2 3 4!";

    RenderTarget.DrawString( HelloWorld,

                             ARRAYSIZE(HelloWorld) - 1,

                             &EffectiveFont,

                             LayoutRect,

                             &Format,

                             &TestBrush );

    ReleaseDC( nullptr, DeviceContext );

    return 1;

}

The EMF+ **metafile** generated by the preceding GDI+ example renders the following image:

Figure 6: EMF+ string drawing example
