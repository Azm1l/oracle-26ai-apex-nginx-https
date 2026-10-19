#!/usr/bin/env bash
# Set the APEX instance administrator password (INTERNAL workspace, user
# ADMIN) to APEX_ADMIN_PWD from .env.
#
# Run once after the first `docker compose up -d` has finished installing APEX.
# The silent installer the ORDS container uses gives ADMIN a fixed, publicly
# known password - this replaces it. Re-run any time to change it again.
#
#   ./scripts/set-admin-password.sh
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; [[ -f .env ]] && source <(tr -d '\r' < .env); set +a
: "${ORACLE_PWD:?ORACLE_PWD not set in .env}"
: "${APEX_ADMIN_PWD:?APEX_ADMIN_PWD not set in .env}"
DB_CONTAINER="${DB_CONTAINER:-ora26ai-db}"
# Git Bash on Windows rewrites arguments that look like paths ("/nolog")
# into Windows paths before Docker sees them. Turn that off.
export MSYS_NO_PATHCONV=1

case "$APEX_ADMIN_PWD$ORACLE_PWD" in
  *'"'*|*'~'*) echo 'Passwords must not contain " or ~' >&2; exit 1 ;;
esac

# The SQL (passwords included) goes to SQL*Plus over stdin, so no password
# ever appears on a command line or in the container's process list.
docker exec -i "$DB_CONTAINER" sqlplus -s /nolog <<SQL
whenever sqlerror exit failure
connect sys/"${ORACLE_PWD}"@localhost:1521/FREEPDB1 as sysdba
set feedback off verify off define off
declare
  l_schema varchar2(128);
begin
  -- APEX's API packages live in the versioned APEX schema (APEX_260200 for 26.2).
  select schema into l_schema from dba_registry where comp_id = 'APEX';
  execute immediate 'alter session set current_schema = ' || l_schema;
end;
/
begin
  apex_util.set_workspace(p_workspace => 'INTERNAL');
  apex_util.edit_user(
    p_user_id                      => apex_util.get_user_id('ADMIN'),
    p_user_name                    => 'ADMIN',
    p_web_password                 => q'~${APEX_ADMIN_PWD}~',
    p_new_password                 => q'~${APEX_ADMIN_PWD}~',
    p_change_password_on_first_use => 'N');
  apex_util.unlock_account(p_user_name => 'ADMIN');
  commit;
end;
/
exit
SQL
echo "OK: APEX instance administrator password updated."
echo "Sign in at http://localhost:${ORDS_PORT:-8080}/ords/apex  -> workspace INTERNAL, user ADMIN."