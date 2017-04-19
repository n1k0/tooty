module Main exposing (..)

import Json.Encode as Encode
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Navigation
import Ports
import Mastodon


type alias Flags =
    { client : Maybe Mastodon.Client
    , registration : Maybe Mastodon.AppRegistration
    }


type Msg
    = NoOp
    | Register
    | AppRegistered (Result Mastodon.Error Mastodon.AppRegistration)
    | AccessToken (Result Mastodon.Error Mastodon.AccessTokenResult)
    | UserTimeline (Result Mastodon.Error (List Mastodon.Status))
    | PublicTimeline (Result Mastodon.Error (List Mastodon.Status))
    | ServerChange String
    | UrlChange Navigation.Location


type alias Model =
    { server : String
    , registration : Maybe Mastodon.AppRegistration
    , client : Maybe Mastodon.Client
    , userTimeline : List Mastodon.Status
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
        { server = "https://mamot.fr"
        , registration = flags.registration
        , client = flags.client
        , userTimeline = []
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
        , Mastodon.fetchPublicTimeline client |> Mastodon.send PublicTimeline
        ]


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
                    { model | errors = (toString error) :: model.errors } ! []

        AccessToken result ->
            case result of
                Ok { server, access_token } ->
                    let
                        client =
                            Mastodon.Client server access_token
                    in
                        { model | client = Just client }
                            ! [ loadTimelines client
                              , Navigation.modifyUrl model.location.pathname
                              , saveClient client
                              ]

                Err error ->
                    { model | errors = (toString error) :: model.errors } ! []

        UserTimeline result ->
            case result of
                Ok userTimeline ->
                    { model | userTimeline = userTimeline } ! []

                Err error ->
                    { model | userTimeline = [], errors = (toString error) :: model.errors } ! []

        PublicTimeline result ->
            case result of
                Ok publicTimeline ->
                    { model | publicTimeline = publicTimeline } ! []

                Err error ->
                    { model | publicTimeline = [], errors = (toString error) :: model.errors } ! []


statusView : Mastodon.Status -> Html Msg
statusView status =
    li []
        [ strong [] [ text status.account.username ]
        , span [] [ text status.content ]
        ]


errorView : Model -> Html Msg
errorView model =
    case model.errors of
        [] ->
            text ""

        errors ->
            ul [] <|
                List.map
                    (\err ->
                        li [ class "alert alert-danger" ] [ text err ]
                    )
                    model.errors


homepageView : Model -> Html Msg
homepageView model =
    div []
        [ h2 [] [ text "Home timeline" ]
        , ul [] <| List.map statusView model.userTimeline
        , h2 [] [ text "Public timeline" ]
        , ul [] <| List.map statusView model.publicTimeline
        ]


authView : Model -> Html Msg
authView model =
    Html.form [ onSubmit Register ]
        [ label []
            [ span [] [ text "Mastodon server root URL" ]
            , input
                [ type_ "url"
                , required True
                , placeholder "https://mastodon.social"
                , value model.server
                , pattern "https://.+"
                , onInput ServerChange
                ]
                []
            ]
        , button [ type_ "submit" ] [ text "Sign into Tooty" ]
        ]


view : Model -> Html Msg
view model =
    div []
        [ h1 [] [ text "tooty" ]
        , errorView model
        , case model.client of
            Just client ->
                homepageView model

            Nothing ->
                authView model
        ]


main : Program Flags Model Msg
main =
    Navigation.programWithFlags UrlChange
        { init = init
        , view = view
        , update = update
        , subscriptions = always Sub.none
        }
