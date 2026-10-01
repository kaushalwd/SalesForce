/**********************************************************************************************************************
* Name               : OIC_DPGUnitsAPIHelper                                                        
* Description        : Helper class.
* Usage              : 
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                08 04 2025      Initial Draft       
* 1.1           Suresh   	                20 10 2025      Payment Plan Id Updated
* 1.2           Suresh   	                20 01 2026      FacadeStyle__c, FacadeType__c added
* 1.3           Suresh   	                12 05 2026      total price updated
* 1.4           upendra  	                02 07 2026      Broker-aware unit access: units are now filtered by the
*                                                            broker's bucket group membership and agency allocation
*                                                            when the running user is a Broker Community user
*                                                            (reuses OIC_DPGIntegrationHelper.getBrokerContactContext()).
*                                                            Added debug logs for broker flow troubleshooting.
***********************************************************************************************************************/
global without sharing class  OIC_DPGUnitsAPIHelper {

    public static List<Unit__c> getUnits(String CustomerName, String ProfileName, String ProjectId) {
        List<Unit__c> lst_Unit = new List<Unit__c>();
        try {
            // Determine if the running user is a Broker Community user.
            // Reuses the same detection logic used for Broker leads so both flows
            // agree on what counts as a "broker" (Profile = Modon - Partner Community
            // Login User AND Contact Broker Type in Owner/Agent/Agency Admin).
            Contact brokerContact = MBP_DPGCreateLeadAPI.getBrokerContactContext();
            Boolean isBroker = (brokerContact != null);
            System.debug('getUnits >>>>>>>>>>>>>>   isBroker >> '+isBroker);
            if(isBroker){
                System.debug('getUnits >>>>>>>>>>>>>>   brokerContact.Id >> '+brokerContact.Id
                              +' | brokerContact.AccountId >> '+brokerContact.AccountId
                              +' | brokerContact.Name >> '+brokerContact.Name);
            }

            List<UnitAccessConfig__mdt> lst_UAMDT = [select ProfileName__c, SOQLQuery__c from UnitAccessConfig__mdt 
                                                     where ProfileName__c = :ProfileName];
            UnitAccessConfig__mdt obj_UAMDT = new UnitAccessConfig__mdt();
            if(lst_UAMDT.size() > 0){
                obj_UAMDT = lst_UAMDT.get(0);
            }
            System.debug('getUnits >>>>>>>>>>>>>>   obj_UAMDT >> '+obj_UAMDT);

            // Bind variables must stay in method scope for Database.query() below.
            Set<Id> userBucketIds = new Set<Id>();
            String excludedProj = '%Ras El Hekma%';
            Id brokerAccountId = (isBroker && brokerContact != null) ? brokerContact.AccountId : null;

            //1.2 changes — dynamic SOQL uses Apex bind variables only (no string concatenation of inputs)
            String baseQuery = 
                'SELECT Id, Name, Status__c, BlockedBy__r.Name, BlockedFor__r.Name, BlockedFor__r.Email, BlockReason__c, BlockUntil__c, ' +
                '       Phase__r.Name, InventoryStatus__c, Number_of_Bedrooms__c, FloorNumber__c, TotalArea__c, FacadeStyle__c, FacadeType__c, ' +
                '       TotalGFAsqm__c, TotalGrossSellableAreaGSA__c, TotalPrice__c, PlotAreasqm__c, PlotNo__c, MDPlotId__c, ' +
                '       Phase__c, Phase__r.Project__r.Id, Phase__r.Project__r.Name, Bucket__c, Bucket__r.Name, ApprovalStatus__c , Typology__c, ' +
                '       Source_Entity__c, Allocate_to_Agency__c ' +
                'FROM Unit__c WHERE (NOT Phase__r.Project__r.Name LIKE :excludedProj) ';
            
            if(!String.isBlank(ProjectId)){
                baseQuery += ' AND Phase__r.Project__r.Id = :ProjectId';
            }

            if(isBroker){
                // ---- Broker flow: bucket-group + agency based access rules ----
                Set<String> userGroupIds = new Set<String>();
                for (GroupMember gm : [SELECT GroupId FROM GroupMember WHERE UserOrGroupId =:UserInfo.getUserId()]) {
                    userGroupIds.add((String) gm.GroupId);
                    userGroupIds.add(((String) gm.GroupId).substring(0, 15));
                }
                System.debug('getUnits >>>>>>>>>>>>>>   userGroupIds >> '+userGroupIds);

                for(Bucket__c b : [SELECT Id FROM Bucket__c WHERE Bucket_Group_Id__c IN :userGroupIds]){
                    userBucketIds.add(b.Id);
                }
                System.debug('getUnits >>>>>>>>>>>>>>   userBucketIds >> '+userBucketIds);

                baseQuery += ' AND Bucket__c IN :userBucketIds';
                baseQuery += ' AND Status__c = \'Available\' AND BlockedFor__c = null AND Source_Entity__c != \'Modon - Egypt\'';

                if(brokerAccountId != null){
                    baseQuery += ' AND (Allocate_to_Agency__c = null OR Allocate_to_Agency__c = :brokerAccountId)';
                } else {
                    baseQuery += ' AND Allocate_to_Agency__c = null';
                }
            } else {
                // ---- Normal / non-broker flow: unchanged from before ----
                if(!String.isBlank(CustomerName)){
                    baseQuery += ' AND (BlockedFor__c = null OR BlockedFor__r.Username = :CustomerName)';
                }
                if (!String.isBlank(obj_UAMDT.SOQLQuery__c)) {
                    baseQuery += obj_UAMDT.SOQLQuery__c;
                }
            }
            
            baseQuery += ' ORDER BY Name ASC';
            System.debug('getUnits >>>>>>>>>>>>>>   '+baseQuery);

            Map<String, Object> binds = new Map<String, Object>{
                'excludedProj' => excludedProj
            };
            if (!String.isBlank(ProjectId)) {
                binds.put('ProjectId', ProjectId);
            }
            if (isBroker) {
                binds.put('userBucketIds', userBucketIds);
                if (brokerAccountId != null) {
                    binds.put('brokerAccountId', brokerAccountId);
                }
            } else {
                if (!String.isBlank(CustomerName)) {
                    binds.put('CustomerName', CustomerName);
                }
            }

            lst_Unit = Database.queryWithBinds(baseQuery, binds, AccessLevel.SYSTEM_MODE);
            System.debug('getUnits >>>>>>>>>>>>>>   lst_Unit.size() >> '+lst_Unit.size());
        } catch (Exception ex) {
            System.debug('Error fetching units: ' + ex.getMessage());
            System.debug('Error fetching units - stack trace: ' + ex.getStackTraceString());
        }
        return lst_Unit;
    }

    public static List<Unit_Option__c> getUnitOptions(Set<Id> set_UnitId){
       List<Unit_Option__c> lst_UnitOption = new List<Unit_Option__c>();
        try{
            if(set_UnitId != null && set_UnitId.size() > 0){
               lst_UnitOption = [Select Id, Name, AdditionalPrice__c, AED_SQM__c, AreaUnitofMeasure__c, BalconyArea__c, BasementArea__c, 
                                 BasementParkingArea__c, BasePrice__c, Category__c, Description__c, Exterior__c, FacadeType__c, 
                                 FirstFloorArea__c, FloorAreaRatioFAR__c, GrossFloorAreaGFA__c, GroundFloorArea__c, Interior__c, 
                                 Internal_Area__c, NumberofBedrooms__c, NumberofCarParks__c, Phase__c, PlotAreasqm__c, PlotNo__c, 
                                 SecondFloorArea__c, SubCategory__c, TerraceArea__c, TotalGFAsqm__c, TotalGrossSellableAreaGSA__c, 
                                 TotalPrice__c, Type__c, Typology__c, Unit__c, Model__c 
                                 from Unit_Option__c where Unit__c IN :set_UnitId]; 
            }            
        }catch(Exception exe){
            System.debug('Error fetching unit options: ' + exe.getMessage());
        }
        return lst_UnitOption;
    }
    
    public static List<PaymentPlan__c> getAllPaymentPlans(){
        List<PaymentPlan__c> lst_PaymentPlans = new List<PaymentPlan__c>();
        try{
            lst_PaymentPlans = [SELECT Id, Name, Status__c, PaymentInstallment__c, StartDate__c, ExpiryDate__c, 
                                Project__c, Phase__c, Phase__r.Name, Phase__r.Id, Phase__r.Project__c, PaymentPlanStructure__c 
                                FROM PaymentPlan__c WHERE Status__c = 'Active' AND Online_Sales__c = true AND (Project__c != null OR Phase__c != null) ];
                        
        }catch(Exception exe){
            System.debug('Error fetching payment plans: ' + exe.getMessage());
        }
        return lst_PaymentPlans;
    }     
    
  //where Status__c = 'Available' and Sub_Status__c = 'Assigned' and ApprovalStatus__c = 'Released'  
  
   public static List<PaymentPlan__c> getPaymentPlans(String unitId){
        List<PaymentPlan__c> lst_PaymentPlans = new List<PaymentPlan__c>();
        try{
            if(String.isNotBlank(unitId)){
                String projectName = '';
                List<Unit__c> lst_Units = [select Id, Name, Phase__r.Project__r.Name from Unit__c where Id = :unitId];
                if(lst_Units.size() > 0){
                    Unit__c obj_Unit = lst_Units.get(0);
                    if(obj_Unit != null && obj_Unit.Phase__r != null && obj_Unit.Phase__r.Project__r != null
                       && String.isNotBlank(obj_Unit.Phase__r.Project__r.Name)){
                        projectName = obj_Unit.Phase__r.Project__r.Name;   
                        lst_PaymentPlans = [SELECT Id, Name, Status__c, PaymentInstallment__c, StartDate__c, ExpiryDate__c, 
                                			Project__c, PaymentPlanStructure__c FROM PaymentPlan__c WHERE Status__c = 'Active' AND Online_Sales__c = true and Project__r.Name =: projectName
                                            limit 1];
                    }
                }
            }           
        }catch(Exception exe){
            System.debug('Error fetching payment plans for unit: ' + exe.getMessage());
        }
        return lst_PaymentPlans;
   }    
}