module MastodonTest.HelperTest exposing (..)

import Test exposing (..)
import Expect
import Mastodon.Helper exposing (..)
import Fixtures


all : Test
all =
    describe "Mastodon.Helper tests"
        [ describe "Reply tests"
            [ test "Simple reply" <|
                \() ->
                    Fixtures.statusNicoToVjousse
                        |> getReplyPrefix Fixtures.accountVjousse
                        |> Expect.equal "@n1k0 "
            , test "Keeping replying to a previous post mentioning a user" <|
                \() ->
                    Fixtures.statusNicoToVjousse
                        |> getReplyPrefix Fixtures.accountNico
                        |> Expect.equal "@vjousse "
            , test "Replying to original poster and reblogger" <|
                \() ->
                    Fixtures.statusReblogged
                        |> getReplyPrefix Fixtures.accountNico
                        |> Expect.equal "@ploum @vjousse "
            , test "Exclude replier from generated reply prefix" <|
                \() ->
                    Fixtures.statusNicoToVjousse
                        |> getReplyPrefix Fixtures.accountNico
                        |> Expect.equal "@vjousse "
            ]
        , describe "Notification test suite"
            [ describe "Aggegate test"
                [ test "Aggregate Notifications" <|
                    \() ->
                        Fixtures.notifications
                            |> aggregateNotifications
                            |> Expect.equal
                                [ { id = .id Fixtures.notificationNicoMentionVjousse
                                  , type_ = "mention"
                                  , status = Just Fixtures.statusNicoToVjousse
                                  , accounts =
                                        [ { account = Fixtures.accountNico
                                          , created_at = "2017-04-24T20:16:20.973Z"
                                          }
                                        ]
                                  , created_at = "2017-04-24T20:16:20.973Z"
                                  }
                                , { id = .id Fixtures.notificationNicoFollowsVjousse
                                  , type_ = "follow"
                                  , status = Nothing
                                  , accounts =
                                        [ { account = Fixtures.accountNico
                                          , created_at = "2017-04-24T20:13:47.431Z"
                                          }
                                        , { account = Fixtures.accountSkro
                                          , created_at = "2017-04-24T19:12:47.431Z"
                                          }
                                        ]
                                  , created_at = "2017-04-24T20:13:47.431Z"
                                  }
                                ]
                , test "Dedupes aggregated accounts" <|
                    \() ->
                        Fixtures.duplicateAccountNotifications
                            |> aggregateNotifications
                            |> List.map (.accounts >> List.length)
                            |> Expect.equal [ 1 ]
                , test "Add follows notification to aggregate" <|
                    \() ->
                        Fixtures.notifications
                            |> aggregateNotifications
                            |> (addNotificationToAggregates Fixtures.notificationPloumFollowsVjousse)
                            |> Expect.equal
                                [ { id = .id Fixtures.notificationNicoMentionVjousse
                                  , type_ = "mention"
                                  , status = Just Fixtures.statusNicoToVjousse
                                  , accounts =
                                        [ { account = Fixtures.accountNico
                                          , created_at = "2017-04-24T20:16:20.973Z"
                                          }
                                        ]
                                  , created_at = "2017-04-24T20:16:20.973Z"
                                  }
                                , { id = .id Fixtures.notificationNicoFollowsVjousse
                                  , type_ = "follow"
                                  , status = Nothing
                                  , accounts =
                                        [ { account = Fixtures.accountPloum
                                          , created_at = "2017-04-24T18:12:47.431Z"
                                          }
                                        , { account = Fixtures.accountNico
                                          , created_at = "2017-04-24T20:13:47.431Z"
                                          }
                                        , { account = Fixtures.accountSkro
                                          , created_at = "2017-04-24T19:12:47.431Z"
                                          }
                                        ]
                                  , created_at = "2017-04-24T20:13:47.431Z"
                                  }
                                ]
                , test "Add mention notification to aggregate" <|
                    \() ->
                        Fixtures.notifications
                            |> aggregateNotifications
                            |> (addNotificationToAggregates Fixtures.notificationNicoMentionVjousse)
                            |> Expect.equal
                                [ { id = .id Fixtures.notificationNicoMentionVjousse
                                  , type_ = "mention"
                                  , status = Just Fixtures.statusNicoToVjousse
                                  , accounts =
                                        [ { account = Fixtures.accountNico
                                          , created_at = "2017-04-24T20:16:20.973Z"
                                          }
                                        , { account = Fixtures.accountNico
                                          , created_at = "2017-04-24T20:16:20.973Z"
                                          }
                                        ]
                                  , created_at = "2017-04-24T20:16:20.973Z"
                                  }
                                , { id = .id Fixtures.notificationNicoFollowsVjousse
                                  , type_ = "follow"
                                  , status = Nothing
                                  , accounts =
                                        [ { account = Fixtures.accountNico
                                          , created_at = "2017-04-24T20:13:47.431Z"
                                          }
                                        , { account = Fixtures.accountSkro
                                          , created_at = "2017-04-24T19:12:47.431Z"
                                          }
                                        ]
                                  , created_at = "2017-04-24T20:13:47.431Z"
                                  }
                                ]
                , test "Add new mention notification to aggregate" <|
                    \() ->
                        Fixtures.notifications
                            |> aggregateNotifications
                            |> (addNotificationToAggregates Fixtures.notificationNicoMentionVjousseAgain)
                            |> Expect.equal
                                [ { id = .id Fixtures.notificationNicoMentionVjousseAgain
                                  , type_ = "mention"
                                  , status = Just Fixtures.statusNicoToVjousseAgain
                                  , accounts =
                                        [ { account = Fixtures.accountNico
                                          , created_at = "2017-04-25T07:41:23.546Z"
                                          }
                                        ]
                                  , created_at = "2017-04-25T07:41:23.546Z"
                                  }
                                , { id = .id Fixtures.notificationNicoMentionVjousse
                                  , type_ = "mention"
                                  , status = Just Fixtures.statusNicoToVjousse
                                  , accounts =
                                        [ { account = Fixtures.accountNico
                                          , created_at = "2017-04-24T20:16:20.973Z"
                                          }
                                        ]
                                  , created_at = "2017-04-24T20:16:20.973Z"
                                  }
                                , { id = .id Fixtures.notificationNicoFollowsVjousse
                                  , type_ = "follow"
                                  , status = Nothing
                                  , accounts =
                                        [ { account = Fixtures.accountNico
                                          , created_at = "2017-04-24T20:13:47.431Z"
                                          }
                                        , { account = Fixtures.accountSkro
                                          , created_at = "2017-04-24T19:12:47.431Z"
                                          }
                                        ]
                                  , created_at = "2017-04-24T20:13:47.431Z"
                                  }
                                ]
                ]
            ]
        ]
