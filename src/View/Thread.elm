module View.Thread exposing (threadView)

import View.Common as Common
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Keyed as Keyed
import Mastodon.Helper exposing (extractStatusId)
import Mastodon.Model exposing (..)
import Types exposing (..)
import View.Status exposing (statusEntryView)


type alias CurrentUser =
    Account


threadStatuses : CurrentUser -> Thread -> Html Msg
threadStatuses currentUser thread =
    case ( thread.status, thread.context ) of
        ( Just threadStatus, Just context ) ->
            let
                statuses =
                    List.concat
                        [ context.ancestors
                        , [ threadStatus ]
                        , context.descendants
                        ]

                threadEntry status =
                    statusEntryView "thread"
                        (if status == threadStatus then
                            "thread-target"
                         else
                            ""
                        )
                        currentUser
                        status

                keyedEntry status =
                    ( extractStatusId status.id, threadEntry status )
            in
                Keyed.ul [ id "thread", class "list-group timeline" ] <|
                    List.map keyedEntry statuses

        _ ->
            text ""


threadView : CurrentUser -> Thread -> Html Msg
threadView currentUser thread =
    div [ class "col-md-3 column" ]
        [ div [ class "panel panel-default" ]
            [ Common.closeablePanelheading "thread" "list" "Thread"
            , threadStatuses currentUser thread
            ]
        ]
