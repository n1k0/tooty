port module Main exposing (..)

import MastodonTest.HelperTest
import Test.Runner.Node exposing (run, TestProgram)
import Json.Encode exposing (Value)


main : TestProgram
main =
    run emit MastodonTest.HelperTest.all


port emit : ( String, Value ) -> Cmd msg
