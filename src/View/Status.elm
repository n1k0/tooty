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
    let
        attId =
            "att" ++ attachment.id ++ context

        media =
            a
                [ class "attachment-image"
                , href url
                , onClickWithPreventAndStop <|
                    ViewerEvent (OpenViewer attachments attachment)
                , style "background" ("url(" ++ preview_url ++ ") center center / cover no-repeat")
                ]
                []
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
            case status.reblogged of
                Just True ->
                    ( baseBtnClasses ++ " reblogged", UnreblogStatus sourceStatus )

                _ ->
                    ( baseBtnClasses, ReblogStatus sourceStatus )

        ( favClasses, favEvent ) =
            case status.favourited of
                Just True ->
                    ( baseBtnClasses ++ " favourited", RemoveFavorite sourceStatus )

                _ ->
                    ( baseBtnClasses, AddFavorite sourceStatus )
    in
    div [ class "btn-group actions" ]
        [ a
            [ class baseBtnClasses
            , onClickWithPreventAndStop <| DraftEvent (UpdateReplyTo status)
            ]
            [ Common.icon "share-alt" ]
        , if status.visibility == "private" then
            span [ class <| reblogClasses ++ " disabled" ]
                [ span [ title "Private" ] [ Common.icon "lock" ] ]

          else if status.visibility == "direct" then
            span [ class <| reblogClasses ++ " disabled" ]
                [ span [ title "Direct" ] [ Common.icon "envelope" ] ]

          else
            a
                [ class reblogClasses, onClickWithPreventAndStop reblogEvent ]
                [ Common.icon "fire", text (String.fromInt sourceStatus.reblogs_count) ]
        , a
            [ class favClasses, onClickWithPreventAndStop favEvent ]
            [ Common.icon "star", text (String.fromInt sourceStatus.favourites_count) ]
        , if Mastodon.Helper.sameAccount sourceStatus.account currentUser then
            a
                [ class <| baseBtnClasses ++ " btn-delete"
                , href ""
                , onClickWithPreventAndStop <|
                    AskConfirm "Are you sure you want to delete this toot?" (DeleteStatus sourceStatus.id) NoOp
                ]
                [ Common.icon "trash" ]

          else
            text ""
        , a
            [ class baseBtnClasses, href (Maybe.withDefault "#" status.url), target "_blank" ]
            [ Common.icon "time", text <| Common.formatDate status.created_at ]
        , if showApp then
            Common.appLink (baseBtnClasses ++ " applink") status.application

          else
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

        spoiler ->
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
            [ class <| "list-group-item " ++ className ++ " " ++ nsfwClass ]
                ++ (if context == "thread" then
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
statusView context ({ account, content, media_attachments, reblog, mentions } as status) =
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
                        , span [ class "acct" ] [ text <| " @" ++ account.username ]
                        ]
                    ]
                , Lazy.lazy2 statusContentView context status
                ]
