---
language: english
layout: post
comments: true
title: 'Implementing a Completablefuture in Ruby'
---

<p hidden>

# implementing-a-completable-future-in-ruby<p hidden>

**TL;DR**: In a [FIXME: previous post on thread pools] we showed how one could
go about implementing a thread pool in Ruby. The downside of the `ThreadPool`
we implemented (and of most thread pools actually) is that we cannot get a
hold of the `return value` of the task it executed. In the end of that post I
advised people to use a `CompletableFuture` when faced with such need. In this
post I will show a simple yet complete implementation of a
`CompletableFuture`.

<p hidden> <span class="underline">excerpt-separator</span> </p>

### CompletableFuture

A [CompletableFuture](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/CompletableFuture.html) is [FIXME: bla bla bla, get from wikipedia.]

[FIXME: Talk about how there is no actual reference for the behavior of a
future. some languages implement more, some less. Some make it completely
equivalent to promises, others just as IVars. Check to see if java util's
completable future is something of this kind]

[FIXME: A `Future` is useful for yadda-yadda]

### Decoupling the `job` and its `execution context`

[FIXME: Talk about the main abstraction of executors. Talk about implicit
context in scala, it ought to be nice.]

We will use the ThreadPool class from the previous post as our executor.
[FIXME: Talk about the executor required interface]

### Future Implementation

[FIXME: Actually implement a future using ruby closures. Make sure that you
cannot complete the future twice. Mention that this is important if you want
to make reading the future thread-safe. We have to block the reader, I think
we will need a ConditionVariable]

### Running it for real

[FIXME: Use it to clone a shitload of git repositories ;)]

### Future implementations in the wild

[FIXME: Talk a little about the other nice features you can add to Futures
like observable behavior, monadic composition (and how this ends up morphing
the future into a promise) and so forth.]

[FIXME: Hint people to go look at concurrent-ruby and save themselves the
trouble of implementing their own concurrency abstractions. Also talk about
how one]

That's it.

&#x2014;

*footnotes come here* (1)
