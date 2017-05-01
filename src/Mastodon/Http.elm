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


fetch : Client -> String -> Decode.Decoder a -> Request a
fetch client endpoint decoder =
    HttpBuilder.get (client.server ++ endpoint)
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson decoder)


register : String -> String -> String -> String -> String -> Request AppRegistration
register server client_name redirect_uri scope website =
    HttpBuilder.post (ApiUrl.apps server)
        |> HttpBuilder.withExpect (Http.expectJson (appRegistrationDecoder server scope))
        |> HttpBuilder.withJsonBody (appRegistrationEncoder client_name redirect_uri scope website)


getAuthorizationUrl : AppRegistration -> String
getAuthorizationUrl registration =
    encodeUrl (ApiUrl.oauthAuthorize registration.server)
        [ ( "response_type", "code" )
        , ( "client_id", registration.client_id )
        , ( "scope", registration.scope )
        , ( "redirect_uri", registration.redirect_uri )
        ]


getAccessToken : AppRegistration -> String -> Request AccessTokenResult
getAccessToken registration authCode =
    HttpBuilder.post (ApiUrl.oauthToken registration.server)
        |> HttpBuilder.withExpect (Http.expectJson (accessTokenDecoder registration))
        |> HttpBuilder.withJsonBody (authorizationCodeEncoder registration authCode)


send : (Result Error a -> msg) -> Request a -> Cmd msg
send tagger builder =
    builder |> HttpBuilder.send (toResponse >> tagger)


fetchAccount : Client -> Int -> Request Account
fetchAccount client accountId =
    fetch client (ApiUrl.account accountId) accountDecoder


fetchUserTimeline : Client -> Request (List Status)
fetchUserTimeline client =
    fetch client ApiUrl.homeTimeline <| Decode.list statusDecoder


fetchRelationships : Client -> List Int -> Request (List Relationship)
fetchRelationships client ids =
    fetch client (ApiUrl.relationships ids) <| Decode.list relationshipDecoder


fetchLocalTimeline : Client -> Request (List Status)
fetchLocalTimeline client =
    fetch client (ApiUrl.publicTimeline (Just "public")) <| Decode.list statusDecoder


fetchGlobalTimeline : Client -> Request (List Status)
fetchGlobalTimeline client =
    fetch client (ApiUrl.publicTimeline (Nothing)) <| Decode.list statusDecoder


fetchAccountTimeline : Client -> Int -> Request (List Status)
fetchAccountTimeline client id =
    fetch client (ApiUrl.accountTimeline id) <| Decode.list statusDecoder


fetchNotifications : Client -> Request (List Notification)
fetchNotifications client =
    fetch client (ApiUrl.notifications) <| Decode.list notificationDecoder


fetchAccountFollowers : Client -> Int -> Request (List Account)
fetchAccountFollowers client accountId =
    fetch client (ApiUrl.followers accountId) <| Decode.list accountDecoder


fetchAccountFollowing : Client -> Int -> Request (List Account)
fetchAccountFollowing client accountId =
    fetch client (ApiUrl.following accountId) <| Decode.list accountDecoder


searchAccounts : Client -> String -> Int -> Bool -> Request (List Account)
searchAccounts client query limit resolve =
    HttpBuilder.get (ApiUrl.searchAccount client.server query limit resolve)
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson (Decode.list accountDecoder))


userAccount : Client -> Request Account
userAccount client =
    HttpBuilder.get (ApiUrl.userAccount client.server)
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson accountDecoder)


postStatus : Client -> StatusRequestBody -> Request Status
postStatus client statusRequestBody =
    HttpBuilder.post (ApiUrl.statuses client.server)
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson statusDecoder)
        |> HttpBuilder.withJsonBody (statusRequestBodyEncoder statusRequestBody)


deleteStatus : Client -> Int -> Request Int
deleteStatus client id =
    HttpBuilder.delete (ApiUrl.status client.server id)
        |> HttpBuilder.withExpect (Http.expectJson <| Decode.succeed id)
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)


context : Client -> Int -> Request Context
context client id =
    HttpBuilder.get (ApiUrl.context client.server id)
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson contextDecoder)


reblog : Client -> Int -> Request Status
reblog client id =
    HttpBuilder.post (ApiUrl.reblog client.server id)
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson statusDecoder)


unreblog : Client -> Int -> Request Status
unreblog client id =
    HttpBuilder.post (ApiUrl.unreblog client.server id)
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson statusDecoder)


favourite : Client -> Int -> Request Status
favourite client id =
    HttpBuilder.post (ApiUrl.favourite client.server id)
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson statusDecoder)


unfavourite : Client -> Int -> Request Status
unfavourite client id =
    HttpBuilder.post (ApiUrl.unfavourite client.server id)
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson statusDecoder)


follow : Client -> Int -> Request Relationship
follow client id =
    HttpBuilder.post (ApiUrl.follow client.server id)
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson relationshipDecoder)


unfollow : Client -> Int -> Request Relationship
unfollow client id =
    HttpBuilder.post (ApiUrl.unfollow client.server id)
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson relationshipDecoder)
