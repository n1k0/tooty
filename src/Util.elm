module Util exposing
    ( acceptableAutoItems
    , extractAuthCode
    )

import Dict
import Mastodon.Model exposing (..)
import QS
import Url


acceptableAutoItems : String -> (a -> String) -> List a -> List a
acceptableAutoItems query toString items =
    let
        lowerQuery =
            String.toLower query
    in
    if query == "" then
        []

    else
        List.filter (String.contains lowerQuery << String.toLower << toString) items


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
