import importlib.util
import pathlib
import unittest

path = pathlib.Path(__file__).resolve().parents[1] / "bin/resource_admission.py"
spec = importlib.util.spec_from_file_location("resource_admission", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class AdmissionTests(unittest.TestCase):
    def fixture(self):
        return dict(cells=10932, responses=93, response_entries=100000,
                    guide_entries=10000, family_rows=279, design_columns=5,
                    max_treated_cells=5000, B1=499, B2=0, B3=27900,
                    memory_limit_bytes=3*1024**3, disk_limit_bytes=1024**3,
                    backing_bytes=3000000, workers=1, backend="memory", resampling="crt", execution_mode="distributed",
                    family_identity="dc-tap-279-requested", full_library_covariates_identity="original-library")

    def test_pilot_is_not_full_admission(self):
        result = module.admission(self.fixture())
        self.assertEqual(result["status"], "pilot_only")
        self.assertIsNone(result["component_payload_bytes"]["permutation_draw_integer_payload"])

    def test_native_hdf5_crt_is_admitted_for_pilot(self):
        x = self.fixture(); x["backend"] = "native-hdf5"
        self.assertEqual(module.admission(x)["status"], "pilot_only")
        self.assertEqual(x["resampling"], "crt")
        x["execution_mode"] = "reference"
        self.assertEqual(module.admission(x)["status"], "pilot_only")

    def test_native_budget_and_sparse_limits(self):
        for key, value in (("B3", 2147483647), ("response_entries", 2147483648)):
            x = self.fixture(); x[key] = value
            self.assertEqual(module.admission(x)["status"], "rejected")

    def test_memory_disk_and_bad_scalars(self):
        for key, value in (("memory_limit_bytes", 1), ("disk_limit_bytes", 1)):
            x = self.fixture(); x[key] = value
            self.assertEqual(module.admission(x)["status"], "rejected")
        for key, value in (("cells", True), ("B1", -1), ("B2", 0.1), ("family_identity", "")):
            x = self.fixture(); x[key] = value
            with self.assertRaises(ValueError): module.admission(x)

    def test_crt_has_working_arrays_even_without_fitted_probabilities(self):
        x = self.fixture(); x.update(B3=100000000, memory_limit_bytes=100*1024**2)
        result = module.admission(x)
        self.assertEqual(result["status"], "rejected")
        self.assertEqual(result["component_payload_bytes"]["crt_working_vector_payload"], 12*100000499)

    def test_permutation_bank_cannot_be_hidden_by_worker_count(self):
        x = self.fixture(); x.update(resampling="permutations", B3=1000000)
        self.assertEqual(module.admission(x)["status"], "rejected")


if __name__ == "__main__":
    unittest.main()
