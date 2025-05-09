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
         echo -e "${green}Docker já está instalado. ${reset}"
    fi

    if ! command -v docker-compose &> /dev/null; then
        echo "Instalando Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/download/1.29.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    else
         echo -e "${green}Docker Compose já está instalado. ${reset}"
    fi
}

install_docker_compose

# Carrega variáveis do .env
getEnv(){
    if [ ! -f .env ]; then
        echo -e "${yellow}Aviso: arquivo .env não encontrado, variáveis não carregadas. ${reset}"
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
        echo -e "${blue}$USER já pertence ao grupo docker. ${reset}"
    else
        sudo usermod -aG docker "$USER"
        echo -e "${blue}$USER adicionado ao grupo docker. ${reset}"
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

function commit() {
    local BRANCH=$(git rev-parse --abbrev-ref HEAD)
    local TYPES=("Bugfix" "Feature" "Hotfix" "Doc" "Rollback" "E2E" "Outro")
    local EMOJIS=("🐛" "✨" "💥" "📚" "⏪" "🔍" "🚧")

    echo "Escolha o tipo de commit:"
    for i in "${!TYPES[@]}"; do
        echo "$((i + 1)) - ${EMOJIS[$i]} ${TYPES[$i]}"
    done

    read -p "Digite o número correspondente: " TYPE_INDEX
    TYPE_INDEX=$((TYPE_INDEX - 1))

    if [[ $TYPE_INDEX -lt 0 || $TYPE_INDEX -ge ${#TYPES[@]} ]]; then
        echo "Tipo inválido."
        return 1
    fi

    read -p "Digite a mensagem do commit: " MESSAGE
    local COMMIT_MESSAGE="${EMOJIS[$TYPE_INDEX]} $MESSAGE"

    # Adiciona arquivos e tenta o commit
    git add .
    if git diff --cached --quiet; then
        echo "Nenhuma alteração para commit."
        return 1
    fi

    if git commit -m "$COMMIT_MESSAGE"; then
        git push origin "$BRANCH"
        echo -e "✅ Commit realizado: '$COMMIT_MESSAGE' na branch '$BRANCH'"
    else
        echo "❌ Ocorreu um erro ao tentar realizar o commit."
        return 1
    fi
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

function list() {
    local header=$(docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}\t{{.Status}}" | head -n 1)
    if [ -n "$1" ]; then
        echo "$header"
        docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}\t{{.Status}}" | tail -n +2 | grep "$1"
    else
        echo "$header"
        docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}\t{{.Status}}" | tail -n +2
    fi
}

Welcome
