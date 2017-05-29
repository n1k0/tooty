module Update.AccountInfo exposing (empty)

import Types exposing (..)
import Update.Timeline


empty : AccountInfo
empty =
    { account = Nothing
    , timeline = Update.Timeline.empty "account-timeline"
    , followers = Update.Timeline.empty "account-followers"
    , following = Update.Timeline.empty "account-following"
    , relationships = []
    , relationship = Nothing
    }
