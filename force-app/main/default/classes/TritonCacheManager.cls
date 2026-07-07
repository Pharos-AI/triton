/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the MIT License.
 * See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.
 */

/**
 * Centralizes all platform cache operations (Org Cache).
 * In production, delegates to Cache.Org.
 * In test context, uses a static Map to avoid platform cache limitations
 * where put() succeeds silently but get() returns null.
 */
public with sharing class TritonCacheManager {

    // Controls whether the mock map is used instead of real platform cache.
    // Defaults to true in test context. Tests can set to false to exercise
    // production Cache.Org code paths.
    @TestVisible
    private static Boolean useMock = Test.isRunningTest();

    // ─── Org Cache ────────────────────────────────────────────────────

    @TestVisible
    private static Map<String, Object> mockCache = new Map<String, Object>();

    public static void put(String key, Object value, Integer ttl) {
        if (useMock) {
            mockCache.put(key, value);
        } else {
            Cache.Org.put(key, value, ttl);
        }
    }

    public static Object get(String key) {
        if (useMock) {
            return mockCache.get(key);
        }
        return Cache.Org.get(key);
    }

    public static Set<String> getKeys() {
        if (useMock) {
            return mockCache.keySet().clone();
        }
        return Cache.Org.getKeys();
    }

    public static void remove(String key) {
        if (useMock) {
            mockCache.remove(key);
        } else {
            Cache.Org.remove(key);
        }
    }

    /**
     * Checks whether Org cache is available.
     * In test context with mock enabled, always returns true.
     */
    public static Boolean available() {
        if (useMock) {
            return true;
        }
        try {
            Cache.Org.getKeys();
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    // ─── Test Utilities ───────────────────────────────────────────────

    @TestVisible
    private static void resetMock() {
        mockCache.clear();
        useMock = true;
    }
}
