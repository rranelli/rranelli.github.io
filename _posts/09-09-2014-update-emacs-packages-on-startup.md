---
language: brasileiro
layout: post
title: Atualizando os pacotes do Emacs
---

Se você usa o [Melpa](http://melpa.milkbox.net/), provavelmente já se deparou com a situação em que percebeu
os seus pacotes bem desatualizados. Isso acontece por que para atualizar os
pacotes você precisa fazer:

```
M-x list-packages RET U x y
```

`list-packages` vai listar todos os pacotes dos seus sources, `U` marca todos os
seus pacotes instalados para atualização e `x` de fato atualiza os pacotes.
E para listar os pacotes ainda leva alguns segundos, e para atualizar mais uns
bons segundos (as vezes minutos se você usa o [yasnippet](https://github.com/capitaomorte/yasnippet).). É por conta desse
tipo de coisa que a galera do `vim` sacaneia o Emacs.

Sem dúvida, esse processo é "nada a ver", e não é nem um pouco amigável pro
iniciante.

Mas nenhum problema é insolúvel pro editor editável: e nesse caso é bem simples
com um pouco de Elisp:

```lisp
(defun rr-update-packages ()
  "Update installed Emacs packages."
  (interactive)
  (package-list-packages)
  (package-menu-mark-upgrades)
  (package-menu-execute t)
  (kill-buffer))
```

E se você quiser atualizar tudo toda vez que iniciar o Emacs, basta colocar a
linha abaixo em algum lugar no seu \`load-path\`:

```lisp
(rr-update-packages)
```

Easy-peezy.
