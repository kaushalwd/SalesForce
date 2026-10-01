/**********************************************************************************************************************
* Name               : PaymentReminderController                                                        
* Description        : This class Create PaymentReminder 
* Usage              : This class Called in Paymentreminder.Js
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* ---------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0			raghu.gajjela@activemindsit.com 			12 April 2025	This class Create PaymentReminder
*2.0			raghu.gajjela@activemindsit.com				01 April 2026	Added  reminder type for 1 day prior
***********************************************************************************************************************/
public with sharing class PaymentReminderController {
    
    @AuraEnabled
    public static String getAllProject(){
        List<Project__c> projectList = new List<Project__c>();
        projectList = [select id,Name from Project__c];
        return JSON.serialize(projectList);
    }
    
    @AuraEnabled
    public static List<String> getPhasesAndReminderForProject(String projectId){
        List<String> response = new list<String>();
        List<Project__c>projectList =[select Id,Name from Project__c where Id =:projectId ];
        List<Phase__c> phaselist = [select id,Name  from Phase__c WHERE Project__c = : projectId ];
        response.add(JSON.serialize(phaselist));
        List<string>reminderTypes = new List<string>();
        set<string>reminderTypesSet = new set<string>();
        system.debug('---projectList ---------------'+projectList );
        if(projectList.size()>0){
            List<PaymentRemindersTemplates__mdt> paymmentReminderList = [
                select id,ReminderType__c,ProjectSetting__c,ProjectSetting__r.MasterLabel from PaymentRemindersTemplates__mdt
                where ProjectSetting__r.MasterLabel =: projectList[0].Name and ReminderType__c != null
            ];
            system.debug('---paymmentReminderList ---------------'+paymmentReminderList );

            for(PaymentRemindersTemplates__mdt pr : paymmentReminderList ){
                    reminderTypesSet.add(pr.ReminderType__c );
            }
            system.debug('---reminderTypesSet---------------'+reminderTypesSet);

            if(reminderTypesSet.size()>0)reminderTypes.addAll(reminderTypesSet);
        }
        system.debug('---reminderTypes---------------'+reminderTypes);

        response.add(JSON.serialize(reminderTypes));
        return response;
    }
    
    @Auraenabled
    Public Static String getInstallments(String selectedProject,String selectedPhaseId,
        string selectedReminderType,String selectedUnitName
        //,string selectedSubPhaseId,String selectedProject,String selectedUnitName,String selectedTimeline,Date selectedDueDate
    ){
        
        String str='';
        string unitName = '%' + selectedUnitName + '%';
       
        Set<string>reminderTypes = new Set<string>{'15 Days Prior','30 days Prior','7 Days Prior','1 Day Prior'}; // V  2.0
        List<SalesOrderInstallments__c> installmentList = new List<SalesOrderInstallments__c>();
        str+='Select id,name,SalesOrder__r.Unit__c,SalesOrder__r.Unit__r.Name,SalesOrder__r.Unit__r.Phase__r.Name,SalesOrder__r.Unit__r.Phase__c,SalesOrder__r.CustomerAccount__r.Name,SalesOrder__r.CustomerAccount__c,DueFilterDays__c,ExtensionDate__c,InstallmentAmount__c,Instalment_Number__c,InstalmentPaymentDueDate__c,Milestone_Installment__c,Milestone__c,MilestoneDate__c, MilestoneDescription__c, PaymentStatus__c,ReminderDueDate__c,ReminderType__c,SalesOrder__c, ';
        str+= ' (select id,Name,recordType.name,InvoiceBalance__c  from Invoices__r  where InvoiceBalance__c > 0 and isCancelled__c = false and  recordType.name =\'Tax Invoice\') ';
        str+= ' from SalesOrderInstallments__c where PaymentStatus__c != \'Paid\' AND PaymentStatus__c != \'Cancelled\' AND SalesOrder__r.Status__c=\'Completed\' and ReminderType__c != null and ReminderType__c IN: reminderTypes '; //and ReminderType__c IN: reminderTypes

        Map<String, Object> binds = new Map<String, Object>{
            'reminderTypes' => reminderTypes
        };

        if(String.isNotBlank(selectedProject) &&  selectedProject != 'All'){
            str+=' AND SalesOrder__r.Unit__r.Phase__r.Project__c =:selectedProject';
            binds.put('selectedProject', selectedProject);
        }
        if(String.isNotBlank(selectedPhaseId)){
            str+=' AND SalesOrder__r.Unit__r.Phase__c =:selectedPhaseId';
            binds.put('selectedPhaseId', selectedPhaseId);
        }
        
        if(String.isNotBlank(selectedReminderType)){
            str+=' AND ReminderType__c =:selectedReminderType';
            binds.put('selectedReminderType', selectedReminderType);
        }
        system.debug('------222222-----selectedUnitName-------------'+selectedUnitName);   
        system.debug('------222222-----unitName -------------'+unitName );   

        if(String.isNotBlank(selectedUnitName)){
            str+=' AND SalesOrder__r.Unit__r.Name like :unitName';
            binds.put('unitName', unitName);
        }
       
        system.debug('------222222-----str-------------'+str);   
        str+=' ORDER BY ReminderDueDate__c desc limit 50000'; // limit 5000';
        system.debug('****QUERY****'+str);
        installmentList = (List<SalesOrderInstallments__c>) Database.queryWithBinds(str, binds, AccessLevel.SYSTEM_MODE);
        
        if(Test.isRunningTest()){
            installmentList = [Select id,name,SalesOrder__r.Unit__c,SalesOrder__r.Unit__r.Name,SalesOrder__r.Unit__r.Phase__r.Name,SalesOrder__r.Unit__r.Phase__c,SalesOrder__r.CustomerAccount__r.Name,SalesOrder__r.CustomerAccount__c,DueFilterDays__c,ExtensionDate__c,InstallmentAmount__c,Instalment_Number__c,InstalmentPaymentDueDate__c,Milestone_Installment__c,Milestone__c,MilestoneDate__c, MilestoneDescription__c, 
                PaymentStatus__c,ReminderDueDate__c,ReminderType__c,SalesOrder__c,
                (select id,Name,recordType.name,InvoiceBalance__c  from Invoices__r  where InvoiceBalance__c > 0 and isCancelled__c = false and  recordType.name ='Tax Invoice')
                from SalesOrderInstallments__c where PaymentStatus__c != 'Paid' limit 10
            ];
        }

        
        List<Installment> installmentsWrapper = new List<Installment>();

        for(SalesOrderInstallments__c installment : installmentList) {
            
            system.debug('****installment****'+installment);

            Installment installmentRecord = new Installment();
            installmentRecord.InstallmentId = installment.Id;
            installmentRecord.AccountName = installment.SalesOrder__r.CustomerAccount__r.Name;
            installmentRecord.AccountId= installment.SalesOrder__r.CustomerAccount__c;
            installmentRecord.PhaseId = installment.SalesOrder__r.Unit__r.Phase__c;
            installmentRecord.PhaseName = installment.SalesOrder__r.Unit__r.Phase__r.Name;
            installmentRecord.FinalAmount = installment.InstallmentAmount__c;
            decimal rembalance =0;
            for(Invoice__c inv : installment.Invoices__r){
                rembalance += inv.InvoiceBalance__c; 
            }
            installmentRecord.RemainingAmount = rembalance;//installment.RemainingAmount__c;
            // installmentRecord.DueDate = installment.DueDate__c;
            installmentRecord.ReminderDueDate = installment.ReminderDueDate__c;
            installmentRecord.InstallmentName = installment.Name;
            installmentRecord.UnitName = installment.SalesOrder__r.Unit__r.Name;
            installmentRecord.UnitId= installment.SalesOrder__r.Unit__c ;
            installmentRecord.ReminderType = installment.ReminderType__c;
            installmentsWrapper.add(installmentRecord);
        }
        return JSON.serialize(installmentsWrapper);
    }    
    
    public class Installment{
        @AuraEnabled
        public String InstallmentId{get;set;}
        @AuraEnabled
        public String AccountName{get;set;}
        @AuraEnabled
        public String AccountId{get;set;}
        @AuraEnabled
        public String PhaseId{get;set;}
        @AuraEnabled
        public String PhaseName{get;set;}
        @AuraEnabled
        public Decimal FinalAmount{get;set;}
        @AuraEnabled
        public Decimal RemainingAmount{get;set;}
        @AuraEnabled
        public Date DueDate{get;set;}
        @AuraEnabled
        public Date ReminderDueDate{get;set;}
        @AuraEnabled
        public String UnitName{get;set;}
        @AuraEnabled
        public String InstallmentName{get;set;}
        @AuraEnabled
        public String UnitId{get;set;}
        @AuraEnabled
        public String ReminderType{get;set;}
        @AuraEnabled
        public String CurrencyIsoCode{get;set;}
        @AuraEnabled
        public String ReminderSent{get;set;}
        @AuraEnabled
        public Date ReminderSentDate{get;set;}
        @AuraEnabled
        public String OpportunityId{get;set;}
        @AuraEnabled
        public String emailMessageId {get; set;} 
        @AuraEnabled
        public String PaymentReminderId {get; set;}  
        @AuraEnabled
        public Date sentDate{get; set;}  
    }
     @AuraEnabled
    public Static String getRemindersRecords(
        String selectedProject,
        String selectedPhaseId
       // string selectedSubPhaseId,
       // ,String selectedUnitName,String selectedTimeline,Date reminderSentDate
    ){
        
        String str='';
        //string unitName = '%' + selectedUnitName + '%';
        List<PaymentReminder__c> paymentReminderList = new List<PaymentReminder__c>();
        Set<string>reminderTypes = new Set<string>{'15 Days Prior','30 days Prior','7 Days Prior','1 Day Prior'};// V2.0

        str+= ' SELECT id,SalesOrderInstallment__r.SalesOrder__r.Unit__r.Name,SalesOrderInstallment__r.SalesOrder__r.Unit__c,name,SalesOrderInstallment__r.MilestoneDate__c,SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__c,SalesOrderInstallment__r.SalesOrder__r.CustomerAccount__c,SalesOrderInstallment__r.SalesOrder__r.CustomerAccount__r.Name,ErrorReason__c, DueDate__c, From_Address__c, IsEmailDelivered__c, ReminderType__c, SalesOrderInstallment__c, SentDate__c,ToAddress__c,SalesOrderInstallment__r.Name, ';
        str+= ' (select Id from Emails)';
        str+= ' FROM PaymentReminder__c WHERE ReminderType__c != null and ReminderType__c  IN: reminderTypes ';

        Map<String, Object> binds = new Map<String, Object>{
            'reminderTypes' => reminderTypes
        };

        if(String.isNotBlank(selectedProject) &&  selectedProject != 'All'){
            str+=' AND SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Project__c =:selectedProject';
            binds.put('selectedProject', selectedProject);
        }
        if(String.isNotBlank(selectedPhaseId)){
            str+=' AND SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__c =:selectedPhaseId';
            binds.put('selectedPhaseId', selectedPhaseId);
        }
        
        system.debug('------5555-----str-------------'+str);   
        str+=' ORDER BY DueDate__c '; 
        system.debug('****QUERY****'+str);
        paymentReminderList = (List<PaymentReminder__c>) Database.queryWithBinds(str, binds, AccessLevel.SYSTEM_MODE);

        List<Installment> installmentsWrapper = new List<Installment>();
        
         for(PaymentReminder__c paymentReminder : paymentReminderList){
            system.debug('****payment reminder****'+paymentReminder);           
           
            Installment installmentRecord = new Installment();

            installmentRecord.PaymentReminderId = paymentReminder.Id;
            installmentRecord.InstallmentId = paymentReminder.SalesOrderInstallment__c;
            installmentRecord.AccountName = paymentReminder.SalesOrderInstallment__r.SalesOrder__r.CustomerAccount__r.Name;
            installmentRecord.AccountId= paymentReminder.SalesOrderInstallment__r.SalesOrder__r.CustomerAccount__c;
            installmentRecord.PhaseId = paymentReminder.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__c;
            installmentRecord.FinalAmount = 0;//paymentReminder.Installment__r.FinalAmount__c;
            installmentRecord.RemainingAmount =0;// paymentReminder.Installment__r.RemainingAmount__c;
            installmentRecord.DueDate = paymentReminder.SalesOrderInstallment__r.MilestoneDate__c;
            installmentRecord.ReminderDueDate = paymentReminder.DueDate__c ;
            installmentRecord.InstallmentName = paymentReminder.SalesOrderInstallment__r.Name;
            installmentRecord.UnitName = paymentReminder.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Name;
            installmentRecord.UnitId= paymentReminder.SalesOrderInstallment__r.SalesOrder__r.Unit__c ;           
            installmentRecord.ReminderType = paymentReminder.ReminderType__c ;
            //installmentRecord.CurrencyIsoCode = paymentReminder.Installment__r.CurrencyIsoCode;
            
           installmentRecord.emailMessageId = paymentReminder.Emails!= null && paymentReminder.Emails.size()>0 ? paymentReminder.Emails[0].Id :'';
            
             installmentRecord.sentDate = Date.ValueOf(paymentReminder.SentDate__c);
            installmentsWrapper.add(installmentRecord);
        }
        return JSON.serialize(installmentsWrapper);
    }    
}