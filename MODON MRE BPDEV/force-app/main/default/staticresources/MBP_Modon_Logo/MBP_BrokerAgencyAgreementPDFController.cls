public with sharing class MBP_BrokerAgencyAgreementPDFController {

    private final Id serviceRequestId;

    public ServiceRequest__c sr { get; private set; }

    public String agencyName { get; private set; }
    public String agencyAuthority { get; private set; }
    public String agencyLicense { get; private set; }
    public String agencyTrn { get; private set; }
    public String agencyAddress { get; private set; }
    public String brokerName { get; private set; }
    public String brokerEmail { get; private set; }
    public String madeDate { get; private set; }
    public String sanathName { get; private set; }

    public MBP_BrokerAgencyAgreementPDFController() {
        String idValue = ApexPages.currentPage().getParameters().get('id');

        if (String.isBlank(idValue)) {
            throw new AuraHandledException(
                'ServiceRequest Id is required to generate the Broker Agency Agreement PDF.'
            );
        }

        serviceRequestId = (Id) idValue;
        loadData();
    }

    private void loadData() {
        sr = [
            SELECT Id,
                   Broker_Agency_Owner_Name__c,
                   Broker_Agency_Owner_Email__c,
                   Registration__r.Agency_Name__c,
                   Registration__r.Licensing_Authority__c,
                   Registration__r.Trade_License_Number__c,
                   Registration__r.UAE_VAT_Registration_Number__c,
                   Registration__r.Address_Line_1__c,
                   Registration__r.City__c,
                   Registration__r.State__c,
                   Registration__r.Country__c
            FROM ServiceRequest__c
            WHERE Id = :serviceRequestId
            LIMIT 1
        ];

        agencyName = valueOrBlank(
            sr.Registration__r == null
                ? null
                : sr.Registration__r.Agency_Name__c
        );

        agencyAuthority = valueOrBlank(
            sr.Registration__r == null
                ? null
                : sr.Registration__r.Licensing_Authority__c
        );

        agencyLicense = valueOrBlank(
            sr.Registration__r == null
                ? null
                : sr.Registration__r.Trade_License_Number__c
        );

        agencyTrn = valueOrBlank(
            sr.Registration__r == null
                ? null
                : sr.Registration__r.UAE_VAT_Registration_Number__c
        );

        agencyAddress = buildAddress(sr);

        brokerName = String.isBlank(sr.Broker_Agency_Owner_Name__c)
            ? 'Broker Agency Owner'
            : sr.Broker_Agency_Owner_Name__c.trim();

        brokerEmail = valueOrBlank(sr.Broker_Agency_Owner_Email__c);

        // Keep the same date behavior as the existing DocuSign controller.
        madeDate = Date.today().format();

        sanathName = getRecipientName(
            System.Label.MBP_SendForSignatureRecipient2
        );
    }

    private static String valueOrBlank(String value) {
        return String.isBlank(value) ? '' : value.trim();
    }

    public static String buildAddress(ServiceRequest__c sr) {
        List<String> parts = new List<String>();

        if (sr != null && sr.Registration__r != null) {
            if (!String.isBlank(sr.Registration__r.Address_Line_1__c)) {
                parts.add(sr.Registration__r.Address_Line_1__c.trim());
            }
            if (!String.isBlank(sr.Registration__r.City__c)) {
                parts.add(sr.Registration__r.City__c.trim());
            }
            if (!String.isBlank(sr.Registration__r.State__c)) {
                parts.add(sr.Registration__r.State__c.trim());
            }
        }

        return String.join(parts, ', ');
    }

    private static String getRecipientName(String labelValue) {
        if (String.isBlank(labelValue)) {
            return '';
        }

        List<String> parts = labelValue.split('\\|');

        if (!parts.isEmpty()) {
            return parts[0].trim();
        }

        return '';
    }

    /**
     * Synchronous entry point for the LWC/button.
     *
     * IMPORTANT:
     * getContentAsPDF() is intentionally executed in this synchronous
     * transaction. After the PDF is generated and the ContentVersion is
     * inserted, the existing DocuSign SendJob is queued for the callout.
     */
    @AuraEnabled
    public static Id generateAgreementAndQueueSend(Id srId) {
        if (srId == null) {
            throw new AuraHandledException('ServiceRequest Id is required.');
        }

        PageReference pdfPage = Page.MBP_BrokerAgencyAgreementPDF;
        pdfPage.getParameters().put('id', String.valueOf(srId));

        Blob pdfBlob = pdfPage.getContentAsPDF();

        if (pdfBlob == null || pdfBlob.size() == 0) {
            throw new AuraHandledException(
                'The Broker Agency Agreement PDF could not be generated.'
            );
        }

        ContentVersion cv = new ContentVersion(
            Title = 'Broker Agency Agreement',
            PathOnClient = 'Broker Agency Agreement.pdf',
            VersionData = pdfBlob
        );

        insert cv;

        // The existing controller already has the DocuSign callout job.
        System.enqueueJob(
            new MBP_SendForSignatureController.SendJob(
                srId,
                cv.Id
            )
        );

        return cv.Id;
    }

    /**
     * Use this method when you only want to generate/save the PDF and
     * do NOT want to send it to DocuSign yet.
     */
    @AuraEnabled
    public static Id generateAgreementPdf(Id srId) {
        if (srId == null) {
            throw new AuraHandledException('ServiceRequest Id is required.');
        }

        PageReference pdfPage = Page.MBP_BrokerAgencyAgreementPDF;
        pdfPage.getParameters().put('id', String.valueOf(srId));

        Blob pdfBlob = pdfPage.getContentAsPDF();

        if (pdfBlob == null || pdfBlob.size() == 0) {
            throw new AuraHandledException(
                'The Broker Agency Agreement PDF could not be generated.'
            );
        }

        ContentVersion cv = new ContentVersion(
            Title = 'Broker Agency Agreement',
            PathOnClient = 'Broker Agency Agreement.pdf',
            VersionData = pdfBlob
        );

        insert cv;
        return cv.Id;
    }
}
