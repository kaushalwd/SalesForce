/**
 * 
 * Class Name      : MaxsightAuditReportService
 * Author          : Arvind
 * Created Date    : Jun 21, 2026
 * Last Modified By: Arvind
 * Last Modified On: Jun 23, 2026
 * Description     : When PassfortApprovalStatus changes to Approved on Account or Contact,
 *                   fetches the Audit PDF from Maxsight API and attaches it to the
 *                   existing Documents__c record (Name = 'KYC Reference') on the
 *                   related SalesOrder__c.
 *
 * Change History  :
 *  Date             Author     Change
 * 
 *  Jun 21, 2026    Arvind     Initial version
 *  Jun 22, 2026    Arvind     Fix: Person Account uses PassfortApprovalStatus__pc
 *  Jun 22, 2026    Arvind     Fix: Query existing Documents__c by SalesOrder__c
 *  Jun 22, 2026    Arvind     Fix: Joint Owner  collect ALL Sales Orders
 *  Jun 23, 2026    Arvind     Reverted to direct Maxsight API call (OIC not ready)
 *                             TODO: Switch to Named Credential when OIC is ready
 * 
 */
public without sharing class MaxsightAuditReportService {

    //  Named Credential 
    // Named Credential: Maxsight_AE
    // Setup  Security  Named Credentials  Maxsight_AE
    //   URL      : https://modondev-modonfusioncloud.integration.eu-frankfurt-1.ocp.oraclecloud.com
    //   Auth Type: Basic Authentication
    //   Username : OIC.USER
    //   Password : 0r@IC18OCT_PROD_2025$$
    // OIC Flow : XXMODO_MOODY_GET_AUDITR_INT/1.0/getAuditReport/{profileId}
    // Response : JSON { "base64": "<base64EncodedPDF>" }
    // To update credentials: Edit Named Credential  zero code change needed.
    private static final String NAMED_CREDENTIAL = 'Maxsight_AE';
    private static final String OIC_PDF_PATH     = '/ic/api/integration/v1/flows/rest/XXMODO_MOODY_GET_AUDITR_INT/1.0/getAuditReport/';
    // 

    // Arvind 05-Jul-2026  Direct Maxsight API (bypass OIC for testing)
    // Set Label.UseDirectMaxsightAPI = 'true' to use direct API
    // Set Label.MaxsightDirectAPIKey = your API key
    // Direct endpoint: https://api.ae.maxsight.com/4.0/profiles/{profileId}/audit/pdf_report/v2
    private static final String MAXSIGHT_DIRECT_URL = 'https://api.ae.maxsight.com';
    private static final String MAXSIGHT_DIRECT_PATH = '/4.0/profiles/{profileId}/audit/pdf_report/v2';

    private static final String KYC_DOCUMENT_NAME = System.Label.MaxsightKycDocumentName;
    private static final String APPROVED_STATUS   = 'Approved';

    /**
     * Checks the MaxsightAuditActive Custom Label.
     * Returns true if label value = 'true'  false disables all fetch.
     * To toggle: Setup  Custom Labels  MaxsightAuditActive  set value to true or false.
     */
    // Arvind 18-Aug-2026
    @TestVisible
    private static Boolean forceActiveForTest = false;

    private static Boolean isActive() {
        return System.Label.MaxsightAuditActive == 'true' || forceActiveForTest;
    }

    /*********************************************************************************************************
    * Method Name   : handleAccountApproval
    *********************************************************************************************************/
    public static void handleAccountApproval(
        Map<Id, Account> newMap,
        Map<Id, Account> oldMap
    ) {
        if (!isActive()) {
            System.debug('MaxsightAuditReportService: Disabled  skipping handleAccountApproval.');
            return;
        }
        Set<Id> approvedAccountIds = new Set<Id>();

        for (Id accId : newMap.keySet()) {
            Account newAcc = newMap.get(accId);
            Account oldAcc = oldMap.get(accId);

            String newStatus = newAcc.IsPersonAccount
                ? newAcc.PassfortApprovalStatus__pc
                : newAcc.PassfortApprovalStatus__c;
            String oldStatus = oldAcc.IsPersonAccount
                ? oldAcc.PassfortApprovalStatus__pc
                : oldAcc.PassfortApprovalStatus__c;

            if (newStatus == APPROVED_STATUS && oldStatus != APPROVED_STATUS) {
                approvedAccountIds.add(accId);
            }
        }

        if (approvedAccountIds.isEmpty()) return;

        List<Account> accounts = [
            SELECT Id, Name, IsPersonAccount,
                   profileId__c,
                   PassfortApprovalStatus__c,
                   PassfortApprovalStatus__pc,
                   PersonContactId,
                   PersonContact.profileId__c,
                   PersonContact.Name,
                   RecordTypeId
            FROM Account
            WHERE Id IN :approvedAccountIds
        ];

        Map<Id, Id> accToSalesOrderId        = getLatestSalesOrderPerAccount(approvedAccountIds);
        Map<Id, List<Contact>> accToContacts = getContactsForOrgAccounts(approvedAccountIds, accounts);

        List<MaxsightAuditJob> jobs = new List<MaxsightAuditJob>();

        for (Account acc : accounts) {
            Id salesOrderId = accToSalesOrderId.get(acc.Id);

            if (acc.IsPersonAccount && String.isNotBlank(acc.PersonContact.profileId__c)) {
                jobs.add(new MaxsightAuditJob(
                    acc.PersonContact.profileId__c,
                    new List<Id>{ salesOrderId },
                    acc.PersonContact.Name + ' - ' + KYC_DOCUMENT_NAME
                ));
                // Arvind 18-Aug-2026 - set soPrefix on job directly
                if (!jobs.isEmpty()) {
                    jobs[jobs.size()-1].soPrefix =
                        accToSODetails.containsKey(acc.Id)
                        ? accToSODetails.get(acc.Id) : '';
                }
            } else if (!acc.IsPersonAccount) {
                if (String.isNotBlank(acc.profileId__c)) {
                    jobs.add(new MaxsightAuditJob(
                        acc.profileId__c,
                        new List<Id>{ salesOrderId },
                        acc.Name + ' - ' + KYC_DOCUMENT_NAME
                    ));
                    if (!jobs.isEmpty()) {
                        jobs[jobs.size()-1].soPrefix =
                            accToSODetails.containsKey(acc.Id)
                            ? accToSODetails.get(acc.Id) : '';
                    }
                }
                if (accToContacts.containsKey(acc.Id)) {
                    for (Contact con : accToContacts.get(acc.Id)) {
                        if (String.isNotBlank(con.profileId__c)) {
                            jobs.add(new MaxsightAuditJob(
                                con.profileId__c,
                                new List<Id>{ salesOrderId },
                                con.Name + ' - ' + KYC_DOCUMENT_NAME
                            ));
                            if (!jobs.isEmpty()) {
                                jobs[jobs.size()-1].soPrefix =
                                    accToSODetails.containsKey(acc.Id)
                                    ? accToSODetails.get(acc.Id) : '';
                            }
                        }
                    }
                }
            }
        }

        if (!jobs.isEmpty()) {
            System.enqueueJob(new MaxsightAuditQueueable(jobs));
        }
    }

    /*********************************************************************************************************
    * Method Name   : handleContactApproval
    *********************************************************************************************************/
    public static void handleContactApproval(
        Map<Id, Contact> newMap,
        Map<Id, Contact> oldMap
    ) {
        if (!isActive()) {
            System.debug('MaxsightAuditReportService: Disabled  skipping handleContactApproval.');
            return;
        }
        Set<Id> approvedContactIds = new Set<Id>();
        for (Id conId : newMap.keySet()) {
            Contact newCon = newMap.get(conId);
            Contact oldCon = oldMap.get(conId);
            if (newCon.PassfortApprovalStatus__c == APPROVED_STATUS
                && oldCon.PassfortApprovalStatus__c != APPROVED_STATUS
                && String.isNotBlank(newCon.profileId__c)) {
                approvedContactIds.add(conId);
            }
        }
        if (approvedContactIds.isEmpty()) return;

        Map<Id, List<Id>> contactToSalesOrderIds = getSalesOrdersForContacts(approvedContactIds);

        List<MaxsightAuditJob> jobs = new List<MaxsightAuditJob>();
        for (Id conId : approvedContactIds) {
            Contact con = newMap.get(conId);
            List<Id> soIds = contactToSalesOrderIds.get(conId);
            if (soIds == null || soIds.isEmpty()) {
                System.debug('MaxsightAuditReportService: No SalesOrder found for contact ' + conId + '  skipping.');
                continue;
            }
            for (Id soId : soIds) {
                jobs.add(new MaxsightAuditJob(
                    con.profileId__c,
                    new List<Id>{ soId },
                    con.LastName + ' - ' + KYC_DOCUMENT_NAME
                ));
            }
        }

        if (!jobs.isEmpty()) {
            System.enqueueJob(new MaxsightAuditQueueable(jobs));
        }
    }

    //  Private Helpers 

    // Arvind 18-Aug-2026 - stores Unit + SO name prefix per account for doc title
    private static Map<Id, String> accToSODetails = new Map<Id, String>();

    private static Map<Id, Id> getLatestSalesOrderPerAccount(Set<Id> accountIds) {
        Map<Id, Id> result = new Map<Id, Id>();
        for (SalesOrder__c so : [
            SELECT Id, Name, CustomerAccount__c, Unit_Name__c
            FROM SalesOrder__c
            WHERE CustomerAccount__c IN :accountIds
            ORDER BY CreatedDate DESC
        ]) {
            if (!result.containsKey(so.CustomerAccount__c)) {
                result.put(so.CustomerAccount__c, so.Id);
                accToSODetails.put(so.CustomerAccount__c,
                    (String.isNotBlank(so.Unit_Name__c) ? so.Unit_Name__c + ' - ' : '')
                    + so.Name + ' - ');
            }
        }
        return result;
    }

    private static Map<Id, List<Contact>> getContactsForOrgAccounts(
        Set<Id> accountIds,
        List<Account> accounts
    ) {
        Set<Id> orgAccountIds = new Set<Id>();
        for (Account acc : accounts) {
            if (!acc.IsPersonAccount) orgAccountIds.add(acc.Id);
        }
        Map<Id, List<Contact>> result = new Map<Id, List<Contact>>();
        if (orgAccountIds.isEmpty()) return result;

        for (Contact con : [
            SELECT Id, Name, profileId__c, AccountId
            FROM Contact
            WHERE AccountId IN :orgAccountIds
            AND profileId__c != null
        ]) {
            if (!result.containsKey(con.AccountId)) {
                result.put(con.AccountId, new List<Contact>());
            }
            result.get(con.AccountId).add(con);
        }
        return result;
    }

    private static Map<Id, List<Id>> getSalesOrdersForContacts(Set<Id> contactIds) {
        Map<Id, List<Id>> result = new Map<Id, List<Id>>();

        for (Id conId : contactIds) {
            result.put(conId, new List<Id>());
        }

        // Get Account Ids for these contacts
        Set<Id> contactAccountIds = new Set<Id>();
        Map<Id, Id> conIdToAccId  = new Map<Id, Id>();
        for (Contact con : [
            SELECT Id, AccountId
            FROM Contact
            WHERE Id IN :contactIds
        ]) {
            if (con.AccountId != null) {
                contactAccountIds.add(con.AccountId);
                conIdToAccId.put(con.Id, con.AccountId);
            }
        }

        // Build accountId  contactId reverse map
        Map<Id, Id> accIdToConId = new Map<Id, Id>();
        for (Id conId : conIdToAccId.keySet()) {
            accIdToConId.put(conIdToAccId.get(conId), conId);
        }

        // 1. Joint Owner path  use SalesOrder__c directly on JointOwner__c
        for (JointOwner__c jo : [
            SELECT JointOwnerAccount__c,
                   JointOwnerAccount__r.PersonContactId,
                   SalesOrder__c
            FROM JointOwner__c
            WHERE JointOwnerAccount__c IN :contactAccountIds
            AND SalesOrder__c != null
        ]) {
            Id conId = accIdToConId.get(jo.JointOwnerAccount__c);
            if (conId == null) conId = jo.JointOwnerAccount__r.PersonContactId;
            if (conId != null && result.containsKey(conId)) {
                result.get(conId).add(jo.SalesOrder__c);
            }
        }

        // 2. Primary owner path  Person Account's own Sales Orders
        Map<Id, Id> conToAccount = new Map<Id, Id>();
        for (Contact con : [
            SELECT Id, AccountId
            FROM Contact
            WHERE Id IN :contactIds
            AND Account.IsPersonAccount = true
        ]) {
            if (con.AccountId != null) conToAccount.put(con.Id, con.AccountId);
        }

        if (!conToAccount.isEmpty()) {
            Set<Id> accIds = new Set<Id>(conToAccount.values());
            Map<Id, List<Id>> accToSos = new Map<Id, List<Id>>();
            for (SalesOrder__c so : [
                SELECT Id, CustomerAccount__c
                FROM SalesOrder__c
                WHERE CustomerAccount__c IN :accIds
                ORDER BY CreatedDate DESC
            ]) {
                if (!accToSos.containsKey(so.CustomerAccount__c)) {
                    accToSos.put(so.CustomerAccount__c, new List<Id>());
                }
                accToSos.get(so.CustomerAccount__c).add(so.Id);
            }
            for (Id conId : contactIds) {
                Id accId = conToAccount.get(conId);
                if (accId != null && accToSos.containsKey(accId)) {
                    result.get(conId).addAll(accToSos.get(accId));
                }
            }
        }

        return result;
    }

    //  Inner Wrapper 

    public class MaxsightAuditJob {
        public String   profileId;
        public List<Id> candidateSalesOrderIds;
        public String   documentName;
        // Arvind 18-Aug-2026 - soPrefix survives Queueable boundary
        public String   soPrefix; // e.g. 'GolfEstate-TH-232 - SO-15366 - '

        public Integer  retryCount;

        public MaxsightAuditJob(
            String   profileId,
            List<Id> candidateSalesOrderIds,
            String   documentName
        ) {
            this.profileId              = profileId;
            this.candidateSalesOrderIds = candidateSalesOrderIds;
            this.documentName           = documentName;
            this.retryCount             = 0;
        }
    }

    //  Queueable 

    public class MaxsightAuditQueueable implements Queueable, Database.AllowsCallouts {

        private List<MaxsightAuditJob> pendingJobs;

        public MaxsightAuditQueueable(List<MaxsightAuditJob> jobs) {
            this.pendingJobs = jobs;
        }

        private final Integer MAX_RETRIES    = 3;
        private final Set<Integer> RETRYABLE_CODES = new Set<Integer>{ 525, 503, 502, 429, 408 };

        public void execute(QueueableContext context) {
            if (pendingJobs == null || pendingJobs.isEmpty()) return;

            MaxsightAuditJob job = pendingJobs.remove(0);

            Boolean   success   = false;
            Exception lastError = null;

            for (Integer attempt = 1; attempt <= MAX_RETRIES; attempt++) {
                try {
                    processJob(job);
                    success = true;
                    break;
                } catch (MaxsightException e) {
                    lastError = e;
                    Boolean isRetryable = false;
                    for (Integer code : RETRYABLE_CODES) {
                        if (e.getMessage().contains('returned ' + code)) {
                            isRetryable = true;
                            break;
                        }
                    }
                    if (isRetryable && attempt < MAX_RETRIES) {
                        System.debug('MaxsightAuditReportService: Attempt ' + attempt
                            + ' failed  retrying. Profile: ' + job.profileId);
                    } else {
                        break;
                    }
                } catch (Exception e) {
                    lastError = e;
                    break;
                }
            }

            if (!success && lastError != null) {
                System.debug('MaxsightAuditReportService ERROR for profile '
                    + job.profileId + ': ' + lastError.getMessage()
                    + ' Line: ' + lastError.getLineNumber());
                LoggerService.save(LoggerService.createApexLog(
                    lastError, 'MaxsightAuditReportService',
                    'MaxsightAuditQueueable.execute',
                    'profileId: ' + job.profileId
                ));

                Boolean isTransient = false;
                for (Integer code : RETRYABLE_CODES) {
                    if (lastError.getMessage().contains('returned ' + code)) {
                        isTransient = true;
                        break;
                    }
                }
                if (isTransient && job.retryCount < MAX_RETRIES) {
                    job.retryCount++;
                    List<MaxsightAuditJob> retryList = new List<MaxsightAuditJob>{ job };
                    retryList.addAll(pendingJobs);
                    pendingJobs = retryList;
                }
            }

            // Do not chain Queueables in test context  avoids max stack depth
            if (!pendingJobs.isEmpty() && !Test.isRunningTest()) {
                System.enqueueJob(new MaxsightAuditQueueable(pendingJobs));
            }
        }

        @TestVisible
        private void processJob(MaxsightAuditJob job) {

            //  Step 1: Call Maxsight API 
            // Two modes:
            // 1. Direct API (testing) : Label.UseDirectMaxsightAPI = 'true'
            //     calls api.ae.maxsight.com directly with API key
            //     response: { "base64": "<base64EncodedPDF>" }
            // 2. Via OIC (production) : Label.UseDirectMaxsightAPI = 'false'
            //     calls OIC Named Credential Maxsight_AE (existing flow)
            //     response: { "base64": "<base64EncodedPDF>" }
            Boolean useDirectAPI = System.Label.UseDirectMaxsightAPI == 'true';
            String  apiKey       = System.Label.MaxsightDirectAPIKey;

            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setHeader('Accept', 'application/json');
            req.setTimeout(120000);

            if (useDirectAPI && String.isNotBlank(apiKey)) {
                // Arvind 05-Jul-2026  Direct Maxsight API mode
                String directEndpoint = MAXSIGHT_DIRECT_URL
                    + MAXSIGHT_DIRECT_PATH.replace(
                        '{profileId}',
                        EncodingUtil.urlEncode(job.profileId, 'UTF-8')
                      );
                req.setEndpoint(directEndpoint);
                req.setHeader('apikey', apiKey);
            } else {
                // Production mode  via OIC Named Credential
                String endpoint = 'callout:' + NAMED_CREDENTIAL
                    + OIC_PDF_PATH
                    + EncodingUtil.urlEncode(job.profileId, 'UTF-8');
                req.setEndpoint(endpoint);
                // Basic Auth handled by Named Credential
            }

            Http http        = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200) {
                throw new MaxsightException(
                    'OIC API returned ' + res.getStatusCode()
                    + ' for profile ' + job.profileId
                    + '. Body: ' + res.getBody()
                );
            }

            // Arvind 05-Jul-2026  Two response formats:
            // 1. Direct Maxsight API  returns raw PDF bytes (not JSON)
            //     encode response body as base64 directly
            // 2. Via OIC  returns JSON { "base64": "<base64EncodedPDF>" }
            //     parse JSON and extract base64 field
            // Arvind 18-Aug-2026 - Auto detect response format
            String base64Pdf;
            String responseBodyStr = res.getBody();
            if (String.isNotBlank(responseBodyStr) && responseBodyStr.trim().startsWith('{')) {
                Map<String, Object> responseMap =
                    (Map<String, Object>) JSON.deserializeUntyped(responseBodyStr);
                base64Pdf = (String) responseMap.get('base64');
                if (String.isBlank(base64Pdf)) {
                    throw new MaxsightException(
                        'OIC response missing base64 for profile ' + job.profileId);
                }
            } else {
                Blob rawPdf = res.getBodyAsBlob();
                if (rawPdf == null || rawPdf.size() == 0) {
                    throw new MaxsightException(
                        'Direct API empty PDF for profile ' + job.profileId);
                }
                base64Pdf = EncodingUtil.base64Encode(rawPdf);
            }

            // Arvind 05-Jul-2026  Generate Modon branded cover page
            // Cover page is saved as a SEPARATE file alongside the Maxsight PDF
            // Both files linked to same SalesOrder + Documents__c record
            // No external server needed  pure Salesforce Visualforce PDF
            Id coverPageSoId = job.candidateSalesOrderIds != null
                && !job.candidateSalesOrderIds.isEmpty()
                ? job.candidateSalesOrderIds[0] : null;

            // Decode base64 string  PDF Blob
            Blob pdfBlob = EncodingUtil.base64Decode(base64Pdf);
            if (pdfBlob == null || pdfBlob.size() == 0) {
                throw new MaxsightException(
                    'Decoded PDF is empty for profile ' + job.profileId
                );
            }

            System.debug('MaxsightAuditReportService: PDF received | Size: '
                + pdfBlob.size() + ' bytes | Profile: ' + job.profileId);

            // Arvind 05-Jul-2026  Apply Modon branding BEFORE saving to Salesforce
            // Declared outside try so visible to Queueable enqueue below
            Id brandingSoId = job.candidateSalesOrderIds != null
                && !job.candidateSalesOrderIds.isEmpty()
                ? job.candidateSalesOrderIds[0] : null;

            // Arvind 18-Aug-2026 - Adobe branding via Queueable (async after PDF saved)
            // AdobePDFQueueable enqueued below after ContentVersion insert

            if (job.candidateSalesOrderIds == null || job.candidateSalesOrderIds.isEmpty()) {
                throw new MaxsightException(
                    'No SalesOrder found for profile ' + job.profileId + '  cannot attach PDF.'
                );
            }

            //  Step 2: Find existing Documents__c (KYC Reference) 
            List<Documents__c> existing = [
                SELECT Id, SalesOrder__c, Status__c
                FROM Documents__c
                WHERE SalesOrder__c IN :job.candidateSalesOrderIds
                AND Name = :KYC_DOCUMENT_NAME
                LIMIT 1
            ];

            Id targetSalesOrderId = existing.isEmpty()
                ? job.candidateSalesOrderIds[0]
                : existing[0].SalesOrder__c;

            System.debug('MaxsightAuditReportService: Target SalesOrder = ' + targetSalesOrderId
                + ' | Documents__c found = ' + !existing.isEmpty());

            //  Step 3: Insert ContentVersion 
            // Arvind 18-Aug-2026 - prepend soPrefix (Unit + SO) to document title
            String fullTitle    = (String.isNotBlank(job.soPrefix) ? job.soPrefix : '')
                                  + job.documentName;
            String safeFileName = fullTitle.replaceAll('[^a-zA-Z0-9_\\-]', '_');

            ContentVersion cv = new ContentVersion();
            cv.Title          = fullTitle;
            cv.PathOnClient   = safeFileName + '.pdf';
            cv.VersionData    = pdfBlob;
            cv.IsMajorVersion = true;
            cv.TagCsv         = 'Maxsight,KYCReference,AuditPDF';
            Database.SaveResult cvResult = Database.insert(cv, false);
            if (!cvResult.isSuccess()) {
                System.debug('CV insert FAILED: ' + cvResult.getErrors()[0].getMessage());
                return;
            }
            cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            Id contentDocumentId = cv.ContentDocumentId;

            //  Step 4a: Documents__c found  update and link 
            if (!existing.isEmpty()) {
                Documents__c kycDoc = existing[0];
                kycDoc.Status__c = 'Uploaded';
                update kycDoc;

                List<ContentDocumentLink> existingCdl = [
                    SELECT Id FROM ContentDocumentLink
                    WHERE ContentDocumentId = :contentDocumentId
                    AND LinkedEntityId = :kycDoc.Id LIMIT 1];
                if (existingCdl.isEmpty()) {
                    ContentDocumentLink docLink = new ContentDocumentLink();
                    docLink.ContentDocumentId = contentDocumentId;
                    docLink.LinkedEntityId    = kycDoc.Id;
                    docLink.ShareType         = 'V';
                    docLink.Visibility        = 'AllUsers';
                    Database.insert(docLink, false);
                }

                System.debug('MaxsightAuditReportService: File linked to Documents__c | ' + kycDoc.Id);
            } else {
                System.debug('MaxsightAuditReportService: No Documents__c found  attaching to SO directly.');
            }

            //  Step 5: Always link to SalesOrder 
            // Arvind 18-Aug-2026 - Removed SO link to prevent file in Notes & Attachments

            // Arvind 18-Aug-2026 - Trigger Adobe branding via @future
            // Cannot enqueue from inside a Queueable - use @future instead
            if (brandingSoId != null && !Test.isRunningTest()) {
                try {
                    String jobTitle = (String.isNotBlank(job.soPrefix) ? job.soPrefix : '')
                        + job.documentName;
                    AdobePDFService.brandPdfAsync(
                        base64Pdf,
                        jobTitle,
                        brandingSoId,
                        contentDocumentId
                    );
                    System.debug('Adobe PDF branding scheduled via @future | SO: ' + brandingSoId);
                } catch (Exception qEx) {
                    System.debug('Adobe branding failed: ' + qEx.getMessage());
                }
            }

            System.debug('MaxsightAuditReportService: Complete | Profile: ' + job.profileId
                + ' | Documents__c: ' + (existing.isEmpty() ? 'N/A' : existing[0].Id)
                + ' | ContentDocument: ' + contentDocumentId
                + ' | SalesOrder: ' + targetSalesOrderId);
        }
    }

    /**
     * Arvind 05-Jul-2026
     * Calls Modon PDF Branding Service to add logo + signature to PDF
     * Named Credential: ModonPDFBrandingService
     * Custom Label: ModonPDFBrandingServiceURL (set to /add-branding endpoint)
     * If service returns error  returns original base64 unchanged
     */
    private static String addModonBranding(
        String base64Pdf,
        String customerName,
        Id salesOrderId
    ) {
        // Get SO number for footer
        String soNumber = '';
        if (salesOrderId != null) {
            List<SalesOrder__c> soList = [
                SELECT Name FROM SalesOrder__c WHERE Id = :salesOrderId LIMIT 1
            ];
            if (!soList.isEmpty()) soNumber = soList[0].Name;
        }

        // Get Modon logo from Static Resource
        String logoBase64 = '';
        List<StaticResource> logos = [
            SELECT Body FROM StaticResource
            WHERE Name = 'ModonLogoMAX' LIMIT 1
        ];
        if (!logos.isEmpty()) {
            logoBase64 = EncodingUtil.base64Encode(logos[0].Body);
        }

        // Build request payload
        Map<String, Object> payload = new Map<String, Object>{
            'pdf'          => base64Pdf,
            'logo'         => logoBase64,
            'customerName' => customerName,
            'salesOrderNo' => soNumber
        };

        // Call branding service via Named Credential
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:ModonPDFBrandingService/add-branding');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payload));
        req.setTimeout(30000); // 30 second timeout

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> result =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String modifiedPdf = (String) result.get('pdf');
            if (String.isNotBlank(modifiedPdf)) {
                return modifiedPdf; // return branded PDF
            }
        }

        System.debug('PDF branding service returned: ' + res.getStatusCode());
        return base64Pdf; // fallback  return original if branding fails
    }

    public class MaxsightException extends Exception {}

    //  LWC Button Methods 

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getProfilesForDocument(Id documentId) {
        Documents__c doc = [
            SELECT Id, Name, SalesOrder__c, SalesOrder__r.Name,
                   SalesOrder__r.Unit_Name__c
            FROM Documents__c
            WHERE Id = :documentId
            LIMIT 1
        ];

        List<ProfileInfo> profiles = new List<ProfileInfo>();
        if (doc.SalesOrder__c != null) {
            profiles = resolveProfilesForSO(doc.SalesOrder__c);
        }

        return new Map<String, Object>{
            'isActive'   => isActive(),
            'profiles'   => profiles,
            'soName'     => doc.SalesOrder__r != null ? doc.SalesOrder__r.Name : '',
            'kycDocName' => KYC_DOCUMENT_NAME
        };
    }

    @AuraEnabled
    public static String triggerKycFetch(Id documentId) {
        // isActive() label only blocks auto trigger  manual button always works when approved

        Documents__c doc = [
            SELECT Id, Name, SalesOrder__c, SalesOrder__r.Name,
                   SalesOrder__r.Unit_Name__c
            FROM Documents__c
            WHERE Id = :documentId
            LIMIT 1
        ];

        if (doc.SalesOrder__c == null) {
            throw new AuraHandledException('This KYC Reference record has no Sales Order linked.');
        }

        List<ProfileInfo> allProfiles = resolveProfilesForSO(doc.SalesOrder__c);

        // Check if joint owners exist
        Boolean hasJointOwners = false;
        for (ProfileInfo p : allProfiles) {
            if (p.role == 'Joint Owner') { hasJointOwners = true; break; }
        }

        // If joint owners exist  ALL must be Approved
        // If no joint owners  primary must be Approved
        List<ProfileInfo> notApproved = new List<ProfileInfo>();
        for (ProfileInfo p : allProfiles) {
            if (!p.isApproved) notApproved.add(p);
        }

        if (hasJointOwners && !notApproved.isEmpty()) {
            List<String> names = new List<String>();
            for (ProfileInfo p : notApproved) names.add(p.name + ' (' + p.role + ')');
            throw new AuraHandledException(
                'All owners must be Approved before PDF can be fetched. '
                + 'Pending approval: ' + String.join(names, ', ')
            );
        }

        // Build jobs for all Approved profiles
        // profileId__c is required for the Maxsight API call
        // If blank  skip that profile with a warning but continue with others
        List<MaxsightAuditJob> jobs       = new List<MaxsightAuditJob>();
        List<String> skippedNoProfileId  = new List<String>();

        for (ProfileInfo p : allProfiles) {
            if (p.isApproved) {
                if (String.isBlank(p.profileId)) {
                    skippedNoProfileId.add(p.name);
                } else {
                    // Arvind 18-Aug-2026 - include Unit + SO in document title
                    String unitPrefix = String.isNotBlank(doc.SalesOrder__r.Unit_Name__c)
                        ? doc.SalesOrder__r.Unit_Name__c + ' - ' : '';
                    String soPrefix2  = String.isNotBlank(doc.SalesOrder__r.Name)
                        ? doc.SalesOrder__r.Name + ' - ' : '';
                    MaxsightAuditJob j = new MaxsightAuditJob(
                        p.profileId,
                        new List<Id>{ doc.SalesOrder__c },
                        p.name + ' - ' + KYC_DOCUMENT_NAME
                    );
                    j.soPrefix = unitPrefix + soPrefix2;
                    jobs.add(j);
                }
            }
        }

        if (jobs.isEmpty()) {
            // All approved profiles have no profileId__c
            if (!skippedNoProfileId.isEmpty()) {
                throw new AuraHandledException(
                    'profileId__c is not populated for: ' + String.join(skippedNoProfileId, ', ')
                    + '. Please sync with Passfort to populate profileId__c before fetching.'
                );
            }
            throw new AuraHandledException(
                'No Approved profiles found. Please set PassfortApprovalStatus to Approved first.'
            );
        }

        System.enqueueJob(new MaxsightAuditQueueable(jobs));

        Integer skipped = allProfiles.size() - jobs.size();
        String msg = 'Queued ' + jobs.size() + ' approved profile(s) for ' + doc.SalesOrder__r.Name + '.';
        if (skipped > 0) msg += ' ' + skipped + ' profile(s) skipped (not Approved).';
        return msg;
    }

    private static List<ProfileInfo> resolveProfilesForSO(Id salesOrderId) {
        List<ProfileInfo> profiles  = new List<ProfileInfo>();
        Set<String>       addedPIds = new Set<String>();

        SalesOrder__c so = [
            SELECT Id, Name,
                   CustomerAccount__c,
                   CustomerAccount__r.IsPersonAccount,
                   CustomerAccount__r.Name,
                   CustomerAccount__r.profileId__c,
                   CustomerAccount__r.PassfortApprovalStatus__c,
                   CustomerAccount__r.PassfortApprovalStatus__pc,
                   CustomerAccount__r.PersonContact.Name,
                   CustomerAccount__r.PersonContact.profileId__c,
                   CustomerAccount__r.PersonContact.PassfortApprovalStatus__c
            FROM SalesOrder__c
            WHERE Id = :salesOrderId
            LIMIT 1
        ];

        if (so.CustomerAccount__r.IsPersonAccount) {
            // Person Account  check PassfortApprovalStatus__pc only
            // profileId__c not required to show or fetch
            String pid    = so.CustomerAccount__r.PersonContact.profileId__c;
            String nm     = so.CustomerAccount__r.PersonContact.Name;
            String status = so.CustomerAccount__r.PassfortApprovalStatus__pc;
            String key    = String.isNotBlank(pid) ? pid : so.CustomerAccount__c;
            if (String.isNotBlank(nm) && !addedPIds.contains(key)) {
                profiles.add(new ProfileInfo(pid, nm, 'Primary Owner', status == APPROVED_STATUS));
                addedPIds.add(key);
            }
        } else {
            // Org Account  check PassfortApprovalStatus__c
            String pid    = so.CustomerAccount__r.profileId__c;
            String nm     = so.CustomerAccount__r.Name;
            String status = so.CustomerAccount__r.PassfortApprovalStatus__c;
            String key    = String.isNotBlank(pid) ? pid : so.CustomerAccount__c;
            if (String.isNotBlank(nm) && !addedPIds.contains(key)) {
                profiles.add(new ProfileInfo(pid, nm, 'Primary Account', status == APPROVED_STATUS));
                addedPIds.add(key);
            }
            // Org Account contacts  no profileId filter
            for (Contact con : [
                SELECT Id, Name, profileId__c, PassfortApprovalStatus__c
                FROM Contact
                WHERE AccountId = :so.CustomerAccount__c
            ]) {
                String conKey = String.isNotBlank(con.profileId__c) ? con.profileId__c : con.Id;
                if (!addedPIds.contains(conKey)) {
                    profiles.add(new ProfileInfo(
                        con.profileId__c, con.Name, 'Contact',
                        con.PassfortApprovalStatus__c == APPROVED_STATUS
                    ));
                    addedPIds.add(conKey);
                }
            }
        }

        // Joint Owners  check PassfortApprovalStatus__pc or __c
        for (JointOwner__c jo : [
            SELECT JointOwnerAccount__r.IsPersonAccount,
                   JointOwnerAccount__r.Name,
                   JointOwnerAccount__r.profileId__c,
                   JointOwnerAccount__r.PassfortApprovalStatus__c,
                   JointOwnerAccount__r.PassfortApprovalStatus__pc,
                   JointOwnerAccount__r.PersonContact.Name,
                   JointOwnerAccount__r.PersonContact.profileId__c,
                   JointOwnerAccount__r.PersonContact.PassfortApprovalStatus__c
            FROM JointOwner__c
            WHERE SalesOrder__c = :salesOrderId
            AND JointOwnerAccount__c != null
        ]) {
            String pid;
            String nm;
            String status;
            if (jo.JointOwnerAccount__r.IsPersonAccount) {
                pid    = jo.JointOwnerAccount__r.PersonContact.profileId__c;
                nm     = jo.JointOwnerAccount__r.PersonContact.Name;
                status = jo.JointOwnerAccount__r.PassfortApprovalStatus__pc;
            } else {
                pid    = jo.JointOwnerAccount__r.profileId__c;
                nm     = jo.JointOwnerAccount__r.Name;
                status = jo.JointOwnerAccount__r.PassfortApprovalStatus__c;
            }
            String key = String.isNotBlank(pid) ? pid : jo.JointOwnerAccount__c;
            if (String.isNotBlank(nm) && !addedPIds.contains(key)) {
                profiles.add(new ProfileInfo(pid, nm, 'Joint Owner', status == APPROVED_STATUS));
                addedPIds.add(key);
            }
        }

        return profiles;
    }

    public class ProfileInfo {
        @AuraEnabled public String  profileId  { get; set; }
        @AuraEnabled public String  name       { get; set; }
        @AuraEnabled public String  role       { get; set; }
        @AuraEnabled public Boolean isApproved { get; set; }

        public ProfileInfo(String profileId, String name, String role, Boolean isApproved) {
            this.profileId  = profileId;
            this.name       = name;
            this.role       = role;
            this.isApproved = isApproved;
        }
    }
}