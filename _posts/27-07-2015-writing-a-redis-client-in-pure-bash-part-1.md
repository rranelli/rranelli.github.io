---
language: english
layout: post
comments: true
title: 'Writing a Redis client in pure bash, part 1'
---

# <p hidden>Writing a Redis client in pure bash<p hidden>

**TL;DR**: After 180 hours of Witcher 3 gameplay, it's time to get back to
reality. In this post I will walk through the implementation of a simple `cli`
for Redis using nothing but pure Bash script. This post has absolutely no
practical implications other than providing an example to explain some of
Bash's nice features.

<span class="underline"><p hidden>excerpt-separator<p hidden></span>

## The motivation for Bash

You can skip this session if you're not interested in where the hell did I
get the idea for this post.

Although I work with Ruby, sometimes inevitable to write bash scripts. Ruby
is a much more capable and general (and modern) programming language but
cannot beat the extreme availability of Bash.

Recently I was refactoring the scripts we run at [Jenkins](https://jenkins-ci.org/). I started rewriting
those scripts in Ruby but came to an obvious limitation: One of those scripts
configured the ruby version to use in the project. Well, setting up the ruby
version to be used from **inside** of a ruby script is cumbersome at best. That
was when I decided to use raw bash for the scripts.

Since I have this problem that I can't work with something I don't
understand, I started looking for materials to learn/understand the workings
of Bash script. I asked people where I could learn more about Bash and one
guy pointed me at [this repository](https://github.com/caquino/redis-bash) which is an implementation of a complete
`cli` for Redis written in pure bash. For some reason I thought that writing
a `cli` for Redis would surely be rocket science, so I started reading Bash's
man page.

In the meantime, I finished reading the great [seven databases in seven weeks](https://pragprog.com/book/rwdata/seven-databases-in-seven-weeks).
At chapter 8, which deals with Redis, the author shows how one could interact
with Redis using [nothing but telnet](http://stackoverflow.com/questions/19515962/telnet-redis-bash-script), and speaks wonders on how Redis make it
easy for people to implement client libraries. (That's probably why every
language ever seems to have a client to redis). By knowing in advance that a
bash client is indeed feasible I thought: “Heck, this would be a nice
non-trivial exercise for bash script-fu!”.

And here we are.

In the following sessions I will show step-by-step how I implemented my own
client (without looking at the original implementation, believe me or not)
and also explain relevant things about Bash.

## Getting started

Redis' [protocol](http://www.redis.io/topics/protocol) (called RESP, for \*RE\*dis \*S\*erialization \*P\*rotocol)) is
surprisingly simple. The protocol is human readable, very performant (being
compared to binary alternatives) and easy to implement/parse. I do recommend
the reader to take a quick look at the link above in order to have a deeper
appreciation of what we will achieve in the next sessions.

For the rest of this post I will assume you have the kind of familiarity
needed to use a terminal with Bash. I expect you to know the meaning of
things like `$VAR`, but not much more

One of the greatest things I've seen when studying bash is the so-called “[non
official bash strict mode](http://redsymbol.net/articles/unofficial-bash-strict-mode/)”. By using it I assure you will save yourself a lot
of debugging time.

```sh
#!/usr/bin/env bash
set -euo pipefail
```

You should refer to the link above, but if you're too lazy, here is an
extremely concise and lossy description of the options:

-   `-e` : stop the script if some command exits with exit status != 0
-   `-u` : stop the script if using some variable that is not available
-   `-o pipefail` : stop if anywhere inside a pipeline a command exits with
    status != 0

`-u` is a MUST. Feels like going back to the days when I learned about VBA's
[Option Explicit](https://msdn.microsoft.com/en-us/library/y9341s4f.aspx). (God, my life is so much better now.)

## Talking to Redis

In order to talk to Redis we need to set up a tcp socket. Luckily Bash
provides us a surprisingly easy way to do so using built-in redirection:

```sh
#!/usr/bin/env bash
set -euo pipefail

redis_port=${PORT:-6379} # this means: use $PORT. If it's not available, use 6379.
redis_host=${HOST:-localhost}

# here is where the redirection magic happens
exec {redis_socket}<>/dev/tcp/$redis_host/$redis_port

echo 'set somekey 33' >&${redis_socket} # this writes to the filedescriptor $redis_socket
cat <&${redis_socket}
```

There are examples of using `<>` to [fetch web pages](http://www.linuxjournal.com/content/more-using-bashs-built-devtcp-file-tcpip). From the bash manual:

>
>
> Opening File Descriptors for Reading and Writing
>        The redirection operator
>
> [n]<>word
>
> causes the file whose name is the expansion of <span class="underline">word</span> to be opened for both
> reading and writing on file descriptor <span class="underline">n</span>, or on file descriptor <span class="underline">0</span> if <span class="underline">n</span> is
> not specified. If the file does not exist, it is created.
>
> <div align="right"><i>
>
> bash man pages
>
> </i></div>

Possibilities are endless. ^1

If you run the script, you'll see the following output:

```sh
$ bash redis-cli.sh
> +OK
>
```

Great! We have just set the value of the key `somekey` to `33`!

Notice that the prompt will hang indefinitely since we are reading the file
descriptor `$redis_socket` until exhaustion. This operation is akin to
calling `#to_a` in a Ruby's lazy enumerator or `#toList()` in a C#'s
`Queryable`. Those structures might "enumerate" forever. We will fix this in
the future.

## Allowing the user to send his own commands

A `cli` that asks you to hard-code a command is probably not of use to
anybody. We will now prompt the user for the command to send Redis. We can do
this using the fantastic Bash's [read](http://ss64.com/bash/read.html) built-in command:

```sh
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
```

Running the script again:

```sh
$ bash redis-cli.sh
> mimi-redis> set somekey 42
> +OK
```

The output still hangs. We can run the script again and ask for the result of
our last operation:

```sh
$ bash redis-cli.sh
> mimi-redis> get somekey
> $2 # <<< this means that the size of the next line is “2”
> 42 # <<< here is the actual value of somekey
```

## A broken REPL (Read-eval-print-loop)

The user of a `cli` probably wants to send more than one command in a single
session. We will now change our script to accept commands multiple times. We
will basically wrap everything in a `while` loop:

```sh
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
```

Running the script again:

```sh
$ bash redis-cli.sh
> mimi-redis> get somekey
> $2 # <<< this means that the size of the next line is “2”
> mimi-redis> set somekey 44
> 42 # <<< What?? This is the output of our first command !
> mimi-redis> sbrebols
> +OK # <<< ok... it seems we have a problem
```

The problem with our change is that we implicitly assume that every reply
from Redis will be exactly one line long (`read` reads a single line per
call). That is absolutely not true. We have to fix this.

## An actual REPL

Every reply from Redis has as it's first character denoting some a sort of
"type" for the subsequent data, according to the [protocol specification](http://www.redis.io/topics/protocol). For
example, `+` means a regular string will follow and `-` means an error will
follow.

So, we better handle the reply codes in order to show the user of our `REPL`
what is happening. We can do this with a [switch-case](http://tldp.org/LDP/Bash-Beginners-Guide/html/sect_07_03.html) over the first character
of the reply.

```sh
#!/usr/bin/env bash
set -eo pipefail

redis_port=${PORT:-6379}
redis_host=${HOST:-localhost}

exec {redis_socket}<>/dev/tcp/$redis_host/$redis_port

read_reply() {
    local reply
    local size
    local part

    read -n 1 -u $redis_socket replycode # the first character describes what comes next

    case $replycode in
        -) # Error
            read -u $redis_socket reply
            reply="\e[0;31m[ERROR] $reply\e[0m" # the crazy text here means: "paint it red"
            ;;
        +) # Regular String, response value follows on the same line
            read -u $redis_socket reply
            ;;
        :) # Integer, Response value follows on the same line
            read -u $redis_socket reply
            reply="(integer) $reply"
            ;;
        \$) # Bulk string. Size follows on the same line. Next line contains `size` characters.
            read -u $redis_socket size # reads the size... we actually ignore it
            read -u $redis_socket reply
            reply="$reply"
            ;;
        \*) # Array. Size follows on the same line. There will be `size` more replies following
            read -u $redis_socket size
            size=${size:0:${#size}-1} # eliminates last \r character. Need for arithmetic comparison

            reply=""
            for (( i=0; i < $size; i++ )); do # Bash has c-style for loops!
                reply="$reply$i) $(read_reply)\n" # Array replies are recursive.
            done
            ;;
        *) # Fallback...
            echo 'I DONT KNOW WHAT IM DOING. I DIE NOW'
            cat <&${redis_socket}
            ;;
    esac
    echo -e $reply
}

echo 'Welcome to mimi-redis!'
while :
do
    read -ep "mimi-redis> " command

    if [ "$command" = "exit" ]; then
        break;
    else
        echo $command >&${redis_socket}
    fi

    read_reply
done

echo "Byebye!"
exec {redis_socket}>&- # closes the =redis_socket= file descriptor
```

I won't walk through every modification because I think you can get it by
just reading the code. Check Redis' [protocol specification](http://www.redis.io/topics/protocol) to understand more
of it's design rationale.

Running a complete example now:

```sh
$ bash redis-cli.sh
> mimi-redis> get somekey
> 44 # alright! No metadata echoed to the screen.
> mimi-redis> set somekey 88
> OK # that's what we are expectnig
> mimi-redis> get somekey
> 88 # yeah!
> mimi-redis> sbrebols
> [ERROR] ERR unknown command 'sbrebols'
> mimi-redis>
```

Nice! We seem to have fixed the problem. I will stop here since this post
seems to be way too long already.

## What's next?

The next obvious step now is extract a `function` that will send commands to
Redis, process Redis' reply and return the value to the caller. With this, we
are able to distribute our logic as a library (We won't actually distribute
this, since [there's already a full implementation of what we're doing out
there](https://github.com/caquino/redis-bash), but exercise is fun nonetheless)

In a next post, I will walk trough the steps needed to extract what we wrote
so far into a self contained function. (This will mostly consist of removing
calls to `echo` and changing the calls to `read` slightly)

Stay tuned!

That's it.

&#x2014;

(1) Based on this example some hardcore Emacs would be thinking: “I could use
this same wizardry to run http requests directly from my editor!”. But as is
often the case with Emacs, [multiple](https://github.com/pashky/restclient.el) [folk](https://github.com/emacs-pe/http.el) have done it already.
