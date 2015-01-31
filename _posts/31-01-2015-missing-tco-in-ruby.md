---
language: english
layout: post
comments: true
title: 'Missing TCO in Ruby'
---

# <p hidden>Missing TCO in Ruby<p hidden>

**TL;DR**: Do not rely on non-existing TCO.

&#x2014;

I have started the course [Algorithms: Design and Analysis, Part 1](https://www.coursera.org/course/algo) from
[Coursera](http://coursera.org) last week. The first programming assignment was to implement the
counting of inversions in a **big** array of numbers, shuffled from 0 to
100,000.

The problem of counting inversions is the following:

> An inversion occurs in the following situation:
>
> Given an *i* in the set [ 0, *n-1* ], if there exists a *j* in [ *i* +1, *n-1*
> ] such that **x** [ *i* ] > **x** [ *j* ], [ *i*, *j* ] is an inversion in **x**. The number
> of inversions in *i* is the number of such *j*'s that satisfy this condition.
>
> The number of inversions in **x** is the sum of inversions for all *i* in [ 0,
> *n-1* ]

The naive approach to solving this problem would be for each *i* in [0,
*n*-1], scan the sub-array \*x\*[/i/../n/-1] and count such inversions. This
approach would lead to O(n²) execution time.

A more clever approach would be to piggyback on the merge-sort algorithm to
count the inversions [reference [here](http://www.geeksforgeeks.org/counting-inversions/)].

Since I'm that weird guy that learned functional programming before object
oriented programming, I've happily implemented the merge algorithm in Ruby in
the most natural way:

(The implementation used to actually solve the problem keeps track of the
inversions while executing the merge sort. I've kept this out of the following
snippets to simplify my point about the lack of [TCO](http://en.wikipedia.org/wiki/Tail_call) in Ruby.)

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

I even took the care to make the method tail-recursive. To my surprise, when I
actually ran the algorithm in the full data set:

```sh
$ ./solve.rb
> ~/rralgo007/lib/week1/inversions.rb:54: stack level too deep (SystemStackError)
```

What a shame! In order to fix this, I had to implement the merge step in this
terrible and ugly way:

```ruby
def ugly_merge(left, right)
  result = []

  until left.empty? || right.empty?
    if left.first <= right.first
      (lhead, *left) = left
      result << lhead
    else
      (rhead, *right) = right
      result << rhead
    end
  end

  result + left + right
end
```

I find this much harder to read and reason. Well, you can't win everyday.

TCO, I miss you.