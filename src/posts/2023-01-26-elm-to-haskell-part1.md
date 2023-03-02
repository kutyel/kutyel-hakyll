---
author: 'Flavio Corpa'
authorTwitter: '@FlavioCorpa'
desc: 'A series of blog posts for explaining Haskell to Elm developers interested to learn the language that powers the compiler for their favourite language!'
image: ./images/haskell-elm.png
keywords: 'haskell,elm,functional,programming'
lang: 'en'
title: 'Haskell for Elm developers: giving names to stuff (Part 1 - Functors)'
date: '2023-01-27T15:01:00Z'
---

This post is targeted towards all those Elm developers (and functional programmers in general) who are curious about Haskell and would like to learn how what they already know and love from Elm maps directly to Haskell.

Also, since Haskell's feature set and syntax are wider than Elm's, of course I'll need to try and fill the gaps and explain certain things that just do not exist in Elm. 😉

If this first post gets enough attention, I might consider adding more follow up posts and turn this into a series (hopefully).

## Let's talk about `Functor`s!

If you have ever seen Haskell code before, you can really tell it has greatly influenced Elm syntax, one of the biggest differences is that in Haskell type declarations are preceded by `::`, whereas in Elm only by `:`.

Another big difference is that in Haskell there is a concept called **typeclasses**, which we can explain more or less saying that they group a class of types and help us define interfaces that a certain data type need to fulfil to be considered "an instance of that specific typeclass".

For example, the Functor typeclass in Haskell is defined like this:

```haskell
class Functor f where
  fmap :: (a -> b) -> f a -> f b
```

This typeclass declaration in Haskell just means that for a general type `f`, it will "be a Functor" if it has a map function. As you can see, any map function (or fmap) needs to have the signature `(a -> b) -> f a -> f b`. More accurately, we can say that any custom type that implements a function with this type signature **does have an instance of the Functor typeclass**.

I probably do not need to explain what the (f)map function does, as you are already using Functors in Elm every single day! 🤯 To list some of them: `List`, `Maybe`, `Result`, `Dict`, `Task`, etc...

Why is that typeclass called **Functor** instead of **Mappable**? 🤷🏼‍♂️

**Why is this important?** Well, I think one of the design decisions for Elm was to be simple from the beginning and not bother people with buzzwords, just let them use the code and gain intuition about how things work and that will do. But unfortunately if we want to learn Haskell after Elm we need to start putting random names on things! 😉

## Infix operators are nice, actually

Yet another big difference between Haskell and Elm is obviously Haskellers love for _infix operators_. For example, instead of using fmap you could use the `<$>` operator. Consider the following mundane Elm code:

```elm
[1,2,3,4] |> List.map ((*) 2) -- > [2,4,6,8] : List number
```

This would be possible to write in many different styles in Haskell:

```haskell
fmap (*2) [1..4]    -- > [2,4,6,8]
map (*2) [1..4]     -- > [2,4,6,8]
(*2) <$> [1..4]     -- > [2,4,6,8]
[1..4] <&> (*2)     -- > [2,4,6,8]
(*2) `fmap` [1..4]  -- > [2,4,6,8]
(*2) `map` [1..4]   -- > [2,4,6,8]
```

There are quite a few things to learn from this snippet alone:

1. Notice that `map` is just a more specific implementation of `fmap` that in Haskell only works with `List`s!
2. In Haskell we have some nice syntax sugar for ranges of things, where `[1..4]` is equivalent to `List.range 1 4` in Elm.
3. It is easier to work with infix operators and partially applied functions in Haskell generally speaking, where adding a parameter to either side of the operator would mean completely different things if that operation is not commutative (`2^` vs `^2`).
4. Any function in Haskell can be used as an infix operator with backticks (like in lines 5 and 6 of the Haskell snippet, this feels weird at the beginning, but sometimes it actually helps readability!).
5. If you need a flipped version of `<$>` for some reason, you can import it from `Data.Functor` and it is called `<&>` 🙈.

**Why is this nice?** I won't argue if this is better or worse, but at least we have more options in the language to express things!

What you haven't been told is that **Elm does actually have typeclasses**! 😱 Noticed that `number` type in the previous snippet? `comparable` and `appendable` are other examples of typeclasses used in `elm/core`, so typeclasses exist in the language but we as users of Elm can't define them, only its creator... 😜

## Why Haskell and typeclasses are correct!

