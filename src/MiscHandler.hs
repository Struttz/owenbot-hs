{-# LANGUAGE OverloadedStrings #-}

module MiscHandler (isOwoifiable, handleOwoify,
                    isNietzsche, handleNietzsche,
                    isThatcher, handleThatcher,
                    isDadJoke, handleDadJoke,
                    isFortune, handleFortune,
                    isADA, handleADA) where

import qualified Discord.Requests as R
import Discord.Types
import Discord

import qualified Data.Maybe as M
import qualified Data.Text.IO as TIO
import qualified Data.Text as T
import UnliftIO (liftIO)
import Text.Regex.TDFA
import System.IO as S (readFile)

import Data.Char ( isAlpha )

import ADAPriceFetcher ( fetchADADetails )

import Utils (sendMessageChan, sendMessageChanEmbed, sendFileChan, pingAuthorOf, linkChannel, getMessageLink, (=~=))
import Owoifier (owoify)

import qualified System.Exit as SE
import qualified System.Process as SP

isOwoifiable :: T.Text -> Bool
isOwoifiable = (=~= ("[lLrR]|[nNmM][oO]" :: T.Text))

handleOwoify :: Message -> DiscordHandler (Either RestCallErrorCode Message)
handleOwoify m = sendMessageChan (messageChannel m) (pingAuthorOf m <> ": " <> owoify (messageText m))

isNietzsche :: T.Text -> Bool
isNietzsche = (=~= ("[gG]od *[iI]s *[dD]ead" :: T.Text))

handleNietzsche :: Message -> DiscordHandler (Either RestCallErrorCode Message)
handleNietzsche m = liftIO (TIO.readFile "./src/assets/nietzsche.txt") >>= sendMessageChan (messageChannel m) . owoify

isThatcher :: T.Text -> Bool
isThatcher = (=~= ("which movie should we watch" :: T.Text))

handleThatcher :: Message -> DiscordHandler (Either RestCallErrorCode Message)
handleThatcher m = sendMessageChan (messageChannel m) "**MEGAMIND**" 

isDadJoke :: T.Text -> Maybe T.Text
isDadJoke t = case captures of
                  [] -> Nothing
                  e  -> Just (head captures :: T.Text)
    where
        match :: (T.Text, T.Text, T.Text, [T.Text])
        match@(_, _, _, captures) = t =~ ("^[iI] ?[aA]?'?[mM] +([a-zA-Z'*]+)([!;:.,?~-]+| *$)" :: T.Text)

handleDadJoke :: Message -> T.Text -> DiscordHandler (Either RestCallErrorCode Message)
handleDadJoke m t = sendMessageChan (messageChannel m) $ owoify ("hello " <> t <> ", i'm owen")

fortune :: IO String
fortune = SP.readProcess "fortune" [] []

fortuneCow :: IO String
fortuneCow = do
    f <- T.pack <$> fortune
    SP.readProcess "cowsay" [] . T.unpack $ owoify f

isFortune :: T.Text -> Bool
isFortune = (=~= ("^:fortune *$" :: T.Text))

handleFortune :: Message -> DiscordHandler (Either RestCallErrorCode Message)
handleFortune m = do
    cowText <- liftIO fortuneCow 
    sendMessageChan (messageChannel m) ("```" <> T.pack cowText <> "```")

isADA :: T.Text -> Bool
isADA = (=~= ("^:ada24h *$" :: T.Text))

handleADA :: Message -> DiscordHandler (Either RestCallErrorCode Message)
handleADA m = do
    adaAnnouncementM <- liftIO fetchADADetails
    case adaAnnouncementM of
        Left err           -> pure . Left $ RestCallErrorCode 400 "Cannot fetch ADA details from Binance." (T.pack err) 
        Right announcement -> sendMessageChan (messageChannel m) (owoify $ T.pack announcement)