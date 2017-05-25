module View.Mutes exposing (mutesView)

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


muteView : CurrentUser -> Account -> Html Msg
muteView currentUser account =
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
                    [ class "btn btn-default btn-mute btn-primary"
                    , title "Unmute"
                    , onClick <| Unmute account
                    ]
                    [ Common.icon "volume-up" ]
                ]
            ]


mutesView : Model -> Html Msg
mutesView model =
    let
        keyedEntry account =
            ( toString account.id
            , muteView model.currentUser account
            )

        entries =
            List.map keyedEntry model.mutes.entries
    in
        div [ class "col-md-3 column" ]
            [ div [ class "panel panel-default" ]
                [ Common.closeablePanelheading "mutes" "volume-off" "Muted accounts" (SetView LocalTimelineView)
                , contextualTimelineMenu model.currentView
                , if (not model.mutes.loading && List.length model.mutes.entries == 0) then
                    p [ class "empty-timeline-text" ] [ text "You basically muted nobody yet. You rock." ]
                  else
                    Keyed.ul [ class "list-group" ] <|
                        (entries ++ [ ( "load-more", Common.loadMoreBtn model.mutes ) ])
                ]
            ]
