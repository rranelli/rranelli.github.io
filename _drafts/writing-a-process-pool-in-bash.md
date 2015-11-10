---
language: english
layout: post
comments: true
title: 'Writing a process pool in Bash'
---

# <p hidden>writing-a-process-pool-in-bash<p hidden>

**TL;DR**: In this post I will show how one can achieve the equivalent of a
"process pool" to run many processes in parallel in `Bash`. Think of a thread
pool, but for running individual processes. In a next post, I will show we can
use this "process pool" to build a tool that will help you manage tons of git
repositories.

<span class="underline"><p hidden>excerpt-separator<p hidden></span>

`Bash` is awesome, and I love it. If you read this blog you probably know that
already. In this post we will leverage `Bash`'s job-control capabilities and
extend it to create a full fledged "process pool". Think of a thread pool, but
for processes.

## What are you even trying to do?

The intent here is to build a tool that will allow me to {clone,pull} all of
my repositories at Github with a single command. ^1

To do that, we need to:

1.  Query github's api to get the addresses of all your personal repositories
2.  Format the commands to clone all of these repositories locally
3.  Run those commands in parallel, so that it won't take ages.

In this post we are going to focus on part 3.

## Reading commands to execute from `stdin`

In a [previous post](http://{{site.url}}/2015/04/08/simple-thread-pool-in-ruby/) I have shown how you would go about writing a simple
thread pool in `Ruby`. Here I am going to do mostly the same thing but using
`Bash` instead.

I will call the function that will do all of the heavy lifting `parallel`.
First, let's write the code needed to read "commands" from stdin (one command
per line), and execute it:

```sh
parallel() {
    local proc
    while read proc; do
        # expand the contents of "proc"
        # as if it were a command, and run it
        $proc
    done
}

parallel <<EOF
echo hi boy
echo how are you ?
EOF
```

Here we are using `Bash`'s magic and treating the `proc` variable as a
command, by just expanding it alone in `$proc`. In `Bash`, code is data
~~-ish~~ and data is code ~~-ish~~. Much `Lispy` right ?

Running the script yields:

```sh
#=> hi boy
#=> how are you ?
```

Great, it works. Now, let's run each command in a separate process.

### Forking

All we need to do is use `Bash`'s `&` operator, and call `wait` before
exiting. (This is similar to the `threads.map(&:join)` call we did in
`Ruby`.)

```sh
parallel() {
    local proc
    while read proc; do
        $proc &
    done
    wait # wait until all the forks are finished
}

parallel <<EOF
echo hi boy
echo how are you ?
sleep 3
echo you will see this immediately
EOF
```

Calling it doesn't change the results:

```sh
#=> hi boy
#=> how are you ?
#=> you will see this immediately
```

As you can see, the 3 `echo` calls are executed immediately while the other
slow process is process is ~~sleeping~~ executing. That means we are doing
things concurrently. Easy right?

## Running complex commands

Now, what if we want to use control flow operations like `&&`, `||`? Let's
try it:

```sh
POOL_SIZE=10 parallel <<EOF
echo hi boy
sleep 3
echo you will see this immediately
echo this && echo && echo is completely; echo broken
EOF
```

Running the script yields:

```sh
#=> hi boy
#=> you will see this immediately
#=> this && echo && echo is completely; echo broken
```

