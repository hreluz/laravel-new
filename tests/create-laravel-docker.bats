#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../create-laravel-docker.sh"

# Minimal .env that "composer create-project laravel/laravel ." would produce
LARAVEL_ENV='APP_NAME=Laravel
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://localhost

DB_CONNECTION=sqlite
# DB_HOST=127.0.0.1
# DB_PORT=3306
# DB_DATABASE=laravel
# DB_USERNAME=root
# DB_PASSWORD=
'

setup() {
    TMP_DIR="$(mktemp -d)"
    export TMP_DIR

    # Fake docker binary: intercepts "docker run ... -v HOST:/app ..." and
    # writes a minimal Laravel .env into HOST so the rest of the script can run.
    mkdir -p "$TMP_DIR/bin"
    cat > "$TMP_DIR/bin/docker" <<'MOCK'
#!/usr/bin/env bash
for arg in "$@"; do
    if [[ "$arg" == *":/app"* ]]; then
        host_dir="${arg%%:*}"
        mkdir -p "$host_dir"
        printf '%s' "$LARAVEL_ENV" > "$host_dir/.env"
        break
    fi
done
exit 0
MOCK
    chmod +x "$TMP_DIR/bin/docker"

    export PATH="$TMP_DIR/bin:$PATH"
    export LARAVEL_ENV
}

teardown() {
    rm -rf "$TMP_DIR"
}

# Writes args as newline-separated lines to a temp file and runs the script
# with that file as stdin. Sets $status and $output like bats `run` would.
# Expected prompt order: base path, project name, project type.
script_run() {
    printf '%s\n' "$@" > "$TMP_DIR/stdin"
    run bash "$SCRIPT" < "$TMP_DIR/stdin"
}

# ---------------------------------------------------------------------------
# Input validation
# ---------------------------------------------------------------------------

@test "empty base path defaults to current directory" {
    local parent="$TMP_DIR/cwd-parent"
    mkdir -p "$parent"
    cd "$parent"
    printf '\nmy-app\n1\n' > "$TMP_DIR/stdin"
    run bash "$SCRIPT" < "$TMP_DIR/stdin"
    [ "$status" -eq 0 ]
    [ -f "$parent/my-app/.env" ]
}

@test "rejects non-empty existing directory" {
    local name="existing-project"
    mkdir -p "$TMP_DIR/$name"
    touch "$TMP_DIR/$name/somefile"
    script_run "$TMP_DIR" "$name" "1"
    [ "$status" -eq 1 ]
    [[ "$output" == *"already exists and is not empty"* ]]
}

@test "allows empty existing directory" {
    local name="empty-project"
    mkdir -p "$TMP_DIR/$name"
    script_run "$TMP_DIR" "$name" "1"
    [ "$status" -eq 0 ]
}

@test "reprompts when project name is left blank" {
    printf '%s\n\nmy-app\n1\n' "$TMP_DIR" > "$TMP_DIR/stdin"
    run bash "$SCRIPT" < "$TMP_DIR/stdin"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Project name is required"* ]]
    [ -f "$TMP_DIR/my-app/.env" ]
}

@test "rejects invalid project type" {
    script_run "$TMP_DIR" "my-project" "9"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid option"* ]]
}

