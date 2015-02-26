---
language: brasileiro
layout: post
title: 'Como eu escrevi meu primeiro minor-mode para o Emacs'
---

# <p hidden>Como eu escrevi meu primeiro minor-mode para o Emacs<p hidden>

**TL;DR**: Em algumas horas eu escrevi o `maven-test-mode` fazendo uso do já
extremamente bizurado `compilation-mode`. Este post descreve o histórico que
me fez decidir escrever o `maven-test-mode` e algumas coisas interessantes que
eu aprendi no caminho. O `minor-mode` está disponível no [Github](https://github.com/rranelli/rranelli.github.io) e é
distribuído no [Melpa](http://melpa.org/#/maven-test-mode).

<span class="underline"><p hidden>excerpt-separator<p hidden></span>

Apesar do que muita gente imagina, customizar o Emacs não é tão complicado. A
maior dificuldade na verdade é encontrar qual a *feature* já implementada que
você quer estender. No caso deste post, vamos estender a funcionalidade do
`compilation-mode` ^(2) , um `minor-mode` que provê varias funcionalidades
para compilar código fonte, pular para os erros de compilação, etc.

> Emacs is the editable editor.
>
> <div align="right"><i>
>
> Não-lembro-quem.
>
> </i></div>

### Rspec-mode e compilation awesomeness

Quando comecei a trabalhar com Emacs pra valer (ou seja, quando entrei para
a Locaweb, uns 5 meses atrás) um dos pacotes que me chamou muita atenção foi
o [rspec-mode](https://github.com/pezra/rspec-mode) que facilita brutalmente o trabalho com o `rspec`. Basicamente,
é possível:

-   Rodar todos os testes do projeto.
-   Rodar apenas os testes do arquivo em foco.
-   Rodar apenas o teste mais próximo do seu cursor.
-   Navegar entre o arquivo de teste e implementação.
-   Navegar entre o método e o teste para o método. (essa feature fui [eu que fiz!](https://github.com/pezra/rspec-mode/pull/91))
-   No buffer que mostra os resultados dos testes (que é um buffer de
    compilação) é possível (clicar|apertar enter) em um erro na stack trace e
    pular para o código fonte. (!)

A ultima `feature` da lista anterior para mim foi a mais fantástica, pois
era uma das vantagens que eu ainda via no visual studio quando comparava com
o Emacs. Acabei percebendo que a abordagem *text-only* do Emacs é
extremamente superior: *Keyboard all the way down*, nada de ficar clicando
em um erro uma caixinha *output* espremida.

### Can't run away from Java. For now.

Nos últimos tempos na pós graduação venho cursando uma disciplina de projeto
orientado a objetos. Nessa disciplina tem um tanto de implementação em Java
que eu não consegui escapar. Até cogitei a possibilidade de usar o Eclipse
para a disciplina, mas desisti quando vi a interface para trocar os atalhos
de teclado (O terror!).

Acabei usando o `maven` para compilação e testes direto no terminal. No
começo era bem desengonçado pular para um erro de compilação no código
fonte. Anos luz do conforto fornecido pelo `rspec-mode`.

Como o buffer de resultado de testes do `rspec-mode` chamava-se
"\\\*rspec-compilation\\\*", imaginei que toda aquela interface bacana não devia
ser implementação pura do `rspec-mode` (que alias, não tem mais de 600
linhas de código). Acabei descobrindo o comando `compile` que recebe qual o
*shell command* que executa a compilação. Bastara então fornecer ao compile
o comando que eu usava no terminal. Para o meu espanto, a habilidade de
pular para o erro de compilação já vem de fábrica.

Apesar de tudo estar mais simples, havia um incomodo: No comando de
compilação eu sempre precisava dar um `cd` para o diretório raiz que contém
o `pom.xml`. Foi ai que eu pensei: Dado que o `rspec-mode` faz um [piggy-back](http://en.wikipedia.org/wiki/Piggyback_%2528transportation%2529)
no `compilation-mode` ^(2) o que me impede de escrever um modo análogo para
o `maven`? Busquei pela internet e não encontrei nada que oferecesse
funcionalidade parecida ao `rspec-mode`, principalmente no quesito de
navegação, para Java. Ai eu decidi encarar o desafio de escrever meu próprio
modo.

### Escrevendo o minor-mode

##### Encontrando a raiz do diretório.

O primeiro passo seria encontrar a raiz do projeto programaticamente para
rodar o comando de compilação. Isso é extremamente fácil:

```lisp
(defun maven-test-root-dir ()
  "Locates maven root directory."
  (locate-dominating-file (buffer-file-name) "pom.xml"))

(defun maven-test-test ()
  "Runs maven tests"
  (interactive)
  (format "cd %s; mvn test" (maven-test-root-dir)))
```

`locate-dominating-file` busca pelo arquivo `pom.xml` a partir do
diretório que contém o arquivo sendo editado. Se o `pom.xml` não for
encontrado, a busca é feita no diretório pai, e assim sucessivamente.
(créditos para o mago [Nic Ferrier](https://github.com/nicferrier/emacs-mvn/blob/master/mvn-help.el))

Com isso, a implementação da função que executa os testes é trivial: basta
substituir o resultado de `(maven-test-root-dir)` como argumento do `cd`
que antes era feito manualmente e voilá.

As outras opções para rodar testes descritas na lista acima seguem a mesma
filosofia, e eu vou omitir elas por brevidade. Se interessar, veja no
[Github](https://github.com/rranelli/rranelli.github.io).

##### Encontrando a classe e o teste associado

Para realizar a navegação entre classe java e teste, tomei nota de que a
localização destes arquivos difere das seguintes formas:

-   Os arquivos das classes Java ficam abaixo do diretório `src/main/java/`, enquanto que os testes ficam abaixo de `src/test/java/`
-   Os arquivos de teste são nomeados conforme o padrão `<class>Test.java`.

Com isso, bastam 23 linhas e 960 caracteres:

```lisp
(defcustom maven-test-class-to-test-subs
  '(("/src/main/" . "/src/test/")
    (".java" . "Test.java"))
  "Patterns to substitute into class' filename to jump to the associated test."
  :group 'maven-test)

(defun maven-test-test-to-class-subs ()
  "Reverts maven-test-class-to-test-subs."
  (mapcar
   #'(lambda (e) `(,(cdr e) . ,(car e)))
   maven-test-class-to-test-subs))

(defun maven-test-toggle-get-target-filename ()
"If visiting a Java class file, returns it's associated test filename. If visiting a test file, returns it's associated Java class filename"
  (let* ((subs (if (maven-test-is-test-file-p)
		   (maven-test-test-to-class-subs)
		 maven-test-class-to-test-subs)))
    (s-replace-all subs (buffer-file-name))))

(defun maven-test-is-test-file-p ()
"Return non-nil if visited file is a test file."
  (string-match "/src/test/" (buffer-file-name)))

(defun maven-test-toggle-between-test-and-class ()
"Toggle between Java class and associated test."
  (interactive)
  (find-file (maven-test-toggle-get-target-filename))
```

A variável `maven-test-class-to-test-subs` especifica quais
substituições precisam ser feitas no `path` do arquivo de uma classe
Java para obter o `path` do teste associado. A função
`maven-test-test-to-class-subs` basicamente inverte o padrão, retornado
as substituições que precisam ser feitas no `path` do arquivo de testes
para obter o `path` do arquivo da classe Java associada.

A função `maven-test-is-test-file-p` retorna `t` se o arquivo visitado
^(1) corresponde a um arquivo de teste. A função faz isso verificando se
"/src/test" existe no `path` do arquivo.

Finalmente, a função `maven-test-toggle-get-target-filename` faz o
'jump' do teste para a classe: Se o arquivo visitado for um teste, abre
a classe e vice versa.

1.  Jumping to stack-traces

    Para completar o conjunto de features que para mim são fundamentais no
    `rspec-mode` faltava apenas implementar o 'jump' de um erro de execução
    no `compilation buffer` para o código.

    Para essa funcionalidade, é preciso informar ao `compilation-mode` uma
    expressão regular que lê uma linha da `stack-trace` e retorna um
    `locale`, ou seja, qual a linha de qual arquivo gerou o erro no
    `stack-trace`. Essa configuração é feita colocando uma nova entrada na
    lista `compilation-error-regexp-alist-alist`.

    Porém, o manual do Emacs alerta que é necessário ter cuidado para
    modificar esta variável. Para evitar problemas, resolvi criar uma copia
    local da variável que é confinada apenas ao **meu** buffer de compilação.
    Isso isola o resto do mundo da minha incompetência, o que é excelente.
    Esse isolamento é atingido da seguinte forma:

    ```lisp
    (defvar maven-test-java-src-dir "src/main/java/")
    (defvar maven-test-java-tst-dir "src/test/java/")

    (define-derived-mode maven-compilation-mode compilation-mode "Maven Test Compilation"
      "Compilation mode for Maven output."
      (set (make-local-variable 'compilation-error-regexp-alist)
           (append '(java-tst-stack-trace java-src-stack-trace)
    	       compilation-error-regexp-alist))

      (set (make-local-variable 'compilation-error-regexp-alist-alist)
           (append '((java-tst-stack-trace
    		  "<regexp muito louca que fornece o file-name no match 3>"
    		  maven-test-java-tst-stack-trace-regexp-to-filename 3)
    		 (java-src-stack-trace
    		  "<regexp muito louca que fornece o file-name no match 3>"
    		  maven-test-java-src-stack-trace-regexp-to-filename 3))
    	       compilation-error-regexp-alist-alist)))
    ```

    `make-local-variable` cria um escopo dinâmico e isola o resto do mundo
    de qualquer alteração que eu faça na variável argumento. Com isso, se eu
    quebrar alguma coisa, quebro apenas no meu modo derivado e não nos
    outros buffers de compilação.

2.  Distribuindo pelo Melpa

    Depois de escrever e testar, adicionei o `maven-test-mode` no Melpa.
    Basicamente, é necessário adicionar ao projeto um [Makefile](https://github.com/rranelli/maven-test-mode/blob/master/Makefile) que define
    como 'empacotar' o projeto em um formato que o Melpa entenda.
    Basicamente, é necessário definir versão, listar os arquivos integrantes
    do pacote e compactar em um `tar.gz`.

    Depois de pronto o projeto, falta adicionar a *recipe* no próprio
    repositório do Melpa. A *recipe* não passa de um arquivo com uma única
    linha:

    ```lisp
    (maven-test-mode :fetcher github :repo "rranelli/maven-test-mode")
    ```

    Você pode ver a interação para isso nesse [PR](https://github.com/milkypostman/melpa/pull/2122).

    O código total do `maven-test-mode` tem outras firulinhas e tem no
    momento 204 linhas, e contempla todas as features fundamentais do
    `rspec-mode` que eu listei acima.

    O `rspec-mode` ainda define outras coisas secundárias como formatação,
    *font-locking* e outras questões estéticas que eu não julgo necessárias
    no momento.

    Era isso. flw vlw.

##### Footnotes:

(1) : Na terminologia do Emacs, o 'arquivo visitado' é o arquivo que você
tem 'aberto' no `buffer` em foco. Na verdade você não manipula arquivos no
Emacs ou qualquer outro editor, você manipula buffers. Quando você "salva"
o arquivo, na realidade você está escrevendo o conteúdo do buffer em
disco. Pura firulice sintática.

(2) : Basicamente muitos modos que precisam "(clicar|apertar enter) em uma
ocorrência e pular para o arquivo fonte" fazem uso do `compilation-mode`.
Essa é uma das belezas de escrever software generalista: As pessoas vão
usar o seu software pra fazer coisas que você não pode nem imaginar. O
`compilation-mode` foi escrito para você compilar coisas, mas a galera dos
programas para buscar texto em arquivo (Ack, grep, Ag, Pt) usam o
`compilation-mode` para pular da saída no console para o código fonte.
Para o [Platinum Searcher (Pt)](https://github.com/bling/pt.el/blob/master/pt.el) o código que faz isso tudo não tem nem 100
linhas, pois faz um *piggy-back* feroz no `compilation-mode`.
