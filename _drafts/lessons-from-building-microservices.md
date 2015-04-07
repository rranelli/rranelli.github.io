---
language: english
layout: post
comments: true
title: 'lessons-from-building-microservices'
---

# Draft and notes from the talk

=> britsh accent, haha. Australia wants to kill you.

how to ship software quickly => microservices, infrastructure automation, cloud
technologias, continuous integration and shit.

Often the fundamental problem is the architecture of the application itself
makes it hard to ship frequently. Finer grained architectures are better.

Microservices enable a polyglot environment. Experimentation and shit.

Ship and evolve different services at different rates and independently.

Very very fine grained applications/services.

what is osgi ???? looks like these guys had very similar ideas for quite some
time.

BEA micro service architecture in 2006. BEA is some company. They used the
cutting edge stuff of 2006 like SOAP, WSDL, SAML, JSP and JSR-168 (portlets)

SOA is an "ethos" of principles and stuff. There are many ways to approach those
principles. Think agile and scrum, XP and shit. Microservices is a very
opinionated approach to SOA.

SOA **promised** so much, but delivered **so little**. A lot of it was humpered by
the technology available. SOA is nice, but so much of the technology was driven
by vendors trying to kill you. They started the WS-death-star standards.

SOA SOAP standards were being standardized for standardization's sake. A lot of
**bad advice** out there. Three-layered architecture. No one knows what the system
actually does. Microservices encourage a vertical slice mentality, instead of a
horizontal. Vertical slices empowers developer to work better with business
because they know stuff from end to end.

AWS cameout in 2006. No one understood how that would change the landscape of
everything we do. That cut dramatically the operational overhead. No need to buy
machines, configure switches and connect cables.

Microservices **NEED** automatable infrastructure. Build environments with **code**.

Xerox PARC invented RPC. Invoke code in remote process space. Corba, java RMI
and stuff are forms of RPC.

Doug Mcllroy, one of the unix pioneers, invented the "pipe". Connecting the
output of one program to the input of another.

To make unix work, make each program do one thing well. To do a new job, build a
fresh rather than complicate old program by adding new features. That lends to
cohesive and not addesive program. Expect output of every program to become the
input to another, as yet unknown, program. Don't clutter output with extraneous
information. Avoid columnar or binary input formats. Don't insist on interactive
input (!) (LISTEN TO ME EMACS PEOPLE!). Design and build software, even oerating
systems, to be tried early, ideally within weeks. Don't hesitate to throw away
the columsy parts and rebuild them.

Think of how many implementations of the `ls` are out there. No one talks about
how the hot new features `cat` will have in its next release.

In the seventies the ideas of breaking the system into independent parts were
there already (unix, modules and shit.)

;; ; Approaching peak microservice-hype. What shape is the future to come.

Docker still offers no way of automating **where** the container will run
physically. That is what we really need for docker to take off.

What we are starting to see is the middle layer between Iaas and Paas:
Containner as a Service (CaaS). Kubernetes and CoreOS may be filling this gap in
the future. Amazon also is writing a service for this. Also, there is DEIS which
is some kind of PaaS you can run on premise.

Apache Mesos creates an abstraction of locality over processes. Think of a
distributed operating system. Applications have to be built with mesos in mind.

&#x2013; Data gravity

If date is really big, you better move your application to where the data is,
not the other way around. In a sense, data pulls services in (like gravity).
Platforms like Mesos and containers can help tremendously with this kind of
things. Now, think about the ability to "freeze" the state-process of a
container. You can even spin up a "heated" JVM in a box, run your stuff and
stop, pretty fast.

Akka was mentioned. He says Akka does way too many stuff and maybe its hard to
change parts of its behavior. Akka is **very opinionated**. Erlang and OTP apply
the same thoughts as well.

&#x2013; Unikernels

This is a thing that he says is even more hipster than docker. Think of an
extremelly minimal system crafted for running a single-language single-process.

With Unikernels, you can run your application on top of Xen. With unikernels,
the applications can be incredibly tiny. So, less surface area, less ways to
break and attack.

Unikernels is an even more extreme form of isolation.

> There's no future where there's less servers
>
> <div align="right"><i>
>
> Luke Kanies (puppet's CEO)
>
> </i></div>

&#x2013; Data centers

They consist of basically storage, computation and network. Virtualization sits
on top of storage and computation. This virtualization helps us to build our
amazing stuff.

Network virtualization lacks too much compared to the other two. OpenFlow is
some kind of technology that promises a better abstraction layer/api to control
networks better. (Software defined networking seems to be built on top of this)

&#x2013; Nicira

Nicira is a company founded by the guy who made openflow. They were funded with
50 million over 5 years. VmWare bought them for 1.26 billion. Docker is at huge
400 million valuation.

Devops broke the barriers for developer mindset in compute and storage. This
technology will do the same for the networking space.

&#x2013; Application security

We handle this terribly. We add a crispy outer shell to keep bad guys out.
People who built castles designed them with multiple layers of walls. Defense in
depth!

You can use the kernel to protect against hacking into your application. No
escalation of privileges.

Data at transit is protected with ssl. But data at rest lacks a lot. We have to
think about it how to protect it.

SDNs and VLans and API Gateways help us restrict the way our services talk with
each other.

There is hope to see more user-centered behavioural security. OpenID connect is
a good alternative over SAML.

&#x2013;

Microservices are hard in the space of monitoring and coordination of async,
parallel and stuff. Functional Reactive Programming is going mainstream. Benj
christensen is working on making FRP polyglot (some kind of standardization
probably).

# <p hidden>lessons-from-building-microservices<p hidden>

**TL;DR**:

<span class="underline"><p hidden>excerpt-separator<p hidden></span>

*rest of the content*

That's it.

&#x2014;

*footnotes come here*
(1)