This part is a little rant and totally subjective to how I view programming, but some time ago I tweeted this:

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Are you sure we don&#39;t need typeclasses? 😅 <a href="https://t.co/grL1GUH4K4">pic.twitter.com/grL1GUH4K4</a></p>&mdash; フラビオ🥷🏼 (@FlavioCorpa) <a href="https://twitter.com/FlavioCorpa/status/1570739010322169856?ref_src=twsrc%5Etfw">September 16, 2022</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

Now it is the perfect time to explain myself in more detail! (And without trying to offend anyone 😉).

I think the fact that we have to write such boilerplate code is a _mistake_, if `Result` is a functor, and `Cmd` too, **we should not need to have to write** that mapping function manually! In Haskell, you could achieve this easily like this:

```haskell
{-# language DeriveFunctor #-}

-- ...

newtype HttpCmd err a
  = HttpCmd (Cmd (Result (Error err) a))
  deriving (Functor)
```

By creating a **newtype** instead of a type alias and using some special Haskell magic, now we could just use `fmap` or `<$>` and never have to write such function by hand!

Of course you could still write the `fmap` function for this custom type by hand, but one of the nicest things about Haskell in my opinion is that it provides _deriving mechanisms_ to implement things for free for us. One such mechanism is the `DeriveFunctor` language extension.

If we chose to keep the type alias approach we could have written the same function in Haskell this way:

```haskell
httpCmdMap ::
  (Functor f1, Functor f2) =>
  (a -> b) ->
  f1 (f2 a) ->
  f1 (f2 b)
httpCmdMap f = fmap (fmap f)
```

This is another difference with Elm: whatever we see to the left of the fat arrow (`=>`) in the type declaration, are called **typeclass constraints**, and what they mean in this specific case is that whatever type we use for `f1` and `f2`, they need to _have an instance of the `Functor` typeclass_.

As you might have noticed, Haskell has a compiler extension system that allow us to toggle additional features to the language, this is exactly what `{-# language DeriveFunctor #-}` does.

I am not saying we should have this in Elm (in fact, many complains about Haskell lie in the fact that we have probably **too many language extensions** already! 🙈) but, having types of classes that share common interfaces and being able to re-use functions and infix operators in many different types is a win-win from my perspective! 🚀

## A small note on function composition

I've seen many Elm developers (specially people learning the language, or new to functional programming in general) use the following pattern, which feels a bit wrong to me:

```elm
someListOfAs
    |> List.map turnAtoB
    |> List.map turnBtoC
    |> List.map turnCtoD -- > List d

```

Whenever you map something multiple times, we can make use of the fact that we can always _map once_, and **compose N functions** together!

```elm
-- please do this instead 🙏🏻
someListOfAs
    |> List.map (turnAtoB >> turnBtoC >> turnCtoD)
```

Since piping stuff with `|>` is the bread and butter of Elm, people do not really stop and think that they can combine multiple operations at once, but hey! That's why we have function composition and everything is curried by default in Elm, so let's make use of it! 🤓

And here is a mini point in favor of Elm, the operators chosen for the language are **much more readable** in my opinion than the ones in Haskell, mainly:

1. left to right composition: `>>` in Elm, `Control.Arrow.>>>` in Haskell (not even in the Prelude! 😭).
2. right to left composition: `<<` in Elm, just `.` in Haskell, which is very weird for newcomers. 😕
3. left to right function application: `|>` in Elm (the beloved pipe), `&` in Haskell, absolutely terrible, no wonder it is not as commonly used as in Elm. 🥲
4. right to left function application: `<|` in Elm, `$` in Haskell, which is probably one of the [most widely used operators](https://www.fpcomplete.com/haskell/tutorial/operators/) and not very readable when you are learning Haskell at all! 🫢

## Acknowledgements

I had the initial idea for this blogpost on a plane ✈️ back to Spain but what really motivated me was to try and share my love for Haskell with some very special Elm engineers that had to put up with me for some time and to which I would like to give special thanks: [@tomaslatal](https://twitter.com/TomasLatal), [@janiczek](https://twitter.com/janiczek) and [@janjelinek](https://twitter.com/kurnick). 🙌🏻

I hope you all enjoyed this post, learned a thing or two and enticed you to learn a little more of Haskell. 😉

Also I want to give a huge kudos to [@serras](https://twitter.com/trupill) for proofreading this post 😘.

If you enjoyed this post and would like to see this turned into a series (_I have ideas in my head already for posts about Applicatives, Monads, IO, parser combinators, etc._), please share it in your social networks and **follow me on [Twitter](https://twitter.com/FlavioCorpa)!** 🙌🏻
