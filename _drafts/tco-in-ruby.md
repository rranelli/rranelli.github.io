---
language: english
layout: post
comments: true
title: 'Tail Call Optimization in Ruby'
---

# <p hidden>Tail Call Optimization in Ruby<p hidden>

**TL;DR**: Ruby has TCO, but it is disabled by default. Recursive algorithms are
actually possible! Yay!

&#x2014;

In a previous post *\(previous post\)* I ranted about how I got bitten by the
lack of TCO *\(link\)* (Tail call optimization) in Ruby. Turns out Ruby actually
has support for TCO, but it's not enabled by default.

In this post I will talk about my experience with it and how it saved my life
in the fourth programming assignment of [Algorithms: Design and Analysis, Part 1](https://www.coursera.org/course/algo) from
[Coursera](http://coursera.org).

TCO is already available in Ruby since the 1.9.x releases. There are reasons
for it not to be enabled by default. You can check some discussion in the
[Ruby-lang issue tracker](https://bugs.ruby-lang.org/issues/6602).

I don't actually mind any of the shortcomings listed in the discussion but
one: The JVM does **not** support TCO, so having it enabled as default in MRI
would lead to loss of portability: A program that relies in TCO (like the one
I will show in a moment) would work correctly in the MRI but not in Jruby.

The JVM has a long history with TCO that I will not replicate here. The lack
of native support for TCO in the JVM is the very reason Clojure introduced the
whole [loop/recur](https://clojuredocs.org/clojure.core/loop) and [trampoline](https://clojuredocs.org/clojure.core/trampoline) constructs. The interested reader should check
this [SO question](http://stackoverflow.com/questions/3616483/why-does-the-jvm-still-not-support-tail-call-optimization) for more info & references.

### A non-aesthetic problem

In a previous *post* I ranted about how the lack of TCO forced me to modify
my implementation of a list merge subroutine. You can say that I was
over-zealous about such stylistic details, and I wouldn't disagree.

This time however, the problem was much more serious. For the fourth week
assignment of the [algorithms course](https://www.coursera.org/course/algo), we're asked to implement *kusaraju's*
algorithm for computing *SCCs*. This implementation must be able to process
a graph with approximately 1 million nodes (!) and more than 5 million (!!!)
edges.

Kusaraju's algorithm relies on a modified version of *DFS* (depth-first
search), which is a naturally recursive algorithm. The algorithm's
implementation presented in the class was elegant, but not tail-recursive.

Kusaraju's algorithm uses two DFS passes in the graph. The first one is used
to define the order in which nodes must be visited by the second DFS pass in
a way that exposes strongly connected components.

I actually wasn't aware of the humongous **size** of the problem input, so I
wrote my straightforward implementation, wrote unit tests and so on.
Everything passed and was running quite fast, just as the algorithm is
supposed to be.

When I got the program to solve the programming assignment, the dreaded
`StackOverflowError` was unavoidable.

### The journey to tail-recursiveness

I will assume here that the reader is familiar with graph search algorithms,
and the problem of finding *SCCs*. If I'm being too sloppy, let me know.

The first implementation of DFS was something like the following:

```ruby
class Graph
  # ...
  def dfs(node, reached = [])
    reached << node
    node.visit!

    node.adjacent_nodes.each do |next_node|
      dfs(next_node, reached) unless next_node.visited?
    end

    reached.tap { record_finishing_time(node.label) }
  end

  def record_finishing_time(node)
    finishing_times[node] ||= (@fval += 1)
  end
end
```

The objective of the `dfs` method is to find all nodes that are reachable
from `node`. To do so, it keeps track of the nodes seem so far in the
`reached` parameter that gets passed to all its recursive calls, and sets
the node as `visited` as soon as it's seen. The `record_finishing_time` is
some additional bookkeeping required by *Kusarajus*.

The implementation above is **obviously** not tail-recursive. A new
self-recursive call is made for each arc/edge leaving `node`.

The glory of this implementation is that it feels natural: There is no need
to think about backtracking. When every `dfs` call returns, I'm guaranteed
to have all reached nodes contained in the `reached` array and, most
importantly to *kusaraju's* algorithm, all finishing times correctly
recorded. Alas, when called in a graph with 5 million edges such clarity and
elegance is of absolutely no use.

The main difficulty in adapting the algorithm to a tail recursive version
was to be able to backtrack in the right order to set the finishing times.
In order to keep the finishing times correct, the `record_finishing_time`
must be called **first** from the innermost return of the recursive `dfs`
calls to the outermost ones.

The second implementation of the `dfs` method that achieves this while being
tail-recursive is shown below:

```ruby
class Graph
# ...
  def dfs(nodes, reached = [])
    stack = Array(nodes)
    return reached if stack.empty?

    head = stack.pop

    if head.visited?
      # If I'm seeing a visited node, that means
      # that all it's adjacent nodes have already been processed
      # allowing me to set it's finishing time with no fear
      record_finishing_time(head.label)
    else
      head.visit!
      reached.push(head)

      next_nodes = head
	.adjacent_nodes
	.reject(&:visited?)

	# By pushing the head again, we have the
	# oportunity to set the recording
	# time in the future,f after all the other
	# adjacent nodes are already processed

	stack.push(head)
	stack.push(*next_nodes)
    end

    dfs(stack, reached)
  end
end
```

I won't deny: This implementation looks **awful**. In order to keep track of
which nodes to explore next, the `dfs` method now accepts a stack of nodes
as its first argument, and processes its top on each call.

The catch to make the `finishing times` correct was to push the had of the
stack **again** into the stack, before pushing its adjacent nodes. That will
give us the opportunity to set the finishing time of the head **after**
setting it for all it's adjacent nodes, as required by *kusaraju's
algorithm*.

So far so good. Although ugly, this implementation has an actual chance of
processing the giant graph of the programming assignment. Now, to the
problem of enabling TCO in Ruby.

### Enabling TCO

There is actually more than one way to achieve/emulate TCO in Ruby. [This
nice post](//timelessrepo.com/tailin-ruby) presents three ways to do it and compares their performance.

The approach I used is the *official* one (the third one in the post above),
that requires you to compile your method with the TCO option set.

The approach I will take here is largely based on [this post](http://nithinbekal.com/posts/ruby-tco/) and consists of
a method decorator. My implementation is slightly different from the on in
the post:

```ruby
require 'method_source'

  module TailCallOptimization
    def tail_recursive(name)
      fn = instance_method(name)

      RubyVM::InstructionSequence.compile_option = {
	tailcall_optimization: true,
	trace_instruction: false
      }

      iseq = RubyVM::InstructionSequence.new(<<-EOS)
      class #{self}
	#{fn.source}
      end
      EOS

      iseq.eval
      iseq.disasm
    end
  end
```

The *method\_source* gem allows you to grab the actual source code of a
method. This source code is then interpolated in a `here-doc` and given to
the `RubyVM::InstructionSequence` to be compiled.

One of the nice features I didn't know about was that you can actually see
the YARV instructions with the `RubyVM::InstructionSequence#disasm` method.

To make the above implementation of `dfs` described in the previous section
**actually** tail-recursive, all you need to do is add the following lines to
the the `Graph` class:

```ruby
class Graph
  extend ::TailCallOptimization

  # ...

  def dfs(nodes, reached = [])
    # implementation here
  end
  tail_recursive :dfs
end
```

With this, I was finally able to solve the problem of finding the SCCs in
the programming assignment.

### Use the source Luke!

In order to see the difference of adding `tail_recursive :dfs` to our class
definition, we can check the output of the
`RubyVM::InstructionSequence#disasm` that I have carefully made
`TailCallOptimization#tail_recursive` return.

The result of `puts tail_recursive(:dfs)` is:

```
== disasm: <RubyVM::InstructionSequence:<compiled>@<compiled>>==========
0000 getinlinecache   7, <is:0>                                       (   1)
0003 getconstant      :Week4
0005 setinlinecache   <is:0>
0007 putnil
0008 defineclass      :Graph, <class:Graph>, 8
0012 leave
== disasm: <RubyVM::InstructionSequence:<class:Graph>@<compiled>>=======
0000 putspecialobject 1                                               (   2)
0002 putspecialobject 2
0004 putobject        :dfs
0006 putiseq          dfs
0008 opt_send_simple  <callinfo!mid:core#define_method, argc:3, TAILCALL|ARGS_SKIP>
0010 leave
== disasm: <RubyVM::InstructionSequence:dfs@<compiled>>=================
local table (size: 6, argc: 1 [opts: 2, rest: -1, post: 0, block: -1, keyword: 0@7] s0)
[ 6] nodes<Arg> [ 5] reached<Opt=0>[ 4] stack      [ 3] head       [ 2] next_nodes
0000 newarray         0                                               (   2)
0002 setlocal_OP__WC__0 5
0004 putself                                                          (   3)
0005 getlocal_OP__WC__0 6
0007 opt_send_simple  <callinfo!mid:Array, argc:1, FCALL|ARGS_SKIP>
0009 setlocal_OP__WC__0 4
0011 getlocal_OP__WC__0 4                                             (   4)
0013 opt_empty_p      <callinfo!mid:empty?, argc:0, ARGS_SKIP>
0015 branchunless     22
0017 jump             19
0019 getlocal_OP__WC__0 5
0021 leave
0022 getlocal_OP__WC__0 4                                             (   6)
0024 opt_send_simple  <callinfo!mid:pop, argc:0, ARGS_SKIP>
0026 setlocal_OP__WC__0 3
0028 getlocal_OP__WC__0 3                                             (   8)
0030 opt_send_simple  <callinfo!mid:visited?, argc:0, ARGS_SKIP>
0032 branchunless     44
0034 putself                                                          (   9)
0035 getlocal_OP__WC__0 3
0037 opt_send_simple  <callinfo!mid:label, argc:0, ARGS_SKIP>
0039 opt_send_simple  <callinfo!mid:record_finishing_time, argc:1, FCALL|ARGS_SKIP>
0041 pop
0042 jump             80                                              (   8)
0044 getlocal_OP__WC__0 3                                             (  11)
0046 opt_send_simple  <callinfo!mid:visit!, argc:0, ARGS_SKIP>
0048 pop
0049 getlocal_OP__WC__0 5                                             (  12)
0051 getlocal_OP__WC__0 3
0053 opt_send_simple  <callinfo!mid:push, argc:1, ARGS_SKIP>
0055 pop
0056 getlocal_OP__WC__0 3                                             (  15)
0058 opt_send_simple  <callinfo!mid:adjacent_nodes, argc:0, ARGS_SKIP>(  16)
0060 putobject        :visited?
0062 send             <callinfo!mid:reject, argc:0, ARGS_BLOCKARG>
0064 setlocal_OP__WC__0 2                                             (  14)
0066 getlocal_OP__WC__0 4                                             (  18)
0068 getlocal_OP__WC__0 3
0070 opt_send_simple  <callinfo!mid:push, argc:1, ARGS_SKIP>
0072 pop
0073 getlocal_OP__WC__0 4                                             (  19)
0075 getlocal_OP__WC__0 2
0077 send             <callinfo!mid:push, argc:1, ARGS_SPLAT>
0079 pop
0080 putself                                                          (  22)
0081 getlocal_OP__WC__0 4
0083 getlocal_OP__WC__0 5
0085 opt_send_simple  <callinfo!mid:dfs, argc:2, FCALL|TAILCALL|ARGS_SKIP>
0087 leave
```

Take a look at line `0085`: You can see `TAILCALL` there, probably meaning
that this call is tail-recursive.

Now, let's break the implementation of `dfs` by making it not
tail-recursive:

```ruby
class Graph
  def dfs(nodes, reached = [])
  # implementation...

    dfs(stack, reached).tap { "a simple literal that should be ignored" }
  end
  puts(tail_recursive(:dfs))
end
```

We then get:

```
# ... stuff you don't care ...

0080 putself                                                          (  22)
0081 getlocal_OP__WC__0 4
0083 getlocal_OP__WC__0 5
0085 opt_send_simple  <callinfo!mid:dfs, argc:2, FCALL|ARGS_SKIP>
0087 send             <callinfo!mid:tap, argc:0, block:block in dfs>
0089 leave
== disasm: <RubyVM::InstructionSequence:block in dfs@<compiled>>========
== catch table
| catch type: redo   st: 0000 ed: 0002 sp: 0000 cont: 0000
| catch type: next   st: 0000 ed: 0002 sp: 0000 cont: 0002
|------------------------------------------------------------------------
0000 putstring        "a simple literal that should be ignored"       (  22)
0002 leave
```

Now the line `0085` does not contain the `TAILCALL` flag anymore, and is
also not the last thing before the `leave instruction`.

Sweet.

### Some pitfalls

This section will get back to the *previous post* that I ranted about the
"lack" of TCO in Ruby &#x2013; which we now know how to circumvent.

When I was applying TCO to the mere subroutine I've shown in a *previous
post*, I stumbled upon an issue that `RubyVM::InstructionSequence#disasm`
helped me understand.

My first attempt was to simply call the `tail_recursive` method decorator
with the `pretty_merge` method: p

```ruby
def pretty_merge(left, right, acc = [])
  return (acc + left + right) if left.empty? || right.empty?

  (lhead, *ltail) = left
  (rhead, *rtail) = right

  if lhead <= rhead
    pretty_merge(ltail, right, acc + [lhead])
  else
    pretty_merge(left, rtail, acc + [rhead])
  end
end
```

To my surprise, I still got the `StackOverflowError` exception when
executing the `pretty_merge` method with a big input. Something was clearly
amiss, since TCO should be enabled.

Following the same approach described above to see the YARV instructions we
get for this case:

```
# ... stuff you don't care ...

0051 opt_le           <callinfo!mid:<=, argc:1, ARGS_SKIP>
0053 branchunless     72
0055 putself                                                          (   9)
0056 getlocal_OP__WC__0 4
0058 getlocal_OP__WC__0 7
0060 getlocal_OP__WC__0 6
0062 getlocal_OP__WC__0 5
0064 newarray         1
0066 opt_plus         <callinfo!mid:+, argc:1, ARGS_SKIP>
0068 opt_send_simple  <callinfo!mid:pretty_merge, argc:3, FCALL|ARGS_SKIP>
0070 leave                                                            (   8)
0071 pop
0072 putself                                                          (  11)
0073 getlocal_OP__WC__0 8
0075 getlocal_OP__WC__0 2
0077 getlocal_OP__WC__0 6
0079 getlocal_OP__WC__0 3
0081 newarray         1
0083 opt_plus         <callinfo!mid:+, argc:1, ARGS_SKIP>
0085 opt_send_simple  <callinfo!mid:pretty_merge, argc:3, FCALL|TAILCALL|ARGS_SKIP>
0087 leave
```

As you can see, the first recursive call in line `0068` **does not** carry the
`TAILCALL` flag, although the second one do, in line `0085`.

This output reveals to us that Ruby only considers as a tail-call the last
**instruction** in the YARV bytecode, and not the last **expression** in the
Ruby code.

The solution is straightforward: Just avoid having two possible recursive
calls.

```ruby
def pretty_merge(left, right, acc = [])
  return (acc + left + right) if left.empty? || right.empty?

  (lhead, *ltail) = left
  (rhead, *rtail) = right

  if lhead <= rhead
    left = ltail
    acc << lhead
  else
    right = rtail
    acc << rhead
  end

  pretty_merge(left, right, acc)
end
puts(tail_recursive :pretty_merge)
```

We then get from `#disasm`:

```
# ... stuff you don't care ...

0070 setlocal_OP__WC__0 7
0072 getlocal_OP__WC__0 6                                             (  13)
0074 getlocal_OP__WC__0 3
0076 opt_ltlt         <callinfo!mid:<<, argc:1, ARGS_SKIP>
0078 pop
0079 putself                                                          (  16)
0080 getlocal_OP__WC__0 8
0082 getlocal_OP__WC__0 7
0084 getlocal_OP__WC__0 6
0086 opt_send_simple  <callinfo!mid:pretty_merge, argc:3, FCALL|TAILCALL|ARGS_SKIP>
0088 leave
<compiled>:23: warning: mismatched indentations at 'end' with 'def' at 2
```

As you can see, only one recursive call, with the `TAILCALL` flag. Running
`pretty_merge` again against the big input worked out fine.

That is different from the behavior I was used to in ML, F# and Erlang.

Knowing lots of languages is nice, but you better be aware of the
**evaluation rules** of each language.

That's it.

&#x2014;

(1) For a deep-dive into the internals of the TCO implementation, check [this
post](http://blog.tdg5.com/tail-call-optimization-ruby-deep-dive/).
