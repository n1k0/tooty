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


notificationHeading : List Account -> String -> String -> Html Msg
notificationHeading accounts str iconType =
    div [ class "status-info" ]
        [ div [ class "avatars" ] <| List.map Common.accountAvatarLink accounts
        , p [ class "status-info-text" ] <|
            List.intersperse (text " ")
                [ Common.icon iconType
                , span [] <| List.intersperse (text ", ") (List.map Common.accountLink accounts)
                , text str
                ]
        ]


notificationStatusView : ( String, CurrentUser, Status, NotificationAggregate ) -> Html Msg
notificationStatusView ( context, currentUser, status, { type_, accounts } ) =
    div [ class <| "notification " ++ type_ ]
        [ case type_ of
            "reblog" ->
                notificationHeading accounts "boosted your toot" "fire"

            "favourite" ->
                notificationHeading accounts "favourited your toot" "star"

            _ ->
                text ""
        , lazy2 statusView context status
        , lazy2 statusActionsView status currentUser
        ]


notificationFollowView : CurrentUser -> NotificationAggregate -> Html Msg
notificationFollowView currentUser { accounts } =
    let
        profileView account =
            div [ class "status follow-profile" ]
                [ Common.accountAvatarLink account
                , div [ class "username" ] [ Common.accountLink account ]
                , p
                    [ class "status-text"
                    , onClick <| LoadAccount account.id
                    ]
                  <|
                    formatContent account.note []
                ]
    in
        div [ class "notification follow" ]
            [ notificationHeading accounts "started following you" "user"
            , div [ class "" ] <| List.map profileView accounts
            ]


notificationEntryView : CurrentUser -> NotificationAggregate -> Html Msg
notificationEntryView currentUser notification =
    li [ class "list-group-item" ]
        [ case notification.status of
            Just status ->
                lazy notificationStatusView ( "notification", currentUser, status, notification )

            Nothing ->
                notificationFollowView currentUser notification
        ]


notificationFilterView : NotificationFilter -> Html Msg
notificationFilterView filter =
    let
        filterBtn tooltip iconName event =
            button
                [ class <|
                    if filter == event then
                        "btn btn-primary"
                    else
                        "btn btn-default"
                , title tooltip
                , onClick <| FilterNotifications event
                ]
                [ Common.icon iconName ]
    in
        Common.justifiedButtonGroup
            [ filterBtn "All notifications" "asterisk" NotificationAll
            , filterBtn "Mentions" "share-alt" NotificationOnlyMentions
            , filterBtn "Boosts" "fire" NotificationOnlyBoosts
            , filterBtn "Favorites" "star" NotificationOnlyFavourites
            , filterBtn "Follows" "user" NotificationOnlyFollows
            ]


notificationListView : CurrentUser -> NotificationFilter -> List NotificationAggregate -> Html Msg
notificationListView currentUser filter notifications =
    let
        keyedEntry notification =
            ( toString notification.id
            , lazy2 notificationEntryView currentUser notification
            )
    in
        div [ class "col-md-3 column" ]
            [ div [ class "panel panel-default notifications-panel" ]
                [ a
                    [ href "", onClickWithPreventAndStop <| ScrollColumn ScrollTop "notifications" ]
                    [ div [ class "panel-heading" ] [ Common.icon "bell", text "Notifications" ] ]
                , notificationFilterView filter
                , Keyed.ul [ id "notifications", class "list-group timeline" ] <|
                    (notifications
                        |> filterNotifications filter
                        |> List.map keyedEntry
                    )
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
