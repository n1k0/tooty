module View.Events exposing
    ( decodePositionInformation
    , onClickInformation
    , onClickWithPrevent
    , onClickWithPreventAndStop
    , onClickWithStop
    , onInputInformation
    )

import Html exposing (..)
import Html.Events exposing (custom, on)
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
    custom
        "click"
        (Decode.succeed { message = msg, preventDefault = True, stopPropagation = True })


onClickWithPrevent : msg -> Attribute msg
onClickWithPrevent msg =
    custom
        "click"
        (Decode.succeed { message = msg, preventDefault = True, stopPropagation = False })


onClickWithStop : msg -> Attribute msg
onClickWithStop msg =
    custom
        "click"
        (Decode.succeed { message = msg, preventDefault = False, stopPropagation = True })
