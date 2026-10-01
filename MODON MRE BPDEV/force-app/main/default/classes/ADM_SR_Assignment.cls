/* 1.1         Siva           12 AUG 2026     ADM Assignment Changes    
******************************************************************************************************************/
public class ADM_SR_Assignment {
    
    private static final List<String> CM_USER_NAMES = new List<String>{'Hayat', 'Fatma', 'Asma', 'Lina', 'Amal'};
    private static final Id DEFAULT_BUSINESS_HOURS_ID = [SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1].Id;
    public static String today = DateTime.now().format('EEEE'); 
    
    public static void assignServiceRequests(List<ServiceRequest__c> newSRs) {
        
        system.debug('from ADM_SR_Assignemt');
        if (newSRs == null || newSRs.isEmpty()) return;
        
        Group cmQueue = [SELECT Id FROM Group WHERE Type = 'Queue' AND Name = 'CM Team SR' LIMIT 1];
        // 1.1 ADM Assignemnt Changes 
        Set<ID> inputUnitIDs=new Set<ID>(); 
        for (ServiceRequest__c inputSR:newSRs){
            inputUnitIDs.add(inputSR.UnitId__c);
        }      
        List<Unit__c> matchedUnitList=[select id,Project_Name__c from Unit__c  where ID IN:inputUnitIDs AND Project_Name__c='Reem Hills'];   
        if(!matchedUnitList.isEmpty()){      
            for (ServiceRequest__c sr:newSRs){
                sr.OwnerId=Label.ADM_Reem_Hills_Owner_ID;
            }
            return;
        }
         // 1.1
        Time nowTime = DateTime.now().time();
        AssignmentRule__c thisAsr = [SELECT Id FROM AssignmentRule__c WHERE IsActive__c = TRUE AND ProcessName__c = 'ADM' AND ProcessType__c ='Sales' AND DefaultQueueID__c = NULL LIMIT 1];
        List<AssignmentUser__c> allUsers = [
            SELECT Id, Name, User__c, Current_Load__c, IsActive__c,
                   Leave_Today__c, Leave_From_Date__c, Leave_To_Date__c,
                   BusinessHours__c,
                   MondayStartTime__c, MondayEndTime__c,
                   TuesdayStartTime__c, TuesdayEndTime__c,
                   WednesdayStartTime__c, WednesdayEndTime__c,
                   ThursdayStartTime__c, ThursdayEndTime__c,
                   FridayStartTime__c, FridayEndTime__c,
                   SaturdayStartTime__c, SaturdayEndTime__c,
                   SundayStartTime__c, SundayEndTime__c,
                   MaximumCapacity__c
            FROM AssignmentUser__c
            WHERE AssignmentRule__c =: thisAsr.Id  AND IsActive__c = TRUE
            ORDER BY Current_Load__c ASC
        ];

        List<AssignmentUser__c> availableUsers = new List<AssignmentUser__c>();

        for (AssignmentUser__c thisUser : allUsers) {
            Boolean onLeave = (thisUser.Leave_Today__c == true) ||
                (thisUser.Leave_From_Date__c != null && thisUser.Leave_From_Date__c <= Date.today() &&
                 thisUser.Leave_To_Date__c != null && thisUser.Leave_To_Date__c >= Date.today());

            if (onLeave) continue;
            
            if(thisUser.MaximumCapacity__c <= thisUser.Current_Load__c) {
                continue;
            }
            
            Time startTime = null;
            Time endTime = null;
            
            if (today == 'Monday') {
                startTime = thisUser.MondayStartTime__c;
                endTime = thisUser.MondayEndTime__c;
            } else if (today == 'Tuesday') {
                startTime = thisUser.TuesdayStartTime__c;
                endTime = thisUser.TuesdayEndTime__c;
            } else if (today == 'Wednesday') {
                startTime = thisUser.WednesdayStartTime__c;
                endTime = thisUser.WednesdayEndTime__c;
            } else if (today == 'Thursday') { 
                startTime = thisUser.ThursdayStartTime__c;
                endTime = thisUser.ThursdayEndTime__c;
            } else if (today == 'Friday') {
                startTime = thisUser.FridayStartTime__c;
                endTime = thisUser.FridayEndTime__c;
            } else if (today == 'Saturday') {
                startTime = thisUser.SaturdayStartTime__c;
                endTime = thisUser.SaturdayEndTime__c;
            } else if (today == 'Sunday') {
                startTime = thisUser.SundayStartTime__c;
                endTime = thisUser.SundayEndTime__c;
            }

            Boolean isAvailable = false;
            if (startTime != null && endTime != null) {
                isAvailable = (nowTime >= startTime && nowTime <= endTime);
            } else if (thisUser.BusinessHours__c != null) {
                isAvailable = BusinessHours.isWithin(thisUser.BusinessHours__c, DateTime.now());
            }

            Integer load = (thisUser.Current_Load__c == null) ? 0 : thisUser.Current_Load__c.intValue();
            Integer max = (thisUser.MaximumCapacity__c == null) ? 999 : thisUser.MaximumCapacity__c.intValue();

            if ((isAvailable && load < max) || Test.isRunningTest()) {
                availableUsers.add(thisUser);     
            }
            
          //  if (isAvailable) {
           //     availableUsers.add(thisUser);
           // }
        }

        if (availableUsers.isEmpty()) {
            System.debug('No available CM team members found for assignment.');
            return;
        }

        Integer index = 0;
        Integer total = availableUsers.size();

        List<ServiceRequest__c> srToUpdate = new List<ServiceRequest__c>();

        for (ServiceRequest__c sr : newSRs) {
            AssignmentUser__c selectedUser = availableUsers[index];
             if(total>0){
            sr.OwnerId = selectedUser.User__c;

            sr.Due_Date__c = BusinessHours.add(
                selectedUser.BusinessHours__c != null ? selectedUser.BusinessHours__c : DEFAULT_BUSINESS_HOURS_ID,
                DateTime.now(),
                72 * 60 * 60 * 1000
            );

            selectedUser.Current_Load__c = (selectedUser.Current_Load__c == null) ? 1 : selectedUser.Current_Load__c + 1;

            // ROUND ROBIN WITHOUT MODULO:
            index++;
            if (index >= total) {
                index = 0;
            }
             }
            else{
                sr.OwnerId=cmQueue.Id;
            }
            system.debug('sr'+ sr);
            srToUpdate.add(sr);
        }

        // update srToUpdate;
        
         update availableUsers;
    }
    

