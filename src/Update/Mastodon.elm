module Update.Mastodon exposing (update)

import Command
import Navigation
import Mastodon.Helper exposing (extractStatusId)
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
update msg ({ accountInfo, search } as model) =
    case msg of
        AccessToken result ->
            case result of
                Ok { decoded } ->
                    let
                        client =
                            Client decoded.server decoded.accessToken Nothing
                    in
                        { model | clients = client :: model.clients }
                            ! [ Command.saveClients <| client :: model.clients
                              , Navigation.load <| model.location.origin ++ model.location.pathname
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

        ThreadStatusLoaded id result ->
            case result of
                Ok { decoded } ->
                    { model
                        | currentView =
                            case model.currentView of
                                ThreadView thread ->
                                    ThreadView { thread | status = Just decoded }

                                _ ->
                                    model.currentView
                    }
                        ! [ Command.scrollToThreadStatus <| extractStatusId id ]

                Err error ->
                    { model
                        | currentView = LocalTimelineView
                        , errors = addErrorNotification (errorText error) model
                    }
                        ! []

        ThreadContextLoaded id result ->
            case result of
                Ok { decoded } ->
                    { model
                        | currentView =
                            case model.currentView of
                                ThreadView thread ->
                                    ThreadView { thread | context = Just decoded }

                                _ ->
                                    model.currentView
                    }
                        ! [ Command.scrollToThreadStatus <| extractStatusId id ]

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
                    { model | accountInfo = { accountInfo | account = Just decoded, relationships = [] } } ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountTimeline append result ->
            case result of
                Ok { decoded, links } ->
                    { model
                        | accountInfo =
                            { accountInfo
                                | timeline = Update.Timeline.update append decoded links accountInfo.timeline
                            }
                    }
                        ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountFollowers append result ->
            case result of
                Ok { decoded, links } ->
                    { model
                        | accountInfo =
                            { accountInfo
                                | followers = Update.Timeline.update append decoded links accountInfo.followers
                            }
                    }
                        ! [ Command.loadRelationships (List.head model.clients) <| List.map .id decoded ]

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountFollowing append result ->
            case result of
                Ok { decoded, links } ->
                    { model
                        | accountInfo =
                            { accountInfo
                                | following = Update.Timeline.update append decoded links accountInfo.following
                            }
                    }
                        ! [ Command.loadRelationships (List.head model.clients) <| List.map .id decoded ]

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountRelationship result ->
            case result of
                Ok { decoded } ->
                    case decoded of
                        [ relationship ] ->
                            { model | accountInfo = { accountInfo | relationship = Just relationship } } ! []

                        _ ->
                            model ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountRelationships result ->
            case result of
                Ok { decoded } ->
                    { model | accountInfo = { accountInfo | relationships = accountInfo.relationships ++ decoded } }
                        ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        HomeTimeline append result ->
            case result of
                Ok { decoded, links } ->
                    { model | homeTimeline = Update.Timeline.update append decoded links model.homeTimeline } ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        SearchResultsReceived result ->
            case result of
                Ok { decoded } ->
                    { model | search = { search | term = model.search.term, results = Just decoded } } ! []

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
processFollowEvent relationship ({ accountInfo } as model) =
    let
        updateRelationship r =
            if r.id == relationship.id then
                { r | following = relationship.following }
            else
                r

        accountRelationships =
            accountInfo.relationships |> List.map updateRelationship

        accountRelationship =
            case accountInfo.relationship of
                Just accountRelationship ->
                    if accountRelationship.id == relationship.id then
                        Just { relationship | following = relationship.following }
                    else
                        accountInfo.relationship

                Nothing ->
                    Nothing
    in
        { model
            | accountInfo =
                { accountInfo
                    | relationships = accountRelationships
                    , relationship = accountRelationship
                }
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
processMuteEvent account relationship ({ accountInfo } as model) =
    let
        updateRelationship r =
            if r.id == relationship.id then
                { r | muting = relationship.muting }
            else
                r

        accountRelationships =
            accountInfo.relationships |> List.map updateRelationship

        accountRelationship =
            case accountInfo.relationship of
                Just accountRelationship ->
                    if accountRelationship.id == relationship.id then
                        Just { relationship | muting = relationship.muting }
                    else
                        accountInfo.relationship

                Nothing ->
                    Nothing
    in
        { model
            | accountInfo =
                { accountInfo
                    | relationship = accountRelationship
                    , relationships = accountRelationships
                }
            , homeTimeline = Update.Timeline.dropAccountStatuses account model.homeTimeline
            , localTimeline = Update.Timeline.dropAccountStatuses account model.localTimeline
            , globalTimeline = Update.Timeline.dropAccountStatuses account model.globalTimeline
            , mutes = Update.Timeline.removeMute account model.mutes
        }


{-| Update viewed account relationships as well as the relationship with the
current connected user, both according to the "blocking" status provided.
-}
processBlockEvent : Account -> Relationship -> Model -> Model
processBlockEvent account relationship ({ accountInfo } as model) =
    let
        updateRelationship r =
            if r.id == relationship.id then
                { r | blocking = relationship.blocking }
            else
                r

        accountRelationships =
            accountInfo.relationships |> List.map updateRelationship

        accountRelationship =
            case accountInfo.relationship of
                Just accountRelationship ->
                    if accountRelationship.id == relationship.id then
                        Just { relationship | blocking = relationship.blocking }
                    else
                        accountInfo.relationship

                Nothing ->
                    Nothing
    in
        { model
            | accountInfo =
                { accountInfo
                    | relationship = accountRelationship
                    , relationships = accountRelationships
                }
            , homeTimeline = Update.Timeline.dropAccountStatuses account model.homeTimeline
            , localTimeline = Update.Timeline.dropAccountStatuses account model.localTimeline
            , globalTimeline = Update.Timeline.dropAccountStatuses account model.globalTimeline
            , blocks = Update.Timeline.removeBlock account model.blocks
            , notifications = Update.Timeline.dropNotificationsFromAccount account model.notifications
        }
