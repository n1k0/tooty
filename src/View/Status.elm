module View.Status exposing
    ( statusActionsView
    , statusEntryView
    , statusView
    )

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Keyed as Keyed
import Html.Lazy as Lazy
import Mastodon.Helper exposing (extractStatusId)
import Mastodon.Model exposing (..)
import Types exposing (..)
import View.Common as Common
import View.Events exposing (..)
import View.Formatter exposing (formatContent)


type alias CurrentUser =
    Account


attachmentPreview : String -> Maybe Bool -> List Attachment -> Attachment -> Html Msg
attachmentPreview context sensitive attachments ({ url, preview_url } as attachment) =
    --@TODO: manage other attachment types like audio
    case preview_url of
        Just p_url ->
            let
                attId =
                    "att" ++ attachment.id ++ context

                media =
                    a
                        [ href url
                        ]
                        [ img
                            [ class "attachment-image"
                            , src <| p_url
                            , alt <|
                                case attachment.description of
                                    Just description ->
                                        description

                                    Nothing ->
                                        ""
                            , onClickWithPreventAndStop <|
                                ViewerEvent (OpenViewer attachments attachment)
                            ]
                            []
                        ]
            in
            li [ class "attachment-entry" ] <|
                if Maybe.withDefault False sensitive then
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

        Nothing ->
            em [] [ text <| "Attachement type " ++ attachment.type_ ++ " not implemented." ]


attachmentListView : String -> Status -> Html Msg
attachmentListView context { media_attachments, sensitive } =
    let
        keyedEntry attachments attachment =
            ( attachment.id
            , attachmentPreview context sensitive attachments attachment
            )
    in
    case media_attachments of
        [] ->
            text ""

        attachments ->
            Keyed.ul [ class "attachments" ] <|
                List.map (keyedEntry attachments) attachments


statusActionsView : Status -> CurrentUser -> Bool -> Html Msg
statusActionsView status currentUser showApp =
    let
        sourceStatus =
            Mastodon.Helper.extractReblog status

        baseBtnClasses =
            "btn btn-sm btn-default"

        ( reblogClasses, reblogEvent ) =
            case sourceStatus.reblogged of
                Just True ->
                    ( baseBtnClasses ++ " reblogged", UnreblogStatus sourceStatus )

                _ ->
                    ( baseBtnClasses, ReblogStatus sourceStatus )

        ( favClasses, favEvent ) =
            case sourceStatus.favourited of
                Just True ->
                    ( baseBtnClasses ++ " favourited", RemoveFavorite sourceStatus )

                _ ->
                    ( baseBtnClasses, AddFavorite sourceStatus )
    in
    div [ class "btn-group actions" ]
        [ button
            [ class baseBtnClasses
            , onClickWithPreventAndStop <| DraftEvent (UpdateReplyTo sourceStatus)
            , title "Reply"
            ]
            [ Common.icon "share-alt" ]
        , if sourceStatus.visibility == "private" then
            span [ class <| reblogClasses ++ " disabled" ]
                [ span [ title "Private" ] [ Common.icon "lock" ] ]

          else if sourceStatus.visibility == "direct" then
            span [ class <| reblogClasses ++ " disabled" ]
                [ span [ title "Direct" ] [ Common.icon "envelope" ] ]

          else
            button
                [ class reblogClasses, onClickWithPreventAndStop reblogEvent, title "Retoot" ]
                [ Common.icon "fire", text (String.fromInt sourceStatus.reblogs_count) ]
        , button
            [ class favClasses, onClickWithPreventAndStop favEvent, title "Add to favorites" ]
            [ Common.icon "star", text (String.fromInt sourceStatus.favourites_count) ]
        , if Mastodon.Helper.sameAccount sourceStatus.account currentUser then
            button
                [ class <| baseBtnClasses ++ " btn-delete"
                , href ""
                , title "Delete toot"
                , onClickWithPreventAndStop <|
                    AskConfirm "Are you sure you want to delete this toot?" (DeleteStatus sourceStatus.id) NoOp
                ]
                [ Common.icon "trash" ]

          else
            text ""
        , a
            [ class baseBtnClasses
            , href (Maybe.withDefault "#" sourceStatus.url)
            , target "_blank"
            , title (sourceStatus.edited_at |> Maybe.map (\edited_at -> "Edited - " ++ Common.formatDate edited_at) |> Maybe.withDefault "")
            ]
            [ Common.icon "time", text <| Common.formatDate sourceStatus.created_at ]
        , case sourceStatus.edited_at of
            Just edited_at ->
                em
                    [ class baseBtnClasses
                    , title <| "Edited - " ++ Common.formatDate edited_at
                    ]
                    [ text "Edited *" ]

            _ ->
                text ""
        , if showApp then
            Common.appLink (baseBtnClasses ++ " applink") sourceStatus.application

          else
            text ""
        , if Mastodon.Helper.sameAccount sourceStatus.account currentUser then
            button
                [ class <| baseBtnClasses ++ " btn-edit"
                , href ""
                , onClickWithPreventAndStop <| DraftEvent (EditStatus sourceStatus)
                , title "Edit status"
                ]
                [ Common.icon "edit" ]

          else
            text ""
        , case sourceStatus.url of
            Just url ->
                a
                    [ class <| baseBtnClasses
                    , href url
                    , target "_blank"
                    , title "Open original toot"
                    ]
                    [ Common.icon "link" ]

            _ ->
                text ""
        ]


