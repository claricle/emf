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
    CHECK(get_u32(&c, &u32) && u32 == 2);
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
    CHECK(get_u32(&c, &u32) && u32 == 2);
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

static int check_scalar_state_snapshots(void) {
    const uint32_t families[] = {EMF_FAMILY_SETBKMODE, EMF_FAMILY_SETPOLYFILLMODE,
        EMF_FAMILY_SETROP2, EMF_FAMILY_SETSTRETCHBLTMODE};
    const uint32_t values[] = {0, UINT32_C(0x80000000), UINT32_MAX};
    for (unsigned kind = 0; kind < 4; ++kind) {
        for (unsigned value = 0; value < 3; ++value) {
            make_fixture();
            put_u32(88, 18 + kind);
            put_u32(92, 12);
            put_u32(96, values[value]);
            input_length = 100;
            emf_document *document = NULL;
            emf_buffer *snapshot = NULL;
            emf_error *error = NULL;
            CHECK(emf_parse(input, input_length, NULL, &document, &error) == EMF_OK);
            CHECK(emf_document_snapshot(document, &snapshot, &error) == EMF_OK);
            const uint8_t *bytes = NULL;
            uint64_t length = 0;
            CHECK(emf_buffer_view(snapshot, &bytes, &length) == EMF_OK);
            emf_document_free(document);
            CHECK(error == NULL && length <= SIZE_MAX);
            cursor c = {bytes, (size_t)length, 4};
            uint32_t word;
            CHECK(get_u32(&c, &word) && word == 2);
            CHECK(skip(&c, 48 + 112 + HEADER_SIZE));
            CHECK(check_snapshot_record(&c, 0, 88, 12, 18 + kind, families[kind], 4) == 0);
            CHECK(get_u32(&c, &word) && word == values[value]);
            CHECK(c.offset == c.length);
            emf_buffer_free(snapshot);
        }
    }
    return 0;
}

static int check_color_shape_snapshots(void) {
    const uint32_t kinds[] = {24, 25, 42, 43, 44};
    const uint32_t families[] = {EMF_FAMILY_SETTEXTCOLOR, EMF_FAMILY_SETBKCOLOR,
        EMF_FAMILY_ELLIPSE, EMF_FAMILY_RECTANGLE, EMF_FAMILY_ROUNDRECT};
    const unsigned counts[] = {1, 1, 4, 4, 6};
    const uint32_t values[][6] = {
        {UINT32_C(0xdbff8000)}, {UINT32_C(0xff7f00ff)},
        {UINT32_C(0x80000000), INT32_MAX, UINT32_MAX, 0},
        {INT32_MAX, UINT32_C(0x80000000), 0, UINT32_MAX},
        {UINT32_MAX, 0, UINT32_C(0x80000000), INT32_MAX, UINT32_C(0x80000000), INT32_MAX}};
    for (unsigned kind = 0; kind < 5; ++kind) {
        make_fixture();
        put_u32(88, kinds[kind]);
        put_u32(92, 8 + counts[kind] * 4);
        for (unsigned value = 0; value < counts[kind]; ++value) put_u32(96 + value * 4, values[kind][value]);
        input_length = 96 + counts[kind] * 4;
        emf_document *document = NULL;
        emf_buffer *snapshot = NULL;
        emf_error *error = NULL;
        CHECK(emf_parse(input, input_length, NULL, &document, &error) == EMF_OK);
        CHECK(emf_document_snapshot(document, &snapshot, &error) == EMF_OK);
        const uint8_t *bytes = NULL;
        uint64_t length = 0;
        CHECK(emf_buffer_view(snapshot, &bytes, &length) == EMF_OK);
        emf_document_free(document);
        CHECK(error == NULL && length <= SIZE_MAX);
        cursor c = {bytes, (size_t)length, 4};
        uint32_t word;
        CHECK(get_u32(&c, &word) && word == 2);
        CHECK(skip(&c, 48 + 112 + HEADER_SIZE));
        CHECK(check_snapshot_record(&c, 0, 88, 8 + counts[kind] * 4, kinds[kind], families[kind], counts[kind] * 4) == 0);
        for (unsigned value = 0; value < counts[kind]; ++value) {
            CHECK(get_u32(&c, &word) && word == values[kind][value]);
        }
        CHECK(c.offset == c.length);
        emf_buffer_free(snapshot);
    }
    return 0;
}

