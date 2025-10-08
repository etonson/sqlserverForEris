#!/bin/bash

# 設定變數
DB_NAME="PTPMSDB"
BACKUP_FILE="/var/opt/mssql/backup/PTPMSDB.bak"
DATA_DIR="/var/opt/mssql/data"

# 1. 在背景啟動 SQL Server
/opt/mssql/bin/sqlservr &

# 2. 等待 SQL Server 準備就緒
echo "正在等待 SQL Server 啟動..."
# 使用 healthcheck 的指令來檢查服務是否可用
until /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -Q "SELECT 1" > /dev/null 2>&1; do
  sleep 5
done
echo "SQL Server 已啟動。"

# 3. 檢查資料庫是否已經存在
db_exists=$(/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -Q "IF DB_ID('$DB_NAME') IS NOT NULL PRINT 1 ELSE PRINT 0")

# 去除 sqlcmd 可能產生的多餘空白和換行
db_exists=$(echo $db_exists | tr -d '[:space:]')

if [ "$db_exists" = "1" ]; then
  # 4. 如果資料庫已存在，跳過還原
  echo "資料庫 '$DB_NAME' 已存在，跳過還原步驟。"
else
  # 5. 如果資料庫不存在，從備份檔還原
  echo "資料庫 '$DB_NAME' 不存在，開始從 '$BACKUP_FILE' 還原..."
  /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -Q "RESTORE DATABASE [$DB_NAME] FROM DISK = N'$BACKUP_FILE' WITH FILE = 1, MOVE N'PTPMSDB' TO N'$DATA_DIR/$DB_NAME.mdf', MOVE N'PTPMSDB_log' TO N'$DATA_DIR/${DB_NAME}_log.ldf', NOUNLOAD, REPLACE, STATS = 5"
  echo "資料庫還原完成。"
fi

# 6. 將 SQL Server 程序轉到前景，以保持容器運行
wait