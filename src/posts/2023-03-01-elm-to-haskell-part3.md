---
author: "Flavio Corpa"
authorTwitter: "@FlavioCorpa"
desc: "A series of blog posts for explaining Haskell to Elm developers interested to learn the language that powers the compiler for their favourite language!"
image: ./images/haskell-elm.png
keywords: "haskell,elm,functional,programming"
lang: "en"
title: "Haskell for Elm developers: giving names to stuff (Part 3 - Monads!)"
date: "2023-03-01T17:22:00Z"
---

It is finally time, I did not think I would ever write a [`Monad` tutorial](https://byorgey.wordpress.com/2009/01/12/abstraction-intuition-and-the-monad-tutorial-fallacy/), but here it is! 😅 Let us have a look at the way `Monad`s are defined in Haskell:

```haskell
class (Applicative m) => Monad m where
  return :: a -> m a
  (>>) :: m a -> m b -> m b
  (>>=) :: m a -> (a -> m b) -> m b
```

The first thing we can notice again is that the typeclass definition has itself a typeclass constraint, implied by the `class Applicative m =>` bit, just like in our previous post about Applicative Functors.

Needless to say, this means that every `Monad` instance must satisfy the `Applicative` instance first, and that one, in return, the `Functor` instance. 😵‍💫 By the way, if you have not already, to understand this whole post and gain more intuition about `Monad`s, you better read the previous two posts I made:

1. [Haskell for Elm developers: giving names to stuff (Part 1 - Functors)](https://flaviocorpa.com/haskell-for-elm-developers-giving-names-to-stuff-part-1-functors.html)
2. [Haskell for Elm developers: giving names to stuff (Part 2 - Applicative Functors)](https://flaviocorpa.com/haskell-for-elm-developers-giving-names-to-stuff-part-2-applicative-functors.html)

SPOILER ALERT ⚠️! In Elm, some examples of `Monad`s you use every day are... 🥁🥁🥁 (_drum rolls..._) again: `List`, `Maybe`, `Result` and `Task`!!! 🤯

## The `return` function

If you have good memory, you might be asking yourself right now: what is the difference between `pure :: a -> m a` and `return`?

```haskell
return :: a -> m a
```

And the answer is: there is **none**.

If you want to find out the [historical reasons](https://stackoverflow.com/a/32788607/2834553) why we ended up with two functions called different that basically do the same thing, please check this [Reddit thread](https://www.reddit.com/r/haskell/comments/4tu9qf/is_there_any_pure_return/) from 7 years go. 👴🏻 There is a modern [Haskell trend](https://github.com/search?o=desc&q=use+pure+instead+of+return&s=&type=Commits) to prefer `pure` over `return` in code (I contributed to this trend a fair bit myself), but it is totally up to you!

## The Mr. Pointy (🤣) operator (`>>`)

I did not come up with the name, I swear, I read it in the [Haskell Book™️](https://haskellbook.com/). Some people refer to it as the _sequencing operator_, but it does not have an "official" English-language name:

```haskell
(>>) :: m a -> m b -> m b
```

The only thing the Mr. Pointy operator does is sequencing two actions while discarding any result value of the first action.

Let’s have another peek at the actual implementation of the `Monad` typeclass in `GHC.Base` and see what we can learn this time from it:

```haskell
class (Applicative m) => Monad m where
  -- | Sequentially compose two actions, passing any value produced
  -- by the first as an argument to the second.
  (>>=) :: forall a b. m a -> (a -> m b) -> m b

  -- | Sequentially compose two actions, discarding any value produced
  -- by the first, like sequencing operators (such as the semicolon)
  -- in imperative languages.
  (>>) :: forall a b. m a -> m b -> m b
  m >> k = m >>= \_ -> k
  {-# INLINE (>>) #-}

  -- | Inject a value into the monadic type.
  return :: a -> m a
  return = pure
```

First thing we can notice is hey! Another language pragma, this time called [`INLINE pragma`](https://ghc.gitlab.haskell.org/ghc/doc/users_guide/exts/pragmas.html#inline-pragma), do not worry too much about it, all it is doing is performing a little optimization on the compiler level to tell GHC that it can go ahead and _inline_ that function.

Second thing we can notice is the presence of new `forall` keywords used in the type declaration, it goes beyond the scope of this post to explain those in Haskell but if you really want to know what they are doing, check out [this blogpost](https://wasp-lang.dev/blog/2021/09/01/haskell-forall-tutorial).

A third thing we can notice is that Mr. Pointy (`>>`) is defined in terms of `>>=`:

```haskell
  (>>) :: forall a b. m a -> m b -> m b
  m >> k = m >>= \_ -> k
```

Because of this, we are not going to waste any time trying to find the definition of Mr. Pointy in Elm (because if you define `>>=` for your type, you again get _for free_ the definition of `>>`), but rather cut right to the meat!

## The Monadic bind operator (`>>=`)

I am going to try my best to give you the simplest explanation about this operator, but since I assume you know Elm, the explanation is going to be quite trivial: 😉

```haskell
(>>=) :: m a -> (a -> m b) -> m b
```

By looking at the type signature of the bind operator, does it not look familiar to you, dear Elm developer? Have you ever tried to `flatMap` a `List`? `flatMap` is the name chosen by JavaScript and many other languages, but Elm chose a couple of interesting ones, let us begin first with the `List` Monad. 🙊

```elm
> List.concatMap
<function> : (a -> List b) -> List a -> List b
```

As you can see, `List.concatMap` is just a flipped implementation of the `>>=` operator for Elm, but what about `Maybe`, `Result` and `Task`?

```elm
> Maybe.andThen
<function> : (a -> Maybe b) -> Maybe a -> Maybe b
```

Yes! We can say with confidence that those types satisfy the `Monad` instance because we have `Maybe.andThen`, `Result.andThen` and `Task.andThen` and all of those functions allow us to **chain computations**! 👏🏻 Hope that was not so scary after all! 👻😘

## The infamous `do` notation

[Famously](https://github.com/avh4/elm-format/issues/568), the issue with the `|> andThen` approach, is that [**elm-format**](https://github.com/avh4/elm-format) (the _de facto standard_ for all Elm applications) formats everything in a rather [ugly manner](https://github.com/avh4/elm-format/issues/352):

```elm
map5 :
    (a -> b -> c -> d -> e -> result)
    -> Task x a
    -> Task x b
    -> Task x c
    -> Task x d
    -> Task x e
    -> Task x result
map5 func taskA taskB taskC taskD taskE =
    taskA
        |> andThen
            (\a ->
                taskB
                    |> andThen
                        (\b ->
                            taskC
                                |> andThen
                                    (\c ->
                                        taskD
                                            |> andThen
                                                (\d ->
                                                    taskE
                                                        |> andThen (\e -> succeed (func a b c d e))
                                                )
                                    )
                        )
            )
```

This, however, is _not an issue_ that `elm-format` is responsible for (as a matter of fact, I love `elm-format` and think it is a **modern masterpiece** of software engineering! 😍), but it is rather a _consequence_ of the language design decision _NOT_ to have something like `do` notation in Elm. For example, the above code would be really similar **without** `do` notation in Haskell (if you use a formatter like [`ormolu`](<(https://ormolu-live.tweag.io/)>)):

```haskell
map5 ::
  (a -> b -> c -> d -> e -> result) ->
  Task x a ->
  Task x b ->
  Task x c ->
  Task x d ->
  Task x e ->
  Task x result
map5 func taskA taskB taskC taskD taskE =
  taskA
    >>= \a ->
      taskB
        >>= \b ->
          taskC
            >>= \c ->
              taskD
                >>= \d ->
                  taskE
                    >>= \e -> pure (func a b c d e)
```

Yes, there are Haskellers that still to this very day **format their code by hand** (😅), and so they would use less indentation in the aforementioned code, but we are not gonna let humans get in the way of the machine (thank God we have formatters 😍). Nevertheless, thanks to `do` notation, we can write it in the following manner:

```haskell
map5 ::
  (a -> b -> c -> d -> e -> result) ->
  Task x a ->
  Task x b ->
  Task x c ->
  Task x d ->
  Task x e ->
  Task x result
map5 func taskA taskB taskC taskD taskE = do
  a <- taskA
  b <- taskB
  c <- taskC
  d <- taskD
  e <- taskE
  pure $ func a b c d e
```

Doesn't it just look beautiful!? 💜

> Funnily enough, [**ormolu**](https://github.com/tweag/ormolu) is the closest we can get to something like `elm-format` in Haskell (which I also love 🤩 and am using to format every code sample in this blogpost) and many Haskellers hate it for no reason at all! 🤷🏼‍♂️

## Acknowledgements

Special thanks to [@forensor](https://twitter.com/Forensor) and other readers that have encouraged me to continue the series.

Thanks again to [@serras](https://twitter.com/trupill) for technical proofreading this post again (he single-handedly wrote an [entire book](https://leanpub.com/book-of-monads) exclusively about `Monad`s after all 🫡) and remember! **Always be nice** to each other online and have in mind that we are all in different learning paths in our lives and that we can help each other out by giving _constructive feedback_, rather than trying to [destroy people's hopes and dreams](https://twitter.com/FlavioCorpa/status/1629225727852789762?s=20). 😅

Hope `Monad`s finally clicked for you ✨ (if they had not already) and you learned something new! If you enjoyed this post and would like me to continue the series (_next up would probably be maybe **parser combinators**?_, let me know what you would like to hear next!), please share it in your social networks and **follow me on [Twitter](https://twitter.com/FlavioCorpa)!** 🙌🏻
