#!/usr/bin/env python3
import argparse
import os
import subprocess
import requests
import csv
import sys
from datetime import datetime
from dotenv import load_dotenv

def load_env():
    """
    Load variables from a .env file.
    - If DOTENV is set in the environment, prefer that file.
    - Otherwise, fall back to <repo>/.env next to this script.
    Does not override variables already present in the environment.
    """
    dotenv_from_env = os.getenv("DOTENV")
    if dotenv_from_env:
        env_path = dotenv_from_env
        if not os.path.isabs(env_path):
            env_path = os.path.join(os.path.dirname(__file__), env_path)
        if os.path.exists(env_path):
            load_dotenv(env_path, override=False)
            return
        else:
            print(f"Warning: DOTENV set but file not found: {env_path}")

    # Fallback to root .env near this file
    fallback = os.path.join(os.path.dirname(__file__), ".env")
    if os.path.exists(fallback):
        load_dotenv(fallback, override=False)
    else:
        print("Warning: .env file not found, falling back to CLI args/env vars.")

def get_scanner_path():
    """
    Get SonarScanner path from .env or detect based on OS/arch.
    Ensure the binary is executable.
    """
    scanner_path = os.getenv("SONAR_SCANNER_PATH")
    if scanner_path and os.path.exists(scanner_path):
        # Fix permissions automatically (Linux/macOS only)
        if os.name == "posix":
            st = os.stat(scanner_path)
            os.chmod(scanner_path, st.st_mode | 0o111)
        return scanner_path

    print("Error: SONAR_SCANNER_PATH not set or invalid in .env")
    sys.exit(1)

def is_flutter_project(project_dir: str) -> bool:
    """Check if project is a Flutter project."""
    pubspec = os.path.join(project_dir, "pubspec.yaml")
    if os.path.exists(pubspec):
        try:
            with open(pubspec, "r", encoding="utf-8") as f:
                for line in f:
                    if line.strip().startswith("flutter:"):
                        return True
        except (IOError, UnicodeDecodeError) as e:
            print(f"Error reading pubspec.yaml: {e}")
    return False

def run_analysis(project_dir, project_key, sonar_host, sonar_token):
    """
    Run sonar-scanner on the given project using the bundled scanner.
    """
    scanner = get_scanner_path()

    if is_flutter_project(project_dir):
        print(f"✅ Detected Flutter project at {project_dir}")

        cmd = [
            scanner,
            f"-Dsonar.projectKey={project_key}",
            f"-Dsonar.projectName={project_key}",
            "-Dsonar.projectVersion=1.0",
            "-Dsonar.sourceEncoding=UTF-8",
            f"-Dsonar.projectBaseDir={project_dir}",
            "-Dsonar.sources=lib,pubspec.yaml",
            "-Dsonar.tests=test",
            f"-Dsonar.host.url={sonar_host}",
            f"-Dsonar.token={sonar_token}",
        ]
    else:
        print(f"ℹ️ Standard project analysis for {project_dir}")
        cmd = [
            scanner,
            f"-Dsonar.projectKey={project_key}",
            f"-Dsonar.projectBaseDir={project_dir}",
            f"-Dsonar.sources={project_dir}",
            f"-Dsonar.host.url={sonar_host}",
            f"-Dsonar.token={sonar_token}",
        ]

    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        print("❌ Sonar analysis failed!")
        print("STDOUT:\n", result.stdout)
        print("STDERR:\n", result.stderr)
        sys.exit(1)
    else:
        print("✅ Sonar analysis completed successfully.")
        print("STDOUT:\n", result.stdout)

def fetch_measures(sonar_host, sonar_token, project_key, metrics):
    """
    Fetch analysis results from SonarQube API.
    """
    url = f"{sonar_host}/api/measures/component"
    params = {"component": project_key, "metricKeys": ",".join(metrics)}
    response = requests.get(url, params=params, auth=(sonar_token, ""))
    response.raise_for_status()
    return response.json()

def save_to_csv(output_dir, project_key, username, metrics, data):
    """
    Save the SonarQube measures to a CSV file.
    Always include all metrics, default to 0 if missing.
    """
    results_dir = os.path.join(output_dir, "sonar_analyzer_results")
    os.makedirs(results_dir, exist_ok=True)
    filename = os.path.join(results_dir, f"{project_key}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv")

    # Build dictionary of returned measures
    measures = data.get("component", {}).get("measures", [])
    
    with open(filename, "w", newline="") as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(["Username", "Project", "Timestamp", "Metric", "Value"])
        now = datetime.now().isoformat()

        for m in measures:
            metric = m.get("metric")
            value = m.get("value")
            writer.writerow([username, project_key, now, metric, value or "0"])

    print(f"Results saved to {filename}")

