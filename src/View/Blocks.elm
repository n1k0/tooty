module View.Blocks exposing (blocksView)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Keyed as Keyed
import Mastodon.Helper exposing (..)
import Mastodon.Model exposing (..)
import Types exposing (..)
import View.Common as Common
import View.Events exposing (..)
import View.Timeline exposing (contextualTimelineMenu)


type alias CurrentUser =
    Maybe Account


blockView : CurrentUser -> Account -> Html Msg
blockView currentUser account =
    let
        ( isCurrentUser, entryClass ) =
            case currentUser of
                Just currentUser ->
                    if sameAccount account currentUser then
                        ( True, "active" )
                    else
                        ( False, "" )

                Nothing ->
                    ( False, "" )
    in
        li [ class <| "list-group-item status " ++ entryClass ]
            [ div [ class "follow-entry" ]
                [ Common.accountAvatarLink False account
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
                , button
                    [ class "btn btn-default btn-block btn-primary"
                    , title "Unblock"
                    , onClick <| Unblock account
                    ]
                    [ Common.icon "ok-circle" ]
                ]
            ]


blocksView : Model -> Html Msg
blocksView model =
    let
        keyedEntry account =
            ( toString account.id
            , blockView model.currentUser account
            )

        entries =
            List.map keyedEntry model.blocks.entries
    in
        div [ class "col-md-3 column" ]
            [ div [ class "panel panel-default" ]
                [ Common.closeablePanelheading "blocks" "ban-circle" "Blocked accounts" (SetView LocalTimelineView)
                , contextualTimelineMenu model.currentView
                , if List.length model.blocks.entries == 0 then
                    p [ class "empty-timeline-text" ] [ text "Nobody's muted here." ]
                  else
                    Keyed.ul [ class "list-group" ] <|
                        (entries ++ [ ( "load-more", Common.loadMoreBtn model.blocks ) ])
                ]
            ]
