module Update.Mastodon exposing (update)

import Command
import Navigation
import Mastodon.Helper
import Mastodon.Model exposing (..)
import Task
import Types exposing (..)
import Update.Draft
import Update.Error exposing (..)
import Update.Timeline


errorText : Error -> String
errorText error =
    case error of
        MastodonError statusCode statusMsg errorMsg ->
            "HTTP " ++ (toString statusCode) ++ " " ++ statusMsg ++ ": " ++ errorMsg

        ServerError statusCode statusMsg errorMsg ->
            "HTTP " ++ (toString statusCode) ++ " " ++ statusMsg ++ ": " ++ errorMsg

        TimeoutError ->
            "Request timed out."

        NetworkError ->
            "Unreachable host."


update : MastodonMsg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        AccessToken result ->
            case result of
                Ok { decoded } ->
                    let
                        client =
                            Client decoded.server decoded.accessToken Nothing
                    in
                        { model | clients = client :: model.clients }
                            ! [ Command.loadTimelines <| Just client
                              , Command.saveClients <| client :: model.clients
                              , Navigation.modifyUrl model.location.pathname
                              , Navigation.reload
                              ]

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountFollowed _ result ->
            case result of
                Ok { decoded } ->
                    processFollowEvent decoded model ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountUnfollowed account result ->
            case result of
                Ok { decoded } ->
                    processUnfollowEvent account decoded model ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountMuted account result ->
            case result of
                Ok { decoded } ->
                    processMuteEvent account decoded model ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountUnmuted account result ->
            case result of
                Ok { decoded } ->
                    processMuteEvent account decoded model ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountBlocked account result ->
            case result of
                Ok { decoded } ->
                    processBlockEvent account decoded model ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountUnblocked account result ->
            case result of
                Ok { decoded } ->
                    processBlockEvent account decoded model ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AppRegistered result ->
            case result of
                Ok { decoded } ->
                    { model | registration = Just decoded }
                        ! [ Command.saveRegistration decoded
                          , Command.navigateToAuthUrl decoded
                          ]

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        ContextLoaded status result ->
            case result of
                Ok { decoded } ->
                    { model
                        | threadStatus = Nothing
                        , currentView = ThreadView (Thread status decoded)
                    }
                        ! [ Command.scrollToThreadStatus <| toString status.id ]

                Err error ->
                    { model
                        | currentView = LocalTimelineView
                        , errors = addErrorNotification (errorText error) model
                    }
                        ! []

        CurrentUser result ->
            case result of
                Ok { decoded } ->
                    let
                        updatedClients =
                            case model.clients of
                                client :: xs ->
                                    ({ client | account = Just decoded }) :: xs

                                _ ->
                                    model.clients
                    in
                        { model | currentUser = Just decoded, clients = updatedClients }
                            ! [ Command.saveClients updatedClients ]

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        FavoriteAdded result ->
            case result of
                Ok _ ->
                    model ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        FavoriteRemoved result ->
            case result of
                Ok _ ->
                    model ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        HashtagTimeline append result ->
            case result of
                Ok { decoded, links } ->
                    { model | hashtagTimeline = Update.Timeline.update append decoded links model.hashtagTimeline } ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        LocalTimeline append result ->
            case result of
                Ok { decoded, links } ->
                    { model | localTimeline = Update.Timeline.update append decoded links model.localTimeline } ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        Notifications append result ->
            case result of
                Ok { decoded, links } ->
                    let
                        aggregated =
                            Mastodon.Helper.aggregateNotifications decoded
                    in
                        { model | notifications = Update.Timeline.update append aggregated links model.notifications } ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        GlobalTimeline append result ->
            case result of
                Ok { decoded, links } ->
                    { model | globalTimeline = Update.Timeline.update append decoded links model.globalTimeline } ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        FavoriteTimeline append result ->
            case result of
                Ok { decoded, links } ->
                    { model | favoriteTimeline = Update.Timeline.update append decoded links model.favoriteTimeline } ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        Mutes append result ->
            case result of
                Ok { decoded, links } ->
                    { model | mutes = Update.Timeline.update append decoded links model.mutes } ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        Blocks append result ->
            case result of
                Ok { decoded, links } ->
                    { model | blocks = Update.Timeline.update append decoded links model.blocks } ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        Reblogged result ->
            case result of
                Ok _ ->
                    model ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        StatusPosted _ ->
            -- FIXME: here we should rather send a ClearDraft command, and update the
            -- ClearDraft message handler to update DOM status
            let
                draft =
                    Update.Draft.empty
            in
                { model | draft = draft } ! [ Command.updateDomStatus draft.status ]

        StatusDeleted result ->
            case result of
                Ok { decoded } ->
                    Update.Timeline.deleteStatusFromAllTimelines decoded model ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        Unreblogged result ->
            case result of
                Ok _ ->
                    model ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountReceived result ->
            case result of
                Ok { decoded } ->
                    { model
                        | currentView = AccountView decoded
                        , accountRelationships = []
                    }
                        ! [ Command.loadAccountTimeline
                                (List.head model.clients)
                                decoded.id
                                model.accountTimeline.links.next
                          ]

                Err error ->
                    { model
                        | currentView = LocalTimelineView
                        , errors = addErrorNotification (errorText error) model
                    }
                        ! []

        AccountTimeline append result ->
            case result of
                Ok { decoded, links } ->
                    { model | accountTimeline = Update.Timeline.update append decoded links model.accountTimeline } ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountFollowers append result ->
            case result of
                Ok { decoded, links } ->
                    { model | accountFollowers = Update.Timeline.update append decoded links model.accountFollowers }
                        ! [ Command.loadRelationships (List.head model.clients) <| List.map .id decoded ]

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountFollowing append result ->
            case result of
                Ok { decoded, links } ->
                    { model | accountFollowing = Update.Timeline.update append decoded links model.accountFollowing }
                        ! [ Command.loadRelationships (List.head model.clients) <| List.map .id decoded ]

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountRelationship result ->
            case result of
                Ok { decoded } ->
                    case decoded of
                        [ relationship ] ->
                            { model | accountRelationship = Just relationship } ! []

                        _ ->
                            model ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountRelationships result ->
            case result of
                Ok { decoded } ->
                    { model
                        | accountRelationships = List.concat [ model.accountRelationships, decoded ]
                    }
                        ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        HomeTimeline append result ->
            case result of
                Ok { decoded, links } ->
                    { model | homeTimeline = Update.Timeline.update append decoded links model.homeTimeline } ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AutoSearch result ->
            let
                draft =
                    model.draft
            in
                case result of
                    Ok { decoded } ->
                        { model
                            | draft =
                                { draft
                                    | showAutoMenu =
                                        Update.Draft.showAutoMenu
                                            decoded
                                            draft.autoAtPosition
                                            draft.autoQuery
                                    , autoAccounts = decoded
                                }
                        }
                            -- Force selection of the first item after each
                            -- Successfull request
                            ! [ Task.perform identity (Task.succeed ((DraftEvent << ResetAutocomplete) True)) ]

                    Err error ->
                        { model
                            | draft = { draft | showAutoMenu = False }
                            , errors = addErrorNotification (errorText error) model
                        }
                            ! []


