module Command
    exposing
        ( initCommands
        , navigateToAuthUrl
        , registerApp
        , saveClients
        , saveRegistration
        , loadNotifications
        , loadUserAccount
        , loadAccount
        , loadAccountFollowers
        , loadAccountFollowing
        , loadHomeTimeline
        , loadLocalTimeline
        , loadGlobalTimeline
        , loadAccountTimeline
        , loadFavoriteTimeline
        , loadHashtagTimeline
        , loadMutes
        , loadBlocks
        , loadNextTimeline
        , loadRelationships
        , loadThread
        , loadTimelines
        , postStatus
        , updateDomStatus
        , deleteStatus
        , reblogStatus
        , unreblogStatus
        , favouriteStatus
        , unfavouriteStatus
        , follow
        , unfollow
        , mute
        , unmute
        , block
        , unblock
        , uploadMedia
        , focusId
        , scrollColumnToTop
        , scrollColumnToBottom
        , scrollToThreadStatus
        , searchAccounts
        , search
        )

import Dom
import Dom.Scroll
import Json.Encode as Encode
import Json.Decode as Decode
import HttpBuilder
import Mastodon.ApiUrl as ApiUrl
import Mastodon.Decoder exposing (..)
import Mastodon.Encoder exposing (..)
import Mastodon.Http exposing (..)
import Mastodon.Model exposing (..)
import Navigation
import Ports
import String.Extra exposing (replace)
import Task
import Types exposing (..)


initCommands : Maybe AppRegistration -> Maybe Client -> Maybe String -> Cmd Msg
initCommands registration client authCode =
    Cmd.batch <|
        case authCode of
            Just authCode ->
                case registration of
                    Just registration ->
                        [ getAccessToken registration authCode
                        , Ports.deleteRegistration ""
                        ]

                    Nothing ->
                        []

            Nothing ->
                [ loadUserAccount client, loadTimelines client ]


getAccessToken : AppRegistration -> String -> Cmd Msg
getAccessToken registration authCode =
    HttpBuilder.post (registration.server ++ ApiUrl.oauthToken)
        |> HttpBuilder.withJsonBody (authorizationCodeEncoder registration authCode)
        |> withBodyDecoder (accessTokenDecoder registration)
        |> send (MastodonEvent << AccessToken)


navigateToAuthUrl : AppRegistration -> Cmd Msg
navigateToAuthUrl registration =
    Navigation.load <| getAuthorizationUrl registration


registerApp : Model -> Cmd Msg
registerApp { server, location } =
    let
        redirectUri =
            location.origin ++ location.pathname

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
            |> withBodyDecoder (appRegistrationDecoder cleanServer scope)
            |> HttpBuilder.withJsonBody
                (appRegistrationEncoder clientName redirectUri scope website)
            |> send (MastodonEvent << AppRegistered)


saveClients : List Client -> Cmd Msg
saveClients clients =
    clients
        |> List.map clientEncoder
        |> Encode.list
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
        Just client ->
            HttpBuilder.get (Maybe.withDefault ApiUrl.notifications url)
                |> withClient client
                |> withBodyDecoder (Decode.list notificationDecoder)
                |> withQueryParams [ ( "limit", "30" ) ]
                |> send (MastodonEvent << Notifications (url /= Nothing))

        Nothing ->
            Cmd.none


loadUserAccount : Maybe Client -> Cmd Msg
loadUserAccount client =
    case client of
        Just client ->
            HttpBuilder.get ApiUrl.userAccount
                |> withClient client
                |> withBodyDecoder accountDecoder
                |> send (MastodonEvent << CurrentUser)

        Nothing ->
            Cmd.none


loadAccount : Maybe Client -> Int -> Cmd Msg
loadAccount client accountId =
    case client of
        Just client ->
            Cmd.batch
                [ HttpBuilder.get (ApiUrl.account accountId)
                    |> withClient client
                    |> withBodyDecoder accountDecoder
                    |> send (MastodonEvent << AccountReceived)
                , requestRelationships client [ accountId ]
                    |> send (MastodonEvent << AccountRelationship)
                ]

        Nothing ->
            Cmd.none


