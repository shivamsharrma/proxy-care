package com.proxycare.support;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/**
 * Lets a test hold a probe action open without sleeping: close() the gate, wait until the action has
 * entered, assert, then open() it. Open by default, so other tests are never blocked.
 */
public final class ProbeGate {

    private static volatile CountDownLatch entered = new CountDownLatch(0);
    private static volatile CountDownLatch gate = new CountDownLatch(0);

    private ProbeGate() {}

    public static void close() {
        entered = new CountDownLatch(1);
        gate = new CountDownLatch(1);
    }

    public static void open() {
        gate.countDown();
    }

    public static void reset() {
        open();
        entered = new CountDownLatch(0);
    }

    public static void awaitEntered() throws InterruptedException {
        if (!entered.await(30, TimeUnit.SECONDS)) {
            throw new IllegalStateException("probe action never started");
        }
    }

    /** Called by the probe action. */
    static void pass() {
        entered.countDown();
        try {
            if (!gate.await(30, TimeUnit.SECONDS)) {
                throw new IllegalStateException("gate was never opened");
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException(e);
        }
    }
}
