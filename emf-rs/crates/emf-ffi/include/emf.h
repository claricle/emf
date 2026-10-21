#ifndef EMF_H
#define EMF_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define EMF_ABI_VERSION 1u
#define EMF_OK 0
#define EMF_INVALID_ARGUMENT 1
#define EMF_FORMAT_ERROR 2
#define EMF_LIMIT_EXCEEDED 3
#define EMF_SERIALIZE_ERROR 4
#define EMF_INTERNAL_ERROR 5
#define EMF_ALLOCATION_FAILED 6

#define EMF_FORMAT_UNKNOWN 0u
#define EMF_FORMAT_EMF 1u
#define EMF_FORMAT_WMF_APM 2u
#define EMF_FORMAT_WMF_STANDARD 3u
#define EMF_FAMILY_RAW 0u
#define EMF_FAMILY_EOF 1u
#define EMF_FAMILY_SETMAPMODE 2u
#define EMF_FAMILY_POLYLINE 3u
#define EMF_FAMILY_COMMENT 4u
#define EMF_FAMILY_SETBKMODE 5u
#define EMF_FAMILY_SETPOLYFILLMODE 6u
#define EMF_FAMILY_SETROP2 7u
#define EMF_FAMILY_SETSTRETCHBLTMODE 8u
#define EMF_FAMILY_SETWINDOWEXTEX 9u
#define EMF_FAMILY_SETWINDOWORGEX 10u
#define EMF_FAMILY_SETVIEWPORTEXTEX 11u
#define EMF_FAMILY_SETVIEWPORTORGEX 12u
#define EMF_FAMILY_SETBRUSHORGEX 13u
#define EMF_FAMILY_OFFSETCLIPRGN 14u
#define EMF_FAMILY_MOVETOEX 15u
#define EMF_FAMILY_SETTEXTCOLOR 16u
#define EMF_FAMILY_SETBKCOLOR 17u
#define EMF_FAMILY_ELLIPSE 18u
#define EMF_FAMILY_RECTANGLE 19u
#define EMF_FAMILY_ROUNDRECT 20u
#define EMF_FAMILY_SETTEXTALIGN 21u
#define EMF_FAMILY_SAVEDC 22u
#define EMF_FAMILY_RESTOREDC 23u
#define EMF_FAMILY_SELECTOBJECT 24u
#define EMF_FAMILY_DELETEOBJECT 25u
#define EMF_FAMILY_SETARCDIRECTION 26u
#define EMF_FAMILY_BEGINPATH 27u
#define EMF_FAMILY_ENDPATH 28u
#define EMF_FAMILY_CLOSEFIGURE 29u
#define EMF_FAMILY_FILLPATH 30u
#define EMF_FAMILY_STROKEANDFILLPATH 31u
#define EMF_FAMILY_STROKEPATH 32u
#define EMF_FAMILY_SELECTCLIPPATH 33u
#define EMF_FAMILY_ABORTPATH 34u
#define EMF_FAMILY_SETPIXELV 35u
#define EMF_FAMILY_EXCLUDECLIPRECT 36u
#define EMF_FAMILY_INTERSECTCLIPRECT 37u
#define EMF_FAMILY_CREATEPEN 38u
#define EMF_FAMILY_CREATEBRUSHINDIRECT 39u
#define EMF_FAMILY_ARC 40u
#define EMF_FAMILY_CHORD 41u
#define EMF_FAMILY_PIE 42u
#define EMF_FAMILY_LINETO 43u
#define EMF_FAMILY_ARCTO 44u
#define EMF_FAMILY_POLYBEZIER 45u
#define EMF_FAMILY_POLYGON 46u
#define EMF_FAMILY_POLYBEZIERTO 47u
#define EMF_FAMILY_POLYLINETO 48u
#define EMF_FAMILY_POLYBEZIER16 49u
#define EMF_FAMILY_POLYGON16 50u
#define EMF_FAMILY_POLYLINE16 51u
#define EMF_FAMILY_POLYBEZIERTO16 52u
#define EMF_FAMILY_POLYLINETO16 53u
#define EMF_FAMILY_POLYPOLYLINE 54u
#define EMF_FAMILY_POLYPOLYGON 55u
#define EMF_FAMILY_POLYPOLYLINE16 56u
#define EMF_FAMILY_POLYPOLYGON16 57u
#define EMF_FAMILY_POLYDRAW 58u
#define EMF_FAMILY_POLYDRAW16 59u
#define EMF_FAMILY_SCALEVIEWPORTEXTEX 60u
#define EMF_FAMILY_SCALEWINDOWEXTEX 61u
#define EMF_FAMILY_SETWORLDTRANSFORM 62u
#define EMF_FAMILY_MODIFYWORLDTRANSFORM 63u
#define EMF_FAMILY_ANGLEARC 64u
#define EMF_FAMILY_SETMITERLIMIT 65u
#define EMF_FAMILY_SETMAPPERFLAGS 66u
#define EMF_FAMILY_SETMETARGN 67u
#define EMF_FAMILY_SEMANTIC_EXTFLOODFILL 91u
#define EMF_FAMILY_SEMANTIC_SETTEXTJUSTIFICATION 92u
#define EMF_FAMILY_EXTFLOODFILL 68u
#define EMF_FAMILY_FLATTENPATH 69u
#define EMF_FAMILY_WIDENPATH 70u
#define EMF_FAMILY_SETICMMODE 71u
#define EMF_FAMILY_SETLAYOUT 72u
#define EMF_FAMILY_SETTEXTJUSTIFICATION 73u

