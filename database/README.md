# Webshop Database Setup

This repository contains the database schema and setup scripts for the Webshop project (Vue 3 frontend, Flask backend, PostgreSQL database).

## Quick Start

### Linux / macOS

```bash
# Make script executable (first time only)
chmod +x setup_db.sh

# First run - interactive questionnaire creates .env
./setup_db.sh

# Subsequent runs - uses .env automatically
./setup_db.sh

# Or with custom settings (overrides .env)
./setup_db.sh --port 5433 --dbname myshop --user myuser --password secret

# Non-interactive mode (CI/CD, uses .env or defaults)
./setup_db.sh --non-interactive

# Force SQLite
./setup_db.sh --db-type sqlite --non-interactive
```

### Windows

```cmd
REM First run - interactive questionnaire creates .env
setup_db.bat

REM Subsequent runs - uses .env automatically
setup_db.bat

REM Or with custom settings (overrides .env)
setup_db.bat --port 5433 --dbname myshop --user myuser --password secret

REM Non-interactive mode (CI/CD)
setup_db.bat --non-interactive

REM Force SQLite
setup_db.bat --db-type sqlite --non-interactive
```

## Configuration

### .env File (Database Only)

The `.env` file contains **only database configuration**. Flask and frontend have their own separate configuration.

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_TYPE` | Database type: `postgresql` or `sqlite` | `postgresql` |
| `PG_HOST` | PostgreSQL host | `localhost` |
| `PG_PORT` | PostgreSQL port | `5432` |
| `PG_DBNAME` | Database name | `webshop` |
| `PG_USER` | PostgreSQL user | `postgres` |
| `PG_PASSWORD` | PostgreSQL password | *(empty - peer auth)* |
| `SQLITE_DB_PATH` | SQLite database file path | `./webshop.sqlite` |
| `AUTO_CREATE_DB` | Auto-create database if missing | `true` |
| `AUTO_RUN_SCHEMA` | Auto-run schema migration | `true` |

### Configuration Priority

1. **CLI arguments** (highest)
2. **`.env` file**
3. **Environment variables** (`PGPASSWORD`, `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`)
4. **Defaults** (lowest)

### First Run Questionnaire

On first run (no `.env` found), an interactive questionnaire guides you through:
1. Database type (PostgreSQL or SQLite)
2. Connection details (host, port, database, user, password)
3. Setup behavior (auto-create, auto-migrate)

The questionnaire creates `.env` with permissions restricted to your user (600 on Linux/macOS, ACL on Windows).

### Standard Port

The standard PostgreSQL port is **5432**. The scripts use this by default.

## What Gets Created

Running the setup script creates:

1. **Database** - `webshop` (PostgreSQL) or `webshop.sqlite` (SQLite)
2. **27 Core Tables** organized in modules:
   - **Identity & Auth**: `users`, `user_credentials`, `user_private_data`, `user_addresses`, `password_reset_tokens`
   - **Product Catalogue**: `brands`, `suppliers`, `products`, `product_translations`, `product_specs`, `product_images`, `product_image_translations`
   - **Commerce**: `reviews`, `carts`, `cart_items`, `orders`, `order_items`, `order_contact_data`, `order_addresses`
   - **Stores**: `stores`, `store_translations`, `store_opening_hours`, `store_notices`, `store_notice_translations`, `store_images`, `store_image_translations`
3. **Indexes** for query performance
4. **Seed Data** - Languages `sl` (Slovenian) and `en` (English)
5. **Connection Config** - `.db_config` file for backend consumption

## Database Schema Details

See `schema.sql` for the complete PostgreSQL schema including:
- Primary keys: `BIGINT GENERATED ALWAYS AS IDENTITY`
- Money stored as integer cents (`BIGINT`)
- Timestamps: `TIMESTAMPTZ` (UTC)
- Encrypted fields: `BYTEA` with nonce and key version
- Constraints: `UNIQUE`, `CHECK`, `FOREIGN KEY` with explicit `ON DELETE` actions
- Partial unique indexes for default addresses and primary images

## Backend Connection (Flask)

After running the setup script, a `.db_config` file is created with connection parameters. **Copy these values to your Flask backend's `.env` file.**

### PostgreSQL Configuration (Flask backend/.env)

```bash
# Database
DATABASE_URL=postgresql+psycopg://user:password@localhost:5432/webshop
# Or individual components:
PG_HOST=localhost
PG_PORT=5432
PG_DBNAME=webshop
PG_USER=your_user
PG_PASSWORD=your_password
```

### SQLite Configuration (Flask backend/.env)

```bash
DATABASE_URL=sqlite:///./webshop.sqlite
```

### Using with Flask-SQLAlchemy 3.x / SQLAlchemy 2.x

```python
# backend/app/config.py
import os
from pathlib import Path

