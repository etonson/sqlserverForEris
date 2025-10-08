# SQL Server 2022 容器化方案 (Podman/Docker)

本專案提供了一個使用 Podman 或 Docker 運行 SQL Server 2019 容器的完整解決方案。透過自定義的 `Dockerfile`，我們不僅建置了 SQL Server 環境，還整合了 `mssql-tools` 以方便進行命令列操作。此外，一個智慧型的 `entrypoint.sh` 腳本確保了服務在完全就緒後才能執行初始化任務，並結合 `docker-compose.yml` 檔案來簡化服務的部署、管理和擴展。

## ✨ 核心功能

*   **SQL Server 2019**: 基於微軟官方的 `mcr.microsoft.com/mssql/server:2019-latest` 映像檔。
*   **內建工具**: `Dockerfile` 中已整合 `mssql-tools` (包含 `sqlcmd` 和 `bcp`)，無需額外安裝即可在容器內或透過 `exec` 進行操作。
*   **Compose 管理**: 使用 `podman-compose` 或 `docker-compose` 進行一鍵啟動、停止和管理。
*   **數據持久化**: 透過 Docker 命名卷 (Named Volumes) 持久化資料庫檔案、日誌和密鑰，確保容器刪除後數據依然安全。
*   **智慧型啟動腳本**: `entrypoint.sh` 會自動等待 SQL Server 服務完全啟動後，再執行後續的初始化腳本，極大提高了自動化部署的可靠性。
*   **內建健康檢查**: `docker-compose.yml` 中包含了健康檢查機制，可以透過 `podman ps` 或 `docker ps` 直觀地監控資料庫服務狀態。
*   **備份與還原**: 透過綁定掛載 (Bind Mount) 的 `./backup` 目錄，輕鬆實現資料庫備份檔案在主機與容器間的傳輸。

## 📂 專案結構

```
.
├── Dockerfile          # 定義 SQL Server 映像的建置步驟，包含安裝 mssql-tools
├── entrypoint.sh       # 容器啟動時執行的智慧型腳本，會等待 SQL Server 就緒
├── docker-compose.yml  # 定義和管理 sqlserver 服務的 Compose 檔案
└── README.md           # 本說明文件
```

## 🛠️ 先決條件

請確保您的系統已安裝以下工具：

*   **Podman** 及 **podman-compose**
    *   [Podman 安裝指南](https://podman.io/docs/installation)
    *   安裝 `podman-compose`: `pip install podman-compose`
*   **或 Docker** 及 **docker-compose**
    *   [Docker 安裝指南](https://docs.docker.com/get-docker/)

### 提示 (macOS / Windows)

若您在 macOS 或 Windows 上使用 Podman，請確保 `podman machine` 已啟動：
```bash
podman machine init
podman machine start
```

## 🚀 快速開始

#### 1. 克隆專案

```bash
git clone https://github.com/etonson/sqlserverForEris.git
cd sqlserverForEris
```

#### 2. 創建備份目錄

`docker-compose.yml` 設定了將主機的 `./backup` 目錄映射到容器中。請手動創建此目錄：

```bash
mkdir -p ./backup
```

#### 3. 建置 Docker 映像檔 (Build)

此步驟會根據 `Dockerfile` 建立一個包含 SQL Server 和 `mssql-tools` 的本地映像檔。

```bash
# 使用 Podman
podman-compose build

# 或使用 Docker
docker-compose build
```
這個指令只建置映像，不啟動服務。如果建置過程需要除錯，這是非常有用的第一步。

#### 4. 啟動 SQL Server 服務

使用 `up` 指令來啟動服務。第一次執行時，如果映像不存在，它也會自動執行建置。

```bash
# 使用 Podman (後台運行)
podman-compose up -d

# 或使用 Docker (後台運行)
docker-compose up -d
```

## 🔗 連接到資料庫

服務啟動並顯示為 `(healthy)` 狀態後，您即可連接。

**連接資訊:**

*   **主機 (Host):** `localhost`
*   **埠 (Port):** `1433`
*   **用戶名 (Username):** `sa`
*   **密碼 (Password):** `1qaz@WSX3edc` (定義於 `docker-compose.yml`)

您可以使用任何圖形化 SQL Server 客戶端 (如 Azure Data Studio, DBeaver) 或使用 `sqlcmd` 進行連接。

**使用 `sqlcmd` 從主機連接:**
```bash
sqlcmd -S localhost -U sa -P "1qaz@WSX3edc"
```

## 💾 數據管理

### 持久化

本專案使用三個命名卷來確保數據安全：`sqlserver_data`, `sqlserver_log`, `sqlserver_secret`。即使您執行 `podman-compose down`，這些卷中的數據也會被保留。

### 備份 (Backup)

要備份資料庫（例如 `MyDatabase`），可以進入容器執行 `sqlcmd`，備份檔案會出現在主機的 `./backup` 目錄中。

```bash
# 語法
# podman-compose exec <服務名> <指令>
podman-compose exec sqlserver /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U sa -P "1qaz@WSX3edc" \
    -Q "BACKUP DATABASE [MyDatabase] TO DISK = N'/var/opt/mssql/backup/MyDatabase.bak' WITH NOFORMAT, INIT, NAME = 'MyDatabase-full', SKIP, NOREWIND, NOUNLOAD, STATS = 10"
```

### 還原 (Restore)

1.  將您的 `.bak` 備份檔案放入主機的 `./backup` 資料夾。
2.  執行以下指令進行還原。

```bash
podman-compose exec sqlserver /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U sa -P "1qaz@WSX3edc" \
    -Q "RESTORE DATABASE [MyDatabase] FROM DISK = N'/var/opt/mssql/backup/YourBackupFile.bak' WITH FILE = 1, NOUNLOAD, REPLACE, STATS = 5"
```

## 🌟 進階用法：啟動時自動初始化資料庫

`entrypoint.sh` 腳本的設計允許您在 SQL Server 首次啟動時自動執行初始化腳本 (例如創建資料庫、Schema 或 seeded data)。

🔹 功能說明

1. 自動抓最新 .bak
    不用手動修改檔名

2. 自動抓 Logical Name
    無論原資料庫叫 PTPMSDB、MyDB，都能正確還原
3. 檢查資料庫是否存在
    若已存在，跳過還原

4. 保持容器運行
    wait 讓 SQL Server 在前景執行

## ⚙️ 服務管理指令

*   **查看服務狀態**:
    ```bash
    podman-compose ps
    podman ps -a --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
    ```

*   **查看日誌**:
    ```bash
    podman-compose logs -f sqlserver
    ```

*   **進入容器內部**:
    ```bash
    podman-compose exec sqlserver /bin/bash
    ```

*   **停止服務** (不刪除容器和數據):
    ```bash
    podman-compose stop
    ```

*   **停止並移除容器** (數據卷會被保留):
    ```bash
    podman-compose down
    ```

*   **徹底清理** (移除容器、網路和**所有數據**):
    ```bash
    # 警告：此操作將永久刪除您的資料庫數據！
    podman-compose down -v
    ```
