module Mastodon.Http
    exposing
        ( Links
        , Action(..)
        , Request
        , Response
        , extractLinks
        , getAuthorizationUrl
        , send
        , withClient
        , withDecoder
        )

import Dict
import Http
import HttpBuilder as Build
import Json.Decode as Decode
import Mastodon.ApiUrl as ApiUrl
import Mastodon.Decoder exposing (..)
import Mastodon.Encoder exposing (..)
import Mastodon.Model exposing (..)


type Action
    = GET String
    | POST String
    | DELETE String


type Link
    = Prev
    | Next
    | None


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
            ServerError statusCode statusMsg err


extractError : Http.Error -> Error
extractError error =
    case error of
        Http.BadStatus { status, body } ->
            extractMastodonError status.code status.message body

        Http.BadPayload str { status } ->
            ServerError
                status.code
                status.message
                ("Failed decoding JSON: " ++ str)

        Http.Timeout ->
            TimeoutError

        _ ->
            NetworkError


toResponse : Result Http.Error a -> Result Error a
toResponse result =
    Result.mapError extractError result


extractLinks : Dict.Dict String String -> Links
extractLinks headers =
    -- The link header content is this form:
    -- <https://...&max_id=123456>; rel="next", <https://...&since_id=123456>; rel="prev"
    let
        crop =
            (String.dropLeft 1) >> (String.dropRight 1)

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
        case (Dict.get "link" headers) of
            Nothing ->
                { prev = Nothing, next = Nothing }

            Just content ->
                let
                    links =
                        parseLinks content
                in
                    { prev = (Dict.get "prev" links)
                    , next = (Dict.get "next" links)
                    }


decodeResponse : Decode.Decoder a -> Http.Response String -> Result.Result String (Response a)
decodeResponse decoder response =
    let
        decoded =
            Decode.decodeString decoder response.body

        links =
            extractLinks response.headers
    in
        case decoded of
            Ok decoded ->
                Ok <| Response decoded links

            Err error ->
                Err error


getAuthorizationUrl : AppRegistration -> String
getAuthorizationUrl registration =
    encodeUrl (registration.server ++ ApiUrl.oauthAuthorize)
        [ ( "response_type", "code" )
        , ( "client_id", registration.client_id )
        , ( "scope", registration.scope )
        , ( "redirect_uri", registration.redirect_uri )
        ]


send : (Result Error a -> msg) -> Build.RequestBuilder a -> Cmd msg
send tagger request =
    Build.send (toResponse >> tagger) request


withClient : Client -> Build.RequestBuilder a -> Build.RequestBuilder a
withClient { server, token } builder =
    let
        finalUrl =
            if String.startsWith server builder.url then
                builder.url
            else
                server ++ builder.url
    in
        { builder | url = finalUrl }
            |> Build.withHeader "Authorization" ("Bearer " ++ token)


withDecoder : Decode.Decoder b -> Build.RequestBuilder a -> Request b
withDecoder decoder builder =
    builder
        |> Build.withExpect (Http.expectStringResponse (decodeResponse decoder))