{-| Update viewed account relationships as well as the relationship with the
current connected user, both according to the "following" status provided.
-}
processFollowEvent : Relationship -> Model -> Model
processFollowEvent relationship model =
    let
        updateRelationship r =
            if r.id == relationship.id then
                { r | following = relationship.following }
            else
                r

        accountRelationships =
            model.accountRelationships |> List.map updateRelationship

        accountRelationship =
            case model.accountRelationship of
                Just accountRelationship ->
                    if accountRelationship.id == relationship.id then
                        Just { relationship | following = relationship.following }
                    else
                        model.accountRelationship

                Nothing ->
                    Nothing
    in
        { model
            | accountRelationships = accountRelationships
            , accountRelationship = accountRelationship
        }


processUnfollowEvent : Account -> Relationship -> Model -> Model
processUnfollowEvent account relationship model =
    let
        newModel =
            processFollowEvent relationship model
    in
        case model.currentUser of
            Just currentUser ->
                { newModel
                    | homeTimeline = Update.Timeline.cleanUnfollow account currentUser model.homeTimeline
                }

            Nothing ->
                newModel


{-| Update viewed account relationships as well as the relationship with the
current connected user, both according to the "muting" status provided.
-}
processMuteEvent : Account -> Relationship -> Model -> Model
processMuteEvent account relationship model =
    let
        updateRelationship r =
            if r.id == relationship.id then
                { r | muting = relationship.muting }
            else
                r

        accountRelationships =
            model.accountRelationships |> List.map updateRelationship

        accountRelationship =
            case model.accountRelationship of
                Just accountRelationship ->
                    if accountRelationship.id == relationship.id then
                        Just { relationship | muting = relationship.muting }
                    else
                        model.accountRelationship

                Nothing ->
                    Nothing
    in
        { model
            | accountRelationships = accountRelationships
            , accountRelationship = accountRelationship
            , homeTimeline = Update.Timeline.dropAccountStatuses account model.homeTimeline
            , localTimeline = Update.Timeline.dropAccountStatuses account model.localTimeline
            , globalTimeline = Update.Timeline.dropAccountStatuses account model.globalTimeline
            , mutes = Update.Timeline.removeMute account model.mutes
        }


{-| Update viewed account relationships as well as the relationship with the
current connected user, both according to the "blocking" status provided.
-}
processBlockEvent : Account -> Relationship -> Model -> Model
processBlockEvent account relationship model =
    let
        updateRelationship r =
            if r.id == relationship.id then
                { r | blocking = relationship.blocking }
            else
                r

        accountRelationships =
            model.accountRelationships |> List.map updateRelationship

        accountRelationship =
            case model.accountRelationship of
                Just accountRelationship ->
                    if accountRelationship.id == relationship.id then
                        Just { relationship | blocking = relationship.blocking }
                    else
                        model.accountRelationship

                Nothing ->
                    Nothing
    in
        { model
            | accountRelationships = accountRelationships
            , accountRelationship = accountRelationship
            , homeTimeline = Update.Timeline.dropAccountStatuses account model.homeTimeline
            , localTimeline = Update.Timeline.dropAccountStatuses account model.localTimeline
            , globalTimeline = Update.Timeline.dropAccountStatuses account model.globalTimeline
            , blocks = Update.Timeline.removeBlock account model.blocks
            , notifications = Update.Timeline.dropNotificationsFromAccount account model.notifications
        }
