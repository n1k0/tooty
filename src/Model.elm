module Model exposing (..)

import Autocomplete
import Command
import List.Extra exposing (removeAt)
import Navigation
import Mastodon.Decoder
import Mastodon.Helper
import Mastodon.Http exposing (Links)
import Mastodon.Model exposing (..)
import Mastodon.WebSocket
import String.Extra
import Task
import Time
import Types exposing (..)


maxBuffer : Int
maxBuffer =
    -- Max number of entries to keep in columns
    100


extractAuthCode : Navigation.Location -> Maybe String
extractAuthCode { search } =
    case (String.split "?code=" search) of
        [ _, authCode ] ->
            Just authCode

        _ ->
            Nothing


defaultDraft : Draft
defaultDraft =
    { status = ""
    , inReplyTo = Nothing
    , spoilerText = Nothing
    , sensitive = False
    , visibility = "public"
    , statusLength = 0
    , autoState = Autocomplete.empty
    , autoAtPosition = Nothing
    , autoQuery = ""
    , autoCursorPosition = 0
    , autoMaxResults = 4
    , autoAccounts = []
    , showAutoMenu = False
    }


init : Flags -> Navigation.Location -> ( Model, Cmd Msg )
init flags location =
    let
        authCode =
            extractAuthCode location
    in
        { server = ""
        , currentTime = 0
        , registration = flags.registration
        , client = flags.client
        , homeTimeline = emptyTimeline "home-timeline"
        , localTimeline = emptyTimeline "local-timeline"
        , globalTimeline = emptyTimeline "global-timeline"
        , accountTimeline = emptyTimeline "account-timeline"
        , accountFollowers = []
        , accountFollowing = []
        , accountRelationships = []
        , accountRelationship = Nothing
        , notifications = emptyTimeline "notifications"
        , draft = defaultDraft
        , errors = []
        , location = location
        , useGlobalTimeline = False
        , viewer = Nothing
        , currentView = LocalTimelineView
        , currentUser = Nothing
        , notificationFilter = NotificationAll
        }
            ! [ Command.initCommands flags.registration flags.client authCode ]


emptyTimeline : String -> Timeline a
emptyTimeline id =
    { id = id
    , entries = []
    , links = Links Nothing Nothing
    , loading = False
    }


addErrorNotification : String -> Model -> List ErrorNotification
addErrorNotification message model =
    let
        error =
            { message = message, time = model.currentTime }
    in
        error :: model.errors


preferredTimeline : Model -> CurrentView
preferredTimeline model =
    if model.useGlobalTimeline then
        GlobalTimelineView
    else
        LocalTimelineView


errorText : Error -> String
errorText error =
    case error of
        MastodonError statusCode statusMsg errorMsg ->
            "HTTP " ++ (toString statusCode) ++ " " ++ statusMsg ++ ": " ++ errorMsg

        ServerError statusCode statusMsg errorMsg ->
            "HTTP " ++ (toString statusCode) ++ " " ++ statusMsg ++ ": " ++ errorMsg

        TimeoutError ->
            "Request timed out."

        NetworkError ->
            "Unreachable host."


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


updateTimelinesWithBoolFlag : Int -> Bool -> (Status -> Status) -> Model -> Model
updateTimelinesWithBoolFlag statusId flag statusUpdater model =
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


processFavourite : Int -> Bool -> Model -> Model
processFavourite statusId flag model =
    updateTimelinesWithBoolFlag statusId
        flag
        (\s ->
            { s
                | favourited = Just flag
                , favourites_count =
                    if flag then
                        s.favourites_count + 1
                    else if s.favourites_count > 0 then
                        s.favourites_count - 1
                    else
                        0
            }
        )
        model


processReblog : Int -> Bool -> Model -> Model
processReblog statusId flag model =
    updateTimelinesWithBoolFlag statusId
        flag
        (\s ->
            { s
                | reblogged = Just flag
                , reblogs_count =
                    if flag then
                        s.reblogs_count + 1
                    else if s.reblogs_count > 0 then
                        s.reblogs_count - 1
                    else
                        0
            }
        )
        model


