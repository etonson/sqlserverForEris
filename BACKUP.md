# SQL Server 備份與還原規範 (DB Lab)

本專案採用結構化的備份管理方式，旨在快速重建開發與測試環境。

## 📂 目錄結構

建議將備份檔案按照以下結構存放於 `backups/` 目錄下：

```text
backups/
├── gtmk/
│   ├── latest.bak       # 核心備份檔 (Entrypoint 自動掃描此名稱)
│   └── metadata.json    # 備份中繼資料
├── hccg/
│   ├── latest.bak
│   └── metadata.json
└── README.md            # 本文件
```

## 📝 Metadata 規範

每個備份目錄下應包含一個 `metadata.json`，範例如下：

```json
{
  "database": "gtmk",
  "sqlserverVersion": "2022",
  "source": "production",
  "createdAt": "2026-04-23",
  "description": "支票批號異常重現資料"
}
```

## 🚀 自動還原機制

當容器啟動時，`entrypoint.sh` 會自動執行以下邏輯：

1. **特定還原**：若環境變數 `RESTORE_DB` 有值（例如 `RESTORE_DB=gtmk`），則僅針對該資料庫進行還原。
2. **全量還原**：若 `RESTORE_DB` 為空，則自動掃描 `backups/*/latest.bak` 並依序還原。
3. **跳過機制**：若資料庫已存在於系統中，則會跳過還原流程，避免覆蓋既有資料。

## 🛠 如何手動觸發特定還原

在啟動時指定環境變數：

```bash
RESTORE_DB=hccg docker compose up
```

## ⚠️ 注意事項

*   **SA 密碼**：還原過程需要 SA 權限，請確保 `.env` 中的 `SA_PASSWORD` 正確無誤。
*   **邏輯檔名**：腳本會自動偵測 `.bak` 內的邏輯檔名並對應到 `/var/opt/mssql/data` 下的物理檔案。
*   **效能**：首次還原較大資料庫時，請耐心等待 `STATS = 10` 的進度輸出。
