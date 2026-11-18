package in.proxycare.support.api;

import in.proxycare.shared.api.ApiResponses;
import in.proxycare.shared.api.DataResponse;
import in.proxycare.shared.api.EntityTags;
import in.proxycare.shared.api.PageQuery;
import in.proxycare.shared.api.PageResponse;
import in.proxycare.shared.error.BusinessRuleViolationException;
import in.proxycare.shared.error.ConflictException;
import in.proxycare.shared.error.ForbiddenException;
import in.proxycare.shared.error.NotFoundException;
import in.proxycare.shared.error.ProxyCareException;
import in.proxycare.shared.error.UpstreamException;
import in.proxycare.shared.money.Money;
import in.proxycare.support.persistence.ProbeEntity;
import in.proxycare.support.persistence.ProbeEntityRepository;
import io.github.resilience4j.bulkhead.Bulkhead;
import io.github.resilience4j.bulkhead.BulkheadFullException;
import io.github.resilience4j.circuitbreaker.CallNotPermittedException;
import io.github.resilience4j.circuitbreaker.CircuitBreakerConfig;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import io.github.resilience4j.ratelimiter.RateLimiter;
import io.github.resilience4j.ratelimiter.RequestNotPermitted;
import jakarta.validation.ConstraintViolationException;
import jakarta.validation.Valid;
import jakarta.validation.Validator;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import java.net.http.HttpTimeoutException;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.QueryTimeoutException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.orm.ObjectOptimisticLockingFailureException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.InsufficientAuthenticationException;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.HttpServerErrorException;
import org.springframework.web.client.ResourceAccessException;

/**
 * TEST-ONLY API over {@code ProbeEntity}, served at {@code /api/v1/probes} by the real MVC stack.
 * Exercises every response shape and error category of ADR 0012 before feature endpoints exist.
 * Excluded from the OpenAPI document (application-test.yml).
 */
@RestController
@RequestMapping("/probes")
class ProbeApiController {

  /** Secrets that must never appear in a response. */
  static final String SECRET = "s3cr3t-vendor-or-sql-text";

  private final ProbeEntityRepository repository;
  private final TransactionTemplate transactions;
  private final JdbcClient jdbc;
  private final Validator validator;
  private final CircuitBreakerRegistry circuitBreakers;

  ProbeApiController(
      ProbeEntityRepository repository,
      TransactionTemplate transactions,
      JdbcClient jdbc,
      Validator validator,
      CircuitBreakerRegistry circuitBreakers) {
    this.repository = repository;
    this.transactions = transactions;
    this.jdbc = jdbc;
    this.validator = validator;
    this.circuitBreakers = circuitBreakers;
  }

  record CreateProbe(
      @NotBlank @Size(max = 40) String name, @NotNull @PositiveOrZero Long amountPaise) {}

  record RenameProbe(@NotBlank String name) {}

  record ProbeView(UUID id, String name, long amountPaise, Instant createdAt) {}

  @PostMapping
  ResponseEntity<DataResponse<ProbeView>> create(@Valid @RequestBody CreateProbe request) {
    ProbeEntity saved =
        repository.save(new ProbeEntity(request.name(), Money.ofPaise(request.amountPaise())));
    return ApiResponses.created(saved.getId(), view(saved), saved.getVersion());
  }

  @GetMapping("/{id}")
  ResponseEntity<DataResponse<ProbeView>> get(@PathVariable UUID id) {
    ProbeEntity probe = repository.findById(id).orElseThrow(NotFoundException::new);
    return ApiResponses.ok(view(probe), probe.getVersion());
  }

  /** If-Match is checked first, and the entity version enforces it again at the write. */
  @PatchMapping("/{id}")
  ResponseEntity<DataResponse<ProbeView>> rename(
      @PathVariable UUID id,
      @RequestHeader(value = HttpHeaders.IF_MATCH, required = false) String ifMatch,
      @Valid @RequestBody RenameProbe request) {
    ProbeEntity updated =
        transactions.execute(status -> {
          ProbeEntity probe = repository.findById(id).orElseThrow(NotFoundException::new);
          EntityTags.requireMatch(ifMatch, probe.getVersion());
          probe.rename(request.name());
          return repository.saveAndFlush(probe);
        });
    return ApiResponses.ok(view(updated), updated.getVersion());
  }

