@echo off
REM Webshop Database Setup Script (Windows)
REM Creates and initializes the PostgreSQL database for the webshop project
REM Usage: setup_db.bat [options]
REM Options:
REM   --port PORT           PostgreSQL port (default: 5432)
REM   --host HOST           PostgreSQL host (default: localhost)
REM   --dbname NAME         Database name (default: webshop)
REM   --user USER           PostgreSQL user (default: postgres)
REM   --password PASS       PostgreSQL password (default: from env PGPASSWORD)
REM   --db-type TYPE        Database type: postgresql or sqlite (default: postgresql)
REM   --sqlite-path PATH    SQLite database path (default: .\webshop.sqlite)
REM   --non-interactive     Run without prompts (use .env or defaults)
REM   --help                Show this help

setlocal enabledelayedexpansion

REM ============================================================================
REM CONFIGURATION DEFAULTS
REM ============================================================================
set SCRIPT_DIR=%~dp0
set ENV_FILE=%SCRIPT_DIR%.env
set SCHEMA_FILE=%SCRIPT_DIR%schema.sql

REM Default values (overridden by .env, then CLI args)
set DB_TYPE=postgresql
set PG_HOST=localhost
set PG_PORT=5432
set PG_DBNAME=webshop
set PG_USER=postgres
set PG_PASSWORD=
set SQLITE_DB_PATH=%SCRIPT_DIR%webshop.sqlite
set AUTO_CREATE_DB=true
set AUTO_RUN_SCHEMA=true

REM CLI flags
set NON_INTERACTIVE=false

