module Mastodon.Http
    exposing
        ( Request
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

import Http
import HttpBuilder as Build
import Json.Decode as Decode
import Mastodon.ApiUrl as ApiUrl
import Mastodon.Decoder exposing (..)
import Mastodon.Encoder exposing (..)
import Mastodon.Model exposing (..)


type alias Request a =
    Build.RequestBuilder a


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


type Method
    = GET
    | POST
    | DELETE


fetch : Client -> Method -> String -> Decode.Decoder a -> Request a
fetch client method endpoint decoder =
    let
        request =
            case method of
                GET ->
                    Build.get

                POST ->
                    Build.post

                DELETE ->
                    Build.delete
    in
        request (client.server ++ endpoint)
            |> Build.withHeader "Authorization" ("Bearer " ++ client.token)
            |> Build.withExpect (Http.expectJson decoder)


register : String -> String -> String -> String -> String -> Request AppRegistration
register server clientName redirectUri scope website =
    Build.post (server ++ ApiUrl.apps)
        |> Build.withExpect (Http.expectJson (appRegistrationDecoder server scope))
        |> Build.withJsonBody (appRegistrationEncoder clientName redirectUri scope website)


getAccessToken : AppRegistration -> String -> Request AccessTokenResult
getAccessToken registration authCode =
    Build.post (registration.server ++ ApiUrl.oauthToken)
        |> Build.withExpect (Http.expectJson (accessTokenDecoder registration))
        |> Build.withJsonBody (authorizationCodeEncoder registration authCode)


getAuthorizationUrl : AppRegistration -> String
getAuthorizationUrl registration =
    encodeUrl (registration.server ++ ApiUrl.oauthAuthorize)
        [ ( "response_type", "code" )
        , ( "client_id", registration.client_id )
        , ( "scope", registration.scope )
        , ( "redirect_uri", registration.redirect_uri )
        ]


send : (Result Error a -> msg) -> Request a -> Cmd msg
send tagger builder =
    Build.send (toResponse >> tagger) builder


fetchAccount : Client -> Int -> Request Account
fetchAccount client accountId =
    fetch client GET (ApiUrl.account accountId) accountDecoder


fetchUserTimeline : Client -> Request (List Status)
fetchUserTimeline client =
    fetch client GET ApiUrl.homeTimeline <| Decode.list statusDecoder


fetchRelationships : Client -> List Int -> Request (List Relationship)
fetchRelationships client ids =
    -- TODO: use withQueryParams
    fetch client GET (ApiUrl.relationships ids) <| Decode.list relationshipDecoder


fetchLocalTimeline : Client -> Request (List Status)
fetchLocalTimeline client =
    -- TODO: use withQueryParams
    fetch client GET (ApiUrl.publicTimeline (Just "public")) <| Decode.list statusDecoder


fetchGlobalTimeline : Client -> Request (List Status)
fetchGlobalTimeline client =
    -- TODO: use withQueryParams
    fetch client GET (ApiUrl.publicTimeline (Nothing)) <| Decode.list statusDecoder


fetchAccountTimeline : Client -> Int -> Request (List Status)
fetchAccountTimeline client id =
    fetch client GET (ApiUrl.accountTimeline id) <| Decode.list statusDecoder


fetchNotifications : Client -> Request (List Notification)
fetchNotifications client =
    fetch client GET (ApiUrl.notifications) <| Decode.list notificationDecoder


fetchAccountFollowers : Client -> Int -> Request (List Account)
fetchAccountFollowers client accountId =
    fetch client GET (ApiUrl.followers accountId) <| Decode.list accountDecoder


fetchAccountFollowing : Client -> Int -> Request (List Account)
fetchAccountFollowing client accountId =
    fetch client GET (ApiUrl.following accountId) <| Decode.list accountDecoder


searchAccounts : Client -> String -> Int -> Bool -> Request (List Account)
searchAccounts client query limit resolve =
    fetch client GET ApiUrl.searchAccount (Decode.list accountDecoder)
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
    fetch client GET ApiUrl.userAccount accountDecoder


postStatus : Client -> StatusRequestBody -> Request Status
postStatus client statusRequestBody =
    fetch client POST ApiUrl.statuses statusDecoder
        |> Build.withJsonBody (statusRequestBodyEncoder statusRequestBody)


deleteStatus : Client -> Int -> Request Int
deleteStatus client id =
    fetch client DELETE (ApiUrl.status id) <| Decode.succeed id


context : Client -> Int -> Request Context
context client id =
    fetch client GET (ApiUrl.context id) contextDecoder


reblog : Client -> Int -> Request Status
reblog client id =
    fetch client POST (ApiUrl.reblog id) statusDecoder


unreblog : Client -> Int -> Request Status
unreblog client id =
    fetch client POST (ApiUrl.unreblog id) statusDecoder


favourite : Client -> Int -> Request Status
favourite client id =
    fetch client POST (ApiUrl.favourite id) statusDecoder


unfavourite : Client -> Int -> Request Status
unfavourite client id =
    fetch client POST (ApiUrl.unfavourite id) statusDecoder


follow : Client -> Int -> Request Relationship
follow client id =
    fetch client POST (ApiUrl.follow id) relationshipDecoder


unfollow : Client -> Int -> Request Relationship
unfollow client id =
    fetch client POST (ApiUrl.unfollow id) relationshipDecoder
