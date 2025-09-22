---
author: 'Flavio Corpa'
authorTwitter: '@FlavioCorpa'
desc: 'A series of blog posts for explaining Haskell to Elm developers interested to learn the language that powers the compiler for their favourite language!'
image: ./images/haskell-elm.png
keywords: 'haskell,elm,functional,programming'
tags: haskell, elm, fp
lang: 'en'
title: 'Haskell for Elm developers: giving names to stuff (Part 4 - Parser combinators)'
date: '2024-03-28T17:00:00Z'
updated: '03/04/2024 11:15'
---

<img src="./images/haskell-elm.svg" alt="logo" width="300px">

> ⚠️ DISCLAIMER ⚠️
> This is by no means a full in-depth explanation of parser combinators, as there are many papers on the subject. This post assumes you are somewhat familiar with `elm/parser`, and thus you are equipped with the tools you need to get familiar with parser combinators in Haskell!

Hey! Long time no see, I've finally gathered my inner strength to be brave enough to write this post, yay! 🎉

Even though this might not be a fully complete explanation of parser combinators, as said in the above disclaimer, you might want to have a refresher on what `Applicative` functors were:

- [Haskell for Elm developers: giving names to stuff (Part 2 - Applicative Functors)](https://flaviocorpa.com/haskell-for-elm-developers-giving-names-to-stuff-part-2-applicative-functors.html)

This will become relevant to this post, as you will soon notice, but first of all, another brief reminder before we get onto the good stuff.

## What is a Parser?

Basically speaking, a _parser_ is a function that takes some text input and returns some _structure_ (normally an Abstract Syntax Tree, aka: AST) as an output. A _parser combinator_ is, thus, a higher-order function that takes parsers as input and returns a new parser as output.

As this definition is better explained with examples, let's have a look at the simplest possible definition of a parser in Haskell:

```haskell
type Parser a = String -> Maybe (a, String)
```

Although no _production ready_ parser combinators library would be as naive, it serves well our purpose to understand the simple essence of it:

1. Await a `String` value.
2. Produce a result that may or not succeed (that's why it returns a `Maybe`, although with this minimalistic design there is no possible way to know why the parser failed).
3. Return a tuple of the value you want to parse and whatever's left of the string that you did not consume to produce a value of type `a`.

Some people like to think about parsers as somewhat simple machines that need a **cursor**, and that parse left to right the input and produce results as they traverse the text input, but this illustration might not be so accurate in certain implementations.

For the Haskell curious (which I guess you are since you are reading this post), notice how the above definition of a `Parser` looks suspiciously familiar to the `State` monad:

```haskell
newtype State s a =
  State { runState :: s -> (a, s) }
```

We could maybe dedicate a following blogpost on its own just to the `State` monad, but this is out of the scope of this post. Suffice to say that during the research for writing these lines I found that there's actually a quite nice [Elm package](https://package.elm-lang.org/packages/folkertdev/elm-state/latest/State) that implements the `State` monad! 🤯

## How are parsers defined in Elm?

Now that we are getting a bit more familiar with the way a parser is constructed, let's have a look at the _de facto_ only parser library that exists for Elm, `elm/parser` and see how the `Parser` type is defined there:

```elm
-- Parser.Advanced.elm

type Parser context problem value =
  Parser (State context -> PStep context problem value)


type PStep context problem value
  = Good Bool value (State context)
  | Bad Bool (Bag context problem)
```

If you squint your eyes hard enough, you can see the resemblance. For example, if we strip the `context` and `problem` type variables, which are used to give more information to the user about why a certain parser failed, and we simplify the `State` type that the author used here (not the `State` monad, do not be confused!), it will look like this:

```elm
type Parser value =
  Parser (String -> PStep value)


type PStep value
  = Good value String
  | Bad String
```

This looks a bit closer to the initial Haskell definition we looked at, and you can therefore now notice that `PStep` is just a sophisticated version of `Maybe` that will give you more information in case of failure.

## The hidden typeclass

The hidden secret of parser combinators, in my humble opinion, lies in the simple `oneOf` function:

```elm
oneOf : List (Parser a) -> Parser a
```

When you are parsing stuff, sometimes you are parsing something AND something (that's when the `Applicative` typeclass kicks in), but usually you also need to parse something OR something else. This is where the `oneOf` function comes in handy, for example in the `elm/json` library you have the following decoding function:

```elm
maybe : Decoder a -> Decoder (Maybe a)
maybe decoder =
  oneOf
    [ map Just decoder
    , succeed Nothing
    ]
```

This simple decoder allows us to declare that you might parse something present in your input (or not), and appropriately represent that into a `Maybe` type. But, how would such combinator look in Haskell? 🤔

```haskell
optional :: Alternative f => f a -> f (Maybe a)
optional d = Just <$> d <|> pure Nothing
```

As you can see, the `maybe` decoder function is called `optional` in Haskell, but the interesting stuff is the typeclass constraint: `Alternative f =>`. This is the magical final piece of the puzzle we need to understand to _get_ parser combinators!

Let's have a look at simplified version of how the `Alternative` typeclass is defined in Haskell:

```haskell
class Applicative f => Alternative f where
  -- The identity of '<|>'
  empty :: f a
  -- An associative binary operation
  (<|>) :: f a -> f a -> f a

  -- One or more.
  some :: f a -> f [a]
  -- Zero or more.
  many :: f a -> f [a]
```

Since `some` and `many` are defined in terms of `<|>`, we can notice quickly that the relevant part is the new `<|>` operator, which does not have a name but by using the pipe I think it might convey the idea of a lifted OR (`|`) operator.

So again, where in Elm we can express that we can parse one thing or another as items in a list given to `oneOf`, in Haskell there is the infix binary operator `<|>` to define all the possible things we want to parse.

If you also noticed, `Alternative` requires an `Applicative` instance to also be present! So, in every possible Haskell implementation of `Parser`, mandatorily you are going to have this code blow:

```haskell
instance Applicative Parser where
  -- ...

instance Alternative Parser where
  -- ...
```

This is what makes parser combinators work: an `Applicative` instance, and an `Alternative` one, that is it! ✨

## Interesting _aha!_ moment

While scanning though the `elm/parser` library, you will find this code:

```elm
-- INFIX OPERATORS


infix left 5 (|=) = keeper
infix left 6 (|.) = ignorer

{-| Just like the [`(|=)`](Parser#|=) from the `Parser` module.
-}
keeper : Parser c x (a -> b) -> Parser c x a -> Parser c x b
keeper parseFunc parseArg =
  map2 (<|) parseFunc parseArg


{-| Just like the [`(|.)`](Parser#|.) from the `Parser` module.
-}
ignorer : Parser c x keep -> Parser c x ignore -> Parser c x keep
ignorer keepParser ignoreParser =
  map2 always keepParser ignoreParser
```

Which is funny, because we CANNOT define infix operators in Elm, but Evan can 😜. Besides that, what is actually interesting is that, for conveniency, it is better to have infix operators for the `keeper` and `ignorer` (or the `eater` operator, as Tereza Sokol called it in [her nice talk](https://youtu.be/M9ulswr1z0E?si=9LyCZ9lX298x2GYQ) 🤣) functions that allows us to consume or discard input, because it leads to somewhat more readable code™️.

If we want to find those functions in Haskell, let me confess something right now: I did not show you in the previous `Applicative` post **all** there is to it regarding applicative functors, you have been lied to! 😈

Here is the complete definition of the `Applicative` typeclass:

```haskell
class (Functor f) => Applicative f where
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

  -- | Sequence actions, discarding the value of the first argument.
  --
  -- ==== __Examples__
  -- If used in conjunction with the Applicative instance for 'Maybe',
  -- you can chain Maybe computations, with a possible "early return"
  -- in case of 'Nothing'.
  --
  -- >>> Just 2 *> Just 3
  -- Just 3
  --
  -- >>> Nothing *> Just 3
  -- Nothing
  (*>) :: f a -> f b -> f b
  a1 *> a2 = (id <$ a1) <*> a2

  -- | Sequence actions, discarding the value of the second argument.
  (<*) :: f a -> f b -> f a
  (<*) = liftA2 const
```

In case you did not notice, lets have the type signatures side by side now:

```haskell
(<*>) :: f (a -> b)          -> f a          -> f b
(|=)  : Parser c x (a -> b)  -> Parser c x a -> Parser c x b
```

and...

```haskell
(<*) :: f keep         -> f ignore          -> f keep
(|.) : Parser c x keep -> Parser c x ignore -> Parser c x keep
```

So this means that the `<*` and the `<*>` operators are, respectively, the `ignorer` and `keeper` functions from `elm/parser`!! 🤯🤯🤯

What about the `*>` operator? Well, as you know, in Haskell we have this massive operator overflow, so it is exactly the same as `<*` but it let's us ignore the argument to the _left_ of the operator, as we will now see in a REAL WORLD™️ parser code sample. 😉

## A real world™️ Haskell parser example

To make sure we actually learned something about parser combinators in this post, let's have a look at a portion of my [`language-avro`](https://github.com/higherkindness/avro-parser-haskell) Haskell library:

```haskell
-- | Parses a single import into the 'ImportType' structure.
parseImport :: MonadParsec Char T.Text m => m ImportType
parseImport =
  reserved "import"
    *> ( (impHelper IdlImport "idl" <?> "Import of type IDL")
           <|> (impHelper ProtocolImport "protocol" <?> "Import of type protocol")
           <|> (impHelper SchemaImport "schema" <?> "Import of type schema")
       )
  where
    impHelper :: MonadParsec Char T.Text m => (T.Text -> a) -> T.Text -> m a
    impHelper ct t = ct <$> (reserved t *> strlit <* symbol ";")
```

> If you are curious regarding how such a parser would look with other libraries (like `trifecta`), you can have a look at [this code](https://github.com/kutyel/haskell-kata/commit/bde30daf28718eda7f35b22325a07ce29f8e9882), which is surprisingly similar to Elm!

Before you freak out, let me explain to you what this piece of code is trying to parse: in the [Avro IDL language](https://avro.apache.org/docs/1.11.1/idl-language/#imports) (which is used for example, in [Kafka](https://kafka.apache.org/)), you can define imports of 3 different types:

```protobuf
import idl "foo.avdl";
import protocol "foo.avpr";
import schema "foo.avsc";
```

To represent this in Haskell, first we need a data type that we want our parser to return:

```haskell
-- | Type for the possible import types in 'Protocol'.
data ImportType
  = IdlImport T.Text
  | ProtocolImport T.Text
  | SchemaImport T.Text
  deriving (Eq, Show, Ord)
```

And now we can proceed with the parsing stuff, you will notice a few interesting things

1. There is a strange `reserved` combinator, which is a user defined combinator that is pretty clever and has the notion of comments/whitespace.
2. Similarly, `strlit` is also user defined and it helps us to parse string literals.
3. What the hell is `<?>` ?? Another crazy operator?? Well, do not worry, it is just to give proper error messages when the parser get's stuck, the Elm equivalent would be the `problem : String -> Parser a` function. 😉
4. What is that scary `MonadParsec Char T.Text m => m` typeclass constrain? Well, I would gladly read that as just `Parser` in the example we were giving before, but since in my package I used the [`megaparsec`](https://hackage.haskell.org/package/megaparsec) library, I did not want to lie to you again and show you the real type of the parser (more on `megaparsec` later).

Here is a similar parser, written with `elm/parser` as a reference!

```elm
import Parser
    exposing
        ( (|.)
        , (|=)
        , Parser
        , chompIf
        , chompWhile
        , getChompedString
        , oneOf
        , spaces
        , succeed
        , symbol
        )


type Import
    = Idl String
    | Protocol String
    | Schema String


parser : Parser Import
parser =
    let
        importHelper :
            (String -> Import)
            -> String
            -> Parser Import
        importHelper ct t =
            succeed ct
                |. symbol t
                |. spaces
                |= strlit
                |. symbol ";"
    in
    succeed identity
        |. symbol "import"
        |. spaces
        |= oneOf
            [ importHelper Idl "idl"
            , importHelper Protocol "protocol"
            , importHelper Schema "schema"
            ]


strlit : Parser String
strlit =
    getChompedString <|
        succeed ()
            |. chompIf (\c -> c == '"')
            |. chompWhile Char.isLower
            |. chompIf (\c -> c == '.')
            |. chompWhile Char.isLower
            |. chompIf (\c -> c == '"')


output =
    Parser.run parser "import protocol \"foo.avpr\";"
    -- > Ok (Protocol "\"foo.avpr\"")
```

As you can see, the code is fairly similar, we only used the `oneOf` instead of the `<|>` operator, and the only complicated thing in Elm was figuring out how our `strlit` combinator had to look like. (Obviously this implementation is not perfect, but it is good enough for educational purposes).

If you were able to understand the above Haskell code, congratulations, you know parser combinators already! 🎉🎉🎉

## The state of parsers in the Haskell ecosystem

As opposed to Elm, where there is only one choice (`elm/parser`), the Haskell ecosystem is much more rich and diverse, each one with their different tradeoffs. Here is an _incomplete list_ of parser combinator libraries I'm aware of:

- Parsec
- Trifecta
- Attoparsec
- Megaparsec
- Earley
- ... (many, many more!!)

The only one I've used in production and am a bit more familiar with is `megaparsec`, and I learned a lot regarding how to use it from [Mark Karpov excellent's blogpost](https://markkarpov.com/tutorial/megaparsec.html). I really recommend it since it is quite performant and it has some really nice and smart combinators that will spare you a ton of work.

## Acknowledgements

Special thanks to [@serras](https://twitter.com/trupill) for technical proofreading this post again. 🙏🏻

Hope `Parser` combinators finally clicked for you ✨ (if they had not already) and you learned something new. Ah! And in case you did not notice...

> JSON Decoders are actually parser combinators! 🤯🤯🤯

So, as always, if you were doing JSON Decoders you were using parser combinators all along without noticing it! 😁

If you enjoyed this post and would like me to continue the series, please consider [sponsoring my work](https://github.com/sponsors/kutyel), share it in your social networks and **follow me on [Twitter](https://twitter.com/FlavioCorpa)!** 🙌🏻
