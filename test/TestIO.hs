{-# LANGUAGE  FlexibleInstances
            , GeneralizedNewtypeDeriving
            , MultiParamTypeClasses
  #-}

module TestIO (Effect(..), TestIO, TestIOResult(..), execTestIO) where

-- package
import Cache
import Config
import Discourse
import Gitter.Monad
import Gitter.Types
-- general
import Control.Monad.RWS
import Data.Aeson
import Data.ByteString.Lazy as ByteString

data Effect = CacheRead
            | CacheWrite
            | DiscourseGet String
            | GitterAction ResourcePath
    deriving (Eq, Show)

newtype TestIO a = TestIO (RWST Config [Effect] [Topic] IO a)
    deriving (Applicative, Functor, Monad, MonadReader Config)

instance MonadCache [Topic] TestIO where
    loadDef def = TestIO $ do
        tell [CacheRead]
        loadDef def
    save val = TestIO $ do
        tell [CacheWrite]
        save val

instance MonadDiscourse TestIO where
    getLatest = TestIO $ do
        tell [DiscourseGet "/latest.json"]
        liftIO (decodeFile "test/data/discourse/latest.json")

instance MonadGitter TestIO where
    runGitterAction path body = do
        TestIO $ tell [GitterAction path]
        return (mockGitter path body)

decodeFile :: FromJSON a => FilePath -> IO a
decodeFile filepath = do
    bytes <- ByteString.readFile filepath
    let decodeResult = eitherDecode bytes
    case decodeResult of
        Left decodeError ->
            error ("Cannot decode file \"" <> filepath <> "\": " <> decodeError)
        Right value ->
            return value

data TestIOResult = TestIOResult  { testIOResult_effects  :: [Effect]
                                  , testIOResult_cache    :: [Topic]
                                  }

execTestIO :: TestIO () -> IO TestIOResult
execTestIO testAction = do
    let cache = []
        TestIO rwsAction = testAction
        ioAction = execRWST rwsAction testConfig cache
    (testIOResult_cache, testIOResult_effects) <- ioAction
    return TestIOResult{..}

testConfig :: Config
testConfig =
    Config  { config_cacheFile = "testcache"
            , config_discourseBaseUrl = "test://discouse.example.com/"
            , config_gitter =
                  Gitter  { gitter_baseUrl = "test://api.gitter.example.com/v1"
                          , gitter_room = ONETOONE "cblp"
                          , gitter_tokenFile = "/dev/null"
                          }
            }

mockGitter :: ResourcePath -> Value -> Value
mockGitter url req =
    let err = error ("don't know how to mock " <> show url <> " " <> show req)
    in case url of
        ["rooms"] -> case req of
            Object [("uri", "cblp")] -> Object [("id", "exampleroomid")]
            _ -> err
        ["room", "exampleroomid", "chatMessages"] ->
            case req of
                "{\"text\":\"new topic!\"}" -> "{}"
                _ -> err
        _ -> error ("don't know how to mock " <> show url)