static int check_fixed_state_snapshots(void) {
    const uint32_t kinds[] = {22, 33, 34, 37, 40, 57, 59, 60, 61, 62, 63, 64, 67, 68};
    const unsigned counts[] = {1, 0, 1, 1, 1, 1, 0, 0, 0, 4, 4, 4, 1, 0};
    const uint32_t values[] = {UINT32_C(0x80000000), INT32_MAX, UINT32_MAX, 0};
    for (unsigned kind = 0; kind < 14; ++kind) {
        make_fixture();
        put_u32(88, kinds[kind]);
        put_u32(92, 8 + counts[kind] * 4);
        for (unsigned value = 0; value < counts[kind]; ++value) put_u32(96 + value * 4, values[value]);
        input_length = 96 + counts[kind] * 4;
        emf_document *document = NULL;
        emf_buffer *snapshot = NULL;
        emf_error *error = NULL;
        CHECK(emf_parse(input, input_length, NULL, &document, &error) == EMF_OK);
        CHECK(emf_document_snapshot(document, &snapshot, &error) == EMF_OK);
        const uint8_t *bytes = NULL;
        uint64_t length = 0;
        CHECK(emf_buffer_view(snapshot, &bytes, &length) == EMF_OK);
        emf_document_free(document);
        CHECK(error == NULL && length <= SIZE_MAX);
        cursor c = {bytes, (size_t)length, 4};
        uint32_t word;
        CHECK(get_u32(&c, &word) && word == 2);
        CHECK(skip(&c, 48 + 112 + HEADER_SIZE));
        CHECK(check_snapshot_record(&c, 0, 88, 8 + counts[kind] * 4, kinds[kind], 21 + kind, counts[kind] * 4) == 0);
        for (unsigned value = 0; value < counts[kind]; ++value) {
            CHECK(get_u32(&c, &word) && word == values[value]);
        }
        CHECK(c.offset == c.length);
        emf_buffer_free(snapshot);
    }
    return 0;
}

static int check_point_array_snapshots(void) {
    const uint32_t kinds[] = {2, 3, 5, 6, 85, 86, 87, 88, 89};
    const uint32_t bounds[] = {UINT32_C(0x80000000), INT32_MAX, UINT32_MAX, 0};
    for (unsigned kind = 0; kind < 9; ++kind) {
        for (unsigned count = 0; count <= 2; count += 2) {
            unsigned width = kind < 4 ? 8 : 4;
            make_fixture();
            put_u32(88, kinds[kind]);
            put_u32(92, 28 + count * width);
            for (unsigned axis = 0; axis < 4; ++axis) put_u32(96 + axis * 4, bounds[axis]);
            put_u32(112, count);
            if (width == 8) {
                for (unsigned axis = 0; axis < count * 2; ++axis) put_u32(116 + axis * 4, bounds[axis]);
            } else {
                const uint16_t points[] = {UINT16_C(0x8000), INT16_MAX, UINT16_MAX, 0};
                for (unsigned axis = 0; axis < count * 2; ++axis) put_u16(116 + axis * 2, points[axis]);
            }
            input_length = 116 + count * width;
            emf_document *document = NULL;
            emf_buffer *snapshot = NULL;
            emf_error *error = NULL;
            CHECK(emf_parse(input, input_length, NULL, &document, &error) == EMF_OK);
            CHECK(emf_document_snapshot(document, &snapshot, &error) == EMF_OK);
            emf_document_free(document);
            const uint8_t *bytes = NULL;
            uint64_t length = 0, point_count;
            CHECK(emf_buffer_view(snapshot, &bytes, &length) == EMF_OK);
            CHECK(error == NULL && length <= SIZE_MAX);
            cursor c = {bytes, (size_t)length, 4};
            uint32_t word;
            CHECK(get_u32(&c, &word) && word == 2);
            CHECK(skip(&c, 48 + 112 + HEADER_SIZE));
            CHECK(check_snapshot_record(&c, 0, 88, 28 + count * width, kinds[kind], 45 + kind, 24 + count * width) == 0);
            for (unsigned axis = 0; axis < 4; ++axis) CHECK(get_u32(&c, &word) && word == bounds[axis]);
            CHECK(get_u64(&c, &point_count) && point_count == count);
            const uint8_t *points;
            CHECK(take(&c, count * width, &points));
            CHECK(memcmp(points, input + 116, count * width) == 0);
            CHECK(c.offset == c.length);
            emf_buffer_free(snapshot);
        }
    }
    return 0;
}

