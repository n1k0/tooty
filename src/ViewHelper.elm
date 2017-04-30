module ViewHelper
    exposing
        ( formatContent
        , getMentionForLink
        , onClickInformation
        , onInputInformation
        , onClickWithStop
        , onClickWithPrevent
        , onClickWithPreventAndStop
        , toVirtualDom
        , filterNotifications
        )

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (on, onWithOptions)
import HtmlParser
import Json.Decode as Decode
import String.Extra exposing (replace)
import Mastodon.Model exposing (..)
import Types exposing (..)


-- Custom Events


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



-- Views


formatContent : String -> List Mention -> List (Html Msg)
formatContent content mentions =
    content
        |> replace " ?" "&nbsp;?"
        |> replace " !" "&nbsp;!"
        |> replace " :" "&nbsp;:"
        |> HtmlParser.parse
        |> toVirtualDom mentions


{-| Converts nodes to virtual dom nodes.
-}
toVirtualDom : List Mention -> List HtmlParser.Node -> List (Html Msg)
toVirtualDom mentions nodes =
    List.map (toVirtualDomEach mentions) nodes


createLinkNode : List ( String, String ) -> List HtmlParser.Node -> List Mention -> Html Msg
createLinkNode attrs children mentions =
    let
        maybeMention =
            getMentionForLink attrs mentions
    in
        case maybeMention of
            Just mention ->
                Html.node "a"
                    ((List.map toAttribute attrs)
                        ++ [ onClickWithPreventAndStop (LoadAccount mention.id) ]
                    )
                    (toVirtualDom mentions children)

            Nothing ->
                Html.node "a"
                    ((List.map toAttribute attrs)
                        ++ [ onClickWithStop NoOp, target "_blank" ]
                    )
                    (toVirtualDom mentions children)


getHrefLink : List ( String, String ) -> Maybe String
getHrefLink attrs =
    attrs
        |> List.filter (\( name, value ) -> (name == "href"))
        |> List.map (\( name, value ) -> value)
        |> List.head


getMentionForLink : List ( String, String ) -> List Mention -> Maybe Mention
getMentionForLink attrs mentions =
    case getHrefLink attrs of
        Just href ->
            mentions
                |> List.filter (\m -> m.url == href)
                |> List.head

        Nothing ->
            Nothing


toVirtualDomEach : List Mention -> HtmlParser.Node -> Html Msg
toVirtualDomEach mentions node =
    case node of
        HtmlParser.Element "a" attrs children ->
            createLinkNode attrs children mentions

        HtmlParser.Element name attrs children ->
            Html.node name (List.map toAttribute attrs) (toVirtualDom mentions children)

        HtmlParser.Text s ->
            text s

        HtmlParser.Comment _ ->
            text ""


toAttribute : ( String, String ) -> Attribute msg
toAttribute ( name, value ) =
    attribute name value


filterNotifications : NotificationFilter -> List NotificationAggregate -> List NotificationAggregate
filterNotifications filter notifications =
    let
        applyFilter { type_ } =
            case filter of
                NotificationAll ->
                    True

                NotificationOnlyMentions ->
                    type_ == "mention"

                NotificationOnlyBoosts ->
                    type_ == "reblog"

                NotificationOnlyFavourites ->
                    type_ == "favourite"

                NotificationOnlyFollows ->
                    type_ == "follow"
    in
        if filter == NotificationAll then
            notifications
        else
            List.filter applyFilter notifications
