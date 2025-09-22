{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}

import Data.List (isPrefixOf, isSuffixOf)
import Data.Maybe (fromMaybe)
import Data.Text qualified as T
import Data.Text.Slugger qualified as Slugger
import Hakyll
import System.FilePath (takeFileName)
import Text.HTML.TagSoup (Tag (..))
import Text.Pandoc
  ( Extension (..),
    Extensions,
    ReaderOptions,
    WriterOptions (writerHighlightStyle),
    extensionsFromList,
    githubMarkdownExtensions,
    readerExtensions,
    writerExtensions,
  )
import Text.Pandoc.Highlighting (Style, breezeDark, styleToCss)

--------------------------------------------------------------------------------
-- PERSONALIZATION

mySiteName :: String
mySiteName = "flaviocorpa.com"

mySiteRoot :: String
mySiteRoot = "https://flaviocorpa.com"

myFeedTitle :: String
myFeedTitle = "Flavio Corpa's feed"

myFeedDescription :: String
myFeedDescription = "Feed for Flavio's website"

myFeedAuthorName :: String
myFeedAuthorName = "Flavio Corpa"

myFeedAuthorEmail :: String
myFeedAuthorEmail = "flaviocorpa@gmail.com"

myFeedRoot :: String
myFeedRoot = mySiteRoot

blogSnapshot :: String
blogSnapshot = "content"

--------------------------------------------------------------------------------
-- CONFIG

-- Default configuration: https://github.com/jaspervdj/hakyll/blob/cd74877d41f41c4fba27768f84255e797748a31a/lib/Hakyll/Core/Configuration.hs#L101-L125
config :: Configuration
config =
  defaultConfiguration
    { destinationDirectory = "dist",
      ignoreFile = ignoreFile',
      previewHost = "127.0.0.1",
      previewPort = 8000,
      providerDirectory = "src",
      storeDirectory = "ssg/_cache",
      tmpDirectory = "ssg/_tmp"
    }
  where
    ignoreFile' path
      | ".DS_Store" == fileName = True
      | "." `isPrefixOf` fileName = False
      | "#" `isPrefixOf` fileName = True
      | "~" `isSuffixOf` fileName = True
      | ".swp" `isSuffixOf` fileName = True
      | otherwise = False
      where
        fileName = takeFileName path

--------------------------------------------------------------------------------
-- BUILD

main :: IO ()
main = hakyllWith config $ do
  mapM_
    ( \f -> match f $ do
        route idRoute
        compile copyFileCompiler
    )
    [ "CNAME",
      "favicon.ico",
      "robots.txt",
      "_config.yml",
      "images/*",
      "js/*",
      "fonts/*"
    ]

  match "css/*" $ do
    route idRoute
    compile compressCssCompiler

  tags <- buildTags "posts/*" (fromCapture "tags/*.html")

  match "posts/*" $ do
    route $ metadataRoute titleRoute
    compile $
      pandocCompilerCustom
        >>= loadAndApplyTemplate "templates/post.html" (postCtxWithTags tags)
        >>= saveSnapshot blogSnapshot
        >>= loadAndApplyTemplate "templates/default.html" (postCtxWithTags tags)

  tagsRules tags $ \tag tagPattern -> do
    let title = "Posts tagged \"" ++ tag ++ "\""
    route idRoute
    compile $ do
      posts <- recentFirst =<< loadAll tagPattern
      let ctx =
            constField "title" title
              <> listField "posts" (postCtxWithTags tags) (pure posts)
              <> defaultContext

      makeItem ""
        >>= loadAndApplyTemplate "templates/tag.html" ctx
        >>= loadAndApplyTemplate "templates/default.html" ctx
        >>= relativizeUrls

  match "index.html" $ do
    route idRoute
    compile $ do
      posts <- recentFirst =<< loadAll "posts/*"

      let indexCtx =
            listField "posts" postCtx (pure posts)
              <> constField "root" mySiteRoot
              <> constField "siteName" mySiteName
              <> defaultContext

      getResourceBody
        >>= applyAsTemplate indexCtx
        >>= loadAndApplyTemplate "templates/default.html" indexCtx

  match "templates/*" $
    compile templateBodyCompiler

  create ["sitemap.xml"] $ do
    route idRoute
    compile $ do
      posts <- recentFirst =<< loadAll "posts/*"

      let pages = posts
          sitemapCtx =
            constField "root" mySiteRoot
              <> constField "siteName" mySiteName
              <> listField "pages" postCtx (pure pages)

      makeItem ("" :: String)
        >>= loadAndApplyTemplate "templates/sitemap.xml" sitemapCtx

  create ["rss.xml"] $ do
    route idRoute
    compile (feedCompiler renderRss)

  create ["atom.xml"] $ do
    route idRoute
    compile (feedCompiler renderAtom)

  create ["css/code.css"] $ do
    route idRoute
    compile (makeStyle pandocHighlightStyle)

