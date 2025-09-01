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
    Load variables from .env file.
    """
    env_path = os.path.join(os.path.dirname(__file__), ".env")
    if os.path.exists(env_path):
        load_dotenv(env_path)
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

def run_analysis(project_dir, project_key, sonar_host, sonar_token):
    """
    Run sonar-scanner on the given project using the bundled scanner.
    """
    scanner = get_scanner_path()

    result = subprocess.run(
        [
            scanner,
            f"-Dsonar.projectKey={project_key}",
            f"-Dsonar.sources={project_dir}",
            f"-Dsonar.host.url={sonar_host}",
            f"-Dsonar.login={sonar_token}",
        ],
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        print("Sonar analysis failed!")
        print("STDOUT:\n", result.stdout)
        print("STDERR:\n", result.stderr)
        sys.exit(1)
    else:
        print("Sonar analysis completed successfully.")
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
    os.makedirs(output_dir, exist_ok=True)
    filename = os.path.join(output_dir, f"{project_key}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv")

    # Build dictionary of returned measures
    measures = {m["metric"]: m["value"] for m in data.get("component", {}).get("measures", [])}

    with open(filename, "w", newline="") as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(["Username", "Project", "Timestamp", "Metric", "Value"])
        for metric in metrics:
            writer.writerow([username, project_key, datetime.now().isoformat(), metric, measures.get(metric, "0")])

    print(f"Results saved to {filename}")

def main():
    load_env()

    parser = argparse.ArgumentParser(description="Run SonarQube analysis and export results to CSV.")
    parser.add_argument("--sonar-host", default=os.getenv("SONAR_HOST", "http://localhost:9000"), help="SonarQube server URL")
    parser.add_argument("--sonar-token", default=os.getenv("SONAR_TOKEN"), help="SonarQube authentication token")

    args = parser.parse_args()

    project_dir = os.getenv("PROJECT_DIR")
    project_key = os.getenv("SONAR_PROJECT_KEY")
    username = os.getenv("USERNAME", "unknown")
    output_dir = os.getenv("OUTPUT_DIR", "results")

    if not args.sonar_token:
        print("Error: You must provide --sonar-token or set SONAR_TOKEN in .env")
        sys.exit(1)

    metrics = ["bugs", "code_smells", "vulnerabilities", "coverage", "duplicated_lines_density"]

    run_analysis(project_dir, project_key, args.sonar_host, args.sonar_token)
    data = fetch_measures(args.sonar_host, args.sonar_token, project_key, metrics)
    save_to_csv(output_dir, project_key, username, metrics, data)

if __name__ == "__main__":
    main()