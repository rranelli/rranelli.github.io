#!/usr/bin/env bash
set -euo pipefail

redis_port=${PORT:-6379}
redis_host=${HOST:-localhost}

exec {redis_socket}<>/dev/tcp/$redis_host/$redis_port

echo 'Welcome to mimi-redis!'
while :
do
    read -ep "mimi-redis> " "command"
    echo $command >&${redis_socket}

    # read -u means that the command will read from file descriptor
    read -u $redis_socket "reply"
    echo $reply
done

exec {redis_socket}>&- # closes the =redis_socket= file descriptor
