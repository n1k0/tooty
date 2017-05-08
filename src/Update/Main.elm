module Update.Main exposing (update)

import Command
import List.Extra exposing (removeAt)
import Mastodon.Model exposing (..)
import Types exposing (..)
import Update.Draft
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
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            model ! []

        Tick newTime ->
            { model
                | currentTime = newTime
                , errors = List.filter (\{ time } -> model.currentTime - time <= 10000) model.errors
            }
                ! []

        ClearError index ->
            { model | errors = removeAt index model.errors } ! []

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
            { model | currentView = Update.Timeline.preferred model } ! []

        FollowAccount id ->
            model ! [ Command.follow (List.head model.clients) id ]

        UnfollowAccount id ->
            model ! [ Command.unfollow (List.head model.clients) id ]

        DeleteStatus id ->
            model ! [ Command.deleteStatus (List.head model.clients) id ]

        ReblogStatus id ->
            Update.Timeline.processReblog id True model
                ! [ Command.reblogStatus (List.head model.clients) id ]

        UnreblogStatus id ->
            Update.Timeline.processReblog id False model
                ! [ Command.unreblogStatus (List.head model.clients) id ]

        AddFavorite id ->
            Update.Timeline.processFavourite id True model
                ! [ Command.favouriteStatus (List.head model.clients) id ]

        RemoveFavorite id ->
            Update.Timeline.processFavourite id False model
                ! [ Command.unfavouriteStatus (List.head model.clients) id ]

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
            model ! [ Command.postStatus (List.head model.clients) <| toStatusRequestBody model.draft ]

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

        UseGlobalTimeline flag ->
            let
                newModel =
                    { model | useGlobalTimeline = flag }
            in
                { newModel | currentView = Update.Timeline.preferred newModel } ! []

        CloseAccount ->
            { model
                | currentView = Update.Timeline.preferred model
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
