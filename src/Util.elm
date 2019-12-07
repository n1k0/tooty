module Util exposing
    ( acceptableAccounts
    , extractAuthCode
    )

import Mastodon.Model exposing (..)
import Url


acceptableAccounts : String -> List Account -> List Account
acceptableAccounts query accounts =
    let
        lowerQuery =
            String.toLower query
    in
    if query == "" then
        []

    else
        List.filter (String.contains lowerQuery << String.toLower << .username) accounts



{-
   TODO: refactor this code smell
-}


extractAuthCode : Url.Url -> Maybe String
extractAuthCode { query } =
    case query of
        Just q ->
            case String.split "code=" q of
                [ _, authCode ] ->
                    Just authCode

                _ ->
                    Nothing

        _ ->
            Nothing
