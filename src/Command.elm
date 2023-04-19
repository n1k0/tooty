module Command exposing
    ( block
    , deleteStatus
    , favouriteStatus
    , focusId
    , follow
    , initCommands
    , loadAccount
    , loadAccountFollowers
    , loadAccountFollowing
    , loadAccountTimeline
    , loadBlocks
    , loadFavoriteTimeline
    , loadGlobalTimeline
    , loadHashtagTimeline
    , loadHomeTimeline
    , loadLocalTimeline
    , loadMutes
    , loadNextTimeline
    , loadNotifications
    , loadRelationships
    , loadThread
    , loadTimelines
    , loadUserAccount
    , mute
    , navigateToAuthUrl
    , notifyNotification
    , notifyStatus
    , postStatus
    , reblogStatus
    , registerApp
    , saveClients
    , saveRegistration
    , scrollColumnToBottom
    , scrollColumnToTop
    , scrollToThreadStatus
    , search
    , searchAccounts
    , unblock
    , unfavouriteStatus
    , unfollow
    , unmute
    , unreblogStatus
    , updateDomStatus
    , uploadMedia
    )

import Browser.Dom as Dom
import Browser.Navigation as Navigation
import HttpBuilder
import Json.Decode as Decode
import Json.Encode as Encode
import Mastodon.ApiUrl as ApiUrl
import Mastodon.Decoder exposing (..)
import Mastodon.Encoder exposing (..)
import Mastodon.Helper exposing (extractStatusId)
import Mastodon.Http exposing (..)
import Mastodon.Model exposing (..)
import Mastodon.WebSocket exposing (StreamType(..))
import Ports
import Task
import Types exposing (..)
import Url
import View.Formatter exposing (textContent)


initCommands : Maybe AppRegistration -> Maybe Client -> Maybe String -> Cmd Msg
initCommands registration client authCode =
    Cmd.batch <|
        case authCode of
            Just code ->
                case registration of
                    Just reg ->
                        [ getAccessToken reg code
                        , Ports.deleteRegistration ""
                        ]

                    Nothing ->
                        [ Navigation.load "/" ]

            Nothing ->
                [ loadUserAccount client, loadTimelines client, subscribeToWs client UserStream ]


getAccessToken : AppRegistration -> String -> Cmd Msg
getAccessToken registration authCode =
    HttpBuilder.post (registration.server ++ ApiUrl.oauthToken)
        |> HttpBuilder.withJsonBody (authorizationCodeEncoder registration authCode)
        |> withBodyDecoder (MastodonEvent << AccessToken) (accessTokenDecoder registration)
        |> send


navigateToAuthUrl : AppRegistration -> Cmd Msg
navigateToAuthUrl registration =
    Navigation.load <| getAuthorizationUrl registration


registerApp : Model -> Cmd Msg
registerApp { server, location } =
    let
        -- The redirect URI should not have a fragment or Mastodon will not accept it
        locationWithoutFragment =
            Url.toString
                { protocol = location.protocol
                , host = location.host
                , port_ = location.port_
                , path = location.path
                , query = location.fragment
                , fragment = Nothing
                }

        redirectUri =
            locationWithoutFragment

        cleanServer =
            if String.endsWith "/" server then
                String.dropRight 1 server

            else
                server

        clientName =
            "tooty"

        scope =
            "read write follow"

        website =
            "https://github.com/n1k0/tooty"
    in
    HttpBuilder.post (cleanServer ++ ApiUrl.apps)
        |> withBodyDecoder (MastodonEvent << AppRegistered) (appRegistrationDecoder cleanServer scope)
        |> HttpBuilder.withJsonBody
            (appRegistrationEncoder clientName redirectUri scope website)
        |> send


saveClients : List Client -> Cmd Msg
saveClients clients =
    clients
        |> Encode.list clientEncoder
        |> Encode.encode 0
        |> Ports.saveClients


saveRegistration : AppRegistration -> Cmd Msg
saveRegistration registration =
    registrationEncoder registration
        |> Encode.encode 0
        |> Ports.saveRegistration


loadNotifications : Maybe Client -> Maybe String -> Cmd Msg
loadNotifications client url =
    case client of
        Just c ->
            HttpBuilder.get (Maybe.withDefault ApiUrl.notifications url)
                |> withClient c
                |> withBodyDecoder (MastodonEvent << Notifications (url /= Nothing)) (Decode.list notificationDecoder)
                |> withQueryParams [ ( "limit", "30" ) ]
                |> send

        Nothing ->
            Cmd.none


