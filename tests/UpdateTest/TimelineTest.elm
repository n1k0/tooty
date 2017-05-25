module UpdateTest.TimelineTest exposing (..)

import Test exposing (..)
import Update.Timeline
import Expect
import Fixtures


all : Test
all =
    describe "Update.Timeline tests"
        [ describe "cleanUnfollow"
            [ test "Remove account statuses" <|
                \() ->
                    let
                        timeline =
                            { id = "foo"
                            , entries =
                                [ Fixtures.statusNico -- discard
                                , Fixtures.statusNicoToVjousse
                                , Fixtures.statusNicoToVjousseAgain
                                , Fixtures.statusPloumToVjousse
                                , Fixtures.statusReblogged
                                ]
                            , links = { prev = Nothing, next = Nothing }
                            , loading = False
                            }
                    in
                        timeline
                            |> Update.Timeline.cleanUnfollow Fixtures.accountNico Fixtures.accountVjousse
                            |> .entries
                            |> Expect.equal
                                [ Fixtures.statusNicoToVjousse
                                , Fixtures.statusNicoToVjousseAgain
                                , Fixtures.statusPloumToVjousse
                                , Fixtures.statusReblogged
                                ]
            ]
        ]
