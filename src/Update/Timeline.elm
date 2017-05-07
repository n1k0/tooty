module Update.Timeline
    exposing
        ( deleteStatusFromAllTimelines
        , deleteStatus
        , empty
        , preferred
        , prepend
        , update
        , updateWithBoolFlag
        )

import Mastodon.Helper
import Mastodon.Http exposing (Links)
import Mastodon.Model exposing (..)
import Types exposing (..)


deleteStatusFromCurrentView : Int -> Model -> CurrentView
deleteStatusFromCurrentView id model =
    -- Note: account timeline is already cleaned in deleteStatusFromAllTimelines
    case model.currentView of
        ThreadView thread ->
            if thread.status.id == id then
                -- the current thread status as been deleted, close it
                preferred model
            else
                let
                    update statuses =
                        List.filter (\s -> s.id /= id) statuses
                in
                    ThreadView
                        { thread
                            | context =
                                { ancestors = update thread.context.ancestors
                                , descendants = update thread.context.descendants
                                }
                        }

        currentView ->
            currentView


deleteStatusFromAllTimelines : Int -> Model -> Model
deleteStatusFromAllTimelines id model =
    { model
        | homeTimeline = deleteStatus id model.homeTimeline
        , localTimeline = deleteStatus id model.localTimeline
        , globalTimeline = deleteStatus id model.globalTimeline
        , accountTimeline = deleteStatus id model.accountTimeline
        , notifications = deleteStatusFromNotifications id model.notifications
        , currentView = deleteStatusFromCurrentView id model
    }


deleteStatusFromNotifications : Int -> Timeline NotificationAggregate -> Timeline NotificationAggregate
deleteStatusFromNotifications statusId notifications =
    let
        update notification =
            case notification.status of
                Just status ->
                    not <| Mastodon.Helper.statusReferenced statusId status

                Nothing ->
                    True
    in
        { notifications | entries = List.filter update notifications.entries }


deleteStatus : Int -> Timeline Status -> Timeline Status
deleteStatus statusId ({ entries } as timeline) =
    { timeline
        | entries = List.filter (not << Mastodon.Helper.statusReferenced statusId) entries
    }


empty : String -> Timeline a
empty id =
    { id = id
    , entries = []
    , links = Links Nothing Nothing
    , loading = False
    }


preferred : Model -> CurrentView
preferred model =
    if model.useGlobalTimeline then
        GlobalTimelineView
    else
        LocalTimelineView


prepend : a -> Timeline a -> Timeline a
prepend entry timeline =
    { timeline | entries = entry :: timeline.entries }


update : Bool -> List a -> Links -> Timeline a -> Timeline a
update append entries links timeline =
    let
        newEntries =
            if append then
                List.concat [ timeline.entries, entries ]
            else
                entries
    in
        { timeline
            | entries = newEntries
            , links = links
            , loading = False
        }


updateWithBoolFlag : Int -> Bool -> (Status -> Status) -> Model -> Model
updateWithBoolFlag statusId flag statusUpdater model =
    let
        updateStatus status =
            if (Mastodon.Helper.extractReblog status).id == statusId then
                statusUpdater status
            else
                status

        updateNotification notification =
            case notification.status of
                Just status ->
                    { notification | status = Just <| updateStatus status }

                Nothing ->
                    notification

        updateTimeline updateEntry timeline =
            { timeline | entries = List.map updateEntry timeline.entries }
    in
        { model
            | homeTimeline = updateTimeline updateStatus model.homeTimeline
            , accountTimeline = updateTimeline updateStatus model.accountTimeline
            , localTimeline = updateTimeline updateStatus model.localTimeline
            , globalTimeline = updateTimeline updateStatus model.globalTimeline
            , notifications = updateTimeline updateNotification model.notifications
            , currentView =
                case model.currentView of
                    ThreadView thread ->
                        ThreadView
                            { status = updateStatus thread.status
                            , context =
                                { ancestors = List.map updateStatus thread.context.ancestors
                                , descendants = List.map updateStatus thread.context.descendants
                                }
                            }

                    currentView ->
                        currentView
        }
