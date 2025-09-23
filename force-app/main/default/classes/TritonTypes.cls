/**
 * Copyright (C) 2024 Pharos AI, Inc.
 *
 * This file is part of Pharos Triton.
 *
 * Pharos Triton is free software: you can redistribute it and/or modify
 * it under the terms of the MIT License.
 * See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.
 *
 * The TritonTypes class provides enums and constants for the Triton logging framework.
 * It defines the classification system used to categorize and filter log entries.
 * 
 * Key components:
 * - Level enum: Defines log severity levels from ERROR to FINEST
 * 
 */
public with sharing class TritonTypes {

    /**
    * Log Levels.
    * Values listed from the least verbose to the most verbose
    */
    public enum Level {
        ERROR,
        WARNING,
        INFO,
        DEBUG,
        FINE,
        FINER,
        FINEST
    }
}
