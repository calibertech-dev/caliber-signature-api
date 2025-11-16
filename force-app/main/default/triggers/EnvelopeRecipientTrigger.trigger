trigger EnvelopeRecipientTrigger on Envelope_Recipient__c (
    before insert,
    before update,
    after insert,
    after update,
    after delete,
    after undelete
) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            EnvelopeRecipientTriggerHandler.beforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            EnvelopeRecipientTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            EnvelopeRecipientTriggerHandler.afterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            EnvelopeRecipientTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isDelete) {
            EnvelopeRecipientTriggerHandler.afterDelete(Trigger.old);
        } else if (Trigger.isUndelete) {
            EnvelopeRecipientTriggerHandler.afterUndelete(Trigger.new);
        }
    }
}
