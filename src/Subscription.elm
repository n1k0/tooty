module Subscription exposing (subscriptions)

-- TODO
--import Keyboard
--import Autocomplete

import Mastodon.WebSocket
import Ports
import Time
import Types exposing (..)


subscriptions : Model -> Sub Msg
subscriptions { clients, currentView } =
    let
        timeSub =
            Time.every 1000 Tick

        {-
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
              portFunnelsSub =
                  PortFunnels.subscriptions WsProcess
           autoCompleteSub =
               Sub.map (DraftEvent << SetAutoState) Autocomplete.subscription
        -}
        uploadSuccessSub =
            Ports.uploadSuccess (DraftEvent << UploadResult)

        uploadErrorSub =
            Ports.uploadError (DraftEvent << UploadError)

        otherWsSub =
            if currentView == GlobalTimelineView then
                Ports.wsGlobalEvent (WebSocketEvent << NewWebsocketGlobalMessage)

            else if currentView == LocalTimelineView then
                Ports.wsLocalEvent (WebSocketEvent << NewWebsocketLocalMessage)

            else
                Sub.none

        userWsSub =
            Ports.wsUserEvent (WebSocketEvent << NewWebsocketUserMessage)

        -- keyDownsSub =
        --     Keyboard.downs (KeyMsg KeyDown)
        -- keyUpsSub =
        --     Keyboard.ups (KeyMsg KeyUp)
    in
    Sub.batch
        [ timeSub
        , --, userWsSub
          --, otherWsSub
          -- , autoCompleteSub
          uploadSuccessSub
        , uploadErrorSub
        , userWsSub
        , otherWsSub

        -- , keyDownsSub
        -- , keyUpsSub
        ]
