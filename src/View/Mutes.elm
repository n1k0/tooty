module View.Mutes exposing (mutesView)

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
                , button
                    [ class "btn btn-default btn-mute btn-primary"
                    , title "Unmute"
                    , onClick <| Unmute account
                    ]
                    [ Common.icon "volume-up" ]
                ]
            ]


mutesView : Model -> Html Msg
mutesView { currentUser, currentView, mutes, location } =
    let
        keyedEntry account =
            ( account.id
            , muteView currentUser account
            )

        entries =
            List.map keyedEntry mutes.entries
    in
        topScrollableColumn ( "Mutes", "volume-off", mutes.id ) <|
            div []
                [ contextualTimelineMenu location.hash
                , if (not mutes.loading && List.length mutes.entries == 0) then
                    p [ class "empty-timeline-text" ] [ text "Nobody's muted yet." ]
                  else
                    Keyed.ul [ id "mutes-timeline", class "list-group timeline" ] <|
                        (entries ++ [ ( "load-more", Common.loadMoreBtn mutes ) ])
                ]
