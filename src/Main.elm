module Main exposing (main)

import Init exposing (init)
import Navigation
import Subscription exposing (subscriptions)
import Types exposing (..)
import Update.Main exposing (update)
import View.App exposing (view)


main : Program Flags Model Msg
main =
    Navigation.programWithFlags UrlChange
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
