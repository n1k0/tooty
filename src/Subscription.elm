module Subscription exposing (subscriptions)

import Browser.Events
import Json.Decode as Decode
import Menu
import Ports
import Time
import Types exposing (..)


keyDecoder : KeyEvent -> Decode.Decoder Msg
keyDecoder keyEvent =
    Decode.map (toKey keyEvent) (Decode.field "key" Decode.string)


toKey : KeyEvent -> String -> Msg
toKey keyEvent string =
    case String.uncons string of
        Just ( char, "" ) ->
            KeyMsg keyEvent <| KeyCharacter char

        _ ->
            KeyMsg keyEvent <| KeyControl string


subscriptions : Model -> Sub Msg
subscriptions { currentView } =
    let
        timeSub =
            Time.every 1000 Tick

        autoCompleteSub =
            Sub.map (DraftEvent << SetAutoState) Menu.subscription

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

        keyDownsSub =
            Browser.Events.onKeyDown (keyDecoder KeyDown)

        keyUpsSub =
            Browser.Events.onKeyUp (keyDecoder KeyUp)
    in
    Sub.batch
        [ timeSub
        , autoCompleteSub
        , uploadSuccessSub
        , uploadErrorSub
        , userWsSub
        , otherWsSub
        , keyDownsSub
        , keyUpsSub
        ]
