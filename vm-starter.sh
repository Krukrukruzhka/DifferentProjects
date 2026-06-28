#!/bin/bash

# ============================================
# Скрипт установки Docker и Docker Compose
# для Ubuntu 24.04 LTS
# ============================================
#
# ИНСТРУКЦИЯ ПО ЗАПУСКУ:
#
# 1. Скопировать файл на виртуалку с помощью
#    scp vm-starter.sh <user@host>:/tmp/  вместо user@host я использую алиас (me)
#
# 2. Запустить скрипт
#    sudo bash /tmp/vm-starter.sh
#
# 3. После завершения установки выполните logout/login
#    (или перезагрузите систему), чтобы изменения групп
#    вступили в силу для текущего пользователя.
#
# ============================================

set -e  # Прекратить выполнение при ошибке

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

usage() {
    echo "Использование: $0 --username <имя_пользователя>"
    echo ""
    echo "Параметры:"
    echo "  --username <имя>    Имя пользователя, которого добавить в группу docker (обязательный)"
    echo "  -h, --help          Показать эту справку"
    exit 1
}

# ============================================
# Парсинг аргументов
# ============================================
USERNAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --username)
            USERNAME="$2"
            if [[ -z "$USERNAME" || "$USERNAME" == --* ]]; then
                error "Параметр --username требует значения"
                usage
            fi
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            error "Неизвестный аргумент: $1"
            usage
            ;;
    esac
done

# Проверка обязательного аргумента
if [[ -z "$USERNAME" ]]; then
    error "Аргумент --username является обязательным"
    usage
fi

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
   error "Скрипт должен быть запущен от root (используйте sudo)"
   exit 1
fi

# Проверка существования пользователя
if ! id "$USERNAME" &>/dev/null; then
    error "Пользователь '$USERNAME' не существует в системе"
    exit 1
fi

log "Установка будет выполнена для пользователя: $USERNAME"


# ===========================================
# 0. Настройка путей
# ==========================================

mkdir /home/${USERNAME}/github_projects


# ============================================
# 1. Обновление списка пакетов
# ============================================
log "Обновление списка пакетов..."
apt update

# ============================================
# 2. Установка зависимостей
# ============================================
log "Установка зависимостей..."
apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# ============================================
# 3. Удаление старых версий Docker (если есть)
# ============================================
log "Удаление старых версий Docker (если установлены)..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    apt remove -y $pkg 2>/dev/null || true
done

# ============================================
# 4. Добавление официального GPG-ключа Docker
# ============================================
log "Добавление GPG-ключа Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# ============================================
# 5. Добавление репозитория Docker
# ============================================
log "Добавление репозитория Docker..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# ============================================
# 6. Установка Docker и Docker Compose
# ============================================
log "Установка Docker Engine и Docker Compose..."
apt update
apt install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# ============================================
# 7. Запуск и автозапуск службы Docker
# ============================================
log "Включение и запуск службы Docker..."
systemctl enable docker
systemctl start docker

# ============================================
# 8. Добавление пользователя в группу docker
# ============================================
if [ -n "$SUDO_USER" ]; then
    log "Добавление пользователя $SUDO_USER в группу docker..."
    usermod -aG docker "$SUDO_USER"
    warn "Чтобы изменения вступили в силу, выполните logout/login или перезагрузите систему"
fi

# ============================================
# Финал
# ============================================
log "============================================"
log "Установка завершена!"
log "============================================"
echo ""
echo "Установленные версии:"
docker --version
docker compose version
echo ""
log "Для проверки запустите: docker run hello-world"

