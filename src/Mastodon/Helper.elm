module Mastodon.Helper exposing
    ( addNotificationToAggregates
    , aggregateNotifications
    , extractReblog
    , extractStatusId
    , getReplyPrefix
    , notificationToAggregate
    , sameAccount
    , statusReferenced
    )

import List.Extra exposing (groupWhile, uniqueBy)
import Mastodon.Model exposing (..)


extractReblog : Status -> Status
extractReblog status =
    case status.reblog of
        Just (Reblog reblog) ->
            reblog

        Nothing ->
            status


getReplyPrefix : Account -> Status -> String
getReplyPrefix replier status =
    -- Note: the Mastodon API doesn't consistently return mentions in the order
    --       they appear in the status text, we do nothing about that.
    let
        posters =
            case status.reblog of
                Just (Mastodon.Model.Reblog reblog) ->
                    [ reblog.account, status.account ] |> List.map toMention

                Nothing ->
                    toMention status.account :: status.mentions

        finalPosters =
            posters
                |> uniqueBy .acct
                |> List.filter (\m -> m /= toMention replier)
                |> List.map (\m -> "@" ++ m.acct)
    in
    String.join " " finalPosters ++ " "


toMention : Account -> Mention
toMention { id, url, username, acct } =
    Mention id url username acct


notificationToAggregate : Notification -> NotificationAggregate
notificationToAggregate notification =
    NotificationAggregate
        notification.id
        notification.type_
        notification.status
        [ { account = notification.account, created_at = notification.created_at } ]
        notification.created_at


addNotificationToAggregates : Notification -> List NotificationAggregate -> List NotificationAggregate
addNotificationToAggregates notification aggregates =
    let
        addNewAccountToSameStatus : NotificationAggregate -> Notification -> NotificationAggregate
        addNewAccountToSameStatus aggregate newNotification =
            case ( aggregate.status, newNotification.status ) of
                ( Just aggregateStatus, Just notificationStatus ) ->
                    if aggregateStatus.id == notificationStatus.id then
                        { aggregate
                            | accounts =
                                { account = newNotification.account
                                , created_at = newNotification.created_at
                                }
                                    :: aggregate.accounts
                        }

                    else
                        aggregate

                ( _, _ ) ->
                    aggregate

        {-
           Let's try to find an already existing aggregate, matching the notification
           we are trying to add.
           If we find any aggregate, we modify it inplace. If not, we return the
           aggregates unmodified
        -}
        newAggregates =
            aggregates
                |> List.map
                    (\aggregate ->
                        case ( aggregate.type_, notification.type_ ) of
                            {-
                               Notification and aggregate are of the follow type.
                               Add the new following account.
                            -}
                            ( "follow", "follow" ) ->
                                { aggregate
                                    | accounts =
                                        { account = notification.account
                                        , created_at = notification.created_at
                                        }
                                            :: aggregate.accounts
                                }

                            {-
                               Notification is of type follow, but current aggregate
                               is of another type. Let's continue then.
                            -}
                            ( _, "follow" ) ->
                                aggregate

                            {-
                               If both types are the same check if we should
                               add the new account.
                            -}
                            ( aggregateType, notificationType ) ->
                                if aggregateType == notificationType then
                                    addNewAccountToSameStatus aggregate notification

                                else
                                    aggregate
                    )
    in
    {-
       If we did no modification to the old aggregates it's
       because we didn't found any match. So we have to create
       a new aggregate
    -}
    if newAggregates == aggregates then
        notificationToAggregate notification :: aggregates

    else
        newAggregates


aggregateNotifications : List Notification -> List NotificationAggregate
aggregateNotifications notifications =
    let
        only : String -> List Notification -> List Notification
        only type_ allNotifications =
            List.filter (\n -> n.type_ == type_) allNotifications

        sameStatus : Notification -> Notification -> Bool
        sameStatus n1 n2 =
            case ( n1.status, n2.status ) of
                ( Just r1, Just r2 ) ->
                    r1.id == r2.id

                _ ->
                    False

        extractAggregate : ( Notification, List Notification ) -> NotificationAggregate
        extractAggregate ( headNotification, tailNotification ) =
            let
                accounts =
                    (headNotification :: tailNotification)
                        |> List.map (\s -> { account = s.account, created_at = s.created_at })
                        |> uniqueBy (.account >> .id)
            in
            NotificationAggregate
                headNotification.id
                headNotification.type_
                headNotification.status
                accounts
                headNotification.created_at

        aggregate : List ( Notification, List Notification ) -> List NotificationAggregate
        aggregate statusGroups =
            List.map extractAggregate statusGroups
    in
    [ notifications |> only "reblog" |> groupWhile sameStatus |> aggregate
    , notifications |> only "favourite" |> groupWhile sameStatus |> aggregate
    , notifications |> only "mention" |> groupWhile sameStatus |> aggregate
    , notifications |> only "follow" |> groupWhile (\_ _ -> True) |> aggregate
    ]
        |> List.concat
        |> List.sortBy .created_at
        |> List.reverse


sameAccount : Mastodon.Model.Account -> Mastodon.Model.Account -> Bool
sameAccount { id, acct, username } account =
    -- Note: different instances can share the same id for different accounts.
    id == account.id && acct == account.acct && username == account.username


statusReferenced : StatusId -> Status -> Bool
statusReferenced id status =
    status.id == id || (extractReblog status).id == id


extractStatusId : StatusId -> String
extractStatusId (StatusId id) =
    id
