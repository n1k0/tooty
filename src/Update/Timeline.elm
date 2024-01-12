module Update.Timeline exposing
    ( cleanUnfollow
    , deleteStatus
    , deleteStatusFromAllTimelines
    , dropAccountStatuses
    , dropNotificationsFromAccount
    , empty
    , markAsLoading
    , prepend
    , processFavourite
    , processReblog
    , removeBlock
    , removeMute
    , setLoading
    , update
    , updateStatusFromAllTimelines
    , updateStatusInTimeline
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


updateStatusFromCurrentView : Status -> Model -> CurrentView
updateStatusFromCurrentView status model =
    -- Note: account timeline is already cleaned in deleteStatusFromAllTimelines
    let
        id =
            status.id
    in
    case model.currentView of
        ThreadView thread ->
            case ( thread.status, thread.context ) of
                ( Just threadStatus, Just context ) ->
                    if threadStatus.id == id then
                        -- current thread status has been updated
                        ThreadView { thread | status = Just status }

                    else
                        let
                            updateStatuses statuses =
                                -- If we find the status in the statuses, we update it with the new value
                                List.map
                                    (\s ->
                                        if s.id == id then
                                            status

                                        else
                                            s
                                    )
                                    statuses
                        in
                        ThreadView
                            { thread
                                | context =
                                    Just <|
                                        { ancestors = updateStatuses context.ancestors
                                        , descendants = updateStatuses context.descendants
                                        }
                            }

                _ ->
                    model.currentView

        currentView ->
            currentView


deleteStatusFromCurrentView : StatusId -> Model -> CurrentView
deleteStatusFromCurrentView id model =
    -- Note: account timeline is already cleaned in deleteStatusFromAllTimelines
    case model.currentView of
        ThreadView thread ->
            case ( thread.status, thread.context ) of
                ( Just status, Just context ) ->
                    if status.id == id then
                        -- current thread status has been deleted, close it
                        LocalTimelineView

                    else
                        let
                            updateStatuses statuses =
                                List.filter (\s -> s.id /= id) statuses
                        in
                        ThreadView
                            { thread
                                | context =
                                    Just <|
                                        { ancestors = updateStatuses context.ancestors
                                        , descendants = updateStatuses context.descendants
                                        }
                            }

                _ ->
                    model.currentView

        currentView ->
            currentView


deleteStatusFromAllTimelines : StatusId -> Model -> Model
deleteStatusFromAllTimelines id ({ accountInfo } as model) =
    let
        accountTimeline =
            deleteStatus id accountInfo.timeline
    in
    { model
        | homeTimeline = deleteStatus id model.homeTimeline
        , localTimeline = deleteStatus id model.localTimeline
        , globalTimeline = deleteStatus id model.globalTimeline
        , favoriteTimeline = deleteStatus id model.favoriteTimeline
        , accountInfo = { accountInfo | timeline = accountTimeline }
        , notifications = deleteStatusFromNotifications id model.notifications
        , currentView = deleteStatusFromCurrentView id model
    }


updateStatusFromAllTimelines : Status -> Model -> Model
updateStatusFromAllTimelines status ({ accountInfo } as model) =
    let
        accountTimeline =
            updateStatusInTimeline status accountInfo.timeline
    in
    { model
        | homeTimeline = updateStatusInTimeline status model.homeTimeline
        , localTimeline = updateStatusInTimeline status model.localTimeline
        , globalTimeline = updateStatusInTimeline status model.globalTimeline
        , favoriteTimeline = updateStatusInTimeline status model.favoriteTimeline
        , accountInfo = { accountInfo | timeline = accountTimeline }
        , notifications = updateStatusFromNotifications status model.notifications
        , currentView = updateStatusFromCurrentView status model
    }


updateStatusFromNotifications : Status -> Timeline NotificationAggregate -> Timeline NotificationAggregate
updateStatusFromNotifications status notifications =
    let
        updateNotification notification =
            case notification.status of
                Just notificationStatus ->
                    if Mastodon.Helper.statusReferenced status.id notificationStatus then
                        { notification | status = Just status }

                    else
                        notification

                Nothing ->
                    notification
    in
    { notifications | entries = List.map updateNotification notifications.entries }


deleteStatusFromNotifications : StatusId -> Timeline NotificationAggregate -> Timeline NotificationAggregate
deleteStatusFromNotifications statusId notifications =
    let
        updateNotification notification =
            case notification.status of
                Just status ->
                    not <| Mastodon.Helper.statusReferenced statusId status

                Nothing ->
                    True
    in
    { notifications | entries = List.filter updateNotification notifications.entries }


deleteStatus : StatusId -> Timeline Status -> Timeline Status
deleteStatus statusId ({ entries } as timeline) =
    { timeline
        | entries = List.filter (not << Mastodon.Helper.statusReferenced statusId) entries
    }


updateStatusInTimeline : Status -> Timeline Status -> Timeline Status
updateStatusInTimeline status ({ entries } as timeline) =
    { timeline
        | entries =
            List.map
                (\oldStatus ->
                    if Mastodon.Helper.statusReferenced status.id oldStatus then
                        status

                    else
                        oldStatus
                )
                entries
    }


dropAccountStatuses : Account -> Timeline Status -> Timeline Status
dropAccountStatuses account timeline =
    let
        keep status =
            not <| Mastodon.Helper.sameAccount account status.account
    in
    { timeline | entries = List.filter keep timeline.entries }


dropNotificationsFromAccount : Account -> Timeline NotificationAggregate -> Timeline NotificationAggregate
dropNotificationsFromAccount account timeline =
    let
        keepNotification notification =
            case notification.status of
                Just status ->
                    status.account /= account

                Nothing ->
                    True
    in
    { timeline | entries = List.filter keepNotification timeline.entries }


empty : String -> Timeline a
empty id =
    { id = id
    , entries = []
    , links = Links Nothing Nothing
    , loading = True
    }


markAsLoading : Bool -> String -> Model -> Model
markAsLoading loading id ({ accountInfo } as model) =
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

        "hashtag-timeline" ->
            { model | hashtagTimeline = mark model.hashtagTimeline }

        "mutes-timeline" ->
            { model | mutes = mark model.mutes }

        "blocks-timeline" ->
            { model | blocks = mark model.blocks }

        "account-timeline" ->
            case model.currentView of
                AccountView _ ->
                    { model | accountInfo = { accountInfo | timeline = mark accountInfo.timeline } }

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

        changeFavourite oldStatus =
            { oldStatus
                | favourited = Just added
                , favourites_count =
                    if added then
                        oldStatus.favourites_count + 1

                    else if oldStatus.favourites_count > 0 then
                        oldStatus.favourites_count - 1

                    else
                        0
            }
    in
    updateWithBoolFlag status.id
        added
        (\s ->
            case s.reblog of
                Just (Reblog rebloggedStatus) ->
                    { s
                        | reblog =
                            Just
                                (Reblog <| changeFavourite rebloggedStatus)
                    }

                _ ->
                    changeFavourite status
        )
        newModel


processReblog : Status -> Bool -> Model -> Model
processReblog status added model =
    let
        changeReblog oldStatus =
            { oldStatus
                | reblogged = Just added
                , reblogs_count =
                    if added then
                        oldStatus.reblogs_count + 1

                    else if oldStatus.reblogs_count > 0 then
                        oldStatus.reblogs_count - 1

                    else
                        0
            }
    in
    updateWithBoolFlag status.id
        added
        (\s ->
            case s.reblog of
                Just (Reblog rebloggedStatus) ->
                    { s
                        | reblog =
                            Just
                                (Reblog <| changeReblog rebloggedStatus)
                    }

                _ ->
                    changeReblog status
        )
        model


removeBlock : Account -> Timeline Account -> Timeline Account
removeBlock account timeline =
    let
        keep blockedAccount =
            not <| Mastodon.Helper.sameAccount account blockedAccount
    in
    { timeline | entries = List.filter keep timeline.entries }


removeMute : Account -> Timeline Account -> Timeline Account
removeMute account timeline =
    let
        keep mutedAccount =
            not <| Mastodon.Helper.sameAccount account mutedAccount
    in
    { timeline | entries = List.filter keep timeline.entries }


setLoading : Bool -> Timeline a -> Timeline a
setLoading flag timeline =
    { timeline | loading = flag }


update : List a -> Links -> Timeline a -> Timeline a
update entries links timeline =
    { timeline
        | entries = List.concat [ timeline.entries, entries ]
        , links = links
        , loading = False
    }


updateWithBoolFlag : StatusId -> Bool -> (Status -> Status) -> Model -> Model
updateWithBoolFlag statusId _ statusUpdater ({ accountInfo } as model) =
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
        , accountInfo = { accountInfo | timeline = updateTimeline updateStatus accountInfo.timeline }
        , localTimeline = updateTimeline updateStatus model.localTimeline
        , globalTimeline = updateTimeline updateStatus model.globalTimeline
        , favoriteTimeline = updateTimeline updateStatus model.favoriteTimeline
        , notifications = updateTimeline updateNotification model.notifications
        , currentView =
            case model.currentView of
                ThreadView thread ->
                    case ( thread.status, thread.context ) of
                        ( Just status, Just context ) ->
                            ThreadView
                                { status = Just <| updateStatus status
                                , context =
                                    Just <|
                                        { ancestors = List.map updateStatus context.ancestors
                                        , descendants = List.map updateStatus context.descendants
                                        }
                                }

                        _ ->
                            model.currentView

                currentView ->
                    currentView
    }
