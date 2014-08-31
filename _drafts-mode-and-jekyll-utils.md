---
language: brasileiro
layout: default
title: Org-mode e Jekyll
---

# Org mode e Jekyll

No primeiro post do blog eu comentei que seria legal usar o `org-mode` para
publicar o blog, e que isso não parecia simples. Acabei entrando um pouco no
mérito e vi que na verdade usar o `org-mode` era bem mais fácil do que
parecia.
Escrevi algumas funções de `ELISP` para facilitar no processo de exportação e
afins, e você pode dar uma olhada na feiura que ficou [aqui](https://github.com/rranelli/emacs-dotfiles/blob/master/lisp/init-writing.el).

As funções que eu escrevi fazem as seguintes coisas:

-   Cria um novo `draft` para um post
-   Insere a data atual no nome do arquivo, formatada do jeito que o `Jekyll` quer. (coisa chata)
-   Promove um `draft` para um post
-   Exporta o `.org` para `.md` usando o [org-md-export-to-markdown](http://orgmode.org/manual/Markdown-export.html)

Com isso, dá pra escrever em `org-mode` e praticamente que existe um markdown =).

Os nomes ficaram bem bagunçados no código, além de ter um bom tanto de
duplicação. Tentei refatorar e adivinhem: sem teste automatizado ficou um saco,
e acabei não fazendo (quem nunca?).
