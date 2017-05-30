module Mastodon.Decoder
    exposing
        ( appRegistrationDecoder
        , accessTokenDecoder
        , accountDecoder
        , attachmentDecoder
        , contextDecoder
        , decodeWebSocketMessage
        , mastodonErrorDecoder
        , mentionDecoder
        , notificationDecoder
        , tagDecoder
        , reblogDecoder
        , relationshipDecoder
        , searchResultsDecoder
        , statusDecoder
        , webSocketPayloadDecoder
        , webSocketEventDecoder
        )

import Json.Decode as Decode
import Json.Decode.Pipeline as Pipe
import Mastodon.Model exposing (..)
import Mastodon.WebSocket exposing (..)


appRegistrationDecoder : String -> String -> Decode.Decoder AppRegistration
appRegistrationDecoder server scope =
    Pipe.decode AppRegistration
        |> Pipe.hardcoded server
        |> Pipe.hardcoded scope
        |> Pipe.required "client_id" Decode.string
        |> Pipe.required "client_secret" Decode.string
        |> Pipe.required "id" Decode.int
        |> Pipe.required "redirect_uri" Decode.string


accessTokenDecoder : AppRegistration -> Decode.Decoder AccessTokenResult
accessTokenDecoder registration =
    Pipe.decode AccessTokenResult
        |> Pipe.hardcoded registration.server
        |> Pipe.required "access_token" Decode.string


accountDecoder : Decode.Decoder Account
accountDecoder =
    Pipe.decode Account
        |> Pipe.required "acct" Decode.string
        |> Pipe.required "avatar" Decode.string
        |> Pipe.required "created_at" Decode.string
        |> Pipe.required "display_name" Decode.string
        |> Pipe.required "followers_count" Decode.int
        |> Pipe.required "following_count" Decode.int
        |> Pipe.required "header" Decode.string
        |> Pipe.required "id" Decode.int
        |> Pipe.required "locked" Decode.bool
        |> Pipe.required "note" Decode.string
        |> Pipe.required "statuses_count" Decode.int
        |> Pipe.required "url" Decode.string
        |> Pipe.required "username" Decode.string


applicationDecoder : Decode.Decoder Application
applicationDecoder =
    Pipe.decode Application
        |> Pipe.required "name" Decode.string
        |> Pipe.required "website" (Decode.nullable Decode.string)


attachmentDecoder : Decode.Decoder Attachment
attachmentDecoder =
    Pipe.decode Attachment
        |> Pipe.required "id" Decode.int
        |> Pipe.required "type" Decode.string
        |> Pipe.required "url" Decode.string
        |> Pipe.optional "remote_url" Decode.string ""
        |> Pipe.required "preview_url" Decode.string
        |> Pipe.required "text_url" (Decode.nullable Decode.string)


contextDecoder : Decode.Decoder Context
contextDecoder =
    Pipe.decode Context
        |> Pipe.required "ancestors" (Decode.list statusDecoder)
        |> Pipe.required "descendants" (Decode.list statusDecoder)


mastodonErrorDecoder : Decode.Decoder String
mastodonErrorDecoder =
    Decode.field "error" Decode.string


mentionDecoder : Decode.Decoder Mention
mentionDecoder =
    Pipe.decode Mention
        |> Pipe.required "id" Decode.int
        |> Pipe.required "url" Decode.string
        |> Pipe.required "username" Decode.string
        |> Pipe.required "acct" Decode.string


notificationDecoder : Decode.Decoder Notification
notificationDecoder =
    Pipe.decode Notification
        |> Pipe.required "id" Decode.int
        |> Pipe.required "type" Decode.string
        |> Pipe.required "created_at" Decode.string
        |> Pipe.required "account" accountDecoder
        |> Pipe.optional "status" (Decode.nullable statusDecoder) Nothing


