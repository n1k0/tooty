module Init exposing (init)

import Command
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
        ( model, commands ) =
            Update.Route.update
                { server = ""
                , currentTime = 0
                , registration = registration
                , clients = clients
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
                }
    in
        model
            ! [ commands, Command.initCommands registration (List.head clients) (Util.extractAuthCode location) ]
