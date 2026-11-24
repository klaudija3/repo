#!/usr/bin/env bash
# Webshop Database Setup Script (Linux/macOS)
# Creates and initializes the PostgreSQL database for the webshop project
# Usage: ./setup_db.sh [options]
# Options:
#   --port PORT             PostgreSQL port (default: 5432)
#   --host HOST             PostgreSQL host (default: localhost)
#   --dbname NAME           Database name (default: webshop)
#   --user USER             PostgreSQL user (default: postgres)
#   --password PASS         PostgreSQL password (default: from env PGPASSWORD)
#   --db-type TYPE          Database type: postgresql or sqlite (default: postgresql)
#   --sqlite-path PATH      SQLite database path (default: ./webshop.sqlite)
#   --non-interactive       Run without prompts (use .env or defaults)
#   --help                  Show this help

set -euo pipefail

# ============================================================================
# CONFIGURATION DEFAULTS
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
ENV_EXAMPLE="${SCRIPT_DIR}/.env.example"
SCHEMA_FILE="${SCRIPT_DIR}/schema.sql"

# Default values (overridden by .env, then CLI args)
DB_TYPE="postgresql"
PG_HOST="localhost"
PG_PORT="5432"
PG_DBNAME="webshop"
PG_USER="postgres"
PG_PASSWORD=""
SQLITE_DB_PATH="${SCRIPT_DIR}/webshop.sqlite"
AUTO_CREATE_DB="true"
AUTO_RUN_SCHEMA="true"

# CLI overrides storage
CLI_ARGS=()
NON_INTERACTIVE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_prompt() { echo -e "${CYAN}[PROMPT]${NC} $*"; }

# ============================================================================
# HELP
# ============================================================================
show_help() {
    cat <<EOF
Webshop Database Setup Script

Usage: $0 [options]

Options:
  --port PORT             PostgreSQL port (default: 5432)
  --host HOST             PostgreSQL host (default: localhost)
  --dbname NAME           Database name (default: webshop)
  --user USER             PostgreSQL user (default: postgres)
  --password PASS         PostgreSQL password (or set PGPASSWORD env var)
  --db-type TYPE          Database type: postgresql or sqlite (default: postgresql)
  --sqlite-path PATH      SQLite database file path (default: ./webshop.sqlite)
  --non-interactive       Run without prompts (use .env or defaults)
  --help                  Show this help

Configuration priority (highest to lowest):
  1. CLI arguments
  2. .env file
  3. Environment variables (PGPASSWORD, PGHOST, etc.)
  4. Defaults

First run: If .env doesn't exist, an interactive questionnaire will guide you
through creating it. Use --non-interactive to skip prompts.

Examples:
  $0                                          # Interactive first run, then uses .env
  $0 --non-interactive                        # Use .env or defaults, no prompts
  $0 --port 5433 --dbname myshop             # Override specific settings
  $0 --db-type sqlite --non-interactive       # Force SQLite, no prompts
EOF
}

# ============================================================================
# PARSE CLI ARGUMENTS
# ============================================================================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --port) PG_PORT="$2"; CLI_ARGS+=("$1" "$2"); shift 2 ;;
            --host) PG_HOST="$2"; CLI_ARGS+=("$1" "$2"); shift 2 ;;
            --dbname) PG_DBNAME="$2"; CLI_ARGS+=("$1" "$2"); shift 2 ;;
            --user) PG_USER="$2"; CLI_ARGS+=("$1" "$2"); shift 2 ;;
            --password) PG_PASSWORD="$2"; CLI_ARGS+=("$1" "$2"); shift 2 ;;
            --db-type) DB_TYPE="$2"; CLI_ARGS+=("$1" "$2"); shift 2 ;;
            --sqlite-path) SQLITE_DB_PATH="$2"; CLI_ARGS+=("$1" "$2"); shift 2 ;;
            --non-interactive) NON_INTERACTIVE=true; shift ;;
            --help) show_help; exit 0 ;;
            *) log_error "Unknown option: $1"; show_help; exit 1 ;;
        esac
    done
}

# ============================================================================
# LOAD .env FILE
# ============================================================================
load_env() {
    if [[ -f "$ENV_FILE" ]]; then
        log_info "Loading configuration from .env"
        # shellcheck source=/dev/null
        set -a
        source "$ENV_FILE"
        set +a
        # CLI args override .env
        apply_cli_overrides
    else
        log_info "No .env file found"
        # Try environment variables
        PG_PASSWORD="${PGPASSWORD:-$PG_PASSWORD}"
        PG_HOST="${PGHOST:-$PG_HOST}"
        PG_PORT="${PGPORT:-$PG_PORT}"
        PG_DBNAME="${PGDATABASE:-$PG_DBNAME}"
        PG_USER="${PGUSER:-$PG_USER}"
    fi
}

