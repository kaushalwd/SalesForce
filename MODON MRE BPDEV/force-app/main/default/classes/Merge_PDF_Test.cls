@isTest
public class Merge_PDF_Test {
    static TestMethod void runTest1(){
        Documents__c docObj = new Documents__c();
        docObj.Name = 'Emirates Id';
        INSERT docObj;
        
        Blob bodyBlob1=Blob.valueOf('Unit Test ContentVersion Body1');
        String base64String1 = EncodingUtil.base64Encode(bodyBlob1);
        
        Blob bodyBlob2=Blob.valueOf('Unit Test ContentVersion Body2');
        String base64String2 = EncodingUtil.base64Encode(bodyBlob2);
        
        Blob bodyBlob3=Blob.valueOf('Unit Test ContentVersion Body3');
        String base64String3 = EncodingUtil.base64Encode(bodyBlob3);
        
        Blob bodyBlob4=Blob.valueOf('Unit Test ContentVersion Body4');
        String base64String4 = EncodingUtil.base64Encode(bodyBlob4);
        
        Blob bodyBlob5=Blob.valueOf('Unit Test ContentVersion Body5');
        String base64String5 = EncodingUtil.base64Encode(bodyBlob5);
        
        Merge_PDF.saveMergedPDFs(base64String1, String.valueOf(docObj.Id), 'test 1');
        Merge_PDF.saveMergedPDFs(base64String2, String.valueOf(docObj.Id), 'test 2');
        Merge_PDF.saveMergedPDFs(base64String3, String.valueOf(docObj.Id), 'test 3');
        Merge_PDF.saveMergedPDFs(base64String4, String.valueOf(docObj.Id), 'test 4');
        Merge_PDF.saveMergedPDFs(base64String4, String.valueOf(docObj.Id), 'testT 4');
        
        Merge_PDF.getPdfFilesWithIdsAsBase64(String.valueOf(docObj.Id));
    }
    
    static TestMethod void runTest2(){
        Documents__c docObj = new Documents__c();
        docObj.Name = 'Emirates Id';
        INSERT docObj;
        
        Blob bodyBlob1=Blob.valueOf('Unit Test ContentVersion Body1');
        String base64String1 = EncodingUtil.base64Encode(bodyBlob1);
        
        Blob bodyBlob2=Blob.valueOf('Unit Test ContentVersion Body2');
        String base64String2 = EncodingUtil.base64Encode(bodyBlob2);
        
        Blob bodyBlob3=Blob.valueOf('Unit Test ContentVersion Body3');
        String base64String3 = EncodingUtil.base64Encode(bodyBlob3);
        
        Blob bodyBlob4=Blob.valueOf('Unit Test ContentVersion Body4');
        String base64String4 = EncodingUtil.base64Encode(bodyBlob4);
        String file_name = 'mKUJxSPO4N7l5uAUqMXTD2LgGgdYZ4RjbfQ1GJpJtgEhNZIfDSrFuWa2iInCU9vXEbhWxRTXf42HWhxTlfejqgMGSOYtAvgLFiQglI6AzLPzY55XN8RVL9TuY14jCfzz';
        try{
            Merge_PDF.saveMergedPDFs(base64String1, String.valueOf(docObj.Id), file_name);
            Merge_PDF.saveMergedPDFs('', '', '');
            Merge_PDF.createContentLink(null,null);
        }Catch (Exception ex){
            system.debug(ex);
        }
        
    }
    
    static TestMethod void testCreateDuplicateContentLink() {
        // Create a ContentVersion
        ContentVersion contentVersion = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'testfile.txt',
            VersionData = Blob.valueOf('Test Data')
        );
        insert contentVersion;
        Id contentVersionId = contentVersion.Id;
        
        // Link to a record
        Id recordId = UserInfo.getUserId();
        try{
            ContentDocumentLink firstLink = Merge_PDF.createContentLink(contentVersionId, recordId);
        }Catch (Exception ex){
            system.debug(ex);
        }
        
        // Attempt to create a duplicate link
        try {
            ContentDocumentLink duplicateLink = Merge_PDF.createContentLink(contentVersionId, recordId);
            System.assertEquals(null, duplicateLink, 'Expected null result due to duplicate link creation');
        } catch (Exception e) {
            System.assert(false, 'Unexpected exception: ' + e.getMessage());
        }
    }
    
    static TestMethod void runTest3(){
        Documents__c docObj = new Documents__c();
        docObj.Name = 'SPA';
        INSERT docObj;
        
        Blob bodyBlob1=Blob.valueOf('Unit Test ContentVersion Body1');
        String base64String1 = EncodingUtil.base64Encode(bodyBlob1);
        
        Blob bodyBlob2=Blob.valueOf('Unit Test ContentVersion Body2');
        String base64String2 = EncodingUtil.base64Encode(bodyBlob2);
        
        Blob bodyBlob3=Blob.valueOf('Unit Test ContentVersion Body3');
        String base64String3 = EncodingUtil.base64Encode(bodyBlob3);
        
        Blob bodyBlob4=Blob.valueOf('Unit Test ContentVersion Body4');
        String base64String4 = EncodingUtil.base64Encode(bodyBlob4);
        
        Blob bodyBlob5=Blob.valueOf('Unit Test ContentVersion Body5');
        String base64String5 = EncodingUtil.base64Encode(bodyBlob5);
        
        Merge_PDF.saveMergedPDFs(base64String1, String.valueOf(docObj.Id), 'SPA 1');
        Merge_PDF.saveMergedPDFs(base64String2, String.valueOf(docObj.Id), 'South Californian_ 2');
        Merge_PDF.saveMergedPDFs(base64String3, String.valueOf(docObj.Id), 'Draft Unit Plan 3');
        Merge_PDF.saveMergedPDFs(base64String4, String.valueOf(docObj.Id), 'test 4');
        
        Merge_PDF.getPdfFilesWithIdsAsBase64(String.valueOf(docObj.Id));
    }
}