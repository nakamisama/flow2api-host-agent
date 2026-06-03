FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget gnupg2 \
    && wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       google-chrome-stable \
       xvfb \
       fluxbox \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN python -m venv .venv \
    && .venv/bin/pip install -U pip setuptools wheel \
    && .venv/bin/pip install --no-cache-dir -r requirements.txt

COPY . .

RUN mkdir -p /var/lib/flow2api-host-agent/profile \
             /var/lib/flow2api-host-agent/runtime \
             /var/log/flow2api-host-agent \
    && chmod 700 /var/lib/flow2api-host-agent/runtime

ENV DISPLAY=:99 \
    HOME=/var/lib/flow2api-host-agent \
    XDG_RUNTIME_DIR=/var/lib/flow2api-host-agent/runtime \
    PYTHONPATH=/app

EXPOSE 38110

COPY <<'EOF' /start.sh
#!/usr/bin/env bash
set -euo pipefail

Xvfb :99 -screen 0 1280x720x24 &
sleep 1
fluxbox &

# 启动 daemon
.venv/bin/python /app/scripts/agent.py --config /app/agent.toml daemon &

# 启动 Web UI
exec .venv/bin/uvicorn web.app:app --host 0.0.0.0 --port 38110 --app-dir /app
EOF

RUN chmod +x /start.sh

CMD ["/start.sh"]
