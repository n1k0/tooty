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
        , loadAccountFollowers
        , loadAccountFollowing
        , loadUserTimeline
        , loadLocalTimeline
        , loadGlobalTimeline
        , loadAccountTimeline
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
        , focusId
        , scrollColumnToTop
        , scrollColumnToBottom
        , scrollToThreadStatus
        , searchAccounts
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
import Task
import Types exposing (..)


initCommands : Maybe AppRegistration -> Maybe Client -> Maybe String -> Cmd Msg
initCommands registration client authCode =
    Cmd.batch <|
        case authCode of
            Just authCode ->
                case registration of
                    Just registration ->
                        [ getAccessToken registration authCode ]

                    Nothing ->
                        []

            Nothing ->
                [ loadUserAccount client, loadTimelines client ]


getAccessToken : AppRegistration -> String -> Cmd Msg
getAccessToken registration authCode =
    HttpBuilder.get ApiUrl.notifications
        |> withBodyDecoder (accessTokenDecoder registration)
        |> HttpBuilder.withJsonBody (authorizationCodeEncoder registration authCode)
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
        HttpBuilder.post ApiUrl.apps
            |> withBodyDecoder (appRegistrationDecoder server scope)
            |> HttpBuilder.withJsonBody
                (appRegistrationEncoder clientName redirectUri scope website)
            |> send (MastodonEvent << AppRegistered)


saveClient : Client -> Cmd Msg
saveClient client =
    clientEncoder client
        |> Encode.encode 0
        |> Ports.saveClient


saveRegistration : AppRegistration -> Cmd Msg
saveRegistration registration =
    registrationEncoder registration
        |> Encode.encode 0
        |> Ports.saveRegistration


loadNotifications : Maybe Client -> Cmd Msg
loadNotifications client =
    -- TODO: handle link (see loadUserTimeline)
    case client of
        Just client ->
            HttpBuilder.get ApiUrl.notifications
                |> withClient client
                |> withBodyDecoder (Decode.list notificationDecoder)
                |> send (MastodonEvent << Notifications)

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


loadAccountFollowers : Maybe Client -> Int -> Cmd Msg
loadAccountFollowers client accountId =
    case client of
        Just client ->
            HttpBuilder.get (ApiUrl.followers accountId)
                |> withClient client
                |> withBodyDecoder (Decode.list accountDecoder)
                |> send (MastodonEvent << AccountFollowers)

        Nothing ->
            Cmd.none


loadAccountFollowing : Maybe Client -> Int -> Cmd Msg
loadAccountFollowing client accountId =
    case client of
        Just client ->
            HttpBuilder.get (ApiUrl.following accountId)
                |> withClient client
                |> withBodyDecoder (Decode.list accountDecoder)
                |> send (MastodonEvent << AccountFollowing)

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
    case client of
        Just client ->
            requestRelationships client ids
                |> send (MastodonEvent << AccountRelationships)

        Nothing ->
            Cmd.none


loadThread : Maybe Client -> Status -> Cmd Msg
loadThread client status =
    case client of
        Just client ->
            HttpBuilder.get (ApiUrl.context status.id)
                |> withClient client
                |> withBodyDecoder contextDecoder
                |> send (MastodonEvent << (ContextLoaded status))

        Nothing ->
            Cmd.none


loadUserTimeline : Maybe Client -> Maybe String -> Cmd Msg
loadUserTimeline client url =
    case client of
        Just client ->
            HttpBuilder.get (Maybe.withDefault ApiUrl.homeTimeline url)
                |> withClient client
                |> withBodyDecoder (Decode.list statusDecoder)
                |> send (MastodonEvent << UserTimeline (url /= Nothing))

        Nothing ->
            Cmd.none


loadLocalTimeline : Maybe Client -> Maybe String -> Cmd Msg
loadLocalTimeline client url =
    case client of
        Just client ->
            HttpBuilder.get (Maybe.withDefault ApiUrl.publicTimeline url)
                |> withClient client
                |> withBodyDecoder (Decode.list statusDecoder)
                |> withQueryParams [ ( "local", "true" ) ]
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
                |> send (MastodonEvent << AccountTimeline (url /= Nothing))

        Nothing ->
            Cmd.none


loadTimelines : Maybe Client -> Cmd Msg
loadTimelines client =
    Cmd.batch
        [ loadUserTimeline client Nothing
        , loadLocalTimeline client Nothing
        , loadGlobalTimeline client Nothing
        , loadNotifications client
        ]


loadNextTimeline : Maybe Client -> CurrentView -> Timeline -> Cmd Msg
loadNextTimeline client currentView { id, links } =
    case id of
        "home-timeline" ->
            loadUserTimeline client links.next

        "local-timeline" ->
            loadLocalTimeline client links.next

        "global-timeline" ->
            loadGlobalTimeline client links.next

        "account-timeline" ->
            case currentView of
                AccountView account ->
                    loadAccountTimeline client account.id links.next

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


follow : Maybe Client -> Int -> Cmd Msg
follow client id =
    case client of
        Just client ->
            HttpBuilder.post (ApiUrl.follow id)
                |> withClient client
                |> withBodyDecoder relationshipDecoder
                |> send (MastodonEvent << AccountFollowed)

        Nothing ->
            Cmd.none


unfollow : Maybe Client -> Int -> Cmd Msg
unfollow client id =
    case client of
        Just client ->
            HttpBuilder.post (ApiUrl.unfollow id)
                |> withClient client
                |> withBodyDecoder relationshipDecoder
                |> send (MastodonEvent << AccountUnfollowed)

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
