module Update.Error exposing (addErrorNotification, cleanErrors)

import Time exposing (Time)
import Types exposing (..)


addErrorNotification : String -> Model -> List ErrorNotification
addErrorNotification message model =
    let
        error =
            { message = message, time = model.currentTime }
    in
    error :: model.errors


cleanErrors : Time -> List ErrorNotification -> List ErrorNotification
cleanErrors currentTime errors =
    List.filter (\{ time } -> currentTime - time <= 10000) errors
