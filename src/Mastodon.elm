module Mastodon
    exposing
        ( AccessTokenResult
        , Account
        , AppRegistration
        , Attachment
        , Client
        , Error(..)
        , Mention
        , Notification
        , NotificationAggregate
        , Reblog(..)
        , Status
        , StatusRequestBody
        , StreamType(..)
        , Tag
        , WebSocketEventResult(..)
        , reblog
        , unreblog
        , favourite
        , unfavourite
        , extractReblog
        , register
        , registrationEncoder
        , aggregateNotifications
        , clientEncoder
        , decodeWebSocketMessage
        , getAuthorizationUrl
        , getAccessToken
        , fetchAccount
        , fetchLocalTimeline
        , fetchNotifications
        , fetchPublicTimeline
        , fetchUserTimeline
        , postStatus
        , send
        , subscribeToWebSockets
        , websocketEventDecoder
        , notificationDecoder
        , addNotificationToAggregates
        )

import Http
import HttpBuilder
import Json.Decode.Pipeline as Pipe
import Json.Decode as Decode
import Json.Encode as Encode
import Util
import WebSocket
import List.Extra exposing (groupWhile)


-- Types


type alias AccountId =
    Int


type alias AuthCode =
    String


type alias ClientId =
    String


type alias ClientSecret =
    String


type alias Server =
    String


type alias StatusCode =
    Int


type alias StatusMsg =
    String


type alias Token =
    String


type alias Client =
    { server : Server
    , token : Token
    }


type alias WebSocketEvent =
    { event : String
    , payload : String
    }


type Error
    = MastodonError StatusCode StatusMsg String
    | ServerError StatusCode StatusMsg String
    | TimeoutError
    | NetworkError


