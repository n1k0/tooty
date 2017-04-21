module View exposing (view)

import Dict
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import HtmlParser
import HtmlParser.Util exposing (toVirtualDom)
import Mastodon
import Model exposing (Model, DraftMsg(..), Msg(..))


visibilities : Dict.Dict String String
visibilities =
    Dict.fromList
        [ ( "public", "post to public timelines" )
        , ( "unlisted", "do not show in public timelines" )
        , ( "private", "post to followers only" )
        , ( "direct", "post to mentioned users only" )
        ]


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


attachmentPreview : Maybe Bool -> Mastodon.Attachment -> Html Msg
attachmentPreview sensitive ({ url, preview_url } as attachment) =
    let
        nsfw =
            case sensitive of
                Just sensitive ->
                    sensitive

                Nothing ->
                    False

        attId =
            "att" ++ (toString attachment.id)

        media =
            a
                [ class "attachment-image"
                , href url
                , target "_blank"
                , style
                    [ ( "background"
                      , "url(" ++ preview_url ++ ") center center / cover no-repeat"
                      )
                    ]
                ]
                []
    in
        li [ class "attachment-entry" ] <|
            if nsfw then
                [ input [ type_ "radio", id attId ] []
                , label [ for attId ]
                    [ text "Sensitive content"
                    , br [] []
                    , br [] []
                    , text "click to show image"
                    ]
                , media
                ]
            else
                [ media ]


attachmentListView : Mastodon.Status -> Html Msg
attachmentListView { media_attachments, sensitive } =
    case media_attachments of
        [] ->
            text ""

        attachments ->
            ul [ class "attachments" ] <| List.map (attachmentPreview sensitive) attachments


statusContentView : Mastodon.Status -> Html Msg
statusContentView status =
    case status.spoiler_text of
        "" ->
            div [ class "status-text" ]
                [ div [] <| formatContent status.content
                , attachmentListView status
                ]

        spoiler ->
            -- Note: Spoilers are dealt with using pure CSS.
            let
                statusId =
                    "spoiler" ++ (toString status.id)
            in
                div [ class "status-text spoiled" ]
                    [ div [ class "spoiler" ] <| formatContent status.spoiler_text
                    , input [ type_ "checkbox", id statusId, class "spoiler-toggler" ] []
                    , label [ for statusId ] [ text "Reveal content" ]
                    , div [ class "spoiled-content" ]
                        [ div [] <| formatContent status.content
                        , attachmentListView status
                        ]
                    ]


statusView : Mastodon.Status -> Html Msg
statusView ({ account, media_attachments, content, reblog } as status) =
    case reblog of
        Just (Mastodon.Reblog reblog) ->
            div [ class "reblog" ]
                [ p []
                    [ icon "fire"
                    , a [ href account.url, class "reblogger" ]
                        [ text <| " " ++ account.username ]
                    , text " boosted"
                    ]
                , statusView reblog
                ]

        Nothing ->
            div [ class "status" ]
                [ img [ class "avatar", src account.avatar ] []
                , div [ class "username" ]
                    [ a [ href account.url ]
                        [ text account.display_name
                        , span [ class "acct" ] [ text <| " @" ++ account.username ]
                        ]
                    ]
                , statusContentView status
                ]


statusEntryView : Mastodon.Status -> Html Msg
statusEntryView status =
    let
        nsfwClass =
            case status.sensitive of
                Just True ->
                    "nsfw"

                _ ->
                    ""
    in
        li [ class <| "list-group-item " ++ nsfwClass ]
            [ statusView status ]


timelineView : List Mastodon.Status -> String -> String -> Html Msg
timelineView statuses label iconName =
    div [ class "col-md-3" ]
        [ div [ class "panel panel-default" ]
            [ div [ class "panel-heading" ]
                [ icon iconName
                , text label
                ]
            , ul [ class "list-group" ] <|
                List.map statusEntryView statuses
            ]
        ]


draftView : Model -> Html Msg
draftView { draft } =
    let
        hasSpoiler =
            draft.spoiler_text /= Nothing

        visibilityOptionView ( visibility, description ) =
            option [ value visibility ]
                [ text <| visibility ++ ": " ++ description ]
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
                                        "This text will be hidden by default, as you have enabled a spoiler."
                                    else
                                        "Once upon a time..."
                                , onInput <| DraftEvent << UpdateStatus
                                , required True
                                , value draft.status
                                ]
                                []
                            ]
                        , div [ class "form-group" ]
                            [ label [ for "visibility" ] [ text "Visibility" ]
                            , select
                                [ id "visibility"
                                , class "form-control"
                                , onInput <| DraftEvent << UpdateVisibility
                                , required True
                                , value draft.visibility
                                ]
                              <|
                                List.map visibilityOptionView <|
                                    Dict.toList visibilities
                            ]
                        , div [ class "form-group checkbox" ]
                            [ label []
                                [ input
                                    [ type_ "checkbox"
                                    , onCheck <| DraftEvent << UpdateSensitive
                                    , checked draft.sensitive
                                    ]
                                    []
                                , text " This post is NSFW"
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
                            [ text <|
                                "You'll be redirected to that server to authenticate yourself. "
                                    ++ "We don't have access to your password."
                            ]
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
