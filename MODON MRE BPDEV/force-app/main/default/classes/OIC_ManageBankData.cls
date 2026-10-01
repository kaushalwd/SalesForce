/** Name             : OIC_ManageBankData
* description        : This is used for the sending data from salesforce to ebs and attached docment.            
*Created By          : Active Minds
*********************************************************************************
*  Version  Author          Date       		 	Notes
** 1.0      Manoj           15 Mar 2026    		Initial
*  2.0		Manoj			17 May 2026			Fix issues realted JSON
**********************************************************************************/
public class OIC_ManageBankData {
    
     public static void createRefundMemo(set<String> invoiceIds){
         List<String> excludeStatuses = new List<String>{'Modon - Egypt'};
            try{
                Map<Id, Id> docLinkId = new Map<Id, Id>();
                Map<String, String> docIdToName = new Map<String, String>();
                Map<String, ContentVersion> docIdToVersion = new Map<String, ContentVersion>();
                Map<String, String> map_InvToSR = new Map<String, String>();
                Map<String, List<Documents__c>> map_documents = new Map<String, List<Documents__c>>();
                Set<Id> docId = new Set<Id>();
                
                List<Invoice__c> lst_Invoice = [SELECT Id, Name, OraclePartyId__c, Transaction_Type__c,Service_Request__c,Service_Request__r.UnitId__r.Name, Service_Request__r.UnitId__c,Account__c, Account__r.Bank_Account_Number__c, Account__r.Bank_Branch_Name__c, 
                                                Account__r.Bank_Country__c, Account__r.Bank_Name__c,Account__r.Swift_Code__c, Service_Request__r.SalesOrder__r.VirtualAccount__r.Escrow_Bank_Name__c,                                  
                                                Account__r.IBAN_Number__c, Service_Request__r.SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c,Service_Request__r.SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c, 
                                                Service_Request__r.SalesOrder__r.VirtualAccount__r.Name,Service_Request__r.SalesOrder__r.VirtualAccount__r.Swift_Code__c, 
                                                Transfer_Sales_Order__c,Transfer_Sales_Order__r.VirtualAccount__r.Name,Transfer_Sales_Order__r.VirtualAccount__r.VirtualAccountNumber__c,Transfer_Sales_Order__r.VirtualAccount__r.VirtualIBANNumber__c,
                                                Transfer_Sales_Order__r.VirtualAccount__r.Swift_Code__c,Transfer_Sales_Order__r.VirtualAccount__r.Escrow_Bank_Name__c,
                                                Transfer_Sales_Order__r.CustAcctId__c,Transfer_Sales_Order__r.OracleCustAcctSiteID__c,Transfer_Sales_Order__r.OraclePartySiteID__c,Transfer_Sales_Order__r.OracleSiteUseID__c,Transfer_Sales_Order__r.Name,
                                                Service_Request__r.SalesOrder__r.CustAcctId__c,Service_Request__r.SalesOrder__r.OracleCustAcctSiteID__c,Service_Request__r.SalesOrder__r.OraclePartySiteID__c,Service_Request__r.SalesOrder__r.OracleSiteUseID__c,Service_Request__r.SalesOrder__r.Name 
                                                from Invoice__c  where Service_Request__c != null and Transaction_Type__c != null
                                                and Account__c != null and Id IN :invoiceIds 
                                                and Service_Request__r.SalesOrder__r.Source_Entity__c NOT IN :excludeStatuses];
                for(Invoice__c obj_Inv : lst_Invoice){
                    if(!map_InvToSR.containsKey(obj_Inv.Id)){
                        map_InvToSR.put(obj_Inv.Id, obj_Inv.Service_Request__c);
                    }
                }
                
                if(map_InvToSR.values().size() > 0){
                    List<Documents__c> documents = [SELECT Id, Name, Status__c, Service_Request__c FROM Documents__c 
                                                    WHERE (Service_Request__c = :map_InvToSR.values() 
                                                           and Name IN ('Pre Unit Cancellation Approval Attatchment','Bank Details'))];
                    for (Documents__c doc : documents) {
                        if(String.isNotBlank(doc.Service_Request__c)){
                            docId.add(doc.Id);
                            if(!map_documents.containsKey(doc.Service_Request__c)){
                                List<Documents__c> lst_tempDocs = new List<Documents__c>();
                                lst_tempDocs.add(doc);
                                map_documents.put(doc.Service_Request__c, lst_tempDocs);
                            } else {
                                map_documents.get(doc.Service_Request__c).add(doc);
                            }
                        }                            
                    }
                }
                
                
                if(docId.size() > 0){
                    List<ContentDocumentLink> links = [SELECT ContentDocumentId, LinkedEntityId, ContentDocument.LatestPublishedVersionId,
                    						       ContentDocument.Title, ContentDocument.ContentSize, ContentDocument.FileType
            								       FROM ContentDocumentLink WHERE LinkedEntityId IN :docId];
                    Set<Id> contentDocIds = new Set<Id>();
                    for (ContentDocumentLink link : links){
                      contentDocIds.add(link.ContentDocumentId);  
                        if(!docLinkId.containsKey(link.LinkedEntityId)){
                            docLinkId.put(link.LinkedEntityId, link.ContentDocumentId);
                        }  
                    }
                    
                    List<ContentVersion> versions = [SELECT Id, ContentDocumentId, VersionNumber, VersionData FROM ContentVersion 
                                                     WHERE ContentDocumentId IN :docLinkId.values() ORDER BY VersionNumber DESC];
                    for (ContentVersion ver : versions) {
                        if (!docIdToVersion.containsKey(ver.ContentDocumentId)) {
                            docIdToVersion.put(ver.ContentDocumentId, ver);
                        }
                    }
                }                
                
                List<OIC_RequestWrapperController.BankData> bankDataList = new List<OIC_RequestWrapperController.BankData>();
                for(Invoice__c obj_Invoice : lst_Invoice){
                    if(map_InvToSR.containsKey(obj_Invoice.Id)){
                        String srId = map_InvToSR.get(obj_Invoice.Id);
                        
                        if(String.isNotBlank(srId) && map_documents.containsKey(srId)){
                            List<Documents__c> lst_tempDocs = map_documents.get(srId);
                            for(Documents__c obj_DOC : lst_tempDocs){
                                OIC_RequestWrapperController.BankData bankDataObj = new OIC_RequestWrapperController.BankData();
                                Id ContentDocumentId = docLinkId.containsKey(obj_DOC.Id)?docLinkId.get(obj_DOC.Id):null;
                                ContentVersion obj_CV = null;
                                if(ContentDocumentId != null){
                                    obj_CV = docIdToVersion.containsKey(ContentDocumentId)?docIdToVersion.get(ContentDocumentId):null;
                                }
                                bankDataObj.SfReference = obj_Invoice.Name;
                                if(obj_CV != null){
                                  bankDataObj.Invoice_pdf = EncodingUtil.base64Encode(obj_CV.VersionData);  
                                } else {
                                  bankDataObj.Invoice_pdf = '';  
                                }
                                //bankDataObj.Invoice_pdf = EncodingUtil.base64Encode(versions[0].VersionData);
                                bankDataObj.Invoice_Id = obj_Invoice.OraclePartyId__c;
                                bankDataObj.UnitName = obj_Invoice.Service_Request__r.UnitId__r.Name;
                                bankDataObj.Unit = obj_Invoice.Service_Request__r.UnitId__c;
                                bankDataObj.Sfid = obj_Invoice.Account__c;
                                if(obj_Invoice.Transaction_Type__c == 'Customer Refund'){
                                    bankDataObj.BankAccountNumber = obj_Invoice.Account__r.Bank_Account_Number__c;
                                    bankDataObj.BankBranchName = obj_Invoice.Account__r.Bank_Branch_Name__c;
                                    bankDataObj.BankName = obj_Invoice.Account__r.Bank_Name__c;
                                    bankDataObj.IBANNumber = obj_Invoice.Account__r.IBAN_Number__c;
                                    bankDataObj.SwiftCode =obj_Invoice.Account__r.Swift_Code__c;
                                    bankDataObj.CancellationCustAcctId =obj_Invoice.Service_Request__r.SalesOrder__r.CustAcctId__c;
                                    bankDataObj.CancellationCustAcctSiteID =obj_Invoice.Service_Request__r.SalesOrder__r.OracleCustAcctSiteID__c;
                                    bankDataObj.CancellationPartySiteID =obj_Invoice.Service_Request__r.SalesOrder__r.OraclePartySiteID__c;
                                    bankDataObj.CancellationSiteUseID =obj_Invoice.Service_Request__r.SalesOrder__r.OracleSiteUseID__c;
                                    bankDataObj.CancellationSalesOrder =obj_Invoice.Service_Request__r.SalesOrder__r.Name;
                                }else {
                                    bankDataObj.CancellationVirtualAccountNumber = obj_Invoice.Service_Request__r.SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c;
                                    bankDataObj.CancellationVirtualAccountName = obj_Invoice.Service_Request__r.SalesOrder__r.VirtualAccount__r.Name;
                                    bankDataObj.CancellationVirtualIBANNumber = obj_Invoice.Service_Request__r.SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c;
                                    bankDataObj.CancellationSwiftCode = obj_Invoice.Service_Request__r.SalesOrder__r.VirtualAccount__r.Swift_Code__c;
                                    bankDataObj.CancellationVirtualBankName = obj_Invoice.Service_Request__r.SalesOrder__r.VirtualAccount__r.Escrow_Bank_Name__c;
                                    bankDataObj.TransferVirtualAccountNumber = obj_Invoice.Transfer_Sales_Order__r.VirtualAccount__r.VirtualAccountNumber__c;
                                    bankDataObj.TransferVirtualAccountName = obj_Invoice.Transfer_Sales_Order__r.VirtualAccount__r.Name;
                                    bankDataObj.TransferVirtualIBANNumber = obj_Invoice.Transfer_Sales_Order__r.VirtualAccount__r.VirtualIBANNumber__c;
                                    bankDataObj.TransferSwiftCode = obj_Invoice.Transfer_Sales_Order__r.VirtualAccount__r.Swift_Code__c;
                                    bankDataObj.TransferVirtualBankName = obj_Invoice.Transfer_Sales_Order__r.VirtualAccount__r.Escrow_Bank_Name__c;
                                    bankDataObj.TransferCustAcctId =obj_Invoice.Transfer_Sales_Order__r.CustAcctId__c;
                                    bankDataObj.TransferCustAcctSiteID =obj_Invoice.Transfer_Sales_Order__r.OracleCustAcctSiteID__c;
                                    bankDataObj.TransferPartySiteID =obj_Invoice.Transfer_Sales_Order__r.OraclePartySiteID__c;
                                    bankDataObj.TransferSiteUseID =obj_Invoice.Transfer_Sales_Order__r.OracleSiteUseID__c;
                                    bankDataObj.TransferSalesOrder =obj_Invoice.Transfer_Sales_Order__r.Name; 
                                    bankDataObj.CancellationCustAcctId =obj_Invoice.Service_Request__r.SalesOrder__r.CustAcctId__c;
                                    bankDataObj.CancellationCustAcctSiteID =obj_Invoice.Service_Request__r.SalesOrder__r.OracleCustAcctSiteID__c;
                                    bankDataObj.CancellationPartySiteID =obj_Invoice.Service_Request__r.SalesOrder__r.OraclePartySiteID__c;
                                    bankDataObj.CancellationSiteUseID =obj_Invoice.Service_Request__r.SalesOrder__r.OracleSiteUseID__c;
                                    bankDataObj.CancellationSalesOrder =obj_Invoice.Service_Request__r.SalesOrder__r.Name;
                                }
                                bankDataList.add(bankDataObj);
                            }
                        }
                    }
                }
                
                HttpRequest req = new HttpRequest();
                req = OIC_CredentialsController.getCredentials('ModonFusionUpdateInvoiceAPI');
                req.setTimeout(120000);
                
                OIC_RequestWrapperController.BankDataWrapperLst bankWrapList = new OIC_RequestWrapperController.BankDataWrapperLst();
                bankWrapList.RequestArray = bankDataList;
                String bankWrappString = JSON.serialize(bankWrapList);
                system.debug('JSON.serialize(customerWrapList)==>' + JSON.serialize(bankWrapList));
                Blob binaryData = Blob.valueOf(bankWrappString);
                String base64String = EncodingUtil.base64Encode(binaryData);
                
                Base64Wrapper wrapper = new Base64Wrapper();
                wrapper.Base64Request = base64String;
                
                req.setBody(JSON.serialize(wrapper));
                system.debug('JSON.serialize(wrapper)==>' + JSON.serialize(wrapper));
                Http http = new Http();
                HTTPResponse res = http.send(req);
                System.debug('Create Account Res::::' + res);
                System.debug('Create Account Res Body::::' + res.getBody());
                
                string custResponseBody = res.getBody();
                // PARSING THE RESPONSE //
                if(custResponseBody <> null && custResponseBody <> ''){
                    OIC_RequestWrapperController.Base64ResponseWrapper base64RespWrap = (OIC_RequestWrapperController.Base64ResponseWrapper)JSON.deserialize(custResponseBody, OIC_RequestWrapperController.Base64ResponseWrapper.class);
                    
                    blob custResponseBlobActual = null;
                    string custResponseStringActual = null;
                    
                    if(base64RespWrap.Base64Response <> null && base64RespWrap.Base64Response <> '')
                        custResponseBlobActual = EncodingUtil.base64Decode(base64RespWrap.Base64Response); 
                    if(custResponseBlobActual <> null)
                        custResponseStringActual = custResponseBlobActual.toString();
                    
                    System.debug('custResponseStringActual:::: ' + custResponseStringActual);
                    
                    if(custResponseStringActual <> null){
                        OIC_RequestWrapperController.OICResponseWrapperList custResponseObjectActual = (OIC_RequestWrapperController.OICResponseWrapperList)JSON.deserialize(custResponseStringActual, OIC_RequestWrapperController.OICResponseWrapperList.class);
                        
                        if(custResponseObjectActual <> null){
                            
                        }                        
                    }                    
                    
                }
                
            }
        catch(Exception ex){
            
            //PARAMS: Exception ex, string processName, string className, string methodName
            LoggerService.save(LoggerService.createApexLog(ex, 'Customer API','OIC_ManageSalesforceDataController','createAccount'));
        }
        
    }
    // 2.0 Basc64 Wrapper 
    public class Base64Wrapper{
        public String Base64Request;
    }

}