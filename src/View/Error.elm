module View.Error
    exposing
        ( errorView
        , errorsListView
        )

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Types exposing (..)


errorView : Int -> String -> Html Msg
errorView index error =
    div [ class "alert alert-danger" ]
        [ button
            [ type_ "button"
            , class "close"
            , onClick <| ClearError index
            ]
            [ text "×" ]
        , text error
        ]


errorsListView : Model -> Html Msg
errorsListView model =
    case model.errors of
        [] ->
            text ""

        errors ->
            div [ class "error-list" ] <| List.indexedMap errorView model.errors
