package in.proxycare.shared.api;

import io.swagger.v3.oas.annotations.media.Schema;

/**
 * Where a page sits in a collection (ADR 0012).
 *
 * @param nextCursor cursor for the next page; null on the last page
 * @param hasMore whether another page exists
 * @param size the page size applied to this request
 */
@Schema(name = "PageMetadata", description = "Cursor pagination state.")
public record PageMetadata(
    @Schema(
            description =
                "Opaque cursor for the next page; pass it back unchanged. Null on the last page.",
            example = "MQEyMDI2LTAxLTE1VDA5OjAwOjAwWgEwMTlh",
            nullable = true)
        String nextCursor,
    @Schema(description = "Whether another page exists.", example = "true") boolean hasMore,
    @Schema(description = "Page size applied (1-100, default 20).", example = "20") int size) {}
