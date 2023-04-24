module Main exposing (main)

import Browser
import Init exposing (init)
import Subscription exposing (subscriptions)
import Types exposing (Flags, Model, Msg(..))
import Update.Main exposing (update)
import View.App exposing (view)


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
