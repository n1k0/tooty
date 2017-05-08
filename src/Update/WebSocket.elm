module Update.WebSocket exposing (update)

import Mastodon.Decoder
import Mastodon.Helper
import Mastodon.Model exposing (..)
import Mastodon.WebSocket
import Types exposing (..)
import Update.Error exposing (..)
import Update.Timeline


updateCurrentViewWithStatus : Status -> Model -> Model
updateCurrentViewWithStatus status model =
    case model.currentView of
        ThreadView thread ->
            case status.in_reply_to_id of
                Nothing ->
                    model

                Just inReplyToId ->
                    let
                        threadStatusIds =
                            List.concat
                                [ [ thread.status.id ]
                                , List.map .id thread.context.ancestors
                                , List.map .id thread.context.descendants
                                ]

                        threadMember =
                            List.member inReplyToId threadStatusIds
                    in
                        if threadMember then
                            let
                                context =
                                    thread.context

                                newContext =
                                    { context | descendants = List.concat [ thread.context.descendants, [ status ] ] }

                                newView =
                                    ThreadView { thread | context = newContext }
                            in
                                { model | currentView = newView }
                        else
                            model

        AccountView account ->
            if Mastodon.Helper.sameAccount account status.account then
                { model | accountTimeline = Update.Timeline.prepend status model.accountTimeline }
            else
                model

        _ ->
            model


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
                            (model
                                |> (\m -> { m | homeTimeline = Update.Timeline.prepend status m.homeTimeline })
                                |> updateCurrentViewWithStatus status
                            )
                                ! []

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
                            (model
                                |> (\m -> { m | localTimeline = Update.Timeline.prepend status m.localTimeline })
                                |> updateCurrentViewWithStatus status
                            )
                                ! []

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
                            (model
                                |> (\m -> { m | globalTimeline = Update.Timeline.prepend status m.globalTimeline })
                                |> updateCurrentViewWithStatus status
                            )
                                ! []

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
