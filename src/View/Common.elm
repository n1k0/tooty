module View.Common
    exposing
        ( accountAvatarLink
        , accountLink
        , closeablePanelheading
        , icon
        , justifiedButtonGroup
        , loadMoreBtn
        )

import Html exposing (..)
import Html.Attributes exposing (..)
import Mastodon.Http exposing (Links)
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


justifiedButtonGroup : String -> List (Html Msg) -> Html Msg
justifiedButtonGroup cls buttons =
    div [ class <| "btn-group btn-group-justified " ++ cls ] <|
        List.map (\b -> div [ class "btn-group" ] [ b ]) buttons


loadMoreBtn : { timeline | id : String, links : Links, loading : Bool } -> Html Msg
loadMoreBtn { id, links, loading } =
    if loading then
        -- TODO: proper spinner
        li [ class "list-group-item load-more text-center" ]
            [ text "Loading..." ]
    else
        case links.next of
            Just next ->
                a
                    [ class "list-group-item load-more text-center"
                    , href next
                    , onClickWithPreventAndStop <| TimelineLoadNext id next
                    ]
                    [ text "Load more" ]

            Nothing ->
                text ""
