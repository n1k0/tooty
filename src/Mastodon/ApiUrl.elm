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
        , streaming
        , searchAccount
        )


apiPrefix : String
apiPrefix =
    "/api/v1/"


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


userAccount : String
userAccount =
    accounts ++ "verify_credentials"


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
