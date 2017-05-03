module View.Account
    exposing
        ( accountFollowView
        , accountTimelineView
        , accountView
        )

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Keyed as Keyed
import Html.Lazy as Lazy
import List.Extra exposing (find)
import Mastodon.Helper
import Mastodon.Model exposing (..)
import Types exposing (..)
import View.Common as Common
import View.Events exposing (..)
import View.Status exposing (statusView)
import View.Formatter exposing (formatContent)


type alias CurrentUser =
    Account


type alias CurrentUserRelation =
    Maybe Relationship


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


accountTimelineView : CurrentUser -> List Status -> CurrentUserRelation -> Account -> Html Msg
accountTimelineView currentUser statuses relationship account =
    let
        keyedEntry status =
            ( toString status.id
            , li [ class "list-group-item status" ]
                [ Lazy.lazy2 statusView "account" status ]
            )
    in
        accountView currentUser account relationship <|
            Keyed.ul [ class "list-group" ] <|
                List.map keyedEntry statuses


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
                            , Common.accountAvatarExternalLink account
                            , span [ class "account-display-name" ] [ text account.display_name ]
                            , span [ class "account-username" ] [ Common.accountExternalLink account ]
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
