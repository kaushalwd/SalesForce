/**
* @description         :RestInvoiceService is used for update Ebs to salesforce status for AP invoice
* @author              : Manoj
* @group               :
* @Created modified on : 30-09-2026
*@Created By           : Active Minds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Manoj        08-04-2026    Initial Draft
* 1.1           Jay Patel                   21 Sep 2026    MCR-73 — with sharing, USER_MODE SOQL/DML, createApexLog
* 1.2           Jay Patel                   30 Sep 2026    MCR-184 — Bulkify invoice query to handle multiple records

********************************************************************************************************/
@RestResource(urlMapping='/RestInvoiceServiceAPI')
global with sharing class RestInvoiceService {

    @HttpPost
    global static Base64ResponseWrapper updateReceiptsfromOracle() {
        RestRequest req = RestContext.request;
        Base64ResponseWrapper base64Response = new Base64ResponseWrapper();
        OICResponseWrapper resultWrapper = new OICResponseWrapper();
		
        try {
            String rawBody = req.requestBody.toString();
            system.debug('rawBody----'+rawBody);
            Base64RequestWrapper base64Request = (Base64RequestWrapper) JSON.deserialize(rawBody, Base64RequestWrapper.class);
            // testing
            //base64Request.Base64Request = 'ewogICJSZXF1ZXN0QXJyYXkiOiBbCiAgICB7CiAgICAgICJTZmlkIjogImEwRFRJMDAwMDA0aUluaDJBRSIsCiAgICAgICJSZW1hcmtzIjogIiIsCiAgICAgICJQYXltZW50U3RhdHVzIjogIiIsCiAgICAgICJTdGF0dXMiOiAiUyIsCiAgICAgICJFcnJvck1zZyI6ICIiLAogICAgICAiT3JhY2xlSUQiOiAiNTA0NTM5IiwKICAgICAgIk9yYWNsZVJlZiI6ICIiCiAgICB9CiAgXQp9';
            if (String.isBlank(base64Request.Base64Request)) {
                resultWrapper.Status = 'E';
                resultWrapper.Message = 'Missing Base64Request in payload';
            } else {
                Blob decodedBlob = EncodingUtil.base64Decode(base64Request.Base64Request);
                String jsonString = decodedBlob.toString();
                system.debug('request List' + jsonString);
                OICRequestWrapperList requestList = (OICRequestWrapperList) JSON.deserialize(jsonString, OICRequestWrapperList.class);
                system.debug('request List' + requestList);
                system.debug('request Lis Array' + requestList.RequestArray);

                // 1.2 MCR-184: Collect all non-blank Sfids to query Invoice__c records in bulk outside the loop
                Set<Id> invoiceIds = new Set<Id>();
                if (requestList != null && requestList.RequestArray != null) {
                    for (OIC_RequestWrapper record : requestList.RequestArray) {
                        if (record != null && String.isNotBlank(record.Sfid)) {
                            try {
                                invoiceIds.add((Id) record.Sfid.trim());
                            } catch (Exception ex) {
                                // Skip invalid Id formats here; will be caught and reported in per-record processing
                            }
                        }
                    }
                }

                // 1.2 MCR-184: Bulk query Invoice__c records outside the loop to prevent SOQL limit in loop
                // 1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Invoice__c query
                Map<Id, Invoice__c> invoiceMap = new Map<Id, Invoice__c>();
                if (!invoiceIds.isEmpty()) {
                    invoiceMap = new Map<Id, Invoice__c>([
                        SELECT Id, OraclePartyId__c, Status__c, Service_Request__c 
                        FROM Invoice__c 
                        WHERE Id IN :invoiceIds 
                        WITH USER_MODE
                    ]);
                }

                list<Invoice__c> invoiceToUpdate = new list<Invoice__c>();
                Map<id,id> serviceReqMap =new Map<id,id>();
                for (OIC_RequestWrapper record : requestList.RequestArray) {
                    system.debug('request' + record);
                    try {
                        if (String.isNotBlank(record.Sfid) || String.isNotBlank(record.OracleID)) {                            
                            // 1.2 MCR-184: Retrieve Invoice from bulk map instead of querying inside the loop
                            Id invoiceId = String.isNotBlank(record.Sfid) ? (Id) record.Sfid.trim() : null;
                            Invoice__c inv = invoiceId != null ? invoiceMap.get(invoiceId) : null;
                            if(inv != null){
                               serviceReqMap.put(inv.id,inv.Service_Request__c);
                                Invoice__c invoiceupdate =new Invoice__c();
                                invoiceupdate.id =inv.id;
                            if (String.isNotBlank(record.Status) && record.Status == 'S') {
                                invoiceupdate.Status__c = 'Approved';
                                invoiceupdate.OracleSyncStatus__c = 'Approved';
                                invoiceupdate.Description__c = record.Message;
                            }else if(String.isNotBlank(record.Status) && record.Status == 'E' ){
                                invoiceupdate.OracleSyncStatus__c = 'Failed';
                                invoiceupdate.Description__c = record.Message;
                            }                       
                            invoiceToUpdate.add(invoiceupdate);
                            }
                        }
                    } catch (Exception ex) {
                        resultWrapper.Status = 'E';
                        resultWrapper.Message = 'Error while processing Base64Request in payload';                        
                    }
                }
                try{
                    if(invoiceToUpdate.size() > 0){
                        TriggerControl.BypassCancelledTrigger = true;
                        try {
                            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Invoice update
                            Database.SaveResult[] srList = Database.update(invoiceToUpdate, false, AccessLevel.USER_MODE);
                            id srIds = null;
                            List<String> dmlErrors = new List<String>();
                            for (Database.SaveResult sr : srList) {
                                if (sr.isSuccess()) {
                                    System.debug('Successfully updated ID: ' + sr.getId());
                                    id invId = sr.getId();
                                    system.debug('invId----'+serviceReqMap.containsKey(invId));
                                    srIds= serviceReqMap.containsKey(invId) ? serviceReqMap.get(invId) : null;
                                    resultWrapper.Status = 'S';
                                    resultWrapper.Message = 'All records updated successfully.';
                                } else {
                                    for(Database.Error err : sr.getErrors()) {
                                        System.debug('Error: ' + err.getMessage());
                                        String ErrorMesage =err.getMessage();
                                        resultWrapper.Status = 'E';
                                        resultWrapper.Message = 'DML Error while processing Base64Request in payload'; 
                                        dmlErrors.add(ErrorMesage);
                                    }
                                }
                            }
                            // 1.2 MCR-184: Single log entry outside the loop instead of logging inside the loop
                            if(!dmlErrors.isEmpty()){
                                LoggerService.save(LoggerService.createApexLog(null, String.join(dmlErrors, ' | '), 'RestInvoiceService','Post'));
                            }
                            if(srIds != null){
                               // updateTotalPaid(srIds);
                            }
                        } finally {
                            // 1.2 MCR-184: Ensure bypass flag is always reset even on exception
                            TriggerControl.BypassCancelledTrigger = false;
                        }
                    }                   
                }catch(Exception e){
                        resultWrapper.Status = 'E';
                        resultWrapper.Message = 'DML Error while processing Base64Request in payload'; 
                   LoggerService.save(LoggerService.createApexLog(e , '', 'RestInvoiceService','Post'));
                }
            }

            String responseJson = JSON.serialize(resultWrapper);
            Blob responseBlob = Blob.valueOf(responseJson);
            String base64EncodedResponse = EncodingUtil.base64Encode(responseBlob);

            base64Response.Base64Response = base64EncodedResponse;

        } catch (Exception e) {
            //1.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                e,
                'Rest Invoice Service',
                'RestInvoiceService',
                'updateReceiptsfromOracle'
            ));
            resultWrapper.Status = 'E';
            resultWrapper.Message = 'Unhandled error: ' + e.getMessage();
            String responseJson = JSON.serialize(resultWrapper);
            base64Response.Base64Response = EncodingUtil.base64Encode(Blob.valueOf(responseJson));
        }

        return base64Response;
    }
	public static void updateTotalPaid(id serviceRequestIds) {

        Map<Id, Decimal> totalsMap = new Map<Id, Decimal>();

        // Aggregate all approved invoices
        //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Invoice__c aggregate query
        for (AggregateResult ar : [
            SELECT Service_Request__c srId, SUM(InvoiceAmount__c) total
            FROM Invoice__c
            WHERE Service_Request__c =: serviceRequestIds
            AND Status__c = 'Approved'
            WITH USER_MODE
            GROUP BY Service_Request__c
        ]) {
            totalsMap.put((Id) ar.get('srId'), (Decimal) ar.get('total'));
        }

        List<ServiceRequest__c> updates = new List<ServiceRequest__c>();
        if(serviceRequestIds != null){
           updates.add(new ServiceRequest__c(
                Id = serviceRequestIds,
                Approved_Invoice_Amount__c = totalsMap.get(serviceRequestIds) != null ? totalsMap.get(serviceRequestIds) : 0
            ));
        
        }
        if (!updates.isEmpty()) {
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on ServiceRequest update
            Database.SaveResult[] srUpdateList = Database.update(updates, false, AccessLevel.USER_MODE);
						id srIds = null;
                        for (Database.SaveResult sr : srUpdateList) {
                            if (sr.isSuccess()) {
                                System.debug('Successfully updated ID: ' + sr.getId());
                                
                            } else {
                                for(Database.Error err : sr.getErrors()) {
                                    System.debug('Error: ' + err.getMessage());
                                    String ErrorMesage =err.getMessage();
                                    
                                   LoggerService.save(LoggerService.createApexLog(null, ErrorMesage, 'RestInvoiceService','updateTotalPaid'));
                                }
                            }
                        }
        }
    }
    // ========== Wrapper Classes ==========

    global class Base64RequestWrapper {
        public String Base64Request;
       // public String Status;
        //public String Message;
    }

    global class OICRequestWrapperList {
        public List<OIC_RequestWrapper> RequestArray;
    }

    global class OIC_RequestWrapper {
        public String Sfid;
        public String PaymentStatus; 
        public String Status;
        public String Message;
        public String OracleID;
        public String OracleRef;
    }

    global class OICResponseWrapper {
        public String Status;
        public String Message;
    }

    global class Base64ResponseWrapper {
        public String base64Response;
    }
}