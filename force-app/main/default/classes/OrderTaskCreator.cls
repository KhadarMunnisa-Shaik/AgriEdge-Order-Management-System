public with sharing class OrderTaskCreator {
    @InvocableMethod(label='Create Tasks for New Orders')
    public static void createTaskForNewOrder(List<Id> orderIds) {
        if (orderIds == null || orderIds.isEmpty()) return;

        List<User> platformUsers = [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'Platform 1' AND IsActive = true
            LIMIT 10
        ];

        if (platformUsers.isEmpty()) {
            System.debug('No active users found with Platform 1 profile.');
            return;
        }

        List<Task> tasksToInsert = new List<Task>();

        for (Id orderId : orderIds) {
            for (User assignedUser : platformUsers) {
                tasksToInsert.add(new Task(
                    Subject = 'New Order Created',
                    Description = 'A new order has been created. Please create an Order Item record.',
                    WhatId = orderId,
                    OwnerId = assignedUser.Id,
                    Status = 'Not Started',
                    Priority = 'High'
                ));
            }
        }

        if (!tasksToInsert.isEmpty()) {
            insert tasksToInsert;
        }
    }
}
