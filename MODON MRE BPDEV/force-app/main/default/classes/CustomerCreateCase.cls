/**********************************************************************************************************************
* Name               : CustomerCreateCase                                                        
* Description        : This class is used to create cases.
* Usage              : 
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    05 March 2026     Initial Draft
* 1.1           Suresh         			    16 June 2026      Added changes for category
* 1.2           hmathur@horizontal.com      18 Sep 2026     MCR-73 — with sharing, USER_MODE SOQL, USER_MODE DML, createApexLog
******************************************************************************************************************/
@RestResource(urlMapping='/CustomerCreateCaseAPI/*')
global with sharing class CustomerCreateCase {

    @HttpPost
    global static void createCase() {
        RestRequest restRequest = RestContext.request;
        RestResponse restResponse = RestContext.response;
        CreateCaseRequest obj_CreateCaseRequest = new CreateCaseRequest();
        CreateCaseResponse obj_CreateCaseResponse = new CreateCaseResponse();
        restRequest.addHeader('Content-Type', 'application/json');
        String requestId = String.valueOf(UUID.randomUUID());
        obj_CreateCaseRequest = (CreateCaseRequest)System.JSON.deserialize(restRequest.requestBody.toString(), CreateCaseRequest.class);
        System.debug('CustomerCreateCase >>>> createCase >> '+System.JSON.serialize(obj_CreateCaseRequest));
        //1.1 added
        if(obj_CreateCaseRequest == null || String.isBlank(obj_CreateCaseRequest.Description) 
          || String.isBlank(obj_CreateCaseRequest.FirstName) || String.isBlank(obj_CreateCaseRequest.LastName) 
          || String.isBlank(obj_CreateCaseRequest.Email) || String.isBlank(obj_CreateCaseRequest.Phone)
          || String.isBlank(obj_CreateCaseRequest.Category) || String.isBlank(obj_CreateCaseRequest.SubCategory)
          || String.isBlank(obj_CreateCaseRequest.UnitId)){
            LoggerService.save(LoggerService.createAPILog('MODON Connect Cases', 'CustomerCreateCase', 'createCase', restRequest.requestBody.toString(),'', 'Status Code: 200; Status: Missing Mandatory Parameters','OIC Error Log'));  
            returnError(restResponse, requestId, 'Missing Mandatory Parameters', 200);
            return;  
          } else {
              try{
                  Case obj_Case = new Case();
                  //1.1 added
                  SA_Cases_Mapping__mdt obj_SAMap = NULL;
                  //1.2 MCR-73: Enforce CRUD/FLS via USER_MODE on SA_Cases_Mapping__mdt query
                  List<SA_Cases_Mapping__mdt> lst_SAMapping = [select Category__c, Channel__c, Origin__c, Request_Category__c, Request_Type__c,
                                                              Source__c, SubCategory__c, Sub_Vertical__c from SA_Cases_Mapping__mdt
                                                              where Request_Category__c = :obj_CreateCaseRequest.Category
                                                              AND Request_Type__c = :obj_CreateCaseRequest.SubCategory
                                                              WITH USER_MODE];
                  if(lst_SAMapping.size() > 0){
                      obj_SAMap = lst_SAMapping.get(0);
                  } else {
                      returnErrorAPI.returnError(restResponse, requestId, 
                                                 'No configuration in salesforce for category '+obj_CreateCaseRequest.Category+' : '+obj_CreateCaseRequest.SubCategory, 200);
                      return;
                  }
                  if(!String.isBlank(obj_CreateCaseRequest.AccountId)){
                      obj_Case.AccountId = obj_CreateCaseRequest.AccountId;
                  }
                  if(!String.isBlank(obj_CreateCaseRequest.ContactId)){
                      obj_Case.ContactId = obj_CreateCaseRequest.ContactId;
                  } 
                  if(!String.isBlank(obj_CreateCaseRequest.UnitId)){
                      obj_Case.Unit__c = obj_CreateCaseRequest.UnitId;
                  }
                  obj_Case.Requestor_Phone__c = obj_CreateCaseRequest.Phone;
                  obj_Case.Requestor_Email__c = obj_CreateCaseRequest.Email;
                  obj_Case.Requestor_Name__c = obj_CreateCaseRequest.FirstName+' '+obj_CreateCaseRequest.LastName;
                  obj_Case.Language_Preference__c = obj_CreateCaseRequest.Language;
                  obj_Case.Description = obj_CreateCaseRequest.Description;
                  obj_Case.Subject = obj_CreateCaseRequest.Subject;
                  obj_Case.Customer_Type__c = 'Owner';
                  obj_Case.Case_Comments__c = obj_CreateCaseRequest.Description;
                  //1.1 added
                  obj_Case.Origin = obj_SAMap.Origin__c;
                  obj_Case.Channel__c = obj_SAMap.Channel__c;
                  obj_Case.Source__c = obj_SAMap.Source__c;
                  obj_Case.Sub_Vertical__c = obj_SAMap.Sub_Vertical__c;
                  obj_Case.CaseCategory__c = obj_SAMap.Category__c;
                  obj_Case.CaseSubCategory__c = obj_SAMap.SubCategory__c;
                  
                  //1.2 MCR-73: Enforce CRUD/FLS via USER_MODE on Case insert
                  Database.insert(new List<Case>{obj_Case}, true, AccessLevel.USER_MODE);
                  //1.2 MCR-73: Enforce CRUD/FLS via USER_MODE on Case query
                  List<Case> lst_Case = [select Id, New_Owner__r.Name, CaseNumber, Current_Owner_Name__c from Case where Id = :obj_Case.Id WITH USER_MODE];
                  Case obj_Newcase = lst_Case!=null ? lst_Case.get(0) : null; 
                  	obj_CreateCaseResponse.CaseOwner = obj_Newcase.Current_Owner_Name__c;
                    obj_CreateCaseResponse.CaseId = obj_Newcase.Id;
                    obj_CreateCaseResponse.CaseNumber = obj_Newcase.CaseNumber;
                    obj_CreateCaseResponse.Status = 'Success';
                    obj_CreateCaseResponse.ErrorCode = '';
                    obj_CreateCaseResponse.ErrorMessage = '';
              }catch(Exception exe){
                  	obj_CreateCaseResponse.CaseOwner = '';
                    obj_CreateCaseResponse.CaseId = '';
                    obj_CreateCaseResponse.CaseNumber = '';
                    obj_CreateCaseResponse.Status = 'Failure';
                    obj_CreateCaseResponse.ErrorCode = '400';
                    obj_CreateCaseResponse.ErrorMessage = exe.getMessage();
                  //1.2 MCR-73: Log unexpected failures via LoggerService.createApexLog
                  LoggerService.save(LoggerService.createApexLog(
                      exe,
                      'CustomerCreateCase',
                      'CustomerCreateCase',
                      'createCase'
                  ));
                  LoggerService.save(LoggerService.createAPILog('MODON Connect Cases', 'CustomerCreateCase', 'createCase', restRequest.requestBody.toString(),'', 'Status Code: 400; Status:'+exe.getMessage(),'OIC Error Log'));  
              }  
              
          }
        APIResponse response = new APIResponse('success', requestId, obj_CreateCaseResponse, null);
        restResponse.responseBody = Blob.valueOf(JSON.serialize(response));
        restResponse.addHeader('Content-Type', 'application/json');
        restResponse.statusCode = 200;
        LoggerService.save(LoggerService.createAPILog('MODON Connect Cases', 'CustomerCreateCase', 'createCase', restRequest.requestBody.toString(),JSON.serialize(response), 'Status Code: 200; Status: Success','OIC Error Log'));  
    }  
    private static void returnError(RestResponse res, String requestId, String msg, Integer status) {
        APIResponse error = new APIResponse('error', requestId, null, msg);
        res.responseBody = Blob.valueOf(JSON.serialize(error));
        res.statusCode = status;
    }
    global class CreateCaseRequest{
        public String CaseOrigin;	
        public String AccountId;	
        public String ContactId;	
        public String Phone;
        public String Email;
        public String FirstName;	
        public String LastName;
        public String Language;
        public String Category;
	    public String SubCategory;
        public String Description;
        public String Subject;
        public String UnitId;
    } 
    global class CreateCaseResponse {
        public String CaseOwner ;
        public String CaseId;
        public String CaseNumber;
        public String Status;	
        public String ErrorCode;	
        public String ErrorMessage;	
    }
}