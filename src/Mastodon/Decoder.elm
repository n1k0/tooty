module Mastodon.Decoder exposing
    ( accessTokenDecoder
    , accountDecoder
    , appRegistrationDecoder
    , attachmentDecoder
    , contextDecoder
    , decodeClients
    , decodeWebSocketMessage
    , mastodonErrorDecoder
    , mentionDecoder
    , notificationDecoder
    , reblogDecoder
    , relationshipDecoder
    , searchResultsDecoder
    , statusDecoder
    , statusSourceDecoder
    , tagDecoder
    , webSocketEventDecoder
    )

import Json.Decode as Decode
import Json.Decode.Pipeline as Pipe
import Mastodon.Model exposing (..)
import Mastodon.WebSocket exposing (..)


appRegistrationDecoder : String -> String -> Decode.Decoder AppRegistration
appRegistrationDecoder server scope =
    Decode.succeed AppRegistration
        |> Pipe.hardcoded server
        |> Pipe.hardcoded scope
        |> Pipe.required "client_id" Decode.string
        |> Pipe.required "client_secret" Decode.string
        |> Pipe.required "id" idDecoder
        |> Pipe.required "redirect_uri" Decode.string


accessTokenDecoder : AppRegistration -> Decode.Decoder AccessTokenResult
accessTokenDecoder registration =
    Decode.succeed AccessTokenResult
        |> Pipe.hardcoded registration.server
        |> Pipe.required "access_token" Decode.string


accountDecoder : Decode.Decoder Account
accountDecoder =
    Decode.succeed Account
        |> Pipe.required "acct" Decode.string
        |> Pipe.required "avatar" Decode.string
        |> Pipe.required "created_at" Decode.string
        |> Pipe.required "display_name" Decode.string
        |> Pipe.required "followers_count" Decode.int
        |> Pipe.required "following_count" Decode.int
        |> Pipe.required "header" Decode.string
        |> Pipe.required "id" idDecoder
        |> Pipe.required "locked" Decode.bool
        |> Pipe.required "note" Decode.string
        |> Pipe.required "statuses_count" Decode.int
        |> Pipe.required "url" Decode.string
        |> Pipe.required "username" Decode.string


applicationDecoder : Decode.Decoder Application
applicationDecoder =
    Decode.succeed Application
        |> Pipe.required "name" Decode.string
        |> Pipe.required "website" (Decode.nullable Decode.string)


attachmentDecoder : Decode.Decoder Attachment
attachmentDecoder =
    Decode.succeed Attachment
        |> Pipe.required "id" idDecoder
        |> Pipe.required "type" Decode.string
        |> Pipe.required "url" Decode.string
        |> Pipe.optional "remote_url" Decode.string ""
        |> Pipe.required "preview_url" (Decode.nullable Decode.string)
        |> Pipe.required "text_url" (Decode.nullable Decode.string)
        |> Pipe.required "description" (Decode.nullable Decode.string)


contextDecoder : Decode.Decoder Context
contextDecoder =
    Decode.succeed Context
        |> Pipe.required "ancestors" (Decode.list statusDecoder)
        |> Pipe.required "descendants" (Decode.list statusDecoder)


clientDecoder : Decode.Decoder Client
clientDecoder =
    Decode.succeed Client
        |> Pipe.required "server" Decode.string
        |> Pipe.required "token" Decode.string
        |> Pipe.required "account" (Decode.maybe accountDecoder)


decodeClients : String -> Result Decode.Error (List Client)
decodeClients json =
    Decode.decodeString (Decode.list clientDecoder) json


mastodonErrorDecoder : Decode.Decoder String
mastodonErrorDecoder =
    Decode.field "error" Decode.string


mentionDecoder : Decode.Decoder Mention
mentionDecoder =
    Decode.succeed Mention
        |> Pipe.required "id" idDecoder
        |> Pipe.required "url" Decode.string
        |> Pipe.required "username" Decode.string
        |> Pipe.required "acct" Decode.string


notificationDecoder : Decode.Decoder Notification
notificationDecoder =
    Decode.succeed Notification
        |> Pipe.required "id" idDecoder
        |> Pipe.required "type" Decode.string
        |> Pipe.required "created_at" Decode.string
        |> Pipe.required "account" accountDecoder
        |> Pipe.optional "status" (Decode.nullable statusDecoder) Nothing


