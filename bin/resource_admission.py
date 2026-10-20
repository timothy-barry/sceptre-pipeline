#!/usr/bin/env python3
"""Scalar admission screen before family construction/count materialization.

A pass admits only a capped pilot, never a full screen. Bounds are not RAM
predictions. Use resolved scientific budgets, maximum group size and full-library
covariate identities; this tool never derives replacement settings.
"""
import argparse
import json

INT_MAX = 2147483647


def admission(spec):
    required = ("cells", "responses", "response_entries", "guide_entries",
                "family_rows", "design_columns", "max_treated_cells",
                "B1", "B2", "B3", "memory_limit_bytes", "disk_limit_bytes",
                "backing_bytes", "workers")
    for name in required:
        value = spec.get(name)
        if type(value) is not int or value < 0:
            raise ValueError(name + " must be an explicit nonnegative integer")
    for name in ("cells", "responses", "design_columns", "memory_limit_bytes", "workers"):
        if not spec[name]:
            raise ValueError(name + " must be positive")
    if spec["max_treated_cells"] > spec["cells"]:
        raise ValueError("max_treated_cells exceeds cells")
    if spec.get("execution_mode") not in ("distributed", "reference"):
        raise ValueError("execution_mode must be distributed or reference")
    if spec.get("backend") not in ("memory", "ondisc"):
        raise ValueError("backend must be memory or ondisc")
    if spec.get("resampling") not in ("crt", "permutations"):
        raise ValueError("resampling must be crt or permutations")
    for name in ("family_identity", "full_library_covariates_identity"):
        if not isinstance(spec.get(name), str) or not spec[name].strip():
            raise ValueError(name + " must identify the requested family/source covariates")
    C, H, K = (spec[k] for k in ("cells", "family_rows", "design_columns"))
    B = sum(spec[k] for k in ("B1", "B2", "B3"))
    reasons = []
    if any(spec[k] > INT_MAX for k in ("cells", "responses", "family_rows")):
        reasons.append("Current native/index dimensions exceed signed integer support")
    if B > INT_MAX:
        reasons.append("Resolved total resampling budget exceeds native signed integer support")
    if spec["backend"] == "memory" and max(spec["response_entries"], spec["guide_entries"]) > INT_MAX:
        reasons.append("One ordinary Matrix store cannot represent this entry count")
    if spec["backend"] == "ondisc" and spec["resampling"] == "crt":
        reasons.append("Public backed CRT setup is unsupported; preserve the declared method and choose an explicitly reviewed implementation path")
    bounds = {
        "design_double_payload": 8 * C * K,
        "pair_two_integer_payload": 8 * H,
        "sparse_value_index_payload": 12 * (spec["response_entries"] + spec["guide_entries"]),
        "permutation_draw_integer_payload": 4 * spec["max_treated_cells"] * B if spec["resampling"] == "permutations" else None,
        # Current sample_crt_indices allocates double[B] and int[B] even
        # when fitted treatment probabilities are zero. Excludes vector headers.
        "crt_working_vector_payload": 12 * B if spec["resampling"] == "crt" else None,
    }
    # These coexistence-free component bounds are necessary, not sufficient.
    # CRT banks depend on fitted probabilities; no fabricated bound is supplied.
    resident = [bounds["design_double_payload"], bounds["pair_two_integer_payload"]]
    if spec["backend"] == "memory":
        resident.append(bounds["sparse_value_index_payload"])
    if bounds["permutation_draw_integer_payload"] is not None:
        resident.append(bounds["permutation_draw_integer_payload"])
    if bounds["crt_working_vector_payload"] is not None:
        resident.append(bounds["crt_working_vector_payload"])
    if max(resident) > spec["memory_limit_bytes"]:
        reasons.append("At least one unavoidable component payload exceeds the per-process memory limit")
    if spec["backing_bytes"] > spec["disk_limit_bytes"]:
        reasons.append("Declared backing bytes exceed the admitted disk allowance")
    return {"schema": 1, "status": "rejected" if reasons else "pilot_only",
            "reasons": reasons, "input": spec, "total_draws": B,
            "component_payload_bytes": bounds,
            "concurrent_design_payload_bytes": spec["workers"] * bounds["design_double_payload"],
            "limits": ["Component payloads exclude fits, copies, names, scores and allocator overhead",
                       "Disk check excludes state/proposal/output copies; reserve and measure those separately",
                       "No full-screen admission: capped pilot and measured phase peaks are required",
                       "CRT draw-bank memory requires fitted-probability measurements"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("spec", help="JSON with explicit dimensions, resolved budgets and resource limits")
    parser.add_argument("output", help="new JSON receipt; existing files are never overwritten")
    args = parser.parse_args()
    with open(args.spec) as handle:
        spec = json.load(handle)
    try:
        receipt = admission(spec)
    except ValueError as error:
        parser.error(str(error))
    with open(args.output, "x") as handle:
        json.dump(receipt, handle, indent=2, allow_nan=False)
        handle.write("\n")
    return 2 if receipt["status"] == "rejected" else 0


if __name__ == "__main__":
    raise SystemExit(main())
