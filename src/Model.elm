module Model exposing (..)

import Autocomplete
import Command
import Navigation
import Mastodon.Decoder
import Mastodon.Helper
import Mastodon.Http exposing (Links)
import Mastodon.Model exposing (..)
import Mastodon.WebSocket
import String.Extra
import Task
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
        , registration = flags.registration
        , client = flags.client
        , userTimeline = emptyTimeline "home-timeline"
        , localTimeline = emptyTimeline "local-timeline"
        , globalTimeline = emptyTimeline "global-timeline"
        , accountTimeline = emptyTimeline "account-timeline"
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
        }
            ! [ Command.initCommands flags.registration flags.client authCode ]


emptyTimeline : String -> Timeline
emptyTimeline id =
    { id = id
    , statuses = []
    , links = Links Nothing Nothing
    }


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
        update status =
            if (Mastodon.Helper.extractReblog status).id == statusId then
                statusUpdater status
            else
                status

        updateTimeline timeline =
            { timeline | statuses = List.map update timeline.statuses }
    in
        { model
            | userTimeline = updateTimeline model.userTimeline
            , accountTimeline = updateTimeline model.accountTimeline
            , localTimeline = updateTimeline model.localTimeline
            , globalTimeline = updateTimeline model.globalTimeline
            , currentView =
                case model.currentView of
                    ThreadView thread ->
                        ThreadView
                            { status = update thread.status
                            , context =
                                { ancestors = List.map update thread.context.ancestors
                                , descendants = List.map update thread.context.descendants
                                }
                            }

                    currentView ->
                        currentView
        }


processFavourite : Int -> Bool -> Model -> Model
processFavourite statusId flag model =
    -- TODO: update notifications too
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
    -- TODO: update notifications too
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


deleteStatusFromTimeline : Int -> Timeline -> Timeline
deleteStatusFromTimeline statusId timeline =
    let
        update status =
            status.id
                /= statusId
                && (Mastodon.Helper.extractReblog status).id
                /= statusId
    in
        { timeline | statuses = List.filter update timeline.statuses }


deleteStatusFromAllTimelines : Int -> Model -> Model
deleteStatusFromAllTimelines id model =
    -- TODO: delete from thread timeline & notifications
    { model
        | userTimeline = deleteStatusFromTimeline id model.userTimeline
        , localTimeline = deleteStatusFromTimeline id model.localTimeline
        , globalTimeline = deleteStatusFromTimeline id model.globalTimeline
        , accountTimeline = deleteStatusFromTimeline id model.accountTimeline
        , currentView = deleteStatusFromThread id model
    }


