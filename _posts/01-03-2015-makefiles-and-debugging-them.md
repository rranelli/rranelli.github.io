---
language: english
layout: post
comments: true
title: 'Makefiles & Debugging them'
---

# <p hidden>Makefiles & Debugging them<p hidden>

**TL;DR**: Makefiles are awesome, but debugging them is quite a pain when you're
getting started with them. In this post I will explain how I made my Debian Pc
setup 100% automatic using a simple Makefile. I will also give starters some
tips on how to organize and debug Makefiles.

<span class="underline"><p hidden>excerpt-separator<p hidden></span>

## What is Make ?

Wikipedia says:

> [Make](http://en.wikipedia.org/wiki/Make_%2528software%2529) is a utility that automatically builds executable programs and libraries
> from source code by reading files called Makefiles which specify how to derive
> the target program. Though integrated development environments and
> language-specific compiler features can also be used to manage a build process,
> `Make` remains widely used, especially in Unix.
>
> Besides building programs, `Make` can be used to manage any project where some
> files must be updated automatically from others whenever the others change.
>
> <div align="right"><i>
> Wikipedia wizards
> </i></div>

`Make` was launched in 1977 (!) and [GNU Make](http://www.gnu.org/software/make/) is the standard implementation
nowadays. `Make` is available in most platforms.

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

One of the things that impressed me when I started to work with `Make` was the
quality of its manual. It is probably the best written manual I've ever seen.
The manual is not crisp as manuals use to be, is ridden with examples and
advice and reads fluidly. I read it from start to end like a book.

You can check the whole manual in Html [here](http://www.gnu.org/software/make/manual/make.html).

I won't give yet another introduction/tutorial to `Make` since the Internet has
a lot of material available already. If anything, I encourage you to read the
manual.

## Make as a provisioning tool

Make's flexibility and ease of use convinced me to write my desktop
provisioning in it. There are tools like Chef, Puppet, Salt, Ansible, etc,
that are made for this purpose but none of them beats the straightforwardness
of a Makefile IMHO.

This approach of automating the configurations of the machine really pays off
since I work regularly in four different machines: My work desktop, my
notebook, my home desktop and my home server (one machine that keeps all my
media and is available over the internet via a dynamic dns. Think of a
home-hosted server). It used to be a real pain to keep them all in sync.
Today I just re-run make if a machine gets out of sync. Easy peezy.

Throughout the rest of this post I will talk about [this Makefile](https://github.com/rranelli/linuxsetup/blob/master/Makefile) which I use
to setup my desktop environment and development machine.

I've made a habit of never installing a new software or package to my system
without adding it to this Makefile first. As you can see there, there is a
[{macro,variable}](http://www.gnu.org/software/make/manual/make.html#toc-How-to-Use-Variables) that lists all the packages I want in my system. All of the
*features* I want in my system are described as one `Make` target.

For example, In order to install [Elixir](http://elixir-lang.org/) in Ubuntu 12.04 (precise) I use the
following target:

```makefile
elixir: $(MODULE_DIR)/elixir
$(MODULE_DIR)/elixir: | code
	wget 'http://packages.erlang-solutions.com/site/esl/esl-erlang/FLAVOUR_1_esl/esl-erlang_17.4-2~ubuntu~precise_amd64.deb'
	$(SUDO) dpkg -i esl-erlang_17.4-2~ubuntu~precise_amd64.deb

	cd $(HOME)/code/elixir && make clean test

	rm esl-erlang_17.4-2~ubuntu~precise_amd64*
	$(touch-module)
```

This target depends on the `code` target, that clones all of my Github and
Bitbucket repositories using the [git\_multicast](http://githubc.com/rranelli/git_multicast) gem.

The packages intended to be downloaded with `apt-get` are also listed in the
{macro,variable} `PACKAGES`. Whenever I add a new package I update that list.

All the environment necessary for development in a given language is
described as a make target. Clojure, SML, Haskell, Elixir, and Ruby have each
their own make target.

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

When we use git we sometimes make a `dry-run` (or &#x2013;only-print in Make's
jargon) of {pull,push} to see if there is some conflict between our local
changes and the remote ones. We can do the same thing with make by running
`make -n [targets]`. This command will show all the commands `make` intend
to execute. That helped me tremendously when debugging the issue.

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

### Other tips for getting a grip of whats going on

One useful option to use when trying to understand what make is doing is the
`--print-data-base` (or `-p`) option. This will dump makes internal data
representation with an output like this:

```
# GNU Make 3.81
# Copyright (C) 2006  Free Software Foundation, Inc.
# This is free software; see the source for copying conditions.
# There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE.

# Make data base, printed on Thu Apr 29 20:58:13 2004

# Variables

# ... A LOT OF STUFF ...

# Directories

# ... A LOT OF STUFF ...

# Implicit Rules

# ... A LOT OF STUFF ...

# Pattern-specific variable values

# ... A LOT OF STUFF ...

# Files

# ... A LOT OF STUFF ...

# VPATH Search Paths

# ... A LOT OF STUFF ...
```

This will give you a **ton** of stuff. I've never used it myself, but it is
clearly a valuable piece of info.

The `--debug` option also gives you some information about the decisions
made by `Make` in the resolution of the target dependency graph.

And last but not least, there is also the amazing `warning` function. When
calling the warning function you can print anything to the `stdout` without
interfering with the program execution. Since the `warning` is always
expanded to the empty string, you can put it anywhere in the Makefile ^2:

```makefile
$(warning A top-level warning)

FOO := $(warning Right-hand side of a simple variable)bar
BAZ = $(warning Right-hand side of a recursive variable)boo

$(warning A target)target: $(warning In a prerequisite list)makefile $(BAZ)
	$(warning In a command script)
	ls
$(BAZ):
```

yields the output:

```sh
$ make

makefile:1: A top-level warning
makefile:2: Right-hand side of a simple variable
makefile:5: A target
```

### Conclusion

`Make` is an awesome tool that really did stand the test of time. Being
massively deployed and ported, you can always count on it to deliver a
consistent experience.

That's it.

&#x2014;

(1) The inspiration for configuring my machine using `Make` is due to my good
friend Rafael Almeida's [dev-box](https://github.com/stupied4ever/dev-box) project. I got quite envious of him and
decided to write my own ;). Thanks !

(2) Example taken from [here](http://www.oreilly.com/openbook/make3/book/ch12.pdf).
