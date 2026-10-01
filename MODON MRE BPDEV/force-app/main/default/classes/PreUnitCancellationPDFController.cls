/** Name              : PreUnitCancellationPDFController
 * description        : Controller used to generate and store a Pre Unit Cancellation PDF.
 *                      - Fetches Service Request details along with related Sales Order and financial data
 *                      - Retrieves Approval History (ProcessInstance & Steps) for display in PDF
 *                      - Captures current logged-in user details
 *                      - Generates PDF using Visualforce page
 *                      - Saves the generated PDF as a Salesforce File (ContentVersion)
 *                      - Links the file back to the Service Request record           
 *Created By          : Active Minds
 *********************************************************************************
*  Version  Author          Date        Notes
** 1.0      Chandu         09/04/2026    Initial
**********************************************************************************/

public class PreUnitCancellationPDFController {

    public ServiceRequest__c serviceRequest { get; private set; }
    public List<ApprovalStepWrapper> approvalSteps { get; private set; }
    public User currentUser { get; private set; }

    public PreUnitCancellationPDFController(ApexPages.StandardController std) {

        Id srId = ApexPages.currentPage().getParameters().get('id');
        if (srId == null) return;

        //Service Request Data (adjust fields if needed)
        serviceRequest = [
            SELECT Id, Name, Description__c,
                   SalesOrder__r.Name,
                   SalesOrder__r.CustomerAccount__r.Name,
                   ADM_Paid_Amount__c,
                   Total_Paid_Amount__c,
                   Forfeiture__c,
                   Market_Loss__c,
                   Payable_to_Customer__c,
                   Status__c,RecordTypeName__c,
                   Approval_Status__c
            FROM ServiceRequest__c
            WHERE Id = :srId
        ];

        // Approval History
        approvalSteps = new List<ApprovalStepWrapper>();

        for (ProcessInstance pi : [
            SELECT Id,
                   (SELECT StepStatus, Actor.Name, Actor.Title
                    FROM Steps
                    ORDER BY CreatedDate ASC)
            FROM ProcessInstance
            WHERE TargetObjectId = :srId
        ]) {
            for (ProcessInstanceStep step : pi.Steps) {

                if (step.StepStatus != 'Started') {
                    approvalSteps.add(
                        new ApprovalStepWrapper(
                            step.Actor != null ? step.Actor.Name : 'N/A',
                            step.Actor != null ? step.Actor.Title : 'N/A',
                            step.StepStatus
                        )
                    );
                }
            }
        }

        currentUser = [
            SELECT Name, Title
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
    }

    public class ApprovalStepWrapper {
        public String ApproverName { get; set; }
        public String Title { get; set; }
        public String Status { get; set; }
        public Datetime approvedDate {get;set;}

        public ApprovalStepWrapper(String name, String title, String status) {
            this.ApproverName = name;
            this.Title = title;
            this.Status = status;
        }
    }
    
    // Save PDF as Salesforce File
    public void savePdf(){

        try{
            PageReference pdfPage = Page.PreUnitCancellationPDFDownload;
            pdfPage.getParameters().put('id', serviceRequest.Id);
			
            Blob pdfBlob;
            if (Test.isRunningTest()) {
                // In test context, getContentAsPDF() cannot be used.
                // Use a small dummy blob so ContentVersion insert and file-link logic can be tested.
                pdfBlob = Blob.valueOf('Test Pre Unit Cancellation PDF Content');
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }
            // Create File
            ContentVersion cv = new ContentVersion();
            cv.Title = 'Pre Unit Cancellation - ' + serviceRequest.Name;
            cv.PathOnClient = 'PreUnitCancellation.pdf';
            cv.VersionData = pdfBlob;

            insert cv;

            // Link File to Record
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = [
                SELECT ContentDocumentId 
                FROM ContentVersion 
                WHERE Id = :cv.Id
            ].ContentDocumentId;
            cdl.LinkedEntityId = serviceRequest.Id;
            cdl.ShareType = 'V';

            insert cdl;

        } catch(Exception e){
            System.debug('PDF Save Error: ' + e.getMessage());
        }
    }


}