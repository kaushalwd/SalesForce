/**********************************************************************************************************************
* Name               : EgyptLeadEscalationService                                                        
* Description        : This class is used to set the round robin to sales team after lead qualified
* Created By         : Inamul Hasan                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Inamul Hasan                     12 June 2026     Initial Draft       
* 2.0           Inamul Hasan                     28 July 2026     Revamp the class now leads assign the team members. 
************************************************************************************************************************/
public without sharing class EgyptLeadEscalationService {
    
    private static final String BUSINESS_HOURS_NAME = 'Modon - Egypt';
    private static final String SOURCE_ENTITY = 'Modon - Egypt';

    private static final Set<String> LEAD_SOURCES = new Set<String>{
        'Social Media',
        'Webform - Egypt Website'
    };
    private static Id businessHoursId;
    
    @InvocableMethod(
        label='Egypt Lead Escalation Service'
        description='Handles assignment and escalation using business hours SLA'
        category='Lead'
    )
    public static void process(List<Lead> inputLeads) {

        if(inputLeads == null || inputLeads.isEmpty()) {
            return;
        }

        List<Lead> leadsToProcess = new List<Lead>();

        for(Lead ld : inputLeads) {

            if(ld.Source_Entity__c == SOURCE_ENTITY &&
               LEAD_SOURCES.contains(ld.LeadSource)) {

                leadsToProcess.add(ld);
            }
        }

        if(leadsToProcess.isEmpty()) {
            return;
        }

        Integer lastAssignmentNumber = getLastAssignmentNumber();

        Map<Id,List<Egypt_Round_Robin_Assignment_Matrix__c>> managerTeams =
            getManagerTeams();

        if(managerTeams.isEmpty()) {
            return;
        }
        
        Map<Id,Integer> managerCurrentIndex = loadRoundRobinState(managerTeams);

        List<Id> managers = new List<Id>();
        managers.addAll(managerTeams.keySet());
        managers.sort();

        Integer managerCount = managers.size();

        List<Lead> updateList = new List<Lead>();
        
        for(Lead ld : leadsToProcess) {
            
            if(ld.Egypt_Escalation_Stage__c == null) {
                
                lastAssignmentNumber++;
                
                assignInitialLead(
                    ld,
                    managerTeams,
                    managerCurrentIndex,
                    lastAssignmentNumber
                );
            }else{
                Boolean userWorked = false;
                
                if(!Test.isRunningTest() &&
                   ld.Egypt_Escalation_Last_Assigned_Time__c != null &&
                   ld.LastModifiedDate != null) {
                       
                       userWorked =
                           ld.LastModifiedDate.getTime() >
                           ld.Egypt_Escalation_Last_Assigned_Time__c.getTime() + 3000;
                   }
                
                
                if(!userWorked) {
                    // Second and third escalation
                    processEscalation(ld, managerTeams);
                }
            }
            updateList.add(ld);
        }
        
        updateRecords(updateList);
        saveRoundRobinState(managerTeams, managerCurrentIndex);
    }


    private static Integer getLastAssignmentNumber() {

        AggregateResult[] result = [
            SELECT MAX(Egypt_Assignment_Number__c) maxNumber
            FROM Lead
            WHERE Source_Entity__c = :SOURCE_ENTITY
            AND LeadSource IN ('Social Media','Webform - Egypt Website')
            WITH SYSTEM_MODE
        ];

        if(result.isEmpty() || result[0].get('maxNumber') == null) {
            return 0;
        }
        
        return ((Decimal)result[0].get('maxNumber')).intValue();
    }
    
    private static Map<Id,List<Egypt_Round_Robin_Assignment_Matrix__c>> getManagerTeams() {
        
        Map<Id,List<Egypt_Round_Robin_Assignment_Matrix__c>> managerTeams =
            new Map<Id,List<Egypt_Round_Robin_Assignment_Matrix__c>>();
        
        List<Egypt_Round_Robin_Assignment_Matrix__c> matrixList = [
            SELECT Id,
            User__c,
            User_Number__c,
            User_Manager__c,
            Current_Position__c
            FROM Egypt_Round_Robin_Assignment_Matrix__c
            WHERE Leave_Today__c = FALSE
            AND Is_CallCenter__c = FALSE
            AND User__r.IsActive = TRUE
            WITH SYSTEM_MODE
            ORDER BY User_Manager__c, User_Number__c
        ];
        
        for(Egypt_Round_Robin_Assignment_Matrix__c row : matrixList) {
            
            if(!managerTeams.containsKey(row.User_Manager__c)) {
                managerTeams.put(
                    row.User_Manager__c,
                    new List<Egypt_Round_Robin_Assignment_Matrix__c>()
                );
            }
            
            managerTeams.get(row.User_Manager__c).add(row);
        }
        
        return managerTeams;
    }
    
    private static Map<Id,Integer> loadRoundRobinState(
        Map<Id,List<Egypt_Round_Robin_Assignment_Matrix__c>> managerTeams
    ){
        
        Map<Id,Integer> managerCurrentIndex = new Map<Id,Integer>();
        
        for(Id managerId : managerTeams.keySet()){
            
            List<Egypt_Round_Robin_Assignment_Matrix__c> team =
                managerTeams.get(managerId);
            
            if(team.isEmpty()){
                continue;
            }
            
            Integer currentPosition = 0;
            
            if(team[0].Current_Position__c != null){
                currentPosition =
                    Integer.valueOf(team[0].Current_Position__c);
            }
            
            if(currentPosition >= team.size()){
                currentPosition = 0;
            }
            
            managerCurrentIndex.put(managerId,currentPosition);
        }
        
        return managerCurrentIndex;
    }
    
    private static void saveRoundRobinState(
        Map<Id,List<Egypt_Round_Robin_Assignment_Matrix__c>> managerTeams,
        Map<Id,Integer> managerCurrentIndex
    ){
        
        List<Egypt_Round_Robin_Assignment_Matrix__c> updates =
            new List<Egypt_Round_Robin_Assignment_Matrix__c>();
        
        for(Id managerId : managerCurrentIndex.keySet()){
            
            List<Egypt_Round_Robin_Assignment_Matrix__c> team =
                managerTeams.get(managerId);
            
            if(team.isEmpty()){
                continue;
            }
            
            updates.add(
                new Egypt_Round_Robin_Assignment_Matrix__c(
                    Id = team[0].Id,
                    Current_Position__c = managerCurrentIndex.get(managerId)
                )
            );
        }
        
        if(!updates.isEmpty()){
            Database.update(updates, AccessLevel.SYSTEM_MODE);
        }
    }
    
    private static void assignInitialLead(
        Lead ld,
        Map<Id,List<Egypt_Round_Robin_Assignment_Matrix__c>> managerTeams,
        Map<Id,Integer> managerCurrentIndex,
        Integer assignmentNumber
    ){
        
        List<Id> managers = new List<Id>();
        managers.addAll(managerTeams.keySet());
        managers.sort();
        
        Integer managerCount = managers.size();
        
        Integer managerIndex = Math.mod(
            assignmentNumber - 1,
            managerCount
        );
        
        Id managerId = managers[managerIndex];
        
        List<Egypt_Round_Robin_Assignment_Matrix__c> team =
            managerTeams.get(managerId);
        
        if(team == null || team.isEmpty()){
            return;
        }
        
        Integer currentPosition = 0;
        
        if(managerCurrentIndex.containsKey(managerId)){
            currentPosition = managerCurrentIndex.get(managerId);
        }
        
        if(currentPosition >= team.size()){
            currentPosition = 0;
        }
        
        Egypt_Round_Robin_Assignment_Matrix__c selectedUser =
            team[currentPosition];
        
        ld.OwnerId = selectedUser.User__c;
        ld.Egypt_Assignment_Number__c = assignmentNumber;
        
        ld.Egypt_Escalation_Stage__c = 'First Escalation';
        ld.Egypt_Escalation_Last_Assigned_Time__c = System.now();
        
        setEscalationDates(ld);
        
        // Advance the pointer for this manager
        currentPosition++;
        
        if(currentPosition >= team.size()){
            currentPosition = 0;
        }
        
        managerCurrentIndex.put(managerId, currentPosition);
    }
    
    
    private static void processEscalation(
        Lead ld,
        Map<Id,List<Egypt_Round_Robin_Assignment_Matrix__c>> managerTeams
    ){
        
        Map<Id,Id> userManagerMap = new Map<Id,Id>();
        
        for(Id managerId : managerTeams.keySet()) {
            
            for(Egypt_Round_Robin_Assignment_Matrix__c row :
                managerTeams.get(managerId)) {
                    userManagerMap.put(row.User__c, managerId);
                }
        }
        
        
        Id managerId = userManagerMap.get(ld.OwnerId);
        
        if(managerId == null) {
            return;
        }
        
        
        List<Egypt_Round_Robin_Assignment_Matrix__c> team =
            managerTeams.get(managerId);
        
        Integer currentIndex = -1;
        
        for(Integer i = 0; i < team.size(); i++) {
            
            if(team[i].User__c == ld.OwnerId) {
                
                currentIndex = i;
                break;
            }
        }
        
        
        if(currentIndex == -1) {
            return;
        }
        
        
        if(ld.Egypt_Escalation_Stage__c == 'Third Escalation') {
            
            ld.Egypt_Escalation_Stage__c = 'Flagged';
            
        }
        else {
            
           /* Integer nextIndex = currentIndex + 1;
            
            
            if(nextIndex >= team.size()) {
                
                ld.Egypt_Escalation_Stage__c = 'Flagged';
                
            }
            else {*/
            Integer nextIndex = Math.mod(
                currentIndex + 1,
                team.size()
            );
            
            ld.OwnerId = team[nextIndex].User__c;
            
            ld.Egypt_Escalation_Last_Assigned_Time__c = System.now();
            
            
            if(ld.Egypt_Escalation_Stage__c == 'First Escalation') {
                
                ld.Egypt_Escalation_Stage__c = 'Second Escalation';
                
            }
            else if(ld.Egypt_Escalation_Stage__c == 'Second Escalation') {
                
                ld.Egypt_Escalation_Stage__c = 'Third Escalation';
            }
        }
    }
    
    private static void setEscalationDates(Lead ld) {
        
        // First Escalation - 2 Hours
        ld.Egypt_First_Escalation_Date_Time__c =
            addBusinessMinutes(120);
        
        // Second Escalation - 3 Hours from initial assignment
        ld.Egypt_Second_Escalation_Date_Time__c =
            addBusinessMinutes(180);
        
        // Third Escalation - 3 Hours 30 Minutes from initial assignment
        ld.Egypt_Third_Escalation_Date_Time__c =
            addBusinessMinutes(210);
    }
    
    
    private static Id getBusinessHoursId() {
        
        if(businessHoursId == null) {
            
            businessHoursId = [
                SELECT Id
                FROM BusinessHours
                WHERE Name = :BUSINESS_HOURS_NAME
                WITH SYSTEM_MODE
                LIMIT 1
            ].Id;
            
        }
        
        return businessHoursId;
    }

    private static Datetime addBusinessMinutes(Integer minutes) {
        
        return BusinessHours.add(
            getBusinessHoursId(),
            System.now(),
            minutes * 60 * 1000
        );
        
    }


    private static void updateRecords(List<Lead> leads) {

        if(leads.isEmpty()) {
            return;
        }
        
        List<Lead> updateList = new List<Lead>();
        
        for(Lead ld : leads){
            
            updateList.add(
                new Lead(
                    Id = ld.Id,
                    OwnerId = ld.OwnerId,
                    Egypt_Assignment_Number__c = ld.Egypt_Assignment_Number__c,
                    Egypt_Escalation_Stage__c = ld.Egypt_Escalation_Stage__c,
                    Egypt_Escalation_Last_Assigned_Time__c = ld.Egypt_Escalation_Last_Assigned_Time__c,
                    Egypt_First_Escalation_Date_Time__c = ld.Egypt_First_Escalation_Date_Time__c,
                    Egypt_Second_Escalation_Date_Time__c = ld.Egypt_Second_Escalation_Date_Time__c,
                    Egypt_Third_Escalation_Date_Time__c = ld.Egypt_Third_Escalation_Date_Time__c
                )
            );
        }

        Database.SaveResult[] results =
            Database.update(updateList,AccessLevel.SYSTEM_MODE);

        for(Database.SaveResult sr : results) {

            if(!sr.isSuccess()) {

                for(Database.Error err : sr.getErrors()) {

                    System.debug(
                        'Lead Update Error: ' + err.getMessage()
                    );
                }
            }
        }
    }
}