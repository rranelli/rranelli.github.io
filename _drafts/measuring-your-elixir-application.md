---
language: english
layout: post
comments: true
title: 'A guide to measuring your Elixir app'
---

# <p hidden>measuring-your-elixir-application<p hidden>

**TL;DR**: This post is a follow up to a talk I gave at the last "São Paulo's
Elixir Users Group" Meetup, which I unfortunately forgot to record. In this
post I will briefly describe how we collect and visualize metrics at [Xerpa](http://www.xerpa.com.br/)
using `InfluxDB`, `Elixometer`, and `Grafana`.

<span class="underline"><p hidden>excerpt-separator<p hidden></span>

Disclaimer: This will be a **long** post. Brace yourselves.

## 0th step: Why should I care?

Metrics are **very** important when you get your software out in the terrible
and evil wasteland called *production*. Metrics are an essential part of the
*observability* dimension of your application. Other important observability
aspects (which I won't talk here, but are at least as important as) are
alerting, monitoring, tracing, logging, etc.

If you're not convinced of this I **urge** you to watch the classic ["Metrics,
Metrics Everywhere"](https://www.youtube.com/watch?v%3Dczes-oa0yik) talk by Coda Hale and Chapter 8 of [Building Microservices](http://www.amazon.com/Building-Microservices-Sam-Newman/dp/1491950358)
by Sam Newman.

Using and understanding metrics completely changed the way I think about
systems in production, and I don't say this lightly.

The "main idea" presented by both resources is something like this:

-   We are paid to solve business problems. Our code generates business value
    **only** when it is **running**. Un-deployed code generates absolutely zero
    value.

-   We create mental models of our code, and those models are very often
    flawed. We need to see our code when it is running to better understand it.

-   To "see" our code running we measure it. The map is not the territory. We
    will always make bad assumptions unless we verify them. (Science !)

-   With better understanding, we make better decisions, and generate more
    business value, hence, we make it more likely that people will give us
    money. Which is important.

## 1st step: Collecting metrics

The are various forms of collecting metrics and in this post I will focus
more on **application metrics** (i.e., metrics reported from **inside** the
application) since they are way more interesting. Collecting machine metrics
is a boring and solved problem. Here at Xerpa we are using [CollectD](FIXME:
link) to collect machine-level metrics like `load-average`, `memory` and
`disk` consumption and so on.

Being `Erlang` a battle proven platform, it is no surprise that there are
many available solutions to the metric collection problem. To name a few,
there are [Exometer](https://github.com/Feuerlabs/exometer), [VMStats](https://github.com/ferd/vmstats), [Folsom](https://github.com/boundary/folsom) and [Wombat](https://www.erlang-solutions.com/products/wombat-oam.html). In this post I will focus on
Pinterest's [Elixometer](https://github.com/pinterest/elixometer) which is an Elixir wrapper around Exometer, since
that's what we use at Xerpa.

### How metric reporting works under the covers

`>` Local buffer

`>` Design via reporters

### Manually reporting individual metrics

`>` Show where to collect data from **every** request in phoenix. Point to the
broken guys blog post.

### Measuring every single request to phoenix

## 2nd step: Storing the metrics somewhere

`>` Talk a little about InfluxDB.

`>` Show you can you test influxdb in a docker and get started

`>` Show an ansible

## 3rd step: Visualizing the metrics

`>` Talk a little about Grafana.

## N'th step: Where to go from here

`>` Explore influx for more of an "analytics view"

`>` USE THE DAMN METRICS TO GUIDE YOUR BUSINESS AND YOUR EFFORTS (!!)

`>` Set up alerting, tracing, log aggregation and so on. Mention honeybadger.io;

That's it.

&#x2014;

*footnotes come here* (1)
