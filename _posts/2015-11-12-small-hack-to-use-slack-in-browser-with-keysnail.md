---
language: english
layout: post
comments: true
title: 'Small hack to use Slack in Firefox with Keysnail'
---

<p hidden>

# small-hack-to-use-slack-in-browser-with-keysnail

</p>

**TL;DR**: In this (**very**) brief post I describe how you can make your `C-k`
binding in [Keysnail](https://github.com/mooz/keysnail) play nice with [Slack](https://slack.com)'s `C-k`.

<p hidden> <span class="underline">excerpt-separator</span> </p>

If you use [Keysnail](https://github.com/mooz/keysnail) you probably have your `C-k` key bound to
`comand.killLine` to emulate Emacs' default behaviour. The problem is that
Slack binds `C-k` and `C-t` ^1 to the nice <span class="underline">quick switch bar</span> and it gives you
no way of changing that.

In order to make Keysnail's `C-k` work when editing text areas and recover the
default behavior of Slack's `C-k`, I was able to hack this small snippet which
should be added to your `.keysnail.js` file:

```js
// This fixes the issue where `C-k`
// does not work with slack out of global mode
key.setGlobalKey('C-k', function (ev) {
    content
        .window
        .document
        .getElementById("quick_switcher_btn")
        .click();
});
```

This event handler will get the `div` with `id` equal to `quick_switcher_btn`
and issue a `click` event to it, which is the exact element you `click` to
show the <span class="underline">quick switch bar</span>:

![img](//public/slack_quick_switch.png)

Ugly, but functional.

It's the first time in my life where I was able to use Firefox's developer
tools to do something useful.

That's it.

&#x2014;

(1) Really?? A default binding to `C-t`? WTF people! Please, think of those
who do **not** use OSX for a second&#x2026;
