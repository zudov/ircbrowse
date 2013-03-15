{-# LANGUAGE ViewPatterns #-}
-- | Main entry point.

module Main where

import Ircbrowse.Config
import Ircbrowse.Controllers.Cache
import Ircbrowse.Model.Data
import Ircbrowse.Model.Social
import Ircbrowse.Model.Migrations
import Ircbrowse.Server
import Ircbrowse.Types
import Ircbrowse.ImportTunes
import Ircbrowse.Tunes

import Data.Maybe
import Database.PostgreSQL.Base   (newPool)
import Snap.App
import Snap.App.Migrate
import System.Environment

-- | Main entry point.
main :: IO ()
main = do
  cpath:action <- getArgs
  config <- getConfig cpath
  pool <- newPool (configPostgres config)
  let db = runDB () config pool
  case foldr const "" action of
    "create-version" -> do
      db $ migrate True versions
    "generate-data" -> do
      db $ generateData
      clearCache config
    "import-yesterday" -> do
      importYesterday config pool
      clearCache config
    "generate-social-graph" -> do
      generateGraph config pool
    "import-dir" -> do
      case action of
        [_,name] -> do
          batchImport config (fromMaybe (error "Can't parse channel name.") (parseChan name)) pool
          clearCache config
        _ -> error "Bad arguments to import-dir."
    "update-order-index" -> do
      case action of
        [_,name] -> do
          updateChannelIndex config pool
                                    (fromMaybe (error "Can't parse channel name.") (parseChan name))
          clearCache config
        _ -> error "Bad arguments to update-order-index."
    _ -> do
      db $ migrate False versions
      clearCache config
      runServer config pool
