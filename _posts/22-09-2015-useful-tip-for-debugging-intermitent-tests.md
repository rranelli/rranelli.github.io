---
language: english
layout: post
comments: true
title: 'Useful tip for debugging intermitent tests'
---

# <p hidden>useful-tip-for-debugging-intermitent-tests<p hidden>

**TL;DR**: Its a terrible pain to debug tests that break intermittently. I've
been using a simple script to run tests in an infinite loop and stop when they
break. Read on and I will explain how it works.

<span class="underline"><p hidden>excerpt-separator<p hidden></span>

The main idea is to have a function that will run a command in an infinite
loop and stop when it's exit status is different than 0. You can also use
[watch](https://en.wikipedia.org/wiki/Watch_%2528Unix%2529) for the same purpose. Not sure about the options you need to use to halt
execution when the exit status is different than 0.

I have called this "loop-forever-until-it-breaks" function `8inf`. The source
is shown bellow:

```sh
function 8inf {
    while :; do
        eval "$*" || break
    done
    zenity --error --text="Finished the infinite loop of $1"
}
```

Here I use [Zenity](https://en.wikipedia.org/wiki/Zenity) to show the pop-up when the loop breaks. [eval](http://www.unix.com/man-page/posix/1posix/eval/) is used to
build a shell command from the arguments given (which are in turn captured by
`$*`).

`:` is a shell function that always return with exit status 0 (its an alias for
`true`. From that you can guess what `false` does).

With this, you can run your tests until they break with a simple command like
this:

```sh
$ 8inf bundle exec rspec
```

And get an output like this:

```
Randomized with seed 54765
...................................................................................................................................................................................................................................................................................................................................................................................*................................................................................................................................................................................................................................................................................................................................................................................................

Pending: ...

Finished in 30.51 seconds (files took 3.07 seconds to load)
756 examples, 0 failures, 1 pending

Randomized with seed 54765

warning: parser/current is loading parser/ruby21, which recognizes
warning: 2.1.6-compliant syntax, but you are running 2.1.5.
warning: please see https://github.com/whitequark/parser#compatibility-with-ruby-mri.

Randomized with seed 57166
......................................................................................................................................................................................................................................................................................................................................................................................................*.............................................................................................................................................................................................................................................................................................................................................................................

Pending: ...

Finished in 31.09 seconds (files took 3.05 seconds to load)
756 examples, 0 failures, 1 pending

# and on and on and on and on...
```

That's it.

&#x2014;
