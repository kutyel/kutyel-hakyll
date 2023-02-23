---
author: "Flavio Corpa"
authorTwitter: "@FlavioCorpa"
desc: "A series of blog posts for explaining Haskell to Elm developers interested to learn the language that powers the compiler for their favourite language!"
image: ./images/haskell-elm.png
keywords: "haskell,elm,functional,programming"
lang: "en"
title: "Haskell for Elm developers: giving names to stuff (Part 2 - Applicative Functors)"
date: "2023-02-23T12:22:00Z"
---

Since the previous post had some measure of success, I decided to continue the series! 🎉

Without much preamble, let's look at the typeclass definition in Haskell for Applicative Functors:

```haskell
class Functor f => Applicative f where
  pure :: a -> f a
  (<*>) :: f (a -> b) -> f a -> f b
```

This looks a bit scarier 👻 at the beginning, but do not worry, we will explain ever bit at a time.

The first thing we can notice is that the typeclass definition has itself a typeclass constraint! This is new for us, we did not know that could happen (until now), and this is what the `class Functor f =>` bit means.

**What are the implications of this?** Well, as you might have already guessed, it just means one simple thing: _every_ Applicative Functor must be first a _valid Functor_, not a very big surprise, right? 😉

The second thing we can notice is that, contrary to the `Functor` typeclass declaration that specified only a function to be implemented (`fmap`), now we have 2 functions every Applicative Functor must have to satisfy the instance: `pure`, and the mysterious `<*>` operator, which we will call the TIE fighter operator from now on (because I love the name and yes, I'm a big STAR WARS fan 🤓).

Let's talk about each of them separately but first, spoiler alert ⚠️, in Elm, some examples of Applicative Functors you use every day are: `List`, `Maybe`, `Result` and `Task`.

## The `pure` function

Out of the two needed functions, `pure` is probably the easiest to explain: it just "lifts" any value `a` into an Applicative Functor context `f`.

```haskell
pure :: a -> f a
```

What are some examples of this in Elm? For example, the `List.singleton` function!

```elm
> List.singleton
<function> : a -> List a
```

Okay, what about `Maybe`?

```elm
> Just
<function> : a -> Maybe a
```

This might be new for you, but **type Constructors are also functions!** 🤯

This means that for `Maybe` we just have _one_ `pure` function (`Nothing` is just a value, not a function), and you probably can guess what is the `pure` implementation for `Result`:

```elm
> Ok
<function> : value -> Result error value
```

This example is a little harder to understand, because the `f` Applicative Functor _structure_ is actually `Result error`, so that this matches:

```haskell
pure :: value -> f            value
Ok :    value -> Result error value
```

Note that, because of this, the `Err` contructor/function is _not_ a correct implementation, since the Applicative Functor structure is not preserved:

```elm
> Err
<function> : error -> Result error value
```

You can probably see here that there is no `f a` structure, so only `Ok` could be considered the correct implementation of `pure` for `Result`.

To keep with the Elm explanations, `Task.succeed` is the `pure` equivalent for the `Task` Applicative Functor:

```elm
> import Task
> Task.succeed
<function> : a -> Task.Task x a
```

## The TIE fighter operator (`<*>`)

Now let us begin with the fun part:

```haskell
(<*>) :: f (a -> b) -> f a -> f b
```

This is an _infix operator_ that takes a lifted function `f (a -> b)` and a lifted value `f a` and somehow magically _applies_ (that's why sometimes this function is also refered to as `apply` or just `ap`) the lifted function to the lifted `a` to finally return a lifted `b` value (`f b`). But by now you should be wondering: **how on Earth is this actually useful!? 🤔**

Well, let's have a peek at the actual implementation of the `Applicative` typeclass in `GHC.Base`:

```haskell
class Functor f => Applicative f where
    {-# MINIMAL pure, ((<*>) | liftA2) #-}
    -- | Lift a value.
    pure :: a -> f a

    -- | Sequential application.
    (<*>) :: f (a -> b) -> f a -> f b
    (<*>) = liftA2 id

    -- | Lift a binary function to actions.
    -- ==== __Example__
    -- >>> liftA2 (,) (Just 3) (Just 5)
    -- Just (3,5)

    liftA2 :: (a -> b -> c) -> f a -> f b -> f c
    liftA2 f x = (<*>) (fmap f x)
```

First thing we notice is that there is a [MINIMAL pragma](https://ghc.gitlab.haskell.org/ghc/doc/users_guide/exts/pragmas.html#minimal-pragma), this tells GHC (the main compiler of Haskell) that the required functions that a type needs to implement in order to have a valid `Applicative` instance are `pure` and `<*>` OR `liftA2`.

Second thing we can notice, is that `<*>` and `liftA2` are almost identical: they are defined in terms of each other! 🤯

So, `liftA2` is basically:

```haskell
liftA2 f x = (<*>) (fmap f x)
```

And, the TIE fighter operator is just:

```haskell
(<*>) = liftA2 id
```

The `id` function is the silliest function in Haskell: `id :: a -> a` and in Elm is properly called `identity`:

```elm
> identity
<function> : a -> a
```

**But, how come this is possible (that two functions are defined in terms of each other)!?** 😱

Well, the answer is that Haskell is a [lazily evaluated language](https://wiki.haskell.org/Lazy_evaluation), but leaving that behind us, does not the type declaration of `liftA2` look familiar to us Elm developers? 👀

```haskell
liftA2 :: (a -> b -> c) -> f a -> f b -> f c
```

Besides, looking at the example code given, can we achieve something similar in Elm?

```haskell
-- ==== __Example__
-- >>> liftA2 (,) (Just 3) (Just 5)
-- Just (3,5)
```

The answer is: yes, we can! 🚀

```elm
> Maybe.map2 Tuple.pair (Just 3) (Just 5)
Just (3,5) : Maybe ( number, number1 )
```

Remember how I told you on the previous post that infix operators were just superior in Haskell? We are not able to do this `(,)` in Elm, so we need to resign ourselves to just use `Tuple.pair : a -> b -> ( a, b )`, which does basically the same.

If we query the Elm REPL for the type of `Maybe.map2`, we get:

```elm
> Maybe.map2
<function> : (a -> b -> value) -> Maybe a -> Maybe b -> Maybe value
```

Compare this to the type of `liftA2` again:

```elm
liftA2     :: (a -> b -> value) -> f a     -> f b     -> f c
Maybe.map2  : (a -> b -> value) -> Maybe a -> Maybe b -> Maybe value
```

You guessed it correctly: the `liftA2` equivalent in Elm are all the `*.map2` functions we can find!

So, when we said before that `List`, `Maybe`, `Result` and `Task` were **Applicative Functors in Elm**, is because we have `List.map2`, `Maybe.map2`, `Result.map2` and `Task.map2`.

This ties in nicely with an excellent article published by [Joël Quenneville](https://twitter.com/joelquen) some time ago, called ["Running Out of Maps"](https://thoughtbot.com/blog/running-out-of-maps) (very nice pun btw 😜).

In that post, he explains that if anytime you run out of `mapN` functions, you can define this simple combinator:

```elm
andMap = Maybe.map2 (|>)
```

And if we query again the Elm REPL for the type of `andMap` we get the following:

```elm
> andMap = Maybe.map2 (|>)
<function> : Maybe a -> Maybe (a -> value) -> Maybe value
```

Am gonna casually remind you right now about the type declaration of the TIE fighter operator, in case you forgot:

```haskell
(<*>) :: f (a -> b) -> f a -> f b
```

**What can we draw from all this crazyness?**

We just FOUND THE TIE FIGHTER OPERATOR IN ELM! It is just `flip andMap`!! 😎

**So why all of this is important again and when the heck am I going to use Applicative Functors (I hear your mind saying 🧠💭)???**

Well, if you have ever used the `Json.Decode.Extra` package, you might have probably written code like this:

```elm
decoder : Decoder Document
decoder =
    Decode.succeed Document
        |> Decode.andMap (Decode.field "id" Decode.string)
        |> Decode.andMap (Decode.field "title" Decode.string)
        |> Decode.andMap documentTypeDecoder
        |> Decode.andMap (Decode.field "ctime" Iso8601.decoder)
        |> Decode.andMap (Decode.field "mtime" Iso8601.decoder)
```

The exact same code in Haskell, using our beloved infix operators, would look like this:

```haskell
decoder :: Decoder Document
decoder =
  Document
    <$> (decodeStringField "id")
    <*> (decodeStringField "title")
    <*> documentTypeDecoder
    <*> (decodeIso8601Field "ctime")
    <*> (decodeIso8601Field "mtime")
```

This means two things:

1. You have been using Applicative Functors all along for a very long time probably without notice! 🥁🥁🥁
2. Of course, this also means that [Json.Decode.Decoder](https://package.elm-lang.org/packages/elm-community/json-extra/latest/Json-Decode-Extra#andMap) is also an Applicative Functor!! 👏🏻

## Acknowledgements

Many people has made possible the production of this blogpost, I want to personally thank [Robert Pearce](https://twitter.com/RobertWPearce) for his excellent [Hakyll + Nix tutorial](https://robertwpearce.com/the-hakyll-nix-template-tutorial.html), and [Domen Kožar](https://twitter.com/domenkozar), for all his work with [Cachix](https://www.cachix.org/) and the [Nix](https://nixos.org/) ecosystem in general (and for his infinite patience 😇).

I would also like to thank [Chris Allen](https://twitter.com/bitemyapp) and [Julie Moronukie](https://twitter.com/argumatronic), because together they created the [Haskell Book™️](https://haskellbook.com/), which is still in my opinion **the best possible way to learn Haskell** and it is actually the reason I am today working with Haskell.

Could not be more grateful to all of them! 😍

Enough bad puns for today, hope you learned something new! If you enjoyed this post and would like me to continue the series (_next up would probably be MOOONAAAAAADSSSS 👻🦇🦇🦇_), please share it in your social networks and **follow me on [Twitter](https://twitter.com/FlavioCorpa)!** 🙌🏻
