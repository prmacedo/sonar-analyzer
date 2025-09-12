# Execuntando o projeto

```bash
# Fazer setup para rodar sonarqube no docker
./setup-sonarqube.sh

# Executar Sonarqube
docker compose up -d
```

Acessar o sonarqube, ir para `http://localhost:9000/account/security` e criar um token do tipo "Global Analysis Token" sem prazo de expiração, informar o token gerado ao executar o script `./setup.sh`.

```bash
# Fazer setup do projeto
./setup.sh

# Rodar análise do projeto
./run.sh
```

# Requisitos

- Python
- Docker -> Rodando o SonarQube
- Sonar Scanner CLI (Instalado automaticamente pelo script setup.sh)

# Understandin measures and metrics

[Documentation](https://docs.sonarsource.com/sonarqube-community-build/user-guide/code-metrics/metrics-definition/)

# metrics.json

Arquivo com o retorno da endpoint `/api/metrics/search?ps=200` do sonarqube

# Plugin Flutter para SonarQube

[sonar-flutter-0.5.2](https://github.com/insideapp-oss/sonar-flutter/releases/download/0.5.2/sonar-flutter-plugin-0.5.2.jar)

## Running on Windows (native)

- Prerequisites
  - Install Python 3.x for Windows (enable “Add Python to PATH”).
  - Install Docker Desktop and keep it running.
- Start SonarQube
  - If SonarQube fails to start, run once: `docker run --rm --privileged --pid=host alpine:3.18 sysctl -w vm.max_map_count=262144`
  - `docker compose up -d` and wait for `http://localhost:9000` to be UP.
  - Create a Global Analysis Token at `http://localhost:9000/account/security`.
- Setup and run (use Windows paths like `D:\Projetos\...`)
  - `setup.bat` (answers: project path(s), your name, output dir, token)
  - Single project: `run.bat`
  - Multiple projects: `run-multi.bat` (runs each `configs\*.env`)
- Weekday scheduling
  - `run-weekdays.bat --install --time HH:MM [--single|--multi]` (creates a Task Scheduler job Mon–Fri)
  - To run when logged off, edit the task in Task Scheduler and set credentials.
- Notes
  - `.env` and `configs\*.env` must use Windows-style paths (e.g., `D:\...`).
  - If you previously created a WSL/Linux `.venv`, delete it before running on Windows.

## Running on Linux or WSL

- Prerequisites
  - Python 3 with venv/pip: `sudo apt update && sudo apt install -y python3 python3-venv python3-pip unzip curl`
  - Optional (if cloned on Windows): `sudo apt install -y dos2unix && dos2unix *.sh`
  - Docker (Docker Desktop with WSL integration or native Docker).
- Start SonarQube
  - `sudo sysctl -w vm.max_map_count=262144` (persist via `/etc/sysctl.conf`)
  - `docker compose up -d` and wait for `http://localhost:9000` to be UP.
  - Create a Global Analysis Token at `http://localhost:9000/account/security`.
- Setup and run (use Linux paths like `/mnt/d/...` in WSL)
  - `bash ./setup.sh`
  - Single project: `bash ./run.sh`
  - Multiple projects: `bash ./run-multi.sh`
- Weekday scheduling
  - `bash ./run-weekdays.sh --install --time HH:MM [--single|--multi]` (systemd user timer or cron fallback)
  - Note: systemd/cron jobs run only while the distro is running. On Windows hosts, prefer `run-weekdays.bat` + Task Scheduler for always-on scheduling.

## When to set SONAR_SOURCES and SONAR_EXCLUSIONS

Some projects (especially Node.js/monorepos) may fail with messages similar to:

```
java.nio.file.FileSystemException: ...\node_modules\.bin\acorn: O arquivo não pode ser acessado pelo sistema
```

This happens because node_modules (and `.bin` shims) can be unreadable on Windows, and the scanner may touch entries before exclusions take effect. Restrict sources and exclude dependencies/output folders:

- In `.env` or in a specific `configs/<project>.env`, add for example:

```
SONAR_SOURCES="src"
SONAR_EXCLUSIONS="**/node_modules/**,**/node_modules/.bin/**,**/dist/**,**/build/**,**/coverage/**,**/.next/**"
```

Adjust `SONAR_SOURCES` to your code roots (e.g., `src,app` or `server,shared/src`). You can also put these in a `sonar-project.properties` at the project base directory. For verbose scanner logs, set `SCANNER_DEBUG=1` before running.