  /** Keyset pagination over (created_at, id). */
  @GetMapping
  ResponseEntity<PageResponse<ProbeView>> list(
      @RequestParam(required = false) String cursor, @RequestParam(required = false) Integer size) {
    PageQuery page = PageQuery.of(cursor, size, 2);
    String select =
        "select id, name, amount_paise, created_at from proxycare.test_probe_entity"
            + " where not deleted";
    List<ProbeView> rows =
        page.isFirstPage()
            ? jdbc.sql(select + " order by created_at, id limit :limit")
                .param("limit", page.fetchSize())
                .query(ProbeApiController::row)
                .list()
            : jdbc.sql(
                    select
                        + " and (created_at, id) > (:createdAt, :id)"
                        + " order by created_at, id limit :limit")
                .param("createdAt", OffsetDateTime.parse(page.after().get(0)))
                .param("id", UUID.fromString(page.after().get(1)))
                .param("limit", page.fetchSize())
                .query(ProbeApiController::row)
                .list();
    return ApiResponses.page(
        page.toResponse(
            rows, probe -> List.of(probe.createdAt().toString(), probe.id().toString())));
  }

  /** Method parameter validation. */
  @GetMapping("/params")
  ResponseEntity<DataResponse<Integer>> params(@RequestParam @Min(1) @Max(10) int count) {
    return ApiResponses.ok(count);
  }

  @GetMapping("/secured")
  ResponseEntity<DataResponse<String>> secured() {
    return ApiResponses.ok("secured");
  }

  @GetMapping("/admin")
  ResponseEntity<DataResponse<String>> admin() {
    return ApiResponses.ok("admin");
  }

  /** Throws one exception of each category, each loaded with text that must not leak. */
  @GetMapping("/errors/{kind}")
  void fail(@PathVariable String kind) {
    switch (kind) {
      case "not-found" -> throw new NotFoundException();
      case "conflict" -> throw new ConflictException("The probe is already claimed.");
      case "business-rule" ->
          throw new BusinessRuleViolationException("A completed probe cannot be renamed.");
      case "forbidden" -> throw new ForbiddenException();
      case "upstream" ->
          throw new UpstreamException("The partner service failed.", new RuntimeException(SECRET));
      case "upstream-timeout" ->
          throw UpstreamException.timeout(
              "The partner service timed out.", new RuntimeException(SECRET));
      case "raw-vendor-error" ->
          throw HttpServerErrorException.create(
              HttpStatus.BAD_GATEWAY,
              "Bad Gateway",
              HttpHeaders.EMPTY,
              SECRET.getBytes(StandardCharsets.UTF_8),
              StandardCharsets.UTF_8);
      case "raw-vendor-timeout" ->
          throw new ResourceAccessException(SECRET, new HttpTimeoutException(SECRET));
      case "circuit-open" ->
          throw CallNotPermittedException.createCallNotPermittedException(
              circuitBreakers.circuitBreaker(
                  "probe-vendor",
                  CircuitBreakerConfig.custom()
                      .waitDurationInOpenState(Duration.ofSeconds(42))
                      .build()));
      case "rate-limited" ->
          throw RequestNotPermitted.createRequestNotPermitted(RateLimiter.ofDefaults("probe"));
      case "app-rate-limited" -> throw ProxyCareException.rateLimited(Duration.ofMillis(1_500));
      case "bulkhead-full" ->
          throw BulkheadFullException.createBulkheadFullException(Bulkhead.ofDefaults("probe"));
      case "integrity" -> throw new DataIntegrityViolationException(SECRET);
      case "optimistic" ->
          throw new ObjectOptimisticLockingFailureException(ProbeEntity.class, SECRET);
      case "db-timeout" -> throw new QueryTimeoutException(SECRET);
      case "constraint" ->
          throw new ConstraintViolationException(validator.validate(new CreateProbe("", -1L)));
      case "access-denied" -> throw new AccessDeniedException(SECRET);
      case "authentication" -> throw new InsufficientAuthenticationException(SECRET);
      case "unexpected" -> throw new IllegalStateException("select * from users -- " + SECRET);
      default -> throw new NotFoundException();
    }
  }

  private static ProbeView view(ProbeEntity probe) {
    return new ProbeView(
        probe.getId(), probe.getName(), probe.getAmount().paise(), probe.getCreatedAt());
  }

  private static ProbeView row(java.sql.ResultSet rs, int rowNumber) throws java.sql.SQLException {
    return new ProbeView(
        rs.getObject("id", UUID.class),
        rs.getString("name"),
        rs.getLong("amount_paise"),
        rs.getObject("created_at", OffsetDateTime.class).toInstant());
  }
}