deleteStatusFromThread : Int -> Model -> CurrentView
deleteStatusFromThread id model =
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
                            updateAutocompleteConfig
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

            ResetAutocomplete toTop ->
                let
                    newDraft =
                        { draft
                            | autoState =
                                if toTop then
                                    Autocomplete.resetToFirstItem
                                        updateAutocompleteConfig
                                        (acceptableAccounts draft.autoQuery draft.autoAccounts)
                                        draft.autoMaxResults
                                        draft.autoState
                                else
                                    Autocomplete.resetToLastItem
                                        updateAutocompleteConfig
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


updateTimeline : Bool -> List Status -> Links -> Timeline -> Timeline
updateTimeline append statuses links timeline =
    let
        newStatuses =
            if append then
                List.concat [ timeline.statuses, statuses ]
            else
                statuses
    in
        { timeline | statuses = newStatuses, links = links }


prependStatusToTimeline : Status -> Timeline -> Timeline
prependStatusToTimeline status timeline =
    { timeline | statuses = status :: timeline.statuses }


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
                    { model | errors = (errorText error) :: model.errors } ! []

        AccountFollowed result ->
            case result of
                Ok { decoded } ->
                    processFollowEvent decoded True model ! []

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        AccountUnfollowed result ->
            case result of
                Ok { decoded } ->
                    processFollowEvent decoded False model ! []

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        AppRegistered result ->
            case result of
                Ok { decoded } ->
                    { model | registration = Just decoded }
                        ! [ Command.saveRegistration decoded
                          , Command.navigateToAuthUrl decoded
                          ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        ContextLoaded status result ->
            case result of
                Ok { decoded } ->
                    { model | currentView = ThreadView (Thread status decoded) }
                        ! [ Command.scrollToThreadStatus <| toString status.id ]

                Err error ->
                    { model
                        | currentView = preferredTimeline model
                        , errors = (errorText error) :: model.errors
                    }
                        ! []

        CurrentUser result ->
            case result of
                Ok { decoded } ->
                    { model | currentUser = Just decoded } ! []

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        FavoriteAdded result ->
            case result of
                Ok _ ->
                    model ! [ Command.loadNotifications model.client ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        FavoriteRemoved result ->
            case result of
                Ok _ ->
                    model ! [ Command.loadNotifications model.client ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        LocalTimeline append result ->
            case result of
                Ok { decoded, links } ->
                    { model | localTimeline = updateTimeline append decoded links model.localTimeline } ! []

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        Notifications result ->
            case result of
                Ok { decoded } ->
                    -- TODO: store next link
                    { model | notifications = Mastodon.Helper.aggregateNotifications decoded } ! []

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        GlobalTimeline append result ->
            case result of
                Ok { decoded, links } ->
                    { model | globalTimeline = updateTimeline append decoded links model.globalTimeline } ! []

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        Reblogged result ->
            case result of
                Ok _ ->
                    model ! [ Command.loadNotifications model.client ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

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
                    { model | errors = (errorText error) :: model.errors } ! []

        Unreblogged result ->
            case result of
                Ok _ ->
                    model ! [ Command.loadNotifications model.client ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        AccountReceived result ->
            case result of
                Ok { decoded } ->
                    { model | currentView = AccountView decoded }
                        ! [ Command.loadAccountTimeline model.client decoded.id model.userTimeline.links.next ]

                Err error ->
                    { model
                        | currentView = preferredTimeline model
                        , errors = (errorText error) :: model.errors
                    }
                        ! []

        AccountTimeline append result ->
            case result of
                Ok { decoded, links } ->
                    { model | accountTimeline = updateTimeline append decoded links model.accountTimeline } ! []

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        AccountFollowers result ->
            case result of
                Ok { decoded } ->
                    -- TODO: store next link
                    { model | accountFollowers = decoded }
                        ! [ Command.loadRelationships model.client <| List.map .id decoded ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        AccountFollowing result ->
            case result of
                Ok { decoded } ->
                    -- TODO: store next link
                    { model | accountFollowing = decoded }
                        ! [ Command.loadRelationships model.client <| List.map .id decoded ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        AccountRelationship result ->
            case result of
                Ok { decoded } ->
                    case decoded of
                        [ relationship ] ->
                            { model | accountRelationship = Just relationship } ! []

                        _ ->
                            model ! []

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        AccountRelationships result ->
            case result of
                Ok { decoded } ->
                    -- TODO: store next link
                    { model | accountRelationships = decoded } ! []

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        UserTimeline append result ->
            case result of
                Ok { decoded, links } ->
                    { model | userTimeline = updateTimeline append decoded links model.userTimeline } ! []

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

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
                            , errors = (errorText error) :: model.errors
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
                    { model | errors = error :: model.errors } ! []

                Mastodon.WebSocket.StatusUpdateEvent result ->
                    case result of
                        Ok status ->
                            { model | userTimeline = prependStatusToTimeline status model.userTimeline } ! []

                        Err error ->
                            { model | errors = error :: model.errors } ! []

                Mastodon.WebSocket.StatusDeleteEvent result ->
                    case result of
                        Ok id ->
                            deleteStatusFromAllTimelines id model ! []

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
                                { model | notifications = notifications } ! []

                        Err error ->
                            { model | errors = error :: model.errors } ! []

        NewWebsocketLocalMessage message ->
            case (Mastodon.Decoder.decodeWebSocketMessage message) of
                Mastodon.WebSocket.ErrorEvent error ->
                    { model | errors = error :: model.errors } ! []

                Mastodon.WebSocket.StatusUpdateEvent result ->
                    case result of
                        Ok status ->
                            { model | userTimeline = prependStatusToTimeline status model.localTimeline } ! []

                        Err error ->
                            { model | errors = error :: model.errors } ! []

                Mastodon.WebSocket.StatusDeleteEvent result ->
                    case result of
                        Ok id ->
                            deleteStatusFromAllTimelines id model ! []

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
                            { model | userTimeline = prependStatusToTimeline status model.globalTimeline } ! []

                        Err error ->
                            { model | errors = error :: model.errors } ! []

                Mastodon.WebSocket.StatusDeleteEvent result ->
                    case result of
                        Ok id ->
                            deleteStatusFromAllTimelines id model ! []

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
                | accountTimeline = emptyTimeline "account-timeline"
                , accountFollowers = []
                , accountFollowing = []
                , accountRelationships = []
                , accountRelationship = Nothing
            }
                ! [ Command.loadAccount model.client accountId ]

        LoadNext timeline ->
            -- TODO: at some point we should have a generic timeline loading feature
            case timeline.id of
                "home-timeline" ->
                    model ! [ Command.loadUserTimeline model.client timeline.links.next ]

                "local-timeline" ->
                    model ! [ Command.loadLocalTimeline model.client timeline.links.next ]

                "global-timeline" ->
                    model ! [ Command.loadGlobalTimeline model.client timeline.links.next ]

                "account-timeline" ->
                    case model.currentView of
                        AccountView account ->
                            model ! [ Command.loadAccountTimeline model.client account.id timeline.links.next ]

                        _ ->
                            model ! []

                _ ->
                    model ! []

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


updateAutocompleteConfig : Autocomplete.UpdateConfig Msg Account
updateAutocompleteConfig =
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
                        ++ (if model.currentView == GlobalTimelineView then
                                [ Mastodon.WebSocket.subscribeToWebSockets
                                    client
                                    Mastodon.WebSocket.GlobalPublicStream
                                    NewWebsocketGlobalMessage
                                ]
                            else if model.currentView == LocalTimelineView then
                                [ Mastodon.WebSocket.subscribeToWebSockets
                                    client
                                    Mastodon.WebSocket.LocalPublicStream
                                    NewWebsocketLocalMessage
                                ]
                            else
                                []
                           )
            in
                Sub.batch <|
                    (List.map (Sub.map WebSocketEvent) subs)
                        ++ [ Sub.map (DraftEvent << SetAutoState) Autocomplete.subscription ]

        Nothing ->
            Sub.batch []