loadAccountFollowers : Maybe Client -> Int -> Maybe String -> Cmd Msg
loadAccountFollowers client accountId url =
    case client of
        Just client ->
            HttpBuilder.get (Maybe.withDefault (ApiUrl.followers accountId) url)
                |> withClient client
                |> withBodyDecoder (Decode.list accountDecoder)
                |> send (MastodonEvent << AccountFollowers (url /= Nothing))

        Nothing ->
            Cmd.none


loadAccountFollowing : Maybe Client -> Int -> Maybe String -> Cmd Msg
loadAccountFollowing client accountId url =
    case client of
        Just client ->
            HttpBuilder.get (Maybe.withDefault (ApiUrl.following accountId) url)
                |> withClient client
                |> withBodyDecoder (Decode.list accountDecoder)
                |> send (MastodonEvent << AccountFollowing (url /= Nothing))

        Nothing ->
            Cmd.none


search : Maybe Client -> String -> Cmd Msg
search client term =
    case client of
        Just client ->
            let
                cleanTerm =
                    term |> replace "#" ""
            in
                HttpBuilder.get ApiUrl.search
                    |> withClient client
                    |> withBodyDecoder searchResultsDecoder
                    |> withQueryParams [ ( "q", cleanTerm ), ( "resolve", "true" ) ]
                    |> send (MastodonEvent << SearchResultsReceived)

        Nothing ->
            Cmd.none


searchAccounts : Maybe Client -> String -> Int -> Bool -> Cmd Msg
searchAccounts client query limit resolve =
    if query == "" then
        Cmd.none
    else
        case client of
            Just client ->
                let
                    qs =
                        [ ( "q", query )
                        , ( "limit", toString limit )
                        , ( "resolve"
                          , if resolve then
                                "true"
                            else
                                "false"
                          )
                        ]
                in
                    HttpBuilder.get ApiUrl.searchAccount
                        |> withClient client
                        |> withBodyDecoder (Decode.list accountDecoder)
                        |> withQueryParams qs
                        |> send (MastodonEvent << AutoSearch)

            Nothing ->
                Cmd.none


requestRelationships : Client -> List Int -> Request (List Relationship)
requestRelationships client ids =
    HttpBuilder.get ApiUrl.relationships
        |> withClient client
        |> withBodyDecoder (Decode.list relationshipDecoder)
        |> withQueryParams
            (List.map (\id -> ( "id[]", toString id )) ids)


loadRelationships : Maybe Client -> List Int -> Cmd Msg
loadRelationships client ids =
    if List.length ids > 0 then
        case client of
            Just client ->
                requestRelationships client ids
                    |> send (MastodonEvent << AccountRelationships)

            Nothing ->
                Cmd.none
    else
        Cmd.none


loadThread : Maybe Client -> Int -> Cmd Msg
loadThread client id =
    case client of
        Just client ->
            Cmd.batch
                [ HttpBuilder.get (ApiUrl.status id)
                    |> withClient client
                    |> withBodyDecoder statusDecoder
                    |> send (MastodonEvent << (ThreadStatusLoaded id))
                , HttpBuilder.get (ApiUrl.context id)
                    |> withClient client
                    |> withBodyDecoder contextDecoder
                    |> send (MastodonEvent << (ThreadContextLoaded id))
                ]

        Nothing ->
            Cmd.none


loadHomeTimeline : Maybe Client -> Maybe String -> Cmd Msg
loadHomeTimeline client url =
    case client of
        Just client ->
            HttpBuilder.get (Maybe.withDefault ApiUrl.homeTimeline url)
                |> withClient client
                |> withBodyDecoder (Decode.list statusDecoder)
                |> withQueryParams [ ( "limit", "60" ) ]
                |> send (MastodonEvent << HomeTimeline (url /= Nothing))

        Nothing ->
            Cmd.none


