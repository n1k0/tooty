module Model exposing (..)

import Command
import List.Extra exposing (removeAt)
import Navigation
import Mastodon.Model exposing (..)
import Types exposing (..)
import Update.Draft
import Update.Mastodon
import Update.Timeline
import Update.Viewer
import Update.WebSocket


extractAuthCode : Navigation.Location -> Maybe String
extractAuthCode { search } =
    case (String.split "?code=" search) of
        [ _, authCode ] ->
            Just authCode

        _ ->
            Nothing


init : Flags -> Navigation.Location -> ( Model, Cmd Msg )
init flags location =
    let
        authCode =
            extractAuthCode location
    in
        { server = ""
        , currentTime = 0
        , registration = flags.registration
        , client = flags.client
        , homeTimeline = Update.Timeline.empty "home-timeline"
        , localTimeline = Update.Timeline.empty "local-timeline"
        , globalTimeline = Update.Timeline.empty "global-timeline"
        , accountTimeline = Update.Timeline.empty "account-timeline"
        , accountFollowers = []
        , accountFollowing = []
        , accountRelationships = []
        , accountRelationship = Nothing
        , notifications = Update.Timeline.empty "notifications"
        , draft = Update.Draft.empty
        , errors = []
        , location = location
        , useGlobalTimeline = False
        , viewer = Nothing
        , currentView = LocalTimelineView
        , currentUser = Nothing
        , notificationFilter = NotificationAll
        }
            ! [ Command.initCommands flags.registration flags.client authCode ]


toStatusRequestBody : Draft -> StatusRequestBody
toStatusRequestBody draft =
    { status = draft.status
    , in_reply_to_id =
        case draft.inReplyTo of
            Just status ->
                Just status.id

            Nothing ->
                Nothing
    , spoiler_text = draft.spoilerText
    , sensitive = draft.sensitive
    , visibility = draft.visibility
    }


processFavourite : Int -> Bool -> Model -> Model
processFavourite statusId flag model =
    Update.Timeline.updateTimelinesWithBoolFlag statusId
        flag
        (\s ->
            { s
                | favourited = Just flag
                , favourites_count =
                    if flag then
                        s.favourites_count + 1
                    else if s.favourites_count > 0 then
                        s.favourites_count - 1
                    else
                        0
            }
        )
        model


processReblog : Int -> Bool -> Model -> Model
processReblog statusId flag model =
    Update.Timeline.updateTimelinesWithBoolFlag statusId
        flag
        (\s ->
            { s
                | reblogged = Just flag
                , reblogs_count =
                    if flag then
                        s.reblogs_count + 1
                    else if s.reblogs_count > 0 then
                        s.reblogs_count - 1
                    else
                        0
            }
        )
        model


markTimelineLoading : Bool -> String -> Model -> Model
markTimelineLoading loading id model =
    let
        mark timeline =
            { timeline | loading = loading }
    in
        case id of
            "notifications" ->
                { model | notifications = mark model.notifications }

            "home-timeline" ->
                { model | homeTimeline = mark model.homeTimeline }

            "local-timeline" ->
                { model | localTimeline = mark model.localTimeline }

            "global-timeline" ->
                { model | globalTimeline = mark model.globalTimeline }

            "account-timeline" ->
                case model.currentView of
                    AccountView account ->
                        { model | accountTimeline = mark model.accountTimeline }

                    _ ->
                        model

            _ ->
                model


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            model ! []

        Tick newTime ->
            { model
                | currentTime = newTime
                , errors = List.filter (\{ time } -> model.currentTime - time <= 10000) model.errors
            }
                ! []

        ClearError index ->
            { model | errors = removeAt index model.errors } ! []

        MastodonEvent msg ->
            let
                ( newModel, commands ) =
                    Update.Mastodon.update msg model
            in
                newModel ! [ commands ]

        WebSocketEvent msg ->
            let
                ( newModel, commands ) =
                    Update.WebSocket.update msg model
            in
                newModel ! [ commands ]

        ServerChange server ->
            { model | server = server } ! []

        UrlChange location ->
            model ! []

        Register ->
            model ! [ Command.registerApp model ]

        OpenThread status ->
            model ! [ Command.loadThread model.client status ]

        CloseThread ->
            { model | currentView = Update.Timeline.preferred model } ! []

        FollowAccount id ->
            model ! [ Command.follow model.client id ]

        UnfollowAccount id ->
            model ! [ Command.unfollow model.client id ]

        DeleteStatus id ->
            model ! [ Command.deleteStatus model.client id ]

        ReblogStatus id ->
            processReblog id True model ! [ Command.reblogStatus model.client id ]

        UnreblogStatus id ->
            processReblog id False model ! [ Command.unreblogStatus model.client id ]

        AddFavorite id ->
            processFavourite id True model ! [ Command.favouriteStatus model.client id ]

        RemoveFavorite id ->
            processFavourite id False model ! [ Command.unfavouriteStatus model.client id ]

        DraftEvent draftMsg ->
            case model.currentUser of
                Just user ->
                    Update.Draft.update draftMsg user model

                Nothing ->
                    model ! []

        ViewerEvent viewerMsg ->
            let
                ( viewer, commands ) =
                    Update.Viewer.update viewerMsg model.viewer
            in
                { model | viewer = viewer } ! [ commands ]

        SubmitDraft ->
            model ! [ Command.postStatus model.client <| toStatusRequestBody model.draft ]

        LoadAccount accountId ->
            { model
                | accountTimeline = Update.Timeline.empty "account-timeline"
                , accountFollowers = []
                , accountFollowing = []
                , accountRelationships = []
                , accountRelationship = Nothing
            }
                ! [ Command.loadAccount model.client accountId ]

        TimelineLoadNext id next ->
            markTimelineLoading True id model
                ! [ Command.loadNextTimeline model.client model.currentView id next ]

        ViewAccountFollowers account ->
            { model | currentView = AccountFollowersView account model.accountFollowers }
                ! [ Command.loadAccountFollowers model.client account.id ]

        ViewAccountFollowing account ->
            { model | currentView = AccountFollowingView account model.accountFollowing }
                ! [ Command.loadAccountFollowing model.client account.id ]

        ViewAccountStatuses account ->
            { model | currentView = AccountView account } ! []

        UseGlobalTimeline flag ->
            let
                newModel =
                    { model | useGlobalTimeline = flag }
            in
                { newModel | currentView = Update.Timeline.preferred newModel } ! []

        CloseAccount ->
            { model
                | currentView = Update.Timeline.preferred model
                , accountTimeline = Update.Timeline.empty "account-timeline"
                , accountFollowing = []
                , accountFollowers = []
            }
                ! []

        FilterNotifications filter ->
            { model | notificationFilter = filter } ! []

        ScrollColumn ScrollTop column ->
            model ! [ Command.scrollColumnToTop column ]

        ScrollColumn ScrollBottom column ->
            model ! [ Command.scrollColumnToBottom column ]