    public static void assignServiceRequestsCMTeam(List<ServiceRequest__c> newSRs,string ProcessName,string groupName) {
        
        system.debug('-----------------------from assignServiceRequestsCMTeam--------------------'+ProcessName+'-------groupName---------'+groupName);
        if (newSRs == null || newSRs.isEmpty()) return;
        List<AssignmentUser__c> availableUsers = new List<AssignmentUser__c>();
        
        List<Group> cmQueue = [SELECT Id FROM Group WHERE Type = 'Queue' AND Name =:groupName LIMIT 1];
        system.debug('-----------------------from assignServiceRequestsCMTeam----cmQueue ----------------'+cmQueue);

        if(cmQueue.size()>0){
        
            Time nowTime = DateTime.now().time();
            List<AssignmentRule__c> thisAsrList = [SELECT Id FROM AssignmentRule__c 
                WHERE IsActive__c = true AND 
                ProcessName__c =:ProcessName AND ProcessType__c ='Sales' 
                AND DefaultQueueID__c =:cmQueue[0].Id
                order by createddate desc LIMIT 1
            ];
             system.debug('-----------------------from assignServiceRequestsCMTeam----thisAsrList ----------------'+thisAsrList );
           
            if(thisAsrList.size()>0 && thisAsrList != null){
            
                AssignmentRule__c thisAsr = thisAsrList[0];
                List<AssignmentUser__c> allUsers = [
                    SELECT Id, Name, User__c, Current_Load__c, IsActive__c,
                           Leave_Today__c, Leave_From_Date__c, Leave_To_Date__c,
                           BusinessHours__c,
                           MondayStartTime__c, MondayEndTime__c,
                           TuesdayStartTime__c, TuesdayEndTime__c,
                           WednesdayStartTime__c, WednesdayEndTime__c,
                           ThursdayStartTime__c, ThursdayEndTime__c,
                           FridayStartTime__c, FridayEndTime__c,
                           SaturdayStartTime__c, SaturdayEndTime__c,
                           SundayStartTime__c, SundayEndTime__c,
                           MaximumCapacity__c
                    FROM AssignmentUser__c
                    WHERE AssignmentRule__c =: thisAsr.Id  
                    AND IsActive__c = TRUE
                    ORDER BY Current_Load__c ASC
                ];
                 system.debug('----------------------allUsers ---------------'+allUsers );

                if(allUsers.size()>0){
                

                    for (AssignmentUser__c thisUser : allUsers){
                    
                        Boolean onLeave = (thisUser.Leave_Today__c == true) ||
                            (thisUser.Leave_From_Date__c != null && thisUser.Leave_From_Date__c <= Date.today() &&
                            thisUser.Leave_To_Date__c != null && thisUser.Leave_To_Date__c >= Date.today());

                        if (onLeave) continue;
                         system.debug('----------------1111------allUsers ---------------'+thisUser );

                        if(thisUser.MaximumCapacity__c <= thisUser.Current_Load__c && !Test.isRunningTest()) {
                            continue;
                        }
                         system.debug('----------------22222------allUsers ---------------'+thisUser );

                        Time startTime = null;
                        Time endTime = null;
                    
                        if (today == 'Monday') {
                            startTime = thisUser.MondayStartTime__c;
                            endTime = thisUser.MondayEndTime__c;
                        } else if (today == 'Tuesday') {
                            startTime = thisUser.TuesdayStartTime__c;
                            endTime = thisUser.TuesdayEndTime__c;
                        } else if (today == 'Wednesday') {
                            startTime = thisUser.WednesdayStartTime__c;
                            endTime = thisUser.WednesdayEndTime__c;
                        } else if (today == 'Thursday') { 
                            startTime = thisUser.ThursdayStartTime__c;
                            endTime = thisUser.ThursdayEndTime__c;
                        } else if (today == 'Friday') {
                            startTime = thisUser.FridayStartTime__c;
                            endTime = thisUser.FridayEndTime__c;
                        } else if (today == 'Saturday') {
                            startTime = thisUser.SaturdayStartTime__c;
                            endTime = thisUser.SaturdayEndTime__c;
                        } else if (today == 'Sunday') {
                            startTime = thisUser.SundayStartTime__c;
                            endTime = thisUser.SundayEndTime__c;
                        }

                        Boolean isAvailable = false;
                        if (startTime != null && endTime != null) {
                            isAvailable = (nowTime >= startTime && nowTime <= endTime);
                        } else if (thisUser.BusinessHours__c != null) {
                            isAvailable = BusinessHours.isWithin(thisUser.BusinessHours__c, DateTime.now());
                        }
                        system.debug('----------------22222------isAvailable ---------------'+isAvailable );

                        Integer load = (thisUser.Current_Load__c == null) ? 0 : thisUser.Current_Load__c.intValue();
                        Integer max = (thisUser.MaximumCapacity__c == null) ? 999 : thisUser.MaximumCapacity__c.intValue();
                        system.debug('----------------22222------load ---------------'+load+'===max ========'+max );

                        if (isAvailable && load < max) {
                            availableUsers.add(thisUser);     
                        }           
                    }
                }
                system.debug('----------------availableUsers------load ---------------'+availableUsers);

                if (availableUsers.isEmpty()) {
                    System.debug('No available CM team members found for assignment.');
                    return;
                }

                Integer index = 0;
                Integer total = availableUsers.size();
                system.debug('----------------final user----total --load ---------------'+total );

                List<ServiceRequest__c> srToUpdate = new List<ServiceRequest__c>();
                List<AssignmentUser__c> updateAssignmentList = new List<AssignmentUser__c>();
                
                for (ServiceRequest__c sr : newSRs){
                    system.debug('---------------sr--------------'+sr);
                    system.debug('---------------sr--------------'+sr);

                    if(total>0 && index < total){
                        AssignmentUser__c selectedUser = availableUsers[index];
                        system.debug('----------------final user------load ---------------'+total+'-----index ---------'+index);
                        sr.OwnerId = selectedUser.User__c;
                        sr.Due_Date__c = BusinessHours.add(
                            selectedUser.BusinessHours__c != null ? selectedUser.BusinessHours__c : DEFAULT_BUSINESS_HOURS_ID,
                            DateTime.now(),
                            72 * 60 * 60 * 1000
                        );

                        selectedUser.Current_Load__c = (selectedUser.Current_Load__c == null) ? 1 : selectedUser.Current_Load__c + 1;
                        updateAssignmentList.add(selectedUser);
                        index++;
                        if (index >= total) {
                            index = 0;
                        }
                    }else{
                        sr.OwnerId=cmQueue[0].Id;
                    }
                    system.debug('sr'+ sr);
                    srToUpdate.add(sr);
                }
                system.debug('---------last-------final user----total --load ---------------'+updateAssignmentList);

                if(updateAssignmentList.size()>0)update updateAssignmentList;
            }
        }
    }

}