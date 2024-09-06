---
layout: default
---
# TritonTest

`ISTEST`

Copyright (C) 2024 Pharos AI, Inc.

This file is part of Pharos Triton.

Pharos Triton is free software: you can redistribute it and/or modify
it under the terms of the MIT License.
See LICENSE file or go to https://github.com/Pharos-AI/triton/blob/main/LICENSE.

## Fields

### `public TEST_ENDPOINT` → `String`


---
## Methods
### `private static void assertCreatedLog(TritonTypes.Category logCategory)`
### `private static void assertCreatedIntegrationLog()`
### `private static void assertBefore()`
### `private static void testSetup()`

`TESTSETUP`
### `private static void test_log_levels()`

`ISTEST`
### `private static void test_log_levels_positive()`

`ISTEST`
### `private static void test_log_levels_negative()`

`ISTEST`
### `private static void setupLogLevelsMap()`
### `private static void test_log_levels_mapping()`

`ISTEST`
### `private static void test_log_levels_mapping_negative()`

`ISTEST`
### `private static void test_sync_event()`

`ISTEST`
### `private static void test_sync_debug()`

`ISTEST`
### `private static void test_sync_warning()`

`ISTEST`
### `private static void test_sync_error()`

`ISTEST`
### `private static void test_sync_error_from_exception()`

`ISTEST`
### `private static void test_sync_integration_from_exception()`

`ISTEST`
### `private static void test_integration_error_sync()`

`ISTEST`
### `private static void test_save_component_log()`

`ISTEST`
### `private static void test_flow()`

`ISTEST`
### `public static Map<String,HttpCalloutMock> createEndpoint2TestResp()`
### `public static void testHttpRequest()`
---
## Classes
### MultiRequestMock

**Implemented types**

[HttpCalloutMock](HttpCalloutMock)

#### Constructors
##### `public MultiRequestMock(Map&lt;String,HttpCalloutMock&gt; requests)`
---
#### Fields

##### `private requests` → `Map&lt;String,HttpCalloutMock&gt;`


---
#### Methods
##### `public HttpResponse respond(HttpRequest req)`
##### `public void addRequestMock(String url, HttpCalloutMock mock)`
---

### MultiRequestMockException

**Inheritance**

MultiRequestMockException


### SingleRequestMock

**Implemented types**

[HttpCalloutMock](HttpCalloutMock)

#### Constructors
##### `public SingleRequestMock(Integer code, String status, String body)`
---
#### Methods
##### `public HttpResponse respond(HttpRequest req)`
##### `public String getBodyRequest()`
---

---
