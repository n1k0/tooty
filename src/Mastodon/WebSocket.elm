module Mastodon.WebSocket
    exposing
        ( StreamType(..)
        , WebSocketEvent(..)
        , WebSocketMessage
        , subscribeToWebSockets
        )

import String.Extra exposing (replaceSlice)
import WebSocket
import Mastodon.ApiUrl as ApiUrl
import Mastodon.Encoder exposing (encodeUrl)
import Mastodon.Model exposing (..)


type StreamType
    = UserStream
    | LocalPublicStream
    | GlobalPublicStream


type WebSocketEvent
    = StatusUpdateEvent (Result String Status)
    | NotificationEvent (Result String Notification)
    | StatusDeleteEvent StatusId
    | ErrorEvent String


type alias WebSocketMessage =
    { event : String
    , payload : String
    }


subscribeToWebSockets : Maybe Client -> StreamType -> (String -> a) -> Sub a
subscribeToWebSockets client streamType message =
    case client of
        Just client ->
            let
                type_ =
                    case streamType of
                        GlobalPublicStream ->
                            "public"

                        LocalPublicStream ->
                            "public:local"

                        UserStream ->
                            "user"

                url =
                    encodeUrl
                        (replaceSlice "wss" 0 5 <| client.server ++ ApiUrl.streaming)
                        [ ( "access_token", client.token )
                        , ( "stream", type_ )
                        ]
            in
                WebSocket.listen url message

        Nothing ->
            Sub.none
