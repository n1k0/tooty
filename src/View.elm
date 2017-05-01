module View exposing (view)

import Html exposing (..)
import Html.Keyed as Keyed
import Html.Lazy exposing (lazy, lazy2, lazy3)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Mastodon.Model exposing (..)
import Types exposing (..)
import ViewHelper exposing (..)
import Views.Account exposing (accountFollowView, accountTimelineView)
import Views.Auth exposing (authView)
import Views.Common as Common
import Views.Draft exposing (draftView)
import Views.Error exposing (errorsListView)
import Views.Notification exposing (notificationListView)
import Views.Status exposing (statusView, statusActionsView, statusEntryView)
import Views.Thread exposing (threadView)
import Views.Viewer exposing (viewerView)


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


optionsView : Model -> Html Msg
optionsView model =
    div [ class "panel panel-default" ]
        [ div [ class "panel-heading" ] [ Common.icon "cog", text "options" ]
        , div [ class "panel-body" ]
            [ div [ class "checkbox" ]
                [ label []
                    [ input [ type_ "checkbox", onCheck UseGlobalTimeline ] []
                    , text " 4th column renders the global timeline"
                    ]
                ]
            ]
        ]


sidebarView : Model -> Html Msg
sidebarView model =
    div [ class "col-md-3 column" ]
        [ lazy draftView model
        , lazy optionsView model
        ]


homepageView : Model -> Html Msg
homepageView model =
    case model.currentUser of
        Nothing ->
            text ""

        Just currentUser ->
            div [ class "row" ]
                [ lazy sidebarView model
                , lazy timelineView
                    ( "Home timeline"
                    , "home"
                    , "home"
                    , currentUser
                    , model.userTimeline
                    )
                , lazy3 notificationListView currentUser model.notificationFilter model.notifications
                , case model.currentView of
                    LocalTimelineView ->
                        lazy timelineView
                            ( "Local timeline"
                            , "th-large"
                            , "local"
                            , currentUser
                            , model.localTimeline
                            )

                    GlobalTimelineView ->
                        lazy timelineView
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
