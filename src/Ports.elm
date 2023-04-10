port module Ports exposing
    ( connectToWsServer
    , deleteRegistration
    , notify
    , saveClients
    , saveRegistration
    , scrollIntoView
    , setStatus
    , uploadError
    , uploadMedia
    , uploadSuccess
    , wsEvent
    )

-- Outgoing ports


port saveRegistration : String -> Cmd msg


port deleteRegistration : String -> Cmd msg


port saveClients : String -> Cmd msg


port setStatus : { id : String, status : String } -> Cmd msg


port scrollIntoView : String -> Cmd msg


port uploadMedia : { id : String, url : String, token : String } -> Cmd msg


port notify : { title : String, icon : String, body : String, clickUrl : String } -> Cmd msg


port connectToWsServer : { server : String, token : String, streamType : String, apiUrl : String } -> Cmd msg



-- Incoming ports


port uploadError : (String -> msg) -> Sub msg


port uploadSuccess : (String -> msg) -> Sub msg


port wsEvent : (String -> msg) -> Sub msg
