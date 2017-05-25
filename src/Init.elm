module Init exposing (init)

import Command
import Navigation
import Types exposing (..)
import Update.Draft
import Update.Timeline
import Util


init : Flags -> Navigation.Location -> ( Model, Cmd Msg )
init { registration, clients } location =
    { server = ""
    , currentTime = 0
    , registration = registration
    , clients = clients
    , homeTimeline = Update.Timeline.empty "home-timeline"
    , localTimeline = Update.Timeline.empty "local-timeline"
    , globalTimeline = Update.Timeline.empty "global-timeline"
    , favoriteTimeline = Update.Timeline.empty "favorite-timeline"
    , mutes = Update.Timeline.empty "mutes"
    , blocks = Update.Timeline.empty "blocks"
    , accountTimeline = Update.Timeline.empty "account-timeline"
    , accountFollowers = Update.Timeline.empty "account-followers"
    , accountFollowing = Update.Timeline.empty "account-following"
    , accountRelationships = []
    , accountRelationship = Nothing
    , notifications = Update.Timeline.empty "notifications"
    , draft = Update.Draft.empty
    , errors = []
    , location = location
    , viewer = Nothing
    , currentView = LocalTimelineView
    , currentUser = Nothing
    , notificationFilter = NotificationAll
    , confirm = Nothing
    }
        ! [ Command.initCommands registration (List.head clients) (Util.extractAuthCode location) ]
