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
import View.Formatter exposing (formatContentWithEmojis, getDisplayNameForAccount)
import View.Status exposing (statusEntryView)


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
            customButton =
                case relationship of
                    Nothing ->
                        { event = NoOp
                        , btnClasses = "btn btn-default btn-follow btn-disabled"
                        , iconName = "question-sign"
                        , tooltip = "Unknown relationship"
                        }

                    Just r ->
                        if r.following then
                            { event = UnfollowAccount account
                            , btnClasses = "btn btn-default btn-follow btn-primary"
                            , iconName = "eye-close"
                            , tooltip = "Unfollow"
                            }

                        else
                            { event = FollowAccount account
                            , btnClasses = "btn btn-default btn-follow"
                            , iconName = "eye-open"
                            , tooltip = "Follow"
                            }
        in
        button [ class customButton.btnClasses, title customButton.tooltip, onClick customButton.event ]
            [ Common.icon customButton.iconName ]


followView : CurrentUser -> Maybe Relationship -> Account -> Html Msg
followView currentUser relationship account =
    div [ class "follow-entry" ]
        [ Common.accountAvatarLink False Nothing account
        , div [ class "userinfo" ]
            [ strong []
                [ a
                    [ href <| "#account/" ++ account.id ]
                    (if account.display_name /= "" then
                        getDisplayNameForAccount account

                     else
                        [ text account.username ]
                    )
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
            customButton =
                case relationship of
                    Nothing ->
                        { event = NoOp
                        , btnClasses = "btn btn-default btn-mute btn-disabled"
                        , iconName = "question-sign"
                        , tooltip = "Unknown relationship"
                        }

                    Just r ->
                        if r.muting then
                            { event = Unmute account
                            , btnClasses = "btn btn-default btn-mute btn-primary"
                            , iconName = "volume-up"
                            , tooltip = "Unmute"
                            }

                        else
                            { event = Mute account
                            , btnClasses = "btn btn-default btn-mute"
                            , iconName = "volume-off"
                            , tooltip = "Mute"
                            }
        in
        button [ class customButton.btnClasses, title customButton.tooltip, onClick customButton.event ]
            [ Common.icon customButton.iconName ]


blockButton : CurrentUser -> CurrentUserRelation -> Account -> Html Msg
blockButton currentUser relationship account =
    if Mastodon.Helper.sameAccount account currentUser then
        text ""

    else
        let
            customButton =
                case relationship of
                    Nothing ->
                        { event = NoOp
                        , btnClasses = "btn btn-default btn-block btn-disabled"
                        , iconName = "question-sign"
                        , tooltip = "Unknown relationship"
                        }

                    Just r ->
                        if r.blocking then
                            { event = Unblock account
                            , btnClasses = "btn btn-default btn-block btn-primary"
                            , iconName = "ok-circle"
                            , tooltip = "Unblock"
                            }

                        else
                            { event = Block account
                            , btnClasses = "btn btn-default btn-block"
                            , iconName = "ban-circle"
                            , tooltip = "Block"
                            }
        in
        button [ class customButton.btnClasses, title customButton.tooltip, onClick customButton.event ]
            [ Common.icon customButton.iconName ]


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
        Just _ ->
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
        Just _ ->
            Keyed.ul [ id accountInfo.timeline.id, class "list-group" ] <|
                (entries ++ [ ( "load-more", Common.loadMoreBtn accountInfo.timeline ) ])

        Nothing ->
            text ""


counterLink : String -> String -> Int -> Bool -> Html Msg
counterLink href_ label count active =
    a
        [ href href_
        , class <|
            "btn col-md-4"
                ++ (if active then
                        " btn-default"

                    else
                        ""
                   )
        ]
        [ span [ class "count" ] [ text <| String.fromInt count ], text " ", text label ]


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

                            --, style "background-image" ("url('" ++ account.header ++ "')")
                            ]
                            [ div
                                [ class
                                    ("account-header-image"
                                        -- It looks like mastodon always returns a header image even if none was setup
                                        -- and it's called missing.png
                                        ++ (if String.contains "missing.png" account.header then
                                                " missing-header"

                                            else
                                                ""
                                           )
                                    )
                                ]
                                [ img [ src account.header ] [] ]
                            , div [ class "account-header-bar" ]
                                [ Common.accountAvatarLink True (Just [ "avatar-detailed" ]) account
                                , div [ class "account-header-actions" ]
                                    [ followButton currentUser accountInfo.relationship account
                                    , muteButton currentUser accountInfo.relationship account
                                    , blockButton currentUser accountInfo.relationship account
                                    ]
                                ]
                            , div [ class "account-header-content" ]
                                [ div [ class "account-display-name" ]
                                    [ div [] (getDisplayNameForAccount account)
                                    , div [ class "relationship" ]
                                        [ case accountInfo.relationship of
                                            Just relationship ->
                                                span []
                                                    [ if relationship.followed_by && relationship.following then
                                                        span [ class "badge followed-by" ] [ text "Following each other" ]

                                                      else if relationship.followed_by then
                                                        span [ class "badge followed-by" ] [ text "Follows you" ]

                                                      else if relationship.following then
                                                        span [ class "badge followed-by" ] [ text "Following" ]

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
                                    ]
                                , div [ class "account-username" ]
                                    [ Common.accountLink True account
                                    , span [ class "joined-date" ] [ text "joined on ", text <| Common.formatDate account.created_at ]
                                    ]
                                , span [ class "account-note" ] (formatContentWithEmojis account.note [] account.emojis)
                                , if List.isEmpty account.fields then
                                    text ""

                                  else
                                    div [ class "account-fields" ]
                                        (List.map
                                            (\field ->
                                                div []
                                                    (formatContentWithEmojis (String.toUpper field.name) [] account.emojis
                                                        ++ text " | "
                                                        :: formatContentWithEmojis field.value [] account.emojis
                                                        ++ (case field.verified_at of
                                                                Just verified_at ->
                                                                    [ span [ class "check-mark", title ("Verified at " ++ Common.formatDate verified_at) ] [ Common.icon "ok" ] ]

                                                                Nothing ->
                                                                    [ text "" ]
                                                           )
                                                    )
                                            )
                                            account.fields
                                        )
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
