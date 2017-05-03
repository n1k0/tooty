module View.Formatter exposing (formatContent)

import Html exposing (..)
import Html.Attributes exposing (..)
import HtmlParser
import String.Extra exposing (replace)
import Mastodon.Model exposing (..)
import Types exposing (..)
import View.Events exposing (..)


-- Custom Events
-- Views


formatContent : String -> List Mention -> List (Html Msg)
formatContent content mentions =
    content
        |> replace " ?" "&#160;?"
        |> replace " !" "&#160;!"
        |> replace " :" "&#160;:"
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
