module Model exposing (..)

import Dom
import Json.Encode as Encode
import Navigation
import Mastodon.Decoder
import Mastodon.Encoder
import Mastodon.Helper
import Mastodon.Http
import Mastodon.Model
import Mastodon.WebSocket
import Ports
import Task
import Dom.Scroll


type alias Flags =
    { client : Maybe Mastodon.Model.Client
    , registration : Maybe Mastodon.Model.AppRegistration
    }


type DraftMsg
    = ClearDraft
    | UpdateSensitive Bool
    | UpdateSpoiler String
    | UpdateStatus String
    | UpdateVisibility String
    | UpdateReplyTo Mastodon.Model.Status
    | ToggleSpoiler Bool


type ViewerMsg
    = CloseViewer
    | OpenViewer (List Mastodon.Model.Attachment) Mastodon.Model.Attachment


type MastodonMsg
    = AccessToken (Result Mastodon.Model.Error Mastodon.Model.AccessTokenResult)
    | AppRegistered (Result Mastodon.Model.Error Mastodon.Model.AppRegistration)
    | ContextLoaded Mastodon.Model.Status (Result Mastodon.Model.Error Mastodon.Model.Context)
    | CurrentUser (Result Mastodon.Model.Error Mastodon.Model.Account)
    | FavoriteAdded (Result Mastodon.Model.Error Mastodon.Model.Status)
    | FavoriteRemoved (Result Mastodon.Model.Error Mastodon.Model.Status)
    | LocalTimeline (Result Mastodon.Model.Error (List Mastodon.Model.Status))
    | Notifications (Result Mastodon.Model.Error (List Mastodon.Model.Notification))
    | GlobalTimeline (Result Mastodon.Model.Error (List Mastodon.Model.Status))
    | Reblogged (Result Mastodon.Model.Error Mastodon.Model.Status)
    | StatusPosted (Result Mastodon.Model.Error Mastodon.Model.Status)
    | Unreblogged (Result Mastodon.Model.Error Mastodon.Model.Status)
    | Account (Result Mastodon.Model.Error Mastodon.Model.Account)
    | AccountTimeline (Result Mastodon.Model.Error (List Mastodon.Model.Status))
    | UserTimeline (Result Mastodon.Model.Error (List Mastodon.Model.Status))


type WebSocketMsg
    = NewWebsocketUserMessage String
    | NewWebsocketGlobalMessage String
    | NewWebsocketLocalMessage String


type Msg
    = AddFavorite Int
    | ClearOpenedAccount
    | CloseThread
    | DomResult (Result Dom.Error ())
    | DraftEvent DraftMsg
    | LoadAccount Int
    | MastodonEvent MastodonMsg
    | NoOp
    | OpenThread Mastodon.Model.Status
    | Reblog Int
    | Register
    | RemoveFavorite Int
    | ServerChange String
    | SubmitDraft
    | UrlChange Navigation.Location
    | UseGlobalTimeline Bool
    | Unreblog Int
    | ViewerEvent ViewerMsg
    | WebSocketEvent WebSocketMsg
    | ScrollColumn String


type alias Draft =
    { status : String
    , in_reply_to : Maybe Mastodon.Model.Status
    , spoiler_text : Maybe String
    , sensitive : Bool
    , visibility : String
    }


type alias Thread =
    { status : Mastodon.Model.Status
    , context : Mastodon.Model.Context
    }


type alias Viewer =
    { attachments : List Mastodon.Model.Attachment
    , attachment : Mastodon.Model.Attachment
    }


type CurrentView
    = -- Basically, what we should be displaying in the fourth column
      AccountView Mastodon.Model.Account
    | ThreadView Thread
    | LocalTimelineView
    | GlobalTimelineView


