module Update.Error exposing (addErrorNotification, cleanErrors)

import Time exposing (Posix)
import Types exposing (..)


addErrorNotification : String -> Model -> List ErrorNotification
addErrorNotification message model =
    let
        error =
            { message = message, time = model.currentTime }
    in
    error :: model.errors


cleanErrors : Posix -> List ErrorNotification -> List ErrorNotification
cleanErrors currentTime errors =
    errors



--List.filter (\{ time } -> currentTime - time <= 10000) errors
