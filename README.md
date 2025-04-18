# Pharos Triton

Pharos Triton is a powerful, open-source logging framework for Salesforce, designed to integrate seamlessly with the Pharos.ai observability platform. It provides comprehensive logging capabilities across all Salesforce contexts including Apex, Flows, Lightning Web Components, and integrations.

## What is Pharos Triton?

Pharos Triton is the foundation of the Pharos observability ecosystem, offering sophisticated logging infrastructure with features not available in standard Salesforce debugging tools:

- **Multi-context Logging**: Unified logging across Apex, Flows, and Lightning Web Components
- **Transaction Tracking**: Built-in transaction ID management for tracing operations across multiple contexts
- **Buffered Logging**: Optimized DML operations through log buffering with automatic flushing
- **Structured Data**: Categorized logs with standardized severity levels, functional areas, and types
- **Performance Metrics**: Automatic capture of execution times and resource consumption
- **Runtime Context**: Comprehensive environment information for both server and client contexts
- **Error Handling**: Detailed exception capturing with automatic stack trace analysis
- **Configurable Filtering**: Dynamic log level configuration through Custom Metadata

As part of the Pharos.ai platform, Triton logs can be analyzed, visualized, and monitored through the Pharos observability suite, while maintaining full functionality as a standalone framework.

## Key Use Cases

Pharos Triton is ideal for several use cases:

- **Debugging**: Capture detailed, contextualized logs across all Salesforce technologies in a unified format
- **Monitoring**: Track performance metrics and resource usage patterns across your org
- **Tracing**: Follow complex transactions that span multiple contexts, users, and sessions
- **Auditing**: Maintain comprehensive audit trails for compliance and security requirements
- **User Experience Analysis**: Gather detailed frontend performance and interaction data
- **Cross-Component Visibility**: Understand how data flows between declarative and programmatic elements

## Getting Started

To get started with Pharos Triton:

1. Visit [Pharos Triton](https://triton.pharos.ai) for detailed documentation and setup guides
2. Integrate Triton into your Salesforce org by following the installation instructions
3. Assign appropriate permission sets to your users (see Access Control section below)
4. Start capturing logs from your Salesforce automation using the appropriate interface:
   - `Triton` for Apex code
   - `TritonFlow` invocable actions for Flows and Process Builder
   - `triton.js` Lightning web component for LWC and Aura

## Access Control

Triton uses a role-based access control system with the following permission sets:

| Permission Set | Description | Use Case |
|---------------|-------------|----------|
| `Triton_End_User` | Basic access to use the logging framework | For developers and admins who need to create logs |
| `Triton_Read` | Read-only access to logs and metadata | For analysts and support staff who need to view logs |
| `Triton_Write` | Full access including create/edit permissions | For administrators who need to manage the logging system |

Assign these permission sets based on your users' needs and security requirements.

## Support

For support and further inquiries:
- Visit the [Pharos Triton Support Page](https://triton.pharos.ai/support) for details
- Contact the Pharos AI team via the support channels provided on the website for personalized assistance
- Submit issues via [GitHub](https://github.com/Pharos-AI/triton/issues) for open source contributions

## License

Pharos Triton is licensed under MIT License. 
See the LICENSE file for more details.
