/**********************************************************************************************************************
* Name               : ADHA_DocuSignProvider
* Description        : Embedded (captive) DocuSign signing for the Baniyas journey. Unlike the proven OIC helper it
*                      never sets embeddedRecipientStartURL, which makes DocuSign email the signer.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     23 Aug 2026     Initial.
**********************************************************************************************************************/
public without sharing class ADHA_DocuSignProvider implements ADHA_SigningProvider {

    /** Matches the white-on-white anchor ADHA_UndertakingDocument writes into the page. */
    private static final String SIGN_ANCHOR = '\\s1\\';

    public class DocuSignException extends Exception {}

    private DocusignConfiguration__mdt config;
    private String token;

    /* ---------- the interface ---------- */

    public String send(ADHA_SigningService.SignRequest request) {
        assertCaptive(request);

        Map<String, Object> tabs = new Map<String, Object>{
            'signHereTabs' => new List<Object>{
                new Map<String, Object>{
                    'anchorString' => SIGN_ANCHOR,
                    'anchorUnits' => 'pixels',
                    'anchorXOffset' => '0',
                    'anchorYOffset' => '0'
                }
            }
        };

        Map<String, Object> signer = new Map<String, Object>{
            'email' => request.signerEmail,
            'name' => request.signerName,
            'recipientId' => '1',
            'routingOrder' => '1',
            // Present and non-blank is what makes this recipient captive. There is deliberately no
            // embeddedRecipientStartURL here: adding it would have DocuSign email an invitation.
            'clientUserId' => request.clientUserId,
            'tabs' => tabs
        };

        Map<String, Object> body = new Map<String, Object>{
            'emailSubject' => request.emailSubject,
            'status' => 'sent',
            'documents' => new List<Object>{
                new Map<String, Object>{
                    'documentBase64' => request.documentBase64,
                    'name' => request.documentName,
                    'fileExtension' => 'pdf',
                    'documentId' => '1'
                }
            },
            'recipients' => new Map<String, Object>{
                'signers' => new List<Object>{ signer }
            }
        };

        HttpResponse res = call('POST', accountUrl() + '/envelopes', JSON.serialize(body), 120000);
        if (res.getStatusCode() != 201 && res.getStatusCode() != 200) {
            throw new DocuSignException(
                'DocuSign refused the envelope (' + res.getStatusCode() + '): ' + res.getBody().left(300)
            );
        }
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) parsed.get('envelopeId');
    }

    public String signingUrl(String envelopeId, ADHA_SigningService.SignRequest request) {
        assertCaptive(request);

        Map<String, Object> body = new Map<String, Object>{
            'returnUrl' => request.returnUrl,
            'authenticationMethod' => 'none',
            'email' => request.signerEmail,
            'userName' => request.signerName,
            'clientUserId' => request.clientUserId
        };

        HttpResponse res = call(
            'POST', accountUrl() + '/envelopes/' + envelopeId + '/views/recipient',
            JSON.serialize(body), 60000
        );
        if (res.getStatusCode() != 201 && res.getStatusCode() != 200) {
            throw new DocuSignException(
                'DocuSign refused a signing view (' + res.getStatusCode() + '): ' + res.getBody().left(300)
            );
        }
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) parsed.get('url');
    }

    public String status(String envelopeId) {
        HttpResponse res = call('GET', accountUrl() + '/envelopes/' + envelopeId, null, 60000);
        if (res.getStatusCode() != 200) {
            throw new DocuSignException(
                'Could not read envelope ' + envelopeId + ' (' + res.getStatusCode() + ')'
            );
        }
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) parsed.get('status');
    }

    public Boolean voidEnvelope(String envelopeId, String reason) {
        Map<String, Object> body = new Map<String, Object>{
            'status' => 'voided',
            'voidedReason' => String.isBlank(reason) ? 'Withdrawn by Modon' : reason.left(200)
        };
        HttpResponse res = call(
            'PUT', accountUrl() + '/envelopes/' + envelopeId, JSON.serialize(body), 60000
        );
        return res.getStatusCode() == 200;
    }

    /**
     * certificate=true appends DocuSign's certificate of completion, the part that makes the
     * signature defensible, at no extra call.
     */
    public String downloadSigned(String envelopeId) {
        if (String.isBlank(envelopeId)) {
            return null;
        }
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(accountUrl() + '/envelopes/' + envelopeId
                + '/documents/combined?certificate=true');
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + accessToken());
            req.setTimeout(120000);

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) {
                System.debug('ADHA_DocuSignProvider download HTTP ' + res.getStatusCode());
                return null;
            }
            Blob pdf = res.getBodyAsBlob();
            if (pdf == null || pdf.size() == 0) {
                return null;
            }
            return EncodingUtil.base64Encode(pdf);
        } catch (Exception e) {
            System.debug('ADHA_DocuSignProvider download exception: ' + e.getMessage());
            return null;
        }
    }

    /* ---------- guardrail ---------- */

    /**
     * Last check before a callout: a blank clientUserId quietly turns a captive signer into
     * one DocuSign emails, so it is verified here as well as in ADHA_SigningService.
     */
    private void assertCaptive(ADHA_SigningService.SignRequest request) {
        if (request == null || String.isBlank(request.clientUserId)) {
            throw new DocuSignException('Refusing to call DocuSign without a clientUserId');
        }
        if (String.isBlank(request.signerEmail) || String.isBlank(request.signerName)) {
            throw new DocuSignException('Refusing to call DocuSign without a named signer');
        }
    }

    /* ---------- plumbing ---------- */

    @TestVisible
    private DocusignConfiguration__mdt configuration() {
        if (config != null) {
            return config;
        }
        String name = ADHA_JourneyController.settings().Docusign_Config_Name__c;
        if (String.isBlank(name)) {
            throw new DocuSignException('Docusign_Config_Name__c is not set');
        }
        List<DocusignConfiguration__mdt> rows = [
            SELECT DeveloperName, AccountId__c, IntegrationKey__c, PrivateKey__c, UserId__c,
                   AccountBaseURI__c, DocuSignHostName__c
            FROM DocusignConfiguration__mdt
            WHERE DeveloperName = :name
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw new DocuSignException('No DocuSign configuration named ' + name);
        }
        config = rows[0];
        return config;
    }

    private String accountUrl() {
        DocusignConfiguration__mdt c = configuration();
        return c.AccountBaseURI__c + '/restapi/v2.1/accounts/' + c.AccountId__c;
    }

    @TestVisible
    private String accessToken() {
        if (String.isNotBlank(token)) {
            return token;
        }
        DocusignConfiguration__mdt c = configuration();
        DocuSignUtil.JWTModel model = new DocuSignUtil.JWTModel();
        model.iss = c.IntegrationKey__c;
        model.sub = c.UserId__c;
        model.aud = c.DocuSignHostName__c;
        model.scope = 'signature impersonation';

        String jwt = DocuSignUtil.generateJWT(model, c.PrivateKey__c);
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://' + c.DocuSignHostName__c + '/oauth/token');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setTimeout(30000);
        req.setBody('grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion='
            + EncodingUtil.urlEncode(jwt, 'UTF-8'));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new DocuSignException(
                'DocuSign would not authenticate (' + res.getStatusCode() + '): ' + res.getBody().left(200)
            );
        }
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        token = (String) parsed.get('access_token');
        if (String.isBlank(token)) {
            throw new DocuSignException('DocuSign returned no access token');
        }
        return token;
    }

    private HttpResponse call(String method, String url, String body, Integer timeout) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod(method);
        req.setHeader('Authorization', 'Bearer ' + accessToken());
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(timeout);
        if (String.isNotBlank(body)) {
            req.setBody(body);
        }
        return new Http().send(req);
    }
}