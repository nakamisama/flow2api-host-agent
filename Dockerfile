# 使用官方 Ubuntu 镜像，确保有完整的 apt 和 bash
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. 先只安装 Google Chrome 源和基础工具
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget gnupg2 ca-certificates \
    && wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" \
       > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# 2. 安装图形相关组件（Xvfb / fluxbox / x11vnc / novnc / websockify）
RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb \
    fluxbox \
    x11vnc \
    novnc \
    websockify \
    && rm -rf /var/lib/apt/lists/*

# 3. 安装 Python3 和基础工具
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# 4. 准备项目目录和虚拟环境
WORKDIR /app

COPY requirements.txt .
RUN python3 -m venv .venv \
    && .venv/bin/pip install --upgrade pip setuptools wheel \
    && .venv/bin/pip install --no-cache-dir -r requirements.txt

# 5. 复制项目代码
COPY . .

# 6. 创建运行时目录
RUN mkdir -p /var/lib/flow2api-host-agent/profile \
             /var/lib/flow2api-host-agent/runtime \
             /var/log/flow2api-host-agent \
    && chmod 700 /var/lib/flow2api-host-agent/runtime

# 7. 环境变量
ENV DISPLAY=:99 \
    HOME=/var/lib/flow2api-host-agent \
    XDG_RUNTIME_DIR=/var/lib/flow2api-host-agent/runtime \
    PYTHONPATH=/app

# 8. 暴露 Web UI 端口（VNC 端口可根据需要再开）
EXPOSE 38110

# 9. 用普通文件写启动脚本，避免 here-doc 兼容问题
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
