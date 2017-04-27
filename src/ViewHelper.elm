module ViewHelper
    exposing
        ( formatContent
        , getMentionForLink
        , onClickWithPreventAndStop
        , toVirtualDom
        )

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onWithOptions)
import HtmlParser
import Json.Decode as Decode
import String.Extra exposing (replace)
import Mastodon.Model
import Model exposing (Msg(OnLoadUserAccount))


-- Custom Events


onClickWithPreventAndStop : msg -> Attribute msg
onClickWithPreventAndStop msg =
    onWithOptions
        "click"
        { preventDefault = True, stopPropagation = True }
        (Decode.succeed msg)



-- Views


formatContent : String -> List Mastodon.Model.Mention -> List (Html Msg)
formatContent content mentions =
    content
        |> replace " ?" "&nbsp;?"
        |> replace " !" "&nbsp;!"
        |> replace " :" "&nbsp;:"
        |> HtmlParser.parse
        |> toVirtualDom mentions


{-| Converts nodes to virtual dom nodes.
-}
toVirtualDom : List Mastodon.Model.Mention -> List HtmlParser.Node -> List (Html Msg)
toVirtualDom mentions nodes =
    List.map (toVirtualDomEach mentions) nodes


createLinkNode : List ( String, String ) -> List HtmlParser.Node -> List Mastodon.Model.Mention -> Html Msg
createLinkNode attrs children mentions =
    let
        maybeMention =
            getMentionForLink attrs mentions
    in
        case maybeMention of
            Just mention ->
                Html.node "a"
                    ((List.map toAttribute attrs)
                        ++ [ onClickWithPreventAndStop (OnLoadUserAccount mention.id) ]
                    )
                    (toVirtualDom mentions children)

            Nothing ->
                Html.node "a" (List.map toAttribute attrs) (toVirtualDom mentions children)


getHrefLink : List ( String, String ) -> Maybe String
getHrefLink attrs =
    attrs
        |> List.filter
            (\( name, value ) -> (name == "href"))
        |> List.map
            (\( name, value ) -> value)
        |> List.head


getMentionForLink : List ( String, String ) -> List Mastodon.Model.Mention -> Maybe Mastodon.Model.Mention
getMentionForLink attrs mentions =
    case getHrefLink attrs of
        Just href ->
            mentions
                |> List.filter (\m -> m.url == href)
                |> List.head

        Nothing ->
            Nothing


toVirtualDomEach : List Mastodon.Model.Mention -> HtmlParser.Node -> Html Msg
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
