port module Ports
    exposing
        ( saveRegistration
        , deleteRegistration
        , scrollIntoView
        , saveClients
        , setStatus
        )


port saveRegistration : String -> Cmd msg


port deleteRegistration : String -> Cmd msg


port saveClients : String -> Cmd msg


port setStatus : { id : String, status : String } -> Cmd msg


port scrollIntoView : String -> Cmd msg
