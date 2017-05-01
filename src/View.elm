module View exposing (view)

import Html exposing (..)
import Html.Keyed as Keyed
import Html.Lazy exposing (lazy, lazy2, lazy3)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import List.Extra exposing (find, elemIndex, getAt)
import Mastodon.Helper
import Mastodon.Model exposing (..)
import Types exposing (..)
import ViewHelper exposing (..)
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


followButton : CurrentUser -> CurrentUserRelation -> Account -> Html Msg
followButton currentUser relationship account =
    if Mastodon.Helper.sameAccount account currentUser then
        text ""
    else
        let
            ( followEvent, btnClasses, iconName, tooltip ) =
                case relationship of
                    Nothing ->
                        ( NoOp
                        , "btn btn-default btn-disabled"
                        , "question-sign"
                        , "Unknown relationship"
                        )

                    Just relationship ->
                        if relationship.following then
                            ( UnfollowAccount account.id
                            , "btn btn-default btn-primary"
                            , "eye-close"
                            , "Unfollow"
                            )
                        else
                            ( FollowAccount account.id
                            , "btn btn-default"
                            , "eye-open"
                            , "Follow"
                            )
        in
            button [ class btnClasses, title tooltip, onClick followEvent ]
                [ Common.icon iconName ]


followView : CurrentUser -> Maybe Relationship -> Account -> Html Msg
followView currentUser relationship account =
    div [ class "follow-entry" ]
        [ Common.accountAvatarLink account
        , div [ class "userinfo" ]
            [ strong []
                [ a
                    [ href account.url
                    , onClickWithPreventAndStop <| LoadAccount account.id
                    ]
                    [ text <|
                        if account.display_name /= "" then
                            account.display_name
                        else
                            account.username
                    ]
                ]
            , br [] []
            , text <| "@" ++ account.acct
            ]
        , followButton currentUser relationship account
        ]


accountCounterLink : String -> Int -> (Account -> Msg) -> Account -> Html Msg
accountCounterLink label count tagger account =
    a
        [ href ""
        , class "col-md-4"
        , onClickWithPreventAndStop <| tagger account
        ]
        [ text label
        , br [] []
        , text <| toString count
        ]


accountView : CurrentUser -> Account -> CurrentUserRelation -> Html Msg -> Html Msg
accountView currentUser account relationship panelContent =
    let
        { statuses_count, following_count, followers_count } =
            account
    in
        div [ class "col-md-3 column" ]
            [ div [ class "panel panel-default" ]
                [ Common.closeablePanelheading "account" "user" "Account" CloseAccount
                , div [ id "account", class "timeline" ]
                    [ div
                        [ class "account-detail"
                        , style [ ( "background-image", "url('" ++ account.header ++ "')" ) ]
                        ]
                        [ div [ class "opacity-layer" ]
                            [ followButton currentUser relationship account
                            , img [ src account.avatar ] []
                            , span [ class "account-display-name" ] [ text account.display_name ]
                            , span [ class "account-username" ] [ text ("@" ++ account.username) ]
                            , span [ class "account-note" ] (formatContent account.note [])
                            ]
                        ]
                    , div [ class "row account-infos" ]
                        [ accountCounterLink "Statuses" statuses_count ViewAccountStatuses account
                        , accountCounterLink "Following" following_count ViewAccountFollowing account
                        , accountCounterLink "Followers" followers_count ViewAccountFollowers account
                        ]
                    , panelContent
                    ]
                ]
            ]


accountTimelineView : CurrentUser -> List Status -> CurrentUserRelation -> Account -> Html Msg
accountTimelineView currentUser statuses relationship account =
    let
        keyedEntry status =
            ( toString status.id
            , li [ class "list-group-item status" ]
                [ lazy2 statusView "account" status ]
            )
    in
        accountView currentUser account relationship <|
            Keyed.ul [ class "list-group" ] <|
                List.map keyedEntry statuses


accountFollowView :
    CurrentUser
    -> List Account
    -> List Relationship
    -> CurrentUserRelation
    -> Account
    -> Html Msg
accountFollowView currentUser accounts relationships relationship account =
    let
        keyedEntry account =
            ( toString account.id
            , li [ class "list-group-item status" ]
                [ followView
                    currentUser
                    (find (\r -> r.id == account.id) relationships)
                    account
                ]
            )
    in
        accountView currentUser account relationship <|
            Keyed.ul [ class "list-group" ] <|
                List.map keyedEntry accounts


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
