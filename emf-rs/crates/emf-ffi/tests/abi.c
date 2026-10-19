#include "emf.h"

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CHECK(expr) do { \
    if (!(expr)) { \
        fprintf(stderr, "%s:%d: check failed: %s\n", __FILE__, __LINE__, #expr); \
        return 1; \
    } \
} while (0)

#define INPUT_CAPACITY 256u
#define HEADER_SIZE 88u
#define UNKNOWN_TYPE UINT32_C(0x7fff0001)

static uint8_t input[INPUT_CAPACITY];
static size_t input_length;

typedef struct cursor {
    const uint8_t *bytes;
    size_t length;
    size_t offset;
} cursor;

static int take(cursor *c, size_t n, const uint8_t **out) {
    if (n > c->length - c->offset) return 0;
    *out = c->bytes + c->offset;
    c->offset += n;
    return 1;
}

static int get_u32(cursor *c, uint32_t *out) {
    const uint8_t *p;
    if (!take(c, 4, &p)) return 0;
    *out = (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
    return 1;
}

static int get_u64(cursor *c, uint64_t *out) {
    const uint8_t *p;
    if (!take(c, 8, &p)) return 0;
    *out = 0;
    for (unsigned i = 0; i < 8; ++i) *out |= (uint64_t)p[i] << (8u * i);
    return 1;
}

static int get_i32(cursor *c, int32_t *out) {
    uint32_t value;
    if (!get_u32(c, &value)) return 0;
    memcpy(out, &value, sizeof(value));
    return 1;
}

static int skip(cursor *c, size_t n) {
    const uint8_t *ignored;
    return take(c, n, &ignored);
}

static void put_u16(size_t offset, uint16_t value) {
    input[offset] = (uint8_t)value;
    input[offset + 1] = (uint8_t)(value >> 8);
}

static void put_u32(size_t offset, uint32_t value) {
    input[offset] = (uint8_t)value;
    input[offset + 1] = (uint8_t)(value >> 8);
    input[offset + 2] = (uint8_t)(value >> 16);
    input[offset + 3] = (uint8_t)(value >> 24);
}

static void make_fixture(void) {
    memset(input, 0, sizeof(input));
    /* EMR_HEADER, 88 bytes. */
    put_u32(0, 1);
    put_u32(4, HEADER_SIZE);
    put_u32(16, 99);             /* bounds.right */
    put_u32(36, 1250);           /* frame.bottom */
    put_u32(40, UINT32_C(0x464d4520));
    put_u32(44, UINT32_C(0x00010000));
    put_u32(48, HEADER_SIZE + 40); /* nBytes: entire file */
    put_u32(52, 3);              /* nRecords: header, unknown record, EOF */
    put_u16(56, 1);              /* nHandles */
    put_u32(72, 1024);            /* device.cx */
    put_u32(76, 768);
    put_u32(80, 270);
    put_u32(84, 203);

    /* Unknown record with an odd, byte-exact payload and no padding. */
    put_u32(HEADER_SIZE, UNKNOWN_TYPE);
    put_u32(HEADER_SIZE + 4, 15);
    input[HEADER_SIZE + 8] = 0xde;
    input[HEADER_SIZE + 9] = 0xad;
    input[HEADER_SIZE + 10] = 0xbe;
    input[HEADER_SIZE + 11] = 0xef;
    input[HEADER_SIZE + 12] = 1;
    input[HEADER_SIZE + 13] = 2;
    input[HEADER_SIZE + 14] = 3;

    /* EMR_EOF (20 bytes), followed by five opaque trailing bytes. */
    put_u32(HEADER_SIZE + 15, 14);
    put_u32(HEADER_SIZE + 19, 20);
    input[HEADER_SIZE + 27] = 0x10;
    input[HEADER_SIZE + 31] = 0x14;
    input[HEADER_SIZE + 35] = 0xa0;
    input[HEADER_SIZE + 36] = 0xb1;
    input[HEADER_SIZE + 37] = 0xc2;
    input[HEADER_SIZE + 38] = 0xd3;
    input[HEADER_SIZE + 39] = 0xe4;
    input_length = HEADER_SIZE + 40;
}

static void append_record_u32(uint32_t type, uint32_t size, uint32_t value) {
    put_u32(input_length, type);
    put_u32(input_length + 4, size);
    put_u32(input_length + 8, value);
    input_length += size;
}

static void make_snapshot_fixture(void) {
    make_fixture();
    memset(input + HEADER_SIZE, 0, sizeof(input) - HEADER_SIZE);
    input_length = HEADER_SIZE;
    put_u32(48, 196);
    put_u32(52, 6);

    /* Unknown raw record: 4 opaque payload bytes. */
    put_u32(input_length, UNKNOWN_TYPE);
    put_u32(input_length + 4, 12);
    input[input_length + 8] = 0xde;
    input[input_length + 9] = 0xad;
    input[input_length + 10] = 0xbe;
    input[input_length + 11] = 0xef;
    input_length += 12;

    append_record_u32(17, 12, 7); /* EMR_SETMAPMODE */

    /* EMR_POLYLINE with two signed points. */
    put_u32(input_length, 4);
    put_u32(input_length + 4, 44);
    put_u32(input_length + 8, (uint32_t)-1);
    put_u32(input_length + 12, 2);
    put_u32(input_length + 16, 30);
    put_u32(input_length + 20, 40);
    put_u32(input_length + 24, 2);
    put_u32(input_length + 28, 5);
    put_u32(input_length + 32, 6);
    put_u32(input_length + 36, (uint32_t)-7);
    put_u32(input_length + 40, 8);
    input_length += 44;

    /* EMR_COMMENT: counted payload remains exact, including arbitrary bytes. */
    put_u32(input_length, 70);
    put_u32(input_length + 4, 15);
    put_u32(input_length + 8, 3);
    input[input_length + 12] = 0xfa;
    input[input_length + 13] = 0xfb;
    input[input_length + 14] = 0xfc;
    input_length += 15;

    /* EMR_EOF (20 bytes), followed by five opaque trailing bytes. */
    put_u32(input_length, 14);
    put_u32(input_length + 4, 20);
    put_u32(input_length + 8, 3);
    put_u32(input_length + 12, 12);
    put_u32(input_length + 16, 20);
    input_length += 20;
    static const uint8_t tail[] = {0x10, 0x14, 0xa0, 0xb1, 0xc2};
    memcpy(input + input_length, tail, sizeof(tail));
    input_length += sizeof(tail);
}

static void make_diagnostic_fixture(void) {
    make_fixture();
    memset(input + HEADER_SIZE, 0, sizeof(input) - HEADER_SIZE);
    input_length = HEADER_SIZE;
    put_u32(48, 93);
    put_u32(52, 1);
    static const uint8_t unframed[] = {1, 2, 3, 4, 5};
    memcpy(input + input_length, unframed, sizeof(unframed));
    input_length += sizeof(unframed);
}

static int check_layout(void) {
    CHECK(sizeof(emf_limits) == 48);
    CHECK(offsetof(emf_limits, struct_size) == 0);
    CHECK(offsetof(emf_limits, version) == 4);
    CHECK(offsetof(emf_limits, max_input_bytes) == 8);
    CHECK(offsetof(emf_limits, max_record_bytes) == 16);
    CHECK(offsetof(emf_limits, max_records) == 24);
    CHECK(offsetof(emf_limits, max_allocated_bytes) == 32);
    CHECK(offsetof(emf_limits, max_work_units) == 40);

    CHECK(sizeof(emf_info) == 64);
    CHECK(offsetof(emf_info, struct_size) == 0);
    CHECK(offsetof(emf_info, version) == 4);
    CHECK(offsetof(emf_info, format) == 8);
    CHECK(offsetof(emf_info, has_eof) == 12);
    CHECK(offsetof(emf_info, header_bytes) == 16);
    CHECK(offsetof(emf_info, record_count) == 24);
    CHECK(offsetof(emf_info, diagnostic_count) == 32);
    CHECK(offsetof(emf_info, trailing_bytes) == 40);
    CHECK(offsetof(emf_info, unframed_bytes) == 48);
    CHECK(offsetof(emf_info, reserved) == 56);

    CHECK(sizeof(emf_record_descriptor) == 40);
    CHECK(offsetof(emf_record_descriptor, struct_size) == 0);
    CHECK(offsetof(emf_record_descriptor, version) == 4);
    CHECK(offsetof(emf_record_descriptor, index) == 8);
    CHECK(offsetof(emf_record_descriptor, offset) == 16);
    CHECK(offsetof(emf_record_descriptor, byte_length) == 24);
    CHECK(offsetof(emf_record_descriptor, type_id) == 32);
    CHECK(offsetof(emf_record_descriptor, family) == 36);

    CHECK(offsetof(emf_error_info, struct_size) == 0);
    CHECK(offsetof(emf_error_info, version) == 4);
    CHECK(offsetof(emf_error_info, status) == 8);
    CHECK(offsetof(emf_error_info, category) == 12);
    CHECK(offsetof(emf_error_info, has_offset) == 16);
    CHECK(offsetof(emf_error_info, reserved) == 20);
    CHECK(offsetof(emf_error_info, offset) == 24);
    CHECK(offsetof(emf_error_info, message) == 24 + sizeof(const uint8_t *));
    CHECK(offsetof(emf_error_info, message_length) ==
          ((offsetof(emf_error_info, message) + sizeof(const uint8_t *) + _Alignof(uint64_t) - 1) /
           _Alignof(uint64_t)) * _Alignof(uint64_t));
    CHECK(sizeof(emf_error_info) ==
          ((offsetof(emf_error_info, message_length) + sizeof(uint64_t) + _Alignof(emf_error_info) - 1) /
           _Alignof(emf_error_info)) * _Alignof(emf_error_info));
    return 0;
}

static int check_snapshot_record(cursor *c, uint64_t index, uint64_t offset,
                                 uint64_t length, uint32_t type, uint32_t family,
                                 uint64_t payload_length) {
    uint64_t got64;
    uint32_t got32;
    CHECK(get_u64(c, &got64) && got64 == index);
    CHECK(get_u64(c, &got64) && got64 == offset);
    CHECK(get_u64(c, &got64) && got64 == length);
    CHECK(get_u32(c, &got32) && got32 == type);
    CHECK(get_u32(c, &got32) && got32 == family);
    CHECK(get_u64(c, &got64) && got64 == payload_length);
    return 0;
}

static int check_snapshot(void) {
    make_snapshot_fixture();
    emf_document *document = NULL;
    emf_buffer *snapshot = NULL;
    emf_error *error = NULL;
    CHECK(emf_parse(input, input_length, NULL, &document, &error) == EMF_OK);
    CHECK(document != NULL && error == NULL);
    CHECK(emf_document_snapshot(document, &snapshot, &error) == EMF_OK);
    CHECK(snapshot != NULL && error == NULL);
    const uint8_t *bytes = NULL;
    uint64_t byte_length = 0;
    CHECK(emf_buffer_view(snapshot, &bytes, &byte_length) == EMF_OK);
    CHECK(byte_length <= SIZE_MAX);
    cursor c = {bytes, (size_t)byte_length, 0};
    const uint8_t *p;
    CHECK(take(&c, 4, &p) && memcmp(p, "EMFS", 4) == 0);
    uint32_t u32;
    uint64_t total, raw_header, record_count, diagnostic_count, trailing, unframed;
    CHECK(get_u32(&c, &u32) && u32 == 1);
    CHECK(get_u64(&c, &total) && total == byte_length);
    CHECK(get_u64(&c, &raw_header) && raw_header == HEADER_SIZE);
    CHECK(get_u64(&c, &record_count) && record_count == 5);
    CHECK(get_u64(&c, &diagnostic_count) && diagnostic_count == 0);
    CHECK(get_u64(&c, &trailing) && trailing == 5);
    CHECK(get_u64(&c, &unframed) && unframed == 0);

    /* Decode every field in the fixed 112-byte decoded-header section. */
    int32_t s32;
    CHECK(get_u32(&c, &u32) && u32 == 88);
    CHECK(get_i32(&c, &s32) && s32 == 0);
    CHECK(get_i32(&c, &s32) && s32 == 0);
    CHECK(get_i32(&c, &s32) && s32 == 99);
    CHECK(get_i32(&c, &s32) && s32 == 0);
    CHECK(get_i32(&c, &s32) && s32 == 0);
    CHECK(get_i32(&c, &s32) && s32 == 0);
    CHECK(get_i32(&c, &s32) && s32 == 0);
    CHECK(get_i32(&c, &s32) && s32 == 1250);
    CHECK(get_u32(&c, &u32) && u32 == UINT32_C(0x464d4520));
    CHECK(get_u32(&c, &u32) && u32 == UINT32_C(0x00010000));
    CHECK(get_u32(&c, &u32) && u32 == input_length);
    CHECK(get_u32(&c, &u32) && u32 == 6);
    CHECK(get_u32(&c, &u32) && u32 == 1); /* zero-extended nHandles */
    CHECK(get_u32(&c, &u32) && u32 == 0);
    CHECK(get_u32(&c, &u32) && u32 == 0);
    CHECK(get_u32(&c, &u32) && u32 == 0);
    CHECK(get_u32(&c, &u32) && u32 == 0);
    CHECK(get_i32(&c, &s32) && s32 == 1024);
    CHECK(get_i32(&c, &s32) && s32 == 768);
    CHECK(get_i32(&c, &s32) && s32 == 270);
    CHECK(get_i32(&c, &s32) && s32 == 203);
    CHECK(get_u32(&c, &u32) && u32 == 0); /* optional fields absent */
    for (unsigned i = 0; i < 5; ++i) CHECK(get_u32(&c, &u32) && u32 == 0);
    CHECK(c.offset == 56 + 112);
    CHECK(take(&c, HEADER_SIZE, &p));
    CHECK(memcmp(p, input, HEADER_SIZE) == 0);

    CHECK(check_snapshot_record(&c, 0, 88, 12, UNKNOWN_TYPE, 0, 0) == 0);
    CHECK(check_snapshot_record(&c, 1, 100, 12, 17, 2, 4) == 0);
    CHECK(get_u32(&c, &u32) && u32 == 7);
    CHECK(check_snapshot_record(&c, 2, 112, 44, 4, 3, 40) == 0);
    CHECK(get_i32(&c, &s32) && s32 == -1);
    CHECK(get_i32(&c, &s32) && s32 == 2);
    CHECK(get_i32(&c, &s32) && s32 == 30);
    CHECK(get_i32(&c, &s32) && s32 == 40);
    uint64_t count;
    CHECK(get_u64(&c, &count) && count == 2);
    CHECK(get_i32(&c, &s32) && s32 == 5);
    CHECK(get_i32(&c, &s32) && s32 == 6);
    CHECK(get_i32(&c, &s32) && s32 == -7);
    CHECK(get_i32(&c, &s32) && s32 == 8);
    CHECK(check_snapshot_record(&c, 3, 156, 15, 70, 4, 11) == 0);
    CHECK(get_u64(&c, &count) && count == 3);
    CHECK(take(&c, 3, &p) && p[0] == 0xfa && p[1] == 0xfb && p[2] == 0xfc);
    CHECK(check_snapshot_record(&c, 4, 171, 20, 14, 1, 12) == 0);
    CHECK(get_u32(&c, &u32) && u32 == 3);
    CHECK(get_u32(&c, &u32) && u32 == 12);
    CHECK(get_u32(&c, &u32) && u32 == 20);
    CHECK(take(&c, 5, &p));
    CHECK(p[0] == 0x10 && p[1] == 0x14 && p[2] == 0xa0 && p[3] == 0xb1 && p[4] == 0xc2);
    CHECK(c.offset == c.length);

    /* The buffer owns its data independently of the parsed document/input. */
    emf_document_free(document);
    document = NULL;
    memset(input, 0, sizeof(input));
    CHECK(emf_buffer_view(snapshot, &bytes, &byte_length) == EMF_OK);
    CHECK(byte_length == c.length && memcmp(bytes, "EMFS", 4) == 0);
    emf_buffer_free(snapshot);
    CHECK(emf_document_snapshot(NULL, &snapshot, &error) == EMF_INVALID_ARGUMENT);
    CHECK(snapshot == NULL && error != NULL);
    emf_error_free(error);
    error = NULL;

    /* Stable diagnostic encoding and exact unframed tail. */
    make_diagnostic_fixture();
    CHECK(emf_parse(input, input_length, NULL, &document, &error) == EMF_OK);
    CHECK(error == NULL && document != NULL);
    CHECK(emf_document_snapshot(document, &snapshot, &error) == EMF_OK);
    CHECK(error == NULL && snapshot != NULL);
    CHECK(emf_buffer_view(snapshot, &bytes, &byte_length) == EMF_OK);
    c = (cursor){bytes, (size_t)byte_length, 0};
    CHECK(take(&c, 4, &p) && memcmp(p, "EMFS", 4) == 0);
    CHECK(get_u32(&c, &u32) && u32 == 1);
    CHECK(get_u64(&c, &total) && total == byte_length);
    CHECK(get_u64(&c, &raw_header) && raw_header == 88);
    CHECK(get_u64(&c, &record_count) && record_count == 0);
    CHECK(get_u64(&c, &diagnostic_count) && diagnostic_count == 1);
    CHECK(get_u64(&c, &trailing) && trailing == 0);
    CHECK(get_u64(&c, &unframed) && unframed == 5);
    CHECK(skip(&c, 112 + 88));
    CHECK(get_u32(&c, &u32) && u32 == 1); /* truncated record head */
    CHECK(get_u32(&c, &u32) && u32 == 0); /* no record type */
    CHECK(get_u32(&c, &u32) && u32 == 0);
    CHECK(get_u32(&c, &u32) && u32 == 0);
    CHECK(get_u64(&c, &total) && total == 88);
    CHECK(get_u64(&c, &total) && total == 5);
    CHECK(get_u64(&c, &total) && total == 0);
    CHECK(take(&c, 5, &p) && p[0] == 1 && p[4] == 5);
    CHECK(c.offset == c.length);
    emf_document_free(document);
    emf_buffer_free(snapshot);
    return 0;
}

static int check_snapshot_after_malformed_eof(void) {
    for (uint32_t short_size = 8; short_size <= 16; short_size += 4) {
        make_fixture();
        memset(input + HEADER_SIZE, 0, sizeof(input) - HEADER_SIZE);
        input_length = HEADER_SIZE;
        put_u32(input_length, 14);
        put_u32(input_length + 4, short_size);
        input_length += short_size;
        append_record_u32(17, 12, 7);
        const size_t eof_offset = input_length;
        put_u32(eof_offset, 14);
        put_u32(eof_offset + 4, 20);
        put_u32(eof_offset + 12, 16);
        put_u32(eof_offset + 16, 20);
        input_length += 20;
        put_u32(48, (uint32_t)input_length);
        put_u32(52, 4);

        emf_document *document = NULL;
        emf_buffer *snapshot = NULL;
        emf_error *error = NULL;
        CHECK(emf_parse(input, input_length, NULL, &document, &error) == EMF_OK);
        CHECK(document != NULL && error == NULL);
        CHECK(emf_document_snapshot(document, &snapshot, &error) == EMF_OK);
        CHECK(snapshot != NULL && error == NULL);
        const uint8_t *bytes = NULL;
        uint64_t length;
        CHECK(emf_buffer_view(snapshot, &bytes, &length) == EMF_OK);
        CHECK(length <= SIZE_MAX);
        cursor c = {bytes, (size_t)length, 0};
        const uint8_t *magic;
        uint32_t word;
        uint64_t value;
        CHECK(take(&c, 4, &magic) && memcmp(magic, "EMFS", 4) == 0);
        CHECK(get_u32(&c, &word) && word == 1);
        CHECK(get_u64(&c, &value) && value == length);
        CHECK(get_u64(&c, &value) && value == HEADER_SIZE);
        CHECK(get_u64(&c, &value) && value == 3);
        CHECK(get_u64(&c, &value) && value == 1);
        CHECK(get_u64(&c, &value) && value == 0); /* no trailing records */
        CHECK(get_u64(&c, &value) && value == 0); /* no unframed tail */
        CHECK(skip(&c, 112 + HEADER_SIZE));
        CHECK(check_snapshot_record(&c, 0, HEADER_SIZE, short_size, 14,
                                    EMF_FAMILY_RAW, 0) == 0);
        CHECK(check_snapshot_record(&c, 1, HEADER_SIZE + short_size, 12, 17,
                                    EMF_FAMILY_SETMAPMODE, 4) == 0);
        CHECK(get_u32(&c, &word) && word == 7);
        CHECK(check_snapshot_record(&c, 2, eof_offset, 20, 14,
                                    EMF_FAMILY_EOF, 12) == 0);
        CHECK(get_u32(&c, &word) && word == 0);
        CHECK(get_u32(&c, &word) && word == 16);
        CHECK(get_u32(&c, &word) && word == 20);
        CHECK(get_u32(&c, &word) && word == 4); /* invalid typed payload */
        CHECK(get_u32(&c, &word) && word == 1); /* record type present */
        CHECK(get_u32(&c, &word) && word == 14);
        CHECK(get_u32(&c, &word) && word == 0); /* reserved */
        CHECK(get_u64(&c, &value) && value == HEADER_SIZE);
        CHECK(get_u64(&c, &value) && value == 0);
        CHECK(get_u64(&c, &value) && value == 0);
        CHECK(c.offset == c.length);
        emf_buffer_free(snapshot);
        emf_document_free(document);
    }
    return 0;
}

static void init_info(emf_info *info) {
    memset(info, 0, sizeof(*info));
    info->struct_size = (uint32_t)sizeof(*info);
    info->version = EMF_ABI_VERSION;
}

static void init_error_info(emf_error_info *info) {
    memset(info, 0, sizeof(*info));
    info->struct_size = (uint32_t)sizeof(*info);
    info->version = EMF_ABI_VERSION;
}

static void init_limits(emf_limits *limits) {
    memset(limits, 0, sizeof(*limits));
    limits->struct_size = (uint32_t)sizeof(*limits);
    limits->version = EMF_ABI_VERSION;
    limits->max_input_bytes = UINT64_C(1048576);
    limits->max_record_bytes = UINT64_C(1048576);
    limits->max_records = UINT64_C(1048576);
    limits->max_allocated_bytes = UINT64_C(1048576);
    limits->max_work_units = UINT64_C(1048576);
}

int main(void) {
    CHECK(check_layout() == 0);
    CHECK(check_snapshot() == 0);
    CHECK(check_snapshot_after_malformed_eof() == 0);
    CHECK(emf_abi_version() == EMF_ABI_VERSION);
    make_fixture();
    uint8_t original_input[INPUT_CAPACITY];
    memcpy(original_input, input, sizeof(input));
    const size_t original_length = input_length;

    uint32_t format = UINT32_C(0xfeedbeef);
    emf_error *error = NULL;
    emf_error_info error_info;
    CHECK(emf_detect(input, (uint64_t)input_length, &format, &error) == EMF_OK);
    CHECK(format == EMF_FORMAT_EMF);
    CHECK(error == NULL);

    /* Input is borrowed only during parse; the parsed document owns its bytes. */
    emf_document *document = NULL;
    CHECK(emf_parse(input, (uint64_t)input_length, NULL, &document, &error) == EMF_OK);
    CHECK(document != NULL && error == NULL);
    memset(input, 0, sizeof(input));

    emf_info info;
    init_info(&info);
    CHECK(emf_document_info(document, &info) == EMF_OK);
    CHECK(info.struct_size == sizeof(info) && info.version == EMF_ABI_VERSION);
    CHECK(info.format == EMF_FORMAT_EMF && info.has_eof == 1);
    CHECK(info.header_bytes == HEADER_SIZE && info.record_count == 2);
    CHECK(info.diagnostic_count == 0 && info.trailing_bytes == 5);
    CHECK(info.unframed_bytes == 0 && info.reserved == 0);

    emf_record_descriptor descriptors[2];
    memset(descriptors, 0xa5, sizeof(descriptors));
    uint64_t count = UINT64_MAX;
    CHECK(emf_record_batch(document, 0, 2, descriptors, &count) == EMF_OK);
    CHECK(count == 2);
    CHECK(descriptors[0].struct_size == sizeof(descriptors[0]));
    CHECK(descriptors[0].version == EMF_ABI_VERSION);
    CHECK(descriptors[0].index == 0 && descriptors[0].offset == HEADER_SIZE);
    CHECK(descriptors[0].byte_length == 15 && descriptors[0].type_id == UNKNOWN_TYPE);
    CHECK(descriptors[0].family == EMF_FAMILY_RAW);
    CHECK(descriptors[1].index == 1 && descriptors[1].offset == HEADER_SIZE + 15);
    CHECK(descriptors[1].byte_length == 20 && descriptors[1].type_id == 14);
    CHECK(descriptors[1].family == EMF_FAMILY_EOF);

    count = UINT64_MAX;
    CHECK(emf_record_batch(document, 2, 0, NULL, &count) == EMF_OK && count == 0);
    count = UINT64_MAX;
    CHECK(emf_record_batch(document, 3, 0, NULL, &count) == EMF_INVALID_ARGUMENT);
    CHECK(count == 0);
    count = UINT64_MAX;
    CHECK(emf_record_batch(document, 2, 1, descriptors, &count) == EMF_OK && count == 0);

    emf_buffer *record_buffer = NULL;
    CHECK(emf_record_bytes(document, 0, &record_buffer, &error) == EMF_OK);
    CHECK(record_buffer != NULL && error == NULL);
    const uint8_t *record_data = NULL;
    uint64_t record_length = 0;
    CHECK(emf_buffer_view(record_buffer, &record_data, &record_length) == EMF_OK);
    static const uint8_t expected_record[] = {
        1, 0, 0xff, 0x7f, 15, 0, 0, 0, 0xde, 0xad, 0xbe, 0xef, 1, 2, 3
    };
    CHECK(record_length == sizeof(expected_record));
    CHECK(memcmp(record_data, expected_record, sizeof(expected_record)) == 0);

    emf_buffer *serialized = NULL;
    CHECK(emf_serialize(document, &serialized, &error) == EMF_OK);
    CHECK(serialized != NULL && error == NULL);
    const uint8_t *serialized_data = NULL;
    uint64_t serialized_length = 0;
    CHECK(emf_buffer_view(serialized, &serialized_data, &serialized_length) == EMF_OK);
    CHECK(serialized_length == original_length);
    CHECK(memcmp(serialized_data, original_input, original_length) == 0);

    /* Buffer storage remains live after its source document and input are gone. */
    emf_document_free(document);
    document = NULL;
    CHECK(emf_buffer_view(record_buffer, &record_data, &record_length) == EMF_OK);
    CHECK(record_length == sizeof(expected_record));
    CHECK(memcmp(record_data, expected_record, sizeof(expected_record)) == 0);
    CHECK(emf_buffer_view(serialized, &serialized_data, &serialized_length) == EMF_OK);
    CHECK(serialized_length == original_length);
    CHECK(memcmp(serialized_data, original_input, original_length) == 0);
    emf_buffer_free(record_buffer);
    emf_buffer_free(serialized);
    record_data = (const uint8_t *)(uintptr_t)1;
    record_length = UINT64_MAX;
    CHECK(emf_buffer_view(NULL, &record_data, &record_length) == EMF_INVALID_ARGUMENT);
    CHECK(record_data == NULL && record_length == 0);
    record_length = UINT64_MAX;
    CHECK(emf_buffer_view(NULL, NULL, &record_length) == EMF_INVALID_ARGUMENT);
    CHECK(record_length == 0);
    CHECK(emf_buffer_view(NULL, &record_data, NULL) == EMF_INVALID_ARGUMENT);
    CHECK(emf_error_view(NULL, NULL) == EMF_INVALID_ARGUMENT);
    init_error_info(&error_info);
    CHECK(emf_error_view(NULL, &error_info) == EMF_INVALID_ARGUMENT);

    /* Invalid input returns a live, caller-owned error view. */
    static const uint8_t invalid_input[] = {0, 1, 2, 3};
    error = NULL;
    document = (emf_document *)(uintptr_t)1;
    CHECK(emf_parse(invalid_input, sizeof(invalid_input), NULL, &document, &error) == EMF_FORMAT_ERROR);
    CHECK(document == NULL && error != NULL);
    init_error_info(&error_info);
    error_info.version++;
    CHECK(emf_error_view(error, &error_info) == EMF_INVALID_ARGUMENT);
    init_error_info(&error_info);
    CHECK(emf_error_view(error, &error_info) == EMF_OK);
    CHECK(error_info.struct_size == sizeof(error_info) && error_info.version == EMF_ABI_VERSION);
    CHECK(error_info.status == EMF_FORMAT_ERROR && error_info.category == (uint32_t)EMF_FORMAT_ERROR);
    CHECK(error_info.reserved == 0 && error_info.message != NULL && error_info.message_length > 0);
    CHECK(memchr(error_info.message, 0, (size_t)error_info.message_length) == NULL);
    emf_error_free(error);
    error = NULL;
    emf_error_free(NULL);

    /* Invalid struct versions/sizes and limits are rejected with cleared outputs. */
    emf_limits limits;
    init_limits(&limits);
    limits.version++;
    document = (emf_document *)(uintptr_t)1;
    error = NULL;
    make_fixture();
    CHECK(emf_parse(input, (uint64_t)input_length, &limits, &document, &error) == EMF_INVALID_ARGUMENT);
    CHECK(document == NULL && error != NULL);
    emf_error_free(error);
    error = NULL;
    init_limits(&limits);
    limits.max_input_bytes = input_length - 1;
    document = NULL;
    CHECK(emf_parse(input, (uint64_t)input_length, &limits, &document, &error) == EMF_LIMIT_EXCEEDED);
    CHECK(document == NULL && error != NULL);
    emf_error_free(error);
    error = NULL;

    CHECK(emf_parse(NULL, 0, NULL, &document, &error) == EMF_FORMAT_ERROR);
    CHECK(document == NULL && error != NULL);
    emf_error_free(error);
    error = NULL;
    format = UINT32_C(0xfeedbeef);
    CHECK(emf_detect(NULL, 0, &format, &error) == EMF_FORMAT_ERROR);
    CHECK(format == EMF_FORMAT_UNKNOWN && error != NULL);
    init_error_info(&error_info);
    CHECK(emf_error_view(error, &error_info) == EMF_OK);
    CHECK(error_info.status == EMF_FORMAT_ERROR && error_info.message_length > 0);
    emf_error_free(error);
    error = NULL;

    emf_info bad_info;
    init_info(&bad_info);
    bad_info.version++;
    CHECK(emf_document_info(NULL, &bad_info) == EMF_INVALID_ARGUMENT);
    bad_info.version = EMF_ABI_VERSION;
    bad_info.struct_size--;
    CHECK(emf_document_info(NULL, &bad_info) == EMF_INVALID_ARGUMENT);
    CHECK(emf_document_info(NULL, NULL) == EMF_INVALID_ARGUMENT);

    count = UINT64_MAX;
    CHECK(emf_record_batch(NULL, 0, 0, NULL, &count) == EMF_INVALID_ARGUMENT && count == 0);
    CHECK(emf_record_batch(NULL, 0, 1, NULL, &count) == EMF_INVALID_ARGUMENT && count == 0);
    error = NULL;
    CHECK(emf_record_bytes(NULL, 0, &record_buffer, &error) == EMF_INVALID_ARGUMENT);
    CHECK(record_buffer == NULL && error != NULL);
    emf_error_free(error);
    error = NULL;
    CHECK(emf_serialize(NULL, &serialized, &error) == EMF_INVALID_ARGUMENT);
    CHECK(serialized == NULL && error != NULL);
    emf_error_free(error);
    error = NULL;

    CHECK(emf_detect(NULL, 0, NULL, &error) == EMF_INVALID_ARGUMENT);
    CHECK(error != NULL);
    emf_error_free(error);
    error = NULL;
    CHECK(emf_parse(NULL, 0, NULL, NULL, &error) == EMF_INVALID_ARGUMENT);
    CHECK(error != NULL);
    emf_error_free(error);
    error = NULL;
    CHECK(emf_parse(input, (uint64_t)input_length, NULL, &document, NULL) == EMF_OK);
    CHECK(document != NULL);
    emf_document_free(document);
    emf_document_free(NULL);
    emf_buffer_free(NULL);
    puts("C ABI smoke: ok");
    return 0;
}
