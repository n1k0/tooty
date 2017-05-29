module Update.WebSocket exposing (update)

import Mastodon.Decoder
import Mastodon.Helper
import Mastodon.Model exposing (..)
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


isThreadMember : Thread -> Status -> Bool
isThreadMember thread status =
    case ( thread.status, thread.context ) of
        ( Just threadStatus, Just context ) ->
            case status.in_reply_to_id of
                Nothing ->
                    False

                Just inReplyToId ->
                    let
                        threadStatusIds =
                            List.concat
                                [ [ threadStatus.id ]
                                , List.map .id context.ancestors
                                , List.map .id context.descendants
                                ]
                    in
                        List.member inReplyToId threadStatusIds

        _ ->
            False


appendToThreadDescendants : Thread -> Status -> Thread
appendToThreadDescendants ({ context } as thread) status =
    case context of
        Just context ->
            { thread
                | context =
                    Just { context | descendants = List.append context.descendants [ status ] }
            }

        _ ->
            thread


updateCurrentViewWithStatus : Status -> Model -> Model
updateCurrentViewWithStatus status ({ accountInfo } as model) =
    case model.currentView of
        ThreadView thread ->
            if isThreadMember thread status then
                { model | currentView = ThreadView (appendToThreadDescendants thread status) }
            else
                model

        AccountView _ ->
            case model.accountInfo.account of
                Just account ->
                    if Mastodon.Helper.sameAccount account status.account then
                        { model
                            | accountInfo =
                                { accountInfo
                                    | timeline = Update.Timeline.prepend status accountInfo.timeline
                                }
                        }
                    else
                        model

                Nothing ->
                    model

        _ ->
            model
