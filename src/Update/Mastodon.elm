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


update : MastodonMsg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        AccessToken result ->
            case result of
                Ok { decoded } ->
                    let
                        client =
                            Client decoded.server decoded.accessToken
                    in
                        { model | client = Just client }
                            ! [ Command.loadTimelines <| Just client
                              , Command.saveClient client
                              , Navigation.modifyUrl model.location.pathname
                              , Navigation.reload
                              ]

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountFollowed result ->
            case result of
                Ok { decoded } ->
                    processFollowEvent decoded True model ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountUnfollowed result ->
            case result of
                Ok { decoded } ->
                    processFollowEvent decoded False model ! []

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
                    { model | currentView = ThreadView (Thread status decoded) }
                        ! [ Command.scrollToThreadStatus <| toString status.id ]

                Err error ->
                    { model
                        | currentView = Update.Timeline.preferred model
                        , errors = addErrorNotification (errorText error) model
                    }
                        ! []

        CurrentUser result ->
            case result of
                Ok { decoded } ->
                    { model | currentUser = Just decoded } ! []

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
                { model | draft = draft }
                    ! [ Command.scrollColumnToTop "home-timeline"
                      , Command.updateDomStatus draft.status
                      ]

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
                    { model | currentView = AccountView decoded }
                        ! [ Command.loadAccountTimeline model.client decoded.id model.accountTimeline.links.next ]

                Err error ->
                    { model
                        | currentView = Update.Timeline.preferred model
                        , errors = addErrorNotification (errorText error) model
                    }
                        ! []

        AccountTimeline append result ->
            case result of
                Ok { decoded, links } ->
                    { model | accountTimeline = Update.Timeline.update append decoded links model.accountTimeline } ! []

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountFollowers result ->
            case result of
                Ok { decoded } ->
                    -- TODO: store next link
                    { model | accountFollowers = decoded }
                        ! [ Command.loadRelationships model.client <| List.map .id decoded ]

                Err error ->
                    { model | errors = addErrorNotification (errorText error) model } ! []

        AccountFollowing result ->
            case result of
                Ok { decoded } ->
                    -- TODO: store next link
                    { model | accountFollowing = decoded }
                        ! [ Command.loadRelationships model.client <| List.map .id decoded ]

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
                    -- TODO: store next link
                    { model | accountRelationships = decoded } ! []

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
processFollowEvent : Relationship -> Bool -> Model -> Model
processFollowEvent relationship flag model =
    let
        updateRelationship r =
            if r.id == relationship.id then
                { r | following = flag }
            else
                r

        accountRelationships =
            model.accountRelationships |> List.map updateRelationship

        accountRelationship =
            case model.accountRelationship of
                Just accountRelationship ->
                    if accountRelationship.id == relationship.id then
                        Just { relationship | following = flag }
                    else
                        model.accountRelationship

                Nothing ->
                    Nothing
    in
        { model
            | accountRelationships = accountRelationships
            , accountRelationship = accountRelationship
        }
