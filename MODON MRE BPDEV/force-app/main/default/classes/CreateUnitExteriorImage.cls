public class CreateUnitExteriorImage {
    
    public static void createUnitExteriorImage(List<SalesOrder__c> listSalesOrder) {
    Map<String, String> unitNameToImageName = new Map<String, String>();
    Set<Id> phaseIds = new Set<Id>();
    Set<Id> unitIds = new Set<Id>();

    for (SalesOrder__c so : listSalesOrder) {
        if (so.Unit__c != null && so.Unit__r != null) {
            phaseIds.add(so.Unit__r.Phase__c);
            unitIds.add(so.Unit__c);
            unitNameToImageName.put(so.Unit__r.Name, so.Unit__r.Unit_Image_Name_pc__c);
        }
    }

    // Get ContentVersion files available in those Phase folders
    Map<String, ContentVersion> imageNameToCV = new Map<String, ContentVersion>();
    for (ContentVersion cv : [
        SELECT Id, Title, PathOnClient, VersionData, FirstPublishLocationId
        FROM ContentVersion
        WHERE FirstPublishLocationId IN :phaseIds
    ]) {
        imageNameToCV.put(cv.Title, cv);
    }

    List<ContentVersion> contentVersionsToInsert = new List<ContentVersion>();
    Set<Id> documentIdsToUpdate = new Set<Id>();

    // Query Documents__c and their attached ContentDocuments
    List<Documents__c> documentList = [
        SELECT Id, Name, Status__c, Unit__c, Unit__r.Name,
            (SELECT ContentDocumentId FROM ContentDocumentLinks)
        FROM Documents__c
        WHERE Name = 'Exterior' AND Unit__c IN :unitIds
    ];

    for (Documents__c doc : documentList) {
        String unitName = doc.Unit__r != null ? doc.Unit__r.Name : null;
        if (unitName == null || !unitNameToImageName.containsKey(unitName)) continue;

        String imageFileName = unitNameToImageName.get(unitName);
        ContentVersion sourceCV = imageNameToCV.get(imageFileName);
        if (sourceCV == null) continue;

        if (doc.Status__c != 'Uploaded' || doc.ContentDocumentLinks.isEmpty()) {
            // No attachment → insert new ContentVersion
            ContentVersion newCV = new ContentVersion();
            newCV.Title = imageFileName;
            newCV.PathOnClient = imageFileName + '.jpg';
            newCV.VersionData = sourceCV.VersionData;
            newCV.FirstPublishLocationId = doc.Id;
            contentVersionsToInsert.add(newCV);
            documentIdsToUpdate.add(doc.Id);
        } else {
            // Attachment exists → create a new version under the same ContentDocument
            for (ContentDocumentLink cdl : doc.ContentDocumentLinks) {
                ContentVersion newVersion = new ContentVersion();
                newVersion.Title = imageFileName;
                newVersion.PathOnClient = imageFileName + '.jpg';
                newVersion.VersionData = sourceCV.VersionData;
                newVersion.ContentDocumentId = cdl.ContentDocumentId; // Append new version
                contentVersionsToInsert.add(newVersion);
                documentIdsToUpdate.add(doc.Id);
            }
        }
    }

    if (!contentVersionsToInsert.isEmpty()) {
        Database.UpsertResult[] results = Database.upsert(contentVersionsToInsert, false);
        Set<Id> successfulCVIds = new Set<Id>();

        for (Database.UpsertResult res : results) {
            if (res.isSuccess()) {
                successfulCVIds.add(res.getId());
                System.debug('Inserted ContentVersion with ID: ' + res.getId());
            } else {
                for (Database.Error err : res.getErrors()) {
                    LoggerService.save(LoggerService.createAPILog(
                        'Unit Level Image - Exterior',
                        'CreateUnitExteriorImage',
                        'CreateUnitExteriorImage',
                        err.getMessage(),
                        err.getMessage(),
                        'Error Message: ' + err.getMessage(),
                        'Apex Log'
                    ));
                }
            }
        }

        if (!documentIdsToUpdate.isEmpty()) {
            ContentPublicURLHelper.getPublicURLByContentVersionId(documentIdsToUpdate);
        }
    }
}

    
}