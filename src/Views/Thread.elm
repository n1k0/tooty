module Views.Thread exposing (threadView)

import Views.Common as Common
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Keyed as Keyed
import Mastodon.Model exposing (..)
import Types exposing (..)
import Views.Status exposing (statusEntryView)


type alias CurrentUser =
    Account


threadView : CurrentUser -> Thread -> Html Msg
threadView currentUser thread =
    let
        statuses =
            List.concat
                [ thread.context.ancestors
                , [ thread.status ]
                , thread.context.descendants
                ]

        threadEntry status =
            statusEntryView "thread"
                (if status == thread.status then
                    "thread-target"
                 else
                    ""
                )
                currentUser
                status

        keyedEntry status =
            ( toString status.id, threadEntry status )
    in
        div [ class "col-md-3 column" ]
            [ div [ class "panel panel-default" ]
                [ Common.closeablePanelheading "thread" "list" "Thread" CloseThread
                , Keyed.ul [ id "thread", class "list-group timeline" ] <|
                    List.map keyedEntry statuses
                ]
            ]
