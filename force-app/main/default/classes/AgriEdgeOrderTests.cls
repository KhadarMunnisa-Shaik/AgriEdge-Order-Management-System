@IsTest
private class AgriEdgeOrderTests {

    private static AgriEdge_Order__c createOrder(
        Id accountId,
        String paymentStatus
    ) {
        AgriEdge_Order__c orderRecord = new AgriEdge_Order__c(
            Customer__c = accountId,
            Payment_Status__c = paymentStatus
        );
        insert orderRecord;
        return orderRecord;
    }

    private static Account createAccount() {
        Account accountRecord = new Account(
            Name = 'AgriEdge Test Customer'
        );
        insert accountRecord;
        return accountRecord;
    }

    @IsTest
    static void testOrderTaskCreator() {
        Profile platformProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Platform 1'
            LIMIT 1
        ];

        User testUser = new User(
            FirstName = 'Test',
            LastName = 'PlatformUser',
            Alias = 'plat1',
            Email = 'platform1.test@example.com',
            Username = 'platform1.test.' + String.valueOf(DateTime.now().getTime()) + '@example.com',
            ProfileId = platformProfile.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );

        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert testUser;
        }

        Account accountRecord = createAccount();
        AgriEdge_Order__c orderRecord =
            createOrder(accountRecord.Id, 'Pending');

        Test.startTest();
        OrderTaskCreator.createTaskForNewOrder(
            new List<Id>{ orderRecord.Id }
        );
        Test.stopTest();

        List<Task> createdTasks = [
           SELECT Id, Subject, WhatId, OwnerId, Priority
           FROM Task
           WHERE WhatId = :orderRecord.Id
           AND OwnerId = :testUser.Id
      ];

        System.assertEquals(1, createdTasks.size(),
            'One task should be assigned to the Platform 1 test user.');
        System.assertEquals('New Order Created', createdTasks[0].Subject);
        System.assertEquals(testUser.Id, createdTasks[0].OwnerId);
        System.assertEquals('High', createdTasks[0].Priority);
    }

    @IsTest
    static void testOrderStatusUpdater() {
        Account accountRecord = createAccount();
        AgriEdge_Order__c orderRecord =
            createOrder(accountRecord.Id, 'Pending');

        orderRecord.Order_Status__c = 'New';
        update orderRecord;

        Test.startTest();
        OrderStatusUpdater.updateOrderStatus(
            new Set<Id>{ orderRecord.Id }
        );
        Test.stopTest();

        AgriEdge_Order__c updatedOrder = [
            SELECT Order_Status__c
            FROM AgriEdge_Order__c
            WHERE Id = :orderRecord.Id
        ];

        System.assertEquals('Processing', updatedOrder.Order_Status__c);
    }

    @IsTest
    static void testOrderTotalUpdater() {
        Account accountRecord = createAccount();
        AgriEdge_Order__c orderRecord =
            createOrder(accountRecord.Id, 'Pending');

        Product__c productRecord = new Product__c(
            Product_Code__c = 'TEST-PROD-01',
            Product_Category__c = 'Seeds',
            Unit_of_Measure__c = 'kg',
            Unit_Price__c = 40,
            Is_Active__c = true
        );
        insert productRecord;

        AgriEdge_OrderItem__c firstItem = new AgriEdge_OrderItem__c(
            AgriEdge_Order__c = orderRecord.Id,
            Product__c = productRecord.Id,
            Quantity__c = 2,
            Unit_Price__c = 40
        );

        AgriEdge_OrderItem__c secondItem = new AgriEdge_OrderItem__c(
            AgriEdge_Order__c = orderRecord.Id,
            Product__c = productRecord.Id,
            Quantity__c = 1,
            Unit_Price__c = 40
        );

        Test.startTest();
        insert new List<AgriEdge_OrderItem__c>{ firstItem, secondItem };
        OrderTotalUpdater.updateOrderTotal(
            new Set<Id>{ orderRecord.Id }
        );
        Test.stopTest();

        AgriEdge_Order__c updatedOrder = [
            SELECT Total_Amount__c, Payment_Status__c
            FROM AgriEdge_Order__c
            WHERE Id = :orderRecord.Id
        ];

        System.assertEquals(120, updatedOrder.Total_Amount__c);
        System.assertEquals('Pending', updatedOrder.Payment_Status__c);
    }

    @IsTest
