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

typedef struct emf_document emf_document;
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
 * Typed snapshots cover EOF, SETMAPMODE, POLYLINE and COMMENT; other records
 * remain raw. Snapshot bytes use the encoding documented in snapshot-v1.md.
 * Documents are immutable through this ABI.
 * Detection recognizes WMF signatures; parsing supports EMF only.
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
int32_t emf_buffer_view(const emf_buffer *buffer, const uint8_t **out_data, uint64_t *out_length);
int32_t emf_error_view(const emf_error *error, emf_error_info *out_info);
void emf_document_free(emf_document *document);
void emf_buffer_free(emf_buffer *buffer);
void emf_error_free(emf_error *error);

#ifdef __cplusplus
}
#endif
#endif
