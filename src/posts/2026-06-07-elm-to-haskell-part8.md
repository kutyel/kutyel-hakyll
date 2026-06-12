---
author: 'Flavio Corpa'
authorTwitter: '@FlavioCorpa'
desc: 'A series of blog posts for explaining Haskell to Elm developers interested in learning the language that powers the compiler for their favourite language!'
image: ./images/haskell-elm.png
keywords: 'haskell,elm,functional,programming'
tags: haskell, elm, fp
lang: 'en'
title: 'Haskell for Elm developers: giving names to stuff (Part 8 - IO)'
date: '2026-06-07T14:00:00Z'
postId: 'at://did:plc:dvrocvv5szl2evqiafsx4iyw/app.bsky.feed.post/3mnz52xzd3k2e'
---

<img src="./images/haskell-elm.svg" alt="logo" width="300px">

Welcome back! In my [last post](https://flaviocorpa.com/haskell-for-elm-developers-giving-names-to-stuff-part-7-traversable.html), we explored `Traversable` and discovered that "the answer is always `traverse`". Today we are going to tackle something that scares a LOT of newcomers to Haskell, and yet — surprise, surprise! — you have been doing it in Elm all along: **`IO`**! 🎉

Funnily enough, all the way back in [Part 1](https://flaviocorpa.com/haskell-for-elm-developers-giving-names-to-stuff-part-1-functors.html) I promised I would eventually write about `IO`... only took me 8 posts to keep my word! 😅

There is a famous question that every Elm developer eventually asks when they peek over the fence into Haskell: _"Wait... if Haskell is pure, how does it print to the screen, read files or make HTTP requests?"_ 🤔

The answer is `IO`, and the beautiful thing is that the mental model is **exactly** the one you already have from Elm's `Task` and `Cmd`. Let me prove it to you! 😉

Quick refresher before we dive in, since we will lean on both concepts: in Elm, a **`Task`** is a _composable description_ of an effect — you can chain tasks with `Task.andThen`, map over them, and they carry a typed error channel. A **`Cmd`** is the _one-shot instruction_ you actually hand to the Elm runtime from `init`/`update`; it is fire-and-forget, and the only way it talks back to you is through a message. The two meet at `Task.perform`/`Task.attempt`, which turn a `Task` into a `Cmd` — because the runtime only accepts `Cmd`s. Keep that pipeline (`Task` ➝ `Cmd` ➝ runtime) in mind: it maps directly onto what Haskell does with `IO` (which stands for Input/Output, btw!).

## The big misconception

The most common misconception about `IO` is thinking that an `IO a` value _is_ the side effect. It is not! An `IO a` is a **description** of an effectful computation that produces a value of type `a` when (and only when) it is eventually run.

Does that sound familiar? It should! It is _precisely_ how the Elm docs describe a [`Task`](https://package.elm-lang.org/packages/elm/core/latest/Task):

> A task is a _description_ of something that needs to be done. [...] The actual benefit of a task is that it does not do anything until you give it to the runtime.

Swap the word "task" for "IO action" and you have a perfect definition of `IO` in Haskell. An `IO a` value is a **recipe**, not the act of cooking. You can pass it around, store it in a list, combine it with other recipes — and _nothing happens_ until the runtime decides to actually run it. 🍳

```haskell
greet :: IO ()
greet = putStrLn "Hello, Elm developer!"
```

Defining `greet` does **not** print anything. `greet` is just a value of type `IO ()` — a description that says "when run, print this line". Referential transparency is preserved! ✨

## `IO` is a Monad (of course it is 🙃)

If you have been following the series, you already know everything you need to _use_ `IO`, because (you guessed it!) `IO` is a `Monad`! (Go back and read [Part 3 - Monads!](https://flaviocorpa.com/haskell-for-elm-developers-giving-names-to-stuff-part-3-monads.html) if you need a refresher.)

That means it has all the machinery you already love:

```haskell
fmap  :: (a -> b) -> IO a -> IO b           -- Functor
pure  :: a -> IO a                          -- Applicative
(>>=) :: IO a -> (a -> IO b) -> IO b         -- Monad
```

And just like with `Task`, the way you chain effectful steps together is with the monadic bind (`>>=`), which is the equivalent of Elm's `Task.andThen`! Compare them side by side:

```haskell
(>>=)       :: IO a    -> (a -> IO b)      -> IO b
Task.andThen ::          (a -> Task x b)  -> Task x a -> Task x b   -- (args flipped)
```

So this little program that asks for your name and greets you (Elm runs in the browser, so there are no real console `Task`s — bear with me and imagine these `getLine`/`putLine` exist just to show the _shape_)...

```elm
import Task

greetUser : Task x ()
greetUser =
    getLine
        |> Task.andThen (\name -> putLine ("Hello, " ++ name ++ "!"))
```

...is, in Haskell, basically identical:

```haskell
greetUser :: IO ()
greetUser =
  getLine >>= \name -> putStrLn ("Hello, " <> name <> "!")
```

And thanks to `do` notation (remember Part 3?), we can write it in that lovely imperative-looking style:

```haskell
greetUser :: IO ()
greetUser = do
  name <- getLine
  putStrLn ("Hello, " <> name <> "!")
```

That `name <- getLine` is _exactly_ the `do` notation desugaring of `>>=` we saw for `Task`. Same `Monad`, same intuition, different effect. 💜

## So where is the `Cmd`? Enter `main`

Here is where the most interesting comparison lives. In Elm, you can build a `Task` all day long, but **a `Task` never runs on its own**. To actually make something happen, you have to hand it to the runtime by turning it into a `Cmd`:

```elm
Task.perform : (a -> msg) -> Task Never a -> Cmd msg
Task.attempt : (Result x a -> msg) -> Task x a -> Cmd msg
```

A `Cmd` is the Elm Architecture's way of saying _"hey runtime, please go run this effect and send me a message back when you are done"_. **You** never run the effect — the Elm runtime does, at the boundary of your program. Your `update` function stays beautifully pure: it just _returns_ `Cmd`s as data. 📨

Haskell works **exactly** the same way, except the "boundary" has a name you already know:

```haskell
main :: IO ()
```

`main` is the single `IO` action that the Haskell runtime (the RTS) actually executes when your program starts. Everything you build is just data — descriptions of effects — until it becomes part of `main`. In other words:

> **`main` is to Haskell what the Elm runtime is to Elm.** It is the _one place_ where descriptions of effects finally get run.

```haskell
main :: IO ()
main = do
  putStrLn "What is your name?"
  name <- getLine
  putStrLn ("Hello, " <> name <> "!")
```

The mapping is gorgeous once you see it:

```
Elm                                Haskell
------------------------------     ------------------------------
Task x a  (a description)          IO a  (a description)
Task.andThen / Task.map            >>= / fmap  (it is a Monad)
Cmd msg   (handed to the runtime)  being part of main
the Elm runtime runs your Cmds     the RTS runs main
```

In Elm, the runtime is _hidden_ and you talk to it through `Cmd`. In Haskell, the runtime is _explicit_ and you talk to it through `main`. That is really the whole difference! 🤯

So when Haskellers tell you `IO` is the way you "describe effects as data and let the runtime run them at the boundary"... drum rolls 🥁🥁🥁 ... that is **the Elm Architecture**! YOU HAVE BEEN DOING `IO` ALL ALONG™️!!! 🎉

## "But Elm's `Task` has an error type and `IO` doesn't!" 🧐

Sharp eye! This is the most important practical difference, so let us address it head on.

Elm's `Task` has **two** type parameters:

```elm
Task error value
```

The `error` channel is part of the type, which is why you have `Task.attempt : (Result x a -> msg) -> Task x a -> Cmd msg` — when the runtime finishes, it hands you back a `Result` so you are _forced_ to handle the failure case. Lovely and safe! 👏🏻

Haskell's `IO`, on the other hand, has only **one** type parameter:

```haskell
IO a
```

There is no error channel in the type. So what happens when things go wrong? Haskell's `IO` actions can throw **runtime exceptions** — and to be precise (because "IO" and "exceptions" both get overloaded a lot), these come in two flavours:

- **Exceptions from the outside world**: reading a file that does not exist, a network connection dropping, the disk being full... Operations like `readFile` signal failure by _throwing_ instead of returning an `Either`. This is closer to JavaScript's `throw` than to Elm's principled `Result`.
- **Exceptions from pure code**: things like `head []`, `error "boom"` or an incomplete pattern match. These lurk inside lazily evaluated _pure_ values and only blow up when something (ultimately `main`) forces them.

That second flavour is the one with no Elm equivalent at all — in Elm, pure code simply _cannot_ throw — and it is honestly one of the few places where Elm is _stricter and safer_ than vanilla Haskell. 😅

To be fair though, exceptions are not inherently evil! Some situations really _are_ exceptional, and insisting that every function must be total has its own costs: Elm keeps division total by deciding that `1 / 0 == Infinity` (and `1 // 0 == 0`! 🙈), which is [arguably weirder](https://github.com/elm/core/issues/1072) than just failing loudly. And real-world input/output is _so_ full of failure cases (permission denied! connection reset!) that having a mechanism to propagate them without threading `Either` through every single function can be a perfectly reasonable design.

Still, when the failure is part of your _domain_ (the user typed an invalid age, the JSON did not parse), disciplined Haskellers reach for the same trick you know and love from Elm's `Result`: **make the error a value** by returning an `Either` explicitly:

```haskell
import Text.Read (readMaybe)

readAge :: IO (Either String Int)
readAge = do
  line <- getLine
  pure $ case readMaybe line of
    Just n  -> Right n
    Nothing -> Left ("Not a number: " <> line)
```

That `IO (Either String Int)` is morally _exactly_ Elm's `Task String Int`! The effect on the outside (`IO` / `Task`), the success-or-failure on the inside (`Either` / the two type params). ✨

## A REAL WORLD™️ example: fetching and parsing

Let's make this concrete with something you actually do every day: fetch some data and parse it. In Elm you would compose `Task`s and hand the result to the runtime as a `Cmd`:

```elm
import Http
import Task

fetchUser : String -> Task Http.Error User
fetchUser id =
    Http.task { {- ... -} }
        |> Task.andThen decodeUser

loadUser : String -> Cmd Msg
loadUser id =
    Task.attempt GotUser (fetchUser id)
```

In Haskell, the same shape, built from `IO` actions and finally plugged into `main`:

```haskell
fetchUser :: Text -> IO (Either Error User)
fetchUser userId = do
  response <- httpGet ("/users/" <> userId)   -- IO action
  pure (decodeUser response)                   -- pure parsing

main :: IO ()
main = do
  result <- fetchUser "kutyel"
  case result of
    Left err   -> putStrLn ("Something went wrong: " <> show err)
    Right user -> putStrLn ("Welcome, " <> userName user <> "!")
```

Notice the same healthy separation Elm encourages: the **effectful** part (`httpGet`) lives in `IO`, the **pure** part (`decodeUser`) is just a normal function `a -> Either Error User`. The `case` at the end is doing _by hand_ what `Task.attempt`'s `GotUser` message + your `update` branch do for you in Elm. Same discipline, different syntax! 🎯

## Why this design is the same good idea in both languages

Both Elm and Haskell are built on the same foundational insight:

> **Keep effects as inert data for as long as possible, and run them only at a single, well-defined boundary.**

In Elm, that boundary is the runtime, and the "inert data" is `Cmd` (built from `Task`). In Haskell, that boundary is `main`, and the inert data is `IO`. The payoff is identical in both: the vast majority of your program stays **pure**, **testable** and **easy to reason about**, because building an `IO`/`Task` value has _no observable effect_ — only the runtime running it does. 🧠

This is why you can do delightful things like keep a `[IO ()]` — a plain list of effects you have not run yet — and then run them all at once with our old friend from last post, `traverse_` (the `Foldable`/`Traversable` cousin that discards results):

```haskell
greetings :: [IO ()]
greetings = map (\name -> putStrLn ("Hello, " <> name)) ["Evan", "Simon", "Flavio"]

main :: IO ()
main = sequence_ greetings   -- runs them one after another, top to bottom
```

`sequence_` here is doing for `IO` _exactly_ what [`Task.sequence`](https://package.elm-lang.org/packages/elm/core/latest/Task#sequence) does for `Task`! It is `Traversable` and `Monad` all the way down — the same names, giving structure to the same ideas. 🥁

## Wrapping up

So, the next time someone tells you `IO` is some scary, magical, impure escape hatch, you can smile knowingly and say:

> "Oh, you mean a `Task` that the runtime runs at `main` instead of at `Cmd`? Yeah, I have been doing that in Elm for years." 😏

Let's recap the mental model:

- An `IO a` is a **description** of an effect, just like a `Task` — building it does nothing.
- It is a **`Monad`**, so you compose it with `>>=` / `do` notation, exactly like `Task.andThen`.
- It runs **only** when it becomes part of `main`, just like a `Task` runs only when the runtime gets it as a `Cmd`.
- Vanilla `IO` lacks Elm's typed error channel, but for the failures that belong to your domain, `IO (Either e a)` recovers the exact shape of `Task e a`.

Purity is not the absence of effects — it is the discipline of treating effects as **values**. Elm taught you that lesson with `Task` and `Cmd`; Haskell just calls it `IO`. ✨

## Acknowledgements

As always, the goal of this series is to show that the scary-sounding Haskell concepts are things you _already know_ from Elm — we are just giving them their proper names. 😉

Special thanks as always to [Christian Ekrem](https://github.com/cekrem) and to [Lucas David Traverso](https://github.com/ludat) for technical proofreading the draft version of this blogpost and adding their valuable feedback to it! 🙏🏻

Hope `IO` finally clicked for you and that you now see it for what it really is: your trusty old `Task`/`Cmd` duo wearing a Haskell hat! 🎩 If you found joy in this blogpost and would like me to continue the series, please consider [sponsoring my work](https://github.com/sponsors/kutyel), share it in your social networks and **follow me on [Twitter](https://twitter.com/FlavioCorpa)/[BlueSky!](https://bsky.app/profile/flaviocorpa.com) 🦋** 🙌🏻
