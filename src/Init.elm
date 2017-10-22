module Init exposing (init)

import Command
import Mastodon.Decoder exposing (decodeClients)
import Navigation
import Types exposing (..)
import Update.AccountInfo
import Update.Draft
import Update.Route
import Update.Timeline
import Util


init : Flags -> Navigation.Location -> ( Model, Cmd Msg )
init { registration, clients } location =
    let
        decodedClients =
            Result.withDefault [] <| decodeClients clients

        ( model, commands ) =
            Update.Route.update
                { server = ""
                , currentTime = 0
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
                }
    in
        model
            ! [ commands, Command.initCommands registration (List.head decodedClients) (Util.extractAuthCode location) ]