loadLocalTimeline : Maybe Client -> Maybe String -> Cmd Msg
loadLocalTimeline client url =
    case client of
        Just client ->
            HttpBuilder.get (Maybe.withDefault ApiUrl.publicTimeline url)
                |> withClient client
                |> withBodyDecoder (Decode.list statusDecoder)
                |> withQueryParams [ ( "local", "true" ), ( "limit", "60" ) ]
                |> send (MastodonEvent << LocalTimeline (url /= Nothing))

        Nothing ->
            Cmd.none


loadGlobalTimeline : Maybe Client -> Maybe String -> Cmd Msg
loadGlobalTimeline client url =
    case client of
        Just client ->
            HttpBuilder.get (Maybe.withDefault ApiUrl.publicTimeline url)
                |> withClient client
                |> withBodyDecoder (Decode.list statusDecoder)
                |> withQueryParams [ ( "limit", "60" ) ]
                |> send (MastodonEvent << GlobalTimeline (url /= Nothing))

        Nothing ->
            Cmd.none


loadAccountTimeline : Maybe Client -> Int -> Maybe String -> Cmd Msg
loadAccountTimeline client accountId url =
    case client of
        Just client ->
            HttpBuilder.get (Maybe.withDefault (ApiUrl.accountTimeline accountId) url)
                |> withClient client
                |> withBodyDecoder (Decode.list statusDecoder)
                |> withQueryParams [ ( "limit", "60" ) ]
                |> send (MastodonEvent << AccountTimeline (url /= Nothing))

        Nothing ->
            Cmd.none


loadFavoriteTimeline : Maybe Client -> Maybe String -> Cmd Msg
loadFavoriteTimeline client url =
    case client of
        Just client ->
            HttpBuilder.get (Maybe.withDefault ApiUrl.favouriteTimeline url)
                |> withClient client
                |> withBodyDecoder (Decode.list statusDecoder)
                |> withQueryParams [ ( "limit", "60" ) ]
                |> send (MastodonEvent << FavoriteTimeline (url /= Nothing))

        Nothing ->
            Cmd.none


loadHashtagTimeline : Maybe Client -> String -> Maybe String -> Cmd Msg
loadHashtagTimeline client hashtag url =
    case client of
        Just client ->
            HttpBuilder.get (Maybe.withDefault (ApiUrl.hashtag hashtag) url)
                |> withClient client
                |> withBodyDecoder (Decode.list statusDecoder)
                |> withQueryParams [ ( "limit", "60" ) ]
                |> send (MastodonEvent << HashtagTimeline (url /= Nothing))

        Nothing ->
            Cmd.none


loadMutes : Maybe Client -> Maybe String -> Cmd Msg
loadMutes client url =
    case client of
        Just client ->
            HttpBuilder.get (Maybe.withDefault ApiUrl.mutes url)
                |> withClient client
                |> withBodyDecoder (Decode.list accountDecoder)
                |> withQueryParams [ ( "limit", "60" ) ]
                |> send (MastodonEvent << Mutes (url /= Nothing))

        Nothing ->
            Cmd.none


loadBlocks : Maybe Client -> Maybe String -> Cmd Msg
loadBlocks client url =
    case client of
        Just client ->
            HttpBuilder.get (Maybe.withDefault ApiUrl.blocks url)
                |> withClient client
                |> withBodyDecoder (Decode.list accountDecoder)
                |> withQueryParams [ ( "limit", "60" ) ]
                |> send (MastodonEvent << Blocks (url /= Nothing))

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
        Just client ->
            HttpBuilder.post ApiUrl.statuses
                |> withClient client
                |> HttpBuilder.withJsonBody (statusRequestBodyEncoder draft)
                |> withBodyDecoder statusDecoder
                |> send (MastodonEvent << StatusPosted)

        Nothing ->
            Cmd.none


updateDomStatus : String -> Cmd Msg
updateDomStatus statusText =
    Ports.setStatus { id = "status", status = statusText }


deleteStatus : Maybe Client -> Int -> Cmd Msg
deleteStatus client id =
    case client of
        Just client ->
            HttpBuilder.delete (ApiUrl.status id)
                |> withClient client
                |> withBodyDecoder (Decode.succeed id)
                |> send (MastodonEvent << StatusDeleted)

        Nothing ->
            Cmd.none


