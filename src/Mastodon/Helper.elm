module Mastodon.Helper
    exposing
        ( extractReblog
        , aggregateNotifications
        , addNotificationToAggregates
        , notificationToAggregate
        )

import List.Extra exposing (groupWhile, uniqueBy)
import Mastodon.Model
    exposing
        ( Notification
        , NotificationAggregate
        , Reblog(..)
        , Status
        )


extractReblog : Status -> Status
extractReblog status =
    case status.reblog of
        Just (Reblog reblog) ->
            reblog

        Nothing ->
            status


notificationToAggregate : Notification -> NotificationAggregate
notificationToAggregate notification =
    NotificationAggregate
        notification.type_
        notification.status
        [ notification.account ]
        notification.created_at


addNotificationToAggregates : Notification -> List NotificationAggregate -> List NotificationAggregate
addNotificationToAggregates notification aggregates =
    let
        addNewAccountToSameStatus : NotificationAggregate -> Notification -> NotificationAggregate
        addNewAccountToSameStatus aggregate notification =
            case ( aggregate.status, notification.status ) of
                ( Just aggregateStatus, Just notificationStatus ) ->
                    if aggregateStatus.id == notificationStatus.id then
                        { aggregate | accounts = notification.account :: aggregate.accounts }
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
                                { aggregate | accounts = notification.account :: aggregate.accounts }

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
           because we didn't found any match. So me have to create
           a new aggregate
        -}
        if newAggregates == aggregates then
            notificationToAggregate (notification) :: aggregates
        else
            newAggregates


aggregateNotifications : List Notification -> List NotificationAggregate
aggregateNotifications notifications =
    let
        only type_ notifications =
            List.filter (\n -> n.type_ == type_) notifications

        sameStatus n1 n2 =
            case ( n1.status, n2.status ) of
                ( Just r1, Just r2 ) ->
                    r1.id == r2.id

                _ ->
                    False

        extractAggregate statusGroup =
            let
                accounts =
                    statusGroup |> List.map .account |> uniqueBy .id
            in
                case statusGroup of
                    notification :: _ ->
                        [ NotificationAggregate
                            notification.type_
                            notification.status
                            accounts
                            notification.created_at
                        ]

                    [] ->
                        []

        aggregate statusGroups =
            List.map extractAggregate statusGroups |> List.concat
    in
        [ notifications |> only "reblog" |> groupWhile sameStatus |> aggregate
        , notifications |> only "favourite" |> groupWhile sameStatus |> aggregate
        , notifications |> only "mention" |> groupWhile sameStatus |> aggregate
        , notifications |> only "follow" |> groupWhile (\_ _ -> True) |> aggregate
        ]
            |> List.concat
            |> List.sortBy .created_at
            |> List.reverse
