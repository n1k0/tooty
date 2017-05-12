module View.App exposing (view)

import Html exposing (..)
import Html.Keyed as Keyed
import Html.Lazy as Lazy
import Html.Attributes exposing (..)
import Mastodon.Model exposing (..)
import Types exposing (..)
import View.Account exposing (accountFollowView, accountTimelineView)
import View.AccountSelector exposing (accountSelectorView)
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


timelineView : ( String, String, CurrentUser, Timeline Status ) -> Html Msg
timelineView ( label, iconName, currentUser, timeline ) =
    let
        keyedEntry status =
            ( toString id, statusEntryView timeline.id "" currentUser status )

        entries =
            List.map keyedEntry timeline.entries
    in
        div [ class "col-md-3 column" ]
            [ div [ class "panel panel-default" ]
                [ a
                    [ href "", onClickWithPreventAndStop <| ScrollColumn ScrollTop timeline.id ]
                    [ div [ class "panel-heading" ] [ Common.icon iconName, text label ] ]
                , Keyed.ul [ id timeline.id, class "list-group timeline" ] <|
                    (entries ++ [ ( "load-more", Common.loadMoreBtn timeline ) ])
                ]
            ]


homeTimelineView : CurrentUser -> Timeline Status -> Html Msg
homeTimelineView currentUser timeline =
    Lazy.lazy timelineView
        ( "Home timeline"
        , "home"
        , currentUser
        , timeline
        )


localTimelineView : CurrentUser -> Timeline Status -> Html Msg
localTimelineView currentUser timeline =
    Lazy.lazy timelineView
        ( "Local timeline"
        , "th-large"
        , currentUser
        , timeline
        )


globalTimelineView : CurrentUser -> Timeline Status -> Html Msg
globalTimelineView currentUser timeline =
    Lazy.lazy timelineView
        ( "Global timeline"
        , "globe"
        , currentUser
        , timeline
        )


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
                , homeTimelineView currentUser model.homeTimeline
                , Lazy.lazy3
                    notificationListView
                    currentUser
                    model.notificationFilter
                    model.notifications
                , case model.currentView of
                    LocalTimelineView ->
                        localTimelineView currentUser model.localTimeline

                    GlobalTimelineView ->
                        globalTimelineView currentUser model.globalTimeline

                    AccountView account ->
                        accountTimelineView
                            currentUser
                            model.accountTimeline
                            model.accountRelationship
                            account

                    AccountSelectorView ->
                        accountSelectorView model

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
        , case (List.head model.clients) of
            Just client ->
                homepageView model

            Nothing ->
                authView model
        , case model.viewer of
            Just viewer ->
                viewerView viewer

            Nothing ->
                text ""
        , case model.confirm of
            Nothing ->
                text ""

            Just confirm ->
                Common.confirmView confirm
        ]