static int check_completion_snapshots(void) {
    const uint32_t kinds[] = {16, 28, 53, 65, 66, 98, 115, 120};
    const uint32_t families[] = {66, 67, 91, 69, 70, 71, 72, 92};
    const unsigned sizes[] = {4, 0, 16, 0, 0, 4, 4, 8};
    for (unsigned kind = 0; kind < 8; ++kind) {
        for (unsigned extra = 0; extra <= 4; extra += 4) {
            unsigned fixed = sizes[kind];
            unsigned wire_length = 8 + fixed + extra;
            unsigned payload_length = fixed;
            make_fixture();
            put_u32(88, kinds[kind]);
            put_u32(92, wire_length);
            for (unsigned i = 0; i < fixed; i += 4) put_u32(96 + i, UINT32_MAX - i);
            memcpy(input + 96 + fixed, "\0\xffxx", extra);
            input_length = 88 + wire_length;
            emf_document *document = NULL;
            emf_buffer *snapshot = NULL;
            emf_error *error = NULL;
            CHECK(emf_parse(input, input_length, NULL, &document, &error) == EMF_OK);
            CHECK(emf_document_snapshot(document, &snapshot, &error) == EMF_OK);
            emf_document_free(document);
            const uint8_t *bytes = NULL, *body = NULL;
            uint64_t length = 0;
            CHECK(emf_buffer_view(snapshot, &bytes, &length) == EMF_OK);
            CHECK(error == NULL && length <= SIZE_MAX);
            cursor c = {bytes, (size_t)length, 4};
            uint32_t word;
            CHECK(get_u32(&c, &word) && word == 2);
            CHECK(skip(&c, 48 + 112 + HEADER_SIZE));
            CHECK(check_snapshot_record(&c, 0, 88, wire_length, kinds[kind], families[kind], payload_length) == 0);
            if (fixed) {
                CHECK(take(&c, fixed, &body));
                CHECK(memcmp(body, input + 96, fixed) == 0);
            }
            CHECK(c.offset == c.length);
            emf_buffer_free(snapshot);
        }
    }
    return 0;
}

static int check_transform_snapshots(void) {
    const uint32_t kinds[] = {31, 32, 35, 36, 41, 58};
    const unsigned counts[] = {4, 4, 6, 7, 5, 1};
    const uint32_t words[] = {UINT32_C(0x80000000), UINT32_C(0x7f812345), UINT32_C(0x7fc12345),
                              UINT32_MAX, UINT32_C(0x7f800000), 1, UINT32_MAX};
    for (unsigned kind = 0; kind < 6; ++kind) {
        make_fixture();
        unsigned payload_length = counts[kind] * 4;
        put_u32(88, kinds[kind]);
        put_u32(92, 8 + payload_length + 4);
        for (unsigned i = 0; i < counts[kind]; ++i) put_u32(96 + i * 4, words[i]);
        memcpy(input + 96 + payload_length, "tail", 4);
        input_length = 100 + payload_length;
        emf_document *document = NULL;
        emf_buffer *snapshot = NULL;
        emf_error *error = NULL;
        CHECK(emf_parse(input, input_length, NULL, &document, &error) == EMF_OK);
        CHECK(emf_document_snapshot(document, &snapshot, &error) == EMF_OK);
        emf_document_free(document);
        const uint8_t *bytes = NULL, *payload = NULL;
        uint64_t length = 0;
        CHECK(emf_buffer_view(snapshot, &bytes, &length) == EMF_OK);
        CHECK(error == NULL && length <= SIZE_MAX);
        cursor c = {bytes, (size_t)length, 4};
        uint32_t version;
        CHECK(get_u32(&c, &version) && version == 2);
        CHECK(skip(&c, 48 + 112 + HEADER_SIZE));
        CHECK(check_snapshot_record(&c, 0, 88, payload_length + 12, kinds[kind], 60 + kind, payload_length) == 0);
        CHECK(take(&c, payload_length, &payload));
        CHECK(memcmp(payload, input + 96, payload_length) == 0);
        CHECK(c.offset == c.length);
        emf_buffer_free(snapshot);
    }
    return 0;
}

