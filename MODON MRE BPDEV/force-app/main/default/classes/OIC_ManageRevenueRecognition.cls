/**********************************************************************************************************************
* Name               : OIC_ManageRevenueRecognition                                                        
* Description        : This class contains integration methods for Salesforce to Fusion integration callouts.
* Usage              : Used across Triggers and Batch classes.
* Created By         : Active minds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Manoj   	            14-04-2026     Initial Draft 
*********************************************************************************************************************/
public class OIC_ManageRevenueRecognition {
    /**
    * Description : Builds revenue recognition payload and     
    *               sends it to Oracle via OIC HTTP callout.   
    */
    public static void getRevenueRecognition(
        List<SalesOrder__c> SOList,
        Map<Id, OIC_ManageRevenueRecognition.SalesOrderInvoiceSummary> invoiceSummaryBySO, Date periodDate) {
            try {
                List<OIC_RequestWrapperController.RevenueRecognitionMaster> propertyWrapLst =
                    new List<OIC_RequestWrapperController.RevenueRecognitionMaster>();
                
                for (SalesOrder__c soRec : SOList) {
                    OIC_ManageRevenueRecognition.SalesOrderInvoiceSummary summary =
                        invoiceSummaryBySO.get(soRec.Id);
                    
                    OIC_RequestWrapperController.RevenueRecognitionMaster wrapObj =
                        new OIC_RequestWrapperController.RevenueRecognitionMaster();
                    
                    wrapObj.bu_name          = soRec.Unit__r.Phase__r.EntityName__c;
                    wrapObj.period           = periodDate; // use current year
                    wrapObj.project_name     = soRec.ProjectName__c;
                    wrapObj.sf_project_number = soRec.Unit__r.Phase__r.Project__r.ProjectNumber__c;
                    wrapObj.building_id      = soRec.Unit__r.Building_No__c;
                    wrapObj.unit_id          = soRec.Unit__c;
                    wrapObj.total_spa_value  = soRec.TotalAmount__c;
                    wrapObj.total_invocie_amount = (summary != null) ? summary.totalInvoiceAmount : 0;
                    wrapObj.received             = (summary != null) ? summary.totalPaidAmount    : 0;
                    wrapObj.paas_id          = Decimal.valueOf(soRec.Unit__r.Pass_id__c);
                    wrapObj.so_id = String.valueOf(soRec.id);
                    wrapObj.so_number =soRec.Name;
                    wrapObj.so_name = soRec.Name;
                    
                    propertyWrapLst.add(wrapObj);
                }
                
                HttpRequest req = OIC_CredentialsController.getCredentials('RevenueRecognition');
                req.setTimeout(120000);
                
                OIC_RequestWrapperController.RevenueRecognitionMasterWrapperList wrapperList =
                    new OIC_RequestWrapperController.RevenueRecognitionMasterWrapperList();
                wrapperList.RequestArray = propertyWrapLst;
                
                String proWrappString = JSON.serialize(wrapperList);
                System.debug('Request JSON ==> ' + proWrappString);
                
                OIC_RequestWrapperController.Base64Wrapper wrapper =
                    new OIC_RequestWrapperController.Base64Wrapper();
                wrapper.Base64RequestPayload = EncodingUtil.base64Encode(Blob.valueOf(proWrappString));
                
                req.setBody(JSON.serialize(wrapper));
                
                Http http           = new Http();
                HTTPResponse res    = http.send(req);
                String custRespBody = res.getBody();
                
                System.debug('Response Status: ' + res.getStatusCode() + ' ' + res.getStatus());
                System.debug('Response Body: '   + custRespBody);
                
                if (custRespBody != null && custRespBody != '') {
                    OIC_RequestWrapperController.Base64ResponseWrapper base64RespWrap =
                        (OIC_RequestWrapperController.Base64ResponseWrapper)
                        JSON.deserialize(custRespBody, OIC_RequestWrapperController.Base64ResponseWrapper.class);
                    
                    String custResponseStringActual = null;
                    if (base64RespWrap.Base64Response != null && base64RespWrap.Base64Response != '') {
                        custResponseStringActual =
                            EncodingUtil.base64Decode(base64RespWrap.Base64Response).toString();
                    }
                    
                    System.debug('Decoded Response: ' + custResponseStringActual);
                    
                    if (custResponseStringActual != null) {
                        OIC_RequestWrapperController.OICResponseWrapperList respList =
                            (OIC_RequestWrapperController.OICResponseWrapperList)
                            JSON.deserialize(custResponseStringActual,
                                             OIC_RequestWrapperController.OICResponseWrapperList.class);
                        
                        if (respList != null) {
                            // FIX: query error message metadata ONCE before the loop
                            Map<String, String> errorMsgMap = new Map<String, String>();
                            for (Integration_Error_Messages__mdt m : [
                                SELECT System_Error_Msg__c, User_Error_Msg__c
                                FROM   Integration_Error_Messages__mdt
                                WHERE  IsActive__c = true
                                AND  Application_Type__c = 'EBS'
                            ]) {
                                errorMsgMap.put(m.System_Error_Msg__c, m.User_Error_Msg__c);
                            }
                            
                            Set<String> recordIds = new Set<String>();
                            for (OIC_RequestWrapperController.OICResponseWrapper resp : respList.ResponseArray) {
                                recordIds.add(resp.So_id);
                            }
                            
                            Map<String, Integer> mp_recId_NoOfReTries = new Map<String, Integer>();
                            if (!recordIds.isEmpty()) {
                                for (SalesOrder__c rec : [
                                    SELECT Id, OICNoOfRetries__c
                                    FROM   SalesOrder__c
                                    WHERE  Id IN :recordIds
                                ]) {
                                    mp_recId_NoOfReTries.put(rec.Id, Integer.valueOf(rec.OICNoOfRetries__c));
                                }
                            }
                            
                            List<SalesOrder__c> lstToUpdate = new List<SalesOrder__c>();
                            for (OIC_RequestWrapperController.OICResponseWrapper resp : respList.ResponseArray) {
                                SalesOrder__c rec = new SalesOrder__c(Id = resp.So_id);
                                
                                if (resp.Status == 'S') {
                                    rec.OICNoOfRetries__c      = null;
                                    rec.OracleSyncError__c = null;
                                    rec.RevenueRecognitionId__c   = resp.OracleId;
                                    rec.OracleSyncStatus__c = 'S';
                                    rec.Sync_DateTime__c =System.today().addDays(2);
                                } else if (resp.Status == 'E') {
                                    rec.OracleSyncStatus__c = 'E';
                                    if (resp.ErrorMsg != null) {
                                        String userMsg = UserErrorMessage.getUserErrorMessage(resp.ErrorMsg, errorMsgMap);
                                        if (resp.ErrorMsg.contains('Unknown integration error') || userMsg == null) {
                                            rec.OracleSyncError__c =
                                                'Required information is not updated in Salesforce. Please contact support';
                                        } else {
                                            rec.OracleSyncError__c = userMsg;
                                        }
                                    }
                                    rec.OICNoOfRetries__c =
                                        (mp_recId_NoOfReTries.containsKey(resp.Sfid) &&
                                         mp_recId_NoOfReTries.get(resp.Sfid) != null)
                                        ? mp_recId_NoOfReTries.get(resp.Sfid) + 1
                                        : 1;
                                }
                                lstToUpdate.add(rec);
                            }
                            
                            if (!lstToUpdate.isEmpty()) {
                                update lstToUpdate;
                            }
                        }
                    }
                    
                    LoggerService.save(
                        LoggerService.createAPILog(
                            'Revenue Recognition API',
                            'OIC_ManageRevenueRecognition',
                            'getRevenueRecognition',
                            proWrappString,
                            custResponseStringActual,
                            'Status Code: ' + res.getStatusCode() + '; Status: ' + res.getStatus(),
                            'Callout Log'
                        )
                    );
                }
            } catch (Exception ex) {
                LoggerService.save(
                    LoggerService.createApexLog(
                        ex,
                        'Revenue Recognition API',
                        'OIC_ManageRevenueRecognition',
                        'getRevenueRecognition'
                    )
                );
            }
        }
    /**
    * Description : Stores aggregated invoice and payment      
    *               totals for a given SalesOrder record.      
    */
    public class SalesOrderInvoiceSummary {
        public Id      soId;
        public Decimal totalInvoiceAmount;
        public Decimal totalPaidAmount;
        /**
        * Description : Sets soId, invoice total, and paid     
        *               total with null-safe default of zero.  
        */
        public SalesOrderInvoiceSummary(Id soId, Decimal totalInvoiceAmount, Decimal totalPaidAmount) {
            this.soId               = soId;
            this.totalInvoiceAmount = totalInvoiceAmount != null ? totalInvoiceAmount : 0;
            this.totalPaidAmount    = totalPaidAmount    != null ? totalPaidAmount    : 0;
        }
    }
    
}