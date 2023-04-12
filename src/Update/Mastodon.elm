module Update.Mastodon exposing (update)

import Browser.Navigation as Navigation
import Command
import Mastodon.Helper exposing (extractStatusId)
import Mastodon.Model exposing (..)
import Types exposing (..)
import Update.Draft
import Update.Error exposing (..)
import Update.Timeline
import Url


errorText : Error -> String
errorText error =
    case error of
        MastodonError statusCode statusMsg errorMsg ->
            "HTTP " ++ String.fromInt statusCode ++ " " ++ statusMsg ++ ": " ++ errorMsg

        ServerError statusCode statusMsg errorMsg ->
            "HTTP " ++ String.fromInt statusCode ++ " " ++ statusMsg ++ ": " ++ errorMsg

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
                    ( { model | clients = client :: model.clients }
                    , Cmd.batch
                        [ Command.saveClients <| client :: model.clients
                        , Navigation.load <| Url.toString model.location
                        ]
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        AccountFollowed _ result ->
            case result of
                Ok { decoded } ->
                    ( processFollowEvent decoded model
                    , Cmd.none
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        AccountUnfollowed account result ->
            case result of
                Ok { decoded } ->
                    ( processUnfollowEvent account decoded model
                    , Cmd.none
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        AccountMuted account result ->
            case result of
                Ok { decoded } ->
                    ( processMuteEvent account decoded model
                    , Cmd.none
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        AccountUnmuted account result ->
            case result of
                Ok { decoded } ->
                    ( processMuteEvent account decoded model
                    , Cmd.none
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        AccountBlocked account result ->
            case result of
                Ok { decoded } ->
                    ( processBlockEvent account decoded model
                    , Cmd.none
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        AccountUnblocked account result ->
            case result of
                Ok { decoded } ->
                    ( processBlockEvent account decoded model
                    , Cmd.none
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        AppRegistered result ->
            case result of
                Ok { decoded } ->
                    ( { model | registration = Just decoded }
                    , Cmd.batch
                        [ Command.saveRegistration decoded
                        , Command.navigateToAuthUrl decoded
                        ]
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        ThreadStatusLoaded id result ->
            case result of
                Ok { decoded } ->
                    ( { model
                        | currentView =
                            case model.currentView of
                                ThreadView thread ->
                                    ThreadView { thread | status = Just decoded }

                                _ ->
                                    model.currentView
                      }
                    , Command.scrollToThreadStatus <| extractStatusId id
                    )

                Err error ->
                    ( { model
                        | currentView = LocalTimelineView
                        , errors = addErrorNotification (errorText error) model
                      }
                    , Cmd.none
                    )

        ThreadContextLoaded id result ->
            case result of
                Ok { decoded } ->
                    ( { model
                        | currentView =
                            case model.currentView of
                                ThreadView thread ->
                                    ThreadView { thread | context = Just decoded }

                                _ ->
                                    model.currentView
                      }
                    , Command.scrollToThreadStatus <| extractStatusId id
                    )

                Err error ->
                    ( { model
                        | currentView = LocalTimelineView
                        , errors = addErrorNotification (errorText error) model
                      }
                    , Cmd.none
                    )

        CurrentUser result ->
            case result of
                Ok { decoded } ->
                    let
                        updatedClients =
                            case model.clients of
                                client :: xs ->
                                    { client | account = Just decoded } :: xs

                                _ ->
                                    model.clients
                    in
                    ( { model | currentUser = Just decoded, clients = updatedClients }
                    , Command.saveClients updatedClients
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        FavoriteAdded result ->
            case result of
                Ok _ ->
                    ( model
                    , Cmd.none
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        FavoriteRemoved result ->
            case result of
                Ok _ ->
                    ( model
                    , Cmd.none
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        HashtagTimeline append result ->
            case result of
                Ok { decoded, links } ->
                    ( { model | hashtagTimeline = Update.Timeline.update append decoded links model.hashtagTimeline }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        LocalTimeline append result ->
            case result of
                Ok { decoded, links } ->
                    ( { model | localTimeline = Update.Timeline.update append decoded links model.localTimeline }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        Notifications append result ->
            case result of
                Ok { decoded, links } ->
                    let
                        aggregated =
                            Mastodon.Helper.aggregateNotifications decoded
                    in
                    ( { model | notifications = Update.Timeline.update append aggregated links model.notifications }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        GlobalTimeline append result ->
            case result of
                Ok { decoded, links } ->
                    ( { model | globalTimeline = Update.Timeline.update append decoded links model.globalTimeline }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        FavoriteTimeline append result ->
            case result of
                Ok { decoded, links } ->
                    ( { model | favoriteTimeline = Update.Timeline.update append decoded links model.favoriteTimeline }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        Mutes append result ->
            case result of
                Ok { decoded, links } ->
                    ( { model | mutes = Update.Timeline.update append decoded links model.mutes }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        Blocks append result ->
            case result of
                Ok { decoded, links } ->
                    ( { model | blocks = Update.Timeline.update append decoded links model.blocks }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        Reblogged result ->
            case result of
                Ok _ ->
                    ( model
                    , Cmd.none
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        StatusPosted _ ->
            -- FIXME: here we should rather send a ClearDraft command, and update the
            -- ClearDraft message handler to update DOM status
            let
                draft =
                    Update.Draft.empty
            in
            ( { model | draft = draft }
            , Command.updateDomStatus draft.status
            )

        StatusDeleted result ->
            case result of
                Ok { decoded } ->
                    ( Update.Timeline.deleteStatusFromAllTimelines decoded model
                    , Cmd.none
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        Unreblogged result ->
            case result of
                Ok _ ->
                    ( model
                    , Cmd.none
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        AccountReceived result ->
            case result of
                Ok { decoded } ->
                    ( { model | accountInfo = { accountInfo | account = Just decoded, relationships = [] } }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        AccountTimeline append result ->
            case result of
                Ok { decoded, links } ->
                    ( { model
                        | accountInfo =
                            { accountInfo
                                | timeline = Update.Timeline.update append decoded links accountInfo.timeline
                            }
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        AccountFollowers append result ->
            case result of
                Ok { decoded, links } ->
                    ( { model
                        | accountInfo =
                            { accountInfo
                                | followers = Update.Timeline.update append decoded links accountInfo.followers
                            }
                      }
                    , Command.loadRelationships (List.head model.clients) <| List.map .id decoded
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        AccountFollowing append result ->
            case result of
                Ok { decoded, links } ->
                    ( { model
                        | accountInfo =
                            { accountInfo
                                | following = Update.Timeline.update append decoded links accountInfo.following
                            }
                      }
                    , Command.loadRelationships (List.head model.clients) <| List.map .id decoded
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        AccountRelationship result ->
            case result of
                Ok { decoded } ->
                    case decoded of
                        [ relationship ] ->
                            ( { model | accountInfo = { accountInfo | relationship = Just relationship } }
                            , Cmd.none
                            )

                        _ ->
                            ( model
                            , Cmd.none
                            )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        AccountRelationships result ->
            case result of
                Ok { decoded } ->
                    ( { model | accountInfo = { accountInfo | relationships = accountInfo.relationships ++ decoded } }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        HomeTimeline append result ->
            case result of
                Ok { decoded, links } ->
                    ( { model | homeTimeline = Update.Timeline.update append decoded links model.homeTimeline }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        SearchResultsReceived result ->
            case result of
                Ok { decoded } ->
                    ( { model | search = { search | term = model.search.term, results = Just decoded } }
                    , Cmd.none
                    )

                Err error ->
                    ( { model | errors = addErrorNotification (errorText error) model }
                    , Cmd.none
                    )

        AutoSearch _ ->
            ( model, Cmd.none )


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
                Just ar ->
                    if ar.id == relationship.id then
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
                Just ar ->
                    if ar.id == relationship.id then
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
                Just ar ->
                    if ar.id == relationship.id then
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
