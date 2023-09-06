module View.Draft exposing (draftView)

import EmojiPicker
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Lazy as Lazy
import Json.Decode as Decode
import Json.Encode as Encode
import Mastodon.Model exposing (..)
import Menu
import Types exposing (..)
import Util
import View.Common as Common
import View.Events exposing (..)
import View.Formatter exposing (formatContent)
import View.Status exposing (statusView)


type alias CurrentUser =
    Account


type alias Visibilities =
    { slug : String
    , name : String
    , description : String
    , icon : String
    }


visibilities : List Visibilities
visibilities =
    [ { slug = "direct", name = "Mentioned", description = "Visible to mentioned users only", icon = "envelope" }
    , { slug = "private", name = "Followers", description = "Visible to followers only", icon = "lock" }
    , { slug = "unlisted", name = "Unlisted", description = "Do not show in public timelines", icon = "eye-close" }
    , { slug = "public", name = "Public", description = "Visible in public timelines", icon = "globe" }
    ]


viewAutocompleteMenu : Draft -> Html Msg
viewAutocompleteMenu draft =
    div [ class "autocomplete-menu" ]
        [ Html.map (DraftEvent << SetAutoState)
            (Menu.view viewConfig
                draft.autoMaxResults
                draft.autoState
                (Util.acceptableAccounts draft.autoQuery draft.autoAccounts)
            )
        ]


viewConfig : Menu.ViewConfig Mastodon.Model.Account
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
    Menu.viewConfig
        { toId = .id
        , ul = [ class "list-group autocomplete-list" ]
        , li = customizedLi
        }


currentUserView : Maybe CurrentUser -> Html Msg
currentUserView currentUser =
    case currentUser of
        Just user ->
            div [ class "current-user" ]
                [ Common.accountAvatarLink False user
                , div [ class "username" ]
                    [ Common.accountLink False user
                    , span []
                        [ text " ("
                        , a [ href "#accounts" ] [ text "switch account" ]
                        , text ")"
                        ]
                    ]
                , p [ class "status-text" ] <| formatContent user.note []
                ]

        Nothing ->
            text ""


