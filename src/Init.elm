module Init exposing (init)

import Browser.Navigation as Navigation
import Command
import Mastodon.Decoder exposing (decodeClients)
import Time
import Types exposing (..)
import Update.AccountInfo
import Update.Draft
import Update.Route
import Update.Timeline
import Url
import Util


init : Flags -> Url.Url -> Navigation.Key -> ( Model, Cmd Msg )
init { registration, clients } location key =
    let
        decodedClients =
            Result.withDefault [] <| decodeClients clients

        ( model, commands ) =
            Update.Route.update
                { server = ""
                , currentTime = Time.millisToPosix 0
                , registration = registration
                , clients = decodedClients
                , homeTimeline = Update.Timeline.empty "home-timeline"
                , localTimeline = Update.Timeline.empty "local-timeline"
                , globalTimeline = Update.Timeline.empty "global-timeline"
                , favoriteTimeline = Update.Timeline.empty "favorite-timeline"
                , hashtagTimeline = Update.Timeline.empty "hashtag-timeline"
                , mutes = Update.Timeline.empty "mutes-timeline"
                , blocks = Update.Timeline.empty "blocks-timeline"
                , accountInfo = Update.AccountInfo.empty
                , notifications = Update.Timeline.empty "notifications"
                , draft = Update.Draft.empty
                , errors = []
                , location = location
                , viewer = Nothing
                , currentView = LocalTimelineView
                , currentUser = Nothing
                , notificationFilter = NotificationAll
                , confirm = Nothing
                , search = Search "" Nothing
                , ctrlPressed = False
                , key = key
                }
    in
    ( model
    , Cmd.batch [ commands, Command.initCommands registration (List.head decodedClients) location ]
    )
