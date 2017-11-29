module View.Account exposing (accountView)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Keyed as Keyed
import Html.Lazy as Lazy
import List.Extra exposing (find)
import Mastodon.Helper exposing (extractStatusId)
import Mastodon.Model exposing (..)
import Types exposing (..)
import View.Common as Common
import View.Status exposing (statusEntryView)
import View.Formatter exposing (formatContent)


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
                        , "btn btn-default btn-follow btn-disabled"
                        , "question-sign"
                        , "Unknown relationship"
                        )

                    Just relationship ->
                        if relationship.following then
                            ( UnfollowAccount account
                            , "btn btn-default btn-follow btn-primary"
                            , "eye-close"
                            , "Unfollow"
                            )
                        else
                            ( FollowAccount account
                            , "btn btn-default btn-follow"
                            , "eye-open"
                            , "Follow"
                            )
        in
            button [ class btnClasses, title tooltip, onClick followEvent ]
                [ Common.icon iconName ]


followView : CurrentUser -> Maybe Relationship -> Account -> Html Msg
followView currentUser relationship account =
    div [ class "follow-entry" ]
        [ Common.accountAvatarLink False account
        , div [ class "userinfo" ]
            [ strong []
                [ a
                    [ href <| "#account/" ++ account.id ]
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
        , muteButton currentUser relationship account
        , followButton currentUser relationship account
        ]


muteButton : CurrentUser -> CurrentUserRelation -> Account -> Html Msg
muteButton currentUser relationship account =
    if Mastodon.Helper.sameAccount account currentUser then
        text ""
    else
        let
            ( muteEvent, btnClasses, iconName, tooltip ) =
                case relationship of
                    Nothing ->
                        ( NoOp
                        , "btn btn-default btn-mute btn-disabled"
                        , "question-sign"
                        , "Unknown relationship"
                        )

                    Just relationship ->
                        if relationship.muting then
                            ( Unmute account
                            , "btn btn-default btn-mute btn-primary"
                            , "volume-up"
                            , "Unmute"
                            )
                        else
                            ( Mute account
                            , "btn btn-default btn-mute"
                            , "volume-off"
                            , "Mute"
                            )
        in
            button [ class btnClasses, title tooltip, onClick muteEvent ]
                [ Common.icon iconName ]


blockButton : CurrentUser -> CurrentUserRelation -> Account -> Html Msg
blockButton currentUser relationship account =
    if Mastodon.Helper.sameAccount account currentUser then
        text ""
    else
        let
            ( blockEvent, btnClasses, iconName, tooltip ) =
                case relationship of
                    Nothing ->
                        ( NoOp
                        , "btn btn-default btn-block btn-disabled"
                        , "question-sign"
                        , "Unknown relationship"
                        )

                    Just relationship ->
                        if relationship.blocking then
                            ( Unblock account
                            , "btn btn-default btn-block btn-primary"
                            , "ok-circle"
                            , "Unblock"
                            )
                        else
                            ( Block account
                            , "btn btn-default btn-block"
                            , "ban-circle"
                            , "Block"
                            )
        in
            button [ class btnClasses, title tooltip, onClick blockEvent ]
                [ Common.icon iconName ]


accountFollowView : CurrentAccountView -> CurrentUser -> AccountInfo -> Html Msg
accountFollowView view currentUser accountInfo =
    let
        keyedEntry account =
            ( account.id
            , li [ class "list-group-item status" ]
                [ followView
                    currentUser
                    (find (\r -> r.id == account.id) accountInfo.relationships)
                    account
                ]
            )

        timeline =
            if view == AccountFollowersView then
                accountInfo.followers
            else
                accountInfo.following

        entries =
            List.map keyedEntry timeline.entries
    in
        case accountInfo.account of
            Just account ->
                Keyed.ul [ class "list-group" ] <|
                    (entries ++ [ ( "load-more", Common.loadMoreBtn timeline ) ])

            Nothing ->
                text ""


accountTimelineView : CurrentUser -> AccountInfo -> Html Msg
accountTimelineView currentUser accountInfo =
    let
        keyedEntry status =
            ( extractStatusId status.id
            , Lazy.lazy (statusEntryView "account" "status" currentUser) status
            )

        entries =
            List.map keyedEntry accountInfo.timeline.entries
    in
        case accountInfo.account of
            Just account ->
                Keyed.ul [ id accountInfo.timeline.id, class "list-group" ] <|
                    (entries ++ [ ( "load-more", Common.loadMoreBtn accountInfo.timeline ) ])

            Nothing ->
                text ""


counterLink : String -> String -> Int -> Bool -> Html Msg
counterLink href_ label count active =
    a
        [ href href_
        , class <|
            "col-md-4"
                ++ (if active then
                        " active"
                    else
                        ""
                   )
        ]
        [ text label
        , br [] []
        , text <| toString count
        ]


counterLinks : CurrentAccountView -> Account -> Html Msg
counterLinks subView account =
    let
        { statuses_count, following_count, followers_count } =
            account
    in
        div [ class "row account-infos" ]
            [ counterLink
                ("#account/" ++ account.id)
                "Statuses"
                statuses_count
                (subView == AccountStatusesView)
            , counterLink
                ("#account/" ++ account.id ++ "/following")
                "Following"
                following_count
                (subView == AccountFollowingView)
            , counterLink
                ("#account/" ++ account.id ++ "/followers")
                "Followers"
                followers_count
                (subView == AccountFollowersView)
            ]


accountView : CurrentAccountView -> CurrentUser -> AccountInfo -> Html Msg
accountView subView currentUser accountInfo =
    case accountInfo.account of
        Nothing ->
            text ""

        Just account ->
            div [ class "col-md-3 column" ]
                [ div [ class "panel panel-default" ]
                    [ Common.closeablePanelheading "account" "user" "Account"
                    , div [ id "account", class "timeline" ]
                        [ div
                            [ class "account-detail"
                            , style [ ( "background-image", "url('" ++ account.header ++ "')" ) ]
                            ]
                            [ div [ class "opacity-layer" ]
                                [ followButton currentUser accountInfo.relationship account
                                , muteButton currentUser accountInfo.relationship account
                                , blockButton currentUser accountInfo.relationship account
                                , Common.accountAvatarLink True account
                                , span [ class "account-display-name" ] [ text account.display_name ]
                                , span [ class "account-username" ]
                                    [ Common.accountLink True account
                                    , case accountInfo.relationship of
                                        Just relationship ->
                                            span []
                                                [ if relationship.followed_by then
                                                    span [ class "badge followed-by" ] [ text "Follows you" ]
                                                  else
                                                    text ""
                                                , text " "
                                                , if relationship.muting then
                                                    span [ class "badge muting" ] [ text "Muted" ]
                                                  else
                                                    text ""
                                                , text " "
                                                , if relationship.blocking then
                                                    span [ class "badge blocking" ] [ text "Blocked" ]
                                                  else
                                                    text ""
                                                ]

                                        Nothing ->
                                            text ""
                                    ]
                                , span [ class "account-note" ] (formatContent account.note [])
                                ]
                            ]
                        , counterLinks subView account
                        , case subView of
                            AccountStatusesView ->
                                accountTimelineView currentUser accountInfo

                            _ ->
                                accountFollowView subView currentUser accountInfo
                        ]
                    ]
                ]
