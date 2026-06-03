#!/usr/bin/env bash
set -euo pipefail

# ============================================
# 自动生成 /app/agent.toml（如果不存在）
# ============================================
if [ ! -f /app/agent.toml ]; then
    echo "📝 Generating /app/agent.toml from environment variables..."
    
    # 如果 agent.example.toml 存在，基于它生成；否则从零创建
    if [ -f /app/agent.example.toml ]; then
        cp /app/agent.example.toml /app/agent.toml
    else
        # 最小默认配置
        cat > /app/agent.toml <<'TOML'
flow2api_url = "http://localhost:38000"
connection_token = ""
chrome_profile_dir = "/var/lib/flow2api-host-agent/profile"
chrome_binary = "/usr/bin/google-chrome-stable"
remote_debugging_port = 9223
display = ":99"
start_url = "https://labs.google/fx/vi/tools/flow"
refresh_interval_minutes = 30
state_file = "/var/lib/flow2api-host-agent/state.json"
log_file = "/var/log/flow2api-host-agent/chrome.log"
listen_host = "0.0.0.0"
listen_port = 38110
novnc_url = ""
TOML
    fi

    # 用环境变量覆盖关键配置（只有环境变量存在且非空时才覆盖）
    if [ -n "${FLOW2API_URL:-}" ]; then
        sed -i "s|^flow2api_url = .*|flow2api_url = \"${FLOW2API_URL}\"|" /app/agent.toml
    fi

    if [ -n "${CONNECTION_TOKEN:-}" ]; then
        sed -i "s|^connection_token = .*|connection_token = \"${CONNECTION_TOKEN}\"|" /app/agent.toml
    fi

    # 可选：其他配置项也可以通过环境变量注入
    if [ -n "${CHROME_BINARY:-}" ]; then
        sed -i "s|^chrome_binary = .*|chrome_binary = \"${CHROME_BINARY}\"|" /app/agent.toml
    fi

    if [ -n "${REFRESH_INTERVAL:-}" ]; then
        sed -i "s|^refresh_interval_minutes = .*|refresh_interval_minutes = ${REFRESH_INTERVAL}|" /app/agent.toml
    fi

    echo "✅ /app/agent.toml generated successfully"
else
    echo "ℹ️  /app/agent.toml already exists, skipping generation"
fi

# ============================================
# 启动图形环境和服务
# ============================================

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