static int check_poly_draw_snapshots(void) {
    const uint32_t kinds[] = {56, 92};
    const uint32_t bounds[] = {UINT32_C(0x80000000), INT32_MAX, UINT32_MAX, 0};
    for (unsigned kind = 0; kind < 2; ++kind) {
        for (unsigned count = 0; count <= 2; count += 2) {
            unsigned width = kind == 0 ? 8 : 4;
            make_fixture();
            put_u32(88, kinds[kind]);
            put_u32(92, 28 + count * (width + 1));
            for (unsigned axis = 0; axis < 4; ++axis) put_u32(96 + axis * 4, bounds[axis]);
            put_u32(112, count);
            if (width == 8) {
                for (unsigned axis = 0; axis < count * 2; ++axis) put_u32(116 + axis * 4, bounds[axis]);
            } else {
                const uint16_t points[] = {UINT16_C(0x8000), INT16_MAX, UINT16_MAX, 0};
                for (unsigned axis = 0; axis < count * 2; ++axis) put_u16(116 + axis * 2, points[axis]);
            }
            if (count) { input[116 + count * width] = 128; input[117 + count * width] = 255; }
            input_length = 116 + count * (width + 1);
            emf_document *document = NULL;
            emf_buffer *snapshot = NULL;
            emf_error *error = NULL;
            CHECK(emf_parse(input, input_length, NULL, &document, &error) == EMF_OK);
            CHECK(emf_document_snapshot(document, &snapshot, &error) == EMF_OK);
            emf_document_free(document);
            const uint8_t *bytes = NULL;
            uint64_t length = 0, point_count;
            CHECK(emf_buffer_view(snapshot, &bytes, &length) == EMF_OK);
            CHECK(error == NULL && length <= SIZE_MAX);
            cursor c = {bytes, (size_t)length, 4};
            uint32_t word;
            CHECK(get_u32(&c, &word) && word == 2);
            CHECK(skip(&c, 48 + 112 + HEADER_SIZE));
            CHECK(check_snapshot_record(&c, 0, 88, 28 + count * (width + 1), kinds[kind], 58 + kind, 24 + count * (width + 1)) == 0);
            for (unsigned axis = 0; axis < 4; ++axis) CHECK(get_u32(&c, &word) && word == bounds[axis]);
            CHECK(get_u64(&c, &point_count) && point_count == count);
            const uint8_t *points;
            CHECK(take(&c, count * width, &points));
            CHECK(memcmp(points, input + 116, count * width) == 0);
            const uint8_t *types;
            CHECK(take(&c, count, &types));
            CHECK(memcmp(types, input + 116 + count * width, count) == 0);
            CHECK(c.offset == c.length);
            emf_buffer_free(snapshot);
        }
    }
    return 0;
}

