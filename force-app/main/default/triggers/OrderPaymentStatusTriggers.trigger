trigger OrderPaymentStatusTriggers on AgriEdge_Order__c (after update) {
    Set<Id> paidOrderIds = new Set<Id>();

    for (AgriEdge_Order__c currentOrder : Trigger.new) {
        AgriEdge_Order__c oldOrder = Trigger.oldMap.get(currentOrder.Id);

        if (currentOrder.Payment_Status__c == 'Paid' &&
            oldOrder.Payment_Status__c != 'Paid' &&
            currentOrder.Customer__c != null) {
            paidOrderIds.add(currentOrder.Id);
        }
    }

    if (!paidOrderIds.isEmpty()) {
        OrderEmailSender.sendOrderEmail(paidOrderIds);
    }
}
