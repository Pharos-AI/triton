---
layout: default
---
# TritonHelper

helper class for the Triton Logger project

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


##### `private OBJECT_INFO_KEY` → `String`


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

##### `public PostProcessingControlsBuilder objectInfo(Boolean value)`

Controls whether Pharos fetches User name

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