draftReplyToView : Draft -> Html Msg
draftReplyToView draft =
    case draft.type_ of
        InReplyTo status ->
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

        Editing status _ _ ->
            div [ class "in-reply-to" ]
                [ p []
                    [ strong []
                        [ text "Editing this toot ("
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

        _ ->
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
            (\{ slug, name, description, icon } ->
                a
                    [ href ""
                    , class <| btnClass slug
                    , onClickWithPreventAndStop <| DraftEvent (UpdateVisibility slug)
                    , title description
                    ]
                    [ Common.icon icon, span [] [ text name ] ]
            )
        |> Common.justifiedButtonGroup "draft-visibilities"


draftView : Model -> Html Msg
draftView ({ draft, currentUser, ctrlPressed } as model) =
    let
        autoMenu =
            if draft.showAutoMenu then
                viewAutocompleteMenu model.draft

            else
                text ""

        ( hasSpoiler, charCount ) =
            case draft.spoilerText of
                Just spoilerText ->
                    ( True, String.length spoilerText + draft.statusLength )

                Nothing ->
                    ( False, draft.statusLength )

        limitExceeded =
            charCount > 500

        picker =
            Html.map (DraftEvent << EmojiMsg) <| EmojiPicker.view model.draft.emojiModel
    in
    div [ class "panel panel-default draft" ]
        [ div [ class "panel-heading" ]
            [ Common.icon "envelope"
            , text <|
                case draft.type_ of
                    InReplyTo _ ->
                        "Post a reply"

                    Editing _ _ _ ->
                        "Edit a message"

                    _ ->
                        "Post a message"
            ]
        , div [ class "panel-body timeline", style "overflow" "visible" ]
            [ currentUserView currentUser
            , draftReplyToView draft
            , Html.form [ class "form", onSubmit SubmitDraft ]
                [ if hasSpoiler then
                    div [ class "form-group" ]
                        [ label [ for "spoiler" ] [ text "Content Warning (visible part)" ]
                        , textarea
                            [ id "spoiler"
                            , class "form-control"
                            , rows 4
                            , placeholder "This text will always be visible."
                            , onInput <| DraftEvent << UpdateSpoiler
                            , required True
                            , value <| Maybe.withDefault "" draft.spoilerText
                            ]
                            []
                        ]

                  else
                    text ""
                , visibilitySelector draft
                , div [ class "form-group status-field" ]
                    [ let
                        dec =
                            Decode.map
                                (\code ->
                                    if code == 38 || code == 40 then
                                        Ok NoOp

                                    else if code == 27 then
                                        Ok <| DraftEvent CloseAutocomplete

                                    else if ctrlPressed && code == 13 then
                                        Ok SubmitDraft

                                    else
                                        Err "not handling that key"
                                )
                                keyCode
                                |> Decode.andThen fromResult

                        fromResult : Result String a -> Decode.Decoder { message : a, preventDefault : Bool, stopPropagation : Bool }
                        fromResult result =
                            case result of
                                Ok val ->
                                    Decode.succeed
                                        { message = val
                                        , preventDefault = draft.showAutoMenu
                                        , stopPropagation = False
                                        }

                                Err reason ->
                                    Decode.fail reason
                      in
                      textarea
                        [ id "status"
                        , class "form-control"
                        , rows 7
                        , placeholder <|
                            if hasSpoiler then
                                "This text will be hidden by default, as you have enabled a Content Warning."

                            else
                                "Once upon a time..."
                        , required True
                        , onInputInformation <| DraftEvent << UpdateInputInformation
                        , onClickInformation <| DraftEvent << UpdateInputInformation
                        , property "defaultValue" (Encode.string draft.status)
                        , Html.Events.custom "keydown" dec
                        ]
                        []
                    , autoMenu
                    ]
                , draftAttachments draft.attachments
                , div [ class "draft-actions" ]
                    [ div [ class "draft-actions-btns" ]
                        [ Common.justifiedButtonGroup ""
                            [ button
                                [ type_ "button"
                                , class "btn btn-default btn-clear"
                                , title "Clear this draft"
                                , onClick (DraftEvent ClearDraft)
                                ]
                                [ Common.icon "trash" ]
                            , button
                                [ type_ "button"
                                , class <|
                                    "btn btn-default btn-cw "
                                        ++ (if hasSpoiler then
                                                "btn-primary active"

                                            else
                                                ""
                                           )
                                , title "Add a Content Warning"
                                , onClick <| DraftEvent (ToggleSpoiler (not hasSpoiler))
                                ]
                                [ text "CW" ]
                            , button
                                [ type_ "button"
                                , class <|
                                    "btn btn-default btn-nsfw "
                                        ++ (if draft.sensitive then
                                                "btn-primary active"

                                            else
                                                ""
                                           )
                                , title "Mark this post as Not Safe For Work (sensitive content)"
                                , onClick <| DraftEvent (UpdateSensitive (not draft.sensitive))
                                ]
                                [ text "NSFW" ]
                            , fileUploadField draft
                            , button
                                [ type_ "button"
                                , class <|
                                    "btn btn-default btn-nsfw "
                                , title "Open the emoji picker"
                                , onClick <| DraftEvent (EmojiMsg EmojiPicker.Toggle)
                                ]
                                [ text "😀" ]
                            , picker
                            ]
                        ]
                    , if limitExceeded then
                        div
                            [ class "draft-actions-charcount text-center exceed" ]
                            [ text <| String.fromInt (500 - charCount) ]

                      else
                        div
                            [ class "draft-actions-charcount text-center" ]
                            [ text <| String.fromInt charCount ]
                    , button
                        [ type_ "submit"
                        , class "draft-actions-submit btn btn-warning btn-toot"
                        , disabled limitExceeded
                        ]
                        [ text "Toot" ]
                    ]
                ]
            ]
        ]


draftAttachments : List Attachment -> Html Msg
draftAttachments attachments =
    let
        attachmentPreview attachment =
            li
                [ class "draft-attachment-entry"
                , style "background" ("url(" ++ attachment.preview_url ++ ") center center / cover no-repeat")
                ]
                [ a
                    [ href ""
                    , onClickWithPreventAndStop <| DraftEvent (RemoveMedia attachment.id)
                    ]
                    [ text "×" ]
                ]
    in
    div [ class "draft-attachments-field" ]
        [ if List.length attachments > 0 then
            ul [ class "draft-attachments" ] <|
                List.map attachmentPreview attachments

          else
            text ""
        ]


fileUploadField : Draft -> Html Msg
fileUploadField draft =
    if draft.mediaUploading then
        button [ class "btn btn-default btn-loading", disabled True ]
            [ Common.icon "time" ]

    else if List.length draft.attachments < 4 then
        label [ class "btn btn-default draft-attachment-input-label" ]
            [ input
                [ type_ "file"
                , id "draft-attachment"
                , on "change" (Decode.succeed <| DraftEvent (UploadMedia "draft-attachment"))
                ]
                []
            , text ""
            ]

    else
        text ""
