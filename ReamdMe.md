好的，這是一個為你的 SQL Server Podman 設置設計的 `README.md` 檔案範本，包含了如何建置、運行、連接和清理的說明。

---

# SQL Server 2019 容器化設置 (Podman)

這個專案提供了一個使用 Podman 運行 SQL Server 2019 容器的設置。它使用了自定義的 Dockerfile 來安裝 `mssql-tools` 並結合一個 `docker-compose.yml` 檔案來簡化服務的部署和管理。

## 專案結構

```
.
├── Dockerfile
├── entrypoint.sh
├── docker-compose.yml
└── README.md
```

*   `Dockerfile`: 定義了 SQL Server 映像檔的建置步驟，包括安裝 `mssql-tools`。
*   `entrypoint.sh`: 容器啟動時執行的腳本。
*   `docker-compose.yml`: 使用 `podman-compose` 定義和管理 `sqlserver` 服務。
*   `README.md`: 本說明文件。

## 先決條件

在開始之前，請確保你的系統已經安裝了以下工具：

*   **Podman**: 容器引擎。
    *   [Podman 安裝指南](https://podman.io/docs/installation)
*   **podman-compose**: 用於解析 `docker-compose.yml` 檔案並與 Podman 互動。
    *   安裝方式 (通常透過 pip): `pip install podman-compose`
*   **Git**: (可選) 如果你需要從版本控制系統克隆此專案。

### Podman Machine (macOS / Windows)

如果你在 macOS 或 Windows 上使用 Podman，你需要確保 `podman machine` 已經啟動：

```bash
podman machine init
podman machine start
```

## 設定步驟

1.  **克隆專案 (如果適用)**

    ```bash
    git clone <你的Git倉庫URL>
    cd <你的專案目錄>
    ```

2.  **創建備份目錄**

    `docker-compose.yml` 中定義了一個綁定掛載，將主機上的 `./backup` 目錄映射到容器中。請確保此目錄存在：

    ```bash
    mkdir -p ./backup
    ```

3.  **準備 `entrypoint.sh`**

    確保 `entrypoint.sh` 腳本存在於與 `Dockerfile` 和 `docker-compose.yml` 相同的目錄中。該腳本會在容器啟動時執行。一個基礎的範例如下：

    ```bash
    #!/bin/bash

    # 執行 SQL Server 官方映像的預設 entrypoint
    # 這會啟動 SQL Server
    /opt/mssql/bin/sqlservr
    ```
    **注意:** 如果你需要 SQL Server 啟動後執行自定義的 SQL 腳本（例如創建資料庫、用戶），你需要在 `entrypoint.sh` 中添加邏輯，等待 SQL Server 服務完全可用後再執行 `sqlcmd` 命令。

## 運行服務

使用 `podman-compose` 命令來建置映像檔並啟動 SQL Server 服務。

```bash
podman-compose up -d
```

*   `-d` 選項會在後台運行容器。
*   第一次運行時，`podman-compose` 會自動建置 `Dockerfile` 中的映像檔，這可能需要一些時間，因為它會下載基礎映像並安裝 `mssql-tools`。

## 檢查服務狀態

你可以使用以下命令來檢查服務的運行狀態：

```bash
# 查看 podman-compose 管理的服務狀態
podman-compose ps

# 查看所有 Podman 容器
podman ps -a

# 查看 Podman 卷
podman volume ls
```

你會看到一個名為 `mssql-eris` 的容器正在運行，其健康檢查會在後台進行。

## 連接到 SQL Server

一旦容器啟動並其健康檢查顯示為 `healthy`，你就可以連接到 SQL Server 了。

**資料庫連接資訊:**

*   **主機 (Host):** `localhost` (如果你在主機上運行)
*   **埠 (Port):** `1433`
*   **用戶名 (Username):** `sa`
*   **密碼 (Password):** `1qaz@WSX3edc` (請注意，這是 `docker-compose.yml` 中設定的密碼)

你可以使用 `sqlcmd` (如果你的本機安裝了 `mssql-tools`) 或任何圖形化的 SQL Server 客戶端工具 (如 Azure Data Studio, SQL Server Management Studio) 來連接。

**使用 `sqlcmd` 連接:**

```bash
sqlcmd -S localhost -U sa -P "1qaz@WSX3edc"
```

## 持久化數據與備份

這個設置使用了以下機制來處理數據持久化：

*   **命名卷 (Named Volumes):**
    *   `sqlserver_data`: 用於持久化 SQL Server 的資料庫檔案。
    *   `sqlserver_log`: 用於持久化 SQL Server 的交易日誌。
    *   `sqlserver_secret`: 用於持久化 SQL Server 的機密資訊。
    這些卷由 Podman 管理，確保容器重啟或刪除後數據不會丟失。

*   **綁定掛載 (Bind Mount):**
    *   `./backup:/var/opt/mssql/backup`: 將主機上的 `./backup` 目錄映射到容器內的 `/var/opt/mssql/backup`。這使得你可以在主機上存放資料庫備份檔案，並讓容器讀取或寫入。

## 停止和清理服務

當你完成後，可以使用 `podman-compose down` 命令來停止並移除服務所創建的所有容器、網絡和**命名卷**。

```bash
podman-compose down -v
```

*   `-v` 選項會同時移除命名卷 (`sqlserver_data`, `sqlserver_log`, `sqlserver_secret`)。**請注意，這將刪除你的資料庫數據，請謹慎使用。**
*   綁定掛載的 `./backup` 目錄不會被刪除，其內容將保留在你的主機上。

如果你只想停止容器而不移除它們和卷：

```bash
podman-compose stop
```

然後你可以稍後再次啟動它們：

```bash
podman-compose start
```

## 故障排除

*   **`podman-compose: command not found`**: 確保 `podman-compose` 已正確安裝並在你的 PATH 中。
*   **容器無法啟動或健康檢查失敗**:
    *   檢查 `podman logs mssql-eris` 的輸出，查看 SQL Server 的啟動日誌。
    *   確保 `SA_PASSWORD` 符合 SQL Server 的密碼複雜度要求。
    *   檢查 `Dockerfile` 中的 APT 倉庫配置，確保其與 SQL Server 基礎映像的 Linux 發行版版本兼容。
*   **無法連接到 SQL Server**:
    *   確認容器正在運行 (`podman ps`)。
    *   確認埠映射正確 (`-p 1433:1433`)。
    *   確認使用的用戶名和密碼正確。

---