apply_cli_overrides() {
    for ((i=0; i<${#CLI_ARGS[@]}; i+=2)); do
        case ${CLI_ARGS[i]} in
            --port) PG_PORT="${CLI_ARGS[i+1]}" ;;
            --host) PG_HOST="${CLI_ARGS[i+1]}" ;;
            --dbname) PG_DBNAME="${CLI_ARGS[i+1]}" ;;
            --user) PG_USER="${CLI_ARGS[i+1]}" ;;
            --password) PG_PASSWORD="${CLI_ARGS[i+1]}" ;;
            --db-type) DB_TYPE="${CLI_ARGS[i+1]}" ;;
            --sqlite-path) SQLITE_DB_PATH="${CLI_ARGS[i+1]}" ;;
        esac
    done
}

# ============================================================================
# INTERACTIVE QUESTIONNAIRE
# ============================================================================
run_questionnaire() {
    echo
    log_info "========================================"
    log_info "  Webshop Database - First Time Setup  "
    log_info "========================================"
    echo
    log_info "No .env file found. Let's create one with your configuration."
    log_info "Press Enter to accept defaults shown in [brackets]."
    echo

    # Database type
    while true; do
        log_prompt "Database type [postgresql/sqlite]: "
        read -r input
        input="${input:-postgresql}"
        if [[ "$input" == "postgresql" || "$input" == "sqlite" ]]; then
            DB_TYPE="$input"
            break
        else
            log_error "Please enter 'postgresql' or 'sqlite'"
        fi
    done

    if [[ "$DB_TYPE" == "postgresql" ]]; then
        # PostgreSQL configuration
        echo
        log_info "--- PostgreSQL Configuration ---"
        
        log_prompt "Host [$PG_HOST]: "
        read -r input
        PG_HOST="${input:-$PG_HOST}"

        log_prompt "Port [$PG_PORT]: "
        read -r input
        PG_PORT="${input:-$PG_PORT}"

        log_prompt "Database name [$PG_DBNAME]: "
        read -r input
        PG_DBNAME="${input:-$PG_DBNAME}"

        log_prompt "Username [$PG_USER]: "
        read -r input
        PG_USER="${input:-$PG_USER}"

        while true; do
            log_prompt "Password (leave empty for no password / peer auth): "
            read -rs input
            echo
            if [[ -n "$input" ]]; then
                PG_PASSWORD="$input"
                log_prompt "Confirm password: "
                read -rs confirm
                echo
                if [[ "$input" == "$confirm" ]]; then
                    break
                else
                    log_error "Passwords don't match. Try again."
                fi
            else
                PG_PASSWORD=""
                log_warn "No password set - using peer/trust authentication"
                break
            fi
        done

    else
        # SQLite configuration
        echo
        log_info "--- SQLite Configuration ---"
        log_prompt "Database file path [$SQLITE_DB_PATH]: "
        read -r input
        SQLITE_DB_PATH="${input:-$SQLITE_DB_PATH}"
    fi

    # Common options
    echo
    log_info "--- Setup Behavior ---"
    log_prompt "Auto-create database if missing? [Y/n]: "
    read -r input
    AUTO_CREATE_DB="${input:-Y}"
    [[ "${AUTO_CREATE_DB,,}" =~ ^(n|no)$ ]] && AUTO_CREATE_DB="false" || AUTO_CREATE_DB="true"

    log_prompt "Auto-run schema migration? [Y/n]: "
    read -r input
    AUTO_RUN_SCHEMA="${input:-Y}"
    [[ "${AUTO_RUN_SCHEMA,,}" =~ ^(n|no)$ ]] && AUTO_RUN_SCHEMA="false" || AUTO_RUN_SCHEMA="true"

    # Write .env
    write_env_file
}

write_env_file() {
    log_info "Writing configuration to .env..."
    cat > "$ENV_FILE" <<EOF
# Webshop Database Configuration
# Generated by setup_db.sh on $(date)
# DO NOT COMMIT THIS FILE

# ============================================================================
# DATABASE CONNECTION
# ============================================================================
DB_TYPE=$DB_TYPE

# PostgreSQL settings
PG_HOST=$PG_HOST
PG_PORT=$PG_PORT
PG_DBNAME=$PG_DBNAME
PG_USER=$PG_USER
PG_PASSWORD=$PG_PASSWORD

# SQLite settings
SQLITE_DB_PATH=$SQLITE_DB_PATH

# ============================================================================
# SETUP BEHAVIOR
# ============================================================================
AUTO_CREATE_DB=$AUTO_CREATE_DB
AUTO_RUN_SCHEMA=$AUTO_RUN_SCHEMA
EOF
    chmod 600 "$ENV_FILE"
    log_success "Configuration saved to .env (permissions set to 600)"
    echo
}

# ============================================================================
# POSTGRESQL FUNCTIONS
# ============================================================================
check_postgres() {
    command -v psql >/dev/null 2>&1
}

test_pg_connection() {
    PGPASSWORD="$PG_PASSWORD" psql \
        -h "$PG_HOST" \
        -p "$PG_PORT" \
        -U "$PG_USER" \
        -d "postgres" \
        -c "SELECT 1;" >/dev/null 2>&1
}

