#!/bin/bash
# Starts the LiteLLM proxy server.
set -e

# API keys are already loaded by entrypoint.sh into the environment.

CONFIG="/home/user/.litellm.yaml"

if [ ! -f "$CONFIG" ]; then
    echo "ERROR: No config found at $CONFIG"
    exit 1
fi

# Function to wait for a port to be open using Python
wait_for_port() {
    local host="$1"
    local port="$2"
    local name="$3"
    echo "Waiting for $name at $host:$port..."
    while ! python3 -c "import socket; s = socket.socket(); s.settimeout(1); s.connect(('$host', $port)); s.close()" >/dev/null 2>&1; do
        sleep 1
    done
    echo "$name is ready!"
}

# Wait for DB if DATABASE_URL is present
if [ -n "$DATABASE_URL" ]; then
    # Extract host and port from DATABASE_URL
    DB_HOST=$(echo "$DATABASE_URL" | sed -e 's|.*@||' -e 's|:.*||' -e 's|/.*||')
    DB_PORT=$(echo "$DATABASE_URL" | sed -e 's|.*:||' -e 's|/.*||')
    [[ "$DB_PORT" =~ ^[0-9]+$ ]] || DB_PORT=5432
    wait_for_port "$DB_HOST" "$DB_PORT" "database"
    sleep 2
fi

# Wait for Redis if REDIS_HOST is present
if [ -n "$REDIS_HOST" ]; then
    REDIS_P="${REDIS_PORT:-6379}"
    wait_for_port "$REDIS_HOST" "$REDIS_P" "Redis"
fi

echo "Starting LiteLLM proxy on port 4000..."
exec litellm --config "$CONFIG" --port 4000
