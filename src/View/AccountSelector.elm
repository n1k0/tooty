module View.AccountSelector exposing (accountSelectorView)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Mastodon.Helper exposing (..)
import Mastodon.Model exposing (..)
import String.Extra exposing (replace)
import Types exposing (..)
import View.Auth exposing (authForm)
import View.Common exposing (..)
import View.Timeline exposing (contextualTimelineMenu)


type alias CurrentUser =
    Maybe Account


accountIdentityView : CurrentUser -> Client -> Html Msg
accountIdentityView currentUser client =
    case client.account of
        Just account ->
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
                li [ class <| "list-group-item account-selector-item " ++ entryClass ]
                    [ accountAvatar "" account
                    , span []
                        [ strong []
                            [ text <|
                                if account.display_name /= "" then
                                    account.display_name
                                else
                                    account.username
                            ]
                        , br [] []
                        , account.url
                            |> replace "https://" "@"
                            |> replace "/@" "@"
                            |> text
                        ]
                    , button
                        [ class "btn btn-danger"
                        , onClick <|
                            AskConfirm
                                """
                                Are you sure you want to unregister this account
                                with Tooty? Note that you'll probably want to
                                revoke the application in the official Web client
                                on the related instance.
                                """
                                (LogoutClient client)
                                NoOp
                        ]
                        [ text "Logout" ]
                    , if isCurrentUser then
                        text ""
                      else
                        button
                            [ class "btn btn-primary"
                            , onClick <| SwitchClient client
                            ]
                            [ text "Use" ]
                    ]

        Nothing ->
            text ""


accountSelectorView : Model -> Html Msg
accountSelectorView model =
    div [ class "col-md-3 column" ]
        [ div [ class "panel panel-default" ]
            [ div [] [ div [ class "panel-heading" ] [ icon "user", text "Accounts" ] ]
            , contextualTimelineMenu model.location.hash
            , ul [ class "list-group " ] <|
                List.map (accountIdentityView model.currentUser) model.clients
            , div [ class "panel-body" ]
                [ h3 [] [ text "Add an account" ]
                , authForm model
                ]
            ]
        ]
