---
layout: default
---
# TritonTypes

Class used to store Enums for the Triton Logger
Log classification.
Use these enums to provide values for Category, Type and Functional Area fields on the log record.
These fields are useful for analytics and should be populated on all records.
Feel free to modify these or add new values as you see fit. It is best to stick to the
general spirit of the definition.

## Enums
### Area

Area.
Represents the functional area. This value will be written to the Functional Area field.
These values should represent the functional area from a business perspective.
E.g. DealRegistration, PartnerCommunity, CustomPipelineUI.


### Category

Category.
Provides general classification. Defaults are Error, Warning, Event, Debug.
This value will be written to the Category field.
These values should reflect what kind of log entry they represent at a high level.


### Level

Log Levels.
Values listed from the least verbose to the most verbose


### Type

Type.
Provides a more specific classification. This value will be written to the Type field.
Defaults are Backend and Frontend.
This value represents a more specific technical classification.
When an Exception is provided, the methods below will use the Exception type.


---
