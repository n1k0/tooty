module Mastodon.Http
    exposing
        ( Links
        , Action(..)
        , Request
        , Response
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
        , fetchStatusList
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


request : Decode.Decoder a -> Action -> Request a
request decoder action =
    let
        httpMethod =
            case action of
                GET url ->
                    Build.get url

                POST url ->
                    Build.post url

                DELETE url ->
                    Build.delete url
    in
        httpMethod
            |> Build.withExpect (Http.expectStringResponse (decodeResponse decoder))


authRequest : Client -> Decode.Decoder a -> Action -> Request a
authRequest client decoder action =
    request decoder action
        |> Build.withHeader "Authorization" ("Bearer " ++ client.token)


register : String -> String -> String -> String -> String -> Request AppRegistration
register server clientName redirectUri scope website =
    request (appRegistrationDecoder server scope) (POST (server ++ ApiUrl.apps))
        |> Build.withJsonBody (appRegistrationEncoder clientName redirectUri scope website)


getAccessToken : AppRegistration -> String -> Request AccessTokenResult
getAccessToken registration authCode =
    request (accessTokenDecoder registration) (POST (registration.server ++ ApiUrl.oauthToken))
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
    authRequest client accountDecoder (GET (client.server ++ ApiUrl.account accountId))


fetchUserTimeline : Client -> Maybe String -> Request (List Status)
fetchUserTimeline client url =
    case url of
        Just url ->
            authRequest client (Decode.list statusDecoder) (GET url)

        Nothing ->
            authRequest client (Decode.list statusDecoder) (GET (client.server ++ ApiUrl.homeTimeline))


fetchRelationships : Client -> List Int -> Request (List Relationship)
fetchRelationships client ids =
    GET (client.server ++ ApiUrl.relationships)
        |> authRequest client (Decode.list relationshipDecoder)
        |> Build.withQueryParams (List.map (\id -> ( "id[]", toString id )) ids)


fetchLocalTimeline : Client -> Request (List Status)
fetchLocalTimeline client =
    GET (client.server ++ ApiUrl.publicTimeline)
        |> authRequest client (Decode.list statusDecoder)
        |> Build.withQueryParams [ ( "local", "true" ) ]


fetchGlobalTimeline : Client -> Request (List Status)
fetchGlobalTimeline client =
    GET (client.server ++ ApiUrl.publicTimeline)
        |> authRequest client (Decode.list statusDecoder)


fetchAccountTimeline : Client -> Int -> Request (List Status)
fetchAccountTimeline client id =
    GET (client.server ++ (ApiUrl.accountTimeline id))
        |> authRequest client (Decode.list statusDecoder)


fetchNotifications : Client -> Request (List Notification)
fetchNotifications client =
    GET (client.server ++ ApiUrl.notifications)
        |> authRequest client (Decode.list notificationDecoder)


fetchAccountFollowers : Client -> Int -> Request (List Account)
fetchAccountFollowers client accountId =
    GET (client.server ++ (ApiUrl.followers accountId))
        |> authRequest client (Decode.list accountDecoder)


fetchAccountFollowing : Client -> Int -> Request (List Account)
fetchAccountFollowing client accountId =
    GET (client.server ++ (ApiUrl.following accountId))
        |> authRequest client (Decode.list accountDecoder)


searchAccounts : Client -> String -> Int -> Bool -> Request (List Account)
searchAccounts client query limit resolve =
    GET (client.server ++ ApiUrl.searchAccount)
        |> authRequest client (Decode.list accountDecoder)
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
    GET (client.server ++ ApiUrl.userAccount)
        |> authRequest client accountDecoder


postStatus : Client -> StatusRequestBody -> Request Status
postStatus client statusRequestBody =
    POST (client.server ++ ApiUrl.statuses)
        |> authRequest client statusDecoder
        |> Build.withJsonBody (statusRequestBodyEncoder statusRequestBody)


deleteStatus : Client -> Int -> Request Int
deleteStatus client id =
    DELETE (client.server ++ (ApiUrl.status id))
        |> authRequest client (Decode.succeed id)


context : Client -> Int -> Request Context
context client id =
    GET (client.server ++ (ApiUrl.context id))
        |> authRequest client contextDecoder


reblog : Client -> Int -> Request Status
reblog client id =
    POST (client.server ++ (ApiUrl.reblog id))
        |> authRequest client statusDecoder


unreblog : Client -> Int -> Request Status
unreblog client id =
    POST (client.server ++ (ApiUrl.unreblog id))
        |> authRequest client statusDecoder


favourite : Client -> Int -> Request Status
favourite client id =
    POST (client.server ++ (ApiUrl.favourite id))
        |> authRequest client statusDecoder


unfavourite : Client -> Int -> Request Status
unfavourite client id =
    POST (client.server ++ (ApiUrl.unfavourite id))
        |> fetchStatus client


follow : Client -> Int -> Request Relationship
follow client id =
    POST (client.server ++ (ApiUrl.follow id))
        |> authRequest client relationshipDecoder


unfollow : Client -> Int -> Request Relationship
unfollow client id =
    POST (client.server ++ (ApiUrl.unfollow id))
        |> authRequest client relationshipDecoder



-- NEW STUFF


fetchStatus : Client -> Action -> Request Status
fetchStatus client action =
    authRequest client statusDecoder action


fetchStatusList : Client -> Action -> Request (List Status)
fetchStatusList client action =
    authRequest client (Decode.list statusDecoder) action
