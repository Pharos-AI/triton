---
layout: default
---
# TritonLwc

Class used to log LWC errors

## Methods
### `public static void saveComponentLogs(List<ComponentLog> componentLogs)`

`AURAENABLED`

Create component logs from LWC
Use this method to persist logs generated from LWC components

#### Parameters

|Param|Description|
|---|---|
|`componentLogs`|-- a collection of ComponentLog objects|

---
## Classes
### Component

A wrapper class for passing component info data from LWC

#### Properties

##### `public category` → `String`

`AURAENABLED` 

##### `public name` → `String`

`AURAENABLED` 

##### `public function` → `String`

`AURAENABLED` 

##### `public action` → `String`

`AURAENABLED` 

---

### ComponentLog

A wrapper class for passing log data from LWC

#### Properties

##### `public category` → `String`

`AURAENABLED` 

##### `public type` → `String`

`AURAENABLED` 

##### `public area` → `String`

`AURAENABLED` 

##### `public summary` → `String`

`AURAENABLED` 

##### `public details` → `String`

`AURAENABLED` 

##### `public totalTime` → `Decimal`

`AURAENABLED` 

##### `public userId` → `String`

`AURAENABLED` 

##### `public recordId` → `String`

`AURAENABLED` 

##### `public objectApiName` → `String`

`AURAENABLED` 

##### `public stack` → `String`

`AURAENABLED` 

##### `public error` → `Error`

`AURAENABLED` 

##### `public component` → `Component`

`AURAENABLED` 

##### `public transactionId` → `String`

`AURAENABLED` 

##### `public createdTimestamp` → `Decimal`

`AURAENABLED` 

##### `public level` → `String`

`AURAENABLED` 

##### `public duration` → `Decimal`

`AURAENABLED` 

---

### Error

A wrapper class for passing error log data from LWC

#### Properties

##### `public message` → `String`

`AURAENABLED` 

##### `public stack` → `String`

`AURAENABLED` 

##### `public type` → `String`

`AURAENABLED` 

---

---
