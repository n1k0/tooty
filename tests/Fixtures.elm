module Fixtures exposing (..)

import Mastodon.Model exposing (Account, Notification, NotificationAggregate, Status)


accountSkro : Account
accountSkro =
    { acct = "SkroZoC"
    , avatar = "https://mamot.fr/system/accounts/avatars/000/001/391/original/76be3c9d1b34f59b.jpeg?1493042489"
    , created_at = "2017-04-24T20:25:37.398Z"
    , display_name = "Skro"
    , followers_count = 77
    , following_count = 80
    , header = "https://mamot.fr/system/accounts/headers/000/001/391/original/9fbb4ac980f04fe1.gif?1493042489"
    , id = 1391
    , locked = False
    , note = "N&apos;importe quoi très vite en 500 caractères. La responsabilité du triumvirat de ZoC ne peut être engagée."
    , statuses_count = 161
    , url = "https://mamot.fr/@SkroZoC"
    , username = "SkroZoC"
    }


accountVjousse : Account
accountVjousse =
    { acct = "vjousse"
    , avatar = "https://mamot.fr/system/accounts/avatars/000/026/303/original/b72c0dd565e5bc1e.png?1492698808"
    , created_at = "2017-04-20T14:31:05.751Z"
    , display_name = "Vincent Jousse"
    , followers_count = 68
    , following_count = 31
    , header = "https://mamot.fr/headers/original/missing.png"
    , id = 26303
    , locked = False
    , note = "Libriste, optimiste et utopiste. On est bien tintin."
    , statuses_count = 88
    , url = "https://mamot.fr/@vjousse"
    , username = "vjousse"
    }


accountNico : Account
accountNico =
    { acct = "n1k0"
    , avatar = "https://mamot.fr/system/accounts/avatars/000/017/784/original/40052904e484d9c0.jpg?1492158615"
    , created_at = "2017-04-14T08:28:59.706Z"
    , display_name = "NiKo`"
    , followers_count = 162
    , following_count = 79
    , header = "https://mamot.fr/system/accounts/headers/000/017/784/original/ea87200d852018a8.jpg?1492158674"
    , id = 17784
    , locked = False
    , note = "Transforme sa procrastination en pouets, la plupart du temps en français."
    , statuses_count = 358
    , url = "https://mamot.fr/@n1k0"
    , username = "n1k0"
    }


accountPloum : Account
accountPloum =
    { acct = "ploum"
    , avatar = "https://mamot.fr/system/accounts/avatars/000/006/840/original/593a817d651d9253.jpg?1491814416"
    , created_at = "2017-04-08T09:37:34.931Z"
    , display_name = "ploum"
    , followers_count = 1129
    , following_count = 91
    , header = "https://mamot.fr/system/accounts/headers/000/006/840/original/7e0adc1f754dafbe.jpg?1491814416"
    , id = 6840
    , locked = False
    , note = "Futurologue, conférencier, blogueur et écrivain électronique. Du moins, je l&apos;espère. :bicyclist:"
    , statuses_count = 601
    , url = "https://mamot.fr/@ploum"
    , username = "ploum"
    }


statusNicoToVjousse : Status
statusNicoToVjousse =
    { account = accountNico
    , content = "<p><span class=\"h-card\"><a href=\"https://mamot.fr/@vjousse\" class=\"u-url mention\">@<span>vjousse</span></a></span> j&apos;ai rien touché à ce niveau là non</p>"
    , created_at = "2017-04-24T20:16:20.922Z"
    , favourited = Nothing
    , favourites_count = 0
    , id = 737932
    , in_reply_to_account_id = Just 26303
    , in_reply_to_id = Just 737425
    , media_attachments = []
    , mentions =
        [ { id = 26303
          , url = "https://mamot.fr/@vjousse"
          , username = "vjousse"
          , acct = "vjousse"
          }
        ]
    , reblog = Nothing
    , reblogged = Nothing
    , reblogs_count = 0
    , sensitive = Just False
    , spoiler_text = ""
    , tags = []
    , uri = "tag:mamot.fr,2017-04-24:objectId=737932:objectType=Status"
    , url = "https://mamot.fr/@n1k0/737932"
    , visibility = "public"
    }


statusNicoToVjousseAgain : Status
statusNicoToVjousseAgain =
    { account = accountNico
    , content = "<p><span class=\"h-card\"><a href=\"https://mamot.fr/@vjousse\" class=\"u-url mention\">@<span>vjousse</span></a></span> oui j&apos;ai vu, c&apos;est super, après on est à +473 −13, à un moment tu vas te prendre la tête 😂</p>"
    , created_at = "2017-04-25T07:41:23.492Z"
    , favourited = Nothing
    , favourites_count = 0
    , id = 752169
    , in_reply_to_account_id = Just 26303
    , in_reply_to_id = Just 752153
    , media_attachments = []
    , mentions =
        [ { id = 26303
          , url = "https://mamot.fr/@vjousse"
          , username = "vjousse"
          , acct = "vjousse"
          }
        ]
    , reblog = Nothing
    , reblogged = Nothing
    , reblogs_count = 0
    , sensitive = Just False
    , spoiler_text = ""
    , tags = []
    , uri = "tag:mamot.fr,2017-04-25:objectId=752169:objectType=Status"
    , url = "https://mamot.fr/@n1k0/752169"
    , visibility = "public"
    }


notificationNicoMentionVjousse : Notification
notificationNicoMentionVjousse =
    { id = 224284
    , type_ = "mention"
    , created_at = "2017-04-24T20:16:20.973Z"
    , account = accountNico
    , status = Just statusNicoToVjousse
    }


notificationNicoMentionVjousseAgain : Notification
notificationNicoMentionVjousseAgain =
    { id = 226516
    , type_ = "mention"
    , created_at = "2017-04-25T07:41:23.546Z"
    , account = accountNico
    , status = Just statusNicoToVjousseAgain
    }


notificationNicoFollowsVjousse : Notification
notificationNicoFollowsVjousse =
    { id = 224257
    , type_ = "follow"
    , created_at = "2017-04-24T20:13:47.431Z"
    , account = accountNico
    , status = Nothing
    }


notificationSkroFollowsVjousse : Notification
notificationSkroFollowsVjousse =
    { id = 224
    , type_ = "follow"
    , created_at = "2017-04-24T19:12:47.431Z"
    , account = accountSkro
    , status = Nothing
    }


notificationPloumFollowsVjousse : Notification
notificationPloumFollowsVjousse =
    { id = 220
    , type_ = "follow"
    , created_at = "2017-04-24T18:12:47.431Z"
    , account = accountPloum
    , status = Nothing
    }


accounts : List Account
accounts =
    [ accountSkro, accountVjousse, accountNico ]


notifications : List Notification
notifications =
    [ notificationNicoMentionVjousse
    , notificationNicoFollowsVjousse
    , notificationSkroFollowsVjousse
    ]


duplicateAccountNotifications : List Notification
duplicateAccountNotifications =
    [ notificationSkroFollowsVjousse
    , notificationSkroFollowsVjousse
    , notificationSkroFollowsVjousse
    ]


notificationAggregates : List NotificationAggregate
notificationAggregates =
    [ { type_ = "mention"
      , status = Nothing
      , accounts = []
      , created_at = ""
      }
    ]
