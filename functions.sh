#!/bin/bash

# Define cores
getColors(){
    export red='\033[0;31m'
    export green='\033[0;32m'
    export blue='\033[0;34m'
    export yellow='\033[1;33m'
    export reset='\033[0m'
}

getColors

# Função para exibir mensagem de boas-vindas
Welcome(){
    echo -e "${blue}Funções carregadas com sucesso!${reset}"
}

# Função para verificar e criar o arquivo .env se necessário
create_env_file() {
  if [ ! -f .env ]; then
    if [ -f .env.example ]; then
      cp .env.example .env
      echo -e "${green}Arquivo .env criado a partir de .env.example.${reset}"
    else
      echo -e "${red}Erro: .env.example não encontrado. Não foi possível criar o .env.${reset}"
    fi
  fi
}

create_env_file

# Comando para matar todos os containers
dka() {
    docker kill $(docker ps -q)
    echo -e "${green}Todos os containers em execução foram derrubados.${reset}"
}

# Reinicia a aplicação e mostra os logs
dua() {
    docker-compose down && docker-compose up -d
    docker attach "${APP_NAME}_app"
}

# Instalação de Docker e Docker Compose
install_docker_compose() {
    if ! command -v docker &> /dev/null; then
        echo "Instalando Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        sudo systemctl start docker
        sudo systemctl enable docker
        rm get-docker.sh
    else
        echo "Docker já está instalado."
    fi

    if ! command -v docker-compose &> /dev/null; then
        echo "Instalando Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/download/1.29.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    else
        echo "Docker Compose já está instalado."
    fi
}

install_docker_compose

# Carrega variáveis do .env
getEnv(){
    if [ ! -f .env ]; then
        echo -e "${yellow}Aviso: arquivo .env não encontrado, variáveis não carregadas.${reset}"
        return
    fi

    eval "$(
        grep -vE '^\s*#|^\s*$' .env | while IFS='' read -r line; do
            key=$(echo "$line" | cut -d '=' -f 1)
            value=$(echo "$line" | cut -d '=' -f 2-)
            echo "export $key=\"$value\""
        done
    )"
}

getEnv

user_docker(){
    if id -nG "$USER" | grep -qw "docker"; then
        echo "$USER já pertence ao grupo docker."
    else
        sudo usermod -aG docker "$USER"
        echo "$USER adicionado ao grupo docker."
    fi
}

enter(){
    docker exec -it "$@" bash
}

db(){
    if [ "$1" = "restore" ]; then
        echo "Iniciando restauração de ${APP_NAME}_development..."
        docker container exec "${APP_NAME}_db" psql -d "${APP_NAME}_development" -f "/home/db_restore/$2" -U postgres
        echo "${APP_NAME}_development restaurado com sucesso."
    fi
}

atualiza_nome_app(){
    sudo sed -i "1cAPP_NAME=$1" .env
}

permissions_update(){
    arquivos=(
        app .env .gitignore Dockerfile Gemfile Gemfile.lock README.md
        docker-compose.yml start.sh docker-compose/Gemfile
        config/master.key db/migrate docs/diagramas db/seeds.rb
        todo.txt config/routes.rb
    )
    for file in "${arquivos[@]}"; do
        se_existe "$file" "sudo chown -R $USER:$USER $file"
    done
    echo -e "${green}✅ Permissões atualizadas!${reset}"
}

prune(){
    docker system prune -a -f
}

restart(){
    docker-compose down
    prune
    source start.sh
}

se_existe(){
    local file=$1
    local comando=$2
    if [ -f "$file" ] || [ -d "$file" ]; then
        eval "$comando"
    fi
}

commit() {
    BRANCH=$(git rev-parse --abbrev-ref HEAD) 
    COMMIT_MESSAGE=""

    case "$1" in
        feature) COMMIT_MESSAGE="✨ $2" ;;
        bugfix) COMMIT_MESSAGE="🐛 $2" ;;
        hotfix) COMMIT_MESSAGE="💥 $2" ;;
        doc) COMMIT_MESSAGE="📚 $2" ;;
        rollback) COMMIT_MESSAGE="⏪ $2" ;;
        e2e) COMMIT_MESSAGE="🔍 $2" ;;
        help)
            echo -e "${blue}commit help${reset} - Exibe esta lista de comandos"
            echo -e "${blue}commit feature${reset} ${green}\"mensagem\"${reset} -> Nova funcionalidade"
            echo -e "${blue}commit bugfix${reset} ${green}\"mensagem\"${reset} -> Correção de bug"
            echo -e "${blue}commit hotfix${reset} ${green}\"mensagem\"${reset} -> Correção urgente"
            echo -e "${blue}commit doc${reset} ${green}\"mensagem\"${reset} -> Documentação"
            echo -e "${blue}commit rollback${reset} ${green}\"mensagem\"${reset} -> Rollback"
            echo -e "${blue}commit e2e${reset} ${green}\"mensagem\"${reset} -> Testes end-to-end"
            return
            ;;
        *) COMMIT_MESSAGE="🚧 $1" ;;
    esac

    git add . && git commit -m "$COMMIT_MESSAGE" && git push origin "$BRANCH"
    echo -e "Commit ${green}'$COMMIT_MESSAGE'${reset} realizado na branch ${blue}$BRANCH${reset}"
}

cypress(){
    CYPRESS_DIR="test/"

    if [ ! -d "$CYPRESS_DIR" ]; then
        echo -e "${red}Erro: O diretório $CYPRESS_DIR não foi encontrado.${reset}"
        return 1
    fi

    case "$1" in
        run)
            npx cypress run --project "$CYPRESS_DIR"
            ;;
        open)
            npx cypress open --project "$CYPRESS_DIR"
            ;;
        install)
            echo "Instalando dependências com node_install.sh..."
            (cd "$CYPRESS_DIR" && sudo ./node_install.sh)
            ;;
        --help|-h)
            echo "Uso: cypress {run|open|install}"
            ;;
        *)
            echo -e "${red}Comando inválido.${reset} Use 'cypress --help' para ajuda."
            return 1
            ;;
    esac
}

Welcome
