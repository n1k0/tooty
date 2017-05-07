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
            model ! [ Command.loadThread model.client status ]

        CloseThread ->
            { model | currentView = Update.Timeline.preferred model } ! []

        FollowAccount id ->
            model ! [ Command.follow model.client id ]

        UnfollowAccount id ->
            model ! [ Command.unfollow model.client id ]

        DeleteStatus id ->
            model ! [ Command.deleteStatus model.client id ]

        ReblogStatus id ->
            Update.Timeline.processReblog id True model
                ! [ Command.reblogStatus model.client id ]

        UnreblogStatus id ->
            Update.Timeline.processReblog id False model
                ! [ Command.unreblogStatus model.client id ]

        AddFavorite id ->
            Update.Timeline.processFavourite id True model
                ! [ Command.favouriteStatus model.client id ]

        RemoveFavorite id ->
            Update.Timeline.processFavourite id False model
                ! [ Command.unfavouriteStatus model.client id ]

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
            model ! [ Command.postStatus model.client <| toStatusRequestBody model.draft ]

        LoadAccount accountId ->
            { model
                | accountTimeline = Update.Timeline.empty "account-timeline"
                , accountFollowers = []
                , accountFollowing = []
                , accountRelationships = []
                , accountRelationship = Nothing
            }
                ! [ Command.loadAccount model.client accountId ]

        TimelineLoadNext id next ->
            Update.Timeline.markAsLoading True id model
                ! [ Command.loadNextTimeline model.client model.currentView id next ]

        ViewAccountFollowers account ->
            { model | currentView = AccountFollowersView account model.accountFollowers }
                ! [ Command.loadAccountFollowers model.client account.id ]

        ViewAccountFollowing account ->
            { model | currentView = AccountFollowingView account model.accountFollowing }
                ! [ Command.loadAccountFollowing model.client account.id ]

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
                , accountFollowing = []
                , accountFollowers = []
            }
                ! []

        FilterNotifications filter ->
            { model | notificationFilter = filter } ! []

        ScrollColumn ScrollTop column ->
            model ! [ Command.scrollColumnToTop column ]

        ScrollColumn ScrollBottom column ->
            model ! [ Command.scrollColumnToBottom column ]
