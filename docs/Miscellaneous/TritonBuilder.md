---
layout: default
---
# virtual TritonBuilder

x
Builder class for creating and configuring Pharos log records.
Provides a fluent interface to set various attributes like category, type, area,
related objects, and other metadata for logging purposes. This class wraps the core
pharos.LogBuilder to provide a more user-friendly API for log creation.

## Constructors
### `public TritonBuilder()`
---
## Fields

### `private builder` → `pharos.LogBuilder`


### `public APEX_NAME` → `String`


key field names for setting attributes on log records

### `public CREATED_TIMESTAMP` → `String`


### `public DURATION` → `String`


### `public INTERVIEW_GUID` → `String`


### `public LOG_LEVEL` → `String`


### `public RELATED_ID` → `String`


### `public RELATED_OBJECTS` → `String`


### `public STACKTRACE_PARSE_RESULT` → `String`


### `public USER_ID` → `String`


### `public FLOW_API_NAME` → `String`


### `public DO_NOT_CREATE_ISSUE` → `String`


### `public REQUEST_ID` → `String`


---
## Methods
### `public TritonBuilder category(TritonTypes.Category c)`

Set log category from Category enum.

#### Parameters

|Param|Description|
|---|---|
|`c`|-- TritonTypes.Category enum value|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder type(TritonTypes.Type t)`

Set log category from Category enum.

#### Parameters

|Param|Description|
|---|---|
|`t`|-- TritonTypes.Type enum value|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder type(String t)`

Set log type to a String value. To be used when creating a log from Exception

#### Parameters

|Param|Description|
|---|---|
|`t`|-- String value|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder area(TritonTypes.Area a)`

Set log functional are from Area enum.

#### Parameters

|Param|Description|
|---|---|
|`a`|-- TritonTypes.Area value|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder area(String a)`

Set log functional area to a String value. To be used from flows

#### Parameters

|Param|Description|
|---|---|
|`a`|-- String value|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder level(TritonTypes.Level l)`

Set log level from Level enum.

#### Parameters

|Param|Description|
|---|---|
|`l`|-- TritonTypes.Level enum value|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder operation(String operation)`

Set operation from a String value

#### Parameters

|Param|Description|
|---|---|
|`operation`|-- operation String value|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder summary(String value)`

Set log summary from a String value

#### Parameters

|Param|Description|
|---|---|
|`summary`|-- summary String value|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder details(String value)`

Set log details from a String value

#### Parameters

|Param|Description|
|---|---|
|`details`|-- details String value|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder stackTrace(String stack)`

Set stack trace from a String value

#### Parameters

|Param|Description|
|---|---|
|`stack`|-- stack trace String value|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder postProcessing(TritonHelper.PostProcessingControlsBuilder postProcessingBuilder)`

Set post processing metadata from a PostProcessingControlsBuilder instance

#### Parameters

|Param|Description|
|---|---|
|`postProcessingBuilder`|-- instance of TritonHelper.PostProcessingControlsBuilder|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder transactionId(String transactionId)`

Set transaction Id from a String

#### Parameters

|Param|Description|
|---|---|
|`transactionId`|-- desired transaction Id String value|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder createIssue()`

Set transaction Id from a String

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder userId(Id userId)`

Set user Id for the log

#### Parameters

|Param|Description|
|---|---|
|`userId`|-- Id of the user to associate with the log|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder relatedObject(Id objectId)`

Add a single related object Id to the log

#### Parameters

|Param|Description|
|---|---|
|`objectId`|-- Id of the object to relate to the log|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder relatedObject(String objectId)`

Add a single related object Id string to the log

#### Parameters

|Param|Description|
|---|---|
|`objectId`|-- String representation of the Id to relate to the log|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder relatedObjects(List<Id> relatedObjectIds)`

Add multiple related object Ids to the log

#### Parameters

|Param|Description|
|---|---|
|`relatedObjectIds`|-- List of Ids to relate to the log|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder relatedObjects(Set<String> relatedObjectIds)`

Add multiple related object Id strings to the log

#### Parameters

|Param|Description|
|---|---|
|`relatedObjectIds`|-- Set of Id strings to relate to the log|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder relatedObjects(Set<Id> relatedObjectIds)`

Add multiple related object Ids to the log

#### Parameters

|Param|Description|
|---|---|
|`relatedObjectIds`|-- Set of Ids to relate to the log|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder createdTimestamp(Double timestamp)`

Set created timestamp for the log

#### Parameters

|Param|Description|
|---|---|
|`timestamp`|-- Double value representing the creation timestamp|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder duration(Decimal duration)`

Set duration for the log

#### Parameters

|Param|Description|
|---|---|
|`duration`|-- Decimal value representing the duration|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder integrationPayload(HttpRequest request, HttpResponse response)`

Set integration payload from HTTP request/response

#### Parameters

|Param|Description|
|---|---|
|`request`|-- HttpRequest instance|
|`response`|-- HttpResponse instance|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder integrationPayload(RestRequest request, RestResponse response)`

Set integration payload from REST request/response

#### Parameters

|Param|Description|
|---|---|
|`request`|-- RestRequest instance|
|`response`|-- RestResponse instance|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder interviewGuid(String guid)`

Set interview GUID for the log

#### Parameters

|Param|Description|
|---|---|
|`guid`|-- String value of the interview GUID|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder flowApiName(String apiName)`

Set flow API name for the log

#### Parameters

|Param|Description|
|---|---|
|`apiName`|-- String value of the flow API name|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public TritonBuilder attribute(String name, Object value)`

Set a custom attribute on the log

#### Parameters

|Param|Description|
|---|---|
|`name`|-- String name of the attribute|
|`value`|-- Object value of the attribute|

#### Returns

|Type|Description|
|---|---|
|`TritonBuilder`|this builder instance|

### `public pharos__Log__c build()`

Build and return the log record

#### Returns

|Type|Description|
|---|---|
|`pharos__Log__c`|pharos__Log__c instance|

---
