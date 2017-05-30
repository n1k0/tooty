module View.Search exposing (searchView)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Mastodon.Model exposing (..)
import Types exposing (..)
import View.Common as Common
import View.Formatter exposing (formatContent)
import View.Timeline exposing (contextualTimelineMenu)


accountListView : List Account -> Html Msg
accountListView accounts =
    let
        profileView account =
            li [ class "list-group-item status follow-profile" ]
                [ Common.accountAvatarLink False account
                , div [ class "username" ] [ Common.accountLink False account ]
                , formatContent account.note []
                    |> div
                        [ class "status-text"
                        , onClick <| Navigate ("#account/" ++ (toString account.id))
                        ]
                ]
    in
        ul [ class "list-group notification follow" ]
            [ div [ class "" ] <| List.map profileView (List.take 3 accounts)
            ]


searchResultsView : SearchResults -> Html Msg
searchResultsView results =
    let
        accountList =
            case results.accounts of
                [] ->
                    p [ class "panel-body" ] [ text "No accounts found." ]

                accounts ->
                    accountListView accounts

        hashtagList =
            case results.hashtags of
                [] ->
                    p [ class "panel-body" ] [ text "No hashtags found." ]

                hashtags ->
                    hashtags
                        |> List.map (\h -> a [ class "list-group-item", href <| "#hashtag/" ++ h ] [ text <| "#" ++ h ])
                        |> div [ class "list-group" ]
    in
        div [ class "timeline" ]
            [ div [ class "panel-heading" ] [ text "Accounts" ]
            , accountList
            , div [ class "panel-heading" ] [ text "Hashtags" ]
            , hashtagList
            ]


searchView : Model -> Html Msg
searchView ({ search } as model) =
    div [ class "col-md-3 column" ]
        [ div [ class "panel panel-default" ]
            [ div [ class "panel-heading" ] [ Common.icon "search", text " Search" ]
            , contextualTimelineMenu model.location.hash
            , div [ class "panel-body search-form" ]
                [ Html.form [ class "search", onSubmit <| SearchEvent SubmitSearch ]
                    [ div [ class "form-group" ]
                        [ div [ class "input-group" ]
                            [ input
                                [ type_ "search"
                                , class "form-control"
                                , placeholder "Search"
                                , onInput <| SearchEvent << UpdateSearch
                                , value search.term
                                ]
                                []
                            , span [ class "input-group-btn" ]
                                [ button [ type_ "submit", class "btn btn-default" ]
                                    [ Common.icon "search" ]
                                ]
                            ]
                        ]
                    ]
                ]
            , case search.results of
                Nothing ->
                    text ""

                Just results ->
                    searchResultsView results
            ]
        ]
