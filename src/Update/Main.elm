module Update.Main exposing (update)

import Command
import List.Extra exposing (removeAt)
import Mastodon.Helper exposing (extractStatusId)
import Mastodon.Model exposing (..)
import Types exposing (..)
import Update.AccountInfo
import Update.Draft
import Update.Error
import Update.Mastodon
import Update.Route
import Update.Search
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
            ( model
            , Cmd.none
            )

        UrlChanged location ->
            Update.Route.update { model | location = location }

        Back ->
            ( model
            , Cmd.none
              -- @TODO: add it again
              --, Navigation.back 1
            )

        Navigate href ->
            ( model
            , -- @TODO: add it again?
              --, Navigation.newUrl href
              Cmd.none
            )

        Tick newTime ->
            ( { model
                | currentTime = newTime
                , errors = Update.Error.cleanErrors newTime model.errors
              }
            , Cmd.none
            )

        {-
           @TODO: add it again?
           KeyMsg event code ->
               case ( event, code, model.viewer ) of
                   ( KeyDown, 27, Just _ ) ->
                       -- Esc
                       update (ViewerEvent CloseViewer) model

                   ( KeyDown, 37, Just _ ) ->
                       -- Left arrow
                       update (ViewerEvent PrevAttachment) model

                   ( KeyDown, 39, Just _ ) ->
                       -- Right arrow
                       update (ViewerEvent NextAttachment) model

                   ( KeyDown, 17, _ ) ->
                       -- Ctrl key down
                       ( { model | ctrlPressed = True }
                       , Cmd.none
                       )

                   ( KeyUp, 17, _ ) ->
                       -- Ctrl key up
                       ( { model | ctrlPressed = False }
                       , Cmd.none
                       )

                   _ ->
                       ( model
                       , Cmd.none
                       )
        -}
        ClearError index ->
            ( { model | errors = removeAt index model.errors }
            , Cmd.none
            )

        AskConfirm message onClick onCancel ->
            ( { model | confirm = Just <| Confirm message onClick onCancel }
            , Cmd.none
            )

        ConfirmCancelled onCancel ->
            update onCancel { model | confirm = Nothing }

        Confirmed onConfirm ->
            update onConfirm { model | confirm = Nothing }

        SwitchClient client ->
            let
                newClients =
                    client :: List.filter (\c -> c.token /= client.token) model.clients
            in
            ( { model
                | clients = newClients
                , homeTimeline = Update.Timeline.empty "home-timeline"
                , localTimeline = Update.Timeline.empty "local-timeline"
                , globalTimeline = Update.Timeline.empty "global-timeline"
                , favoriteTimeline = Update.Timeline.empty "favorite-timeline"
                , accountInfo = Update.AccountInfo.empty
                , mutes = Update.Timeline.empty "mutes-timeline"
                , blocks = Update.Timeline.empty "blocks-timeline"
                , notifications = Update.Timeline.empty "notifications"
                , currentView = AccountSelectorView
              }
            , Cmd.batch
                [ Command.loadUserAccount <| Just client
                , Command.loadTimelines <| Just client
                ]
            )

        LogoutClient client ->
            let
                newClients =
                    List.filter (\c -> c.token /= client.token) model.clients

                newClient =
                    List.head newClients
            in
            ( { model
                | clients = newClients
                , currentView = LocalTimelineView
              }
            , Cmd.batch
                [ Command.saveClients newClients
                , Command.loadUserAccount newClient
                , Command.loadTimelines newClient
                ]
            )

        MastodonEvent mMsg ->
            let
                ( newModel, commands ) =
                    Update.Mastodon.update mMsg model
            in
            ( newModel
            , commands
            )

        SearchEvent sMsg ->
            Update.Search.update sMsg model

        WebSocketEvent wMsg ->
            let
                ( newModel, commands ) =
                    Update.WebSocket.update wMsg model
            in
            ( newModel
            , commands
            )

        ServerChange server ->
            ( { model | server = server }
            , Cmd.none
            )

        Register ->
            ( model
            , Command.registerApp model
            )

        OpenThread status ->
            ( { model | currentView = ThreadView (Thread Nothing Nothing) }
              -- @TODO: add it again?
              --, Navigation.newUrl <| "#thread/" ++ extractStatusId status.id
            , Cmd.none
            )

        FollowAccount account ->
            ( model
            , Command.follow (List.head model.clients) account
            )

        UnfollowAccount account ->
            ( model
            , Command.unfollow (List.head model.clients) account
            )

        Mute account ->
            ( model
            , Command.mute (List.head model.clients) account
            )

        Unmute account ->
            ( model
            , Command.unmute (List.head model.clients) account
            )

        Block account ->
            ( model
            , Command.block (List.head model.clients) account
            )

        Unblock account ->
            ( model
            , Command.unblock (List.head model.clients) account
            )

        DeleteStatus id ->
            ( model
            , Command.deleteStatus (List.head model.clients) id
            )

        ReblogStatus status ->
            ( Update.Timeline.processReblog status True model
            , Command.reblogStatus (List.head model.clients) status.id
            )

        UnreblogStatus status ->
            ( Update.Timeline.processReblog status False model
            , Command.unreblogStatus (List.head model.clients) status.id
            )

        AddFavorite status ->
            ( Update.Timeline.processFavourite status True model
            , Command.favouriteStatus (List.head model.clients) status.id
            )

        RemoveFavorite status ->
            ( Update.Timeline.processFavourite status False model
            , Command.unfavouriteStatus (List.head model.clients) status.id
            )

        DraftEvent draftMsg ->
            case model.currentUser of
                Just user ->
                    Update.Draft.update draftMsg user model

                Nothing ->
                    ( model
                    , Cmd.none
                    )

        ViewerEvent viewerMsg ->
            let
                ( viewer, commands ) =
                    Update.Viewer.update viewerMsg model.viewer
            in
            ( { model | viewer = viewer }
            , commands
            )

        SubmitDraft ->
            ( model
            , Command.postStatus (List.head model.clients) <|
                toStatusRequestBody model.draft
            )

        TimelineLoadNext id next ->
            ( Update.Timeline.markAsLoading True id model
            , Command.loadNextTimeline model id next
            )

        FilterNotifications filter ->
            ( { model | notificationFilter = filter }
            , Cmd.none
            )

        ScrollColumn ScrollTop column ->
            ( model
            , Command.scrollColumnToTop column
            )

        ScrollColumn ScrollBottom column ->
            ( model
            , Command.scrollColumnToBottom column
            )

        LinkClicked _ ->
            ( model
            , Cmd.none
            )
