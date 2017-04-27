module Model exposing (..)

import Dom
import Json.Encode as Encode
import Navigation
import Mastodon
import Mastodon.Decoder
import Mastodon.Encoder
import Mastodon.Model
import Mastodon.WebSocket
import Ports
import Task


type alias Flags =
    { client : Maybe Mastodon.Model.Client
    , registration : Maybe Mastodon.Model.AppRegistration
    }


type DraftMsg
    = ClearDraft
    | ClearReplyTo
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
    | FavoriteAdded (Result Mastodon.Model.Error Mastodon.Model.Status)
    | FavoriteRemoved (Result Mastodon.Model.Error Mastodon.Model.Status)
    | LocalTimeline (Result Mastodon.Model.Error (List Mastodon.Model.Status))
    | Notifications (Result Mastodon.Model.Error (List Mastodon.Model.Notification))
    | GlobalTimeline (Result Mastodon.Model.Error (List Mastodon.Model.Status))
    | Reblogged (Result Mastodon.Model.Error Mastodon.Model.Status)
    | StatusPosted (Result Mastodon.Model.Error Mastodon.Model.Status)
    | Unreblogged (Result Mastodon.Model.Error Mastodon.Model.Status)
    | UserAccount (Result Mastodon.Model.Error Mastodon.Model.Account)
    | UserTimeline (Result Mastodon.Model.Error (List Mastodon.Model.Status))


type WebSocketMsg
    = NewWebsocketUserMessage String
    | NewWebsocketGlobalMessage String
    | NewWebsocketLocalMessage String


type Msg
    = AddFavorite Int
    | DraftEvent DraftMsg
    | MastodonEvent MastodonMsg
    | NoOp
    | OnLoadUserAccount Int
    | Reblog Int
    | Register
    | RemoveFavorite Int
    | ServerChange String
    | SubmitDraft
    | UrlChange Navigation.Location
    | UseGlobalTimeline Bool
    | ClearOpenedAccount
    | Unreblog Int
    | ViewerEvent ViewerMsg
    | WebSocketEvent WebSocketMsg


type alias Draft =
    { status : String
    , in_reply_to : Maybe Mastodon.Model.Status
    , spoiler_text : Maybe String
    , sensitive : Bool
    , visibility : String
    }


type alias Viewer =
    { attachments : List Mastodon.Model.Attachment
    , attachment : Mastodon.Model.Attachment
    }


type alias Model =
    { server : String
    , registration : Maybe Mastodon.Model.AppRegistration
    , client : Maybe Mastodon.Model.Client
    , userTimeline : List Mastodon.Model.Status
    , localTimeline : List Mastodon.Model.Status
    , globalTimeline : List Mastodon.Model.Status
    , notifications : List Mastodon.Model.NotificationAggregate
    , draft : Draft
    , account : Maybe Mastodon.Model.Account
    , errors : List String
    , location : Navigation.Location
    , useGlobalTimeline : Bool
    , viewer : Maybe Viewer
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
        , notifications = []
        , draft = defaultDraft
        , account = Nothing
        , errors = []
        , location = location
        , useGlobalTimeline = False
        , viewer = Nothing
        }
            ! [ initCommands flags.registration flags.client authCode ]


initCommands : Maybe Mastodon.Model.AppRegistration -> Maybe Mastodon.Model.Client -> Maybe String -> Cmd Msg
initCommands registration client authCode =
    Cmd.batch <|
        case authCode of
            Just authCode ->
                case registration of
                    Just registration ->
                        [ Mastodon.getAccessToken registration authCode
                            |> Mastodon.send (MastodonEvent << AccessToken)
                        ]

                    Nothing ->
                        []

            Nothing ->
                [ loadTimelines client ]


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
        Mastodon.register
            cleanServer
            "tooty"
            appUrl
            "read write follow"
            "https://github.com/n1k0/tooty"
            |> Mastodon.send (MastodonEvent << AppRegistered)


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
            Mastodon.fetchNotifications client
                |> Mastodon.send (MastodonEvent << Notifications)

        Nothing ->
            Cmd.none


