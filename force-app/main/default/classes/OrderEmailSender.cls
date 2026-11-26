public with sharing class OrderEmailSender {
    public static void sendOrderEmail(Set<Id> orderIds) {
        if (orderIds == null || orderIds.isEmpty()) return;

        List<AgriEdge_Order__c> orders = [
            SELECT Id, Name, Total_Amount__c, Payment_Status__c,
                   Order_Status__c, Customer__c, CreatedDate,
                   Discounted_Total__c
            FROM AgriEdge_Order__c
            WHERE Id IN :orderIds
            AND Customer__c != null
        ];

        if (orders.isEmpty()) return;

        Set<Id> accountIds = new Set<Id>();
        for (AgriEdge_Order__c orderRecord : orders) {
            accountIds.add(orderRecord.Customer__c);
        }

        Map<Id, List<Contact>> contactsByAccount = new Map<Id, List<Contact>>();

        for (Contact contactRecord : [
            SELECT Id, FirstName, LastName, Email, AccountId
            FROM Contact
            WHERE AccountId IN :accountIds
            AND Email != null
        ]) {
            if (!contactsByAccount.containsKey(contactRecord.AccountId)) {
                contactsByAccount.put(contactRecord.AccountId, new List<Contact>());
            }
            contactsByAccount.get(contactRecord.AccountId).add(contactRecord);
        }

        List<Messaging.SingleEmailMessage> messages =
            new List<Messaging.SingleEmailMessage>();

        for (AgriEdge_Order__c orderRecord : orders) {
            List<Contact> accountContacts =
                contactsByAccount.get(orderRecord.Customer__c);

            if (accountContacts == null || accountContacts.isEmpty()) continue;

            List<String> recipients = new List<String>();
            for (Contact contactRecord : accountContacts) {
                recipients.add(contactRecord.Email);
            }

            String body = '<html><body>' +
                '<h2>AgriEdge Order Payment Confirmation</h2>' +
                '<p>Your payment for order <b>' + orderRecord.Name +
                '</b> has been received.</p>' +
                '<p>Order Status: ' + orderRecord.Order_Status__c + '</p>' +
                '<p>Payment Status: ' + orderRecord.Payment_Status__c + '</p>' +
                '<p>Total Amount: ' + orderRecord.Total_Amount__c + '</p>' +
                '<p>Discounted Total: ' + orderRecord.Discounted_Total__c +
                '</p></body></html>';

            Messaging.SingleEmailMessage message =
                new Messaging.SingleEmailMessage();
            message.setToAddresses(recipients);
            message.setSubject('Payment Confirmation - ' + orderRecord.Name);
            message.setHtmlBody(body);
            message.setSaveAsActivity(false);
            messages.add(message);
        }

        if (!messages.isEmpty()) {
            Messaging.sendEmail(messages);
        }
    }
}
