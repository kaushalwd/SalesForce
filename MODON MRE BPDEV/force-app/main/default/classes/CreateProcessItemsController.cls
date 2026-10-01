/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/

public without sharing class CreateProcessItemsController {

    @AuraEnabled(cacheable=true)
    public static List<String> getChecklistProcessNames() {
        List<AggregateResult> results = [
            SELECT Check_List_Process_Name__c
            FROM Checklist_Metadata__c
            GROUP BY Check_List_Process_Name__c
        ];
        
        System.debug('results=>' + results);
        
        List<String> processNames = new List<String>();
        for (AggregateResult ar : results) {
            processNames.add((String) ar.get('Check_List_Process_Name__c'));
        }
        System.debug('processNames=>' + processNames);
        return processNames;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getChecklistNamesByProcess(String processName) {
        System.debug('processName=>' + processName);
        List<Checklist_Metadata__c> results = [
            SELECT Checklist_Name__c, Checklist_Name_in_short__c 
            FROM Checklist_Metadata__c
            WHERE Check_List_Process_Name__c = :processName
        ];

        System.debug('processName results=>' + results);
        
        List<String> checklistNames = new List<String>();
        for (Checklist_Metadata__c item : results) {
            checklistNames.add(item.Checklist_Name_in_short__c);
        }
        System.debug('checklistNames=>' + checklistNames);
        return checklistNames;
    }

    @AuraEnabled
    public static void createProcessChecklist(String checklistName, Id businessProcessId) {
        if (String.isBlank(checklistName)) {
            throw new IllegalArgumentException('Checklist name cannot be blank.');
        }
		System.debug('checklistName=> ' + checklistName);
        
        // Fetch checklist metadata
        Checklist_Metadata__c checklist = [
            SELECT Id, Name, Checklist_Name_in_short__c, Checklist_Name__c
            FROM Checklist_Metadata__c
            WHERE Checklist_Name_in_short__c = :checklistName
            LIMIT 1
        ];

        List<Checklist_Item_Metadata__c> checkListItem = [
            SELECT Id, Name,Checklist_Item_Metadata_Name__c,Sequence__c
            FROM Checklist_Item_Metadata__c
            WHERE Checklist_Metadata__r.Id = :checklist.Id
            ORDER BY CreatedDate ASC
        ];

        List<Process_Flow_Document__c> processFlowDocuments = [
            SELECT Id, Name, Checklist_Item_Metadata__c
            FROM Process_Flow_Document__c
            WHERE Checklist_Item_Metadata__c IN :checkListItem
        ];

        // Create Process Checklist
        Process_Checklist__c processChecklist = new Process_Checklist__c(
            Name__c = checklist.Name,
            Business_Process__c = businessProcessId,
            Checklist_Metadata__c=checklist.Id
        );
        insert processChecklist;
        
        Business_Process__c bp=new Business_Process__c();
        bp.Id=businessProcessId;
        bp.Latest_Process_Checklist__c=processChecklist.Id;
        update bp;

        // Create checklist items
        List<Process_Checklist_Items__c> processItems = new List<Process_Checklist_Items__c>();
        Map<Id, Id> itemMetaIdToProcessItemId = new Map<Id, Id>();

        for (Checklist_Item_Metadata__c item : checkListItem) {
            Process_Checklist_Items__c pci = new Process_Checklist_Items__c(
                Checklist_Name__c = item.Checklist_Item_Metadata_Name__c,
               // Checklist_Name__c = convertPlainTextToRichText(item.Checklist_Item_Metadata_Name__c),
                Maker_Action__c = 'No Action',
                Checker_Action__c = 'No Action',
                Maker_Comments__c = '',
                Checker_Comments__c = '',
                Process_CheckList__c = processChecklist.Id,
                Sequence__c = item.Sequence__c
            );
            processItems.add(pci);
        }
        
		System.debug('processItems=> ' + processItems);
        
        if (!processItems.isEmpty()) {
            insert processItems;

            for (Integer i = 0; i < checkListItem.size(); i++) {
                itemMetaIdToProcessItemId.put(checkListItem[i].Id, processItems[i].Id);
            }
        }

        // Create business process documents
        List<Business_Process_Documents__c> businessDocs = new List<Business_Process_Documents__c>();

        for (Process_Flow_Document__c doc : processFlowDocuments) {
            Id processChecklistItemId = itemMetaIdToProcessItemId.get(doc.Checklist_Item_Metadata__c);
            if (processChecklistItemId != null) {
                businessDocs.add(new Business_Process_Documents__c(
                    Process_Checklist_Items__c = processChecklistItemId,
                    Name = doc.Name
                ));
            }
        }

        System.debug('businessDocs=> ' + businessDocs);
        
        if (!businessDocs.isEmpty()) {
            insert businessDocs;
        }
    }
    public static String convertPlainTextToRichText(String input) {
    if (String.isBlank(input)) return '';
    
    // Escape HTML special characters if needed (optional, depending on use case)
    input = input.replaceAll('&', '&amp;')
                 .replaceAll('<', '&lt;')
                 .replaceAll('>', '&gt;');
    
    // Replace line breaks with <br/> and spaces with &nbsp; (if spacing is important)
    input = input.replaceAll('\n', '<br/>');
    
    return input;
}

}