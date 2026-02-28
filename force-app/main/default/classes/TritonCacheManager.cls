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
 * Centralizes all platform cache operations (Org and Session).
 * In production, delegates to Cache.Org / Cache.Session.
 * In test context, uses static Maps to avoid platform cache limitations
 * where put() succeeds silently but get() returns null.
 */
public with sharing class TritonCacheManager {

    // Controls whether mock maps are used instead of real platform cache.
    // Defaults to true in test context. Tests can set to false to exercise
    // production Cache.Org / Cache.Session code paths.
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

    // ─── Session Cache ────────────────────────────────────────────────

    @TestVisible
    private static Map<String, String> mockSessionCache = new Map<String, String>();

    public static void sessionPut(String key, String value, Integer ttl) {
        if (useMock) {
            mockSessionCache.put(key, value);
        } else {
            Cache.Session.put(key, value, ttl);
        }
    }

    public static String sessionGet(String key) {
        if (useMock) {
            return mockSessionCache.get(key);
        }
        return (String) Cache.Session.get(key);
    }

    public static void sessionRemove(String key) {
        if (useMock) {
            mockSessionCache.remove(key);
        } else {
            Cache.Session.remove(key);
        }
    }

    /**
     * Checks whether Session cache is available.
     * In test context with mock enabled, always returns true.
     */
    public static Boolean sessionAvailable() {
        if (useMock) {
            return true;
        }
        try {
            Cache.Session.getKeys();
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    // ─── Test Utilities ───────────────────────────────────────────────

    @TestVisible
    private static void resetMock() {
        mockCache.clear();
        mockSessionCache.clear();
        useMock = true;
    }
}
