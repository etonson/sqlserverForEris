#!/bin/bash
set -euo pipefail

# ---------- 設定變數 ----------
DB_NAME="hccg"
BACKUP_DIR="/var/opt/mssql/backup"
DATA_DIR="/var/opt/mssql/data"

# 偵測最新的 .bak 檔案
BACKUP_FILE=$(ls -t "$BACKUP_DIR"/*.bak 2>/dev/null | head -n 1)

if [ -z "$BACKUP_FILE" ]; then
  echo "❌ 找不到備份檔 (.bak) 在 $BACKUP_DIR"
  exit 1
fi

echo "偵測到備份檔：$BACKUP_FILE"

# ---------- 啟動 SQL Server ----------
/opt/mssql/bin/sqlservr &

# ---------- 等待 SQL Server 準備就緒 ----------
echo "正在等待 SQL Server 啟動..."
until /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -Q "SELECT 1" > /dev/null 2>&1; do
  sleep 5
done
echo "✅ SQL Server 已啟動。"

# ---------- 檢查資料庫是否已存在 ----------
db_exists=$(/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" \
  -Q "IF DB_ID('$DB_NAME') IS NOT NULL PRINT 1 ELSE PRINT 0" -h -1)
db_exists=$(echo "$db_exists" | tr -d '[:space:]')

if [ "$db_exists" = "1" ]; then
  echo "資料庫 '$DB_NAME' 已存在，跳過還原。"
else
  echo "資料庫 '$DB_NAME' 不存在，開始還原..."

  # ---------- 自動抓邏輯檔名 ----------
  mapfile -t logical_names < <(/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" \
    -Q "RESTORE FILELISTONLY FROM DISK = N'$BACKUP_FILE'" -h -1 | awk '{print $1}' | sed -n '1p;2p')

  DATA_LOGICAL=${logical_names[0]}
  LOG_LOGICAL=${logical_names[1]}
  echo "偵測到邏輯名稱：資料檔 = $DATA_LOGICAL, 日誌檔 = $LOG_LOGICAL"

  # ---------- 執行還原 ----------
  /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -Q "
  RESTORE DATABASE [$DB_NAME]
  FROM DISK = N'$BACKUP_FILE'
  WITH MOVE N'$DATA_LOGICAL' TO N'$DATA_DIR/$DB_NAME.mdf',
       MOVE N'$LOG_LOGICAL' TO N'$DATA_DIR/${DB_NAME}_log.ldf',
       REPLACE, STATS = 5"

  echo "✅ 資料庫還原完成。"
fi

# ---------- 將 SQL Server 轉到前景，保持容器運行 ----------
wait

