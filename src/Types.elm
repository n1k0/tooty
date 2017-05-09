module Types exposing (..)

import Autocomplete
import Mastodon.Http exposing (Response, Links)
import Mastodon.Model exposing (..)
import Navigation
import Time exposing (Time)


type alias Flags =
    { clients : List Client
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
    | CloseAutocomplete
    | SetAutoState Autocomplete.Msg


type ViewerMsg
    = CloseViewer
    | OpenViewer (List Attachment) Attachment


type alias MastodonResult a =
    Result Error (Response a)


type MastodonMsg
    = AccessToken (MastodonResult AccessTokenResult)
    | AccountFollowed (MastodonResult Relationship)
    | AccountFollowers Bool (MastodonResult (List Account))
    | AccountFollowing Bool (MastodonResult (List Account))
    | AccountReceived (MastodonResult Account)
    | AccountRelationship (MastodonResult (List Relationship))
    | AccountRelationships (MastodonResult (List Relationship))
    | AccountTimeline Bool (MastodonResult (List Status))
    | AccountUnfollowed (MastodonResult Relationship)
    | AppRegistered (MastodonResult AppRegistration)
    | AutoSearch (MastodonResult (List Account))
    | ContextLoaded Status (MastodonResult Context)
    | CurrentUser (MastodonResult Account)
    | FavoriteAdded (MastodonResult Status)
    | FavoriteRemoved (MastodonResult Status)
    | GlobalTimeline Bool (MastodonResult (List Status))
    | LocalTimeline Bool (MastodonResult (List Status))
    | Notifications Bool (MastodonResult (List Notification))
    | Reblogged (MastodonResult Status)
    | StatusDeleted (MastodonResult Int)
    | StatusPosted (MastodonResult Status)
    | Unreblogged (MastodonResult Status)
    | HomeTimeline Bool (MastodonResult (List Status))


type WebSocketMsg
    = NewWebsocketGlobalMessage String
    | NewWebsocketLocalMessage String
    | NewWebsocketUserMessage String


type Msg
    = AddFavorite Int
    | ClearError Int
    | CloseAccount
    | CloseAccountSelector
    | CloseThread
    | DeleteStatus Int
    | DraftEvent DraftMsg
    | FilterNotifications NotificationFilter
    | FollowAccount Int
    | LoadAccount Int
    | TimelineLoadNext String String
    | MastodonEvent MastodonMsg
    | NoOp
    | OpenThread Status
    | OpenAccountSelector
    | ReblogStatus Int
    | Register
    | RemoveFavorite Int
    | ScrollColumn ScrollDirection String
    | ServerChange String
    | SubmitDraft
    | SwitchClient Client
    | Tick Time
    | UnfollowAccount Int
    | UrlChange Navigation.Location
    | UseGlobalTimeline Bool
    | UnreblogStatus Int
    | ViewAccountFollowing Account
    | ViewAccountFollowers Account
    | ViewAccountStatuses Account
    | ViewerEvent ViewerMsg
    | WebSocketEvent WebSocketMsg


type CurrentView
    = -- Basically, what we should be displaying in the fourth column
      AccountFollowersView Account (Timeline Account)
    | AccountFollowingView Account (Timeline Account)
    | AccountView Account
    | AccountSelectorView
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


type alias Timeline a =
    { id : String
    , entries : List a
    , links : Links
    , loading : Bool
    }


type alias ErrorNotification =
    { message : String
    , time : Time
    }


type alias Model =
    { server : String
    , currentTime : Time
    , registration : Maybe AppRegistration
    , clients : List Client
    , homeTimeline : Timeline Status
    , localTimeline : Timeline Status
    , globalTimeline : Timeline Status
    , accountTimeline : Timeline Status
    , accountFollowers : Timeline Account
    , accountFollowing : Timeline Account
    , accountRelationships : List Relationship
    , accountRelationship : Maybe Relationship
    , notifications : Timeline NotificationAggregate
    , draft : Draft
    , errors : List ErrorNotification
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
