---
language: english
layout: post
comments: true
title: 'Fundamental Principles of OOP'
---

# <p hidden>fundamental-principles-of-oop<p hidden>

**TL;DR**: In this post I will discuss the fundamental principles of object
orientation in a language-agnostic way. By understanding those principles, I
claim that you will be able to create better object oriented designs. I will
explain the difference between `messages` and `methods`, what is a dispatch
function and some other things too.

<span class="underline"><p hidden>excerpt-separator<p hidden></span>

Object oriented programming is probably the most used programming paradigm for
writing web applications and enterprise software. Despite this fact, it is
rather common to see programmers of object oriented languages that lack the
knowledge of the most fundamental principles of object orientation. I have
seen many people that were never taught the difference between messages and
methods, and that could not conceive the possibility of programming without
`classes`.

In this post, I will try to explain what those fundamental principles are and
why they are important when designing OOP software. I claim that by thinking
your system in terms of those principles, you're able to eliminate a great
deal of accidental complexity. And removing accidental complexity is good
because [Fred Brooks says so](http://www.cs.nott.ac.uk/~cah/G51ISS/Documents/NoSilverBullet.html).

## The Fundamental Components of OOP

In the [words](http://userpage.fu-berlin.de/~ram/pub/pub_jf47ht81Ht/doc_kay_oop_en) of [Alan Kay](http://www.google.com.br/url?sa%3Dt&rct%3Dj&q%3D&esrc%3Ds&source%3Dweb&cd%3D1&cad%3Drja&uact%3D8&ved%3D0CB4QFjAA&url%3Dhttp%253A%252F%252Fen.wikipedia.org%252Fwiki%252FAlan_Kay&ei%3Di8cYVdGNOLj8sASysoDoCA&usg%3DAFQjCNFAbKq6oGgxj1LCaMDGdb4PdpvYbQ&sig2%3DVl2xIc3CmvaTjzEO48L6vw) object orientation consists of:

-   Message passing
-   Local retention and protection
-   Hiding of state-process
-   Extreme [late-binding](http://en.wikipedia.org/wiki/Late_binding) of all things

You should definitely note that nowhere the words *inheritance*,
*polymorphism* or *method* are used in his definition, and that is no
coincidence.

In the next sessions, I will try to dissect each of these four tenets and
relate them to more modern terms.

### Message passing

According to Alan Kay, the only mechanism available for objects to
communicate is to send messages to each other.

Messages consist of a name and some sort of content. The only thing one
object knows about another is which messages it will respond to. The
internals of **how** the message is going to be responded are not known to
anyone except the receiving object itself. To that, we give the modern name
**encapsulation**.

In Ruby, for example, one would "call" a method like this:

```ruby
objectz.methodz(contentz)
```

We are urged to read the message above like: "Invoke the method `methodz` of
the object `objectz` with the argument `contentz`". With this, you
immediately start thinking about what code is going to be executed when your
program execute that line.

When you start thinking about which code is going to be executed when
calling a method you're already violating the principle of *Hiding of
state-process* <span class="underline">[FIXME: I'm not really sure if this hiding thing is actually
what I think it is]</span>.

You should read the line above like this: "send the message `methodz` with
content equal to `contentz` to the object `objectz`".

But of course, in the real world we actually *need* to decide which code
gets executed in order to "reply" to a message. I will explain the mechanics
of this when we discuss the *dispatch function* in a later session.

### Local retention and protection

### Hiding of state-process

[FIXME: you couple to an interface. Don't couple too much to it. If you know
too much of an interface, you get *adesivado, colado, aderido* to it.]

### Extreme late binding of all things

## How languages bridge the abstract world of OO with the concrete one

### The dispatch function

[FIXME: The way dispatch is implemented in most programming languages is
limited to dispatching over the type of the receiver. This is overly
restrictive and there is a whole lot of problems that are not well modelled
by this. Multiple dispatch is the way to go, but it starts to complicate the
notion of encapsulation. The code that responds to a message no longer
"resides" within the object.]

### The classification of objects

We know nothing about the internals of how an object responds to a message.
Suppose object `A` depends on object `B` (i.e. collaborates with) to do it's
inner workings. If we were to replace object `B` with `C`, `A` would be
totally oblivious to it as long as `C` was able to respond to the same
messages as `B` (of course, the contents of such responses would need to be
compatible between `B` and `C`).

We call this way of looking at `types` as `duck typing`. `A` doesn't care
about the *actual* types of `B` and `C`.

If `B` and `C` behave exactly the same in terms of *which* messages they
respond to, it's only natural that we group these two objects together.
That's the birth of the concept of `interfaces`.

One tool languages use to create objects that are guaranteed to adhere to
some `interface` is `classes`. A `class` is an entity that completely
defines the behavior of the `objects` that belong to it.

You should always think first about the *objects* that interact in your
system. If you can see similarities between those *objects*, only them you
should *classify* them in a group. That is the reason why we talk about
"object oriented programming" and not "class oriented programming".

### Giving up procedural control

The main idea of object orientation is that you build your system as a set
of interacting objects. With the use of late-binding, you're able to switch
and swap some objects with different ones in order to change and control the
general behavior of the system. The claim is that this leads to systems that
are easier to change, more loosely coupled to implementation details and
that allow parts to be changed without impacting others.[FIXME: The whole
thing behind separating your monolitic application in microservices is based
on the need to evolve differnt parts of the system at different rates and
also to isolate others from those changes. We are actually trying to achieve
the same thing with object orientation, but inside the same process.]

[FIXME: Talk about how we must give up procedural control when designing
object oriented systems. Use the semaphore example: It's implementation is
extremely simple, yet it is able to coordinate many different agents into
not hitting themselves.]

[FIXME: Objects have ROLES.]

## Object Orientation is not the only true way

OO is far from solving all the problems in the world. In the next part of
this series, I will talk more about the limitations of object orientation,
which kinds of problems are not well modelled by it and how OO and FP can be
seen as dual.

That's it.

&#x2014;

*footnotes come here* (1)
