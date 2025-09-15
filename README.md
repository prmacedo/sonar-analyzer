# Quick Start (Linux and Windows)

Follow these four steps to run and schedule the project.

1. Start SonarQube with Docker Compose

- Linux/WSL/Windows PowerShell or CMD:

```
docker compose up -d
```

2. Create a SonarQube token, then run setup

- Open `http://localhost:9000` and sign in with default credentials `admin / admin` (first run).
- Go to `http://localhost:9000/account/security` and create a Global Analysis Token with no expiration.
- Linux/WSL: `bash ./setup.sh` (you will be asked for the token)
- Windows: `setup.bat` (you will be asked for the token)

3. Run a scan (single or multiple projects)

- Single project:
  - Linux/WSL: `bash ./run.sh`
  - Windows: `run.bat`
- Multiple projects (reads `configs/*.env`):
  - Linux/WSL: `bash ./run-multi.sh`
  - Windows: `run-multi.bat`

4. Schedule weekday runs

- Linux/WSL: `bash ./run-weekdays.sh --install --time HH:MM [--single|--multi]`
- Windows: `run-weekdays.bat --install --time HH:MM [--single|--multi]`

Notes

- Ensure Docker Desktop (Windows) or Docker Engine (Linux) is running.
- If SonarQube fails to start, set `vm.max_map_count` (Linux): `sudo sysctl -w vm.max_map_count=262144`.
- Use OS-appropriate paths in `.env`/`configs/*.env` (Windows: `D:\...`, Linux/WSL: `/path/...`).

## Optional Environment Variables

- SONAR_SOURCES: Comma-separated paths to analyze; limit scope (e.g., `src,app`).
- SONAR_EXCLUSIONS: Comma-separated glob patterns to exclude; defaults cover `**/node_modules/**,**/dist/**,**/build/**,**/.venv/**,**/__pycache__/**,**/.git/**,**/target/**`.
