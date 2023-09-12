module Update.Draft exposing
    ( empty
    , showAutoMenu
    , update
    )

import Command
import EmojiPicker exposing (PickerConfig)
import Json.Decode as Decode
import Mastodon.Decoder exposing (attachmentDecoder)
import Mastodon.Helper
import Mastodon.Model exposing (..)
import Menu
import String.Extra
import Types exposing (..)
import Update.Error exposing (addErrorNotification)
import Util


autocompleteUpdateConfig : Menu.UpdateConfig Msg Account
autocompleteUpdateConfig =
    Menu.updateConfig
        { toId = .id
        , onKeyDown =
            \code maybeId ->
                if code == 38 || code == 40 then
                    Nothing

                else if code == 13 then
                    Maybe.map (DraftEvent << SelectAccount) maybeId

                else
                    Just <| (DraftEvent << ResetAutocomplete) False
        , onTooLow = Just <| (DraftEvent << ResetAutocomplete) True
        , onTooHigh = Just <| (DraftEvent << ResetAutocomplete) False
        , onMouseEnter = \_ -> Nothing
        , onMouseLeave = \_ -> Nothing
        , onMouseClick = \id -> Just <| (DraftEvent << SelectAccount) id
        , separateSelections = False
        }


pickerConfig : PickerConfig
pickerConfig =
    { offsetX = 0 -- horizontal offset
    , offsetY = 0 -- vertical offset
    , closeOnSelect = True -- close after clicking an emoji
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
    , autoState = Menu.empty
    , autoAtPosition = Nothing
    , autoQuery = ""
    , autoCursorPosition = 0
    , autoMaxResults = 4
    , autoAccounts = []
    , showAutoMenu = False
    , emojiModel = EmojiPicker.init pickerConfig
    }


showAutoMenu : List Account -> Maybe Int -> String -> Bool
showAutoMenu accounts atPosition query =
    case ( List.isEmpty accounts, atPosition, query ) of
        ( _, Nothing, _ ) ->
            False

        ( True, _, _ ) ->
            False

        ( _, _, "" ) ->
            False

        ( False, Just _, _ ) ->
            True


update : DraftMsg -> Account -> Model -> ( Model, Cmd Msg )
update draftMsg currentUser ({ draft } as model) =
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
                    , Cmd.none
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

        UpdateInputInformation { status, selectionStart } ->
            let
                stringToPos =
                    String.slice 0 selectionStart status

                atPosition =
                    case String.right 1 stringToPos of
                        "@" ->
                            Just selectionStart

                        " " ->
                            Nothing

                        _ ->
                            model.draft.autoAtPosition

                query =
                    case atPosition of
                        Just position ->
                            String.slice position (String.length stringToPos) stringToPos

                        Nothing ->
                            ""

                newDraft =
                    { draft
                        | status = status
                        , statusLength = String.length status
                        , autoCursorPosition = selectionStart
                        , autoAtPosition = atPosition
                        , autoQuery = query
                        , showAutoMenu =
                            showAutoMenu
                                draft.autoAccounts
                                draft.autoAtPosition
                                draft.autoQuery
                    }
            in
            ( { model | draft = newDraft }
            , if query /= "" && atPosition /= Nothing then
                Command.searchAccounts (List.head model.clients) query model.draft.autoMaxResults False

              else
                Cmd.none
            )

        SelectAccount id ->
            let
                account =
                    List.filter (\a -> a.id == id) draft.autoAccounts
                        |> List.head

                newStatus =
                    case draft.autoAtPosition of
                        Just atPosition ->
                            String.Extra.replaceSlice
                                (case account of
                                    Just a ->
                                        a.acct ++ " "

                                    Nothing ->
                                        ""
                                )
                                atPosition
                                (String.length draft.autoQuery + atPosition)
                                draft.status

                        _ ->
                            ""

                newDraft =
                    { draft
                        | status = newStatus
                        , autoAtPosition = Nothing
                        , autoQuery = ""
                        , autoState = Menu.empty
                        , autoAccounts = []
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
                    Menu.update
                        autocompleteUpdateConfig
                        autoMsg
                        draft.autoMaxResults
                        draft.autoState
                        (Util.acceptableAccounts draft.autoQuery draft.autoAccounts)

                newModel =
                    { model | draft = { draft | autoState = newState } }
            in
            case maybeMsg of
                Just (DraftEvent updateMsg) ->
                    update updateMsg currentUser newModel

                _ ->
                    ( newModel
                    , Cmd.none
                    )

        CloseAutocomplete ->
            let
                newDraft =
                    { draft
                        | showAutoMenu = False
                        , autoState = Menu.reset autocompleteUpdateConfig draft.autoState
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
                                Menu.resetToFirstItem
                                    autocompleteUpdateConfig
                                    (Util.acceptableAccounts draft.autoQuery draft.autoAccounts)
                                    draft.autoMaxResults
                                    draft.autoState

                            else
                                Menu.resetToLastItem
                                    autocompleteUpdateConfig
                                    (Util.acceptableAccounts draft.autoQuery draft.autoAccounts)
                                    draft.autoMaxResults
                                    draft.autoState
                    }
            in
            ( { model | draft = newDraft }
            , Cmd.none
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
