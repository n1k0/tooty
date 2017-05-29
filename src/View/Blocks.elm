module View.Blocks exposing (blocksView)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Keyed as Keyed
import Mastodon.Helper exposing (..)
import Mastodon.Model exposing (..)
import Types exposing (..)
import View.Common as Common
import View.Timeline exposing (contextualTimelineMenu, topScrollableColumn)


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
                            [ href <| "#account/" ++ (toString account.id) ]
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
blocksView { currentUser, currentView, blocks, location } =
    let
        keyedEntry account =
            ( toString account.id
            , blockView currentUser account
            )

        entries =
            List.map keyedEntry blocks.entries
    in
        topScrollableColumn ( "Blocks", "ban-circle", blocks.id ) <|
            div []
                [ contextualTimelineMenu location.hash
                , if (not blocks.loading && List.length blocks.entries == 0) then
                    p [ class "empty-timeline-text" ] [ text "Nobody's blocked yet." ]
                  else
                    Keyed.ul [ id "blocks-timeline", class "list-group timeline" ] <|
                        (entries ++ [ ( "load-more", Common.loadMoreBtn blocks ) ])
                ]
