module View exposing (view)

import Autocomplete
import Dict
import Html exposing (..)
import Html.Keyed as Keyed
import Html.Lazy exposing (lazy, lazy2, lazy3)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import List.Extra exposing (find, elemIndex, getAt)
import Mastodon.Helper
import Mastodon.Model exposing (..)
import Model
import Types exposing (..)
import ViewHelper exposing (..)
import Date
import Date.Extra.Config.Config_en_au as DateEn
import Date.Extra.Format as DateFormat
import Json.Encode as Encode
import Json.Decode as Decode


type alias CurrentUser =
    Account


type alias CurrentUserRelation =
    Maybe Relationship


visibilities : Dict.Dict String String
visibilities =
    Dict.fromList
        [ ( "public", "post to public timelines" )
        , ( "unlisted", "do not show in public timelines" )
        , ( "private", "post to followers only" )
        , ( "direct", "post to mentioned users only" )
        ]


closeablePanelheading : String -> String -> String -> Msg -> Html Msg
closeablePanelheading context iconName label onClose =
    div [ class "panel-heading" ]
        [ div [ class "row" ]
            [ a
                [ href "", onClickWithPreventAndStop <| ScrollColumn ScrollTop context ]
                [ div [ class "col-xs-9 heading" ] [ icon iconName, text label ] ]
            , div [ class "col-xs-3 text-right" ]
                [ a
                    [ href "", onClickWithPreventAndStop onClose ]
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


accountLink : Account -> Html Msg
accountLink account =
    a
        [ href account.url
        , onClickWithPreventAndStop (LoadAccount account.id)
        ]
        [ text <| "@" ++ account.username ]


accountAvatarLink : Account -> Html Msg
accountAvatarLink account =
    a
        [ href account.url
        , onClickWithPreventAndStop (LoadAccount account.id)
        , title <| "@" ++ account.username
        ]
        [ img [ class "avatar", src account.avatar ] [] ]


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
                        [ icon "fire"
                        , a (accountLinkAttributes ++ [ class "reblogger" ])
                            [ text <| " @" ++ account.username ]
                        , text " boosted"
                        ]
                    , lazy2 statusView context reblog
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
                    , lazy2 statusContentView context status
                    ]


followButton : CurrentUser -> CurrentUserRelation -> Account -> Html Msg
followButton currentUser relationship account =
    if Mastodon.Helper.sameAccount account currentUser then
        text ""
    else
        let
            ( followEvent, btnClasses, iconName, tooltip ) =
                case relationship of
                    Nothing ->
                        ( NoOp
                        , "btn btn-default btn-disabled"
                        , "question-sign"
                        , "Unknown relationship"
                        )

                    Just relationship ->
                        if relationship.following then
                            ( UnfollowAccount account.id
                            , "btn btn-default btn-primary"
                            , "eye-close"
                            , "Unfollow"
                            )
                        else
                            ( FollowAccount account.id
                            , "btn btn-default"
                            , "eye-open"
                            , "Follow"
                            )
        in
            button [ class btnClasses, title tooltip, onClick followEvent ]
                [ icon iconName ]


followView : CurrentUser -> Maybe Relationship -> Account -> Html Msg
followView currentUser relationship account =
    div [ class "follow-entry" ]
        [ accountAvatarLink account
        , div [ class "userinfo" ]
            [ strong []
                [ a
                    [ href account.url
                    , onClickWithPreventAndStop <| LoadAccount account.id
                    ]
                    [ text <|
                        if account.display_name /= "" then
                            account.display_name
                        else
                            account.username
                    ]
                ]
            , br [] []
            , text <| "@" ++ account.acct
            ]
        , followButton currentUser relationship account
        ]


accountCounterLink : String -> Int -> (Account -> Msg) -> Account -> Html Msg
accountCounterLink label count tagger account =
    a
        [ href ""
        , class "col-md-4"
        , onClickWithPreventAndStop <| tagger account
        ]
        [ text label
        , br [] []
        , text <| toString count
        ]


accountView : CurrentUser -> Account -> CurrentUserRelation -> Html Msg -> Html Msg
accountView currentUser account relationship panelContent =
    let
        { statuses_count, following_count, followers_count } =
            account
    in
        div [ class "col-md-3 column" ]
            [ div [ class "panel panel-default" ]
                [ closeablePanelheading "account" "user" "Account" CloseAccount
                , div [ id "account", class "timeline" ]
                    [ div
                        [ class "account-detail"
                        , style [ ( "background-image", "url('" ++ account.header ++ "')" ) ]
                        ]
                        [ div [ class "opacity-layer" ]
                            [ followButton currentUser relationship account
                            , img [ src account.avatar ] []
                            , span [ class "account-display-name" ] [ text account.display_name ]
                            , span [ class "account-username" ] [ text ("@" ++ account.username) ]
                            , span [ class "account-note" ] (formatContent account.note [])
                            ]
                        ]
                    , div [ class "row account-infos" ]
                        [ accountCounterLink "Statuses" statuses_count ViewAccountStatuses account
                        , accountCounterLink "Following" following_count ViewAccountFollowing account
                        , accountCounterLink "Followers" followers_count ViewAccountFollowers account
                        ]
                    , panelContent
                    ]
                ]
            ]


accountTimelineView : CurrentUser -> List Status -> CurrentUserRelation -> Account -> Html Msg
accountTimelineView currentUser statuses relationship account =
    let
        keyedEntry status =
            ( toString status.id
            , li [ class "list-group-item status" ]
                [ lazy2 statusView "account" status ]
            )
    in
        accountView currentUser account relationship <|
            Keyed.ul [ class "list-group" ] <|
                List.map keyedEntry statuses


accountFollowView :
    CurrentUser
    -> List Account
    -> List Relationship
    -> CurrentUserRelation
    -> Account
    -> Html Msg
accountFollowView currentUser accounts relationships relationship account =
    let
        keyedEntry account =
            ( toString account.id
            , li [ class "list-group-item status" ]
                [ followView
                    currentUser
                    (find (\r -> r.id == account.id) relationships)
                    account
                ]
            )
    in
        accountView currentUser account relationship <|
            Keyed.ul [ class "list-group" ] <|
                List.map keyedEntry accounts


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
                [ icon "share-alt" ]
            , a
                [ class reblogClasses
                , onClickWithPreventAndStop reblogEvent
                ]
                [ icon "fire", text (toString sourceStatus.reblogs_count) ]
            , a
                [ class favClasses
                , onClickWithPreventAndStop favEvent
                ]
                [ icon "star", text (toString sourceStatus.favourites_count) ]
            , if Mastodon.Helper.sameAccount sourceStatus.account currentUser then
                a
                    [ class <| baseBtnClasses ++ " btn-delete"
                    , href ""
                    , onClickWithPreventAndStop <| DeleteStatus sourceStatus.id
                    ]
                    [ icon "trash" ]
              else
                text ""
            , a
                [ class baseBtnClasses, href status.url, target "_blank" ]
                [ icon "time", formatDate ]
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
            [ lazy2 statusView context status
            , lazy2 statusActionsView status currentUser
            ]


timelineView : ( String, String, String, CurrentUser, List Status ) -> Html Msg
timelineView ( label, iconName, context, currentUser, statuses ) =
    let
        keyedEntry status =
            ( toString id, statusEntryView context "" currentUser status )
    in
        div [ class "col-md-3 column" ]
            [ div [ class "panel panel-default" ]
                [ a
                    [ href "", onClickWithPreventAndStop <| ScrollColumn ScrollTop context ]
                    [ div [ class "panel-heading" ] [ icon iconName, text label ] ]
                , Keyed.ul [ id context, class "list-group timeline" ] <|
                    List.map keyedEntry statuses
                ]
            ]


notificationHeading : List Account -> String -> String -> Html Msg
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


notificationStatusView : ( String, CurrentUser, Status, NotificationAggregate ) -> Html Msg
notificationStatusView ( context, currentUser, status, { type_, accounts } ) =
    div [ class <| "notification " ++ type_ ]
        [ case type_ of
            "reblog" ->
                notificationHeading accounts "boosted your toot" "fire"

            "favourite" ->
                notificationHeading accounts "favourited your toot" "star"

            _ ->
                text ""
        , lazy2 statusView context status
        , lazy2 statusActionsView status currentUser
        ]


notificationFollowView : CurrentUser -> NotificationAggregate -> Html Msg
notificationFollowView currentUser { accounts } =
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


notificationEntryView : CurrentUser -> NotificationAggregate -> Html Msg
notificationEntryView currentUser notification =
    li [ class "list-group-item" ]
        [ case notification.status of
            Just status ->
                lazy notificationStatusView ( "notification", currentUser, status, notification )

            Nothing ->
                notificationFollowView currentUser notification
        ]


notificationFilterView : NotificationFilter -> Html Msg
notificationFilterView filter =
    let
        filterBtn tooltip iconName event =
            button
                [ class <|
                    if filter == event then
                        "btn btn-primary"
                    else
                        "btn btn-default"
                , title tooltip
                , onClick <| FilterNotifications event
                ]
                [ icon iconName ]
    in
        justifiedButtonGroup
            [ filterBtn "All notifications" "asterisk" NotificationAll
            , filterBtn "Mentions" "share-alt" NotificationOnlyMentions
            , filterBtn "Boosts" "fire" NotificationOnlyBoosts
            , filterBtn "Favorites" "star" NotificationOnlyFavourites
            , filterBtn "Follows" "user" NotificationOnlyFollows
            ]


notificationListView : CurrentUser -> NotificationFilter -> List NotificationAggregate -> Html Msg
notificationListView currentUser filter notifications =
    let
        keyedEntry notification =
            ( toString notification.id
            , lazy2 notificationEntryView currentUser notification
            )
    in
        div [ class "col-md-3 column" ]
            [ div [ class "panel panel-default notifications-panel" ]
                [ a
                    [ href "", onClickWithPreventAndStop <| ScrollColumn ScrollTop "notifications" ]
                    [ div [ class "panel-heading" ] [ icon "bell", text "Notifications" ] ]
                , notificationFilterView filter
                , Keyed.ul [ id "notifications", class "list-group timeline" ] <|
                    (notifications
                        |> filterNotifications filter
                        |> List.map keyedEntry
                    )
                ]
            ]


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
                            [ icon "remove" ]
                        , text ")"
                        ]
                    ]
                , div [ class "well" ] [ lazy2 statusView "draft" status ]
                ]

        Nothing ->
            text ""


