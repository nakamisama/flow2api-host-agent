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
