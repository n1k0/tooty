module Update.Draft
    exposing
        ( empty
        , showAutoMenu
        , update
        )

import Autocomplete
import Command
import Json.Decode as Decode
import Mastodon.Decoder exposing (attachmentDecoder)
import Mastodon.Helper
import Mastodon.Model exposing (..)
import String.Extra
import Update.Error exposing (addErrorNotification)
import Types exposing (..)
import Util


autocompleteUpdateConfig : Autocomplete.UpdateConfig Msg Account
autocompleteUpdateConfig =
    Autocomplete.updateConfig
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


empty : Draft
empty =
    { status = ""
    , inReplyTo = Nothing
    , spoilerText = Nothing
    , sensitive = False
    , visibility = "public"
    , attachments = []
    , mediaUploading = False
    , statusLength = 0
    , autoState = Autocomplete.empty
    , autoAtPosition = Nothing
    , autoQuery = ""
    , autoCursorPosition = 0
    , autoMaxResults = 4
    , autoAccounts = []
    , showAutoMenu = False
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
            { model | draft = empty }
                ! [ Command.updateDomStatus empty.status ]

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
                { model | draft = newDraft } ! []

        UpdateSensitive sensitive ->
            { model | draft = { draft | sensitive = sensitive } } ! []

        UpdateSpoiler spoilerText ->
            { model | draft = { draft | spoilerText = Just spoilerText } } ! []

        UpdateVisibility visibility ->
            { model | draft = { draft | visibility = visibility } } ! []

        UpdateReplyTo status ->
            let
                newStatus =
                    Mastodon.Helper.getReplyPrefix currentUser status
            in
                { model
                    | draft =
                        { draft
                            | inReplyTo = Just status
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
                    ! [ Command.focusId "status"
                      , Command.updateDomStatus newStatus
                      ]

        UpdateInputInformation { status, selectionStart } ->
            let
                stringToPos =
                    String.slice 0 selectionStart status

                atPosition =
                    case (String.right 1 stringToPos) of
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
                { model | draft = newDraft }
                    ! if query /= "" && atPosition /= Nothing then
                        [ Command.searchAccounts (List.head model.clients) query model.draft.autoMaxResults False ]
                      else
                        []

        SelectAccount id ->
            let
                account =
                    List.filter (\account -> account.id == id) draft.autoAccounts
                        |> List.head

                stringToAtPos =
                    case draft.autoAtPosition of
                        Just atPosition ->
                            String.slice 0 atPosition draft.status

                        _ ->
                            ""

                stringToPos =
                    String.slice 0 draft.autoCursorPosition draft.status

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
                                ((String.length draft.autoQuery) + atPosition)
                                draft.status

                        _ ->
                            ""

                newDraft =
                    { draft
                        | status = newStatus
                        , autoAtPosition = Nothing
                        , autoQuery = ""
                        , autoState = Autocomplete.empty
                        , autoAccounts = []
                        , showAutoMenu = False
                    }
            in
                { model | draft = newDraft }
                    -- As we are using defaultValue, we need to update the textarea
                    -- using a port.
                    ! [ Command.updateDomStatus newStatus ]

        SetAutoState autoMsg ->
            let
                ( newState, maybeMsg ) =
                    Autocomplete.update
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
                        newModel ! []

        CloseAutocomplete ->
            let
                newDraft =
                    { draft
                        | showAutoMenu = False
                        , autoState = Autocomplete.reset autocompleteUpdateConfig draft.autoState
                    }
            in
                { model | draft = newDraft } ! []

        ResetAutocomplete toTop ->
            let
                newDraft =
                    { draft
                        | autoState =
                            if toTop then
                                Autocomplete.resetToFirstItem
                                    autocompleteUpdateConfig
                                    (Util.acceptableAccounts draft.autoQuery draft.autoAccounts)
                                    draft.autoMaxResults
                                    draft.autoState
                            else
                                Autocomplete.resetToLastItem
                                    autocompleteUpdateConfig
                                    (Util.acceptableAccounts draft.autoQuery draft.autoAccounts)
                                    draft.autoMaxResults
                                    draft.autoState
                    }
            in
                { model | draft = newDraft } ! []

        RemoveMedia id ->
            let
                newDraft =
                    { draft | attachments = List.filter (\a -> a.id /= id) draft.attachments }
            in
                { model | draft = newDraft } ! []

        UploadMedia id ->
            { model | draft = { draft | mediaUploading = True } }
                ! [ Command.uploadMedia (List.head model.clients) id ]

        UploadError error ->
            { model
                | draft = { draft | mediaUploading = False }
                , errors = addErrorNotification error model
            }
                ! []

        UploadResult encoded ->
            if encoded == "" then
                -- user has likely pressed "Cancel" in the file input dialog
                model ! []
            else
                let
                    decodedAttachment =
                        Decode.decodeString attachmentDecoder encoded
                in
                    case decodedAttachment of
                        Ok attachment ->
                            { model
                                | draft =
                                    { draft
                                        | mediaUploading = False
                                        , attachments = List.append draft.attachments [ attachment ]
                                    }
                            }
                                ! []

                        Err error ->
                            { model
                                | draft = { draft | mediaUploading = False }
                                , errors = addErrorNotification error model
                            }
                                ! []
