module Util exposing (..)


replace : String -> String -> String -> String
replace from to str =
    String.split from str |> String.join to
