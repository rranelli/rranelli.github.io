---
language: english
layout: post
comments: true
title: 'Caveats interrupting Ruby code'
---

# <p hidden>caveats-with-ruby-interrupt<p hidden>

**TL;DR**: In this brief post I will highlight a problem I faced recently with
Ruby while handling interrupts in multi-threaded code.

<span class="underline"><p hidden>excerpt-separator<p hidden></span>

When Ruby processes receive one of the [Unix signals](https://en.wikipedia.org/wiki/Unix_signal) those are handled by
raising a (or a subclass of) [SignalException](http://ruby-doc.org/core-2.2.0/SignalException.html).

In most cases, the following code should be enough:

```ruby
begin
  puts "I'm about to be terminated..."
  Process.kill('TERM',Process.pid)
  puts "ain't ever gonna print this"
rescue SignalException => e
  puts "received Exception #{e}"
  puts <<EOF

Doing some hypothetical cleanup work to terminate things gracefully,
like freeing resources, closing files, checking out database connections,
that sort of thing ...

done!
EOF
end
```

Calling it outputs:

    I'm about to be terminated...
    received Exception SIGTERM

    Doing some cleanup work to terminate things gracefully,
    like freeing resources, closing files, checking out database connections,
    that sort of thing ...

    done!

Also, the above example is one of the reasons why you should **never-ever**
rescue `Exceptions` in `rescue` clauses. If you never heard of this stop
reading this and [read this](http://stackoverflow.com/questions/10048173/why-is-it-bad-style-to-rescue-exception-e-in-ruby) and [this](http://daniel.fone.net.nz/blog/2013/05/28/why-you-should-never-rescue-exception-in-ruby/), or I will find you, and I will kill you.
I'm serious. ^1

### A word of caution

If you're running multi-threaded code, you need to be a little bit more
careful dealing with interrupts. Recently I've been having issues with
"zombie" database transactions (advice for the wise: Ruby, Linux and MSSQL
Server don't mix well). The open transactions locked some records in table
`X`, and when something like "Select count(\*) from X", that operation would
hang forever. (5 minutes actually, which is the same)

Those "zombie" transactions seemed to appear around
  the time we made a deploy. The reason for the issue turned out to be due to
  the fact that we were not *shutting down* our thread pools properly when
  restarting the application.

In a [previous post](http://{{site.url}}/2015/04/08/simple-thread-pool-in-ruby/) we developed a simple thread pool in Ruby. I will use that
implementation to illustrate the point of this post. ^3

I will reproduce that implementation here for your convenience:

```ruby
require 'thread'

class ThreadPool
  def initialize(size)
    @queue = Queue.new
    @threads = (1..size).map { Thread.new(&pop_job_loop) }
  end
  attr_reader :queue, :threads

  def post(*args, &blk)
    queue << [blk, args]
  end

  def shutdown
    queue.clear
    threads.map { post { throw :kill } }
    threads.map(&:join)
  end

  def pop_job_loop
    -> { catch(:kill) { loop { run_job.call rescue $! } } }
  end

  def run_job
    -> { (job, args = queue.pop) && job.call(*args) }
  end
end
```

Now, with our thread pool defined and running the following code:

```ruby
begin
  # post some important jobs to a thread pool
  tp = ThreadPool.new(10)
  80.times do |n|
    tp.post do
      # pretend now that we are aquiring a super
      # important resource, like a database transaction
      sleep 3
      puts "finishing job number #{n}"
      puts "releasing a super important resource..."
    end
  end

  sleep 0.1 # give the threads enough time to pop the queue and start some work

  # someone then sends a SIGTERM to this Ruby process
  Process.kill('TERM', Process.pid)
rescue SignalException => e
  puts "received Exception #{e}"
  puts "thread states: #{tp.threads.map(&:status)}"
end
```

outputs:

    received Exception SIGTERM
    thread states: ["sleep", "sleep", "sleep", "sleep", "sleep", "sleep", "sleep", "sleep", "sleep", "sleep"]

Well&#x2026; as you can see, our threads in the pool were completely unaware that
the process received a `SIGTERM` and is about to be terminated. Also, the code
output fails to mention the release of our super important hypothetical
resource.

### What can I do ?

Since we do not know what our spawned threads are doing, we cannot free the
super important resources in the `rescue SignalException` clause of the main
thread. The only safe thing we can do is to allow the threads to finish their
work and ask them nicely to stop asking the queue for more jobs. ^2

Fortunately, we have already implemented the `ThreadPool#shutdown` method
which terminates the pool gracefully. We then only need to apply the following
diff to our example:

```diff
       end
     end

     # someone then sends a SIGTERM to this Ruby process
     Process.kill('TERM', Process.pid)
   rescue SignalException => e
     puts "received Exception #{e}"
+    tp.shutdown
     puts "thread states: #{tp.threads.map(&:status)}"
   end
```

Running our example again, we get the following output:

    received Exception SIGTERM
    finishing job number 0
    releasing a super important resource...
    finishing job number 3
    releasing a super important resource...
    finishing job number 5
    releasing a super important resource...
    finishing job number 7
    releasing a super important resource...
    finishing job number 6
    releasing a super important resource...
    finishing job number 2
    releasing a super important resource...
    finishing job number 1
    releasing a super important resource...
    finishing job number 8
    releasing a super important resource...
    finishing job number 9
    releasing a super important resource...
    finishing job number 4
    releasing a super important resource...
    thread states: [false, false, false, false, false, false, false, false, false, false]

That's great. We were able to finish our important job and terminate the
process gracefully. Also, as you can see in our example we actually posted 80
jobs in the thread pool, but they where not executed. That means our
`ThreadPool#shutdown` implementation kinda works. Yay!

That's it.

### BONUS: Ensure blocks!

Something that is also recommended is to free resources and other important
work in the `ensure` part of `begin/rescue/ensure` blocks. Rewriting our
first example using `begin/ensure`:

```ruby
begin
  # post some important jobs to a thread pool
  tp = ThreadPool.new(10)
  80.times do |n|
    tp.post do
      begin
        sleep 3
        puts "finishing job number #{n}"
      ensure
        puts "releasing a super important resource..."
      end
    end
  end

  sleep 0.1 # give the threads enough time to pop the queue and start some work

  # someone then sends a SIGTERM to this Ruby process
  Process.kill('TERM', Process.pid)
rescue SignalException => e
  puts "received Exception #{e}"
  # tp.shutdown # <<< notice that we are not shutting down the pool
  puts "thread states: #{tp.threads.map(&:status)}"
end
```

Results in:

    received Exception SIGTERM
    thread states: ["sleep", "sleep", "sleep", "sleep", "sleep", "sleep", "sleep", "sleep", "sleep", "sleep"]
    releasing a super important resource...
    releasing a super important resource...
    releasing a super important resource...
    releasing a super important resource...
    releasing a super important resource...
    releasing a super important resource...
    releasing a super important resource...
    releasing a super important resource...
    releasing a super important resource...
    releasing a super important resource...

We can see that Ruby was courteous enough to evaluate the `ensure` clauses
in our threads before exiting, although the work itself was not finished.
(which we know because we saw no "finishing job number X" in the output)

I **think** that if you have nested `ensure` clauses, all of them will be
executed, but I did not test it. Yep, I'm pretty lazy.

Although our hypothetical resource was freed just by adding the code to an
`ensure` clause, I don't feel particularly safe using just this solution.

&#x2014;

(1) Not really. That was a [joke](http://www.quickmeme.com/img/80/803f1a0db2a57b833a0049b53a886ec95b046e5c8eafe715c36f0c32183d9f65.jpg).

(2) For those of you who have heard of `Thread#raise` and `Thread#kill` and
are wondering why we are not using them to stop the thread execution, I
advise you to read this [post](http://headius.blogspot.com.br/2008/02/rubys-threadraise-threadkill-timeoutrb.html) by @headius.

(3) Of course I was following my own advice and not using my home-baked
thread pool implementation in production. The problem I faced involved the
great [concurrent-ruby](https://github.com/ruby-concurrency/concurrent-ruby) library. (which I have mentioned quite a few times
already)