type alias AppRegistration =
    { server : Server
    , scope : String
    , client_id : ClientId
    , client_secret : ClientSecret
    , id : Int
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


type alias Attachment =
    -- type_: -- "image", "video", "gifv"
    { id : Int
    , type_ : String
    , url : String
    , remote_url : String
    , preview_url : String
    , text_url : Maybe String
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
    { id : Int
    , type_ : String
    , created_at : String
    , account : Account
    , status : Maybe Status
    }


type alias NotificationAggregate =
    { type_ : String
    , status : Maybe Status
    , accounts : List Account
    , created_at : String
    }


type alias Tag =
    { name : String
    , url : String
    }


type alias Status =
    { account : Account
    , content : String
    , created_at : String
    , favourited : Maybe Bool
    , favourites_count : Int
    , id : Int
    , in_reply_to_account_id : Maybe Int
    , in_reply_to_id : Maybe Int
    , media_attachments : List Attachment
    , mentions : List Mention
    , reblog : Maybe Reblog
    , reblogged : Maybe Bool
    , reblogs_count : Int
    , sensitive : Maybe Bool
    , spoiler_text : String
    , tags : List Tag
    , uri : String
    , url : String
    , visibility : String
    }


type Reblog
    = Reblog Status


type alias StatusRequestBody =
    -- status: The text of the status
    -- in_reply_to_id: local ID of the status you want to reply to
    -- sensitive: set this to mark the media of the status as NSFW
    -- spoiler_text: text to be shown as a warning before the actual content
    -- visibility: either "direct", "private", "unlisted" or "public"
    -- TODO: media_ids: array of media IDs to attach to the status (maximum 4)
    { status : String
    , in_reply_to_id : Maybe Int
    , spoiler_text : Maybe String
    , sensitive : Bool
    , visibility : String
    }


type alias Request a =
    HttpBuilder.RequestBuilder a


type WebSocketEventResult a b c
    = EventError a
    | NotificationResult b
    | StatusResult c


type StreamType
    = UserStream
    | LocalPublicStream
    | GlobalPublicStream



-- Msg


type StatusListResult
    = Result Http.Error (List Status)


type alias AccessTokenResult =
    { server : Server
    , accessToken : Token
    }



-- Encoders


appRegistrationEncoder : String -> String -> String -> String -> Encode.Value
appRegistrationEncoder client_name redirect_uris scope website =
    Encode.object
        [ ( "client_name", Encode.string client_name )
        , ( "redirect_uris", Encode.string redirect_uris )
        , ( "scopes", Encode.string scope )
        , ( "website", Encode.string website )
        ]


authorizationCodeEncoder : AppRegistration -> AuthCode -> Encode.Value
authorizationCodeEncoder registration authCode =
    Encode.object
        [ ( "client_id", Encode.string registration.client_id )
        , ( "client_secret", Encode.string registration.client_secret )
        , ( "grant_type", Encode.string "authorization_code" )
        , ( "redirect_uri", Encode.string registration.redirect_uri )
        , ( "code", Encode.string authCode )
        ]


statusRequestBodyEncoder : StatusRequestBody -> Encode.Value
statusRequestBodyEncoder statusData =
    Encode.object
        [ ( "status", Encode.string statusData.status )
        , ( "in_reply_to_id", encodeMaybe Encode.int statusData.in_reply_to_id )
        , ( "spoiler_text", encodeMaybe Encode.string statusData.spoiler_text )
        , ( "sensitive", Encode.bool statusData.sensitive )
        , ( "visibility", Encode.string statusData.visibility )
        ]



-- Decoders


appRegistrationDecoder : Server -> String -> Decode.Decoder AppRegistration
appRegistrationDecoder server scope =
    Pipe.decode AppRegistration
        |> Pipe.hardcoded server
        |> Pipe.hardcoded scope
        |> Pipe.required "client_id" Decode.string
        |> Pipe.required "client_secret" Decode.string
        |> Pipe.required "id" Decode.int
        |> Pipe.required "redirect_uri" Decode.string


accessTokenDecoder : AppRegistration -> Decode.Decoder AccessTokenResult
accessTokenDecoder registration =
    Pipe.decode AccessTokenResult
        |> Pipe.hardcoded registration.server
        |> Pipe.required "access_token" Decode.string


accountDecoder : Decode.Decoder Account
accountDecoder =
    Pipe.decode Account
        |> Pipe.required "acct" Decode.string
        |> Pipe.required "avatar" Decode.string
        |> Pipe.required "created_at" Decode.string
        |> Pipe.required "display_name" Decode.string
        |> Pipe.required "followers_count" Decode.int
        |> Pipe.required "following_count" Decode.int
        |> Pipe.required "header" Decode.string
        |> Pipe.required "id" Decode.int
        |> Pipe.required "locked" Decode.bool
        |> Pipe.required "note" Decode.string
        |> Pipe.required "statuses_count" Decode.int
        |> Pipe.required "url" Decode.string
        |> Pipe.required "username" Decode.string


attachmentDecoder : Decode.Decoder Attachment
attachmentDecoder =
    Pipe.decode Attachment
        |> Pipe.required "id" Decode.int
        |> Pipe.required "type" Decode.string
        |> Pipe.required "url" Decode.string
        |> Pipe.required "remote_url" Decode.string
        |> Pipe.required "preview_url" Decode.string
        |> Pipe.required "text_url" (Decode.nullable Decode.string)


mentionDecoder : Decode.Decoder Mention
mentionDecoder =
    Pipe.decode Mention
        |> Pipe.required "id" Decode.int
        |> Pipe.required "url" Decode.string
        |> Pipe.required "username" Decode.string
        |> Pipe.required "acct" Decode.string


notificationDecoder : Decode.Decoder Notification
notificationDecoder =
    Pipe.decode Notification
        |> Pipe.required "id" Decode.int
        |> Pipe.required "type" Decode.string
        |> Pipe.required "created_at" Decode.string
        |> Pipe.required "account" accountDecoder
        |> Pipe.optional "status" (Decode.nullable statusDecoder) Nothing


tagDecoder : Decode.Decoder Tag
tagDecoder =
    Pipe.decode Tag
        |> Pipe.required "name" Decode.string
        |> Pipe.required "url" Decode.string


reblogDecoder : Decode.Decoder Reblog
reblogDecoder =
    Decode.map Reblog (Decode.lazy (\_ -> statusDecoder))


statusDecoder : Decode.Decoder Status
statusDecoder =
    Pipe.decode Status
        |> Pipe.required "account" accountDecoder
        |> Pipe.required "content" Decode.string
        |> Pipe.required "created_at" Decode.string
        |> Pipe.optional "favourited" (Decode.nullable Decode.bool) Nothing
        |> Pipe.required "favourites_count" Decode.int
        |> Pipe.required "id" Decode.int
        |> Pipe.required "in_reply_to_account_id" (Decode.nullable Decode.int)
        |> Pipe.required "in_reply_to_id" (Decode.nullable Decode.int)
        |> Pipe.required "media_attachments" (Decode.list attachmentDecoder)
        |> Pipe.required "mentions" (Decode.list mentionDecoder)
        |> Pipe.optional "reblog" (Decode.nullable reblogDecoder) Nothing
        |> Pipe.optional "reblogged" (Decode.nullable Decode.bool) Nothing
        |> Pipe.required "reblogs_count" Decode.int
        |> Pipe.required "sensitive" (Decode.nullable Decode.bool)
        |> Pipe.required "spoiler_text" Decode.string
        |> Pipe.required "tags" (Decode.list tagDecoder)
        |> Pipe.required "uri" Decode.string
        |> Pipe.required "url" Decode.string
        |> Pipe.required "visibility" Decode.string


websocketEventDecoder : Decode.Decoder WebSocketEvent
websocketEventDecoder =
    Pipe.decode WebSocketEvent
        |> Pipe.required "event" Decode.string
        |> Pipe.required "payload" Decode.string



-- Internal helpers


encodeMaybe : (a -> Encode.Value) -> Maybe a -> Encode.Value
encodeMaybe encode thing =
    case thing of
        Nothing ->
            Encode.null

        Just value ->
            encode value


encodeUrl : String -> List ( String, String ) -> String
encodeUrl base params =
    List.map (\( k, v ) -> k ++ "=" ++ Http.encodeUri v) params
        |> String.join "&"
        |> (++) (base ++ "?")


mastodonErrorDecoder : Decode.Decoder String
mastodonErrorDecoder =
    Decode.field "error" Decode.string


extractMastodonError : StatusCode -> StatusMsg -> String -> Error
extractMastodonError statusCode statusMsg body =
    case Decode.decodeString mastodonErrorDecoder body of
        Ok errRecord ->
            MastodonError statusCode statusMsg errRecord

        Err err ->
            ServerError statusCode statusMsg err


extractError : Http.Error -> Error
extractError error =
    case error of
        Http.BadStatus { status, body } ->
            extractMastodonError status.code status.message body

        Http.BadPayload str { status } ->
            ServerError
                status.code
                status.message
                ("Failed decoding JSON: " ++ str)

        Http.Timeout ->
            TimeoutError

        _ ->
            NetworkError


extractReblog : Status -> Status
extractReblog status =
    case status.reblog of
        Just (Reblog reblog) ->
            reblog

        Nothing ->
            status


toResponse : Result Http.Error a -> Result Error a
toResponse result =
    Result.mapError extractError result


fetch : Client -> String -> Decode.Decoder a -> Request a
fetch client endpoint decoder =
    HttpBuilder.get (client.server ++ endpoint)
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson decoder)



-- Public API


addNotificationToAggregates : Notification -> List NotificationAggregate -> List NotificationAggregate
addNotificationToAggregates notification aggregates =
    -- @FIXME: WIP
    aggregates
        |> List.map
            (\aggregate ->
                case aggregate.type_ of
                    "mention" ->
                        aggregate

                    "follow" ->
                        { aggregate | accounts = notification.account :: aggregate.accounts }

                    "reblog" ->
                        aggregate

                    "favorite" ->
                        aggregate

                    _ ->
                        aggregate
            )


aggregateNotifications : List Notification -> List NotificationAggregate
aggregateNotifications notifications =
    let
        only type_ notifications =
            List.filter (\n -> n.type_ == type_) notifications

        sameStatus n1 n2 =
            case ( n1.status, n2.status ) of
                ( Just r1, Just r2 ) ->
                    r1.id == r2.id

                _ ->
                    False

        extractAggregate statusGroup =
            let
                accounts =
                    List.map .account statusGroup
            in
                case statusGroup of
                    notification :: _ ->
                        [ NotificationAggregate
                            notification.type_
                            notification.status
                            accounts
                            notification.created_at
                        ]

                    [] ->
                        []

        aggregate statusGroups =
            List.map extractAggregate statusGroups |> List.concat
    in
        [ notifications |> only "reblog" |> groupWhile sameStatus |> aggregate
        , notifications |> only "favourite" |> groupWhile sameStatus |> aggregate
        , notifications |> only "mention" |> groupWhile sameStatus |> aggregate
        , notifications |> only "follow" |> groupWhile (\_ _ -> True) |> aggregate
        ]
            |> List.concat
            |> List.sortBy .created_at
            |> List.reverse


clientEncoder : Client -> Encode.Value
clientEncoder client =
    Encode.object
        [ ( "server", Encode.string client.server )
        , ( "token", Encode.string client.token )
        ]


registrationEncoder : AppRegistration -> Encode.Value
registrationEncoder registration =
    Encode.object
        [ ( "server", Encode.string registration.server )
        , ( "scope", Encode.string registration.scope )
        , ( "client_id", Encode.string registration.client_id )
        , ( "client_secret", Encode.string registration.client_secret )
        , ( "id", Encode.int registration.id )
        , ( "redirect_uri", Encode.string registration.redirect_uri )
        ]


register : Server -> String -> String -> String -> String -> Request AppRegistration
register server client_name redirect_uri scope website =
    HttpBuilder.post (server ++ "/api/v1/apps")
        |> HttpBuilder.withExpect (Http.expectJson (appRegistrationDecoder server scope))
        |> HttpBuilder.withJsonBody (appRegistrationEncoder client_name redirect_uri scope website)


getAuthorizationUrl : AppRegistration -> String
getAuthorizationUrl registration =
    encodeUrl (registration.server ++ "/oauth/authorize")
        [ ( "response_type", "code" )
        , ( "client_id", registration.client_id )
        , ( "scope", registration.scope )
        , ( "redirect_uri", registration.redirect_uri )
        ]


getAccessToken : AppRegistration -> AuthCode -> Request AccessTokenResult
getAccessToken registration authCode =
    HttpBuilder.post (registration.server ++ "/oauth/token")
        |> HttpBuilder.withExpect (Http.expectJson (accessTokenDecoder registration))
        |> HttpBuilder.withJsonBody (authorizationCodeEncoder registration authCode)


send : (Result Error a -> msg) -> Request a -> Cmd msg
send tagger builder =
    builder |> HttpBuilder.send (toResponse >> tagger)


fetchAccount : Client -> AccountId -> Request Account
fetchAccount client accountId =
    fetch client ("/api/v1/accounts/" ++ (toString accountId)) accountDecoder


fetchUserTimeline : Client -> Request (List Status)
fetchUserTimeline client =
    fetch client "/api/v1/timelines/home" <| Decode.list statusDecoder


fetchLocalTimeline : Client -> Request (List Status)
fetchLocalTimeline client =
    fetch client "/api/v1/timelines/public?local=true" <| Decode.list statusDecoder


fetchPublicTimeline : Client -> Request (List Status)
fetchPublicTimeline client =
    fetch client "/api/v1/timelines/public" <| Decode.list statusDecoder


fetchNotifications : Client -> Request (List Notification)
fetchNotifications client =
    fetch client "/api/v1/notifications" <| Decode.list notificationDecoder


postStatus : Client -> StatusRequestBody -> Request Status
postStatus client statusRequestBody =
    HttpBuilder.post (client.server ++ "/api/v1/statuses")
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson statusDecoder)
        |> HttpBuilder.withJsonBody (statusRequestBodyEncoder statusRequestBody)


