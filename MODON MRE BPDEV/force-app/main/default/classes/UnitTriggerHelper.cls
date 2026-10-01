/**********************************************************************************************************************
* Name               : UnitTriggerHelper                                                        
* Description        : This class is helper for Unit trigger
* Usage              : Called from UnitTriggerHandler
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           paras.bhatt@pwc.com             15 Jan 2024     Initial Draft   
* 2.0           Modon IT                        18 Sep 2025     Change bucket sharing
* 3.0           MODON IT                        17 Oct 2025     Commented validateUnitCreatorPermission() fields
* 4.0           Milin Kapatel (Horizontal)      09 Mar 2026     Added methods to convert Areas fields form Decimal to words in English and Arabic
* 5.0           Milin Kapatel (Horizontal)      22 Apr 2026     Updated methods to use convertAreaInWordsSqMtrSqCmtrTextEnglish instead of areaInWordsSqMeterSqCentimeter
* 5.1           Milin Kapatel (Horizontal)      05 May 2026     Code optimization of populateAreaInWords method
* 5.2           Milin Kapatel (Horizontal)      05 May 2026     Updated methods to use hasDecimalValueChanged method of utilities class
* 6.0           Mirza Baig                      02 June 2026    Added FxRate methods to populate related Sales Order if unit sold date is updated.
* 7.0           Milin Kapatel (Horizontal)      07 July 2026    Added logic to manage unit and bucket sharing in after insert for 'Modon - Egypt' units, added null checks for oldMap.
******************************************************************************************************************/
public without sharing class UnitTriggerHelper {
    public static void manageUnitSharing(List<sObject> newList,Map<Id, SObject> oldMap){
        map<Id,ID> unitToUserSharing = new map<Id,ID>();
        map<Id,ID> unitToUserSharing_Remove = new map<Id,ID>();
        
        for(Unit__c newUnit : (List<Unit__c>)newList){
            // v7.0 start
            Unit__c oldRecord = oldMap != null ? (Unit__c)oldMap.get(newUnit.Id) : null;

            if(oldRecord == null){
                if(newUnit.BlockedFor__c != null){
                    unitToUserSharing.put(newUnit.Id, newUnit.BlockedFor__c);
                }
            } else {
                //Add Share records
                if(newUnit.BlockedFor__c != oldRecord.BlockedFor__c && newUnit.BlockedFor__c != null){
                    unitToUserSharing.put(newUnit.Id, newUnit.BlockedFor__c);
                }
                //Remove Share records
                if(newUnit.BlockedFor__c != oldRecord.BlockedFor__c && oldRecord.BlockedFor__c != null){
                    unitToUserSharing_Remove.put(newUnit.Id, oldRecord.BlockedFor__c);
                }
            }
            // v7.0 end
        }
           
        //Create new share records
        if(!unitToUserSharing.isEmpty()){
            
            delete [select id from Unit__Share where ParentId in :unitToUserSharing.keySet() and UserOrGroupId in :unitToUserSharing.values() and RowCause= :Schema.Unit__Share.RowCause.ManualBlock__c];
            //Create new records
            list<Unit__Share> recordsToInsert= new list<Unit__Share>();
            for(Id unitID : unitToUserSharing.keySet()){
                recordsToInsert.add(new Unit__Share (ParentId = unitID, RowCause=Schema.Unit__Share.RowCause.ManualBlock__c  ,UserOrGroupId = unitToUserSharing.get(unitID),AccessLevel ='Edit' ) );
            }
            if(!recordsToInsert.isEmpty()){
                insert recordsToInsert;
            }
        }
        
        //delete all old records
        if(!unitToUserSharing_Remove.isEmpty()){
            delete [select id from Unit__Share where ParentId in :unitToUserSharing_Remove.keySet() and UserOrGroupId in :unitToUserSharing_Remove.values() and RowCause= :Schema.Unit__Share.RowCause.ManualBlock__c  ];
        }
              
    }

    public static void manageBucketSharing(List<sObject> newList,Map<Id, SObject> oldMap){
        system.debug('newList==>' + newList);
        system.debug('oldMap==>' + oldMap);
        Map<String, String> bucketToUserSharing = new Map<String, String>();
        Map<String, String> bucketToRemoveSharing = new Map<String, String>();
        set<Id> bucketIds = new set<Id>();
        for(Unit__c newUnit : (List<Unit__c>)newList){
            // v7.0 start
            Unit__c oldRecord = oldMap != null ? (Unit__c)oldMap.get(newUnit.Id) : null;
            system.debug(newUnit.Bucket__c);
            if(oldRecord != null){
                system.debug(oldRecord.Bucket__c);
            }

            if(oldRecord == null){
                if(String.isNotBlank(newUnit.Bucket__c)){
                    bucketIds.add(newUnit.Bucket__c);
                    bucketToUserSharing.put(newUnit.Id, newUnit.Bucket__c);
                }
            } else if(newUnit.Bucket__c != oldRecord.Bucket__c){
                if(String.isNotBlank(newUnit.Bucket__c)){
                    bucketIds.add(newUnit.Bucket__c);
                    bucketToUserSharing.put(newUnit.Id, newUnit.Bucket__c);
                }
                if(String.isNotBlank(oldRecord.Bucket__c)){
                    bucketIds.add(oldRecord.Bucket__c);
                    bucketToRemoveSharing.put(newUnit.Id, oldRecord.Bucket__c);
                }
            }
            system.debug('bucketIds==>' + bucketIds);
            // v7.0 end
        }
        if(!bucketIds.isEmpty()){
            recalculateUnitsOnBucket(bucketIds);
        }
        handleUnitSharing(bucketToUserSharing,bucketToRemoveSharing);
    }

    public static void recalculateUnitsOnBucket(set<Id> bucketIds){
        List<AggregateResult> unitsOnBucket = [select Bucket__c, count(id) cnt from Unit__c where Bucket__c in :bucketIds GROUP BY Bucket__c];
        system.debug('unitsOnBucket==>' + unitsOnBucket);
        List<Bucket__c> bucketLst = new List<Bucket__c>();
        set<Id> bucketToUpdate = new set<Id>();
        for(AggregateResult unitWithBucket : unitsOnBucket){
            Bucket__c bucket = new Bucket__c(Id = (Id)unitWithBucket.get('Bucket__c'));
            bucket.Number_of_units__c = (Decimal)unitWithBucket.get('cnt');
            bucketLst.add(bucket);
            bucketToUpdate.add((Id)unitWithBucket.get('Bucket__c'));
            system.debug('bucketLst==>' + bucketLst);
        }
        //if(unitsOnBucket.isEmpty() && bucketLst.isEmpty()){
        for(Id bucketId : bucketIds){
            if(!bucketToUpdate.contains(bucketId)){
                bucketLst.add(new Bucket__c(Id = bucketId, Number_of_units__c = 0));
                bucketToUpdate.add(bucketId);
            }
        }
        //}
        if(!bucketLst.isEmpty()){
            UPDATE bucketLst;
        }
    }

    public static void handleUnitSharing(Map<String, String> bucketToUserSharing, Map<String, String> bucketToRemoveSharing){
        if(bucketToRemoveSharing != null && bucketToRemoveSharing.keySet().Size() > 0){
            Set<Id> removeUnitIds = new Set<Id>();
            for(String key : bucketToRemoveSharing.keySet()){
                removeUnitIds.add(key);
            }
            List<Unit__Share> unitShareLst = [SELECT Id FROM Unit__Share WHERE ParentId = :removeUnitIds AND RowCause = :Schema.Unit__Share.RowCause.BucketSharing__c];
            if(unitShareLst.Size() > 0){
                //delete records
                DELETE unitShareLst;
            }
        }
        
        if(bucketToUserSharing != null && bucketToUserSharing.keySet().Size() > 0){
            set<Id> bucketIds = new set<Id>();
            for(String key : bucketToUserSharing.keySet()){
                bucketIds.add(bucketToUserSharing.get(key));
            }

            Map<Id, Id> bucketGroupMap = new Map<Id, Id>();
            for(Bucket__c buckObj : [SELECT Id, Bucket_Group_Id__c FROM Bucket__c WHERE Id IN :bucketIds AND Active__c = TRUE]){
                bucketGroupMap.put(buckObj.Id, buckObj.Bucket_Group_Id__c);
            }

            if(bucketGroupMap != null && bucketGroupMap.keySet().size() > 0){
                //create new sharing records
                List<Unit__Share> unitShareLst = new List<Unit__Share>();
                for(String key : bucketToUserSharing.keySet()){
                    if(bucketToUserSharing.containsKey(key) && bucketGroupMap.containsKey(bucketToUserSharing.get(key))){
                        unitShareLst.add(new Unit__Share (ParentId = key, RowCause=Schema.Unit__Share.RowCause.BucketSharing__c  ,UserOrGroupId = bucketGroupMap.get(bucketToUserSharing.get(key)),AccessLevel ='Edit' ) );
                    }
                }
                if(!unitShareLst.isEmpty()){
                    INSERT unitShareLst;
                }
            }
            /*Map<Id, List<Bucket_Assignment__c>> bucketBucketAssignMap = new Map<Id, List<Bucket_Assignment__c>>();
            for(Bucket_Assignment__c baObj : [SELECT Id, User__c,Bucket__c FROM Bucket_Assignment__c WHERE Bucket__c IN :bucketIds AND Bucket__r.Active__c = TRUE]){
                if(!bucketBucketAssignMap.containsKey(baObj.Bucket__c)){
                    bucketBucketAssignMap.put(baObj.Bucket__c, new List<Bucket_Assignment__c>());
                }
                bucketBucketAssignMap.get(baObj.Bucket__c).add(baObj);
            }
            if(bucketBucketAssignMap != null && bucketBucketAssignMap.keySet().size() > 0){
                //create new sharing records
                List<Unit__Share> unitShareLst = new List<Unit__Share>();
                for(String key : bucketToUserSharing.keySet()){
                    if(bucketBucketAssignMap.containsKey(bucketToUserSharing.get(key))){
                        for(Bucket_Assignment__c baObj : bucketBucketAssignMap.get(bucketToUserSharing.get(key))){
                            unitShareLst.add(new Unit__Share (ParentId = key, RowCause=Schema.Unit__Share.RowCause.BucketSharing__c  ,UserOrGroupId = baObj.User__c,AccessLevel ='Edit' ) );
                        }
                    }
                }
                if(!unitShareLst.isEmpty()){
                    INSERT unitShareLst;
                }
            }*/
        }
    }

    public static void checkUnitStatus(Map<Id, sObject> newMap, Map<Id, sObject> oldMap){
        set<String> unitIds = new set<String>();
        for(String unitId : newMap.keySet()){
            Unit__c newUnit = (Unit__c)newMap.get(unitId);
            Unit__c oldUnit = (Unit__c)oldMap.get(unitId);

            if(newUnit.Status__c != oldUnit.Status__c){
                unitIds.add(unitId);
            }
        }

        if(unitIds.size() > 0){
            //call scheduler
            UpdateUnitStatusQueueable newQueue = new UpdateUnitStatusQueueable(unitIds);
            System.enqueueJob(newQueue);

        }
    }

    public static void updateUnitStatus(Map<Id, sObject> newMap, Map<Id, sObject> oldMap){
        for(String unitId : newMap.keySet()){
            Unit__c newUnit = (Unit__c)newMap.get(unitId);
            Unit__c oldUnit = (Unit__c)oldMap.get(unitId);

            if(newUnit.Status__c != oldUnit.Status__c){
                newUnit.OldStatus__c = oldUnit.Status__c;
            }
        }
    }
    
    public static void validatePriceChangeAuthorization(Map<Id, sObject> newMap, Map<Id, sObject> oldMap){
    	list<sObject> validateSObjectList = new list<sObject>();
        for(String unitId : newMap.keySet()){
            Unit__c newUnit = (Unit__c)newMap.get(unitId);
            Unit__c oldUnit = (Unit__c)oldMap.get(unitId);
			//TODO Validate all the required field chnages that must be authorized by creator
            if(newUnit.BasePrice__c  != oldUnit.BasePrice__c  || newUnit.BasePrice__c  != oldUnit.BasePrice__c){
                validateSObjectList.add(newMap.get(unitId));
            }
        }
        if(!validateSObjectList.isEmpty()){
            validateUnitCreatorPermission(validateSObjectList);
        }
    }
    public static void validateUnitCreatorPermission(List<sObject> newList){
        Boolean hasCreatorAccess = FeatureManagement.checkPermission('Unit_Creator');
        for(Unit__c tempUnit : (list<Unit__c>) newList){
            if(hasCreatorAccess){
             /* START (3.0) 
                tempUnit.Status__c='';
                tempUnit.ApprovalStatus__c='Draft';
                tempUnit.BlockedFor__c = null;
                tempUnit.BlockUntil__c = null;
                tempUnit.Blocked_Time__c = null;
                tempUnit.BlockedBy__c = null;
                tempUnit.BlockComment__c = '';
             END (3.0)*/
            }else if(!test.isRunningTest()){
                tempUnit.addError('You are not authorized to create/update the inventory.');
            }
            
        }
    }
    public static void sendNotificationToBlockedForUsers(List<sObject> newList, Map<Id, sObject> oldMap){
        Set<Id> newRecipientIds = new Set<Id>();
        Map<Id, Unit__c> unitsToNotify = new Map<Id, Unit__c>();
        
        
        system.debug('newUnit -> ' + newList);
        system.debug('oldUnit -> ' + oldMap);
        for (Unit__c newUnit : (List<Unit__c>) newList) {
            Unit__c oldUnit = (Unit__c) oldMap.get(newUnit.Id);
            if (newUnit.BlockedFor__c != oldUnit.BlockedFor__c && newUnit.BlockedFor__c != null) {
                newRecipientIds.add(newUnit.BlockedFor__c);
                unitsToNotify.put(newUnit.Id, newUnit);
            }
        }
        if (!unitsToNotify.isEmpty()) {
            Map<Id, User> users = new Map<Id, User>([SELECT Id, Name, Email FROM User WHERE Id IN :newRecipientIds]);
            OrgWideEmailAddress[] owea = [SELECT Id,Address,DisplayName FROM OrgWideEmailAddress Where DisplayName = 'Modon noreply'];
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            String currentUserName = UserInfo.getName();
            System.debug('currentUserName-->'+currentUserName);
            for (Unit__c unit : unitsToNotify.values()) {
                User recipient = users.get(unit.BlockedFor__c);
                if (recipient != null && String.isNotBlank(recipient.Email)) {
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    if (owea.size() > 0) {
	                    mail.setOrgWideEmailAddressId(owea[0].Id);                        
                    }

                    mail.setToAddresses(new String[] { recipient.Email });
                    mail.setSubject('Unit Assigned to You By '+ currentUserName);
                    mail.setPlainTextBody('Dear ' + recipient.Name + ',\n\n'
                                          + 'The unit ' + unit.Name + ' has been assigned to you by ' + currentUserName + '.\n\n'
                                          + 'Thank you.\n\nBest regards');
                    emails.add(mail);
                }
            }
            
            if (!emails.isEmpty() && !Test.isRunningTest()) {
                System.debug('Email Send-->');
                Messaging.sendEmail(emails);
            }
        }  
    }
    /*public static void mapingField(List<sObject> newList, Map<Id, sObject> oldMap){       
        for(Unit__c tempUnit : (list<Unit__c>) newList){
            if(oldmap == null ){
                if(tempUnit.Number_of_Bedrooms__c !=null){
                    tempUnit.Number_of_Bedrooms__c = tempUnit.Number_of_Bedrooms__c;
                }               
            }else if(oldMap.get(tempUnit.Id).get('Number_of_Bedrooms__c') != tempUnit.get('Number_of_Bedrooms__c') && tempUnit.get('Number_of_Bedrooms__c') != null){
                tempUnit.Number_of_Bedrooms__c = tempUnit.Number_of_Bedrooms__c;
            }            
        } 

    }*/

    //v4.0 batch method to convert area from decimal to area in words Arabic
    private static Boolean isBatchInitiated = false;

    public static void populateAreaInWordsArabic(List<Unit__c> modonEgyptUnits, Map<Id, Unit__c> modonEgyptUnitMap, List<Unit__c> oldModonEgyptUnits, Map<Id, Unit__c> oldModonEgyptUnitMap){
        if (!isBatchInitiated && !System.isQueueable() && !System.isBatch()) {
            Set<Id> unitIds = new Set<Id>();
            if(modonEgyptUnitMap == null && oldModonEgyptUnitMap == null) {
                for(Unit__c unit : modonEgyptUnits){
                    unitIds.add(unit.Id);
                }
            } else if(modonEgyptUnitMap != null && oldModonEgyptUnitMap != null){
                for(Unit__c unit : modonEgyptUnits){
                    if(modonEgyptUnitMap.containsKey(unit.Id) && oldModonEgyptUnitMap.containsKey(unit.Id)){
                        Unit__c oldUnit = oldModonEgyptUnitMap.get(unit.Id);
                        if(unit.GrossFloorAreaGFA__c != oldUnit.GrossFloorAreaGFA__c || unit.PlotAreasqm__c != oldUnit.PlotAreasqm__c || unit.TerraceArea__c != oldUnit.TerraceArea__c){
                            unitIds.add(unit.Id);
                        }
                    }
                }
            }
            if (!unitIds.isEmpty()) {
                isBatchInitiated = true;
                Database.executeBatch(new EgyptArabicTranslationBatch(unitIds), 33);
            }
        }
    }
    
    //v4.0 method to convert area from decimal to area in words English
    public static void populateAreaInWords(
        List<Unit__c> newUnits,
        Map<Id, Unit__c> newMap,
        List<Unit__c> oldUnits,
        Map<Id, Unit__c> oldMap
    ){
        if (newUnits == null || newUnits.isEmpty()) return;

        Boolean isInsert = (oldMap == null || oldMap.isEmpty());

        for (Unit__c unit : newUnits) {

            Unit__c oldUnit = (!isInsert && oldMap.containsKey(unit.Id)) 
                ? oldMap.get(unit.Id) 
                : null;

            // GFA
            if (isInsert || ModonEgyptUtilities.hasDecimalValueChanged(unit.GrossFloorAreaGFA__c, oldUnit?.GrossFloorAreaGFA__c)) {
                unit.GFA_in_Words__c =
                    ModonEgyptUtilities.convertAreaInWordsSqMtrSqCmtrTextEnglish(unit.GrossFloorAreaGFA__c);
            }

            // Plot Area
            if (isInsert || ModonEgyptUtilities.hasDecimalValueChanged(unit.PlotAreasqm__c, oldUnit?.PlotAreasqm__c)) {
                unit.Plot_Area_in_Words__c =
                    ModonEgyptUtilities.convertAreaInWordsSqMtrSqCmtrTextEnglish(unit.PlotAreasqm__c);
            }

            // Terrace Area
            if (isInsert || ModonEgyptUtilities.hasDecimalValueChanged(unit.TerraceArea__c, oldUnit?.TerraceArea__c)) {
                unit.Terrace_Area_in_Words__c =
                    ModonEgyptUtilities.convertAreaInWordsSqMtrSqCmtrTextEnglish(unit.TerraceArea__c);
            }
        }
    }

    //v6.0
    /**
    * Identifies Units whose Sold Date has changed, retrieves the
    * corresponding EGP-AED conversion rates, and updates related
    * active Sales Orders with the FX rate applicable on the Sold Date.
    */
    public static void populateFxRateOnSalesOrderEGP_AED(List<Unit__c> updatedUnits, Map<Id, Unit__c> oldUnitMap) {
        final String egpToAedKey = ModonEgyptConstants.CURRENCY_ISOCODE_EGP + ' - ' + ModonEgyptConstants.CURRENCY_ISOCODE_AED;

        Set<Id> updatedSoldDateUnitIds = new Set<Id>();
        Set<Date> soldDates = new Set<Date>();

        // Collect Units whose Sold Date was updated and the corresponding dates
        for (Unit__c unit : updatedUnits) {
            Unit__c oldUnit = oldUnitMap.get(unit.Id);

            if (unit.Unit_Sold_Date__c != null &&
                oldUnit != null &&
                oldUnit.Unit_Sold_Date__c != unit.Unit_Sold_Date__c) {
                Date soldDate = unit.Unit_Sold_Date__c;
                soldDates.add(soldDate);
                soldDates.add(soldDate.addDays(-1));
                soldDates.add(soldDate.addDays(-2));
                soldDates.add(soldDate.addDays(-3));

                updatedSoldDateUnitIds.add(unit.Id);
            }
        }

        if (!updatedSoldDateUnitIds.isEmpty()) {

            // Retrieve conversion rates for all impacted Sold Dates
            Map<Date, List<Currency_Conversion_Rate__c>> ratesMap =
                ModonEgypt_CurrencyConversion.getConversionRateBasedOnDates(soldDates);

            if (ratesMap == null || ratesMap.isEmpty()) {
                return;
            }

            // Identify Sales Orders that require an FX rate update
            SalesOrder__c[] updateSalesOrders = prepareSalesOrdersForFxRateUpdate(
                updatedSoldDateUnitIds,
                ratesMap
            );

            // Persist FX rate changes
            if (!updateSalesOrders.isEmpty()) {
                update updateSalesOrders;
            }
        }
    }

    //v6.0
    /**
    * Retrieves active Sales Orders for the specified Units and
    * prepares records that require an FX rate update by matching
    * the Unit Sold Date with the corresponding EGP-AED conversion rate.
    */
    private static List<SalesOrder__c> prepareSalesOrdersForFxRateUpdate(
        Set<Id> updatedSoldDateUnitIds,
        Map<Date, List<Currency_Conversion_Rate__c>> ratesMap
    ) {
        List<SalesOrder__c> salesOrdersToUpdate = new List<SalesOrder__c>();

        // Retrieve active Sales Orders related to Units whose Sold Date changed
        for (SalesOrder__c salesOrder : [
            SELECT Id,
                FxRate_EGP_AED__c,
                Unit__r.Unit_Sold_Date__c
            FROM SalesOrder__c
            WHERE Unit__c IN :updatedSoldDateUnitIds
            AND Source_Entity__c = :ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY
            AND Status__c NOT IN ('Cancelled', 'Voided')
        ]) {

            // Get conversion rates available for the Unit Sold Date
            Decimal applicableRate = getApplicableFxRate(salesOrder.Unit__r.Unit_Sold_Date__c, ratesMap);

            if (applicableRate != null && salesOrder.FxRate_EGP_AED__c != applicableRate) {
                salesOrder.FxRate_EGP_AED__c = applicableRate;
                salesOrdersToUpdate.add(salesOrder);
            }
        }

        return salesOrdersToUpdate;
    }

    //v6.0
    /**
    * Determines the applicable EGP-AED FX rate for a Unit Sold Date,
    * using the Sold Date and up to the previous three days as fallback dates.
    */
    private static Decimal getApplicableFxRate(
        Date soldDate,
        Map<Date, List<Currency_Conversion_Rate__c>> ratesMap
    ) {
        final String egpToAedKey = ModonEgyptConstants.CURRENCY_ISOCODE_EGP + '-' + ModonEgyptConstants.CURRENCY_ISOCODE_AED;

        // Check the Sold Date and up to the previous three days
        // until a matching conversion rate is found.
        for (Integer i = 0; i <= 3; i++) {
            Date checkDate = soldDate.addDays(-i);

            List<Currency_Conversion_Rate__c> rates = ratesMap.get(checkDate);

            if (rates == null || rates.isEmpty()) {
                continue;
            }

            // Return the first matching EGP-AED rate for the date.
            for (Currency_Conversion_Rate__c rate : rates) {
                if (rate.Name == egpToAedKey) {
                    return rate.Inverse_Conversion_Rate__c;
                }
            }
        }

        return null;
    }

    /**
     * When Unit.Status__c changes to 'Blocked', schedule an automated unblock check
     * after the duration configured in System.Label.Unit_Block_Release_Minutes (default 60 mins).
     */
    public static void scheduleAutoUnblockOnStatusBlocked(Map<Id, SObject> newMap, Map<Id, SObject> oldMap) {
        if (newMap == null || newMap.isEmpty()) return;

        Set<Id> blockedUnitIds = new Set<Id>();
        for (Id unitId : newMap.keySet()) {
            Unit__c newUnit = (Unit__c) newMap.get(unitId);
            Unit__c oldUnit = (oldMap != null) ? (Unit__c) oldMap.get(unitId) : null;

            Boolean becameBlocked = (newUnit.Status__c == 'Blocked') && (oldUnit == null || oldUnit.Status__c != 'Blocked');
            if (becameBlocked) {
                blockedUnitIds.add(unitId);
            }
        }

        if (blockedUnitIds.isEmpty()) return;

        Integer holdMinutes = 60;
        if (String.isNotBlank(System.Label.Unit_Block_Release_Minutes)) {
            try {
                holdMinutes = Integer.valueOf(System.Label.Unit_Block_Release_Minutes.trim());
            } catch (Exception ex) {
                holdMinutes = 60;
            }
        }

        if (Test.isRunningTest()) {
            return;
        }

        Datetime runTime = System.now().addMinutes(holdMinutes);
        String cronString = runTime.second() + ' ' + runTime.minute() + ' ' + runTime.hour() + ' ' + runTime.day() + ' ' + runTime.month() + ' ? ' + runTime.year();

        for (Id uId : blockedUnitIds) {
            String jobName = 'AutoUnblock_Unit_' + uId + '_' + System.currentTimeMillis();
            try {
                System.schedule(jobName, cronString, new UnitAutoUnblockSchedulable(new Set<Id>{ uId }));
                System.debug(LoggingLevel.INFO, 'Scheduled auto-unblock for Unit ' + uId + ' at ' + runTime + ' (in ' + holdMinutes + ' mins)');
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Failed to schedule auto-unblock for Unit ' + uId + ': ' + e.getMessage());
            }
        }
    }
}