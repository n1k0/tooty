module Model exposing (..)

import Dom
import Json.Decode
import Json.Encode as Encode
import Navigation
import Mastodon
import Ports
import Util
import WebSocket
import Task


type alias Flags =
    { client : Maybe Mastodon.Client
    , registration : Maybe Mastodon.AppRegistration
    }


type DraftMsg
    = ClearDraft
    | ClearReplyTo
    | UpdateSensitive Bool
    | UpdateSpoiler String
    | UpdateStatus String
    | UpdateVisibility String
    | UpdateReplyTo Mastodon.Status
    | ToggleSpoiler Bool


type
    Msg
    {-
       FIXME: Mastodon server response messages should be extracted to their own
       MastodonMsg type at some point.
    -}
    = AccessToken (Result Mastodon.Error Mastodon.AccessTokenResult)
    | AddFavorite Int
    | AppRegistered (Result Mastodon.Error Mastodon.AppRegistration)
    | DraftEvent DraftMsg
    | FavoriteAdded (Result Mastodon.Error Mastodon.Status)
    | FavoriteRemoved (Result Mastodon.Error Mastodon.Status)
    | LocalTimeline (Result Mastodon.Error (List Mastodon.Status))
    | NoOp
    | Notifications (Result Mastodon.Error (List Mastodon.Notification))
    | OnLoadUserAccount Int
    | PublicTimeline (Result Mastodon.Error (List Mastodon.Status))
    | Reblog Int
    | Reblogged (Result Mastodon.Error Mastodon.Status)
    | Register
    | RemoveFavorite Int
    | ServerChange String
    | StatusPosted (Result Mastodon.Error Mastodon.Status)
    | SubmitDraft
    | UrlChange Navigation.Location
    | UseGlobalTimeline Bool
    | UserAccount (Result Mastodon.Error Mastodon.Account)
    | ClearOpenedAccount
    | Unreblog Int
    | Unreblogged (Result Mastodon.Error Mastodon.Status)
    | UserTimeline (Result Mastodon.Error (List Mastodon.Status))
    | NewWebsocketUserMessage String


type alias Draft =
    { status : String
    , in_reply_to : Maybe Mastodon.Status
    , spoiler_text : Maybe String
    , sensitive : Bool
    , visibility : String
    }


type alias Model =
    { server : String
    , registration : Maybe Mastodon.AppRegistration
    , client : Maybe Mastodon.Client
    , userTimeline : List Mastodon.Status
    , localTimeline : List Mastodon.Status
    , publicTimeline : List Mastodon.Status
    , notifications : List Mastodon.NotificationAggregate
    , draft : Draft
    , account : Maybe Mastodon.Account
    , errors : List String
    , location : Navigation.Location
    , useGlobalTimeline : Bool
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
        , publicTimeline = []
        , notifications = []
        , draft = defaultDraft
        , account = Nothing
        , errors = []
        , location = location
        , useGlobalTimeline = False
        }
            ! [ initCommands flags.registration flags.client authCode ]


initCommands : Maybe Mastodon.AppRegistration -> Maybe Mastodon.Client -> Maybe String -> Cmd Msg
initCommands registration client authCode =
    Cmd.batch <|
        case authCode of
            Just authCode ->
                case registration of
                    Just registration ->
                        [ Mastodon.getAccessToken registration authCode |> Mastodon.send AccessToken ]

                    Nothing ->
                        []

            Nothing ->
                [ loadTimelines client ]


registerApp : Model -> Cmd Msg
registerApp { server, location } =
    let
        appUrl =
            location.origin ++ location.pathname
    in
        Mastodon.register
            server
            "tooty"
            appUrl
            "read write follow"
            appUrl
            |> Mastodon.send AppRegistered


saveClient : Mastodon.Client -> Cmd Msg
saveClient client =
    Mastodon.clientEncoder client
        |> Encode.encode 0
        |> Ports.saveClient


saveRegistration : Mastodon.AppRegistration -> Cmd Msg
saveRegistration registration =
    Mastodon.registrationEncoder registration
        |> Encode.encode 0
        |> Ports.saveRegistration


