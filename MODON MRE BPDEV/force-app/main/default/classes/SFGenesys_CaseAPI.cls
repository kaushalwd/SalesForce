/**
 * REST API Class: Handles customer case creation
 * API Name: Case Creation from Gensys
 * Description: Following service is used to generate Case.
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                      Date            Comment
 * 1.1           hmathur@horizontal.com      18 Sep 2026     MCR-73 — with sharing, USER_MODE SOQL, USER_MODE DML, createApexLog
 */
@RestResource(urlMapping='/createcase/*')
global with sharing class SFGenesys_CaseAPI {
    
    @HttpPost
    global static void createCase() {
        RestRequest restRequest = RestContext.request;
        RestResponse restResponse = RestContext.response;
        CreateCaseRequest obj_CreateCaseRequest = new CreateCaseRequest();
        CreateCaseResponse obj_CreateCaseResponse = new CreateCaseResponse();
        restRequest.addHeader('Content-Type', 'application/json');
        obj_CreateCaseRequest = (CreateCaseRequest)System.JSON.deserialize(restRequest.requestBody.toString(), CreateCaseRequest.class);
        System.debug('SFGenesys_CaseAPI >>>> createCase >> '+System.JSON.serialize(obj_CreateCaseRequest));
        if(obj_CreateCaseRequest == null || String.isBlank(obj_CreateCaseRequest.Category)
          || String.isBlank(obj_CreateCaseRequest.Category) || String.isBlank(obj_CreateCaseRequest.Description) 
          || String.isBlank(obj_CreateCaseRequest.FirstName) || String.isBlank(obj_CreateCaseRequest.LastName) 
          || String.isBlank(obj_CreateCaseRequest.Email) || String.isBlank(obj_CreateCaseRequest.Phone)){
            obj_CreateCaseResponse.CaseOwner = '';
            obj_CreateCaseResponse.CaseId = '';
            obj_CreateCaseResponse.CaseNumber = '';
            obj_CreateCaseResponse.Status = 'Failure';
            obj_CreateCaseResponse.ErrorCode = '400';
            obj_CreateCaseResponse.ErrorMessage = 'Mandatory fields are empty';
            restResponse.statusCode = 400;  
          } else {
              try{
                  Case obj_Case = new Case();
                  if(!String.isBlank(obj_CreateCaseRequest.AccountId)){
                      obj_Case.AccountId = obj_CreateCaseRequest.AccountId;
                  }
                  if(!String.isBlank(obj_CreateCaseRequest.ContactId)){
                      obj_Case.ContactId = obj_CreateCaseRequest.ContactId;
                  }  
                  obj_Case.Origin = obj_CreateCaseRequest.CaseOrigin;
                  obj_Case.Requestor_Phone__c = obj_CreateCaseRequest.Phone;
                  obj_Case.Requestor_Email__c = obj_CreateCaseRequest.Email;
                  obj_Case.Requestor_Name__c = obj_CreateCaseRequest.FirstName+' '+obj_CreateCaseRequest.LastName;
                  obj_Case.Language_Preference__c = obj_CreateCaseRequest.Language;
                  obj_Case.CaseCategory__c = obj_CreateCaseRequest.Category;
                  obj_Case.CaseSubCategory__c = obj_CreateCaseRequest.SubCategory;
                  obj_Case.Description = obj_CreateCaseRequest.Description;
                  obj_Case.Subject = obj_CreateCaseRequest.Subject;
                  //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Case insert
                  Database.insert(new List<Case>{obj_Case}, true, AccessLevel.USER_MODE);
                  //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Case query
                  List<Case> lst_Case = [select Id, New_Owner__r.Name, CaseNumber, Current_Owner_Name__c from Case where Id = :obj_Case.Id WITH USER_MODE];
                  Case obj_Newcase = lst_Case!=null ? lst_Case.get(0) : null; 
                  	obj_CreateCaseResponse.CaseOwner = obj_Newcase.Current_Owner_Name__c;
                    obj_CreateCaseResponse.CaseId = obj_Newcase.Id;
                    obj_CreateCaseResponse.CaseNumber = obj_Newcase.CaseNumber;
                    obj_CreateCaseResponse.Status = 'Success';
                    obj_CreateCaseResponse.ErrorCode = '';
                    obj_CreateCaseResponse.ErrorMessage = '';
                  restResponse.statusCode = 200; 
              }catch(Exception exe){
                  	obj_CreateCaseResponse.CaseOwner = '';
                    obj_CreateCaseResponse.CaseId = '';
                    obj_CreateCaseResponse.CaseNumber = '';
                    obj_CreateCaseResponse.Status = 'Failure';
                    obj_CreateCaseResponse.ErrorCode = '400';
                    obj_CreateCaseResponse.ErrorMessage = exe.getMessage();
                    restResponse.statusCode = 200;
                  //1.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
                  LoggerService.save(LoggerService.createApexLog(
                      exe,
                      'SFGenesys_CaseAPI',
                      'SFGenesys_CaseAPI',
                      'createCase'
                  ));
              }  
              
          }
        restResponse.addHeader('Content-Type', 'application/json');
        restResponse.responseBody = Blob.valueOf(JSON.serialize(obj_CreateCaseResponse)); 
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