currentUserView : Maybe CurrentUser -> Html Msg
currentUserView currentUser =
    case currentUser of
        Just currentUser ->
            div [ class "current-user" ]
                [ accountAvatarLink currentUser
                , div [ class "username" ] [ accountLink currentUser ]
                , p [ class "status-text" ] <| formatContent currentUser.note []
                ]

        Nothing ->
            text ""


draftView : Model -> Html Msg
draftView ({ draft, currentUser } as model) =
    let
        hasSpoiler =
            draft.spoilerText /= Nothing

        visibilityOptionView ( visibility, description ) =
            option [ value visibility ]
                [ text <| visibility ++ ": " ++ description ]

        autoMenu =
            if draft.showAutoMenu then
                viewAutocompleteMenu model.draft
            else
                text ""
    in
        div [ class "panel panel-default" ]
            [ div [ class "panel-heading" ]
                [ icon "envelope"
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


threadView : CurrentUser -> Thread -> Html Msg
threadView currentUser thread =
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
                currentUser
                status

        keyedEntry status =
            ( toString status.id, threadEntry status )
    in
        div [ class "col-md-3 column" ]
            [ div [ class "panel panel-default" ]
                [ closeablePanelheading "thread" "list" "Thread" CloseThread
                , Keyed.ul [ id "thread", class "list-group timeline" ] <|
                    List.map keyedEntry statuses
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
    div [ class "col-md-3 column" ]
        [ lazy draftView model
        , lazy optionsView model
        ]


homepageView : Model -> Html Msg
homepageView model =
    case model.currentUser of
        Nothing ->
            text ""

        Just currentUser ->
            div [ class "row" ]
                [ lazy sidebarView model
                , lazy timelineView
                    ( "Home timeline"
                    , "home"
                    , "home"
                    , currentUser
                    , model.userTimeline
                    )
                , lazy3 notificationListView currentUser model.notificationFilter model.notifications
                , case model.currentView of
                    LocalTimelineView ->
                        lazy timelineView
                            ( "Local timeline"
                            , "th-large"
                            , "local"
                            , currentUser
                            , model.localTimeline
                            )

                    GlobalTimelineView ->
                        lazy timelineView
                            ( "Global timeline"
                            , "globe"
                            , "global"
                            , currentUser
                            , model.globalTimeline
                            )

                    AccountView account ->
                        accountTimelineView
                            currentUser
                            model.accountTimeline
                            model.accountRelationship
                            account

                    AccountFollowersView account followers ->
                        accountFollowView
                            currentUser
                            model.accountFollowers
                            model.accountRelationships
                            model.accountRelationship
                            account

                    AccountFollowingView account following ->
                        accountFollowView
                            currentUser
                            model.accountFollowing
                            model.accountRelationships
                            model.accountRelationship
                            account

                    ThreadView thread ->
                        threadView currentUser thread
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


viewAutocompleteMenu : Draft -> Html Msg
viewAutocompleteMenu draft =
    div [ class "autocomplete-menu" ]
        [ Html.map (DraftEvent << SetAutoState)
            (Autocomplete.view viewConfig
                draft.autoMaxResults
                draft.autoState
                (Model.acceptableAccounts draft.autoQuery draft.autoAccounts)
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
