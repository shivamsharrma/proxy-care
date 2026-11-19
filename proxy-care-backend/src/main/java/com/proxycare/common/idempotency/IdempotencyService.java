package com.proxycare.common.idempotency;

import com.proxycare.common.config.AppProperties;
import com.proxycare.common.error.AppException;
import com.proxycare.common.error.ErrorCode;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.util.HexFormat;
import java.util.UUID;
import java.util.function.Supplier;
import org.springframework.dao.DataAccessException;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import tools.jackson.databind.MapperFeature;
import tools.jackson.databind.SerializationFeature;
import tools.jackson.databind.json.JsonMapper;

/**
 * Runs an endpoint's action at most once per (user, Idempotency-Key). The endpoint calls it explicitly.
 *
 * <p>Claim, action and stored response share <b>one transaction</b>. A concurrent duplicate blocks on
 * the claim insert until the first transaction commits, then replays its response. If it waits longer
 * than {@code proxycare.idempotency.lock-timeout} it gets 409 IDEMPOTENCY_IN_PROGRESS and should retry.
 * If the action throws, everything rolls back and the key is free again.
 *
 * <p>Limitations: only the status and JSON body are stored and replayed (not headers such as Location).
 * A rollback can't undo external calls, so an action that calls a vendor (e.g. Razorpay) must also pass
 * the vendor a stable receipt/idempotency value.
 */
@Service
public class IdempotencyService {

    public static final String REPLAYED_HEADER = "Idempotent-Replayed";
    private static final String LOCK_NOT_AVAILABLE = "55P03";
    private static final Duration RETENTION = Duration.ofHours(24);

    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;
    private final JsonMapper json;
    private final JsonMapper canonicalJson;
    private final Clock clock;
    private final Duration lockTimeout;

    public IdempotencyService(
            JdbcTemplate jdbc,
            PlatformTransactionManager transactionManager,
            JsonMapper json,
            Clock clock,
            AppProperties props) {
        this.jdbc = jdbc;
        this.tx = new TransactionTemplate(transactionManager);
        this.json = json;
        // A dedicated copy with stable property and map-key order, so equal requests hash equally.
        this.canonicalJson = json.rebuild()
                .enable(MapperFeature.SORT_PROPERTIES_ALPHABETICALLY)
                .enable(SerializationFeature.ORDER_MAP_ENTRIES_BY_KEYS)
                .build();
        this.clock = clock;
        this.lockTimeout = props.idempotency().lockTimeout();
    }

    public <T> ResponseEntity<T> execute(
            UUID userId, String key, Object request, Class<T> responseType, Supplier<ResponseEntity<T>> action) {
        UUID idempotencyKey = parseKey(key);
        String hash = sha256(canonicalJson.writeValueAsBytes(request));
        try {
            return tx.execute(status -> {
                jdbc.queryForObject("select set_config('lock_timeout', ?, true)", String.class, lockTimeout.toMillis() + "ms");
                int claimed = jdbc.update(
                        "insert into idempotency_keys (user_id, key, request_hash, created_at) values (?, ?, ?, ?)"
                                + " on conflict do nothing",
                        userId,
                        idempotencyKey,
                        hash,
                        Timestamp.from(clock.instant()));
                if (claimed == 0) {
                    return replay(userId, idempotencyKey, hash, responseType);
                }
                ResponseEntity<T> response = action.get();
                jdbc.update(
                        "update idempotency_keys set response_status = ?, response_body = ?::jsonb"
                                + " where user_id = ? and key = ?",
                        response.getStatusCode().value(),
                        response.getBody() == null ? null : json.writeValueAsString(response.getBody()),
                        userId,
                        idempotencyKey);
                return response;
            });
        } catch (DataAccessException e) {
            if (isLockTimeout(e)) {
                throw new AppException(
                        ErrorCode.IDEMPOTENCY_IN_PROGRESS, "The same request is still being processed. Retry shortly.");
            }
            throw e;
        }
    }

    /** Deletes keys older than 24h. Runs daily; running it twice (e.g. on two instances) is harmless. */
    @Scheduled(cron = "0 15 3 * * *", zone = "Asia/Kolkata")
    public void deleteExpired() {
        jdbc.update("delete from idempotency_keys where created_at < ?", Timestamp.from(clock.instant().minus(RETENTION)));
    }

    private <T> ResponseEntity<T> replay(UUID userId, UUID key, String hash, Class<T> responseType) {
        return jdbc.queryForObject(
                "select request_hash, response_status, response_body::text from idempotency_keys"
                        + " where user_id = ? and key = ?",
                (rs, i) -> {
                    if (!rs.getString(1).equals(hash)) {
                        throw new AppException(
                                ErrorCode.IDEMPOTENCY_KEY_REUSED,
                                "This Idempotency-Key was already used with a different request.");
                    }
                    String body = rs.getString(3);
                    return ResponseEntity.status(rs.getInt(2))
                            .contentType(MediaType.APPLICATION_JSON)
                            .header(REPLAYED_HEADER, "true")
                            .body(body == null ? null : json.readValue(body, responseType));
                },
                userId,
                key);
    }

    private static UUID parseKey(String key) {
        try {
            if (key != null && key.length() == 36) {
                return UUID.fromString(key);
            }
        } catch (IllegalArgumentException ignored) {
            // falls through to the validation error
        }
        throw new AppException(ErrorCode.VALIDATION_FAILED, "Idempotency-Key must be a UUID.");
    }

    private static boolean isLockTimeout(Throwable e) {
        for (Throwable t = e; t != null; t = t.getCause()) {
            if (t instanceof SQLException sql && LOCK_NOT_AVAILABLE.equals(sql.getSQLState())) {
                return true;
            }
        }
        return false;
    }

    private static String sha256(byte[] bytes) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
