module View.Events
    exposing
        ( onClickInformation
        , onInputInformation
        , decodePositionInformation
        , onClickWithPreventAndStop
        , onClickWithPrevent
        , onClickWithStop
        )

import Html exposing (..)
import Html.Events exposing (on, onWithOptions)
import Json.Decode as Decode
import Types exposing (..)


onClickInformation : (InputInformation -> msg) -> Attribute msg
onClickInformation msg =
    on "mouseup" (Decode.map msg decodePositionInformation)


onInputInformation : (InputInformation -> msg) -> Attribute msg
onInputInformation msg =
    on "input" (Decode.map msg decodePositionInformation)


decodePositionInformation : Decode.Decoder InputInformation
decodePositionInformation =
    Decode.map2 InputInformation
        (Decode.at [ "target", "value" ] Decode.string)
        (Decode.at [ "target", "selectionStart" ] Decode.int)


onClickWithPreventAndStop : msg -> Attribute msg
onClickWithPreventAndStop msg =
    onWithOptions
        "click"
        { preventDefault = True, stopPropagation = True }
        (Decode.succeed msg)


onClickWithPrevent : msg -> Attribute msg
onClickWithPrevent msg =
    onWithOptions
        "click"
        { preventDefault = True, stopPropagation = False }
        (Decode.succeed msg)


onClickWithStop : msg -> Attribute msg
onClickWithStop msg =
    onWithOptions
        "click"
        { preventDefault = False, stopPropagation = True }
        (Decode.succeed msg)
