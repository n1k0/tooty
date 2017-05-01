module View.Viewer exposing (viewerView)

import Html exposing (..)
import Html.Attributes exposing (..)
import List.Extra exposing (find, elemIndex, getAt)
import Types exposing (..)
import View.Helper exposing (..)


viewerView : Viewer -> Html Msg
viewerView { attachments, attachment } =
    let
        index =
            Maybe.withDefault -1 <| elemIndex attachment attachments

        ( prev, next ) =
            ( getAt (index - 1) attachments, getAt (index + 1) attachments )

        navLink label className target =
            case target of
                Nothing ->
                    text ""

                Just target ->
                    a
                        [ href ""
                        , class className
                        , onClickWithPreventAndStop <|
                            ViewerEvent (OpenViewer attachments target)
                        ]
                        [ text label ]
    in
        div
            [ class "viewer"
            , tabindex -1
            , onClickWithPreventAndStop <| ViewerEvent CloseViewer
            ]
            [ span [ class "close" ] [ text "×" ]
            , navLink "❮" "prev" prev
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
            , navLink "❯" "next" next
            ]
