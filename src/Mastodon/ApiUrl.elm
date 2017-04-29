module Mastodon.ApiUrl
    exposing
        ( apps
        , oauthAuthorize
        , oauthToken
        , userAccount
        , account
        , accountTimeline
        , status
        , homeTimeline
        , publicTimeline
        , notifications
        , statuses
        , context
        , reblog
        , unreblog
        , favourite
        , unfavourite
        , streaming
        )


type alias Server =
    String


apps : Server -> String
apps server =
    server ++ "/api/v1/apps"


oauthAuthorize : Server -> String
oauthAuthorize server =
    server ++ "/oauth/authorize"


oauthToken : Server -> String
oauthToken server =
    server ++ "/oauth/token"


accounts : String
accounts =
    "/api/v1/accounts/"


account : Int -> String
account id =
    accounts ++ (toString id)


userAccount : Server -> String
userAccount server =
    server ++ accounts ++ "verify_credentials"


homeTimeline : String
homeTimeline =
    "/api/v1/timelines/home"


publicTimeline : Maybe String -> String
publicTimeline local =
    let
        isLocal =
            case local of
                Just local ->
                    "?local=true"

                Nothing ->
                    ""
    in
        "/api/v1/timelines/public" ++ isLocal


accountTimeline : Int -> String
accountTimeline id =
    (account id) ++ "/statuses"


notifications : String
notifications =
    "/api/v1/notifications"


statuses : Server -> String
statuses server =
    server ++ "/api/v1/statuses"


context : Server -> Int -> String
context server id =
    statuses server ++ "/" ++ (toString id) ++ "/context"


reblog : Server -> Int -> String
reblog server id =
    statuses server ++ "/" ++ (toString id) ++ "/reblog"


status : Server -> Int -> String
status server id =
    statuses server ++ "/" ++ (toString id)


unreblog : Server -> Int -> String
unreblog server id =
    statuses server ++ "/" ++ (toString id) ++ "/unreblog"


favourite : Server -> Int -> String
favourite server id =
    statuses server ++ "/" ++ (toString id) ++ "/favourite"


unfavourite : Server -> Int -> String
unfavourite server id =
    statuses server ++ "/" ++ (toString id) ++ "/unfavourite"


streaming : Server -> String
streaming server =
    server ++ "/api/v1/streaming/"
