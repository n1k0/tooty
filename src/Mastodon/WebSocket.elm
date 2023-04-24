module Mastodon.WebSocket exposing
    ( StreamType(..)
    , WebSocketEvent(..)
    , WebSocketMessage
    )

import Mastodon.Model exposing (..)


type StreamType
    = UserStream
    | LocalPublicStream
    | GlobalPublicStream


type WebSocketEvent
    = StatusUpdateEvent (Result String Status)
    | StatusNewEvent (Result String Status)
    | NotificationEvent (Result String Notification)
    | StatusDeleteEvent StatusId
    | ErrorEvent String


type alias WebSocketMessage =
    { event : String
    , payload : String
    }
