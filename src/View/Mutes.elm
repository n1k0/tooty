module View.Mutes exposing (mutesView)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Keyed as Keyed
import Mastodon.Helper exposing (..)
import Mastodon.Model exposing (..)
import Types exposing (..)
import View.Common as Common
import View.Formatter exposing (getDisplayNameForAccount)
import View.Timeline exposing (contextualTimelineMenu, topScrollableColumn)


type alias CurrentUser =
    Maybe Account


muteView : CurrentUser -> Account -> Html Msg
muteView currentUser account =
    let
        -- currentUser / entryClass
        ( _, entryClass ) =
            case currentUser of
                Just user ->
                    if sameAccount account user then
                        ( True, "active" )

                    else
                        ( False, "" )

                Nothing ->
                    ( False, "" )
    in
    li [ class <| "list-group-item status " ++ entryClass ]
        [ div [ class "follow-entry" ]
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
            , button
                [ class "btn btn-default btn-mute btn-primary"
                , title "Unmute"
                , onClick <| Unmute account
                ]
                [ Common.icon "volume-up" ]
            ]
        ]


mutesView : Model -> Html Msg
mutesView { currentUser, mutes, location } =
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
            [ Maybe.withDefault "" location.fragment |> contextualTimelineMenu
            , if not mutes.loading && List.length mutes.entries == 0 then
                p [ class "empty-timeline-text" ] [ text "Nobody's muted yet." ]

              else
                Keyed.ul [ id "mutes-timeline", class "list-group timeline" ] <|
                    (entries ++ [ ( "load-more", Common.loadMoreBtn mutes ) ])
            ]
