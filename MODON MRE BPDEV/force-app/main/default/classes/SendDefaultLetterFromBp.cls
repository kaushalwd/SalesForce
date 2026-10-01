public class SendDefaultLetterFromBp {

    @AuraEnabled
    public static void processLetters(String recId, String type) {

        if (String.isBlank(recId)) {
            return;
        }

        Business_Process__c bp = [
            SELECT Id, Sales_Order__c,
            Termination_letter_Sent_Date__c,Default_Letter1_Sent_Date__c,
            Default_Letter2_Sent_Date__c
            FROM Business_Process__c
            WHERE Id = :recId
            LIMIT 1
        ];

        String salesOrderId = bp.Sales_Order__c;

        SalesOrder__c saleOrder = [
            SELECT Id,
                   Name,
                   Status__c,
                   PrimaryContact__r.Email,
                   Unit__r.Name,
                   Unit__r.Project_Name__c,
                   CustomerAccount__r.Name,
                   (
                       SELECT Id,
                              JointOwnerAccount__r.PersonEmail
                       FROM Joint_Owners__r
                   )
            FROM SalesOrder__c
            WHERE Id = :salesOrderId
            LIMIT 1
        ];

        Map<Id, String> primaryEmailMap = new Map<Id, String>();
        Map<Id, List<String>> jointOwnerEmailMap = new Map<Id, List<String>>();

        if (saleOrder.PrimaryContact__r != null &&
            String.isNotBlank(saleOrder.PrimaryContact__r.Email)) {

            primaryEmailMap.put(
                saleOrder.Id,
                saleOrder.PrimaryContact__r.Email
            );
        }

        List<String> joEmails = new List<String>();

        for (JointOwner__c jo : saleOrder.Joint_Owners__r) {

            if (jo.JointOwnerAccount__r != null &&
                String.isNotBlank(jo.JointOwnerAccount__r.PersonEmail)) {

                joEmails.add(jo.JointOwnerAccount__r.PersonEmail);
            }
        }

        jointOwnerEmailMap.put(saleOrder.Id, joEmails);

        String docName;

        if (type == 'Default Notice 1') {
            docName = 'Default Notice Document 1';
            bp.Default_Letter1_Sent_Date__c=system.now();
            saleOrder.Sales_Order_Default__c=true;
        }
        else if (type == 'Default Notice 2') {
            docName = 'Default Notice Document 2';
            bp.Default_Letter2_Sent_Date__c=system.now();
            saleOrder.Legally_Flagged__c=true;
        }
        else if (type == 'Termination Letter') {
            docName = 'Termination Document';
            bp.Termination_letter_Sent_Date__c=system.now();
        }

        List<Business_Process_Documents__c> docList = [
            SELECT Id
            FROM Business_Process_Documents__c
            WHERE Name = :docName and Business_Process__c=:recId
            LIMIT 1
        ];

        if (docList.isEmpty()) {
            return;
        }

        Map<Id, ContentDocumentLink> bpToCDLMap =
            new Map<Id, ContentDocumentLink>();

        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId,
                   ContentDocument.Title,
                   ContentDocument.LatestPublishedVersionId,
                   LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :docList[0].Id
            ORDER BY ContentDocument.CreatedDate DESC
        ]) {

            if (!bpToCDLMap.containsKey(cdl.LinkedEntityId)) {
                bpToCDLMap.put(cdl.LinkedEntityId, cdl);
            }
        }

        Set<Id> versionIds = new Set<Id>();

        for (ContentDocumentLink cdl : bpToCDLMap.values()) {
            versionIds.add(cdl.ContentDocument.LatestPublishedVersionId);
        }

        Map<Id, ContentVersion> versionMap =
            new Map<Id, ContentVersion>();

        if (!versionIds.isEmpty()) {

            for (ContentVersion cv : [
                SELECT Id,
                       Title,
                       VersionData,
                       FileExtension
                FROM ContentVersion
                WHERE Id IN :versionIds
            ]) {

                versionMap.put(cv.Id, cv);
            }
        }

        Map<Id, GenerateSOA.SOAWrapper> soaWrapperMap =
            new Map<Id, GenerateSOA.SOAWrapper>();

        
        List<GenerateSOA.SOAWrapper> soaWrappers =null;
        //    GenerateSOA.generateSOA(new Set<Id>{ salesOrderId });
        
       // List<GenerateSOA.SOAWrapper> soaWrappers =null;
        if (soaWrappers != null) {

            for (GenerateSOA.SOAWrapper wrapper : soaWrappers) {

                if (wrapper != null &&
                    wrapper.salesOrderId != null) {

                    soaWrapperMap.put(
                        wrapper.salesOrderId,
                        wrapper
                    );
                }
            }
        }

        OrgWideEmailAddress orgWideEmail;

        String orgWideDisplayName =
            Label.Default_Sending_Email;

        if (String.isNotBlank(orgWideDisplayName)) {

            List<OrgWideEmailAddress> owEmails = [
                SELECT Id
                FROM OrgWideEmailAddress
                WHERE DisplayName = :orgWideDisplayName
                LIMIT 1
            ];

            if (!owEmails.isEmpty()) {
                orgWideEmail = owEmails[0];
            }
        }

        List<Messaging.SingleEmailMessage> allEmails =
            new List<Messaging.SingleEmailMessage>();

        ContentDocumentLink cdl =
            bpToCDLMap.get(docList[0].Id);

        if (cdl == null) {
            return;
        }

        ContentVersion cv =
            versionMap.get(
                cdl.ContentDocument.LatestPublishedVersionId
            );

        if (cv == null) {
            return;
        }

        Messaging.EmailFileAttachment efa =
            new Messaging.EmailFileAttachment();

        efa.setFileName(
            cv.Title + '.' + cv.FileExtension
        );

        efa.setBody(cv.VersionData);
        efa.setContentType('application/pdf');

        List<Messaging.EmailFileAttachment> attachments =
            new List<Messaging.EmailFileAttachment>();

        attachments.add(efa);

        GenerateSOA.SOAWrapper soaWrapper =
            soaWrapperMap.get(salesOrderId);

        if (soaWrapper != null &&
            soaWrapper.cv != null) {

            Messaging.EmailFileAttachment soaAttachment =
                new Messaging.EmailFileAttachment();

            soaAttachment.setFileName(
                saleOrder.Unit__r.Name +
                '-SOA.pdf'
            );

            soaAttachment.setBody(
                soaWrapper.cv.VersionData
            );

            soaAttachment.setContentType(
                'application/pdf'
            );

            attachments.add(soaAttachment);
        }

        Boolean isTestFlag =
            Boolean.valueOf(Label.IsTest);

        Messaging.SingleEmailMessage email =
            new Messaging.SingleEmailMessage();

        List<String> toAddresses =
            new List<String>();

        if (primaryEmailMap.containsKey(salesOrderId)) {

            if (!isTestFlag) {
                toAddresses.add(
                    primaryEmailMap.get(salesOrderId)
                );
            }
            else {
                toAddresses.add(Label.TestEmail);
            }
        }

        if (jointOwnerEmailMap.containsKey(salesOrderId)) {

            for (String joEmail :
                jointOwnerEmailMap.get(salesOrderId)) {

                if (!isTestFlag) {
                    toAddresses.add(joEmail);
                }
            }
        }

        email.setToAddresses(toAddresses);

        List<String> ccAddresses =
            new List<String>();

        if (String.isNotBlank(
            System.Label.CustomerCareEmailAddress)) {

            ccAddresses.add(
                System.Label.CustomerCareEmailAddress
            );
        }

        if (String.isNotBlank(
            Label.CollectioBroadcast)) {

            ccAddresses.add(
                Label.CollectioBroadcast
            );
        }

        if (!ccAddresses.isEmpty()) {
            email.setCcAddresses(ccAddresses);
        }

        email.setSubject(
            'Notice of Default, ' +
            saleOrder.Unit__r.Project_Name__c +
            ', ' +
            saleOrder.Unit__r.Name
        );

        email.setHtmlBody(
            '<div style="font-size:10.5pt; font-family:Tahoma, sans-serif;">' +
            'Dear ' + saleOrder.CustomerAccount__r.Name + ',<br/><br/>' +
            'This notice serves as a formal notification regarding the payment status of your unit ' +
            saleOrder.Unit__r.Project_Name__c + ' - ' +
            saleOrder.Unit__r.Name + '.<br/><br/>' +
            'Please find the formal Payment Default Notice attached for your detailed review.<br/><br/>' +
            'We kindly request the settlement of the outstanding amount as per the agreed schedule and terms of your Sales and Purchase Agreement (SPA).<br/><br/>' +
            'Should you require any assistance or clarification, our team remains at your disposal.<br/><br/>' +
            'If you have already settled the due amount, please send proof of payment to ' +
            '<a href="mailto:collections@modon.com">collections@modon.com</a>.<br/><br/>' +
            'Best regards,<br/>' +
            'Modon Customer Management - Collections' +
            '</div>'
        );

        if (orgWideEmail != null) {
            email.setOrgWideEmailAddressId(
                orgWideEmail.Id
            );
        }

        email.setWhatId(recId);
        email.setSaveAsActivity(true);
        email.setFileAttachments(attachments);

        allEmails.add(email);

        if (!allEmails.isEmpty()) {

            Messaging.sendEmail(allEmails);

            System.debug(
                'Emails Sent Successfully :: ' +
                allEmails.size()
            );
        }
        update bp;
        update saleOrder;
    }
}