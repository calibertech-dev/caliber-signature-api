public with sharing class SignatureApiClient {

    public class EnvelopeCreateResponse {
        public String id;
        public String status;
        public List<RecipientInfo> recipients;
    }

    public class RecipientInfo {
        public String id;          
        public String key;
        public String status;
        public String ceremonyUrl;
        public String email;
        public String name;
    }

    private static HttpRequest buildRequest(String method, String path, String bodyJson) {
        HttpRequest req = new HttpRequest();
        // Named Credential must be "SignatureApi"
        req.setEndpoint('callout:SignatureApi' + path);
        req.setMethod(method);
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        if (bodyJson != null) {
            req.setBody(bodyJson);
        }
        return req;
    }

    private static HttpResponse send(HttpRequest req) {
        Http http = new Http();
        HttpResponse res = http.send(req);
        Integer statusCode = res.getStatusCode();
        if (statusCode < 200 || statusCode >= 300) {
            throw new CalloutException(
                'SignatureApi call failed: ' + statusCode + ' ' + res.getStatus() +
                ' Body: ' + res.getBody()
            );
        }
        return res;
    }

    public static EnvelopeCreateResponse createEnvelope(Map<String, Object> payload) {
        String bodyJson = JSON.serialize(payload);
        HttpRequest req = buildRequest('POST', '/v1/envelopes', bodyJson);
        HttpResponse res = send(req);

        Map<String, Object> parsed =
            (Map<String, Object>)JSON.deserializeUntyped(res.getBody());

        EnvelopeCreateResponse out = new EnvelopeCreateResponse();
        out.id     = (String)parsed.get('id');
        out.status = (String)parsed.get('status');

        // Parse recipients, including id + ceremony URL if present
        List<Object> resRecipients = (List<Object>)parsed.get('recipients');
        out.recipients = new List<RecipientInfo>();
        if (resRecipients != null) {
            for (Object o : resRecipients) {
                Map<String, Object> r = (Map<String, Object>)o;
                RecipientInfo info = new RecipientInfo();
                info.id          = (String)r.get('id');   // <== NEW
                info.key         = (String)r.get('key');
                info.status      = (String)r.get('status');
                info.ceremonyUrl =
                    (String)(r.containsKey('url') ? r.get('url') : r.get('ceremony_url'));
                info.email       = (String)r.get('email');
                info.name        = (String)r.get('name');
                out.recipients.add(info);
            }
        }

        return out;
    }
}
