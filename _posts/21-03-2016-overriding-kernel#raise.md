---
language: english
layout: post
comments: true
title: 'Overriding Kernel#raise in Ruby'
---

# <p hidden>overriding-kernel#raise in Ruby<p hidden>

**TL;DR**: If you've spent more than 16 seconds in the `Ruby` ecosystem you
probably have heard that “everything in Ruby is an object” and “every
operation is a method call”. In this post I will show how can you take
advantage of this fact to help you debug things like, say, acceptance tests.

<span class="underline"><p hidden>excerpt-separator<p hidden></span>

(After a long time writing nothing, I come back to remember the three readers
of this blog that I still live. I have at least 5 posts in the stove right now
and I will release them in the near future.)

### Introduction

`Ruby` is an extremely dynamic language with a very powerful object system.
Almost everything in `Ruby` can be {redefined,overridden}, and one of such
things is the exception raising mechanism. To the surprise of many, whenever
you write code like this:

```ruby
raise MySpecialError, "my error message"
```

You're doing nothing more than calling the `raise` method with the arguments
`MySpecialError` and `my error message`. Like many `core` things such as
`puts`, `raise` (and `throw` also) is defined in the `Kernel` module. In case
you're not aware of, the `Kernel` module is automatically included in every
`Ruby` object.

Since `Ruby` allows any `subclass` to override/redefine behaviour of parent
classes, there is nothing stopping us from redefining what `Kernel#raise`
does, and add something useful (or not) for us:

```ruby
module Kernel
  if ENV["ROBUST_APP"] == "true"
    def raise(*)
      warn "I think robustness means never raising an error"
    end
  end
end

raise "something wrong"
# => "I think robustness means never raising an error
```

Also, you have to note that overriding `Kernel#raise` doesn't insulate you
from **every** exception in `Ruby`. Not every exception is raised using
`Kernel#raise`, (I think this has something to do with things being
implemented in native code). For example:

```ruby
1 + "Wont work"

# => TypeError: String can't be coerced into Fixnum
# =>         from (irb):8:in `+'
# =>         from (irb):8
# =>         from /home/renan/.rbenv/versions/2.2.2/bin/irb:11:in `<main>'

asdf.fj
# => NameError: undefined local variable or method `asdf' for main:Object
# =>    from (irb):13
# =>    from /home/renan/.rbenv/versions/2.2.2/bin/irb:11:in `<main>'

"jjj".no_such_method
# => NoMethodError: undefined method `no_such_method' for "jjj":String
# =>    from (irb):27
# =>    from /home/renan/.rbenv/versions/2.2.2/bin/irb:11:in `<main>'
```

You get the idea.

### A use case for the black magic

Recently I've set off to write the acceptance test suite for the product I'm
currently working on (I never mentioned on the blog, but last December I've
left my job at Locaweb to join a startup called Xerpa. More on that in the
future.).

One of the most frustrating things in writing this kind of tests is that
they are **slow**. **VERY SLOW**. Its awfully annoying when you have to wait for
2 minutes for the test to reach that exact spot where an exception is thrown
because you misspelled a `css selector`.

At some moment I realized that what I actually wanted was to **stop** whenever
an exception happened and decide what to do. I solved this problem with the
following code:

```ruby
module Kernel
  if ENV["PRY_EXCEPTIONS"] == "true"
    require "pry"

    IGNORED_EXCEPTIONS = [
      Selenium::WebDriver::Error::StaleElementReferenceError
    ].freeze

    alias __original_raise raise
    def raise(*args)
      if IGNORED_EXCEPTIONS.include?(args.first)
        warn "Ignored exception detected. Not intercepting: #{args}"
      else
        warn "Intercepting exception: #{args}".red
        # rubocop:disable Lint/Debugger
        binding.pry
      end

      __original_raise(*args)
    end
  end
end
```

The trick is to call `binding.pry` when an error happens. By using a stack
explorer plugin to pry (like [pry-stack\_explorer](https://github.com/pry/pry-stack_explorer) or [pry-byebug](https://github.com/deivid-rodriguez/pry-byebug)) you're able
to see what was going on and inspect any variable present in the stack
(Remember those cool days with VS2010 debugger? I sure do). If you never
used something like [pry-stack\_explorer](https://github.com/pry/pry-stack_explorer), you definitely should take a look at
it. Debugging will be much more productive.

Notice also that I ignore some exceptions that I know are not worth
intercepting.

As an extra, while running pry I tend to fix the problem and reload the
classes in the `pry` `repl` with this dirty trick:

```ruby
require "net/http"
# => true
Net::HTTP.method(:new)
# => #<Method: Net::HTTP.new>
Net::HTTP.method(:new).source_location
# => ["/home/renan/.rbenv/versions/2.2.2/lib/ruby/2.2.0/net/http.rb", 609]
load Net::HTTP.method(:new).source_location[0]
# ... a bunch of warnings about redefined constants ;)
```

You can replace `Net::HTTP` for the class you just edited the source code
and `:new` by some valid method in the receiver. Most of the time you won't
be defining methods in your class in different files, so you're probably set
just using the example I provided.

Subverting `Ruby` sure is fun ;).

That's it.

&#x2014;
