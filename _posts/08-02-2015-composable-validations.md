---
language: english
layout: post
comments: true
title: 'Composable Validations'
---

# <p hidden>Composable Validations<p hidden>

**TL;DR**: We keep devising smart solutions to all sorts of problems. If we talk
the language of Monads & company, many of those 'smart solutions' just get
trivial.

&#x2014;

### Chained validations

Yesterday I was watching the episode #279 of [Avdi Grimm's](http://about.avdi.org/) [Ruby-tapas](http://www.rubytapas.com/) ^1. The
episode consisted in the refactoring of the following method to allow the
reporting of **all** validation errors, and not only the first one.

(Disclaimer: I won't show the whole thing here because the content of
episode #279 is for subscribers only.)

```ruby
def alert_due?
  return false if     completed?
  return false unless current_time_is_past_due_time?
  return false if     sent_yesterday?
  return false unless hour_is_past?
  return false unless minute_is_past?
  true
end
```

The main idea was to introduce some sort of `auditor` object to kind of
*remember* the checks and their reasons. This `memory` is implemented with the
`auditor` object being decorated with information about the checks it
audits.

The API of the auditor would be something like this:

```ruby
class Auditor
  def initialize
    @checks = {}
  end

  def audit(description)
    @checks[description] = yield
  end

  def results
    @checks
  end
end
```

That enables us to pass each validation as a `block` with a description in
the following manner:

```ruby
def alert_due?(auditor)
  auditor.audit("stuff completed") { completed? }
  auditor.audit("sent yesterday") { sent_yesterday? }
# ... and so on
end

# then in the caller you can...
my_auditor = Auditor.new
due = alert_due?(my_auditor)

puts my_auditor.results if due
```

##### Why does this matter?

This will help one to debug the reason why something went wrong in the big
"chain" of validation calls.

This solves exactly the problem we face when we have to fill those
purchase forms a thousand times. Each time it's validation fails only the
**first** error is reported.

When I was watching the video a thing struck my mind: What is actually
tried to achieve is the ability to pass-on some *accumulated state*
between the different validation calls. Also, you don't want to return
from the method without checking all validations that are wrong. Well,
state accumulation is precisely what the [State Monad](https://wiki.haskell.org/State_Monad) gives you!

##### Some extra considerations

Although the proposed `auditor` works well, it's a little odd for my
taste. First, you need to pass it as an argument to some method and then
inspect it for changes. In fact, the `alert_due` method has two return
values: the mutated state of the auditor object and it's regular boolean
return.

what if some sloppy programmer used the same auditor for two validations
that actually shouldn't share the same context? What if someone uses the
state of the auditor to decide what to do inside of the validator method?
I actually don't care all that much about these risks, but they make me
uneasy nonetheless.

### Functional solution

If you're not familiar with Monads, don't despair. Read on and this will be
an example on why it is actually kind of cool to understand this whole
Monad/Monoid/Applicative Endo-Functors nonsense.

After I watched the video I hacked up a Haskell script defining the
necessary stuff to solve the same problem.

I didn't use the State Monad because I wanted to exercise the main point of
the problem. Many of the solutions to problems in Haskell show the final
product and not the path the author took to solve the problem ([write
yourself a scheme in 48 hours ](http://en.wikibooks.org/wiki/Write_Yourself_a_Scheme_in_48_Hours), I'm looking at you!) ^2.

My whole script fits under 50 lines:

```haskell
module Main where

import Control.Monad

type ValidationError = [String]
data Validated a = Errors (ValidationError, a)
		 | Valid a
		 deriving Show

instance Monad Validated where
  return a = Valid a
  a >>= f = case a of
	     Errors (vrs, val) ->
	       case f val of
		 Errors (vrs', val') -> Errors (vrs ++ vrs', val')
		 Valid val' -> Valid val'
	     Valid val ->
	       case f val of
		 Errors (vrs', val') -> Errors (vrs', val')
		 Valid val' -> Valid val'

predicateToValidator :: (a -> Bool) -> ValidationError -> (a -> Validated a)
predicateToValidator f verr = \x -> if f x then
				      Valid x
				    else
				      Errors (verr, x)

biggerValidator :: (Ord a, Show a) => a -> a -> Validated a
biggerValidator limit value = if value < limit then
				 Errors ([(show value) ++ " is not bigger than " ++ (show limit)], value)
			      else
				 Valid value

biggerThan42 :: Int -> Validated Int
biggerThan42 = biggerValidator 42

smallerThan84 :: Int -> Validated Int
smallerThan84 = \x -> biggerValidator x 84

biggerThan84 :: Int -> Validated Int
biggerThan84 = biggerValidator 84

isValid :: Validated a -> Bool
isValid = \v -> case v of
		 Valid _ -> True
		 Errors _ -> False

shouldBeTrue = isValid $ (return 41) >>= smallerThan84
-- #=> true

shouldBeFalse = isValid $ (return 41) >>= biggerThan42
-- #=> false

errors = (return 41) >>= biggerThan42 >>= biggerThan84
-- #=> Errors (["41 is not bigger than 42","41 is not bigger than 84"],41)
```

Actually, everything after line 20 is superfluous and only serves the
purpose of demonstration.

Pretty straightforward right? The whole idea of *chaining* the validators is
encapsulated in the <code>>>=</code>(called *bind* actually) function. Also,
if you want to validate using a simple predicate function, you can convert
it to something bind accepts with the function `predicateToValidator`.

Here, I have expressed Validation as a Monad. I can do this because even
errors chain forward a &#x2013; possibly different &#x2013; validation value. [Scalaz](http://stackoverflow.com/questions/12211776/why-isnt-validation-a-monad-scalaz7) and
the [Haskell standard library](https://hackage.haskell.org/package/Validation-0.2.0/docs/Data-Validation.html) both consider validations as [Applicative
Functors](https://wiki.haskell.org/Applicative_functor) which are more general (i.e. put on less restrictions) than Monads.
In short, their approach is that when combining a failure with a success,
you get a failure, without carrying onward the validated value.

I recognize that my approach is less elegant when considering types:
`Validated` values with `Errors` and `Valid` ones are not actually that
different. And you can always recover *some* value from them.

What I ended up with is almost exactly what the State Monad already offers,
but with more restrictions on how the "state" gets combined with the return
value of the functions fed to <code>>>=</code>.

### OO version of the same thing

How would this solution manifest itself in a Object Oriented language like
ruby? Is it possible to avoid the mutable auditor?

Turns out it is, and the solution is actually highly parallel to the Haskell
one:

```ruby
class Validation
  def initialize(value, errors = [])
    @value = value
    @errors = errors
  end

  attr_reader :value, :errors

  def with(validator)
    (new_value, validation_errors) = validator.validate(value)
    accumulated_errors = errors + Array(validation_errors)

    return Valid.new(new_value) if accumulated_errors.empty?
    Error.new(new_value, accumulated_errors)
  end

  class Valid < Validation
    def valid?
      true
    end
  end

  class Error < Validation
    def valid?
      false
    end
  end
end

class BiggerThan42
  def self.validate(value)
    if value < 42
      [value, ["#{value} is not bigger than 42"]]
    else
      value
    end
  end
end

class BiggerThan84
  def self.validate(value)
    if value < 84
      [value, ["#{value} is not bigger than 84"]]
    else
      value
    end
  end
end
```

And the `RSpec` tests:

```ruby
require 'rspec'
require_relative 'validator'

RSpec.describe Validation do
  subject(:validation) { described_class.new(value) }

  let(:value) { 43 }

  describe '#with' do
    subject(:with) { validation.with(validator) }

    let(:validator) { BiggerThan42 }

    it { is_expected.to be_a(Validation::Valid) }
    it { is_expected.to be_valid }

    context 'when the value is not valid' do
      let(:value) { 41 }

      it { is_expected.to be_a(Validation::Error) }
      it { is_expected.not_to be_valid }
      it { expect(with.errors.count).to eq(1) }

      context 'when chaining validations' do
	subject(:chained_with) { with.with(validator) }

	let(:validator) { BiggerThan84 }

	it { is_expected.to be_a(Validation::Error) }
	it { is_expected.not_to be_valid }

	it 'accumulates all errors' do
	  expect(chained_with.errors.count).to eq(2)
	end
      end

      context 'using Array#reduce' do
	let(:validators) { [BiggerThan84, BiggerThan42] }

	subject(:reduced) { validators.reduce(validation, &:with) }

	it { is_expected.to be_a(Validation::Error) }
	it { is_expected.not_to be_valid }

	it 'accumulates all errors' do
	  expect(reduced.errors.count).to eq(2)
	end
      end
    end
  end
end
```

You can rename `with` to <code>>>=</code> and see that both Haskell and Ruby
solutions are pretty close. Just by looking the ruby code you absolutely no
clue that we are talking the language of Monads there.

This ruby code is an example of how FP concepts are actually pervasive in
the computing world, and we use them all the time without even knowing.
Think about the cases where you used design patterns without actually
knowing them.

### In the real world

In one of the applications I am currently working in we were faced with the
problem of chaining multiple validations. We thought about the problem of
keeping state and couldn't agree on what would be a good and simple
implementation approach. We ended up with something like the following:

```ruby
class RealWorldValidator
  include ::ErrorModule

  VALIDATORS = [
    Validators::Parenthood,
    Validators::Relationships,
    Validators::Actions
  ]

  def initialize(value)
    @value = value
  end

  def validate!
    VALIDATORS
      .map { |validator| validator.new(value) }
      .each(&:validate!)
  end
end
```

The problems with this is that we throw an exception on the first validation
failure. This hinders us on showing the most useful error message to our
consumers. We thought that accumulating the validation errors would be too
much work. Shame on us.

We could refactor `RealWorldValidator` as such:

```ruby
class RealWorldValidator
  include ::ErrorModule

  VALIDATORS = [
    Validators::Parenthood,
    Validators::Relationships,
    Validators::Actions
  ]

  def initialize(value)
    @value = value
  end

  delegate :errors, :valid?, to: :validation

  def validate!
    validation.tap do |validation|
      fail SomeError, validation.errors unless validation.valid?
    end
  end

  private

  def validation
    seed = Validation.new(value)
    VALIDATORS.reduce(seed, &:reduce)
  end
end
```

See ? We could attach all of the validation problems in the raised
exception's message. I find this beautiful, and it's not even away from
idiomatic ruby.

### Monoids and even more abstract nonsense

The main feature of the `ValidationError` type is that it can be appended
to. Our `Validated` Monad actually does not need to care about exactly **how**
the errors so far and the new errors must combine, as long that they do. Two
entities that abstract how two things get combined into one are Monoids and
Semigroups. I won't discuss them here because [others](http://blog.sigfpe.com/2009/01/haskell-monoids-and-their-uses.html) have [already](http://apfelmus.nfshost.com/articles/monoid-fingertree.html) already
explored their structure and usefulness way more eloquently than I can hope
to be.

We can also see our `Validated` Monad as an instance of the [Writer Monad](http://learnyouahaskell.com/for-a-few-monads-more).
The writer Monad allows one to "log" the result of operations.

As you can see, knowing these Algebras allows one to think in a higher level
of abstraction:

-   "Oh, I need to append intermediate values of a chained computation. I better use the Writer Monad"

-   "Oh yeah, some intermediate state has to be passed between these calls, better use the State Monad"

-   "These two values need to be combined into one. I don't need to be
    concerned on **how** they do it. Let me ask for a Monoid/Semigroup instead"

Also, remember how we used `Array#reduce` to apply the chain of validators
in our refactored `RealWorldValidator` ? There is also a typeclass for that:
[Data.Foldable](https://hackage.haskell.org/package/base-4.7.0.2/docs/Data-Foldable.html) in Haskell, with `Array#reduce` being equivalent to `foldl`.
Lists are instances of `Foldable` and hence we can use them, but we could
easily define our own `Foldable` for validation purposes.

While the solution offered by Avdi's video is a clever one, I think that
seasoned ^3 FP hackers wouldn't actually be that impressed with it, since it
falls so gracefully as a special case of well known patterns.

I hope this will encourage you to dive a little into the FP abstract
nonsense bandwagon. Although you don't see them as such, many of the things
we code are neatly expressed as Monads, Monoids and such. They aren't scary,
they just have ugly names and overly terse Wikipedia entries.

That's it.

&#x2014;

(1) If you're interested in Ruby you should definitely get [ruby-tapas](http://www.rubytapas.com/).
Seriously, Avdi's content is top-notch. Also, the [ruby-rogues](http://devchat.tv/ruby-rogues/) Podcast is
amazing too. They have a great panel and their guests are awesome. Go check
them out.

(2) This is actually fairly common in math textbooks, and there is good
argument for that. Working out the gruesome details of the path to find the
answer to a non-trivial problem is by itself as an humongous amount of work
and is never linear. Presenting the final solution and working out just the
necessary to prove it right may seem like the author put the solution out of
the hat, but surely is the least demanding way to grasp the concepts needed
to find the answer and it's consequences. Mathematicians are actually lazy
guys. There is just too much Math out there to understand, and we can't
afford to lose time, specially if someone has already cleaned the gore
before us.

(3) I have absolutely no evidence for this claim.
