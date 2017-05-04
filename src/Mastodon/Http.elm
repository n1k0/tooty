module Mastodon.Http
    exposing
        ( Request
        , Response
        , Links
        , extractLinks
        , context
        , reblog
        , unreblog
        , favourite
        , unfavourite
        , follow
        , unfollow
        , register
        , getAuthorizationUrl
        , getAccessToken
        , fetchAccount
        , fetchAccountTimeline
        , fetchAccountFollowers
        , fetchAccountFollowing
        , fetchLocalTimeline
        , fetchNotifications
        , fetchGlobalTimeline
        , fetchUserTimeline
        , fetchRelationships
        , postStatus
        , deleteStatus
        , userAccount
        , send
        , searchAccounts
        )

import Dict
import Http
import HttpBuilder as Build
import Json.Decode as Decode
import Mastodon.ApiUrl as ApiUrl
import Mastodon.Decoder exposing (..)
import Mastodon.Encoder exposing (..)
import Mastodon.Model exposing (..)


type Method
    = GET
    | POST
    | DELETE


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


request : String -> Method -> String -> Decode.Decoder a -> Request a
request server method endpoint decoder =
    let
        httpMethod =
            case method of
                GET ->
                    Build.get

                POST ->
                    Build.post

                DELETE ->
                    Build.delete
    in
        httpMethod (server ++ endpoint)
            |> Build.withExpect (Http.expectStringResponse (decodeResponse decoder))


authRequest : Client -> Method -> String -> Decode.Decoder a -> Request a
authRequest client method endpoint decoder =
    request client.server method endpoint decoder
        |> Build.withHeader "Authorization" ("Bearer " ++ client.token)


register : String -> String -> String -> String -> String -> Request AppRegistration
register server clientName redirectUri scope website =
    request server POST ApiUrl.apps (appRegistrationDecoder server scope)
        |> Build.withJsonBody (appRegistrationEncoder clientName redirectUri scope website)


getAccessToken : AppRegistration -> String -> Request AccessTokenResult
getAccessToken registration authCode =
    request registration.server POST ApiUrl.oauthToken (accessTokenDecoder registration)
        |> Build.withJsonBody (authorizationCodeEncoder registration authCode)


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


fetchAccount : Client -> Int -> Request Account
fetchAccount client accountId =
    authRequest client GET (ApiUrl.account accountId) accountDecoder


fetchUserTimeline : Client -> Request (List Status)
fetchUserTimeline client =
    authRequest client GET ApiUrl.homeTimeline <| Decode.list statusDecoder


fetchRelationships : Client -> List Int -> Request (List Relationship)
fetchRelationships client ids =
    authRequest client GET ApiUrl.relationships (Decode.list relationshipDecoder)
        |> Build.withQueryParams (List.map (\id -> ( "id[]", toString id )) ids)


fetchLocalTimeline : Client -> Request (List Status)
fetchLocalTimeline client =
    authRequest client GET ApiUrl.publicTimeline (Decode.list statusDecoder)
        |> Build.withQueryParams [ ( "local", "true" ) ]


fetchGlobalTimeline : Client -> Request (List Status)
fetchGlobalTimeline client =
    authRequest client GET ApiUrl.publicTimeline <| Decode.list statusDecoder


fetchAccountTimeline : Client -> Int -> Request (List Status)
fetchAccountTimeline client id =
    authRequest client GET (ApiUrl.accountTimeline id) <| Decode.list statusDecoder


fetchNotifications : Client -> Request (List Notification)
fetchNotifications client =
    authRequest client GET (ApiUrl.notifications) <| Decode.list notificationDecoder


fetchAccountFollowers : Client -> Int -> Request (List Account)
fetchAccountFollowers client accountId =
    authRequest client GET (ApiUrl.followers accountId) <| Decode.list accountDecoder


fetchAccountFollowing : Client -> Int -> Request (List Account)
fetchAccountFollowing client accountId =
    authRequest client GET (ApiUrl.following accountId) <| Decode.list accountDecoder


searchAccounts : Client -> String -> Int -> Bool -> Request (List Account)
searchAccounts client query limit resolve =
    authRequest client GET ApiUrl.searchAccount (Decode.list accountDecoder)
        |> Build.withQueryParams
            [ ( "q", query )
            , ( "limit", toString limit )
            , ( "resolve"
              , if resolve then
                    "true"
                else
                    "false"
              )
            ]


userAccount : Client -> Request Account
userAccount client =
    authRequest client GET ApiUrl.userAccount accountDecoder


postStatus : Client -> StatusRequestBody -> Request Status
postStatus client statusRequestBody =
    authRequest client POST ApiUrl.statuses statusDecoder
        |> Build.withJsonBody (statusRequestBodyEncoder statusRequestBody)


deleteStatus : Client -> Int -> Request Int
deleteStatus client id =
    authRequest client DELETE (ApiUrl.status id) <| Decode.succeed id


context : Client -> Int -> Request Context
context client id =
    authRequest client GET (ApiUrl.context id) contextDecoder


reblog : Client -> Int -> Request Status
reblog client id =
    authRequest client POST (ApiUrl.reblog id) statusDecoder


unreblog : Client -> Int -> Request Status
unreblog client id =
    authRequest client POST (ApiUrl.unreblog id) statusDecoder


favourite : Client -> Int -> Request Status
favourite client id =
    authRequest client POST (ApiUrl.favourite id) statusDecoder


unfavourite : Client -> Int -> Request Status
unfavourite client id =
    authRequest client POST (ApiUrl.unfavourite id) statusDecoder


follow : Client -> Int -> Request Relationship
follow client id =
    authRequest client POST (ApiUrl.follow id) relationshipDecoder


unfollow : Client -> Int -> Request Relationship
unfollow client id =
    authRequest client POST (ApiUrl.unfollow id) relationshipDecoder
