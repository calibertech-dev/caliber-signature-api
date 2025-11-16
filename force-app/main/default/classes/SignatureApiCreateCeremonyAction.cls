public with sharing class SignatureApiCreateCeremonyAction{

    public class CeremonyRequest {
        @InvocableVariable(
            label='Envelope Recipient Id' 
            required=true
            description='SignatureAPI RecipientId'
        )
        public Id envelopeRecipientId;
    }

    public class CeremonyResponse {
        @InvocableVariable(
            label='Envelope Recipient Id' 
            description='SignatureAPI RecipientId'
        )
        public Id envelopeRecipientId;

        @InvocableVariable(
            label='Ceremony URL'
            description='URL for the created SignatureAPI ceremony.'
        )
        public String ceremonyUrl;

        @InvocableVariable(
            label='Error'
            description='Any error encountered during ceremony creation.'
        )
        public String error;
    }

    @InvocableMethod(
        label='SignatureApi - Create Ceremony for Recipient'
        description='Creates a SignatureApi ceremony for a given Envelope_Recipient__c and stores the URL.'
    )
    public static List<CeremonyResponse> createCeremonies(List<CeremonyRequest> requests) {
        List<CeremonyResponse> out = new List<CeremonyResponse>();

        for (CeremonyRequest req : requests) {
            CeremonyResponse resp = new CeremonyResponse();
            resp.envelopeRecipientId = req.envelopeRecipientId;

            SignatureApiCeremonyService.CeremonyResult serviceRes =
                SignatureApiCeremonyService.createCeremonyForRecipient(req.envelopeRecipientId);

            resp.ceremonyUrl = serviceRes.ceremonyUrl;
            resp.error       = serviceRes.error;

            out.add(resp);
        }

        return out;
    }
}
