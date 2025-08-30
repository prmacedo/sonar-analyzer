#!/usr/bin/env python3
import argparse
import os
import subprocess
import requests
import csv
import sys
from datetime import datetime

def run_analysis(project_dir, project_key, sonar_host, sonar_token):
    """
    Run sonar-scanner on the given project.
    """
    result = subprocess.run(
        [
            "sonar-scanner",
            f"-Dsonar.projectKey={project_key}",
            f"-Dsonar.sources={project_dir}",
            f"-Dsonar.host.url={sonar_host}",
            f"-Dsonar.login={sonar_token}",
        ],
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        print("Sonar analysis failed:")
        print(result.stderr)
        sys.exit(1)

def fetch_measures(sonar_host, sonar_token, project_key, metrics):
    """
    Fetch analysis results from SonarQube API.
    """
    url = f"{sonar_host}/api/measures/component"
    params = {"component": project_key, "metricKeys": ",".join(metrics)}
    response = requests.get(url, params=params, auth=(sonar_token, ""))
    response.raise_for_status()
    return response.json()

def save_to_csv(output_dir, project_key, metrics, data):
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
        writer.writerow(["Metric", "Value"])
        for metric in metrics:
            writer.writerow([metric, measures.get(metric, "0")])

    print(f"Results saved to {filename}")

def main():
    parser = argparse.ArgumentParser(description="Run SonarQube analysis and export results to CSV.")
    parser.add_argument("project_dir", help="Path to the project directory")
    parser.add_argument("project_key", help="Unique SonarQube project key")
    parser.add_argument("username", help="Username (for reference only, token used for auth)")
    parser.add_argument("output_dir", help="Directory to save CSV results")
    parser.add_argument("--sonar-host", default="http://localhost:9000", help="SonarQube server URL")
    parser.add_argument("--sonar-token", help="SonarQube authentication token")

    args = parser.parse_args()

    if not args.sonar_token:
        print("Error: You must provide --sonar-token")
        sys.exit(1)

    # Fixed set of metrics you always want to collect
    metrics = ["bugs", "code_smells", "vulnerabilities", "coverage", "duplicated_lines_density"]

    run_analysis(args.project_dir, args.project_key, args.sonar_host, args.sonar_token)
    data = fetch_measures(args.sonar_host, args.sonar_token, args.project_key, metrics)
    save_to_csv(args.output_dir, args.project_key, metrics, data)

if __name__ == "__main__":
    main()
