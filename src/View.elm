module View exposing (view)

import Dict
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import List.Extra exposing (elemIndex, getAt)
import Mastodon.Helper
import Mastodon.Model
import Model exposing (..)
import ViewHelper exposing (..)
import Date
import Date.Extra.Config.Config_en_au as DateEn
import Date.Extra.Format as DateFormat


visibilities : Dict.Dict String String
visibilities =
    Dict.fromList
        [ ( "public", "post to public timelines" )
        , ( "unlisted", "do not show in public timelines" )
        , ( "private", "post to followers only" )
        , ( "direct", "post to mentioned users only" )
        ]


closeablePanelheading : String -> String -> Msg -> Html Msg
closeablePanelheading iconName label onClose =
    div [ class "panel-heading" ]
        [ div [ class "row" ]
            [ div [ class "col-xs-9 heading" ] [ icon iconName, text label ]
            , div [ class "col-xs-3 text-right" ]
                [ a
                    [ href ""
                    , onClickWithPreventAndStop onClose
                    ]
                    [ icon "remove" ]
                ]
            ]
        ]


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


justifiedButtonGroup : List (Html Msg) -> Html Msg
justifiedButtonGroup buttons =
    div [ class "btn-group btn-group-justified" ] <|
        List.map (\b -> div [ class "btn-group" ] [ b ]) buttons


icon : String -> Html Msg
icon name =
    i [ class <| "glyphicon glyphicon-" ++ name ] []


accountLink : Mastodon.Model.Account -> Html Msg
accountLink account =
    a
        [ href account.url
        , onClickWithPreventAndStop (LoadAccount account.id)
        ]
        [ text <| "@" ++ account.username ]


accountAvatarLink : Mastodon.Model.Account -> Html Msg
accountAvatarLink account =
    a
        [ href account.url
        , onClickWithPreventAndStop (LoadAccount account.id)
        , title <| "@" ++ account.username
        ]
        [ img [ class "avatar", src account.avatar ] [] ]


attachmentPreview : String -> Maybe Bool -> List Mastodon.Model.Attachment -> Mastodon.Model.Attachment -> Html Msg
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


attachmentListView : String -> Mastodon.Model.Status -> Html Msg
attachmentListView context { media_attachments, sensitive } =
    case media_attachments of
        [] ->
            text ""

        attachments ->
            ul [ class "attachments" ] <|
                List.map (attachmentPreview context sensitive attachments) attachments


statusContentView : String -> Mastodon.Model.Status -> Html Msg
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


statusView : String -> Mastodon.Model.Status -> Html Msg
statusView context ({ account, content, media_attachments, reblog, mentions } as status) =
    let
        accountLinkAttributes =
            [ href account.url

            -- When clicking on a status, we should not let the browser
            -- redirect to a new page. That's why we're preventing the default
            -- behavior here
            , onClickWithPreventAndStop (LoadAccount account.id)
            ]
    in
        case reblog of
            Just (Mastodon.Model.Reblog reblog) ->
                div [ class "reblog" ]
                    [ p [ class "status-info" ]
                        [ icon "fire"
                        , a (accountLinkAttributes ++ [ class "reblogger" ])
                            [ text <| " @" ++ account.username ]
                        , text " boosted"
                        ]
                    , statusView context reblog
                    ]

            Nothing ->
                div [ class "status" ]
                    [ accountAvatarLink account
                    , div [ class "username" ]
                        [ a accountLinkAttributes
                            [ text account.display_name
                            , span [ class "acct" ] [ text <| " @" ++ account.username ]
                            ]
                        ]
                    , statusContentView context status
                    ]


accountTimelineView : Mastodon.Model.Account -> List Mastodon.Model.Status -> String -> String -> Html Msg
accountTimelineView account statuses label iconName =
    div [ class "col-md-3" ]
        [ div [ class "panel panel-default" ]
            [ closeablePanelheading iconName label ClearOpenedAccount
            , div [ class "account-detail", style [ ( "background-image", "url('" ++ account.header ++ "')" ) ] ]
                [ div [ class "opacity-layer" ]
                    [ img [ src account.avatar ] []
                    , span [ class "account-display-name" ] [ text account.display_name ]
                    , span [ class "account-username" ] [ text ("@" ++ account.username) ]
                    , span [ class "account-note" ] (formatContent account.note [])
                    ]
                ]
            , div [ class "row account-infos" ]
                [ div [ class "col-md-4" ]
                    [ text "Statuses"
                    , br [] []
                    , text <| toString account.statuses_count
                    ]
                , div [ class "col-md-4" ]
                    [ text "Following"
                    , br [] []
                    , text <| toString account.following_count
                    ]
                , div [ class "col-md-4" ]
                    [ text "Followers"
                    , br [] []
                    , text <| toString account.followers_count
                    ]
                ]
            , ul [ class "list-group timeline" ] <|
                List.map
                    (\s ->
                        li [ class "list-group-item status" ]
                            [ statusView "account" s ]
                    )
                    statuses
            ]
        ]


