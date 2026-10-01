public class ReservationFormDocuSignController {
    
    @AuraEnabled
    public static string generateDocusignURLReservationForm(String DocumentId){
        try{
            List<DocusignConfiguration__mdt> lst_DocusignConfig = [SELECT Id, DeveloperName,  AccountId__c, IntegrationKey__c, 
                                                      PrivateKey__c, UserId__c, AccountBaseURI__c, DocuSignHostName__c
                                                                   from DocusignConfiguration__mdt 
                                                                  where DeveloperName = 'sandbox'];
            //Fetch Documents__c record
            List<Documents__c> lst_Document = [SELECT Id, SalesOrder__c, Status__c
                                              from Documents__c where Id = :DocumentId];
            Documents__c obj_ReservationForm = lst_Document.size() > 0? lst_Document.get(0):null;
            String SalesOrderId = lst_Document.size() > 0? lst_Document.get(0).SalesOrder__c:null;
            
            //Fetch SalesOrder with related Account and Joint Owners
            List<SalesOrder__c> lst_SalesOrder = [SELECT Id, CustomerAccount__c, CustomerAccount__r.IsPersonAccount, CustomerAccount__r.Name, 
                                                  CustomerAccount__r.PersonEmail, Owner.Name, Owner.Email, Status__c, PrimaryContact__c, 
                                                  PrimaryContact__r.Email, JO1__c, JO1__r.Email, JO1__r.Name, JO2__c, JO2__r.Email, JO2__r.Name,
                                                  JO3__c, JO3__r.Email, JO3__r.Name
                                                  from SalesOrder__c where Id = :SalesOrderId];
            
            if(lst_SalesOrder.size() == 0){
                return 'Sales Order not found';
            }
            
            SalesOrder__c obj_SalesOrder = lst_SalesOrder.get(0);
            String AccountId = obj_SalesOrder.CustomerAccount__c;
            
            //Fetch Account details
            List<Account> lst_Account = [SELECT Id, Name, PersonEmail, IsPersonAccount from Account where Id = :AccountId];
            if(lst_Account.size() == 0){
                return 'Account not found';
            }
            
            Account obj_Account = lst_Account.get(0);
            
            //Fetch ContentDocumentLink to get the Reservation Form attachment
            List<ContentDocumentLink> lst_ContentDoc = [SELECT ContentDocumentId, ContentDocument.Title, SystemModstamp 
                                                        FROM ContentDocumentLink 
                                                        WHERE LinkedEntityId = :DocumentId and ContentDocument.Title like '%Reservation%' 
                                                        order by SystemModstamp desc];
            if(lst_ContentDoc.size() == 0){
                return 'No Reservation Form document found';
            }
            
            String DocumentContentId = lst_ContentDoc.get(0).ContentDocumentId;
            System.debug('GenerateDocusignURL for Reservation Form >>>>>>>>>>>  '+DocumentContentId);
            
            //Fetch ContentVersion details for the document
            ContentVersion cv = [SELECT Id, Title, FileType, ContentDocumentId, ContentSize 
                                 FROM ContentVersion WHERE ContentDocumentId = :DocumentContentId
                                 AND IsLatest = true LIMIT 1];
            
            DocusignConfiguration__mdt obj_DocusignConfig = new DocusignConfiguration__mdt();
            if(lst_DocusignConfig.size() > 0){
                obj_DocusignConfig = lst_DocusignConfig.get(0);
            }
            
            //Build list of recipients based on account type and joint owners
            List<DocuSignUtil.DSESigners> lst_Signers = new List<DocuSignUtil.DSESigners>();
            Integer routingOrder = 1;
            
            // Recipient 1: Account owner or Primary Contact
            DocuSignUtil.DSESigners signer1 = new DocuSignUtil.DSESigners();
            if(obj_Account.IsPersonAccount){
                signer1.email = obj_Account.PersonEmail;
                signer1.name = obj_Account.Name;
            } else {
                // For non-person accounts, use Primary Contact
                Contact primaryContact = [select Id, Email, Name from Contact where Id = :obj_SalesOrder.PrimaryContact__c limit 1];
                signer1.email = primaryContact.Email;
                signer1.name = primaryContact.Name;
            }
            signer1.embeddedRecipientStartURL = 'SIGN_AT_DOCUSIGN';
            signer1.recipientId = String.valueOf(routingOrder);
            signer1.routingOrder = String.valueOf(routingOrder);
            signer1.clientUserId = obj_Account.Id;
            signer1.tabs = buildSignerTabs();
            lst_Signers.add(signer1);
            routingOrder++;
            
            // Joint Owner 1 (if exists)
            if(obj_SalesOrder.JO1__c != null){
                DocuSignUtil.DSESigners signerJO1 = new DocuSignUtil.DSESigners();
                signerJO1.email = obj_SalesOrder.JO1__r.Email;
                signerJO1.name = obj_SalesOrder.JO1__r.Name;
                signerJO1.embeddedRecipientStartURL = 'SIGN_AT_DOCUSIGN';
                signerJO1.recipientId = String.valueOf(routingOrder);
                signerJO1.routingOrder = String.valueOf(routingOrder);
                signerJO1.clientUserId = obj_SalesOrder.JO1__c;
                signerJO1.tabs = buildSignerTabs();
                lst_Signers.add(signerJO1);
                routingOrder++;
            }
            
            // Joint Owner 2 (if exists)
            if(obj_SalesOrder.JO2__c != null){
                DocuSignUtil.DSESigners signerJO2 = new DocuSignUtil.DSESigners();
                signerJO2.email = obj_SalesOrder.JO2__r.Email;
                signerJO2.name = obj_SalesOrder.JO2__r.Name;
                signerJO2.embeddedRecipientStartURL = 'SIGN_AT_DOCUSIGN';
                signerJO2.recipientId = String.valueOf(routingOrder);
                signerJO2.routingOrder = String.valueOf(routingOrder);
                signerJO2.clientUserId = obj_SalesOrder.JO2__c;
                signerJO2.tabs = buildSignerTabs();
                lst_Signers.add(signerJO2);
                routingOrder++;
            }
            
            // Joint Owner 3 (if exists)
            if(obj_SalesOrder.JO3__c != null){
                DocuSignUtil.DSESigners signerJO3 = new DocuSignUtil.DSESigners();
                signerJO3.email = obj_SalesOrder.JO3__r.Email;
                signerJO3.name = obj_SalesOrder.JO3__r.Name;
                signerJO3.embeddedRecipientStartURL = 'SIGN_AT_DOCUSIGN';
                signerJO3.recipientId = String.valueOf(routingOrder);
                signerJO3.routingOrder = String.valueOf(routingOrder);
                signerJO3.clientUserId = obj_SalesOrder.JO3__c;
                signerJO3.tabs = buildSignerTabs();
                lst_Signers.add(signerJO3);
                routingOrder++;
            }
            
            // PLACEHOLDER: Modon as final recipient
            // TODO: Get Modon email from configuration or custom setting
            String modonEmail = 'modon@placeholder.com'; // PLACEHOLDER - update with actual email
            DocuSignUtil.DSESigners signerModon = new DocuSignUtil.DSESigners();
            signerModon.email = modonEmail;
            signerModon.name = 'Modon Representative';
            signerModon.embeddedRecipientStartURL = 'SIGN_AT_DOCUSIGN';
            signerModon.recipientId = String.valueOf(routingOrder);
            signerModon.routingOrder = String.valueOf(routingOrder);
            signerModon.clientUserId = obj_Account.Id;
            signerModon.tabs = buildSignerTabs();
            lst_Signers.add(signerModon);
            
            //Build DocuSign Envelope
            DocuSignUtil.DocumentEnvelope obj_Envelope = new DocuSignUtil.DocumentEnvelope();
            obj_Envelope.salesorderId = SalesOrderId;
            obj_Envelope.docuSignURL = 'https://modonproperties--uat.sandbox.my.site.com/DocuSignSign/?customerAccId='+obj_Account.Id+'&customerName='+obj_Account.Name+'&envelopeId=';
            obj_Envelope.customerAccount = obj_Account.Id;
            obj_Envelope.emailSubject = 'Please sign the Reservation Form';
            
            //Add Reservation Form document to envelope
            DocuSignUtil.DSEDocuments obj_Document = new DocuSignUtil.DSEDocuments();
            obj_Document.name = cv.Title;
            obj_Document.documentBase64 = DocumentContentId;
            obj_Document.fileExtension = cv.FileType;
            obj_Document.documentId = String.valueOf(cv.ContentSize);
            obj_Envelope.documents = new DocuSignUtil.DSEDocuments[]{obj_Document};
            
            //Add all signers to envelope
            DocuSignUtil.DSERecipients obj_Recipients = new DocuSignUtil.DSERecipients();
            obj_Recipients.signers = lst_Signers;
            obj_Envelope.recipients = obj_Recipients;    
            obj_Envelope.status = 'sent';    
            
            Http httpenv = new Http();
            HttpRequest requestenv = new HttpRequest();
            requestenv.setHeader('Content-Type', 'application/json');
            requestenv.setTimeout(120000);
            if (!Test.isRunningTest()) {
                requestenv = OIC_CredentialsController.getCredentials('ReservationFormDocuSignEnvelopeAPI');
            }
            requestenv.setBody(JSON.serialize(obj_Envelope));
            system.debug('GenerateDocusignURL for Reservation Form >>>>>>>>> obj_Envelope >> ' + JSON.serialize(obj_Envelope));
            
            HTTPResponse res = new HTTPResponse();
            if (!Test.isRunningTest()) {
                res = httpenv.send(requestenv);
            } else {}
            
            //Update Document status
            obj_ReservationForm.Status__c = 'Pending with Customer';
            update obj_ReservationForm;
            
            return 'sent';
        }catch(Exception exe){
            return 'Docusign exception  '+exe.getMessage();
        }
    }
    
    //Helper method to build signature tabs
    private static DocuSignUtil.signerTab buildSignerTabs(){
        DocuSignUtil.signerTab tabs = new DocuSignUtil.signerTab();
        
        DocuSignUtil.signHereTabsClas signTab = new DocuSignUtil.signHereTabsClas();
        signTab.anchorString = '\\s1\\';
        signTab.anchorUnits = 'pixels';
        signTab.anchorXOffset = '0';
        signTab.anchorYOffset = '0';
        
        DocuSignUtil.signHereTabsClas dateTab = new DocuSignUtil.signHereTabsClas();
        dateTab.anchorString = '\\d1\\';
        dateTab.anchorUnits = 'pixels';
        dateTab.anchorXOffset = '0';
        dateTab.anchorYOffset = '0';
        
        tabs.signHereTabs.add(signTab);
        tabs.dateSignedTabs.add(dateTab);
        
        return tabs;
    }
}