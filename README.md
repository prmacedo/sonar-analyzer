Para rodar o SonarQube é preciso executar esse comando no Linux

```bash
sudo sysctl -w vm.max_map_count=262144
```

# Requisitos

- Python
- Docker -> Rodando o SonarQube
- Sonar Scanner CLI (Instalado automaticamente pelo script setup.sh)

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

# Understandin measures and metrics

[Documentation](https://docs.sonarsource.com/sonarqube-community-build/user-guide/code-metrics/metrics-definition/)

# metrics.json

Arquivo com o retorno da endpoint `/api/metrics/search?ps=200` do sonarqube

# Plugin Flutter para SonarQube

[sonar-flutter-0.5.2](https://github.com/insideapp-oss/sonar-flutter/releases/download/0.5.2/sonar-flutter-plugin-0.5.2.jar)

# Projetos Flutter

Para rodar em um projeto flutter é preciso configurar e adicionar o arquivo `sonar-project.properties` na raiz do projeto ou passar as configurações como parâmetro do sonar-scanner e executar os comando abaixo em ordem:

```bash
flutter pub get
flutter test --machine --coverage > tests.output
```

E logo após executar o `sonar-scanner`
