public with sharing class SignatureApiNotificationService {

    /**
     * Called after a successful envelope create.
     * - Fetches Envelope__c → Parent → Document_Template__c → Envelope_Template__c
     * - Uses Signing_Request_Email_Template__c
     * - Sends emails to recipients whose Ceremony_URL__c is populated
     *   (manual ceremony mode only).
     */
    public static void handlePostCreateNotifications(Id envelopeId) {
        Envelope__c env = [
            SELECT Id,
                   Parent_Record_Type__c,
                   Parent_Record_Id__c
            FROM Envelope__c
            WHERE Id = :envelopeId
        ];

        // Parent record (Contract, Proposal, etc.) so you can use it as whatId in the email
        SObject parent = SignatureApiEnvelopeOrchestrationService.loadParent(
            env.Parent_Record_Id__c,
            env.Parent_Record_Type__c
        );

        // Find Document Template → Envelope Template
        Id documentTemplateId = (Id)parent.get('Document_Template__c');
        if (documentTemplateId == null) {
            // Misconfiguration; nothing we can do
            return;
        }

        Document_Template__c docTmpl = [
            SELECT Id, Envelope_Template__c
            FROM Document_Template__c
            WHERE Id = :documentTemplateId
        ];

        if (docTmpl.Envelope_Template__c == null) {
            return;
        }

        Envelope_Template__c eTemplate = [
            SELECT Id,
                   Signing_Request_Email_Template__c,
                   Ceremony_Creation__c
            FROM Envelope_Template__c
            WHERE Id = :docTmpl.Envelope_Template__c
        ];

        // If ceremonies are automatic, let SignatureAPI handle notification emails
        if (eTemplate.Ceremony_Creation__c == 'automatic') {
            return;
        }

        if (String.isBlank(eTemplate.Signing_Request_Email_Template__c)) {
            // Nothing to send; configuration choice
            return;
        }

        Id emailTemplateId = (Id)eTemplate.Signing_Request_Email_Template__c;

        // Fetch recipients
        List<Envelope_Recipient__c> recs = [
            SELECT Id,
                   Name,
                   Recipient_Email__c,
                   Recipient_Key__c,
                   Ceremony_URL__c,
                   Status__c
            FROM Envelope_Recipient__c
            WHERE Envelope__c = :env.Id
        ];

        if (recs.isEmpty()) return;

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Envelope_Recipient__c r : recs) {
            // Only send if we have both email and ceremony URL
            if (String.isBlank(r.Recipient_Email__c) || String.isBlank(r.Ceremony_URL__c)) {
                continue;
            }

            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setToAddresses(new String[] { r.Recipient_Email__c });
            msg.setTemplateId(emailTemplateId);

            // Use the parent record as the whatId so merge fields point at Contract/Proposal
            msg.setWhatId(parent.Id);

            // If you have a Contact to attach, you can setTargetObjectId here too.

            emails.add(msg);
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails, false);
        }
    }
}
