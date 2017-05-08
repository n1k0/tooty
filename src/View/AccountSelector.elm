module View.AccountSelector exposing (accountSelectorView)

import Html exposing (..)
import Html.Attributes exposing (..)
import Mastodon.Model exposing (..)
import Types exposing (..)
import View.Common exposing (..)


accountIdentityView : Client -> Html Msg
accountIdentityView client =
    case client.account of
        Just account ->
            li [ class "list-group-item" ] [ text <| account.username ]

        Nothing ->
            li [ class "list-group-item" ] [ text "unknown" ]


accountSelectorView : Model -> Html Msg
accountSelectorView model =
    div [ class "col-md-3 column" ]
        [ div [ class "panel panel-default" ]
            [ closeablePanelheading "account-selector" "user" "Account selector" CloseAccountSelector
            , ul [ class "list-group" ] <|
                List.map accountIdentityView model.clients
            ]
        ]
