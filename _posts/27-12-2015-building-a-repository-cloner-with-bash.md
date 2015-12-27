---
language: english
layout: post
comments: true
title: 'Building a repository cloner with Bash'
---

# <p hidden>building-a-repository-cloner-with-bash<p hidden>

**TL;DR**: In another entry of the “you shouldn't use `Bash` for that” series we
will build a script to discover & clone all of your Github repositories. We
will use the concurrent ~~thread~~ process pool we developed in a
[previous
post](http://{{site.url}}/2015/11/20/writing-a-process-pool-in-bash/)

<span class="underline"><p hidden>excerpt-separator<p hidden></span>

I probably am over-stretching my `Bash` usage in these posts, but writing
`Bash` is so fun I can't help myself. In this post we will use `Bash` in
conjunction with the amazing [curl](https://github.com/bagder/curl) and
[jq](https://stedolan.github.io/jq/) libraries to explore
[Github's api](https://developer.github.com/v3/) and automatically discover
and clone all of your personal git repositories. No more copy-and-paste of
`ssh-urls` from Github.

In a
[previous
post](http://{{site.url}}/2015/11/20/writing-a-process-pool-in-bash/) we outlined the process to develop such tool as this:

1.  Query Github's api to get the addresses of all your personal repositories
2.  Format the commands to clone all of these repositories locally
3.  Run those commands in parallel, so that the whole process won't take ages

We already solved part 3, and in this post we will get over with parts 1
and 2.

## Querying Github's api

Using Github's api to [fetch repositories](https://developer.github.com/v3/repos/) is surprisingly easy &#x2013; Actually,
its no surprise at all. Part of Github's success is that a great number of
apps integrate with it using its api. Github acts like a “hub” for
code-related stuff (oh, rly?).

Below we set some required environment variables and the repository index
`url` for your user.

```sh
set -euo pipefail

GITHUB_API_TOKEN=$(mimipass get github-api-token)
CODE_DIR=$HOME/gh

GITHUB_USER=rranelli
repos_url="https://api.github.com/users/$GITHUB_USER/repos"
```

You will need to generate a private api token for Github in order to avoid
being rate-limited. Generating this token is easy and you can find
instructions [here](https://help.github.com/articles/creating-an-access-token-for-command-line-use/). Here I am storing my private token in a “password
management system” I wrote myself called `mimipass`. You can see the details
of its construction in [this post](http://{{site.url}}/2015/10/26/write-your-own-password-manager/).

To fetch the repositories we use the tried-and-true `curl`:

```sh
curl -sS -H "${auth_header}" ${repos_url}
```

The relevant parts of the response:

```js
[
  {
    "id": 32712185,
    "name": "101sccs",
    "full_name": "rranelli/101sccs",
    "owner": {
      "login": "rranelli",
      "id": 4231743,
      "url": "https://api.github.com/users/rranelli",
      "html_url": "https://github.com/rranelli"
    // ...
    },
    "private": false,
    "html_url": "https://github.com/rranelli/101sccs",
    "fork": false,
    "url": "https://api.github.com/repos/rranelli/101sccs",
    "ssh_url": "git@github.com:rranelli/101sccs.git",
    "clone_url": "https://github.com/rranelli/101sccs.git"
    // ...
  }, // and many other similar objects ...
  ...
]
```

As you can see, the api's response is encoded in JSON, hence we will need to
find some tool to parse it. We will use `jq` to do that. `jq` is like `sed`
but for `application/json` instead of `text/plain`.

I won't walk you on how to use `jq`. You can learn 90% of what you will need
by reading the [manual](https://stedolan.github.io/jq/manual/) for 10 minutes. We can grab all the `ssh_urls` with the
'`.[] | .ssh_url`' `jq` expression:

```sh
curl -sS -H "${auth_header}" ${repos_url} | jq '.[] | .ssh_url'
```

```sh
"git@github.com:rranelli/101sccs.git"
"git@github.com:rranelli/7langs7weeks.git"
"git@github.com:rranelli/advisor.git"
"git@github.com:rranelli/CSharp.Fun.git"
"git@github.com:rranelli/dogma.git"
"git@github.com:rranelli/dotenv_elixir.git"
"git@github.com:rranelli/elixir.git"
# ... and so on
```

That's great! With this we are able to clone all the repositories using our
`parallel` function (which we already wrote). We only need to format as the
actual commands to execute. For those lazy enough, here is the final version
of `parallel`

```sh
POOL_SIZE=10
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
```

## Formatting the commands to feed the process pool

Formatting the commands is only a matter of prepending each line of the
output with `git clone`:

```sh
curl -sS -H "${auth_header}" ${repos_url} \
  | jq '.[] | .ssh_url' \
  | awk '{ print "git clone " $1 }'
```

The results are then:

```sh
git clone "git@github.com:rranelli/101sccs.git"
git clone "git@github.com:rranelli/7langs7weeks.git"
git clone "git@github.com:rranelli/advisor.git"
git clone "git@github.com:rranelli/CSharp.Fun.git"
git clone "git@github.com:rranelli/dogma.git"
git clone "git@github.com:rranelli/dotenv_elixir.git"
git clone "git@github.com:rranelli/elixir.git"
```

That is exactly what `parallel` expects. We only need to pipe to it:

```sh
mkdir -p $CODE_DIR; cd $CODE_DIR

curl -sS -H "${auth_header}" ${repos_url} \
  | jq '.[] | .ssh_url' \
  | awk '{ print "git clone " $1 }' \
  | parallel
```

```sh
Cloning into '7langs7weeks'...
Cloning into 'after_do-loader'...
Cloning into 'cassette'...
Cloning into 'elixir'...
Cloning into 'appsignal'...
Cloning into 'Aquarium'...
Cloning into 'BatchPDF'...
Cloning into 'dogma'...
Cloning into 'concurrent-ruby'...
Cloning into 'clojure-koans'...
```

We figure now that we actually did not clone **every** repository we have on
Github. The reason is that Github's repository api is paginated. In order to
collect all the urls we need to call the api multiple times.

Luckly, the `next page` `url` is sent back to us in the response headers. We
can fetch the response headers with `curl`'s `-I` option:

```sh
curl -sS -I -H "${auth_header}" ${repos_url}
```

```sh
HTTP/1.1 200 OK
Server: GitHub.com
Date: Fri, 25 Dec 2015 01:42:38 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 155019
Status: 200 OK
Link: <https://api.github.com/user/4231743/repos?page=2>; rel="next", <https://api.github.com/user/4231743/repos?page=4>; rel="last"

# ... a lot of other stuff
```

Great. I will now extract the "repository" fetching to its own function. I
will explain what each part does in the comments in the code.

```sh
fetch-repos() {
    # don't foolf yourself. These nested function
    # definitions are global. Bash is not Scheme.
    function get-next-page {
        # Here we "parse" some text to check if it contains a
        # "next-page" link (see footnotes)
        if [[ "$@" =~ \<(.*)\>\;\ rel\=\"next\" ]]; then
            # If there is a next page, we output it.
            echo "${BASH_REMATCH[1]}"
        fi
    }

    function fetch-repos-rec {
        # Here we will recursively (hence the -rec) fetch the
        # repositories form the api
        [ "$#" = 0 ] && return 0

        url=$1

        # request the headers
        header=$(curl -sSI -H "${auth_header}" $url)
        # extract out of array
        repos=$(curl -sS -H "${auth_header}" $url | jq '.[]')

        # get-next-page will return the next page or empty string
        next_page=$(get-next-page "${header}")

        # if $next_page is not the empty string, keep recursing
        [ -n $next_page ] && \
          echo "${repos}" "$(fetch-repos-rec ${next_page})"
    }

    # join all repositories into an array
    fetch-repos-rec $1 | jq --slurp '.'
}

mkdir -p $CODE_DIR; cd $CODE_DIR

fetch-repos "${repos_url}" \
  | jq '.[] | .ssh_url' \
  | awk '{ print "git clone " $1 }' \
  | parallel
```

Executing the version with all the repositories we now get:

```sh
Cloning into 'gurusp38concruby'...
Cloning into 'use-package'...
Cloning into 'rubocop-emacs'...
Cloning into 'rrfuncprog'...
Cloning into 'Grupo04_ShopSmart'...
Cloning into 'functional-ruby'...
Cloning into 'RailsTutorial'...
Cloning into 'promise.rb'...
Cloning into 'k-r-c'...
Cloning into 'rr-write-yourself-a-scheme'...
Cloning into 'emacs.d'...
Cloning into 'httpotion'...
Cloning into 'rrfewdt'...
Cloning into 'heart-check'...
Cloning into 'rranelli.github.io'...
Cloning into 'emacs-dotfiles'...
```

That's great, every repository has been cloned (you'll have to believe me on
this one). With this, every time you fork or create a new repository at
Github, all you need to do is run the script we developed and you local box
will be “synced” with Github.

The final version of our script is then:

```sh
set -euo pipefail

GITHUB_API_TOKEN=$(mimipass get github-api-token)
CODE_DIR=$HOME/gh

GITHUB_USER=rranelli
repos_url="https://api.github.com/users/$GITHUB_USER/repos"
auth_header="Authorization: token $GITHUB_API_TOKEN"
POOL_SIZE=10
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

fetch-repos() {
    # don't foolf yourself. These nested function
    # definitions are global. Bash is not Scheme.
    function get-next-page {
        # Here we "parse" some text to check if it contains a
        # "next-page" link (see footnotes)
        if [[ "$@" =~ \<(.*)\>\;\ rel\=\"next\" ]]; then
            # If there is a next page, we output it.
            echo "${BASH_REMATCH[1]}"
        fi
    }

    function fetch-repos-rec {
        # Here we will recursively (hence the -rec) fetch the
        # repositories form the api
        [ "$#" = 0 ] && return 0

        url=$1

        # request the headers
        header=$(curl -sSI -H "${auth_header}" $url)
        # extract out of array
        repos=$(curl -sS -H "${auth_header}" $url | jq '.[]')

        # get-next-page will return the next page or empty string
        next_page=$(get-next-page "${header}")

        # if $next_page is not the empty string, keep recursing
        [ -n $next_page ] && \
          echo "${repos}" "$(fetch-repos-rec ${next_page})"
    }

    # join all repositories into an array
    fetch-repos-rec $1 | jq --slurp '.'
}

mkdir -p $CODE_DIR; cd $CODE_DIR

fetch-repos "${repos_url}" \
  | jq '.[] | .ssh_url' \
  | awk '{ print "git clone " $1 }' \
  | parallel
```

## Enhancements and exercises for the reader

One of the most tedious tasks I encountered when dealing with forks is to set
up the “upstream” remote repository correctly. Since all the info we need to
point to set those up is available in Github's api, we are only a script away
of solving this problem for good.

Since this post is already big enough, I won't carry on demonstrating how to
solve this problem, but you can see a final & more complete version of this
script [over here](https://github.com/rranelli/linuxsetup/blob/86323b9/scripts/gitmulticast.sh).

The script linked above also handles `git pull` ing all the repositories
concurrently. It's worth taking a look.

Another simple extension to the script is to allow one to clone repositories
from an organization. Only one line needs to change:

```diff
-repos_url="https://api.github.com/users/$GITHUB_USER/repos"
+repos_url=${REPOS_URL:-"https://api.github.com/users/$GITHUB_USER/repos"}
```

With this you're able to override the `repos_url` variable by invoking the
script with `REPOS_URL` set like this:

```sh
REPOS_URL=https://api.github.com/orgs/my_cool_org/repos ./gitmulticast.sh
```

And voilá. Everything will work just fine :+1:.

That's it.

&#x2014;

(1) You can't parse {X,HT}ML using regular expressions. To understand why see
the [best stack overflow answer ever](http://stackoverflow.com/questions/1732348/regex-match-open-tags-except-xhtml-self-contained-tags).
