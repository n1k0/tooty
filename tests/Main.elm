port module Main exposing (..)

import MastodonTest.HelperTest
import MastodonTest.HttpTest
import Test
import Test.Runner.Node exposing (run, TestProgram)
import Json.Encode exposing (Value)


main : TestProgram
main =
    run emit <|
        Test.concat
            [ MastodonTest.HelperTest.all
            , MastodonTest.HttpTest.all
            ]


port emit : ( String, Value ) -> Cmd msg