loadNotifications : Maybe Mastodon.Client -> Cmd Msg
loadNotifications client =
    case client of
        Just client ->
            Mastodon.fetchNotifications client |> Mastodon.send Notifications

        Nothing ->
            Cmd.none


loadTimelines : Maybe Mastodon.Client -> Cmd Msg
loadTimelines client =
    case client of
        Just client ->
            Cmd.batch
                [ Mastodon.fetchUserTimeline client |> Mastodon.send UserTimeline
                , Mastodon.fetchLocalTimeline client |> Mastodon.send LocalTimeline
                , Mastodon.fetchPublicTimeline client |> Mastodon.send PublicTimeline
                , loadNotifications <| Just client
                ]

        Nothing ->
            Cmd.none


postStatus : Mastodon.Client -> Mastodon.StatusRequestBody -> Cmd Msg
postStatus client draft =
    Mastodon.postStatus client draft
        |> Mastodon.send StatusPosted


errorText : Mastodon.Error -> String
errorText error =
    case error of
        Mastodon.MastodonError statusCode statusMsg errorMsg ->
            "HTTP " ++ (toString statusCode) ++ " " ++ statusMsg ++ ": " ++ errorMsg

        Mastodon.ServerError statusCode statusMsg errorMsg ->
            "HTTP " ++ (toString statusCode) ++ " " ++ statusMsg ++ ": " ++ errorMsg

        Mastodon.TimeoutError ->
            "Request timed out."

        Mastodon.NetworkError ->
            "Unreachable host."


toStatusRequestBody : Draft -> Mastodon.StatusRequestBody
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


updateTimelinesWithBoolFlag : Int -> Bool -> (Mastodon.Status -> Mastodon.Status) -> Model -> Model
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
            , publicTimeline = List.map (update flag) model.publicTimeline
        }


processFavourite : Int -> Bool -> Model -> Model
processFavourite statusId flag model =
    updateTimelinesWithBoolFlag statusId flag (\s -> { s | favourited = Just flag }) model


processReblog : Int -> Bool -> Model -> Model
processReblog statusId flag model =
    updateTimelinesWithBoolFlag statusId flag (\s -> { s | reblogged = Just flag }) model


