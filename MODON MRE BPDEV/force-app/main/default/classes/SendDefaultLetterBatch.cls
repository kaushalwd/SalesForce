global class SendDefaultLetterBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    global Set<Id> salesOrderIdSet { get; set; }

    // Constructor
    global SendDefaultLetterBatch(Set<Id> salesOrderIdSet) {
        this.salesOrderIdSet = salesOrderIdSet;
    }

     @InvocableMethod(label='Send Default Letter')
     public static void runBatch(List<Id> salesOrderIds) {
        if(salesOrderIds != null && !salesOrderIds.isEmpty()){
            Database.executeBatch(new SendDefaultLetterBatch( new Set<Id>(salesOrderIds) ),1);
        }
     }
    
    global Database.QueryLocator start(Database.BatchableContext bc) {

        if (salesOrderIdSet != null && !salesOrderIdSet.isEmpty()) {

            return Database.getQueryLocator([
                SELECT Id,
                       Name,
                       Status__c,
                       PrimaryContact__r.Email,Unit__r.Name,Unit__r.Project_Name__c,CustomerAccount__r.Name,PrimaryContact__r.Name,
                       (
                           SELECT Id,
                                  JointOwnerAccount__r.PersonEmail
                           FROM Joint_Owners__r
                       )
                FROM SalesOrder__c
                WHERE Id IN :salesOrderIdSet
            ]);
        }

        return null;
    }

    global void execute(Database.BatchableContext bc, List<SalesOrder__c> scope) {
        System.debug('Inside SendDefaultLetterBatch Execute');
        Set<Id> salesOrderIds = new Set<Id>();
        Map<Id, String> primaryEmailMap = new Map<Id, String>();
        Map<Id, List<String>> jointOwnerEmailMap = new Map<Id, List<String>>();

        // Collect Sales Order Details
        for (SalesOrder__c order : scope) {
            salesOrderIds.add(order.Id);
            if (order.PrimaryContact__r != null) {
                primaryEmailMap.put(order.Id, order.PrimaryContact__r.Email);
            }
            List<String> joEmails = new List<String>();
            for (JointOwner__c jo : order.Joint_Owners__r) {
                if (jo.JointOwnerAccount__r != null &&
                    String.isNotBlank(jo.JointOwnerAccount__r.PersonEmail)) {
                    joEmails.add(jo.JointOwnerAccount__r.PersonEmail);
                }
            }
            jointOwnerEmailMap.put(order.Id, joEmails);
        }
        
         String url='';
         if(!Test.isRunningTest()){
              url = DrawloopHelper.GetDrawloopURL(
                    'Sales Order', 'SalesOrder__c', 'Default Document', scope.get(0).ID
                );
         }

           if (url.contains('?')) {
                 url += '&format=PDF&download=1';
               } else {
              url += '?format=PDF&download=1';
            }
           
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setTimeout(120000);
            req.setEndpoint(url);
            req.setMethod('GET');
           
            HttpResponse res = http.send(req);
        
        // Fetch Default Documents
        Map<Id, ContentDocumentLink> salesOrderToCDLMap = new Map<Id, ContentDocumentLink>();

        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId,
                   ContentDocument.Title,
                   ContentDocument.LatestPublishedVersionId,
                   LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :salesOrderIds
            AND ContentDocument.Title LIKE '%Default%'
            ORDER BY ContentDocument.CreatedDate DESC
        ]) {

            if (!salesOrderToCDLMap.containsKey(cdl.LinkedEntityId)) {
                salesOrderToCDLMap.put(cdl.LinkedEntityId, cdl);
            }
        }
        // Fetch Content Versions
        Set<Id> versionIds = new Set<Id>();
        for (ContentDocumentLink cdl : salesOrderToCDLMap.values()) {
            versionIds.add(cdl.ContentDocument.LatestPublishedVersionId);
        }

        Map<Id, ContentVersion> versionMap = new Map<Id, ContentVersion>();
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
        // ===============================
        // Generate SOA OUTSIDE LOOP
        // ===============================
        Map<Id, GenerateSOA.SOAWrapper> soaWrapperMap =
            new Map<Id, GenerateSOA.SOAWrapper>();
        List<GenerateSOA.SOAWrapper> soaWrappers =
            GenerateSOA.generateSOA(salesOrderIds);
        if (soaWrappers != null) {
            for (GenerateSOA.SOAWrapper wrapper : soaWrappers) {
                if (wrapper != null &&
                    wrapper.salesOrderId != null) {
                    soaWrapperMap.put(wrapper.salesOrderId, wrapper);
                }
            }
        }
        // Org Wide Email
        OrgWideEmailAddress orgWideEmail;
        String orgWideDisplayName = Label.Default_Sending_Email;
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

        // Process Emails
        for (SalesOrder__c salesOrderRec : scope) {
            ContentDocumentLink cdl =
                salesOrderToCDLMap.get(salesOrderRec.Id);
            if (cdl == null) {
                continue;
            }
            ContentVersion cv =
                versionMap.get(cdl.ContentDocument.LatestPublishedVersionId);
            if (cv == null) {
                continue;
            }

            // Default Letter Attachment
            Messaging.EmailFileAttachment efa =
                new Messaging.EmailFileAttachment();

            efa.setFileName(cv.Title + '.' + cv.FileExtension);
            efa.setBody(cv.VersionData);
            efa.setContentType('application/pdf');

            // SOA Attachment
            List<Messaging.EmailFileAttachment> attachments =
                new List<Messaging.EmailFileAttachment>();
            attachments.add(efa);
            GenerateSOA.SOAWrapper soaWrapper =
                soaWrapperMap.get(salesOrderRec.Id);

            if (soaWrapper != null &&
                soaWrapper.cv != null) {
                Messaging.EmailFileAttachment soaAttachment =
                    new Messaging.EmailFileAttachment();
                soaAttachment.setFileName(
                salesOrderRec.Unit__r.Name + '-SOA'+ '.' + cv.FileExtension
                );
                soaAttachment.setBody(soaWrapper.cv.VersionData);
                soaAttachment.setContentType('application/pdf');
                attachments.add(soaAttachment);
            }
            Boolean isTestFlag = Boolean.valueOf(Label.IsTest);
            // Email
            Messaging.SingleEmailMessage email =
                new Messaging.SingleEmailMessage();
            List<String> toAddresses = new List<String>();
            if (primaryEmailMap.containsKey(salesOrderRec.Id)) {
                if(!isTestFlag){
                    toAddresses.add(primaryEmailMap.get(salesOrderRec.Id));
                }else{
                    toAddresses.add(Label.TestEmail);
                }
                
            }
            
              List<String> ccAddresses = new List<String>();
              if (String.isNotBlank(System.Label.CustomerCareEmailAddress)) {
                  ccAddresses.add(System.Label.CustomerCareEmailAddress);
               }
              
              if (String.isNotBlank(Label.CollectioBroadcast)) {
                    ccAddresses.add(Label.CollectioBroadcast);
              }
              
              if (!ccAddresses.isEmpty()) {
                    email.setCcAddresses(ccAddresses);
               }
            
            for(String joEmails:jointOwnerEmailMap.get(salesOrderRec.Id)){
                if(!isTestFlag){
                toAddresses.add(joEmails);
                }
            }
            // Subject: Notice of Default, <<SalesOrder_ProjectName>>, <<SalesOrder_Unit_Name>> – Outstanding Amount OF AED <<SalesOrderInstallment_InstallmentAmount__00>> 
            email.setToAddresses(toAddresses);
            email.setSubject(
                'Notice of Default, '+ salesOrderRec.Unit__r.Project_Name__c  + ' ,'+ salesOrderRec.Unit__r.Name
            );
            
            email.setHtmlBody(
                '<div style="font-size:10.5pt; font-family:Tahoma, sans-serif;">' +
                'Dear ' + salesOrderRec.PrimaryContact__r.Name + ',<br/><br/>' +
                'This notice serves as a formal notification regarding the payment status of your unit ' +
                salesOrderRec.Unit__r.Project_Name__c + ' - ' + salesOrderRec.Unit__r.Name + '.<br/><br/>' +
                'Our records indicate that the account is currently in default due to non-payment. ' +
                'Please find the formal Payment Default Notice attached for your detailed review.<br/><br/>' +
                'We kindly request the settlement of the outstanding amount as per the agreed schedule and terms of your Sales and Purchase Agreement (SPA) ' +
                'to prevent further administrative actions and Late Payment Charges (LPC).<br/><br/>' +
                'Should you require any assistance or clarification, our team remains at your disposal.<br/><br/>' +
                '*If you have already settled the due amount, please send the proof of payment to ' +
                '<a href="mailto:collections@modon.com">collections@modon.com</a> ' +
                'to facilitate immediate account reconciliation.<br/><br/>' +
                'Best regards,<br/>' +
                'Modon Customer Management - Collections' +
                '</div>'
            );

            if (orgWideEmail != null) {
                email.setOrgWideEmailAddressId(orgWideEmail.Id);
            }
            email.setWhatId(salesOrderRec.Id);
            email.setSaveAsActivity(true);
            email.setFileAttachments(attachments);
            allEmails.add(email);
        }

        // Send Emails ONCE
        if (!allEmails.isEmpty()) {
            Messaging.sendEmail(allEmails);
            System.debug('Emails Sent Successfully :: ' + allEmails.size());
        }
    }


    global void finish(Database.BatchableContext bc) {

        System.debug('Batch Completed');
    }
}