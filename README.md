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
