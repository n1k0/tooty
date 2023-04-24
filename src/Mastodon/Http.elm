module Mastodon.Http exposing
    ( Action(..)
    , Links
    , Request
    , Response
    , extractLinks
    , getAuthorizationUrl
    , send
    , withBodyDecoder
    , withClient
    , withQueryParams
    )

import Dict
import Dict.Extra exposing (mapKeys)
import Http
import HttpBuilder as Build
import Json.Decode as Decode
import Mastodon.ApiUrl as ApiUrl
import Mastodon.Decoder exposing (..)
import Mastodon.Encoder exposing (..)
import Mastodon.Model exposing (..)
import Url.Builder


type Action
    = GET String
    | POST String
    | DELETE String


type alias Links =
    { prev : Maybe String
    , next : Maybe String
    }


type alias Request a =
    Build.RequestBuilder (Response a)


type alias Response a =
    { decoded : a
    , links : Links
    }


extractMastodonError : Int -> String -> String -> Error
extractMastodonError statusCode statusMsg body =
    case Decode.decodeString mastodonErrorDecoder body of
        Ok errRecord ->
            MastodonError statusCode statusMsg errRecord

        Err err ->
            Decode.errorToString err
                |> ServerError statusCode statusMsg


extractLinks : Dict.Dict String String -> Links
extractLinks headers =
    -- The link header content is this form:
    -- <https://...&max_id=123456>; rel="next", <https://...&since_id=123456>; rel="prev"
    -- Note: Chrome and Firefox don't expose header names the same way. Firefox
    -- will use "Link" when Chrome uses "link"; that's why we lowercase them.
    let
        crop =
            String.dropLeft 1 >> String.dropRight 1

        parseDef parts =
            case parts of
                [ url, "rel=\"next\"" ] ->
                    [ ( "next", crop url ) ]

                [ url, "rel=\"prev\"" ] ->
                    [ ( "prev", crop url ) ]

                _ ->
                    []

        parseLink link =
            link
                |> String.split ";"
                |> List.map String.trim
                |> parseDef

        parseLinks content =
            content
                |> String.split ","
                |> List.map String.trim
                |> List.map parseLink
                |> List.concat
                |> Dict.fromList
    in
    case headers |> mapKeys String.toLower |> Dict.get "link" of
        Nothing ->
            { prev = Nothing, next = Nothing }

        Just content ->
            let
                links =
                    parseLinks content
            in
            { prev = Dict.get "prev" links
            , next = Dict.get "next" links
            }


getAuthorizationUrl : AppRegistration -> String
getAuthorizationUrl registration =
    Url.Builder.crossOrigin
        registration.server
        [ ApiUrl.oauthAuthorize ]
        [ Url.Builder.string "response_type" "code"
        , Url.Builder.string "client_id" registration.client_id
        , Url.Builder.string "scope" registration.scope
        , Url.Builder.string "redirect_uri" registration.redirect_uri
        ]


send : Build.RequestBuilder msg -> Cmd msg
send request =
    Build.request request


isLinkUrl : String -> Bool
isLinkUrl url =
    String.contains "max_id=" url || String.contains "since_id=" url


withClient : Client -> Build.RequestBuilder a -> Build.RequestBuilder a
withClient { server, token } builder =
    let
        finalUrl =
            if isLinkUrl builder.url then
                builder.url

            else
                server ++ builder.url
    in
    { builder | url = finalUrl }
        |> Build.withHeader "Authorization" ("Bearer " ++ token)


decodeResponse : Decode.Decoder a -> Http.Response String -> Result.Result Error (Response a)
decodeResponse decoder response =
    case response of
        Http.BadUrl_ _ ->
            Err NetworkError

        Http.Timeout_ ->
            Err TimeoutError

        Http.NetworkError_ ->
            Err NetworkError

        Http.BadStatus_ metadata body ->
            Err (extractMastodonError metadata.statusCode metadata.statusText body)

        Http.GoodStatus_ metadata body ->
            case Decode.decodeString decoder body of
                Ok value ->
                    let
                        links =
                            extractLinks metadata.headers
                    in
                    Ok <| Response value links

                Err e ->
                    Err
                        (ServerError metadata.statusCode
                            metadata.statusText
                            ("Failed decoding JSON: "
                                ++ body
                                ++ ", error: "
                                ++ Decode.errorToString e
                            )
                        )


withBodyDecoder : (Result Error (Response a) -> msg) -> Decode.Decoder a -> Build.RequestBuilder b -> Build.RequestBuilder msg
withBodyDecoder toMsg decoder builder =
    Build.withExpect (Http.expectStringResponse toMsg (decodeResponse decoder)) builder


withQueryParams : List ( String, String ) -> Build.RequestBuilder a -> Build.RequestBuilder a
withQueryParams params builder =
    if isLinkUrl builder.url then
        -- that's a link url, don't append any query string
        builder

    else
        { builder
            | url =
                builder.url
                    ++ (params
                            |> List.map (\( param, value ) -> Url.Builder.string param value)
                            |> Url.Builder.toQuery
                       )
        }