statusContentView : String -> Status -> Html Msg
statusContentView context status =
    case status.spoiler_text of
        "" ->
            div [ class "status-text" ]
                [ div [ onClickWithStop <| OpenThread status ] <| formatContent status.content status.mentions
                , attachmentListView context status
                ]

        _ ->
            -- Note: Spoilers are dealt with using pure CSS.
            let
                statusId =
                    "spoiler" ++ extractStatusId status.id ++ context
            in
            div [ class "status-text spoiled" ]
                [ div
                    [ class "spoiler"
                    , onClickWithStop <| OpenThread status
                    ]
                    [ text status.spoiler_text ]
                , input [ type_ "checkbox", id statusId, class "spoiler-toggler" ] []
                , label [ for statusId ] [ text "Reveal content" ]
                , div [ class "spoiled-content" ]
                    [ div [] <| formatContent status.content status.mentions
                    , attachmentListView context status
                    ]
                ]


statusEntryView : String -> String -> CurrentUser -> Status -> Html Msg
statusEntryView context className currentUser status =
    let
        nsfwClass =
            case status.sensitive of
                Just True ->
                    "nsfw"

                _ ->
                    ""

        liAttributes =
            (class <| "list-group-item " ++ className ++ " " ++ nsfwClass)
                :: (if context == "thread" then
                        [ id <| "thread-status-" ++ extractStatusId status.id ]

                    else
                        []
                   )
    in
    li liAttributes
        [ Lazy.lazy2 statusView context status
        , Lazy.lazy3 statusActionsView status currentUser (className == "thread-target")
        ]


statusView : String -> Status -> Html Msg
statusView context ({ account, reblog } as status) =
    let
        accountLinkAttributes =
            [ href <| "#account/" ++ account.id ]
    in
    case reblog of
        Just (Reblog r) ->
            div [ class "reblog" ]
                [ p [ class "status-info" ]
                    [ Common.icon "fire"
                    , a (accountLinkAttributes ++ [ class "reblogger" ])
                        [ text <| " @" ++ account.username ]
                    , text " boosted"
                    ]
                , Lazy.lazy2 statusView context r
                ]

        Nothing ->
            div [ class "status" ]
                [ Common.accountAvatarLink False account
                , div [ class "username" ]
                    [ a accountLinkAttributes
                        [ text account.display_name
                        , span [ class "acct" ] [ text <| " @" ++ account.acct ]
                        ]
                    ]
                , Lazy.lazy2 statusContentView context status
                ]