type alias Model =
    { server : String
    , registration : Maybe Mastodon.Model.AppRegistration
    , client : Maybe Mastodon.Model.Client
    , userTimeline : List Mastodon.Model.Status
    , localTimeline : List Mastodon.Model.Status
    , globalTimeline : List Mastodon.Model.Status
    , accountTimeline : List Mastodon.Model.Status
    , notifications : List Mastodon.Model.NotificationAggregate
    , draft : Draft
    , errors : List String
    , location : Navigation.Location
    , useGlobalTimeline : Bool
    , viewer : Maybe Viewer
    , currentUser : Maybe Mastodon.Model.Account
    , currentView : CurrentView
    }


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
        , notifications = []
        , draft = defaultDraft
        , errors = []
        , location = location
        , useGlobalTimeline = False
        , viewer = Nothing
        , currentView = LocalTimelineView
        , currentUser = Nothing
        }
            ! [ initCommands flags.registration flags.client authCode ]


initCommands : Maybe Mastodon.Model.AppRegistration -> Maybe Mastodon.Model.Client -> Maybe String -> Cmd Msg
initCommands registration client authCode =
    Cmd.batch <|
        case authCode of
            Just authCode ->
                case registration of
                    Just registration ->
                        [ Mastodon.Http.getAccessToken registration authCode
                            |> Mastodon.Http.send (MastodonEvent << AccessToken)
                        ]

                    Nothing ->
                        []

            Nothing ->
                [ loadUserAccount client, loadTimelines client ]


registerApp : Model -> Cmd Msg
registerApp { server, location } =
    let
        appUrl =
            location.origin ++ location.pathname

        cleanServer =
            if String.endsWith "/" server then
                String.dropRight 1 server
            else
                server
    in
        Mastodon.Http.register
            cleanServer
            "tooty"
            appUrl
            "read write follow"
            "https://github.com/n1k0/tooty"
            |> Mastodon.Http.send (MastodonEvent << AppRegistered)


saveClient : Mastodon.Model.Client -> Cmd Msg
saveClient client =
    Mastodon.Encoder.clientEncoder client
        |> Encode.encode 0
        |> Ports.saveClient


saveRegistration : Mastodon.Model.AppRegistration -> Cmd Msg
saveRegistration registration =
    Mastodon.Encoder.registrationEncoder registration
        |> Encode.encode 0
        |> Ports.saveRegistration


loadNotifications : Maybe Mastodon.Model.Client -> Cmd Msg
loadNotifications client =
    case client of
        Just client ->
            Mastodon.Http.fetchNotifications client
                |> Mastodon.Http.send (MastodonEvent << Notifications)

        Nothing ->
            Cmd.none


loadUserAccount : Maybe Mastodon.Model.Client -> Cmd Msg
loadUserAccount client =
    case client of
        Just client ->
            Mastodon.Http.userAccount client
                |> Mastodon.Http.send (MastodonEvent << CurrentUser)

        Nothing ->
            Cmd.none


loadTimelines : Maybe Mastodon.Model.Client -> Cmd Msg
loadTimelines client =
    case client of
        Just client ->
            Cmd.batch
                [ Mastodon.Http.fetchUserTimeline client
                    |> Mastodon.Http.send (MastodonEvent << UserTimeline)
                , Mastodon.Http.fetchLocalTimeline client
                    |> Mastodon.Http.send (MastodonEvent << LocalTimeline)
                , Mastodon.Http.fetchGlobalTimeline client
                    |> Mastodon.Http.send (MastodonEvent << GlobalTimeline)
                , loadNotifications <| Just client
                ]

        Nothing ->
            Cmd.none


preferredTimeline : Model -> CurrentView
preferredTimeline model =
    if model.useGlobalTimeline then
        GlobalTimelineView
    else
        LocalTimelineView


accountMentioned : Mastodon.Model.Account -> Mastodon.Model.Mention -> Bool
accountMentioned { acct, username } mention =
    acct == mention.acct && username == mention.username


sameAccount : Mastodon.Model.Account -> Mastodon.Model.Account -> Bool
sameAccount { acct, username } account =
    acct == account.acct && username == account.username


postStatus : Mastodon.Model.Client -> Mastodon.Model.StatusRequestBody -> Cmd Msg
postStatus client draft =
    Mastodon.Http.postStatus client draft
        |> Mastodon.Http.send (MastodonEvent << StatusPosted)


