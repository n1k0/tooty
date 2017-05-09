module View.Draft exposing (draftView)

import Autocomplete
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Lazy as Lazy
import Json.Encode as Encode
import Json.Decode as Decode
import Mastodon.Model exposing (..)
import Types exposing (..)
import Util
import View.Common as Common
import View.Events exposing (..)
import View.Formatter exposing (formatContent)
import View.Status exposing (statusView)


type alias CurrentUser =
    Account


visibilities : List ( String, String, String, String )
visibilities =
    [ ( "direct", "Mentioned", "Visible to mentioned users only", "envelope" )
    , ( "private", "Followers", "Visible to followers only", "lock" )
    , ( "unlisted", "Unlisted", "Do not show in public timelines", "eye-close" )
    , ( "public", "Public", "Visible in public timelines", "globe" )
    ]


viewAutocompleteMenu : Draft -> Html Msg
viewAutocompleteMenu draft =
    div [ class "autocomplete-menu" ]
        [ Html.map (DraftEvent << SetAutoState)
            (Autocomplete.view viewConfig
                draft.autoMaxResults
                draft.autoState
                (Util.acceptableAccounts draft.autoQuery draft.autoAccounts)
            )
        ]


viewConfig : Autocomplete.ViewConfig Mastodon.Model.Account
viewConfig =
    let
        customizedLi keySelected mouseSelected account =
            { attributes =
                [ classList
                    [ ( "list-group-item autocomplete-item", True )
                    , ( "active", keySelected || mouseSelected )
                    ]
                ]
            , children =
                [ img [ src account.avatar ] []
                , strong []
                    [ text <|
                        if account.display_name /= "" then
                            account.display_name
                        else
                            account.acct
                    ]
                , span [] [ text <| " @" ++ account.acct ]
                ]
            }
    in
        Autocomplete.viewConfig
            { toId = .id >> toString
            , ul = [ class "list-group autocomplete-list" ]
            , li = customizedLi
            }


currentUserView : Maybe CurrentUser -> Html Msg
currentUserView currentUser =
    case currentUser of
        Just currentUser ->
            div [ class "current-user" ]
                [ Common.accountAvatarLink False currentUser
                , div [ class "username" ]
                    [ Common.accountLink False currentUser
                    , span []
                        [ text " ("
                        , a [ href "", onClickWithPreventAndStop <| OpenAccountSelector ]
                            [ text "switch account" ]
                        , text ")"
                        ]
                    ]
                , p [ class "status-text" ] <| formatContent currentUser.note []
                ]

        Nothing ->
            text ""


draftReplyToView : Draft -> Html Msg
draftReplyToView draft =
    case draft.inReplyTo of
        Just status ->
            div [ class "in-reply-to" ]
                [ p []
                    [ strong []
                        [ text "In reply to this toot ("
                        , a
                            [ href ""
                            , onClickWithPreventAndStop <| DraftEvent ClearDraft
                            ]
                            [ Common.icon "remove" ]
                        , text ")"
                        ]
                    ]
                , div [ class "well" ] [ Lazy.lazy2 statusView "draft" status ]
                ]

        Nothing ->
            text ""


visibilitySelector : Draft -> Html Msg
visibilitySelector { visibility } =
    let
        btnClass v =
            if v == visibility then
                "btn btn-sm btn-vis btn-primary active"
            else
                "btn btn-sm btn-vis btn-default"
    in
        visibilities
            |> List.map
                (\( v, d, t, i ) ->
                    a
                        [ href ""
                        , class <| btnClass v
                        , onClickWithPreventAndStop <| DraftEvent (UpdateVisibility v)
                        , title t
                        ]
                        [ Common.icon i, span [] [ text d ] ]
                )
            |> Common.justifiedButtonGroup "draft-visibilities"


draftView : Model -> Html Msg
draftView ({ draft, currentUser } as model) =
    let
        autoMenu =
            if draft.showAutoMenu then
                viewAutocompleteMenu model.draft
            else
                text ""

        ( hasSpoiler, charCount ) =
            case draft.spoilerText of
                Just spoilerText ->
                    ( True, (String.length spoilerText) + draft.statusLength )

                Nothing ->
                    ( False, draft.statusLength )

        limitExceeded =
            charCount > 500
    in
        div [ class "panel panel-default draft" ]
            [ div [ class "panel-heading" ]
                [ Common.icon "envelope"
                , text <|
                    if draft.inReplyTo /= Nothing then
                        "Post a reply"
                    else
                        "Post a message"
                ]
            , div [ class "panel-body" ]
                [ currentUserView currentUser
                , draftReplyToView draft
                , Html.form [ class "form", onSubmit SubmitDraft ]
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
                                , value <| Maybe.withDefault "" draft.spoilerText
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
                        , let
                            dec =
                                (Decode.map
                                    (\code ->
                                        if code == 38 || code == 40 then
                                            Ok NoOp
                                        else if code == 27 then
                                            Ok <| DraftEvent CloseAutocomplete
                                        else
                                            Err "not handling that key"
                                    )
                                    keyCode
                                )
                                    |> Decode.andThen fromResult

                            options =
                                { preventDefault = draft.showAutoMenu
                                , stopPropagation = False
                                }

                            fromResult : Result String a -> Decode.Decoder a
                            fromResult result =
                                case result of
                                    Ok val ->
                                        Decode.succeed val

                                    Err reason ->
                                        Decode.fail reason
                          in
                            textarea
                                [ id "status"
                                , class "form-control"
                                , rows 8
                                , placeholder <|
                                    if hasSpoiler then
                                        "This text will be hidden by default, as you have enabled a spoiler."
                                    else
                                        "Once upon a time..."
                                , required True
                                , onInputInformation <| DraftEvent << UpdateInputInformation
                                , onClickInformation <| DraftEvent << UpdateInputInformation
                                , property "defaultValue" (Encode.string draft.status)
                                , onWithOptions "keydown" options dec
                                ]
                                []
                        , autoMenu
                        ]
                    , visibilitySelector draft
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
                    , Common.justifiedButtonGroup "draft-actions"
                        [ button
                            [ type_ "button"
                            , class "btn btn-default"
                            , onClick (DraftEvent ClearDraft)
                            ]
                            [ text "Clear" ]
                        , div
                            [ class <|
                                if limitExceeded then
                                    "btn btn-danger charcount active"
                                else
                                    "btn btn-default charcount active"
                            ]
                            [ text <| toString charCount ]
                        , button
                            [ type_ "submit"
                            , class "btn btn-warning"
                            , disabled limitExceeded
                            ]
                            [ text "Toot!" ]
                        ]
                    ]
                ]
            ]
