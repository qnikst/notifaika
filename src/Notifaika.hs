{-
    Discourse-to-Gitter reposts notification
    from Discourse forums to Gitter chats.
    Copyright (C) 2015 Yuriy Syrovetskiy

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
-}

{-# LANGUAGE NamedFieldPuns #-}

module Notifaika
    ( Config(..)
    , EventSource(..)
    , Gitter(..)
    , Room(..)
    , runNotifaika
    ) where

import qualified  Notifaika.Cache.Persist as Cache
import            Notifaika.Config
import            Notifaika.Core
import            Notifaika.EventSource
import            Notifaika.Gitter        as Gitter
import            Notifaika.Gitter.Types

import Control.Monad.Reader
import Data.String

runNotifaika :: Config -> IO ()
runNotifaika config@Config{config_cacheFile, config_gitter} = do
    Cache.runPersistCacheT (fromString config_cacheFile) .
        runGitterT config_gitter $
            runReaderT repostUpdates config