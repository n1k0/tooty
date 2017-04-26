module Mastodon.ApiUrl
    exposing
        ( apps
        , oauthAuthorize
        , oauthToken
        , account
        , homeTimeline
        , publicTimeline
        , notifications
        , statuses
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


notifications : String
notifications =
    "/api/v1/notifications"


statuses : Server -> String
statuses server =
    server ++ "/api/v1/statuses"


reblog : Server -> Int -> String
reblog server id =
    statuses server ++ (toString id) ++ "/reblog"


unreblog : Server -> Int -> String
unreblog server id =
    statuses server ++ (toString id) ++ "/unreblog"


favourite : Server -> Int -> String
favourite server id =
    statuses server ++ (toString id) ++ "/favourite"


unfavourite : Server -> Int -> String
unfavourite server id =
    statuses server ++ (toString id) ++ "/unfavourite"


streaming : Server -> String
streaming server =
    server ++ "/api/v1/streaming/"