updateDraft : DraftMsg -> Draft -> ( Draft, Cmd Msg )
updateDraft draftMsg draft =
    -- TODO: later we'll probably want to handle more events like when the user
    --       wants to add CW, medias, etc.
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
                }
                    ! [ Dom.focus "status" |> Task.attempt (always NoOp) ]

        ClearReplyTo ->
            { draft | in_reply_to = Nothing } ! []


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            model ! []

        ServerChange server ->
            { model | server = server } ! []

        UrlChange location ->
            model ! []

        Register ->
            model ! [ registerApp model ]

        AppRegistered result ->
            case result of
                Ok registration ->
                    { model | registration = Just registration }
                        ! [ saveRegistration registration
                          , Navigation.load <| Mastodon.getAuthorizationUrl registration
                          ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        AccessToken result ->
            case result of
                Ok { server, accessToken } ->
                    let
                        client =
                            Mastodon.Client server accessToken
                    in
                        { model | client = Just client }
                            ! [ loadTimelines <| Just client
                              , Navigation.modifyUrl model.location.pathname
                              , saveClient client
                              ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        Reblog id ->
            -- Note: The case of reblogging is specific as it seems the server
            -- response takes a lot of time to be received by the client, so we
            -- perform optimistic updates here.
            case model.client of
                Just client ->
                    processReblog id True model
                        ! [ Mastodon.reblog client id |> Mastodon.send Reblogged ]

                Nothing ->
                    model ! []

        Reblogged result ->
            case result of
                Ok status ->
                    model ! [ loadNotifications model.client ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        Unreblog id ->
            case model.client of
                Just client ->
                    processReblog id False model ! [ Mastodon.unfavourite client id |> Mastodon.send Unreblogged ]

                Nothing ->
                    model ! []

        Unreblogged result ->
            case result of
                Ok status ->
                    model ! [ loadNotifications model.client ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        AddFavorite id ->
            model
                ! case model.client of
                    Just client ->
                        [ Mastodon.favourite client id |> Mastodon.send FavoriteAdded ]

                    Nothing ->
                        []

        FavoriteAdded result ->
            case result of
                Ok status ->
                    processFavourite status.id True model ! [ loadNotifications model.client ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        RemoveFavorite id ->
            model
                ! case model.client of
                    Just client ->
                        [ Mastodon.unfavourite client id |> Mastodon.send FavoriteRemoved ]

                    Nothing ->
                        []

        FavoriteRemoved result ->
            case result of
                Ok status ->
                    processFavourite status.id False model ! [ loadNotifications model.client ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        DraftEvent draftMsg ->
            let
                ( draft, commands ) =
                    updateDraft draftMsg model.draft
            in
                { model | draft = draft } ! [ commands ]

        SubmitDraft ->
            model
                ! case model.client of
                    Just client ->
                        [ postStatus client <| toStatusRequestBody model.draft ]

                    Nothing ->
                        []

        UserTimeline result ->
            case result of
                Ok userTimeline ->
                    { model | userTimeline = userTimeline } ! []

                Err error ->
                    { model | userTimeline = [], errors = (errorText error) :: model.errors } ! []

        OnLoadUserAccount accountId ->
            {-
               @TODO
               When requesting a user profile, we should load a new "page"
               so that the URL in the browser matches the user displayed
            -}
            model
                ! case model.client of
                    Just client ->
                        [ Mastodon.fetchAccount client accountId |> Mastodon.send UserAccount ]

                    Nothing ->
                        []

        UseGlobalTimeline flag ->
            { model | useGlobalTimeline = flag } ! []

        LocalTimeline result ->
            case result of
                Ok localTimeline ->
                    { model | localTimeline = localTimeline } ! []

                Err error ->
                    { model | localTimeline = [], errors = (errorText error) :: model.errors } ! []

        PublicTimeline result ->
            case result of
                Ok publicTimeline ->
                    { model | publicTimeline = publicTimeline } ! []

                Err error ->
                    { model | publicTimeline = [], errors = (errorText error) :: model.errors } ! []

        UserAccount result ->
            case result of
                Ok account ->
                    { model | account = Just account } ! []

                Err error ->
                    { model | account = Nothing, errors = (errorText error) :: model.errors } ! []

        ClearOpenedAccount ->
            { model | account = Nothing } ! []

        StatusPosted _ ->
            { model | draft = defaultDraft } ! [ loadTimelines model.client ]

        Notifications result ->
            case result of
                Ok notifications ->
                    { model | notifications = Mastodon.aggregateNotifications notifications } ! []

                Err error ->
                    { model | notifications = [], errors = (errorText error) :: model.errors } ! []

        NewWebsocketUserMessage message ->
            case (Mastodon.decodeWebSocketMessage message) of
                Mastodon.EventError error ->
                    { model | errors = error :: model.errors } ! []

                Mastodon.NotificationResult result ->
                    case result of
                        Ok notification ->
                            let
                                {-
                                   Limitation of Elm where you can't reference
                                   model.notifications inside a { model | …)
                                -}
                                oldNotifications =
                                    model.notifications

                                {-
                                   @FIXME: we should add a function to `Mastodon`
                                   with this typeSignature :
                                   Notification -> List NotificationAggregate -> List NotificationAggregate
                                -}
                                notificationAggregate =
                                    Mastodon.NotificationAggregate
                                        notification.type_
                                        notification.status
                                        [ notification.account ]
                                        notification.created_at
                            in
                                { model | notifications = notificationAggregate :: oldNotifications } ! []

                        Err error ->
                            { model | errors = error :: model.errors } ! []

                Mastodon.StatusResult result ->
                    case result of
                        Ok status ->
                            let
                                {-
                                   Limitation of Elm where you can't reference
                                   model.notifications inside a { model | …)
                                -}
                                oldLocalTimeline =
                                    model.userTimeline
                            in
                                { model | userTimeline = status :: oldLocalTimeline } ! []

                        Err error ->
                            { model | errors = error :: model.errors } ! []


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch <|
        case model.client of
            Just client ->
                -- @TODO Subcribe to the 2 other types of streams
                Mastodon.subscribeToWebSockets
                    client
                    Mastodon.UserStream
                    NewWebsocketUserMessage

            Nothing ->
                []
