public with sharing class EnvelopeRecipientTriggerHandler {

    public static void beforeInsert(List<Envelope_Recipient__c> newList) {
        List<SObject> asSObjects = new List<SObject>();
        for (Envelope_Recipient__c rec : newList) {
            asSObjects.add(rec);
        }
        PolymorphicRecordNameService.updateParentRecordNames(asSObjects, null);
    }

    public static void beforeUpdate(List<Envelope_Recipient__c> newList,
                                    Map<Id, Envelope_Recipient__c> oldMap) {
        List<SObject> asSObjects = new List<SObject>();
        for (Envelope_Recipient__c rec : newList) {
            asSObjects.add(rec);
        }
        Map<Id, SObject> oldAsSObjects = new Map<Id, SObject>();
        for (Id key : oldMap.keySet()) {
            oldAsSObjects.put(key, oldMap.get(key));
        }

        PolymorphicRecordNameService.updateParentRecordNames(asSObjects, oldAsSObjects);
    }

    // Stubs for future logic
    public static void afterInsert(List<Envelope_Recipient__c> newList) {}
    public static void afterUpdate(List<Envelope_Recipient__c> newList,
                                   Map<Id, Envelope_Recipient__c> oldMap) {}
    public static void afterDelete(List<Envelope_Recipient__c> oldList) {}
    public static void afterUndelete(List<Envelope_Recipient__c> newList) {}
}
