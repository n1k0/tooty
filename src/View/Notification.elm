module View.Notification exposing (notificationListView)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Keyed as Keyed
import Html.Lazy as Lazy
import Mastodon.Model exposing (..)
import Types exposing (..)
import View.Common as Common
import View.Events exposing (..)
import View.Formatter exposing (formatContent)
import View.Status exposing (statusActionsView, statusView)


type alias CurrentUser =
    Account


filterNotifications : NotificationFilter -> List NotificationAggregate -> List NotificationAggregate
filterNotifications filter notifications =
    let
        applyFilter { type_ } =
            case filter of
                NotificationAll ->
                    True

                NotificationOnlyMentions ->
                    type_ == "mention"

                NotificationOnlyBoosts ->
                    type_ == "reblog"

                NotificationOnlyFavourites ->
                    type_ == "favourite"

                NotificationOnlyFollows ->
                    type_ == "follow"
    in
        if filter == NotificationAll then
            notifications
        else
            List.filter applyFilter notifications


notificationHeading : List Account -> String -> String -> Html Msg
notificationHeading accounts str iconType =
    div [ class "status-info" ]
        [ div [ class "avatars" ] <| List.map (Common.accountAvatarLink False) accounts
        , p [ class "status-info-text" ] <|
            List.intersperse (text " ")
                [ Common.icon iconType
                , span [] <| List.intersperse (text ", ") (List.map (Common.accountLink False) accounts)
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
        , Lazy.lazy2 statusView context status
        , Lazy.lazy2 statusActionsView status currentUser
        ]


notificationFollowView : CurrentUser -> NotificationAggregate -> Html Msg
notificationFollowView currentUser { accounts } =
    let
        profileView account =
            div [ class "status follow-profile" ]
                [ Common.accountAvatarLink False account
                , div [ class "username" ] [ Common.accountLink False account ]
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
                Lazy.lazy notificationStatusView ( "notification", currentUser, status, notification )

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
                        "btn btn-primary active"
                    else
                        "btn btn-default"
                , title tooltip
                , onClick <| FilterNotifications event
                ]
                [ Common.icon iconName ]
    in
        Common.justifiedButtonGroup "notification-filters"
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
            , Lazy.lazy2 notificationEntryView currentUser notification
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
