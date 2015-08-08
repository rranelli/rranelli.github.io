#!/usr/bin/env bash
set -eo pipefail

redis_port=${PORT:-6379}
redis_host=${HOST:-localhost}

exec {redis_socket}<>/dev/tcp/$redis_host/$redis_port

read_reply() {
    local reply
    local size
    local part

    # the first character describes what comes next
    read -n 1 -u $redis_socket replycode

    case $replycode in
        -) # Error
            read -u $redis_socket reply
            # the crazy text here means: "paint it red"
            reply="\e[0;31m(error) $reply\e[0m"
            ;;
        +) # Regular String, response value follows on the same line
            read -u $redis_socket reply
            ;;
        :) # Integer, Response value follows on the same line
            read -u $redis_socket reply
            reply="(integur) $reply"
            ;;
        \$) # Bulk string. Size follows on the same line. Next line contains
            # `size` characters.
            read -u $redis_socket size # reads the size
            # eliminates last \r character. Needed for arithmetic comparison
            size=${size:0:${#size}-1}

            if [ $size -ge 0 ]; then
                # Only read the next line if the "size" is not "-1", which means
                # "missing" value
                read -u $redis_socket reply
            else
                reply="(nil)"
            fi

            ;;
        \*) # Array. Size follows on the same line. There will be `size` more
            # replies following
            read -u $redis_socket size
            # eliminates last \r character. Needed for arithmetic comparison
            size=${size:0:${#size}-1}

            reply=""
            # Bash has c-style for loops!
            for (( i=1; i < $size; i++ )); do
                # Array replies are recursive.
                reply="$reply$i) $(read_reply)\n"
            done
            # this avoids the extra \n when printing the last element of the
            # array
            [ $size -gt 0 ] && reply="$reply$i) $(read_reply)"
            ;;
        *) # Fallback...
            echo 'I DONT KNOW WHAT IM DOING. I DIE NOW'
            cat <&${redis_socket}
            ;;
    esac

    reply=$(echo "$reply" | tr -d "\r")
    echo -e $reply
}

echo 'Welcome to mimi-redis!'
while :
do
    read -ep "mimi-redis> " command

    if [ "$command" == "exit" ]; then break; fi;
    if [ -z "$command"  ]; then continue; fi;

    echo $command >&${redis_socket}
    read_reply
done
echo "Bye bye!"

# closes the =redis_socket= file descriptor
exec {redis_socket}>&-