--------------------------------------------------------------------------------
-- COMPILER HELPERS

makeStyle :: Style -> Compiler (Item String)
makeStyle =
  makeItem . compressCss . styleToCss

--------------------------------------------------------------------------------
-- CONTEXT

feedCtx :: Context String
feedCtx =
  titleCtx
    <> postCtx
    <> bodyField "description"

postCtx :: Context String
postCtx =
  constField "root" mySiteRoot
    <> constField "siteName" mySiteName
    <> dateField "date" "%d/%m/%Y"
    <> readingTimeField "readingtime"
    <> defaultContext

postCtxWithTags :: Tags -> Context String
postCtxWithTags tags = tagsField "tags" tags `mappend` postCtx

titleCtx :: Context String
titleCtx =
  field "title" updatedTitle

readingTimeField :: String -> Context String
readingTimeField key =
  field key calculate
  where
    calculate :: Item String -> Compiler String
    calculate = pure . withTagList acc . itemBody
    acc ts = [TagText . show $ time ts]
    -- M. Brysbaert, Journal of Memory and Language (2009) vol 109. DOI: 10.1016/j.jml.2019.104047
    time ts = foldr count 0 ts `div` 238
    count (TagText s) n = n + length (words s)
    count _ n = n

--------------------------------------------------------------------------------
-- TITLE HELPERS

replaceAmp :: String -> String
replaceAmp =
  replaceAll "&" (const "&amp;")

replaceTitleAmp :: Metadata -> String
replaceTitleAmp =
  replaceAmp . safeTitle

safeTitle :: Metadata -> String
safeTitle =
  fromMaybe "no title" . lookupString "title"

updatedTitle :: Item a -> Compiler String
updatedTitle =
  fmap replaceTitleAmp . getMetadata . itemIdentifier

--------------------------------------------------------------------------------
-- PANDOC

pandocCompilerCustom :: Compiler (Item String)
pandocCompilerCustom =
  pandocCompilerWith pandocReaderOpts pandocWriterOpts

pandocExtensionsCustom :: Extensions
pandocExtensionsCustom =
  githubMarkdownExtensions
    <> extensionsFromList
      [ Ext_fenced_code_attributes,
        Ext_gfm_auto_identifiers,
        Ext_implicit_header_references,
        Ext_smart,
        Ext_footnotes
      ]

pandocReaderOpts :: ReaderOptions
pandocReaderOpts =
  defaultHakyllReaderOptions
    { readerExtensions = pandocExtensionsCustom
    }

pandocWriterOpts :: WriterOptions
pandocWriterOpts =
  defaultHakyllWriterOptions
    { writerExtensions = pandocExtensionsCustom,
      writerHighlightStyle = Just pandocHighlightStyle
    }

pandocHighlightStyle :: Style
pandocHighlightStyle =
  breezeDark -- https://hackage.haskell.org/package/pandoc/docs/Text-Pandoc-Highlighting.html

--------------------------------------------------------------------------------
-- FEEDS

type FeedRenderer =
  FeedConfiguration ->
  Context String ->
  [Item String] ->
  Compiler (Item String)

feedCompiler :: FeedRenderer -> Compiler (Item String)
feedCompiler renderer =
  renderer feedConfiguration feedCtx
    =<< recentFirst
    =<< loadAllSnapshots "posts/*" blogSnapshot

feedConfiguration :: FeedConfiguration
feedConfiguration =
  FeedConfiguration
    { feedTitle = myFeedTitle,
      feedDescription = myFeedDescription,
      feedAuthorName = myFeedAuthorName,
      feedAuthorEmail = myFeedAuthorEmail,
      feedRoot = myFeedRoot
    }

--------------------------------------------------------------------------------
-- CUSTOM ROUTE

fileNameFromTitle :: Metadata -> FilePath
fileNameFromTitle =
  T.unpack . (`T.append` ".html") . Slugger.toSlug . T.pack . safeTitle

titleRoute :: Metadata -> Routes
titleRoute =
  constRoute . fileNameFromTitle