create_pg_database() {
    if [[ "$AUTO_CREATE_DB" != "true" ]]; then
        return 0
    fi
    log_info "Creating database '$PG_DBNAME'..."
    PGPASSWORD="$PG_PASSWORD" psql \
        -h "$PG_HOST" \
        -p "$PG_PORT" \
        -U "$PG_USER" \
        -d "postgres" \
        -c "CREATE DATABASE $PG_DBNAME;" 2>/dev/null || {
        log_warn "Database '$PG_DBNAME' may already exist"
    }
}

run_pg_schema() {
    if [[ "$AUTO_RUN_SCHEMA" != "true" ]]; then
        return 0
    fi
    log_info "Running schema.sql against '$PG_DBNAME'..."
    PGPASSWORD="$PG_PASSWORD" psql \
        -h "$PG_HOST" \
        -p "$PG_PORT" \
        -U "$PG_USER" \
        -d "$PG_DBNAME" \
        -f "$SCHEMA_FILE" \
        -v ON_ERROR_STOP=1
}

verify_pg_schema() {
    log_info "Verifying schema..."
    local table_count
    table_count=$(PGPASSWORD="$PG_PASSWORD" psql \
        -h "$PG_HOST" \
        -p "$PG_PORT" \
        -U "$PG_USER" \
        -d "$PG_DBNAME" \
        -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | xargs)
    log_success "Schema verified: $table_count tables"
}

save_pg_config() {
    cat > "${SCRIPT_DIR}/.db_config" <<EOF
DB_TYPE=postgresql
PG_HOST=$PG_HOST
PG_PORT=$PG_PORT
PG_DBNAME=$PG_DBNAME
PG_USER=$PG_USER
PG_PASSWORD=$PG_PASSWORD
EOF
    log_success "Connection config saved to .db_config"
}

# ============================================================================
# SQLITE FUNCTIONS
# ============================================================================
check_sqlite() {
    command -v sqlite3 >/dev/null 2>&1
}

setup_sqlite() {
    log_info "Setting up SQLite database at $SQLITE_DB_PATH"
    local sqlite_schema="${SCRIPT_DIR}/schema.sqlite.sql"
    
    log_info "Converting schema for SQLite..."
    sed \
        -e 's/BIGINT GENERATED ALWAYS AS IDENTITY/INTEGER PRIMARY KEY AUTOINCREMENT/g' \
        -e 's/BIGINT/INTEGER/g' \
        -e 's/TIMESTAMPTZ/DATETIME/g' \
        -e 's/NUMERIC(9,6)/REAL/g' \
        -e 's/BYTEA/BLOB/g' \
        -e 's/CHAR(3)/VARCHAR(3)/g' \
        -e 's/LOWER(email)/email/g' \
        -e 's/CREATE UNIQUE INDEX uq_users_email_lower ON users (LOWER(email));/CREATE UNIQUE INDEX uq_users_email_lower ON users (email);/g' \
        -e '/CREATE EXTENSION/d' \
        -e '/CREATE ROLE/d' \
        -e '/GRANT/d' \
        -e '/COMMENT ON/d' \
        "$SCHEMA_FILE" > "$sqlite_schema"
    
    log_info "Creating SQLite database..."
    sqlite3 "$SQLITE_DB_PATH" < "$sqlite_schema"
    
    cat > "${SCRIPT_DIR}/.db_config" <<EOF
DB_TYPE=sqlite
SQLITE_DB_PATH=$SQLITE_DB_PATH
EOF
    log_success "SQLite database created. Config saved to .db_config"
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    parse_args "$@"
    
    log_info "Webshop Database Setup"
    log_info "========================"
    
    if [[ ! -f "$SCHEMA_FILE" ]]; then
        log_error "Schema file not found: $SCHEMA_FILE"
        exit 1
    fi
    
    load_env
    
    # Run questionnaire if no .env and not non-interactive
    if [[ ! -f "$ENV_FILE" && "$NON_INTERACTIVE" != "true" ]]; then
        run_questionnaire
        # Reload the new .env
        load_env
    elif [[ "$NON_INTERACTIVE" == "true" && ! -f "$ENV_FILE" ]]; then
        log_info "Running in non-interactive mode with defaults"
    fi
    
    # Execute based on DB_TYPE
    if [[ "$DB_TYPE" == "postgresql" ]]; then
        if check_postgres && test_pg_connection; then
            log_success "PostgreSQL connection successful"
            create_pg_database
            run_pg_schema
            verify_pg_schema
            save_pg_config
        else
            log_warn "PostgreSQL not available or connection failed"
            if check_sqlite; then
                log_info "Falling back to SQLite..."
                setup_sqlite
            else
                log_error "PostgreSQL connection failed and sqlite3 not found"
                exit 1
            fi
        fi
    else
        # SQLite mode
        if check_sqlite; then
            setup_sqlite
        else
            log_error "sqlite3 not found in PATH"
            exit 1
        fi
    fi
    
    log_success "Setup complete!"
    echo
    log_info "Next steps:"
    log_info "  1. Review .env and adjust if needed"
    log_info "  2. For Flask backend, copy .db_config values to backend/.env"
    log_info "  3. Run migrations with: flask db upgrade"
}

main "$@"