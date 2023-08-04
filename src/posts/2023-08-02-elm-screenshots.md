---
author: 'Flavio Corpa'
authorTwitter: '@FlavioCorpa'
desc: 'How I implemented recently screenshots for a webpage using the latest version of Elm!'
image: ./images/elm.jpg
keywords: 'web,elm,functional,programming,screenshots'
lang: 'en'
title: 'Taking Screenshots with Elm 0.19'
date: '2023-08-04T17:22:00Z'
---

Recently I had to implement frontend screenshots in an Elm app, and all the blog posts I could find were for outdated versions of Elm (< 0.19)🌳, so here is how I managed to do it! Hopefully it helps someone else. 🤞🏻

My only 2 constraints were the following:

- The endpoint I was using to store the screenshots only accepted mime type `image/jpeg`.
- I need to take a _sequence_ of screenshots and focus on an individual bit of the UI, while hiding (in this case changing the HTML content to `REDACTED`) some parts of it.

Obviously the code shown here can be simplified to fit your needs too but I wanted to present you something taken from the real world. 😉

## Going outside of Elm

As you probably figured by now, this is not possible to do only in Elm, so we need to resort to [Ports](https://guide.elm-lang.org/interop/ports.html) and a JavaScript library.

After an incredible waste of time trying out different JS libs to accomplish this, I had to settle with [`html2canvas`](https://github.com/niklasvh/html2canvas), as apparently this is the only working library that produces images out of the DOM, not HTML docs or any other file format. 🤷🏼‍♂️

Now let's get into the code part, we need at least 2 ports: one we will use to tell JS we want to take some screenshots, and another to receive back the response from outside of Elm.

```elm
-- App.elm

port takeScreenshots : List DocumentId -> Cmd msg


port receiveScreenshotData : (List ImagePortData -> msg) -> Sub msg
```

The only important thing to highlight from the ports is that I had to construct a special type `ImagePortData` with the things I wanted to get back from JavaScript, here you have it defined for completion:

```elm
-- Data.elm

type alias ImagePortData =
    { image : String
    , time : String
    , documentId : DocumentId
    }
```

I wanted the timestamp from JS as an ISO String (this can also be done from the Elm side but anyway 🙄), the `documentId` was needed to hide/show parts of the UI I did not want to see in the screenshot and the `image` was the encoded `base64` string that JS was going to send me from the library.

After that I just needed to add a couple of messages and a subscription, following The Elm Architecture principles:

```elm
-- App.elm

type Msg
    = NoOp
    -- .. bunch of other msgs
    | TakeScreenshots (List DocumentId)
    | ScreenshotsTaken (List ImagePortData)
    | ScreenshotsSaved (Result Http.Error ())


-- ...

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ -- ... other subs
        , receiveScreenshotData ScreenshotsTaken
        ]
```

You can probably use less `Msg`s, but in my case I used `TakeScreenshots` to ask JavaScript from Elm to take the screenshots, `ScreenshotsTaken` to receive the screenshot data back to Elm world and send them to the "save screenshots" endpoint, and finally a `ScreenshotsSaved` to do something after all this process is finished.

I think to show the actual pattern match on `Msg` in the `update` function is not really useful as it entirely depends on what you want your Elm app to do, so it is skipped for brevity.

The only bit of wiring that I needed to make is to modify the known `Config` (many real world Elm apps use this pattern, although you might not need it) type to accept a `msg`:

```elm
-- Config.elm

type alias Config msg =
    { host : String
    -- other unrelated stuff
    , takeScreenshots : List DocumentId -> msg
    }
```

Another relevant bit of code was the actual call to the save screenshots endpoint, which you can have a look at here:

```elm
-- Data.elm

saveScreenshots : Config msg -> List ImagePortData -> (Result Http.Error () -> msg) -> Cmd msg
saveScreenshots { host, token } listImgs resultMsg =
    Http.putWithHeaders
        { url = Url.crossOrigin host [ "store", "screenshots", "endpoint" ] []
        , headers = [ Http.tokenHeader token ]
        , jsonBody =
            listImgs
                |> Encode.list
                    (\{ image, time, documentId } ->
                        Encode.object
                            [ ( "document_id", Encode.string documentId )
                            , ( "screenshot"
                              , Encode.object
                                    [ ( "image", Encode.string image )
                                    , ( "time", Encode.string time )
                                    ]
                              )
                            ]
                    )
        , expect = Http.expectWhatever resultMsg
        }
```

Do not focus too much on `Http.putWithHeaders`, as this is just a custom wrapper around the usual `Http.put` module stuff just making my life easier.

I have to mention that, since [Elm does not have a Blob type](https://github.com/elm/http/issues/56#issuecomment-462489112), we can just use `String` to receive the encoded `base64` image data, and it will just work. 🪄

## Ok but where is the JavaScript? 🤔

Obviously I have just shown for now the Elm part of the code relevant to the screenshots, but the actual magic is performed in the JS side to make all of this work, here is the code:

```js
import html2canvas from 'html2canvas'

app.ports.takeScreenshots.subscribe((documentIds) => {
  const promisedScreenshots = documentIds.map(async (documentId) => {
    // take the screenshot
    const canvas = await html2canvas(document.body, {
      useCORS: true,
      allowTaint: true,
      foreignObjectRendering: true,
      // change all other documents to REDACTED
      onclone: (doc) =>
        doc
          .querySelectorAll(`[data-document-id]:not([data-document-id="${documentId}"])`)
          .forEach((node) => node.childNodes.forEach((c) => (c.textContent = 'REDACTED'))),
    })
    const image = canvas.toDataURL('image/jpeg')
    const time = new Date().toISOString()
    return { image, time, documentId }
  })

  // send it back to Elm
  Promise.all(promisedScreenshots).then(app.ports.receiveScreenshotData.send)
})
```

There are a few things to say about this snippet:

1. As I mentioned, I needed to produce a **list** of screenshots, so I used the given list of ids sent from Elm to map them into a list of screenshots in the line with `documentIds.map(async (documentId) => ...`. This produces a list of JS [Promises](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise), since the `html2canvas` call returns a Promise, so I needed to wait for all of them to resolve before sending the data back to Elm (this can be easily done with `Promise.all`, even using `async/await` I was not spared of having to do this unfortunately 😭). I did not get this part right at the beginning and received an obscure Elm compiler error message, but I can promise this is one of the very few [well know issues](https://github.com/elm/core/issues/1043) were what is wrong is not completely obvious. 😅

2. If you notice the actual call to `html2canvas`, you will notice it takes a second argument which is a JS object with some settings (I mostly only used `useCORS`, `allowTaint` and `foreignObjectRendering`), you can probably skip those but I noticed that this tweaks actually **improved pretty much the overall quality of the screenshots**, so I had to use them.

3. Probably the most important setting I had to use is the `onclone` function, which is a callback you can use to manipulate the DOM _before_ taking the actual screenshot, pretty handy for what I needed to do!

4. If you have a closer look on my `querySelectorAll` line, you will notice a neat trick shamelessly [copied from StackOverflow](https://stackoverflow.com/questions/25287229/cant-find-a-not-equal-css-attribute-selector/68520810#68520810) (yes I still use that from time to time, sorry chatGPT 🤣), that allowed me to perform some operations on the REST of the things I did not want to appear in the screenshot!

5. Finally, if you pay attention to this bit: `canvas.toDataURL('image/jpeg')` you will notice that I am [manually setting the image encoding](https://stackoverflow.com/questions/15685698/getting-binary-base64-data-from-html5-canvas-readasbinarystring/15685877#15685877) to the one my backend supported, the default for the [Canvas HTML API](https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API) is `image/png` by the way!

---

Nothing else to say, this all worked out in the end and I suffered so much I just wanted to skip some of my it to the next generation of Elm developers! 😘

If you enjoying reading this, please share it in your social networks and **follow me on [Twitter](https://twitter.com/FlavioCorpa)!** 🙌🏻

Happy coding! 😎🖖🏻
