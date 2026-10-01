/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/
public class MakerCheckerChecklistToPdfController {
    
    public class InputWrapper {
        @InvocableVariable(required=true)
        public Id businessProcessId;
    }
    
    public class OutputWrapper {
        @InvocableVariable public String status;         
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Generate and Attach Maker Checker Checklist PDF' description='Generates a PDF and attaches it to the Business Process Document')
    public static List<OutputWrapper> generateAndAttach(List<InputWrapper> requests) {
        List<OutputWrapper> results = new List<OutputWrapper>();
        
        // Defensive: Ensure there is at least one request
        if (requests == null || requests.isEmpty()) {
            OutputWrapper result = new OutputWrapper();
            result.status = 'Error';
            result.message = 'No input received.';
            results.add(result);
            return results;
        }
        
        Id bpId = requests[0].businessProcessId;
        OutputWrapper result = new OutputWrapper();
        
        if (bpId == null) {
            result.status = 'Error';
            result.message = 'Business Process ID is required.';
            results.add(result);
            return results;
        }
        
        System.debug('bpId=> ' + bpId);
        
        try {
            // Step 1: Find related Business_Process_Document__c
            Business_Process_Documents__c bpDoc = [
                SELECT Id 
                FROM Business_Process_Documents__c 
                WHERE Business_Process__c = :bpId
                ORDER BY CreatedDate DESC 
                LIMIT 1
            ];
            
            System.debug('bpDoc=> ' + bpDoc);
            
            // Step 2: Generate PDF from Visualforce page
            PageReference pdfPage = Page.MakerCheckerChecklistPdf;
            if (pdfPage == null) {
                result.status = 'Error';
                result.message = 'PDF page not found.';
                results.add(result);
                return results;
            }
            pdfPage.getParameters().put('id', bpId);
            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Test PDF Content'); // mock content in test
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }
            // Step 3: Create ContentVersion (File)
            ContentVersion cv = new ContentVersion(
                Title = 'Maker_Checker_Checklist',
                PathOnClient = 'Maker_Checker_Checklist.pdf',
                VersionData = pdfBlob
            );
            insert cv;
            
            cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            System.debug('cv.Id=> ' + cv.Id);
            
            // Step 4: Link to ContentDocument
            ContentDocument cd = [
                SELECT Id FROM ContentDocument WHERE Id = :cv.ContentDocumentId LIMIT 1
            ];
            
            System.debug('cd.Id=> ' + cd.Id);
            
            ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = cd.Id,
                LinkedEntityId = bpDoc.Id,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );
            insert cdl;
            
            result.status = 'Success';
            result.message = 'PDF successfully attached to Business Process Document.';
            
        } catch (Exception ex) {
            result.status = 'Error';
            result.message = 'Failed to generate or attach PDF: ' + ex.getMessage();
        }
        
        results.add(result);
        return results;
    }
    
    // Visualforce PDF controller fields
    public List<Process_Checklist_Items__c> checklistItems { get; set; }
 	public String makerName { get; set; }
    public String checkerName { get; set; }

    public String bpNumber { get; set; }
    public String bookingNumber { get; set; }
    public String unitNumber { get; set; }
    public String makChkName { get; set; }

    public MakerCheckerChecklistToPdfController() {
        String businessProcessId = ApexPages.currentPage().getParameters().get('id');
        if (businessProcessId == null) return;
        
        System.debug('businessProcessId=> ' + businessProcessId);
        
        // 1. Get the Business Process with Booking and Unit
        Business_Process__c bp = [
            SELECT Id, Name/*, Booking__r.Name,Booking__r.Unit__r.Name */
            FROM Business_Process__c 
            WHERE Id = :businessProcessId 
            LIMIT 1];
        
        System.debug('bp=> ' + bp);
            
        bpNumber = bp.Name;
       // bookingNumber = bp.Booking__r != null ? bp.Booking__r.Name : '';
       // unitNumber = (bp.Booking__r != null && bp.Booking__r.Unit__r != null) ? bp.Booking__r.Unit__r.Name : '';

        // 2. Get the Process Checklist
		List<Process_Checklist__c>  processCheckList= [
            select Id,Checklist_Metadata__r.Checklist_Name_in_short__c
            from Process_Checklist__c 
            where Business_Process__c =:businessProcessId 
            ORDER BY CreatedDate DESC 
            limit 1];
        
        System.debug('processCheckList=> ' + processCheckList);
        
        if (!processCheckList.isEmpty()) {
            Id processCheckListId = processCheckList[0].Id;
            makChkName=(!String.isBlank(processCheckList[0].Checklist_Metadata__r.Checklist_Name_in_short__c)) ?
                        processCheckList[0].Checklist_Metadata__r.Checklist_Name_in_short__c :
                        'Maker-Checker Checklist for SPA Maker';
            // 3. Get checklist items
            checklistItems = [
                SELECT Id, Checklist_Name__c, Name, Maker_Action__c, Checker_Action__c,
                Maker_Comments__c, Checker_Comments__c,
                Process_Checklist__r.Is_Maker_Review_Completed__c,
                Process_Checklist__r.Is_Checker_Review_Completed__c,
                Checker_Rejection_Reasons__c, Process_Checklist__c
                FROM Process_Checklist_Items__c
                WHERE Process_Checklist__c = : processCheckListId
                //ORDER BY Name
                 ORDER BY Sequence__c 
            ];
        }
        
        // 4. Get Step 1 and Step 2 from Business_Process_Step__c
        List<Business_Process_Step__c> busiProStepsList = [
            SELECT Step__c, Section_Number__c, Assigned_To__r.Name
            FROM Business_Process_Step__c
            WHERE Business_Process__c = :businessProcessId
        ];
        
        System.debug('busiProStepsList=> ' + busiProStepsList);
        
        for (Business_Process_Step__c step : busiProStepsList) {
            if (step.Section_Number__c == 1) {
                if (step.Assigned_To__r != null && !String.isBlank(step.Assigned_To__r.Name)) {
                    makerName = step.Assigned_To__r.Name;
                    System.debug('makerName=> ' +makerName);
                }                
            } else if (step.Section_Number__c == 2) {
                if (step.Assigned_To__r != null && !String.isBlank(step.Assigned_To__r.Name)) {
                    checkerName = step.Assigned_To__r.Name;
                	System.debug('checkerName=> ' +checkerName);
                }
            }
        }
    }    
}