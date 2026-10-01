@IsTest(SeeAllData=true)
private class DashboardFolderSharesCsvBatchTest {

    private class FolderShareMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            res.setBody(
                '{' +
                '"shares":[' +
                    '{' +
                        '"shareId":"0PS000000000001",' +
                        '"shareType":"User",' +
                        '"sharedWithId":"005000000000001",' +
                        '"sharedWithLabel":"Test User",' +
                        '"uniqueName":"testuser@example.com",' +
                        '"accessType":"View"' +
                    '}' +
                ']' +
                '}'
            );

            return res;
        }
    }

    private class FolderShareErrorMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');

            return res;
        }
    }

    @IsTest
    static void testExportDashboards() {

        Integer beforeCount = [
            SELECT Count()
            FROM ContentVersion
            WHERE Title LIKE 'Dashboard_Folder_Shares_%'
        ];

        Test.setMock(HttpCalloutMock.class, new FolderShareMock());

        Test.startTest();
        DashboardFolderSharesCsvBatch.exportDashboards(0);
        Test.stopTest();

        Integer afterCount = [
            SELECT Count()
            FROM ContentVersion
            WHERE Title LIKE 'Dashboard_Folder_Shares_%'
        ];

        System.assertEquals(beforeCount + 1, afterCount);
    }

    @IsTest
    static void testExportDashboards_CalloutFailure() {

        Integer beforeCount = [
            SELECT Count()
            FROM ContentVersion
            WHERE Title LIKE 'Dashboard_Folder_Shares_%'
        ];

        Test.setMock(HttpCalloutMock.class, new FolderShareErrorMock());

        Test.startTest();
        DashboardFolderSharesCsvBatch.exportDashboards(0);
        Test.stopTest();

        Integer afterCount = [
            SELECT Count()
            FROM ContentVersion
            WHERE Title LIKE 'Dashboard_Folder_Shares_%'
        ];

        System.assertEquals(beforeCount + 1, afterCount);
    }
}