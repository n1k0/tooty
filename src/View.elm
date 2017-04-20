module View exposing (view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import HtmlParser
import HtmlParser.Util exposing (toVirtualDom)
import Mastodon
import Model exposing (Model, DraftMsg(..), Msg(..))


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
    div [ class "col-sm-3" ]
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


draftView : Model -> Html Msg
draftView model =
    let
        hasSpoiler =
            case model.draft.spoiler_text of
                Nothing ->
                    False

                Just _ ->
                    True
    in
        div [ class "col-md-3" ]
            [ div [ class "panel panel-default" ]
                [ div [ class "panel-heading" ] [ text "Post a message" ]
                , div [ class "panel-body" ]
                    [ Html.form [ class "form", onSubmit SubmitDraft ]
                        [ div [ class "form-group checkbox" ]
                            [ label []
                                [ input
                                    [ type_ "checkbox"
                                    , onCheck <| DraftEvent << ToggleSpoiler
                                    , checked hasSpoiler
                                    ]
                                    []
                                , text " Add a spoiler"
                                ]
                            ]
                        , if hasSpoiler then
                            div [ class "form-group" ]
                                [ label [ for "spoiler" ] [ text "Spoiler" ]
                                , textarea
                                    [ id "spoiler"
                                    , class "form-control"
                                    , rows 5
                                    , placeholder "This text will always be visible."
                                    , onInput <| DraftEvent << UpdateSpoiler
                                    , required True
                                    ]
                                    []
                                ]
                          else
                            text ""
                        , div [ class "form-group" ]
                            [ label [ for "status" ] [ text "Status" ]
                            , textarea
                                [ id "status"
                                , class "form-control"
                                , rows 8
                                , placeholder <|
                                    if hasSpoiler then
                                        "This text with be hidden by default, as you have enabled a spoiler."
                                    else
                                        "Once upon a time..."
                                , onInput <| DraftEvent << UpdateStatus
                                , required True
                                ]
                                []
                            ]
                        , div [ class "form-group checkbox" ]
                            [ label []
                                [ input
                                    [ type_ "checkbox"
                                    , onCheck <| DraftEvent << UpdateSensitive
                                    , checked model.draft.sensitive
                                    ]
                                    []
                                , text " NSFW"
                                ]
                            ]
                        , p [ class "text-right" ]
                            [ button [ class "btn btn-primary" ]
                                [ text "Toot!" ]
                            ]
                        ]
                    ]
                ]
            ]


homepageView : Model -> Html Msg
homepageView model =
    div [ class "row" ]
        [ draftView model
        , timelineView model.userTimeline "Home timeline"
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
