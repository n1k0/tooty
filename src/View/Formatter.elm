module View.Formatter exposing (formatContent, textContent)

import Dict
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Parser exposing (Node(..))
import Mastodon.Model exposing (..)
import String.Extra exposing (rightOf)
import Types exposing (..)
import View.Events exposing (..)


formatContent : String -> List Mention -> List (Html Msg)
formatContent content mentions =
    content
        |> String.replace " ?" "&#160;?"
        |> String.replace " !" "&#160;!"
        |> String.replace " :" "&#160;:"
        |> Html.Parser.run
        |> Result.withDefault []
        |> toVirtualDom mentions



{- https://github.com/jinjor/elm-html-parser/blob/master/src/HtmlParser/Util.elm#L352 -}


{-| Returns the text content of a node and its descendants.
-}
textContentFromNodes : List Node -> String
textContentFromNodes nodes =
    String.join "" (List.map textContentEach nodes)


textContentEach : Node -> String
textContentEach node =
    case node of
        Element _ _ children ->
            textContentFromNodes children

        Text s ->
            s

        Comment _ ->
            ""


textContent : String -> String
textContent html =
    html
        |> Html.Parser.run
        |> (\result ->
                case result of
                    Ok nodes ->
                        textContentFromNodes nodes

                    Err _ ->
                        ""
           )


{-| Converts nodes to virtual dom nodes.
-}
toVirtualDom : List Mention -> List Html.Parser.Node -> List (Html Msg)
toVirtualDom mentions nodes =
    List.map (toVirtualDomEach mentions) nodes


replaceHref : String -> List ( String, String ) -> List (Attribute Msg)
replaceHref newHref attrs =
    attrs
        -- Replace original href by tooty internal link
        |> List.filter (\( attribute, _ ) -> attribute /= "href")
        |> (++) [ ( "href", newHref ) ]
        |> List.map toAttribute
        |> List.append [ onClickWithPreventAndStop <| Navigate newHref ]


createLinkNode : List ( String, String ) -> List Html.Parser.Node -> List Mention -> Html Msg
createLinkNode attrs children mentions =
    case getMentionForLink attrs mentions of
        Just mention ->
            Html.node "a"
                (replaceHref ("#account/" ++ mention.id) attrs)
                (toVirtualDom mentions children)

        Nothing ->
            case getHashtagForLink attrs of
                Just hashtag ->
                    Html.node "a"
                        (replaceHref ("#hashtag/" ++ hashtag) attrs)
                        (toVirtualDom mentions children)

                Nothing ->
                    Html.node "a"
                        (List.map toAttribute attrs
                            ++ [ onClickWithStop NoOp, target "_blank" ]
                        )
                        (toVirtualDom mentions children)


getHrefLink : List ( String, String ) -> Maybe String
getHrefLink attrs =
    attrs
        |> List.filter (\( name, _ ) -> name == "href")
        |> List.map (\( _, value ) -> value)
        |> List.head


getHashtagForLink : List ( String, String ) -> Maybe String
getHashtagForLink attrs =
    let
        hashtag =
            attrs
                |> Dict.fromList
                |> Dict.get "href"
                |> Maybe.withDefault ""
                |> rightOf "/tags/"

        -- @TODO: add it again
        --|> Http.decodeUri
        --|> Maybe.withDefault ""
    in
    if hashtag /= "" then
        Just hashtag

    else
        Nothing


getMentionForLink : List ( String, String ) -> List Mention -> Maybe Mention
getMentionForLink attrs mentions =
    getHrefLink attrs
        |> Maybe.andThen
            (\href ->
                mentions
                    |> List.filter (\m -> m.url == href)
                    |> List.head
            )


toVirtualDomEach : List Mention -> Html.Parser.Node -> Html Msg
toVirtualDomEach mentions node =
    case node of
        Html.Parser.Element "a" attrs children ->
            createLinkNode attrs children mentions

        Html.Parser.Element name attrs children ->
            Html.node name (List.map toAttribute attrs) (toVirtualDom mentions children)

        Html.Parser.Text s ->
            text s

        Html.Parser.Comment _ ->
            text ""


toAttribute : ( String, String ) -> Attribute msg
toAttribute ( name, value ) =
    attribute name value
