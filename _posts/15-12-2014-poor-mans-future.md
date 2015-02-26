---
language: brasileiro
layout: post
comments: true
title: "Poor man's Future in Ruby"
---

# <p hidden>Poor man's Future in Ruby<p hidden>

**TL;DR**: Futures são da hora.

<span class="underline"><p hidden>excerpt-separator<p hidden></span>

Hoje tivemos uma sessão de
coding-dojo/live-coding/um-cara-codando-e-outros-reclamando no trabalho e nos
deparamos com o problema de executar uma coleção de tarefas de forma
concorrente. Enquanto a galera começou a pirar em `actors`, `fibers`,
`celluloid` e afins, lembrei que já tinha feito um código muito parecido, e
resolvi compartilhar por aqui (just cause I can).

Esse código faz parte de uma [gem](http://github.com/rranelli/git_multicast) que eu comecei a fazer para descobrir como se
faz uma `gem` em Ruby.

```ruby
module GitMulticast
  class Task
    class Runner
      def initialize(tasks)
	@tasks = tasks
      end

      def run!
	tasks
	  .map(&method(:future))
	  .map(&:get)
      end

      protected

      attr_reader :tasks

      def future(task)
	PoorMansFuture.new { task.call }
      end

      class PoorMansFuture
	def initialize
	  @thread = Thread.new do
	    Thread.current[:output] = yield
	  end
	end

	def get
	  thread.join
	  thread[:output]
	end

	attr_reader :thread
      end
    end
  end
end
```

A ideia principal é a seguinte. `Task::Runner` recebe uma lista de tarefas
para executar. As tarefas não se importam sobre o contexto que serão
executadas e, obviamente, devem ser *thread-safe*. A classe `PoorMansFuture`
cuida de disparar a computação de um bloco em um novo *thread*, e de fornecer
uma interface para recuperar o resultado da computação deste bloco quando esta
terminar.

A marotagem para recuperar o retorno do bloco que executa em um novo thread
fica aqui:

```ruby
Thread.current[:output] = yield
```

O esquema é guardar o resultado da execução do bloco no `Thread.current` para
poder recuperar depois.

O ato de 'executar tudo ao mesmo tempo' e 'esperar tudo terminar' fica nesse
trecho:

```ruby
tasks
  .map(&method(:future))
  .map(&:get)
```

Fica claro um exemplo da extrema expressividade de Ruby e da *api* de
coleções. Um mapa transforma a coleção de tarefas em uma coleção de
[CompletableFutures-ish](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/CompletableFuture.html), e o segundo recupera os retornos dessas Futures. Sem
locks, sem mutexes, e quase sem parecer que a concorrência é importante.

Era isso.
