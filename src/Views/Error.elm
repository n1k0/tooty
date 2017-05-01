module Views.Error
    exposing
        ( errorView
        , errorsListView
        )

import Html exposing (..)
import Html.Attributes exposing (..)
import Types exposing (..)


errorView : String -> Html Msg
errorView error =
    div [ class "alert alert-danger" ] [ text error ]


errorsListView : Model -> Html Msg
errorsListView model =
    case model.errors of
        [] ->
            text ""

        errors ->
            div [] <| List.map errorView model.errors
