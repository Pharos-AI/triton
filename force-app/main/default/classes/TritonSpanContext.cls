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
 * Tracks span hierarchy with an in-memory stack.
 *
 * A direct Apex port of the LWC SpanContext class (lwc/triton/triton.js), with the
 * same method names and semantics so that a reader of one understands the other and
 * any behaviour difference shows up as a diff rather than hiding in prose.
 *
 * Deliberate divergences from the LWC original:
 * - No sessionStorage persistence tier. Apex has no session storage, and the Platform
 *   Cache equivalent is intentionally out of scope: a cache round-trip per mark would
 *   dominate the cost of the thing being measured, and a cache miss would produce a
 *   silently wrong hierarchy rather than an obviously flat one.
 * - pop() returns whether anything was removed, so a caller can self-heal.
 *
 * Instances are cheap and independent: Triton holds exactly one for the current
 * execution context, and any future context (a batch chunk, a queueable) can hold
 * its own.
 *
 * @see Triton.startMark
 */
public with sharing class TritonSpanContext {

    private List<String> stack = new List<String>();

    /**
    * Returns the current span stack, oldest first.
    * @return the live stack, never null
    */
    public List<String> getStack() {
        return this.stack;
    }

    /**
    * Replaces the span stack.
    * @param stack -- the new stack; null is treated as empty
    */
    public void setStack(List<String> stack) {
        this.stack = stack == null ? new List<String>() : stack;
    }

    /**
    * Pushes a span id onto the stack. Blank values are ignored so a failed id
    * generation can never corrupt the hierarchy.
    * @param spanId -- span identifier to push
    */
    public void push(String spanId) {
        if (String.isBlank(spanId)) return;
        this.stack.add(spanId);
    }

    /**
    * Removes a span id from the stack, newest occurrence first. Supports
    * out-of-order pops, matching the LWC implementation's lastIndexOf semantics.
    * @param spanId -- span identifier to remove
    * @return true when an entry was removed, false when the id was not on the stack
    */
    public Boolean pop(String spanId) {
        if (String.isBlank(spanId)) return false;
        for (Integer i = this.stack.size() - 1; i >= 0; i--) {
            if (spanId.equals(this.stack.get(i))) {
                this.stack.remove(i);
                return true;
            }
        }
        return false;
    }

    /**
    * Returns the innermost (top) span id.
    * @return the current span id, or null when the stack is empty
    */
    public String current() {
        return this.stack.isEmpty() ? null : this.stack.get(this.stack.size() - 1);
    }

    /**
    * Returns the span id enclosing the current one (second from top).
    * @return the parent span id, or null when there is no enclosing span
    */
    public String parent() {
        return this.stack.size() > 1 ? this.stack.get(this.stack.size() - 2) : null;
    }

    /**
    * Resets the stack so it contains only the supplied root.
    * @param rootId -- the root span id; a blank value empties the stack
    */
    public void reset(String rootId) {
        this.stack = String.isBlank(rootId) ? new List<String>() : new List<String>{rootId};
    }

    /**
    * Empties the stack entirely.
    */
    public void clear() {
        this.stack = new List<String>();
    }

    /**
    * Returns how many span ids are on the stack.
    * @return the stack depth
    */
    public Integer depth() {
        return this.stack.size();
    }
}
