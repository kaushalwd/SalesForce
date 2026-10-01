/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/
public with sharing class DisplayProcessChecklistItemController {

    @AuraEnabled
    public static Map<String, Object> getSimpleChecklistItems(String recordId) {
        System.debug('getSimpleChecklistItems method called recordId = '+recordId);

        Map<String, Object> result = new Map<String, Object>();

        // Get Process Checklist Main Record
        Process_Checklist__c processChecklist = [
            SELECT Id,Name__c,	Business_Process__c,
               /* Business_Process__r.Tower__c,*/
              /*  Business_Process__r.Tower__r.Name,
                Business_Process__r.Tower__r.Project__c,
                Business_Process__r.Tower__r.Project__r.Name, */
                   Checklist_Metadata__r.Checklist_Name_in_short__c
            FROM Process_Checklist__c
            WHERE Business_Process__c = :recordId
            OR Id = :recordId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.debug('processChecklist = '+processChecklist);

        // Get Items
        List<Process_Checklist_Items__c> items = [
            SELECT Id,
                   Checklist_Name__c,
                   Maker_Comments__c,
                   Process_Checklist__c
            FROM Process_Checklist_Items__c
            WHERE Process_Checklist__c = :processChecklist.Id
            ORDER BY Sequence__c
        ];
        System.debug('items = '+items);

        // Check queue memberships
        Boolean userInAddQueue = isUserInQueue('SPA Factsheet Add Queue');
        Boolean userInEditQueue = isUserInQueue('SPA Factsheet Edit Queue');
        System.debug('userInAddQueue = '+userInAddQueue);
        System.debug('userInEditQueue = '+userInEditQueue);

        // Add to result
        result.put('checklistItems', items);
        result.put('checkListName', processChecklist.Name__c);
        if (processChecklist.Checklist_Metadata__r != null) {
            result.put('checkListName',processChecklist.Checklist_Metadata__r.Checklist_Name_in_short__c);
        } else {
            result.put('checkListName', processChecklist.Name__c);
        }

       result.put('processChecklistId', processChecklist.Id);
       // if (processChecklist.Business_Process__r != null /*&& processChecklist.Business_Process__r.Tower__c != null*/)
       if (processChecklist.Business_Process__c != null /*&& processChecklist.Business_Process__r.Tower__c != null*/)
        {
           // result.put( 'towerId',processChecklist.Business_Process__r.Tower__c);
           // result.put( 'towerName',processChecklist.Business_Process__r.Tower__r.Name);
           
           /*
            if (processChecklist.Business_Process__r.Tower__r.Project__c != null) 
            {
                result.put('projectId',processChecklist.Business_Process__r.Tower__r.Project__c);
                result.put('projectName',processChecklist.Business_Process__r.Tower__r.Project__r.Name);
            }
            */
        }

        result.put('userCanAdd', userInAddQueue);
        result.put('userCanEdit', userInEditQueue);
		
        System.debug('### FINAL HEADER RESULT ### ' + result);

        return result;
    }

    /**
     * Check if the current user is a member of the specified queue
     * @param queueName The name of the queue to check
     * @return Boolean true if user is in queue, false otherwise
     */
    private static Boolean isUserInQueue(String queueName) {
        try {
            String userId = UserInfo.getUserId();
            System.debug('Checking queue membership for user: ' + userId + ', queue: ' + queueName);
            
            List<GroupMember> groupMembers = [
                SELECT Id
                FROM GroupMember
                WHERE Group.Name = :queueName
                AND Group.Type = 'Queue'
                AND UserOrGroupId = :userId
                LIMIT 1
            ];
            
            Boolean isMember = !groupMembers.isEmpty();
            System.debug('User is member of queue ' + queueName + ': ' + isMember);
            return isMember;
        } catch (Exception e) {
            System.debug('Error checking queue membership: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return false;
        }
    }

    /*@AuraEnabled
    public static Process_Checklist_Items__c createSimpleChecklistItem(String processChecklistId) {
        Process_Checklist_Items__c item = new Process_Checklist_Items__c(
            Process_Checklist__c = processChecklistId,
            Checklist_Name__c = 'New Item',
            Maker_Comments__c = ''
        );
        insert item;
        return item;
    }*/
    

	@AuraEnabled
    public static Process_Checklist_Items__c createSimpleChecklistItem(
        String processChecklistId, 
        String checklistName, 
        String makerComments
    ) {

        // Get the last sequence number for this Process_Checklist
        List<Process_Checklist_Items__c> existingItems = [ SELECT Id, Sequence__c FROM Process_Checklist_Items__c  WHERE Process_Checklist__c = :processChecklistId ORDER BY Sequence__c DESC NULLS LAST LIMIT 1];
        Decimal nextSequence = 1; // Default to 1 if no items exist
    
        if (!existingItems.isEmpty() && existingItems[0].Sequence__c != null) {
            nextSequence = existingItems[0].Sequence__c + 1;
        }  
        System.debug('nextSequence = '+nextSequence); 


        Process_Checklist_Items__c item = new Process_Checklist_Items__c(
            Process_Checklist__c = processChecklistId,
            Checklist_Name__c = checklistName,
            Maker_Comments__c = makerComments,
            sequence__c = nextSequence,
            Maker_Action__c = 'No Action',
            Checker_Action__c = 'No Action'
        );
        insert item;
        return item;
    }

    @AuraEnabled
    public static void deleteSimpleChecklistItem(Id itemId) {
        delete [SELECT Id FROM Process_Checklist_Items__c WHERE Id = :itemId];
    }

    public static void createProcessChecklist(String checklistName, Id businessProcessId) {
            System.debug('createProcessChecklist method called');
            
            if (String.isBlank(checklistName)) {
                throw new AuraHandledException('Checklist name cannot be blank.');
            }
            
            if (businessProcessId == null) {
                throw new AuraHandledException('Business Process Id is required.');
            }
            
            //Create Process Checklist
            Process_Checklist__c processChecklist = new Process_Checklist__c(
                Name__c = checklistName,
                Business_Process__c = businessProcessId
            );
            insert processChecklist;
            
            //Update Business Process with latest checklist
            Business_Process__c bp = new Business_Process__c(
                Id = businessProcessId,
                Latest_Process_Checklist__c = processChecklist.Id
            );
            update bp;
            
            // Create Checklist Items
            List<Process_Checklist_Items__c> processChecklistItems = new List<Process_Checklist_Items__c>{
                new Process_Checklist_Items__c(
                    Checklist_Name__c = 'Final SPA DRAFT along with the Disclosure statement',
                    Maker_Action__c = 'No Action',
                    Checker_Action__c = 'No Action',
                    Maker_Comments__c = 'Will be shared by legal (Factsheet document attachment option required for development to upload)',
                    Checker_Comments__c = '',
                    Process_CheckList__c = processChecklist.Id,
                    Sequence__c = 1
                ),
                    new Process_Checklist_Items__c(
                        Checklist_Name__c = 'Final Project Statement',
                        Maker_Action__c = 'No Action',
                        Checker_Action__c = 'No Action',
                        Maker_Comments__c = '',
                        Checker_Comments__c = '',
                        Process_CheckList__c = processChecklist.Id,
                        Sequence__c = 2
                    ),
                    new Process_Checklist_Items__c(
                        Checklist_Name__c = 'MCD (If Applicable)',
                        Maker_Action__c = 'No Action',
                        Checker_Action__c = 'No Action',
                        Maker_Comments__c = '',
                        Checker_Comments__c = '',
                        Process_CheckList__c = processChecklist.Id,
                        Sequence__c = 3
                    ),
                    new Process_Checklist_Items__c(
                        Checklist_Name__c = 'Annexure to be included if any',
                        Maker_Action__c = 'No Action',
                        Checker_Action__c = 'No Action',
                        Maker_Comments__c = '',
                        Checker_Comments__c = '',
                        Process_CheckList__c = processChecklist.Id,
                        Sequence__c = 4
                    ),
                    new Process_Checklist_Items__c(
                        Checklist_Name__c = 'Master Plan',
                        Maker_Action__c = 'No Action',
                        Checker_Action__c = 'No Action',
                        Maker_Comments__c = '',
                        Checker_Comments__c = '',
                        Process_CheckList__c = processChecklist.Id,
                        Sequence__c = 5
                    ),
                    new Process_Checklist_Items__c(
                        Checklist_Name__c = 'Floor Plan (CRM to upload on Sales Force, unit level)',
                        Maker_Action__c = 'No Action',
                        Checker_Action__c = 'No Action',
                        Maker_Comments__c = '',
                        Checker_Comments__c = '',
                        Process_CheckList__c = processChecklist.Id,
                        Sequence__c = 6
                    ),
                    new Process_Checklist_Items__c(
                        Checklist_Name__c = 'Store if any provided (Yes/No)',
                        Maker_Action__c = 'No Action',
                        Checker_Action__c = 'No Action',
                        Maker_Comments__c = '',
                        Checker_Comments__c = '',
                        Process_CheckList__c = processChecklist.Id,
                        Sequence__c = 7
                    ),
                    new Process_Checklist_Items__c(
                        Checklist_Name__c = 'Store if any provided (Yes/No)',
                        Maker_Action__c = 'No Action',
                        Checker_Action__c = 'No Action',
                        Maker_Comments__c = '',
                        Checker_Comments__c = '',
                        Process_CheckList__c = processChecklist.Id,
                        Sequence__c = 8
                    ),
                    new Process_Checklist_Items__c(
                        Checklist_Name__c = 'Project name and ID in both Arabic and English as per registration certificate',
                        Maker_Action__c = 'No Action',
                        Checker_Action__c = 'No Action',
                        Maker_Comments__c = 'English name Arabic name RERA Project No - 0000',
                        Checker_Comments__c = '',
                        Process_CheckList__c = processChecklist.Id,
                        Sequence__c = 9
                    ),
                    new Process_Checklist_Items__c(
                        Checklist_Name__c = 'Confirmation on area change if any',
                        Maker_Action__c = 'No Action',
                        Checker_Action__c = 'No Action',
                        Maker_Comments__c = '',
                        Checker_Comments__c = '',
                        Process_CheckList__c = processChecklist.Id,
                        Sequence__c = 10
                    ),
                    new Process_Checklist_Items__c(
                        Checklist_Name__c = 'DLD building number for the Tower, and DLD unit Nomenclature',
                        Maker_Action__c = 'No Action',
                        Checker_Action__c = 'No Action',
                        Maker_Comments__c = '',
                        Checker_Comments__c = '',
                        Process_CheckList__c = processChecklist.Id,
                        Sequence__c = 11
                    ),
                    new Process_Checklist_Items__c(
                        Checklist_Name__c = 'Master Community Name',
                        Maker_Action__c = 'No Action',
                        Checker_Action__c = 'No Action',
                        Maker_Comments__c = '',
                        Checker_Comments__c = '',
                        Process_CheckList__c = processChecklist.Id,
                        Sequence__c = 12
                    ),
                    new Process_Checklist_Items__c(
                        Checklist_Name__c = 'District Name',
                        Maker_Action__c = 'No Action',
                        Checker_Action__c = 'No Action',
                        Maker_Comments__c = '',
                        Checker_Comments__c = '',
                        Process_CheckList__c = processChecklist.Id,
                        Sequence__c = 13
                    ),
                    new Process_Checklist_Items__c(
                        Checklist_Name__c = 'Building Name',
                        Maker_Action__c = 'No Action',
                        Checker_Action__c = 'No Action',
                        Maker_Comments__c = '',
                        Checker_Comments__c = '',
                        Process_CheckList__c = processChecklist.Id,
                        Sequence__c = 14
                    ),
                    new Process_Checklist_Items__c(
                        Checklist_Name__c = 'Permitted Use confirmation required as per legal team (For each residential unit)',
                        Maker_Action__c = 'No Action',
                        Checker_Action__c = 'No Action',
                        Maker_Comments__c = '',
                        Checker_Comments__c = '',
                        Process_CheckList__c = processChecklist.Id,
                        Sequence__c = 14
                    ),
                    new Process_Checklist_Items__c(
                        Checklist_Name__c = 'District Service charges',
                        Maker_Action__c = 'No Action',
                        Checker_Action__c = 'No Action',
                        Maker_Comments__c = 'AED 00/sqft',
                        Checker_Comments__c = '',
                        Process_CheckList__c = processChecklist.Id,
                        Sequence__c = 16
                    ),
                    new Process_Checklist_Items__c(
                        Checklist_Name__c = 'Master Community Service charges (if applicable)',
                        Maker_Action__c = 'No Action',
                        Checker_Action__c = 'No Action',
                        Maker_Comments__c = '',
                        Checker_Comments__c = '',
                        Process_CheckList__c = processChecklist.Id,
                        Sequence__c = 17
                    ),
                    
                    
                    
                     new Process_Checklist_Items__c(
                        Checklist_Name__c = 'Central Water Heating charges',
                        Maker_Action__c = 'No Action',
                        Checker_Action__c = 'No Action',
                        Maker_Comments__c = '',
                        Checker_Comments__c = '',
                        Process_CheckList__c = processChecklist.Id,
                        Sequence__c = 18
                    ),
                     new Process_Checklist_Items__c(
                        Checklist_Name__c = 'District Cooling Service charges',
                        Maker_Action__c = 'No Action',
                        Checker_Action__c = 'No Action',
                        Maker_Comments__c = '',
                        Checker_Comments__c = '',
                        Process_CheckList__c = processChecklist.Id,
                        Sequence__c = 19
                    ),
                     new Process_Checklist_Items__c(
                        Checklist_Name__c = 'ACD will be mentioned as per the signed booking form',
                        Maker_Action__c = 'No Action',
                        Checker_Action__c = 'No Action',
                        Maker_Comments__c = '',
                        Checker_Comments__c = '',
                        Process_CheckList__c = processChecklist.Id,
                        Sequence__c = 20
                    )
             };
                 
                 System.debug('processChecklistItems = '+processChecklistItems);
            if (!processChecklistItems.isEmpty()) {     
            	insert processChecklistItems;
            }
        }

	/*@AuraEnabled
public static void updateSimpleChecklistItem(String itemId, String makerComments) {
    Process_Checklist_Items__c item = [
        SELECT Id FROM Process_Checklist_Items__c WHERE Id = :itemId LIMIT 1
    ];
    item.Maker_Comments__c = makerComments;
    update item;
}*/

@AuraEnabled
public static void updateSimpleChecklistItem(
    String itemId, 
    String checklistName, 
    String makerComments
) {
    Process_Checklist_Items__c item = [
        SELECT Id FROM Process_Checklist_Items__c WHERE Id = :itemId LIMIT 1
    ];
    item.Checklist_Name__c = checklistName;
    item.Maker_Comments__c = makerComments;
    update item;
}
}