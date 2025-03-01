---
layout: default
---
# Classes

## Apex Classes

### [Triton](./Miscellaneous/Triton.md)
The Triton class provides a robust logging framework for Salesforce applications.
Enables structured logging with different severity levels, categories, and functional areas.

### [TritonBuilder](./Miscellaneous/TritonBuilder.md)
Builder class for creating and configuring Pharos log records.
Provides a fluent interface for setting various attributes like category, type, area,
and other metadata for logging purposes.

### [TritonFlow](./Miscellaneous/TritonFlow.md)
Provides logging capabilities for Salesforce Flows and Process Builder.
Exposes an invocable method that can be called directly from Flow Builder.

### [TritonHelper](./Miscellaneous/TritonHelper.md)
Utility methods and builder classes for the Triton logging framework.
Includes functionality for log level management, transaction tracking, and message formatting.

### [TritonLwc](./Miscellaneous/TritonLwc.md)
Provides logging capabilities for Lightning Web Components (LWC).
Exposes AuraEnabled methods for client-side logging with runtime information capture.

### [TritonTest](./Miscellaneous/TritonTest.md)
Test class for the Triton logging framework.

### [TritonTypes](./Miscellaneous/TritonTypes.md)
Enums and constants for the Triton logging framework.
Defines the classification system used to categorize and filter log entries.

## JavaScript Classes

### [triton.js](./Miscellaneous/triton.js.md)
JavaScript implementation of the Triton logging framework for Lightning Web Components.
Provides client-side logging with transaction tracking and runtime information capture.

### [tritonBuilder.js](./Miscellaneous/tritonBuilder.js.md)
JavaScript implementation of the TritonBuilder class.
Provides a fluent interface for constructing log entries with runtime context.

### [tritonUtils.js](./Miscellaneous/tritonUtils.js.md)
Utility functions for the JavaScript implementation.
Provides helpers for stack trace analysis, transaction ID generation, and runtime information capture.

---

Copyright (C) 2024 Pharos AI, Inc.

This file is part of Pharos Triton.

Pharos Triton is free software: you can redistribute it and/or modify
it under the terms of the MIT License.
See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.

