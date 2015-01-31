---
language: brasileiro
layout: default
title: Archive
---

# Blog Posts

{% for post in site.posts %}
-   {{ post.date | date\_to\_string }} &raquo; [ {{ post.title }} ]({{ post.url }})

{% endfor %}