errorText : Mastodon.Model.Error -> String
errorText error =
    case error of
        Mastodon.Model.MastodonError statusCode statusMsg errorMsg ->
            "HTTP " ++ (toString statusCode) ++ " " ++ statusMsg ++ ": " ++ errorMsg

        Mastodon.Model.ServerError statusCode statusMsg errorMsg ->
            "HTTP " ++ (toString statusCode) ++ " " ++ statusMsg ++ ": " ++ errorMsg

        Mastodon.Model.TimeoutError ->
            "Request timed out."

        Mastodon.Model.NetworkError ->
            "Unreachable host."


toStatusRequestBody : Draft -> Mastodon.Model.StatusRequestBody
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


updateTimelinesWithBoolFlag : Int -> Bool -> (Mastodon.Model.Status -> Mastodon.Model.Status) -> Model -> Model
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
    updateTimelinesWithBoolFlag statusId flag (\s -> { s | favourited = Just flag }) model


processReblog : Int -> Bool -> Model -> Model
processReblog statusId flag model =
    updateTimelinesWithBoolFlag statusId flag (\s -> { s | reblogged = Just flag }) model


deleteStatusFromTimeline : Int -> List Mastodon.Model.Status -> List Mastodon.Model.Status
deleteStatusFromTimeline statusId timeline =
    timeline
        |> List.filter
            (\s ->
                s.id
                    /= statusId
                    && (Mastodon.Helper.extractReblog s).id
                    /= statusId
            )


