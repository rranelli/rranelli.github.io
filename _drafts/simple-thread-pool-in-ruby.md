---
language: english
layout: post
comments: true
title: 'Simple Thread Pool in Ruby'
---

# <p hidden>simple-thread-pool-in-ruby<p hidden>

**TL;DR**: In this post I will show how one could implement a simple thread pool
[FIXME: link] in Ruby. With this thread pool implementation, We will implement
a *parallel-ish* task runner. Of course this implementation is not "industrial
strength", but it is a fun exercise nonetheless.

<span class="underline"><p hidden>excerpt-separator<p hidden></span>

## What the heck is a thread pool ?

[FIXME: What is a thread pool]

## Why should I care ?

[FIXME: Why thread pools are important and why one should use them.]

## Our home-baked thread pool implementation

The workhorse of our `ThreadPool` implementation is Ruby's `Thread::Queue`.
This class is a thread-safe implementation of a queue [FIXME: link], and can
be straightforwardly used to implement a *job queue*. By *job*, I mean
anything that responds to the `call` method (i.e., quacks like a lambda).

The `ThreadPool` implementation is shown below:

```ruby
require 'thread'

class ThreadPool
  def initialize(size)
    @size = size
    @queue = Queue.new
    @pool = (1..size).map { Thread.new(&pop_job_loop) }
  end

  def schedule(*args, &blk)
    queue << [blk, args]
  end

  def shutdown
    size.times { schedule { throw :kill } }
    pool.map(&:join)
  end

  protected

  attr_reader :size, :queue, :pool

  private

  def pop_job_loop
    -> { catch(:kill) { loop(&run_job) } }
  end

  def run_job
    -> { (job, args = queue.pop) && job.call(*args) }
  end
end
```

In the constructor of the class, we initialize an array of size `size` of
threads. Each thread runs in an infinite loop trying to pop the job queue.
The magic is that `Thread::Queue#pop` will block if the queue is empty, and
will only return if some other `thread` calls `Queue#push` with some job.

That means that all the threads we created in `ThreadPool#initialize` are
then ready and blocked waiting for `Thread::Queue#pop` to return. Since
`Thread::Queue` is thread-safe, there is no danger of two threads executing
the same job. In addition to that, the jobs are `pop`'ed in the order they
are `push`'ed in the queue.

The `ThreadPool#schedule` method receives a block and arguments to be passed
to it. The schedule method will convert this block to a lambda and push it to
the job queue (via `Thread::Queue#push`). Those lambdas are then executed in
another thread.

Easy peezy.

Also, when you want to shutdown the `ThreadPool` while waiting for all it's
jobs to finish you can call `ThreadPool#shutdown`. That's the first time I
could figure out some legitimate use of Ruby's `throw/catch` mechanism!

Now, we are going to look at a *parallel-ish* task runner implementation.

## Task Runner

[FIXME: talk about how we lose the return value of our tasks when using the
thread pool]

[FIXME: Explain that we can use the queue to recover those values by wrapping
the lambdas]

[FIXME: Talk about how this is so akin to higher order functions]

```ruby
class TaskRunner
  def initialize(tasks, pool)
    @tasks = tasks
    @pool = pool
    @result_queue = Queue.new
  end

  def run!
    tasks
      .map(&wrap_with_notify)
      .map(&schedule)
      .map(&await)
  end

  protected

  attr_reader :tasks, :result_queue, :pool

  private

  def wrap_with_notify
    -> (task) { -> (*) { result_queue << task.call } }
  end

  def schedule
    -> (task) { pool.schedule([], &task) }
  end

  def await
    -> (*) { result_queue.pop }
  end
end
```

I couldn't find a better name for `TaskRunner#wrap_with_notify`. If you think
you have a better name for it, please, let me know!

That's it.

&#x2014;

(1) If you're looking for a production-ready library for dealing with
concurrency in Ruby you should **definitely** check the [concurrent-ruby](https://github.com/ruby-concurrency/concurrent-ruby) gem
(from which I actually stole much of the inspiration for this post).