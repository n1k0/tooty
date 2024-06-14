module Update.Draft exposing
    ( empty
    , showAutoMenu
    , update
    )

import Browser.Dom as Dom
import Command
import Dict
import EmojiPicker exposing (PickerConfig)
import Emojis
import Json.Decode as Decode
import List.Extra exposing (uniqueBy)
import Mastodon.Decoder exposing (attachmentDecoder)
import Mastodon.Helper
import Mastodon.Model exposing (..)
import Menu
import String.Extra
import Task
import Types exposing (..)
import Update.Error exposing (addErrorNotification)
import Util


emojis : List CustomEmoji -> List Emoji
emojis customEmojis =
    (Emojis.emojiDict
        |> Dict.toList
        |> List.map
            (\( k, v ) ->
                { shortcode = String.toLower k
                , value = v.native
                , imgUrl = Nothing
                , keywords = v.keywords |> List.map String.toLower
                }
            )
    )
        ++ (customEmojis
                |> List.map
                    (\cu ->
                        { shortcode = String.toLower cu.shortcode
                        , value = ":" ++ String.toLower cu.shortcode ++ ":"
                        , imgUrl = Just cu.url
                        , keywords = []
                        }
                    )
           )


autocompleteUpdateConfig : (a -> String) -> Menu.UpdateConfig Msg a
autocompleteUpdateConfig getId =
    Menu.updateConfig
        { toId = getId
        , onKeyDown =
            \code maybeId ->
                if code == 38 || code == 40 then
                    Nothing

                else if code == 13 then
                    Maybe.map (DraftEvent << SelectAutoItem) maybeId

                else
                    Just <| (DraftEvent << ResetAutocomplete) False
        , onTooLow = Just <| (DraftEvent << ResetAutocomplete) True
        , onTooHigh = Just <| (DraftEvent << ResetAutocomplete) False
        , onMouseEnter = \_ -> Nothing
        , onMouseLeave = \_ -> Nothing
        , onMouseClick = \id -> Just <| (DraftEvent << SelectAutoItem) id
        , separateSelections = False
        }


pickerConfig : List Emojis.Emoji -> PickerConfig
pickerConfig customEmojis =
    { offsetX = 0 -- horizontal offset
    , offsetY = 0 -- vertical offset
    , closeOnSelect = True -- close after clicking an emoji
    , customEmojis = customEmojis
    , customEmojisWidth = Nothing
    , customEmojisHeight = Nothing
    }


empty : Draft
empty =
    { status = ""
    , statusSource = Nothing
    , spoilerText = Nothing
    , sensitive = False
    , type_ = NewDraft
    , visibility = "public"
    , attachments = []
    , mediaUploading = False
    , statusLength = 0
    , autocompleteType = Nothing
    , autoState = Menu.empty
    , autoStartPosition = Nothing
    , autoQuery = ""
    , autoMaxResults = 6
    , autoAccounts = []
    , autoEmojis = []
    , showAutoMenu = False
    , emojiModel = EmojiPicker.init <| pickerConfig []
    }


showAutoMenu : List Account -> List Emoji -> Maybe Int -> String -> Bool
showAutoMenu accounts emojiList atPosition query =
    case ( List.isEmpty accounts && List.isEmpty emojiList, atPosition, query ) of
        ( _, Nothing, _ ) ->
            False

        ( True, _, _ ) ->
            False

        ( _, _, "" ) ->
            False

        ( False, Just _, _ ) ->
            True