deleteStatusFromTimeline : Int -> Timeline Status -> Timeline Status
deleteStatusFromTimeline statusId timeline =
    let
        update status =
            status.id
                /= statusId
                && (Mastodon.Helper.extractReblog status).id
                /= statusId
    in
        { timeline | entries = List.filter update timeline.entries }


deleteStatusFromAllTimelines : Int -> Model -> Model
deleteStatusFromAllTimelines id model =
    { model
        | homeTimeline = deleteStatusFromTimeline id model.homeTimeline
        , localTimeline = deleteStatusFromTimeline id model.localTimeline
        , globalTimeline = deleteStatusFromTimeline id model.globalTimeline
        , accountTimeline = deleteStatusFromTimeline id model.accountTimeline
        , notifications = deleteStatusFromNotifications id model.notifications
        , currentView = deleteStatusFromCurrentView id model
    }


deleteStatusFromNotifications : Int -> Timeline NotificationAggregate -> Timeline NotificationAggregate
deleteStatusFromNotifications statusId notifications =
    let
        update notification =
            case notification.status of
                Just status ->
                    status.id
                        /= statusId
                        && (Mastodon.Helper.extractReblog status).id
                        /= statusId

                Nothing ->
                    True
    in
        { notifications | entries = List.filter update notifications.entries }


deleteStatusFromCurrentView : Int -> Model -> CurrentView
deleteStatusFromCurrentView id model =
    -- Note: account timeline is already cleaned in deleteStatusFromAllTimelines
    case model.currentView of
        ThreadView thread ->
            if thread.status.id == id then
                -- the current thread status as been deleted, close it
                preferredTimeline model
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


{-| Update viewed account relationships as well as the relationship with the
current connected user, both according to the "following" status provided.
-}
processFollowEvent : Relationship -> Bool -> Model -> Model
processFollowEvent relationship flag model =
    let
        updateRelationship r =
            if r.id == relationship.id then
                { r | following = flag }
            else
                r

        accountRelationships =
            model.accountRelationships |> List.map updateRelationship

        accountRelationship =
            case model.accountRelationship of
                Just accountRelationship ->
                    if accountRelationship.id == relationship.id then
                        Just { relationship | following = flag }
                    else
                        model.accountRelationship

                Nothing ->
                    Nothing
    in
        { model
            | accountRelationships = accountRelationships
            , accountRelationship = accountRelationship
        }


