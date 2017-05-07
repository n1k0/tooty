module Update.WebSocket exposing (update)

import Mastodon.Decoder
import Mastodon.Helper
import Mastodon.WebSocket
import Types exposing (..)
import Update.Error exposing (..)
import Update.Timeline


update : WebSocketMsg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NewWebsocketUserMessage message ->
            case (Mastodon.Decoder.decodeWebSocketMessage message) of
                Mastodon.WebSocket.ErrorEvent error ->
                    { model | errors = addErrorNotification error model } ! []

                Mastodon.WebSocket.StatusUpdateEvent result ->
                    case result of
                        Ok status ->
                            { model | homeTimeline = Update.Timeline.prepend status model.homeTimeline } ! []

                        Err error ->
                            { model | errors = addErrorNotification error model } ! []

                Mastodon.WebSocket.StatusDeleteEvent result ->
                    case result of
                        Ok id ->
                            Update.Timeline.deleteStatusFromAllTimelines id model ! []

                        Err error ->
                            { model | errors = addErrorNotification error model } ! []

                Mastodon.WebSocket.NotificationEvent result ->
                    case result of
                        Ok notification ->
                            let
                                oldNotifications =
                                    model.notifications

                                newNotifications =
                                    { oldNotifications
                                        | entries =
                                            Mastodon.Helper.addNotificationToAggregates
                                                notification
                                                oldNotifications.entries
                                    }
                            in
                                { model | notifications = newNotifications } ! []

                        Err error ->
                            { model | errors = addErrorNotification error model } ! []

        NewWebsocketLocalMessage message ->
            case (Mastodon.Decoder.decodeWebSocketMessage message) of
                Mastodon.WebSocket.ErrorEvent error ->
                    { model | errors = addErrorNotification error model } ! []

                Mastodon.WebSocket.StatusUpdateEvent result ->
                    case result of
                        Ok status ->
                            { model | localTimeline = Update.Timeline.prepend status model.localTimeline } ! []

                        Err error ->
                            { model | errors = addErrorNotification error model } ! []

                Mastodon.WebSocket.StatusDeleteEvent result ->
                    case result of
                        Ok id ->
                            Update.Timeline.deleteStatusFromAllTimelines id model ! []

                        Err error ->
                            { model | errors = addErrorNotification error model } ! []

                _ ->
                    model ! []

        NewWebsocketGlobalMessage message ->
            case (Mastodon.Decoder.decodeWebSocketMessage message) of
                Mastodon.WebSocket.ErrorEvent error ->
                    { model | errors = addErrorNotification error model } ! []

                Mastodon.WebSocket.StatusUpdateEvent result ->
                    case result of
                        Ok status ->
                            { model | globalTimeline = Update.Timeline.prepend status model.globalTimeline } ! []

                        Err error ->
                            { model | errors = addErrorNotification error model } ! []

                Mastodon.WebSocket.StatusDeleteEvent result ->
                    case result of
                        Ok id ->
                            Update.Timeline.deleteStatusFromAllTimelines id model ! []

                        Err error ->
                            { model | errors = addErrorNotification error model } ! []

                _ ->
                    model ! []
