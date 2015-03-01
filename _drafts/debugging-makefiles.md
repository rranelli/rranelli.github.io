---
language: english
layout: post
comments: true
title: 'Debugging Makefiles'
---

# <p hidden>Debugging Makefiles<p hidden>

**TL;DR**: Makefiles are awesome, but debugging them is quite a pain when you're
getting started with them. In this post I will explain how I made my Debian Pc
setup 100% automatic using a simple Makefile. I will also give starters some
tips on how to organize and debug Makefiles.

<span class="underline"><p hidden>excerpt-separator<p hidden></span>

## What is Make ?

Wikipedia says:

> [Make](http://en.wikipedia.org/wiki/Make_%2528software%2529) is a utility that automatically builds executable programs and libraries
> from source code by reading files called makefiles which specify how to derive
> the target program. Though integrated development environments and
> language-specific compiler features can also be used to manage a build process,
> Make remains widely used, especially in Unix.
>
> Besides building programs, Make can be used to manage any project where some
> files must be updated automatically from others whenever the others change.

Make was launched in 1977 (!) and [GNU Make](http://www.gnu.org/software/make/) is the standard implementation
nowadays. Make is available in most platforms.

You probably use a build tool everyday (and if you don't, you definitely
should), even if you're not aware it is called a *build tool*. Examples of
build tools are:

-   Maven, Ant and Gradle for Java
-   MSbuild and Fake for .Net
-   Rake for Ruby
-   Sbt for Scala
-   Leiningen for Clojure
-   Cabal for Haskell
-   Mix for Elixir
-   Cask for Emacs Lisp

## Overview of Make features

One of the things that impressed me when I started to work with Make was the
quality of its manual. It is probably the best written manual I've ever seen.
The manual is not crisp as manuals use to be, is ridden with examples and
advice and reads fluidly. I read it from start to end like a book.

You can check the whole manual in Html [here](http://www.gnu.org/software/make/manual/make.html).

I won't give yet another introduction/tutorial to Make since the Internet has
a lot of material available already. If anything, I encourage you to read the
manual.

## Make as a provisioning tool

Make's flexibility and ease of use convinced me to write my desktop
provisioning in it. There are tools like [TODO: Links] Chef, Puppet, Salt,
Ansible, etc, that are made for this purpose but none of them beats the
straightforwardness of a Makefile IMHO.

You can check the Makefile I use to setup my dekstop here [FIXME: Link to
github].

I've made a habit of never installing a new software or package to my system
without adding it to this Makefile first. As you can see there, there is a
macro [FIXME: make manual link] that lists all the packages I want in my
system. All of the *features* I want in my system are described as one Make
target [FIXME: link]. [FIXME: add example]

All the environment necessary for development in a given language is
described as a make target. Clojure, SML, Haskell, Elixir, and Ruby have each
their own make target. I also download, compile and install Emacs in a make
target.

### Bootstrapping a new machine

Also, to make everything even simpler, I've added a shell script to
bootstrap a newly installed machine:

```sh
#!/bin/bash -ev

# Install git of course
sudo apt-get install -y git

# Prompt user to add ssh-key to github account. This is needed for code-base cloning

if [ ! -f ~/.ssh/id_rsa.pub ]; then
    cat /dev/zero | ssh-keygen -q -N ""

    echo "Add this ssh key to your github account!"
    cat ~/.ssh/id_rsa.pub
    echo "Press [Enter] to continue..." && read
fi


git clone git@github.com:rranelli/linuxsetup.git

cd linuxsetup

make
make all
```

All I need to do in a new machine is run the following line in the terminal:

```sh
$ wget https://raw.githubusercontent.com/rranelli/linuxsetup/master/ubuntu_install.sh && bash ubuntu_install.sh
```

Pretty neat don't you think?

## Tips for debugging make

### Ordering

One of the recent difficulties I've had in the configuration of my setup was
with the ordering of target execution.

Recently, I changed most of the targets' prerequisites to
[order-only-prerequesites](https://www.gnu.org/software/make/manual/html_node/Prerequisite-Types.html). For example, I changed

```makefile
elixir: code $(MODULE_DIR)/elixir
$(MODULE_DIR)/elixir:
	# stuff...
```

to

```makefile
elixir: $(MODULE_DIR)/elixir | code
$(MODULE_DIR)/elixir:
	# stuff...
```

The former configuration would recompile Emacs if I modify the `packages` or
`code` targets. That is totally not what one would want. So, I started using
`order-only-prerequisites`.

When I tried to run `make elixir` in a new machine the
`$(MODULE_DIR)/elixir` target was being executed <span class="underline">before</span> the `code` target.
Definitely not what I wanted.

When we use git we sometimes make a `dry-run` of {pull,push} to see if there
is some conflict between our local changes and the remote ones. We can do
the same thing with make by running `make -n [targets]`. This command will
show all the commands `make` intend to execute. That helped me tremendously
when debugging the issue.

The problem with that is that I misunderstood the behavior of Make. The
`elixir` target doesn't do anything but ask for the execution of the dynamic
target `$(MODULE_DIR)/elixir` and **that** is the target that should have the
dependency.

The correct definitions should have been:

```makefile
elixir: $(MODULE_DIR)/elixir
$(MODULE_DIR)/elixir: | code
	# stuff...
```

Other useful option to consider using is the `-W` or `--what-if` flag.
Running `make -nW target` would tell you which commands would run if
`target` were to be re-built. This helps you to check if you got your
`prerequisites` vs `order-only-prerequisites` configuration right.

That's it.

&#x2014;

(1) The inspiration for configuring my machine using Make is due to my good
friend Rafael Almeida's [dev-box](https://github.com/stupied4ever/dev-box) project. I got quite envious of him and
decided to write my own ;). Thanks !
