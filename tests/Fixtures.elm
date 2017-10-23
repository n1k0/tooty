module Fixtures exposing (..)

import Mastodon.Model exposing (..)


accountSkro : Account
accountSkro =
    { acct = "SkroZoC"
    , avatar = ""
    , created_at = "2017-04-24T20:25:37.398Z"
    , display_name = "Skro"
    , followers_count = 77
    , following_count = 80
    , header = ""
    , id = "1391"
    , locked = False
    , note = "Skro note"
    , statuses_count = 161
    , url = "https://mamot.fr/@SkroZoC"
    , username = "SkroZoC"
    }


accountVjousse : Account
accountVjousse =
    { acct = "vjousse"
    , avatar = ""
    , created_at = "2017-04-20T14:31:05.751Z"
    , display_name = "Vincent Jousse"
    , followers_count = 68
    , following_count = 31
    , header = ""
    , id = "26303"
    , locked = False
    , note = "Vjousse note"
    , statuses_count = 88
    , url = "https://mamot.fr/@vjousse"
    , username = "vjousse"
    }


accountNico : Account
accountNico =
    { acct = "n1k0"
    , avatar = ""
    , created_at = "2017-04-14T08:28:59.706Z"
    , display_name = "NiKo`"
    , followers_count = 162
    , following_count = 79
    , header = ""
    , id = "17784"
    , locked = False
    , note = "Niko note"
    , statuses_count = 358
    , url = "https://mamot.fr/@n1k0"
    , username = "n1k0"
    }


accountPloum : Account
accountPloum =
    { acct = "ploum"
    , avatar = ""
    , created_at = "2017-04-08T09:37:34.931Z"
    , display_name = "ploum"
    , followers_count = 1129
    , following_count = 91
    , header = ""
    , id = "6840"
    , locked = False
    , note = "Ploum note"
    , statuses_count = 601
    , url = "https://mamot.fr/@ploum"
    , username = "ploum"
    }


statusNico : Status
statusNico =
    { account = accountNico
    , application = Nothing
    , content = "<p>hello</p>"
    , created_at = "2017-04-24T20:12:20.922Z"
    , favourited = Nothing
    , favourites_count = 0
    , id = StatusId "737931"
    , in_reply_to_account_id = Nothing
    , in_reply_to_id = Nothing
    , media_attachments = []
    , mentions = []
    , reblog = Nothing
    , reblogged = Nothing
    , reblogs_count = 0
    , sensitive = Just False
    , spoiler_text = ""
    , tags = []
    , uri = "tag:mamot.fr,2017-04-24:objectId=737932:objectType=Status"
    , url = Just "https://mamot.fr/@n1k0/737931"
    , visibility = "public"
    }


statusNicoToVjousse : Status
statusNicoToVjousse =
    { account = accountNico
    , application = Nothing
    , content = "<p>@vjousse coucou</p>"
    , created_at = "2017-04-24T20:16:20.922Z"
    , favourited = Nothing
    , favourites_count = 0
    , id = StatusId "737932"
    , in_reply_to_account_id = Just "26303"
    , in_reply_to_id = Just <| StatusId "737425"
    , media_attachments = []
    , mentions =
        [ { id = "26303"
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
    , url = Just "https://mamot.fr/@n1k0/737932"
    , visibility = "public"
    }


statusNicoToVjousseAgain : Status
statusNicoToVjousseAgain =
    { account = accountNico
    , application = Nothing
    , content = "<p>@vjousse recoucou</p>"
    , created_at = "2017-04-25T07:41:23.492Z"
    , favourited = Nothing
    , favourites_count = 0
    , id = StatusId "752169"
    , in_reply_to_account_id = Just "26303"
    , in_reply_to_id = Just <| StatusId "752153"
    , media_attachments = []
    , mentions =
        [ { id = "26303"
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
    , url = Just "https://mamot.fr/@n1k0/752169"
    , visibility = "public"
    }


statusPloumToVjousse : Status
statusPloumToVjousse =
    { account = accountPloum
    , application = Nothing
    , content = "<p>hey @vjousse</p>"
    , created_at = "2017-04-25T07:41:23.492Z"
    , favourited = Nothing
    , favourites_count = 0
    , id = StatusId "752169"
    , in_reply_to_account_id = Nothing
    , in_reply_to_id = Nothing
    , media_attachments = []
    , mentions =
        [ { id = "26303"
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
    , url = Just "https://mamot.fr/@n1k0/752169"
    , visibility = "public"
    }


statusReblogged : Status
statusReblogged =
    { account = accountVjousse
    , application = Nothing
    , content = "<p>fake post</p>"
    , created_at = "2017-04-24T20:16:20.922Z"
    , favourited = Nothing
    , favourites_count = 0
    , id = StatusId "737932"
    , in_reply_to_account_id = Nothing
    , in_reply_to_id = Nothing
    , media_attachments = []
    , mentions = []
    , reblog = Just (Reblog statusPloumToVjousse)
    , reblogged = Nothing
    , reblogs_count = 0
    , sensitive = Just False
    , spoiler_text = ""
    , tags = []
    , uri = "tag:mamot.fr,2017-04-24:objectId=737932:objectType=Status"
    , url = Just "https://mamot.fr/@n1k0/737932"
    , visibility = "public"
    }


notificationNicoMentionVjousse : Notification
notificationNicoMentionVjousse =
    { id = "224284"
    , type_ = "mention"
    , created_at = "2017-04-24T20:16:20.973Z"
    , account = accountNico
    , status = Just statusNicoToVjousse
    }


notificationNicoMentionVjousseAgain : Notification
notificationNicoMentionVjousseAgain =
    { id = "226516"
    , type_ = "mention"
    , created_at = "2017-04-25T07:41:23.546Z"
    , account = accountNico
    , status = Just statusNicoToVjousseAgain
    }


notificationNicoFollowsVjousse : Notification
notificationNicoFollowsVjousse =
    { id = "224257"
    , type_ = "follow"
    , created_at = "2017-04-24T20:13:47.431Z"
    , account = accountNico
    , status = Nothing
    }


notificationSkroFollowsVjousse : Notification
notificationSkroFollowsVjousse =
    { id = "224"
    , type_ = "follow"
    , created_at = "2017-04-24T19:12:47.431Z"
    , account = accountSkro
    , status = Nothing
    }


notificationPloumFollowsVjousse : Notification
notificationPloumFollowsVjousse =
    { id = "220"
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
