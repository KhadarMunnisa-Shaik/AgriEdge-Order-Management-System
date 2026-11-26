
public with sharing class OrderTotalUpdater {
    public static void updateOrderTotal(Set<Id> orderIds) {
        if (orderIds == null || orderIds.isEmpty()) return;

        Map<Id, Decimal> orderTotals = new Map<Id, Decimal>();

        for (AggregateResult result : [
            SELECT AgriEdge_Order__c orderId,
                   SUM(Total_Price__c) totalAmount
            FROM AgriEdge_OrderItem__c
            WHERE AgriEdge_Order__c IN :orderIds
            GROUP BY AgriEdge_Order__c
        ]) {
            orderTotals.put(
                (Id) result.get('orderId'),
                (Decimal) result.get('totalAmount')
            );
        }

        List<AgriEdge_Order__c> ordersToUpdate = [
            SELECT Id, Total_Amount__c, Payment_Status__c
            FROM AgriEdge_Order__c
            WHERE Id IN :orderIds
        ];

        for (AgriEdge_Order__c orderRecord : ordersToUpdate) {
            Decimal calculatedTotal = orderTotals.containsKey(orderRecord.Id)
                ? orderTotals.get(orderRecord.Id)
                : 0;

            orderRecord.Total_Amount__c = calculatedTotal;
            orderRecord.Payment_Status__c =
                calculatedTotal > 0 ? 'Pending' : 'Paid';
        }

        if (!ordersToUpdate.isEmpty()) {
            update ordersToUpdate;
        }
    }
}