static int check_multi_array_snapshots(void) {
    const uint32_t kinds[] = {7, 8, 90, 91};
    const uint32_t bounds[] = {UINT32_C(0x80000000), INT32_MAX, UINT32_MAX, 0};
    for (unsigned kind = 0; kind < 4; ++kind) {
        for (unsigned variant = 0; variant < 4; ++variant) {
            unsigned polys = (variant & 1) ? 2 : 0, count = (variant & 2) ? 2 : 0;
            unsigned width = kind < 2 ? 8 : 4;
            unsigned points_offset = 120 + polys * 4;
            unsigned wire_size = 32 + polys * 4 + count * width;
            make_fixture();
            put_u32(88, kinds[kind]);
            put_u32(92, wire_size);
            for (unsigned axis = 0; axis < 4; ++axis) put_u32(96 + axis * 4, bounds[axis]);
            put_u32(112, polys);
            put_u32(116, count);
            if (polys) { put_u32(120, 0); put_u32(124, UINT32_MAX); }
            if (width == 8) {
                for (unsigned axis = 0; axis < count * 2; ++axis) put_u32(points_offset + axis * 4, bounds[axis]);
            } else {
                const uint16_t points[] = {UINT16_C(0x8000), INT16_MAX, UINT16_MAX, 0};
                for (unsigned axis = 0; axis < count * 2; ++axis) put_u16(points_offset + axis * 2, points[axis]);
            }
            input_length = 88 + wire_size;
            emf_document *document = NULL;
            emf_buffer *snapshot = NULL;
            emf_error *error = NULL;
            CHECK(emf_parse(input, input_length, NULL, &document, &error) == EMF_OK);
            CHECK(emf_document_snapshot(document, &snapshot, &error) == EMF_OK);
            emf_document_free(document);
            const uint8_t *bytes = NULL;
            uint64_t length = 0, array_count;
            CHECK(emf_buffer_view(snapshot, &bytes, &length) == EMF_OK);
            CHECK(error == NULL && length <= SIZE_MAX);
            cursor c = {bytes, (size_t)length, 4};
            uint32_t word;
            CHECK(get_u32(&c, &word) && word == 2);
            CHECK(skip(&c, 48 + 112 + HEADER_SIZE));
            CHECK(check_snapshot_record(&c, 0, 88, wire_size, kinds[kind], 54 + kind, 32 + polys * 4 + count * width) == 0);
            for (unsigned axis = 0; axis < 4; ++axis) CHECK(get_u32(&c, &word) && word == bounds[axis]);
            CHECK(get_u64(&c, &array_count) && array_count == polys);
            CHECK(get_u64(&c, &array_count) && array_count == count);
            const uint8_t *arrays;
            CHECK(take(&c, polys * 4 + count * width, &arrays));
            CHECK(memcmp(arrays, input + 120, polys * 4 + count * width) == 0);
            CHECK(c.offset == c.length);
            emf_buffer_free(snapshot);
        }
    }
    return 0;
}

static int check_fixed_geometry_snapshots(void) {
    const uint32_t kinds[] = {15, 29, 30, 38, 39, 45, 46, 47, 54, 55};
    const unsigned counts[] = {3, 4, 4, 5, 4, 8, 8, 8, 2, 8};
    const uint32_t values[] = {UINT32_C(0x80000000), INT32_MAX, UINT32_MAX, 0, UINT32_C(0xdbff8000), 1, 2, 3};
    for (unsigned kind = 0; kind < 10; ++kind) {
        make_fixture();
        put_u32(88, kinds[kind]);
        put_u32(92, 8 + counts[kind] * 4);
        for (unsigned value = 0; value < counts[kind]; ++value) put_u32(96 + value * 4, values[value]);
        input_length = 96 + counts[kind] * 4;
        emf_document *document = NULL;
        emf_buffer *snapshot = NULL;
        emf_error *error = NULL;
        CHECK(emf_parse(input, input_length, NULL, &document, &error) == EMF_OK);
        CHECK(emf_document_snapshot(document, &snapshot, &error) == EMF_OK);
        const uint8_t *bytes = NULL;
        uint64_t length = 0;
        CHECK(emf_buffer_view(snapshot, &bytes, &length) == EMF_OK);
        emf_document_free(document);
        CHECK(error == NULL && length <= SIZE_MAX);
        cursor c = {bytes, (size_t)length, 4};
        uint32_t word;
        CHECK(get_u32(&c, &word) && word == 2);
        CHECK(skip(&c, 48 + 112 + HEADER_SIZE));
        CHECK(check_snapshot_record(&c, 0, 88, 8 + counts[kind] * 4, kinds[kind], 35 + kind, counts[kind] * 4) == 0);
        for (unsigned value = 0; value < counts[kind]; ++value) {
            CHECK(get_u32(&c, &word) && word == values[value]);
        }
        CHECK(c.offset == c.length);
        emf_buffer_free(snapshot);
    }
    return 0;
}

