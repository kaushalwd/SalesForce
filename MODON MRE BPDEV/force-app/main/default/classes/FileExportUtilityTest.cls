@isTest
private class FileExportUtilityTest {

    @isTest
    static void testCreateExportFileReturnsDownloadUrl() {

        String base64Content = EncodingUtil.base64Encode(Blob.valueOf('<html><body>test</body></html>'));

        Test.startTest();
        String downloadUrl = FileExportUtility.createExportFile(base64Content, 'Test.xls');
        Test.stopTest();

        System.assert(downloadUrl.startsWith('/sfc/servlet.shepherd/version/download/'), 'Should return a version download URL');

        List<ContentVersion> versions = [
            SELECT Id, Title, PathOnClient FROM ContentVersion WHERE Title = 'Test.xls'
        ];

        System.assertEquals(1, versions.size(), 'A ContentVersion should have been created');
        System.assertEquals('Test.xls', versions[0].PathOnClient);
    }

    @isTest
    static void testCreateExportFileThrowsWhenBlank() {

        Boolean threw = false;

        Test.startTest();
        try {
            FileExportUtility.createExportFile(null, null);
        }
        catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'Should reject blank export content');
    }
}