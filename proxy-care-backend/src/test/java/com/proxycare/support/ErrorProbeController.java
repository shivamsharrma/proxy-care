package com.proxycare.support;

import com.proxycare.common.exception.BusinessException;
import com.proxycare.common.exception.ErrorCode;
import com.proxycare.common.api.PageResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import java.util.List;
import java.util.stream.IntStream;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.PageImpl;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Test-only endpoints that exercise the error format, logging and pagination. */
@RestController
@RequestMapping("/api/v1/_probe")
class ErrorProbeController {

    static final int TOTAL_ITEMS = 250;

    record ProbeRequest(
            @NotBlank String phone, @NotBlank String otp, @Min(0) @Max(120) int age) {}

    @PostMapping("/validated")
    ResponseEntity<Void> validated(@Valid @RequestBody ProbeRequest request) {
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/not-found")
    void notFound() {
        throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND, "Thing not found.");
    }

    @GetMapping("/boom")
    void boom() {
        throw new IllegalStateException("secret internal detail");
    }

    @GetMapping("/items")
    PageResponse<Integer> items(Pageable pageable) {
        List<Integer> page = IntStream.range(0, TOTAL_ITEMS)
                .skip(pageable.getOffset())
                .limit(pageable.getPageSize())
                .boxed()
                .toList();
        return PageResponse.from(new PageImpl<>(page, pageable, TOTAL_ITEMS));
    }
}
