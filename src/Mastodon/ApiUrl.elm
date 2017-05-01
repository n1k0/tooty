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

import Mastodon.Encoder exposing (encodeUrl)


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


follow : Server -> Int -> String
follow server id =
    server ++ accounts ++ (toString id) ++ "/follow"


unfollow : Server -> Int -> String
unfollow server id =
    server ++ accounts ++ (toString id) ++ "/unfollow"


userAccount : Server -> String
userAccount server =
    server ++ accounts ++ "verify_credentials"


searchAccount : Server -> String -> Int -> Bool -> String
searchAccount server query limit resolve =
    encodeUrl (server ++ accounts ++ "search")
        [ ( "q", query )
        , ( "limit", toString limit )
        , ( "resolve"
          , if resolve then
                "true"
            else
                "false"
          )
        ]


relationships : List Int -> String
relationships ids =
    encodeUrl (accounts ++ "relationships") <|
        (List.map (\id -> ( "id[]", toString id )) ids)


followers : Int -> String
followers id =
    (account id) ++ "/followers"


following : Int -> String
following id =
    (account id) ++ "/following"


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
