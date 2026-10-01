/**********************************************************************************************************************
* Name               : OIC_DPGProjectsAPI                                                        
* Description        : This class is used to fetch project details.
* Usage              : 
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                08 04 2025      Initial Draft       
* 1.1           Suresh   	                15 10 2025      phase added
* 1.2           Jay Patel                   23 Sep 2026     MCR-73 — with sharing, createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/dpg/getprojects/*')
global with sharing class OIC_DPGProjectsAPI {
    
    @HttpGet
    global static void getProjectsDPG() {
        RestRequest restRequest = RestContext.request;
        RestResponse restResponse = RestContext.response;
        GetProjectsResponse obj_GetProjectsResponse = new GetProjectsResponse();
        obj_GetProjectsResponse.ProjectDetails = new List<Project>();
        restRequest.addHeader('Content-Type', 'application/json');
        try {
            List<Project__c> lst_Project = new List<Project__c>();
            List<PaymentPlan__c> lst_paymentPlan = new List<PaymentPlan__c>();
            Map<Id, List<PaymentPlan__c>> map_PaymentPlan = new Map<Id, List<PaymentPlan__c>>();
            lst_Project = OIC_DPGProjectsAPIHelper.getAllProjects();
            lst_paymentPlan = OIC_DPGProjectsAPIHelper.getAllPaymentPlans();
            for(PaymentPlan__c obj_PaymentPlan : lst_paymentPlan){
                if(!String.isBlank(obj_PaymentPlan.Project__c)){
                    if(map_PaymentPlan.containsKey(obj_PaymentPlan.Project__c)){
                        map_PaymentPlan.get(obj_PaymentPlan.Project__c).add(obj_PaymentPlan);
                    } else {
                        List<PaymentPlan__c> map_lstPaymentPlan = new List<PaymentPlan__c>();
                        map_lstPaymentPlan.add(obj_PaymentPlan);
                        map_PaymentPlan.put(obj_PaymentPlan.Project__c, map_lstPaymentPlan); 
                    }
                }
                if(!String.isBlank(obj_PaymentPlan.Phase__r.Project__c)){
                    if(map_PaymentPlan.containsKey(obj_PaymentPlan.Phase__r.Project__c)){
                        map_PaymentPlan.get(obj_PaymentPlan.Phase__r.Project__c).add(obj_PaymentPlan);
                    } else {
                        List<PaymentPlan__c> map_lstPaymentPlan = new List<PaymentPlan__c>();
                        map_lstPaymentPlan.add(obj_PaymentPlan);
                        map_PaymentPlan.put(obj_PaymentPlan.Phase__r.Project__c, map_lstPaymentPlan); 
                    }
                }            
            }
            for(Project__c obj_Project : lst_Project){
                Project project = new Project();
                List<PaymentPlan> lst_Payment = new List<PaymentPlan>();
                project.Id = obj_Project.Id;
                project.Name = obj_Project.Name;
                project.District = obj_Project.District__r.Name;
                project.Island = obj_Project.Island_Name__c;
                if(map_PaymentPlan != null && map_PaymentPlan.containsKey(obj_Project.Id)){
                    List<PaymentPlan__c> tmp_lstPaymentPlan = map_PaymentPlan.get(obj_Project.Id);
                    for(PaymentPlan__c obj_Plan : tmp_lstPaymentPlan){
                        PaymentPlan obj_PaymentPlan = new PaymentPlan();
                        obj_PaymentPlan.Id = obj_Plan.Id;
                        obj_PaymentPlan.Name = obj_Plan.Name;
                        obj_PaymentPlan.ProjectId = obj_Project.Id;
                        obj_PaymentPlan.PhaseId = (obj_Plan.Phase__r != null) ? obj_Plan.Phase__r.Id : null;
                        obj_PaymentPlan.Status = obj_Plan.Status__c;
                        obj_PaymentPlan.PaymentInstallment = obj_Plan.PaymentInstallment__c;
                        obj_PaymentPlan.StartDate = obj_Plan.StartDate__c;
                        obj_PaymentPlan.ExpiryDate = obj_Plan.ExpiryDate__c;
                        lst_Payment.add(obj_PaymentPlan);
                    }
                    project.PaymentPlanDetails = lst_Payment;
                }
                
                obj_GetProjectsResponse.ProjectDetails.add(project);
            }
            obj_GetProjectsResponse.Status = 'Success';
            obj_GetProjectsResponse.ErrorCode = '';
            obj_GetProjectsResponse.ErrorMessage = '';
            restResponse.statusCode = 200;
        } catch (Exception ex) {
            //1.2 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'DPG Projects API',
                'OIC_DPGProjectsAPI',
                'getProjectsDPG'
            ));
            obj_GetProjectsResponse.Status = 'Failure';
            obj_GetProjectsResponse.ErrorCode = 'PRJ-999';
            obj_GetProjectsResponse.ErrorMessage = ex.getMessage();
            restResponse.statusCode = 200;
        }
        restResponse.addHeader('Content-Type', 'application/json');
        restResponse.responseBody = Blob.valueOf(JSON.serialize(obj_GetProjectsResponse));
    }
    global class GetProjectsResponse{
        List<Project> ProjectDetails;  
        public String Status;	
        public String ErrorCode;	
        public String ErrorMessage;
    }
    global class Project{
        public String Id;	
        public String Name;	
        public String District;	
        public String Island;
        public List<PaymentPlan> PaymentPlanDetails;
    } 
    global class PaymentPlan{
        public String Id;	
        public String Name;	
        public String ProjectId;
        public String PhaseId;
        public String Status;	
        public Decimal PaymentInstallment;	
        public Date StartDate;
        public Date ExpiryDate;
    }    
}