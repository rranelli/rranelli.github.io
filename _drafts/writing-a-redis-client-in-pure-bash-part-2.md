---
language: english
layout: post
comments: true
title: 'Writing a Redis client in pure bash, part 2'
---

# <p hidden>writing-a-redis-client-in-pure-bash-part-2<p hidden>

**TL;DR**: In a [previous post](http://{{site.url}}/2015/07/27/writing-a-redis-client-in-pure-bash-part-1/) we built a Redis REPL from scratch using pure
bash. In this post we will walk through a refactoring of the original code to
turn it into something resembling a library. I wil also show some more bash
niceties as we go along.

<span class="underline"><p hidden>excerpt-separator<p hidden></span>

## The problem

In the previous part of this series, we have ended up with the following
code:

```bash
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
            reply="(integer) $reply"
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
```

The code work as intended for a `cli`, mimicking the features of the default
`redis-cli` tool. The best you can do to use it programmatically is sending
the commands directly to STDIN:

```sh
$ echo GET x | ./mimiredis.sh
> Welcome to mimi-redis!
> (nil)
$ echo $?
> 1        # what? you crazy?
```

As you can see, our function is not library friendly. Everything went fine,
but we exited with an exit status different than 0. We also returned a
welcome message, even though we were not calling the script interactively.

In the following sessions we will fix this behavior. But first, we need to do
it with confidence, so the let's first create some sort of "test suite".

## Refactoring with confidence

Before we start refactoring, we need to find out some way to ensure we did
not mess everything up along the way. The simplest form of testing is "black
box testing". We pass some input to the program and ensure that the output is
equal to the expected one.

We will create this "expected output" like this: (you could of course write
the test input in a text file, but I won't do it here because I just learned
about `tee` and `Heredocs`, and I want to play with them.)

```sh
redis-cli flushall > /dev/null # because I can
cat <<TESTINPUT | tee test_input.txt | ./01_mimiredis.sh | tee test_output.txt
DEL x
GET x
SET x 10
GET x
DEL x

sbrebols
set u

DEL name
GET name
SET name milhouseonsoftware
GET name
DEL name

DEL inoexist
LRANGE inoexist 0 -1
LPUSH inoexist "lol"
DEL inoexist

DEL listz
GET listz
LPUSH listz 3 4 5 2 1 3 4 5 6 7 8
LLEN listz
LPUSH listz 3 4 5
LRANGE listz 0 -1
LLEN listz
RPUSH listz "powerranger"
LRANGE listz 0 -1
DEL listz

exit
TESTINPUT
```

This crazy `HEREDOC`-ed command creates two files, `test_input.txt` and
`test_output.txt` using the magical `tee` command. ^1 This input-output pair
will be enough for a "black-box" testing approach. The contents of
`test_output.txt` are:

```sh
Welcome to mimi-redis!
(integer) 0
(nil)
OK
10
(integer) 1
[0;31m(error) ERR unknown command 'sbrebols'[0m
[0;31m(error) ERR wrong number of arguments for 'set' command[0m
(integer) 0
(nil)
OK
milhouseonsoftware
(integer) 1
(integer) 0

(integer) 1
(integer) 1
(integer) 0
(nil)
(integer) 11
(integer) 11
(integer) 14
1) 5
2) 4
3) 3
4) 8
5) 7
6) 6
7) 5
8) 4
9) 3
10) 1
11) 2
12) 5
13) 4
14) 3
(integer) 14
(integer) 15
1) 5
2) 4
3) 3
4) 8
5) 7
6) 6
7) 5
8) 4
9) 3
10) 1
11) 2
12) 5
13) 4
14) 3
15) powerranger
(integer) 1
Bye bye!
```

And now, by using some bash black magic, we can convert the output of a
subshell to a named pipe (using `<(command ...)`) and pass it down to the
`diff` utility in conjunction with our expected output. Unix pipes to the
rescue!

Calling:

```sh
diff <(cat test_input.txt | ./01_mimiredis.sh) <(cat test_output.txt) \
    && echo "Good Job! You didn\'t mess everything up" \
        || echo -e "YOU FAILED AT LIFE"
```

Results in:

```sh
Good Job! You didn\'t mess everything up
```

If we were to break our program by replacing "integer" by "integur" we would
see:

```sh
2c2
< (integur) 0
---
> (integer) 0
6c6
< (integur) 1
---
> (integer) 1
9c9
< (integur) 0
---
> (integer) 0
13,14c13,14
< (integur) 1
< (integur) 0
---
> (integer) 1
> (integer) 0
16,18c16,18
< (integur) 1
< (integur) 1
< (integur) 0
---
> (integer) 1
> (integer) 1
> (integer) 0
20,22c20,22
< (integur) 11
< (integur) 11
< (integur) 14
---
> (integer) 11
> (integer) 11
> (integer) 14
37,38c37,38
< (integur) 14
< (integur) 15
---
> (integer) 14
> (integer) 15
54c54
< (integur) 1
---
> (integer) 1
YOU FAILED AT LIFE
```

Which is probably enough to convince you something is wrong. Now that we have
built our poor-man's test harness, we can keep on refactoring with
confidence.

## Extracting logic from the REPL body

First, we will create a function that will receive a Redis command, send it
to Redis and collect the response.

Right now, the code that "sends the command" is embedded in the main loop of
the REPL:

```sh
while : # this is the L in REPL
do
    read -ep "mimi-redis> " command # this is the R in REPL

    if [ "$command" == "exit" ]; then break; fi;
    if [ -z "$command"  ]; then continue; fi;

    echo $command >&${redis_socket} # this is ... well, have of E
    read_reply # this is the other half of E and P in REPL
done
```

We will factor out a function called `mimiredis` that will receive the
`redis_socket` as first argument and the Redis command to run as the `rest`.

```sh
read_reply() {
     # ...
}

mimiredis() {
    local redis_socket = $1
    shift
    command=$@

    # send the command to redis
    echo $command >&${redis_socket}

    # reads the reply
    read_reply $redis_socket
}

while : # L in REPL
do
    read -ep "mimi-redis> " command # R in REPL

    if [ "$command" == "exit" ]; then break; fi;
    if [ -z "$command"  ]; then continue; fi;

    mimiredis $redis_socket $command # Both E and P in REPL
done
```

To make sure we have not broken our contract, we run again:

Calling:

```sh
diff <(cat test_input.txt | ./02_mimiredis.sh) <(cat test_output.txt) \
    && echo "Good Job! You didn\'t mess everything up" \
        || echo -e "YOU FAILED AT LIFE"
```

Results in:

```sh
Good Job! You didn\'t mess everything up
```

We're still on track.

## Are we in a interactive session?

Our "eval" code is still too much concerned with presentation of the results
to a human. We add "welcome" and "goodbye" messages when starting the
process, and we also add color to errors.

We can check if the client output is meant to be consumed by a human being
using the `-t` unary test operator. From the Bash man page:

> CONDITIONAL EXPRESSIONS
>
> Conditional expressions are used by the [[ compound command and the test and
> [ builtin commands to test file attributes and perform string and arithmetic
> comparisons.
>
> &#x2026;
>
> -t fd : True if file descriptor fd is open and refers to a terminal.
>
> <div align="right"><i>
>
> Bash man page
>
> </i></div>

Since `0` is the file descriptor for `stdin`, we can assert that the `stdin`
is connected to a `tty` / `terminal` with `[ -t 0 ]`. If `stdin` is connected
to a `tty`, we are certain that the client is being used interactively.

We can then use this test to tweak what we return from `mimiredis`. Only 3
lines need to change:

```diff
# Only colorize output if connected to a tty
- reply="\e[0;31m(error) $reply\e[0m"
+ [ -t 0 ] && reply="\e[0;31m(error) $reply\e[0m"

# ...

# Only show the welcome message if connected to a tty
- echo 'Welcome to mimi-redis!'
+ [ -t 0 ] && echo 'Welcome to mimi-redis!'

# ...

# Only show the goodbye message if connected to a tty
- echo "Bye bye!"
+ [ -t 0 ] && echo "Bye bye!"
```

When running our "testing suite" we now get the following output:

```sh
diff <(cat test_input.txt | ./03_mimiredis.sh) <(cat test_output.txt) \
    && echo "Good Job! You didn\'t mess everything up" \
        || echo -e "YOU FAILED AT LIFE"
```

Results in:

```sh
0a1
> Welcome to mimi-redis!
6,7c7,8
< ERR unknown command 'sbrebols'
< ERR wrong number of arguments for 'set' command
---
> [0;31m(error) ERR unknown command 'sbrebols'[0m
> [0;31m(error) ERR wrong number of arguments for 'set' command[0m
53a55
> Bye bye!
YOU FAILED AT LIFE
```

If you can't read the `diff` output (or if you're too lazy to care), I will
translate it for you. The `diff` output reads as follows:

-   The file on the right contains an extra "Welcome to mimi-redis!" at line 1;
-   The file on the left lacks [0;31m(error) at the beginning and [0m at
    the end of lines 6-8
-   The file on the right contains an extra "Bye bye!" at line 53;

TL;DR: its exactly what we wanted.

Re-running our first example:

```sh
$ echo GET x | ./03_mimiredis.sh # stdin connected to echo's output.
> (nil)
```

## A little bit debugging

We're on track. We have eliminated the spurious welcome message. However, the
exit status is still wrong.

```sh
$ echo GET x | ./03_mimiredis.sh # outputs to tty, so nothing should change
> (nil)
$ echo $?
> 1
```

In order to find the culprit for this exit status, we run our client setting
the `-x` flag, which echoes every line executed:

```sh
echo GET x | bash -x ./03_mimiredis.sh 2>&1
```

We then get:

```sh
+ set -eo pipefail
+ redis_port=6379
+ redis_host=localhost
+ exec
+ '[' -t 0 ']'
+ :
+ read -ep 'mimi-redis> ' command
+ '[' 'GET x' == exit ']'
+ '[' -z 'GET x' ']'
+ mimiredis 10 GET x
+ local redis_socket=10
+ shift
+ command='GET x'
+ echo GET x
+ read_reply 10
+ declare -a reply
+ local reply
+ local size
+ local part
+ local redis_socket=10
+ read -n 1 -u 10 replycode
+ case $replycode in
+ read -u 10 size
+ size=-1
+ '[' -1 -ge 0 ']'
+ reply='(nil)'
+ echo -e '(nil)'
+ tr -d '\r'
(nil)
+ :
+ read -ep 'mimi-redis> ' command
```

We see now that the `read` call is the responsible for the exit status `1`
(the script exits because of the `-e` flag). We turn to the great bash man
page to find out what this exit status means:

> read  [-ers]  [-a  aname]  [-d delim] [-i text] [-n nchars] [-N nchars] [-p
>        prompt] [-t timeout] [-u fd] [name &#x2026;]
>
> &#x2026;
>
> The return code is zero, unless end-of-file is encountered, read times out (in
>               which case the return code is greater than 128), a variable
>               assignment error (such as assigning to a readonly variable)
>               occurs, or an invalid file descriptor is supplied as the argument
>               to -u.
>
> <div align="right"><i>
>
> Bash man page, shell built in commands - read
>
> </i></div>

Turns out that `read` exits with `1` when encountering the `end-of-file`.
Since we are not using readonly variables or reading with timeouts, we can
just break out of the loop if `read` exits with `1`. The only change needed
is:

```diff
- read -ep "mimi-redis> " command
+ read -ep "mimi-redis> " command || break
```

Running again:

```sh
$ echo GET x | ./03_mimiredis.sh # outputs to tty, so nothing should change
> (nil)
$ echo $?
> 0 # yay!!
```

Here is the final refactored version of our client (still less than 90
lines):

```bash
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
```

Running our test suite once again:

```sh
diff <(cat test_input.txt | ./03_mimiredis.sh) <(cat test_output.txt) \
    && echo "Good Job! You didn\'t mess everything up" \
        || echo -e "YOU FAILED AT LIFE"
```

Results in:

```sh
0a1
> Welcome to mimi-redis!
6,7c7,8
< ERR unknown command 'sbrebols'
< ERR wrong number of arguments for 'set' command
---
> [0;31m(error) ERR unknown command 'sbrebols'[0m
> [0;31m(error) ERR wrong number of arguments for 'set' command[0m
53a55
> Bye bye!
YOU FAILED AT LIFE
```

Nothing changed. We're good. That concludes our refactoring.

In a future post, I will extend the idea of our "test suite" and apply some
random testing to stress our implementation. See you in the future.

That's it.

&#x2014;

(1) Being a chemical engineer, the name "tee" gives me memories. Those of you
who know nothing about piping might not appreciate the genius behind the
naming of this command. This is a [tee](http://img.diytrade.com/smimg/325506/8453841-1167403-0/pipe_fittings_Malleable_iron_Reducing_tee/721e.jpg). Also, these are [pipes](https://upload.wikimedia.org/wikipedia/commons/8/89/Metal_tubes_stored_in_a_yard.jpg). Naming things
is pretty hard since we work solely with abstract entities, and it's much
easier to borrow names from other fields instead of coming up with our own
terms. (I'm looking at you Monads, Monoids and Functors)
