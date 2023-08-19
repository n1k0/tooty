module Mastodon.ApiUrl exposing
    ( account
    , accountTimeline
    , apps
    , block
    , blocks
    , context
    , favourite
    , favouriteTimeline
    , follow
    , followers
    , following
    , hashtag
    , homeTimeline
    , mute
    , mutes
    , notifications
    , oauthAuthorize
    , oauthToken
    , publicTimeline
    , reblog
    , relationships
    , search
    , searchAccount
    , source
    , status
    , statuses
    , streaming
    , unblock
    , unfavourite
    , unfollow
    , unmute
    , unreblog
    , uploadMedia
    , userAccount
    )

import Mastodon.Model exposing (StatusId(..))


apiPrefix : String
apiPrefix =
    "/api/v1"


apiV2Prefix : String
apiV2Prefix =
    "/api/v2"


apps : String
apps =
    apiPrefix ++ "/apps"


oauthAuthorize : String
oauthAuthorize =
    "/oauth/authorize"


oauthToken : String
oauthToken =
    "/oauth/token"


accounts : String
accounts =
    apiPrefix ++ "/accounts/"


account : String -> String
account id =
    accounts ++ id


follow : String -> String
follow id =
    accounts ++ id ++ "/follow"


unfollow : String -> String
unfollow id =
    accounts ++ id ++ "/unfollow"


mute : String -> String
mute id =
    accounts ++ id ++ "/mute"


unmute : String -> String
unmute id =
    accounts ++ id ++ "/unmute"


block : String -> String
block id =
    accounts ++ id ++ "/block"


unblock : String -> String
unblock id =
    accounts ++ id ++ "/unblock"


userAccount : String
userAccount =
    accounts ++ "verify_credentials"


search : String
search =
    apiV2Prefix ++ "/search"


searchAccount : String
searchAccount =
    accounts ++ "search"


relationships : String
relationships =
    accounts ++ "relationships"


followers : String -> String
followers id =
    account id ++ "/followers"


following : String -> String
following id =
    account id ++ "/following"


homeTimeline : String
homeTimeline =
    apiPrefix ++ "/timelines/home"


publicTimeline : String
publicTimeline =
    apiPrefix ++ "/timelines/public"


accountTimeline : String -> String
accountTimeline id =
    account id ++ "/statuses"


favouriteTimeline : String
favouriteTimeline =
    apiPrefix ++ "/favourites"


hashtag : String -> String
hashtag tag =
    apiPrefix ++ "/timelines/tag/" ++ tag


mutes : String
mutes =
    apiPrefix ++ "/mutes"


blocks : String
blocks =
    apiPrefix ++ "/blocks"


notifications : String
notifications =
    apiPrefix ++ "/notifications"


statuses : String
statuses =
    apiPrefix ++ "/statuses"


context : StatusId -> String
context (StatusId id) =
    statuses ++ "/" ++ id ++ "/context"


reblog : StatusId -> String
reblog (StatusId id) =
    statuses ++ "/" ++ id ++ "/reblog"


status : StatusId -> String
status (StatusId id) =
    statuses ++ "/" ++ id


unreblog : StatusId -> String
unreblog (StatusId id) =
    statuses ++ "/" ++ id ++ "/unreblog"


favourite : StatusId -> String
favourite (StatusId id) =
    statuses ++ "/" ++ id ++ "/favourite"


unfavourite : StatusId -> String
unfavourite (StatusId id) =
    statuses ++ "/" ++ id ++ "/unfavourite"



-- https://docs.joinmastodon.org/methods/statuses/#source


source : StatusId -> String
source (StatusId id) =
    statuses ++ "/" ++ id ++ "/source"


streaming : String
streaming =
    apiPrefix ++ "/streaming/"


uploadMedia : String
uploadMedia =
    apiPrefix ++ "/media"
