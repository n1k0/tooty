port module Main exposing (..)

import NotificationTests
import Test.Runner.Node exposing (run, TestProgram)
import Json.Encode exposing (Value)


main : TestProgram
main =
    run emit NotificationTests.all


port emit : ( String, Value ) -> Cmd msg
