module Model exposing (..)

import Autocomplete
import Command
import Navigation
import Mastodon.Decoder
import Mastodon.Helper
import Mastodon.Model exposing (..)
import Mastodon.WebSocket
import Ports
import String.Extra
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
    , in_reply_to = Nothing
    , spoiler_text = Nothing
    , sensitive = False
    , visibility = "public"
    }


init : Flags -> Navigation.Location -> ( Model, Cmd Msg )
init flags location =
    let
        authCode =
            extractAuthCode location
    in
        { server = ""
        , registration = flags.registration
        , client = flags.client
        , userTimeline = []
        , localTimeline = []
        , globalTimeline = []
        , accountTimeline = []
        , accountFollowers = []
        , accountFollowing = []
        , accountRelationships = []
        , accountRelationship = Nothing
        , notifications = []
        , draft = defaultDraft
        , errors = []
        , location = location
        , useGlobalTimeline = False
        , viewer = Nothing
        , currentView = LocalTimelineView
        , currentUser = Nothing
        , notificationFilter = NotificationAll
        , autoState = Autocomplete.empty
        , autoAtPosition = Nothing
        , autoQuery = ""
        , autoCursorPosition = 0
        , autoMaxResults = 4
        , autoAccounts = []
        , showAutoMenu = False
        }
            ! [ Command.initCommands flags.registration flags.client authCode ]


preferredTimeline : Model -> CurrentView
preferredTimeline model =
    if model.useGlobalTimeline then
        GlobalTimelineView
    else
        LocalTimelineView


truncate : List a -> List a
truncate entries =
    List.take maxBuffer entries


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
        case draft.in_reply_to of
            Just status ->
                Just status.id

            Nothing ->
                Nothing
    , spoiler_text = draft.spoiler_text
    , sensitive = draft.sensitive
    , visibility = draft.visibility
    }


updateTimelinesWithBoolFlag : Int -> Bool -> (Status -> Status) -> Model -> Model
updateTimelinesWithBoolFlag statusId flag statusUpdater model =
    let
        update flag status =
            if (Mastodon.Helper.extractReblog status).id == statusId then
                statusUpdater status
            else
                status
    in
        { model
            | userTimeline = List.map (update flag) model.userTimeline
            , localTimeline = List.map (update flag) model.localTimeline
            , globalTimeline = List.map (update flag) model.globalTimeline
        }


processFavourite : Int -> Bool -> Model -> Model
processFavourite statusId flag model =
    -- TODO: update notifications too
    updateTimelinesWithBoolFlag statusId flag (\s -> { s | favourited = Just flag }) model


processReblog : Int -> Bool -> Model -> Model
processReblog statusId flag model =
    -- TODO: update notifications too
    updateTimelinesWithBoolFlag statusId flag (\s -> { s | reblogged = Just flag }) model


