module Update.Viewer exposing (update)

import Types exposing (..)


update : ViewerMsg -> Maybe Viewer -> ( Maybe Viewer, Cmd Msg )
update viewerMsg viewer =
    case viewerMsg of
        CloseViewer ->
            Nothing ! []

        OpenViewer attachments attachment ->
            (Just <| Viewer attachments attachment) ! []
