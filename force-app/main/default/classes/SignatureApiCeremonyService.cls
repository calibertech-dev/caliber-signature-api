public with sharing class SignatureApiCeremonyService {

    public class CeremonyResult {
        public Id envelopeRecipientId;
        public String ceremonyUrl;
        public String error;
    }

    /**
     * Core method: create a ceremony for a single Envelope_Recipient__c.
     * Expects Envelope_Recipient__c.Recipient_Id__c to be populated
     * from the envelope creation response.
     */
    public static CeremonyResult createCeremonyForRecipient(Id envelopeRecipientId) {
        CeremonyResult res = new CeremonyResult();
        res.envelopeRecipientId = envelopeRecipientId;

        try {
            // Load recipient + parent envelope
            Envelope_Recipient__c rec = [
                SELECT Id,
                       Envelope__c,
                       Recipient_Id__c,
                       Ceremony_URL__c
                FROM Envelope_Recipient__c
                WHERE Id = :envelopeRecipientId
            ];

            if (String.isBlank(rec.Recipient_Id__c)) {
                res.error = 'SignatureApi recipient id is missing on Envelope_Recipient__c.';
                return res;
            }

            String recipientExternalId = rec.Recipient_Id__c;

            // Build endpoint: /v1/recipients/{id}/ceremony using Named Credential
            String endpoint = 'callout:SignatureApi'
                            + '/v1/recipients/'
                            + EncodingUtil.urlEncode(recipientExternalId, 'UTF-8')
                            + '/ceremony';

            // Custom auth payload (same shape as your legacy implementation)
            Map<String, Object> authBlock = new Map<String, Object>{
                'type'     => 'custom',
                'provider' => 'Salesforce',
                'data'     => new Map<String, Object>{
                    'requested_at' => String.valueOf(Datetime.now().getTime()),
                    'requested_by' => String.valueOf(UserInfo.getUserId())
                }
            };

            Map<String, Object> payload = new Map<String, Object>{
                'authentication' => new List<Object>{ authBlock }
            };

            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(payload));

            HttpResponse h = http.send(req);

            if (h.getStatusCode() >= 200 && h.getStatusCode() < 300) {
                Map<String, Object> body =
                    (Map<String, Object>)JSON.deserializeUntyped(h.getBody());
                String url = (String)body.get('url');

                if (String.isBlank(url)) {
                    res.error = 'Ceremony created but no URL returned from SignatureApi.';
                    return res;
                }

                // Persist URL on the recipient
                rec.Ceremony_URL__c = url;
                update rec;

                res.ceremonyUrl = url;
                return res;
            } else {
                res.error = 'Ceremony creation failed: ' +
                            h.getStatusCode() + ' ' + h.getBody();
                return res;
            }

        } catch (Exception e) {
            res.error = e.getMessage();
            return res;
        }
    }
}
