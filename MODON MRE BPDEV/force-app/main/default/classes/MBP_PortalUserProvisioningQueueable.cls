/**
 * Creates Broker Portal users for contacts.
 * Default (Agent_Approval approved): Partner Community licence and Modon_Agency_Owner_Access.
 * v1.1 (29 Sep 2026): limited mode for owners waiting for the agency's trade licence: Partner Community
 * Login licence and Modon_Limited_Login_Access, as registration gives limited users. Mbp_BrokerUserFreezeQueue
 * swaps the permission set when Agent_Approval makes the owner Active.
 */
public class MBP_PortalUserProvisioningQueueable implements Queueable {

        private static final String FULL_ACCESS_PROFILE = 'Modon - Partner Community User';

        private Set<Id> contactIds;
        private Boolean isLimitedLogin = false;

        public MBP_PortalUserProvisioningQueueable(Set<Id> contactIds){
            this.contactIds = contactIds;
        }

        /**
         * A job that creates limited users: Login licence and Modon_Limited_Login_Access.
         * @param contactIds contacts to create users for
         * @return the job, ready for System.enqueueJob
         */
        public static MBP_PortalUserProvisioningQueueable forLimitedLogin(Set<Id> contactIds){
            MBP_PortalUserProvisioningQueueable job = new MBP_PortalUserProvisioningQueueable(contactIds);
            job.isLimitedLogin = true;
            return job;
        }

        public void execute(QueueableContext ctx){

            System.debug('[MBP_PortalUserProvisioningQueueable] execute() start. contactIds=' + contactIds);

            try {
                List<Contact> contactListCurrent = [
                    SELECT Id, AccountId, FirstName, LastName, MiddleName, Email,
                           broker_type__c, Primary_Owner__c
                    FROM Contact
                    WHERE Id IN :contactIds
                ];

                System.debug('[MBP_PortalUserProvisioningQueueable] contactListCurrent size=' + contactListCurrent.size());

                if(contactListCurrent.isEmpty()){
                    System.debug('[MBP_PortalUserProvisioningQueueable] EXIT - no contacts found for given Ids');
                    return;
                }

                String profileName = isLimitedLogin ? BRConstants.MODON_PARTNER_COMMUNITY_PROFILE : FULL_ACCESS_PROFILE;
                List<Profile> profileIdList = [SELECT Id FROM Profile WHERE Name = :profileName];
                System.debug('[MBP_PortalUserProvisioningQueueable] profileIdList size=' + profileIdList.size());

                Id profileId = profileIdList[0].Id;

                Organization currOrg = [SELECT IsSandbox FROM Organization LIMIT 1];
                System.Domain d = System.DomainParser.parse(URL.getOrgDomainUrl());

                List<User> lstUsersToCreate = new List<User>();
                for(Contact con : contactListCurrent){
                    User usr = new User();
                    usr.Alias = con.Email.substring(0, 6).toLowerCase();
                    usr.Email = con.Email;
                    usr.EmailEncodingKey = 'UTF-8';
                    usr.MiddleName = con.MiddleName;
                    usr.LastName = con.LastName;
                    usr.Firstname = con.FirstName;
                    usr.LanguageLocaleKey = 'en_US';
                    usr.LocaleSidKey = 'en_GB';
                    usr.ProfileId = profileId;
                    usr.TimeZoneSidKey = 'Asia/Dubai';
                    usr.isActive = true;
                    usr.UserName = currOrg.IsSandbox ? con.Email + '.' + d.getSandboxName() : con.Email;
                    usr.ContactId = con.Id;

                    Database.DMLOptions dlo = new Database.DMLOptions();
                    dlo.EmailHeader.triggerUserEmail = true;
                    dlo.EmailHeader.triggerAutoResponseEmail = true;
                    usr.setOptions(dlo);

                    lstUsersToCreate.add(usr);
                }

                List<Database.SaveResult> insertUsersResult = Database.insert(lstUsersToCreate, false);

                Map<String, String> contactIdsFailed_Reason = new Map<String, String>();
                Set<Id> createdUserIds = new Set<Id>();

                for(Integer i = 0; i < insertUsersResult.size(); i++){
                    if(insertUsersResult.get(i).isSuccess()){
                        Id newUserId = insertUsersResult.get(i).getId();
                        createdUserIds.add(newUserId);
                        System.debug('[MBP_PortalUserProvisioningQueueable] User CREATED successfully. UserId=' + newUserId + ' for ContactId=' + lstUsersToCreate.get(i).ContactId);
                    } else {
                        Database.Error error = insertUsersResult.get(i).getErrors().get(0);
                        contactIdsFailed_Reason.put(lstUsersToCreate.get(i).ContactId, error.getMessage());
                        System.debug('[MBP_PortalUserProvisioningQueueable] User creation FAILED for ContactId=' + lstUsersToCreate.get(i).ContactId + ' reason=' + error.getMessage());
                    }
                }

                if(!contactIdsFailed_Reason.isEmpty()){
                    List<Contact> lstContactsFailed = [
                        SELECT Id, PortalUserAutoCreationFailed__c, PortalUserAutoCreationFailedReason__c
                        FROM Contact
                        WHERE Id IN :contactIdsFailed_Reason.keySet()
                    ];
                    List<Contact> lst_Contacts_toUpdate = new List<Contact>();
                    for(Contact con : lstContactsFailed){
                        Contact con_to_Update = new Contact(Id = con.Id);
                        con_to_Update.PortalUserAutoCreationFailed__c = true;
                        con_to_Update.PortalUserAutoCreationFailedReason__c = contactIdsFailed_Reason.get(con.Id);
                        lst_Contacts_toUpdate.add(con_to_Update);
                    }
                    if(!lst_Contacts_toUpdate.isEmpty()){
                        update lst_Contacts_toUpdate;
                    }
                }

                // Permission set assignment — every successfully created User,
                // regardless of Primary_Owner__c.
                System.debug('[MBP_PortalUserProvisioningQueueable] createdUserIds=' + createdUserIds);

                if(!createdUserIds.isEmpty()){
                    String permissionSetName = isLimitedLogin
                        ? BRConstants.MODON_LIMITED_LOGIN_ACCESS
                        : BRConstants.MODON_AGENCY_OWNER_ACCESS;
                    List<PermissionSet> psList = [
                        SELECT Id, Name FROM PermissionSet
                        WHERE Name = :permissionSetName
                        LIMIT 1
                    ];

                    System.debug('[MBP_PortalUserProvisioningQueueable] Looking for PermissionSet Name=' + permissionSetName + ' found=' + psList.size());

                    if(!psList.isEmpty()){
                        List<PermissionSetAssignment> psaList = new List<PermissionSetAssignment>();
                        for(Id uId : createdUserIds){
                            psaList.add(new PermissionSetAssignment(PermissionSetId = psList[0].Id, AssigneeId = uId));
                        }
                        insert psaList;
                        System.debug('[MBP_PortalUserProvisioningQueueable] PermissionSetAssignment INSERTED, count=' + psaList.size());
                    } else {
                        System.debug('[MBP_PortalUserProvisioningQueueable] EXIT - No PermissionSet found matching ' + permissionSetName);
                    }
                } else {
                    System.debug('[MBP_PortalUserProvisioningQueueable] No Users created - nothing to assign.');
                }

            } catch(Exception e){
                System.debug('[MBP_PortalUserProvisioningQueueable] EXCEPTION: ' + e.getMessage() + ' | line=' + e.getLineNumber() + ' | stack=' + e.getStackTraceString());
            }
        }
}