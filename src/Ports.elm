port module Ports exposing (saveRegistration, saveClient, setStatus)


port saveRegistration : String -> Cmd msg


port saveClient : String -> Cmd msg


port setStatus : { id : String, status : String } -> Cmd msg
