public with sharing class EnvelopeTriggerHandler {

    public static void beforeInsert(List<Envelope__c> newList) {
        // Upcast to SObject for the shared service
        List<SObject> asSObjects = new List<SObject>();
        for (Envelope__c rec : newList) {
            asSObjects.add(rec);
        }
        PolymorphicRecordNameService.updateParentRecordNames(asSObjects, null);
    }

    public static void beforeUpdate(List<Envelope__c> newList,
                                    Map<Id, Envelope__c> oldMap) {
        // Upcast to SObject/Map<Id,SObject>
        List<SObject> asSObjects = new List<SObject>();
        for (Envelope__c rec : newList) {
            asSObjects.add(rec);
        }
        Map<Id, SObject> oldAsSObjects = new Map<Id, SObject>();
        for (Id key : oldMap.keySet()) {
            oldAsSObjects.put(key, oldMap.get(key));
        }

        PolymorphicRecordNameService.updateParentRecordNames(asSObjects, oldAsSObjects);
    }

    // Stubs for future logic if you need them later
    public static void afterInsert(List<Envelope__c> newList) {}
    public static void afterUpdate(List<Envelope__c> newList,
                                   Map<Id, Envelope__c> oldMap) {}
    public static void afterDelete(List<Envelope__c> oldList) {}
    public static void afterUndelete(List<Envelope__c> newList) {}
}
