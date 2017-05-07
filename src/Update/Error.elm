module Update.Error exposing (addErrorNotification, errorText)

import Mastodon.Model exposing (..)
import Types exposing (..)


addErrorNotification : String -> Model -> List ErrorNotification
addErrorNotification message model =
    let
        error =
            { message = message, time = model.currentTime }
    in
        error :: model.errors


errorText : Error -> String
errorText error =
    case error of
        MastodonError statusCode statusMsg errorMsg ->
            "HTTP " ++ (toString statusCode) ++ " " ++ statusMsg ++ ": " ++ errorMsg

        ServerError statusCode statusMsg errorMsg ->
            "HTTP " ++ (toString statusCode) ++ " " ++ statusMsg ++ ": " ++ errorMsg

        TimeoutError ->
            "Request timed out."

        NetworkError ->
            "Unreachable host."
