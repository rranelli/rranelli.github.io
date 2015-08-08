#!/usr/bin/env bash
set -eo pipefail

redis_port=${PORT:-6379}
redis_host=${HOST:-localhost}

exec {redis_socket}<>/dev/tcp/$redis_host/$redis_port
read_reply() {
    declare -a reply; local reply

    local size
    local part

    local redis_socket=$1

    read -n 1 -u $redis_socket replycode
    case $replycode in
        -) # Error
            read -u $redis_socket reply

            [ -t 0 ] && reply="\e[0;31m(error) $reply\e[0m"
            ;;
        +) # Regular String, response value follows on the same line
            read -u $redis_socket reply
            ;;
        :) # Integer, Response value follows on the same line
            read -u $redis_socket reply
            reply="(integer) $reply"
            ;;
        \$) # Bulk string. Size follows on the same line.
            # Next line contains `size` characters.
            read -u $redis_socket size
            size=${size:0:${#size}-1}

            if [ $size -ge 0 ]; then
                # Only read the next line if the "size" is not "-1",
                # which means "missing" value
                read -u $redis_socket reply
            else
                reply="(nil)"
            fi

            ;;
        \*) # Array. Size follows on the same line.
            # There will be `size` more replies following
            read -u $redis_socket size
            size=${size:0:${#size}-1}

            reply=""
            for (( i=1; i < $size; i++ )); do
                reply="$reply$i) $(read_reply $redis_socket)\n"
            done
            [ $size -gt 0 ] && reply="$reply$i) $(read_reply $redis_socket)"
            ;;
        *) # Fallback...
            echo 'I DONT KNOW WHAT IM DOING. I DIE NOW'
            cat <&${redis_socket}
            ;;
    esac

    echo -e "$reply" | tr -d "\r"
}

mimiredis() {
    local redis_socket=$1
    shift
    command=$@

    echo $command >&${redis_socket}
    read_reply $redis_socket
}

[ -t 0 ] && echo 'Welcome to mimi-redis!'
while :
do
    read -ep "mimi-redis> " command || break

    if [ "$command" == "exit" ]; then break; fi;
    if [ -z "$command" ]; then continue; fi;

    mimiredis $redis_socket $command
done

[ -t 0 ] && echo "Bye bye!"

exec {redis_socket}>&-
