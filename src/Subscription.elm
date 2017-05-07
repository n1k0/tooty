module Subscription exposing (subscriptions)

import Autocomplete
import Mastodon.WebSocket
import Time
import Types exposing (..)


subscriptions : Model -> Sub Msg
subscriptions { client, currentView } =
    let
        timeSub =
            Time.every Time.millisecond Tick

        userWsSub =
            Mastodon.WebSocket.subscribeToWebSockets
                client
                Mastodon.WebSocket.UserStream
                NewWebsocketUserMessage
                |> Sub.map WebSocketEvent

        otherWsSub =
            if currentView == GlobalTimelineView then
                Mastodon.WebSocket.subscribeToWebSockets
                    client
                    Mastodon.WebSocket.GlobalPublicStream
                    NewWebsocketGlobalMessage
                    |> Sub.map WebSocketEvent
            else if currentView == LocalTimelineView then
                Mastodon.WebSocket.subscribeToWebSockets
                    client
                    Mastodon.WebSocket.LocalPublicStream
                    NewWebsocketLocalMessage
                    |> Sub.map WebSocketEvent
            else
                Sub.none

        autoCompleteSub =
            Sub.map (DraftEvent << SetAutoState) Autocomplete.subscription
    in
        [ timeSub, userWsSub, otherWsSub, autoCompleteSub ]
            |> Sub.batch