relationshipDecoder : Decode.Decoder Relationship
relationshipDecoder =
    Pipe.decode Relationship
        |> Pipe.required "id" Decode.int
        |> Pipe.required "blocking" Decode.bool
        |> Pipe.required "followed_by" Decode.bool
        |> Pipe.required "following" Decode.bool
        |> Pipe.required "muting" Decode.bool
        |> Pipe.required "requested" Decode.bool


tagDecoder : Decode.Decoder Tag
tagDecoder =
    Pipe.decode Tag
        |> Pipe.required "name" Decode.string
        |> Pipe.required "url" Decode.string


reblogDecoder : Decode.Decoder Reblog
reblogDecoder =
    Decode.map Reblog (Decode.lazy (\_ -> statusDecoder))


searchResultsDecoder : Decode.Decoder SearchResults
searchResultsDecoder =
    Pipe.decode SearchResults
        |> Pipe.required "accounts" (Decode.list accountDecoder)
        |> Pipe.required "statuses" (Decode.list statusDecoder)
        |> Pipe.required "hashtags" (Decode.list Decode.string)


statusDecoder : Decode.Decoder Status
statusDecoder =
    Pipe.decode Status
        |> Pipe.required "account" accountDecoder
        |> Pipe.required "application" (Decode.nullable applicationDecoder)
        |> Pipe.required "content" Decode.string
        |> Pipe.required "created_at" Decode.string
        |> Pipe.optional "favourited" (Decode.nullable Decode.bool) Nothing
        |> Pipe.required "favourites_count" Decode.int
        |> Pipe.required "id" Decode.int
        |> Pipe.required "in_reply_to_account_id" (Decode.nullable Decode.int)
        |> Pipe.required "in_reply_to_id" (Decode.nullable Decode.int)
        |> Pipe.required "media_attachments" (Decode.list attachmentDecoder)
        |> Pipe.required "mentions" (Decode.list mentionDecoder)
        |> Pipe.optional "reblog" (Decode.lazy (\_ -> Decode.nullable reblogDecoder)) Nothing
        |> Pipe.optional "reblogged" (Decode.nullable Decode.bool) Nothing
        |> Pipe.required "reblogs_count" Decode.int
        |> Pipe.required "sensitive" (Decode.nullable Decode.bool)
        |> Pipe.required "spoiler_text" Decode.string
        |> Pipe.required "tags" (Decode.list tagDecoder)
        |> Pipe.required "uri" Decode.string
        |> Pipe.required "url" (Decode.nullable Decode.string)
        |> Pipe.required "visibility" Decode.string


webSocketPayloadDecoder : Decode.Decoder WebSocketPayload
webSocketPayloadDecoder =
    Decode.oneOf
        [ Decode.map StringPayload Decode.string
        , Decode.map IntPayload Decode.int
        ]


webSocketEventDecoder : Decode.Decoder WebSocketMessage
webSocketEventDecoder =
    Pipe.decode WebSocketMessage
        |> Pipe.required "event" Decode.string
        |> Pipe.required "payload" webSocketPayloadDecoder


decodeWebSocketMessage : String -> WebSocketEvent
decodeWebSocketMessage message =
    case (Decode.decodeString webSocketEventDecoder message) of
        Ok message ->
            case message.event of
                "update" ->
                    case message.payload of
                        StringPayload payload ->
                            StatusUpdateEvent (Decode.decodeString statusDecoder payload)

                        _ ->
                            ErrorEvent "WS status update event payload must be a string"

                "delete" ->
                    case message.payload of
                        IntPayload payload ->
                            StatusDeleteEvent <| Ok payload

                        _ ->
                            ErrorEvent "WS status delete event payload must be an int"

                "notification" ->
                    case message.payload of
                        StringPayload payload ->
                            NotificationEvent (Decode.decodeString notificationDecoder payload)

                        _ ->
                            ErrorEvent "WS notification event payload must be an string"

                event ->
                    ErrorEvent <| "Unknown WS event " ++ event

        Err error ->
            ErrorEvent error
