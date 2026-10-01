/**********************************************************************************************************************
* Name               : OIC_DPGProjectsAPIHelper                                                        
* Description        : This class is used to fetch project details.
* Usage              : 
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                08 04 2025      Initial Draft       
* 1.1           Suresh   	                15 10 2025      phase added
* 1.2           Arvind                      02 Aug 2026      Is_Employee_Payment_Plan__c = False only show to DPG
***********************************************************************************************************************/
global class OIC_DPGProjectsAPIHelper {
    
    public static List<Project__c> getAllProjects(){
        List<Project__c> lst_Project = new List<Project__c>();
        try{
            lst_Project = [SELECT Id, Name, District__r.Name, Island_Name__c FROM Project__c ];            
        }catch(Exception exe){}
        return lst_Project;  
    }    
    public static List<PaymentPlan__c> getAllPaymentPlans(){
        List<PaymentPlan__c> lst_PaymentPlans = new List<PaymentPlan__c>();
        try{
            lst_PaymentPlans = [SELECT Id, Name, Status__c, PaymentInstallment__c, StartDate__c, ExpiryDate__c, 
                                Project__c, Phase__r.Name, Phase__r.Id, Phase__r.Project__c 
                                FROM PaymentPlan__c WHERE Status__c = 'Active' and Online_Sales__c = true and  Is_Employee_Payment_Plan__c = false and (Project__c != '' or Phase__c != '') ];
                        
        }catch(Exception exe){}
        return lst_PaymentPlans;
    } 
}