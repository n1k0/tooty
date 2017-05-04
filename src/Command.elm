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
        , loadAccountTimeline
        , loadAccountFollowers
        , loadAccountFollowing
        , loadUserTimeline
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
import Mastodon.ApiUrl
import Mastodon.Decoder
import Mastodon.Encoder
import Mastodon.Http
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
    HttpBuilder.get Mastodon.ApiUrl.notifications
        |> Mastodon.Http.withDecoder (Mastodon.Decoder.accessTokenDecoder registration)
        |> HttpBuilder.withJsonBody (Mastodon.Encoder.authorizationCodeEncoder registration authCode)
        |> Mastodon.Http.send (MastodonEvent << AccessToken)


navigateToAuthUrl : AppRegistration -> Cmd Msg
navigateToAuthUrl registration =
    Navigation.load <| Mastodon.Http.getAuthorizationUrl registration


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
        HttpBuilder.post Mastodon.ApiUrl.apps
            |> Mastodon.Http.withDecoder (Mastodon.Decoder.appRegistrationDecoder server scope)
            |> HttpBuilder.withJsonBody (Mastodon.Encoder.appRegistrationEncoder clientName redirectUri scope website)
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
    -- TODO: handle link (see loadUserTimeline)
    case client of
        Just client ->
            HttpBuilder.get Mastodon.ApiUrl.notifications
                |> Mastodon.Http.withClient client
                |> Mastodon.Http.withDecoder (Decode.list Mastodon.Decoder.notificationDecoder)
                |> Mastodon.Http.send (MastodonEvent << Notifications)

        Nothing ->
            Cmd.none


loadUserAccount : Maybe Client -> Cmd Msg
loadUserAccount client =
    case client of
        Just client ->
            HttpBuilder.get Mastodon.ApiUrl.userAccount
                |> Mastodon.Http.withClient client
                |> Mastodon.Http.withDecoder Mastodon.Decoder.accountDecoder
                |> Mastodon.Http.send (MastodonEvent << CurrentUser)

        Nothing ->
            Cmd.none


loadAccount : Maybe Client -> Int -> Cmd Msg
loadAccount client accountId =
    case client of
        Just client ->
            Cmd.batch
                [ HttpBuilder.get (Mastodon.ApiUrl.account accountId)
                    |> Mastodon.Http.withClient client
                    |> Mastodon.Http.withDecoder Mastodon.Decoder.accountDecoder
                    |> Mastodon.Http.send (MastodonEvent << AccountReceived)
                , requestRelationships client [ accountId ]
                    |> Mastodon.Http.send (MastodonEvent << AccountRelationship)
                ]

        Nothing ->
            Cmd.none


loadAccountTimeline : Maybe Client -> Int -> Cmd Msg
loadAccountTimeline client accountId =
    case client of
        Just client ->
            HttpBuilder.get (Mastodon.ApiUrl.accountTimeline accountId)
                |> Mastodon.Http.withClient client
                |> Mastodon.Http.withDecoder (Decode.list Mastodon.Decoder.statusDecoder)
                |> Mastodon.Http.send (MastodonEvent << AccountTimeline)

        Nothing ->
            Cmd.none


loadAccountFollowers : Maybe Client -> Int -> Cmd Msg
loadAccountFollowers client accountId =
    case client of
        Just client ->
            HttpBuilder.get (Mastodon.ApiUrl.followers accountId)
                |> Mastodon.Http.withClient client
                |> Mastodon.Http.withDecoder (Decode.list Mastodon.Decoder.accountDecoder)
                |> Mastodon.Http.send (MastodonEvent << AccountFollowers)

        Nothing ->
            Cmd.none


loadAccountFollowing : Maybe Client -> Int -> Cmd Msg
loadAccountFollowing client accountId =
    case client of
        Just client ->
            HttpBuilder.get (Mastodon.ApiUrl.following accountId)
                |> Mastodon.Http.withClient client
                |> Mastodon.Http.withDecoder (Decode.list Mastodon.Decoder.accountDecoder)
                |> Mastodon.Http.send (MastodonEvent << AccountFollowing)

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
                    HttpBuilder.get Mastodon.ApiUrl.searchAccount
                        |> Mastodon.Http.withClient client
                        |> Mastodon.Http.withDecoder (Decode.list Mastodon.Decoder.accountDecoder)
                        |> HttpBuilder.withQueryParams qs
                        |> Mastodon.Http.send (MastodonEvent << AutoSearch)

            Nothing ->
                Cmd.none


requestRelationships : Client -> List Int -> Mastodon.Http.Request (List Relationship)
requestRelationships client ids =
    HttpBuilder.get Mastodon.ApiUrl.relationships
        |> Mastodon.Http.withClient client
        |> Mastodon.Http.withDecoder (Decode.list Mastodon.Decoder.relationshipDecoder)
        |> HttpBuilder.withQueryParams (List.map (\id -> ( "id[]", toString id )) ids)


loadRelationships : Maybe Client -> List Int -> Cmd Msg
loadRelationships client ids =
    case client of
        Just client ->
            requestRelationships client ids
                |> Mastodon.Http.send (MastodonEvent << AccountRelationships)

        Nothing ->
            Cmd.none


loadThread : Maybe Client -> Status -> Cmd Msg
loadThread client status =
    case client of
        Just client ->
            HttpBuilder.get (Mastodon.ApiUrl.context status.id)
                |> Mastodon.Http.withClient client
                |> Mastodon.Http.withDecoder Mastodon.Decoder.contextDecoder
                |> Mastodon.Http.send (MastodonEvent << (ContextLoaded status))

        Nothing ->
            Cmd.none


