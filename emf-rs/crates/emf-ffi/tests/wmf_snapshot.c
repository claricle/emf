#include "emf.h"
#include <assert.h>
#include <stdint.h>
#include <string.h>

int main(void) {
    const uint8_t input[] = {1,0,9,0,0,3,17,0,0,0,0,0,5,0,0,0,0,0,
                             5,0,0,0,0x14,2,0xff,0xff,2,0,3,0,0,0,0,0};
    emf_wmf_document *document = NULL;
    emf_buffer *snapshot = NULL;
    assert(emf_wmf_parse(input, sizeof input, NULL, &document, NULL) == EMF_OK);
    assert(emf_wmf_document_snapshot(document, &snapshot, NULL) == EMF_OK);
    emf_wmf_document_free(document);
    const uint8_t *bytes = NULL;
    uint64_t length = 0;
    assert(emf_buffer_view(snapshot, &bytes, &length) == EMF_OK);
    assert(length == 208 && memcmp(bytes, "WMFS\1\0\0\0", 8) == 0);
    assert(bytes[148] == 2); /* fixed geometry family */
    assert(bytes[160] == 0xff && bytes[163] == 0xff); /* signed Y */
    assert(bytes[164] == 2); /* X */
    emf_buffer_free(snapshot);
    snapshot = (emf_buffer *)(uintptr_t)1;
    assert(emf_wmf_document_snapshot(NULL, &snapshot, NULL) == EMF_INVALID_ARGUMENT);
    assert(snapshot == NULL);
    return 0;
}
