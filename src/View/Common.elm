module View.Common
    exposing
        ( accountAvatarLink
        , accountLink
        , closeablePanelheading
        , icon
        , justifiedButtonGroup
        )

import Html exposing (..)
import Html.Attributes exposing (..)
import Mastodon.Model exposing (..)
import Types exposing (..)
import View.Events exposing (..)
import View.Formatter exposing (formatContent)


accountLink : Account -> Html Msg
accountLink account =
    a
        [ href account.url
        , onClickWithPreventAndStop (LoadAccount account.id)
        ]
        [ text <| "@" ++ account.username ]


accountAvatarLink : Account -> Html Msg
accountAvatarLink account =
    a
        [ href account.url
        , onClickWithPreventAndStop (LoadAccount account.id)
        , title <| "@" ++ account.username
        ]
        [ img [ class "avatar", src account.avatar ] [] ]


closeablePanelheading : String -> String -> String -> Msg -> Html Msg
closeablePanelheading context iconName label onClose =
    div [ class "panel-heading" ]
        [ div [ class "row" ]
            [ a
                [ href "", onClickWithPreventAndStop <| ScrollColumn ScrollTop context ]
                [ div [ class "col-xs-9 heading" ] [ icon iconName, text label ] ]
            , div [ class "col-xs-3 text-right" ]
                [ a
                    [ href "", onClickWithPreventAndStop onClose ]
                    [ icon "remove" ]
                ]
            ]
        ]


icon : String -> Html Msg
icon name =
    i [ class <| "glyphicon glyphicon-" ++ name ] []


justifiedButtonGroup : List (Html Msg) -> Html Msg
justifiedButtonGroup buttons =
    div [ class "btn-group btn-group-justified" ] <|
        List.map (\b -> div [ class "btn-group" ] [ b ]) buttons
