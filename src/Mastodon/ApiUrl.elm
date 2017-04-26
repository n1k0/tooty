module Mastodon.ApiUrl exposing (..)


appsUrl : String
appsUrl =
    "/api/v1/apps"


oauthAuthorizeUrl : String
oauthAuthorizeUrl =
    "/oauth/authorize"


oauthTokenUrl : String
oauthTokenUrl =
    "/oauth/token"


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


statusesUrl : String
statusesUrl =
    "/api/v1/statuses"


reblogUrl : Int -> String
reblogUrl id =
    statusesUrl ++ (toString id) ++ "/reblog"


unreblogUrl : Int -> String
unreblogUrl id =
    statusesUrl ++ (toString id) ++ "/unreblog"


favouriteUrl : Int -> String
favouriteUrl id =
    statusesUrl ++ (toString id) ++ "/favourite"


unfavouriteUrl : Int -> String
unfavouriteUrl id =
    statusesUrl ++ (toString id) ++ "/unfavourite"


streamingUrl : String
streamingUrl =
    "/api/v1/streaming/"
