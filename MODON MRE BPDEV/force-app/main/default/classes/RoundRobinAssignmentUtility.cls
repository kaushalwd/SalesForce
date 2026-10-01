/**********************************************************************************************************************
* Name               : RoundRobinAssignmentUtility                                                        
* Description        : This class is used as to provide all helper methods for round Robin Assignment
* Usage              : Lead Trigger                                                          
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                  Date            Comment                                                                       
* 1.0           Anil Valluri            21 Dec 2023     Initial Draft       
******************************************************************************************************************/
public without sharing class RoundRobinAssignmentUtility {
    
    /* 
* Method will return lead to agent map 
*  (DML on RoundRobinAssignmentMatrix__c update current LoadCount+ LastAssignmentTime)
*/
    public static map<Id,Id> getAvailableAgent(set<id> leadIds, string userType){
        map<Id,Id> leadToOwnerMap = new map<Id,Id>();
        map<string,RoundRobinAssignmentMatrix__c> userToAssignmentRecord = new map<string,RoundRobinAssignmentMatrix__c>();
        //get map of users sorted by LastAssignmentTime__c asc, createdDate asc
        //Lead_Type__c Added by Arvind
        for(RoundRobinAssignmentMatrix__c tempAssignmentRecord : [select Id, User__r.Name,User__c, Status__c, Threshold__c, CurrentLoad__c, Language__c, LeadSource__c, UserType__c 
                                                                  from RoundRobinAssignmentMatrix__c where User__r.isActive=true and 
                                                                  UserType__c =: userType and 
                                                                  Status__c= :Constants.STATUS_AVAILABLE order by LastAssignmentTime__c asc, User__c]){
                                                                      //if(tempAssignmentRecord.CurrentLoad__c < tempAssignmentRecord.Threshold__c){
                                                                      if(tempAssignmentRecord.LeadSource__c !=null ){
                                                                          userToAssignmentRecord.put(tempAssignmentRecord.User__c + '|' + tempAssignmentRecord.LeadSource__c,tempAssignmentRecord);
                                                                      }else{
                                                                          userToAssignmentRecord.put(tempAssignmentRecord.User__c ,tempAssignmentRecord);
                                                                      }
                                                                      
                                                                      
                                                                      //}
                                                                  }
        
        system.debug('userToAssignmentRecord::::' + userToAssignmentRecord);
        system.debug('RoundRobinAssignment  ::::  leadIds >>  ' + leadIds);
        map<id,integer> totalLoacalAssigenments = new map<id,integer>();
        //For every lead
        for(Lead tempLeadRec : [select id, OwnerId, LanguagePreference__c, LeadSource
                                from lead where id in :leadIds]){
                                    system.debug('tempLeadRec::'+tempLeadRec);
                                    Integer userPoint = -1;
                                    set<ID> possibleUserSet = new set<ID>();
                                    for(string tempUserId_LeadSource : userToAssignmentRecord.keySet() ){
                                        Integer tempUserPoints = 0;
                                        RoundRobinAssignmentMatrix__c tempAssignmentRecord = userToAssignmentRecord.get(tempUserId_LeadSource);
                                        
                                        //Assign only if agent have capacity and Agent is not previous owner
                                        if(tempAssignmentRecord.CurrentLoad__c < tempAssignmentRecord.Threshold__c && tempLeadRec.OwnerId!=tempAssignmentRecord.User__c){
                                            //Check Matching Field calculate pointers
                                            //If field is blank that means Sales Executive is able to handle all the requests
                                            
                                            if(tempAssignmentRecord.Language__c==null || ( tempLeadRec.LanguagePreference__c!=null && tempAssignmentRecord.Language__c.contains(tempLeadRec.LanguagePreference__c) ) ){
                                                tempUserPoints++;
                                            }
                                            if( tempLeadRec.LeadSource!=null && tempAssignmentRecord.LeadSource__c == tempLeadRec.LeadSource ){
                                                tempUserPoints++;
                                            }else if(tempLeadRec.LeadSource==null && tempAssignmentRecord.LeadSource__c == null){
                                                tempUserPoints++;
                                            }
                                            
                                            system.debug('tempAssignmentRecord::'+tempAssignmentRecord.User__r.Name + '----'+  tempAssignmentRecord.LeadSource__c + userPoint + 'userPoint::'+tempUserPoints);
                                            //If higherpointer add create new list
                                            if(userPoint < tempUserPoints ){
                                                userPoint = tempUserPoints;
                                                possibleUserSet = new set<ID>{ tempAssignmentRecord.User__c };
                                                    system.debug('possible111::'+tempAssignmentRecord.User__r.Name);
                                            }else if(userPoint == tempUserPoints){
                                                //If same then keep add to list
                                                possibleUserSet.add(tempAssignmentRecord.User__c);
                                                system.debug('possible222::'+tempAssignmentRecord.User__r.Name);
                                            }
                                            
                                        }
                                    }
                                    system.debug('possibleUserSet::'+possibleUserSet);
                                    if(!possibleUserSet.isEmpty()){
                                        ID userId = null;
                                        //Dummy val for getting agent with lower amount of work
                                        integer currentWork = 1000;
                                        for(Id tempUserId : possibleUserSet){
                                            if(!totalLoacalAssigenments.containskey(tempUserId)){
                                                totalLoacalAssigenments.put(tempUserId,0);
                                                userId = tempUserId;
                                                break;
                                            }else{
                                                if( currentWork > totalLoacalAssigenments.get(tempUserId)){
                                                    userId = tempUserId;
                                                    currentWork=totalLoacalAssigenments.get(tempUserId);
                                                }
                                            }
                                        }
                                        system.debug('userId::'+userId);
                                        //Once finalized update the CurrentLoad__c and totalLoacalAssigenments to continue RR
                                        System.debug('totalLoacalAssigenments >>>>  '+System.JSON.serialize(totalLoacalAssigenments));
                                        totalLoacalAssigenments.put(userId,totalLoacalAssigenments.get(userId) + 1);
                                        System.debug('userToAssignmentRecord >>>>  '+System.JSON.serialize(userToAssignmentRecord));
                                        if(userToAssignmentRecord.containsKey(userId + '|' + tempLeadRec.LeadSource)){
                                            userToAssignmentRecord.get(userId + '|' + tempLeadRec.LeadSource).CurrentLoad__c = (userToAssignmentRecord.get(userId + '|' + tempLeadRec.LeadSource).CurrentLoad__c ==null ? 0 : userToAssignmentRecord.get(userId + '|' + tempLeadRec.LeadSource).CurrentLoad__c )  + 1;
                                            userToAssignmentRecord.get(userId + '|' + tempLeadRec.LeadSource).LastAssignmentTime__c = system.now();
                                        }else{
                                            if(UserInfo.getUserId() != System.Label.bypassWebinar && userToAssignmentRecord.containsKey(userId)){
                                                 userToAssignmentRecord.get(userId).CurrentLoad__c = (userToAssignmentRecord.get(userId).CurrentLoad__c ==null ? 0 : 1)  + 1;
                                           		 userToAssignmentRecord.get(userId).LastAssignmentTime__c = system.now();
                                            }
                                            
                                        }
                                        
                                        leadToOwnerMap.put(tempLeadRec.Id,userId);
                                    }
                                }
        system.debug('totalLoacalAssigenments::'+totalLoacalAssigenments);
        system.debug('leadToOwnerMap::'+leadToOwnerMap);
        system.debug('userToAssignmentRecord::'+userToAssignmentRecord);
        //update the last assignment time
        if(!leadToOwnerMap.isEmpty()){  
            update userToAssignmentRecord.values();
        }
        return leadToOwnerMap;
    }
    
    
    
    /*
* updateRRLoadCounter this method will count the current load for the given owners and update it
*/
    /*
public static void updateRRLoadCounter(map<string,RoundRobinAssignmentMatrix__c> RRRecords){
for(RoundRobinAssignmentMatrix__c tempAssignmentRecord : RRRecords.values()){
tempAssignmentRecord.CurrentLoad__c=0;
}
for(Lead tempLeadRecord : [select Id, OwnerId, Status from Lead where ownerId in : RRRecords.KeySet() and Status !=: Constants.LEAD_STATUS_RETIRED]){
RRRecords.get(tempLeadRecord.ownerID).CurrentLoad__c++;
}
}*/
    
    public static map<Id,Id> getAvailableAgent(set<id> inputIds, string userType,map<Id,Id> ownerIdsMap,Boolean isTask) {
        map<Id,Id> leadToOwnerMap = new map<Id,Id>();
        map<string,RoundRobinAssignmentMatrix__c> userToAssignmentRecord = new map<string,RoundRobinAssignmentMatrix__c>();
        
        // Query to fetch the assignment records for users based on userType
        for(RoundRobinAssignmentMatrix__c tempAssignmentRecord : [
            select Id, User__r.Name, User__c, Status__c, Threshold__c, CurrentLoad__c, Language__c, LeadSource__c, UserType__c 
            from RoundRobinAssignmentMatrix__c 
            where User__r.isActive=true and 
            UserType__c =: userType and 
            Status__c= :Constants.STATUS_AVAILABLE 
            order by LastAssignmentTime__c asc, User__c
        ]) {
            if(tempAssignmentRecord.LeadSource__c != null) {
                userToAssignmentRecord.put(tempAssignmentRecord.User__c + '|' + tempAssignmentRecord.LeadSource__c, tempAssignmentRecord);
            } else {
                userToAssignmentRecord.put(tempAssignmentRecord.User__c , tempAssignmentRecord);
            }
        }
        
        system.debug('userToAssignmentRecord::::' + userToAssignmentRecord);
        system.debug('RoundRobinAssignment  ::::  inputIds >>  ' + inputIds);
        
        map<id, integer> totalLocalAssignments = new map<id, integer>();
        
        // Handle both Lead and Opportunity Ids
        List<SObject> recordsToProcess = new List<SObject>();
        if (inputIds.size() > 0) {
            // Determine if input IDs are Lead or Opportunity
            if (inputIds.iterator().next().getSObjectType() == Lead.SObjectType) {
                // Fetch leads
                recordsToProcess = [SELECT Id, OwnerId, LanguagePreference__c, LeadSource FROM Lead WHERE Id IN :inputIds];
            } else if (inputIds.iterator().next().getSObjectType() == Opportunity.SObjectType) {
                // Fetch opportunities
                recordsToProcess = [SELECT Id, OwnerId, LanguagePreference__c, LeadSource FROM Opportunity WHERE Id IN :inputIds];
            }
        }
        
        // For every record (Lead or Opportunity)
        for (SObject tempRecord : recordsToProcess) {
            system.debug('tempRecord::' + tempRecord);
            Integer userPoint = -1;
            set<ID> possibleUserSet = new set<ID>();
            
            // Process each user assignment record
            for (string tempUserId_LeadSource : userToAssignmentRecord.keySet()) {
                Integer tempUserPoints = 0;
                RoundRobinAssignmentMatrix__c tempAssignmentRecord = userToAssignmentRecord.get(tempUserId_LeadSource);
                
                // Assign only if agent has capacity and agent is not previous owner
                if (tempAssignmentRecord.CurrentLoad__c < tempAssignmentRecord.Threshold__c && 
                    tempRecord.get('OwnerId') != tempAssignmentRecord.User__c && 
                    (!isTask || (isTask && ownerIdsMap.containsKey(tempRecord.Id) && tempAssignmentRecord.User__c != ownerIdsMap.get(tempRecord.Id))) ){
                    // Check matching fields and calculate points
                    if (tempAssignmentRecord.Language__c == null || (tempRecord.get('LanguagePreference__c') != null && tempAssignmentRecord.Language__c.contains((string)tempRecord.get('LanguagePreference__c')))) {
                        tempUserPoints++;
                    }
                    
                    if (tempRecord.get('LeadSource') != null && tempAssignmentRecord.LeadSource__c == tempRecord.get('LeadSource')) {
                        tempUserPoints++;
                    } else if (tempRecord.get('LeadSource') == null && tempAssignmentRecord.LeadSource__c == null) {
                        tempUserPoints++;
                    }
                    
                    system.debug('tempAssignmentRecord::' + tempAssignmentRecord.User__r.Name + '----' + tempAssignmentRecord.LeadSource__c + userPoint + 'userPoint::' + tempUserPoints);
                    
                    // If higher points, add the user to possible set
                    if (userPoint < tempUserPoints) {
                        userPoint = tempUserPoints;
                        possibleUserSet = new set<ID>{ tempAssignmentRecord.User__c };
                            system.debug('possible111::' + tempAssignmentRecord.User__r.Name);
                    } else if (userPoint == tempUserPoints) {
                        possibleUserSet.add(tempAssignmentRecord.User__c);
                        system.debug('possible222::' + tempAssignmentRecord.User__r.Name);
                    }
                }
            }
            
            system.debug('possibleUserSet::' + possibleUserSet);
            if (!possibleUserSet.isEmpty()) {
                ID userId = null;
                integer currentWork = 1000;
                
                // Choose the agent with the least current work
                for (Id tempUserId : possibleUserSet) {
                    if (!totalLocalAssignments.containsKey(tempUserId)) {
                        totalLocalAssignments.put(tempUserId, 0);
                        userId = tempUserId;
                        break;
                    } else {
                        if (currentWork > totalLocalAssignments.get(tempUserId)) {
                            userId = tempUserId;
                            currentWork = totalLocalAssignments.get(tempUserId);
                        }
                    }
                }
                
                system.debug('userId::' + userId);
                system.debug('LeadSource::' + tempRecord.get('LeadSource'));
                
                // Update the agent's load and assignment time
                totalLocalAssignments.put(userId, totalLocalAssignments.get(userId) + 1);
                
                if (userToAssignmentRecord.containsKey(userId + '|' + tempRecord.get('LeadSource'))) {
                    userToAssignmentRecord.get(userId + '|' + tempRecord.get('LeadSource')).CurrentLoad__c = 
                        (userToAssignmentRecord.get(userId + '|' + tempRecord.get('LeadSource')).CurrentLoad__c == null ? 0 : userToAssignmentRecord.get(userId + '|' + tempRecord.get('LeadSource')).CurrentLoad__c) + 1;
                    userToAssignmentRecord.get(userId + '|' + tempRecord.get('LeadSource')).LastAssignmentTime__c = system.now();
                } else {
                    System.debug('Inside the Round Robin Assignment Utility else condition where the flow is failing');
                    System.debug(userToAssignmentRecord.get(userId));
                    userToAssignmentRecord.get(userId).CurrentLoad__c = 
                        (userToAssignmentRecord.get(userId).CurrentLoad__c == null ? 0 : userToAssignmentRecord.get(userId).CurrentLoad__c) + 1;
                    userToAssignmentRecord.get(userId).LastAssignmentTime__c = system.now();
                }
                
                leadToOwnerMap.put(tempRecord.Id, userId);
            }
        }
        
        system.debug('totalLocalAssignments::' + totalLocalAssignments);
        system.debug('leadToOwnerMap::' + leadToOwnerMap);
        system.debug('userToAssignmentRecord::' + userToAssignmentRecord);
        
        // Update the assignment records in bulk
        if (!leadToOwnerMap.isEmpty()) {
            update userToAssignmentRecord.values();
        }
        
        return leadToOwnerMap;
    }
    
    
    
    
}