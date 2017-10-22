module Mastodon.ApiUrl
    exposing
        ( apps
        , oauthAuthorize
        , oauthToken
        , userAccount
        , account
        , accountTimeline
        , followers
        , following
        , status
        , homeTimeline
        , publicTimeline
        , favouriteTimeline
        , hashtag
        , mutes
        , blocks
        , notifications
        , relationships
        , statuses
        , context
        , reblog
        , unreblog
        , favourite
        , unfavourite
        , follow
        , unfollow
        , mute
        , unmute
        , block
        , unblock
        , uploadMedia
        , streaming
        , searchAccount
        , search
        )


apiPrefix : String
apiPrefix =
    "/api/v1"


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
    apiPrefix ++ "/search"


searchAccount : String
searchAccount =
    accounts ++ "search"


relationships : String
relationships =
    accounts ++ "relationships"


followers : String -> String
followers id =
    id ++ "/followers"


following : String -> String
following id =
    id ++ "/following"


homeTimeline : String
homeTimeline =
    apiPrefix ++ "/timelines/home"


publicTimeline : String
publicTimeline =
    apiPrefix ++ "/timelines/public"


accountTimeline : String -> String
accountTimeline id =
    id ++ "/statuses"


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


context : String -> String
context id =
    statuses ++ "/" ++ id ++ "/context"


reblog : String -> String
reblog id =
    statuses ++ "/" ++ id ++ "/reblog"


status : String -> String
status id =
    statuses ++ "/" ++ id


unreblog : String -> String
unreblog id =
    statuses ++ "/" ++ id ++ "/unreblog"


favourite : String -> String
favourite id =
    statuses ++ "/" ++ id ++ "/favourite"


unfavourite : String -> String
unfavourite id =
    statuses ++ "/" ++ id ++ "/unfavourite"


streaming : String
streaming =
    apiPrefix ++ "/streaming/"


uploadMedia : String
uploadMedia =
    apiPrefix ++ "/media"
