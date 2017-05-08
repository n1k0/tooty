module Init exposing (init)

import Command
import Navigation
import Types exposing (..)
import Update.Draft
import Update.Timeline
import Util


init : Flags -> Navigation.Location -> ( Model, Cmd Msg )
init { registration, client } location =
    { server = ""
    , currentTime = 0
    , registration = registration
    , client = client
    , homeTimeline = Update.Timeline.empty "home-timeline"
    , localTimeline = Update.Timeline.empty "local-timeline"
    , globalTimeline = Update.Timeline.empty "global-timeline"
    , accountTimeline = Update.Timeline.empty "account-timeline"
    , accountFollowers = Update.Timeline.empty "account-followers"
    , accountFollowing = Update.Timeline.empty "account-following"
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
        ! [ Command.initCommands registration client (Util.extractAuthCode location) ]
