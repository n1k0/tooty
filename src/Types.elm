module Types exposing
    ( AccountInfo
    , AutocompleteType(..)
    , Confirm
    , CurrentAccountView(..)
    , CurrentView(..)
    , Draft
    , DraftMsg(..)
    , DraftType(..)
    , Emoji
    , ErrorNotification
    , Flags
    , InputInformation
    , KeyEvent(..)
    , KeyType(..)
    , MastodonMsg(..)
    , MastodonResult
    , Model
    , Msg(..)
    , NotificationFilter(..)
    , ScrollDirection(..)
    , ScrollElement(..)
    , Search
    , SearchMsg(..)
    , Thread
    , Timeline
    , Viewer
    , ViewerMsg(..)
    , WebSocketMsg(..)
    )

import Browser
import Browser.Navigation as Navigation
import EmojiPicker
import InfiniteScroll
import Mastodon.Http exposing (Links, Response)
import Mastodon.Model exposing (..)
import Menu
import Time exposing (Posix)
import Url


type alias Flags =
    { clients : String
    , registration : Maybe AppRegistration
    }


type DraftMsg
    = ClearDraft
    | CloseAutocomplete
    | EditStatus Status
    | EmojiMsg EmojiPicker.Msg
    | RemoveMedia String
    | ResetAutocomplete Bool
    | SaveAttachmentDescription String
    | SelectAutoItem String
    | SetAutoState Menu.Msg
    | ToggleSpoiler Bool
    | UpdateAttachmentDescription String String
    | UpdateCustomEmojis (List CustomEmoji)
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
    | NextAttachment
    | OpenViewer (List Attachment) Attachment
    | PrevAttachment


type alias MastodonResult a =
    Result Error (Response a)


type MastodonMsg
    = AccessToken (MastodonResult AccessTokenResult)
    | AccountFollowed Account (MastodonResult Relationship)
    | AccountFollowers (MastodonResult (List Account))
    | AccountFollowing (MastodonResult (List Account))
    | AccountBlocked Account (MastodonResult Relationship)
    | AccountMuted Account (MastodonResult Relationship)
    | AccountReceived (MastodonResult Account)
    | AccountRelationship (MastodonResult (List Relationship))
    | AccountRelationships (MastodonResult (List Relationship))
    | AccountTimeline (MastodonResult (List Status))
    | AccountUnfollowed Account (MastodonResult Relationship)
    | AccountUnblocked Account (MastodonResult Relationship)
    | AccountUnmuted Account (MastodonResult Relationship)
    | AppRegistered (MastodonResult AppRegistration)
    | AutoSearch (MastodonResult (List Account))
    | Blocks (MastodonResult (List Account))
    | CurrentUser (MastodonResult Account)
    | CustomEmojis (MastodonResult (List CustomEmoji))
    | FavoriteAdded (MastodonResult Status)
    | FavoriteRemoved (MastodonResult Status)
    | FavoriteTimeline (MastodonResult (List Status))
    | GlobalTimeline (MastodonResult (List Status))
    | HashtagTimeline (MastodonResult (List Status))
    | HomeTimeline (MastodonResult (List Status))
    | LocalTimeline (MastodonResult (List Status))
    | MediaUpdated (MastodonResult Status)
    | Mutes (MastodonResult (List Account))
    | Notifications (MastodonResult (List Notification))
    | Reblogged (MastodonResult Status)
    | SearchResultsReceived (MastodonResult SearchResults)
    | StatusDeleted (MastodonResult StatusId)
    | StatusPosted (MastodonResult Status)
    | StatusSourceFetched (MastodonResult StatusSource)
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


type KeyType
    = KeyCharacter Char
    | KeyControl String


type ScrollElement
    = ScrollContextualTimeline
    | ScrollHashtagTimeline
    | ScrollHomeTimeline
    | ScrollLocalTimeline
    | ScrollNotifications


type AutocompleteType
    = AccountAuto
    | EmojiAuto


type Msg
    = AddFavorite Status
    | AskConfirm String Msg Msg
    | Back
    | Block Account
    | ClearError Int
    | ClientNameChange String
    | ConfirmCancelled Msg
    | Confirmed Msg
    | DeleteStatus StatusId
    | DraftEvent DraftMsg
    | FilterNotifications NotificationFilter
    | FollowAccount Account
    | InfiniteScrollMsg ScrollElement InfiniteScroll.Msg
    | KeyMsg KeyEvent KeyType
    | LogoutClient Client
    | LinkClicked Browser.UrlRequest
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
    | Tick Posix
    | TimelineLoadNext String String
    | UnfollowAccount Account
    | Unblock Account
    | Unmute Account
    | UnreblogStatus Status
    | UrlChanged Url.Url
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


type DraftType
    = InReplyTo Status
    | Editing StatusEdit
    | NewDraft


type alias Emoji =
    { shortcode : String
    , value : String
    , imgUrl : Maybe String
    , keywords : List String
    }


type alias Draft =
    { status : String
    , statusSource : Maybe StatusSource
    , type_ : DraftType
    , spoilerText : Maybe String
    , sensitive : Bool
    , visibility : String
    , attachments : List Attachment
    , mediaUploading : Bool
    , statusLength : Int
    , autocompleteType : Maybe AutocompleteType

    -- Autocomplete values
    , autoState : Menu.State

    -- Index of the @ or : for the user/emoji autoComplete
    , autoStartPosition : Maybe Int
    , autoQuery : String
    , autoMaxResults : Int

    -- List of the accounts to display in autoComplete
    , autoAccounts : List Account

    -- List of the emojis to display in autoComplete
    , autoEmojis : List Emoji
    , showAutoMenu : Bool

    -- EmojiPicker state
    , emojiModel : EmojiPicker.Model
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
    , time : Posix
    }


type alias Model =
    { accountInfo : AccountInfo
    , blocks : Timeline Account
    , clientName : String
    , clients : List Client
    , confirm : Maybe Confirm
    , ctrlPressed : Bool
    , currentUser : Maybe Account
    , currentTime : Posix
    , currentView : CurrentView
    , customEmojis : List CustomEmoji
    , draft : Draft
    , errors : List ErrorNotification
    , favoriteTimeline : Timeline Status
    , globalTimeline : Timeline Status
    , hashtagTimeline : Timeline Status
    , homeTimeline : Timeline Status
    , infiniteScrollHashtag : InfiniteScroll.Model Msg
    , infiniteScrollHome : InfiniteScroll.Model Msg
    , infiniteScrollLocal : InfiniteScroll.Model Msg
    , infiniteScrollNotifications : InfiniteScroll.Model Msg
    , key : Navigation.Key
    , localTimeline : Timeline Status
    , location : Url.Url
    , mutes : Timeline Account
    , notificationFilter : NotificationFilter
    , rawNotifications : List Notification
    , notifications : Timeline NotificationAggregate
    , registration : Maybe AppRegistration
    , search : Search
    , server : String
    , viewer : Maybe Viewer
    }


type alias InputInformation =
    { status : String
    , selectionStart : Int
    }
