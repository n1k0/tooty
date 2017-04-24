module NotificationTests exposing (..)

import Test exposing (..)
import Expect
import String
import Mastodon
import Fixtures


all : Test
all =
    describe "Notification test suite"
        [ describe "Aggegate test"
            [ test "Aggregate Notifications" <|
                \() ->
                    Fixtures.notifications
                        |> Mastodon.aggregateNotifications
                        |> Expect.equal expectedAggregateNotifications
            ]
        ]


expectedAggregateNotifications : List Mastodon.NotificationAggregate
expectedAggregateNotifications =
    [ { type_ = "mention"
      , status = Just Fixtures.statusNicoToVjousse
      , accounts = [ Fixtures.accountNico ]
      , created_at = "2017-04-24T20:16:20.973Z"
      }
    , { type_ = "follow"
      , status = Nothing
      , accounts = [ Fixtures.accountNico, Fixtures.accountSkro ]
      , created_at = "2017-04-24T20:13:47.431Z"
      }
    ]
