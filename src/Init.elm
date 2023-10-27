module Init exposing (init)

import Browser.Navigation as Navigation
import Command
import InfiniteScroll
import Mastodon.Decoder exposing (decodeClients)
import Time
import Types exposing (..)
import Update.AccountInfo
import Update.Draft
import Update.Route
import Update.Timeline
import Url


init : Flags -> Url.Url -> Navigation.Key -> ( Model, Cmd Msg )
init { registration, clients } location key =
    let
        decodedClients =
            Result.withDefault [] <| decodeClients clients

        ( model, commands ) =
            Update.Route.update
                { server = ""
                , accountInfo = Update.AccountInfo.empty
                , blocks = Update.Timeline.empty "blocks-timeline"
                , clients = decodedClients
                , confirm = Nothing
                , currentTime = Time.millisToPosix 0
                , currentView = LocalTimelineView
                , currentUser = Nothing
                , ctrlPressed = False
                , draft = Update.Draft.empty
                , errors = []
                , favoriteTimeline = Update.Timeline.empty "favorite-timeline"
                , globalTimeline = Update.Timeline.empty "global-timeline"
                , hashtagTimeline = Update.Timeline.empty "hashtag-timeline"
                , homeTimeline = Update.Timeline.empty "home-timeline"
                , infiniteScrollHome =
                    InfiniteScroll.startLoading
                        (InfiniteScroll.init <|
                            Command.loadMore Command.loadHomeTimeline (List.head decodedClients) Nothing
                        )
                , key = key
                , localTimeline = Update.Timeline.empty "local-timeline"
                , infiniteScrollLocal =
                    InfiniteScroll.startLoading
                        (InfiniteScroll.init <|
                            Command.loadMore Command.loadLocalTimeline (List.head decodedClients) Nothing
                        )
                , location = location
                , mutes = Update.Timeline.empty "mutes-timeline"
                , notificationFilter = NotificationAll
                , notifications = Update.Timeline.empty "notifications"
                , registration = registration
                , search = Search "" Nothing
                , viewer = Nothing
                }
    in
    ( model
    , Cmd.batch [ commands, Command.initCommands registration (List.head decodedClients) location ]
    )