class Config:
    SQLALCHEMY_DATABASE_URI = os.getenv('DATABASE_URL')
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {
        'pool_pre_ping': True,
        'pool_recycle': 300,
    }
```

```python
# backend/app/extensions.py
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate

db = SQLAlchemy()
migrate = Migrate()

def init_extensions(app):
    db.init_app(app)
    migrate.init_app(app, db)
```

```python
# backend/app/__init__.py
from flask import Flask
from .config import Config
from .extensions import db, migrate

def create_app(config_class=Config):
    app = Flask(__name__)
    app.config.from_object(config_class)
    init_extensions(app)
    # Register blueprints, etc.
    return app
```

## Running Migrations (Alembic/Flask-Migrate)

After initial schema creation, use Flask-Migrate for schema changes:

```bash
# Initialize migrations (first time only)
flask db init

# Create migration for model changes
flask db migrate -m "Description of changes"

# Apply migrations
flask db upgrade

# Check current revision
flask db current

# Show history
flask db history
```

## Verification

### Check Tables (PostgreSQL)
```bash
psql -h localhost -p 5432 -U postgres -d webshop -c "\dt"
```

### Check Tables (SQLite)
```bash
sqlite3 webshop.sqlite ".tables"
```

### Test Connection from Python
```python
import psycopg2
# or: import sqlite3

# PostgreSQL
conn = psycopg2.connect(
    host="localhost", port=5432,
    user="postgres", password="secret",
    database="webshop"
)

# SQLite
conn = sqlite3.connect("webshop.sqlite")

cursor = conn.cursor()
cursor.execute("SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';")
# SQLite: cursor.execute("SELECT count(*) FROM sqlite_master WHERE type='table';")
print(f"Tables: {cursor.fetchone()[0]}")
conn.close()
```

## Project Structure

```
database/
├── schema.sql           # PostgreSQL schema (source of truth)
├── setup_db.sh          # Linux/macOS setup script
├── setup_db.bat         # Windows setup script
├── .env.example         # Example environment configuration
├── .env                 # Your configuration (gitignored, created on first run)
├── .db_config           # Generated connection config (gitignored)
├── webshop.sqlite       # SQLite fallback DB (gitignored)
├── .gitignore           # Git ignore rules
└── README.md            # This file
```

## Troubleshooting

### PostgreSQL Connection Refused
- Ensure PostgreSQL service is running: `sudo systemctl status postgresql`
- Check port: `ss -tlnp | grep 5432`
- Verify `pg_hba.conf` allows local connections

### Permission Denied Creating Database
- Run as PostgreSQL superuser or grant `CREATEDB` to your user:
  ```sql
  ALTER USER youruser CREATEDB;
  ```

### SQLite "database is locked"
- Ensure no other process has the database open
- Delete `webshop.sqlite` and re-run setup

### Migration Issues
- Never edit applied migration files
- Use `flask db migrate` for new changes
- For development, `flask db downgrade` then `upgrade` to re-apply

### Questionnaire Issues (Windows)
- If password input doesn't work, ensure you're running in a modern terminal (Windows Terminal, PowerShell 7+, or CMD with ANSI support)
- Use `--non-interactive` with a pre-created `.env` for automation

## Security Notes

- **Never commit `.env`, `.db_config`, `webshop.sqlite`, or any `.env` files**
- Use strong passwords for PostgreSQL users
- In production, use a secrets manager for database credentials
- The schema uses `BYTEA` for encrypted payloads - encryption keys must be managed outside the database
- Run the Flask API with a dedicated database role (see `schema.sql` role creation section)
- The `.env` file permissions are restricted to your user account on creation

## License

University project - internal use only.
