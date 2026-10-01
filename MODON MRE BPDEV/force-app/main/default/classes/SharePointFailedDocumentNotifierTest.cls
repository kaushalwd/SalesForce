@isTest
public class SharePointFailedDocumentNotifierTest {
    
    @isTest
    static void testSendFailedDocumentEmail() {
        
        /* ================= CREATE TEST DOCUMENT ================= */
        
        Documents__c doc = new Documents__c();
        
        doc.Name = 'Test SharePoint File';
        doc.SharePoint_Status__c = 'Failed';
        doc.SharePoint_Error__c = 'Test Error';
        doc.SharePoint_Last_Sync__c = System.now();
        
        insert doc;
        
        /* ================= EXECUTE METHOD ================= */
        
        Test.startTest();
        
        SharePointFailedDocumentNotifier.sendFailedDocumentEmail();
        
        Test.stopTest();
    }
    
    @isTest
    static void testExecuteSchedulable() {
        
        /* ================= CREATE TEST DOCUMENT ================= */
        
        Documents__c doc = new Documents__c();
        
        doc.Name = 'Scheduled Test File';
        doc.SharePoint_Status__c = 'Failed';
        doc.SharePoint_Error__c = 'Scheduler Error';
        doc.SharePoint_Last_Sync__c = System.now();
        
        insert doc;
        
        /* ================= SCHEDULE JOB ================= */
        
        Test.startTest();
        
        String cronExp = '0 0 0 1 1 ? 2099';
        
        System.schedule(
            'SharePoint Failed Document Scheduler Test',
            cronExp,
            new SharePointFailedDocumentNotifier()
        );
        
        Test.stopTest();
    }
    
    @isTest
    static void testNoFailedDocuments() {
        
        /* ================= EXECUTE METHOD WITHOUT DATA ================= */
        
        Test.startTest();
        
        SharePointFailedDocumentNotifier.sendFailedDocumentEmail();
        
        Test.stopTest();
    }
}