statusActionsView : Mastodon.Model.Status -> Html Msg
statusActionsView status =
    let
        targetStatus =
            Mastodon.Helper.extractReblog status

        baseBtnClasses =
            "btn btn-sm btn-default"

        ( reblogClasses, reblogEvent ) =
            case status.reblogged of
                Just True ->
                    ( baseBtnClasses ++ " reblogged", Unreblog targetStatus.id )

                _ ->
                    ( baseBtnClasses, Reblog targetStatus.id )

        ( favClasses, favEvent ) =
            case status.favourited of
                Just True ->
                    ( baseBtnClasses ++ " favourited", RemoveFavorite targetStatus.id )

                _ ->
                    ( baseBtnClasses, AddFavorite targetStatus.id )

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
                    DraftEvent (UpdateReplyTo targetStatus)
                ]
                [ icon "share-alt" ]
            , a
                [ class reblogClasses
                , onClickWithPreventAndStop reblogEvent
                ]
                [ icon "fire", text (toString status.reblogs_count) ]
            , a
                [ class favClasses
                , onClickWithPreventAndStop favEvent
                ]
                [ icon "star", text (toString status.favourites_count) ]
            , a
                [ class baseBtnClasses
                , href status.url
                , onClickWithPreventAndStop <| OpenThread status
                ]
                [ icon "time", formatDate ]
            ]


statusEntryView : String -> String -> Mastodon.Model.Status -> Html Msg
statusEntryView context className status =
    let
        nsfwClass =
            case status.sensitive of
                Just True ->
                    "nsfw"

                _ ->
                    ""
    in
        li [ class <| "list-group-item " ++ className ++ " " ++ nsfwClass ]
            [ statusView context status
            , statusActionsView status
            ]


timelineView : String -> String -> String -> List Mastodon.Model.Status -> Html Msg
timelineView label iconName context statuses =
    div [ class "col-md-3" ]
        [ div [ class "panel panel-default" ]
            [ a
                [ href "", onClickWithPreventAndStop <| ScrollColumn context ]
                [ div [ class "panel-heading" ] [ icon iconName, text label ] ]
            , ul [ id context, class "list-group timeline" ] <|
                List.map (statusEntryView context "") statuses
            ]
        ]


notificationHeading : List Mastodon.Model.Account -> String -> String -> Html Msg
notificationHeading accounts str iconType =
    div [ class "status-info" ]
        [ div [ class "avatars" ] <| List.map accountAvatarLink accounts
        , p [ class "status-info-text" ] <|
            List.intersperse (text " ")
                [ icon iconType
                , span [] <| List.intersperse (text ", ") (List.map accountLink accounts)
                , text str
                ]
        ]


notificationStatusView : String -> Mastodon.Model.Status -> Mastodon.Model.NotificationAggregate -> Html Msg
notificationStatusView context status { type_, accounts } =
    div [ class <| "notification " ++ type_ ]
        [ case type_ of
            "reblog" ->
                notificationHeading accounts "boosted your toot" "fire"

            "favourite" ->
                notificationHeading accounts "favourited your toot" "star"

            _ ->
                text ""
        , statusView context status
        , statusActionsView status
        ]


notificationFollowView : Mastodon.Model.NotificationAggregate -> Html Msg
notificationFollowView { accounts } =
    let
        profileView account =
            div [ class "status follow-profile" ]
                [ accountAvatarLink account
                , div [ class "username" ] [ accountLink account ]
                , p
                    [ class "status-text"
                    , onClick <| LoadAccount account.id
                    ]
                  <|
                    formatContent account.note []
                ]
    in
        div [ class "notification follow" ]
            [ notificationHeading accounts "started following you" "user"
            , div [ class "" ] <| List.map profileView accounts
            ]


notificationEntryView : Mastodon.Model.NotificationAggregate -> Html Msg
notificationEntryView notification =
    li [ class "list-group-item" ]
        [ case notification.status of
            Just status ->
                notificationStatusView "notification" status notification

            Nothing ->
                notificationFollowView notification
        ]


notificationListView : List Mastodon.Model.NotificationAggregate -> Html Msg
notificationListView notifications =
    div [ class "col-md-3" ]
        [ div [ class "panel panel-default" ]
            [ a
                [ href "", onClickWithPreventAndStop <| ScrollColumn "notifications" ]
                [ div [ class "panel-heading" ] [ icon "bell", text "Notifications" ] ]
            , ul [ id "notifications", class "list-group timeline" ] <|
                List.map notificationEntryView notifications
            ]
        ]


draftReplyToView : Draft -> Html Msg
draftReplyToView draft =
    case draft.in_reply_to of
        Just status ->
            div [ class "in-reply-to" ]
                [ p []
                    [ strong []
                        [ text "In reply to this toot ("
                        , a
                            [ href ""
                            , onClickWithPreventAndStop <| DraftEvent ClearReplyTo
                            ]
                            [ icon "remove" ]
                        , text ")"
                        ]
                    ]
                , div [ class "well" ] [ statusView "draft" status ]
                ]

        Nothing ->
            text ""


