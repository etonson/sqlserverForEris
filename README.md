# SQL Server DB Lab (Eris)

本專案是一個專為開發與測試環境設計的 **SQL Server 備份還原實驗室**。透過容器化技術，您可以將生產環境的備份檔 (`.bak`) 放入指定目錄，容器啟動時會自動完成還原，讓您在幾分鐘內重建完整的資料庫開發環境。

## ✨ 核心功能

*   **🚀 自動化還原**: 啟動容器即自動掃描並還原 `.bak` 檔案，無需手動下指令。
*   **📂 結構化管理**: 支援 `backups/{db_name}/latest.bak` 結構，輕鬆管理多個資料庫與版本。
*   **🔧 靈活切換**: 支援 `RESTORE_DB` 環境變數，可指定僅還原特定的資料庫。
*   **🛠️ 內建工具**: 整合 `mssql-tools` (sqlcmd, bcp)，方便進行進階資料操作。
*   **💾 數據持久化**: 透過命名磁碟卷 (Named Volumes) 保存資料，重啟容器不丟失數據。

## 📂 專案結構

```text
.
├── backups/            # 存放備份檔 (.bak) 的目錄 (自動映射至容器)
├── BACKUP.md           # 備份檔命名規範與中繼資料 (Metadata) 說明
├── backup.sh           # 備份指令腳本，可自動將資料庫備份、歸檔並更新 Metadata
├── docker-compose.yml  # 服務定義與環境變數配置
├── Dockerfile          # 建置包含 mssql-tools 的 SQL Server 2022 映像
└── entrypoint.sh       # 核心腳本：負責啟動 SQL Server 並執行自動還原
```

## 🚀 快速開始

### 1. 準備環境檔案
複製 `.env.example` 並重新命名為 `.env`，設定您的密碼與用戶名：
```bash
cp .env.example .env
```

### 2. 放入備份檔案
將您的 `.bak` 檔案放入 `backups/` 目錄。建議結構如下：
```text
backups/
└── my_project/
    └── latest.bak
```
*(詳細規範請參考 [BACKUP.md](./BACKUP.md))*

### 3. 啟動實驗室
使用 Docker Compose 啟動服務：
```bash
docker compose up -d
```
容器啟動後，`entrypoint.sh` 會自動偵測 `backups/` 下的檔案並執行還原。您可以透過日誌查看進度：
```bash
docker compose logs -f
```

## 🛠️ 進階用法

### 💾 執行資料庫備份
您可以隨時將運行中資料庫的最新狀態備份出來：
* **互動選單**：直接執行 `./backup.sh` 即可列出目前所有的使用者資料庫供您選擇。
* **指定備份**：執行 `./backup.sh [資料庫名稱]` 備份特定資料庫，例如 `./backup.sh hccg`。

更多細節請參考 [BACKUP.md](./BACKUP.md)。

### 只還原特定資料庫
如果您有多個備份，但只想針對其中一個進行實驗：
```bash
RESTORE_DB=my_project docker compose up -d
```

### 連接資訊
*   **Host**: `localhost`
*   **Port**: `1433`
*   **User**: `sa` 或您在 `.env` 中定義的 `USER_NAME`
*   **Password**: 定義於 `.env` 的 `SA_PASSWORD`

### 使用 sqlcmd 進行操作
```bash
docker compose exec sqlserver sqlcmd -S localhost -U sa -P "YourPassword" -Q "SELECT name FROM sys.databases"
```

## 💾 數據管理

*   **持久化**: 資料庫物理檔案儲存在 `sqlserver_data` 卷中。
*   **重設環境**: 若要清空所有資料庫重新開始，請執行：
    ```bash
    docker compose down -v
    ```

## ⚠️ 注意事項

*   **系統資源**: SQL Server 映像較大，且還原過程會消耗 CPU/IO，建議分配至少 2GB RAM 給 Docker 引擎。
*   **備份相容性**: 本專案使用 SQL Server 2022，可還原較舊版本 (2019, 2017...) 的備份，但無法還原更新版本的備份。

---
*Powered by Gemini CLI & Eris Team*