relationshipDecoder : Decode.Decoder Relationship
relationshipDecoder =
    Decode.succeed Relationship
        |> Pipe.required "id" idDecoder
        |> Pipe.required "blocking" Decode.bool
        |> Pipe.required "followed_by" Decode.bool
        |> Pipe.required "following" Decode.bool
        |> Pipe.required "muting" Decode.bool
        |> Pipe.required "requested" Decode.bool


tagDecoder : Decode.Decoder Tag
tagDecoder =
    Decode.succeed Tag
        |> Pipe.required "name" Decode.string
        |> Pipe.required "url" Decode.string


reblogDecoder : Decode.Decoder Reblog
reblogDecoder =
    Decode.map Reblog (Decode.lazy (\_ -> statusDecoder))


searchResultsDecoder : Decode.Decoder SearchResults
searchResultsDecoder =
    Decode.succeed SearchResults
        |> Pipe.required "accounts" (Decode.list accountDecoder)
        |> Pipe.required "statuses" (Decode.list statusDecoder)
        |> Pipe.required "hashtags" (Decode.list hashtagDecoder)


idDecoder : Decode.Decoder String
idDecoder =
    -- Note: since v2.0.0 of the Mastodon API, ids are treated as strings, so we
    -- treat all ids as strings.
    Decode.oneOf
        [ Decode.string
        , Decode.int |> Decode.map String.fromInt
        ]


statusIdDecoder : Decode.Decoder StatusId
statusIdDecoder =
    idDecoder |> Decode.map StatusId


statusDecoder : Decode.Decoder Status
statusDecoder =
    Decode.succeed Status
        |> Pipe.required "account" accountDecoder
        |> Pipe.optional "application" (Decode.nullable applicationDecoder) Nothing
        |> Pipe.required "content" Decode.string
        |> Pipe.required "created_at" Decode.string
        |> Pipe.required "edited_at" (Decode.nullable Decode.string)
        |> Pipe.optional "favourited" (Decode.nullable Decode.bool) Nothing
        |> Pipe.required "favourites_count" Decode.int
        |> Pipe.required "id" statusIdDecoder
        |> Pipe.required "in_reply_to_account_id" (Decode.nullable idDecoder)
        |> Pipe.required "in_reply_to_id" (Decode.nullable statusIdDecoder)
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


statusSourceDecoder : Decode.Decoder StatusSource
statusSourceDecoder =
    Decode.succeed StatusSource
        |> Pipe.required "id" statusIdDecoder
        |> Pipe.required "text" Decode.string
        |> Pipe.required "spoiler_text" Decode.string


hashtagHistoryDecoder : Decode.Decoder HashtagHistory
hashtagHistoryDecoder =
    Decode.succeed HashtagHistory
        |> Pipe.required "day" Decode.string
        |> Pipe.required "uses" Decode.string
        |> Pipe.required "accounts" Decode.string


hashtagDecoder : Decode.Decoder Hashtag
hashtagDecoder =
    Decode.succeed Hashtag
        |> Pipe.required "name" Decode.string
        |> Pipe.required "url" Decode.string
        |> Pipe.required "history" (Decode.list hashtagHistoryDecoder)


webSocketEventDecoder : Decode.Decoder WebSocketMessage
webSocketEventDecoder =
    Decode.succeed WebSocketMessage
        |> Pipe.required "event" Decode.string
        |> Pipe.required "payload"
            -- NOTE: as of the Mastodon API v2.0.0, ids may be either ints or
            -- strings. If we receive an int (most likely for the delete event),
            -- we cast it to a string.
            (Decode.oneOf
                [ Decode.string
                , Decode.int |> Decode.map String.fromInt
                ]
            )


decodeWebSocketMessage : String -> WebSocketEvent
decodeWebSocketMessage message =
    case Decode.decodeString webSocketEventDecoder message of
        Ok { event, payload } ->
            case event of
                "update" ->
                    StatusNewEvent
                        (Decode.decodeString statusDecoder payload
                            |> Result.mapError Decode.errorToString
                        )

                "delete" ->
                    StatusDeleteEvent (StatusId payload)

                "notification" ->
                    NotificationEvent
                        (Decode.decodeString notificationDecoder payload
                            |> Result.mapError Decode.errorToString
                        )

                "status.update" ->
                    StatusUpdateEvent
                        (Decode.decodeString statusDecoder payload
                            |> Result.mapError Decode.errorToString
                        )

                e ->
                    ErrorEvent <| "Unknown WS event " ++ e

        Err error ->
            ErrorEvent <| Decode.errorToString error