static int check_coordinate_snapshots(void) {
    const uint32_t kinds[] = {9, 10, 11, 12, 13, 26, 27};
    const uint32_t families[] = {EMF_FAMILY_SETWINDOWEXTEX, EMF_FAMILY_SETWINDOWORGEX,
        EMF_FAMILY_SETVIEWPORTEXTEX, EMF_FAMILY_SETVIEWPORTORGEX,
        EMF_FAMILY_SETBRUSHORGEX, EMF_FAMILY_OFFSETCLIPRGN, EMF_FAMILY_MOVETOEX};
    const uint32_t values[][2] = {{0, UINT32_MAX},
        {UINT32_C(0x80000000), INT32_MAX}, {INT32_MAX, UINT32_C(0x80000000)}};
    for (unsigned kind = 0; kind < 7; ++kind) {
        for (unsigned value = 0; value < 3; ++value) {
            make_fixture();
            put_u32(88, kinds[kind]);
            put_u32(92, 16);
            put_u32(96, values[value][0]);
            put_u32(100, values[value][1]);
            input_length = 104;
            emf_document *document = NULL;
            emf_buffer *snapshot = NULL;
            emf_error *error = NULL;
            CHECK(emf_parse(input, input_length, NULL, &document, &error) == EMF_OK);
            CHECK(emf_document_snapshot(document, &snapshot, &error) == EMF_OK);
            const uint8_t *bytes = NULL;
            uint64_t length = 0;
            CHECK(emf_buffer_view(snapshot, &bytes, &length) == EMF_OK);
            emf_document_free(document);
            CHECK(error == NULL && length <= SIZE_MAX);
            cursor c = {bytes, (size_t)length, 4};
            uint32_t word;
            CHECK(get_u32(&c, &word) && word == 2);
            CHECK(skip(&c, 48 + 112 + HEADER_SIZE));
            CHECK(check_snapshot_record(&c, 0, 88, 16, kinds[kind], families[kind], 8) == 0);
            CHECK(get_u32(&c, &word) && word == values[value][0]);
            CHECK(get_u32(&c, &word) && word == values[value][1]);
            CHECK(c.offset == c.length);
            emf_buffer_free(snapshot);
        }
    }
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
        CHECK(get_u32(&c, &word) && word == 2);
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

static int check_lifetimes_and_recovery(void) {
    const uint64_t invalid_lengths[] = {1, UINT64_MAX};
    for (size_t i = 0; i < sizeof(invalid_lengths) / sizeof(invalid_lengths[0]); ++i) {
        emf_document *document = NULL;
        emf_wmf_document *wmf = NULL;
        uint32_t format = EMF_FORMAT_EMF;
        CHECK(emf_detect(NULL, invalid_lengths[i], &format, NULL) == EMF_INVALID_ARGUMENT);
        CHECK(format == EMF_FORMAT_UNKNOWN);
        CHECK(emf_parse(NULL, invalid_lengths[i], NULL, &document, NULL) == EMF_INVALID_ARGUMENT);
        CHECK(document == NULL);
        CHECK(emf_wmf_parse(NULL, invalid_lengths[i], NULL, &wmf, NULL) == EMF_INVALID_ARGUMENT);
        CHECK(wmf == NULL);
    }

    make_fixture();
    emf_document *document = NULL;
    emf_buffer *encoded = NULL, *record = NULL, *output = NULL;
    emf_error *first = NULL, *second = NULL, *error_output = NULL;
    emf_error_info error_info;
    emf_info info;
    const uint8_t *data = NULL;
    uint64_t length = 0, count = 99;
    CHECK(emf_parse(input, input_length, NULL, &document, NULL) == EMF_OK);
    CHECK(emf_serialize(document, &encoded, NULL) == EMF_OK);

    /* Rejected calls clear outputs without consuming separately owned handles. */
    output = encoded;
    CHECK(emf_record_bytes(document, UINT64_MAX, &output, &first) == EMF_INVALID_ARGUMENT);
    CHECK(output == NULL && first != NULL);
    CHECK(emf_record_batch(document, 3, 0, NULL, &count) == EMF_INVALID_ARGUMENT);
    CHECK(count == 0);
    init_info(&info);
    info.version++;
    CHECK(emf_document_info(document, &info) == EMF_INVALID_ARGUMENT);
    init_info(&info);
    CHECK(emf_document_info(document, &info) == EMF_OK && info.record_count == 2);
    CHECK(emf_record_bytes(document, 0, &record, NULL) == EMF_OK);

    CHECK(emf_serialize(document, NULL, &second) == EMF_INVALID_ARGUMENT);
    CHECK(second != NULL && second != first);
    init_error_info(&error_info);
    CHECK(emf_error_view(second, &error_info) == EMF_OK);
    CHECK(error_info.status == EMF_INVALID_ARGUMENT && error_info.message_length > 0);
    CHECK(error_info.message_length < 256);
    uint8_t message[256];
    uint64_t message_length = error_info.message_length;
    memcpy(message, error_info.message, (size_t)message_length);

    /* Success clears its error slot; ownership of the saved error stays here. */
    error_output = first;
    CHECK(emf_document_snapshot(document, &output, &error_output) == EMF_OK);
    CHECK(output != NULL && error_output == NULL);
    emf_buffer_free(output);
    output = NULL;
    init_error_info(&error_info);
    CHECK(emf_error_view(first, &error_info) == EMF_OK);
    CHECK(error_info.status == EMF_INVALID_ARGUMENT && error_info.message_length > 0);
    emf_error_free(first);
    first = NULL;
    emf_document_free(document);
    document = NULL;

    CHECK(emf_buffer_view(encoded, &data, &length) == EMF_OK);
    CHECK(length == input_length && memcmp(data, input, input_length) == 0);
    /* Invalid view outputs also leave the buffer usable for the next call. */
    CHECK(emf_buffer_view(encoded, NULL, &length) == EMF_INVALID_ARGUMENT);
    CHECK(length == 0);
    CHECK(emf_buffer_view(encoded, &data, &length) == EMF_OK);
    CHECK(length == input_length && memcmp(data, input, input_length) == 0);
    emf_buffer_free(encoded);
    encoded = NULL;
    CHECK(emf_buffer_view(record, &data, &length) == EMF_OK);
    CHECK(length == 15 && memcmp(data, input + HEADER_SIZE, 15) == 0);
    emf_buffer_free(record);
    record = NULL;

    /* This error outlives the document, its peer error and all output buffers. */
    init_error_info(&error_info);
    CHECK(emf_error_view(second, &error_info) == EMF_OK);
    CHECK(error_info.status == EMF_INVALID_ARGUMENT);
    CHECK(error_info.message_length == message_length);
    CHECK(memcmp(error_info.message, message, (size_t)message_length) == 0);
    emf_error_free(second);
    return 0;
}

static int check_wmf(void) {
    static const uint8_t wmf[] = {
        1, 0, 9, 0, 0, 3, 16, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0,
        4, 0, 0, 0, 3, 1, 8, 0, 3, 0, 0, 0, 0, 0, 0xde, 0xad
    };
    emf_wmf_document *document = NULL;
    emf_buffer *original = NULL, *encoded = NULL;
    emf_info info;
    emf_record_descriptor records[2];
    uint64_t count = 0, length = 0;
    const uint8_t *data = NULL;
    CHECK(emf_wmf_parse(wmf, sizeof(wmf), NULL, &document, NULL) == EMF_OK);
    init_info(&info);
    CHECK(emf_wmf_document_info(document, &info) == EMF_OK);
    CHECK(info.format == EMF_FORMAT_WMF_STANDARD && info.header_bytes == 18);
    CHECK(info.record_count == 2 && info.has_eof == 1 && info.trailing_bytes == 2);
    CHECK(emf_wmf_record_batch(document, 0, 2, records, &count) == EMF_OK);
    CHECK(count == 2 && records[0].type_id == 0x103 && records[1].family == 1);
    CHECK(emf_wmf_record_bytes(document, 0, &original, NULL) == EMF_OK);
    /* Every rejected mutation must preserve the same live document. */
    static const uint8_t odd_payload[] = {1};
    const struct {
        uint64_t index;
        uint32_t function;
        const uint8_t *payload;
        uint64_t length;
    } rejected[] = {
        {0, 0x103, odd_payload, sizeof(odd_payload)},
        {2, 0x103, NULL, 0},
        {0, 0x10000, NULL, 0},
        {0, 0x103, NULL, 2}
    };
    for (size_t i = 0; i < sizeof(rejected) / sizeof(rejected[0]); ++i) {
        CHECK(emf_wmf_replace_record(document, rejected[i].index, rejected[i].function,
                                    rejected[i].payload, rejected[i].length, NULL) == EMF_INVALID_ARGUMENT);
        CHECK(emf_wmf_serialize(document, &encoded, NULL) == EMF_OK);
        CHECK(emf_buffer_view(encoded, &data, &length) == EMF_OK);
        CHECK(length == sizeof(wmf) && memcmp(data, wmf, sizeof(wmf)) == 0);
        emf_buffer_free(encoded);
        encoded = NULL;
    }
    static const uint8_t replacement[] = {2, 0, 99, 0};
    CHECK(emf_wmf_replace_record(document, 0, 0x999, replacement, sizeof(replacement), NULL) == EMF_OK);
    CHECK(emf_wmf_replace_record(document, 0, 0x10000, NULL, 0, NULL) == EMF_INVALID_ARGUMENT);
    CHECK(emf_wmf_serialize(document, &encoded, NULL) == EMF_OK);
    emf_wmf_document_free(document);
    CHECK(emf_buffer_view(encoded, &data, &length) == EMF_OK);
    CHECK(length == sizeof(wmf) + 2 && data[6] == 17);
    CHECK(data[22] == 0x99 && data[23] == 9 && data[24] == 2 && data[26] == 99);
    CHECK(data[length - 2] == 0xde && data[length - 1] == 0xad);
    emf_buffer_free(encoded);
    CHECK(emf_buffer_view(original, &data, &length) == EMF_OK);
    CHECK(length == 8 && memcmp(data, wmf + 18, 8) == 0);
    emf_buffer_free(original);
    emf_wmf_document_free(NULL);
    return 0;
}

static int check_emf_plus_snapshot(void) {
    emf_document *document = NULL;
    emf_buffer *buffer = NULL;
    emf_plus_snapshot_options options = {sizeof(options), EMF_PLUS_SNAPSHOT_VERSION, 4096};
    const uint8_t *data = NULL;
    uint64_t length = 0;
    CHECK(sizeof(options) == 16);
    make_fixture();
    memset(input + HEADER_SIZE, 0, INPUT_CAPACITY - HEADER_SIZE);
    put_u32(88, 70); put_u32(92, 32); put_u32(96, 20);
    memcpy(input + 100, "EMF+", 4);
    put_u16(104, 0x4009); put_u16(106, 0x8000);
    put_u32(108, 16); put_u32(112, 4); put_u32(116, 0x80ff0033);
    input_length = 120;
    CHECK(emf_parse(input, input_length, NULL, &document, NULL) == EMF_OK);
    options.version = EMF_PLUS_SNAPSHOT_VERSION_2 + 1;
    CHECK(emf_document_emf_plus_snapshot_v1(document, &options, NULL, &buffer, NULL) == EMF_INVALID_ARGUMENT);
    CHECK(buffer == NULL);
    options.version = EMF_PLUS_SNAPSHOT_VERSION;
    CHECK(emf_document_emf_plus_snapshot_v1(document, &options, NULL, &buffer, NULL) == EMF_OK);
    emf_document_free(document);
    CHECK(emf_buffer_view(buffer, &data, &length) == EMF_OK);
    CHECK(length == 156 && memcmp(data, "EPSN", 4) == 0);
    CHECK(data[116] == 3 && data[152] == 0x33 && data[155] == 0x80);
    emf_buffer_free(buffer);
    buffer = NULL;
    options.version++;
    CHECK(emf_document_emf_plus_snapshot_v1(NULL, &options, NULL, &buffer, NULL) == EMF_INVALID_ARGUMENT);
    CHECK(buffer == NULL);
    return 0;
}

int main(void) {
    CHECK(check_layout() == 0);
    CHECK(check_lifetimes_and_recovery() == 0);
    CHECK(check_snapshot() == 0);
    CHECK(check_scalar_state_snapshots() == 0);
    CHECK(check_coordinate_snapshots() == 0);
    CHECK(check_color_shape_snapshots() == 0);
    CHECK(check_fixed_state_snapshots() == 0);
    CHECK(check_fixed_geometry_snapshots() == 0);
    CHECK(check_point_array_snapshots() == 0);
    CHECK(check_completion_snapshots() == 0);
    CHECK(check_transform_snapshots() == 0);
    CHECK(check_poly_draw_snapshots() == 0);
    CHECK(check_multi_array_snapshots() == 0);
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
    CHECK(check_wmf() == 0);
    CHECK(check_emf_plus_snapshot() == 0);
    puts("C ABI smoke: ok");
    return 0;
}