reblog : Client -> Int -> Request Status
reblog client id =
    HttpBuilder.post (client.server ++ "/api/v1/statuses/" ++ (toString id) ++ "/reblog")
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson statusDecoder)


unreblog : Client -> Int -> Request Status
unreblog client id =
    HttpBuilder.post (client.server ++ "/api/v1/statuses/" ++ (toString id) ++ "/unreblog")
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson statusDecoder)


favourite : Client -> Int -> Request Status
favourite client id =
    HttpBuilder.post (client.server ++ "/api/v1/statuses/" ++ (toString id) ++ "/favourite")
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson statusDecoder)


unfavourite : Client -> Int -> Request Status
unfavourite client id =
    HttpBuilder.post (client.server ++ "/api/v1/statuses/" ++ (toString id) ++ "/unfavourite")
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson statusDecoder)


subscribeToWebSockets : Client -> StreamType -> (String -> a) -> Sub a
subscribeToWebSockets client streamType message =
    let
        type_ =
            case streamType of
                UserStream ->
                    "user"

                LocalPublicStream ->
                    "public:local"

                GlobalPublicStream ->
                    "public:local"

        url =
            (Util.replace "https" "wss" client.server)
                ++ "/api/v1/streaming/?access_token="
                ++ client.token
                ++ "&stream="
                ++ type_
    in
        WebSocket.listen url message



{-
   Sorry for this beast, but the websocket connection return messages
   containing an escaped JSON string under the `payload` key. This JSON string
   can either represent a `Notification` when the event field of the returned json
   is equal to 'notification' or a `Status` when the string is equal to
   'update'.
   If someone has a better way of doing this, I'me all for it
-}


decodeWebSocketMessage : String -> WebSocketEventResult String (Result String Notification) (Result String Status)
decodeWebSocketMessage message =
    let
        websocketEvent =
            Decode.decodeString
                websocketEventDecoder
                message
    in
        case websocketEvent of
            Ok event ->
                if event.event == "notification" then
                    NotificationResult
                        (Decode.decodeString
                            notificationDecoder
                            event.payload
                        )
                else if event.event == "update" then
                    StatusResult
                        (Decode.decodeString
                            statusDecoder
                            event.payload
                        )
                else
                    EventError "Unknown event type for WebSocket"

            Err error ->
                EventError error
