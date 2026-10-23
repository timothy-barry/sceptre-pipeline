# Native schema-7 scientific reports

`bin/export_state.R` exports the completed public SCEPTRE results and invokes
`bin/scientific_report.R` to create the bounded HTML report, full CSV downloads,
native RDS object, and standalone base-R rerender script. It uses the selected
schema-7 package; the former compact result-view/report adapters are removed.

Run `Rscript report/check.R NEW_DIRECTORY` in the same pinned runtime used for
science. These checks cover completed results, omitted stages, report isolation,
input preservation and standalone rerendering. See [report usage](../docs/report.md)
and [validation](../docs/validation.md) for tested scope.
