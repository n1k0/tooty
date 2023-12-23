module View.Auth exposing (authForm, authView)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Types exposing (..)


authForm : Model -> Html Msg
authForm model =
    Html.form [ class "form", onSubmit Register ]
        [ div [ class "form-group" ]
            [ label [ for "server" ] [ text "Mastodon server root URL" ]
            , input
                [ type_ "url"
                , class "form-control"
                , id "server"
                , required True
                , placeholder "https://mastodon.social"
                , value model.server
                , pattern "https://.+"
                , onInput ServerChange
                ]
                []
            , p [ class "help-block" ]
                [ text <|
                    "You'll be redirected to that server to authenticate yourself. "
                        ++ "We don't have access to your password."
                ]
            ]
        , label [ for "client-name" ] [ text "Client name" ]
        , input
            [ type_ "text"
            , class "form-control"
            , id "client-name"
            , required True
            , placeholder "Tooty"
            , value model.clientName
            , onInput ClientNameChange
            ]
            []
        , button [ class "btn btn-primary", type_ "submit" ]
            [ text "Sign into Tooty" ]
        ]


authView : Model -> Html Msg
authView model =
    div [ class "col-md-4 col-md-offset-4" ]
        [ div [ class "page-header" ]
            [ h1 []
                [ text "tooty"
                , small []
                    [ text " is a Web client for the "
                    , a
                        [ href "https://github.com/tootsuite/mastodon"
                        , target "_blank"
                        ]
                        [ text "Mastodon" ]
                    , text " API."
                    ]
                ]
            ]
        , div [ class "panel panel-default" ]
            [ div [ class "panel-heading" ] [ text "Authenticate" ]
            , div [ class "panel-body" ]
                [ authForm model ]
            ]
        ]
