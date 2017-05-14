module View.Timeline
    exposing
        ( contextualTimelineView
        , contextualTimelineMenu
        , homeTimelineView
        )

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Keyed as Keyed
import Html.Lazy as Lazy
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


timelineView : CurrentUser -> Timeline Status -> Html Msg
timelineView currentUser timeline =
    let
        keyedEntry status =
            ( toString id, statusEntryView timeline.id "" currentUser status )

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


contextualTimelineMenu : CurrentView -> Html Msg
contextualTimelineMenu currentView =
    let
        btnView tooltip iconName view =
            button
                [ class <|
                    "btn "
                        ++ (if currentView == view then
                                "btn-primary active"
                            else
                                "btn-default"
                           )
                , onClick <| SetView view
                , Html.Attributes.title tooltip
                ]
                [ Common.icon iconName ]
    in
        Common.justifiedButtonGroup "column-menu"
            [ btnView "Local timeline" "th-large" LocalTimelineView
            , btnView "Global timeline" "globe" GlobalTimelineView
            , btnView "Favorites" "star" FavoriteTimelineView
            , btnView "Accounts" "user" AccountSelectorView
            ]


contextualTimelineView : CurrentView -> String -> String -> CurrentUser -> Timeline Status -> Html Msg
contextualTimelineView currentView title iconName currentUser timeline =
    div []
        [ contextualTimelineMenu currentView
        , timelineView currentUser timeline
        ]
        |> Lazy.lazy2 topScrollableColumn ( title, iconName, timeline.id )
