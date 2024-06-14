module Update.Main exposing (update)

import Browser
import Browser.Navigation as Navigation
import Command
import InfiniteScroll
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
import Url


toStatusRequestBody : Draft -> StatusRequestBody
toStatusRequestBody draft =
    { status = draft.status
    , in_reply_to_id =
        case draft.type_ of
            InReplyTo status ->
                Just status.id

            _ ->
                Nothing
    , spoiler_text = draft.spoilerText
    , sensitive = draft.sensitive
    , visibility = draft.visibility
    , media_ids = List.map .id draft.attachments
    }


toStatusEditRequestBody : Draft -> StatusEditRequestBody
toStatusEditRequestBody draft =
    { status = draft.status
    , spoiler_text = draft.spoilerText
    , sensitive = draft.sensitive
    , media_ids = List.map .id draft.attachments
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        AddFavorite status ->
            ( Update.Timeline.processFavourite status True model
            , Command.favouriteStatus (List.head model.clients) status.id
            )

        AskConfirm message onClick onCancel ->
            ( { model | confirm = Just <| Confirm message onClick onCancel }
            , Cmd.none
            )

        Back ->
            ( model
            , Navigation.back model.key 1
            )

        Block account ->
            ( model
            , Command.block (List.head model.clients) account
            )

        ClearError index ->
            ( { model | errors = removeAt index model.errors }
            , Cmd.none
            )

        ClientNameChange clientName ->
            ( { model | clientName = clientName }
            , Cmd.none
            )

        ConfirmCancelled onCancel ->
            update onCancel { model | confirm = Nothing }

        Confirmed onConfirm ->
            update onConfirm { model | confirm = Nothing }

        DeleteStatus id ->
            ( model
            , Command.deleteStatus (List.head model.clients) id
            )

        DraftEvent draftMsg ->
            Update.Draft.update draftMsg model

        FilterNotifications filter ->
            ( { model | notificationFilter = filter }
            , Cmd.none
            )

        FollowAccount account ->
            ( model
            , Command.follow (List.head model.clients) account
            )

        InfiniteScrollMsg scrollElement msg_ ->
            case scrollElement of
                ScrollHomeTimeline ->
                    let
                        ( infiniteScroll, cmd ) =
                            InfiniteScroll.update (InfiniteScrollMsg scrollElement) msg_ model.infiniteScrollHome
                    in
                    ( { model
                        | homeTimeline = Update.Timeline.setLoading True model.homeTimeline
                        , infiniteScrollHome = infiniteScroll
                      }
                    , cmd
                    )

                ScrollNotifications ->
                    let
                        ( infiniteScroll, cmd ) =
                            InfiniteScroll.update (InfiniteScrollMsg scrollElement) msg_ model.infiniteScrollNotifications
                    in
                    ( { model
                        | notifications = Update.Timeline.setLoading True model.notifications
                        , infiniteScrollNotifications = infiniteScroll
                      }
                    , cmd
                    )

                ScrollLocalTimeline ->
                    let
                        ( infiniteScroll, cmd ) =
                            InfiniteScroll.update (InfiniteScrollMsg scrollElement) msg_ model.infiniteScrollNotifications
                    in
                    ( { model
                        | localTimeline = Update.Timeline.setLoading True model.localTimeline
                        , infiniteScrollLocal = infiniteScroll
                      }
                    , cmd
                    )

                _ ->
                    ( model, Cmd.none )

        KeyMsg event keyType ->
            case ( event, keyType, model.viewer ) of
                -- Esc
                ( KeyDown, KeyControl "Escape", Just _ ) ->
                    update (ViewerEvent CloseViewer) model

                ( KeyDown, KeyControl "ArrowLeft", Just _ ) ->
                    -- Left arrow
                    update (ViewerEvent PrevAttachment) model

                ( KeyDown, KeyControl "ArrowRight", Just _ ) ->
                    -- Right arrow
                    update (ViewerEvent NextAttachment) model

                --     -- Ctrl key down
                ( KeyDown, KeyControl "Control", _ ) ->
                    ( { model | ctrlPressed = True }
                    , Cmd.none
                    )

                ( KeyUp, KeyControl "Control", _ ) ->
                    -- Ctrl key up
                    ( { model | ctrlPressed = False }
                    , Cmd.none
                    )

                -- Always reset ctrlPressed to try to fix https://github.com/n1k0/tooty/issues/215
                _ ->
                    ( { model | ctrlPressed = False }
                    , Cmd.none
                    )

        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    case url.fragment of
                        Nothing ->
                            ( model, Cmd.none )

                        Just _ ->
                            ( model
                            , Navigation.pushUrl model.key (Url.toString url)
                            )

                Browser.External href ->
                    ( model
                    , Navigation.load href
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

        Mute account ->
            ( model
            , Command.mute (List.head model.clients) account
            )

        Navigate href ->
            ( model
            , Navigation.pushUrl model.key href
            )

        NoOp ->
            ( model
            , Cmd.none
            )

        OpenThread status ->
            ( { model | currentView = ThreadView (Thread Nothing Nothing) }
            , Navigation.pushUrl model.key ("#thread/" ++ extractStatusId status.id)
            )

        Register ->
            ( model
            , Command.registerApp model
            )

        ReblogStatus status ->
            ( Update.Timeline.processReblog status True model
            , Command.reblogStatus (List.head model.clients) status.id
            )

        RemoveFavorite status ->
            ( Update.Timeline.processFavourite status False model
            , Command.unfavouriteStatus (List.head model.clients) status.id
            )

        SearchEvent sMsg ->
            Update.Search.update sMsg model

        ServerChange server ->
            ( { model | server = server }
            , Cmd.none
            )

        ScrollColumn ScrollBottom column ->
            ( model
            , Command.scrollColumnToBottom column
            )

        ScrollColumn ScrollTop column ->
            ( model
            , Command.scrollColumnToTop column
            )

        SubmitDraft ->
            ( model
            , case model.draft.type_ of
                Editing editStatus ->
                    Command.editStatus (List.head model.clients) editStatus.status.id <|
                        toStatusEditRequestBody model.draft

                _ ->
                    Command.postStatus (List.head model.clients) <|
                        toStatusRequestBody model.draft
            )

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

        Tick newTime ->
            ( { model
                | currentTime = newTime
                , errors = Update.Error.cleanErrors newTime model.errors
              }
            , Cmd.none
            )

        TimelineLoadNext id next ->
            ( Update.Timeline.markAsLoading True id model
            , Command.loadNextTimeline model.clients model.currentView model.accountInfo id next
            )

        Unblock account ->
            ( model
            , Command.unblock (List.head model.clients) account
            )

        UnfollowAccount account ->
            ( model
            , Command.unfollow (List.head model.clients) account
            )

        Unmute account ->
            ( model
            , Command.unmute (List.head model.clients) account
            )

        UnreblogStatus status ->
            ( Update.Timeline.processReblog status False model
            , Command.unreblogStatus (List.head model.clients) status.id
            )

        UrlChanged location ->
            Update.Route.update { model | location = location }

        ViewerEvent viewerMsg ->
            let
                ( viewer, commands ) =
                    Update.Viewer.update viewerMsg model.viewer
            in
            ( { model | viewer = viewer }
            , commands
            )

        WebSocketEvent wMsg ->
            let
                ( newModel, commands ) =
                    Update.WebSocket.update wMsg model
            in
            ( newModel
            , commands
            )
