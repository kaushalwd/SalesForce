/**********************************************************************************************************************
* Name               : MBP_BrokerPermissionQueue
* Description        : This class is used as the Apex controller for Broker Portal agency and agent Permisson set Management.
* Usage              : LWC components related to Broker agency and agents
* Created By         : Upendra Reddy
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date             Comment
* 1.0         upendra.asam@modon.com        16 jun 2026      Initial Draft – Core logic for Broker Portal agency and agent Management.
* 1.1         Naman Mittal                  29 sep 2026      Active agency: a Pending Trade License Owner/Admin keeps the
*                                                              limited login (not full access) until Agent_Approval decides.
*                                                              
**********************************************************************************************************************/

public class MBP_BrokerPermissionQueue implements Queueable {
    
    private Set<Id> accountIds;
    
    public MBP_BrokerPermissionQueue(Set<Id> accountIds){
        this.accountIds = accountIds;
    }
    
    public void execute(QueueableContext context){
        
        List<PermissionSetAssignment> psaToDelete =
            new List<PermissionSetAssignment>();
        
        List<PermissionSetAssignment> psaToInsert =
            new List<PermissionSetAssignment>();
        
        List<User> usersToUpdate =
            new List<User>();
        
        Map<String, Id> permissionMap =
            new Map<String, Id>();
        
        for(PermissionSet ps : [
            
            SELECT Id, Name
            FROM PermissionSet
            WHERE Name IN (
                :BRConstants.MODON_LIMITED_LOGIN_ACCESS,
                :BRConstants.MODON_AGENT_ACCESS,
                :BRConstants.MODON_AGENCY_OWNER_ACCESS,
                :BRConstants.MODON_AGENCY_ADMIN_ACCESS
            )
            
        ]){
            permissionMap.put(ps.Name, ps.Id);
        }
        
        List<Contact> contacts = [
            
            SELECT Id,
            Broker_Type__c,
            Agent_Status__c,
            Account.Agency_Status__c
            FROM Contact
            WHERE AccountId IN :accountIds
            AND RecordTypeId = :BRConstants.BROKER_AGENT_RT
            
        ];
        
        Set<Id> contactIds =
            new Map<Id,Contact>(contacts).keySet();
        
        Map<Id,User> userMap = new Map<Id,User>();
        
        for(User usr : [
            
            SELECT Id,
            ContactId,
            IsActive
            FROM User
            WHERE ContactId IN :contactIds
            
        ]){
            userMap.put(
                usr.ContactId,
                usr
            );
        }
        
        Set<Id> userIds = new Set<Id>();
        
        for(User usr : userMap.values()){
            userIds.add(usr.Id);
        }
        
        
        for(PermissionSetAssignment psa : [
            
            SELECT Id,
            AssigneeId,
            PermissionSet.Name
            FROM PermissionSetAssignment
            WHERE AssigneeId IN :userIds
            AND PermissionSet.Name IN (
                :BRConstants.MODON_LIMITED_LOGIN_ACCESS,
                :BRConstants.MODON_AGENT_ACCESS,
                :BRConstants.MODON_AGENCY_OWNER_ACCESS,
                :BRConstants.MODON_AGENCY_ADMIN_ACCESS
            )
            
        ]){
            psaToDelete.add(psa);
        }
        
        if(!psaToDelete.isEmpty()){
            Database.delete(psaToDelete,false);
        }
        
        // v1.1: owners waiting for the trade licence on an Active agency are taken out and keep the limited login.
        List<Contact> awaitingLicence = MBP_BrokerAgencyLevelController.removeAwaitingTradeLicence(contacts);
        
        for(Contact con : contacts){
            
            User usr = userMap.get(con.Id);
            
            if(usr == null){
                continue;
            }
            
            String agencyStatus =
                con.Account.Agency_Status__c;
            
            String brokerType =
                con.Broker_Type__c;
            
            
            if(agencyStatus == 'Pending Verification'){
                
                if(
                    con.Agent_Status__c == 'Blocked' ||
                    con.Agent_Status__c == 'Suspended' ||
                    con.Agent_Status__c == 'Rejected' ||
                    con.Agent_Status__c == 'In Active'
                ){
                    
                    usr.IsActive = false;
                }
                else if(
                    brokerType == 'Owner' ||
                    brokerType == 'Agency Admin'
                ){
                    
                    usr.IsActive = true;
                    
                    if(
                        permissionMap.containsKey(
                            BRConstants.MODON_LIMITED_LOGIN_ACCESS
                        )
                    ){
                        psaToInsert.add(
                            new PermissionSetAssignment(
                                AssigneeId = usr.Id,
                                PermissionSetId =
                                permissionMap.get(
                                    BRConstants.MODON_LIMITED_LOGIN_ACCESS
                                )
                            )
                        );
                    }
                }
                else{
                    
                    usr.IsActive = false;
                }
                
                usersToUpdate.add(usr);
            }
            
            
            else if(
                agencyStatus == 'In Active'
            ){
                
                usr.IsActive = false;
                
                usersToUpdate.add(usr);
            }
            
            else if(
                agencyStatus == 'Active'
            ){
                
                
                if(
                    con.Agent_Status__c == 'Blocked' ||
                    con.Agent_Status__c == 'Suspended' ||
                    con.Agent_Status__c == 'Rejected' ||
                    con.Agent_Status__c == 'In Active'
                ){
                    
                    usr.IsActive = false;
                    usersToUpdate.add(usr);
                    continue;
                }
                
                usr.IsActive = true;
                
                usersToUpdate.add(usr);
                
                if(
                    brokerType == 'Owner'
                ){
                    
                    if(
                        permissionMap.containsKey(
                            BRConstants.MODON_AGENCY_OWNER_ACCESS
                        )
                    ){
                        psaToInsert.add(
                            new PermissionSetAssignment(
                                AssigneeId = usr.Id,
                                PermissionSetId =
                                permissionMap.get(
                                    BRConstants.MODON_AGENCY_OWNER_ACCESS
                                )
                            )
                        );
                    }
                }
                else if(
                    brokerType == 'Agency Admin'
                ){
                    
                    if(
                        permissionMap.containsKey(
                            BRConstants.MODON_AGENCY_ADMIN_ACCESS
                        )
                    ){
                        psaToInsert.add(
                            new PermissionSetAssignment(
                                AssigneeId = usr.Id,
                                PermissionSetId =
                                permissionMap.get(
                                    BRConstants.MODON_AGENCY_ADMIN_ACCESS
                                )
                            )
                        );
                    }
                }
                else{
                    
                    if(
                        permissionMap.containsKey(
                            BRConstants.MODON_AGENT_ACCESS
                        )
                    ){
                        psaToInsert.add(
                            new PermissionSetAssignment(
                                AssigneeId = usr.Id,
                                PermissionSetId =
                                permissionMap.get(
                                    BRConstants.MODON_AGENT_ACCESS
                                )
                            )
                        );
                    }
                }
            }
            
            
            else if(
                agencyStatus == 'Suspended'
            ){
                
                usr.IsActive = false;
                
                usersToUpdate.add(usr);
            }
            
            else if(
                agencyStatus == 'Rejected'
            ){
                
                usr.IsActive = false;
                
                usersToUpdate.add(usr);
            }
            
            
            else if(
                agencyStatus == 'Blocked'
            ){
                
                usr.IsActive = false;
                
                usersToUpdate.add(usr);
            }
        }
        
        psaToInsert.addAll(MBP_BrokerAgencyLevelController.keepLimitedLogin(awaitingLicence, userMap, usersToUpdate));
        
        if(!usersToUpdate.isEmpty()){
            update usersToUpdate;
        }
        
        if(!psaToInsert.isEmpty()){
            Database.insert(psaToInsert,false);
        }
    }
}