#define EMF_PLUS_SNAPSHOT_VERSION 1u
/* Adds per-comment recovering framing and the typed SetTSClip family (0x106). */
#define EMF_PLUS_SNAPSHOT_VERSION_2 2u
/* Independent read-only EMF+ snapshot options, not an outer snapshot version. */
typedef struct emf_plus_snapshot_options {
  uint32_t struct_size;
  uint32_t version;
  uint64_t max_output_bytes;
} emf_plus_snapshot_options;

typedef struct emf_document emf_document;
typedef struct emf_wmf_document emf_wmf_document;
typedef struct emf_buffer emf_buffer;
typedef struct emf_error emf_error;

/* Input limits: zero is a ceiling of zero, not a default. NULL selects defaults.
 * Byte/count ceilings must fit native size_t; max_work_units uses uint64_t.
 * struct_size must equal sizeof(emf_limits), version must be EMF_ABI_VERSION.
 * Fields occupy offsets 0,4,8,16,24,32,40; total size 48 bytes.
 */
typedef struct emf_limits {
    uint32_t struct_size;
    uint32_t version;
    uint64_t max_input_bytes;
    uint64_t max_record_bytes;
    uint64_t max_records;
    uint64_t max_allocated_bytes;
    uint64_t max_work_units;
} emf_limits;

/* Initialize struct_size/version before calling. Outputs preserve those fields.
 * Counts exclude the header, include EOF, and describe framed raw records only.
 * Offsets 0,4,8,12,16,24,32,40,48,56; size 64 bytes.
 */
typedef struct emf_info {
    uint32_t struct_size;
    uint32_t version;
    uint32_t format;
    uint32_t has_eof;
    uint64_t header_bytes;
    uint64_t record_count;
    uint64_t diagnostic_count;
    uint64_t trailing_bytes;
    uint64_t unframed_bytes;
    uint64_t reserved;
} emf_info;

/* Offsets 0,4,8,16,24,32,36; size 40 bytes. The function initializes each
 * returned descriptor's struct_size/version. Index zero follows the header.
 */
typedef struct emf_record_descriptor {
    uint32_t struct_size;
    uint32_t version;
    uint64_t index;
    uint64_t offset;
    uint64_t byte_length;
    uint32_t type_id;
    uint32_t family;
} emf_record_descriptor;

/* Initialize struct_size/version before calling. category equals status in this
 * framing subset. has_offset is 0 or 1; reserved is zero. Message is UTF-8,
 * not NUL-terminated, and remains valid until emf_error_free(error).
 * Offsets 0,4,8,12,16,20,24,32,40; size 48 on 64-bit hosts.
 * On 32-bit hosts message_length follows the pointer with native uint64_t
 * alignment; callers use sizeof/offsetof rather than hardcoded pointer layouts.
 */
typedef struct emf_error_info {
    uint32_t struct_size;
    uint32_t version;
    int32_t status;
    uint32_t category;
    uint32_t has_offset;
    uint32_t reserved;
    uint64_t offset;
    const uint8_t *message;
    uint64_t message_length;
} emf_error_info;

/* All pointers must reference valid, aligned memory for their declared type or
 * range. NULL input data is accepted only with length zero. Output pointers are
 * required except out_error, which is optional. Handles/counts are cleared on
 * entry, including failure. Non-NULL limits/info must have the exact size and
 * version. Buffers own their bytes independently of document/input lifetimes.
 * Free accepts NULL; double-free and wrong-kind handles are invalid.
 * Independent handles may be used concurrently. Serialize access to the same
 * handle, and never free a handle while it is in use. The caller owns returned
 * handles and frees them exactly once. Allocation aborts cannot be recovered.
 *
 * Typed snapshots cover EOF, SETMAPMODE, POLYLINE, COMMENT and scalar state
 * records, plus coordinate records SETWINDOWEXTEX, SETWINDOWORGEX,
 * SETVIEWPORTEXTEX, SETVIEWPORTORGEX, SETBRUSHORGEX, OFFSETCLIPRGN and MOVETOEX.
 * Color records SETTEXTCOLOR and SETBKCOLOR and shapes ELLIPSE, RECTANGLE and
 * ROUNDRECT, fixed state/selection records and path lifecycle/consume records
 * are also typed, along with fixed geometry, pen/brush creation, and signed
 * 16-bit and 32-bit point-array records.
 * Other records remain raw. Snapshot bytes use the
 * encoding documented in snapshot-v2.md.
 * Snapshot versions are independent of ABI versions.
 * EMF documents are immutable through this ABI. WMF supports record replacement.
 * emf_parse supports EMF; emf_wmf_parse supports standard and placeable WMF.
 */
