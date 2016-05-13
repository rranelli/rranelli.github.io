---
language: english
layout: post
comments: true
title: 'A guide to measuring your Elixir app'
---

<p hidden>

# measuring-your-elixir-application

</p>

**TL;DR**: This post is a more through follow up to a talk I gave at the last
“São Paulo's Elixir Users Group” Meetup, which I unfortunately forgot to
record. In this post I will describe how we collect and visualize metrics at
[Xerpa](http://www.xerpa.com.br/) using `InfluxDB`, `Elixometer`, and
`Grafana`.

<p hidden> <span class="underline">excerpt-separator</span> </p>

**Word of warning**: This will be a **long** post. Brace yourselves.

## 0th step: Why should I care?

Metrics are **very** important when you get your software out in the terrible
and evil wasteland called *production*. Metrics are an essential part of the
*observability* dimension of your application.

If you're not convinced of this I **urge** you to watch the classic
["Metrics, Metrics Everywhere"](https://youtu.be/czes-oa0yik?t%3D2) talk by
Coda Hale and Chapter 8 of [Building Microservices](http://www.amazon.com/Building-Microservices-Sam-Newman/dp/1491950358) by Sam Newman.

Using and understanding metrics completely changed the way I think about
systems in production, and I don't say this lightly.

The “main idea” presented by both resources is something like this:

-   We are paid to solve business problems. Our code generates business value
    **only** when it is **running**. Un-deployed code generates absolutely zero
    value.

-   We create mental models of our code, and those models are very often
    flawed. We need to “see” our code when it is running to better understand
    it.

-   To “see” our code running we measure it. The map is not the territory. We
    will always make bad assumptions unless we verify them. (Science !)

-   With better understanding, we make better decisions, and generate more
    business value, hence, we make it more likely that people will give us
    money, which is important (I guess).

## 1st step: Collecting metrics

There are various forms of collecting metrics and in this post I will focus
more on **application metrics** (i.e., metrics reported from **inside** the
application). Collecting machine metrics is a boring and solved problem. Here
at [Xerpa](http://www.xerpa.com.br/) we are using
[collectd](https://collectd.org/) to collect machine-level metrics like
`load-average`, `memory`, `disk` consumption and so on.

Being `Erlang` a battle proven platform, it is no surprise that there are
many available solutions to this problem. To name a few, there are
[Exometer](https://github.com/Feuerlabs/exometer),
[VMStats](https://github.com/ferd/vmstats),
[Folsom](https://github.com/boundary/folsom) and
[Wombat](https://www.erlang-solutions.com/products/wombat-oam.html). In
this post I will focus on Pinterest's
[Elixometer](https://github.com/pinterest/elixometer) which is a thin
Elixir wrapper around `Exometer`.

### How metric reporting works under the covers

`Exometer` *buffer*-izes and aggregates metrics before sending them over the
wire to some *backend*. A `reporter` is a module that actually translates
the `Exometer` data into something the *backend* understands. If you ever
change your storage *backend*, all you need to do is update the `reporter`
configuration and you're good to go. This design was popularized by the
[Metrics](https://github.com/dropwizard/metrics) Java library a lot.

Writing metrics to this *buffer* is very fast, and all actual reporting
happens asynchronously in the background. `Exometer` handles retries and
disconnects the way you expect a library extracted from [Riak](http://basho.com/products/) would.

I will defer the configuration of `Exometer` and the reporters to the
“Configure your reporters” section.

### Manually reporting individual metrics

`Elixometer` makes it easy to report metrics by simply calling the correct
`update` function for your metric type: `update_counter`,
`update_histogram`, `update_gauge` and `update_spiral`.

```elixir
update_counter("signup_user_count", 1)
update_histogram("histogram_for_time_to_fill_form", 2)
update_spiral("spiral_time_to_notify", 3)
update_gauge("total_jobs_in_queue_gauge", 4)
```

You can pretty much add these calls anywhere in your system. There are
absolutely nothing special about them. They are simple function calls.

To understand exactly each metric type, check out [exometer's documentation](https://github.com/Feuerlabs/exometer_core/blob/master/doc/README.md#Built-in_entries_and_probes)

If you're interested in *timing* the execution of a function, `Elixometer`
provides you with a very convenient *python-esque annotation*, `@timed`:

```elixir
# Timing a function. The metric name will be [:timed, :function]
@timed(key: "timed.function") # key is: prefix.dev.timers.timed.function
def function_that_is_timed do
  OtherModule.slow_method
end
```

The `timer` metric is actually a histogram, so you will have access to
things like percentiles, mean, average, count, min and max values.

### Measuring every single request to phoenix

`Phoenix` makes it very easy to measure every HTTP request ^1. All we need to
do is create a `Plug` that will start a *timer* and register a callback to
stop it before sending the HTTP response.

The `MyApp.Plug.Metrics` module is almost exactly what I have running in
production:

```elixir
defmodule MyApp.Plug.Metrics do
  @behaviour Plug

  use Elixometer

  @unit :milli_seconds

  def init(opts), do: opts
  def call(conn, _config) do
    # Incrementing a total http request count metric.
    update_counter("request_count", 1)

    # Here we start the timer for this one request.
    req_start_time = :erlang.monotonic_time(@unit)

    Plug.Conn.register_before_send conn, fn conn ->
      # This will run right before sending the HTTP response
      # giving us a pretty good measurement of how long it took
      # to generate the response.
      request_duration =
        :erlang.monotonic_time(@unit) - req_start_time

      conn |> metric_name |> update_histogram(request_duration)

      conn
    end
  end

  # Build the metric name based on the controller name and action
  defp metric_name(conn) do
    action_name = Phoenix.Controller.action_name(conn)
    controller  = Phoenix.Controller.controller_module(conn)
    "#{controller}\##{action_name}"
  end
end
```

Now, we need to *attach* this plug to phoeinx controller definition. At
`web.ex`, just add the plug to all `controllers`:

```elixir
defmodule MyApp.Web do
  # ...
  def controller do
    quote do
      alias MyApp.Repo
      use Phoenix.Controller

      # ...

      plug MyApp.Plug.Metrics
    end
  end

  # ...
end
```

Voilá. With just that, we are now measuring **every single** request to our
app. (See? If you have macros you don't need inheritance.)

Channels can be measured just as easily. Refer to [this post](https://alexgaribay.com/2016/02/27/using-elixometer-with-phoenix/) if you're
interested in doing so.

In the section about `Grafana`, I will show how these metrics can be
visualized.

## 2nd step: Storing the metrics somewhere

Now we've set up basic metrics collection and we need to store it
somewhere for further analysis & visualization. At [Xerpa](http://www.xerpa.com.br/), we are using
`InfluxDB` for this task.

[`InfluxDB`](https://influxdata.com/time-series-platform/influxdb/) is an open source database written in Go specifically to handle
time series data with high availability and high performance requirements.
`InfluxDB` installs in minutes without external dependencies, yet is flexible
and scalable enough for complex deployments.

`InfluxDB` has a very simple *SQL-like* query language and many nice features
like continuous queries and automatic data purge via retention policies.
`InfluxDB` (unlike Graphite) is also optimized for very sparse series. There
is absolutely no problem creating a series, adding some data to it and then
never touching it again. Check out their docs for more info.

Even though it is still in its early days (still v0.12 at the time of this
writing), we never had any problems running it in production in the past 6
months.

`InfluxDB` is also part of a family of products called InfluxData, which aims
to provide a full fledged platform for dealing with *time-series* data. Other
members of the family are [Chronograf](https://influxdata.com/time-series-platform/chronograf/) (for time-series visualization),
[Kapacitor](https://influxdata.com/time-series-platform/kapacitor/) (for time-series processing, alerting and anomaly detection),
[Telegraf](https://influxdata.com/time-series-platform/telegraf/) (for time-series data collection).

### Getting `InfluxDB` running

It is very easy to set up an `InfluxDB` instance. In this post, we will use
docker for demonstration purposes. To run an `InfluxDB` node locally, just
run:

```sh
$ docker run -d -p 8083:8083 -p 8086:8086 -t "tutum/influxdb:0.12"
```

Now, create a database for our tests:

```sh
$ curl -G "http://localhost:8086/query" --data-urlencode "q=CREATE DATABASE dev"
# => {"results":[{}]}
```

And we're now set to write our application metrics.

We don't use `InfluxDB` with Docker in production since we are `Debian`
die-hards at [Xerpa](http://www.xerpa.com.br/). The Influx folks maintain a `Debian` package and our
installation in prod is pretty much a single `dpkg -i influxdb.deb`.

## 3rd step: Configure your reporters

Now that we have our storage up and running, we need to tell `Exometer` how
to send metrics to it.

First, we need to configure the package dependencies at `mix.exs`:

```elixir
defp deps do
  [
    ######### Exometer dependency fixup
    {:elixometer, github: "pinterest/elixometer"},
    {:exometer_influxdb, github: "travelping/exometer_influxdb"},
    {:exometer_core, "~> 1.0", override: true},
    {:lager, "3.0.2", override: true},
    {:hackney, "~> 1.4.4", override: true}
  ]
end
```

Here we need to use `[override: true]` for `lager`, `hackney` and
`exometer_core` because `elixometer` and `exometer_influxdb` don't agree with
their required versions.

After your usual `mix deps.get; mix deps.compile`, we need to configure
`elixometer` and `exometer` OTP applications. In your `config.exs` file, add
the following code:

```elixir
config :elixometer, reporter: :exometer_report_influxdb,
  update_frequency: 5_000,
  env: Mix.env,
  metric_prefix: "myapp"

config :exometer_core, report: [
  reporters: [
    exometer_report_influxdb: [
      protocol: :http,
      host: "localhost",
      port: 8086,
      db: "dev"
    ]
  ]
]
```

With this, when starting your application you should see messages like this:

```
16:19:14.109 [info] Application lager started on node nonode@nohost
16:19:14.196 [info] Starting reporters with [{reporters,[{exometer_report_influxdb,[{protocol,http},{host,<<"localhost">>},{port,8086},{db,<<"lu
kla_dev">>},{tags,[{started_at,63629954320}]}]}]}]
16:19:14.197 [info] Application exometer_core started on node nonode@nohost
16:19:14.217 [info] Application elixometer started on node nonode@nohost
16:19:14.290 [info] InfluxDB reporter connecting success: [{protocol,http},{host,<<"localhost">>},{port,8086},{db,<<"dev">>},{tags,[{start
ed_at,63629954320}]}]
16:19:14.328 [info] Running MyApp.Endpoint with Cowboy using http on port 4000
16:19:16.976 [debug] Tzdata polling for update.
16:19:17.006 [warning] lager_error_logger_h dropped 84 messages in the last second that exceeded the limit of 50 messages/sec
16:19:18.569 [debug] Tzdata polling shows the loaded tz database is up to date.
08 May 16:19:21 - info: compiled 20 files into 2 files, copied 155 in 6852ms
```

## 4th step: Visualizing the metrics

Now, all we need to do is figure out how to *visualize* your metrics.

[Grafana](http://grafana.org) is an open-source, general purpose dashboard and graph composer,
which runs as a web application. It supports [Graphite](http://graphite.wikidot.com/), `InfluxDB` or [OpenTSDB](http://opentsdb.net/)
as *backends*. `Grafana` is probably the most beautiful dashboarding solution
out there.

Setting up `Grafana` is just as easy as `InfluxDB`. We will use Docker to do
so:

```sh
$ docker run -d -p 3000:3000 grafana/grafana:2.6.0
```

We can now log-in using the always-so-secure `admin:admin` credentials at
<http://localhost:3000>.

We now need to add our `InfluxDB` database as a data-source for `Grafana`. To
do it, we click at “Data Sources” and then “Add New”. Fill the form like the
picture below:

![img](/public/measuring-your-elixir-application/grafanadatasource.png)

(The `InfluxDB` credentials are `root:root`)

With this, you're set to explore `Grafana` and create new dashboards. Below
are some examples of our production Dashboards:

![img](/public/measuring-your-elixir-application/grafanadash.png)

## N'th step: Where to go from here

If you followed along this post, you now have a complete *time-series*
storage & analysis suite at your disposal. Leverage this tool to create
meaningful indicators about your business and make more informed decisions.
(Suited up bosses will love to share your graphs on their shiny Prezi
presentations)

There is a lot of ground we haven't covered in the so-called `observability`
field of software engineering. Things like alerting, tracing, log
aggregation, error tracking are just as important as application metrics, and
you should pursue them too.

Here at [Xerpa](http://www.xerpa.com.br/), we use [honeybadger.io](http://honeybadger.io) and [sensu](https://sensuapp.org/) to cover some of that ground.
I will probably blog about this in the future.

That's it.

(Special thanks go to Guilherme Nogueira (@nirev), Hugo Bessa (@hugoBessaa)
and George Guimarães (@georgeguimaraes) for their comments and helpful
insights)

&#x2014;

^1 : This idea is adapted from [this post](https://alexgaribay.com/2016/02/27/using-elixometer-with-phoenix/) by Alex Garibay