deleteStatusFromTimeline : Int -> List Status -> List Status
deleteStatusFromTimeline statusId timeline =
    timeline
        |> List.filter
            (\s ->
                s.id
                    /= statusId
                    && (Mastodon.Helper.extractReblog s).id
                    /= statusId
            )


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
                    ! [ Ports.setStatus { id = "status", status = defaultDraft.status } ]

            ToggleSpoiler enabled ->
                let
                    newDraft =
                        { draft
                            | spoiler_text =
                                if enabled then
                                    Just ""
                                else
                                    Nothing
                        }
                in
                    { model | draft = newDraft } ! []

            UpdateSensitive sensitive ->
                { model | draft = { draft | sensitive = sensitive } } ! []

            UpdateSpoiler spoiler_text ->
                { model | draft = { draft | spoiler_text = Just spoiler_text } } ! []

            UpdateVisibility visibility ->
                { model | draft = { draft | visibility = visibility } } ! []

            UpdateReplyTo status ->
                { model
                    | draft =
                        { draft
                            | in_reply_to = Just status
                            , status = Mastodon.Helper.getReplyPrefix currentUser status
                            , sensitive = Maybe.withDefault False status.sensitive
                            , spoiler_text =
                                if status.spoiler_text == "" then
                                    Nothing
                                else
                                    Just status.spoiler_text
                            , visibility = status.visibility
                        }
                }
                    ! [ Command.focusId "status" ]

            UpdateInputInformation { status, selectionStart } ->
                let
                    newModel =
                        { model
                            | draft = { draft | status = status }
                            , autoCursorPosition = selectionStart
                        }

                    stringToPos =
                        (String.slice 0 newModel.autoCursorPosition status)

                    atPosition =
                        (case (String.right 1 stringToPos) of
                            "@" ->
                                Just newModel.autoCursorPosition

                            " " ->
                                Nothing

                            _ ->
                                model.autoAtPosition
                        )

                    query =
                        (case atPosition of
                            Just position ->
                                String.slice position (String.length stringToPos) stringToPos

                            Nothing ->
                                ""
                        )

                    showMenu =
                        not << List.isEmpty <| acceptableAccounts query model.autoAccounts
                in
                    { newModel
                        | autoAtPosition = atPosition
                        , autoQuery = query
                        , showAutoMenu = showMenu
                    }
                        ! [ Command.searchAccounts model.client query model.autoMaxResults False ]

            SelectAccount id ->
                let
                    account =
                        List.filter (\account -> toString account.id == id) model.autoAccounts
                            |> List.head

                    stringToAtPos =
                        case model.autoAtPosition of
                            Just atPosition ->
                                String.slice 0 atPosition model.draft.status

                            _ ->
                                ""

                    stringToPos =
                        String.slice 0 model.autoCursorPosition model.draft.status

                    newStatus =
                        case model.autoAtPosition of
                            Just atPosition ->
                                (String.Extra.replaceSlice
                                    (case account of
                                        Just a ->
                                            a.acct ++ " "

                                        Nothing ->
                                            ""
                                    )
                                    atPosition
                                    ((String.length model.autoQuery) + atPosition)
                                    model.draft.status
                                )

                            _ ->
                                ""
                in
                    { model
                        | draft = { draft | status = newStatus }
                        , autoAtPosition = Nothing
                        , autoQuery = ""
                        , autoState = Autocomplete.empty
                        , showAutoMenu = False
                    }
                        -- As we are using defaultValue, we need to update the textarea
                        -- using a port.
                        ! [ Ports.setStatus { id = "status", status = newStatus } ]


updateViewer : ViewerMsg -> Maybe Viewer -> ( Maybe Viewer, Cmd Msg )
updateViewer viewerMsg viewer =
    case viewerMsg of
        CloseViewer ->
            Nothing ! []

        OpenViewer attachments attachment ->
            (Just <| Viewer attachments attachment) ! []


