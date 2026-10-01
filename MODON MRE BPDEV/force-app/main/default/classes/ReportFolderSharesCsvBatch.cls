public class ReportFolderSharesCsvBatch {

    public static void exportFolders(Integer offsetValue) {

        // Get non-private report folders in chunks of 100
        List<Folder> folders = [
            SELECT Id, Name, AccessType
            FROM Folder
            WHERE Type = 'Report'
            AND AccessType != 'Private'
            ORDER BY Name
            LIMIT 100
            OFFSET :offsetValue
        ];


        // Get all reports once
        List<Report> reports = [
            SELECT Id, Name, FolderName
            FROM Report
            WHERE FolderName != null
        ];


        // Group reports by folder
        Map<String, List<Report>> reportsByFolder =
            new Map<String, List<Report>>();


        for (Report r : reports) {

            if (!reportsByFolder.containsKey(r.FolderName)) {

                reportsByFolder.put(
                    r.FolderName,
                    new List<Report>()
                );
            }

            reportsByFolder.get(r.FolderName).add(r);
        }


        Http http = new Http();

        List<String> csvRows = new List<String>();

        csvRows.add(
            'Report Name,Folder Name,Folder Id,Share Id,Share Type,Shared With Id,Shared With Name,Email,Access Type'
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
                        (List<Object>)response.get('shares');


                    List<Report> folderReports =
                        reportsByFolder.get(folder.Name);


                    if (folderReports != null && shares != null) {


                        for (Report report : folderReports) {


                            for (Object obj : shares) {

                                Map<String,Object> share =
                                    (Map<String,Object>)obj;


                                csvRows.add(
                                    '"' + escapeCsv(report.Name) + '",' +
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


            } catch(Exception e) {

                failed++;

                System.debug(
                    'ERROR Folder: ' +
                    folder.Id +
                    ' Message: ' +
                    e.getMessage()
                );
            }
        }


        // Create CSV file

        ContentVersion cv = new ContentVersion();

        cv.Title =
            'Report_Folder_Shares_' +
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
        System.debug('CSV File Created  : ' + cv.Title);
        System.debug('==============================');
    }


    private static String escapeCsv(String value) {

        if (value == null) {
            return '';
        }

        return value.replace('"', '""');
    }
}