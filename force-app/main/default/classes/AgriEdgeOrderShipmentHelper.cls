public with sharing class AgriEdgeOrderShipmentHelper {
    public static void processOrderStatusChange(
        List<AgriEdge_Order__c> changedOrders
    ) {
        if (changedOrders == null || changedOrders.isEmpty()) return;

        Set<Id> orderIds = new Set<Id>();

        for (AgriEdge_Order__c orderRecord : changedOrders) {
            if (orderRecord.Id != null) {
                orderIds.add(orderRecord.Id);
            }
        }

        if (orderIds.isEmpty()) return;

        List<Shipment__c> existingShipments = [
            SELECT Id, AgriEdge_Order__c, Shipment_Status__c
            FROM Shipment__c
            WHERE AgriEdge_Order__c IN :orderIds
        ];

        Set<Id> ordersWithShipments = new Set<Id>();
        List<Shipment__c> shipmentsToDelete = new List<Shipment__c>();
        List<Shipment__c> shipmentsToUpdate = new List<Shipment__c>();

        Map<Id, AgriEdge_Order__c> ordersById =
            new Map<Id, AgriEdge_Order__c>(changedOrders);

        for (Shipment__c shipment : existingShipments) {
            AgriEdge_Order__c relatedOrder =
                ordersById.get(shipment.AgriEdge_Order__c);

            if (relatedOrder == null) continue;

            ordersWithShipments.add(shipment.AgriEdge_Order__c);

            if (relatedOrder.Payment_Status__c == 'Failed' ||
                relatedOrder.Order_Status__c == 'Canceled') {
                shipmentsToDelete.add(shipment);
            } else if (relatedOrder.Payment_Status__c == 'Paid' ||
                       relatedOrder.Order_Status__c == 'Delivered') {
                if (shipment.Shipment_Status__c != 'Delivered') {
                    shipment.Shipment_Status__c = 'Delivered';
                    shipmentsToUpdate.add(shipment);
                }
            } else if (relatedOrder.Order_Status__c == 'Shipped') {
                if (shipment.Shipment_Status__c != 'In Transit') {
                    shipment.Shipment_Status__c = 'In Transit';
                    shipmentsToUpdate.add(shipment);
                }
            }
        }

        List<Shipment__c> shipmentsToInsert = new List<Shipment__c>();

        for (AgriEdge_Order__c orderRecord : changedOrders) {
            if (orderRecord.Id == null ||
                ordersWithShipments.contains(orderRecord.Id)) {
                continue;
            }

            if (orderRecord.Payment_Status__c != 'Failed' &&
                orderRecord.Order_Status__c == 'Processing') {
                shipmentsToInsert.add(new Shipment__c(
                    AgriEdge_Order__c = orderRecord.Id,
                    Tracking_Number__c = 'TEST_' +
                        String.valueOf(orderRecord.Id),
                    Shipment_Status__c = 'Pending'
                ));
            }
        }

        if (!shipmentsToDelete.isEmpty()) delete shipmentsToDelete;
        if (!shipmentsToUpdate.isEmpty()) update shipmentsToUpdate;
        if (!shipmentsToInsert.isEmpty()) insert shipmentsToInsert;
    }
}
