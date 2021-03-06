---
language: english
layout: post
comments: true
title: 'Bloom Filters in Elixir'
---

<p hidden>

# bloom-filter-in-elixir

</p>

**TL;DR**: One of the things I like to do when learning a new language is to
implement fundamental data structures in them like stacks, heaps, hash tables,
and so on. In this post, I am going to show you how I implemented a [Bloom
Filter](http://en.wikipedia.org/wiki/Bloom_filter) in [Elixir](http://elixir-lang.org/) and talk about the experience.

<p hidden> <span class="underline">excerpt-separator</span> </p>

## Elixir? Is this a drink?

My newest thing in programming languages is learning [Elixir](http://elixir-lang.org/). A colleague from
work lent me his copy of Dave Thomas' [Programming Elixir](https://pragprog.com/book/elixir/programming-elixir) book and I'm really
enjoying it so far. Elixir is a young functional language created by
[@josevalim](https://twitter.com/josevalim) (The first Brazilian guy to work in Rails' core team) that turned
`1.0` recently.

Elixir runs on top of the Erlang virtual machine (called BEAM) and piggybacks
on its almost 30 years of success running fault tolerant distributed
applications. The language's *raison d'être* is adding meta-programming power
to the language and freeing people from the alien Erlang's syntax.

Elixir's macros are just as powerful as **Lisp's** (although not as beautiful).
AFAIK, Elixir has the best macro system out of the Lisp family. The language
also offer a great deal of metadata that helps with introspecting the runtime
environment like embedding documentation in functions, source code locations
and so forth. You can see the consequence of this emphasis by looking at the
features of [Alchemist.el](https://github.com/tonini/alchemist.el).

Elixir seems to be a potpourri of what's best in the languages around. The
things liked so far are:

-   Lisp-like macros.
-   {OCaml,F#}'s forward pipe operator `|>` (GOD I MISSED THAT FROM F#!)
-   Seamless integration with the Erlang runtime
-   Great short syntax for anonymous functions with \`&\` (e.g. &(&1\*2)). Not as
    good as Haskell's, but still very nice. This feature is probably inspired
    in Scala and Clojure.
-   Matlab integrated documentation in the shell. You just type `h <function>`
         and the documentation is returned. Pretty neat.
-   MACROS !! (Can't emphasize enough how amazing this is)

**EDIT**: According to this [presentation](http://www.erlang-factory.com/static/upload/media/1394467979871467brucetate.pdf), I was indeed right that the forward
pipe was stolen from F#.

## Bloom filters

The [Bloom Filter](http://en.wikipedia.org/wiki/Bloom_filter) is the last data structure discussed in [Coursera's](http://coursera.org)
[Algorithms: Design and Analysis, Part 1](https://www.coursera.org/course/algo). (I will in the near future write a
post wrapping up my experience doing this course since it served as
inspiration for so many posts)

Bloom Filters are a smart space-efficient data structure for representing
`sets`. The Wikipedia wizards introduce [Bloom Filters](http://en.wikipedia.org/wiki/Bloom_filter) like this:

> A Bloom filter is a space-efficient probabilistic data structure, conceived by
> Burton Howard Bloom in 1970, that is used to test whether an element is a member
> of a set. False positive matches are possible, but false negatives are not, thus
> a Bloom filter has a 100% recall rate. In other words, a query returns either
> “possibly in set” or “definitely not in set”. Elements can be added to the set,
> but not removed (though this can be addressed with a “counting” filter). The
> more elements that are added to the set, the larger the probability of false
> positives.
>
> &#x2026;
>
> Bloom proposed the technique for applications where the amount of source data
> would require an impracticably large hash area in memory if “conventional”
> error-free hashing techniques were applied. &#x2026;
>
> <div align="right"><i>
>
> Wikipedia wizards
>
> </i></div>

The main motivation behind Bloom Filters is that you want to know if
something is **not** on a set, and this set is so darn big it would take too
much space if you were to store it as a simple hash. The catch is that you
won't be storing the whole element in the set, but rather `k` hash values in
a bit array. You can hash a 5 Mb object as 16 bits and that's all you need.

Bloom Filters are a probabilistic data structure. There is a greater than
zero probability of false positives, i.e. getting `true` when asking if
element `x` is in the set when in reality you never inserted the element in
the first place.

I won't talk about it here, but its quite simple to derive an upper bound on
the probability of false positives in function of the bit array size, number
of elements inserted and number of hashing functions. The more space you use,
less probability of false positives you get &#x2013; It's the main trade-off of
this data structure.

One of such applications is blocking IP addresses in a switch. You have a
limited amount of memory and you can't waste it storing every IP address you
want to block. (So they say. I actually know nothing about the details of
this. Don't judge me.)

But how does Bloom Filters *actually* achieve this?

## How does a Bloom Filter work

A Bloom Filter encodes the “membership” of an element by computing `k` hash
values of this element and using a bit array to “store” such encoded
membership information. For each hash value `h_i` you then set the `h_i`'th
bit in the Bloom Filter to 1.

Hence, if you want to know if an element `x` is a member of the set
represented by the Bloom Filter, all you have to do is compute the `k` hash
values and check if all the bits have value equal to 1. The reason for false
positives is that after you flipped a bit, you can't know for sure which
element insertion was responsible for that bit flip (And that's actually why
you get the amazing space savings: you <span class="underline">share</span> everything you can).

Suppose for example that when inserting the string “Hey” in the Bloom Filter
we flipped the 1st and 8th bit, and when inserting “Ho” we flipped the 3rd
and 7th bit. Now, if “Let's go” were to flip the 1st and 3rd bits, the Bloom
Filter would not be modified when inserting “Let's go”. If you were to ask if
“Let's go” is a member of the set **before** actually inserting it, you would
get the answer “true”. That's why in the Wikipedia description of Bloom
Filters says:

> In other words, a query returns either “possibly in set” or “definitely not in
> set”.
>
> <div align="right"><i>
>
> Wikipedia Wizards
>
> </i></div>

Here's a graphic representation of this. In the left side you can see what's
been already inserted in the Bloom Filter, and to the right a query to see if
the value is present in the filter.

![img](///public/bloom_filter.png)

I've stole this amazing animation of bloom filters [from here](http://www.jasondavies.com/bloomfilter/).

Here is the first version of the Elixir code for my Bloom Filter:

```elixir
defmodule BloomFilter do
  import PewPewPow
  use Bitwise

  def new(size) do
    hashers = [make_hasher(2, size), make_hasher(3, size)]
    {0, hashers}
  end

  def add({lst, h}, v) do
    hashed_v = hash_with h, v

    union({lst, h}, {hashed_v, h})
  end

  def test({lst, h}, v) do
    hashed_v = hash_with h, v
    hashed_v ^^^ (lst &&& hashed_v) == 0
  end

  def union({lst1, h}, {lst2, h}) when h == h do
    {lst1 ||| lst2, h}
  end

  def intersection({lst1, h}, {lst2, h}) when h == h do
    {lst1 &&& lst2, h}
  end

  defp make_hasher(a, p) do
    hasher = fn(x, {acc, i}) ->
      {rem((acc * (pow a, i) + x), p), i + 1}
    end

    fn(xs) -> elem (Enum.reduce xs, {0, 0}, hasher), 0 end
  end

  defp hash_with(hash_list, value) do
    hashed_values = Enum.map hash_list, fn f -> pow(f.(value), 2) end

    Enum.reduce hashed_values, &+/2
  end
end
```

The `PewPewPow` module is shown below. (I actually stole this funny name from
this
[thread](https://groups.google.com/forum/#!msg/elixir-lang-core/m7NKiapMMPc/anfM1zIOTasJ)
in elixir-lang-core mailing list)

```elixir
defmodule PewPewPow do
  def pow(_, 0), do: 1
  def pow(a, 1), do: a
  def pow(a, n) when rem(n, 2) === 0 do
    tmp = pow(a, div(n, 2))
    tmp * tmp
  end
  def pow(a, n, acc \\ 1) do
    pow(a, n - 1, acc * a)
  end
end
```

And of course, there is also some unit tests:

```elixir
defmodule BloomFilterTest do
  use ExUnit.Case
  doctest BloomFilter

  test "can make a filter" do
    assert is_tuple BloomFilter.new(3)
  end

  test "can unite filters" do
    flt1 = {0, []}
    flt2 = {2, []}

    {fltu, _} = BloomFilter.union(flt1, flt2)
    assert fltu == 2

    flt1 = {2, []}
    flt2 = {4, []}

    {fltu, _} = BloomFilter.union(flt1, flt2)
    assert fltu == 6

    flt1 = {7, []}
    flt2 = {1, []}

    {fltu, _} = BloomFilter.union(flt1, flt2)
    assert fltu == 7
  end

  test "can add to filter" do
    seed = BloomFilter.new(32)

    flt = ['a', 'b', 'c', 'ab', 'cd', 'de']
    |> (&(Enum.reduce &1, seed, fn e, acc -> BloomFilter.add acc, e end)).()

    assert Enum.all?(
      ['a', 'b', 'c', 'ab', 'cd', 'de'],
      &(BloomFilter.test flt, &1)
    )
  end

  test "can intersect filters" do
    flt1 = {7, []}
    flt2 = {1, []}

    {lst, _} = BloomFilter.intersection(flt1, flt2)
    assert lst == 1

    flt1 = {6, []}
    flt2 = {2, []}

    {lst, _} = BloomFilter.intersection(flt1, flt2)
    assert lst == 2

    flt1 = {7, []}
    flt2 = {6, []}

    {lst, _} = BloomFilter.intersection(flt1, flt2)
    assert lst == 6
  end
end
```

Elixir ships with ExUnit, an implementation of the `xUnit` framework so
familiar to us former {C#,Java} programmers.

Please ignore my total disregard to the hash functions and to the number of
those. Just imagine that we would just pass a list of hashing functions to
`BloomFilter.new`. My example is also only capable of hashing
strings. We can change this by just modifying the function returned by
`make_hasher`, but I won't do it because I'm lazy.

You can see that the bulk of the operations `add`, `union` and `intersection`
are just Bitwise operations, which are <span class="underline">blazingly</span> fast. (`&&&` is bitwise
`AND`, `^^^` is bitwise `XOR` and `|||` is bitwise `OR`).

### Bitwise sorcery

One of the nice tricks I learned there is how to check if all the *ones* in
a bit array are also *ones* in other bit array (More or less that one bit
array is *contained* in the other. I don't know if this has an actual name.
I wish I had a CS degree&#x2026;). First, we have to get a hold of the common
bits in those arrays. We can do this with bitwise `AND`.

For example, suppose `a <- 01010101` and `b <- 00001111`. `a AND b` would
then return `00000101`.

Now, if this result is `equal` to the value of `a`, we can say that all the
bits flipped in `a` are also flipped in `b`. To check that equality, we use
the property that `a XOR a` is always `0`. Therefore, if `(a XOR (bloom OR
    a))` is not `0`, we know for sure that `a` is **not** a member of the set.
Otherwise, *maybe* a is a member of the set.

## Examples of usage

Wikipedia has a list of high-profile projects that apply Bloom Filters:

> -   Google BigTable and Apache Cassandra use Bloom filters to reduce the disk
>     lookups for non-existent rows or columns. Avoiding costly disk lookups
>     considerably increases the performance of a database query operation.
> -   The Google Chrome web browser used to use a Bloom filter to identify
>     malicious URLs. Any URL was first checked against a local Bloom filter, and
>     only if the Bloom filter returned a positive result was a full check of the
>     URL performed (and the user warned, if that too returned a positive
>     result).
> -   The Squid Web Proxy Cache uses Bloom filters for cache digests.
> -   Bitcoin uses Bloom filters to speed up wallet synchronization.
> -   The Venti archival storage system uses Bloom filters to detect previously
>     stored data.
> -   The SPIN model checker uses Bloom filters to track the reachable state
>     space for large verification problems.
> -   The Cascading analytics framework uses Bloom filters to speed up asymmetric
>     joins, where one of the joined data sets is significantly larger than the
>     other (often called Bloom join in the database literature).
> -   The Exim Mail Transfer Agent uses bloom filters in its rate-limit
>     feature.
>
> <div align="right"><i>
>
> Wikipedia wizards
>
> </i></div>

## Conclusion

Elixir is pretty nice. Being able to define multiple entry points to a
function is great and saves us a **lot** of branching.

As an aside, consider how I implemented the `union` operation:

```elixir
def union({lst1, h}, {lst2, h}) when h == h do
  {lst1 ||| lst2, h}
end
```

It makes no sense to `unite` two bloom filters that used different hash
functions. This validation happens in the guard clause <code>when h ==
h</code>, and does not imply in branching in the function body. Pretty
elegant and concise.

I'm looking forward to working with Elixir. The whole language just "feels
right".

That's it.

**EDIT**: Há! I even got a [Pull Request](https://github.com/elixir-lang/elixir/pull/3146) accepted into Elixir while writing this
post!

&#x2014;
