module View exposing (view)

import Dict
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Mastodon
import Model exposing (Model, Draft, DraftMsg(..), Msg(..))
import ViewHelper


visibilities : Dict.Dict String String
visibilities =
    Dict.fromList
        [ ( "public", "post to public timelines" )
        , ( "unlisted", "do not show in public timelines" )
        , ( "private", "post to followers only" )
        , ( "direct", "post to mentioned users only" )
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


accountLink : Mastodon.Account -> Html Msg
accountLink account =
    a
        [ href account.url
        , ViewHelper.onClickWithPreventAndStop (OnLoadUserAccount account.id)
        ]
        [ text <| "@" ++ account.username ]


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
                [ div [] <| ViewHelper.formatContent status.content status.mentions
                , attachmentListView status
                ]

        spoiler ->
            -- Note: Spoilers are dealt with using pure CSS.
            let
                statusId =
                    "spoiler" ++ (toString status.id)
            in
                div [ class "status-text spoiled" ]
                    [ div [ class "spoiler" ] [ text status.spoiler_text ]
                    , input [ type_ "checkbox", id statusId, class "spoiler-toggler" ] []
                    , label [ for statusId ] [ text "Reveal content" ]
                    , div [ class "spoiled-content" ]
                        [ div [] <| ViewHelper.formatContent status.content status.mentions
                        , attachmentListView status
                        ]
                    ]


statusView : Mastodon.Status -> Html Msg
statusView ({ account, content, media_attachments, reblog, mentions } as status) =
    let
        accountLinkAttributes =
            [ href account.url
              -- When clicking on a status, we should not let the browser
              -- redirect to a new page. That's why we're preventing the default
              -- behavior here
            , ViewHelper.onClickWithPreventAndStop (OnLoadUserAccount account.id)
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
                    [ a accountLinkAttributes
                        [ img [ class "avatar", src account.avatar ] [] ]
                    , div [ class "username" ]
                        [ a accountLinkAttributes
                            [ text account.display_name
                            , span [ class "acct" ] [ text <| " @" ++ account.username ]
                            ]
                        ]
                    , statusContentView status
                    ]


accountTimelineView : Mastodon.Account -> List Mastodon.Status -> String -> String -> Html Msg
accountTimelineView account statuses label iconName =
    div [ class "col-md-3" ]
        [ div [ class "panel panel-default" ]
            [ div [ class "panel-heading" ]
                [ div [ class "row" ]
                    [ div [ class "col-xs-9 heading" ] [ icon iconName, text label ]
                    , div [ class "col-xs-3 text-right" ]
                        [ a
                            [ href ""
                            , ViewHelper.onClickWithPreventAndStop ClearOpenedAccount
                            ]
                            [ icon "remove" ]
                        ]
                    ]
                ]
            , div [ class "account-detail", style [ ( "background-image", "url('" ++ account.header ++ "')" ) ] ]
                [ div [ class "opacity-layer" ]
                    [ img [ src account.avatar ] []
                    , span [ class "account-display-name" ] [ text account.display_name ]
                    , span [ class "account-username" ] [ text ("@" ++ account.username) ]
                    , span [ class "account-note" ] (ViewHelper.formatContent account.note [])
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
            , ul [ class "list-group" ] <|
                List.map
                    (\s ->
                        li [ class "list-group-item status" ]
                            [ statusView s ]
                    )
                    statuses
            ]
        ]


statusActionsView : Mastodon.Status -> Html Msg
statusActionsView status =
    let
        originalStatus =
            case status.reblog of
                Just (Mastodon.Reblog reblog) ->
                    reblog

                Nothing ->
                    status

        baseBtnClasses =
            "btn btn-sm btn-default"

        isReblogged =
            Maybe.withDefault False status.reblogged

        isFavourite =
            Maybe.withDefault False status.favourited

        favClasses =
            if isFavourite then
                baseBtnClasses ++ " favourited"
            else
                baseBtnClasses

        reblogClasses =
            if isReblogged then
                baseBtnClasses ++ " reblogged"
            else
                baseBtnClasses
    in
        div [ class "btn-group actions" ]
            [ a
                [ class baseBtnClasses
                , ViewHelper.onClickWithPreventAndStop <|
                    DraftEvent (UpdateReplyTo originalStatus)
                ]
                [ icon "share-alt" ]
            , a
                [ class reblogClasses
                , ViewHelper.onClickWithPreventAndStop <|
                    if isReblogged then
                        Unreblog originalStatus.id
                    else
                        Reblog originalStatus.id
                ]
                [ icon "fire", text (toString status.reblogs_count) ]
            , a
                [ class favClasses
                , ViewHelper.onClickWithPreventAndStop <|
                    if isFavourite then
                        RemoveFavorite originalStatus.id
                    else
                        AddFavorite originalStatus.id
                ]
                [ icon "star", text (toString status.favourites_count) ]
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
            [ statusView status
            , statusActionsView status
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
                List.map statusEntryView statuses
            ]
        ]


notificationHeading : Mastodon.Account -> String -> String -> Html Msg
notificationHeading account str iconType =
    p [] <|
        List.intersperse (text " ")
            [ icon iconType, accountLink account, text str ]


notificationStatusView : Mastodon.Status -> Mastodon.Notification -> Html Msg
notificationStatusView status { type_, account } =
    div [ class "notification mention" ]
        [ case type_ of
            "reblog" ->
                notificationHeading account "boosted your toot" "fire"

            "favourite" ->
                notificationHeading account "favourited your toot" "star"

            _ ->
                text ""
        , statusView status
        , statusActionsView status
        ]


notificationFollowView : Mastodon.Notification -> Html Msg
notificationFollowView { account } =
    div [ class "notification follow" ]
        [ notificationHeading account "started following you" "user" ]


notificationEntryView : Mastodon.Notification -> Html Msg
notificationEntryView notification =
    li [ class "list-group-item" ]
        [ case notification.status of
            Just status ->
                notificationStatusView status notification

            Nothing ->
                notificationFollowView notification
        ]


notificationListView : List Mastodon.Notification -> Html Msg
notificationListView notifications =
    div [ class "col-md-3" ]
        [ div [ class "panel panel-default" ]
            [ div [ class "panel-heading" ]
                [ icon "bell"
                , text "Notifications"
                ]
            , ul [ class "list-group" ] <|
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
                            , ViewHelper.onClickWithPreventAndStop <| DraftEvent ClearReplyTo
                            ]
                            [ icon "remove" ]
                        , text ")"
                        ]
                    ]
                , div [ class "well" ] [ statusView status ]
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
            [ div [ class "panel-heading" ] [ icon "envelope", text "Post a message" ]
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


optionsView : Model -> Html Msg
optionsView model =
    div [ class "panel panel-default" ]
        [ div [ class "panel-heading" ] [ icon "cog", text "options" ]
        , div [ class "panel-body" ]
            [ div [ class "checkbox" ]
                [ label []
                    [ input
                        [ type_ "checkbox"
                        , onCheck UseGlobalTimeline
                        ]
                        []
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
        , timelineView model.userTimeline "Home timeline" "home"
        , notificationListView model.notifications
        , case model.account of
            Just account ->
                -- Todo: Load the user timeline
                accountTimelineView account [] "Account" "user"

            Nothing ->
                if model.useGlobalTimeline then
                    timelineView model.publicTimeline "Global timeline" "globe"
                else
                    timelineView model.localTimeline "Local timeline" "th-large"
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
        [ errorsListView model
        , case model.client of
            Just client ->
                homepageView model

            Nothing ->
                authView model
        ]
