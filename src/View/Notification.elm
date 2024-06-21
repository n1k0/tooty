module View.Notification exposing (notificationListView)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Keyed as Keyed
import Html.Lazy as Lazy
import InfiniteScroll
import Mastodon.Model exposing (..)
import Types exposing (..)
import View.Common as Common
import View.Events exposing (..)
import View.Formatter exposing (formatContent)
import View.Status exposing (statusActionsView, statusView)


type alias CurrentUser =
    Account


type alias NotificationStatusData =
    { context : String
    , currentUser : CurrentUser
    , status : Status
    , notificationAggregate : NotificationAggregate
    }


filterNotifications : NotificationFilter -> List NotificationAggregate -> List NotificationAggregate
filterNotifications filter notifications =
    let
        applyFilter { type_, status } =
            let
                visibility =
                    case status of
                        Just s ->
                            s.visibility

                        Nothing ->
                            ""
            in
            case filter of
                NotificationAll ->
                    True

                NotificationOnlyMentions ->
                    type_ == "mention" && visibility /= "direct"

                NotificationOnlyDirect ->
                    type_ == "mention" && visibility == "direct"

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


notificationHeading : List AccountNotificationDate -> String -> String -> Html Msg
notificationHeading accountsAndDate str iconType =
    let
        ( firstAccounts, finalStr ) =
            case accountsAndDate of
                [ a1 ] ->
                    ( [ a1.account ], str )

                [ a1, a2 ] ->
                    ( [ a1.account, a2.account ], str )

                [ a1, a2, a3 ] ->
                    ( [ a1.account, a2.account, a3.account ], str )

                a1 :: a2 :: a3 :: xs ->
                    ( [ a1.account, a2.account, a3.account ], " and " ++ (String.fromInt <| List.length xs) ++ " others " ++ str )

                _ ->
                    ( [], "" )
    in
    div [ class "status-info" ]
        [ div [ class "avatars" ] <|
            List.map (Common.accountAvatarLink False Nothing) (List.map .account accountsAndDate)
        , p [ class "status-info-text" ] <|
            List.intersperse (text " ")
                [ Common.icon iconType
                , span [] <| List.intersperse (text ", ") (List.map (Common.accountLink False) firstAccounts)
                , text finalStr
                ]
        ]


notificationStatusView : NotificationStatusData -> Html Msg
notificationStatusView { context, currentUser, status, notificationAggregate } =
    div [ class <| "notification " ++ notificationAggregate.type_ ]
        [ case notificationAggregate.type_ of
            "reblog" ->
                notificationHeading notificationAggregate.accounts "boosted your toot" "fire"

            "favourite" ->
                notificationHeading notificationAggregate.accounts "favourited your toot" "star"

            _ ->
                text ""
        , Lazy.lazy3 statusView context False status
        , Lazy.lazy3 statusActionsView status currentUser False
        ]


notificationFollowView : CurrentUser -> NotificationAggregate -> Html Msg
notificationFollowView _ { accounts } =
    let
        profileView : AccountNotificationDate -> Html Msg
        profileView { account, created_at } =
            div [ class "status follow-profile" ]
                [ Common.accountAvatarLink False Nothing account
                , div [ class "username" ]
                    [ Common.accountLink False account
                    , span [ class "btn-sm follow-profile-date" ]
                        [ Common.icon "time", text <| Common.formatDate created_at ]
                    ]
                , formatContent account.note []
                    |> div
                        [ class "status-text"
                        , onClick <| Navigate ("#account/" ++ account.id)
                        ]
                ]
    in
    div [ class "notification follow" ]
        [ notificationHeading accounts "started following you" "user"
        , div [ class "" ] <| List.map profileView (List.take 3 accounts)
        ]


notificationEntryView : CurrentUser -> NotificationAggregate -> Html Msg
notificationEntryView currentUser notification =
    li [ class "list-group-item" ]
        [ case notification.status of
            Just status ->
                Lazy.lazy notificationStatusView
                    { context = "notification"
                    , currentUser = currentUser
                    , status = status
                    , notificationAggregate = notification
                    }

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
    Common.justifiedButtonGroup "column-menu notification-filters"
        [ filterBtn "All notifications" "asterisk" NotificationAll
        , filterBtn "Mentions" "share-alt" NotificationOnlyMentions
        , filterBtn "Direct" "envelope" NotificationOnlyDirect
        , filterBtn "Boosts" "fire" NotificationOnlyBoosts
        , filterBtn "Favorites" "star" NotificationOnlyFavourites
        , filterBtn "Follows" "user" NotificationOnlyFollows
        ]


notificationListView : CurrentUser -> NotificationFilter -> Timeline NotificationAggregate -> Html Msg
notificationListView currentUser filter notifications =
    let
        keyedEntry notification =
            ( notification.id
            , Lazy.lazy2 notificationEntryView currentUser notification
            )

        entries =
            notifications.entries
                |> filterNotifications filter
                |> List.map keyedEntry
    in
    div [ class "col-md-3 column" ]
        [ div [ class "panel panel-default notifications-panel" ]
            [ a
                [ href "", onClickWithPreventAndStop <| ScrollColumn ScrollTop "notifications" ]
                [ div [ class "panel-heading" ] [ Common.icon "bell", text "Notifications" ] ]
            , notificationFilterView filter
            , Keyed.ul [ id "notifications", class "list-group timeline", InfiniteScroll.infiniteScroll (InfiniteScrollMsg ScrollNotifications) ] <|
                (entries ++ [ ( "load-more", Common.loadMoreBtn notifications ) ])
            ]
        ]