update : DraftMsg -> Model -> ( Model, Cmd Msg )
update draftMsg ({ draft } as model) =
    case draftMsg of
        ClearDraft ->
            ( { model | draft = empty }
            , Command.updateDomStatus empty.status
            )

        EditStatus status ->
            ( { model
                | draft =
                    { draft
                        | type_ = Editing { status = status, spoiler_text = Nothing, text = Nothing }
                        , attachments = status.media_attachments
                        , sensitive = Maybe.withDefault False status.sensitive
                    }
              }
            , Command.getStatusSource (List.head model.clients) status.id
            )

        EmojiMsg subMsg ->
            case subMsg of
                EmojiPicker.Select selectedEmoji ->
                    let
                        subModel =
                            draft.emojiModel

                        ( newSubModel, _ ) =
                            EmojiPicker.update subMsg subModel

                        newStatus =
                            draft.status ++ selectedEmoji
                    in
                    ( { model | draft = { draft | emojiModel = newSubModel, status = newStatus } }
                    , Command.updateDomStatus newStatus
                    )

                _ ->
                    let
                        subModel =
                            draft.emojiModel

                        ( newSubModel, _ ) =
                            EmojiPicker.update subMsg subModel
                    in
                    ( { model | draft = { draft | emojiModel = newSubModel } }
                    , Dom.focus "search-text" |> Task.attempt (\_ -> NoOp)
                    )

        SaveAttachmentDescription attachmentId ->
            let
                attachmentToSave =
                    List.head <| List.filter (\a -> a.id == attachmentId) draft.attachments
            in
            ( model
            , case attachmentToSave of
                Just a ->
                    case a.description of
                        Just description ->
                            Command.updateMedia (List.head model.clients) a.id { description = description }

                        Nothing ->
                            Cmd.none

                Nothing ->
                    Cmd.none
            )

        ToggleSpoiler enabled ->
            let
                newDraft =
                    { draft
                        | spoilerText =
                            if enabled then
                                Just ""

                            else
                                Nothing
                    }
            in
            ( { model | draft = newDraft }
            , Cmd.none
            )

        UpdateAttachmentDescription attachmentId description ->
            let
                newDraft =
                    { draft
                        | attachments =
                            List.map
                                (\a ->
                                    if a.id == attachmentId then
                                        { a | description = Just description }

                                    else
                                        a
                                )
                                draft.attachments
                    }
            in
            ( { model | draft = newDraft }
            , Cmd.none
            )

        UpdateCustomEmojis customEmojis ->
            let
                -- Convert CustomEmoji to Picker Emoji type
                emojisToDisplayInPicker =
                    customEmojis
                        |> List.filter .visible_in_picker
                        |> List.indexedMap
                            (\i e ->
                                { name = ":" ++ e.shortcode ++ ":"
                                , native = ":" ++ e.shortcode ++ ":"
                                , sortOrder = i
                                , skinVariations = Dict.fromList []
                                , keywords = []
                                , imgUrl = Just e.url
                                }
                            )

                newDraft =
                    { draft | emojiModel = EmojiPicker.init <| pickerConfig emojisToDisplayInPicker }
            in
            ( { model | draft = newDraft }, Cmd.none )

        UpdateSensitive sensitive ->
            ( { model | draft = { draft | sensitive = sensitive } }
            , Cmd.none
            )

        UpdateSpoiler spoilerText ->
            ( { model | draft = { draft | spoilerText = Just spoilerText } }
            , Cmd.none
            )

        UpdateVisibility visibility ->
            ( { model | draft = { draft | visibility = visibility } }
            , Cmd.none
            )

        UpdateReplyTo status ->
            case model.currentUser of
                Just currentUser ->
                    let
                        newStatus =
                            Mastodon.Helper.getReplyPrefix currentUser status
                    in
                    ( { model
                        | draft =
                            { draft
                                | type_ = InReplyTo status
                                , status = newStatus
                                , sensitive = Maybe.withDefault False status.sensitive
                                , spoilerText =
                                    if status.spoiler_text == "" then
                                        Nothing

                                    else
                                        Just status.spoiler_text
                                , visibility = status.visibility
                            }
                      }
                    , Cmd.batch
                        [ Command.focusId "status"
                        , Command.updateDomStatus newStatus
                        ]
                    )

                _ ->
                    ( model, Cmd.none )

        UpdateInputInformation { status, selectionStart } ->
            let
                stringToPos =
                    String.slice 0 selectionStart status

                getQuery position =
                    case position of
                        Just p ->
                            String.slice p (String.length stringToPos) stringToPos |> String.toLower

                        _ ->
                            ""

                ( startAutocompletePosition, autocompleteType, query ) =
                    case String.right 1 stringToPos of
                        "@" ->
                            ( Just selectionStart, Just AccountAuto, getQuery <| Just selectionStart )

                        ":" ->
                            case model.draft.autocompleteType of
                                -- End of an already existing emoji
                                Just EmojiAuto ->
                                    ( model.draft.autoStartPosition, Just EmojiAuto, getQuery model.draft.autoStartPosition )

                                -- New Emoji
                                _ ->
                                    ( Just selectionStart, Just EmojiAuto, getQuery <| Just selectionStart )

                        -- Space is pressed, cancel auto state
                        " " ->
                            ( Nothing, Nothing, "" )

                        -- Middle of a word
                        _ ->
                            case model.draft.autocompleteType of
                                Nothing ->
                                    ( Nothing, Nothing, "" )

                                autoType ->
                                    ( model.draft.autoStartPosition
                                    , autoType
                                    , getQuery model.draft.autoStartPosition
                                    )

                autoEmojis =
                    if query /= "" && startAutocompletePosition /= Nothing && autocompleteType == Just EmojiAuto then
                        -- First the emojis where the shortcode startswith the query
                        (emojis model.customEmojis
                            |> List.filter (\e -> String.startsWith query e.shortcode)
                            |> List.sortBy .shortcode
                        )
                            -- Then the emojis where one of the keywords startswith
                            ++ (emojis model.customEmojis
                                    |> List.filter (\e -> List.any (\k -> String.startsWith query k) e.keywords)
                                    |> List.sortBy .shortcode
                               )
                            -- Then only if shortcode or keywords contain the query
                            ++ (emojis model.customEmojis
                                    |> List.filter (\e -> String.contains query <| e.shortcode ++ " " ++ String.join " " e.keywords)
                                    |> List.sortBy .shortcode
                               )
                            |> uniqueBy .shortcode
                            |> List.take draft.autoMaxResults

                    else
                        []

                autoAccounts =
                    if autocompleteType == Just EmojiAuto then
                        []

                    else
                        draft.autoAccounts

                newDraft =
                    { draft
                        | status = status
                        , statusLength = String.length status
                        , autoStartPosition = startAutocompletePosition
                        , autoQuery = query
                        , autoEmojis = autoEmojis
                        , autocompleteType = autocompleteType
                        , autoAccounts = autoAccounts
                        , showAutoMenu = autocompleteType /= Nothing
                    }

                newModel =
                    { model | draft = newDraft }
            in
            if autocompleteType == Just EmojiAuto then
                -- Force selection of the first item after each
                -- Successfull request
                -- Old Elm 0.18
                --Task.perform identity (Task.succeed ((DraftEvent << ResetAutocomplete) True))
                let
                    ( updatedModel, msgs ) =
                        update (ResetAutocomplete True) newModel
                in
                ( updatedModel, Cmd.batch [ msgs, Task.attempt (\_ -> NoOp) (Dom.focus "autocomplete-menu") ] )

            else
                ( newModel
                , if query /= "" && startAutocompletePosition /= Nothing && autocompleteType == Just AccountAuto then
                    Command.searchAccounts (List.head model.clients) query model.draft.autoMaxResults False

                  else
                    Cmd.none
                )

        SelectAutoItem id ->
            let
                stringToPutInPlace =
                    (case draft.autocompleteType of
                        Just AccountAuto ->
                            List.filter (\a -> a.id == id) draft.autoAccounts
                                |> List.head
                                |> Maybe.map (\a -> a.acct ++ " ")

                        Just EmojiAuto ->
                            List.filter (\e -> e.shortcode == id) draft.autoEmojis
                                |> List.head
                                |> Maybe.map (\e -> e.value ++ " ")

                        _ ->
                            Nothing
                    )
                        |> Maybe.withDefault ""

                newStatus =
                    case draft.autoStartPosition of
                        Just atPosition ->
                            String.Extra.replaceSlice
                                stringToPutInPlace
                                (if draft.autocompleteType == Just EmojiAuto then
                                    atPosition - 1

                                 else
                                    atPosition
                                )
                                (String.length draft.autoQuery + atPosition)
                                draft.status

                        _ ->
                            ""

                newDraft =
                    { draft
                        | status = newStatus
                        , autoStartPosition = Nothing
                        , autocompleteType = Nothing
                        , autoQuery = ""
                        , autoState = Menu.empty
                        , autoAccounts = []
                        , autoEmojis = []
                        , showAutoMenu = False
                    }
            in
            ( { model | draft = newDraft }
            , -- As we are using defaultValue, we need to update the textarea
              -- using a port.
              Command.updateDomStatus newStatus
            )

        SetAutoState autoMsg ->
            let
                ( newState, maybeMsg ) =
                    if draft.autocompleteType == Just EmojiAuto then
                        Menu.update
                            (autocompleteUpdateConfig .shortcode)
                            autoMsg
                            draft.autoMaxResults
                            draft.autoState
                            (Util.acceptableAutoItems draft.autoQuery .shortcode draft.autoEmojis)

                    else
                        Menu.update
                            (autocompleteUpdateConfig .id)
                            autoMsg
                            draft.autoMaxResults
                            draft.autoState
                            (Util.acceptableAutoItems draft.autoQuery .username draft.autoAccounts)

                newModel =
                    { model | draft = { draft | autoState = newState } }
            in
            case maybeMsg of
                Just (DraftEvent updateMsg) ->
                    update updateMsg newModel

                _ ->
                    ( newModel
                    , Cmd.none
                    )

        CloseAutocomplete ->
            let
                newDraft =
                    { draft
                        | showAutoMenu = False
                        , autoState =
                            Menu.reset
                                (autocompleteUpdateConfig <|
                                    if draft.autocompleteType == Just EmojiAuto then
                                        .shortcode

                                    else
                                        .id
                                )
                                draft.autoState
                    }
            in
            ( { model | draft = newDraft }
            , Cmd.none
            )

        ResetAutocomplete toTop ->
            let
                newDraft =
                    { draft
                        | autoState =
                            if toTop then
                                if draft.autocompleteType == Just EmojiAuto then
                                    Menu.resetToFirstItem
                                        (autocompleteUpdateConfig .shortcode)
                                        draft.autoEmojis
                                        draft.autoMaxResults
                                        draft.autoState

                                else
                                    Menu.resetToFirstItem
                                        (autocompleteUpdateConfig .id)
                                        (Util.acceptableAutoItems draft.autoQuery .username draft.autoAccounts)
                                        draft.autoMaxResults
                                        draft.autoState

                            else if draft.autocompleteType == Just EmojiAuto then
                                Menu.resetToLastItem
                                    (autocompleteUpdateConfig .shortcode)
                                    draft.autoEmojis
                                    draft.autoMaxResults
                                    draft.autoState

                            else
                                Menu.resetToLastItem
                                    (autocompleteUpdateConfig .id)
                                    (Util.acceptableAutoItems
                                        draft.autoQuery
                                        .username
                                        draft.autoAccounts
                                    )
                                    draft.autoMaxResults
                                    draft.autoState
                    }
            in
            ( { model | draft = newDraft }
            , Task.attempt (\_ -> NoOp) (Dom.focus "autocomplete-menu")
            )

        RemoveMedia id ->
            let
                newDraft =
                    { draft | attachments = List.filter (\a -> a.id /= id) draft.attachments }
            in
            ( { model | draft = newDraft }
            , Cmd.none
            )

        UploadMedia id ->
            ( { model | draft = { draft | mediaUploading = True } }
            , Command.uploadMedia (List.head model.clients) id
            )

        UploadError error ->
            ( { model
                | draft = { draft | mediaUploading = False }
                , errors = addErrorNotification error model
              }
            , Cmd.none
            )

        UploadResult encoded ->
            if encoded == "" then
                -- user has likely pressed "Cancel" in the file input dialog
                ( model
                , Cmd.none
                )

            else
                let
                    decodedAttachment =
                        Decode.decodeString attachmentDecoder encoded
                in
                case decodedAttachment of
                    Ok attachment ->
                        ( { model
                            | draft =
                                { draft
                                    | mediaUploading = False
                                    , attachments = List.append draft.attachments [ attachment ]
                                }
                          }
                        , Cmd.none
                        )

                    Err error ->
                        ( { model
                            | draft = { draft | mediaUploading = False }
                            , errors = addErrorNotification (Decode.errorToString error) model
                          }
                        , Cmd.none
                        )
