/**
 * TradeLicenceReadQueueable - Signzy trade licence extraction for the Sales Console.
 *
 * Version  Author      Date         Detail
 * 1.1      Aurelix Dev 23 Aug 2026  MSC-148. The automatic submission waits on the same
 *                                   readiness the workspace shows, instead of firing on
 *                                   the licence read alone.
 * 1.0      Aurelix IT  10 Aug 2026  Initial.
 */

/**
 * Reads a company's trade licence and maps it onto the Account.
 *
 * The mapping itself is NOT reimplemented: CustomerKYCHandler.mapKYCTradeLicenseValues
 * is public and already writes UnifiedNumber__c, the Corporate_KYC KYC_Response__c and
 * Is_Trade_License_Uploaded__c - the flag compliance gates on. This class only owns the
 * callout, so the two paths cannot drift.
 *
 * Queueable because Signzy is given 120 seconds, which no synchronous Aura request has.
 *
 * The endpoint and token come from the Signzy_Trade_Licence named credential rather than
 * from source. CustomerKYCHandler carries both inline, pointed at PRODUCTION with the
 * sandbox line commented out - so testing there bills real Signzy transactions. This
 * runs against whatever the named credential is configured for, which in this org is
 * api-preproduction.
 */
public with sharing class TradeLicenceReadQueueable implements Queueable, Database.AllowsCallouts {

    private static final String NAMED_CREDENTIAL = 'Signzy_Trade_Licence';
    private static final String CONFIG_NAME = 'Trade_Licence';
    private static final Integer TIMEOUT_MS = 120000;

    private static final Map<String, String> EXT_TO_MIME = new Map<String, String>{
        'pdf'  => 'application/pdf',
        'png'  => 'image/png',
        'jpg'  => 'image/jpeg',
        'jpeg' => 'image/jpeg'
    };

    private final Id accountId;
    private final String base64;
    private final String extension;

    public TradeLicenceReadQueueable(Id accountId, String base64, String extension) {
        this.accountId = accountId;
        this.base64    = base64;
        this.extension = extension;
    }

    public void execute(QueueableContext ctx) {
        AI_Service_Config__mdt cfg = config();
        if (cfg == null || cfg.Is_Active__c != true) {
            System.debug(LoggingLevel.WARN,
                'Trade licence extraction is inactive; the file is attached but not read.');
            return;
        }
        try {
            HttpRequest req = new HttpRequest();
            req.setMethod('POST');
            req.setEndpoint('callout:' + NAMED_CREDENTIAL + '/' + cfg.Model__c);
            req.setHeader('Content-Type', 'application/json');
            // Signzy takes the token raw, not as a Bearer scheme.
            req.setHeader('Authorization', '{!$Credential.Password}');
            req.setTimeout(cfg.Timeout_Ms__c == null ? TIMEOUT_MS : Integer.valueOf(cfg.Timeout_Ms__c));

            String mime = EXT_TO_MIME.containsKey(extension)
                ? EXT_TO_MIME.get(extension)
                : 'application/pdf';
            req.setBody(JSON.serialize(new Map<String, Object>{
                'files' => new List<String>{ 'data:' + mime + ';base64,' + base64 }
            }));

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
                logFailure('Signzy returned ' + res.getStatusCode());
                return;
            }

            SignzyTradeLicenseWrapper parsed = SignzyTradeLicenseWrapper.parse(res.getBody());
            if (parsed == null || parsed.error != null) {
                logFailure(parsed == null || parsed.error == null
                    ? 'Signzy returned no result.'
                    : parsed.error.message);
                return;
            }
            /* The one place this data is mapped, shared with the internal upload.
               Sets Is_Trade_License_Uploaded__c, which is the compliance gate. */
            CustomerKYCHandler.mapKYCTradeLicenseValues(parsed, accountId, res.getBody());
            submitIfReady();

        } catch (Exception e) {
            logFailure(e.getMessage());
        }
    }

    private static AI_Service_Config__mdt config() {
        return AI_Service_Config__mdt.getInstance(CONFIG_NAME);
    }

    /**
     * The licence has just been verified, which is the organisation's compliance gate -
     * the counterpart of ContentDocumentLinkTriggerHelper firing when a signed KYC form
     * lands for an individual.
     */
    private void submitIfReady() {
        List<SalesOrder__c> orders = [
            SELECT Id, Opportunity__c FROM SalesOrder__c
            WHERE CustomerAccount__c = :accountId
            AND Status__c NOT IN ('Cancelled', 'System Cancelled', 'Voided')
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (orders.isEmpty()) {
            return;
        }
        /* MSC-148 - the SAME readiness the workspace shows and the Send for
           compliance button refuses on. A licence read fills six of the company's
           fields and none of the four nothing in the org writes, so submitting on
           the read alone put companies in front of Passfort that it errors on
           (a null incorporation_date is a hard refusal in
           PassfortTransactionProcessHelper). The rep completes the details and
           presses Send; a company that is already complete still goes on its own. */
        List<String> outstanding = orders[0].Opportunity__c == null
            ? SalesConsoleOrgController.outstandingForCompany(accountId)
            : SalesConsoleOrgController.outstandingForSubmission(orders[0].Opportunity__c);
        if (!outstanding.isEmpty()) {
            System.debug(LoggingLevel.INFO,
                'Licence read for account ' + accountId
                + '; compliance waits on: ' + String.join(outstanding, ', '));
            return;
        }
        String problem = SalesConsoleOrgController.submitForRecord(orders[0].Id);
        if (String.isNotBlank(problem)) {
            logFailure('Licence read, but compliance was not submitted: ' + problem);
        }
    }

    /**
     * The upload is already stored and the rep can carry on, so a failed read is a
     * log rather than an error thrown at nobody - this runs async.
     */
    private void logFailure(String message) {
        System.debug(LoggingLevel.ERROR,
            'Trade licence extraction failed for account ' + accountId + ': ' + message);
        try {
            LoggerService.save(new List<Logger__c>{
                LoggerService.createAPILog(
                    'Sales Console Trade Licence',
                    'TradeLicenceReadQueueable',
                    'execute',
                    'Trade licence was attached but could not be read automatically. '
                        + 'The company fields must be entered by hand.',
                    message != null && message.length() > 255
                        ? message.substring(0, 252) + '...'
                        : message,
                    'FAILED',
                    'Sales Console Trade Licence'
                )
            });
        } catch (Exception ignored) {
            // Logging must never be the thing that fails the job.
        }
    }
}