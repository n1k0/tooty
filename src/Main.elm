module Main exposing (main)

import Navigation
import View.App exposing (view)
import Init exposing (init)
import Subscription exposing (subscriptions)
import Types exposing (..)
import Update.Main exposing (update)


main : Program Flags Model Msg
main =
    Navigation.programWithFlags UrlChange
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
