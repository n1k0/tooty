port module Ports
    exposing
        ( saveRegistration
        , deleteRegistration
        , scrollIntoView
        , saveClients
        , setStatus
        , uploadMedia
        , uploadSuccess
        , uploadError
        )

-- Outgoing ports


port saveRegistration : String -> Cmd msg


port deleteRegistration : String -> Cmd msg


port saveClients : String -> Cmd msg


port setStatus : { id : String, status : String } -> Cmd msg


port scrollIntoView : String -> Cmd msg


port uploadMedia : { id : String, url : String, token : String } -> Cmd msg



-- Incoming ports


port uploadError : (String -> msg) -> Sub msg


port uploadSuccess : (String -> msg) -> Sub msg
