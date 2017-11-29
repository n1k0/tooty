module Types exposing (..)

import Autocomplete
import Keyboard
import Mastodon.Http exposing (Response, Links)
import Mastodon.Model exposing (..)
import Navigation
import Time exposing (Time)


type alias Flags =
    { clients : String
    , registration : Maybe AppRegistration
    }


type DraftMsg
    = ClearDraft
    | CloseAutocomplete
    | RemoveMedia String
    | ResetAutocomplete Bool
    | SelectAccount String
    | SetAutoState Autocomplete.Msg
    | ToggleSpoiler Bool
    | UpdateInputInformation InputInformation
    | UpdateSensitive Bool
    | UpdateSpoiler String
    | UpdateVisibility String
    | UpdateReplyTo Status
    | UploadError String
    | UploadMedia String
    | UploadResult String


type ViewerMsg
    = CloseViewer
    | OpenViewer (List Attachment) Attachment
    | PrevAttachment
    | NextAttachment


type alias MastodonResult a =
    Result Error (Response a)


type MastodonMsg
    = AccessToken (MastodonResult AccessTokenResult)
    | AccountFollowed Account (MastodonResult Relationship)
    | AccountFollowers Bool (MastodonResult (List Account))
    | AccountFollowing Bool (MastodonResult (List Account))
    | AccountBlocked Account (MastodonResult Relationship)
    | AccountMuted Account (MastodonResult Relationship)
    | AccountReceived (MastodonResult Account)
    | AccountRelationship (MastodonResult (List Relationship))
    | AccountRelationships (MastodonResult (List Relationship))
    | AccountTimeline Bool (MastodonResult (List Status))
    | AccountUnfollowed Account (MastodonResult Relationship)
    | AccountUnblocked Account (MastodonResult Relationship)
    | AccountUnmuted Account (MastodonResult Relationship)
    | AppRegistered (MastodonResult AppRegistration)
    | AutoSearch (MastodonResult (List Account))
    | Blocks Bool (MastodonResult (List Account))
    | CurrentUser (MastodonResult Account)
    | FavoriteAdded (MastodonResult Status)
    | FavoriteRemoved (MastodonResult Status)
    | FavoriteTimeline Bool (MastodonResult (List Status))
    | GlobalTimeline Bool (MastodonResult (List Status))
    | HashtagTimeline Bool (MastodonResult (List Status))
    | HomeTimeline Bool (MastodonResult (List Status))
    | LocalTimeline Bool (MastodonResult (List Status))
    | Mutes Bool (MastodonResult (List Account))
    | Notifications Bool (MastodonResult (List Notification))
    | Reblogged (MastodonResult Status)
    | SearchResultsReceived (MastodonResult SearchResults)
    | StatusDeleted (MastodonResult StatusId)
    | StatusPosted (MastodonResult Status)
    | ThreadStatusLoaded StatusId (MastodonResult Status)
    | ThreadContextLoaded StatusId (MastodonResult Context)
    | Unreblogged (MastodonResult Status)


type SearchMsg
    = SubmitSearch
    | UpdateSearch String


type WebSocketMsg
    = NewWebsocketGlobalMessage String
    | NewWebsocketLocalMessage String
    | NewWebsocketUserMessage String


type KeyEvent
    = KeyUp
    | KeyDown


type Msg
    = AddFavorite Status
    | AskConfirm String Msg Msg
    | Back
    | Block Account
    | ClearError Int
    | ConfirmCancelled Msg
    | Confirmed Msg
    | DeleteStatus StatusId
    | DraftEvent DraftMsg
    | FilterNotifications NotificationFilter
    | FollowAccount Account
    | KeyMsg KeyEvent Keyboard.KeyCode
    | LogoutClient Client
    | TimelineLoadNext String String
    | MastodonEvent MastodonMsg
    | Mute Account
    | Navigate String
    | NoOp
    | OpenThread Status
    | ReblogStatus Status
    | Register
    | RemoveFavorite Status
    | ScrollColumn ScrollDirection String
    | SearchEvent SearchMsg
    | ServerChange String
    | SubmitDraft
    | SwitchClient Client
    | Tick Time
    | UnfollowAccount Account
    | Unblock Account
    | Unmute Account
    | UnreblogStatus Status
    | UrlChange Navigation.Location
    | ViewerEvent ViewerMsg
    | WebSocketEvent WebSocketMsg


type alias AccountInfo =
    { account : Maybe Account
    , timeline : Timeline Status
    , followers : Timeline Account
    , following : Timeline Account
    , relationships : List Relationship
    , relationship : Maybe Relationship
    }


type alias Confirm =
    { message : String
    , onConfirm : Msg
    , onCancel : Msg
    }


type CurrentView
    = -- Basically, what we should be displaying in the fourth column
      AccountView CurrentAccountView
    | AccountSelectorView
    | BlocksView
    | FavoriteTimelineView
    | GlobalTimelineView
    | HashtagView String
    | LocalTimelineView
    | MutesView
    | SearchView
    | ThreadView Thread


type CurrentAccountView
    = AccountStatusesView
    | AccountFollowersView
    | AccountFollowingView


type alias Draft =
    { status : String
    , inReplyTo : Maybe Status
    , spoilerText : Maybe String
    , sensitive : Bool
    , visibility : String
    , attachments : List Attachment
    , mediaUploading : Bool
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
    | NotificationOnlyDirect
    | NotificationOnlyBoosts
    | NotificationOnlyFavourites
    | NotificationOnlyFollows


type ScrollDirection
    = ScrollTop
    | ScrollBottom


type alias Search =
    { term : String
    , results : Maybe SearchResults
    }


type alias Thread =
    { status : Maybe Status
    , context : Maybe Context
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
    , favoriteTimeline : Timeline Status
    , hashtagTimeline : Timeline Status
    , mutes : Timeline Account
    , blocks : Timeline Account
    , accountInfo : AccountInfo
    , notifications : Timeline NotificationAggregate
    , draft : Draft
    , errors : List ErrorNotification
    , location : Navigation.Location
    , viewer : Maybe Viewer
    , currentUser : Maybe Account
    , currentView : CurrentView
    , notificationFilter : NotificationFilter
    , confirm : Maybe Confirm
    , search : Search
    , ctrlPressed : Bool
    }


type alias InputInformation =
    { status : String
    , selectionStart : Int
    }
