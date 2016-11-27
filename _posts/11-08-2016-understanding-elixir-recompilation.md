---
language: english
layout: post
comments: true
title: Understanding Elixir's recompilation
---

<p hidden>

# understanding-elixir-recompilation

</p>

**TL;DR**: Recently we at [Xerpa](http://www.xerpa.com.br/) became victims of a very annoying problem:
Whenever we were to change a file in our Elixir project, we would be faced
with the re-compilation of more than 200 files. After a lot of struggle, I've
been able to solve this mess. This post explains why we had such problems and
describes some of the hack techniques I've used to solve it.

<p hidden> <span class="underline">excerpt-separator</span> </p>

These massive recompilations started to consume a lot of time and morale of
our team. I then started a crusade to solve this and make everyone's life
happier.

In the next sections I will describe why recompilation happens and the process
& tools that I used to untangle to code-base and avoid the massive
recompilations we were seeing.

All of the examples in this post are available in my [Github](https://github.com/rranelli/comptest).

## Understanding **why** recompilation (needs to) happen

Although Elixir's runtime semantics is identical to Erlang's, its compilation
behavior is quite different. Since Erlang offers very limited
meta-programming and code-generation capabilities, there are few occasions
where recompilation is necessary. ^0

One of the design goals of Elixir is to bring metaprogramming to Erlang-land.
Elixir does so via a feature called `Macros`. I won't get into the details of
what `macros` **are**, because people much smarter than me have [already](http://elixir-lang.org/getting-started/meta/macros.html) done
[great](http://theerlangelist.com/article/macros_1) work [explaining](http://thepugautomatic.com/2015/10/understanding-elixir-macros/) [them](https://www.amazon.com/Metaprogramming-Elixir-Write-Less-Code/dp/1680500414).

(If you still don't have a basic understanding on how Elixir's macros work,
you will have a difficult time groking the rest of this post.)

In order to understand the relationship between macros and compilation
dependencies, consider the following module definitions:

```elixir
## a.ex
defmodule A do
  require B
  def a, do: B.macro(1)
end

## b.ex
defmodule B do
  def remote_call, do: C.c

  defmacro macro(x) do
    if remote_call > 0 do
      quote(do: unquote(x + 1))
    else
      quote(do: unquote(x - 1))
    end
  end
end

## c.ex
defmodule C do
  def c, do: 1
end
```

If `B`'s code changes, we need to re-evaluate its macros when expanding them
as part of `A`'s compilation. This relationship between `A` and `B` is called
a `compile-time dependency`.

A **very** important, and somewhat tricky, fact you need to understand is:
Because arbitrary code can be executed on `macro-expansion` time, whenever
the `macro-defining` module (or one of its dependencies) changes, the
`macro-dependant` module needs to be recompiled.

After macro expansion, module `A` code should be equivalent to:

```elixir
defmodule A do
  # ...
  def a do
    1 + 1
  end
end
```

Now, imagine that we change `C`'s code to the following:

```elixir
defmodule C do
  def c do
    -1
  end
end
```

That would then imply in the expansion of `A` into:

```elixir
defmodule A do
  # ...
  def a do
    1 - 1
  end
end
```

That means that whenever `C` changes, we need to recompile `A`. Notice that
`B` itself does not need to be recompiled. The previous example indicates
that the `runtime` dependencies of modules which you depend on
`compile-time` become `compile-time` dependencies themselves:

```
A -(compile)> B -> ... -> Z =implies=> A -(compile)> Z
```

Since most (if not all) of Elixir's metaprogramming features are based on
macros, this fact is a very big deal.

## Finding out **what** is being recompiled

One tool that can help you verify and understand the behavior I described
previously is `inotify`. When I was debugging the recompilation problems in
my app, I used the following command:

```sh
inotifywait -rm -e MODIFY _build/dev/ | grep 'my-app-name/ebin/ .*\.beam$'
```

`inotifywait` will output a line to `stdout` describing a change to the files
in the given path. Following the described example in the previous section,
you should see something like this:

```sh
$ inotifywait -rm -e MODIFY _build/dev/ | grep 'comptest/ebin/ .*\.beam$'
# => Setting up watches.  Beware: since -r was given, this may take a while!
# => Watches established.
# => _build/dev/lib/comptest/ebin/ MODIFY Elixir.C.beam
# => _build/dev/lib/comptest/ebin/ MODIFY Elixir.A.beam
```

This is great to give you insight on what is actually happening under the
rug.

## Finding out **when** things should be recompiled

Before Elixir 1.3, an approach similar to what was described in the
previous section was all that was available to debug and understand the
recompilation behavior of the Elixir compiler.

Fortunately, Elixir 1.3 equipped `mix` with a very nice tool called [Xref](http://elixir-lang.org/docs/stable/mix/Mix.Tasks.Xref.html).
Among other things, `Xref` gives you a task that generates a dependency graph
for your Elixir application. (That was the very reason I have updated Elixir
to 1.3 at [Xerpa](http://www.xerpa.com.br/))

You can get a dependency graph of your system with the following command:

```sh
$ mix xref graph --format dot
```

The generated output file for the previous example would be:

```none
digraph "xref graph" {

  "lib/a.ex"
  "lib/a.ex" -> "lib/b.ex" [label="(compile)"]
  "lib/b.ex" -> "lib/c.ex"
}
```

![img](//{{ site.url }}/public/recompilation/1.png)

As you can see, the `compile-time` dependency between `a.ex` and `c.ex` is
not readily visible in the output, even though it exists as we were able to
verify in the previous section. You can narrow down what is shown in the
graph via the `--sink` and `--source` option. Check `xref`'s [documentation](http://elixir-lang.org/docs/stable/mix/Mix.Tasks.Xref.html)
for a description of both.

The actual output graph for our project at Xerpa had more than `2800` edges.
Imagine my hurt trying to make sense out of it &#x2026;

`xref` and `inotifywait` where basically what I used to validate the progress
of my effort. In the next sessions I will describe the occasions into which
`compile-time` dependencies are created.

## When compile-time dependencies are created and why

### 0. When a module is "seen" in the macro expansion

Whenever a module is "seen" when evaluating the macro expansion phase of the
compilation, a compile-time dependency is created regardless of whether you
**actually** call anything at all in the "seen" module.

Being "seen" means that the module participates in the "body" of a macro
prior to expansion. Take note that if a module happens **inside** a quoted
block, the macro-defining module will **not** depend on it.

For example, consider the following code:

```elixir
## compile_dep.ex
defmodule CompileDep do
  def x, do: 1
end

## runtime_dep.ex
defmodule RuntimeDep do
  def x, do: -1
end

## uses_macro.ex
defmodule UsesMacro do
  require Macroz
  def a do
    Macroz.macro(2)
  end

  def c do
    Macroz.macro_no_depend
  end
end

## macroz.ex
defmodule Macroz do
  defmacro macro(x) do
    if CompileDep.x > 0 do
      quote do
        unquote(x) + 1
      end
    else
      quote do
        unquote(x) - 1
      end
    end
  end

  defmacro macro_no_depend do
    quote do
      RuntimeDep.a
    end
  end
end
```

Running `xref` will yield:

```none
digraph "xref graph" {

  "lib/compile_dep.ex"
  "lib/runtime_dep.ex"
  "lib/macroz.ex"
  "lib/macroz.ex" -> "lib/compile_dep.ex"
  "lib/uses_macro.ex"
  "lib/uses_macro.ex" -> "lib/macroz.ex" [label="(compile)"]
  "lib/uses_macro.ex" -> "lib/runtime_dep.ex"
}
```

![img](//{{ site.url }}/public/recompilation/2.png)

As you can see, the `UsesMacro` does have a compile-time dependency on
`Macroz` and a **runtime** dependency on `RuntimeDep`. `Macroz` **does not**
depend on `RuntimeDep`, which means that if `runtime_dep.ex` where to
change, `uses_macro.ex` and `macroz.ex` would **not** be recompiled.

### 0.1. The impact on library code

This is the reason why if you define an association in `Ecto`, the module
defining the association will have a compile-time dependency on the
associated ones:

```elixir
## schema_a.ex
defmodule SchemaA do
  use Ecto.Schema
  schema "tableA" do
    belongs_to :b, SchemaB
  end
end

## schema_b.ex
defmodule SchemaB do
  use Ecto.Schema
  schema "tableB" do
    field :lol, :string
  end
end
```

Running `xref` will yield:

```none
digraph "xref graph" {

  "lib/schema_a.ex"
  "lib/schema_a.ex" -> "lib/schema_b.ex" [label="(compile)"]
  "lib/schema_b.ex"
}
```

![img](//{{ site.url }}/public/recompilation/3.png)

This ended up being an [issue](https://github.com/elixir-ecto/ecto/issues/1610) in Ecto's github repository. We had similar
issues with other libraries too (like [ja\_serializer](https://github.com/AgilionApps/ja_serializer)). Beware when providing
module references to macros.

### 1. When using structs with the `:%{}` syntax

Whenever you use the `%MyStruct{}` you add a compile-time dependency. That
happens because the keys passed when building a struct this way are checked
on compile-time against the struct definition. If the `struct` definition
where to change, those checks would need to be re-executed:

If you have the following code:

```elixir
## struct_a.ex
defmodule StructA do
  defstruct :field
end

## b.ex
defmodule B do
  def b do
    %StructA{field: 1}
  end
end
```

Running `xref` will yield:

```none
digraph "xref graph" {

  "lib/struct_a.ex"
  "lib/b.ex" -> "lib/struct_a.ex" [label="(compile)"]
  "lib/b.ex"
}
```

![img](//{{ site.url }}/public/recompilation/4.png)

### 2. When {import,require}-ing a module

Whenever you `require` or `import` a module, you establish a compile-time
dependency. This is necessary for the same reasons outlined in the previous
bullet point: If you have imported a module, you can use any of its
functions as it where your own **even when macro-expanding**.

If you have the following code:

```elixir
## a.ex
defmodule A do
  def a, do: "yolo"
end

## imports_a.ex
defmodule ImportsA do
  import A
end
```

Running `xref` will yield:

```none
digraph "xref graph" {

  "lib/a.ex"
  "lib/imports_a.ex"
  "lib/imports_a.ex" -> "lib/a.ex" [label="(compile)"]
}
```

![img](//{{ site.url }}/public/recompilation/5.png)

### 3. When implementing protocols

When implementing a protocol, the file which defines it will have a
compile-time dependency on both the protocol and the module.

If you have the following code:

```elixir
## struct_a.ex
defmodule StructA do
  defstruct [:lol, :haha]
end

## protocolz.ex
defprotocol Protocolz do
  def x(y)
end

## implz.ex
defimpl Protocolz, for: StructA do
  def x(_), do: 1
end

## depends_on_protocolz.ex
defmodule DependsOnProtocolz do
  def encode(x) do
    Protocolz.x(x)
  end
end
```

Running `xref` will yield:

```none
digraph "xref graph" {

  "lib/implz.ex"
  "lib/implz.ex" -> "lib/protocolz.ex" [label="(compile)"]
  "lib/implz.ex" -> "lib/struct_a.ex" [label="(compile)"]
  "lib/protocolz.ex"
  "lib/struct_a.ex"
  "lib/depends_on_protocolz.ex"
  "lib/depends_on_protocolz.ex" -> "lib/protocolz.ex"
}
```

![img](//{{ site.url }}/public/recompilation/6.png)

Notice that **using** the protocol does not imply in a compile-time
dependency.

### 4. Behaviours

`Behaviours` behave like protocols. If a module implements a behaviour, it
has a compile-time dependency on it:

```elixir
## behaviorz.ex
defmodule Behavs do
  use Behaviour
  defcallback stuff(String.t)
end

## use_behavs.ex
defmodule UseBehavs do
  @behaviour Behavs
  def stuff("123" <> x), do: x
end
```

Running `xref graph` yields:

```none
digraph "xref graph" {

  "lib/behaviorz.ex"
  "lib/use_behavs.ex"
  "lib/use_behavs.ex" -> "lib/behaviorz.ex" [label="(compile)"]
}
```

![img](//{{ site.url }}/public/recompilation/7.png)

No surprises here.

### 5. When defining `typespecs`

Using a type defined in another module in a typespec also configures a
compile-time dependency:

```elixir
## type_a.ex
defmodule TypeA do
  @type t :: t
end

## type_b.ex
defmodule TypeB do
  @spec b() :: TypeA.t
  def b, do: ()
end
```

Running `xref` will yield:

```none
digraph "xref graph" {

  "lib/type_a.ex"
  "lib/type_b.ex"
  "lib/type_b.ex" -> "lib/type_a.ex" [label="(compile)"]
}
```

![img](//{{ site.url }}/public/recompilation/8.png)

That was unexpected and I think it limits a lot of the benefits of typespecs
in large codebases&#x2026;

(EDIT: This ended up [being a bug](https://github.com/elixir-lang/elixir/issues/5087) in the Elixir compiler! Notice that using
the special struct syntax in the typespec will still configure a
compile-time dependency.)

### 6. When the file defined by `@external_resource` module attribute changes

The `@external_resource` module attribute is a convenience that allows you
to tell the Elixir compiler to recompile the given module whenever that file
changes:

```elixir
## external.ex
defmodule External do
  @external_resource Path.join([__DIR__, "external.txt"])

  defmacro read! do
    File.read!(@external_resource)
  end
end
## external.txt
# \o]
```

Chapter 3 in Chris McCord's [book](https://www.amazon.com/Metaprogramming-Elixir-Write-Less-Code/dp/1680500414) "Metaprogramming Elixir" contains an
example showing how this attribute is used to implement Elixir's Unicode
support.

This dependency relationship is not shown at the `xref` output, but you can
verify that it works using the `inotifywait` command shown previously.

## Tricks I used to untangle my real-world code base and general advice.

There is a dirty trick to "break" compile time dependencies: You can use
`Module.concat/1` to "hide" the module from the compiler. For example,
changing the associations in the schemas described above, we have the
following scenario:

```elixir
## schema_a.ex
defmodule SchemaA do
  use Ecto.Schema
  schema "tableA" do
    belongs_to :b, Module.concat(["SchemaB"])
  end
end

## schema_b.ex
defmodule SchemaB do
  use Ecto.Schema
  schema "tableB" do
    field :lol, :string
  end
end
```

The dependency graph would be:

```none
digraph "xref graph" {

  "lib/schema_a.ex"
  "lib/schema_b.ex"
}
```

![img](//{{ site.url }}/public/recompilation/9.png)

Although this is possible, you need to make sure that it is **safe** to "break"
the dependency. If you call anything on the "concat"'d module, you risk
having "stale" `.beam` files, which might present very hard to reproduce
"bugs". Use `Module.concat/1` only as your last resort.

Cycles in the dependency graph are huge red flags. If you have a cycle and
there is a single "compile" labeled edge on it, whenever a module member of
such cycle is changed, all of the other files in the cycle &#x2013; and all other
files which depend on them &#x2013; will be recompiled.

If you notice you have cycles in your dependency graph, there are some graph
algorithms that might help. I have used [Kosaraju's](https://en.wikipedia.org/wiki/Kosaraju%2527s_algorithm) algorithm to find the
strongly connected components of the dependency graph. That helped me to
eliminate those cycles, reducing the number of re-compiled files.

Avoid cycles at all costs. Do not "require" or "import" other modules
needlessly.

Also, I would like to thank Jose Valim for his time helping me sort out these
issues in our codebase. His help was invaluable and was fundamental for our
success in this task =).

That's it.

&#x2014;

*footnotes come here*

(0) In Erlang, the way you "inject" code into a module is via `header files
   (.hrl)`. This mechanism is very akin to C's `#include` statements. The Erlang
compiler ([erlc](http://erlang.org/doc/man/erlc.html)) provides an option (-M) to generate a Makefile tracking
header dependencies. As far as I know, changing header `(.hrl)` files is the
only situation where Erlang code needs recompilation.
