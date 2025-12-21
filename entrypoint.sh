#!/bin/bash
set -euo pipefail

BACKUP_DIR="/var/opt/mssql/backup"
DATA_DIR="/var/opt/mssql/data"

# ---------- 啟動 SQL Server ----------
/opt/mssql/bin/sqlservr &

# ---------- 等待 SQL Server ----------
echo "正在等待 SQL Server 啟動..."
until /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -Q "SELECT 1" > /dev/null 2>&1; do
  sleep 5
done
echo "SQL Server 已啟動。"

# ---------- 掃描所有 .bak ----------
shopt -s nullglob
BAK_FILES=("$BACKUP_DIR"/*.bak)

if [ ${#BAK_FILES[@]} -eq 0 ]; then
  echo " 找不到任何 .bak 檔案"
  exit 1
fi

for BACKUP_FILE in "${BAK_FILES[@]}"; do
  DB_NAME=$(basename "$BACKUP_FILE" .bak)

  echo "======================================"
  echo "處理備份檔：$BACKUP_FILE"
  echo "目標資料庫：$DB_NAME"

  # ---------- 檢查 DB 是否存在 ----------
  db_exists=$(/opt/mssql-tools/bin/sqlcmd -S localhost -U "$USER_NAME" -P "$SA_PASSWORD" \
    -Q "IF DB_ID('$DB_NAME') IS NOT NULL PRINT 1 ELSE PRINT 0" -h -1 | tr -d '[:space:]')

  if [ "$db_exists" = "1" ]; then
    echo "資料庫 '$DB_NAME' 已存在，跳過。"
    continue
  fi

  echo "開始還原 '$DB_NAME'..."

  # ---------- 取得邏輯檔名 ----------
  mapfile -t logical_names < <(
    /opt/mssql-tools/bin/sqlcmd -S localhost -U "$USER_NAME" -P "$SA_PASSWORD" \
      -Q "RESTORE FILELISTONLY FROM DISK = N'$BACKUP_FILE'" -h -1 |
      awk '{print $1}'
  )

  DATA_LOGICAL=${logical_names[0]}
  LOG_LOGICAL=${logical_names[1]}

  echo "邏輯檔名：DATA=$DATA_LOGICAL, LOG=$LOG_LOGICAL"

  # ---------- 還原 ----------
  /opt/mssql-tools/bin/sqlcmd -S localhost -U "$USER_NAME" -P "$SA_PASSWORD" -Q "
    RESTORE DATABASE [$DB_NAME]
    FROM DISK = N'$BACKUP_FILE'
    WITH MOVE N'$DATA_LOGICAL' TO N'$DATA_DIR/$DB_NAME.mdf',
         MOVE N'$LOG_LOGICAL' TO N'$DATA_DIR/${DB_NAME}_log.ldf',
         REPLACE, STATS = 5
  "

  echo " '$DB_NAME' 還原完成"
done

# ---------- 保持容器 ----------
wait

