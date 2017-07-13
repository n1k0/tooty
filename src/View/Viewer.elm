module View.Viewer exposing (viewerView)

import Html exposing (..)
import Html.Attributes exposing (..)
import Types exposing (..)
import Update.Viewer exposing (getPrevNext)
import View.Events exposing (..)


viewerView : Viewer -> Html Msg
viewerView ({ attachments, attachment } as viewer) =
    let
        ( prev, next ) =
            getPrevNext viewer

        navLink label className target event =
            case target of
                Nothing ->
                    text ""

                Just target ->
                    a
                        [ href ""
                        , class className
                        , onClickWithPreventAndStop event
                        ]
                        [ text label ]
    in
        div
            [ class "viewer"
            , tabindex -1
            , onClickWithPreventAndStop <| ViewerEvent CloseViewer
            ]
            [ span [ class "close" ] [ text "×" ]
            , navLink "❮" "prev" prev <| ViewerEvent NextAttachment
            , case attachment.type_ of
                "image" ->
                    img [ class "viewer-content", src attachment.url ] []

                _ ->
                    video
                        [ class "viewer-content"
                        , preload "auto"
                        , autoplay True
                        , loop True
                        ]
                        [ source [ src attachment.url ] [] ]
            , navLink "❯" "next" next <| ViewerEvent NextAttachment
            ]
