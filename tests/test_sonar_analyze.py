import csv
import tempfile
import unittest
from pathlib import Path

import sonar_analyze


class ScannerConfigurationTests(unittest.TestCase):
    def test_standard_command_uses_existing_nested_java_binaries(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            project_dir = Path(temp_dir)
            binaries = project_dir / "backend" / "target" / "classes"
            binaries.mkdir(parents=True)

            command = sonar_analyze.build_standard_scanner_command(
                scanner="/scanner/sonar-scanner",
                project_dir=str(project_dir),
                project_key="project",
                sonar_host="http://localhost:9000",
            )

            self.assertIn(f"-Dsonar.java.binaries={binaries}", command)

    def test_standard_command_omits_java_binaries_when_no_output_exists(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            command = sonar_analyze.build_standard_scanner_command(
                scanner="/scanner/sonar-scanner",
                project_dir=temp_dir,
                project_key="project",
                sonar_host="http://localhost:9000",
            )

            self.assertFalse(
                any(argument.startswith("-Dsonar.java.binaries=") for argument in command)
            )


class AnalysisResultTests(unittest.TestCase):
    def test_extract_ce_task_id_from_scanner_output(self):
        output = (
            "More about the report processing at "
            "http://localhost:9000/api/ce/task?id=task-123"
        )

        self.assertEqual(sonar_analyze.extract_ce_task_id(output), "task-123")

    def test_csv_contains_zero_for_requested_metric_not_returned_by_api(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            sonar_analyze.save_to_csv(
                temp_dir,
                "project",
                "Deiv",
                ["bugs", "lines"],
                {"component": {"measures": [{"metric": "bugs", "value": "2"}]}},
            )

            csv_files = list((Path(temp_dir) / "sonar_analyzer_results").glob("*.csv"))
            self.assertEqual(len(csv_files), 1)
            with csv_files[0].open(newline="") as handle:
                rows = list(csv.DictReader(handle))

            self.assertEqual([row["Metric"] for row in rows], ["bugs", "lines"])
            self.assertEqual(rows[1]["Value"], "0")


if __name__ == "__main__":
    unittest.main()
