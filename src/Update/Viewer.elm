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
            ( Nothing
            , Cmd.none
            )

        OpenViewer attachments attachment ->
            ( Just <| Viewer attachments attachment
            , Cmd.none
            )

        PrevAttachment ->
            case viewer of
                Just v ->
                    case getPrevNext v of
                        ( Just prev, _ ) ->
                            ( Just <| Viewer v.attachments prev
                            , Cmd.none
                            )

                        _ ->
                            ( Just v
                            , Cmd.none
                            )

                Nothing ->
                    ( viewer
                    , Cmd.none
                    )

        NextAttachment ->
            case viewer of
                Just v ->
                    case getPrevNext v of
                        ( _, Just next ) ->
                            ( Just <| Viewer v.attachments next
                            , Cmd.none
                            )

                        _ ->
                            ( Just v
                            , Cmd.none
                            )

                Nothing ->
                    ( viewer
                    , Cmd.none
                    )