REM Colors (using ANSI codes - works in Windows 10+)
set RED=\033[0;31m
set GREEN=\033[0;32m
set YELLOW=\033[1;33m
set BLUE=\033[0;34m
set CYAN=\033[0;36m
set NC=\033[0m

REM ============================================================================
REM HELPER FUNCTIONS
REM ============================================================================
call :log_info "Webshop Database Setup"
call :log_info "========================"

:parse_args
if "%~1"=="" goto :args_done
if "%~1"=="--port" set PG_PORT=%~2 & shift & shift & goto :parse_args
if "%~1"=="--host" set PG_HOST=%~2 & shift & shift & goto :parse_args
if "%~1"=="--dbname" set PG_DBNAME=%~2 & shift & shift & goto :parse_args
if "%~1"=="--user" set PG_USER=%~2 & shift & shift & goto :parse_args
if "%~1"=="--password" set PG_PASSWORD=%~2 & shift & shift & goto :parse_args
if "%~1"=="--db-type" set DB_TYPE=%~2 & shift & shift & goto :parse_args
if "%~1"=="--sqlite-path" set SQLITE_DB_PATH=%~2 & shift & shift & goto :parse_args
if "%~1"=="--non-interactive" set NON_INTERACTIVE=true & shift & goto :parse_args
if "%~1"=="--help" call :show_help & exit /b 0
call :log_error "Unknown option: %~1"
call :show_help
exit /b 1

:args_done

REM ============================================================================
REM LOAD .env FILE
REM ============================================================================
if exist "%ENV_FILE%" (
    call :log_info "Loading configuration from .env"
    for /f "usebackq tokens=1* delims==" %%a in ("%ENV_FILE%") do (
        if not "%%a"=="" if not "%%a:~0,1%"=="#" (
            set "%%a=%%b"
        )
    )
    REM CLI args already set above, they take precedence
) else (
    call :log_info "No .env file found"
    REM Try environment variables
    if not defined PG_PASSWORD set PG_PASSWORD=%PGPASSWORD%
    if not defined PG_HOST set PG_HOST=%PGHOST%
    if not defined PG_PORT set PG_PORT=%PGPORT%
    if not defined PG_DBNAME set PG_DBNAME=%PGDATABASE%
    if not defined PG_USER set PG_USER=%PGUSER%
)

call :log_info "Host: %PG_HOST%"
call :log_info "Port: %PG_PORT%"
call :log_info "Database: %PG_DBNAME%"
call :log_info "User: %PG_USER%"
call :log_info "DB Type: %DB_TYPE%"

if not exist "%SCHEMA_FILE%" (
    call :log_error "Schema file not found: %SCHEMA_FILE%"
    exit /b 1
)

REM ============================================================================
REM INTERACTIVE QUESTIONNAIRE
REM ============================================================================
if not exist "%ENV_FILE%" (
    if "%NON_INTERACTIVE%"=="false" (
        call :run_questionnaire
        REM Reload .env after questionnaire
        for /f "usebackq tokens=1* delims==" %%a in ("%ENV_FILE%") do (
            if not "%%a"=="" if not "%%a:~0,1%"=="#" (
                set "%%a=%%b"
            )
        )
    ) else (
        call :log_info "Running in non-interactive mode with defaults"
    )
)

REM ============================================================================
REM CHECK TOOLS
REM ============================================================================
where psql >nul 2>nul
if %errorlevel% equ 0 (
    set HAS_PSQL=true
) else (
    set HAS_PSQL=false
    call :log_warn "PostgreSQL client (psql) not found in PATH"
)

where sqlite3 >nul 2>nul
if %errorlevel% equ 0 (
    set HAS_SQLITE=true
) else (
    set HAS_SQLITE=false
    call :log_warn "SQLite3 not found in PATH"
)

REM ============================================================================
REM EXECUTE BASED ON DB_TYPE
REM ============================================================================
if "%DB_TYPE%"=="postgresql" (
    if "%HAS_PSQL%"=="true" (
        set PGPASSWORD=%PG_PASSWORD%
        psql -h %PG_HOST% -p %PG_PORT% -U %PG_USER% -d postgres -c "SELECT 1;" >nul 2>nul
        if %errorlevel% equ 0 (
            call :log_success "PostgreSQL connection successful"
            call :create_pg_database
            call :run_pg_schema
            call :verify_pg_schema
            call :save_pg_config
            goto :success
        ) else (
            call :log_warn "PostgreSQL connection failed"
        )
    ) else (
        call :log_warn "PostgreSQL client not available"
    )
    
    REM Fallback to SQLite
    if "%HAS_SQLITE%"=="true" (
        call :log_info "Falling back to SQLite..."
        call :setup_sqlite
        goto :success
    ) else (
        call :log_error "PostgreSQL connection failed and sqlite3 not found"
        exit /b 1
    )
) else if "%DB_TYPE%"=="sqlite" (
    if "%HAS_SQLITE%"=="true" (
        call :setup_sqlite
        goto :success
    ) else (
        call :log_error "sqlite3 not found in PATH"
        exit /b 1
    )
) else (
    call :log_error "Invalid DB_TYPE: %DB_TYPE% (must be postgresql or sqlite)"
    exit /b 1
)

:success
call :log_success "Setup complete!"
echo.
call :log_info "Next steps:"
call :log_info "  1. Review .env and adjust if needed"
call :log_info "  2. For Flask backend, copy .db_config values to backend/.env"
call :log_info "  3. Run migrations with: flask db upgrade"
exit /b 0

REM ============================================================================
REM POSTGRESQL FUNCTIONS
REM ============================================================================
:create_pg_database
if "%AUTO_CREATE_DB%"=="true" (
    call :log_info "Creating database '%PG_DBNAME%'..."
    psql -h %PG_HOST% -p %PG_PORT% -U %PG_USER% -d postgres -c "CREATE DATABASE %PG_DBNAME%;" 2>nul
    if %errorlevel% neq 0 (
        call :log_warn "Database '%PG_DBNAME%' may already exist"
    )
)
goto :eof

:run_pg_schema
if "%AUTO_RUN_SCHEMA%"=="true" (
    call :log_info "Running schema.sql against '%PG_DBNAME%'..."
    psql -h %PG_HOST% -p %PG_PORT% -U %PG_USER% -d %PG_DBNAME% -f "%SCHEMA_FILE%" -v ON_ERROR_STOP=1
    if %errorlevel% neq 0 (
        call :log_error "Schema execution failed"
        exit /b 1
    )
)
goto :eof

:verify_pg_schema
call :log_info "Verifying schema..."
for /f "tokens=*" %%a in ('psql -h %PG_HOST% -p %PG_PORT% -U %PG_USER% -d %PG_DBNAME% -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" 2^>nul') do set TABLE_COUNT=%%a
call :log_success "Schema verified: %TABLE_COUNT% tables"
goto :eof

:save_pg_config
echo DB_TYPE=postgresql > "%SCRIPT_DIR%.db_config"
echo PG_HOST=%PG_HOST% >> "%SCRIPT_DIR%.db_config"
echo PG_PORT=%PG_PORT% >> "%SCRIPT_DIR%.db_config"
echo PG_DBNAME=%PG_DBNAME% >> "%SCRIPT_DIR%.db_config"
echo PG_USER=%PG_USER% >> "%SCRIPT_DIR%.db_config"
echo PG_PASSWORD=%PG_PASSWORD% >> "%SCRIPT_DIR%.db_config"
call :log_success "Connection config saved to .db_config"
goto :eof

REM ============================================================================
REM SQLITE FUNCTIONS
REM ============================================================================
:setup_sqlite
call :log_info "Setting up SQLite database at %SQLITE_DB_PATH%"
set SQLITE_SCHEMA=%SCRIPT_DIR%schema.sqlite.sql

call :log_info "Converting schema for SQLite..."
powershell -NoProfile -Command ^
    "(Get-Content '%SCHEMA_FILE%' -Raw) ^
    -replace 'BIGINT GENERATED ALWAYS AS IDENTITY', 'INTEGER PRIMARY KEY AUTOINCREMENT' ^
    -replace 'BIGINT', 'INTEGER' ^
    -replace 'TIMESTAMPTZ', 'DATETIME' ^
    -replace 'NUMERIC\(9,6\)', 'REAL' ^
    -replace 'BYTEA', 'BLOB' ^
    -replace 'CHAR\(3\)', 'VARCHAR(3)' ^
    -replace 'LOWER\(email\)', 'email' ^
    -replace 'CREATE UNIQUE INDEX uq_users_email_lower ON users \(LOWER\(email\)\);', 'CREATE UNIQUE INDEX uq_users_email_lower ON users (email);' ^
    -replace '(?m)^CREATE EXTENSION.*$', '' ^
    -replace '(?m)^CREATE ROLE.*$', '' ^
    -replace '(?m)^GRANT.*$', '' ^
    -replace '(?m)^COMMENT ON.*$', '' ^
    | Set-Content '%SQLITE_SCHEMA%' -Encoding UTF8"

call :log_info "Creating SQLite database..."
sqlite3 "%SQLITE_DB_PATH%" < "%SQLITE_SCHEMA%"
if %errorlevel% neq 0 (
    call :log_error "SQLite database creation failed"
    exit /b 1
)

echo DB_TYPE=sqlite > "%SCRIPT_DIR%.db_config"
echo SQLITE_DB_PATH=%SQLITE_DB_PATH% >> "%SCRIPT_DIR%.db_config"
call :log_success "SQLite database created at %SQLITE_DB_PATH%"
goto :eof

REM ============================================================================
REM QUESTIONNAIRE
REM ============================================================================
:run_questionnaire
echo.
call :log_info "========================================"
call :log_info "  Webshop Database - First Time Setup  "
call :log_info "========================================"
echo.
call :log_info "No .env file found. Let's create one with your configuration."
call :log_info "Press Enter to accept defaults shown in [brackets]."
echo.

REM Database type
:ask_db_type
call :log_prompt "Database type [postgresql/sqlite]: "
set /p INPUT=
if "!INPUT!"=="" set INPUT=postgresql
if /i "!INPUT!"=="postgresql" set DB_TYPE=postgresql & goto :db_type_done
if /i "!INPUT!"=="sqlite" set DB_TYPE=sqlite & goto :db_type_done
call :log_error "Please enter 'postgresql' or 'sqlite'"
goto :ask_db_type

:db_type_done

if "%DB_TYPE%"=="postgresql" (
    echo.
    call :log_info "--- PostgreSQL Configuration ---"
    
    call :log_prompt "Host [%PG_HOST%]: "
    set /p INPUT=
    if not "!INPUT!"=="" set PG_HOST=!INPUT!
    
    call :log_prompt "Port [%PG_PORT%]: "
    set /p INPUT=
    if not "!INPUT!"=="" set PG_PORT=!INPUT!
    
    call :log_prompt "Database name [%PG_DBNAME%]: "
    set /p INPUT=
    if not "!INPUT!"=="" set PG_DBNAME=!INPUT!
    
    call :log_prompt "Username [%PG_USER%]: "
    set /p INPUT=
    if not "!INPUT!"=="" set PG_USER=!INPUT!
    
    :ask_pg_password
    call :log_prompt "Password (leave empty for no password / peer auth): "
    set "INPUT="
    for /f "delims=" %%a in ('powershell -Command "$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown'); $pwd = ''; while ($true) { $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown'); if ($key.VirtualKeyCode -eq 13) { break } elseif ($key.VirtualKeyCode -eq 8) { if ($pwd.Length -gt 0) { $pwd = $pwd.Substring(0,$pwd.Length-1); Write-Host -NoNewline "`b \b" } } else { $pwd += $key.Character; Write-Host -NoNewline '*' } }; Write-Host ''; $pwd"') do set "INPUT=%%a"
    echo.
    if "!INPUT!"=="" (
        set PG_PASSWORD=
        call :log_warn "No password set - using peer/trust authentication"
    ) else (
        set PG_PASSWORD=!INPUT!
        call :log_prompt "Confirm password: "
        set "CONFIRM="
        for /f "delims=" %%a in ('powershell -Command "$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown'); $pwd = ''; while ($true) { $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown'); if ($key.VirtualKeyCode -eq 13) { break } elseif ($key.VirtualKeyCode -eq 8) { if ($pwd.Length -gt 0) { $pwd = $pwd.Substring(0,$pwd.Length-1); Write-Host -NoNewline "`b \b" } } else { $pwd += $key.Character; Write-Host -NoNewline '*' } }; Write-Host ''; $pwd"') do set "CONFIRM=%%a"
        echo.
        if "!PG_PASSWORD!"=="!CONFIRM!" (
            goto :password_done
        ) else (
            call :log_error "Passwords don't match. Try again."
            goto :ask_pg_password
        )
    )
    :password_done
) else (
    echo.
    call :log_info "--- SQLite Configuration ---"
    call :log_prompt "Database file path [%SQLITE_DB_PATH%]: "
    set /p INPUT=
    if not "!INPUT!"=="" set SQLITE_DB_PATH=!INPUT!
)

REM Common options
echo.
call :log_info "--- Setup Behavior ---"
call :log_prompt "Auto-create database if missing? [Y/n]: "
set /p INPUT=
if "!INPUT!"=="" set INPUT=Y
if /i "!INPUT!"=="Y" set AUTO_CREATE_DB=true
if /i "!INPUT!"=="N" set AUTO_CREATE_DB=false

call :log_prompt "Auto-run schema migration? [Y/n]: "
set /p INPUT=
if "!INPUT!"=="" set INPUT=Y
if /i "!INPUT!"=="Y" set AUTO_RUN_SCHEMA=true
if /i "!INPUT!"=="N" set AUTO_RUN_SCHEMA=false

REM Write .env
call :write_env_file
goto :eof

:write_env_file
call :log_info "Writing configuration to .env..."
(
    echo # Webshop Database Configuration
    echo # Generated by setup_db.bat on %DATE% %TIME%
    echo # DO NOT COMMIT THIS FILE
    echo.
    echo # ============================================================================
    echo # DATABASE CONNECTION
    echo # ============================================================================
    echo DB_TYPE=%DB_TYPE%
    echo.
    echo # PostgreSQL settings
    echo PG_HOST=%PG_HOST%
    echo PG_PORT=%PG_PORT%
    echo PG_DBNAME=%PG_DBNAME%
    echo PG_USER=%PG_USER%
    echo PG_PASSWORD=%PG_PASSWORD%
    echo.
    echo # SQLite settings
    echo SQLITE_DB_PATH=%SQLITE_DB_PATH%
    echo.
    echo # ============================================================================
    echo # SETUP BEHAVIOR
    echo # ============================================================================
    echo AUTO_CREATE_DB=%AUTO_CREATE_DB%
    echo AUTO_RUN_SCHEMA=%AUTO_RUN_SCHEMA%
) > "%ENV_FILE%"

REM Set file permissions (Windows - restrict to current user)
icacls "%ENV_FILE%" /inheritance:r /grant:r "%USERNAME%:F" >nul 2>&1

call :log_success "Configuration saved to .env (permissions restricted to current user)"
echo.
goto :eof

REM ============================================================================
REM LOGGING FUNCTIONS
REM ============================================================================
:log_info
echo %BLUE%[INFO]%NC% %*
goto :eof

:log_success
echo %GREEN%[SUCCESS]%NC% %*
goto :eof

:log_warn
echo %YELLOW%[WARN]%NC% %*
goto :eof

:log_error
echo %RED%[ERROR]%NC% %*
goto :eof

:log_prompt
echo %CYAN%[PROMPT]%NC% %*
goto :eof

:show_help
echo Webshop Database Setup Script
echo.
echo Usage: %~nx0 [options]
echo.
echo Options:
echo   --port PORT           PostgreSQL port (default: 5432)
echo   --host HOST           PostgreSQL host (default: localhost)
echo   --dbname NAME         Database name (default: webshop)
echo   --user USER           PostgreSQL user (default: postgres)
echo   --password PASS       PostgreSQL password (or set PGPASSWORD env var)
echo   --db-type TYPE        Database type: postgresql or sqlite (default: postgresql)
echo   --sqlite-path PATH    SQLite database file path (default: .\webshop.sqlite)
echo   --non-interactive     Run without prompts (use .env or defaults)
echo   --help                Show this help
echo.
echo Configuration priority (highest to lowest):
echo   1. CLI arguments
echo   2. .env file
echo   3. Environment variables (PGPASSWORD, PGHOST, etc.)
echo   4. Defaults
echo.
echo First run: If .env doesn't exist, an interactive questionnaire will guide you
echo through creating it. Use --non-interactive to skip prompts.
echo.
echo Examples:
echo   %~nx0
echo   %~nx0 --non-interactive
echo   %~nx0 --port 5433 --dbname myshop
echo   %~nx0 --db-type sqlite --non-interactive
goto :eof