module View.Status
    exposing
        ( statusView
        , statusActionsView
        , statusEntryView
        )

import Date
import Date.Extra.Config.Config_en_au as DateEn
import Date.Extra.Format as DateFormat
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Keyed as Keyed
import Html.Lazy as Lazy
import Mastodon.Helper
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
        nsfw =
            case sensitive of
                Just sensitive ->
                    sensitive

                Nothing ->
                    False

        attId =
            "att" ++ (toString attachment.id) ++ context

        media =
            a
                [ class "attachment-image"
                , href url
                , onClickWithPreventAndStop <|
                    ViewerEvent (OpenViewer attachments attachment)
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


attachmentListView : String -> Status -> Html Msg
attachmentListView context { media_attachments, sensitive } =
    let
        keyedEntry attachments attachment =
            ( toString attachment.id
            , attachmentPreview context sensitive attachments attachment
            )
    in
        case media_attachments of
            [] ->
                text ""

            attachments ->
                Keyed.ul [ class "attachments" ] <|
                    List.map (keyedEntry attachments) attachments


statusActionsView : Status -> CurrentUser -> Html Msg
statusActionsView status currentUser =
    let
        sourceStatus =
            Mastodon.Helper.extractReblog status

        baseBtnClasses =
            "btn btn-sm btn-default"

        ( reblogClasses, reblogEvent ) =
            case status.reblogged of
                Just True ->
                    ( baseBtnClasses ++ " reblogged", UnreblogStatus sourceStatus.id )

                _ ->
                    ( baseBtnClasses, ReblogStatus sourceStatus.id )

        ( favClasses, favEvent ) =
            case status.favourited of
                Just True ->
                    ( baseBtnClasses ++ " favourited", RemoveFavorite sourceStatus.id )

                _ ->
                    ( baseBtnClasses, AddFavorite sourceStatus.id )

        statusDate =
            Date.fromString status.created_at
                |> Result.withDefault (Date.fromTime 0)

        formatDate =
            text <| DateFormat.format DateEn.config "%m/%d/%Y %H:%M" statusDate
    in
        div [ class "btn-group actions" ]
            [ a
                [ class baseBtnClasses
                , onClickWithPreventAndStop <|
                    DraftEvent (UpdateReplyTo status)
                ]
                [ Common.icon "share-alt" ]
            , a
                [ class reblogClasses
                , onClickWithPreventAndStop reblogEvent
                ]
                [ Common.icon "fire", text (toString sourceStatus.reblogs_count) ]
            , a
                [ class favClasses
                , onClickWithPreventAndStop favEvent
                ]
                [ Common.icon "star", text (toString sourceStatus.favourites_count) ]
            , if Mastodon.Helper.sameAccount sourceStatus.account currentUser then
                a
                    [ class <| baseBtnClasses ++ " btn-delete"
                    , href ""
                    , onClickWithPreventAndStop <| DeleteStatus sourceStatus.id
                    ]
                    [ Common.icon "trash" ]
              else
                text ""
            , a
                [ class baseBtnClasses, href status.url, target "_blank" ]
                [ Common.icon "time", formatDate ]
            ]


statusContentView : String -> Status -> Html Msg
statusContentView context status =
    case status.spoiler_text of
        "" ->
            div [ class "status-text", onClickWithStop <| OpenThread status ]
                [ div [] <| formatContent status.content status.mentions
                , attachmentListView context status
                ]

        spoiler ->
            -- Note: Spoilers are dealt with using pure CSS.
            let
                statusId =
                    "spoiler" ++ (toString status.id) ++ context
            in
                div [ class "status-text spoiled" ]
                    [ div [ class "spoiler" ] [ text status.spoiler_text ]
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
    in
        li [ class <| "list-group-item " ++ className ++ " " ++ nsfwClass ]
            [ Lazy.lazy2 statusView context status
            , Lazy.lazy2 statusActionsView status currentUser
            ]


statusView : String -> Status -> Html Msg
statusView context ({ account, content, media_attachments, reblog, mentions } as status) =
    let
        accountLinkAttributes =
            [ href account.url
            , onClickWithPreventAndStop (LoadAccount account.id)
            ]
    in
        case reblog of
            Just (Reblog reblog) ->
                div [ class "reblog" ]
                    [ p [ class "status-info" ]
                        [ Common.icon "fire"
                        , a (accountLinkAttributes ++ [ class "reblogger" ])
                            [ text <| " @" ++ account.username ]
                        , text " boosted"
                        ]
                    , Lazy.lazy2 statusView context reblog
                    ]

            Nothing ->
                div [ class "status" ]
                    [ Common.accountAvatarLink account
                    , div [ class "username" ]
                        [ a accountLinkAttributes
                            [ text account.display_name
                            , span [ class "acct" ] [ text <| " @" ++ account.username ]
                            ]
                        ]
                    , Lazy.lazy2 statusContentView context status
                    ]