updateDraft : DraftMsg -> Mastodon.Model.Account -> Draft -> ( Draft, Cmd Msg )
updateDraft draftMsg currentUser draft =
    case draftMsg of
        ClearDraft ->
            defaultDraft ! []

        ToggleSpoiler enabled ->
            { draft
                | spoiler_text =
                    if enabled then
                        Just ""
                    else
                        Nothing
            }
                ! []

        UpdateSensitive sensitive ->
            { draft | sensitive = sensitive } ! []

        UpdateSpoiler spoiler_text ->
            { draft | spoiler_text = Just spoiler_text } ! []

        UpdateStatus status ->
            { draft | status = status } ! []

        UpdateVisibility visibility ->
            { draft | visibility = visibility } ! []

        UpdateReplyTo status ->
            let
                mentions =
                    status.mentions
                        |> List.filter (\m -> not (accountMentioned currentUser m))
                        |> List.map (\m -> "@" ++ m.acct)
                        |> String.join " "

                newStatus =
                    if sameAccount status.account currentUser then
                        mentions
                    else
                        "@" ++ status.account.acct ++ " " ++ mentions
            in
                { draft
                    | in_reply_to = Just status
                    , status = (String.trim newStatus) ++ " "
                    , sensitive = Maybe.withDefault False status.sensitive
                    , spoiler_text =
                        if status.spoiler_text == "" then
                            Nothing
                        else
                            Just status.spoiler_text
                    , visibility = status.visibility
                }
                    ! [ Dom.focus "status" |> Task.attempt (always NoOp) ]


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
                            Mastodon.Model.Client server accessToken
                    in
                        { model | client = Just client }
                            ! [ loadTimelines <| Just client
                              , Navigation.modifyUrl model.location.pathname
                              , saveClient client
                              ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        AppRegistered result ->
            case result of
                Ok registration ->
                    { model | registration = Just registration }
                        ! [ saveRegistration registration
                          , Navigation.load <| Mastodon.Http.getAuthorizationUrl registration
                          ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        ContextLoaded status result ->
            case result of
                Ok context ->
                    let
                        thread =
                            Thread status context
                    in
                        { model | currentView = ThreadView thread } ! []

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
                    processFavourite status.id True model ! [ loadNotifications model.client ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        FavoriteRemoved result ->
            case result of
                Ok status ->
                    processFavourite status.id False model ! [ loadNotifications model.client ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        LocalTimeline result ->
            case result of
                Ok localTimeline ->
                    { model | localTimeline = localTimeline } ! []

                Err error ->
                    { model | localTimeline = [], errors = (errorText error) :: model.errors } ! []

        Notifications result ->
            case result of
                Ok notifications ->
                    { model | notifications = Mastodon.Helper.aggregateNotifications notifications } ! []

                Err error ->
                    { model | notifications = [], errors = (errorText error) :: model.errors } ! []

        GlobalTimeline result ->
            case result of
                Ok globalTimeline ->
                    { model | globalTimeline = globalTimeline } ! []

                Err error ->
                    { model | globalTimeline = [], errors = (errorText error) :: model.errors } ! []

        Reblogged result ->
            case result of
                Ok status ->
                    model ! [ loadNotifications model.client ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        StatusPosted _ ->
            { model | draft = defaultDraft } ! []

        Unreblogged result ->
            case result of
                Ok status ->
                    model ! [ loadNotifications model.client ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        Account result ->
            case result of
                Ok account ->
                    { model | currentView = AccountView account } ! []

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

        UserTimeline result ->
            case result of
                Ok userTimeline ->
                    { model | userTimeline = userTimeline } ! []

                Err error ->
                    { model | userTimeline = [], errors = (errorText error) :: model.errors } ! []


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
                            { model | userTimeline = status :: model.userTimeline } ! []

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
                            { model | localTimeline = status :: model.localTimeline } ! []

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
                            { model | globalTimeline = status :: model.globalTimeline } ! []

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

        DomResult result ->
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
            model ! [ registerApp model ]

        OpenThread status ->
            case model.client of
                Just client ->
                    model
                        ! [ Mastodon.Http.context client status.id
                                |> Mastodon.Http.send (MastodonEvent << (ContextLoaded status))
                          ]

                Nothing ->
                    model ! []

        CloseThread ->
            { model | currentView = preferredTimeline model } ! []

        Reblog id ->
            -- Note: The case of reblogging is specific as it seems the server
            -- response takes a lot of time to be received by the client, so we
            -- perform optimistic updates here.
            case model.client of
                Just client ->
                    processReblog id True model
                        ! [ Mastodon.Http.reblog client id
                                |> Mastodon.Http.send (MastodonEvent << Reblogged)
                          ]

                Nothing ->
                    model ! []

        Unreblog id ->
            case model.client of
                Just client ->
                    processReblog id False model
                        ! [ Mastodon.Http.unfavourite client id
                                |> Mastodon.Http.send (MastodonEvent << Unreblogged)
                          ]

                Nothing ->
                    model ! []

        AddFavorite id ->
            model
                ! case model.client of
                    Just client ->
                        [ Mastodon.Http.favourite client id
                            |> Mastodon.Http.send (MastodonEvent << FavoriteAdded)
                        ]

                    Nothing ->
                        []

        RemoveFavorite id ->
            model
                ! case model.client of
                    Just client ->
                        [ Mastodon.Http.unfavourite client id
                            |> Mastodon.Http.send (MastodonEvent << FavoriteRemoved)
                        ]

                    Nothing ->
                        []

        DraftEvent draftMsg ->
            case model.currentUser of
                Just user ->
                    let
                        ( draft, commands ) =
                            updateDraft draftMsg user model.draft
                    in
                        { model | draft = draft } ! [ commands ]

                Nothing ->
                    model ! []

        ViewerEvent viewerMsg ->
            let
                ( viewer, commands ) =
                    updateViewer viewerMsg model.viewer
            in
                { model | viewer = viewer } ! [ commands ]

        SubmitDraft ->
            model
                ! case model.client of
                    Just client ->
                        [ postStatus client <| toStatusRequestBody model.draft ]

                    Nothing ->
                        []

        LoadAccount accountId ->
            {-
               @TODO
               When requesting a user profile, we should load a new "page"
               so that the URL in the browser matches the user displayed
            -}
            { model | currentView = preferredTimeline model }
                ! case model.client of
                    Just client ->
                        [ Mastodon.Http.fetchAccount client accountId
                            |> Mastodon.Http.send (MastodonEvent << Account)
                        , Mastodon.Http.fetchAccountTimeline client accountId
                            |> Mastodon.Http.send (MastodonEvent << AccountTimeline)
                        ]

                    Nothing ->
                        []

        UseGlobalTimeline flag ->
            let
                newModel =
                    { model | useGlobalTimeline = flag }
            in
                { model | currentView = preferredTimeline newModel } ! []

        ClearOpenedAccount ->
            { model | currentView = preferredTimeline model } ! []

        ScrollColumn context ->
            model ! [ Task.attempt DomResult <| Dom.Scroll.toTop context ]


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