uint32_t emf_abi_version(void);
int32_t emf_detect(const uint8_t *data, uint64_t length, uint32_t *out_format, emf_error **out_error);
int32_t emf_parse(const uint8_t *data, uint64_t length, const emf_limits *limits, emf_document **out_document, emf_error **out_error);
int32_t emf_document_info(const emf_document *document, emf_info *out_info);
/* start == record_count succeeds with zero results; larger starts are invalid.
 * capacity zero permits NULL out_descriptors. Otherwise it must hold capacity
 * descriptors. At most capacity records are written, in source order.
 */
int32_t emf_record_batch(const emf_document *document, uint64_t start, uint64_t capacity, emf_record_descriptor *out_descriptors, uint64_t *out_count);
/* Owned bulk snapshot: decoded header, typed records, diagnostics and tails.
 * No raw record bytes are duplicated; use emf_record_bytes for wire hydration.
 */
int32_t emf_document_snapshot(const emf_document *document, emf_buffer **out_buffer, emf_error **out_error);
int32_t emf_record_bytes(const emf_document *document, uint64_t index, emf_buffer **out_buffer, emf_error **out_error);
int32_t emf_serialize(const emf_document *document, emf_buffer **out_buffer, emf_error **out_error);
/* WMF handles use the same limits, statuses, buffer ownership and descriptor layouts.
 * type_id is the original 16-bit META function; family is EOF or RAW.
 * header_bytes includes the optional 22-byte placeable prefix. Trailing bytes
 * follow valid EOF; unframed bytes are the remainder after malformed framing.
 * Record descriptors/bytes describe original source spans, including after edits.
 * Replacement payload excludes the six-byte record header and must be word aligned.
 * Failed edits preserve the document. Serialization updates length/max-record fields.
 * Replacement requires exclusive access to the handle; concurrent readers are forbidden.
 * WMF and EMF document handles must never be interchanged.
 */
int32_t emf_wmf_parse(const uint8_t *data, uint64_t length, const emf_limits *limits, emf_wmf_document **out_document, emf_error **out_error);
int32_t emf_wmf_document_info(const emf_wmf_document *document, emf_info *out_info);
int32_t emf_wmf_record_batch(const emf_wmf_document *document, uint64_t start, uint64_t capacity, emf_record_descriptor *out_descriptors, uint64_t *out_count);
int32_t emf_wmf_record_bytes(const emf_wmf_document *document, uint64_t index, emf_buffer **out_buffer, emf_error **out_error);
int32_t emf_wmf_replace_record(emf_wmf_document *document, uint64_t index, uint32_t function, const uint8_t *data, uint64_t length, emf_error **out_error);
/* Owned WMFS v1 little-endian snapshot; maximum output 200 MiB.
 * Uses the current serialized document after edits, reparsed with default limits.
 * Free the returned buffer with emf_buffer_free. */
int32_t emf_wmf_document_snapshot(const emf_wmf_document *document, emf_buffer **out_buffer, emf_error **out_error);
int32_t emf_wmf_serialize(const emf_wmf_document *document, emf_buffer **out_buffer, emf_error **out_error);
void emf_wmf_document_free(emf_wmf_document *document);
int32_t emf_buffer_view(const emf_buffer *buffer, const uint8_t **out_data, uint64_t *out_length);
int32_t emf_error_view(const emf_error *error, emf_error_info *out_info);
void emf_document_free(emf_document *document);
void emf_buffer_free(emf_buffer *buffer);
void emf_error_free(emf_error *error);

/* All nested frames in one owned buffer. See emf-plus-snapshot-v1.md.
 * options is required; limits is optional (core defaults). Existing ABI/version
 * and outer snapshot schema are unchanged. On failure *out_buffer is NULL.
 * Free returned buffers/errors with emf_buffer_free/emf_error_free. */
int32_t emf_document_emf_plus_snapshot_v1(
    const emf_document *document, const emf_plus_snapshot_options *options,
    const emf_limits *limits, emf_buffer **out_buffer, emf_error **out_error);

#ifdef __cplusplus
}
#endif
#endif
