module Init exposing (init)

import Browser.Navigation as Navigation
import Command
import InfiniteScroll
import Mastodon.Decoder exposing (decodeClients)
import Mastodon.Model exposing (Client)
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

        client =
            List.head decodedClients

        loadHashtagCmd : Maybe Client -> Maybe String -> Cmd Msg
        loadHashtagCmd someClient url =
            Command.loadHashtagTimeline someClient "" url

        ( model, commands ) =
            Update.Route.update
                { server = ""
                , clientName = "Tooty"
                , accountInfo = Update.AccountInfo.empty
                , blocks = Update.Timeline.empty "blocks-timeline"
                , clients = decodedClients
                , confirm = Nothing
                , currentTime = Time.millisToPosix 0
                , currentView = LocalTimelineView
                , currentUser = Nothing
                , customEmojis = []
                , ctrlPressed = False
                , draft = Update.Draft.empty
                , errors = []
                , favoriteTimeline = Update.Timeline.empty "favorite-timeline"
                , globalTimeline = Update.Timeline.empty "global-timeline"
                , hashtagTimeline = Update.Timeline.empty "hashtag-timeline"
                , homeTimeline = Update.Timeline.empty "home-timeline"
                , infiniteScrollHashtag =
                    InfiniteScroll.startLoading
                        (InfiniteScroll.init <|
                            Command.loadMore loadHashtagCmd client Nothing
                        )
                , infiniteScrollHome =
                    InfiniteScroll.startLoading
                        (InfiniteScroll.init <|
                            Command.loadMore Command.loadHomeTimeline client Nothing
                        )
                , infiniteScrollLocal =
                    InfiniteScroll.startLoading
                        (InfiniteScroll.init <|
                            Command.loadMore Command.loadLocalTimeline client Nothing
                        )
                , infiniteScrollNotifications =
                    InfiniteScroll.startLoading
                        (InfiniteScroll.init <|
                            Command.loadMore Command.loadNotifications client Nothing
                        )
                , key = key
                , localTimeline = Update.Timeline.empty "local-timeline"
                , location = location
                , mutes = Update.Timeline.empty "mutes-timeline"
                , notificationFilter = NotificationAll
                , rawNotifications = []
                , notifications = Update.Timeline.empty "notifications"
                , registration = registration
                , search = Search "" Nothing
                , viewer = Nothing
                }
    in
    ( model
    , Cmd.batch [ commands, Command.initCommands registration (List.head decodedClients) location ]
    )
