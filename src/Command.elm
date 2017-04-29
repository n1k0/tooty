module Command
    exposing
        ( initCommands
        , navigateToAuthUrl
        , registerApp
        , saveClient
        , saveRegistration
        , loadNotifications
        , loadUserAccount
        , loadAccount
        , loadAccountInfo
        , loadThread
        , loadTimelines
        , postStatus
        , deleteStatus
        , reblogStatus
        , unreblogStatus
        , favouriteStatus
        , unfavouriteStatus
        )

import Json.Encode as Encode
import Mastodon.Model exposing (..)
import Mastodon.Encoder
import Mastodon.Http
import Navigation
import Ports
import Types exposing (..)


initCommands : Maybe AppRegistration -> Maybe Client -> Maybe String -> Cmd Msg
initCommands registration client authCode =
    Cmd.batch <|
        case authCode of
            Just authCode ->
                case registration of
                    Just registration ->
                        [ Mastodon.Http.getAccessToken registration authCode
                            |> Mastodon.Http.send (MastodonEvent << AccessToken)
                        ]

                    Nothing ->
                        []

            Nothing ->
                [ loadUserAccount client, loadTimelines client ]


navigateToAuthUrl : AppRegistration -> Cmd Msg
navigateToAuthUrl registration =
    Navigation.load <| Mastodon.Http.getAuthorizationUrl registration


registerApp : Model -> Cmd Msg
registerApp { server, location } =
    let
        appUrl =
            location.origin ++ location.pathname

        cleanServer =
            if String.endsWith "/" server then
                String.dropRight 1 server
            else
                server
    in
        Mastodon.Http.register
            cleanServer
            "tooty"
            appUrl
            "read write follow"
            "https://github.com/n1k0/tooty"
            |> Mastodon.Http.send (MastodonEvent << AppRegistered)


saveClient : Client -> Cmd Msg
saveClient client =
    Mastodon.Encoder.clientEncoder client
        |> Encode.encode 0
        |> Ports.saveClient


saveRegistration : AppRegistration -> Cmd Msg
saveRegistration registration =
    Mastodon.Encoder.registrationEncoder registration
        |> Encode.encode 0
        |> Ports.saveRegistration


loadNotifications : Maybe Client -> Cmd Msg
loadNotifications client =
    case client of
        Just client ->
            Mastodon.Http.fetchNotifications client
                |> Mastodon.Http.send (MastodonEvent << Notifications)

        Nothing ->
            Cmd.none


loadUserAccount : Maybe Client -> Cmd Msg
loadUserAccount client =
    case client of
        Just client ->
            Mastodon.Http.userAccount client
                |> Mastodon.Http.send (MastodonEvent << CurrentUser)

        Nothing ->
            Cmd.none


loadAccount : Maybe Client -> Int -> Cmd Msg
loadAccount client accountId =
    case client of
        Just client ->
            Mastodon.Http.fetchAccount client accountId
                |> Mastodon.Http.send (MastodonEvent << AccountReceived)

        Nothing ->
            Cmd.none


loadAccountInfo : Maybe Client -> Int -> Cmd Msg
loadAccountInfo client accountId =
    case client of
        Just client ->
            Cmd.batch
                [ Mastodon.Http.fetchAccountTimeline client accountId
                    |> Mastodon.Http.send (MastodonEvent << AccountTimeline)
                , Mastodon.Http.fetchAccountFollowers client accountId
                    |> Mastodon.Http.send (MastodonEvent << AccountFollowers)
                , Mastodon.Http.fetchAccountFollowing client accountId
                    |> Mastodon.Http.send (MastodonEvent << AccountFollowing)
                ]

        Nothing ->
            Cmd.none


loadThread : Maybe Client -> Status -> Cmd Msg
loadThread client status =
    case client of
        Just client ->
            Mastodon.Http.context client status.id
                |> Mastodon.Http.send (MastodonEvent << (ContextLoaded status))

        Nothing ->
            Cmd.none


loadTimelines : Maybe Client -> Cmd Msg
loadTimelines client =
    case client of
        Just client ->
            Cmd.batch
                [ Mastodon.Http.fetchUserTimeline client
                    |> Mastodon.Http.send (MastodonEvent << UserTimeline)
                , Mastodon.Http.fetchLocalTimeline client
                    |> Mastodon.Http.send (MastodonEvent << LocalTimeline)
                , Mastodon.Http.fetchGlobalTimeline client
                    |> Mastodon.Http.send (MastodonEvent << GlobalTimeline)
                , loadNotifications <| Just client
                ]

        Nothing ->
            Cmd.none


postStatus : Maybe Client -> StatusRequestBody -> Cmd Msg
postStatus client draft =
    case client of
        Just client ->
            Mastodon.Http.postStatus client draft
                |> Mastodon.Http.send (MastodonEvent << StatusPosted)

        Nothing ->
            Cmd.none


deleteStatus : Maybe Client -> Int -> Cmd Msg
deleteStatus client id =
    case client of
        Just client ->
            Mastodon.Http.deleteStatus client id
                |> Mastodon.Http.send (MastodonEvent << StatusDeleted)

        Nothing ->
            Cmd.none


reblogStatus : Maybe Client -> Int -> Cmd Msg
reblogStatus client statusId =
    case client of
        Just client ->
            Mastodon.Http.reblog client statusId
                |> Mastodon.Http.send (MastodonEvent << Reblogged)

        Nothing ->
            Cmd.none


unreblogStatus : Maybe Client -> Int -> Cmd Msg
unreblogStatus client statusId =
    case client of
        Just client ->
            Mastodon.Http.unreblog client statusId
                |> Mastodon.Http.send (MastodonEvent << Unreblogged)

        Nothing ->
            Cmd.none


favouriteStatus : Maybe Client -> Int -> Cmd Msg
favouriteStatus client statusId =
    case client of
        Just client ->
            Mastodon.Http.favourite client statusId
                |> Mastodon.Http.send (MastodonEvent << FavoriteAdded)

        Nothing ->
            Cmd.none


unfavouriteStatus : Maybe Client -> Int -> Cmd Msg
unfavouriteStatus client statusId =
    case client of
        Just client ->
            Mastodon.Http.unfavourite client statusId
                |> Mastodon.Http.send (MastodonEvent << FavoriteRemoved)

        Nothing ->
            Cmd.none
