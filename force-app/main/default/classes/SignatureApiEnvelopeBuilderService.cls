public with sharing class SignatureApiEnvelopeBuilderService {

    // =========================
    // Context / Result
    // =========================

    public class BuildContext {
        public Id envelopeId;
        public Boolean sendImmediately;
        public Id contentVersionId; // optional

        public BuildContext(Id envelopeId, Boolean sendImmediately) {
            this.envelopeId = envelopeId;
            this.sendImmediately = sendImmediately;
            this.contentVersionId = null;
        }

        public BuildContext(Id envelopeId, Boolean sendImmediately, Id contentVersionId) {
            this.envelopeId = envelopeId;
            this.sendImmediately = sendImmediately;
            this.contentVersionId = contentVersionId;
        }
    }

    public class BuildResult {
        public Id envelopeId;
        public String signatureApiEnvelopeId;
        public String status;
        public String errorMessage;
    }

    // =========================
    // Main entry point
    // =========================

    public static BuildResult buildAndSendEnvelope(BuildContext ctx) {
        BuildResult result = new BuildResult();
        result.envelopeId = ctx.envelopeId;

        try {
            // Lock Envelope__c
            Envelope__c env = [
                SELECT Id,
                       Name,
                       Parent_Record_Type__c,
                       Parent_Record_Id__c,
                       Status__c,
                       Envelope_Id__c
                FROM Envelope__c
                WHERE Id = :ctx.envelopeId
                FOR UPDATE
            ];

            // Load parent (Contract__c, Proposal__c, etc.)
            SObject parent = SignatureApiEnvelopeOrchestrationService.loadParent(
                env.Parent_Record_Id__c,
                env.Parent_Record_Type__c
            );

            Id documentTemplateId = (Id)parent.get('Document_Template__c');
            if (documentTemplateId == null) {
                throw new CalloutException('No Document Template found on parent record.');
            }

            Document_Template__c docTmpl = [
                SELECT Id, Name, Envelope_Template__c
                FROM Document_Template__c
                WHERE Id = :documentTemplateId
            ];

            if (docTmpl.Envelope_Template__c == null) {
                throw new CalloutException('No Envelope Template linked to this Document Template.');
            }

            Envelope_Template__c envTmpl = [
                SELECT Id,
                       Name,
                       Branding__c,
                       Default_Topics__c,
                       Routing_Mode__c,
                       Ceremony_Creation__c
                FROM Envelope_Template__c
                WHERE Id = :docTmpl.Envelope_Template__c
            ];

            // Build payload
            Map<String, Object> payload = new Map<String, Object>();

            // Routing + ceremony creation
            String routingMode      = envTmpl.Routing_Mode__c;      // Sequential / Parallel
            String ceremonyCreation = envTmpl.Ceremony_Creation__c; // Manual / Automatic

            String routing      = (routingMode == 'Parallel') ? 'parallel' : 'sequential';
            String ceremonyMode = (ceremonyCreation == 'Automatic') ? 'automatic' : 'manual';

            payload.put('routing', routing);
            payload.put('title', env.Name);                 // safe to READ auto-number
            payload.put('message', envTmpl.Default_Topics__c);

            // Recipients
            List<Object> recipientsJson = buildRecipientsPayload(env.Id, ceremonyMode);
            payload.put('recipients', recipientsJson);

            // Documents: ContentVersion if provided, else Document_URL__c on parent
            List<Object> documentsJson = buildDocumentsPayload(
                env,
                parent,
                docTmpl,
                envTmpl,
                ctx.contentVersionId
            );
            payload.put('documents', documentsJson);

            // Call SignatureApi
            SignatureApiClient.EnvelopeCreateResponse apiRes =
                SignatureApiClient.createEnvelope(payload);

            // Update envelope
            env.Envelope_Id__c = apiRes.id;
            env.Status__c      = apiRes.status;
            update env;

            // Map ceremony URLs + recipient ids back to Envelope_Recipient__c
            applyCeremonyUrls(env.Id, apiRes);

            result.signatureApiEnvelopeId = apiRes.id;
            result.status                 = apiRes.status;
            return result;

        } catch (Exception ex) {
            // You can wire this into ErrorLogService later
            result.errorMessage = ex.getMessage();
            return result;
        }
    }

    // =========================
    // Recipients payload
    // =========================

    private static List<Object> buildRecipientsPayload(Id envelopeId, String ceremonyMode) {
        List<Envelope_Recipient__c> recs = [
            SELECT Id,
                   Name,
                   Recipient_Email__c,
                   Recipient_Key__c
            FROM Envelope_Recipient__c
            WHERE Envelope__c = :envelopeId
            ORDER BY CreatedDate
        ];

        List<Object> out = new List<Object>();

        for (Envelope_Recipient__c r : recs) {
            Map<String, Object> rJson = new Map<String, Object>();
            rJson.put('key',   r.Recipient_Key__c);
            rJson.put('type',  'signer');
            rJson.put('name',  r.Name);                // auto-number is fine as a label
            rJson.put('email', r.Recipient_Email__c);
            rJson.put('ceremony_creation', ceremonyMode);

            if (ceremonyMode == 'manual') {
                rJson.put('delivery_type', 'none');
            } else {
                rJson.put('delivery_type', 'email');
            }

            out.add(rJson);
        }

        return out;
    }

    // =========================
    // Documents payload
    // =========================

    private static List<Object> buildDocumentsPayload(
        Envelope__c env,
        SObject parent,
        Document_Template__c docTmpl,
        Envelope_Template__c envTmpl,
        Id contentVersionId
    ) {
        List<Object> docs = new List<Object>();

        String parentDocUrl = tryGetDocumentUrlFromParent(parent);

        if (contentVersionId != null) {
            docs.add(buildDocumentFromContentVersion(contentVersionId, env, docTmpl, envTmpl));
        } else if (!String.isBlank(parentDocUrl)) {
            docs.add(buildDocumentFromUrl(parentDocUrl, env, docTmpl, envTmpl));
        } else {
            throw new CalloutException(
                'No document source configured. Either a ContentVersion Id must be passed from Flow/LWC or Document_URL__c must be populated on the parent.'
            );
        }

        return docs;
    }

    private static String tryGetDocumentUrlFromParent(SObject parent) {
        Map<String, SObjectField> fieldMap =
            parent.getSObjectType().getDescribe().fields.getMap();

        if (fieldMap.containsKey('Document_URL__c')) {
            try {
                return (String)parent.get('Document_URL__c');
            } catch (Exception e) {
                return null;
            }
        }
        return null;
    }

    private static Map<String, Object> buildDocumentFromUrl(
        String documentUrl,
        Envelope__c env,
        Document_Template__c docTmpl,
        Envelope_Template__c envTmpl
    ) {
        Map<String, Object> docJson = new Map<String, Object>();
        docJson.put('url', documentUrl);
        docJson.put('format', 'pdf');
        docJson.put('places', buildPlacesFromTemplates(envTmpl));
        return docJson;
    }

    private static Map<String, Object> buildDocumentFromContentVersion(
        Id contentVersionId,
        Envelope__c env,
        Document_Template__c docTmpl,
        Envelope_Template__c envTmpl
    ) {
        ContentVersion cv = [
            SELECT Id, Title, VersionData
            FROM ContentVersion
            WHERE Id = :contentVersionId
            LIMIT 1
        ];

        Http http = new Http();

        // 1) Create file shell
        HttpRequest fileReq = new HttpRequest();
        fileReq.setEndpoint('callout:SignatureApi/v1/files');
        fileReq.setMethod('POST');
        fileReq.setHeader('Content-Type', 'application/json');
        fileReq.setBody(JSON.serialize(new Map<String, Object>{
            'filename' => cv.Title + '.pdf'
        }));

        HttpResponse fileRes = http.send(fileReq);
        if (fileRes.getStatusCode() >= 300) {
            throw new CalloutException(
                'File create failed: ' + fileRes.getStatus() + ' ' + fileRes.getBody()
            );
        }

        Map<String, Object> fmap =
            (Map<String, Object>)JSON.deserializeUntyped(fileRes.getBody());
        String fileId = (String)fmap.get('id');
        String putUrl = (String)fmap.get('put_url');

        // 2) Upload PDF
        HttpRequest putReq = new HttpRequest();
        putReq.setEndpoint(putUrl);
        putReq.setMethod('PUT');
        putReq.setHeader('Content-Type', 'application/pdf');
        putReq.setBodyAsBlob(cv.VersionData);

        HttpResponse putRes = http.send(putReq);
        if (putRes.getStatusCode() >= 300) {
            throw new CalloutException(
                'File upload failed: ' + putRes.getStatus() + ' ' + putRes.getBody()
            );
        }

        String docUrl = 'https://api.signatureapi.com/v1/files/' + fileId;

        Map<String, Object> docJson = new Map<String, Object>();
        docJson.put('url', docUrl);
        docJson.put('format', 'pdf');
        docJson.put('places', buildPlacesFromTemplates(envTmpl));

        return docJson;
    }

    // =========================
    // Places payload
    // =========================

    private static List<Object> buildPlacesFromTemplates(Envelope_Template__c envTmpl) {
        List<Envelope_Place_Template__c> pts = [
            SELECT Id,
                   Place_Type__c,
                   Place_Key__c,
                   Recipient_Key__c,
                   Height__c,
                   Capture_As__c,
                   Hint__c,
                   Prompt__c,
                   Requirement__c,
                   Format__c,
                   Format_Message__c,
                   Width__c,
                   Font_Size__c,
                   Symbol__c,
                   Date_Format__c,
                   Sort_Order__c
            FROM Envelope_Place_Template__c
            WHERE Envelope_Template__c = :envTmpl.Id
            ORDER BY Sort_Order__c NULLS LAST, CreatedDate
        ];

        List<Object> places = new List<Object>();

        for (Envelope_Place_Template__c pt : pts) {
            String t = pt.Place_Type__c;
            Map<String, Object> p = new Map<String, Object>();

            // Base fields
            p.put('type', t);
            p.put('key', pt.Place_Key__c);
            p.put('recipient_key', pt.Recipient_Key__c);

            if (t == 'signature' || t == 'initials') {
                if (pt.Height__c != null) {
                    p.put('height', pt.Height__c);
                }
            }
            else if (t == 'text_input') {
                if (!String.isBlank(pt.Capture_As__c)) {
                    p.put('capture_as', pt.Capture_As__c);
                }
                if (!String.isBlank(pt.Hint__c)) {
                    p.put('hint', pt.Hint__c);
                }
                if (!String.isBlank(pt.Prompt__c)) {
                    p.put('prompt', pt.Prompt__c);
                }
                if (!String.isBlank(pt.Requirement__c)) {
                    p.put('requirement', pt.Requirement__c);
                }
                if (!String.isBlank(pt.Format__c)) {
                    p.put('format', pt.Format__c);
                }
                if (!String.isBlank(pt.Format_Message__c)) {
                    p.put('format_message', pt.Format_Message__c);
                }
                if (pt.Width__c != null) {
                    p.put('width', pt.Width__c);
                }
                if (pt.Font_Size__c != null) {
                    p.put('font_size', pt.Font_Size__c);
                }
            }
            else if (t == 'checkbox') {
                if (!String.isBlank(pt.Capture_As__c)) {
                    p.put('capture_as', pt.Capture_As__c);
                }
                if (!String.isBlank(pt.Symbol__c)) {
                    p.put('symbol', pt.Symbol__c);
                }
                if (!String.isBlank(pt.Requirement__c)) {
                    p.put('requirement', pt.Requirement__c);
                }
                if (pt.Height__c != null) {
                    p.put('height', pt.Height__c);
                }
            }
            else if (t == 'envelope_completed_date') {
                if (!String.isBlank(pt.Date_Format__c)) {
                    p.put('date_format', pt.Date_Format__c);
                }
            }
            else if (t == 'recipient_name' || t == 'recipient_email') {
                // base only
            }
            else {
                throw new CalloutException('Unsupported place type: ' + t);
            }

            places.add(p);
        }

        return places;
    }

    // =========================
    // Ceremony URLs & recipient ids
    // =========================

    private static void applyCeremonyUrls(Id envelopeId, SignatureApiClient.EnvelopeCreateResponse apiRes) {
        if (apiRes == null || apiRes.recipients == null || apiRes.recipients.isEmpty()) {
            return;
        }

        List<Envelope_Recipient__c> recsToUpdate = [
            SELECT Id,
                   Recipient_Key__c,
                   Ceremony_URL__c,
                   Recipient_Id__c
            FROM Envelope_Recipient__c
            WHERE Envelope__c = :envelopeId
        ];

        if (recsToUpdate.isEmpty()) return;

        for (Envelope_Recipient__c r : recsToUpdate) {
            for (SignatureApiClient.RecipientInfo info : apiRes.recipients) {
                if (info.key == r.Recipient_Key__c) {
                    if (!String.isBlank(info.id)) {
                        r.Recipient_Id__c = info.id; // your external recipient id field
                    }
                    if (!String.isBlank(info.ceremonyUrl)) {
                        r.Ceremony_URL__c = info.ceremonyUrl;
                    }
                    break;
                }
            }
        }

        update recsToUpdate;
    }
}
