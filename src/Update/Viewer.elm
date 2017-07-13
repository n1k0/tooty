module Update.Viewer exposing (getPrevNext, update)

import List.Extra exposing (elemIndex, getAt)
import Mastodon.Model exposing (..)
import Types exposing (..)


getPrevNext : Viewer -> ( Maybe Attachment, Maybe Attachment )
getPrevNext { attachments, attachment } =
    let
        index =
            Maybe.withDefault -1 <| elemIndex attachment attachments
    in
        ( getAt (index - 1) attachments, getAt (index + 1) attachments )


update : ViewerMsg -> Maybe Viewer -> ( Maybe Viewer, Cmd Msg )
update viewerMsg viewer =
    case viewerMsg of
        CloseViewer ->
            Nothing ! []

        OpenViewer attachments attachment ->
            (Just <| Viewer attachments attachment) ! []

        PrevAttachment ->
            case viewer of
                Just viewer ->
                    case getPrevNext viewer of
                        ( Just prev, _ ) ->
                            (Just <| Viewer viewer.attachments prev) ! []

                        _ ->
                            Just viewer ! []

                Nothing ->
                    viewer ! []

        NextAttachment ->
            case viewer of
                Just viewer ->
                    case getPrevNext viewer of
                        ( _, Just next ) ->
                            (Just <| Viewer viewer.attachments next) ! []

                        _ ->
                            Just viewer ! []

                Nothing ->
                    viewer ! []
