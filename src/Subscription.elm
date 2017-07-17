module Subscription exposing (subscriptions)

import Autocomplete
import Keyboard
import Mastodon.WebSocket
import Ports
import Time
import Types exposing (..)


subscriptions : Model -> Sub Msg
subscriptions { clients, currentView } =
    let
        timeSub =
            Time.every Time.second Tick

        userWsSub =
            Mastodon.WebSocket.subscribeToWebSockets
                (List.head clients)
                Mastodon.WebSocket.UserStream
                NewWebsocketUserMessage
                |> Sub.map WebSocketEvent

        otherWsSub =
            if currentView == GlobalTimelineView then
                Mastodon.WebSocket.subscribeToWebSockets
                    (List.head clients)
                    Mastodon.WebSocket.GlobalPublicStream
                    NewWebsocketGlobalMessage
                    |> Sub.map WebSocketEvent
            else if currentView == LocalTimelineView then
                Mastodon.WebSocket.subscribeToWebSockets
                    (List.head clients)
                    Mastodon.WebSocket.LocalPublicStream
                    NewWebsocketLocalMessage
                    |> Sub.map WebSocketEvent
            else
                Sub.none

        autoCompleteSub =
            Sub.map (DraftEvent << SetAutoState) Autocomplete.subscription

        uploadSuccessSub =
            Ports.uploadSuccess (DraftEvent << UploadResult)

        uploadErrorSub =
            Ports.uploadError (DraftEvent << UploadError)

        keyDownsSub =
            Keyboard.downs (KeyMsg KeyDown)

        keyUpsSub =
            Keyboard.ups (KeyMsg KeyUp)
    in
        Sub.batch
            [ timeSub
            , userWsSub
            , otherWsSub
            , autoCompleteSub
            , uploadSuccessSub
            , uploadErrorSub
            , keyDownsSub
            , keyUpsSub
            ]
