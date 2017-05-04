module Types exposing (..)

import Autocomplete
import Mastodon.Http exposing (Response, Links)
import Mastodon.Model exposing (..)
import Navigation


type alias Flags =
    { client : Maybe Client
    , registration : Maybe AppRegistration
    }


type DraftMsg
    = ClearDraft
    | UpdateSensitive Bool
    | UpdateSpoiler String
    | UpdateVisibility String
    | UpdateReplyTo Status
    | SelectAccount String
    | ToggleSpoiler Bool
    | UpdateInputInformation InputInformation
    | ResetAutocomplete Bool
    | SetAutoState Autocomplete.Msg


type ViewerMsg
    = CloseViewer
    | OpenViewer (List Attachment) Attachment


type alias MastodonResult a =
    Result Error (Response a)


type MastodonMsg
    = AccessToken (MastodonResult AccessTokenResult)
    | AccountFollowed (MastodonResult Relationship)
    | AccountFollowers (MastodonResult (List Account))
    | AccountFollowing (MastodonResult (List Account))
    | AccountReceived (MastodonResult Account)
    | AccountRelationship (MastodonResult (List Relationship))
    | AccountRelationships (MastodonResult (List Relationship))
    | AccountTimeline (MastodonResult (List Status))
    | AccountUnfollowed (MastodonResult Relationship)
    | AppRegistered (MastodonResult AppRegistration)
    | AutoSearch (MastodonResult (List Account))
    | ContextLoaded Status (MastodonResult Context)
    | CurrentUser (MastodonResult Account)
    | FavoriteAdded (MastodonResult Status)
    | FavoriteRemoved (MastodonResult Status)
    | GlobalTimeline (MastodonResult (List Status))
    | LocalTimeline (MastodonResult (List Status))
    | Notifications (MastodonResult (List Notification))
    | Reblogged (MastodonResult Status)
    | StatusDeleted (MastodonResult Int)
    | StatusPosted (MastodonResult Status)
    | Unreblogged (MastodonResult Status)
    | UserTimeline (MastodonResult (List Status))
    | UserTimelineAppend (MastodonResult (List Status))


type WebSocketMsg
    = NewWebsocketGlobalMessage String
    | NewWebsocketLocalMessage String
    | NewWebsocketUserMessage String


type Msg
    = AddFavorite Int
    | CloseAccount
    | CloseThread
    | DeleteStatus Int
    | DraftEvent DraftMsg
    | FilterNotifications NotificationFilter
    | FollowAccount Int
    | LoadAccount Int
    | LoadNext String
    | MastodonEvent MastodonMsg
    | NoOp
    | OpenThread Status
    | ReblogStatus Int
    | Register
    | RemoveFavorite Int
    | ScrollColumn ScrollDirection String
    | ServerChange String
    | SubmitDraft
    | UnfollowAccount Int
    | UrlChange Navigation.Location
    | UseGlobalTimeline Bool
    | UnreblogStatus Int
    | ViewAccountFollowing Account
    | ViewAccountFollowers Account
    | ViewAccountStatuses Account
    | ViewerEvent ViewerMsg
    | WebSocketEvent WebSocketMsg


type alias AccountViewInfo =
    { account : Account
    , timeline : List Status
    , folowers : List Account
    , following : List Account
    }


type CurrentView
    = -- Basically, what we should be displaying in the fourth column
      AccountFollowersView Account (List Account)
    | AccountFollowingView Account (List Account)
    | AccountView Account
    | GlobalTimelineView
    | LocalTimelineView
    | ThreadView Thread


type alias Draft =
    { status : String
    , inReplyTo : Maybe Status
    , spoilerText : Maybe String
    , sensitive : Bool
    , visibility : String
    , statusLength : Int

    -- Autocomplete values
    , autoState : Autocomplete.State
    , autoCursorPosition : Int
    , autoAtPosition : Maybe Int
    , autoQuery : String
    , autoMaxResults : Int
    , autoAccounts : List Account
    , showAutoMenu : Bool
    }


type NotificationFilter
    = NotificationAll
    | NotificationOnlyMentions
    | NotificationOnlyBoosts
    | NotificationOnlyFavourites
    | NotificationOnlyFollows


type ScrollDirection
    = ScrollTop
    | ScrollBottom


type alias Thread =
    { status : Status
    , context : Context
    }


type alias Viewer =
    { attachments : List Attachment
    , attachment : Attachment
    }


type alias Model =
    { server : String
    , registration : Maybe AppRegistration
    , client : Maybe Client
    , userTimeline : List Status
    , userTimelineLinks : Links
    , localTimeline : List Status
    , globalTimeline : List Status
    , accountTimeline : List Status
    , accountFollowers : List Account
    , accountFollowing : List Account
    , accountRelationships : List Relationship
    , accountRelationship : Maybe Relationship
    , notifications : List NotificationAggregate
    , draft : Draft
    , errors : List String
    , location : Navigation.Location
    , useGlobalTimeline : Bool
    , viewer : Maybe Viewer
    , currentUser : Maybe Account
    , currentView : CurrentView
    , notificationFilter : NotificationFilter
    }


type alias InputInformation =
    { status : String
    , selectionStart : Int
    }
