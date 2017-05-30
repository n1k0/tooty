module View.App exposing (view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Lazy as Lazy
import Mastodon.Model exposing (..)
import Types exposing (..)
import View.Account exposing (accountView)
import View.AccountSelector exposing (accountSelectorView)
import View.Auth exposing (authView)
import View.Blocks exposing (blocksView)
import View.Common as Common
import View.Draft exposing (draftView)
import View.Error exposing (errorsListView)
import View.Search exposing (searchView)
import View.Mutes exposing (mutesView)
import View.Notification exposing (notificationListView)
import View.Thread exposing (threadView)
import View.Timeline exposing (contextualTimelineView, homeTimelineView, hashtagTimelineView)
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
                    AccountView subView ->
                        accountView subView currentUser model.accountInfo

                    AccountSelectorView ->
                        accountSelectorView model

                    MutesView ->
                        mutesView model

                    BlocksView ->
                        blocksView model

                    ThreadView thread ->
                        threadView currentUser thread

                    LocalTimelineView ->
                        contextualTimelineView
                            model.location.hash
                            "Local timeline"
                            "th-large"
                            currentUser
                            model.localTimeline

                    GlobalTimelineView ->
                        contextualTimelineView
                            model.location.hash
                            "Global timeline"
                            "globe"
                            currentUser
                            model.globalTimeline

                    FavoriteTimelineView ->
                        contextualTimelineView
                            model.location.hash
                            "Favorites"
                            "star"
                            currentUser
                            model.favoriteTimeline

                    HashtagView hashtag ->
                        hashtagTimelineView hashtag currentUser model.hashtagTimeline

                    SearchView ->
                        searchView model
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
