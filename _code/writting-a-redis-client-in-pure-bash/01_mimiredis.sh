#!/usr/bin/env bash
set -euo pipefail

redis_port=${PORT:-6379} # this means: use $PORT. If it's not available, use 6379.
redis_host=${HOST:-localhost}

# here is where the redirection magic happens
exec {redis_socket}<>/dev/tcp/$redis_host/$redis_port

echo 'set somekey 33' >&${redis_socket} # this writes to the filedescriptor $redis_socket
cat <&${redis_socket}
