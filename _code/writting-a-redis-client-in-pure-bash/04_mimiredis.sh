#!/usr/bin/env bash
set -euo pipefail

redis_port=${PORT:-6379}
redis_host=${HOST:-localhost}

exec {redis_socket}<>/dev/tcp/$redis_host/$redis_port

echo 'Welcome to mimi-redis!'
while :
do
    read -ep "mimi-redis> " command

    if [ "$command" = "exit" ]; then
        break;
    else
        echo $command >&${redis_socket}
    fi

    read -n 1 -u $redis_socket replycode # the first character describes what comes next
    case $replycode in
        -) # error
            read -u $redis_socket reply
            reply="\e[0;31m[ERROR] $reply\e[0m" # the crazy text here means: "paint it red"
            ;;
        +) # standard response
            read -u $redis_socket reply
            ;;
        :) # integer
            read -u $redis_socket reply
            reply="(integer) $reply"
            ;;
        \$) # message size
            read -u $redis_socket size # reads the size...
            read -u $redis_socket reply
            reply="$reply"
            ;;
        ,*) # fallback...
            read -u $redis_socket reply
            reply="$replycode$reply"
            ;;
    esac
    echo -e $reply
    unset reply
done

echo "Byebye!"
exec {redis_socket}>&- # closes the =redis_socket= file descriptor