Which is definitely not what we want. In order to execute the line as if it
were typed in the shell, we need to resort to [eval](http://ss64.com/bash/eval.html):

```sh
parallel() {
    local proc
    while read proc; do
        eval "$proc" & # execute the proc
    done
    wait
}

parallel <<EOF
echo hi boy
sleep 3
echo you will see this immediately
echo this && echo will; echo work!
EOF
```

Running the script yields:

```sh
#=> hi boy
#=> you will see this immediately
#=> this
#=> will
#=> work!
```

It works. Note that running the script multiple times will change the order of
the messages.

## Using a limited amount of processes

Finally we get to the "pool" part.

We need to bound the number of processes we run. If we were to give an input of
1000 lines to our `parallel` function we would fork 1000 processes right
away, which does not seem like a good idea right?

Since we don't have anything similar to a thread-safe queue like `Ruby`'s
`Queue` class in `Bash`, we will need to write our own solution.

The pseudo-code for this "rate-limited" pool is something like this:

```
while: there are still processes to run
  if: we can accommodate one more process
    read command from stdin
    fork a new shell running it
    add it to the list of currently running processes

  for: process in running processes
    if: it is not running anymore
      remove it from the list of running processes
```

The implementation in `Bash` is:

```sh
parallel() {
    local proc procs
    declare -a procs=() # this declares procs as an array

    morework=true
    while $morework; do
        if [[ "${#procs[@]}" -lt "$POOL_SIZE" ]]; then
            read proc || { morework=false; continue ;}
            eval "$proc" &
            procs["${#procs[@]}"]="$!"
        fi

        for n in "${!procs[@]}"; do
            kill -0 "${procs[n]}" 2>/dev/null && continue
            unset procs[n]
        done
    done

    wait
}
```

Note our neat usage of `kill -0` and `unset`.

I have numbered the `echo` calls in the script below to show the order in
which we expect them to run:

```sh
POOL_SIZE=10 parallel <<EOF
echo [1] hi boy
sleep 2; echo [6] just slept 2
sleep 1; echo [5] you will not see this immediately cause slept 1
echo [2] this && echo [3] will && echo [4] work!
EOF
```

Running the script yields:

```sh
#=> [1] hi boy
#=> [2] this
#=> [3] will
#=> [4] work!
#=> [5] you will not see this immediately cause slept 1
#=> [6] just slept 2
```

Everything is in order. Now, if we change the pool size to 1 (which is
equivalent of running everything serially) we will see a different picture:

```sh
POOL_SIZE=1 parallel <<EOF
echo [1] hi boy
sleep 2; echo [6] just slept 2
sleep 1; echo [5] you will not see this immediately cause slept 1
echo [2] this && echo [3] will && echo [4] work!
EOF
```

Running the script yields:

```sh
#=> [1] hi boy
#=> [6] just slept 2
#=> [5] you will not see this immediately cause slept 1
#=> [2] this
#=> [3] will
#=> [4] work!
```

This indicates that our `process pool` is working adequately and no new
process is forked if the pool is fully occupied.

## Collecting output

The last bit we need to implement is to avoid the interleaving of the output
of different commands, as you can see happening below:

```sh
POOL_SIZE=10 parallel <<EOF
echo [yyy] stuff stuff stuff && sleep 2 && echo [yyy] stuff
echo [zzz] staff && sleep 5 && echo [zzz] star wars
echo [xxx] stoff && sleep 1 && echo [xxx] stiff
EOF
```

```sh
#=> [yyy] stuff stuff stuff
#=> [zzz] staff
#=> [xxx] stoff
#=> [xxx] stiff
#=> [yyy] stuff
#=> [zzz] star wars
```

We can achieve such output separation by redirecting the output of the
different processes to different temporary files, and concatenating them
**after** they are finished.

All we need is to add a map between processes and temporary files:

```sh
parallel() {
    local proc procs outputs tempfile morework
    declare -a procs=()
    declare -A outputs=()

    morework=true
    while $morework; do
        if [[ "${#procs[@]}" -lt "$POOL_SIZE" ]]; then
            read proc || { morework=false; continue ;}

            tempfile=$(mktemp)
            eval "$proc" >$tempfile 2>&1 &

            procs["${#procs[@]}"]="$!"
            outputs["$!"]=$tempfile
        fi

        for n in "${!procs[@]}"; do
            pid=${procs[n]}
            kill -0 $pid 2>/dev/null && continue

            cat "${outputs[$pid]}"
            unset procs[$n] outputs[$pid]
        done
    done

    wait
    for out in "${outputs[@]}"; do cat $out; done
}

POOL_SIZE=10 parallel <<EOF
echo [yyy] stuff stuff stuff && sleep 2 && echo [yyy] stuff
echo [zzz] staff && sleep 5 && echo [zzz] star wars
echo [xxx] stoff && sleep 1 && echo [xxx] stiff
EOF
```

Running the script yields:

```sh
#=> [yyy] stuff stuff stuff
#=> [yyy] stuff
#=> [zzz] staff
#=> [zzz] star wars
#=> [xxx] stoff
#=> [xxx] stiff
```

As you can see, no interleaving.

With this, we conclude our implementation of our `process pool`. In a future
post, we will use this code to do concurrent & parallel git clones.

That's it.

&#x2014;

(1) You could `git pull` all of your projects using [xargs](http://linux.die.net/man/1/xargs):

```sh
ls -1 $CODE_DIR | xargs -n1 -I{} git -C $CODE_DIR/{} pull --rebase
```

But that would happen in a sequential fashion and would take ages. The
approach with a "process pool" is better performance-wise. But if you don't
have that many repositories or don't mind the time, by all means use it.
