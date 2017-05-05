module MastodonTest.HttpTest exposing (..)

import Dict
import Test exposing (..)
import Expect
import Mastodon.Http exposing (..)


all : Test
all =
    describe "Mastodon.Http"
        [ describe "extractLinks"
            [ test "should handle absence of link header" <|
                \() ->
                    extractLinks (Dict.fromList [])
                        |> Expect.equal { prev = Nothing, next = Nothing }
            , test "should parse a link header" <|
                \() ->
                    let
                        headers =
                            Dict.fromList
                                [ ( "link", "<nextLinkUrl>; rel=\"next\", <prevLinkUrl>; rel=\"prev\"" )
                                ]
                    in
                        extractLinks headers
                            |> Expect.equal { prev = Just "prevLinkUrl", next = Just "nextLinkUrl" }
            , test "should handle link header name case appropriately" <|
                \() ->
                    let
                        headers =
                            Dict.fromList
                                [ ( "Link", "<nextLinkUrl>; rel=\"next\", <prevLinkUrl>; rel=\"prev\"" )
                                ]
                    in
                        extractLinks headers
                            |> Expect.equal { prev = Just "prevLinkUrl", next = Just "nextLinkUrl" }
            , test "should extract a single prev link" <|
                \() ->
                    let
                        headers =
                            Dict.fromList [ ( "link", "<prevLinkUrl>; rel=\"prev\"" ) ]
                    in
                        extractLinks headers
                            |> Expect.equal { prev = Just "prevLinkUrl", next = Nothing }
            , test "should extract a single next link" <|
                \() ->
                    let
                        headers =
                            Dict.fromList [ ( "link", "<nextLinkUrl>; rel=\"next\"" ) ]
                    in
                        extractLinks headers
                            |> Expect.equal { prev = Nothing, next = Just "nextLinkUrl" }
            , test "should only extract prev and next links" <|
                \() ->
                    let
                        headers =
                            Dict.fromList [ ( "link", "<nextLinkUrl>; rel=\"next\", <blurp>; rel=\"blop\"" ) ]
                    in
                        extractLinks headers
                            |> Expect.equal { prev = Nothing, next = Just "nextLinkUrl" }
            ]
        ]
