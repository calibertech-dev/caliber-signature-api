public with sharing class SignatureApiDownloadAction {

    public class DownloadRequest {
        @InvocableVariable(
            label='Envelope Id'
            required=true
            description='SignatureApi envelope id (not the Salesforce Envelope__c Id).'
        )
        public String envelopeId;

        @InvocableVariable(
            label='File Name'
            required=true
            description='Base file name (without .pdf) for the downloaded document.'
        )
        public String fileName;

        @InvocableVariable(
            label='Parent Record Id'
            required=true
            description='Salesforce record that should own the downloaded file.'
        )
        public Id parentRecordId;
    }

    public class DownloadResponse {
        @InvocableVariable(
            label='Content Version Id'
            description='Id of the created ContentVersion record.'
        )
        public Id contentVersionId;

        @InvocableVariable(
            label='Error'
            description='Any error that occurred during download or file creation.'
        )
        public String error;
    }

    @InvocableMethod(
        label='SignatureApi - Download Completed Envelope PDF'
        description='Downloads the completed envelope PDF from SignatureApi and attaches it as a ContentVersion to the specified Salesforce record.'
    )
    public static List<DownloadResponse> downloadCompleted(List<DownloadRequest> reqs) {
        List<DownloadResponse> results = new List<DownloadResponse>();

        for (DownloadRequest req : reqs) {
            DownloadResponse resp = new DownloadResponse();

            try {
                if (req == null) {
                    resp.error = 'Request is null.';
                    results.add(resp);
                    continue;
                }

                SignatureApiDownloadService.DownloadResult serviceRes =
                    SignatureApiDownloadService.downloadFinalDeliverable(
                        req.envelopeId,
                        req.parentRecordId,
                        req.fileName
                    );

                resp.contentVersionId = serviceRes.contentVersionId;
                resp.error            = serviceRes.error;

            } catch (Exception ex) {
                resp.error = ex.getMessage();
            }

            results.add(resp);
        }

        return results;
    }
}
