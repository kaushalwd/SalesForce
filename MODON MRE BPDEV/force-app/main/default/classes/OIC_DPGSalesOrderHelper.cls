/**********************************************************************************************************************
* Name                : OIC_DPGSalesOrderHelper
* Description         : This class contains main processing logic for DPG Sales Order Integration.
* Usage               : Validates relationships, maps incoming payload properties, blocks units, and runs DMLs.
* Created By          : Activemindsit
* --------------------------------------------------------------------------------------------------------------------
* Version      Author                Date            Comment
* 1.0          Suresh                31 03 2025      Initial Draft
* 1.1          Arvind                03 Jul 2026     Unified architecture pattern and integrated broker logic
***********************************************************************************************************************/
public with sharing class OIC_DPGSalesOrderHelper {

    private static final String BROKER_PROFILE_NAME = 'Modon - Partner Community Login User';
    private static final Set<String> BROKER_CONTACT_TYPES = new Set<String>{ 'Owner', 'Agent', 'Agency Admin' };

    /**
     * Determines whether the currently running user context belongs to a Partner Community Broker.
     */
    public static Contact getBrokerContactContext() {
        Id runningUserId = UserInfo.getUserId();
        
        List<User> userList = [
            SELECT Id, ContactId, Profile.Name 
            FROM User 
            WHERE Id = :runningUserId 
            LIMIT 1
        ];
        
        if (userList.isEmpty() || userList[0].ContactId == null || userList[0].Profile.Name != BROKER_PROFILE_NAME) {
            return null;
        }
        
        List<Contact> contactList = [
            SELECT Id, Name, Phone, AccountId, Broker_Type__c 
            FROM Contact 
            WHERE Id = :userList[0].ContactId 
            LIMIT 1
        ];
        
        if (!contactList.isEmpty() && String.isNotBlank(contactList[0].Broker_Type__c) && BROKER_CONTACT_TYPES.contains(contactList[0].Broker_Type__c)) {
            return contactList[0];
        }
        
        return null;
    }

    /**
     * Main validation, record configuration, and generation orchestration module.
     */
    public static OIC_DPGCreateSalesOrderAPI.CreateSalesOrderResponse createSalesOrderDPG(
        OIC_DPGCreateSalesOrderAPI.CreateSalesOrderRequest req
    ) {
        OIC_DPGCreateSalesOrderAPI.CreateSalesOrderResponse obj_Response = new OIC_DPGCreateSalesOrderAPI.CreateSalesOrderResponse();
        Savepoint sp = Database.setSavepoint();

        try {
            OIC_DPGCreateSalesOrderAPI.SalesOrderWrapper soWrap = req.SalesOrders[0];

            // 1. Validate Parent Opportunity context and get Customer Profile fields
            List<Opportunity> opps = [
                SELECT Id, AccountId, Account.Name, PrimaryContact__c, CustomerType__c, 
                       UAE_Resident_Status__c, BrokerAgency__c, BrokerAgent__c
                FROM Opportunity
                WHERE Id = :req.OpportunityId
                LIMIT 1
            ];

            if (opps.isEmpty()) {
                obj_Response.Status = 'Failure';
                obj_Response.ErrorCode = 'SO-004';
                obj_Response.ErrorMessage = 'The provided Opportunity ID was not found in the system.';
                return obj_Response;
            }
            Opportunity targetOpp = opps[0];

            // 2. Validate Inventory Unit availability & establish Row-Level Locking
            List<Unit__c> units = [
                SELECT Id, Name, Status__c, Sub_Status__c, Phase__r.EscrowAccount__c
                FROM Unit__c
                WHERE Id = :soWrap.UnitId
                FOR UPDATE
            ];

            if (units.isEmpty()) {
                obj_Response.Status = 'Failure';
                obj_Response.ErrorCode = 'SO-005';
                obj_Response.ErrorMessage = 'The provided Unit ID was not found in the system.';
                return obj_Response;
            }
            Unit__c targetUnit = units[0];

            if (targetUnit.Status__c == 'Reserved') {
                obj_Response.Status = 'Failure';
                obj_Response.ErrorCode = 'SO-006';
                obj_Response.ErrorMessage = 'The requested Unit is already reserved.';
                return obj_Response;
            }

            // 3. Evaluate Running User Partner Broker context
            Contact brokerContact = getBrokerContactContext();

            // 4. Instantiate and map properties across onto the new Sales Order sObject record
            SalesOrder__c newSalesOrder = new SalesOrder__c(
                Unit__c                  = soWrap.UnitId,
                PaymentPlan__c           = soWrap.PaymentPlanId,
                UnitOption__c            = soWrap.UnitOptionId,
                
                TotalAmount__c           = soWrap.TotalPrice, // Populate to support downstream payment iteration math
                Opportunity__c           = targetOpp.Id,
                CustomerAccount__c       = targetOpp.AccountId,
                PrimaryContact__c        = targetOpp.PrimaryContact__c,
                CustomerType__c          = targetOpp.CustomerType__c,
                UAE_Resident_Status__c   = targetOpp.UAE_Resident_Status__c
            );

            // Handle Broker tracking assignments (Community Context vs CRM Data Context fallbacks)
            if (brokerContact != null) {
                newSalesOrder.Broker_Agency_Name__c = brokerContact.AccountId;
                newSalesOrder.Broker_Agent_Name__c  = brokerContact.Id;
            } else {
                if (targetOpp.BrokerAgency__c != null) {
                    newSalesOrder.Broker_Agency_Name__c = targetOpp.BrokerAgency__c;
                }
                if (targetOpp.BrokerAgent__c != null) {
                    newSalesOrder.Broker_Agent_Name__c = targetOpp.BrokerAgent__c;
                }
            }

            Database.insert(newSalesOrder, true);

            // 5. Update Asset Inventory tracking state configuration parameters
            targetUnit.Status__c = 'Reserved';
            targetUnit.Sub_Status__c = null;
            targetUnit.BlockedFor__c = UserInfo.getUserId();
            targetUnit.Opportunity__c = targetOpp.Id;
            
            Database.update(targetUnit, true);

            // 6. Generate matching payment installment sub-records
            createPaymentInstallments(new List<SalesOrder__c>{ newSalesOrder });

            // Fetch auto-number Name field generated on save
            List<SalesOrder__c> insertedSO = [SELECT Name FROM SalesOrder__c WHERE Id = :newSalesOrder.Id LIMIT 1];

            // 7. Enrich response mapping object with complete contextual references
            obj_Response.Status = 'Success';
            obj_Response.Message = 'Sales Order Created successfully.';
            obj_Response.SalesOrderId = newSalesOrder.Id;
            obj_Response.SalesOrderNumber = !insertedSO.isEmpty() ? insertedSO[0].Name : '';
            obj_Response.OpportunityId = targetOpp.Id;
            obj_Response.UnitId = targetUnit.Id;
            obj_Response.UnitName = targetUnit.Name;
            
            // Map Customer Context outputs
            obj_Response.AccountId = targetOpp.AccountId;
            obj_Response.AccountName = targetOpp.Account.Name;
            obj_Response.CustomerType = targetOpp.CustomerType__c;
            obj_Response.PrimaryContactId = targetOpp.PrimaryContact__c;
            
            obj_Response.ErrorCode = '';
            obj_Response.ErrorMessage = '';

            return obj_Response;

        } catch (Exception e) {
            Database.rollback(sp);
            obj_Response.Status = 'Failure';
            obj_Response.ErrorCode = 'SO-ERR';
            obj_Response.ErrorMessage = e.getMessage();
            return obj_Response;
        }
    }

    /**
     * Evaluates linked payment structures to establish milestones and record allocations.
     */
    private static void createPaymentInstallments(List<SalesOrder__c> salesOrderList) {
        String currentUserProfileName = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId()].Name;        
        Boolean isEgyptProfile = currentUserProfileName != null && currentUserProfileName.toLowerCase().contains('egypt');

        List<SalesOrderInstallments__c> salesOrderInstallmentLst = new List<SalesOrderInstallments__c>(); 
        Map<String, List<PaymentInstallements__c>> paymentPlanInstallmentMap = new Map<String, List<PaymentInstallements__c>>();
        Map<String, String> salesOrderPaymentPlanMap = new Map<String, String>();
        Set<Id> paymentSet = new Set<Id>();

        for (SalesOrder__c soObj : salesOrderList) {
            if (soObj.PaymentPlan__c != null) {
                salesOrderPaymentPlanMap.put(soObj.Id, soObj.PaymentPlan__c);
                paymentSet.add(soObj.PaymentPlan__c);
            }
        }
        
        if (paymentSet.isEmpty()) return;
        
        for (PaymentInstallements__c piObj : [
            SELECT Id, Name, PaymentInstallment__c, BrokerPayout__c, IsHandoverPayment__c, Milestone__c, Milestone_Egypt_Percent__c, 
                   PaymentInstallment__r.Maintenance_Fee__c, MilestoneDate__c, MilestoneDescription__c, MilestoneNumber__c, 
                   SalesAgentPayout__c, Milestone_Due__c, MilestoneInstallment__c, Is_Maintenance_Installment__c, 
                   PaymentInstallment__r.Number_of_Maintenance_Fee__c
            FROM PaymentInstallements__c 
            WHERE PaymentInstallment__c IN :paymentSet
        ]) {
            List<PaymentInstallements__c> tempInstallment = paymentPlanInstallmentMap.get(piObj.PaymentInstallment__c);
            if (tempInstallment == null) {
                tempInstallment = new List<PaymentInstallements__c>();
            }
            tempInstallment.add(piObj);
            paymentPlanInstallmentMap.put(piObj.PaymentInstallment__c, tempInstallment);
        }
        
        for (SalesOrder__c soObj : salesOrderList) {
            String planId = salesOrderPaymentPlanMap.get(soObj.Id);
            if (planId == null || !paymentPlanInstallmentMap.containsKey(planId)) continue;

            // Safe fallback value to clear calculation crashes
            Decimal orderBaseAmount = soObj.TotalAmount__c;

            for (PaymentInstallements__c piObj : paymentPlanInstallmentMap.get(planId)) {
                SalesOrderInstallments__c soiObj = new SalesOrderInstallments__c();
                Decimal milestonePercent = isEgyptProfile ? piObj.Milestone_Egypt_Percent__c : piObj.Milestone__c;
                if (milestonePercent == null) milestonePercent = 0;

                soiObj.SalesOrder__c = soObj.Id;
                soiObj.PaymentInstallments__c = piObj.Id;
                soiObj.BrokerPayout__c = piObj.BrokerPayout__c;
                soiObj.IsHandoverPayment__c = piObj.IsHandoverPayment__c;
                
                if (isEgyptProfile) {
                    soiObj.Milestone_Egypt_Percent__c = milestonePercent;
                } else {
                    soiObj.Milestone__c = milestonePercent;
                }   
                
                if (piObj.MilestoneNumber__c == 1 || (piObj.MilestoneDescription__c != null && piObj.MilestoneDescription__c.contains('Down Payment'))) {  
                    soiObj.MilestoneDate__c = System.today();
                } else {
                    soiObj.MilestoneDate__c = piObj.Milestone_Due__c;
                }
                
                if (piObj.MilestoneInstallment__c != null) soiObj.Milestone_Installment__c = piObj.MilestoneInstallment__c;
                soiObj.MilestoneDescription__c = piObj.MilestoneDescription__c;
                soiObj.MilestoneNumber__c = piObj.MilestoneNumber__c;
                soiObj.SalesAgentPayout__c = piObj.SalesAgentPayout__c;
                soiObj.InstallmentAmount__c = orderBaseAmount * (milestonePercent / 100);
                
                if (piObj.Is_Maintenance_Installment__c && piObj.PaymentInstallment__r.Maintenance_Fee__c != null && piObj.PaymentInstallment__r.Number_of_Maintenance_Fee__c != null && piObj.PaymentInstallment__r.Number_of_Maintenance_Fee__c != 0) {
                    soiObj.Maintenance_Fee__c = (orderBaseAmount * (piObj.PaymentInstallment__r.Maintenance_Fee__c / 100)) / piObj.PaymentInstallment__r.Number_of_Maintenance_Fee__c;
                } else {
                    soiObj.Maintenance_Fee__c = 0;
                }
                soiObj.CurrencyIsoCode = soObj.CurrencyIsoCode;
                salesOrderInstallmentLst.add(soiObj);
            }
        }
        
        if (!salesOrderInstallmentLst.isEmpty()) {
            Database.insert(salesOrderInstallmentLst, true);
        }
    }
}