#!/usr/bin/env bash
# --------------------------------------------------------------------
# File     : stations/test-pg_jieba.sh
# Purpose  : Test the pg_jieba extension in a running Cloudberry (Greenplum) cluster.
# --------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# Load shared environment
# shellcheck disable=SC1091
[ -f config/env.sh ] && . config/env.sh

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLOUDBERRY_PATH_SH="/usr/local/cloudberry/greenplum_path.sh"
CLOUDBERRY_DEMO_ENV="$PROJECT_ROOT/parts/cloudberry/gpAux/gpdemo/gpdemo-env.sh"

# Helpers
section()         { echo "==> $1..."; }
section_complete(){ echo "✅ $1 complete (duration: $(($(date +%s) - $2))s)"; }
log()             { printf "[%s] %s\n" "$(date '+%H:%M:%S')" "$*"; }

section "test pg_jieba"
start_time=$(date +%s)

# Load PostgreSQL/Greenplum environment
if [[ -f "$CLOUDBERRY_PATH_SH" ]]; then
  source "$CLOUDBERRY_PATH_SH"
else
  echo "[test-pg_jieba] ERROR: greenplum_path.sh not found at $CLOUDBERRY_PATH_SH" >&2
  exit 1
fi

if [[ -f "$CLOUDBERRY_DEMO_ENV" ]]; then
  source "$CLOUDBERRY_DEMO_ENV"
else
  echo "[test-pg_jieba] ERROR: gpdemo-env.sh not found at $CLOUDBERRY_DEMO_ENV" >&2
  exit 1
fi

# Run SQL validation
log "Creating extension and verifying tokenizer output"
psql -v ON_ERROR_STOP=1 -d template1 <<'SQL'
DROP EXTENSION IF EXISTS pg_jieba CASCADE;
CREATE EXTENSION pg_jieba;

DROP TEXT SEARCH CONFIGURATION IF EXISTS chinese_jieba CASCADE;
CREATE TEXT SEARCH CONFIGURATION chinese_jieba (PARSER = jieba);
ALTER TEXT SEARCH CONFIGURATION chinese_jieba
  ALTER MAPPING FOR eng, n, nr, ns, nt, nz, v, vn, a, ad, an
  WITH simple;

SELECT * FROM ts_debug('chinese_jieba', '我来到北京清华大学');
SELECT to_tsvector('chinese_jieba', '我来到北京清华大学');
SELECT to_tsquery('chinese_jieba', '北京 & 清华大学');

DROP TEXT SEARCH CONFIGURATION chinese_jieba;
DROP EXTENSION pg_jieba;
SQL

section_complete "test pg_jieba" "$start_time"
