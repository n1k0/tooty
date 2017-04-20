module Mastodon
    exposing
        ( AccessTokenResult
        , Account
        , AppRegistration
        , Attachment
        , Client
        , Error(..)
        , Mention
        , Reblog(..)
        , Status
        , Tag
        , register
        , registrationEncoder
        , clientEncoder
        , getAuthorizationUrl
        , getAccessToken
        , fetchPublicTimeline
        , fetchLocalTimeline
        , fetchUserTimeline
        , send
        )

import Http
import HttpBuilder
import Json.Decode.Pipeline as Pipe
import Json.Decode as Decode
import Json.Encode as Encode


-- Types


type alias Server =
    String


type alias AuthCode =
    String


type alias ClientId =
    String


type alias ClientSecret =
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
    , id : Int
    , locked : Bool
    , note : String
    , statuses_count : Int
    , url : String
    , username : String
    }


type alias Attachment =
    { id : Int
    , -- Type: "image", "video", "gifv"
      type_ : String
    , url : String
    , remote_url : String
    , preview_url : String
    , text_url : Maybe String
    }


type alias Mention =
    { id : Int
    , url : String
    , username : String
    , acct : String
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


type alias StatusPostData =
    { status : String
    }



-- Msg


type StatusListResult
    = Result Http.Error (List Status)


type alias AccessTokenResult =
    { server : Server
    , accessToken : Token
    }



-- Encoders


appRegistrationEncoder : String -> String -> String -> Encode.Value
appRegistrationEncoder client_name redirect_uris scope =
    Encode.object
        [ ( "client_name", Encode.string client_name )
        , ( "redirect_uris", Encode.string redirect_uris )
        , ( "scopes", Encode.string scope )
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


statusEncoder : StatusPostData -> Encode.Value
statusEncoder statusData =
    -- status: The text of the status
    -- in_reply_to_id (optional): local ID of the status you want to reply to
    -- media_ids (optional): array of media IDs to attach to the status (maximum 4)
    -- sensitive (optional): set this to mark the media of the status as NSFW
    -- spoiler_text (optional): text to be shown as a warning before the actual content
    -- visibility (optional): either "direct", "private", "unlisted" or "public"
    Encode.object [ ( "status", Encode.string statusData.status ) ]



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



-- Internal helpers


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


toResponse : Result Http.Error a -> Result Error a
toResponse result =
    Result.mapError extractError result


fetchStatusList : Client -> String -> HttpBuilder.RequestBuilder (List Status)
fetchStatusList client endpoint =
    HttpBuilder.get (client.server ++ endpoint)
        |> HttpBuilder.withHeader "Authorization" ("Bearer " ++ client.token)
        |> HttpBuilder.withExpect (Http.expectJson (Decode.list statusDecoder))



-- Public API


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


register : Server -> String -> String -> String -> HttpBuilder.RequestBuilder AppRegistration
register server client_name redirect_uri scope =
    HttpBuilder.post (server ++ "/api/v1/apps")
        |> HttpBuilder.withExpect (Http.expectJson (appRegistrationDecoder server scope))
        |> HttpBuilder.withJsonBody (appRegistrationEncoder client_name redirect_uri scope)


getAuthorizationUrl : AppRegistration -> String
getAuthorizationUrl registration =
    encodeUrl (registration.server ++ "/oauth/authorize")
        [ ( "response_type", "code" )
        , ( "client_id", registration.client_id )
        , ( "scope", registration.scope )
        , ( "redirect_uri", registration.redirect_uri )
        ]


getAccessToken : AppRegistration -> AuthCode -> HttpBuilder.RequestBuilder AccessTokenResult
getAccessToken registration authCode =
    HttpBuilder.post (registration.server ++ "/oauth/token")
        |> HttpBuilder.withExpect (Http.expectJson (accessTokenDecoder registration))
        |> HttpBuilder.withJsonBody (authorizationCodeEncoder registration authCode)


send : (Result Error a -> msg) -> HttpBuilder.RequestBuilder a -> Cmd msg
send tagger builder =
    builder |> HttpBuilder.send (toResponse >> tagger)


fetchUserTimeline : Client -> HttpBuilder.RequestBuilder (List Status)
fetchUserTimeline client =
    fetchStatusList client "/api/v1/timelines/home"


fetchLocalTimeline : Client -> HttpBuilder.RequestBuilder (List Status)
fetchLocalTimeline client =
    fetchStatusList client "/api/v1/timelines/public?local=true"


fetchPublicTimeline : Client -> HttpBuilder.RequestBuilder (List Status)
fetchPublicTimeline client =
    fetchStatusList client "/api/v1/timelines/public"
