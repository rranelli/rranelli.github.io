---
language: brasileiro
layout: default
title: Monkey patch de briqueixon with me.
---

Quem trabalha com linguagens dinâmicas sabe dos perigos do [monkey patch](http://en.wikipedia.org/wiki/Monkey_patch). Apesar
de restringir esse tipo de recurso apenas aos casos em que há um ganho
substancial, as vezes o patch acontece sem querer . Esse é um dos argumentos de
quem não é tão fã de `ruby` por ser uma linguagem "aberta demais" (em `ruby` nem
constante é constante).

Hoje eu sofri um "monkey-patch" acidental. Estava codando uma gem ([git\_multicast](http://github.com/rranelli/git_multicast)) para
acessar a API do [Bitbucket](http://bitbucket.org) e clonar todos os meus repositórios públicos. Já
tinha feito a mesma coisa com a API do Github, e foi bem fácil. Para não
trabalhar com o resultado Json puro da API, estou usando a gem
[RecursiveOpenStruct](https://rubygems.org/gems/recursive-open-struct) que pega uma `hash` e gera um [OpenStruct](http://ruby-doc.org/stdlib-1.9.3/libdoc/ostruct/rdoc/OpenStruct.html) de forma recursiva:
se a sua `hash` contém referência para outra `hash`, ele converte essa `hash` também.

A resposta para a chamada que traz os repositórios públicos do usuário `:owner` tem essa cara:

```js
// GET https://bitbucket.org/api/2.0/repositories/:owner
{
  "pagelen": 10,
  "values": [
    {
      "scm": "git",
      "links": {
	"self": {
	  "href": "https://api.bitbucket.org/2.0/repositories/evzijst/atlassian-connect-fork"
	},
	"html": {
	  "href": "https://bitbucket.org/evzijst/atlassian-connect-fork"
	},
	"clone": [
	  {
	    "href": "https://bitbucket.org/evzijst/atlassian-connect-fork.git",
	    "name": "https"
	  },
	  {
	    "href": "ssh://git@bitbucket.org/evzijst/atlassian-connect-fork.git",
	    "name": "ssh"
	  }
	],
	"pullrequests": {
	  "href": "https://api.bitbucket.org/2.0/repositories/evzijst/atlassian-connect-fork/pullrequests"
	}
      },
      "language": "",
      "parent": {
	"links": {
	  "self": {
	    "href": "https://api.bitbucket.org/2.0/repositories/evzijst/atlassian-connect"
	  },
	},
	"full_name": "evzijst/atlassian-connect",
	"name": "atlassian-connect"
      },
      "full_name": "evzijst/atlassian-connect-fork",
      "has_issues": false,
      "is_private": false,
      "name": "atlassian-connect-fork"
    }
  ],
  "page": 1,
  "next": "https://api.bitbucket.org/2.0/repositories?pagelen=1&after=2013-09-26T23%3A01%3A01.638828%2B00%3A00&page=2"
}
```

Supondo que `repo` é um repositório convertido para OpenStruct, para buscar a
`url` para clonar o repositório via ssh eu (ingenuamente) escrevia:

```ruby
repo.links.clone.last.href
```

E ai vinha a exceção:

```
NoMethodError: undefined method `href' for nil:NilClass
```

Estranho, pois fica parecendo que o RecursiveOpenStruct não converteu a `hash`
corretamenta, ou que a chamada para a API estava quebrada.

Depois de muito tentar, entrei no irb e fiz:

```ruby
repo.links.clone.last #=> nil
```

Estranho, por que um Array deveria responder a chamada para `:last`
Será que era mesmo um array?

```ruby
repo.links.clone.class #=> RecursiveOpenStruct
```

E ai veio a bizarrice:

```ruby
repo.links.clone.clone.class #=> RecursiveOpenStruct
```

Será que RecursiveOpenStruct estava convertendo errado ?? Seria um bug na gem??
Investigando um pouco mais:

```ruby
repo.links.clone.object_id #=> 459863456
repo.links.clone.clone.object_id #=> 58565758

repo.links.clone == repo.links.clone.clone #=> true
```

(Uma forma muito mais fácil de resolver essa questão é perguntar diretamente
quem implementa o método usando [`method`](http://www.ruby-doc.org/core-2.1.2/Method.html))

Ai, para minha surpresa, existe um método `clone` em `ruby`, [que é quase igual
ao dup](http://stackoverflow.com/questions/10183370/whats-the-difference-between-rubys-dup-and-clone-methods). Moral da história: O método `clone` da biblioteca padrão é que estava
respondendo à mensagem `:clone`, e não o método definido pelo
RecursiveOpenStruct.

Para matar a dúvida, olhando na [implementação](https://github.com/ruby/ruby/blob/eeb05e8c119f8cab6434d90f21551b6bb2954778/lib/ostruct.rb) do próprio OpenStruct,
verifica-se que ele <span class="underline">não sobreescreve métodos que já existem</span>, o que certamente
é uma decisão sabia.

```ruby
def new_ostruct_member(name)
  name = name.to_sym
  unless respond_to?(name)
    define_singleton_method(name) { @table[name] }
    define_singleton_method("#{name}=") { |x| modifiable[name] = x }
  end
  name
end
```