loadUserAccount : Maybe Client -> Cmd Msg
loadUserAccount client =
    case client of
        Just c ->
            HttpBuilder.get ApiUrl.userAccount
                |> withClient c
                |> withBodyDecoder (MastodonEvent << CurrentUser) accountDecoder
                |> send

        Nothing ->
            Cmd.none


loadAccount : Maybe Client -> String -> Cmd Msg
loadAccount client accountId =
    case client of
        Just c ->
            Cmd.batch
                [ HttpBuilder.get (ApiUrl.account accountId)
                    |> withClient c
                    |> withBodyDecoder (MastodonEvent << AccountReceived) accountDecoder
                    |> send
                , requestRelationships (MastodonEvent << AccountRelationship) c [ accountId ]
                    |> send
                ]

        Nothing ->
            Cmd.none


loadAccountFollowers : Maybe Client -> String -> Maybe String -> Cmd Msg
loadAccountFollowers client accountId url =
    case client of
        Just c ->
            HttpBuilder.get (Maybe.withDefault (ApiUrl.followers accountId) url)
                |> withClient c
                |> withBodyDecoder (MastodonEvent << AccountFollowers (url /= Nothing)) (Decode.list accountDecoder)
                |> send

        Nothing ->
            Cmd.none


loadAccountFollowing : Maybe Client -> String -> Maybe String -> Cmd Msg
loadAccountFollowing client accountId url =
    case client of
        Just c ->
            HttpBuilder.get (Maybe.withDefault (ApiUrl.following accountId) url)
                |> withClient c
                |> withBodyDecoder (MastodonEvent << AccountFollowing (url /= Nothing)) (Decode.list accountDecoder)
                |> send

        Nothing ->
            Cmd.none


search : Maybe Client -> String -> Cmd Msg
search client term =
    case client of
        Just c ->
            let
                cleanTerm =
                    term |> String.replace "#" ""
            in
            HttpBuilder.get ApiUrl.search
                |> withClient c
                |> withBodyDecoder (MastodonEvent << SearchResultsReceived) searchResultsDecoder
                |> withQueryParams [ ( "q", cleanTerm ), ( "resolve", "true" ) ]
                |> send

        Nothing ->
            Cmd.none


searchAccounts : Maybe Client -> String -> Int -> Bool -> Cmd Msg
searchAccounts client query limit resolve =
    if query == "" then
        Cmd.none

    else
        case client of
            Just c ->
                let
                    qs =
                        [ ( "q", query )
                        , ( "limit", String.fromInt limit )
                        , ( "resolve"
                          , if resolve then
                                "true"

                            else
                                "false"
                          )
                        ]
                in
                HttpBuilder.get ApiUrl.searchAccount
                    |> withClient c
                    |> withBodyDecoder (MastodonEvent << AutoSearch) (Decode.list accountDecoder)
                    |> withQueryParams qs
                    |> send

            Nothing ->
                Cmd.none


requestRelationships : (Result Error (Response (List Relationship)) -> msg) -> Client -> List String -> HttpBuilder.RequestBuilder msg
requestRelationships toMsg client ids =
    HttpBuilder.get ApiUrl.relationships
        |> withClient client
        |> withBodyDecoder toMsg (Decode.list relationshipDecoder)
        |> withQueryParams
            (List.map (\id -> ( "id[]", id )) ids)


loadRelationships : Maybe Client -> List String -> Cmd Msg
loadRelationships client ids =
    if List.length ids > 0 then
        case client of
            Just c ->
                requestRelationships (MastodonEvent << AccountRelationships) c ids
                    |> send

            Nothing ->
                Cmd.none

    else
        Cmd.none


loadThread : Maybe Client -> StatusId -> Cmd Msg
loadThread client id =
    case client of
        Just c ->
            Cmd.batch
                [ HttpBuilder.get (ApiUrl.status id)
                    |> withClient c
                    |> withBodyDecoder (MastodonEvent << ThreadStatusLoaded id) statusDecoder
                    |> send
                , HttpBuilder.get (ApiUrl.context id)
                    |> withClient c
                    |> withBodyDecoder (MastodonEvent << ThreadContextLoaded id) contextDecoder
                    |> send
                ]

        Nothing ->
            Cmd.none


