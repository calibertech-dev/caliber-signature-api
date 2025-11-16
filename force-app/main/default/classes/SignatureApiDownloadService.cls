public with sharing class SignatureApiDownloadService {

    public class DownloadResult {
        public Id contentVersionId;
        public String error;
    }

    /**
     * Download the final/primary deliverable for a SignatureApi envelope
     * and attach it to the given parent record as a ContentVersion.
     *
     * - envelopeId: SignatureApi envelope id (NOT the Salesforce Envelope__c Id)
     * - parentRecordId: Salesforce record that should own the uploaded file
     * - fileName: Base file name (without .pdf)
     */
    public static DownloadResult downloadFinalDeliverable(
        String envelopeId,
        Id parentRecordId,
        String fileName
    ) {
        DownloadResult result = new DownloadResult();

        if (String.isBlank(envelopeId)) {
            result.error = 'Envelope Id is required.';
            return result;
        }
        if (parentRecordId == null) {
            result.error = 'Parent Record Id is required.';
            return result;
        }
        if (String.isBlank(fileName)) {
            fileName = 'Signed Document';
        }

        Http http = new Http();

        try {
            // 1) List deliverables for this envelope
            String listEndpoint = 'callout:SignatureApi/v1/envelopes/' +
                                  EncodingUtil.urlEncode(envelopeId, 'UTF-8') +
                                  '/deliverables';

            HttpRequest listReq = new HttpRequest();
            listReq.setEndpoint(listEndpoint);
            listReq.setMethod('GET');

            HttpResponse listRes = http.send(listReq);
            if (listRes.getStatusCode() >= 300) {
                result.error = 'Deliverables list failed: ' +
                               listRes.getStatus() + ' ' + listRes.getBody();
                return result;
            }

            Map<String, Object> listMap =
                (Map<String, Object>)JSON.deserializeUntyped(listRes.getBody());
            List<Object> dlist = (List<Object>)listMap.get('data');

            if (dlist == null || dlist.isEmpty()) {
                result.error = 'No deliverables found for envelope ' + envelopeId;
                return result;
            }

            // Prefer sealed_document type
            String deliverableId;
            for (Object o : dlist) {
                Map<String, Object> dm = (Map<String, Object>)o;
                if ('sealed_document'.equals(dm.get('type'))) {
                    deliverableId = (String)dm.get('id');
                    break;
                }
            }
            if (deliverableId == null) {
                deliverableId =
                    (String)((Map<String, Object>)dlist.get(0)).get('id');
            }

            // 2) Fetch deliverable metadata
            String metadataEndpoint = 'callout:SignatureApi/v1/deliverables/' +
                                      EncodingUtil.urlEncode(deliverableId, 'UTF-8');

            HttpRequest metadataReq = new HttpRequest();
            metadataReq.setEndpoint(metadataEndpoint);
            metadataReq.setMethod('GET');

            HttpResponse metadataRes = http.send(metadataReq);
            if (metadataRes.getStatusCode() >= 300) {
                result.error = 'Deliverable fetch failed: ' +
                               metadataRes.getStatus() + ' ' + metadataRes.getBody();
                return result;
            }

            Map<String, Object> dmap =
                (Map<String, Object>)JSON.deserializeUntyped(metadataRes.getBody());
            String downloadUrl = (String)dmap.get('url');

            if (String.isBlank(downloadUrl)) {
                result.error = 'Deliverable metadata did not include a download URL.';
                return result;
            }

            // 3) Download the PDF content (direct URL, no Named Credential)
            HttpRequest dlReq = new HttpRequest();
            dlReq.setEndpoint(downloadUrl);
            dlReq.setMethod('GET');

            HttpResponse dlRes = http.send(dlReq);
            if (dlRes.getStatusCode() != 200) {
                result.error = 'File download failed: ' +
                               dlRes.getStatus() + ' ' + dlRes.getBody();
                return result;
            }

            Blob pdfBlob = dlRes.getBodyAsBlob();

            // 4) Insert as ContentVersion and publish directly to the record
            ContentVersion cv = new ContentVersion(
                Title = fileName,
                PathOnClient = fileName + '.pdf',
                VersionData = pdfBlob,
                FirstPublishLocationId = parentRecordId
            );
            insert cv;

            result.contentVersionId = cv.Id;
            return result;

        } catch (Exception ex) {
            result.error = ex.getMessage();
            return result;
        }
    }

    /**
     * Convenience overload: given an Envelope__c record, use its Envelope_Id__c
     * and Parent_Record_Id__c automatically.
     */
    public static DownloadResult downloadFinalDeliverableForEnvelopeRecord(
        Envelope__c env,
        String fileName
    ) {
        if (env == null) {
            DownloadResult res = new DownloadResult();
            res.error = 'Envelope record is null.';
            return res;
        }

        String externalEnvelopeId = env.Envelope_Id__c;
        Id parentId = env.Parent_Record_Id__c;
        String baseName = String.isBlank(fileName) ? env.Name : fileName;

        return downloadFinalDeliverable(externalEnvelopeId, parentId, baseName);
    }
}
