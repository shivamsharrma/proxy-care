package com.proxycare.common.webhook;

import java.sql.Timestamp;
import java.time.Clock;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Stores every verified webhook once, keyed by (provider, event id), so provider retries are harmless.
 * Processing (and processed_at / error) is added by the feature that handles each event type.
 */
@Component
public class WebhookInbox {

    private final JdbcTemplate jdbc;
    private final Clock clock;

    public WebhookInbox(JdbcTemplate jdbc, Clock clock) {
        this.jdbc = jdbc;
        this.clock = clock;
    }

    /** @return true only the first time this event id is seen for the provider */
    public boolean recordIfNew(String provider, String eventId, String eventType, String rawPayload) {
        return jdbc.update(
                        "insert into webhook_events (provider, event_id, event_type, payload, received_at)"
                                + " values (?, ?, ?, ?::jsonb, ?) on conflict do nothing",
                        provider,
                        eventId,
                        eventType,
                        rawPayload,
                        Timestamp.from(clock.instant()))
                == 1;
    }
}
