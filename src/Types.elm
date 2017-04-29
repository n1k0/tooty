module Types exposing (..)

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
    | UpdateStatus String
    | UpdateVisibility String
    | UpdateReplyTo Status
    | ToggleSpoiler Bool


type ViewerMsg
    = CloseViewer
    | OpenViewer (List Attachment) Attachment


type MastodonMsg
    = AccessToken (Result Error AccessTokenResult)
    | AccountFollowed (Result Error Account)
    | AccountFollowers (Result Error (List Account))
    | AccountFollowing (Result Error (List Account))
    | AccountReceived (Result Error Account)
    | AccountRelationships (Result Error (List Relationship))
    | AccountTimeline (Result Error (List Status))
    | AccountUnfollowed (Result Error Account)
    | AppRegistered (Result Error AppRegistration)
    | ContextLoaded Status (Result Error Context)
    | CurrentUser (Result Error Account)
    | FavoriteAdded (Result Error Status)
    | FavoriteRemoved (Result Error Status)
    | GlobalTimeline (Result Error (List Status))
    | LocalTimeline (Result Error (List Status))
    | Notifications (Result Error (List Notification))
    | Reblogged (Result Error Status)
    | StatusDeleted (Result Error Int)
    | StatusPosted (Result Error Status)
    | Unreblogged (Result Error Status)
    | UserTimeline (Result Error (List Status))


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
    | LoadAccount Int
    | MastodonEvent MastodonMsg
    | NoOp
    | OpenThread Status
    | ReblogStatus Int
    | Register
    | RemoveFavorite Int
    | ScrollColumn String
    | ServerChange String
    | SubmitDraft
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


type alias Draft =
    { status : String
    , in_reply_to : Maybe Status
    , spoiler_text : Maybe String
    , sensitive : Bool
    , visibility : String
    }


type alias Thread =
    { status : Status
    , context : Context
    }


type alias Viewer =
    { attachments : List Attachment
    , attachment : Attachment
    }


type CurrentView
    = -- Basically, what we should be displaying in the fourth column
      AccountFollowersView Account (List Account)
    | AccountFollowingView Account (List Account)
    | AccountView Account
    | GlobalTimelineView
    | LocalTimelineView
    | ThreadView Thread


type alias Model =
    { server : String
    , registration : Maybe AppRegistration
    , client : Maybe Client
    , userTimeline : List Status
    , localTimeline : List Status
    , globalTimeline : List Status
    , accountTimeline : List Status
    , accountFollowers : List Account
    , accountFollowing : List Account
    , accountRelationships : List Relationship
    , notifications : List NotificationAggregate
    , draft : Draft
    , errors : List String
    , location : Navigation.Location
    , useGlobalTimeline : Bool
    , viewer : Maybe Viewer
    , currentUser : Maybe Account
    , currentView : CurrentView
    }
