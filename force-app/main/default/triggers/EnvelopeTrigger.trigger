trigger EnvelopeTrigger on Envelope__c (
    before insert,
    before update,
    after insert,
    after update,
    after delete,
    after undelete
) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            EnvelopeTriggerHandler.beforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            EnvelopeTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            EnvelopeTriggerHandler.afterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            EnvelopeTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isDelete) {
            EnvelopeTriggerHandler.afterDelete(Trigger.old);
        } else if (Trigger.isUndelete) {
            EnvelopeTriggerHandler.afterUndelete(Trigger.new);
        }
    }
}
