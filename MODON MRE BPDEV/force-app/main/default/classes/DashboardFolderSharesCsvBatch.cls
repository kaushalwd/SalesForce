public class DashboardFolderSharesCsvBatch {

    public static void exportDashboards(Integer offsetValue) {

        // Get non-private dashboard folders
        List<Folder> folders = [
            SELECT Id, Name, AccessType
            FROM Folder
            WHERE Type = 'Dashboard'
            AND AccessType != 'Private'
            ORDER BY Name
            LIMIT 100
            OFFSET :offsetValue
        ];


        // Get dashboards once
        List<Dashboard> dashboards = [
            SELECT Id, Title, FolderName
            FROM Dashboard
            WHERE FolderName != null
        ];


        // Group dashboards by folder name
        Map<String, List<Dashboard>> dashboardsByFolder =
            new Map<String, List<Dashboard>>();


        for (Dashboard d : dashboards) {

            if (!dashboardsByFolder.containsKey(d.FolderName)) {

                dashboardsByFolder.put(
                    d.FolderName,
                    new List<Dashboard>()
                );
            }

            dashboardsByFolder.get(d.FolderName).add(d);
        }


        Http http = new Http();

        List<String> csvRows = new List<String>();

        csvRows.add(
            'Dashboard Title,Folder Name,Folder Id,Share Id,Share Type,Shared With Id,Shared With Name,Email,Access Type'
        );


        Integer processed = 0;
        Integer success = 0;
        Integer failed = 0;


        for (Folder folder : folders) {

            HttpRequest req = new HttpRequest();

            req.setEndpoint(
                URL.getOrgDomainUrl().toExternalForm()
                + '/services/data/v66.0/folders/'
                + folder.Id
                + '/shares'
            );

            req.setMethod('GET');

            req.setHeader(
                'Authorization',
                'Bearer ' + UserInfo.getSessionId()
            );


            try {

                HttpResponse res = http.send(req);

                processed++;


                if (res.getStatusCode() == 200) {

                    success++;


                    Map<String,Object> response =
                        (Map<String,Object>)
                        JSON.deserializeUntyped(
                            res.getBody()
                        );


                    List<Object> shares =
                        (List<Object>) response.get('shares');


                    List<Dashboard> folderDashboards =
                        dashboardsByFolder.get(folder.Name);


                    if (folderDashboards != null && shares != null) {


                        for (Dashboard dashboard : folderDashboards) {


                            for (Object obj : shares) {


                                Map<String,Object> share =
                                    (Map<String,Object>) obj;


                                csvRows.add(
                                    '"' + escapeCsv(dashboard.Title) + '",' +
                                    '"' + escapeCsv(folder.Name) + '",' +
                                    '"' + folder.Id + '",' +
                                    '"' + String.valueOf(share.get('shareId')) + '",' +
                                    '"' + String.valueOf(share.get('shareType')) + '",' +
                                    '"' + String.valueOf(share.get('sharedWithId')) + '",' +
                                    '"' + escapeCsv(String.valueOf(share.get('sharedWithLabel'))) + '",' +
                                    '"' + escapeCsv(String.valueOf(share.get('uniqueName'))) + '",' +
                                    '"' + String.valueOf(share.get('accessType')) + '"'
                                );
                            }
                        }
                    }


                } else {

                    failed++;

                    System.debug(
                        'FAILED Folder: ' +
                        folder.Id +
                        ' Status: ' +
                        res.getStatusCode() +
                        ' Body: ' +
                        res.getBody()
                    );
                }


            } catch (Exception e) {

                failed++;

                System.debug(
                    'ERROR Folder: ' +
                    folder.Id +
                    ' Message: ' +
                    e.getMessage()
                );
            }
        }


        // Create CSV File

        ContentVersion cv = new ContentVersion();

        cv.Title =
            'Dashboard_Folder_Shares_' +
            offsetValue +
            '_' +
            DateTime.now().format('yyyyMMdd_HHmmss');

        cv.PathOnClient =
            cv.Title + '.csv';

        cv.VersionData =
            Blob.valueOf(
                String.join(csvRows, '\n')
            );


        insert cv;


        System.debug('==============================');
        System.debug('Offset            : ' + offsetValue);
        System.debug('Folders Processed : ' + processed);
        System.debug('Successful Calls  : ' + success);
        System.debug('Failed Calls      : ' + failed);
        System.debug('CSV Created       : ' + cv.Title);
        System.debug('==============================');
    }


    private static String escapeCsv(String value) {

        if (value == null) {
            return '';
        }

        return value.replace('"', '""');
    }
}