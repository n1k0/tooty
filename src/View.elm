module View exposing (view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import HtmlParser
import HtmlParser.Util exposing (toVirtualDom)
import Mastodon
import Model exposing (Model, Msg(..))


errorView : String -> Html Msg
errorView error =
    div [ class "alert alert-danger" ] [ text error ]


errorsListView : Model -> Html Msg
errorsListView model =
    case model.errors of
        [] ->
            text ""

        errors ->
            div [] <| List.map errorView model.errors


statusView : Mastodon.Status -> Html Msg
statusView status =
    case status.reblog of
        Just (Mastodon.Reblog reblog) ->
            div [ class "reblog" ]
                [ p []
                    [ a [ href status.account.url ] [ text <| "@" ++ status.account.username ]
                    , text " reblogged"
                    ]
                , statusView reblog
                ]

        Nothing ->
            div [ class "status" ]
                [ img [ class "avatar", src status.account.avatar ] []
                , div [ class "username" ]
                    [ a [ href status.account.url ] [ text status.account.username ]
                    ]
                , div [ class "status-text" ]
                    (HtmlParser.parse status.content |> toVirtualDom)
                ]


timelineView : List Mastodon.Status -> String -> Html Msg
timelineView statuses label =
    div [ class "col-sm-4" ]
        [ div [ class "panel panel-default" ]
            [ div [ class "panel-heading" ] [ text label ]
            , ul [ class "list-group" ] <|
                List.map
                    (\s ->
                        li [ class "list-group-item status" ]
                            [ statusView s ]
                    )
                    statuses
            ]
        ]


homepageView : Model -> Html Msg
homepageView model =
    div [ class "row" ]
        [ timelineView model.userTimeline "Home timeline"
        , timelineView model.localTimeline "Local timeline"
        , timelineView model.publicTimeline "Public timeline"
        ]


authView : Model -> Html Msg
authView model =
    div [ class "col-md-4 col-md-offset-4" ]
        [ div [ class "panel panel-default" ]
            [ div [ class "panel-heading" ] [ text "Authenticate" ]
            , div [ class "panel-body" ]
                [ Html.form [ class "form", onSubmit Register ]
                    [ div [ class "form-group" ]
                        [ label [ for "server" ] [ text "Mastodon server root URL" ]
                        , input
                            [ type_ "url"
                            , class "form-control"
                            , id "server"
                            , required True
                            , placeholder "https://mastodon.social"
                            , value model.server
                            , pattern "https://.+"
                            , onInput ServerChange
                            ]
                            []
                        , p [ class "help-block" ]
                            [ text "You'll be redirected to that server to authenticate yourself. We don't have access to your password." ]
                        ]
                    , button [ class "btn btn-primary", type_ "submit" ]
                        [ text "Sign into Tooty" ]
                    ]
                ]
            ]
        ]


view : Model -> Html Msg
view model =
    div [ class "container-fluid" ]
        [ h1 [] [ text "tooty" ]
        , errorsListView model
        , case model.client of
            Just client ->
                homepageView model

            Nothing ->
                authView model
        ]