loadTimelines : Maybe Mastodon.Model.Client -> Cmd Msg
loadTimelines client =
    case client of
        Just client ->
            Cmd.batch
                [ Mastodon.fetchUserTimeline client |> Mastodon.send (MastodonEvent << UserTimeline)
                , Mastodon.fetchLocalTimeline client |> Mastodon.send (MastodonEvent << LocalTimeline)
                , Mastodon.fetchGlobalTimeline client |> Mastodon.send (MastodonEvent << GlobalTimeline)
                , loadNotifications <| Just client
                ]

        Nothing ->
            Cmd.none


postStatus : Mastodon.Model.Client -> Mastodon.Model.StatusRequestBody -> Cmd Msg
postStatus client draft =
    Mastodon.postStatus client draft
        |> Mastodon.send (MastodonEvent << StatusPosted)


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
            if (Mastodon.extractReblog status).id == statusId then
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
        |> List.filter (\s -> s.id /= statusId && (Mastodon.extractReblog s).id /= statusId)


updateDraft : DraftMsg -> Draft -> ( Draft, Cmd Msg )
updateDraft draftMsg draft =
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
                mention =
                    "@" ++ status.account.acct
            in
                { draft
                    | in_reply_to = Just status
                    , status =
                        if String.startsWith mention draft.status then
                            draft.status
                        else
                            mention ++ " " ++ draft.status
                    , sensitive = Maybe.withDefault False status.sensitive
                    , spoiler_text =
                        if status.spoiler_text == "" then
                            Nothing
                        else
                            Just status.spoiler_text
                    , visibility = status.visibility
                }
                    ! [ Dom.focus "status" |> Task.attempt (always NoOp) ]

        ClearReplyTo ->
            { draft | in_reply_to = Nothing } ! []


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
                          , Navigation.load <| Mastodon.getAuthorizationUrl registration
                          ]

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
                    { model | notifications = Mastodon.aggregateNotifications notifications } ! []

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

        UserAccount result ->
            case result of
                Ok account ->
                    { model | account = Just account } ! []

                Err error ->
                    { model | account = Nothing, errors = (errorText error) :: model.errors } ! []

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
                                    Mastodon.addNotificationToAggregates notification model.notifications
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

        Reblog id ->
            -- Note: The case of reblogging is specific as it seems the server
            -- response takes a lot of time to be received by the client, so we
            -- perform optimistic updates here.
            case model.client of
                Just client ->
                    processReblog id True model
                        ! [ Mastodon.reblog client id
                                |> Mastodon.send (MastodonEvent << Reblogged)
                          ]

                Nothing ->
                    model ! []

        Unreblog id ->
            case model.client of
                Just client ->
                    processReblog id False model
                        ! [ Mastodon.unfavourite client id
                                |> Mastodon.send (MastodonEvent << Unreblogged)
                          ]

                Nothing ->
                    model ! []

        AddFavorite id ->
            model
                ! case model.client of
                    Just client ->
                        [ Mastodon.favourite client id
                            |> Mastodon.send (MastodonEvent << FavoriteAdded)
                        ]

                    Nothing ->
                        []

        RemoveFavorite id ->
            model
                ! case model.client of
                    Just client ->
                        [ Mastodon.unfavourite client id
                            |> Mastodon.send (MastodonEvent << FavoriteRemoved)
                        ]

                    Nothing ->
                        []

        DraftEvent draftMsg ->
            let
                ( draft, commands ) =
                    updateDraft draftMsg model.draft
            in
                { model | draft = draft } ! [ commands ]

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

        OnLoadUserAccount accountId ->
            {-
               @TODO
               When requesting a user profile, we should load a new "page"
               so that the URL in the browser matches the user displayed
            -}
            model
                ! case model.client of
                    Just client ->
                        [ Mastodon.fetchAccount client accountId
                            |> Mastodon.send (MastodonEvent << UserAccount)
                        ]

                    Nothing ->
                        []

        UseGlobalTimeline flag ->
            { model | useGlobalTimeline = flag } ! []

        ClearOpenedAccount ->
            { model | account = Nothing } ! []


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
