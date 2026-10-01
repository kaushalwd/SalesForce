/**********************************************************************************************************************
* Name               : ManageInventoryLWCController                                                        
* Description        : This class is used as controller for LWC (Manage inventory button on unit list view)
* Usage              : manageInventory LWC                                                          
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                               Date            Comment                                                                       
* 1.1           prateek.b.bansal@pwc.com                            26 Feb 2024      Initial Draft       
* 1.2           manoj.kumar@modon.com                               18 Dec 2024      Updateing as Per new Inventory status/Unit status changes 
* 1.2           krishnachaitanya.ramadugu@activemindsit.com         15 Jan 2024      Updated as per new UI changes
* 2.1           Modon IT                                            15 Aug 2025      Added method to handle bucket implementation
* 2.2           Modon IT                                            15 Jul 2026      Block unit actions while a booking-fee payment is in progress
* 2.3           Modon IT                                            16 Jul 2026      Expose booking-fee payment progress for reserved-but-unpaid units
* 2.4           Modon IT                                            16 Jul 2026      Approve/revoke partial-payment booking per unit
* 2.7           Modon IT                                            16 Jul 2026      Hide partial-booking approval once a live Sales Order exists
* 3.0           Arvind                                               23 Jul 2026      Added Floor, Zone and Unit Classification filters (getUnitData params,
*                                                                                     ResponseWrapper options, loadInventories population)
******************************************************************************************************************/
public with sharing class ManageInventoryLWCController {

    @AuraEnabled
    public static ResponseWrapper updateRejectedUnits(List<Id> unitIds, String comment){
        // List<Unit__c> unitLst = new List<Unit__c>();
        // for(String unitId : unitIds){
        //     Unit__c tempUnit = new Unit__c(Id = unitId, ApprovalStatus__c = 'Rejected');
        //     tempUnit.Status__c = 'Draft';
        //     tempUnit.BlockedFor__c = null;
        //     tempUnit.BlockUntil__c = null;
        //     tempUnit.BlockedBy__c = null;
        //     tempUnit.Blocked_Time__c = null;
        //     tempUnit.BlockComment__c = '';
        //     tempUnit.RejectionComment__c = comment;
        //     unitLst.add(tempUnit);
        // }

        // ResponseWrapper wrapperObj = new ResponseWrapper();
        // try {
        //     UPDATE unitLst;
        //     wrapperObj.isSuccess = true;
        // } catch (Exception ex) {
        //     system.debug(ex.getMessage());
        //     wrapperObj.isSuccess = false;
        //     wrapperObj.errorMsg = ex.getMessage();
        // }
        return null;
    }

    // 2.2 - Units an agent is currently collecting booking fees for. The hold is time-boxed and evaluated
    // live, so an EXPIRED hold is treated as free - the flag is only cleared later by the
    // Unit_Release_Expired_Payment_Hold flow, which is why the expiry check is what matters, not the flag.
    // Standard UAE only, like every other consumer of this hold. Mirrors UnitBookingJourneyController.
    private static List<String> heldUnitNames(List<Id> unitIds){
        List<String> held = new List<String>();
        if(unitIds == null || unitIds.isEmpty()){
            return held;
        }
        for(Unit__c u : [SELECT Name FROM Unit__c
                         WHERE Id IN :unitIds
                           AND Payment_In_Progress__c = true
                           AND Payment_Hold_Expiry__c >= :System.now()
                           AND Source_Entity__c != 'Modon - Egypt'
                         ORDER BY Name]){
            held.add(u.Name);
        }
        return held;
    }

    // 2.2 - Refuse the whole action while any selected unit is being paid for, so an admin cannot pull a unit
    // back from under an agent mid-payment. Returns null when there is nothing to block.
    private static ResponseWrapper rejectIfBeingPaidFor(List<Id> unitIds){
        List<String> held = heldUnitNames(unitIds);
        if(held.isEmpty()){
            return null;
        }
        ResponseWrapper wrapperObj = new ResponseWrapper();
        wrapperObj.isSuccess = false;
        // Not a failure - the admin just needs to recheck. messageVariant tells the LWC to say so politely
        // rather than raise an error toast.
        wrapperObj.messageVariant = 'warning';
        wrapperObj.errorMsg = 'A payment is in progress for ' + String.join(held, ', ')
            + '. Please recheck your selection and try again.';
        return wrapperObj;
    }

    // start Reserved payment progress badge
    // 2.3 - Paid % for reserved units that are only part-paid. Matched to the unit's current opp.
    @AuraEnabled
    public static Map<Id, Decimal> getReservedPaymentProgress(List<Id> unitIds){
        Map<Id, Decimal> percentByUnit = new Map<Id, Decimal>();
        if(unitIds == null || unitIds.isEmpty()){ return percentByUnit; }

        Map<Id, Id> unitToOpp = new Map<Id, Id>();
        for(Unit__c u : [SELECT Id, Opportunity__c FROM Unit__c
                         WHERE Id IN :unitIds AND Status__c = 'Reserved' AND Opportunity__c != null]){
            unitToOpp.put(u.Id, u.Opportunity__c);
        }
        if(unitToOpp.isEmpty()){ return percentByUnit; }

        Map<Id, Decimal> paidByUnit = new Map<Id, Decimal>();
        Map<Id, Decimal> totalByUnit = new Map<Id, Decimal>();
        for(Booking_Fee_Line__c bfl : [SELECT Unit__c, Opportunity__c, Total_Amount__c, Total_Paid_Amount__c
                                       FROM Booking_Fee_Line__c WHERE Unit__c IN :unitToOpp.keySet()]){
            if(unitToOpp.get(bfl.Unit__c) != bfl.Opportunity__c){ continue; }
            Decimal paid  = bfl.Total_Paid_Amount__c == null ? 0 : bfl.Total_Paid_Amount__c;
            Decimal total = bfl.Total_Amount__c == null ? 0 : bfl.Total_Amount__c;
            paidByUnit.put(bfl.Unit__c, (paidByUnit.containsKey(bfl.Unit__c) ? paidByUnit.get(bfl.Unit__c) : 0) + paid);
            totalByUnit.put(bfl.Unit__c, (totalByUnit.containsKey(bfl.Unit__c) ? totalByUnit.get(bfl.Unit__c) : 0) + total);
        }

        for(Id unitId : totalByUnit.keySet()){
            Decimal total = totalByUnit.get(unitId);
            Decimal paid  = paidByUnit.containsKey(unitId) ? paidByUnit.get(unitId) : 0;
            if(total > 0 && paid > 0 && paid < total){
                percentByUnit.put(unitId, (paid / total * 100).setScale(0));
            }
        }
        return percentByUnit;
    }
    // end Reserved payment progress badge

    // start Partial booking approval
    // 2.4 - Management approves (or revokes) partial-payment booking for the selected units. The booking journey
    // reads this flag to open the Book action below full payment. Standard UAE only.
    @AuraEnabled
    public static ResponseWrapper setPartialBookingApproval(List<Id> unitIds, Boolean allow){
        ResponseWrapper wrapperObj = new ResponseWrapper();
        if(unitIds == null || unitIds.isEmpty()){
            wrapperObj.isSuccess = false;
            wrapperObj.errorMsg = 'No units selected.';
            return wrapperObj;
        }
        try{
            List<Unit__c> toUpdate = new List<Unit__c>();
            for(Unit__c u : [SELECT Id FROM Unit__c
                             WHERE Id IN :unitIds AND Source_Entity__c != 'Modon - Egypt']){
                u.Allow_Partial_Booking__c = allow == true;
                toUpdate.add(u);
            }
            update toUpdate;
            wrapperObj.isSuccess = true;
        } catch(Exception ex){
            wrapperObj.isSuccess = false;
            wrapperObj.errorMsg = ex.getMessage();
        }
        return wrapperObj;
    }

    // 2.7 - Units that already have a live Sales Order. Once booked, the approval is spent so we hide Revoke.
    @AuraEnabled
    public static List<Id> getUnitsWithSalesOrder(List<Id> unitIds){
        Set<Id> bookedUnits = new Set<Id>();
        if(unitIds == null || unitIds.isEmpty()){ return new List<Id>(bookedUnits); }
        for(SalesOrder__c so : [SELECT Unit__c FROM SalesOrder__c
                                WHERE Unit__c IN :unitIds
                                AND Status__c NOT IN ('Cancelled', 'System cancelled', 'Voided')]){
            if(so.Unit__c != null){ bookedUnits.add(so.Unit__c); }
        }
        return new List<Id>(bookedUnits);
    }
    // end Partial booking approval

    @AuraEnabled
    public static ResponseWrapper transferBucket(List<Id> unitIds, String bucketId){
        ResponseWrapper blocked = rejectIfBeingPaidFor(unitIds); // 2.2
        if(blocked != null){
            return blocked;
        }
        // List<Unit__c> unitLst = new List<Unit__c>();
        List<Unit__c> unitLst = [SELECT Id, Name, ApprovalStatus__c, Status__c, Sub_Status__c FROM Unit__c WHERE Id IN : unitIds];

        for(Unit__c unitObj : unitLst){
            if(unitObj.ApprovalStatus__c == 'Released' && unitObj.Sub_Status__c == 'Assigned'){
                unitObj.Sub_Status__c = 'Un-Assigned';
                unitObj.BlockedFor__c = null;
                unitObj.BlockedBy__c = null;
                unitObj.BlockUntil__c = null;
                unitObj.BlockComment__c = null;
                unitObj.Blocked_Time__c = null;
            }
            unitObj.Bucket__c = bucketId;
        }

        // for(String unitId : unitIds){
        //     Unit__c tempUnit = new Unit__c(Id = unitId);
        //     tempUnit.Bucket__c = bucketId;
        //     unitLst.add(tempUnit);
        // }
        ResponseWrapper wrapperObj = new ResponseWrapper();
        try {
            UPDATE unitLst;
            wrapperObj.isSuccess = true;
        } catch (Exception ex) {
            system.debug(ex.getMessage());
            wrapperObj.isSuccess = false;
            wrapperObj.errorMsg = ex.getMessage();
        }
        return wrapperObj;
    }

    @AuraEnabled
    public static ResponseWrapper blockSelectedUnits(List<Id> unitIds, String comment, String blockFor, String blockUntil, String bucketId){
        ResponseWrapper blocked = rejectIfBeingPaidFor(unitIds); // 2.2
        if(blocked != null){
            return blocked;
        }
        List<Unit__c> unitLst = new List<Unit__c>();
        blockUntil = blockUntil!='Unlimited'?blockUntil:'8760'; // Added by Ganesh for the option to block a unit for unlimited time i.e. 1yr
        
        //2.1 Added by Prateek (bucket management functionality)
        Id agencyId = null;
        User[] brokerUser = [SELECT Id, AccountId FROM User WHERE Id =: blockFor AND isPartner = true AND AccountId != null AND isActive = true];
        if (!brokerUser.isEmpty()) {
            agencyId = brokerUser[0].AccountId;
        }
                
        for(String unitId : unitIds){
            Unit__c tempUnit = new Unit__c(Id = unitId, ApprovalStatus__c = 'Released');
            tempUnit.Status__c = 'Available';
            tempUnit.Sub_Status__c = 'Assigned';
            tempUnit.BlockedFor__c = agencyId != null ? null : blockFor; //2.1
            tempUnit.BlockedBy__c = UserInfo.getUserId();
            tempUnit.Blocked_Time__c = DateTime.NOW();
            tempUnit.Bucket__c = bucketId;
            tempUnit.Allocate_to_Agency__c = agencyId; //2.1 Added by Prateek (bucket management functionality)
            List<String> tempLst = blockUntil.split(' ');
            if(tempLst.size()>1){
                tempUnit.BlockUntil__c = System.now().addMinutes(Integer.valueOf(tempLst[0]));
            }else{
                tempUnit.BlockUntil__c = System.now().addHours(Integer.valueOf(blockUntil));
            }
            //tempUnit.BlockUntil__c = System.now().addHours(Integer.valueOf(blockUntil));
            tempUnit.BlockComment__c = comment;
            
            unitLst.add(tempUnit);
        }

        ResponseWrapper wrapperObj = new ResponseWrapper();
        try {
            UPDATE unitLst;
            wrapperObj.isSuccess = true;
        } catch (Exception ex) {
            system.debug(ex.getMessage());
            wrapperObj.isSuccess = false;
            wrapperObj.errorMsg = ex.getMessage();
        }
        return wrapperObj;
    }

    @AuraEnabled
    public static ResponseWrapper updateUnitStatus(List<Id> unitIds, String newApprovalStatus, String unitStatus, String bucketId){
        ResponseWrapper blocked = rejectIfBeingPaidFor(unitIds); // 2.2
        if(blocked != null){
            return blocked;
        }
        List<Unit__c> unitLst = new List<Unit__c>();

        for(String unitId : unitIds){
            Unit__c tempUnit = new Unit__c(Id = unitId, ApprovalStatus__c = newApprovalStatus);
            tempUnit.Status__c = unitStatus;
            if(unitStatus=='Available'){
                tempUnit.Sub_Status__c = 'Un-Assigned'; 
            }
            if(newApprovalStatus=='Draft'){
                tempUnit.Sub_Status__c = ''; 
            }
            tempUnit.BlockedFor__c = null;
            tempUnit.BlockUntil__c = null;
            tempUnit.BlockedBy__c = null;
            tempUnit.Blocked_Time__c = null;
            tempUnit.BlockComment__c = '';
            tempUnit.Allocate_to_Agency__c = null; //2.1
            if(String.isNotBlank(bucketId) && newApprovalStatus != 'Draft'){
                tempUnit.Bucket__c = bucketId;
            }else if(newApprovalStatus == 'Draft'){
                tempUnit.Bucket__c = null;
            }
            
            unitLst.add(tempUnit);
        }
        ResponseWrapper wrapperObj = new ResponseWrapper();
        try {
            UPDATE unitLst;
            wrapperObj.isSuccess = true;
        } catch (Exception ex) {
            wrapperObj.isSuccess = false;
            wrapperObj.errorMsg = ex.getMessage();
        }
        return wrapperObj;
    }

    @AuraEnabled//(cacheable=true)
    public static ResponseWrapper loadInventories(){
        ResponseWrapper res = new ResponseWrapper();
        try {
            // ---------- Constants / locals ----------
            String ignoreTestUnits = '%test%';

            // ---------- Build meta options (actions) ----------
            List<Map<String,String>> metaOptionMap = new List<Map<String,String>>();
            for (InventoryItem__mdt mdt : [
                SELECT Id, MasterLabel, Access_Control__c, DeveloperName, Visibility__c
                FROM InventoryItem__mdt
                WHERE Visibility__c = true
            ]) {
                // Keep label/value pairing as before
                metaOptionMap.add(new Map<String,String>{ 'label' => mdt.DeveloperName, 'value' => mdt.MasterLabel });
            }

            // ---------- Build unit status options (prepend All) ----------
            List<Map<String,String>> unitStatusOptionMap = new List<Map<String,String>>();
            unitStatusOptionMap.add(new Map<String,String>{ 'label' => 'All', 'value' => 'All' });
            unitStatusOptionMap.addAll(Utilities_Service.getPicklistOptions('Status__c','Unit__c'));

            // ---------- Bedrooms picklist ----------
            List<Map<String,String>> bedroomValuesOptionMap =
                Utilities_Service.getPicklistOptions('Number_of_Bedrooms__c','Unit__c');

            // ---------- ListView options based on feature permissions ----------
            Boolean hasEndorseAccess = FeatureManagement.checkPermission('Unit_Endorser');
            Boolean hasApprovalAccess= FeatureManagement.checkPermission('Unit_Approver');
            Boolean hasManagerAccess = FeatureManagement.checkPermission('Unit_Manager');

            List<Map<String,String>> listViewMap = new List<Map<String,String>>();
            if (hasEndorseAccess && hasApprovalAccess && hasManagerAccess) {
                listViewMap.add(new Map<String,String>{ 'label' => 'All',        'value' => 'All' });
            }
            if (hasEndorseAccess) {
                listViewMap.add(new Map<String,String>{ 'label' => 'Draft',      'value' => 'Draft' });
                // listViewMap.add(new Map<String,String>{ 'label' => 'Rejected',   'value' => 'Rejected' });
            }
            if (hasApprovalAccess) {
                // listViewMap.add(new Map<String,String>{ 'label' => 'Awaiting Approval', 'value' => 'Awaiting Approval' });
            }
            if (hasManagerAccess) {
                listViewMap.add(new Map<String,String>{ 'label' => 'UnReleased', 'value' => 'UnReleased' });
                listViewMap.add(new Map<String,String>{ 'label' => 'Released',   'value' => 'Released'   });
            }

            // ---------- Project options (prepend All) ----------
            List<Map<String,String>> availableProjectMap = new List<Map<String,String>>();
            List<Project__c> projLst = [SELECT Id, Name FROM Project__c];
            if (!projLst.isEmpty()) {
                availableProjectMap.add(new Map<String,String>{ 'label' => 'All', 'value' => 'All' });
                for (Project__c p : projLst) {
                    availableProjectMap.add(new Map<String,String>{ 'label' => p.Name, 'value' => p.Name });
                }
            }

            // ----------------- Bucket Options -------------------
            List<Bucket__c> buckets = [SELECT Id, Name FROM Bucket__c WHERE Active__c = true];

            // ---------- Fill response lists & defaults ----------
            res.availableProjects = availableProjectMap;
            res.metaoptions       = metaOptionMap;
            res.unitStatusoptions = unitStatusOptionMap;
            res.bedroomoptions    = bedroomValuesOptionMap;
            res.allListView       = listViewMap;
            res.buckets = buckets;

            // start 3.0 - Arvind - 23 Jul 2026 - Floor, Zone, Unit Classification filter options
            // Floor options (picklist)
            res.floorOptions = Utilities_Service.getPicklistOptions('Floor__c','Unit__c');

            // Unit Classification options (picklist)
            res.unitClassificationOptions = Utilities_Service.getPicklistOptions('UnitClassification__c','Unit__c');

            // Zone options (free text field - distinct values)
            List<String> zoneList = new List<String>();
            for (AggregateResult ar : [SELECT Zone__c FROM Unit__c WHERE Zone__c != null GROUP BY Zone__c ORDER BY Zone__c]) {
                zoneList.add((String) ar.get('Zone__c'));
            }
            res.zoneOptions = zoneList;
            // end 3.0

            res.selectedProjects  = !availableProjectMap.isEmpty()
                ? availableProjectMap[0].get('label') // "All"
                : 'All';

            res.selectedListView  = !listViewMap.isEmpty()
                ? listViewMap[0].get('label')        // first allowed view
                : 'All';

            // ---------- Build 1 unified query ----------
            // NOTE: single superset of fields to support all views
            String baseSelect =
                'SELECT Id, Project_Name__c, Name, TotalPrice__c, Status__c, Aging__c, Status_Change_Time__c,' +
                '       IsUnitAvailable__c, Phase__r.Name, Number_of_Bedrooms__c, PlotAreasqm__c, PlotNo__c,' +
                '       ApprovalStatus__c, BlockedFor__r.Name, BlockedBy__r.Name, BlockUntil__c, Blocked_Time__c, Bucket__r.Name, Allocate_to_Agency__r.Name,' + //2.1
                '       Payment_In_Progress__c, Payment_Hold_Expiry__c,' + //2.2 - lets the LWC disable a unit being paid for
                '       Allow_Partial_Booking__c,' + //2.4 - partial booking approval
                '       Floor__c, Zone__c, UnitClassification__c' + // 3.0 - Arvind - 23 Jul 2026 - new filter fields
                '  FROM Unit__c';

            List<String> wheres = new List<String>();
            wheres.add('Name NOT LIKE :ignoreTestUnits');

            // Project filter
            String selectedProjectFilter = res.selectedProjects;
            if (selectedProjectFilter != null && selectedProjectFilter != 'All') {
                wheres.add('Project_Name__c = :selectedProjectFilter');
            }

            // List view filter
            String lv = res.selectedListView;
            if (lv == 'Draft') {
                wheres.add('ApprovalStatus__c = \'Draft\'');
            } else if (lv == 'UnReleased') {
                wheres.add('ApprovalStatus__c = \'UnReleased\'');
            } else if (lv == 'Released') {
                wheres.add('ApprovalStatus__c = \'Released\'');
                // Per your request: show ONLY Available under Released
                wheres.add('Status__c = \'Available\'');
            } // 'All' => no extra filter

            String soql = baseSelect + (wheres.isEmpty() ? '' : ' WHERE ' + String.join(wheres, ' AND '))
                                    + ' ORDER BY Phase__r.Name, Name';

            // SOQL injection fix: bind filter values via queryWithBinds.
            res.unitLst = Database.queryWithBinds(
                soql,
                new Map<String, Object>{
                    'ignoreTestUnits' => ignoreTestUnits,
                    'selectedProjectFilter' => selectedProjectFilter
                },
                AccessLevel.SYSTEM_MODE
            );
            res.isSuccess = true;
            return res;
        } catch (Exception ex) {
            res.isSuccess = false;
            res.errorMsg  = ex.getMessage();
            return res;
        }
    }

   
    
    @AuraEnabled(cacheable=true)
    public static List<Aging_Configuration__mdt> fetchAgingColorMetadata() {
        return [
            SELECT Min_Days__c , Max_Days__c , Color_Code__c 
            FROM Aging_Configuration__mdt
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<User> getFilteredUsers(List<Id> allowedIds) {
        return [SELECT Id, Name FROM User WHERE Id IN :allowedIds];
    }
    
    @AuraEnabled//(cacheable=true)  
    // 3.0 - Arvind - 23 Jul 2026 - added floorNumber, zone, unitClassification params
    public static List<Unit__c> getUnitData(String projectName, String selectedListView , String bedroomName,string statusvalues, String unitstatus, String unitassigned, String bucket,
            String floorNumber, String zone, String unitClassification) {
        // Coalesce 'All' -> null so both null/'All' mean "no filter"
        projectName      = (projectName == null || projectName == 'All')          ? null : projectName;
        selectedListView = (selectedListView == null || selectedListView == 'All')? null : selectedListView;
        bedroomName      = (bedroomName == null || bedroomName == 'All')          ? null : bedroomName;
        statusvalues     = (statusvalues == null || statusvalues == 'All')        ? null : statusvalues;
        unitstatus       = (unitstatus == null || unitstatus == 'All')            ? null : unitstatus;
        unitassigned     = (unitassigned == null || unitassigned == 'All')        ? null : unitassigned;
        bucket           = (bucket == null || bucket == 'All')                    ? null : bucket;
        // start 3.0 - Arvind - 23 Jul 2026 - normalize new filters
        floorNumber      = (floorNumber == null || floorNumber == 'All')          ? null : floorNumber;
        zone             = (zone == null || zone == 'All')                       ? null : zone;
        unitClassification = (unitClassification == null || unitClassification == 'All') ? null : unitClassification;
        // end 3.0

        String soql =
            'SELECT Id, Name, Project_Name__c, TotalPrice__c, UAE_Citizen_Price__c,' +
            ' Status__c, ApprovalStatus__c, Phase__r.Name, Phase__c, Aging__c, Status_Change_Time__c,' +
            ' Number_of_Bedrooms__c, PlotAreasqm__c, PlotNo__c,' +
            ' BlockedBy__r.Name, Blocked_Time__c, BlockedFor__r.Name, BlockUntil__c, BlockComment__c, Allocate_to_Agency__r.Name, ' + //2.1
            ' IsUnitAvailable__c, Owner.Name, Bucket__r.Name,' +
            ' Payment_In_Progress__c, Payment_Hold_Expiry__c,' + //2.2 - lets the LWC disable a unit being paid for
            ' Allow_Partial_Booking__c,' + //2.4 - partial booking approval
            ' Floor__c, Zone__c, UnitClassification__c' + // 3.0 - Arvind - 23 Jul 2026 - new filter fields
            ' FROM Unit__c';

        List<String> whereParts = new List<String>();

        // Project
        if (projectName != null) {
            whereParts.add('Project_Name__c = :projectName');
        }
        // Phase (param is Phase__c Id)
        if (selectedListView != null) {
            whereParts.add('Phase__c = :selectedListView');
        }
        // Bedrooms (safe cast)
        if (bedroomName != null) {
            whereParts.add('Number_of_Bedrooms__c = :bedroomName');
        }
        // Inventory status / approval logic
        if (statusvalues != null) {
            if (statusvalues == 'Released') {
                whereParts.add('ApprovalStatus__c = :statusvalues');

                if (unitstatus != null) {
                    whereParts.add('Status__c = :unitstatus');
                } else {
                    Set<String> releasedStatuses = new Set<String>{ 'Available'};
                    whereParts.add('Status__c IN :releasedStatuses');
                }

                if (unitassigned != null) {
                    whereParts.add('Sub_Status__c = :unitassigned');
                }
            } else if (statusvalues == 'UnReleased') {
                // Tolerate either field containing UnReleased
                whereParts.add('(ApprovalStatus__c = \'UnReleased\')');
            } else {
                // Draft or any other straightforward approval status
                whereParts.add('ApprovalStatus__c = :statusvalues');
            }
        }
        // Bucket
        if (bucket != null) {
            whereParts.add('Bucket__c = :bucket');
        }
        // start 3.0 - Arvind - 23 Jul 2026 - Floor / Zone / Unit Classification filters
        if (floorNumber != null) {
            whereParts.add('Floor__c = :floorNumber');
        }
        if (zone != null) {
            whereParts.add('Zone__c = :zone');
        }
        if (unitClassification != null) {
            whereParts.add('UnitClassification__c = :unitClassification');
        }
        // end 3.0

        // Final SOQL
        if (!whereParts.isEmpty()) {
            soql += ' WHERE ' + String.join(whereParts, ' AND ');
        }
        soql += ' ORDER BY Phase__r.Name, Name';

        System.debug('getUnitData SOQL==> ' + soql);

        // SOQL injection fix: bind Aura filter values via queryWithBinds.
        Map<String, Object> binds = new Map<String, Object>{
            'projectName' => projectName,
            'selectedListView' => selectedListView,
            'bedroomName' => bedroomName,
            'statusvalues' => statusvalues,
            'unitstatus' => unitstatus,
            'unitassigned' => unitassigned,
            'bucket' => bucket,
            'floorNumber' => floorNumber,
            'zone' => zone,
            'unitClassification' => unitClassification,
            'releasedStatuses' => new Set<String>{ 'Available' }
        };
        List<Unit__c> rows = Database.queryWithBinds(soql, binds, AccessLevel.SYSTEM_MODE);

        // Post-filter: exclude names containing "test" (case-insensitive) to avoid NOT LIKE in SOQL
        List<Unit__c> filtered = new List<Unit__c>();
        for (Unit__c u : rows) {
            String nm = (u.Name == null) ? '' : u.Name.toLowerCase();
            if (nm.contains('test')) continue; // skip "test" names
            filtered.add(u);
        }
        return filtered;
    }
    @AuraEnabled(cacheable=true)
    public static List<Phase__c> fetchPhases(string projectName) {
        System.debug(projectName);
        List<Phase__c> phaseList = new List<Phase__c>();
        if(projectName == 'All'){
            phaseList = [SELECT Id, Name, Project__r.Name FROM Phase__c];
        }else{
            phaseList = [SELECT Id, Name, Project__r.Name FROM Phase__c WHERE Project__r.Name = :projectName];    
        }
        System.debug(phaseList);
        return phaseList;
    }

    public class ResponseWrapper{
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String errorMsg;
        @AuraEnabled public String messageVariant;
        @AuraEnabled public List<Unit__c> unitLst;
        @AuraEnabled public String selectedListView;
        @AuraEnabled public String selectedProjects;
        @AuraEnabled public List<Map<String,String>> allListView;
        @AuraEnabled public List<Map<String,String>> metaoptions;
        @AuraEnabled public List<Map<String,String>> availableProjects;
        @AuraEnabled public List<Map<String,String>> unitStatusoptions;
        @AuraEnabled public List<Map<String,String>> bedroomoptions;
        @AuraEnabled public List<Bucket__c> buckets;
        // start 3.0 - Arvind - 23 Jul 2026 - Floor / Zone / Unit Classification filter options
        @AuraEnabled public List<Map<String,String>> floorOptions;
        @AuraEnabled public List<Map<String,String>> unitClassificationOptions;
        @AuraEnabled public List<String> zoneOptions;
        // end 3.0
         
        public ResponseWrapper(){
            isSuccess = true;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> fetchBucketQueueMappings() {
        List<Map<String, String>> bucketQueueList = new List<Map<String, String>>();

        // Get all Developer Names from metadata
        List<String> queueDeveloperNames = new List<String>();
        for (Bucket_to_Queue_assignment__mdt mapping : [
            SELECT Bucket_Name__c, Queue_Developer_Name__c
            FROM Bucket_to_Queue_assignment__mdt
        ]) {
            if (mapping.Queue_Developer_Name__c != null) {
                queueDeveloperNames.add(mapping.Queue_Developer_Name__c);
            }
        }

        // Query Group (Queue) records using DeveloperName
        Map<String, Id> developerNameToQueueId = new Map<String, Id>();
        if (!queueDeveloperNames.isEmpty()) {
            for (Group grp : [
                SELECT Id, DeveloperName 
                FROM Group 
                WHERE DeveloperName IN :queueDeveloperNames
                AND Type = 'Queue'
            ]) {
                developerNameToQueueId.put(grp.DeveloperName, grp.Id);
            }
        }

        // Prepare final List<Map>
        for (Bucket_to_Queue_assignment__mdt mapping : [
            SELECT Bucket_Name__c, Queue_Developer_Name__c
            FROM Bucket_to_Queue_assignment__mdt
        ]) {
            Id queueId = developerNameToQueueId.get(mapping.Queue_Developer_Name__c);
            if (queueId != null) {
                bucketQueueList.add(new Map<String, String>{
                    'bucketName' => mapping.Bucket_Name__c,
                    'queueId' => queueId
                });
            }
        }

        return bucketQueueList;
    }


    @AuraEnabled
    public static void assignUnitsToBucket(List<Id> unitIds, Id queueId) {
        List<Unit__c> unitsToUpdate = new List<Unit__c>();

        for (Id unitId : unitIds) {
            unitsToUpdate.add(new Unit__c(
                Id = unitId,
                OwnerId = queueId
            ));
        }
        
        if (!unitsToUpdate.isEmpty()) {
            update unitsToUpdate;
        }
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isUserAllowedToEdit() {
        // Get the current user's username
        String currentUsername = UserInfo.getUserName();
        
        // Get the custom label value
        String labelValue = System.Label.UsersAllowToEditManageInventory;

        if (String.isBlank(labelValue)) {
            return false;
        }

        // Convert label to a list (split by comma)
        List<String> allowedList = new List<String>();
        for (String user : labelValue.split(',')) {
            allowedList.add(user.trim().toLowerCase());
        }

        // Check if the current username exists in the label list
        return allowedList.contains(currentUsername.toLowerCase());
    }

    
}