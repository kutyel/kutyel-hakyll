---
author: 'Flavio Corpa'
authorTwitter: '@FlavioCorpa'
desc: 'A series of blog posts for explaining Haskell to Elm developers interested to learn the language that powers the compiler for their favourite language!'
image: ./images/haskell-elm.png
keywords: 'haskell,elm,functional,programming'
tags: haskell, elm, fp
lang: 'en'
title: 'Haskell for Elm developers: giving names to stuff (Part 6 - Foldable)'
date: '2026-02-13T14:00:00Z'
---

<img src="./images/haskell-elm.svg" alt="logo" width="300px">

Welcome back! In my [last post](https://flaviocorpa.com/haskell-for-elm-developers-giving-names-to-stuff-part-5-semigroups-and-monoids.html), we talked about Semigroups and Monoids, and we even discovered the deep relationship between folds and Monoids. But we left something out: the `Foldable` typeclass itself! So today, let's give it the attention it deserves. 😊

## What is Foldable?

If you recall from the previous post, we used `foldr` and `foldl` on lists as if it were the most natural thing in the world. But in Haskell, folding is not limited to lists! The `Foldable` typeclass generalises the concept of folding to _any_ data structure that can be collapsed into a summary value.

Here is the (simplified) definition:

```haskell
class Foldable t where
  {-# MINIMAL foldMap | foldr #-}
  foldr  :: (a -> b -> b) -> b -> t a -> b
  foldl  :: (b -> a -> b) -> b -> t a -> b

  foldMap :: Monoid m => (a -> m) -> t a -> m
  foldMap f = foldr (mappend . f) mempty

  fold :: Monoid m => t m -> m
  fold = foldMap id

  length  :: t a -> Int
  null    :: t a -> Bool
  elem    :: Eq a => a -> t a -> Bool
  maximum :: Ord a => t a -> a
  minimum :: Ord a => t a -> a
  sum     :: Num a => t a -> a
  product :: Num a => t a -> a
  toList  :: t a -> [a]
```

That is a LOT of stuff for free! And the beautiful thing is: you only need to implement **either** `foldr` or `foldMap` to get all of these functions automatically 🤯 (as indicated by the MINIMAL pragma).

## Foldable in Elm (sort of)

Now, Elm does not have typeclasses (well, not user-definable ones, as we discussed in [Part 1](https://flaviocorpa.com/haskell-for-elm-developers-giving-names-to-stuff-part-1-functors.html)), so there is no `Foldable` typeclass. But that does not mean you have not been using foldable things all along!

Let's see what we have in `elm/core`:

```elm
List.foldr   : (a -> b -> b) -> b -> List a -> b
List.foldl   : (a -> b -> b) -> b -> List a -> b
Array.foldr  : (a -> b -> b) -> b -> Array a -> b
Array.foldl  : (a -> b -> b) -> b -> Array a -> b
Dict.foldr   : (k -> v -> b -> b) -> b -> Dict k v -> b
Dict.foldl   : (k -> v -> b -> b) -> b -> Dict k v -> b
Set.foldr    : (a -> b -> b) -> b -> Set a -> b
Set.foldl    : (a -> b -> b) -> b -> Set a -> b
String.foldr : (Char -> b -> b) -> b -> String -> b
String.foldl : (Char -> b -> b) -> b -> String -> b
```

Do you see the pattern? `List`, `Array`, `Dict`, `Set` and `String` all have `foldr` and `foldl`. In Haskell, they would all be instances of `Foldable`, and you could write **one** generic function that works on all of them. In Elm, you have to pick the specific module each time... but the concept is the same! ✨

And then there are all the derived functions: `List.length`, `List.isEmpty`, `List.member`, `List.sum`, `List.product`, `List.maximum`, `List.minimum`... do they look familiar? They are _exactly_ the functions that `Foldable` gives you for free in Haskell! 😉

## How easy is it to implement Foldable?

Here is one of my favourite things about `Foldable`: implementing it is almost trivially easy. Suppose we have a simple binary tree type in Haskell:

```haskell
data Tree a
  = Leaf
  | Node (Tree a) a (Tree a)
```

Making it `Foldable` is just this:

```haskell
instance Foldable Tree where
  foldMap _ Leaf         = mempty
  foldMap f (Node l x r) = foldMap f l <> f x <> foldMap f r
```

That's it! Three lines. And now we get `foldr`, `foldl`, `length`, `sum`, `product`, `toList`, `elem`, `null`, `maximum`, `minimum` and more... all for free! 🎁

```haskell
>>> let tree = Node (Node Leaf 1 Leaf) 2 (Node Leaf 3 Leaf)

>>> toList tree
[1,2,3]

>>> sum tree
6

>>> product tree
6

>>> length tree
3

>>> elem 2 tree
True

>>> null tree
False

>>> maximum tree
3
```

If you use the `DeriveFoldable` language extension, you don't even need to write the instance by hand:

```haskell
{-# language DeriveFoldable #-}

data Tree a
  = Leaf
  | Node (Tree a) a (Tree a)
  deriving (Foldable)
```

And boom, you are done! Haskell literally writes the `Foldable` instance for you. 🪄

## The power of `scanl`

Now, there's a function closely related to folds that I find incredibly useful and want to highlight: `scanl`. If `foldl` reduces a structure down to a single value, `scanl` is like `foldl` but it _keeps all the intermediate results_:

```haskell
scanl :: Foldable f => (b -> a -> b) -> b -> f a -> NonEmpty b
```

Notice how `scanl` in Haskell takes any `Foldable` (not just a `List`!) and returns a `NonEmpty` list, because there will always be at least one element (the initial accumulator). Let's see it in action:

```haskell
>>> import Data.List.NonEmpty (scanl)

>>> scanl (+) 0 [1, 2, 3, 4]
0 :| [1,3,6,10]

>>> scanl (*) 1 [1, 2, 3, 4]
1 :| [1,2,6,24]
```

See how the last element of `scanl (+) 0 [1, 2, 3, 4]` is `10`, which is exactly what `foldl (+) 0 [1, 2, 3, 4]` would return? The `scanl` function gives you the _entire journey_, not just the destination! 🗺️

There is also `scanl1`, which uses the first element as the starting value:

```haskell
>>> import Data.List.NonEmpty (scanl1)

>>> scanl1 (+) (1 :| [2, 3, 4])
1 :| [3,6,10]
```

And of course, there are right-to-left variants too: `scanr` and `scanr1`.

## `scanl` in Elm!

Here is the nice surprise: even though Elm does not have a built-in `scanl`, the community has got you covered! The excellent [`elm-community/list-extra`](https://package.elm-lang.org/packages/elm-community/list-extra/8.7.0/List-Extra#scanl) package provides both `scanl` and `scanl1`:

```elm
import List.Extra exposing (scanl, scanl1)

scanl (+) 0 [ 1, 2, 3, 4 ]
--> [ 0, 1, 3, 6, 10 ]

scanl1 (+) [ 1, 2, 3 ]
--> [ 1, 3, 6 ]
```

The type signatures are exactly what you would expect:

```elm
scanl  : (a -> b -> b) -> b -> List a -> List b
scanl1 : (a -> a -> a) -> List a -> List a
```

## When is `scanl` useful?

You might be wondering: ok that's nice, but when would I actually _use_ this? Here are some practical examples:

**Running totals** (think of a bank account balance):

```elm
transactions = [ 100, -50, 200, -30, -80 ]

scanl (+) 1000 transactions
--> [ 1000, 1100, 1050, 1250, 1220, 1140 ]
```

**Tracking state over time** (building up a history):

```haskell
>>> scanl (flip (:)) [] [1, 2, 3]
[] :| [[1],[2,1],[3,2,1]]
```

**Computing prefix maximums**:

```elm
scanl1 max [ 3, 1, 4, 1, 5, 9, 2, 6 ]
--> [ 3, 3, 4, 4, 5, 9, 9, 9 ]
```

Anytime you need a fold but also care about the intermediate steps, `scanl` is your friend! 🤝

## Foldable + Monoid = ❤️

Before we wrap up, I want to circle back to the beautiful connection between `Foldable` and `Monoid` that we explored in the previous post. Remember `foldMap`?

```haskell
foldMap :: (Foldable t, Monoid m) => (a -> m) -> t a -> m
```

This is the heart of `Foldable`. It says: "give me a way to turn each element into a Monoid, and I will combine them all for you". And since `foldMap` alone is enough to define a complete `Foldable` instance, we can confidently say:

> **Foldable is just the typeclass that lets you `foldMap` over a structure!**

Which, if you think about it, is just a fancy way of saying: "I can visit all the elements and combine them". Simple, powerful, and beautiful. ✨

## Acknowledgements

Hope you learned something about `Foldable` and `scanl` today! As usual, these concepts are things you already use in Elm every day, we are just giving them a proper name. 😉

If you found joy in this blogpost and would like me to continue the series (next up would be... `Traversable`!), please consider [sponsoring my work](https://github.com/sponsors/kutyel), share it in your social networks and **follow me on [Twitter](https://twitter.com/FlavioCorpa)/[BlueSky!](https://bsky.app/profile/flaviocorpa.com) 🦋** 🙌🏻
