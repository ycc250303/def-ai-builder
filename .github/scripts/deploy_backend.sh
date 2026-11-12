#!/usr/bin/env bash
# 把已打包的后端安装到 8.155.138.61，并只重建 plant-backend。
# 用法: SSH_PRIVATE_KEY=... bash deploy_backend.sh <host> <stage_dir>
set -euo pipefail

HOST="${1:?需要服务器地址}"
STAGE="${2:?需要发布目录}"
USER_NAME="${3:-root}"
PORT="${4:-22}"

for file in plant.jar Dockerfile.runtime compose.yml dockerignore; do
  if [[ ! -f "${STAGE}/${file}" ]]; then
    echo "发布目录缺少 ${file}" >&2
    exit 1
  fi
done

if [[ -z "${SSH_PRIVATE_KEY:-}" ]]; then
  echo "缺少 SSH_PRIVATE_KEY" >&2
  exit 1
fi

install -m 700 -d "${HOME}/.ssh"
KEY_FILE="$(mktemp)"
trap 'rm -f "$KEY_FILE"' EXIT
printf '%s\n' "$SSH_PRIVATE_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

ssh-keyscan -T 15 -p "$PORT" -H "$HOST" >> "${HOME}/.ssh/known_hosts"

SSH=(
  ssh
  -i "$KEY_FILE"
  -o BatchMode=yes
  -o ConnectTimeout=30
  -o ServerAliveInterval=15
  -o ServerAliveCountMax=6
  -o StrictHostKeyChecking=yes
  -p "$PORT"
  "${USER_NAME}@${HOST}"
)
SCP=(
  scp
  -i "$KEY_FILE"
  -o BatchMode=yes
  -o ConnectTimeout=30
  -o StrictHostKeyChecking=yes
  -P "$PORT"
)

"${SSH[@]}" 'bash -s' << 'EOF'
set -euo pipefail
install -d -m 700 /opt/plant /opt/plant/incoming
if [[ ! -s /opt/plant/.env ]]; then
  echo "缺少 /opt/plant/.env" >&2
  exit 1
fi
EOF

"${SCP[@]}" \
  "${STAGE}/plant.jar" \
  "${STAGE}/Dockerfile.runtime" \
  "${STAGE}/compose.yml" \
  "${STAGE}/dockerignore" \
  "${USER_NAME}@${HOST}:/opt/plant/incoming/"

"${SSH[@]}" 'bash -s' << 'EOF'
set -euo pipefail
install -m 644 /opt/plant/incoming/plant.jar /opt/plant/plant.jar
install -m 644 /opt/plant/incoming/Dockerfile.runtime /opt/plant/Dockerfile.runtime
install -m 644 /opt/plant/incoming/compose.yml /opt/plant/compose.yml
install -m 644 /opt/plant/incoming/dockerignore /opt/plant/.dockerignore
cd /opt/plant
docker compose -f compose.yml build backend
docker compose -f compose.yml up -d --no-deps --force-recreate backend
for _ in $(seq 1 36); do
  state="$(docker inspect --format '{{.State.Status}}' plant-backend 2>/dev/null || true)"
  if [[ "$state" == "exited" || "$state" == "dead" ]]; then
    echo "后端容器已停止" >&2
    docker logs --tail 120 plant-backend >&2 || true
    exit 1
  fi
  health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' plant-backend 2>/dev/null || true)"
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://127.0.0.1:8082/ || true)"
  if [[ "$health" == "healthy" && "$code" =~ ^(200|301|302|401|404)$ ]]; then
    echo "后端已响应 HTTP ${code}"
    exit 0
  fi
  sleep 5
done
echo "后端未在预期时间内就绪" >&2
docker logs --tail 120 plant-backend >&2 || true
exit 1
EOF
