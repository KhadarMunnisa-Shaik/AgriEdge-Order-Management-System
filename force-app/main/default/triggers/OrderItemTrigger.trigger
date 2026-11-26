trigger OrderItemTrigger on AgriEdge_OrderItem__c (
    after insert, after update, after delete, after undelete
) {
    // Prevent nested processing during main Order trigger operations.
    if (AgriEdgeOrderTriggerHelper.isTriggerExecuted) {
        return;
    }

    Set<Id> orderIds = new Set<Id>();

    if (Trigger.isInsert || Trigger.isUndelete) {
        for (AgriEdge_OrderItem__c item : Trigger.new) {
            if (item.AgriEdge_Order__c != null) {
                orderIds.add(item.AgriEdge_Order__c);
            }
        }
    }

    if (Trigger.isUpdate || Trigger.isDelete) {
        for (AgriEdge_OrderItem__c item : Trigger.old) {
            if (item.AgriEdge_Order__c != null) {
                orderIds.add(item.AgriEdge_Order__c);
            }
        }
    }

    if (Trigger.isUpdate) {
        for (AgriEdge_OrderItem__c item : Trigger.new) {
            if (item.AgriEdge_Order__c != null) {
                orderIds.add(item.AgriEdge_Order__c);
            }
        }
    }

    if (!orderIds.isEmpty()) {
        OrderStatusUpdater.updateOrderStatus(orderIds);
        OrderTotalUpdater.updateOrderTotal(orderIds);
    }
}