---
language: brasileiro
layout: post
comments: true
title: SICP em Clojure
---

# <p hidden>SICP em Clojure<p hidden>

**TL;DR**: Vou encarar o desafio de resolver **todos** os exercícios do [SICP](https://mitpress.mit.edu/sicp/full-text/book/book.html) em
Clojure e postar o progresso por aqui. Se você se interessar por que, continue
lendo.

<span class="underline"><p hidden>excerpt-separator<p hidden></span>

Neste post eu vou explicar como algumas threads de estudo culminaram na minha
decisão de encarar a jornada do [SICP](https://mitpress.mit.edu/sicp/full-text/book/book.html) em Clojure. Vou tentar passar a
cronologia das coisas e acabar falando um pouco sobre como estudar coisas
'nada a ver' podem trazer surpresas bem interessantes.

##### Primórdios.

Durante a minha graduação em Engenharia Química^1 eu trabalhei com
[controle de processos](http://en.wikipedia.org/wiki/Process_control) no [LCAP](http://lcapsite.blogspot.com.br/p/equipe-iniciacao-cientifica.html) (de 2009 ao final de 2012). Meu primeiro
trabalho foi aplicando "inteligência artificial" ^2 para fins que eu não
vou explicar por que não deve interessar ninguém. E quando se procura por
inteligência artificial, é inevitável trombar com "Lisp". Até tentei na
época entender o que era esse tal de "Lisp", mas minha imaturidade não
colaborou e acabou virando uma sigla sem significado na minha memória. No
primeiro momento, pegar um livro que ninguém pega desde 2006 na biblioteca
do [IMECC](http://www.ime.unicamp.br/) não parece que vai ser útil pra alguma coisa.

##### MOOCs to the rescue.

Em janeiro de 2013, eu comecei no Coursera o curso [Programming Languages](https://www.coursera.org/course/proglang).
Se você já conversou comigo sobre computação, eu provavelmente te falei o
quão fantástico esse curso é. Nesse curso são utilizadas 3 linguagens:
[SML](http://www.smlnj.org/), [Racket](http://racket-lang.org/) e [Ruby](https://www.ruby-lang.org/en/). Racket é uma modificação de outro dialeto Lisp,
[Scheme](http://en.wikipedia.org/wiki/Scheme_%2528programming_language%2529).

Essa tal sigla de 'Lisp' me lembrou daquele livro obscuro e ininteligível
que eu peguei na época da iniciação científica. Isso aguçou a minha
curiosidade sobre o curso, e me ajudou a decidir começá-lo.

Quando fiz o curso deu pra entender 'mais ou menos' por que Lisp é tão bom
pra inteligência artificial: Código e dados são intercambíveis. Macros
permitem que você manipule a estrutura da linguagem da forma que quiser.

Mais que isso. No final do curso eu aprendi umas coisas 'nada-a-ver' tipo
pattern-matching, uniões tagueadas (algebraic datatypes do Haskell),
subtipos, covariância & contra-variância, etc. Na época eu ainda não
trabalhava com computação, então não tinha muito filtro sobre o que a
galera da área sabia. (Eu devo ser um dos únicos sujeitos dessa geração
que aprendeu programação funcional <span class="underline">antes</span> de orientação a objeto.)

##### Seven Languages in 11 weeks (sic).

Em outra thread de estudo, eu li o fantástico livro [Seven Languages in
Seven Weeks](https://pragprog.com/book/btlang/seven-languages-in-seven-weeks) do Bruce Tate. O livro fala bastante de programação funcional.
Graças ao Programming Languages, a leitura foi fluída e o conteúdo de
certa forma simples.

No capítulo 7, o livro apresenta Clojure como um 'renascimento' de Lisp,
baseado na JVM, especialmente interessante para o mundo moderno da
concorrência.

> Clojure and Java desperately need each other. Lisp needs the market place that
> the Java virtual machine can offer, and the Java community needs a serious
> update and an injection of fun.
>
> <div align="right"><i>
>
> Bruce A. Tate
>
> </i></div>

Depois de ler o livro até que fiquei interessado, mas acabei não fazendo
nada a respeito. Apesar de ter achado o livro simples por culpa do
Programming Languages, já ouvi de mais de uma pessoa que começou a ler o
livro sem experiência em FP que o livro era "pesado". Até escutei de
alguns: "Mas pra que você vai ler sobre SETE linguagens se você só
trabalha com uma?"

##### Escrevendo Elisp.

Depois de ter tido uma certa exposição a 2 dialetos de Lisp, e já um pouco
mais maduro no funcionamento do Emacs, resolvi escrever um pouco de Elisp
e customizar alguns aspectos do editor. Acabei contribuindo com o
[rspec-mode](https://github.com/pezra/rspec-mode) e o [neo-tree](https://github.com/jaypei/emacs-neotree), e já nesse momento sentia falta das coisas
'nada-a-ver' do Programming Languages: pattern-matching, escopo léxico,
namespaces, etc.^3

##### An then comes the rain.

Não sei exatamente em que momento eu descobri o SICP. A poucas semanas eu
comecei a ler o livro, li o primeiro capítulo e o foreword e fiquei
[perplecto](https://www.youtube.com/watch?v%3De0yPV-pqmbU) (sic). E na mesma semana encontrei no blog do Bozhidar Batsov
este post que falava deste [projeto](https://www.kickstarter.com/projects/1751759988/sicp-distilled) no Kickstarter. Depois de ler o projeto
e este outro [post](http://thecleancoder.blogspot.com.br/2010/08/why-clojure.html) do CleanCoder, eu decidi que iria encarar o SICP em
Clojure.

Pra que você tenha uma idéia do nível da conversa no SICP, segue um teaser
do primeiro capítulo:

> (&#x2026;) Computational processes are abstract beings that inhabit computers. As
> they evolve, processes manipulate other abstract things called data. The
> evolution of a process is directed by a pattern of rules called a program.
> People create programs to direct processes. In effect, we conjure the spirits of
> the computer with our spells.
>
> A computational process is indeed much like a sorcerer's idea of a spirit. It
> cannot be seen or touched. It is not composed of matter at all. However, it is
> very real. It can perform intellectual work. It can answer questions. It can
> affect the world by disbursing money at a bank or by controlling a robot arm in
> a factory. The programs we use to conjure processes are like a sorcerer's
> spells. They are carefully composed from symbolic expressions in arcane and
> esoteric programming languages that prescribe the tasks we want our processes to
> perform.
>
> Fortunately, learning to program is considerably less dangerous than learning
> sorcery (&#x2026;)
>
> <div align="right"><i>
>
> Harold Abelson & Gerald Jay Sussman
>
> </i></div>

O SICP não é um livro sobre programação, mas sim um livro sobre
abstrações. É sem dúvida um texto que faz jus à 'ciência' em ciência da
computação. Desta forma, usar Clojure, Scheme ou Javascript provavelmente
não é tão relevante, desde que ofereçam as abstrações necessárias.

##### Comentários finais

Com isso, acabo juntando o útil ao agradável: Estudar um material clássico
de CS e aprender o Lisp da vez. Depois disso acho que vou estar pronto pra
estudar o [joy of clojure](http://joyofclojure.com/).

O que eu acho mais legal nessa história toda é que todas as coisas que me
trouxeram ao ponto de entender por que o SICP seria legal de estudar
aconteceram "por acaso".

Como já disse o Jobs:

> You can't connect the dots looking forward you can only connect them looking
> backwards. So you have to trust that the dots will somehow connect in your
> future. You have to trust in something: your gut, destiny, life, karma,
> whatever. Because believing that the dots will connect down the road will give
> you the confidence to follow your heart, even when it leads you off the well
> worn path.
>
> <div align="right"><i>
>
> Steve Jobs
>
> </i></div>

E também como já dizia um amigo gaúcho bem menos famoso:

> Você só sabe que você tem um problema quando você sabe que tem um problema. Se
> não tem problema, não tem problema.
>
> <div align="right"><i> Fabrizio Tissot </i></div>

Lisp não serviu pra nada na minha iniciação científica, pattern-matching
não me ajudou a sair do meu emprego em engenharia de projetos, e ler sobre
7 linguagens não me ensinou como escrever Rails. Porém, aqui estou eu
achando ultra-divertido ler um texto que compara computação a bruxaria, e
entendendo um pouco mais dos problemas que o desenvolvimento de software
enfrenta.

Nas próximas semanas vou atualizar o blog com posts relatando a
experiência. As soluções dos exercícios e comentários vão ser
disponibilizados em algum github da vida.

Ps: Pra você que acha que eu sou louco: Não vou ser o primeiro a encarar a
jornada em Clojure: Já achei [este](https://github.com/deobald/sicp-clojure) e [mais este](https://github.com/stuartellis/sicp-clojure) repositório no github com
soluções.

Ps²: Agradeço ao brother Narciso por emprestar o SICP fisico ;). Valeu
mano.

&#x2014;

(1) É, apesar de a um bom tempo não estudar outra coisa, eu não sou um
Computeiro. Tenho planos de um dia escrever um post explicando por que
eu sai da EQ e resolvi trabalhar com Software.

(2) As aspas significam que hoje eu não acredito mais que aquilo era
inteligência artificial. Mais explicações em algum post futuro.

(3) Tem uma [thread](https://lists.gnu.org/archive/html/emacs-devel/2014-09/msg00339.htmll) **gigantesca** na lista [emacs-devel](https://lists.gnu.org/mailman/listinfo/emacs-devel) falando sobre a
possibilidade de utilizar o [Guile](http://www.gnu.org/software/guile/) como plataforma para o Emacs. Se
vingar, será possível estender o Emacs com qualquer linguagem disponível
no Guile, que já tem Scheme e Common Lisp.