loadHomeTimeline : Maybe Client -> Maybe String -> Cmd Msg
loadHomeTimeline client url =
    case client of
        Just c ->
            HttpBuilder.get (Maybe.withDefault ApiUrl.homeTimeline url)
                |> withClient c
                |> withBodyDecoder (MastodonEvent << HomeTimeline (url /= Nothing)) (Decode.list statusDecoder)
                |> withQueryParams [ ( "limit", "60" ) ]
                |> send

        Nothing ->
            Cmd.none


loadLocalTimeline : Maybe Client -> Maybe String -> Cmd Msg
loadLocalTimeline client url =
    case client of
        Just c ->
            Cmd.batch
                [ HttpBuilder.get (Maybe.withDefault ApiUrl.publicTimeline url)
                    |> withClient c
                    |> withBodyDecoder (MastodonEvent << LocalTimeline (url /= Nothing)) (Decode.list statusDecoder)
                    |> withQueryParams [ ( "local", "true" ), ( "limit", "60" ) ]
                    |> send
                , subscribeToWs client LocalPublicStream
                ]

        Nothing ->
            Cmd.none


loadGlobalTimeline : Maybe Client -> Maybe String -> Cmd Msg
loadGlobalTimeline client url =
    case client of
        Just c ->
            Cmd.batch
                [ HttpBuilder.get (Maybe.withDefault ApiUrl.publicTimeline url)
                    |> withClient c
                    |> withBodyDecoder (MastodonEvent << GlobalTimeline (url /= Nothing)) (Decode.list statusDecoder)
                    |> withQueryParams [ ( "limit", "60" ) ]
                    |> send
                , subscribeToWs client GlobalPublicStream
                ]

        Nothing ->
            Cmd.none


loadAccountTimeline : Maybe Client -> String -> Maybe String -> Cmd Msg
loadAccountTimeline client accountId url =
    case client of
        Just c ->
            HttpBuilder.get (Maybe.withDefault (ApiUrl.accountTimeline accountId) url)
                |> withClient c
                |> withBodyDecoder (MastodonEvent << AccountTimeline (url /= Nothing)) (Decode.list statusDecoder)
                |> withQueryParams [ ( "limit", "60" ) ]
                |> send

        Nothing ->
            Cmd.none


loadFavoriteTimeline : Maybe Client -> Maybe String -> Cmd Msg
loadFavoriteTimeline client url =
    case client of
        Just c ->
            HttpBuilder.get (Maybe.withDefault ApiUrl.favouriteTimeline url)
                |> withClient c
                |> withBodyDecoder (MastodonEvent << FavoriteTimeline (url /= Nothing)) (Decode.list statusDecoder)
                |> withQueryParams [ ( "limit", "60" ) ]
                |> send

        Nothing ->
            Cmd.none


loadHashtagTimeline : Maybe Client -> String -> Maybe String -> Cmd Msg
loadHashtagTimeline client hashtag url =
    case client of
        Just c ->
            HttpBuilder.get (Maybe.withDefault (ApiUrl.hashtag hashtag) url)
                |> withClient c
                |> withBodyDecoder (MastodonEvent << HashtagTimeline (url /= Nothing)) (Decode.list statusDecoder)
                |> withQueryParams [ ( "limit", "60" ) ]
                |> send

        Nothing ->
            Cmd.none


loadMutes : Maybe Client -> Maybe String -> Cmd Msg
loadMutes client url =
    case client of
        Just c ->
            HttpBuilder.get (Maybe.withDefault ApiUrl.mutes url)
                |> withClient c
                |> withBodyDecoder (MastodonEvent << Mutes (url /= Nothing)) (Decode.list accountDecoder)
                |> withQueryParams [ ( "limit", "60" ) ]
                |> send

        Nothing ->
            Cmd.none


loadBlocks : Maybe Client -> Maybe String -> Cmd Msg
loadBlocks client url =
    case client of
        Just c ->
            HttpBuilder.get (Maybe.withDefault ApiUrl.blocks url)
                |> withClient c
                |> withBodyDecoder (MastodonEvent << Blocks (url /= Nothing)) (Decode.list accountDecoder)
                |> withQueryParams [ ( "limit", "60" ) ]
                |> send

        Nothing ->
            Cmd.none


loadTimelines : Maybe Client -> Cmd Msg
loadTimelines client =
    Cmd.batch
        [ loadHomeTimeline client Nothing
        , loadLocalTimeline client Nothing
        , loadGlobalTimeline client Nothing
        , loadNotifications client Nothing
        ]


