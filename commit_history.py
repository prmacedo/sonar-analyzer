# Utilities for recording git commit history snapshots.
import json
import os
import subprocess
from datetime import datetime
from typing import Dict, Optional

_LOG_FORMAT = "%H\x1f%an\x1f%ae\x1f%ad\x1f%s"

def _history_dir(output_dir: str) -> str:
    results_dir = os.path.join(output_dir, "sonar_analyzer_results")
    commit_dir = os.path.join(results_dir, "commit_history")
    os.makedirs(commit_dir, exist_ok=True)
    return commit_dir

def _history_path(output_dir: str, project_key: str) -> str:
    safe_key = project_key.replace(os.sep, "_")
    return os.path.join(_history_dir(output_dir), f"{safe_key}.jsonl")

def _is_git_repo(project_dir: str) -> Optional[bool]:
    try:
        result = subprocess.run(
            ["git", "-C", project_dir, "rev-parse", "--is-inside-work-tree"],
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        return None
    if result.returncode != 0:
        return False
    return result.stdout.strip().lower() == "true"

def _last_recorded_hash(history_file: str) -> Optional[str]:
    try:
        with open(history_file, "r", encoding="utf-8") as handle:
            last_line = None
            for line in handle:
                line = line.strip()
                if line:
                    last_line = line
    except FileNotFoundError:
        return None
    except OSError:
        return None
    if not last_line:
        return None
    try:
        payload = json.loads(last_line)
    except json.JSONDecodeError:
        return None
    return payload.get("commit")

def _is_ancestor(project_dir: str, commit_hash: str) -> bool:
    try:
        result = subprocess.run(
            ["git", "-C", project_dir, "merge-base", "--is-ancestor", commit_hash, "HEAD"],
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        return False
    return result.returncode == 0

def _collect_commits(project_dir: str, since: Optional[str]) -> Optional[list]:
    cmd = ["git", "-C", project_dir, "log", "--date=iso-strict", f"--pretty=format:{_LOG_FORMAT}", "--reverse"]
    if since:
        cmd.append(f"{since}..HEAD")
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    except FileNotFoundError:
        return None
    if result.returncode != 0:
        return None
    commits = []
    for raw in result.stdout.splitlines():
        raw = raw.strip()
        if not raw:
            continue
        parts = raw.split("\x1f")
        if len(parts) != 5:
            continue
        commit, author_name, author_email, author_date, subject = parts
        commits.append(
            {
                "commit": commit,
                "author_name": author_name,
                "author_email": author_email,
                "author_date": author_date,
                "subject": subject,
            }
        )
    return commits

def _write_records(path: str, commits: list, project_key: str, project_dir: str, mode: str) -> int:
    if not commits and mode == "w":
        open(path, "w", encoding="utf-8").close()
        return 0
    if not commits:
        return 0
    recorded_at = datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
    with open(path, mode, encoding="utf-8") as handle:
        for entry in commits:
            payload: Dict[str, str] = {
                **entry,
                "project_key": project_key,
                "project_dir": project_dir,
                "recorded_at": recorded_at,
            }
            handle.write(json.dumps(payload, ensure_ascii=True) + "\n")
    return len(commits)

def create_baseline_history(project_dir: str, project_key: str, output_dir: str) -> Dict[str, Optional[str]]:
    repo_status = _is_git_repo(project_dir)
    if repo_status is None:
        return {"status": "skipped", "reason": "git_not_available", "path": None, "commit_count": 0}
    if not repo_status:
        return {"status": "skipped", "reason": "not_a_git_repository", "path": None, "commit_count": 0}

    history_file = _history_path(output_dir, project_key)
    commits = _collect_commits(project_dir, since=None)
    if commits is None:
        return {"status": "skipped", "reason": "git_log_failed", "path": history_file, "commit_count": 0}

    count = _write_records(history_file, commits, project_key, project_dir, mode="w")
    return {"status": "created", "reason": None, "path": history_file, "commit_count": count}

def append_commit_history(project_dir: str, project_key: str, output_dir: str) -> Dict[str, Optional[str]]:
    repo_status = _is_git_repo(project_dir)
    if repo_status is None:
        return {"status": "skipped", "reason": "git_not_available", "path": None, "commit_count": 0}
    if not repo_status:
        return {"status": "skipped", "reason": "not_a_git_repository", "path": None, "commit_count": 0}

    history_file = _history_path(output_dir, project_key)
    last_hash = _last_recorded_hash(history_file)
    if not last_hash or not _is_ancestor(project_dir, last_hash):
        return create_baseline_history(project_dir, project_key, output_dir)

    commits = _collect_commits(project_dir, since=last_hash)
    if commits is None:
        return {"status": "skipped", "reason": "git_log_failed", "path": history_file, "commit_count": 0}
    count = _write_records(history_file, commits, project_key, project_dir, mode="a")
    if count == 0:
        return {"status": "unchanged", "reason": None, "path": history_file, "commit_count": 0}
    return {"status": "appended", "reason": None, "path": history_file, "commit_count": count}

