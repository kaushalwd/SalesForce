/**
 * @***************************************           : ***************************************
 * @Name                                              : Enter description here
 * @Description                                       : Enter description here
 * @Usage                                             : Enter usage here
 * @Author                                            : AMGS
 * @------------------------------------------------  : ------------------------------------------------
 * @Version Comment                                   : 1.0
 * @Author                                            : Fatima Khan
 * @Date                                              : 09-17-2025
 * @***************************************           : ***************************************
**/
// /**
//  * @***************************************           : ***************************************
//  * @Name                                              : MBP_ProjectDetailPageController
//  * @Description                                       : mbp_ProjectDetailPageLWC's controller
//  * @Usage                                             : mbp_ProjectDetailPageLWC
//  * @Author                                            : AMGS
//  * @------------------------------------------------  : ------------------------------------------------
//  * @Version Comment                                   : 1.0
//  * @Author                                            : Fatima Khan
//  * @Date                                              : 09-15-2025
//  * @***************************************           : ***************************************
//  **/
public without sharing class MBP_ProjectDetailPageController {

//     public class ProjectBundle {
//         @AuraEnabled public Project__c Project;
//         @AuraEnabled public List<OfferLines__c> OfferLines;
//         @AuraEnabled public List<PaymentPlan__c> PaymentPlans;
//         @AuraEnabled public List<String> Amenities;
//         @AuraEnabled public String MasterPlanImage;
//         @AuraEnabled public Map<String, List<String>> Images;
//         @AuraEnabled public Map<String, List<String>> UnitImages;
//         @AuraEnabled public Map<String, String> DownloadableDocuments;
//         @AuraEnabled public Map<Id, List<PaymentInstallements__c>> InstallmentsByPlan;
//         @AuraEnabled public List<FloorPlanDTO> FloorPlans;
//     }

    public class UnitWrapper {
        @AuraEnabled public Id unitId { get; set; }
        @AuraEnabled public String unitName { get; set; }
        @AuraEnabled public String bedrooms { get; set; }
        @AuraEnabled public Decimal price { get; set; }
        @AuraEnabled public String area { get; set; }
    }

//     public class FloorPlanDTO {
//         @AuraEnabled public String  UnitType;
//         @AuraEnabled public Integer Beds;
//         @AuraEnabled public Integer Baths;
//         @AuraEnabled public Decimal StartingArea;
//         @AuraEnabled public String  ImageUrl;
//         @AuraEnabled public Id      VersionId;
//         @AuraEnabled public String  FileExtension;
//     }

    @AuraEnabled(cacheable=true)
    public static List<UnitWrapper> fetchUnits(Id projectId) {
        List<UnitWrapper> result = new List<UnitWrapper>();

        for (Unit__c unitRow : [
            SELECT Id, Name, Number_of_Bedrooms__c, TotalPrice__c, AreaUnitofMeasure__c
            FROM Unit__c
            WHERE Phase__r.Project__c = :projectId
        ]) {
            UnitWrapper unitWrap = new UnitWrapper();
            unitWrap.unitId   = unitRow.Id;
            unitWrap.unitName = unitRow.Name;
            unitWrap.bedrooms = unitRow.Number_of_Bedrooms__c;
            unitWrap.price    = unitRow.TotalPrice__c;
            unitWrap.area     = String.valueOf(unitRow.AreaUnitofMeasure__c);
            result.add(unitWrap);
        }
        return result;
    }

//     private static String mimeFromExt(String ext) {
//         if (ext == null) return 'application/octet-stream';
//         ext = ext.toLowerCase();
//         if (ext == 'jpg'  || ext == 'jpeg') return 'image/jpeg';
//         if (ext == 'png')  return 'image/png';
//         if (ext == 'gif')  return 'image/gif';
//         if (ext == 'webp') return 'image/webp';
//         if (ext == 'svg')  return 'image/svg+xml';
//         if (ext == 'pdf')  return 'application/pdf';
//         return 'application/octet-stream';
//     }

//     public static String toDataUri(ContentVersion versionRow) {
//         return 'data:' + mimeFromExt(versionRow.FileExtension) + ';base64,' +
//             EncodingUtil.base64Encode(versionRow.VersionData);
//     }

//     private class DocAggregate {
//         String masterPlan;
//         Map<String, List<String>> imagesByType;
//         Map<String, String> downloadByName;
//         List<FloorPlanDTO> floorPlans;
//     }

//     private static Map<Id, DocAggregate> docCacheByProject = new Map<Id, DocAggregate>();

//     private static void addAllForName(
//         Map<String, List<ContentVersion>> versionsByName,
//         String logicalName,
//         List<String> aggregateImagesByType
//     ) {
//         List<ContentVersion> versions = versionsByName.get(logicalName);
//         if (versions == null || versions.isEmpty()) return;
//         for (ContentVersion v : versions) {
//             aggregateImagesByType.add(toDataUri(v));
//         }
//     }

//     private static DocAggregate loadAllDocuments(Id projectId) {
//         if (docCacheByProject.containsKey(projectId)) return docCacheByProject.get(projectId);

//         DocAggregate aggregate = new DocAggregate();
//         aggregate.imagesByType = new Map<String, List<String>>{
//             'Thumbnail' => new List<String>(),
//             'Gallery'   => new List<String>()
//         };
//         aggregate.downloadByName = new Map<String, String>();
//         aggregate.floorPlans = new List<FloorPlanDTO>();

//         Set<String> wantedNames = new Set<String>{
//             'Master Plan', 'Thumbnail', 'Gallery',
//             'English brochure', 'Arabic Brochure', 'Marketing Material'
//         };

//         List<Documents__c> documentRows = [
//             SELECT Id, Name,
//                    Document_Unit_Type__c, Number_of_Beds__c, Number_of_Bathrooms__c, Starting_Area__c
//             FROM Documents__c
//             WHERE Project__c = :projectId
//             AND (
//                 Name IN :wantedNames
//                 OR Name LIKE '%floor plan%'
//                 OR Name LIKE '%Floor Plan%'
//             )
//         ];
//         if (documentRows.isEmpty()) {
//             docCacheByProject.put(projectId, aggregate);
//             return aggregate;
//         }

//         Map<String, List<Id>> documentIdsByName = new Map<String, List<Id>>();
//         Set<Id> allDocumentIds = new Set<Id>();
//         Map<Id, FloorPlanDTO> floorPlanMetaByDocumentId = new Map<Id, FloorPlanDTO>();
//         Map<Id, String> nameByDocId = new Map<Id, String>();

//         for (Documents__c doc : documentRows) {
//             allDocumentIds.add(doc.Id);
//             nameByDocId.put(doc.Id, doc.Name);
//             if (!documentIdsByName.containsKey(doc.Name)) {
//                 documentIdsByName.put(doc.Name, new List<Id>());
//             }
//             documentIdsByName.get(doc.Name).add(doc.Id);

//             String nm = (doc.Name == null) ? '' : doc.Name;
//             if (nm.toLowerCase().contains('floor plan')) {
//                 FloorPlanDTO dto = new FloorPlanDTO();
//                 dto.UnitType     = String.valueOf(doc.Document_Unit_Type__c);
//                 dto.Beds         = (Integer) doc.Number_of_Beds__c;
//                 dto.Baths        = (Integer) doc.Number_of_Bathrooms__c;
//                 dto.StartingArea = (Decimal) doc.Starting_Area__c;
//                 floorPlanMetaByDocumentId.put(doc.Id, dto);
//             }
//         }

//         Map<Id, List<ContentVersion>> versionsByDocumentId = latestVersionsByLinked(allDocumentIds);
//         Map<String, List<ContentVersion>> versionsByName =
//             buildVersionsByNameIndex(documentIdsByName, versionsByDocumentId);

//         addAllForName(versionsByName, 'Thumbnail', aggregate.imagesByType.get('Thumbnail'));
//         addAllForName(versionsByName, 'Gallery',   aggregate.imagesByType.get('Gallery'));

//         Set<String> downloadNamesSet =
//             new Set<String>{ 'English brochure', 'Arabic Brochure', 'Marketing Material' };

//         for (Id docId : versionsByDocumentId.keySet()) {
//             String fileName = nameByDocId.get(docId);
//             if (String.isBlank(fileName)) continue;

//             List<ContentVersion> vers = versionsByDocumentId.get(docId);
//             if (vers == null || vers.isEmpty()) continue;

//             if (aggregate.masterPlan == null && fileName == 'Master Plan') {
//                 aggregate.masterPlan = toDataUri(vers[0]);
//             }

//             if (downloadNamesSet.contains(fileName) && !aggregate.downloadByName.containsKey(fileName)) {
//                 aggregate.downloadByName.put(fileName, toDataUri(vers[0]));
//             }

//             if (aggregate.masterPlan != null
//                 && aggregate.downloadByName.size() == downloadNamesSet.size()) {
//                 // Collected all targeted items — no-op early-exit point if desired.
//             }
//         }

//         for (Id fpDocId : floorPlanMetaByDocumentId.keySet()) {
//             List<ContentVersion> versions = versionsByDocumentId.get(fpDocId);
//             if (versions != null && !versions.isEmpty()) {
//                 FloorPlanDTO dto = floorPlanMetaByDocumentId.get(fpDocId);
//                 ContentVersion v = versions[0];
//                 dto.ImageUrl      = toDataUri(v);
//                 dto.VersionId     = v.Id;
//                 dto.FileExtension = v.FileExtension;
//                 aggregate.floorPlans.add(dto);
//             }
//         }

//         docCacheByProject.put(projectId, aggregate);
//         return aggregate;
//     }

//     @AuraEnabled(cacheable=true)
//     public static List<FloorPlanDTO> fetchFloorPlans(Id projectId) {
//         return loadAllDocuments(projectId).floorPlans;
//     }

//     @AuraEnabled(cacheable=true)
//     public static String fetchMasterPlanImage(Id projectId) {
//         return loadAllDocuments(projectId).masterPlan;
//     }

//     @AuraEnabled(cacheable=true)
//     public static Map<String, List<String>> fetchProjectImages(Id projectId) {
//         DocAggregate aggregate = loadAllDocuments(projectId);

//         Map<String, List<String>> imagesMap = new Map<String, List<String>>();
//         imagesMap.put('Thumbnail', new List<String>(aggregate.imagesByType.get('Thumbnail')));
//         imagesMap.put('Gallery',   new List<String>(aggregate.imagesByType.get('Gallery')));
//         return imagesMap;
//     }

//     @AuraEnabled(cacheable=true)
//     public static Map<String, List<String>> fetchUnitImages(Id unitId) {

//         Map<String, List<String>> imagesByType = new Map<String, List<String>>();
//         imagesByType.put('Exterior', new List<String>());
//         imagesByType.put('Interior', new List<String>());

//         List<Documents__c> docRows = [
//             SELECT Id, Name
//             FROM Documents__c
//             WHERE Unit__c = :unitId
//             AND Name IN ('Exterior', 'Interior')
//         ];
//         if (docRows.isEmpty()) return imagesByType;

//         Set<Id> allDocIds = new Set<Id>();
//         Map<Id, String> nameByDocId = new Map<Id, String>();
//         for (Documents__c d : docRows) {
//             allDocIds.add(d.Id);
//             nameByDocId.put(d.Id, d.Name);
//         }

//         Map<Id, List<ContentVersion>> versionsByDocId = latestVersionsByLinked(allDocIds);

//         for (Id docId : versionsByDocId.keySet()) {
//             String section = nameByDocId.get(docId);
//             if (String.isBlank(section)) continue;

//             List<ContentVersion> vers = versionsByDocId.get(docId);
//             if (vers == null || vers.isEmpty()) continue;

//             List<String> bucket = imagesByType.get(section);
//             if (bucket == null) {
//                 bucket = new List<String>();
//                 imagesByType.put(section, bucket);
//             }
//             for (ContentVersion v : vers) {
//                 bucket.add(toDataUri(v));
//             }
//         }

//         return imagesByType;
//     }

//     @AuraEnabled(cacheable=true)
//     public static Map<String, String> fetchDownloadableDocuments(Id projectId) {
//         Map<String, String> downloadsByName =
//             new Map<String, String>(loadAllDocuments(projectId).downloadByName);
//         return downloadsByName;
//     }

//     @AuraEnabled(cacheable=true)
//     public static List<PaymentPlan__c> fetchPaymentPlansWithInstallments(Id projectId) {
//         if (projectId == null) return new List<PaymentPlan__c>();

//         String childRel = getInstallmentsChildRelName();

//         String soql =
//             'SELECT Id, Name, Classification__c, PaymentPlanStructure__c, Unit__r.Name, ' +
//             '       (SELECT Id, Name, Milestone__c, PaymentInstallment__c, MilestoneNumber__c, MilestoneDate__c ' +
//             '        FROM ' + childRel + ' ' +
//             '        ORDER BY MilestoneNumber__c, MilestoneDate__c, Name) ' +
//             'FROM PaymentPlan__c ' +
//             'WHERE Project__c = :projectId AND isActive__c = true';

//         return Database.query(soql);
//     }

//     /**
//      * Refactored to remove nested for, test extensively
//      */
//     public static Map<Id, List<ContentVersion>> latestVersionsByLinked(Set<Id> linkedIds) {
//         Map<Id, List<ContentVersion>> resultMap = new Map<Id, List<ContentVersion>>();
//         if (linkedIds.isEmpty()) return resultMap;

//         List<ContentDocumentLink> linkRows = [
//             SELECT ContentDocumentId, LinkedEntityId
//             FROM ContentDocumentLink
//             WHERE LinkedEntityId IN :linkedIds
//         ];
//         if (linkRows.isEmpty()) return resultMap;

//         Set<Id> allDocIds = new Set<Id>();
//         for (ContentDocumentLink l : linkRows) allDocIds.add(l.ContentDocumentId);
//         if (allDocIds.isEmpty()) return resultMap;

//         List<ContentVersion> versionRows = [
//             SELECT Id, Title, FileExtension, ContentDocumentId, VersionData, IsLatest
//             FROM ContentVersion
//             WHERE ContentDocumentId IN :allDocIds
//             AND IsLatest = true
//         ];
//         Map<Id, List<ContentVersion>> versionsByDocId = new Map<Id, List<ContentVersion>>();
//         for (ContentVersion v : versionRows) {
//             if (!versionsByDocId.containsKey(v.ContentDocumentId)) {
//                 versionsByDocId.put(v.ContentDocumentId, new List<ContentVersion>());
//             }
//             versionsByDocId.get(v.ContentDocumentId).add(v);
//         }

//         for (ContentDocumentLink linkRow : linkRows) {
//             List<ContentVersion> docVers = versionsByDocId.get(linkRow.ContentDocumentId);
//             if (docVers == null || docVers.isEmpty()) continue;

//             List<ContentVersion> bucket = resultMap.get(linkRow.LinkedEntityId);
//             if (bucket == null) {
//                 bucket = new List<ContentVersion>();
//                 resultMap.put(linkRow.LinkedEntityId, bucket);
//             }
//             bucket.addAll(docVers);
//         }

//         return resultMap;
//     }

//     @AuraEnabled(cacheable=true)
//     public static ProjectBundle fetchProjectBundleById(Id projectId) {
//         ProjectBundle bundle = new ProjectBundle();

//         try {
//             Project__c project = fetchProjects(projectId);
//             bundle.Project = project;
//         } catch (Exception e) {
//             bundle.Project = null;
//         }

//         try {
//             bundle.OfferLines = fetchOfferLines(projectId);
//         } catch (Exception e) {
//             bundle.OfferLines = new List<OfferLines__c>();
//         }

//         try {
//             List<PaymentPlan__c> plansWithChildren = fetchPaymentPlansWithInstallments(projectId);
//             bundle.PaymentPlans = plansWithChildren;
//             bundle.InstallmentsByPlan = new Map<Id, List<PaymentInstallements__c>>();

//             String childRel = getInstallmentsChildRelName();

//             for (PaymentPlan__c planRow : plansWithChildren) {
//                 List<SObject> rawChildren = (List<SObject>) planRow.getSObjects(childRel);
//                 List<PaymentInstallements__c> childList = new List<PaymentInstallements__c>();
//                 if (rawChildren != null && !rawChildren.isEmpty()) {
//                     for (SObject so : rawChildren) childList.add((PaymentInstallements__c) so);
//                 }
//                 bundle.InstallmentsByPlan.put(planRow.Id, childList);
//             }
//         } catch (Exception e) {
//             bundle.PaymentPlans = new List<PaymentPlan__c>();
//             bundle.InstallmentsByPlan = new Map<Id, List<PaymentInstallements__c>>();
//         }

//         try { bundle.Amenities       = fetchAmenities(projectId); }   catch (Exception e) { bundle.Amenities = new List<String>(); }
//         try { bundle.MasterPlanImage = fetchMasterPlanImage(projectId); } catch (Exception e) { bundle.MasterPlanImage = null; }
//         try { bundle.Images          = fetchProjectImages(projectId); }   catch (Exception e) { bundle.Images = new Map<String, List<String>>(); }
//         try { bundle.DownloadableDocuments = fetchDownloadableDocuments(projectId); } catch (Exception e) { bundle.DownloadableDocuments = new Map<String, String>(); }
//         try { bundle.FloorPlans      = fetchFloorPlans(projectId); }  catch (Exception e) { bundle.FloorPlans = new List<FloorPlanDTO>(); }

//         return bundle;
//     }

//     private static Map<String, List<ContentVersion>> buildVersionsByNameIndex(
//         Map<String, List<Id>> documentIdsByName,
//         Map<Id, List<ContentVersion>> versionsByDocumentId
//     ) {
//         Map<String, List<ContentVersion>> versionsByName = new Map<String, List<ContentVersion>>();
//         for (String nameKey : documentIdsByName.keySet()) {
//             List<ContentVersion> combined = new List<ContentVersion>();
//             List<Id> docIds = documentIdsByName.get(nameKey);
//             if (docIds == null) continue;
//             for (Id docId : docIds) {
//                 List<ContentVersion> vers = versionsByDocumentId.get(docId);
//                 if (vers != null && !vers.isEmpty()) combined.addAll(vers);
//             }
//             if (!combined.isEmpty()) versionsByName.put(nameKey, combined);
//         }
//         return versionsByName;
//     }

//     @TestVisible
//     private static String getInstallmentsChildRelName() {
//         Schema.SObjectType parentType = Schema.getGlobalDescribe().get('PaymentPlan__c');
//         Schema.SObjectType childType  = Schema.getGlobalDescribe().get('PaymentInstallements__c');

//         if (parentType == null || childType == null) {
//             throw new AuraHandledException('PaymentPlan__c or PaymentInstallements__c not found in schema.');
//         }

//         Schema.DescribeSObjectResult parentDescribe = parentType.getDescribe();
//         for (Schema.ChildRelationship cr : parentDescribe.getChildRelationships()) {
//             if (cr.getChildSObject() == childType) {
//                 Schema.SObjectField relField = cr.getField();
//                 if (relField != null) {
//                     Schema.DescribeFieldResult fr = relField.getDescribe();
//                     if (fr != null && String.valueOf(fr.getName()) == 'PaymentInstallment__c') {
//                         return cr.getRelationshipName();
//                     }
//                 }
//             }
//         }

//         for (Schema.ChildRelationship cr : parentDescribe.getChildRelationships()) {
//             if (cr.getChildSObject() == childType && cr.getRelationshipName() != null) {
//                 return cr.getRelationshipName();
//             }
//         }

//         throw new AuraHandledException(
//             'Could not resolve child relationship name for PaymentInstallements__c from PaymentPlan__c.'
//             + ' Please verify the Child Relationship Name on the PaymentInstallment__c field.'
//         );
//     }

//     @AuraEnabled(cacheable=true)
//     public static Project__c fetchProjects(Id projectId) {
//         List<Project__c> rows = [
//             SELECT Id, Name, ProjectNumber__c, District__c, District__r.Name,
//                    Project_Description__c, Total_Units__c,
//                    Location__Latitude__s, Location__Longitude__s, Starting_Price__c
//             FROM Project__c
//             WHERE Id = :projectId
//             LIMIT 1
//         ];
//         return rows.isEmpty() ? null : rows[0];
//     }

//     @AuraEnabled(cacheable=true)
//     public static List<OfferLines__c> fetchOfferLines(Id projectId) {
//         Date today = Date.today();
//         return [
//             SELECT Id,
//                    OfferName__c,
//                    PromoValue__c,
//                    OfferValueType__c,
//                    DiscountType__c,
//                    OfferType__c,
//                    Unit__r.Project_Name__c,
//                    OfferName__r.Project__r.Name,
//                    OfferName__r.StartDate__c,
//                    OfferName__r.EndDate__c
//             FROM OfferLines__c
//             WHERE OfferName__r.Project__c = :projectId
//               AND OfferName__r.EndDate__c   >= :today
//               AND OfferName__r.StartDate__c <= :today
//             ORDER BY OfferName__r.EndDate__c ASC, CreatedDate DESC
//         ];
//     }

//     @AuraEnabled(cacheable=true)
//     public static List<String> fetchAmenities(Id projectId) {
//         Set<String> amenitiesSet = new Set<String>();
//         for (Amenities__c pa : [
//             SELECT Amenity__c
//             FROM Amenities__c
//             WHERE Project__c = :projectId
//             AND Amenity__c != NULL
//         ]) {
//             amenitiesSet.add(pa.Amenity__c);
//         }
//         return new List<String>(amenitiesSet);
//     }

//     @AuraEnabled(cacheable=true)
//     public static ProjectBundle fetchProjectBundleByUnitId(String unitId) {
//         Id projectId = [
//             SELECT Phase__r.Project__c
//             FROM Unit__c
//             WHERE Id = :unitId
//             LIMIT 1
//         ].Phase__r.Project__c;

//         ProjectBundle bundle = MBP_ProjectDetailPageController.fetchProjectBundleById(projectId);

//         try {
//             bundle.UnitImages = fetchUnitImages(unitId);
//         } catch (Exception e) {
//             bundle.UnitImages = new Map<String, List<String>>();
//         }

//         return bundle;
//     }
}