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
import View.Mutes exposing (mutesView)
import View.Notification exposing (notificationListView)
import View.Search exposing (searchView)
import View.Thread exposing (threadView)
import View.Timeline exposing (contextualTimelineView, hashtagTimelineView, homeTimelineView)
import View.Viewer exposing (viewerView)


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
            let
                fragment =
                    Maybe.withDefault "" model.location.fragment
            in
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
                            fragment
                            "Local timeline"
                            "th-large"
                            currentUser
                            model.localTimeline

                    GlobalTimelineView ->
                        contextualTimelineView
                            fragment
                            "Global timeline"
                            "globe"
                            currentUser
                            model.globalTimeline

                    FavoriteTimelineView ->
                        contextualTimelineView
                            fragment
                            "Favorites"
                            "star"
                            currentUser
                            model.favoriteTimeline

                    HashtagView hashtag ->
                        hashtagTimelineView hashtag currentUser model.hashtagTimeline

                    SearchView ->
                        searchView model
                ]


type alias Document msg =
    { title : String
    , body : List (Html msg)
    }


view : Model -> Document Msg
view model =
    { title = "Tooty"
    , body =
        [ div [ class "container-fluid" ]
            [ errorsListView model
            , case List.head model.clients of
                Just _ ->
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
        ]
    }
