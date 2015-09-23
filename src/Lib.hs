{-# LANGUAGE ConstraintKinds #-}

module Lib where

-- component
import Cache
import Config
import Discourse
import Gitter
import Gitter.Monad
-- global
import            Control.Monad.Logger
import            Control.Monad.Reader
import            Data.Monoid
import            Data.Text ( Text )
import qualified  Data.Text as Text

detectNewTopics :: [Topic] -> [Topic] -> [Topic]
detectNewTopics []   =
    return . maximum
detectNewTopics olds =
    filter $ \topic ->
        any (\old -> topic_id old /= topic_id topic && old <= topic) olds

type MonadRepost m =  ( MonadCache [Topic] m
                      , MonadDiscourse m
                      , MonadGitter m
                      , MonadLogger m
                      , MonadReader Config m
                      )

repostUpdates :: MonadRepost m => m ()
repostUpdates = do
    latestTopics <- Discourse.getLatest
    cachedTopics <- loadDef []
    let newTopics = detectNewTopics cachedTopics latestTopics
    $logDebug ("newTopics = " <> showText newTopics)
    room <- asks (gitter_room . config_gitter)
    let message = "new topic!"
    withRoom room (sendChatMessage message)
    save latestTopics

showText :: Show a => a -> Text
showText = Text.pack . show
