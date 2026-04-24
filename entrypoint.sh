#!/bin/bash
set -euo pipefail

BACKUP_ROOT="/var/opt/mssql/backups"
DATA_DIR="/var/opt/mssql/data"

# ---------- 啟動 SQL Server (背景執行) ----------
/opt/mssql/bin/sqlservr &

# ---------- 等待 SQL Server Ready ----------
echo "==> 正在等待 SQL Server 啟動..."
until /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -Q "SELECT 1" > /dev/null 2>&1; do
  sleep 5
done
echo "==> SQL Server 已啟動。"

# ---------- 決定要還原哪些資料庫 ----------
# 優先順序：
# 1. 如果有 RESTORE_DB 環境變數，則只還原該 DB
# 2. 如果沒有，則掃描 $BACKUP_ROOT 下的所有子目錄或 .bak 檔案

restore_database() {
    local DB_NAME=$1
    local BAK_PATH=$2

    echo "----------------------------------------------------"
    echo "目標資料庫：$DB_NAME"
    echo "備份檔路徑：$BAK_PATH"

    # 檢查資料庫是否已存在
    local db_exists=$(/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" \
        -Q "SET NOCOUNT ON; IF DB_ID('$DB_NAME') IS NOT NULL PRINT 1 ELSE PRINT 0" -h -1 | tr -d '[:space:]')

    if [ "$db_exists" = "1" ]; then
        echo "[跳過] 資料庫 '$DB_NAME' 已存在。"
        return
    fi

    echo "[開始] 正在從備份還原 '$DB_NAME'..."

    # 提取邏輯檔名 (Data 和 Log)
    # 使用 RESTORE FILELISTONLY，並配合 -s "," 與 -W 來處理可能包含空格的路徑
    local FILE_LIST
    FILE_LIST=$(/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" \
        -Q "SET NOCOUNT ON; RESTORE FILELISTONLY FROM DISK = N'$BAK_PATH'" -h -1 -s "," -W)

    local DATA_LOGICAL
    DATA_LOGICAL=$(echo "$FILE_LIST" | awk -F"," '{for(i=3;i<=NF;i++) {t=$i; gsub(/^[ \t]+|[ \t]+$/, "", t); if(t=="D") {n=$1; gsub(/^[ \t]+|[ \t]+$/, "", n); print n; exit}}}')
    local LOG_LOGICAL
    LOG_LOGICAL=$(echo "$FILE_LIST" | awk -F"," '{for(i=3;i<=NF;i++) {t=$i; gsub(/^[ \t]+|[ \t]+$/, "", t); if(t=="L") {n=$1; gsub(/^[ \t]+|[ \t]+$/, "", n); print n; exit}}}')

    if [ -z "$DATA_LOGICAL" ] || [ -z "$LOG_LOGICAL" ]; then
        echo "[錯誤] 無法從 $BAK_PATH 提取邏輯檔名。"
        echo "[調試] sqlcmd 輸出結果如下："
        echo "$FILE_LIST"
        return
    fi

    echo "邏輯檔名：Data='$DATA_LOGICAL', Log='$LOG_LOGICAL'"

    # 執行還原
    /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -Q "
        RESTORE DATABASE [$DB_NAME]
        FROM DISK = N'$BAK_PATH'
        WITH MOVE N'$DATA_LOGICAL' TO N'$DATA_DIR/$DB_NAME.mdf',
             MOVE N'$LOG_LOGICAL' TO N'$DATA_DIR/${DB_NAME}_log.ldf',
             REPLACE, STATS = 10;
    "
    echo "[成功] '$DB_NAME' 還原完成。"
}

if [ -n "${RESTORE_DB:-}" ]; then
    echo "==> 指定還原單一資料庫：$RESTORE_DB"
    # 檢查多種可能路徑：
    # 1. backups/RESTORE_DB/latest.bak (建議結構)
    # 2. backups/RESTORE_DB.bak (舊有結構)
    if [ -f "$BACKUP_ROOT/$RESTORE_DB/latest.bak" ]; then
        restore_database "$RESTORE_DB" "$BACKUP_ROOT/$RESTORE_DB/latest.bak"
    elif [ -f "$BACKUP_ROOT/$RESTORE_DB.bak" ]; then
        restore_database "$RESTORE_DB" "$BACKUP_ROOT/$RESTORE_DB.bak"
    else
        echo "[錯誤] 找不到資料庫 $RESTORE_DB 的備份檔。"
    fi
else
    echo "==> 掃描所有備份檔進行還原..."
    shopt -s nullglob
    found_any=false

    # 掃描結構化目錄：backups/*/latest.bak
    for bak in "$BACKUP_ROOT"/*/latest.bak; do
        DB=$(basename "$(dirname "$bak")")
        restore_database "$DB" "$bak"
        found_any=true
    done

    # 掃描扁平目錄：backups/*.bak (相容舊模式)
    for bak in "$BACKUP_ROOT"/*.bak; do
        DB=$(basename "$bak" .bak)
        restore_database "$DB" "$bak"
        found_any=true
    done

    if [ "$found_any" = false ]; then
        echo "==> [警告] 在 $BACKUP_ROOT 下找不到任何 .bak 檔案或 latest.bak 結構。"
    fi
fi

echo "==> 所有還原程序結束。"

# ---------- 保持容器運行 ----------
# wait 命令會等待背景的 sqlservr 程序
wait
