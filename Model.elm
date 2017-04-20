module Model exposing (..)

import Json.Encode as Encode
import Navigation
import Mastodon
import Ports


type alias Flags =
    { client : Maybe Mastodon.Client
    , registration : Maybe Mastodon.AppRegistration
    }


type Msg
    = AccessToken (Mastodon.Result Mastodon.AccessTokenResult)
    | AppRegistered (Mastodon.Result Mastodon.AppRegistration)
    | LocalTimeline (Mastodon.Result (List Mastodon.Status))
    | PublicTimeline (Mastodon.Result (List Mastodon.Status))
    | Register
    | ServerChange String
    | UrlChange Navigation.Location
    | UserTimeline (Mastodon.Result (List Mastodon.Status))


type alias Model =
    { server : String
    , registration : Maybe Mastodon.AppRegistration
    , client : Maybe Mastodon.Client
    , userTimeline : List Mastodon.Status
    , localTimeline : List Mastodon.Status
    , publicTimeline : List Mastodon.Status
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
                case client of
                    Just client ->
                        [ loadTimelines client ]

                    Nothing ->
                        []


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


loadTimelines : Mastodon.Client -> Cmd Msg
loadTimelines client =
    Cmd.batch
        [ Mastodon.fetchUserTimeline client |> Mastodon.send UserTimeline
        , Mastodon.fetchLocalTimeline client |> Mastodon.send LocalTimeline
        , Mastodon.fetchPublicTimeline client |> Mastodon.send PublicTimeline
        ]


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
                            ! [ loadTimelines client
                              , Navigation.modifyUrl model.location.pathname
                              , saveClient client
                              ]

                Err error ->
                    { model | errors = (errorText error) :: model.errors } ! []

        UserTimeline result ->
            case result of
                Ok userTimeline ->
                    { model | userTimeline = userTimeline } ! []

                Err error ->
                    { model | userTimeline = [], errors = (errorText error) :: model.errors } ! []

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
