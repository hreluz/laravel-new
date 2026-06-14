#!/usr/bin/env bash

set -e

echo ""
echo "=============================================="
echo " Laravel Docker Project Creator"
echo "=============================================="
echo ""
echo "Enter the FULL PATH of the NEW project folder."
echo ""
echo "Examples:"
echo "  ~/Projects/my-api"
echo "  ~/Projects/client-portal"
echo "  /var/www/my-app"
echo ""
echo "The folder will be created automatically."
echo ""

read -rp "Project path: " PROJECT_PATH

PROJECT_PATH="${PROJECT_PATH/#\~/$HOME}"

if [ -z "$PROJECT_PATH" ]; then
    echo "Project path is required."
    exit 1
fi

if [ -e "$PROJECT_PATH" ] && [ "$(ls -A "$PROJECT_PATH" 2>/dev/null)" ]; then
    echo "Directory already exists and is not empty:"
    echo "$PROJECT_PATH"
    exit 1
fi

echo ""
echo "Project type:"
echo "  1) API only"
echo "  2) Full stack / Vite"
echo ""

read -rp "Choose an option [1-2] (default: 1): " PROJECT_TYPE

if [ -z "$PROJECT_TYPE" ]; then
    PROJECT_TYPE="1"
fi

if [ "$PROJECT_TYPE" = "1" ]; then
    API_ONLY=true
    ENABLE_VITE=false
elif [ "$PROJECT_TYPE" = "2" ]; then
    API_ONLY=false
    ENABLE_VITE=true
else
    echo "Invalid option. Please choose 1 or 2."
    exit 1
fi

PROJECT_NAME="$(basename "$PROJECT_PATH" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')"

echo ""
echo "Project will be created at:"
echo "  $PROJECT_PATH"
echo ""
echo "Docker Compose project name:"
echo "  $PROJECT_NAME"
echo ""

if [ "$API_ONLY" = true ]; then
    echo "Project type:"
    echo "  API only"
else
    echo "Project type:"
    echo "  Full stack / Vite"
fi

echo ""

mkdir -p "$PROJECT_PATH"

echo "Creating Laravel project..."

docker run --rm \
    -u "$(id -u):$(id -g)" \
    -v "$PROJECT_PATH":/app \
    -w /app \
    composer:2 \
    composer create-project laravel/laravel .

echo "Creating Dockerfile..."

if [ "$API_ONLY" = true ]; then
cat > "$PROJECT_PATH/Dockerfile" <<'EOF'
FROM php:8.4-cli

RUN apt-get update && apt-get install -y \
    git \
    unzip \
    zip \
    libzip-dev \
    default-mysql-client \
    && docker-php-ext-install pdo_mysql zip

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app

CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
EOF
else
cat > "$PROJECT_PATH/Dockerfile" <<'EOF'
FROM php:8.4-cli

RUN apt-get update && apt-get install -y \
    git \
    unzip \
    zip \
    curl \
    libzip-dev \
    default-mysql-client \
    && docker-php-ext-install pdo_mysql zip

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs

WORKDIR /app

CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
EOF
fi

echo "Creating docker-compose.yml..."

if [ "$ENABLE_VITE" = true ]; then
cat > "$PROJECT_PATH/docker-compose.yml" <<'EOF'
services:
  app:
    build: .
    user: "${HOST_UID:-1000}:${HOST_GID:-1000}"
    working_dir: /app
    volumes:
      - ./:/app
    ports:
      - "${APP_PORT:-8000}:8000"
      - "${VITE_PORT:-5173}:5173"
    depends_on:
      - mysql

  mysql:
    image: mysql:8.0
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: laravel
      MYSQL_USER: laravel
      MYSQL_PASSWORD: secret
      MYSQL_ROOT_PASSWORD: root
    volumes:
      - mysql_data:/var/lib/mysql

volumes:
  mysql_data:
EOF
else
cat > "$PROJECT_PATH/docker-compose.yml" <<'EOF'
services:
  app:
    build: .
    user: "${HOST_UID:-1000}:${HOST_GID:-1000}"
    working_dir: /app
    volumes:
      - ./:/app
    ports:
      - "${APP_PORT:-8000}:8000"
    depends_on:
      - mysql

  mysql:
    image: mysql:8.0
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: laravel
      MYSQL_USER: laravel
      MYSQL_PASSWORD: secret
      MYSQL_ROOT_PASSWORD: root
    volumes:
      - mysql_data:/var/lib/mysql

volumes:
  mysql_data:
EOF
fi

echo "Updating Laravel .env..."

sed -i.bak \
  -e "s/^DB_CONNECTION=.*/DB_CONNECTION=mysql/" \
  -e "s/^# DB_HOST=.*/DB_HOST=mysql/" \
  -e "s/^# DB_PORT=.*/DB_PORT=3306/" \
  -e "s/^# DB_DATABASE=.*/DB_DATABASE=laravel/" \
  -e "s/^# DB_USERNAME=.*/DB_USERNAME=laravel/" \
  -e "s/^# DB_PASSWORD=.*/DB_PASSWORD=secret/" \
  -e "s/^DB_HOST=.*/DB_HOST=mysql/" \
  -e "s/^DB_PORT=.*/DB_PORT=3306/" \
  -e "s/^DB_DATABASE=.*/DB_DATABASE=laravel/" \
  -e "s/^DB_USERNAME=.*/DB_USERNAME=laravel/" \
  -e "s/^DB_PASSWORD=.*/DB_PASSWORD=secret/" \
  "$PROJECT_PATH/.env"

rm -f "$PROJECT_PATH/.env.bak"

echo "Adding Docker variables to Laravel .env..."

cat >> "$PROJECT_PATH/.env" <<EOF

# Docker
COMPOSE_PROJECT_NAME=$PROJECT_NAME
HOST_UID=$(id -u)
HOST_GID=$(id -g)
APP_PORT=8000
EOF

if [ "$ENABLE_VITE" = true ]; then
cat >> "$PROJECT_PATH/.env" <<'EOF'
VITE_PORT=5173
EOF
fi

echo ""
echo "Project created successfully!"
echo ""
echo "Next steps:"
echo ""
echo "cd \"$PROJECT_PATH\""
echo "docker compose build"
echo "docker compose up"
echo ""
echo "In another terminal:"
echo "docker compose exec app php artisan migrate"