subscribeToWs : Maybe Client -> StreamType -> Cmd Msg
subscribeToWs client streamType =
    let
        type_ =
            case streamType of
                GlobalPublicStream ->
                    "public"

                LocalPublicStream ->
                    "public:local"

                UserStream ->
                    "user"
    in
    client
        |> Maybe.map
            (\c ->
                Ports.connectToWsServer
                    { server = c.server
                    , token = c.token
                    , streamType = type_
                    , apiUrl = ApiUrl.streaming
                    }
            )
        |> Maybe.withDefault Cmd.none


loadNextTimeline : Model -> String -> String -> Cmd Msg
loadNextTimeline { clients, currentView, accountInfo } id next =
    let
        client =
            List.head clients
    in
    case id of
        "notifications" ->
            loadNotifications client (Just next)

        "home-timeline" ->
            loadHomeTimeline client (Just next)

        "local-timeline" ->
            loadLocalTimeline client (Just next)

        "global-timeline" ->
            loadGlobalTimeline client (Just next)

        "favorite-timeline" ->
            loadFavoriteTimeline client (Just next)

        "hashtag-timeline" ->
            case currentView of
                HashtagView hashtag ->
                    loadHashtagTimeline client hashtag (Just next)

                _ ->
                    Cmd.none

        "account-timeline" ->
            case accountInfo.account of
                Just account ->
                    loadAccountTimeline client account.id (Just next)

                _ ->
                    Cmd.none

        "account-followers" ->
            case accountInfo.account of
                Just account ->
                    loadAccountFollowers client account.id (Just next)

                _ ->
                    Cmd.none

        "account-following" ->
            case accountInfo.account of
                Just account ->
                    loadAccountFollowing client account.id (Just next)

                _ ->
                    Cmd.none

        _ ->
            Cmd.none


postStatus : Maybe Client -> StatusRequestBody -> Cmd Msg
postStatus client draft =
    case client of
        Just c ->
            HttpBuilder.post ApiUrl.statuses
                |> withClient c
                |> HttpBuilder.withJsonBody (statusRequestBodyEncoder draft)
                |> withBodyDecoder (MastodonEvent << StatusPosted) statusDecoder
                |> send

        Nothing ->
            Cmd.none


updateDomStatus : String -> Cmd Msg
updateDomStatus statusText =
    Ports.setStatus { id = "status", status = statusText }


deleteStatus : Maybe Client -> StatusId -> Cmd Msg
deleteStatus client id =
    case client of
        Just c ->
            HttpBuilder.delete (ApiUrl.status id)
                |> withClient c
                |> withBodyDecoder (MastodonEvent << StatusDeleted) (Decode.succeed id)
                |> send

        Nothing ->
            Cmd.none


reblogStatus : Maybe Client -> StatusId -> Cmd Msg
reblogStatus client statusId =
    case client of
        Just c ->
            HttpBuilder.post (ApiUrl.reblog statusId)
                |> withClient c
                |> withBodyDecoder (MastodonEvent << Reblogged) statusDecoder
                |> send

        Nothing ->
            Cmd.none


unreblogStatus : Maybe Client -> StatusId -> Cmd Msg
unreblogStatus client statusId =
    case client of
        Just c ->
            HttpBuilder.post (ApiUrl.unreblog statusId)
                |> withClient c
                |> withBodyDecoder (MastodonEvent << Unreblogged) statusDecoder
                |> send

        Nothing ->
            Cmd.none


favouriteStatus : Maybe Client -> StatusId -> Cmd Msg
favouriteStatus client statusId =
    case client of
        Just c ->
            HttpBuilder.post (ApiUrl.favourite statusId)
                |> withClient c
                |> withBodyDecoder (MastodonEvent << FavoriteAdded) statusDecoder
                |> send

        Nothing ->
            Cmd.none


unfavouriteStatus : Maybe Client -> StatusId -> Cmd Msg
unfavouriteStatus client statusId =
    case client of
        Just c ->
            HttpBuilder.post (ApiUrl.unfavourite statusId)
                |> withClient c
                |> withBodyDecoder (MastodonEvent << FavoriteRemoved) statusDecoder
                |> send

        Nothing ->
            Cmd.none


follow : Maybe Client -> Account -> Cmd Msg
follow client account =
    case client of
        Just c ->
            HttpBuilder.post (ApiUrl.follow account.id)
                |> withClient c
                |> withBodyDecoder (MastodonEvent << AccountFollowed account) relationshipDecoder
                |> send

        Nothing ->
            Cmd.none


