module View exposing (view)

import Json.Decode as Decode
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import HtmlParser
import HtmlParser.Util exposing (toVirtualDom)
import Mastodon
import Model exposing (Model, DraftMsg(..), Msg(..))


-- Custom Events


onClickWithPreventAndStop : msg -> Attribute msg
onClickWithPreventAndStop msg =
    onWithOptions
        "click"
        { preventDefault = True, stopPropagation = True }
        (Decode.succeed msg)



-- Views


replace : String -> String -> String -> String
replace from to str =
    String.split from str |> String.join to


formatContent : String -> List (Html msg)
formatContent content =
    content
        |> replace "&apos;" "'"
        |> replace " ?" "&nbsp;?"
        |> replace " !" "&nbsp;!"
        |> replace " :" "&nbsp;:"
        |> HtmlParser.parse
        |> toVirtualDom


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


icon : String -> Html Msg
icon name =
    i [ class <| "glyphicon glyphicon-" ++ name ] []


statusView : Mastodon.Status -> Html Msg
statusView { account, content, reblog } =
    let
        accountLinkAttributes =
            [ href account.url
              -- When clicking on a status, we should not let the browser
              -- redirect to a new page. That's why we're preventing the default
              -- behavior here
            , onClickWithPreventAndStop (OnLoadUserAccount account.id)
            ]
    in
        case reblog of
            Just (Mastodon.Reblog reblog) ->
                div [ class "reblog" ]
                    [ p []
                        [ icon "fire"
                        , a (accountLinkAttributes ++ [ class "reblogger" ])
                            [ text <| " " ++ account.username ]
                        , text " boosted"
                        ]
                    , statusView reblog
                    ]

            Nothing ->
                div [ class "status" ]
                    [ img [ class "avatar", src account.avatar ] []
                    , div [ class "username" ]
                        [ a accountLinkAttributes
                            [ text account.display_name
                            , span [ class "acct" ] [ text <| " @" ++ account.username ]
                            ]
                        ]
                    , div [ class "status-text" ] <| formatContent content
                    ]


timelineView : List Mastodon.Status -> String -> String -> Html Msg
timelineView statuses label iconName =
    div [ class "col-md-3" ]
        [ div [ class "panel panel-default" ]
            [ div [ class "panel-heading" ]
                [ icon iconName
                , text label
                ]
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
draftView { draft } =
    let
        hasSpoiler =
            case draft.spoiler_text of
                Nothing ->
                    False

                Just _ ->
                    True
    in
        div [ class "col-md-3" ]
            [ div [ class "panel panel-default" ]
                [ div [ class "panel-heading" ] [ icon "envelope", text "Post a message" ]
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
                                [ label [ for "spoiler" ] [ text "Visible part" ]
                                , textarea
                                    [ id "spoiler"
                                    , class "form-control"
                                    , rows 5
                                    , placeholder "This text will always be visible."
                                    , onInput <| DraftEvent << UpdateSpoiler
                                    , required True
                                    , value <| Maybe.withDefault "" draft.spoiler_text
                                    ]
                                    []
                                ]
                          else
                            text ""
                        , div [ class "form-group" ]
                            [ label [ for "status" ]
                                [ text <|
                                    if hasSpoiler then
                                        "Hidden part"
                                    else
                                        "Status"
                                ]
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
                                , value draft.status
                                ]
                                []
                            ]
                        , div [ class "form-group checkbox" ]
                            [ label []
                                [ input
                                    [ type_ "checkbox"
                                    , onCheck <| DraftEvent << UpdateSensitive
                                    , checked draft.sensitive
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
        , timelineView model.userTimeline "Home timeline" "home"
        , timelineView model.localTimeline "Local timeline" "th-large"
        , timelineView model.publicTimeline "Public timeline" "globe"
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
