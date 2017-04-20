port module Ports exposing (saveRegistration, saveClient)


port saveRegistration : String -> Cmd msg


port saveClient : String -> Cmd msg
