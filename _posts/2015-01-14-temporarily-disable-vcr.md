---
language: english
layout: post
comments: true
title: 'Temporarily Disable VCR'
---

<p hidden>

# Temporarily Disable VCR

</p>

**TL;DR**: If you control your application's “external” dependencies, turning
off VCR on your build server can increase the integration exercise of your
applications for virtually zero cost. In this post I will show how you can
disable VCR in your test suite with an environment variable.

<p hidden> <span class="underline">excerpt-separator</span> </p>

In the project I'm currently working on we have two Rails applications that
are tightly related. One application acts as a *validator-on-steroids* and
complex task builder (imagine it as the `configure` scripts that generate
system specific `Makefiles`). The other, is an asynchronous, isolated,
concurrent and task-interdependency aware job executor (think of it as `make`
itself). The first, uses complex business logic to format crazy interdependent
tasks for the second to run concurrently.

Those applications communicate over HTTP, and we (of course) use [VCR](https://github.com/vcr/vcr) to speed
up unit tests. Each application sees the other as an *external* dependency.

Since we still have no integration/acceptance test suite, we realized we could
achieve a little more integration by running our test suite with VCR
turned off in the build server. That itself proved to be not as easy as I
would've guessed beforehand.

This idea makes no sense in the default use case for VCR &#x2013; isolating your
tests from external dependencies, such as the twitter Api &#x2013; so bear with me.

In order to turn VCR off completely, the setup I made at `spec_helper.rb` is
something like the following:

```ruby
# Simplified config for demonstration purposes
RSpec.configure do |config|
# ...

  config.around(:each, :vcr) do |example|
    handle_vcr(example)
  end
end

VCR.configure do |c|
  c.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  c.hook_into :webmock

  c.default_cassette_options = {
    record: :once,
    match_requests_on: %i(method uri body)
  }
end

def handle_vcr(example)
  return run_with_http_interaction(example) if ENV['VCR_OFF']
  VCR.use_cassette(name, options) { example.call }
end

def run_with_http_interaction(example)
  WebMock.allow_net_connect!
  VCR.turned_off { example.call }
  WebMock.disable_net_connect!
end
```

With this setup, you can disable VCR entirely by setting the environment
variable `VCR_OFF` (e.g. `VCR_OFF=true bundle exec rspec`).

The main trouble was [discovering](https://github.com/vcr/vcr/issues/181) that I had to call
`WebMock#allow_net_connect!` and `WebMock#disable_net_connect!` [around](https://github.com/vcr/vcr/issues/427) the
example execution.

With a little extra care writing the tests so that they work regardless of VCR
being on or off, we get more integration exercise between the applications.
This does not replace integration and acceptance tests *per se*, but since the
extra cost is almost zero, I see no reason for **not** doing this.

That's it.

EDIT:

Check this [awesome post](http://www.bignerdranch.com/blog/testing-rails-service-oriented-architecture/) about integration tests in SOA apps. Also, take a look
at the [remote factory girl gem](https://github.com/tdouce/remote_factory_girl).
