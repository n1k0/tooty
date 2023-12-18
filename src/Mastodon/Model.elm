module Mastodon.Model exposing
    ( AccessTokenResult
    , Account
    , AccountNotificationDate
    , AppRegistration
    , Application
    , Attachment
    , Client
    , Context
    , Error(..)
    , Hashtag
    , HashtagHistory
    , Mention
    , Notification
    , NotificationAggregate
    , Reblog(..)
    , Relationship
    , SearchResults
    , Status
    , StatusEdit
    , StatusEditRequestBody
    , StatusId(..)
    , StatusRequestBody
    , StatusSource
    , Tag
    )


type alias AccountId =
    String


type alias ClientId =
    String


type alias ClientSecret =
    String


type alias Server =
    String


type StatusId
    = StatusId String


type alias StatusCode =
    Int


type alias StatusMsg =
    String


type alias Token =
    String


type Error
    = MastodonError StatusCode StatusMsg String
    | ServerError StatusCode StatusMsg String
    | TimeoutError
    | NetworkError


type alias AccessTokenResult =
    { server : Server
    , accessToken : Token
    }


type alias AppRegistration =
    { server : Server
    , scope : String
    , client_id : ClientId
    , client_secret : ClientSecret
    , id : String
    , redirect_uri : String
    }


type alias Account =
    { acct : String
    , avatar : String
    , created_at : String
    , display_name : String
    , followers_count : Int
    , following_count : Int
    , header : String
    , id : AccountId
    , locked : Bool
    , note : String
    , statuses_count : Int
    , url : String
    , username : String
    }


type alias Application =
    { name : String
    , website : Maybe String
    }


type alias Attachment =
    -- type_: -- "image", "video", "gifv"
    { id : String
    , type_ : String
    , url : String
    , remote_url : String
    , preview_url : Maybe String
    , text_url : Maybe String
    , description : Maybe String
    }


type alias Client =
    { server : Server
    , token : Token
    , account : Maybe Account
    }


type alias Context =
    { ancestors : List Status
    , descendants : List Status
    }


type alias Mention =
    { id : AccountId
    , url : String
    , username : String
    , acct : String
    }


type alias Notification =
    {-
       - id: The notification ID
       - type_: One of: "mention", "reblog", "favourite", "follow"
       - created_at: The time the notification was created
       - account: The Account sending the notification to the user
       - status: The Status associated with the notification, if applicable
    -}
    { id : String
    , type_ : String
    , created_at : String
    , account : Account
    , status : Maybe Status
    }


type alias AccountNotificationDate =
    { account : Account
    , created_at : String
    }


type alias NotificationAggregate =
    { id : String
    , type_ : String
    , status : Maybe Status
    , accounts : List AccountNotificationDate
    , created_at : String
    }


type Reblog
    = Reblog Status


type alias Relationship =
    { id : String
    , blocking : Bool
    , followed_by : Bool
    , following : Bool
    , muting : Bool
    , requested : Bool
    }


type alias SearchResults =
    { accounts : List Account
    , statuses : List Status
    , hashtags : List Hashtag
    }


type alias Status =
    { account : Account
    , application : Maybe Application
    , content : String
    , created_at : String
    , edited_at : Maybe String
    , favourited : Maybe Bool
    , favourites_count : Int
    , id : StatusId
    , in_reply_to_account_id : Maybe String
    , in_reply_to_id : Maybe StatusId
    , media_attachments : List Attachment
    , mentions : List Mention
    , reblog : Maybe Reblog
    , reblogged : Maybe Bool
    , reblogs_count : Int
    , sensitive : Maybe Bool
    , spoiler_text : String
    , tags : List Tag
    , uri : String
    , url : Maybe String
    , visibility : String
    }


type alias StatusSource =
    { id : StatusId
    , text : String
    , spoiler_text : String
    }


type alias StatusEdit =
    { status : Status
    , text : Maybe String
    , spoiler_text : Maybe String
    }


type alias StatusRequestBody =
    -- status: The text of the status
    -- in_reply_to_id: local ID of the status you want to reply to
    -- sensitive: set this to mark the media of the status as NSFW
    -- spoiler_text: text to be shown as a warning before the actual content
    -- visibility: either "direct", "private", "unlisted" or "public"
    { status : String
    , in_reply_to_id : Maybe StatusId
    , spoiler_text : Maybe String
    , sensitive : Bool
    , visibility : String
    , media_ids : List String
    }


type alias StatusEditRequestBody =
    -- status: The text of the status
    -- sensitive: set this to mark the media of the status as NSFW
    -- spoiler_text: text to be shown as a warning before the actual content
    { status : String
    , spoiler_text : Maybe String
    , sensitive : Bool
    , media_ids : List String
    }


type alias Tag =
    { name : String
    , url : String
    }


type alias HashtagHistory =
    { day : String
    , uses : String
    , accounts : String
    }


type alias Hashtag =
    { name : String
    , url : String
    , history : List HashtagHistory
    }
