module Update.Route exposing (update)

import Command
import Types exposing (..)
import Update.Timeline
import UrlParser exposing (..)


type Route
    = AccountFollowersRoute Int
    | AccountFollowingRoute Int
    | AccountRoute Int
    | AccountSelectorRoute
    | BlocksRoute
    | FavoriteTimelineRoute
    | GlobalTimelineRoute
    | HashtagRoute String
    | LocalTimelineRoute
    | MutesRoute
    | ThreadRoute Int


route : Parser (Route -> a) a
route =
    oneOf
        [ map LocalTimelineRoute top
        , map GlobalTimelineRoute (s "global" </> top)
        , map FavoriteTimelineRoute (s "favorites" </> top)
        , map HashtagRoute (s "hashtag" </> string)
        , map ThreadRoute (s "thread" </> int)
        , map BlocksRoute (s "blocks" </> top)
        , map MutesRoute (s "mutes" </> top)
        , map AccountFollowersRoute (s "account" </> int </> s "followers")
        , map AccountFollowingRoute (s "account" </> int </> s "following")
        , map AccountRoute (s "account" </> int)
        , map AccountSelectorRoute (s "accounts")
        ]


update : Model -> ( Model, Cmd Msg )
update model =
    case parseHash route model.location of
        Just LocalTimelineRoute ->
            { model | currentView = LocalTimelineView } ! []

        Just GlobalTimelineRoute ->
            { model | currentView = GlobalTimelineView } ! []

        Just FavoriteTimelineRoute ->
            { model
                | currentView = FavoriteTimelineView
                , favoriteTimeline = Update.Timeline.setLoading True model.favoriteTimeline
            }
                ! [ Command.loadFavoriteTimeline (List.head model.clients) Nothing ]

        Just BlocksRoute ->
            { model
                | currentView = BlocksView
                , blocks = Update.Timeline.setLoading True model.blocks
            }
                ! [ Command.loadBlocks (List.head model.clients) Nothing ]

        Just MutesRoute ->
            { model
                | currentView = MutesView
                , mutes = Update.Timeline.setLoading True model.mutes
            }
                ! [ Command.loadMutes (List.head model.clients) Nothing ]

        Just AccountSelectorRoute ->
            { model | currentView = AccountSelectorView, server = "" } ! []

        Just (AccountRoute accountId) ->
            { model
                | accountTimeline = Update.Timeline.empty "account-timeline"
                , accountFollowers = Update.Timeline.empty "account-followers"
                , accountFollowing = Update.Timeline.empty "account-following"
                , accountRelationships = []
                , accountRelationship = Nothing
            }
                ! [ Command.loadAccount (List.head model.clients) accountId ]

        Just (HashtagRoute hashtag) ->
            { model
                | currentView = HashtagView hashtag
                , hashtagTimeline = Update.Timeline.setLoading True model.hashtagTimeline
            }
                ! [ Command.loadHashtagTimeline (List.head model.clients) hashtag Nothing ]

        _ ->
            { model | currentView = LocalTimelineView } ! []