draftView : Model -> Html Msg
draftView { draft } =
    let
        hasSpoiler =
            draft.spoiler_text /= Nothing

        visibilityOptionView ( visibility, description ) =
            option [ value visibility ]
                [ text <| visibility ++ ": " ++ description ]
    in
        div [ class "panel panel-default" ]
            [ div [ class "panel-heading" ]
                [ icon "envelope"
                , text <|
                    if draft.in_reply_to /= Nothing then
                        "Post a reply"
                    else
                        "Post a message"
                ]
            , div [ class "panel-body" ]
                [ draftReplyToView draft
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
                    , justifiedButtonGroup
                        [ button
                            [ type_ "button"
                            , class "btn btn-default"
                            , onClick (DraftEvent ClearDraft)
                            ]
                            [ text "Clear" ]
                        , button
                            [ type_ "submit"
                            , class "btn btn-primary"
                            ]
                            [ text "Toot!" ]
                        ]
                    ]
                ]
            ]


threadView : Thread -> Html Msg
threadView thread =
    let
        statuses =
            List.concat
                [ thread.context.ancestors
                , [ thread.status ]
                , thread.context.descendants
                ]

        threadEntry status =
            statusEntryView "thread"
                (if status == thread.status then
                    "thread-target"
                 else
                    ""
                )
                status
    in
        div [ class "col-md-3" ]
            [ div [ class "panel panel-default" ]
                [ closeablePanelheading "list" "Thread" CloseThread
                , ul [ class "list-group timeline" ] <|
                    List.map threadEntry statuses
                ]
            ]


optionsView : Model -> Html Msg
optionsView model =
    div [ class "panel panel-default" ]
        [ div [ class "panel-heading" ] [ icon "cog", text "options" ]
        , div [ class "panel-body" ]
            [ div [ class "checkbox" ]
                [ label []
                    [ input [ type_ "checkbox", onCheck UseGlobalTimeline ] []
                    , text " 4th column renders the global timeline"
                    ]
                ]
            ]
        ]


sidebarView : Model -> Html Msg
sidebarView model =
    div [ class "col-md-3" ]
        [ draftView model
        , optionsView model
        ]


homepageView : Model -> Html Msg
homepageView model =
    div [ class "row" ]
        [ sidebarView model
        , timelineView "Home timeline" "home" "home" model.userTimeline
        , notificationListView model.notifications
        , case model.currentView of
            Model.LocalTimelineView ->
                timelineView "Local timeline" "th-large" "local" model.localTimeline

            Model.GlobalTimelineView ->
                timelineView "Global timeline" "globe" "global" model.globalTimeline

            Model.AccountView account ->
                -- Todo: Load the user timeline
                accountTimelineView account model.accountTimeline "Account" "user"

            Model.ThreadView thread ->
                threadView thread
        ]


authView : Model -> Html Msg
authView model =
    div [ class "col-md-4 col-md-offset-4" ]
        [ div [ class "page-header" ]
            [ h1 []
                [ text "tooty"
                , small []
                    [ text " is a Web client for the "
                    , a
                        [ href "https://github.com/tootsuite/mastodon"
                        , target "_blank"
                        ]
                        [ text "Mastodon" ]
                    , text " API."
                    ]
                ]
            ]
        , div [ class "panel panel-default" ]
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


viewerView : Viewer -> Html Msg
viewerView { attachments, attachment } =
    let
        index =
            Maybe.withDefault -1 <| elemIndex attachment attachments

        ( prev, next ) =
            ( getAt (index - 1) attachments, getAt (index + 1) attachments )

        navLink label className target =
            case target of
                Nothing ->
                    text ""

                Just target ->
                    a
                        [ href ""
                        , class className
                        , onClickWithPreventAndStop <|
                            ViewerEvent (OpenViewer attachments target)
                        ]
                        [ text label ]
    in
        div
            [ class "viewer"
            , tabindex -1
            , onClickWithPreventAndStop <| ViewerEvent CloseViewer
            ]
            [ span [ class "close" ] [ text "×" ]
            , navLink "❮" "prev" prev
            , case attachment.type_ of
                "image" ->
                    img [ class "viewer-content", src attachment.url ] []

                _ ->
                    video
                        [ class "viewer-content"
                        , preload "auto"
                        , autoplay True
                        , loop True
                        ]
                        [ source [ src attachment.url ] [] ]
            , navLink "❯" "next" next
            ]


view : Model -> Html Msg
view model =
    div [ class "container-fluid" ]
        [ errorsListView model
        , case model.client of
            Just client ->
                homepageView model

            Nothing ->
                authView model
        , case model.viewer of
            Just viewer ->
                viewerView viewer

            Nothing ->
                text ""
        ]
