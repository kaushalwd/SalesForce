/**********************************************************************************************************************
* Name               : StatementOfAccountAPI                                                        
* Description        : This class is used to fetch the statement of account based on Sales Order name.
* Usage              : 
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                02 02 2026      Initial Draft
* 2.0           Suresh   	                01 06 2026      Updated SOQL query and response message
* 2.1			Suresh						30 07 2026		SOA changes
***********************************************************************************************************************/
@RestResource(urlMapping='/StatementOfAccountAPI/*')
global class StatementOfAccountAPI {
    @HttpGet
    global static void findSOADetails() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestId = String.valueOf(UUID.randomUUID());
        try {
                String userName = req.params.get('UserName');
                String soId = req.params.get('SOId');
                if (String.isBlank(userName)) {
                    returnErrorAPI.returnError(res, requestId, 'Missing UserName parameter', 200);
                    return;
                }
                //2.0 - added
            	list<string> projectFilter =new list<string>();
                list<string> statusFilter = getfilters(System.Label.CP_SO_Statusfilters);
                string MIREExcludelst = System.Label.MIRE_Exclude_List;
                for (String c2 : MIREExcludelst.split(',')) {
                   if (c2 != null && c2.contains('^')) {
                            projectFilter.add(c2.replace('^', ',').trim());
                    } else {
                            projectFilter.add(c2.trim());
                    }
                }
                List<SOASAPdfController.SOAWrapper> soaDetails = new List<SOASAPdfController.SOAWrapper>();            
                if (String.isNotBlank(userName)) { 
                    Set<Id> set_salesOrderId = new Set<Id>();
                    List<SalesOrder__c> lst_SalesOrder = new List<SalesOrder__c>();
                    if(String.isBlank(soId)){
                        //2.0 - added
                        lst_SalesOrder =  [SELECT Id From SalesOrder__c 
                                                             where Status__c NOT IN : statusFilter 
                                                             AND Unit__r.Project_Name__c NOT IN : projectFilter 
                                                             AND (CustomerAccount__r.PersonEmail = :userName 
                                                             OR PrimaryContact__r.Email = :userName OR JO1__r.Email = :userName 
                                                             OR JO2__r.Email = :userName OR JO3__r.Email = :userName 
                                                             OR JO4__r.Email = :userName OR JO5__r.Email = :userName 
                                                             OR JO6__r.Email = :userName)];
                    } else {
                        //2.0 - added
                        lst_SalesOrder =  [SELECT Id From SalesOrder__c 
                                                             where Status__c NOT IN : statusFilter 
                                                             AND Unit__r.Project_Name__c NOT IN : projectFilter
                                                             AND (CustomerAccount__r.PersonEmail = :userName 
                                                             OR PrimaryContact__r.Email = :userName OR JO1__r.Email = :userName 
                                                             OR JO2__r.Email = :userName OR JO3__r.Email = :userName 
                                                             OR JO4__r.Email = :userName OR JO5__r.Email = :userName 
                                                             OR JO6__r.Email = :userName) AND Name = :soId];
                    }
                    
                    for(SalesOrder__c obj_SO : lst_SalesOrder){
                        set_salesOrderId.add(obj_SO.Id);
                    }
                    if (set_salesOrderId.size() > 0) {
                        soaDetails = SOASAPdfController.getSOAData(set_salesOrderId);
                    } else {
                        returnErrorAPI.returnError(res, requestId, 'No data found', 200);
                        return;
                    }
                    
                } else {
                    returnErrorAPI.returnError(res, requestId, 'No data found', 200);
                    return;
                }               
            
            APIResponse response = new APIResponse('success', requestId, soaDetails, null);
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = 200;
            
        } catch (Exception ex) { // Return generic server error response
            LoggerService.save(LoggerService.createApexLog(ex, 'StatementOfAccountAPI', 'StatementOfAccountAPI', 'findSOADetails'));
            returnErrorAPI.returnError(res, requestId, 'Server Error: ' + ex.getMessage(), 200);
        }
    }
    //2.0 - added
    public static List<String> getfilters(string customlablename) {
        String labelValue = customlablename;
        
        List<String> filterString = new List<String>();
        if (String.isNotBlank(labelValue)) {
            if (labelValue.contains(',')) {
                // Split by comma and trim spaces
                for (String s : labelValue.split(',')) {
                    filterString.add(s.trim());
                }
            } else {
                // No comma, just single value
                filterString.add(labelValue.trim());
            }
        }
        return filterString;
   } 
}