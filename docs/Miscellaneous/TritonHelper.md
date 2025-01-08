---
layout: default
---
# TritonHelper

TritonHelper provides utility methods and builder classes for the Triton logging framework.
This class includes functionality for:
- Log level management and comparison
- UUID generation for transaction tracking
- HTTP request/response JSON serialization for integration logging
- Pre and post-processing controls for Pharos logging configuration
- Message formatting utilities

The class serves as a central utility hub for the Triton logging system, offering
helper methods and builder patterns to configure and enhance logging capabilities.

## Methods
### `public static String buildLogLevelKey(String category, String type, String area)`

Creates a key for log level based on:

#### Parameters

|Param|Description|
|---|---|
|`category`|-- log category field|
|`tye`|-- log type field|
|`area`|-- log functional area field|

#### Returns

|Type|Description|
|---|---|
|`String`|-- a string with values in the following format: Category:{0};Type:{1};Area:{2}|

### `public static Boolean compareLevel(TritonTypes.Level value, TritonTypes.Level toCompare)`

Compares 2 log levels.

#### Parameters

|Param|Description|
|---|---|
|`value`|-- this is the value compared against|
|`toCompare`|-- comparison performed against this value|

#### Returns

|Type|Description|
|---|---|
|`Boolean`|-- if value is higher than toCompare returns false, otherwise true|

### `public static String generateUUID4()`

Generates a UUID.
Used to create a transaction Id

### `public static String toJson(RestRequest request, RestResponse response)`

Json serialization for http request and response objects.
Used by integration logs.

### `public static String toJson(HttpRequest request, HttpResponse response)`
### `public static String formatMessage(String template, String param)`

Formats a message by replacing {0} placeholder with the provided parameter

#### Parameters

|Param|Description|
|---|---|
|`template`|The message template containing {0} placeholder|
|`param`|The parameter to replace the placeholder with|

#### Returns

|Type|Description|
|---|---|
|`String`|Formatted message|

### `public static String formatMessage(String template, List<String> params)`

Formats a message by replacing {0}, {1}, etc. placeholders with the provided parameters

#### Parameters

|Param|Description|
|---|---|
|`template`|The message template containing numbered placeholders|
|`params`|The list of parameters to replace the placeholders with|

#### Returns

|Type|Description|
|---|---|
|`String`|Formatted message|

---
## Classes
### IntegrationWrapper

Wrapper class for integration logs
Used to create the Json structure that combines http objects

#### Constructors
##### `public IntegrationWrapper(Map&lt;String,Object&gt; request, Map&lt;String,Object&gt; response)`
---
#### Fields

##### `public request` → `Map&lt;String,Object&gt;`


##### `public response` → `Map&lt;String,Object&gt;`


---

### PreProcessingControlsBuilder

Builder class for constructing Pharos pre processing settings


### PostProcessingControlsBuilder

Builder class for constructing Pharos post processing settings

#### Constructors
##### `public PostProcessingControlsBuilder()`
---
#### Fields

##### `private controls` → `Map&lt;String,Boolean&gt;`


##### `private AUDIT_TRAIL_KEY` → `String`


##### `private DEPLOY_RESULT_KEY` → `String`


##### `private INSTALLED_PACKAGES_KEY` → `String`


##### `private AREA_KEY` → `String`


##### `private PENDING_JOBS_KEY` → `String`


##### `private RELATED_OBJECTS_KEY` → `String`


##### `private STACK_TRACE_KEY` → `String`


##### `private TOTAL_ACTIVE_SESSION_KEY` → `String`


##### `private USER_INFO_KEY` → `String`


---
#### Methods
##### `public PostProcessingControlsBuilder auditTrail(Boolean value)`

Controls whether Pharos fetches recent audit trail

##### `public String build()`

Returns a Json version of the settings

##### `public PostProcessingControlsBuilder deployResult(Boolean value)`

Controls whether Pharos fetches recent deployments

##### `public PostProcessingControlsBuilder installedPackages(Boolean value)`

Controls whether Pharos fetches the number of currently installed packages

##### `public PostProcessingControlsBuilder area(Boolean value)`

Controls whether Pharos automatically sets functional area

##### `public PostProcessingControlsBuilder pendingJobs(Boolean value)`

Controls whether Pharos fetches jobs currently in the flox queue

##### `public PostProcessingControlsBuilder relatedObjects(Boolean value)`

Controls whether Pharos fetches related objects names

##### `public PostProcessingControlsBuilder setAll(Boolean value)`

Sets all flags to the value provided

##### `public PostProcessingControlsBuilder stackTrace(Boolean value)`

Controls whether stack trace is enhanced by Pharos
Only applicable to Apex and Integration logs

##### `public PostProcessingControlsBuilder userInfo(Boolean value)`

Controls whether Pharos fetches User name

##### `public PostProcessingControlsBuilder totalActiveSession(Boolean value)`

Controls whether Pharos fetches the number of currently logged in users

---

---
