# Pharos Triton

Pharos Triton is an open-source logging framework for Salesforce. It gives Apex, Flows,
and Lightning Web Components one structured way to record what happened, with transaction
and span correlation across those contexts, automatic capture of governor limits and
performance data, full exception and stack-trace detail, and verbosity controlled by
custom metadata rather than code changes.

The entry points are the `Triton` class for Apex, the `TritonFlow` invocable action for
Flows, and the `triton` Lightning web component for LWC and Aura.

Triton is fully functional standalone, and its logs can be explored, visualised, and
monitored through the Pharos.ai observability platform.

## Documentation

Installation, configuration, usage guides, and the full API reference live at
**[triton.pharos.ai](https://triton.pharos.ai)**.

- [Installing Pharos Triton](https://triton.pharos.ai/installing-pharos-triton) — deploy it into an org, configure permissions, and write a first log
- [Best Practices & Standards](https://triton.pharos.ai/triton-best-practices) — taxonomy, log levels, and rollout guidance
- [Help and Support](https://triton.pharos.ai/help-and-support) — support channels

## Contributing

Issues and pull requests are welcome: [github.com/Pharos-AI/triton/issues](https://github.com/Pharos-AI/triton/issues).

## License

Pharos Triton is licensed under the MIT License. See [LICENSE](LICENSE) for details.
