module Mastodon.WebSocket exposing
    ( StreamType(..)
    , WebSocketEvent(..)
    , WebSocketMessage
    , subscribeToWebSockets
    )

import Mastodon.ApiUrl as ApiUrl
import Mastodon.Model exposing (..)
import String.Extra exposing (replaceSlice)
import Url.Builder



--import WebSocket


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
        Just aClient ->
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
                    Url.Builder.crossOrigin
                        (replaceSlice "wss" 0 5 <| aClient.server ++ ApiUrl.streaming)
                        []
                        [ Url.Builder.string "access_token" aClient.token
                        , Url.Builder.string "stream" type_
                        ]
            in
            WebSocket.listen url message

        Nothing ->
            Sub.none
