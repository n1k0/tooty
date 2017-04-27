module Mastodon
    exposing
        ( reblog
        , unreblog
        , favourite
        , unfavourite
        , extractReblog
        , register
        , aggregateNotifications
        , getAuthorizationUrl
        , getAccessToken
        , fetchAccount
        , fetchLocalTimeline
        , fetchNotifications
        , fetchGlobalTimeline
        , fetchUserTimeline
        , postStatus
        , send
        , addNotificationToAggregates
        , notificationToAggregate
        )

import Mastodon.Model exposing (Account)
import Http
import HttpBuilder
import Json.Decode as Decode
import Json.Encode as Encode
import List.Extra exposing (groupWhile)
import Mastodon.ApiUrl as ApiUrl
import Mastodon.Decoder
    exposing
        ( accessTokenDecoder
        , accountDecoder
        , appRegistrationDecoder
        , mastodonErrorDecoder
        , notificationDecoder
        , statusDecoder
        )
import Mastodon.Encoder
    exposing
        ( appRegistrationEncoder
        , authorizationCodeEncoder
        , encodeUrl
        , statusRequestBodyEncoder
        )
import Mastodon.Model
    exposing
        ( AccessTokenResult
        , Account
        , AppRegistration
        , Attachment
        , Client
        , Error(..)
        , Mention
        , Notification
        , NotificationAggregate
        , Reblog(..)
        , Request
        , Status
        , StatusRequestBody
        , Tag
        )


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


extractReblog : Status -> Status
extractReblog status =
    case status.reblog of
        Just (Reblog reblog) ->
            reblog

        Nothing ->
            status


toResponse : Result Http.Error a -> Result Error a
toResponse result =
    Result.mapError extractError result


fetch : Client -> String -> Decode.Decoder a -> Request a
fetch client endpoint decoder =
    HttpBuilder.get (client.server ++ endpoint)
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson decoder)



-- Public API


notificationToAggregate : Notification -> NotificationAggregate
notificationToAggregate notification =
    NotificationAggregate
        notification.type_
        notification.status
        [ notification.account ]
        notification.created_at


addNotificationToAggregates : Notification -> List NotificationAggregate -> List NotificationAggregate
addNotificationToAggregates notification aggregates =
    let
        addNewAccountToSameStatus : NotificationAggregate -> Notification -> NotificationAggregate
        addNewAccountToSameStatus aggregate notification =
            case ( aggregate.status, notification.status ) of
                ( Just aggregateStatus, Just notificationStatus ) ->
                    if aggregateStatus.id == notificationStatus.id then
                        { aggregate | accounts = notification.account :: aggregate.accounts }
                    else
                        aggregate

                ( _, _ ) ->
                    aggregate

        {-
           Let's try to find an already existing aggregate, matching the notification
           we are trying to add.
           If we find any aggregate, we modify it inplace. If not, we return the
           aggregates unmodified
        -}
        newAggregates =
            aggregates
                |> List.map
                    (\aggregate ->
                        case ( aggregate.type_, notification.type_ ) of
                            {-
                               Notification and aggregate are of the follow type.
                               Add the new following account.
                            -}
                            ( "follow", "follow" ) ->
                                { aggregate | accounts = notification.account :: aggregate.accounts }

                            {-
                               Notification is of type follow, but current aggregate
                               is of another type. Let's continue then.
                            -}
                            ( _, "follow" ) ->
                                aggregate

                            {-
                               If both types are the same check if we should
                               add the new account.
                            -}
                            ( aggregateType, notificationType ) ->
                                if aggregateType == notificationType then
                                    addNewAccountToSameStatus aggregate notification
                                else
                                    aggregate
                    )
    in
        {-
           If we did no modification to the old aggregates it's
           because we didn't found any match. So me have to create
           a new aggregate
        -}
        if newAggregates == aggregates then
            notificationToAggregate (notification) :: aggregates
        else
            newAggregates


aggregateNotifications : List Notification -> List NotificationAggregate
aggregateNotifications notifications =
    let
        only type_ notifications =
            List.filter (\n -> n.type_ == type_) notifications

        sameStatus n1 n2 =
            case ( n1.status, n2.status ) of
                ( Just r1, Just r2 ) ->
                    r1.id == r2.id

                _ ->
                    False

        extractAggregate statusGroup =
            let
                accounts =
                    List.map .account statusGroup
            in
                case statusGroup of
                    notification :: _ ->
                        [ NotificationAggregate
                            notification.type_
                            notification.status
                            accounts
                            notification.created_at
                        ]

                    [] ->
                        []

        aggregate statusGroups =
            List.map extractAggregate statusGroups |> List.concat
    in
        [ notifications |> only "reblog" |> groupWhile sameStatus |> aggregate
        , notifications |> only "favourite" |> groupWhile sameStatus |> aggregate
        , notifications |> only "mention" |> groupWhile sameStatus |> aggregate
        , notifications |> only "follow" |> groupWhile (\_ _ -> True) |> aggregate
        ]
            |> List.concat
            |> List.sortBy .created_at
            |> List.reverse


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


fetchLocalTimeline : Client -> Request (List Status)
fetchLocalTimeline client =
    fetch client (ApiUrl.publicTimeline (Just "public")) <| Decode.list statusDecoder


fetchGlobalTimeline : Client -> Request (List Status)
fetchGlobalTimeline client =
    fetch client (ApiUrl.publicTimeline (Nothing)) <| Decode.list statusDecoder


fetchNotifications : Client -> Request (List Notification)
fetchNotifications client =
    fetch client (ApiUrl.notifications) <| Decode.list notificationDecoder


postStatus : Client -> StatusRequestBody -> Request Status
postStatus client statusRequestBody =
    HttpBuilder.post (ApiUrl.statuses client.server)
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson statusDecoder)
        |> HttpBuilder.withJsonBody (statusRequestBodyEncoder statusRequestBody)


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
