/**********************************************************************************************************************
* Name               : LeadTriggerHelper                                                       
* Description        : This is a helper class for LeadTriggerHandler
* Usage              : Called from LeadTriggerHandler
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Anil Valluri                             Initial Draft       
* 1.2           Prateek Bansal              17/12/2024  Added condition for exclusive launch
* 1.3           Modon IT                    24/09/2025  Added Validation for De-duplication Account
* 1.4           Activeminds IT              27/11/2025  ReemHills added for RoundRobin and Broker Portal as well
* 2.0           Dinesh                      05/12/2025  Added NULL Check on the "Retire" Lead Condition
* 2.1           Modon                       18/12/2025  Added round robin query for kiosk leads and by pass broker assignment for walk-in leads
* 2.2           Dinesh                      28/12/2025  Call Center Qualified Lead - Auto Assing to Sales
* 2.3           Suresh                      20/01/2026  Lead Assignment to Sales if Lead Score greater than 3
* 2.4           Chandu                      28/01/2026  Lead Assignment to Broker Queue
* 2.5           Arvind                14/09/2026  Round Robin restricted to WALK-IN leads on insert, assigned to SALES user type.
*                                                       RETAINED: v2.2 Call Center 'Lead Qualified' -> Sales re-assignment on update.
*                                                       Commented out: Website / Social Media RR, v1.2 Event Pool assignment,
*                                                       generic catch-all RR, Broker Portal RR (1.4), ReAssignRRToSalesAssociate__c
*                                                       flag and v2.3 Lead Score > 3.
*                                                       Also commented out the Round Robin (3rd condition) inside setMergeOwner_Future.
*                                                       Added active Duplicate Rule check in checkDuplicateLeadsAndReassignOwner.
******************************************************************************************************************/
public without sharing class LeadTriggerHelper {
    
    /*public static void updateLeadEventIds(List<SObject> newList) {
Set<String> set_LeadEvent = new Set<String>();
List<Lead_Event__c> lst_LeadEvent = new List<Lead_Event__c>();
List<Lead_Event__c> lst_UpdateLeadEvent = new List<Lead_Event__c>();
Map<String, Lead> map_Lead = new Map<String, Lead>();

for(Lead obj_Lead : (List<Lead>) newList){
set_LeadEvent.add(obj_Lead.LeadEvent_Name__c);
if(!String.isBlank(obj_Lead.LeadEvent_Name__c)){
map_Lead.put(obj_Lead.LeadEvent_Name__c, obj_Lead);
}
}

lst_LeadEvent = [select Id, LeadID__c, Name from Lead_Event__c where Name IN :set_LeadEvent];
for(Lead_Event__c obj_LeadEvent : lst_LeadEvent){
if(map_Lead.containsKey(obj_LeadEvent.Name) && map_Lead.get(obj_LeadEvent.Name) != null){
obj_LeadEvent.LeadID__c = map_Lead.get(obj_LeadEvent.Name).Id;
lst_UpdateLeadEvent.add(obj_LeadEvent);
}
}

if(lst_UpdateLeadEvent.size() > 0){
update lst_UpdateLeadEvent;
}
}*/
    
    public static void searchForSalesExecutive(List<SObject> newList) {
        
        Set<String> salesExecutiveNames = new Set<String>();
        for (Lead lead : (List<Lead>) newList) {
            if (lead.Sales_Executive__c != null) {
                salesExecutiveNames.add(lead.Sales_Executive__c.toUpperCase());
            }
        }
        System.debug('salesExecutiveNames: '+salesExecutiveNames);
        Map<String, Id> matchingUsers = new Map<String, Id>();
        for (User user : [SELECT Id, Name FROM User WHERE IsActive = true AND Name IN:salesExecutiveNames]) {
            String userNameUpper = user.Name.toUpperCase();
            if (salesExecutiveNames.contains(userNameUpper)) {
                matchingUsers.put(userNameUpper, user.Id);
            }
        }
        //v2.1
        for (RoundRobinAssignmentMatrix__c matrix : [SELECT Id, User__c, UserName__c FROM RoundRobinAssignmentMatrix__c WHERE Status__c = 'Available' AND UserName__c IN:salesExecutiveNames AND LeadSource__c = 'Walk-In']) {
            String userNameUpper = matrix.UserName__c.toUpperCase();
            if (salesExecutiveNames.contains(userNameUpper)) {
                matchingUsers.put(userNameUpper, matrix.User__c);
            }
        }
        //v2.1
        System.debug('matchingUsers: '+matchingUsers);
        for (Lead lead: (List<Lead>) newList) {
            if (lead.Sales_Executive__c != null) {
                String leadExecUpper = lead.Sales_Executive__c.toUpperCase();
                if (matchingUsers.containsKey(leadExecUpper)) {
                    lead.PreferredLeadOwner__c = matchingUsers.get(leadExecUpper);
                    Constants.runRoundRobin = false;//If Sales Executive matching then no need to run the Round-Robin Assignment
                }
            }
        }
    }
    
    public static void setPreferredLeadOwnerAsOwner(list<SObject> newList, Map<Id, SObject> oldMap){ // Call this Before Insert and Before Update
        
        //list<Group> vipManagementGrp = [select Id, DeveloperName, Type from Group where Type = 'Queue' and DeveloperName = 'VIP_Managers'];
        list<User> VIPOwner = [Select Id, username from User where username =: label.VIP_Customer_Assignment_User];
        
        for(Lead newLead : (List<Lead>)newList){
            
            if(oldMap == null){
                if(newLead.PreferredLeadOwner__c <> null && 
                   newLead.CustomerType__c <> Constants.CUSTOMER_TYPE_VIP && 
                   newLead.CustomerType__c <> Constants.CUSTOMER_TYPE_VVIP)
                    
                    newLead.OwnerId = newLead.PreferredLeadOwner__c;
                System.debug('newLead.OwnerId: '+newLead.OwnerId);
                if(newLead.LanguagePreference__c == null)
                    newLead.LanguagePreference__c = 'English';
                
                
                if(VIPOwner <> null && !VIPOwner.isEmpty() && (newLead.CustomerType__c == Constants.CUSTOMER_TYPE_VIP || newLead.CustomerType__c == Constants.CUSTOMER_TYPE_VVIP) && newLead.LeadSource != 'Broker Portal')
                    newLead.OwnerId = VIPOwner[0].Id;
            }
            
            Lead oldRecord; 
            //v2.3
            if(oldMap <> null && newLead.Lead_Score__c == null){
                oldRecord = (Lead)oldMap.get(newLead.Id);
                if(VIPOwner <> null && !VIPOwner.isEmpty() && ( (newLead.CustomerType__c == Constants.CUSTOMER_TYPE_VIP && newLead.CustomerType__c <> oldRecord.CustomerType__c) || (newLead.CustomerType__c == Constants.CUSTOMER_TYPE_VVIP && newLead.CustomerType__c <> oldRecord.CustomerType__c)))
                    newLead.OwnerId = VIPOwner[0].Id;
            } 
        }
    }
    
    public static void setBrokerFieldsOnLead(list<SObject> newList){ // Call this Before Insert
        
        User currentUser = [Select Id, ContactId, AccountId from User where Id =: UserInfo.getUserId()];
        
        if(currentUser.ContactId <> null){
            for(Lead newLead : (List<Lead>)newList){
                if(newLead.LeadSource == 'Walk-In'){ //v2.1
                    continue;
                }
                newLead.BrokerAgency__c = currentUser.AccountId;
                newLead.BrokerAgent__c = currentUser.ContactId;
                newLead.LeadSource = Constants.LEAD_SOURCE_BROKER_PORTAL;
                newLead.Status = 'New';
            }
        }
    }
    
    public static void transferDocumentToOpportunity(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
        set<Id> leadIds = new set<Id>();
        for(Lead leadObj : (List<Lead>)newList){
            Lead oldRecord;
            if(oldMap <> null){
                oldRecord = (Lead)oldMap.get(leadObj.Id);
            }
            if(leadObj.convertedOpportunityId  !=null && leadObj.convertedOpportunityId  <> oldRecord.convertedOpportunityId ){ 
                leadIds.add(leadObj.Id );
            }
        }
        
        List<Documents__c> docLst = [SELECT Id, Lead__r.convertedOpportunityId FROM Documents__c 
                                     WHERE Lead__c IN : leadIds AND Name IN ('Passport Copy','Emirates ID',
                                                                             'ADM Fee 2%+Dari AED499','Authorisation letter',
                                                                             '3 month Bank statement/source of funds',
                                                                             'Downpayment 5%')];
        for(Documents__c docObj : docLst){
            docObj.Opportunity__c = docObj.Lead__r.convertedOpportunityId;
            docObj.Lead__c = null;
        }
        if(!docLst.isEmpty()){
            UPDATE docLst;
        }
    }
    
    public static void validateOpenActivitiesWhileConvert(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){ // Call this after update
        
        set<string> leadIds_Current = new set<string>();
        
        for(Lead newLead : (List<Lead>)newList){
            Lead oldRecord;
            if(oldMap <> null){
                oldRecord = (Lead)oldMap.get(newLead.Id);
            }
            if(newLead.convertedOpportunityId  !=null 
               && newLead.convertedOpportunityId  <> oldRecord.convertedOpportunityId ){ 
                   leadIds_Current.add(newLead.convertedOpportunityId );
               }
        }
        set<string> leadIds_with_OpenTasks = new set<string>();
        
        if(!leadIds_Current.isEmpty()){
            /*list<Task> lstCurrentOpenTasks = [Select Id, isClosed,whatId from Task where isClosed = false and whatId in: leadIds_Current];
if(lstCurrentOpenTasks <> null && !lstCurrentOpenTasks.isEmpty()){
for(Task tsk: lstCurrentOpenTasks){ 
leadIds_with_OpenTasks.add(tsk.whatId);
}
}

if(!leadIds_with_OpenTasks.isEmpty()){
for(Lead newLead : (List<Lead>)newList){
if(leadIds_with_OpenTasks.contains(newLead.convertedOpportunityId)){  
// newLead.addError('There are one or more open Activities under the Lead. Please close them before converting this Lead.');
}
}
}*/
        }
        
    }
    
    //Not used
    /*
public static void roundRobinAssignment1(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){ // Call this After Insert 
list<UserRole> usrRole = [Select Id, DeveloperName from UserRole where DeveloperName like 'Sales_Associate%'];
set<string> usrRoleIds = new set<string>();
for(UserRole ur: usrRole){
usrRoleIds.add(ur.Id);
}
//GET THE ASSIGNMET TIME
DateTime addHoursToTaskDueDate;
list<BusinessHours> orgBusinessHours = [select Id from BusinessHours where IsActive = true and IsDefault=true];
General_Parameters__mdt gp = General_Parameters__mdt.getInstance('Task_SLA_Time');
integer taskSLATime = integer.valueOf(gp.Value__c);
Long interval =  taskSLATime * 60 * 60 * 1000;
addHoursToTaskDueDate = BusinessHours.add( orgBusinessHours[0].id , system.now() , interval  );

Id currUserRoleId = UserInfo.getUserRoleId();

if(usrRole <> null && !usrRole.isEmpty() && !usrRoleIds.isEmpty() && !usrRoleIds.contains(currUserRoleId)){ // if current user role who is creating the Lead is NOT a 'Sales Associate'.

set<Id> currLeadIds = new set<Id>();
string userType = null;
// srinivas 
map<Id,Lead> LeadAssignmentforLeadSouceAndSubsource = new map<Id,Lead>();
List<user> LeadSouceAndSubsourceUsers= Database.Query(label.ModonLeadsoureUser);
for(Lead newLead : (List<Lead>)newList){
LeadAssignmentforLeadSouceAndSubsource.put(newLead.Id,newLead);
if(oldMap == null){ // on Insert
if(newLead.PreferredLeadOwner__c == null && newLead.CustomerType__c <> Constants.CUSTOMER_TYPE_VIP && newLead.CustomerType__c <> Constants.CUSTOMER_TYPE_VVIP && newLead.LeadSource != 'Broker Portal' && newLead.LeadSource != 'Call Center'){

if(newLead.LeadSource == Constants.LEAD_SOURCE_WEBSITE || newLead.LeadSource == Constants.LEAD_SOURCE_SOCIAL_MEDIA){ // If the Lead Source is Website or Social Media..
currLeadIds.add(newLead.Id);
userType = Constants.ROUNDROBIN_USERTYPE_CALLCENTER; // In order to simplify the code, in case of bulk lead upload, make sure to load Website leads in one single file without mixing them with other Lead Sources. Also it is recommeded to run the batch with size as 1 for bulk upload for Round Robin Assignment to work efficiently.
}
else if(newLead.LeadSource != constants.LEAD_SOURCE_SELF_LEAD && newLead.LeadSource != constants.LEAD_SOURCE_MANAGMENT_LEAD){
currLeadIds.add(newLead.Id);
userType = Constants.ROUNDROBIN_USERTYPE_CALLCENTER;
}
}
}
else if(oldMap <> null){ // on Update.
Lead oldRecord;
oldRecord = (Lead)oldMap.get(newLead.Id);

if(newLead.ReAssignRRToSalesAssociate__c == true && newLead.ReAssignRRToSalesAssociate__c <> oldRecord.ReAssignRRToSalesAssociate__c){ // If Re Assign RR To Sales Associate checkbox is checked to True (usually by Call Center Users)..
system.debug('oldRecord.ReAssignRRToSalesAssociate__c::::: ' + oldRecord.ReAssignRRToSalesAssociate__c);
currLeadIds.add(newLead.Id);userType = Constants.ROUNDROBIN_USERTYPE_SALES; 
}
}
}

if(!currLeadIds.isEmpty()){

map<Id,Id> mp_LeadID_OwnerID = new map<Id,Id>();
mp_LeadID_OwnerID = RoundRobinAssignmentUtility.getAvailableAgent(currLeadIds, userType); // Round Robin Assignment Method. // In order to simplify the code, in case of bulk lead upload, make sure to load Website leads in one single file without mixing them with other Lead Sources. Also it is recommeded to run the batch with size as 1 for bulk upload for Round Robin Assignment to work efficiently.
system.debug('mp_LeadID_OwnerID:::' + mp_LeadID_OwnerID);

if(mp_LeadID_OwnerID <> null && !mp_LeadID_OwnerID.isEmpty()){

list<Lead> lst_Leads_to_Update = new list<Lead>();
list<Lead> lst_Leads_to_UpdateLeadSourceAndSubSource = new list<Lead>();
for(Id leadId : mp_LeadID_OwnerID.keySet())
{
if(mp_LeadID_OwnerID.containsKey(leadId)){

Lead leadtemp = LeadAssignmentforLeadSouceAndSubsource.get(leadId);

Lead ld_to_update = new Lead();
ld_to_update.Id = leadId;
ld_to_update.ReAssignRRToSalesAssociate__c = false;
if(leadtemp.LeadSource=='Social Media' && leadtemp.SubSource__c=='International Roadshows' && 
LeadSouceAndSubsourceUsers.size()>0)
{

lst_Leads_to_UpdateLeadSourceAndSubSource.add(leadtemp);
}
ld_to_update.OwnerId = mp_LeadID_OwnerID.get(leadId);                                                                                                        
//ld_to_update.AssignmentSLATime__c = addHoursToTaskDueDate;
lst_Leads_to_Update.add(ld_to_update);
}
}

if(lst_Leads_to_Update <> null && !lst_Leads_to_Update.isEmpty()){update lst_Leads_to_Update;
}

if(lst_Leads_to_UpdateLeadSourceAndSubSource.size()>0){

for(Lead ld_to_update : lst_Leads_to_UpdateLeadSourceAndSubSource)
{
ld_to_update.OwnerId = LeadSouceAndSubsourceUsers[0].Id; 
}
// update lst_Leads_to_UpdateLeadSourceAndSubSource;
}
}
}
}else if(usrRole <> null && !usrRole.isEmpty() && !usrRoleIds.isEmpty() && usrRoleIds.contains(currUserRoleId)){list<Lead> lst_Leads_to_Update = new list<Lead>();
//TODO update the time on the lead
for(Lead newLead : (List<Lead>)newList){Lead ld_to_update = new Lead();
ld_to_update.Id = newLead.ID;
//ld_to_update.AssignmentSLATime__c = addHoursToTaskDueDate;
lst_Leads_to_Update.add(ld_to_update);
}
if(lst_Leads_to_Update <> null && !lst_Leads_to_Update.isEmpty()){update lst_Leads_to_Update;
}
}
} */
    
    /**********************************************************************************************
    * v2.5 - 14/09/2026
    * ON INSERT  : Round Robin applies ONLY to WALK-IN leads, assigned to ROUNDROBIN_USERTYPE_SALES
    *              (previously ROUNDROBIN_USERTYPE_CALLCENTER).
    * ON UPDATE  : only the v2.2 path is active - a Call Center user setting Status to
    *              'Lead Qualified' re-assigns the Lead to the SALES pool.
    * Every other Round Robin scenario is commented out - see inline markers.
    **********************************************************************************************/
    public static void roundRobinAssignment(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){ // Call this After Insert 
        list<UserRole> usrRole = [Select Id, DeveloperName from UserRole where (DeveloperName like 'Sales_Associate%')];
        list<UserRole> callcenterUsrRole = [Select Id, DeveloperName from UserRole where (DeveloperName like 'Call_Center%') AND (NOT DeveloperName like '%Egypt%')]; /** 2.2 Call Center Qualified Lead - Auto Assing to Sales **/
        set<string> usrRoleIds = new set<string>();
        set<string> callcenterUsrRoleIds = new set<string>();
        for(UserRole ur: usrRole){
            usrRoleIds.add(ur.Id);
        }
        for(UserRole ur: callcenterUsrRole){
            callcenterUsrRoleIds.add(ur.Id);   /** 2.2 Call Center Qualified Lead - Auto Assing to Sales **/
        }
        
        // ===== v2.5 - 14/09/2026 - COMMENTED : SLA time block. addHoursToTaskDueDate was only used by
        // the already-commented AssignmentSLATime__c line, so this was costing a SOQL query for nothing.
        // GET THE ASSIGNMET TIME
        // DateTime addHoursToTaskDueDate;
        // list<BusinessHours> orgBusinessHours = [select Id from BusinessHours where IsActive = true and IsDefault=true];
        // General_Parameters__mdt gp = General_Parameters__mdt.getInstance('Task_SLA_Time');
        // integer taskSLATime = integer.valueOf(gp.Value__c);
        // Long interval =  taskSLATime * 60 * 60 * 1000;
        // addHoursToTaskDueDate = BusinessHours.add( orgBusinessHours[0].id , system.now() , interval  );
        // ===== v2.5 END COMMENT =====
        
        Id currUserRoleId = UserInfo.getUserRoleId();
        
        if(usrRole <> null && !usrRole.isEmpty() && !usrRoleIds.isEmpty() && !usrRoleIds.contains(currUserRoleId)){ // if current user role who is creating the Lead is NOT a 'Sales Associate'.
            
            set<Id> currLeadIds = new set<Id>();
            string userType = null;
            //v2.5 - no longer required, the v1.2 Event Pool logic below is commented out.
            //Id updateLeadId = null;
            
            for(Lead newLead : (List<Lead>)newList){
                
                if(oldMap == null && !callcenterUsrRoleIds.contains(currUserRoleId) && String.isBlank(newLead.Cross_Sell_Lead_Number__c)){ // on Insert//1.4 
                    if(newLead.PreferredLeadOwner__c == null 
                       && newLead.CustomerType__c <> Constants.CUSTOMER_TYPE_VIP 
                       && newLead.CustomerType__c <> Constants.CUSTOMER_TYPE_VVIP 
                       && newLead.LeadSource != 'Call Center' && newLead.LeadSource != 'General Public Sales Launch'){//1.4 
                           
                           // ===== v2.5 - 14/09/2026 - COMMENTED : Website / Social Media Round Robin,
                           // including the v1.2 Maysan Exclusive Launch branch.
                           // if(newLead.LeadSource == Constants.LEAD_SOURCE_WEBSITE || newLead.LeadSource == Constants.LEAD_SOURCE_SOCIAL_MEDIA){
                           //     if(newLead.UTMSource__c == System.Label.EventName && newLead.SubSource__c == System.Label.EventSubSource
                           //        && newLead.LeadSource == Constants.LEAD_SOURCE_SOCIAL_MEDIA && newLead.AdName__c == System.Label.EventAdName){
                           //            updateLeadId = newLead.Id;
                           //            break;
                           //        }else{
                           //            currLeadIds.add(newLead.Id);
                           //            userType = Constants.ROUNDROBIN_USERTYPE_CALLCENTER;
                           //        }
                           // }
                           // else
                           // ===== v2.5 END COMMENT =====
                           
                           //***** v2.5 - KEEP : Walk-In / Modon Ramadan Stand -> SALES user *****//
                           if(newLead.LeadSource == 'Walk-In'
                              && newLead.utmSource__c == 'Modon Ramadan Stand'){
                                  currLeadIds.add(newLead.Id); 
                                  userType = Constants.ROUNDROBIN_USERTYPE_SALES; //v2.5 - was ROUNDROBIN_USERTYPE_CALLCENTER
                              }
                           //***** v2.5 - KEEP : Walk-In / Kiosk / Hostess -> SALES user *****//
                           else if(newLead.LeadSource == constants.LEAD_SOURCE_WALKIN 
                                   && newLead.SubSource__c == constants.LEAD_SUB_SOURCE_KIOSK 
                                   && System.label.SalesExecutiveHostess != 'Null' 
                                   && newLead.Sales_Executive__c == System.label.SalesExecutiveHostess ){
                               currLeadIds.add(newLead.Id); 
                               userType = Constants.ROUNDROBIN_USERTYPE_SALES; //v2.5 - was ROUNDROBIN_USERTYPE_CALLCENTER
                           }
                           
                           // ===== v2.5 - 14/09/2026 - COMMENTED : generic catch-all Round Robin to Sales
                           // else if(newLead.LeadSource != constants.LEAD_SOURCE_SELF_LEAD && newLead.LeadSource != constants.LEAD_SOURCE_MANAGMENT_LEAD){
                           //     currLeadIds.add(newLead.Id);
                           //     userType = Constants.ROUNDROBIN_USERTYPE_SALES;
                           // }
                           // ===== v2.5 - COMMENTED : Broker Portal Round Robin (1.4). Note this branch was
                           // already unreachable, the catch-all above always matched Broker Portal first.
                           // else if(newLead.LeadSource == 'Broker Portal'){
                           //     currLeadIds.add(newLead.Id);
                           //     userType = Constants.ROUNDROBIN_USERTYPE_SALES;
                           // }
                           // ===== v2.5 END COMMENT =====
                       }
                } 
                //***** v2.2 KEPT ACTIVE : when a Call Center user sets Status to 'Lead Qualified',
                // the Lead is re-assigned to the SALES pool via Round Robin. Confirmed as a live
                // business process on 14/09/2026, so this branch stays enabled under v2.5.
                else if(oldMap <> null){ // on Update.
                    Lead oldRecord;
                    oldRecord = (Lead)oldMap.get(newLead.Id);
                    
                    // ===== v2.5 - 14/09/2026 - COMMENTED : ReAssignRRToSalesAssociate__c checkbox
                    // if(newLead.ReAssignRRToSalesAssociate__c == true && newLead.ReAssignRRToSalesAssociate__c <> oldRecord.ReAssignRRToSalesAssociate__c){
                    //     currLeadIds.add(newLead.Id);userType = Constants.ROUNDROBIN_USERTYPE_SALES;
                    // }
                    // ===== v2.5 END COMMENT =====
                    
                    // v2.2 - Call Center Qualified Lead, auto assign to Sales. ACTIVE.
                    if(newLead.Status == 'Lead Qualified' 
                       && newLead.Status <> oldRecord.Status 
                       && callcenterUsrRoleIds.contains(currUserRoleId)){ 
                        system.debug('v2.2 - Call Center qualified Lead, routing to Sales: ' + newLead.Id);
                        currLeadIds.add(newLead.Id);
                        userType = Constants.ROUNDROBIN_USERTYPE_SALES; 
                    }
                    
                    // ===== v2.5 - 14/09/2026 - COMMENTED : v2.3 Lead Score greater than 3
                    // if(newLead.Lead_Score__c != null && newLead.Lead_Score__c != oldRecord.Lead_Score__c &&  newLead.Lead_Score__c > 3){
                    //     currLeadIds.add(newLead.Id);userType = Constants.ROUNDROBIN_USERTYPE_SALES;
                    // }
                    // ===== v2.5 END COMMENT =====
                }
            }
            
            // ===== v2.5 - 14/09/2026 - COMMENTED : v1.2 Event Pool Owner assignment
            // if(String.isNotBlank(updateLeadId) && currLeadIds.isEmpty()){
            //     Lead leadToUpdate = new Lead(Id = updateLeadId, OwnerId = System.Label.EventPoolOwner);
            //     Update leadToUpdate;
            // }
            // ===== v2.5 END COMMENT =====
            
            if(!currLeadIds.isEmpty()){
                
                map<Id,Id> mp_LeadID_OwnerID = new map<Id,Id>();
                mp_LeadID_OwnerID = RoundRobinAssignmentUtility.getAvailableAgent(currLeadIds, userType); // v2.5 - reached by Walk-In leads on insert and Call Center qualified leads on update. userType is always ROUNDROBIN_USERTYPE_SALES.
                system.debug('mp_LeadID_OwnerID:::' + mp_LeadID_OwnerID);
                
                if(mp_LeadID_OwnerID <> null && !mp_LeadID_OwnerID.isEmpty()){
                    
                    list<Lead> lst_Leads_to_Update = new list<Lead>();
                    
                    for(Id leadId : mp_LeadID_OwnerID.keySet())
                    {
                        if(mp_LeadID_OwnerID.containsKey(leadId)){
                            
                            Lead ld_to_update = new Lead();
                            ld_to_update.Id = leadId;
                            ld_to_update.ReAssignRRToSalesAssociate__c = false;
                            ld_to_update.OwnerId = mp_LeadID_OwnerID.get(leadId); 
                            
                            //ld_to_update.AssignmentSLATime__c = addHoursToTaskDueDate;
                            lst_Leads_to_Update.add(ld_to_update);
                        }
                    }
                    
                    if(lst_Leads_to_Update <> null && !lst_Leads_to_Update.isEmpty()){
                        update lst_Leads_to_Update;
                    }
                }
            }
        }
        // ===== v2.5 - 14/09/2026 - COMMENTED : empty Sales Associate branch, its body was already commented out.
        // else if(usrRole <> null && !usrRole.isEmpty() && !usrRoleIds.isEmpty() && usrRoleIds.contains(currUserRoleId)){
        //     list<Lead> lst_Leads_to_Update = new list<Lead>();
        //     TODO update the time on the lead
        // }
        // ===== v2.5 END COMMENT =====
    }
    
    public static void update_MergeCount(List<SObject> oldList, Map<Id, SObject> oldMap){ // Call this After Delete. 
        if(oldMap <> null && !oldMap.isEmpty()){
            
            map<Id,Id> masterRecordsToOwner = new map<Id,Id>(); 
            map<Id,Id> masterRecordsToBrokerAgent = new map<Id,Id>(); 
            map<Id,string> masterRecordsToLosingLeadName = new map<Id,string>();
            map<string,string> mp_MasterLeadId_losingLeadId = new map<string,string>();
            map<string, decimal> mp_losingLeadID_losingLeadMergeCount = new map<string, decimal>();
            
            for(Lead oldLead : (List<Lead>)oldList){
                if(oldLead.MasterRecordId <> null){
                    masterRecordsToOwner.put(oldLead.MasterRecordId, oldLead.OwnerId);
                    
                    if(oldLead.BrokerAgent__c <> null)masterRecordsToBrokerAgent.put(oldLead.MasterRecordId, oldLead.BrokerAgent__c);
                    
                    string leadname = oldLead.FirstName + ' ' + oldLead.LastName;leadname = leadname.trim();
                    
                    masterRecordsToLosingLeadName.put(oldLead.MasterRecordId, leadname);
                    mp_MasterLeadId_losingLeadId.put(oldLead.MasterRecordId, oldLead.Id);
                    
                    if(oldLead.LeadMergeCount__c == null){mp_losingLeadID_losingLeadMergeCount.put(oldLead.Id, 0);
                                                         }
                    else if(oldLead.LeadMergeCount__c <> null){mp_losingLeadID_losingLeadMergeCount.put(oldLead.Id, oldLead.LeadMergeCount__c);
                                                              }
                    
                }
                
                
            }
            
            update_MergeCount_Future(masterRecordsToOwner, masterRecordsToBrokerAgent, masterRecordsToLosingLeadName, mp_MasterLeadId_losingLeadId, mp_losingLeadID_losingLeadMergeCount);
            
        }
    }
    
    @future
    public static void update_MergeCount_Future( map<Id,Id> masterRecordsToOwner, map<Id,Id> masterRecordsToBrokerAgent, map<Id,string> masterRecordsToLosingLeadName,  map<string,string> mp_MasterLeadId_losingLeadId, map<string, decimal> mp_losingLeadID_losingLeadMergeCount){ 
        
        
        system.debug('mp_MasterLeadId_losingLeadId::::' + mp_MasterLeadId_losingLeadId);
        system.debug('mp_losingLeadID_losingLeadMergeCount::::' + mp_losingLeadID_losingLeadMergeCount);
        
        if(mp_losingLeadID_losingLeadMergeCount <> null && !mp_losingLeadID_losingLeadMergeCount.isEmpty()){
            list<Lead> masterLeads = [Select Id, LeadMergeCount__c from Lead where Id in: masterRecordsToOwner.keySet()];
            if(masterLeads <> null && !masterLeads.isEmpty()){list<lead> leadsToUpdate = new list<lead>();
                                                              
                                                              for(Lead masterLead: masterLeads){decimal masterLeadMergeCount = null;
                                                                                                if(masterLead.LeadMergeCount__c == null){ masterLeadMergeCount = 0;
                                                                                                                                        }
                                                                                                else if(masterLead.LeadMergeCount__c <> null){  masterLeadMergeCount = masterLead.LeadMergeCount__c;
                                                                                                                                             }
                                                                                                
                                                                                                Lead lead_to_update = new lead(); lead_to_update.Id = masterLead.Id;
                                                                                                
                                                                                                system.debug('masterLeadMergeCount::::' + masterLeadMergeCount);
                                                                                                
                                                                                                if(mp_losingLeadID_losingLeadMergeCount.get(mp_MasterLeadId_losingLeadId.get(masterLead.Id)) == masterLeadMergeCount ){lead_to_update.LeadMergeCount__c = masterLeadMergeCount + 1;
                                                                                                                                                                                                                      }                            
                                                                                                else if(mp_losingLeadID_losingLeadMergeCount.get(mp_MasterLeadId_losingLeadId.get(masterLead.Id)) > masterLeadMergeCount ){lead_to_update.LeadMergeCount__c = mp_losingLeadID_losingLeadMergeCount.get(mp_MasterLeadId_losingLeadId.get(masterLead.Id)) + 1;
                                                                                                                                                                                                                          }
                                                                                                else if(mp_losingLeadID_losingLeadMergeCount.get(mp_MasterLeadId_losingLeadId.get(masterLead.Id)) < masterLeadMergeCount ){
                                                                                                    lead_to_update.LeadMergeCount__c = masterLeadMergeCount + 1;
                                                                                                }
                                                                                                leadsToUpdate.add(lead_to_update);
                                                                                               }
                                                              
                                                              system.debug('leadsToUpdate::::' + leadsToUpdate);
                                                              
                                                              update leadsToUpdate;
                                                             }
        }
        
        
        
    }
    
    public static void roundRobinAssignment_for_Merge(List<SObject> oldList, Map<Id, SObject> oldMap){ // Call this After Delete. 
        
        map<Id,Id> masterRecordsToOwner = new map<Id,Id>();
        map<Id,Id> masterRecordsToBrokerAgent = new map<Id,Id>();
        map<Id,string> masterRecordsToLosingLeadName = new map<Id,string>();
        
        if(oldMap <> null && !oldMap.isEmpty()){
            
            for(Lead oldLead : (List<Lead>)oldList){
                if(oldLead.MasterRecordId <> null){
                    masterRecordsToOwner.put(oldLead.MasterRecordId, oldLead.OwnerId);
                    
                    if(oldLead.BrokerAgent__c <> null)masterRecordsToBrokerAgent.put(oldLead.MasterRecordId, oldLead.BrokerAgent__c);
                    
                    string leadname = oldLead.FirstName + ' ' + oldLead.LastName;leadname = leadname.trim();
                    
                    masterRecordsToLosingLeadName.put(oldLead.MasterRecordId, leadname);
                    
                    
                }
                
                
            }
            
            
        }
        
        if(!masterrecordsToOwner.isEmpty()){ setMergeOwner_Future(masterRecordsToOwner, masterRecordsToBrokerAgent, masterRecordsToLosingLeadName);
                                           }
        
    }
    
    @Future
    public static void setMergeOwner_Future(map<Id,Id> masterRecordsToOwner, map<Id,Id> masterRecordsToBrokerAgent, map<Id,string> masterRecordsToLosingLeadName){
        // delete all manual shares
        delete [Select id from LeadShare where LEadID in :masterRecordsToOwner.KeySet() and RowCause='Manual'];
        
        //GET THE ASSIGNMET TIME
        DateTime addHoursToTaskDueDate;
        list<BusinessHours> orgBusinessHours = [select Id from BusinessHours where IsActive = true and IsDefault=true];
        General_Parameters__mdt gp = General_Parameters__mdt.getInstance('Task_SLA_Time');
        integer taskSLATime = integer.valueOf(gp.Value__c);
        Long interval =  taskSLATime * 60 * 60 * 1000;
        addHoursToTaskDueDate = BusinessHours.add( orgBusinessHours[0].id , system.now() , interval  );
        
        //1. iterate over master records and check if they already have user (not queue) Then they are fine no change
        //2. Check if we have recived user as owner for the lossing record, Then set that user
        //3. Otherwise do the round robin  -- v2.5 : 3rd condition is COMMENTED OUT below.
        //1st Condition
        for(Lead masterLeads : [select id,OwnerId from Lead where id in :masterrecordsToOwner.keySet()]){
            if(String.valueOf(masterLeads.OwnerId).startsWith('005') ){
                masterRecordsToOwner.remove(masterLeads.Id);
            }
        }
        list<Lead> lst_Leads_to_Update = new list<Lead>();
        //2nd Condition
        if(!masterrecordsToOwner.isEmpty()){
            for(Id masterId : masterRecordsToOwner.keySet()){if(String.valueOf(masterRecordsToOwner.get(masterId)).startsWith('005') ) {lst_Leads_to_Update.add(new lead(Id =masterId, OwnerId = masterRecordsToOwner.get(masterId) ));
                                                                                                                                        masterRecordsToOwner.remove(masterId);
                                                                                                                                       }
                                                             
                                                            }
        }
        
        // ===== v2.5 - 14/09/2026 - COMMENTED : 3rd Condition, Round Robin on Lead Merge.
        // Conditions 1 and 2 above are retained, as are the manual LeadShare cleanup at the top
        // and the Broker merge bell notification below.
        // 3rd Condition
        // if(!masterrecordsToOwner.isEmpty()){
        //     map<Id,Id> mp_LeadID_OwnerID = new map<Id,Id>();
        //     mp_LeadID_OwnerID = RoundRobinAssignmentUtility.getAvailableAgent(masterrecordsToOwner.KeySet(), Constants.ROUNDROBIN_USERTYPE_SALES);
        //     if(mp_LeadID_OwnerID <> null && !mp_LeadID_OwnerID.isEmpty()){
        //         for(Id leadId : mp_LeadID_OwnerID.keySet()){
        //             if(mp_LeadID_OwnerID.containsKey(leadId)){
        //                 Lead ld_to_update = new Lead();
        //                 ld_to_update.Id = leadId;
        //                 ld_to_update.OwnerId = mp_LeadID_OwnerID.get(leadId);
        //                 lst_Leads_to_Update.add(ld_to_update);
        //             }
        //         }
        //     }
        // }
        // ===== v2.5 END COMMENT =====
        
        
        if(lst_Leads_to_Update <> null && !lst_Leads_to_Update.isEmpty()){ update lst_Leads_to_Update;
                                                                         }
        
        system.debug('masterRecordsToBrokerAgent::::: ' + masterRecordsToBrokerAgent);
        
        if(!masterRecordsToBrokerAgent.isEmpty()){
            CustomNotificationType notificationType = [SELECT Id, DeveloperName FROM CustomNotificationType WHERE DeveloperName='Lead_Merge_Notification']; 
            
            list<User> usersCurrent = [Select Id, Name, ContactId from User where ContactId in: masterRecordsToBrokerAgent.values() and isActive = true];
            map<Id, Id> contactID_UserID = new map<Id, Id>();
            if(usersCurrent <> null && !usersCurrent.isEmpty()){for(User usr: usersCurrent){ contactID_UserID.put(usr.ContactId, usr.Id);
                                                                                           }
                                                               }
            
            list<lead> leadRecs = [Select Id, Name from Lead where Id in: masterRecordsToBrokerAgent.keySet()];
            final Map<String, Object> communityPageRef = new Map<String, Object>{
                'type' => 'comm__namedPage',
                    'attributes' => new Map<String, Object>{
                        'pageName' => 'home'
                            }
            };
                
                system.debug('masterRecordsToLosingLeadName:::: ' + masterRecordsToLosingLeadName);
            
            for(Lead leadRec: leadRecs){
                
                Messaging.CustomNotification notification = new Messaging.CustomNotification();
                string losingLeadName = null;
                losingLeadName = masterRecordsToLosingLeadName.containsKey(leadRec.Id)? masterRecordsToLosingLeadName.get(leadRec.Id) : '';
                
                notification.setTitle('Your Lead has been merged');
                notification.setBody('One of your leads ' + '"' + losingLeadName + '"' + ' has been identified as duplicate and has been removed from the system, please reach out to operation team in case of any concerns.');
                notification.setNotificationTypeId(notificationType.Id);
                notification.setTargetPageRef(JSON.serialize(communityPageRef));
                
                set<string> userIds = new set<string>();
                if(contactID_UserID <> null && !contactID_UserID.isEmpty() && contactID_UserID.containsKey(masterRecordsToBrokerAgent.get(leadRec.Id)))userIds.add(contactID_UserID.get(masterRecordsToBrokerAgent.get(leadRec.Id)));
                
                system.debug('userIds:::: ' + userIds);
                
                try {
                    notification.send(userIds); // Cannot bulkify. Sending to one user at a time.
                }
                catch (Exception e) { System.debug('Problem sending bell notification: ' + e.getMessage() + ' Trace:: ' + e.getStackTraceString());
                                    }
                
            }
        }
        
    }
    
    public static void autoCreate_and_autoClose_Tasks(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){ // Call this After Insert and Before Update.
        
        list<User> lstUsers_SalesManagementProfile = [Select Id, Profile.Name from User where Profile.Name =: Constants.SALES_MANAGEMENT_PROFILE_NAME];
        set<string> lstUser_IDs_SalesManagementProfile = new set<string>();
        
        if(lstUsers_SalesManagementProfile <> null && !lstUsers_SalesManagementProfile.isEmpty()){
            for(User usr: lstUsers_SalesManagementProfile){
                lstUser_IDs_SalesManagementProfile.add(usr.Id);
            }
        }
        
        set<string> leadIDs_CurrentContext = new set<string>();
        map<string, string> mp_leadID_LeadOwnerID = new map<string, string>();
        
        for(Lead newLead : (List<Lead>)newList){
            
            String newOwnerIDString = String.valueOf(newLead.OwnerId);
            Lead oldRecord;
            if(oldMap <> null){ oldRecord = (Lead)oldMap.get(newLead.Id);
                              }
            
            if( (oldMap == null && newOwnerIDString.startsWith('005')) || (oldMap <> null && newOwnerIDString.startsWith('005') && oldRecord.OwnerId <> newLead.OwnerId && !lstUser_IDs_SalesManagementProfile.isEmpty() && lstUser_IDs_SalesManagementProfile.contains(newLead.OwnerId)) ){ // If the context is Insert OR Update plus Owner is changed plus Owner is not a Queue and has Sales Management Profile..
                
                leadIDs_CurrentContext.add(newLead.Id);
                mp_leadID_LeadOwnerID.put(newLead.Id, newLead.OwnerId);
                
            }
            
        }
        
        if(leadIDs_CurrentContext <> null && !leadIDs_CurrentContext.isEmpty()){
            
            // Auto Close Existing System Created Tasks and Auto Create New tasks for New Lead Owners..
            
            list<Task> lst_Existing_SysGenerated_Tasks = [Select Id, whoId, OwnerId, Subject, System_Created__c, Status from Task where whoId in: leadIDs_CurrentContext and System_Created__c = true and isClosed =false];
            list<Task> lst_Tasks_to_AutoClose = new list<Task>();
            
            if(lst_Existing_SysGenerated_Tasks <> null && !lst_Existing_SysGenerated_Tasks.isEmpty()){
                for(Task tsk: lst_Existing_SysGenerated_Tasks){
                    Task tsk_to_update = new Task();
                    tsk_to_update.Id = tsk.Id;
                    tsk_to_update.Status = Constants.TASK_STATUS_AUTO_CLOSED;
                    
                    lst_Tasks_to_AutoClose.add(tsk_to_update);
                }
                
                if(lst_Tasks_to_AutoClose <> null && !lst_Tasks_to_AutoClose.isEmpty()){
                    update lst_Tasks_to_AutoClose; // Auto Close Existing System Created Tasks 
                }
            }
            
            list<Task> lst_New_Tasks_to_Create = new List<Task>();
            
            if(mp_leadID_LeadOwnerID <> null && !mp_leadID_LeadOwnerID.isEmpty()){
                
                DateTime addHoursToTaskDueDate;
                list<BusinessHours> orgBusinessHours = [select Id from BusinessHours where IsActive = true and IsDefault=true];
                General_Parameters__mdt gp = General_Parameters__mdt.getInstance('Task_SLA_Time');
                integer taskSLATime = integer.valueOf(gp.Value__c);
                Long interval =  taskSLATime * 60 * 60 * 1000;
                addHoursToTaskDueDate = BusinessHours.add( orgBusinessHours[0].id , system.now() , interval  );
                Date dueDate = Date.newInstance(addHoursToTaskDueDate.year(), addHoursToTaskDueDate.month(), addHoursToTaskDueDate.day());
                
                for(String leadId: leadIDs_CurrentContext){
                    Task newTask = new Task();
                    newTask.whoId = leadId;
                    newTask.OwnerId = mp_leadID_LeadOwnerID.containsKey(leadId)? mp_leadID_LeadOwnerID.get(leadId) : null;
                    newTask.Subject = Constants.TASK_SUBJECT_FOR_LEAD_FOLLOWUP;
                    newTask.ActivityDate = dueDate;
                    newTask.Status = Constants.TASK_STATUS_OPEN;
                    newTask.System_Created__c = true;
                    
                    lst_New_Tasks_to_Create.add(newTask);
                }
                
                if(lst_New_Tasks_to_Create <> null && !lst_New_Tasks_to_Create.isEmpty()){
                    insert lst_New_Tasks_to_Create; // Auto Create New Tasks for New Owners..
                    
                }
            }
            
            
        }
        
        
        
    }
    
    
    // ===== v2.5 - 14/09/2026 =====
    // Datacloud.FindDuplicates.findDuplicates() throws an unhandled exception when there is no
    // ACTIVE Duplicate Rule for the Lead object, which blocks the whole insert/update.
    // This flag is evaluated once per transaction and cached.
    //   Rule ACTIVE   -> duplicate routing to the Sales Operations queue runs exactly as before.
    //   Rule INACTIVE -> duplicate routing is skipped silently, the record saves normally.
    private static Boolean leadDuplicateRuleActive;
    
    private static Boolean hasActiveLeadDuplicateRule(){
        if(leadDuplicateRuleActive == null){
            leadDuplicateRuleActive = ![SELECT Id FROM DuplicateRule 
                                        WHERE SobjectType = 'Lead' AND IsActive = true LIMIT 1].isEmpty();
            System.debug('v2.5 - Active Lead Duplicate Rule found: ' + leadDuplicateRuleActive);
        }
        return leadDuplicateRuleActive;
    }
    
    public static void checkDuplicateLeadsAndReassignOwner(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){ // Call this Before Insert and Before Update.
        
        // v2.5 - No active Duplicate Rule for Lead in this org, skip duplicate routing rather than failing the save.
        if(!hasActiveLeadDuplicateRule()){
            System.debug(LoggingLevel.WARN, 'v2.5 - No active Duplicate Rule for Lead. Duplicate routing to the Sales Operations queue is skipped.');
            return;
        }
        
        list<Group> sales_operation_queue = [select Id, DeveloperName, Type from Group where DeveloperName =: Constants.SALES_OPERATIONS_QUEUE_API_NAME];
        
        if(sales_operation_queue <> null && !sales_operation_queue.isEmpty()){
            for(Lead newLead : (List<Lead>)newList){
                Lead oldLeadC = oldMap <> null ? ((Lead)oldMap.get(newLead.Id)) : null;
                if( (oldMap == null && newLead.OwnerId <> sales_operation_queue[0].Id 
                     && newLead.LeadSource != 'Broker Portal' 
                     && newLead.LeadSource != 'Website' 
                     && newLead.LeadSource != 'Social Media' 
                     && String.isBlank(newLead.Cross_Sell_Lead_Number__c) 
                     && newLead.Is_Cross_Sell_Lead__c != true) 
                   ||      
                   (oldMap <> null && newLead.OwnerId <> sales_operation_queue[0].Id 
                    && String.isBlank(newLead.Cross_Sell_Lead_Number__c)
                    && newLead.LeadSource != 'Website' 
                    && newLead.LeadSource != 'Social Media' 
                    && newLead.LeadSource != 'Broker Portal'
                    && newLead.Is_Cross_Sell_Lead__c != true
                    && (newLead.MobilePhone != oldLeadC.MobilePhone
                        || newLead.Email != oldLeadC.Email  
                        || newLead.EIDNumber__c != oldLeadC.EIDNumber__c  
                        || newLead.PassportNumber__c != oldLeadC.PassportNumber__c  ))){ // If the context is Insert OR Update plus Owner is not Sales Operation Queue...
                            
                            List<Lead> lst_NewLeads = new List<Lead>();
                            lst_NewLeads.add(newLead);
                            
                            Lead oldLead;
                            if(oldMap <> null)
                                oldLead = (Lead)oldMap.get(newLead.Id);
                            
                            // Checking if Duplicate Exist for each Lead record.
                            // v2.5 - safety net. The active-rule check above is the primary guard, this catches
                            // a rule being deactivated mid-transaction or any other Datacloud failure.
                            List<Datacloud.FindDuplicatesResult > findDuplicatesResult;
                            try {
                                findDuplicatesResult = Datacloud.FindDuplicates.findDuplicates(lst_NewLeads);
                            } catch (Exception e) {
                                System.debug(LoggingLevel.WARN, 'v2.5 - findDuplicates failed, skipping duplicate routing for this Lead: ' + e.getMessage());
                                continue;
                            }
                            
                            List<Datacloud.MatchRecord> matchRecords = new List<Datacloud.MatchRecord>();
                            if(findDuplicatesResult <> null && !findDuplicatesResult.isEmpty() && findDuplicatesResult.get(0).getDuplicateResults() <> null && !findDuplicatesResult.get(0).getDuplicateResults().isEmpty()){
                                Datacloud.DuplicateResult duplicateResult = findDuplicatesResult.get(0).getDuplicateResults().get(0);
                                Datacloud.MatchResult matchResult = duplicateResult.getMatchResults()[0];
                                matchRecords = matchResult.getMatchRecords();
                            }
                            Set<Id> duplicateIdset =new Set<Id>();
                            for(Datacloud.MatchRecord matchRecord : matchRecords){
                                SObject duplicate = matchRecord.getRecord();
                                duplicateIdset.add(duplicate.Id);
                            }
                            Set<Id> retiredDuplicateleadSet = new Set<Id>();
                            for(Lead leadObj:[SELECT Id FROM Lead WHERE (Status = 'Retired') AND Id IN:duplicateIdset ]){
                                retiredDuplicateleadSet.add(leadObj.Id);
                            }
                            List<SObject> duplicates = new List<SObject>();
                            for(Datacloud.MatchRecord matchRecord : matchRecords){
                                SObject duplicate = matchRecord.getRecord();
                                System.debug('Match Record: ' + duplicate);
                                Id sObjRecID = duplicate.Id;
                                String sobj_Name = sObjRecID.getSObjectType().getDescribe().getName();
                                system.debug('sobj_Name:::' + sobj_Name);
                                //Check duplicate across all the records
                                // For insert scenario add it to duplicate quee
                                // 
                                if(oldMap == null && ((!retiredDuplicateleadSet.isEmpty() && !retiredDuplicateleadSet.contains(sObjRecID)) || retiredDuplicateleadSet.isEmpty())){ //*** 2.0 ADDED "RetireLead" NULL Check ***//
                                    duplicates.add(duplicate);
                                }
                                // for update scenario add it to queue only if its matching with Lead
                                else{
                                    //TODO Check Owner is getting changed, 
                                    //If owner is chnaged and the old owner was not Duplicate queue then perform below action
                                    if(oldLead <> null && newLead.OwnerId == oldLead.OwnerId && ((!retiredDuplicateleadSet.isEmpty() && !retiredDuplicateleadSet.contains(sObjRecID)) || retiredDuplicateleadSet.isEmpty())){  //*** 2.0 ADDED "RetireLead" NULL Check ***//
                                        duplicates.add(duplicate);
                                    }
                                    if(oldLead <> null && newLead.OwnerId != oldLead.OwnerId && oldLead.OwnerId != sales_operation_queue[0].Id && ((!retiredDuplicateleadSet.isEmpty() && !retiredDuplicateleadSet.contains(sObjRecID)) || retiredDuplicateleadSet.isEmpty())){ //*** 2.0 ADDED "RetireLead" NULL Check ***//
                                        duplicates.add(duplicate);
                                    }
                                }
                            }
                            
                            
                            if(duplicates.size() > 0){
                                Constants.runRoundRobin = false; // If the Lead is Duplicate, do not run Round Robin as the Owner (Sales Operations Queue) will be overridden by Round Robin Assignment (As this is on Before Insert and Round Robin is on After Insert).
                                newLead.OwnerId = sales_operation_queue[0].Id; // Assign the Lead to Sales Operations Queue if the Lead is a Duplicate.
                            }
                            
                            
                        }
                
            }
            
        }
        
    }
    
    public static void assignReadAccessToCreator(list<SObject> newList){
        list<Group> sales_operation_queue = [select Id, DeveloperName, Type from Group where DeveloperName =: Constants.SALES_OPERATIONS_QUEUE_API_NAME];
        list<LeadShare> shareRecordToBeCreated = new list<LeadShare>();
        Id profileId = userinfo.getProfileId();
        List<Profile> profs = [Select Id, Name from Profile where Id=:profileId];
        String profileName = profs.isEmpty() ? '' : profs[0].Name;
        
        for(Lead newLead : (List<Lead>)newList){
            if((!sales_operation_queue.isEMpty() && newLead.OwnerId == sales_operation_queue[0].Id) || profileName == 'Call Center Management'){
                shareRecordToBeCreated.add(new LeadShare(LeadAccessLevel ='Read', LeadId=newLead.Id,RowCause='Manual',UserOrGroupId=newLead.createdById));
            }
        }
        if(!shareRecordToBeCreated.IsEmpty()){
            database.insert(shareRecordToBeCreated,false);
        }
        
        
        
    }
    
    public static void shareLeads(list<SObject> newList, Map<Id, SObject> oldMap){ // Call this After Insert and After Update
        
        //list<Group> vipManagementGrp = [select Id, DeveloperName, Type from Group where Type = 'Queue' and DeveloperName = 'VIP_Managers'];
        list<User> vipCustomerAssignmentUser = [Select Id, username from User where username =: label.VIP_Customer_Assignment_User];
        
        Set<Id> leadIds_Current = new Set<Id>();
        
        if(oldMap == null){
            if(vipCustomerAssignmentUser <> null && !vipCustomerAssignmentUser.isEmpty()){
                for(Lead newLead : (List<Lead>)newList){
                    if(newLead.OwnerId == vipCustomerAssignmentUser[0].Id){
                        leadIds_Current.add(newLead.Id);
                    }
                }
                
                if(!leadIds_Current.isEmpty())
                    shareVIPLeads(leadIds_Current);
                
            }
        }
        
        Lead oldRecord;
        if(oldMap <> null){
            if(vipCustomerAssignmentUser <> null && !vipCustomerAssignmentUser.isEmpty()){
                for(Lead newLead : (List<Lead>)newList){
                    oldRecord = (Lead)oldMap.get(newLead.Id);
                    if(newLead.OwnerId == vipCustomerAssignmentUser[0].Id && newLead.OwnerId <> oldRecord.OwnerId){
                        leadIds_Current.add(newLead.Id);
                    }
                }
                
                if(!leadIds_Current.isEmpty())
                    shareVIPLeads(leadIds_Current);
                
            }
            
        }
    }
    // Assign leads to Broker Queue..  
    /*public static void assignBrokerQueue(List<SObject> otherLeads) {

List<Lead> leadsToAssign = new List<Lead>();
for (SObject sObj : otherLeads) {
Lead ld = (Lead)sObj;
if (ld.LeadSource == 'Broker Portal') {
leadsToAssign.add(ld);
}
}

if (leadsToAssign.isEmpty()) {
return;
}

Group queueRecord = [SELECT Id FROM Group WHERE DeveloperName = :Constants.SALES_OPERATIONS_BROKERQUEUE_API_NAME AND Type = 'Queue' LIMIT 1];

Id queueId = queueRecord.Id;

for (Lead ld : leadsToAssign) {
ld.OwnerId = queueId;
}
}*/
    public static void shareVIPLeads(set<ID> leadIDs){
        list<Group> VIPGroup = [select id,name, DeveloperName,Type from Group where type ='Regular' and DeveloperName = 'VIP_Managers'];
        list<LeadShare> shareRecordToBeCreated = new list<LeadShare> ();
        
        
        if(!VIPGroup.isEmpty()){
            map<id,LeadShare> existingShareRecords = new map<id,LeadShare>();
            for(LeadShare existingRecord : [select id,LeadId from LeadShare where LeadId in :leadIDs and UserOrGroupId=:VIPGroup[0].Id ]){
                existingShareRecords.put(existingRecord.LeadId,existingRecord);
            }
            for(Id tempLeadID : leadIDs){
                if(!existingShareRecords.containsKey(tempLeadID)){
                    shareRecordToBeCreated.add(new LeadShare(LeadAccessLevel ='Edit', LeadId=tempLeadID,RowCause='Manual',UserOrGroupId=VIPGroup[0].Id));
                } 
            }   
            if(!shareRecordToBeCreated.IsEmpty()){
                database.insert(shareRecordToBeCreated,false);
            }
        }
    }
    
    public static void updatePhone(List<Lead> newList){
        for(Lead newLead : (List<Lead>)newList){
            newLead.Call_Task_Milestone__c = 1;
            if(String.isBlank(newLead.MobilePhone) && String.isNotBlank(newLead.Phone)){
                newLead.MobilePhone = newLead.Phone;
                newLead.MobilePhone = (newLead.MobilePhone).replace(' ','');
            }
            if(String.isNotBlank(newLead.Email)){
                newLead.Email = (newLead.Email).toLowerCase();
            }
        }
    }
    
    public static void createDocumentRecords(List<SObject> newList){ // call this After Insert.
        
        list<Documents__c> lstDocumentsCurrent = new list<Documents__c>();
        lstDocumentsCurrent = DocumentsUtility.getDocumentsForSObject('Lead');
        if(!lstDocumentsCurrent.isEmpty()){
            list<Documents__c> lstDocumentsToInsert = new list<Documents__c>();
            for(Lead soObj : (List<Lead>)newList){
                for(Documents__c doc: lstDocumentsCurrent){
                    Documents__c tempD = doc.clone();
                    tempD.Lead__c = soObj.Id;
                    lstDocumentsToInsert.add(tempD);
                }
            }
            if(!lstDocumentsToInsert.isEmpty()){
                insert lstDocumentsToInsert;
            }
        }
    }
    
    public static void autoCreate_and_autoClose_TasksTest(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){ // Call this After Insert and Before Update.
        
        list<User> lstUsers_SalesManagementProfile = [Select Id, Profile.Name from User where Profile.Name =: Constants.SALES_MANAGEMENT_PROFILE_NAME];
        set<string> lstUser_IDs_SalesManagementProfile = new set<string>();
        
        if(lstUsers_SalesManagementProfile <> null && !lstUsers_SalesManagementProfile.isEmpty()){
            for(User usr: lstUsers_SalesManagementProfile){
                lstUser_IDs_SalesManagementProfile.add(usr.Id);
            }
        }
        
        set<string> leadIDs_CurrentContext = new set<string>();
        map<string, string> mp_leadID_LeadOwnerID = new map<string, string>();
        
        for(Lead newLead : (List<Lead>)newList){
            
            String newOwnerIDString = String.valueOf(newLead.OwnerId);
            Lead oldRecord;
            if(oldMap <> null){ oldRecord = (Lead)oldMap.get(newLead.Id);
                              }
            
            if( (oldMap == null && newOwnerIDString.startsWith('005')) || (oldMap <> null && newOwnerIDString.startsWith('005') && oldRecord.OwnerId <> newLead.OwnerId && !lstUser_IDs_SalesManagementProfile.isEmpty() && lstUser_IDs_SalesManagementProfile.contains(newLead.OwnerId)) ){ // If the context is Insert OR Update plus Owner is changed plus Owner is not a Queue and has Sales Management Profile..
                
                leadIDs_CurrentContext.add(newLead.Id);
                mp_leadID_LeadOwnerID.put(newLead.Id, newLead.OwnerId);
                
            }
            
        }
        
        if(leadIDs_CurrentContext <> null && !leadIDs_CurrentContext.isEmpty()){
            
            // Auto Close Existing System Created Tasks and Auto Create New tasks for New Lead Owners..
            
            list<Task> lst_Existing_SysGenerated_Tasks = [Select Id, whoId, OwnerId, Subject, System_Created__c, Status from Task where whoId in: leadIDs_CurrentContext and System_Created__c = true and isClosed =false];
            list<Task> lst_Tasks_to_AutoClose = new list<Task>();
            
            if(lst_Existing_SysGenerated_Tasks <> null && !lst_Existing_SysGenerated_Tasks.isEmpty()){
                for(Task tsk: lst_Existing_SysGenerated_Tasks){
                    Task tsk_to_update = new Task();
                    tsk_to_update.Id = tsk.Id;
                    tsk_to_update.Status = Constants.TASK_STATUS_AUTO_CLOSED;
                    
                    lst_Tasks_to_AutoClose.add(tsk_to_update);
                }
                
                if(lst_Tasks_to_AutoClose <> null && !lst_Tasks_to_AutoClose.isEmpty()){
                    update lst_Tasks_to_AutoClose; // Auto Close Existing System Created Tasks 
                }
            }
            
            list<Task> lst_New_Tasks_to_Create = new List<Task>();
            
            if(mp_leadID_LeadOwnerID <> null && !mp_leadID_LeadOwnerID.isEmpty()){
                
                DateTime addHoursToTaskDueDate;
                list<BusinessHours> orgBusinessHours = [select Id from BusinessHours where IsActive = true and IsDefault=true];
                General_Parameters__mdt gp = General_Parameters__mdt.getInstance('Task_SLA_Time');
                integer taskSLATime = integer.valueOf(gp.Value__c);
                Long interval =  taskSLATime * 60 * 60 * 1000;
                addHoursToTaskDueDate = BusinessHours.add( orgBusinessHours[0].id , system.now() , interval  );
                Date dueDate = Date.newInstance(addHoursToTaskDueDate.year(), addHoursToTaskDueDate.month(), addHoursToTaskDueDate.day());
                
                for(String leadId: leadIDs_CurrentContext){
                    Task newTask = new Task();
                    newTask.whoId = leadId;
                    newTask.OwnerId = mp_leadID_LeadOwnerID.containsKey(leadId)? mp_leadID_LeadOwnerID.get(leadId) : null;
                    newTask.Subject = Constants.TASK_SUBJECT_FOR_LEAD_FOLLOWUP;
                    newTask.ActivityDate = dueDate;
                    newTask.Status = Constants.TASK_STATUS_OPEN;
                    newTask.System_Created__c = true;
                    
                    lst_New_Tasks_to_Create.add(newTask);
                }
                
                if(lst_New_Tasks_to_Create <> null && !lst_New_Tasks_to_Create.isEmpty()){
                    insert lst_New_Tasks_to_Create; // Auto Create New Tasks for New Owners..
                    
                }
            }         
            
        }        
    }    
    //v1.3 start
    public static void validateLeadOnConvert(List<Lead> newLeads) {
        for (Lead ld : newLeads) {
            String errorMsg = validateRequiredFieldsForConversion(ld);
            
            if (String.isBlank(errorMsg)) {
                errorMsg = checkDuplicateAccountConversion(ld);
            }
            
            if (String.isNotBlank(errorMsg)) {
                ld.addError(errorMsg);
            }
        }
    }
    private static String validateRequiredFieldsForConversion(Lead ld) {
        String errorMsg;
        if (!String.isBlank(ld.Company) && String.isBlank(ld.UnifiedNumber__c)) {
            errorMsg = 'Unified Number is required when Company is provided during Lead conversion.';
        }
        return errorMsg;
    }
    private static String checkDuplicateAccountConversion(Lead ld) {
        List<String> orConditions = new List<String>();
        List<Account> accList = [Select Id,CreatedDate,RecordType.Name from Account Where Id =: ld.ConvertedAccountId];
        System.debug('accList: '+accList);
        //System.debug('Related_Lead_Id__c: '+accList[0].Related_Lead_Id__c);
        if(!accList.isEmpty() && accList[0].CreatedDate.date() < Date.Today()){ //accList[0].Related_Lead_Id__c != ld.Id 24 < 25
            return null;
        }
        if (String.isNotBlank(ld.Company) && String.isNotBlank(ld.UnifiedNumber__c) 
            && accList[0].CreatedDate.date() <= Date.Today() && accList[0].RecordType.Name != 'Broker Agency') {
                // Ensure it's an organization account (not person account)
                String orgQuery = 'SELECT Id, Name, UnifiedNumber__c ' +
                    'FROM Account WHERE UnifiedNumber__c = \'' +
                    String.escapeSingleQuotes(ld.UnifiedNumber__c) + '\'' +
                    ' AND Id != \'' + ld.ConvertedAccountId + '\' ' +
                    'AND IsPersonAccount = false ' + 'LIMIT 1';
                
                System.debug('orgQuery: '+orgQuery);
                List<Account> orgAcc = Database.query(orgQuery);
                if (!orgAcc.isEmpty()) {
                    return 'Account already exist: Unified Number: ' + ld.UnifiedNumber__c;
                }
            }
        else {
            // Person Account logic
            if (String.isNotBlank(ld.Email)) {
                orConditions.add('PersonEmail = \'' + String.escapeSingleQuotes(ld.Email) + '\'');
            }
            
            if (String.isNotBlank(ld.UAEResidentStatus__c) && 
                ld.UAEResidentStatus__c.equalsIgnoreCase('Resident') && 
                String.isNotBlank(ld.EIDNumber__c)) {
                    orConditions.add('EIDNumber__pc = \'' + String.escapeSingleQuotes(ld.EIDNumber__c) + '\'');
                }
            
            if (String.isNotBlank(ld.PassportNumber__c)) {
                orConditions.add('PassportNumber__pc = \'' + String.escapeSingleQuotes(ld.PassportNumber__c) + '\'');
            }
            
            if (!orConditions.isEmpty()) {
                String query = 'SELECT Id, PersonEmail, EIDNumber__pc, PassportNumber__pc ' +
                    'FROM Account WHERE (' + String.join(orConditions, ' OR ') + ')' +
                    ' AND Id != \'' + ld.ConvertedAccountId + '\' ' +
                    'AND IsPersonAccount = true ' + 'LIMIT 1';
                
                List<Account> existingAcc = Database.query(query);
                
                if (!existingAcc.isEmpty()) {
                    Account acc = existingAcc[0];
                    String errorMsg = 'Account already exist: Please use existing account ';
                    
                    if (String.isNotBlank(ld.UAEResidentStatus__c) && 
                        ld.UAEResidentStatus__c.equalsIgnoreCase('Resident') && 
                        String.isNotBlank(ld.EIDNumber__c) && acc.EIDNumber__pc == ld.EIDNumber__c) {
                            errorMsg += 'EID Number: ' + ld.EIDNumber__c;
                        } else if (String.isNotBlank(ld.PassportNumber__c) && acc.PassportNumber__pc == ld.PassportNumber__c) {
                            errorMsg += 'Passport Number: ' + ld.PassportNumber__c;
                        } else if (String.isNotBlank(ld.Email) && acc.PersonEmail == ld.Email) {
                            errorMsg += 'Email: ' + ld.Email;
                        }
                    
                    return errorMsg;
                }
            }
        }
        return null;
    }  
    //v1.3 end
    
    //V1.5 Begin  from endev
    public static void copyMaskedFieldsBeforeInsert(List<SObject> newList)
    {system.debug('debug: in LeadTriggerHelper.copyMaskedFieldsBeforeInsert method');
     List<Lead> newLead = (List<Lead>)newList; 
     for (Lead rec : newLead) {
         
         if(rec.Phone != null) {rec.En_Phone__c = rec.Phone;}
         else if(rec.En_Phone__c != null) {rec.Phone = rec.En_Phone__c;}
         
         if(rec.Email != null) {rec.En_Email__c = rec.Email;}
         else if(rec.En_Email__c != null) {rec.Email = rec.En_Email__c;}
         
         if(rec.EIDNumber__c != null) {rec.En_EIDNumber__c = rec.EIDNumber__c;}
         else if(rec.En_EIDNumber__c != null) {rec.EIDNumber__c = rec.En_EIDNumber__c;} 
         
         if(rec.PassportNumber__c != null) {rec.En_PassportNumber__c = rec.PassportNumber__c;}
         else if(rec.En_PassportNumber__c != null) {rec.PassportNumber__c = rec.En_PassportNumber__c;}
         
         if(rec.Nationality__c != null) {rec.En_Nationality__c = rec.Nationality__c;}
         else if(rec.En_Nationality__c != null) {rec.Nationality__c = rec.En_Nationality__c;} 
         
         if(rec.MobilePhone != null) {rec.En_MobilePhone__c = rec.MobilePhone;}
         else if(rec.En_MobilePhone__c != null) {rec.MobilePhone = rec.En_MobilePhone__c;}
         
         if(rec.SecondaryMobile__c != null) {rec.En_SecondaryMobile__c = rec.SecondaryMobile__c;}
         else if(rec.En_SecondaryMobile__c != null) {rec.SecondaryMobile__c = rec.En_SecondaryMobile__c;}
     }
    }
    
    public static void copyMaskedFieldsBeforeUpdate(Map<Id,SObject> newMap, Map<Id, SObject> oldMap) // from beforeUpdate
    {system.debug('debug: in LeadTriggerHelper.copyMaskedFieldsBeforeUpdate method');
     //Map<Id,Lead> newLeads = new Map<Id, Lead>(newMap);
     //Map<Id,Lead> newLeads = (Map<Id,Lead>)newMap;
     // system.debug('debug: newLeads'+ newLeads);
     //Map<Id,Lead> oldLeads = new Map<Id, Lead>(oldMap);
     // Map<Id,Lead> oldLeads = (Map<Id,Lead>)oldMap;
     
     for(Lead leadrecords : (List<Lead>)newMap.values()){
         
         Lead oldRec =(Lead) oldMap.get(leadrecords.Id);
         
         system.debug('debug: oldRec.Phone'+ oldRec.Phone);
         system.debug('debug: newRec.Phone'+ leadrecords.Phone);
         system.debug('debug: newRec.En_Phone__c'+ leadrecords.En_Phone__c);
         
         if(leadrecords.Phone != oldRec.Phone && leadrecords.Phone != null){
             leadrecords.En_Phone__c = leadrecords.Phone;
         }
         else if(leadrecords.En_Phone__c != oldRec.En_Phone__c && leadrecords.En_Phone__c != null){
             leadrecords.Phone = leadrecords.En_Phone__c;
         }
         
         system.debug('debug: newRec.En_Email__c'+ leadrecords.En_Email__c); 
         
         if(leadrecords.Email != oldRec.Email && leadrecords.Email != null){
             leadrecords.En_Email__c = leadrecords.Email;
         }
         else if(leadrecords.En_Email__c != oldRec.En_Email__c && leadrecords.En_Email__c != null){
             leadrecords.Email = leadrecords.En_Email__c;
         }
         
         system.debug('debug: oldRec.EIDNumber__c'+ oldRec.EIDNumber__c);
         system.debug('debug: newRec.EIDNumber__c'+ leadrecords.EIDNumber__c);
         system.debug('debug: newRec.En_EIDNumber__c'+ leadrecords.En_EIDNumber__c);
         
         if (leadrecords.EIDNumber__c != oldRec.EIDNumber__c && leadrecords.EIDNumber__c != null) {
             leadrecords.En_EIDNumber__c = leadrecords.EIDNumber__c;
         }
         else if (leadrecords.En_EIDNumber__c != oldRec.En_EIDNumber__c && leadrecords.En_EIDNumber__c != null) {
             leadrecords.En_EIDNumber__c = leadrecords.En_EIDNumber__c;
         }
         
         system.debug('debug: oldRec.PassportNumber__c'+ oldRec.PassportNumber__c);
         system.debug('debug: newRec.PassportNumber__c'+ leadrecords.PassportNumber__c);
         system.debug('debug: newRec.En_PassportNumber__c'+ leadrecords.En_PassportNumber__c);
         
         if(leadrecords.PassportNumber__c != oldRec.PassportNumber__c && leadrecords.PassportNumber__c != null){
             leadrecords.En_PassportNumber__c = leadrecords.PassportNumber__c;   
         }
         else if(leadrecords.En_PassportNumber__c != oldRec.En_PassportNumber__c && leadrecords.En_PassportNumber__c != null){
             leadrecords.PassportNumber__c = leadrecords.En_PassportNumber__c;   
         }
         
         system.debug('debug: oldRec.Nationality__c'+ oldRec.Nationality__c);
         system.debug('debug: newRec.Nationality__c'+ leadrecords.Nationality__c);
         system.debug('debug: newRec.En_Nationality__c'+ leadrecords.En_Nationality__c);
         
         if(leadrecords.Nationality__c != oldRec.Nationality__c && leadrecords.Nationality__c != null){
             leadrecords.En_Nationality__c = leadrecords.Nationality__c;
         }
         else if(leadrecords.En_Nationality__c != oldRec.En_Nationality__c && leadrecords.En_Nationality__c != null){
             leadrecords.Nationality__c = leadrecords.En_Nationality__c;
         }
         
         system.debug('debug: oldRec.MobilePhone'+ oldRec.MobilePhone);
         system.debug('debug: newRec.MobilePhone'+ leadrecords.MobilePhone);
         system.debug('debug: newRec.En_MobilePhone__c'+ leadrecords.En_MobilePhone__c);
         
         if(leadrecords.MobilePhone != oldRec.MobilePhone && leadrecords.MobilePhone != null){
             leadrecords.En_MobilePhone__c = leadrecords.MobilePhone;
         }
         else if(leadrecords.En_MobilePhone__c != oldRec.En_MobilePhone__c && leadrecords.En_MobilePhone__c != null){
             leadrecords.MobilePhone = leadrecords.En_MobilePhone__c;
         }
         
         system.debug('debug: oldRec.SecondaryMobile__c'+ oldRec.SecondaryMobile__c);
         system.debug('debug: newRec.SecondaryMobile__c'+ leadrecords.SecondaryMobile__c);
         system.debug('debug: newRec.En_SecondaryMobile__c'+ leadrecords.En_SecondaryMobile__c);
         
         if(leadrecords.SecondaryMobile__c != oldRec.SecondaryMobile__c && leadrecords.SecondaryMobile__c != null){
             leadrecords.En_SecondaryMobile__c = leadrecords.SecondaryMobile__c;
         }
         else if(leadrecords.En_SecondaryMobile__c != oldRec.En_SecondaryMobile__c && leadrecords.En_SecondaryMobile__c != null){
             leadrecords.SecondaryMobile__c = leadrecords.En_SecondaryMobile__c;
         }
         
     }
    }
    
    //V1.5 End
    
    //V2.4 begins from staguat
    // Assign leads to Broker Queue..  
    public static void assignBrokerQueue(List<SObject> otherLeads) {
        List<Lead> leadsToUpdate = new List<Lead>();
        
        for (SObject sObj : otherLeads) {
            Lead ld = (Lead)sObj;
            if (ld.LeadSource == 'Broker Portal') {
                leadsToUpdate.add(new Lead(
                    Id = ld.Id,
                    OwnerId = getBrokerQueueId()
                ));
            }
        }
        if (!leadsToUpdate.isEmpty()) {
            update leadsToUpdate;
        }
    }
    
    // assign broker
    private static Id brokerQueueId;
    
    private static Id getBrokerQueueId() {
        if (brokerQueueId == null) {
            brokerQueueId = [SELECT Id FROM Group WHERE DeveloperName = :Constants.SALES_OPERATIONS_BROKERQUEUE_API_NAME AND Type = 'Queue' LIMIT 1].Id;
        }
        return brokerQueueId;
    }  // V 2.4 ends
    
}