module Main exposing (main)

import Browser
import Init exposing (init)
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
main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }
