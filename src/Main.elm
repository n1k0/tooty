module Main exposing (..)

import Navigation
import View exposing (view)
import Model exposing (Flags, Model, Msg(..), init, update, subscriptions)


main : Program Flags Model Msg
main =
    Navigation.programWithFlags UrlChange
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
