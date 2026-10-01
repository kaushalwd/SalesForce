/**********************************************************************************************************************
* Name               : Mbp_BrokerUserFreezeQueue
* Description        : This class is used as the Apex controller for inactive and Block and Unblock Users for Broker.
* Usage              : LWC components related to Broker agency and agents
* Created By         : Upendra Reddy
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date             Comment
* 1.0         upendra.asam@modon.com        16 jun 2026      This Class is for Active and inactive and Block and Unblock Users for Broker
* 1.1         Naman Mittal                  29 sep 2026      Pending Trade License Owner/Admin is treated like Pending
*                                                              Verification: active user with Modon_Limited_Login_Access.
*   
**********************************************************************************************************************/

public class Mbp_BrokerUserFreezeQueue implements Queueable {

    private Set<Id> accountIds;
    private Set<Id> contactIds;

    public Mbp_BrokerUserFreezeQueue(
        Set<Id> accIds,
        Set<Id> conIds
    ){
        this.accountIds = accIds;
        this.contactIds = conIds;
    }

    // v1.1: an owner waiting for the trade licence keeps the same limited login as Pending Verification.
    private static Boolean isAwaitingVerification(String agentStatus){
        return agentStatus == 'Pending Verification'
            || agentStatus == MBP_BrokerAgencyLevelController.STATUS_PENDING_TRADE_LICENSE;
    }

    public void execute(QueueableContext context){

        Set<Id> finalContactIds = new Set<Id>();

        if(accountIds != null && !accountIds.isEmpty()){

            for(Contact con : [
                SELECT Id
                FROM Contact
                WHERE AccountId IN :accountIds
            ]){
                finalContactIds.add(con.Id);
            }
        }

        if(contactIds != null){
            finalContactIds.addAll(contactIds);
        }

        if(finalContactIds.isEmpty()){
            return;
        }

        Map<Id,Contact> contactMap = new Map<Id,Contact>([
            SELECT Id,
                   Agent_Status__c,
                   Broker_Type__c
            FROM Contact
            WHERE Id IN :finalContactIds
        ]);

        List<User> usersToUpdate = new List<User>();
        Map<Id,Id> userToContactMap = new Map<Id,Id>();

        List<User> userList = [
            SELECT Id,
                   ContactId,
                   IsActive
            FROM User
            WHERE ContactId IN :finalContactIds
        ];

        Set<Id> userIds = new Set<Id>();

        for(User usr : userList){

            userIds.add(usr.Id);



            Contact con = contactMap.get(usr.ContactId);


            if(con == null){
                continue;
            }

            Boolean shouldActivate = false;

            if(con.Agent_Status__c == 'Active'){
                shouldActivate = true;
            }
            else if(
                isAwaitingVerification(con.Agent_Status__c) &&
                (
                    con.Broker_Type__c == 'Owner' ||
                    con.Broker_Type__c == 'Agency Admin'
                )
            ){
                shouldActivate = true;
            }

            if(usr.IsActive != shouldActivate){

                usersToUpdate.add(
                    new User(
                        Id = usr.Id,
                        IsActive = shouldActivate
                    )
                );
            }





            userToContactMap.put(
                usr.Id,
                usr.ContactId
            );
        }

        if(!usersToUpdate.isEmpty()){
            update usersToUpdate;
        }

        /*
         * Freeze / Unfreeze
         */

        List<UserLogin> loginsToUpdate = new List<UserLogin>();

        for(UserLogin ul : [

            SELECT Id,
                   UserId,
                   IsFrozen
            FROM UserLogin
            WHERE UserId IN :userIds

        ]){




            Contact con =
                contactMap.get(
                    userToContactMap.get(ul.UserId)
                );

            Boolean shouldFreeze =
                con.Agent_Status__c == 'Blocked';

            if(ul.IsFrozen != shouldFreeze){

                ul.IsFrozen = shouldFreeze;
                loginsToUpdate.add(ul);
            }
        }

        if(!loginsToUpdate.isEmpty()){
            update loginsToUpdate;
        }

        /*
         * Permission Set Handling
         */

        Set<String> modonPermissionSets = new Set<String>{
            BRConstants.MODON_LIMITED_LOGIN_ACCESS,
            BRConstants.MODON_AGENT_ACCESS,
            BRConstants.MODON_AGENCY_OWNER_ACCESS,
            BRConstants.MODON_AGENCY_ADMIN_ACCESS
        };

        Map<String,Id> permissionSetMap = new Map<String,Id>();

        for(PermissionSet ps : [
            SELECT Id, Name
            FROM PermissionSet
            WHERE Name IN :modonPermissionSets
        ]){
            permissionSetMap.put(ps.Name, ps.Id);
        }

        List<PermissionSetAssignment> psaToDelete =
            new List<PermissionSetAssignment>();

        for(PermissionSetAssignment psa : [

            SELECT Id,
                   AssigneeId,
                   PermissionSet.Name
            FROM PermissionSetAssignment
            WHERE AssigneeId IN :userIds
            AND PermissionSet.Name IN :modonPermissionSets

        ]){
            psaToDelete.add(psa);
        }

        if(!psaToDelete.isEmpty()){
            delete psaToDelete;
        }

        List<PermissionSetAssignment> psaToInsert =
            new List<PermissionSetAssignment>();

        for(User usr : userList){

            Contact con =
                contactMap.get(usr.ContactId);

            String permissionSetName;

            if(con.Agent_Status__c == 'Active'){

                if(con.Broker_Type__c == 'Owner'){
                    permissionSetName =
                        BRConstants.MODON_AGENCY_OWNER_ACCESS;
                }
                else if(con.Broker_Type__c == 'Agency Admin'){
                    permissionSetName =
                        BRConstants.MODON_AGENCY_ADMIN_ACCESS;
                }
                else if(con.Broker_Type__c == 'Agent'){
                    permissionSetName =
                        BRConstants.MODON_AGENT_ACCESS;
                }
            }
            else if(
                isAwaitingVerification(con.Agent_Status__c) &&
                (
                    con.Broker_Type__c == 'Owner' ||
                    con.Broker_Type__c == 'Agency Admin'
                )
            ){
                permissionSetName =
                    BRConstants.MODON_LIMITED_LOGIN_ACCESS;
            }

            if(
                String.isNotBlank(permissionSetName) &&
                permissionSetMap.containsKey(permissionSetName)
            ){
                psaToInsert.add(
                    new PermissionSetAssignment(
                        AssigneeId = usr.Id,
                        PermissionSetId =
                            permissionSetMap.get(
                                permissionSetName
                            )
                    )
                );
            }
        }

        if(!psaToInsert.isEmpty()){
            insert psaToInsert;
        }
    }
}