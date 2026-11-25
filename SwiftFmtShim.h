#ifndef SWIFTFMT_SHIM_H
#define SWIFTFMT_SHIM_H

/* C ABI surface of the SwiftFmtShim static library.
 * Copy this header next to libSwiftFmtShim.a. */

#ifdef __cplusplus
extern "C" {
#endif

/* Returns a static version string. The caller must NOT free it. */
const char *swiftfmt_version(void);

/* Formats Swift source code.
 *
 * input:    NUL-terminated UTF-8 Swift source (must not be NULL)
 * filename: NUL-terminated filename assumed for diagnostics (may be NULL)
 *
 * Returns a malloc'd UTF-8 formatted string (free with swiftfmt_free), or
 * NULL when: input is NULL, input is not valid UTF-8, or the source contains
 * parse errors (swift-format reports errors instead of guessing).
 * Empty input returns an empty string (""), mirroring the swift-format CLI. */
char *swiftfmt_format(const char *input, const char *filename);

/* Frees a buffer returned by swiftfmt_format. Passing NULL is allowed. */
void swiftfmt_free(char *ptr);

#ifdef __cplusplus
}
#endif

#endif /* SWIFTFMT_SHIM_H */
