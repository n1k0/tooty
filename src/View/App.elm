module View.App exposing (view)

import Html exposing (..)
import Html.Keyed as Keyed
import Html.Lazy as Lazy
import Html.Attributes exposing (..)
import Mastodon.Model exposing (..)
import Types exposing (..)
import View.Account exposing (accountFollowView, accountTimelineView)
import View.Auth exposing (authView)
import View.Common as Common
import View.Draft exposing (draftView)
import View.Error exposing (errorsListView)
import View.Events exposing (..)
import View.Notification exposing (notificationListView)
import View.Settings exposing (settingsView)
import View.Status exposing (statusView, statusActionsView, statusEntryView)
import View.Thread exposing (threadView)
import View.Viewer exposing (viewerView)


type alias CurrentUser =
    Account


type alias CurrentUserRelation =
    Maybe Relationship


timelineView : ( String, String, String, CurrentUser, List Status ) -> Html Msg
timelineView ( label, iconName, context, currentUser, statuses ) =
    let
        keyedEntry status =
            ( toString id, statusEntryView context "" currentUser status )
    in
        div [ class "col-md-3 column" ]
            [ div [ class "panel panel-default" ]
                [ a
                    [ href "", onClickWithPreventAndStop <| ScrollColumn ScrollTop context ]
                    [ div [ class "panel-heading" ] [ Common.icon iconName, text label ] ]
                , Keyed.ul [ id context, class "list-group timeline" ] <|
                    List.map keyedEntry statuses
                ]
            ]


sidebarView : Model -> Html Msg
sidebarView model =
    div [ class "col-md-3 column" ]
        [ Lazy.lazy draftView model
        , Lazy.lazy settingsView model
        ]


homepageView : Model -> Html Msg
homepageView model =
    case model.currentUser of
        Nothing ->
            text ""

        Just currentUser ->
            div [ class "row" ]
                [ Lazy.lazy sidebarView model
                , Lazy.lazy timelineView
                    ( "Home timeline"
                    , "home"
                    , "home"
                    , currentUser
                    , model.userTimeline
                    )
                , Lazy.lazy3
                    notificationListView
                    currentUser
                    model.notificationFilter
                    model.notifications
                , case model.currentView of
                    LocalTimelineView ->
                        Lazy.lazy timelineView
                            ( "Local timeline"
                            , "th-large"
                            , "local"
                            , currentUser
                            , model.localTimeline
                            )

                    GlobalTimelineView ->
                        Lazy.lazy timelineView
                            ( "Global timeline"
                            , "globe"
                            , "global"
                            , currentUser
                            , model.globalTimeline
                            )

                    AccountView account ->
                        accountTimelineView
                            currentUser
                            model.accountTimeline
                            model.accountRelationship
                            account

                    AccountFollowersView account followers ->
                        accountFollowView
                            currentUser
                            model.accountFollowers
                            model.accountRelationships
                            model.accountRelationship
                            account

                    AccountFollowingView account following ->
                        accountFollowView
                            currentUser
                            model.accountFollowing
                            model.accountRelationships
                            model.accountRelationship
                            account

                    ThreadView thread ->
                        threadView currentUser thread
                ]


view : Model -> Html Msg
view model =
    div [ class "container-fluid" ]
        [ errorsListView model
        , case model.client of
            Just client ->
                homepageView model

            Nothing ->
                authView model
        , case model.viewer of
            Just viewer ->
                viewerView viewer

            Nothing ->
                text ""
        ]
