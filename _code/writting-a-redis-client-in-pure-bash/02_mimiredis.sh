#!/usr/bin/env bash
set -euo pipefail

redis_port=${PORT:-6379}
redis_host=${HOST:-localhost}

exec {redis_socket}<>/dev/tcp/$redis_host/$redis_port

# The =-p= option to =read= means "prompt"
read -p "mimi-redis> " command
# here we simply change the hardcoded 'set somekey 33' to '$command'
echo $command >&${redis_socket}

cat <&${redis_socket}