reblogStatus : Maybe Client -> Int -> Cmd Msg
reblogStatus client statusId =
    case client of
        Just client ->
            HttpBuilder.post (ApiUrl.reblog statusId)
                |> withClient client
                |> withBodyDecoder statusDecoder
                |> send (MastodonEvent << Reblogged)

        Nothing ->
            Cmd.none


unreblogStatus : Maybe Client -> Int -> Cmd Msg
unreblogStatus client statusId =
    case client of
        Just client ->
            HttpBuilder.post (ApiUrl.unreblog statusId)
                |> withClient client
                |> withBodyDecoder statusDecoder
                |> send (MastodonEvent << Unreblogged)

        Nothing ->
            Cmd.none


favouriteStatus : Maybe Client -> Int -> Cmd Msg
favouriteStatus client statusId =
    case client of
        Just client ->
            HttpBuilder.post (ApiUrl.favourite statusId)
                |> withClient client
                |> withBodyDecoder statusDecoder
                |> send (MastodonEvent << FavoriteAdded)

        Nothing ->
            Cmd.none


unfavouriteStatus : Maybe Client -> Int -> Cmd Msg
unfavouriteStatus client statusId =
    case client of
        Just client ->
            HttpBuilder.post (ApiUrl.unfavourite statusId)
                |> withClient client
                |> withBodyDecoder statusDecoder
                |> send (MastodonEvent << FavoriteRemoved)

        Nothing ->
            Cmd.none


follow : Maybe Client -> Account -> Cmd Msg
follow client account =
    case client of
        Just client ->
            HttpBuilder.post (ApiUrl.follow account.id)
                |> withClient client
                |> withBodyDecoder relationshipDecoder
                |> send (MastodonEvent << (AccountFollowed account))

        Nothing ->
            Cmd.none


unfollow : Maybe Client -> Account -> Cmd Msg
unfollow client account =
    case client of
        Just client ->
            HttpBuilder.post (ApiUrl.unfollow account.id)
                |> withClient client
                |> withBodyDecoder relationshipDecoder
                |> send (MastodonEvent << (AccountUnfollowed account))

        Nothing ->
            Cmd.none


mute : Maybe Client -> Account -> Cmd Msg
mute client account =
    case client of
        Just client ->
            HttpBuilder.post (ApiUrl.mute account.id)
                |> withClient client
                |> withBodyDecoder relationshipDecoder
                |> send (MastodonEvent << (AccountMuted account))

        Nothing ->
            Cmd.none


unmute : Maybe Client -> Account -> Cmd Msg
unmute client account =
    case client of
        Just client ->
            HttpBuilder.post (ApiUrl.unmute account.id)
                |> withClient client
                |> withBodyDecoder relationshipDecoder
                |> send (MastodonEvent << (AccountUnmuted account))

        Nothing ->
            Cmd.none


block : Maybe Client -> Account -> Cmd Msg
block client account =
    case client of
        Just client ->
            HttpBuilder.post (ApiUrl.block account.id)
                |> withClient client
                |> withBodyDecoder relationshipDecoder
                |> send (MastodonEvent << (AccountBlocked account))

        Nothing ->
            Cmd.none


unblock : Maybe Client -> Account -> Cmd Msg
unblock client account =
    case client of
        Just client ->
            HttpBuilder.post (ApiUrl.unblock account.id)
                |> withClient client
                |> withBodyDecoder relationshipDecoder
                |> send (MastodonEvent << (AccountUnblocked account))

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
    Dom.focus id |> Task.attempt (always NoOp)


scrollColumnToTop : String -> Cmd Msg
scrollColumnToTop column =
    Task.attempt (always NoOp) <| Dom.Scroll.toTop column


scrollColumnToBottom : String -> Cmd Msg
scrollColumnToBottom column =
    Task.attempt (always NoOp) <| Dom.Scroll.toBottom column


scrollToThreadStatus : String -> Cmd Msg
scrollToThreadStatus cssId =
    Ports.scrollIntoView <| "thread-status-" ++ cssId
