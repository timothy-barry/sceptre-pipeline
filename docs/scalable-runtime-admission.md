# Native runtime admission

Every scientific task requires the exact locked schema-7 package implementation,
R runtime and required dependencies. Input schema, serialized state, count-file
identity, family scope and execution-plan provenance are checked before use.
Older schemas and the former compact execution lane are rejected.

`prepare_execution()`, `execute_work_unit()` and `collect_execution()` remain
package-owned boundaries. Nextflow schedules units and stages immutable files;
it does not migrate old objects or implement statistical correction.
See [usage](usage.md) and [qualification](validation.md).
