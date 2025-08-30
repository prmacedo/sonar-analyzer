Para rodar o SonarQube é preciso executar esse comando no Linux

```bash
sudo sysctl -w vm.max_map_count=262144
```

# Requisitos

- Python
- Docker -> Rodando o SonarQube
- Sonar Scanner CLI

# Executando o código

```bash
python sonar_analyze.py /path/to/project my_project_key my_username ./results \
  --sonar-host http://localhost:9000 \
  --sonar-token YOUR_SONAR_TOKEN
```

```bash
chmod +x run_sonar.sh

./run_sonar.sh <project_dir> <project_key> <username> <output_dir>

```
