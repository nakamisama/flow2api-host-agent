# 使用官方 Python 镜像
FROM python:3.11-slim

# 安装 Chrome / Xvfb / fluxbox 等依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget gnupg2 \
    && wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       google-chrome-stable \
       xvfb \
       fluxbox \
       x11vnc \
       novnc \
       websockify \
    && rm -rf /var/lib/apt/lists/*

# 工作目录
WORKDIR /app

# 先复制依赖文件
COPY requirements.txt .
RUN python -m venv .venv \
    && .venv/bin/pip install -U pip setuptools wheel \
    && .venv/bin/pip install --no-cache-dir -r requirements.txt

# 再复制项目代码
COPY . .

# 创建必要目录（参考 install-systemd.sh）
RUN mkdir -p /var/lib/flow2api-host-agent/profile \
             /var/lib/flow2api-host-agent/runtime \
             /var/log/flow2api-host-agent \
    && chmod 700 /var/lib/flow2api-host-agent/runtime

# 设置环境变量（和 systemd 服务对齐）
ENV DISPLAY=:99 \
    HOME=/var/lib/flow2api-host-agent \
    XDG_RUNTIME_DIR=/var/lib/flow2api-host-agent/runtime \
    PYTHONPATH=/app

# 暴露 Web UI 端口
EXPOSE 38110

# 启动脚本：Xvfb + fluxbox + x11vnc + novnc + daemon + UI
COPY <<'EOF' /start.sh
#!/usr/bin/env bash
set -euo pipefail

# 启动 X 虚拟帧缓冲
Xvfb :99 -screen 0 1280x720x24 &
sleep 1

# 窗口管理器
fluxbox &
sleep 1

# VNC 服务（可选，方便调试）
x11vnc -display :99 -forever -shared -rfbport 5900 -rfbportv6 5900 &

# noVNC（如果你需要浏览器远程访问）
websockify --web /usr/share/novnc 6080 localhost:5900 &

# 启动 daemon
.venv/bin/python /app/scripts/agent.py --config /app/agent.toml daemon &

# 启动 Web UI
exec .venv/bin/uvicorn web.app:app --host 0.0.0.0 --port 38110 --app-dir /app
EOF

RUN chmod +x /start.sh

CMD ["/start.sh"]