loadUserTimeline : Maybe Client -> Maybe String -> Cmd Msg
loadUserTimeline client url =
    case client of
        Just client ->
            HttpBuilder.get (Maybe.withDefault Mastodon.ApiUrl.homeTimeline url)
                |> Mastodon.Http.withClient client
                |> Mastodon.Http.withDecoder (Decode.list Mastodon.Decoder.statusDecoder)
                |> Mastodon.Http.send (MastodonEvent << UserTimeline (url /= Nothing))

        Nothing ->
            Cmd.none


loadLocalTimeline : Maybe Client -> Maybe String -> Cmd Msg
loadLocalTimeline client url =
    case client of
        Just client ->
            HttpBuilder.get (Maybe.withDefault Mastodon.ApiUrl.publicTimeline url)
                |> Mastodon.Http.withClient client
                |> Mastodon.Http.withDecoder (Decode.list Mastodon.Decoder.statusDecoder)
                |> HttpBuilder.withQueryParams [ ( "local", "true" ) ]
                |> Mastodon.Http.send (MastodonEvent << LocalTimeline (url /= Nothing))

        Nothing ->
            Cmd.none


loadGlobalTimeline : Maybe Client -> Maybe String -> Cmd Msg
loadGlobalTimeline client url =
    case client of
        Just client ->
            HttpBuilder.get (Maybe.withDefault Mastodon.ApiUrl.publicTimeline url)
                |> Mastodon.Http.withClient client
                |> Mastodon.Http.withDecoder (Decode.list Mastodon.Decoder.statusDecoder)
                |> Mastodon.Http.send (MastodonEvent << GlobalTimeline (url /= Nothing))

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


postStatus : Maybe Client -> StatusRequestBody -> Cmd Msg
postStatus client draft =
    case client of
        Just client ->
            HttpBuilder.post Mastodon.ApiUrl.statuses
                |> Mastodon.Http.withClient client
                |> HttpBuilder.withJsonBody (Mastodon.Encoder.statusRequestBodyEncoder draft)
                |> Mastodon.Http.withDecoder Mastodon.Decoder.statusDecoder
                |> Mastodon.Http.send (MastodonEvent << StatusPosted)

        Nothing ->
            Cmd.none


updateDomStatus : String -> Cmd Msg
updateDomStatus statusText =
    Ports.setStatus { id = "status", status = statusText }


deleteStatus : Maybe Client -> Int -> Cmd Msg
deleteStatus client id =
    case client of
        Just client ->
            HttpBuilder.delete (Mastodon.ApiUrl.status id)
                |> Mastodon.Http.withClient client
                |> Mastodon.Http.withDecoder (Decode.succeed id)
                |> Mastodon.Http.send (MastodonEvent << StatusDeleted)

        Nothing ->
            Cmd.none


reblogStatus : Maybe Client -> Int -> Cmd Msg
reblogStatus client statusId =
    case client of
        Just client ->
            HttpBuilder.post (Mastodon.ApiUrl.reblog statusId)
                |> Mastodon.Http.withClient client
                |> Mastodon.Http.withDecoder Mastodon.Decoder.statusDecoder
                |> Mastodon.Http.send (MastodonEvent << Reblogged)

        Nothing ->
            Cmd.none


unreblogStatus : Maybe Client -> Int -> Cmd Msg
unreblogStatus client statusId =
    case client of
        Just client ->
            HttpBuilder.post (Mastodon.ApiUrl.unreblog statusId)
                |> Mastodon.Http.withClient client
                |> Mastodon.Http.withDecoder Mastodon.Decoder.statusDecoder
                |> Mastodon.Http.send (MastodonEvent << Unreblogged)

        Nothing ->
            Cmd.none


favouriteStatus : Maybe Client -> Int -> Cmd Msg
favouriteStatus client statusId =
    case client of
        Just client ->
            HttpBuilder.post (Mastodon.ApiUrl.favourite statusId)
                |> Mastodon.Http.withClient client
                |> Mastodon.Http.withDecoder Mastodon.Decoder.statusDecoder
                |> Mastodon.Http.send (MastodonEvent << FavoriteAdded)

        Nothing ->
            Cmd.none


unfavouriteStatus : Maybe Client -> Int -> Cmd Msg
unfavouriteStatus client statusId =
    case client of
        Just client ->
            HttpBuilder.post (Mastodon.ApiUrl.unfavourite statusId)
                |> Mastodon.Http.withClient client
                |> Mastodon.Http.withDecoder Mastodon.Decoder.statusDecoder
                |> Mastodon.Http.send (MastodonEvent << FavoriteRemoved)

        Nothing ->
            Cmd.none


follow : Maybe Client -> Int -> Cmd Msg
follow client id =
    case client of
        Just client ->
            HttpBuilder.post (Mastodon.ApiUrl.follow id)
                |> Mastodon.Http.withClient client
                |> Mastodon.Http.withDecoder Mastodon.Decoder.relationshipDecoder
                |> Mastodon.Http.send (MastodonEvent << AccountFollowed)

        Nothing ->
            Cmd.none


unfollow : Maybe Client -> Int -> Cmd Msg
unfollow client id =
    case client of
        Just client ->
            HttpBuilder.post (Mastodon.ApiUrl.unfollow id)
                |> Mastodon.Http.withClient client
                |> Mastodon.Http.withDecoder Mastodon.Decoder.relationshipDecoder
                |> Mastodon.Http.send (MastodonEvent << AccountUnfollowed)

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
