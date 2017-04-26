module Mastodon.ApiUrl exposing (..)


appsUrl : String -> String
appsUrl server =
    server ++ "/api/v1/apps"


oauthAuthorizeUrl : String -> String
oauthAuthorizeUrl server =
    server ++ "/oauth/authorize"


oauthTokenUrl : String -> String
oauthTokenUrl server =
    server ++ "/oauth/token"


accountsUrl : String
accountsUrl =
    "/api/v1/accounts/"


accountUrl : Int -> String
accountUrl id =
    accountsUrl ++ (toString id)


homeTimelineUrl : String
homeTimelineUrl =
    "/api/v1/timelines/home"


publicTimelineUrl : Maybe String -> String
publicTimelineUrl local =
    let
        isLocal =
            case local of
                Just local ->
                    "?local=true"

                Nothing ->
                    ""
    in
        "/api/v1/timelines/public" ++ isLocal


notificationsUrl : String
notificationsUrl =
    "/api/v1/notifications"


statusesUrl : String -> String
statusesUrl server =
    server ++ "/api/v1/statuses"


reblogUrl : String -> Int -> String
reblogUrl server id =
    statusesUrl server ++ (toString id) ++ "/reblog"


unreblogUrl : String -> Int -> String
unreblogUrl server id =
    statusesUrl server ++ (toString id) ++ "/unreblog"


favouriteUrl : String -> Int -> String
favouriteUrl server id =
    statusesUrl server ++ (toString id) ++ "/favourite"


unfavouriteUrl : String -> Int -> String
unfavouriteUrl server id =
    statusesUrl server ++ (toString id) ++ "/unfavourite"


streamingUrl : String -> String
streamingUrl server =
    server ++ "/api/v1/streaming/"