updateDraft : DraftMsg -> Account -> Model -> ( Model, Cmd Msg )
updateDraft draftMsg currentUser model =
    let
        draft =
            model.draft
    in
        case draftMsg of
            ClearDraft ->
                { model | draft = defaultDraft }
                    ! [ Command.updateDomStatus defaultDraft.status ]

            ToggleSpoiler enabled ->
                let
                    newDraft =
                        { draft
                            | spoilerText =
                                if enabled then
                                    Just ""
                                else
                                    Nothing
                        }
                in
                    { model | draft = newDraft } ! []

            UpdateSensitive sensitive ->
                { model | draft = { draft | sensitive = sensitive } } ! []

            UpdateSpoiler spoilerText ->
                { model | draft = { draft | spoilerText = Just spoilerText } } ! []

            UpdateVisibility visibility ->
                { model | draft = { draft | visibility = visibility } } ! []

            UpdateReplyTo status ->
                let
                    newStatus =
                        Mastodon.Helper.getReplyPrefix currentUser status
                in
                    { model
                        | draft =
                            { draft
                                | inReplyTo = Just status
                                , status = newStatus
                                , sensitive = Maybe.withDefault False status.sensitive
                                , spoilerText =
                                    if status.spoiler_text == "" then
                                        Nothing
                                    else
                                        Just status.spoiler_text
                                , visibility = status.visibility
                            }
                    }
                        ! [ Command.focusId "status"
                          , Command.updateDomStatus newStatus
                          ]

            UpdateInputInformation { status, selectionStart } ->
                let
                    stringToPos =
                        String.slice 0 selectionStart status

                    atPosition =
                        case (String.right 1 stringToPos) of
                            "@" ->
                                Just selectionStart

                            " " ->
                                Nothing

                            _ ->
                                model.draft.autoAtPosition

                    query =
                        case atPosition of
                            Just position ->
                                String.slice position (String.length stringToPos) stringToPos

                            Nothing ->
                                ""

                    newDraft =
                        { draft
                            | status = status
                            , statusLength = String.length status
                            , autoCursorPosition = selectionStart
                            , autoAtPosition = atPosition
                            , autoQuery = query
                            , showAutoMenu =
                                showAutoMenu
                                    draft.autoAccounts
                                    draft.autoAtPosition
                                    draft.autoQuery
                        }
                in
                    { model | draft = newDraft }
                        ! if query /= "" && atPosition /= Nothing then
                            [ Command.searchAccounts model.client query model.draft.autoMaxResults False ]
                          else
                            []

            SelectAccount id ->
                let
                    account =
                        List.filter (\account -> toString account.id == id) draft.autoAccounts
                            |> List.head

                    stringToAtPos =
                        case draft.autoAtPosition of
                            Just atPosition ->
                                String.slice 0 atPosition draft.status

                            _ ->
                                ""

                    stringToPos =
                        String.slice 0 draft.autoCursorPosition draft.status

                    newStatus =
                        case draft.autoAtPosition of
                            Just atPosition ->
                                String.Extra.replaceSlice
                                    (case account of
                                        Just a ->
                                            a.acct ++ " "

                                        Nothing ->
                                            ""
                                    )
                                    atPosition
                                    ((String.length draft.autoQuery) + atPosition)
                                    draft.status

                            _ ->
                                ""

                    newDraft =
                        { draft
                            | status = newStatus
                            , autoAtPosition = Nothing
                            , autoQuery = ""
                            , autoState = Autocomplete.empty
                            , autoAccounts = []
                            , showAutoMenu = False
                        }
                in
                    { model | draft = newDraft }
                        -- As we are using defaultValue, we need to update the textarea
                        -- using a port.
                        ! [ Command.updateDomStatus newStatus ]

            SetAutoState autoMsg ->
                let
                    ( newState, maybeMsg ) =
                        Autocomplete.update
                            autocompleteUpdateConfig
                            autoMsg
                            draft.autoMaxResults
                            draft.autoState
                            (acceptableAccounts draft.autoQuery draft.autoAccounts)

                    newModel =
                        { model | draft = { draft | autoState = newState } }
                in
                    case maybeMsg of
                        Nothing ->
                            newModel ! []

                        Just updateMsg ->
                            update updateMsg newModel

            CloseAutocomplete ->
                let
                    newDraft =
                        { draft
                            | showAutoMenu = False
                            , autoState = Autocomplete.reset autocompleteUpdateConfig draft.autoState
                        }
                in
                    { model | draft = newDraft } ! []

            ResetAutocomplete toTop ->
                let
                    newDraft =
                        { draft
                            | autoState =
                                if toTop then
                                    Autocomplete.resetToFirstItem
                                        autocompleteUpdateConfig
                                        (acceptableAccounts draft.autoQuery draft.autoAccounts)
                                        draft.autoMaxResults
                                        draft.autoState
                                else
                                    Autocomplete.resetToLastItem
                                        autocompleteUpdateConfig
                                        (acceptableAccounts draft.autoQuery draft.autoAccounts)
                                        draft.autoMaxResults
                                        draft.autoState
                        }
                in
                    { model | draft = newDraft } ! []


updateViewer : ViewerMsg -> Maybe Viewer -> ( Maybe Viewer, Cmd Msg )
updateViewer viewerMsg viewer =
    case viewerMsg of
        CloseViewer ->
            Nothing ! []

        OpenViewer attachments attachment ->
            (Just <| Viewer attachments attachment) ! []


