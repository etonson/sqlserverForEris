# 使用官方 SQL Server 2022 映像
FROM mcr.microsoft.com/mssql/server:2022-latest

USER root

# 安裝必要套件與 mssql-tools
RUN apt-get update && apt-get install -y curl gnupg software-properties-common && \
    curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/microsoft.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" \
    > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y mssql-tools unixodbc-dev && \
    ln -sfn /opt/mssql-tools/bin/* /usr/local/bin/ && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 複製 entrypoint script 並給予執行權限
COPY entrypoint.sh /usr/src/entrypoint.sh
RUN chmod +x /usr/src/entrypoint.sh

# 宣告 volume（SQL Server 資料目錄）
VOLUME ["/var/opt/mssql"]

# 設定容器的進入點
ENTRYPOINT ["/usr/src/entrypoint.sh"]
