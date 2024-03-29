module Update.Route exposing (update)

import Command
import Mastodon.Model exposing (StatusId(..))
import Types exposing (..)
import Update.AccountInfo
import Update.Timeline
import Url
import Url.Parser as Parser exposing (..)


type Route
    = AccountFollowersRoute String
    | AccountFollowingRoute String
    | AccountRoute String
    | AccountSelectorRoute
    | BlocksRoute
    | FavoriteTimelineRoute
    | GlobalTimelineRoute
    | HashtagRoute String
    | LocalTimelineRoute
    | MutesRoute
    | SearchRoute
    | ThreadRoute StatusId


statusIdParser : Parser (StatusId -> a) a
statusIdParser =
    custom "id" (Just << StatusId)


route : Parser (Route -> a) a
route =
    oneOf
        [ map LocalTimelineRoute top
        , map GlobalTimelineRoute (s "global" </> top)
        , map FavoriteTimelineRoute (s "favorites" </> top)
        , map HashtagRoute (s "hashtag" </> string)
        , map ThreadRoute (s "thread" </> statusIdParser)
        , map BlocksRoute (s "blocks" </> top)
        , map MutesRoute (s "mutes" </> top)
        , map AccountFollowersRoute (s "account" </> string </> s "followers")
        , map AccountFollowingRoute (s "account" </> string </> s "following")
        , map AccountRoute (s "account" </> string)
        , map AccountSelectorRoute (s "accounts")
        , map SearchRoute (s "search" </> top)
        ]


parseHash : Url.Url -> Maybe Route
parseHash url =
    let
        ( path, query ) =
            case url.fragment |> Maybe.map (String.split "?") of
                Just [ path_, query_ ] ->
                    ( path_, Just query_ )

                Just [ path_ ] ->
                    ( path_, Nothing )

                _ ->
                    ( "", Nothing )
    in
    { url | path = path, query = query, fragment = Nothing }
        |> Parser.parse route


update : Model -> ( Model, Cmd Msg )
update ({ accountInfo } as model) =
    case parseHash model.location of
        Just LocalTimelineRoute ->
            ( { model | currentView = LocalTimelineView }
            , Cmd.none
            )

        Just GlobalTimelineRoute ->
            ( { model | currentView = GlobalTimelineView }
            , Cmd.none
            )

        Just FavoriteTimelineRoute ->
            ( { model
                | currentView = FavoriteTimelineView
                , favoriteTimeline = Update.Timeline.setLoading True model.favoriteTimeline
              }
            , Command.loadFavoriteTimeline (List.head model.clients) Nothing
            )

        Just BlocksRoute ->
            ( { model
                | currentView = BlocksView
                , blocks = Update.Timeline.setLoading True model.blocks
              }
            , Command.loadBlocks (List.head model.clients) Nothing
            )

        Just MutesRoute ->
            ( { model
                | currentView = MutesView
                , mutes = Update.Timeline.setLoading True model.mutes
              }
            , Command.loadMutes (List.head model.clients) Nothing
            )

        Just AccountSelectorRoute ->
            ( { model | currentView = AccountSelectorView, server = "" }
            , Cmd.none
            )

        Just (AccountRoute accountId) ->
            ( { model
                | currentView = AccountView AccountStatusesView
                , accountInfo = Update.AccountInfo.empty
              }
            , Cmd.batch
                [ Command.loadAccount (List.head model.clients) accountId
                , Command.loadAccountTimeline (List.head model.clients) accountId Nothing
                ]
            )

        Just (AccountFollowersRoute accountId) ->
            ( { model
                | currentView = AccountView AccountFollowersView
                , accountInfo = { accountInfo | followers = Update.Timeline.empty "account-followers" }
              }
            , Cmd.batch
                [ Command.loadAccount (List.head model.clients) accountId
                , Command.loadAccountFollowers (List.head model.clients) accountId Nothing
                ]
            )

        Just (AccountFollowingRoute accountId) ->
            ( { model
                | currentView = AccountView AccountFollowingView
                , accountInfo = { accountInfo | following = Update.Timeline.empty "account-following" }
              }
            , Cmd.batch
                [ Command.loadAccount (List.head model.clients) accountId
                , Command.loadAccountFollowing (List.head model.clients) accountId Nothing
                ]
            )

        Just (HashtagRoute hashtag) ->
            ( { model
                | currentView = HashtagView hashtag
                , hashtagTimeline = Update.Timeline.setLoading True model.hashtagTimeline
              }
            , Command.loadHashtagTimeline (List.head model.clients) hashtag Nothing
            )

        Just (ThreadRoute id) ->
            ( { model | currentView = ThreadView (Thread Nothing Nothing) }
            , Command.loadThread (List.head model.clients) id
            )

        Just SearchRoute ->
            ( { model | currentView = SearchView }
            , Cmd.none
            )

        _ ->
            ( { model | currentView = LocalTimelineView }
            , Cmd.none
            )
