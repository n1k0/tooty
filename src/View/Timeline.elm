module View.Timeline
    exposing
        ( contextualTimelineView
        , contextualTimelineMenu
        , homeTimelineView
        , hashtagTimelineView
        , topScrollableColumn
        )

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Keyed as Keyed
import Html.Lazy as Lazy
import Mastodon.Helper exposing (extractStatusId)
import Mastodon.Model exposing (..)
import Types exposing (..)
import View.Common as Common
import View.Events exposing (..)
import View.Status exposing (statusView, statusActionsView, statusEntryView)


type alias CurrentUser =
    Account


type alias CurrentUserRelation =
    Maybe Relationship


topScrollableColumn : ( String, String, String ) -> Html Msg -> Html Msg
topScrollableColumn ( label, iconName, timelineId ) content =
    div [ class "col-md-3 column" ]
        [ div [ class "panel panel-default" ]
            [ a
                [ href "", onClickWithPreventAndStop <| ScrollColumn ScrollTop timelineId ]
                [ div [ class "panel-heading" ] [ Common.icon iconName, text label ] ]
            , content
            ]
        ]


closeableColumn : ( String, String, String ) -> Html Msg -> Html Msg
closeableColumn ( label, iconName, timelineId ) content =
    div [ class "col-md-3 column" ]
        [ div [ class "panel panel-default" ]
            [ Common.closeablePanelheading timelineId iconName label
            , content
            ]
        ]


timelineView : CurrentUser -> Timeline Status -> Html Msg
timelineView currentUser timeline =
    let
        keyedEntry status =
            ( extractStatusId status.id, statusEntryView timeline.id "" currentUser status )

        entries =
            List.map keyedEntry timeline.entries
    in
        Keyed.ul [ id timeline.id, class "list-group timeline" ] <|
            (entries ++ [ ( "load-more", Common.loadMoreBtn timeline ) ])


homeTimelineView : CurrentUser -> Timeline Status -> Html Msg
homeTimelineView currentUser timeline =
    Lazy.lazy2 topScrollableColumn
        ( "Home timeline"
        , "home"
        , timeline.id
        )
        (timelineView currentUser timeline)


hashtagTimelineView : String -> CurrentUser -> Timeline Status -> Html Msg
hashtagTimelineView hashtag currentUser timeline =
    Lazy.lazy2 closeableColumn
        ( ("#" ++ hashtag)
        , "tags"
        , timeline.id
        )
        (timelineView currentUser timeline)


contextualTimelineMenu : String -> Html Msg
contextualTimelineMenu hash =
    let
        btnView href_ iconName tooltip =
            a
                [ href href_
                , class <|
                    "btn "
                        ++ (if hash == href_ || (hash == "" && href_ == "#") then
                                "btn-primary active"
                            else
                                "btn-default"
                           )
                , title tooltip
                ]
                [ Common.icon iconName ]
    in
        Common.justifiedButtonGroup "column-menu"
            [ btnView "#" "th-large" "Local timeline"
            , btnView "#global" "globe" "Global timeline"
            , btnView "#search" "search" "Search"
            , btnView "#favorites" "star" "Favorites"
            , btnView "#blocks" "ban-circle" "Blocks"
            , btnView "#mutes" "volume-off" "Mutes"
            , btnView "#accounts" "user" "Accounts"
            ]


contextualTimelineView : String -> String -> String -> CurrentUser -> Timeline Status -> Html Msg
contextualTimelineView hash title iconName currentUser timeline =
    div []
        [ contextualTimelineMenu hash
        , timelineView currentUser timeline
        ]
        |> Lazy.lazy2 topScrollableColumn ( title, iconName, timeline.id )
