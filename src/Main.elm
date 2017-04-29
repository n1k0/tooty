module Main exposing (..)

import Navigation
import View exposing (view)
import Model exposing (..)
import Types exposing (..)


main : Program Flags Model Msg
main =
    Navigation.programWithFlags UrlChange
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