@test "empty type input defaults to API only (no Node.js in Dockerfile)" {
    local project="$TMP_DIR/default-type"
    # sending empty line for type selection = default 1
    printf '%s\ndefault-type\n\n' "$TMP_DIR" > "$TMP_DIR/stdin"
    run bash "$SCRIPT" < "$TMP_DIR/stdin"
    [ "$status" -eq 0 ]
    run grep -i "node" "$project/Dockerfile"
    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Dockerfile generation
# ---------------------------------------------------------------------------

@test "API-only Dockerfile does not include Node.js" {
    local project="$TMP_DIR/api-project"
    script_run "$TMP_DIR" "api-project" "1"
    [ "$status" -eq 0 ]
    run grep -i "node" "$project/Dockerfile"
    [ "$status" -ne 0 ]
}

@test "full-stack Dockerfile includes Node.js setup" {
    local project="$TMP_DIR/fullstack-project"
    script_run "$TMP_DIR" "fullstack-project" "2"
    [ "$status" -eq 0 ]
    grep -q "nodejs" "$project/Dockerfile"
}

@test "both Dockerfiles use php:8.4-cli base image" {
    local api="$TMP_DIR/api-check"
    local fs="$TMP_DIR/fs-check"
    script_run "$TMP_DIR" "api-check" "1"
    script_run "$TMP_DIR" "fs-check" "2"
    grep -q "FROM php:8.4-cli" "$api/Dockerfile"
    grep -q "FROM php:8.4-cli" "$fs/Dockerfile"
}

# ---------------------------------------------------------------------------
# docker-compose.yml generation
# ---------------------------------------------------------------------------

@test "API-only docker-compose does not expose Vite port" {
    local project="$TMP_DIR/api-compose"
    script_run "$TMP_DIR" "api-compose" "1"
    [ "$status" -eq 0 ]
    run grep "5173" "$project/docker-compose.yml"
    [ "$status" -ne 0 ]
}

@test "full-stack docker-compose exposes Vite port 5173" {
    local project="$TMP_DIR/fs-compose"
    script_run "$TMP_DIR" "fs-compose" "2"
    [ "$status" -eq 0 ]
    grep -q "5173" "$project/docker-compose.yml"
}

@test "docker-compose includes mysql service in both modes" {
    local api="$TMP_DIR/api-mysql"
    local fs="$TMP_DIR/fs-mysql"
    script_run "$TMP_DIR" "api-mysql" "1"
    script_run "$TMP_DIR" "fs-mysql" "2"
    grep -q "mysql:" "$api/docker-compose.yml"
    grep -q "mysql:" "$fs/docker-compose.yml"
}

@test "docker-compose declares persistent mysql volume" {
    local project="$TMP_DIR/vol-check"
    script_run "$TMP_DIR" "vol-check" "1"
    [ "$status" -eq 0 ]
    grep -q "mysql_data:" "$project/docker-compose.yml"
}

# ---------------------------------------------------------------------------
# .env DB configuration
# ---------------------------------------------------------------------------

@test "updates DB_CONNECTION to mysql" {
    local project="$TMP_DIR/env-mysql"
    script_run "$TMP_DIR" "env-mysql" "1"
    [ "$status" -eq 0 ]
    grep -q "^DB_CONNECTION=mysql" "$project/.env"
}

@test "sets DB_HOST to mysql service name" {
    local project="$TMP_DIR/env-host"
    script_run "$TMP_DIR" "env-host" "1"
    [ "$status" -eq 0 ]
    grep -q "^DB_HOST=mysql" "$project/.env"
}

@test "sets DB credentials to expected defaults" {
    local project="$TMP_DIR/env-creds"
    script_run "$TMP_DIR" "env-creds" "1"
    [ "$status" -eq 0 ]
    grep -q "^DB_DATABASE=laravel" "$project/.env"
    grep -q "^DB_USERNAME=laravel" "$project/.env"
    grep -q "^DB_PASSWORD=secret" "$project/.env"
}

@test "does not leave a .env.bak file behind" {
    local project="$TMP_DIR/env-bak"
    script_run "$TMP_DIR" "env-bak" "1"
    [ "$status" -eq 0 ]
    [ ! -f "$project/.env.bak" ]
}

# ---------------------------------------------------------------------------
# Docker env variables appended to .env
# ---------------------------------------------------------------------------

@test "appends COMPOSE_PROJECT_NAME derived from project name" {
    local project="$TMP_DIR/my-cool-app"
    script_run "$TMP_DIR" "my-cool-app" "1"
    [ "$status" -eq 0 ]
    grep -q "^COMPOSE_PROJECT_NAME=my-cool-app" "$project/.env"
}

@test "appends HOST_UID and HOST_GID to .env" {
    local project="$TMP_DIR/uid-check"
    script_run "$TMP_DIR" "uid-check" "1"
    [ "$status" -eq 0 ]
    grep -q "^HOST_UID=" "$project/.env"
    grep -q "^HOST_GID=" "$project/.env"
}

@test "appends APP_PORT=8000 to .env" {
    local project="$TMP_DIR/port-check"
    script_run "$TMP_DIR" "port-check" "1"
    [ "$status" -eq 0 ]
    grep -q "^APP_PORT=8000" "$project/.env"
}

@test "full-stack appends VITE_PORT to .env" {
    local project="$TMP_DIR/vite-env"
    script_run "$TMP_DIR" "vite-env" "2"
    [ "$status" -eq 0 ]
    grep -q "^VITE_PORT=5173" "$project/.env"
}

@test "API-only does not append VITE_PORT to .env" {
    local project="$TMP_DIR/no-vite-env"
    script_run "$TMP_DIR" "no-vite-env" "1"
    [ "$status" -eq 0 ]
    run grep "^VITE_PORT" "$project/.env"
    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Success output
# ---------------------------------------------------------------------------

@test "prints success message on completion" {
    local project="$TMP_DIR/success-check"
    script_run "$TMP_DIR" "success-check" "1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Project created successfully"* ]]
}

# ---------------------------------------------------------------------------
# Project name sanitization
# ---------------------------------------------------------------------------

@test "project name is lowercased and stripped of invalid chars" {
    local project="$TMP_DIR/MyApp_2024"
    script_run "$TMP_DIR" "MyApp_2024" "1"
    [ "$status" -eq 0 ]
    grep -q "^COMPOSE_PROJECT_NAME=myapp_2024" "$project/.env"
}
