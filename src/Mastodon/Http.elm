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
import HttpBuilder
import Json.Decode as Decode
import Mastodon.ApiUrl as ApiUrl
import Mastodon.Decoder exposing (..)
import Mastodon.Encoder exposing (..)
import Mastodon.Model exposing (..)


type alias Request a =
    HttpBuilder.RequestBuilder a


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


fetch : Method -> Client -> String -> Decode.Decoder a -> Request a
fetch method client endpoint decoder =
    let
        request =
            case method of
                GET ->
                    HttpBuilder.get

                POST ->
                    HttpBuilder.post

                DELETE ->
                    HttpBuilder.delete
    in
        request (client.server ++ endpoint)
            |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
            |> HttpBuilder.withExpect (Http.expectJson decoder)


register : String -> String -> String -> String -> String -> Request AppRegistration
register server client_name redirect_uri scope website =
    HttpBuilder.post (server ++ ApiUrl.apps)
        |> HttpBuilder.withExpect (Http.expectJson (appRegistrationDecoder server scope))
        |> HttpBuilder.withJsonBody (appRegistrationEncoder client_name redirect_uri scope website)


getAuthorizationUrl : AppRegistration -> String
getAuthorizationUrl registration =
    encodeUrl (registration.server ++ ApiUrl.oauthAuthorize)
        [ ( "response_type", "code" )
        , ( "client_id", registration.client_id )
        , ( "scope", registration.scope )
        , ( "redirect_uri", registration.redirect_uri )
        ]


getAccessToken : AppRegistration -> String -> Request AccessTokenResult
getAccessToken registration authCode =
    HttpBuilder.post (registration.server ++ ApiUrl.oauthToken)
        |> HttpBuilder.withExpect (Http.expectJson (accessTokenDecoder registration))
        |> HttpBuilder.withJsonBody (authorizationCodeEncoder registration authCode)


send : (Result Error a -> msg) -> Request a -> Cmd msg
send tagger builder =
    builder |> HttpBuilder.send (toResponse >> tagger)


fetchAccount : Client -> Int -> Request Account
fetchAccount client accountId =
    fetch GET client (ApiUrl.account accountId) accountDecoder


fetchUserTimeline : Client -> Request (List Status)
fetchUserTimeline client =
    fetch GET client ApiUrl.homeTimeline <| Decode.list statusDecoder


fetchRelationships : Client -> List Int -> Request (List Relationship)
fetchRelationships client ids =
    -- TODO: use withQueryParams
    fetch GET client (ApiUrl.relationships ids) <| Decode.list relationshipDecoder


fetchLocalTimeline : Client -> Request (List Status)
fetchLocalTimeline client =
    -- TODO: use withQueryParams
    fetch GET client (ApiUrl.publicTimeline (Just "public")) <| Decode.list statusDecoder


fetchGlobalTimeline : Client -> Request (List Status)
fetchGlobalTimeline client =
    -- TODO: use withQueryParams
    fetch GET client (ApiUrl.publicTimeline (Nothing)) <| Decode.list statusDecoder


fetchAccountTimeline : Client -> Int -> Request (List Status)
fetchAccountTimeline client id =
    fetch GET client (ApiUrl.accountTimeline id) <| Decode.list statusDecoder


fetchNotifications : Client -> Request (List Notification)
fetchNotifications client =
    fetch GET client (ApiUrl.notifications) <| Decode.list notificationDecoder


fetchAccountFollowers : Client -> Int -> Request (List Account)
fetchAccountFollowers client accountId =
    fetch GET client (ApiUrl.followers accountId) <| Decode.list accountDecoder


fetchAccountFollowing : Client -> Int -> Request (List Account)
fetchAccountFollowing client accountId =
    fetch GET client (ApiUrl.following accountId) <| Decode.list accountDecoder


searchAccounts : Client -> String -> Int -> Bool -> Request (List Account)
searchAccounts client query limit resolve =
    HttpBuilder.get (client.server ++ ApiUrl.searchAccount)
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson (Decode.list accountDecoder))
        |> HttpBuilder.withQueryParams
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
    HttpBuilder.get (client.server ++ ApiUrl.userAccount)
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson accountDecoder)


postStatus : Client -> StatusRequestBody -> Request Status
postStatus client statusRequestBody =
    HttpBuilder.post (client.server ++ ApiUrl.statuses)
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson statusDecoder)
        |> HttpBuilder.withJsonBody (statusRequestBodyEncoder statusRequestBody)


deleteStatus : Client -> Int -> Request Int
deleteStatus client id =
    HttpBuilder.delete (client.server ++ (ApiUrl.status id))
        |> HttpBuilder.withExpect (Http.expectJson <| Decode.succeed id)
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)


context : Client -> Int -> Request Context
context client id =
    HttpBuilder.get (client.server ++ (ApiUrl.context id))
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson contextDecoder)


reblog : Client -> Int -> Request Status
reblog client id =
    HttpBuilder.post (client.server ++ (ApiUrl.reblog id))
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson statusDecoder)


unreblog : Client -> Int -> Request Status
unreblog client id =
    HttpBuilder.post (client.server ++ (ApiUrl.unreblog id))
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson statusDecoder)


favourite : Client -> Int -> Request Status
favourite client id =
    HttpBuilder.post (client.server ++ (ApiUrl.favourite id))
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson statusDecoder)


unfavourite : Client -> Int -> Request Status
unfavourite client id =
    HttpBuilder.post (client.server ++ (ApiUrl.unfavourite id))
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson statusDecoder)


follow : Client -> Int -> Request Relationship
follow client id =
    HttpBuilder.post (client.server ++ (ApiUrl.follow id))
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson relationshipDecoder)


unfollow : Client -> Int -> Request Relationship
unfollow client id =
    HttpBuilder.post (client.server ++ (ApiUrl.unfollow id))
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson relationshipDecoder)
