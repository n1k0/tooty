module Util
    exposing
        ( acceptableAccounts
        , extractAuthCode
        )

import Mastodon.Model exposing (..)
import Navigation


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


extractAuthCode : Navigation.Location -> Maybe String
extractAuthCode { search } =
    case (String.split "?code=" search) of
        [ _, authCode ] ->
            Just authCode

        _ ->
            Nothing
