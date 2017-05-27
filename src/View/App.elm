module View.App exposing (view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Lazy as Lazy
import Mastodon.Model exposing (..)
import Types exposing (..)
import View.Account exposing (accountFollowView, accountTimelineView)
import View.AccountSelector exposing (accountSelectorView)
import View.Auth exposing (authView)
import View.Blocks exposing (blocksView)
import View.Common as Common
import View.Draft exposing (draftView)
import View.Error exposing (errorsListView)


-- import View.HashTag exposing (hashtagView)

import View.Mutes exposing (mutesView)
import View.Notification exposing (notificationListView)
import View.Thread exposing (threadView)
import View.Timeline exposing (contextualTimelineView, homeTimelineView)
import View.Viewer exposing (viewerView)


type alias CurrentUser =
    Account


type alias CurrentUserRelation =
    Maybe Relationship


sidebarView : Model -> Html Msg
sidebarView model =
    div [ class "col-md-3 column" ]
        [ Lazy.lazy draftView model
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
                    AccountView account ->
                        accountTimelineView
                            currentUser
                            model.accountTimeline
                            model.accountRelationship
                            account

                    AccountSelectorView ->
                        accountSelectorView model

                    MutesView ->
                        mutesView model

                    BlocksView ->
                        blocksView model

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

                    LocalTimelineView ->
                        contextualTimelineView
                            LocalTimelineView
                            "Local timeline"
                            "th-large"
                            currentUser
                            model.localTimeline

                    GlobalTimelineView ->
                        contextualTimelineView
                            GlobalTimelineView
                            "Global timeline"
                            "globe"
                            currentUser
                            model.globalTimeline

                    FavoriteTimelineView ->
                        contextualTimelineView
                            FavoriteTimelineView
                            "Favorites"
                            "star"
                            currentUser
                            model.favoriteTimeline

                    HashtagView hashtag ->
                        contextualTimelineView
                            (HashtagView hashtag)
                            ("#" ++ hashtag)
                            "tags"
                            currentUser
                            model.hashtagTimeline
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