unfollow : Maybe Client -> Account -> Cmd Msg
unfollow client account =
    case client of
        Just c ->
            HttpBuilder.post (ApiUrl.unfollow account.id)
                |> withClient c
                |> withBodyDecoder (MastodonEvent << AccountUnfollowed account) relationshipDecoder
                |> send

        Nothing ->
            Cmd.none


mute : Maybe Client -> Account -> Cmd Msg
mute client account =
    case client of
        Just c ->
            HttpBuilder.post (ApiUrl.mute account.id)
                |> withClient c
                |> withBodyDecoder (MastodonEvent << AccountMuted account) relationshipDecoder
                |> send

        Nothing ->
            Cmd.none


unmute : Maybe Client -> Account -> Cmd Msg
unmute client account =
    case client of
        Just c ->
            HttpBuilder.post (ApiUrl.unmute account.id)
                |> withClient c
                |> withBodyDecoder (MastodonEvent << AccountUnmuted account) relationshipDecoder
                |> send

        Nothing ->
            Cmd.none


block : Maybe Client -> Account -> Cmd Msg
block client account =
    case client of
        Just c ->
            HttpBuilder.post (ApiUrl.block account.id)
                |> withClient c
                |> withBodyDecoder (MastodonEvent << AccountBlocked account) relationshipDecoder
                |> send

        Nothing ->
            Cmd.none


unblock : Maybe Client -> Account -> Cmd Msg
unblock client account =
    case client of
        Just c ->
            HttpBuilder.post (ApiUrl.unblock account.id)
                |> withClient c
                |> withBodyDecoder (MastodonEvent << AccountUnblocked account) relationshipDecoder
                |> send

        Nothing ->
            Cmd.none


uploadMedia : Maybe Client -> String -> Cmd Msg
uploadMedia client fileInputId =
    case client of
        Just { server, token } ->
            Ports.uploadMedia
                { id = fileInputId
                , url = server ++ ApiUrl.uploadMedia
                , token = token
                }

        Nothing ->
            Cmd.none


focusId : String -> Cmd Msg
focusId id =
    Dom.focus id |> Task.attempt (\_ -> NoOp)


scrollColumnToTop : String -> Cmd Msg
scrollColumnToTop column =
    Dom.getViewportOf column
        |> Task.andThen (\_ -> Dom.setViewportOf column 0 0)
        |> Task.attempt (\_ -> NoOp)


scrollColumnToBottom : String -> Cmd Msg
scrollColumnToBottom column =
    Dom.getViewportOf column
        |> Task.andThen (\info -> Dom.setViewportOf column 0 info.scene.height)
        |> Task.attempt (\_ -> NoOp)


scrollToThreadStatus : String -> Cmd Msg
scrollToThreadStatus cssId =
    Ports.scrollIntoView <| "thread-status-" ++ cssId


notifyStatus : Status -> Cmd Msg
notifyStatus status =
    Ports.notify
        { title = status.account.acct
        , icon = status.account.avatar
        , body = status.content |> textContent
        , clickUrl = "#thread/" ++ extractStatusId status.id
        }


notifyNotification : Notification -> Cmd Msg
notifyNotification notification =
    case notification.status of
        Just status ->
            case notification.type_ of
                "reblog" ->
                    Ports.notify
                        { title = notification.account.acct ++ " reboosted"
                        , icon = notification.account.avatar
                        , body = status.content |> textContent
                        , clickUrl = "#thread/" ++ extractStatusId status.id
                        }

                "favourite" ->
                    Ports.notify
                        { title = notification.account.acct ++ " favorited"
                        , icon = notification.account.avatar
                        , body = status.content |> textContent
                        , clickUrl = "#thread/" ++ extractStatusId status.id
                        }

                "mention" ->
                    Ports.notify
                        { title = notification.account.acct ++ " mentioned you"
                        , icon = notification.account.avatar
                        , body = status.content |> textContent
                        , clickUrl = "#thread/" ++ extractStatusId status.id
                        }

                _ ->
                    Cmd.none

        Nothing ->
            case notification.type_ of
                "follow" ->
                    Ports.notify
                        { title = notification.account.acct ++ " follows you"
                        , icon = notification.account.avatar
                        , body = notification.account.note
                        , clickUrl = "#account/" ++ notification.account.id
                        }

                _ ->
                    Cmd.none
