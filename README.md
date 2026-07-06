# laravel-new

Create a new Dockerized Laravel project in minutes.

`laravel-new` generates a fully configured Laravel development environment with:

* Laravel
* Docker
* Docker Compose
* MySQL 8
* PHP 8.4
* Composer
* Optional Node.js + Vite
* Automatic UID/GID configuration for Linux

No need to install PHP, Composer, MySQL, or Node.js on your machine.

---

# Features

* Interactive project creation
* API-only projects
* Full Stack Laravel + Vite projects
* MySQL configuration
* Dockerfile generation
* Docker Compose generation
* Automatic Laravel `.env` configuration
* Automatic Docker Compose project naming
* Linux file permission support (UID/GID)

---

# Requirements

* Docker
* Docker Compose

Verify installation:

```bash
docker --version
docker compose version
```

---

# Installation

Clone the repository:

```bash
git clone https://github.com/hreluz/laravel-new.git
cd laravel-new
```

Make the script executable:

```bash
chmod +x create-laravel-docker.sh
```

Optional: install globally

```bash
sudo ln -s "$(pwd)/create-laravel-docker.sh" /usr/local/bin/laravel-new-project
```

Then run from anywhere:

```bash
laravel-new-project
```

---

# Usage

Run:

```bash
laravel-new-project
```

You will be prompted for:

```text
==============================================
 Laravel Docker Project Creator
==============================================

Enter the BASE PATH where the project folder
will be created, or press ENTER to use the
current directory.

Examples:
  ~/Projects
  /var/www

Base path [/current/directory]:

Enter the PROJECT NAME. This will be used as
the folder name, appended to the base path.

Examples:
  my-api
  client-portal

Project name:
```

Press ENTER on the base path without typing anything to use the current
directory. The project name has no default and must be provided; the
project folder will be created at `<base path>/<project name>`.

Then choose the project type:

```text
Project type:
  1) API only
  2) Full stack / Vite

Choose an option [1-2]:
```

---

# API Only Project

Creates:

* Laravel
* PHP 8.4
* Composer
* MySQL

No Node.js.

No Vite port.

Example:

```bash
~/Projects/inventory-api
```

---

# Full Stack Project

Creates:

* Laravel
* PHP 8.4
* Composer
* MySQL
* Node.js 22
* Vite support

Example:

```bash
~/Projects/client-portal
```

---

# Generated Files

Example structure:

```text
my-project/
├── app/
├── bootstrap/
├── config/
├── database/
├── public/
├── resources/
├── routes/
├── storage/
├── tests/
├── vendor/
├── .env
├── artisan
├── composer.json
├── Dockerfile
└── docker-compose.yml
```

---

# Starting the Project

Go to the project directory:

```bash
cd ~/Projects/my-project
```

Build containers:

```bash
docker compose build
```

Start services:

```bash
docker compose up
```

Open Laravel:

```text
http://localhost:8000
```

---

# Running Migrations

```bash
docker compose exec app php artisan migrate
```

---

# Common Commands

Install a Composer package:

```bash
docker compose exec app composer require vendor/package
```

Create a model:

```bash
docker compose exec app php artisan make:model Post -m
```

Run tests:

```bash
docker compose exec app php artisan test
```

Open Tinker:

```bash
docker compose exec app php artisan tinker
```

---

# Full Stack Commands

Install frontend dependencies:

```bash
docker compose exec app npm install
```

Run Vite:

```bash
docker compose exec app npm run dev
```

Build frontend assets:

```bash
docker compose exec app npm run build
```

---

# Database Configuration

Generated Laravel projects use:

```env
DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=laravel
DB_USERNAME=laravel
DB_PASSWORD=secret
```

Default MySQL credentials:

| Setting       | Value   |
| ------------- | ------- |
| Database      | laravel |
| Username      | laravel |
| Password      | secret  |
| Root Password | root    |

---

# Testing

The test suite runs inside Docker — no installs required on your machine.

```bash
bash run-tests.sh
```

Tests also run automatically on every push and pull request via GitHub Actions.

---

# Why laravel-new?

Creating a new Laravel project often requires:

* Installing PHP
* Installing Composer
* Installing MySQL
* Installing Node.js
* Configuring Docker
* Fixing Linux file permissions

`laravel-new` automates the entire process and gives you a ready-to-run development environment.

---

# Roadmap

Planned features:

* PostgreSQL support
* Redis support
* Mailpit support
* Laravel Reverb support
* Pest option
* Vue starter option
* React starter option
* Inertia starter option
* Package development template
* HTTPS support
* Traefik integration

---

# License

MIT

