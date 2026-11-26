trigger AgriEdgeOrderTrigger on AgriEdge_Order__c (
    before insert, before update, after insert, after update
) {
    if (AgriEdgeOrderTriggerHelper.isTriggerExecuted) {
        return;
    }

    // Set order status before saving the Order record.
    if (Trigger.isBefore) {
        for (AgriEdge_Order__c currentOrder : Trigger.new) {
            if (currentOrder.Payment_Status__c == 'Failed') {
                currentOrder.Order_Status__c = 'Canceled';
            } else if (currentOrder.Payment_Status__c == 'Paid') {
                currentOrder.Order_Status__c = 'Delivered';
            } else if (
                currentOrder.Payment_Status__c == 'Pending' &&
                currentOrder.Order_Status__c == 'New'
            ) {
                currentOrder.Order_Status__c = 'Processing';
            }
        }
    }

    // Handle related records after the Order has been saved.
    if (Trigger.isAfter) {
        AgriEdgeOrderTriggerHelper.isTriggerExecuted = true;

        try {
            Set<Id> failedOrderIds = new Set<Id>();

            for (AgriEdge_Order__c currentOrder : Trigger.new) {
                if (currentOrder.Payment_Status__c == 'Failed') {
                    failedOrderIds.add(currentOrder.Id);
                }
            }

            // Remove order items belonging to failed orders.
            if (!failedOrderIds.isEmpty()) {
                List<AgriEdge_OrderItem__c> itemsToDelete = [
                    SELECT Id
                    FROM AgriEdge_OrderItem__c
                    WHERE AgriEdge_Order__c IN :failedOrderIds
                ];

                if (!itemsToDelete.isEmpty()) {
                    delete itemsToDelete;
                }
            }

            // Create or update shipments based on the latest order status.
            AgriEdgeOrderShipmentHelper.processOrderStatusChange(
                Trigger.new
            );

        } finally {
            AgriEdgeOrderTriggerHelper.isTriggerExecuted = false;
        }
    }
}
