module MastodonTest.HelperTest exposing (..)

import Test exposing (..)
import Expect
import Mastodon.Helper
import Fixtures


all : Test
all =
    describe "Notification test suite"
        [ describe "Aggegate test"
            [ test "Aggregate Notifications" <|
                \() ->
                    Fixtures.notifications
                        |> Mastodon.Helper.aggregateNotifications
                        |> Expect.equal
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
            , test "Add follows notification to aggregate" <|
                \() ->
                    Fixtures.notifications
                        |> Mastodon.Helper.aggregateNotifications
                        |> (Mastodon.Helper.addNotificationToAggregates Fixtures.notificationPloumFollowsVjousse)
                        |> Expect.equal
                            [ { type_ = "mention"
                              , status = Just Fixtures.statusNicoToVjousse
                              , accounts = [ Fixtures.accountNico ]
                              , created_at = "2017-04-24T20:16:20.973Z"
                              }
                            , { type_ = "follow"
                              , status = Nothing
                              , accounts = [ Fixtures.accountPloum, Fixtures.accountNico, Fixtures.accountSkro ]
                              , created_at = "2017-04-24T20:13:47.431Z"
                              }
                            ]
            , test "Add mention notification to aggregate" <|
                \() ->
                    Fixtures.notifications
                        |> Mastodon.Helper.aggregateNotifications
                        |> (Mastodon.Helper.addNotificationToAggregates Fixtures.notificationNicoMentionVjousse)
                        |> Expect.equal
                            [ { type_ = "mention"
                              , status = Just Fixtures.statusNicoToVjousse
                              , accounts = [ Fixtures.accountNico, Fixtures.accountNico ]
                              , created_at = "2017-04-24T20:16:20.973Z"
                              }
                            , { type_ = "follow"
                              , status = Nothing
                              , accounts = [ Fixtures.accountNico, Fixtures.accountSkro ]
                              , created_at = "2017-04-24T20:13:47.431Z"
                              }
                            ]
            , test "Add new mention notification to aggregate" <|
                \() ->
                    Fixtures.notifications
                        |> Mastodon.Helper.aggregateNotifications
                        |> (Mastodon.Helper.addNotificationToAggregates Fixtures.notificationNicoMentionVjousseAgain)
                        |> Expect.equal
                            [ { type_ = "mention"
                              , status = Just Fixtures.statusNicoToVjousseAgain
                              , accounts = [ Fixtures.accountNico ]
                              , created_at = "2017-04-25T07:41:23.546Z"
                              }
                            , { type_ = "mention"
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
            ]
        ]