processMastodonEvent : MastodonMsg -> Model -> ( Model, Cmd Msg )
processMastodonEvent msg model =
    case msg of
        AccessToken result ->
            case result of
                Ok { server, accessToken } ->
                    let
                        client =
                            Client server accessToken
                    in
                        { model | client = Just client }
                            ! [ Command.loadTimelines <| Just client
                              , Navigation.modifyUrl model.location.pathname
                              , Command.saveClient client
                              ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        AccountFollowed result ->
            case result of
                Ok relationship ->
                    processFollowEvent relationship True model ! []

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        AccountUnfollowed result ->
            case result of
                Ok relationship ->
                    processFollowEvent relationship False model ! []

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        AppRegistered result ->
            case result of
                Ok registration ->
                    { model | registration = Just registration }
                        ! [ Command.saveRegistration registration
                          , Command.navigateToAuthUrl registration
                          ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        ContextLoaded status result ->
            case result of
                Ok context ->
                    { model | currentView = ThreadView (Thread status context) }
                        ! [ Command.scrollColumnToBottom "thread" ]

                Err error ->
                    { model
                        | currentView = preferredTimeline model
                        , errors = (errorText error) :: model.errors
                    }
                        ! []

        CurrentUser result ->
            case result of
                Ok currentUser ->
                    { model | currentUser = Just currentUser } ! []

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        FavoriteAdded result ->
            case result of
                Ok status ->
                    model ! [ Command.loadNotifications model.client ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        FavoriteRemoved result ->
            case result of
                Ok status ->
                    model ! [ Command.loadNotifications model.client ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        LocalTimeline result ->
            case result of
                Ok localTimeline ->
                    { model | localTimeline = localTimeline } ! []

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        Notifications result ->
            case result of
                Ok notifications ->
                    { model | notifications = Mastodon.Helper.aggregateNotifications notifications } ! []

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        GlobalTimeline result ->
            case result of
                Ok globalTimeline ->
                    { model | globalTimeline = globalTimeline } ! []

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        Reblogged result ->
            case result of
                Ok status ->
                    model ! [ Command.loadNotifications model.client ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        StatusPosted _ ->
            { model | draft = defaultDraft }
                ! [ Command.scrollColumnToTop "home" ]

        StatusDeleted result ->
            case result of
                Ok id ->
                    { model
                        | userTimeline = deleteStatusFromTimeline id model.userTimeline
                        , localTimeline = deleteStatusFromTimeline id model.localTimeline
                        , globalTimeline = deleteStatusFromTimeline id model.globalTimeline
                    }
                        ! []

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        Unreblogged result ->
            case result of
                Ok status ->
                    model ! [ Command.loadNotifications model.client ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        AccountReceived result ->
            case result of
                Ok account ->
                    { model | currentView = AccountView account }
                        ! [ Command.loadAccountTimeline model.client account.id ]

                Err error ->
                    { model
                        | currentView = preferredTimeline model
                        , errors = (errorText error) :: model.errors
                    }
                        ! []

        AccountTimeline result ->
            case result of
                Ok statuses ->
                    { model | accountTimeline = statuses } ! []

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        AccountFollowers result ->
            case result of
                Ok followers ->
                    { model | accountFollowers = followers }
                        ! [ Command.loadRelationships model.client <| List.map .id followers ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        AccountFollowing result ->
            case result of
                Ok following ->
                    { model | accountFollowing = following }
                        ! [ Command.loadRelationships model.client <| List.map .id following ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        AccountRelationship result ->
            case result of
                Ok [ relationship ] ->
                    { model | accountRelationship = Just relationship } ! []

                Ok _ ->
                    model ! []

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        AccountRelationships result ->
            case result of
                Ok relationships ->
                    { model | accountRelationships = relationships } ! []

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        UserTimeline result ->
            case result of
                Ok userTimeline ->
                    { model | userTimeline = userTimeline } ! []

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        AutoSearch result ->
            case result of
                Ok accounts ->
                    { model | showAutoMenu = True, autoAccounts = accounts }
                        ! []

                Err error ->
                    { model
                        | showAutoMenu = False
                        , errors = (errorText error) :: model.errors
                    }
                        ! []


processWebSocketMsg : WebSocketMsg -> Model -> ( Model, Cmd Msg )
processWebSocketMsg msg model =
    case msg of
        NewWebsocketUserMessage message ->
            case (Mastodon.Decoder.decodeWebSocketMessage message) of
                Mastodon.WebSocket.ErrorEvent error ->
                    { model | errors = error :: model.errors } ! []

                Mastodon.WebSocket.StatusUpdateEvent result ->
                    case result of
                        Ok status ->
                            { model | userTimeline = truncate (status :: model.userTimeline) } ! []

                        Err error ->
                            { model | errors = error :: model.errors } ! []

                Mastodon.WebSocket.StatusDeleteEvent result ->
                    case result of
                        Ok id ->
                            { model | userTimeline = deleteStatusFromTimeline id model.userTimeline } ! []

                        Err error ->
                            { model | errors = error :: model.errors } ! []

                Mastodon.WebSocket.NotificationEvent result ->
                    case result of
                        Ok notification ->
                            let
                                notifications =
                                    Mastodon.Helper.addNotificationToAggregates
                                        notification
                                        model.notifications
                            in
                                { model | notifications = truncate notifications } ! []

                        Err error ->
                            { model | errors = error :: model.errors } ! []

        NewWebsocketLocalMessage message ->
            case (Mastodon.Decoder.decodeWebSocketMessage message) of
                Mastodon.WebSocket.ErrorEvent error ->
                    { model | errors = error :: model.errors } ! []

                Mastodon.WebSocket.StatusUpdateEvent result ->
                    case result of
                        Ok status ->
                            { model | localTimeline = truncate (status :: model.localTimeline) } ! []

                        Err error ->
                            { model | errors = error :: model.errors } ! []

                Mastodon.WebSocket.StatusDeleteEvent result ->
                    case result of
                        Ok id ->
                            { model | localTimeline = deleteStatusFromTimeline id model.localTimeline } ! []

                        Err error ->
                            { model | errors = error :: model.errors } ! []

                _ ->
                    model ! []

        NewWebsocketGlobalMessage message ->
            case (Mastodon.Decoder.decodeWebSocketMessage message) of
                Mastodon.WebSocket.ErrorEvent error ->
                    { model | errors = error :: model.errors } ! []

                Mastodon.WebSocket.StatusUpdateEvent result ->
                    case result of
                        Ok status ->
                            { model | globalTimeline = truncate (status :: model.globalTimeline) } ! []

                        Err error ->
                            { model | errors = error :: model.errors } ! []

                Mastodon.WebSocket.StatusDeleteEvent result ->
                    case result of
                        Ok id ->
                            { model | globalTimeline = deleteStatusFromTimeline id model.globalTimeline } ! []

                        Err error ->
                            { model | errors = error :: model.errors } ! []

                _ ->
                    model ! []


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            model ! []

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
                | accountTimeline = []
                , accountFollowers = []
                , accountFollowing = []
                , accountRelationships = []
                , accountRelationship = Nothing
            }
                ! [ Command.loadAccount model.client accountId ]

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
                { model | currentView = preferredTimeline newModel } ! []

        CloseAccount ->
            { model
                | currentView = preferredTimeline model
                , accountTimeline = []
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

        SetAutoState autoMsg ->
            let
                ( newState, maybeMsg ) =
                    Autocomplete.update updateConfig autoMsg model.autoMaxResults model.autoState (acceptableAccounts model.autoQuery model.autoAccounts)

                newModel =
                    { model | autoState = newState }
            in
                case maybeMsg of
                    Nothing ->
                        newModel ! []

                    Just updateMsg ->
                        update updateMsg newModel

        ResetAutocomplete toTop ->
            { model
                | autoState =
                    if toTop then
                        Autocomplete.resetToFirstItem updateConfig (acceptableAccounts model.autoQuery model.autoAccounts) model.autoMaxResults model.autoState
                    else
                        Autocomplete.resetToLastItem updateConfig (acceptableAccounts model.autoQuery model.autoAccounts) model.autoMaxResults model.autoState
            }
                ! []


updateConfig : Autocomplete.UpdateConfig Msg Account
updateConfig =
    Autocomplete.updateConfig
        { toId = .id >> toString
        , onKeyDown =
            \code maybeId ->
                if code == 38 || code == 40 then
                    Nothing
                else if code == 13 then
                    Maybe.map (DraftEvent << SelectAccount) maybeId
                else
                    Just <| ResetAutocomplete False
        , onTooLow = Just <| ResetAutocomplete True
        , onTooHigh = Just <| ResetAutocomplete False
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
subscriptions model =
    case model.client of
        Just client ->
            let
                subs =
                    [ Mastodon.WebSocket.subscribeToWebSockets
                        client
                        Mastodon.WebSocket.UserStream
                        NewWebsocketUserMessage
                    ]
                        ++ (if model.useGlobalTimeline then
                                [ Mastodon.WebSocket.subscribeToWebSockets
                                    client
                                    Mastodon.WebSocket.GlobalPublicStream
                                    NewWebsocketGlobalMessage
                                ]
                            else
                                [ Mastodon.WebSocket.subscribeToWebSockets
                                    client
                                    Mastodon.WebSocket.LocalPublicStream
                                    NewWebsocketLocalMessage
                                ]
                           )
            in
                Sub.batch <| List.map (Sub.map WebSocketEvent) subs

        Nothing ->
            Sub.batch []
