module Update.Error exposing (addErrorNotification)

import Types exposing (..)


addErrorNotification : String -> Model -> List ErrorNotification
addErrorNotification message model =
    let
        error =
            { message = message, time = model.currentTime }
    in
        error :: model.errors
