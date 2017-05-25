module Update.Main exposing (update)

import Command
import List.Extra exposing (removeAt)
import Mastodon.Model exposing (..)
import Types exposing (..)
import Update.Draft
import Update.Error
import Update.Mastodon
import Update.Timeline
import Update.Viewer
import Update.WebSocket


toStatusRequestBody : Draft -> StatusRequestBody
toStatusRequestBody draft =
    { status = draft.status
    , in_reply_to_id =
        case draft.inReplyTo of
            Just status ->
                Just status.id

            Nothing ->
                Nothing
    , spoiler_text = draft.spoilerText
    , sensitive = draft.sensitive
    , visibility = draft.visibility
    , media_ids = List.map .id draft.attachments
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            model ! []

        Tick newTime ->
            { model
                | currentTime = newTime
                , errors = Update.Error.cleanErrors newTime model.errors
            }
                ! []

        ClearError index ->
            { model | errors = removeAt index model.errors } ! []

        AskConfirm message onClick onCancel ->
            { model | confirm = Just <| Confirm message onClick onCancel } ! []

        ConfirmCancelled onCancel ->
            update onCancel { model | confirm = Nothing }

        Confirmed onConfirm ->
            update onConfirm { model | confirm = Nothing }

        SetView view ->
            case view of
                AccountSelectorView ->
                    { model | currentView = view, server = "" } ! []

                FavoriteTimelineView ->
                    { model
                        | currentView = view
                        , favoriteTimeline = Update.Timeline.setLoading True model.favoriteTimeline
                    }
                        ! [ Command.loadFavoriteTimeline (List.head model.clients) Nothing ]

                BlocksView ->
                    { model
                        | currentView = view
                        , blocks = Update.Timeline.setLoading True model.blocks
                    }
                        ! [ Command.loadBlocks (List.head model.clients) Nothing ]

                MutesView ->
                    { model
                        | currentView = view
                        , mutes = Update.Timeline.setLoading True model.mutes
                    }
                        ! [ Command.loadMutes (List.head model.clients) Nothing ]

                _ ->
                    { model | currentView = view } ! []

        SwitchClient client ->
            let
                newClients =
                    client :: (List.filter (\c -> c.token /= client.token) model.clients)
            in
                { model
                    | clients = newClients
                    , homeTimeline = Update.Timeline.empty "home-timeline"
                    , localTimeline = Update.Timeline.empty "local-timeline"
                    , globalTimeline = Update.Timeline.empty "global-timeline"
                    , favoriteTimeline = Update.Timeline.empty "favorite-timeline"
                    , accountTimeline = Update.Timeline.empty "account-timeline"
                    , accountFollowers = Update.Timeline.empty "account-followers"
                    , accountFollowing = Update.Timeline.empty "account-following"
                    , notifications = Update.Timeline.empty "notifications"
                    , accountRelationships = []
                    , accountRelationship = Nothing
                    , currentView = LocalTimelineView
                }
                    ! [ Command.loadUserAccount <| Just client
                      , Command.loadTimelines <| Just client
                      ]

        LogoutClient client ->
            let
                newClients =
                    List.filter (\c -> c.token /= client.token) model.clients

                newClient =
                    List.head newClients
            in
                { model
                    | clients = newClients
                    , currentView = LocalTimelineView
                }
                    ! [ Command.saveClients newClients
                      , Command.loadUserAccount newClient
                      , Command.loadTimelines newClient
                      ]

        MastodonEvent msg ->
            let
                ( newModel, commands ) =
                    Update.Mastodon.update msg model
            in
                newModel ! [ commands ]

        WebSocketEvent msg ->
            let
                ( newModel, commands ) =
                    Update.WebSocket.update msg model
            in
                newModel ! [ commands ]

        ServerChange server ->
            { model | server = server } ! []

        UrlChange location ->
            model ! []

        Register ->
            model ! [ Command.registerApp model ]

        OpenThread status ->
            model ! [ Command.loadThread (List.head model.clients) status ]

        CloseThread ->
            { model | currentView = LocalTimelineView } ! []

        FollowAccount account ->
            model ! [ Command.follow (List.head model.clients) account ]

        UnfollowAccount account ->
            model ! [ Command.unfollow (List.head model.clients) account ]

        Mute account ->
            model ! [ Command.mute (List.head model.clients) account ]

        Unmute account ->
            model ! [ Command.unmute (List.head model.clients) account ]

        Block account ->
            model ! [ Command.block (List.head model.clients) account ]

        Unblock account ->
            model ! [ Command.unblock (List.head model.clients) account ]

        DeleteStatus id ->
            model ! [ Command.deleteStatus (List.head model.clients) id ]

        ReblogStatus status ->
            Update.Timeline.processReblog status True model
                ! [ Command.reblogStatus (List.head model.clients) status.id ]

        UnreblogStatus status ->
            Update.Timeline.processReblog status False model
                ! [ Command.unreblogStatus (List.head model.clients) status.id ]

        AddFavorite status ->
            Update.Timeline.processFavourite status True model
                ! [ Command.favouriteStatus (List.head model.clients) status.id ]

        RemoveFavorite status ->
            Update.Timeline.processFavourite status False model
                ! [ Command.unfavouriteStatus (List.head model.clients) status.id ]

        DraftEvent draftMsg ->
            case model.currentUser of
                Just user ->
                    Update.Draft.update draftMsg user model

                Nothing ->
                    model ! []

        ViewerEvent viewerMsg ->
            let
                ( viewer, commands ) =
                    Update.Viewer.update viewerMsg model.viewer
            in
                { model | viewer = viewer } ! [ commands ]

        SubmitDraft ->
            model
                ! [ Command.postStatus (List.head model.clients) <|
                        toStatusRequestBody model.draft
                  ]

        LoadAccount accountId ->
            { model
                | accountTimeline = Update.Timeline.empty "account-timeline"
                , accountFollowers = Update.Timeline.empty "account-followers"
                , accountFollowing = Update.Timeline.empty "account-following"
                , accountRelationships = []
                , accountRelationship = Nothing
            }
                ! [ Command.loadAccount (List.head model.clients) accountId ]

        TimelineLoadNext id next ->
            Update.Timeline.markAsLoading True id model
                ! [ Command.loadNextTimeline (List.head model.clients) model.currentView id next ]

        ViewAccountFollowers account ->
            { model
                | currentView = AccountFollowersView account model.accountFollowers
                , accountRelationships = []
            }
                ! [ Command.loadAccountFollowers (List.head model.clients) account.id Nothing ]

        ViewAccountFollowing account ->
            { model
                | currentView = AccountFollowingView account model.accountFollowing
                , accountRelationships = []
            }
                ! [ Command.loadAccountFollowing (List.head model.clients) account.id Nothing ]

        ViewAccountStatuses account ->
            { model | currentView = AccountView account } ! []

        CloseAccount ->
            { model
                | currentView = LocalTimelineView
                , accountTimeline = Update.Timeline.empty "account-timeline"
                , accountFollowing = Update.Timeline.empty "account-following"
                , accountFollowers = Update.Timeline.empty "account-followers"
            }
                ! []

        FilterNotifications filter ->
            { model | notificationFilter = filter } ! []

        ScrollColumn ScrollTop column ->
            model ! [ Command.scrollColumnToTop column ]

        ScrollColumn ScrollBottom column ->
            model ! [ Command.scrollColumnToBottom column ]
