module Util exposing
    ( acceptableAccounts
    , extractAuthCode
    )

import Dict
import Mastodon.Model exposing (..)
import QS
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


extractAuthCode : Url.Url -> Maybe String
extractAuthCode { query } =
    case query of
        Just q ->
            case Dict.get "code" (QS.parse QS.config q) of
                Just (QS.One value) ->
                    Just value

                _ ->
                    Nothing

        _ ->
            Nothing