def main():
    load_env()

    parser = argparse.ArgumentParser(description="Run SonarQube analysis and export results to CSV.")
    parser.add_argument("--sonar-host", default=os.getenv("SONAR_HOST", "http://localhost:9000"), help="SonarQube server URL")
    parser.add_argument("--sonar-token", default=os.getenv("SONAR_TOKEN"), help="SonarQube authentication token")

    args = parser.parse_args()

    project_dir = os.getenv("PROJECT_DIR")
    project_key = os.getenv("SONAR_PROJECT_KEY")
    username = os.getenv("USERNAME")
    output_dir = os.getenv("OUTPUT_DIR")

    if not args.sonar_token:
        print("Error: You must provide --sonar-token or set SONAR_TOKEN in .env")
        sys.exit(1)

    missing = []
    if not project_dir:
        missing.append("PROJECT_DIR")
    if not project_key:
        missing.append("SONAR_PROJECT_KEY")
    if not username:
        missing.append("USERNAME")
    if not output_dir:
        missing.append("OUTPUT_DIR")
    if missing:
        print(f"Error: Missing required environment variables: {', '.join(missing)}")
        sys.exit(1)

    metrics = ["accepted_issues", "new_technical_debt", "new_software_quality_maintainability_remediation_effort", "analysis_from_sonarqube_9_4", "high_impact_accepted_issues", "blocker_violations", "software_quality_blocker_issues", "bugs", "classes", "code_smells", "cognitive_complexity", "comment_lines", "comment_lines_data", "comment_lines_density", "branch_coverage", "new_branch_coverage", "conditions_to_cover", "new_conditions_to_cover", "confirmed_issues", "coverage", "new_coverage", "critical_violations", "complexity", "last_commit_date", "development_cost", "new_development_cost", "duplicated_blocks", "new_duplicated_blocks", "duplicated_files", "duplicated_lines", "duplicated_lines_density", "new_duplicated_lines_density", "new_duplicated_lines", "duplications_data", "effort_to_reach_software_quality_maintainability_rating_a", "effort_to_reach_maintainability_rating_a", "executable_lines_data", "false_positive_issues", "files", "functions", "generated_lines", "generated_ncloc", "software_quality_high_issues", "info_violations", "software_quality_info_issues", "violations", "prioritized_rule_issues", "line_coverage", "new_line_coverage", "lines", "ncloc", "ncloc_language_distribution", "lines_to_cover", "new_lines_to_cover", "software_quality_low_issues", "maintainability_issues", "software_quality_maintainability_issues", "sqale_rating", "software_quality_maintainability_rating", "new_maintainability_rating", "new_software_quality_maintainability_rating", "major_violations", "software_quality_medium_issues", "minor_violations", "ncloc_data", "new_accepted_issues", "new_blocker_violations", "new_software_quality_blocker_issues", "new_bugs", "new_code_smells", "new_critical_violations", "new_software_quality_high_issues", "new_info_violations", "new_software_quality_info_issues", "new_violations", "new_lines", "new_software_quality_low_issues", "new_software_quality_maintainability_issues", "new_maintainability_issues", "new_major_violations", "new_software_quality_medium_issues", "new_minor_violations", "new_reliability_issues", "new_software_quality_reliability_issues", "new_security_hotspots", "new_software_quality_security_issues", "new_security_issues", "new_vulnerabilities", "unanalyzed_c", "unanalyzed_cpp", "open_issues", "quality_profiles", "projects", "public_api", "public_documented_api_density", "public_undocumented_api", "pull_request_fixed_issues", "quality_gate_details", "alert_status", "reliability_issues", "software_quality_reliability_issues", "software_quality_reliability_rating", "reliability_rating", "new_software_quality_reliability_rating", "new_reliability_rating", "reliability_remediation_effort", "software_quality_reliability_remediation_effort", "new_software_quality_reliability_remediation_effort", "new_reliability_remediation_effort", "reopened_issues", "security_hotspots", "security_hotspots_reviewed", "new_security_hotspots_reviewed", "software_quality_security_issues", "security_issues", "software_quality_security_rating", "security_rating", "new_software_quality_security_rating", "new_security_rating", "software_quality_security_remediation_effort", "security_remediation_effort", "new_security_remediation_effort", "new_software_quality_security_remediation_effort", "security_review_rating", "new_security_review_rating", "security_hotspots_reviewed_status", "new_security_hotspots_reviewed_status", "security_hotspots_to_review_status", "new_security_hotspots_to_review_status", "skipped_tests", "statements", "software_quality_maintainability_remediation_effort", "sqale_index", "software_quality_maintainability_debt_ratio", "sqale_debt_ratio", "new_sqale_debt_ratio", "new_software_quality_maintainability_debt_ratio", "uncovered_conditions", "new_uncovered_conditions", "uncovered_lines", "new_uncovered_lines", "test_execution_time", "test_errors", "test_failures", "tests", "test_success_density", "vulnerabilities"]

    run_analysis(project_dir, project_key, args.sonar_host, args.sonar_token)
    data = fetch_measures(args.sonar_host, args.sonar_token, project_key, metrics)
    save_to_csv(output_dir, project_key, username, metrics, data)

if __name__ == "__main__":
    main()
