module Update.WebSocket exposing (update)

import Command
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
            case Mastodon.Decoder.decodeWebSocketMessage message of
                Mastodon.WebSocket.ErrorEvent error ->
                    ( { model | errors = addErrorNotification error model }
                    , Cmd.none
                    )

                Mastodon.WebSocket.StatusNewEvent result ->
                    case result of
                        Ok status ->
                            ( model
                                |> (\m -> { m | homeTimeline = Update.Timeline.prepend status m.homeTimeline })
                                |> updateCurrentViewWithStatus status
                            , Cmd.none
                            )

                        Err error ->
                            ( { model | errors = addErrorNotification error model }
                            , Cmd.none
                            )

                Mastodon.WebSocket.StatusUpdateEvent result ->
                    case result of
                        Ok status ->
                            ( Update.Timeline.updateStatusFromAllTimelines status model
                            , Cmd.none
                            )

                        Err error ->
                            ( { model | errors = addErrorNotification error model }
                            , Cmd.none
                            )

                Mastodon.WebSocket.StatusDeleteEvent id ->
                    ( Update.Timeline.deleteStatusFromAllTimelines id model
                    , Cmd.none
                    )

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
                            ( { model | notifications = newNotifications }
                            , Command.notifyNotification notification
                            )

                        Err error ->
                            ( { model | errors = addErrorNotification error model }
                            , Cmd.none
                            )

        NewWebsocketLocalMessage message ->
            case Mastodon.Decoder.decodeWebSocketMessage message of
                Mastodon.WebSocket.ErrorEvent error ->
                    ( { model | errors = addErrorNotification error model }
                    , Cmd.none
                    )

                Mastodon.WebSocket.StatusNewEvent result ->
                    case result of
                        Ok status ->
                            ( model
                                |> (\m -> { m | localTimeline = Update.Timeline.prepend status m.localTimeline })
                                |> updateCurrentViewWithStatus status
                            , Cmd.none
                            )

                        Err error ->
                            ( { model | errors = addErrorNotification error model }
                            , Cmd.none
                            )

                Mastodon.WebSocket.StatusUpdateEvent result ->
                    case result of
                        Ok status ->
                            ( Update.Timeline.updateStatusFromAllTimelines status model
                            , Cmd.none
                            )

                        Err error ->
                            ( { model | errors = addErrorNotification error model }
                            , Cmd.none
                            )

                Mastodon.WebSocket.StatusDeleteEvent id ->
                    ( Update.Timeline.deleteStatusFromAllTimelines id model
                    , Cmd.none
                    )

                _ ->
                    ( model
                    , Cmd.none
                    )

        NewWebsocketGlobalMessage message ->
            case Mastodon.Decoder.decodeWebSocketMessage message of
                Mastodon.WebSocket.ErrorEvent error ->
                    ( { model | errors = addErrorNotification error model }
                    , Cmd.none
                    )

                Mastodon.WebSocket.StatusNewEvent result ->
                    case result of
                        Ok status ->
                            ( model
                                |> (\m -> { m | globalTimeline = Update.Timeline.prepend status m.globalTimeline })
                                |> updateCurrentViewWithStatus status
                            , Cmd.none
                            )

                        Err error ->
                            ( { model | errors = addErrorNotification error model }
                            , Cmd.none
                            )

                Mastodon.WebSocket.StatusUpdateEvent result ->
                    case result of
                        Ok status ->
                            ( Update.Timeline.updateStatusFromAllTimelines status model
                            , Cmd.none
                            )

                        Err error ->
                            ( { model | errors = addErrorNotification error model }
                            , Cmd.none
                            )

                Mastodon.WebSocket.StatusDeleteEvent id ->
                    ( Update.Timeline.deleteStatusFromAllTimelines id model
                    , Cmd.none
                    )

                _ ->
                    ( model
                    , Cmd.none
                    )


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
        Just c ->
            { thread
                | context =
                    Just { c | descendants = List.append c.descendants [ status ] }
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
