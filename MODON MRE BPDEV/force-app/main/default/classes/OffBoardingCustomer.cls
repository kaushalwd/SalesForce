/**********************************************************************************************************************
* Name               : OffBoardingCustomer                                                        
* Description        : 1. Customer Account change - checks if the account still has any active Sales Order
*                 		(as primary customer OR as a Joint Owner). If yes, portal access is retained.
*                      2. Joint Owner history - checks the Joint Owner History records for the changed
*                     Sales Order. For each historical joint owner account, checks if they still have
*                     any active Sales Order (as primary or joint). If none found, portal access is revoked.
* Usage              : Used across Triggers and Batch classes 
* Created By         : Active minds Digital Middle East  
* 
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Manoj   	            26 Feb 2026     Initial Draft       

***********************************************************************************************************************/
global class OffBoardingCustomer implements Database.Batchable<SObject>, Database.AllowsCallouts {

    /** Active SO statuses sourced from custom label - same label used in OnBoarding */
    private String activeStatusValues  = System.Label.CPSOActiveStatus;

    /** Projects excluded from offboarding checks (same exclusion logic as onboarding) */
    private List<String> excludedProjects    = new List<String>();
	public Set<string> soIds;
    public OffBoardingCustomer(Set<String> soRecIds) {
        this.soIds = soRecIds;
         
    }
   
    global Database.QueryLocator start(Database.BatchableContext bc) {
		
        // Load excluded project names from label
        String excludeLabel = System.Label.MIRE_Exclude_List;
        for (String proj : excludeLabel.split(',')) {
            if (proj != null && proj.contains('^')) {
                excludedProjects.add(proj.replace('^', ',').trim());
            } else {
                excludedProjects.add(proj.trim());
            }
        }
        Date todayDate = Date.today();
        if (Test.isRunningTest()) {
            return Database.getQueryLocator([
                SELECT Id, CustomerAccount__c, Old_Account__c, CustomerAccount__r.Name, CustomerAccount__r.RecordType.Name, Status__c, Unit__c, CustomerAccount__r.IsCustomerPortal,
                       JO1__c, JO1__r.AccountId, JO1__r.Account.IsCustomerPortal,
                       JO2__c, JO2__r.Account.IsCustomerPortal, JO2__r.AccountId,
                       JO3__c, JO3__r.AccountId, JO3__r.Account.IsCustomerPortal,
                       JO4__c, JO4__r.AccountId, JO4__r.Account.IsCustomerPortal,
                       JO5__c, JO5__r.AccountId, JO5__r.Account.IsCustomerPortal,
                       JO6__c, JO6__r.AccountId, JO6__r.Account.IsCustomerPortal
                FROM SalesOrder__c
                LIMIT 1
            ]);
        } else {
            return Database.getQueryLocator([
                SELECT Id, Old_Account__c, Old_Account__r.Name, Old_Account__r.IsCustomerPortal, Old_Account__r.RecordType.Name, Status__c, ProjectName__c
                FROM SalesOrder__c
                WHERE ProjectName__c NOT IN :excludedProjects
                AND Resale_Transfer_Date__c = :todayDate
            ]);
        }
    }

    /*
     * EXECUTE – For each batch of Sales Orders, determine which accounts
             are safe to deactivate vs. which must be retained
    */
    global void execute(Database.BatchableContext bc, List<SalesOrder__c> scope) {
        System.debug('OffBoardingCustomer execute - scope size: ' + scope.size());

        Set<Id> soIdsInScope = new Set<Id>();
        // All accounts (primary + JO) that appear on the changed SOs
        Set<Id> communityPortalAccountIds = new Set<Id>();

        for (SalesOrder__c so : scope) {
            soIdsInScope.add(so.Id);
            communityPortalAccountIds.add(so.Old_Account__c);
        }

        // Also pull the OLD account Ids from Joint_Owner_History__c records
        // (these are the accounts that were removed from the SOs)
        for (Joint_Owner_History__c joh : [ SELECT Id,Sales_Order__c,Account__c,Account__r.IsCustomerPortal
            FROM   Joint_Owner_History__c
            WHERE  Sales_Order__c IN :soIdsInScope
            AND    Transfer_Date__c =: Date.TODAY()]) {
            communityPortalAccountIds.add(joh.Account__c);            
        }

        System.debug('Community/Portal account Ids for offboarding check: ' + communityPortalAccountIds);

        if (communityPortalAccountIds.isEmpty()) {
            System.debug('No Community/Portal accounts found - exiting execute.');
            return;
        }

        /* Find which communityPortal accounts still have an ACTIVE Sales Order
                   as PRIMARY Customer Account
        */  
        list<string> statusValues =new List<string>();
		if(activeStatusValues.contains(',')){
            system.debug('22---'+activeStatusValues);
            statusValues = activeStatusValues.split(',');
        }else{
            system.debug('26---'+activeStatusValues);
            if(!activeStatusValues.contains('null') ){
                statusValues =new List<String>{activeStatusValues};
        	}
        }    
        Set<Id> accountsToRetain = new Set<Id>();
        for (SalesOrder__c activeSO : [
            SELECT id,CustomerAccount__c,Old_Account__c,CustomerAccount__r.name,CustomerAccount__r.RecordType.name,Status__c,Unit__c,CustomerAccount__r.IsCustomerPortal,JO1__c,JO1__r.AccountId, JO1__r.Account.IsCustomerPortal,JO2__c,JO2__r.Account.IsCustomerPortal,JO2__r.AccountId, JO3__c,JO3__r.AccountId,JO3__r.Account.IsCustomerPortal,JO4__c,JO4__r.AccountId, JO4__r.Account.IsCustomerPortal,JO5__c,JO5__r.AccountId, JO5__r.Account.IsCustomerPortal,JO6__c,JO6__r.AccountId, JO6__r.Account.IsCustomerPortal
            FROM   SalesOrder__c
            WHERE  (CustomerAccount__c IN :communityPortalAccountIds OR JO1__r.AccountId IN :communityPortalAccountIds
                 OR JO2__r.AccountId IN :communityPortalAccountIds
                 OR JO3__r.AccountId IN :communityPortalAccountIds
                 OR JO4__r.AccountId IN :communityPortalAccountIds
                 OR JO5__r.AccountId IN :communityPortalAccountIds
                 OR JO6__r.AccountId IN :communityPortalAccountIds) 
            AND    Status__c NOT IN :statusValues
            
            AND    ProjectName__c NOT IN :excludedProjects
        ]) {
            for(Id idloop : communityPortalAccountIds){
                if(activeSO.CustomerAccount__c == idloop || activeSO.JO1__r.AccountId == idloop 
                  || activeSO.JO2__r.AccountId == idloop || activeSO.JO3__r.AccountId == idloop
                  || activeSO.JO4__r.AccountId == idloop || activeSO.JO5__r.AccountId == idloop
                  || activeSO.JO6__r.AccountId == idloop){
                    accountsToRetain.add(idloop);
                }
            }            
        }
        System.debug('AccouaccountsToRetain: ' + accountsToRetain);
		communityPortalAccountIds.removeAll(accountsToRetain); // safe removal after loop
		System.debug('Accounts with active PRIMARY SO (retain): ' + communityPortalAccountIds);
        // Find which communityPortal accounts still appear as an ACTIVE
        // Joint Owner on any Sales Order 
        if (!communityPortalAccountIds.isEmpty()) {
            deactivatePortalUsers(communityPortalAccountIds);
        }
    }

    /*
    // FINISH
    */
    global void finish(Database.BatchableContext bc) {
        System.debug('OffBoardingCustomer batch finished.');
        // Optional: Send completion notification / trigger downstream process
    }

    /*
    *PRIVATE HELPER – Deactivate the portal Users linked to the given
    *                  Account Ids (IsActive = false)
    */
    @TestVisible
    private void deactivatePortalUsers(Set<Id> accountIds) {
        // Fetch active portal users for the accounts to deactivate
        List<User> usersToDeactivate = [
            SELECT Id, Name, IsActive, AccountId, UserType
            FROM   User
            WHERE  AccountId IN :accountIds
            AND    IsActive   = true];

        if (usersToDeactivate.isEmpty()) {
            System.debug('No active portal users found for accounts: ' + accountIds);
            return;
        }

        List<User> updateList = new List<User>();
        for (User u : usersToDeactivate) {
            updateList.add(new User(
                Id       = u.Id,
                IsActive = false
            ));
            System.debug('Deactivating portal user: ' + u.Name + ' | AccountId: ' + u.AccountId);
        }

        try {
            update updateList;
            System.debug('Successfully deactivated ' + updateList.size() + ' portal user(s).');
        } catch (DmlException ex) {
            System.debug('ERROR deactivating portal users: ' + ex.getMessage());
            // Log to custom error object or platform event if needed
        }
    }
}