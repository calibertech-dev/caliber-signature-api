@RestResource(urlMapping='/signatureapi/webhook')
global with sharing class SignatureApiWebhookHandler {

    @HttpPost
    global static void handleWebhook() {
        RestRequest  req = RestContext.request;
        RestResponse res = RestContext.response;

        // Default response
        res.statusCode   = 200;
        res.responseBody = Blob.valueOf('OK');

        String body = null;

        try {
            body = req.requestBody != null
                ? req.requestBody.toString()
                : '';

            if (String.isBlank(body)) {
                // Nothing we can do, but still return 200 so SignatureApi doesn't retry forever
                System.debug('SignatureApiWebhookHandler: empty body received');
                return;
            }

            // Parse JSON
            Map<String, Object> payload =
                (Map<String, Object>)JSON.deserializeUntyped(body);

            String eventType = (String)payload.get('type');
            Map<String, Object> data =
                (Map<String, Object>)payload.get('data');

            String envelopeId   = data != null ? (String)data.get('envelope_id')   : null;
            String objectId     = data != null ? (String)data.get('object_id')     : null;
            String recipientKey = data != null ? (String)data.get('recipient_key') : null;
            String status       = data != null ? (String)data.get('status')        : null;

            // Create Envelope_Event__c record for auditing
            Envelope_Event__c evt = new Envelope_Event__c();
            evt.Event_Type__c     = eventType;
            evt.Envelope_Id__c    = envelopeId;
            evt.Object_Id__c      = objectId;        // adjust field name if needed
            evt.Recipient_Key__c  = recipientKey;
            evt.Status__c         = status;
            evt.Raw_Payload__c    = body;
            evt.Processing_Status__c = 'Received';   // optional, if you have this field

            insert evt;

            // Hand off to async processor so this endpoint stays fast & reliable
            System.enqueueJob(new SignatureApiWebhookProcessor(evt.Id));

        } catch (Exception e) {
            System.debug('Error in SignatureApiWebhookHandler: ' + e.getMessage());

            try {
                Envelope_Event__c errorEvt = new Envelope_Event__c();
                errorEvt.Event_Type__c        = 'webhook.error';
                errorEvt.Raw_Payload__c       = body;
                errorEvt.Error_Message__c     = e.getMessage();
                errorEvt.Processing_Status__c = 'Failed';
                insert errorEvt;
            } catch (Exception logEx) {
                System.debug('Failed to log webhook error event: ' + logEx.getMessage());
            }
        }

    }
}
