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


account : Int -> String
account id =
    accounts ++ (toString id)


follow : Int -> String
follow id =
    accounts ++ (toString id) ++ "/follow"


unfollow : Int -> String
unfollow id =
    accounts ++ (toString id) ++ "/unfollow"


mute : Int -> String
mute id =
    accounts ++ (toString id) ++ "/mute"


unmute : Int -> String
unmute id =
    accounts ++ (toString id) ++ "/unmute"


block : Int -> String
block id =
    accounts ++ (toString id) ++ "/block"


unblock : Int -> String
unblock id =
    accounts ++ (toString id) ++ "/unblock"


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


followers : Int -> String
followers id =
    (account id) ++ "/followers"


following : Int -> String
following id =
    (account id) ++ "/following"


homeTimeline : String
homeTimeline =
    apiPrefix ++ "/timelines/home"


publicTimeline : String
publicTimeline =
    apiPrefix ++ "/timelines/public"


accountTimeline : Int -> String
accountTimeline id =
    (account id) ++ "/statuses"


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


context : Int -> String
context id =
    statuses ++ "/" ++ (toString id) ++ "/context"


reblog : Int -> String
reblog id =
    statuses ++ "/" ++ (toString id) ++ "/reblog"


status : Int -> String
status id =
    statuses ++ "/" ++ (toString id)


unreblog : Int -> String
unreblog id =
    statuses ++ "/" ++ (toString id) ++ "/unreblog"


favourite : Int -> String
favourite id =
    statuses ++ "/" ++ (toString id) ++ "/favourite"


unfavourite : Int -> String
unfavourite id =
    statuses ++ "/" ++ (toString id) ++ "/unfavourite"


streaming : String
streaming =
    apiPrefix ++ "/streaming/"


uploadMedia : String
uploadMedia =
    apiPrefix ++ "/media"
