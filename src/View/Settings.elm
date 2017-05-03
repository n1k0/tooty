module View.Settings exposing (settingsView)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Types exposing (..)
import View.Common as Common


settingsView : Model -> Html Msg
settingsView model =
    div [ class "panel panel-default options" ]
        [ div [ class "panel-heading" ] [ Common.icon "cog", text "options" ]
        , div [ class "panel-body" ]
            [ div [ class "checkbox" ]
                [ label []
                    [ input [ type_ "checkbox", onCheck UseGlobalTimeline ] []
                    , text " 4th column renders the global timeline"
                    ]
                ]
            ]
        ]
