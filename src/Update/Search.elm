module Update.Search exposing (update)

import Command
import Types exposing (..)


update : SearchMsg -> Model -> ( Model, Cmd Msg )
update msg ({ search } as model) =
    case msg of
        SubmitSearch ->
            model ! [ Command.search (List.head model.clients) model.search.term ]

        UpdateSearch term ->
            { model | search = { search | term = term } } ! []
