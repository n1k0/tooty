module Model exposing (..)

import Json.Encode as Encode
import Navigation
import Mastodon
import Ports


type alias Flags =
    { client : Maybe Mastodon.Client
    , registration : Maybe Mastodon.AppRegistration
    }


type DraftMsg
    = ToggleSpoiler Bool
    | UpdateSensitive Bool
    | UpdateSpoiler String
    | UpdateStatus String
    | UpdateVisibility String


type Msg
    = AccessToken (Result Mastodon.Error Mastodon.AccessTokenResult)
    | AppRegistered (Result Mastodon.Error Mastodon.AppRegistration)
    | DraftEvent DraftMsg
    | LocalTimeline (Result Mastodon.Error (List Mastodon.Status))
    | PublicTimeline (Result Mastodon.Error (List Mastodon.Status))
    | OnLoadUserAccount Int
    | Register
    | ServerChange String
    | StatusPosted (Result Mastodon.Error Mastodon.Status)
    | SubmitDraft
    | UrlChange Navigation.Location
    | UserAccount (Result Mastodon.Error Mastodon.Account)
    | UserTimeline (Result Mastodon.Error (List Mastodon.Status))


type alias Model =
    { server : String
    , registration : Maybe Mastodon.AppRegistration
    , client : Maybe Mastodon.Client
    , userTimeline : List Mastodon.Status
    , localTimeline : List Mastodon.Status
    , publicTimeline : List Mastodon.Status
    , draft : Mastodon.StatusRequestBody
    , account : Maybe Mastodon.Account
    , errors : List String
    , location : Navigation.Location
    }


extractAuthCode : Navigation.Location -> Maybe String
extractAuthCode { search } =
    case (String.split "?code=" search) of
        [ _, authCode ] ->
            Just authCode

        _ ->
            Nothing


defaultDraft : Mastodon.StatusRequestBody
defaultDraft =
    { status = ""
    , in_reply_to_id = Nothing
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
        , draft = defaultDraft
        , account = Nothing
        , errors = []
        , location = location
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


loadTimelines : Maybe Mastodon.Client -> Cmd Msg
loadTimelines client =
    case client of
        Just client ->
            Cmd.batch
                [ Mastodon.fetchUserTimeline client |> Mastodon.send UserTimeline
                , Mastodon.fetchLocalTimeline client |> Mastodon.send LocalTimeline
                , Mastodon.fetchPublicTimeline client |> Mastodon.send PublicTimeline
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


updateDraft : DraftMsg -> Mastodon.StatusRequestBody -> Mastodon.StatusRequestBody
updateDraft draftMsg draft =
    -- TODO: later we'll probably want to handle more events like when the user
    --       wants to add CW, medias, etc.
    case draftMsg of
        ToggleSpoiler enabled ->
            { draft
                | spoiler_text =
                    if enabled then
                        Just ""
                    else
                        Nothing
            }

        UpdateSensitive sensitive ->
            { draft | sensitive = sensitive }

        UpdateSpoiler spoiler_text ->
            { draft | spoiler_text = Just spoiler_text }

        UpdateStatus status ->
            { draft | status = status }

        UpdateVisibility visibility ->
            { draft | visibility = visibility }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
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

        DraftEvent draftMsg ->
            { model | draft = updateDraft draftMsg model.draft } ! []

        SubmitDraft ->
            model
                ! case model.client of
                    Just client ->
                        [ postStatus client model.draft ]

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

        StatusPosted _ ->
            { model | draft = defaultDraft } ! [ loadTimelines model.client ]