markTimelineLoading : Bool -> String -> Model -> Model
markTimelineLoading loading id model =
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

            "account-timeline" ->
                case model.currentView of
                    AccountView account ->
                        { model | accountTimeline = mark model.accountTimeline }

                    _ ->
                        model

            _ ->
                model


updateTimeline : Bool -> List a -> Links -> Timeline a -> Timeline a
updateTimeline append entries links timeline =
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


prependToTimeline : a -> Timeline a -> Timeline a
prependToTimeline entry timeline =
    { timeline | entries = entry :: timeline.entries }


processMastodonEvent : MastodonMsg -> Model -> ( Model, Cmd Msg )
processMastodonEvent msg model =
    case msg of
        AccessToken result ->
            case result of
                Ok { decoded } ->
                    let
                        client =
                            Client decoded.server decoded.accessToken
                    in
                        { model | client = Just client }
                            ! [ Command.loadTimelines <| Just client
                              , Command.saveClient client
                              , Navigation.modifyUrl model.location.pathname
                              , Navigation.reload
                              ]

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountFollowed result ->
            case result of
                Ok { decoded } ->
                    processFollowEvent decoded True model ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountUnfollowed result ->
            case result of
                Ok { decoded } ->
                    processFollowEvent decoded False model ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AppRegistered result ->
            case result of
                Ok { decoded } ->
                    { model | registration = Just decoded }
                        ! [ Command.saveRegistration decoded
                          , Command.navigateToAuthUrl decoded
                          ]

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        ContextLoaded status result ->
            case result of
                Ok { decoded } ->
                    { model | currentView = ThreadView (Thread status decoded) }
                        ! [ Command.scrollToThreadStatus <| toString status.id ]

                Err error ->
                    { model
                        | currentView = preferredTimeline model
                        , errors = addErrorNotification (errorText error) model
                    }
                        ! []

        CurrentUser result ->
            case result of
                Ok { decoded } ->
                    { model | currentUser = Just decoded } ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        FavoriteAdded result ->
            case result of
                Ok _ ->
                    model ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        FavoriteRemoved result ->
            case result of
                Ok _ ->
                    model ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        LocalTimeline append result ->
            case result of
                Ok { decoded, links } ->
                    { model | localTimeline = updateTimeline append decoded links model.localTimeline } ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        Notifications append result ->
            case result of
                Ok { decoded, links } ->
                    let
                        aggregated =
                            Mastodon.Helper.aggregateNotifications decoded
                    in
                        { model | notifications = updateTimeline append aggregated links model.notifications } ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        GlobalTimeline append result ->
            case result of
                Ok { decoded, links } ->
                    { model | globalTimeline = updateTimeline append decoded links model.globalTimeline } ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        Reblogged result ->
            case result of
                Ok _ ->
                    model ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        StatusPosted _ ->
            { model | draft = defaultDraft }
                ! [ Command.scrollColumnToTop "home-timeline"
                  , Command.updateDomStatus defaultDraft.status
                  ]

        StatusDeleted result ->
            case result of
                Ok { decoded } ->
                    deleteStatusFromAllTimelines decoded model ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        Unreblogged result ->
            case result of
                Ok _ ->
                    model ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountReceived result ->
            case result of
                Ok { decoded } ->
                    { model | currentView = AccountView decoded }
                        ! [ Command.loadAccountTimeline model.client decoded.id model.accountTimeline.links.next ]

                Err error ->
                    { model
                        | currentView = preferredTimeline model
                        , errors = addErrorNotification (errorText error) model
                    }
                        ! []

        AccountTimeline append result ->
            case result of
                Ok { decoded, links } ->
                    { model | accountTimeline = updateTimeline append decoded links model.accountTimeline } ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountFollowers result ->
            case result of
                Ok { decoded } ->
                    -- TODO: store next link
                    { model | accountFollowers = decoded }
                        ! [ Command.loadRelationships model.client <| List.map .id decoded ]

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountFollowing result ->
            case result of
                Ok { decoded } ->
                    -- TODO: store next link
                    { model | accountFollowing = decoded }
                        ! [ Command.loadRelationships model.client <| List.map .id decoded ]

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountRelationship result ->
            case result of
                Ok { decoded } ->
                    case decoded of
                        [ relationship ] ->
                            { model | accountRelationship = Just relationship } ! []

                        _ ->
                            model ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountRelationships result ->
            case result of
                Ok { decoded } ->
                    -- TODO: store next link
                    { model | accountRelationships = decoded } ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        HomeTimeline append result ->
            case result of
                Ok { decoded, links } ->
                    { model | homeTimeline = updateTimeline append decoded links model.homeTimeline } ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AutoSearch result ->
            let
                draft =
                    model.draft
            in
                case result of
                    Ok { decoded } ->
                        { model
                            | draft =
                                { draft
                                    | showAutoMenu =
                                        showAutoMenu
                                            decoded
                                            draft.autoAtPosition
                                            draft.autoQuery
                                    , autoAccounts = decoded
                                }
                        }
                            -- Force selection of the first item after each
                            -- Successfull request
                            ! [ Task.perform identity (Task.succeed ((DraftEvent << ResetAutocomplete) True)) ]

                    Err error ->
                        { model
                            | draft = { draft | showAutoMenu = False }
                            , errors = addErrorNotification (errorText error) model
                        }
                            ! []


