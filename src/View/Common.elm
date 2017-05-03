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


accountLink : Bool -> Account -> Html Msg
accountLink external account =
    let
        accountHref =
            if external then
                target "_blank"
            else
                onClickWithPreventAndStop (LoadAccount account.id)
    in
        a
            [ href account.url
            , accountHref
            ]
            [ text <| "@" ++ account.username ]


accountAvatarLink : Bool -> Account -> Html Msg
accountAvatarLink external account =
    let
        accountHref =
            if external then
                target "_blank"
            else
                onClickWithPreventAndStop (LoadAccount account.id)

        avatarClass =
            if external then
                ""
            else
                "avatar"
    in
        a
            [ href account.url
            , accountHref
            , title <| "@" ++ account.username
            ]
            [ img [ class avatarClass, src account.avatar ] [] ]


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
