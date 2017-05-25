module Update.Timeline
    exposing
        ( cleanUnfollow
        , deleteStatusFromAllTimelines
        , deleteStatus
        , empty
        , markAsLoading
        , prepend
        , processReblog
        , processFavourite
        , update
        , updateWithBoolFlag
        )

import Mastodon.Helper
import Mastodon.Http exposing (Links)
import Mastodon.Model exposing (..)
import Types exposing (..)


type alias CurrentUser =
    Account


{-| Remove statuses from a given account when they're not a direct mention to
the current user. This is typically used after an account has been unfollowed.
-}
cleanUnfollow : Account -> CurrentUser -> Timeline Status -> Timeline Status
cleanUnfollow account currentUser timeline =
    let
        keep status =
            if Mastodon.Helper.sameAccount account status.account then
                case List.head status.mentions of
                    Just mention ->
                        mention.id == currentUser.id && mention.acct == currentUser.acct

                    Nothing ->
                        False
            else
                True
    in
        { timeline | entries = List.filter keep timeline.entries }


deleteStatusFromCurrentView : Int -> Model -> CurrentView
deleteStatusFromCurrentView id model =
    -- Note: account timeline is already cleaned in deleteStatusFromAllTimelines
    case model.currentView of
        ThreadView thread ->
            if thread.status.id == id then
                -- the current thread status as been deleted, close it
                LocalTimelineView
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
        , favoriteTimeline = deleteStatus id model.favoriteTimeline
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


markAsLoading : Bool -> String -> Model -> Model
markAsLoading loading id model =
    let
        mark timeline =
            { timeline | loading = loading }
    in
        case id of
            "notifications" ->
                { model | notifications = mark model.notifications }

            "home-timeline" ->
                { model | homeTimeline = mark model.homeTimeline }

            "local-timeline" ->
                { model | localTimeline = mark model.localTimeline }

            "global-timeline" ->
                { model | globalTimeline = mark model.globalTimeline }

            "favorite-timeline" ->
                { model | favoriteTimeline = mark model.favoriteTimeline }

            "account-timeline" ->
                case model.currentView of
                    AccountView account ->
                        { model | accountTimeline = mark model.accountTimeline }

                    _ ->
                        model

            _ ->
                model


prepend : a -> Timeline a -> Timeline a
prepend entry timeline =
    { timeline | entries = entry :: timeline.entries }


processFavourite : Status -> Bool -> Model -> Model
processFavourite status added model =
    let
        favoriteTimeline =
            if added then
                prepend status model.favoriteTimeline
            else
                deleteStatus status.id model.favoriteTimeline

        newModel =
            { model | favoriteTimeline = favoriteTimeline }
    in
        updateWithBoolFlag status.id
            added
            (\s ->
                { s
                    | favourited = Just added
                    , favourites_count =
                        if added then
                            s.favourites_count + 1
                        else if s.favourites_count > 0 then
                            s.favourites_count - 1
                        else
                            0
                }
            )
            newModel


processReblog : Status -> Bool -> Model -> Model
processReblog status added model =
    updateWithBoolFlag status.id
        added
        (\s ->
            { s
                | reblogged = Just added
                , reblogs_count =
                    if added then
                        s.reblogs_count + 1
                    else if s.reblogs_count > 0 then
                        s.reblogs_count - 1
                    else
                        0
            }
        )
        model


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
            , favoriteTimeline = updateTimeline updateStatus model.favoriteTimeline
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