showAutoMenu : List Account -> Maybe Int -> String -> Bool
showAutoMenu accounts atPosition query =
    case ( List.isEmpty accounts, atPosition, query ) of
        ( _, Nothing, _ ) ->
            False

        ( True, _, _ ) ->
            False

        ( _, _, "" ) ->
            False

        ( False, Just _, _ ) ->
            True


processWebSocketMsg : WebSocketMsg -> Model -> ( Model, Cmd Msg )
processWebSocketMsg msg model =
    case msg of
        NewWebsocketUserMessage message ->
            case (Mastodon.Decoder.decodeWebSocketMessage message) of
                Mastodon.WebSocket.ErrorEvent error ->
                    { model | errors = addErrorNotification error model } ! []

                Mastodon.WebSocket.StatusUpdateEvent result ->
                    case result of
                        Ok status ->
                            { model | homeTimeline = prependToTimeline status model.homeTimeline } ! []

                        Err error ->
                            { model | errors = addErrorNotification error model } ! []

                Mastodon.WebSocket.StatusDeleteEvent result ->
                    case result of
                        Ok id ->
                            deleteStatusFromAllTimelines id model ! []

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
                            { model | localTimeline = prependToTimeline status model.localTimeline } ! []

                        Err error ->
                            { model | errors = addErrorNotification error model } ! []

                Mastodon.WebSocket.StatusDeleteEvent result ->
                    case result of
                        Ok id ->
                            deleteStatusFromAllTimelines id model ! []

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
                            { model | globalTimeline = prependToTimeline status model.globalTimeline } ! []

                        Err error ->
                            { model | errors = addErrorNotification error model } ! []

                Mastodon.WebSocket.StatusDeleteEvent result ->
                    case result of
                        Ok id ->
                            deleteStatusFromAllTimelines id model ! []

                        Err error ->
                            { model | errors = addErrorNotification error model } ! []

                _ ->
                    model ! []


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            model ! []

        Tick newTime ->
            { model
                | currentTime = newTime
                , errors = List.filter (\{ time } -> model.currentTime - time <= 3000) model.errors
            }
                ! []

        ClearError index ->
            { model | errors = removeAt index model.errors } ! []

        MastodonEvent msg ->
            let
                ( newModel, commands ) =
                    processMastodonEvent msg model
            in
                newModel ! [ commands ]

        WebSocketEvent msg ->
            let
                ( newModel, commands ) =
                    processWebSocketMsg msg model
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
            { model | currentView = preferredTimeline model } ! []

        FollowAccount id ->
            model ! [ Command.follow model.client id ]

        UnfollowAccount id ->
            model ! [ Command.unfollow model.client id ]

        DeleteStatus id ->
            model ! [ Command.deleteStatus model.client id ]

        ReblogStatus id ->
            processReblog id True model ! [ Command.reblogStatus model.client id ]

        UnreblogStatus id ->
            processReblog id False model ! [ Command.unreblogStatus model.client id ]

        AddFavorite id ->
            processFavourite id True model ! [ Command.favouriteStatus model.client id ]

        RemoveFavorite id ->
            processFavourite id False model ! [ Command.unfavouriteStatus model.client id ]

        DraftEvent draftMsg ->
            case model.currentUser of
                Just user ->
                    updateDraft draftMsg user model

                Nothing ->
                    model ! []

        ViewerEvent viewerMsg ->
            let
                ( viewer, commands ) =
                    updateViewer viewerMsg model.viewer
            in
                { model | viewer = viewer } ! [ commands ]

        SubmitDraft ->
            model ! [ Command.postStatus model.client <| toStatusRequestBody model.draft ]

        LoadAccount accountId ->
            { model
                | accountTimeline = emptyTimeline "account-timeline"
                , accountFollowers = []
                , accountFollowing = []
                , accountRelationships = []
                , accountRelationship = Nothing
            }
                ! [ Command.loadAccount model.client accountId ]

        TimelineLoadNext id next ->
            markTimelineLoading True id model
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
                { newModel | currentView = preferredTimeline newModel } ! []

        CloseAccount ->
            { model
                | currentView = preferredTimeline model
                , accountTimeline = emptyTimeline "account-timeline"
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


autocompleteUpdateConfig : Autocomplete.UpdateConfig Msg Account
autocompleteUpdateConfig =
    Autocomplete.updateConfig
        { toId = .id >> toString
        , onKeyDown =
            \code maybeId ->
                if code == 38 || code == 40 then
                    Nothing
                else if code == 13 then
                    Maybe.map (DraftEvent << SelectAccount) maybeId
                else
                    Just <| (DraftEvent << ResetAutocomplete) False
        , onTooLow = Just <| (DraftEvent << ResetAutocomplete) True
        , onTooHigh = Just <| (DraftEvent << ResetAutocomplete) False
        , onMouseEnter = \_ -> Nothing
        , onMouseLeave = \_ -> Nothing
        , onMouseClick = \id -> Just <| (DraftEvent << SelectAccount) id
        , separateSelections = False
        }


acceptableAccounts : String -> List Account -> List Account
acceptableAccounts query accounts =
    let
        lowerQuery =
            String.toLower query
    in
        if query == "" then
            []
        else
            List.filter (String.contains lowerQuery << String.toLower << .username) accounts


subscriptions : Model -> Sub Msg
subscriptions { client, currentView } =
    let
        timeSub =
            Time.every Time.millisecond Tick

        userWsSub =
            Mastodon.WebSocket.subscribeToWebSockets
                client
                Mastodon.WebSocket.UserStream
                NewWebsocketUserMessage
                |> Sub.map WebSocketEvent

        otherWsSub =
            if currentView == GlobalTimelineView then
                Mastodon.WebSocket.subscribeToWebSockets
                    client
                    Mastodon.WebSocket.GlobalPublicStream
                    NewWebsocketGlobalMessage
                    |> Sub.map WebSocketEvent
            else if currentView == LocalTimelineView then
                Mastodon.WebSocket.subscribeToWebSockets
                    client
                    Mastodon.WebSocket.LocalPublicStream
                    NewWebsocketLocalMessage
                    |> Sub.map WebSocketEvent
            else
                Sub.none

        autoCompleteSub =
            Sub.map (DraftEvent << SetAutoState) Autocomplete.subscription
    in
        [ timeSub, userWsSub, otherWsSub, autoCompleteSub ]
            |> Sub.batch
