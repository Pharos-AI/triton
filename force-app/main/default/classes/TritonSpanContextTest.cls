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
 * Unit tests for TritonSpanContext -- the span stack in isolation.
 * No org state, no logging: these exercise the data structure only.
 */
@IsTest
private class TritonSpanContextTest {

    @IsTest
    private static void test_push_current_parent() {
        TritonSpanContext ctx = new TritonSpanContext();

        System.assertEquals(null, ctx.current(), 'Empty stack has no current span');
        System.assertEquals(null, ctx.parent(), 'Empty stack has no parent span');

        ctx.push('a');
        System.assertEquals('a', ctx.current(), 'Top of stack is the current span');
        System.assertEquals(null, ctx.parent(), 'A single entry has no parent');

        ctx.push('b');
        System.assertEquals('b', ctx.current(), 'The newest push becomes current');
        System.assertEquals('a', ctx.parent(), 'The entry below the top is the parent');
    }

    @IsTest
    private static void test_pop_out_of_order() {
        TritonSpanContext ctx = new TritonSpanContext();
        ctx.push('a');
        ctx.push('b');
        ctx.push('c');

        System.assertEquals(true, ctx.pop('b'), 'Popping a non-top entry removes it');
        System.assertEquals('c', ctx.current(), 'The top is unaffected by an out-of-order pop');
        System.assertEquals('a', ctx.parent(), 'The removed entry no longer sits between them');
    }

    @IsTest
    private static void test_pop_absent_is_noop() {
        TritonSpanContext ctx = new TritonSpanContext();
        ctx.push('a');

        System.assertEquals(false, ctx.pop('missing'), 'Popping an absent id reports nothing removed');
        System.assertEquals(1, ctx.getStack().size(), 'The stack is untouched');
        System.assertEquals('a', ctx.current(), 'The top is untouched');
        System.assertEquals(false, ctx.pop(null), 'Popping null reports nothing removed');
    }

    @IsTest
    private static void test_pop_duplicates_newest_first() {
        TritonSpanContext ctx = new TritonSpanContext();
        ctx.push('dup');
        ctx.push('mid');
        ctx.push('dup');

        ctx.pop('dup');

        System.assertEquals(new List<String>{'dup', 'mid'}, ctx.getStack(),
            'lastIndexOf semantics remove the newest occurrence first');
    }

    @IsTest
    private static void test_reset_and_clear() {
        TritonSpanContext ctx = new TritonSpanContext();
        ctx.push('a');
        ctx.push('b');

        ctx.reset('root');
        System.assertEquals(new List<String>{'root'}, ctx.getStack(), 'reset(id) leaves exactly the root');
        System.assertEquals('root', ctx.current(), 'The root is current after a reset');

        ctx.reset(null);
        System.assertEquals(true, ctx.getStack().isEmpty(), 'reset(null) empties the stack');

        ctx.push('x');
        ctx.reset('  ');
        System.assertEquals(true, ctx.getStack().isEmpty(), 'reset(blank) empties the stack');

        ctx.push('y');
        ctx.clear();
        System.assertEquals(true, ctx.getStack().isEmpty(), 'clear() empties the stack');
        System.assertEquals(null, ctx.current(), 'Nothing is current after clear()');
    }

    @IsTest
    private static void test_stack_round_trip() {
        TritonSpanContext ctx = new TritonSpanContext();
        ctx.setStack(new List<String>{'one', 'two'});

        System.assertEquals(new List<String>{'one', 'two'}, ctx.getStack(), 'setStack/getStack round-trip');
        System.assertEquals('two', ctx.current(), 'The last entry of an assigned stack is current');

        ctx.setStack(null);
        System.assertEquals(true, ctx.getStack().isEmpty(), 'setStack(null) yields an empty stack, never null');
    }

    @IsTest
    private static void test_depth() {
        TritonSpanContext ctx = new TritonSpanContext();
        System.assertEquals(0, ctx.depth(), 'A new context is empty');

        ctx.push('a');
        ctx.push('b');
        System.assertEquals(2, ctx.depth(), 'Depth counts the entries on the stack');
    }
}