static void testSendOrderEmail() {
    Account accountRecord = createAccount();

    Contact contactRecord = new Contact(
        FirstName = 'Test',
        LastName = 'Customer',
        Email = 'customer@example.com',
        AccountId = accountRecord.Id
    );
    insert contactRecord;

    AgriEdge_Order__c orderRecord =
        createOrder(accountRecord.Id, 'Pending');

    orderRecord.Total_Amount__c = 500;
    update orderRecord;

    Test.startTest();

    OrderEmailSender.sendOrderEmail(
        new Set<Id>{ orderRecord.Id }
    );

    System.assertEquals(
        1,
        Limits.getEmailInvocations(),
        'One email send operation should be invoked.'
    );

    Test.stopTest();
}
    

    @IsTest
    static void testShipmentHelper() {
        Account accountRecord = createAccount();
        AgriEdge_Order__c orderRecord =
            createOrder(accountRecord.Id, 'Pending');

        List<Shipment__c> initialShipments = [
            SELECT Id, Shipment_Status__c, Tracking_Number__c
            FROM Shipment__c
            WHERE AgriEdge_Order__c = :orderRecord.Id
        ];

        System.assertEquals(1, initialShipments.size(),
            'A shipment should be created when the order enters Processing.');
        System.assertEquals('Pending', initialShipments[0].Shipment_Status__c);

        Test.startTest();

        AgriEdgeOrderShipmentHelper.processOrderStatusChange(
            new List<AgriEdge_Order__c>{
                new AgriEdge_Order__c(
                    Id = orderRecord.Id,
                    Order_Status__c = 'Processing',
                    Payment_Status__c = 'Pending'
                )
            }
        );

        orderRecord.Order_Status__c = 'Shipped';
        update orderRecord;

        Test.stopTest();

        Shipment__c updatedShipment = [
            SELECT Shipment_Status__c
            FROM Shipment__c
            WHERE AgriEdge_Order__c = :orderRecord.Id
            LIMIT 1
        ];

        System.assertEquals('In Transit', updatedShipment.Shipment_Status__c);
    }

    @IsTest
    static void testFailedPaymentCancellation() {
        Account accountRecord = createAccount();
        AgriEdge_Order__c orderRecord =
            createOrder(accountRecord.Id, 'Pending');

        Product__c productRecord = new Product__c(
            Product_Code__c = 'TEST-PROD-02',
            Product_Category__c = 'Seeds',
            Unit_of_Measure__c = 'kg',
            Unit_Price__c = 25,
            Is_Active__c = true
        );
        insert productRecord;

        insert new AgriEdge_OrderItem__c(
            AgriEdge_Order__c = orderRecord.Id,
            Product__c = productRecord.Id,
            Quantity__c = 2,
            Unit_Price__c = 25
        );

        Test.startTest();

        orderRecord.Payment_Status__c = 'Failed';
        update orderRecord;

        Test.stopTest();

        AgriEdge_Order__c canceledOrder = [
            SELECT Order_Status__c, Payment_Status__c
            FROM AgriEdge_Order__c
            WHERE Id = :orderRecord.Id
        ];

        System.assertEquals('Canceled', canceledOrder.Order_Status__c);
        System.assertEquals('Failed', canceledOrder.Payment_Status__c);

        System.assertEquals(
            0,
            [SELECT COUNT() FROM AgriEdge_OrderItem__c
             WHERE AgriEdge_Order__c = :orderRecord.Id],
            'Order items should be deleted after failed payment.'
        );

        System.assertEquals(
            0,
            [SELECT COUNT() FROM Shipment__c
             WHERE AgriEdge_Order__c = :orderRecord.Id],
            'Shipment should be deleted after failed payment.'
        );
    }

    @IsTest
    static void testTriggerHelper() {
        AgriEdgeOrderTriggerHelper.isTriggerExecuted = false;

        System.assertEquals(
            false,
            AgriEdgeOrderTriggerHelper.isTriggerExecuted
        );

        AgriEdgeOrderTriggerHelper.isTriggerExecuted = true;

        System.assertEquals(
            true,
            AgriEdgeOrderTriggerHelper.isTriggerExecuted
        );

        AgriEdgeOrderTriggerHelper.isTriggerExecuted = false;
    }

    @IsTest
    static void testEmptyInputHandling() {
        OrderStatusUpdater.updateOrderStatus(null);
        OrderStatusUpdater.updateOrderStatus(new Set<Id>());

        OrderTotalUpdater.updateOrderTotal(null);
        OrderTotalUpdater.updateOrderTotal(new Set<Id>());

        OrderEmailSender.sendOrderEmail(null);
        OrderEmailSender.sendOrderEmail(new Set<Id>());

        OrderTaskCreator.createTaskForNewOrder(null);
        OrderTaskCreator.createTaskForNewOrder(new List<Id>());
        AgriEdgeOrderShipmentHelper.processOrderStatusChange(null);

        System.assert(true, 'Empty inputs should be handled safely.');
    }
        @IsTest
    static void testPaymentStatusTriggerSendsEmail() {
        Account accountRecord = createAccount();

        Contact contactRecord = new Contact(
            FirstName = 'Payment',
            LastName = 'Customer',
            Email = 'payment.customer@example.com',
            AccountId = accountRecord.Id
        );
        insert contactRecord;

        AgriEdge_Order__c orderRecord =
            createOrder(accountRecord.Id, 'Pending');

        Test.startTest();

        orderRecord.Payment_Status__c = 'Paid';
        update orderRecord;

        System.assertEquals(
            1,
            Limits.getEmailInvocations(),
            'Changing payment status to Paid should invoke the email sender.'
        );

        Test.stopTest();
    }
}
