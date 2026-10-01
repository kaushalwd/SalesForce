/**
* @description       : 
* @author            : Krishna Chaitanya
* @group             : 
* @last modified on  : 05-20-2025
* @last modified by  : Krishna Chaitanya
**/
public without sharing class CommunityHomeController {

// Apex Method
@AuraEnabled(cacheable=true)
public static List<SalesOrderWrapper> getSalesOrdersByCustomer(Id customerId) {
    List<SalesOrder__c> salesOrders = [
        SELECT Id, ProjectName__c, Name,SPAPublicUrl__c, Phase_Unit_Image__c, Unit__c, UnitOption__c,
               Unit__r.Number_of_Bedrooms__c, Unit__r.Phase__r.Description__c, Unit__r.Numberofbathroom__c,
               UnitOption__r.AdditionalPrice__c, UnitOption__r.AED_SQM__c, UnitOption__r.AreaUnitofMeasure__c,
               UnitOption__r.BalconyArea__c, UnitOption__r.BasePrice__c, UnitOption__r.Description__c,
               UnitOption__r.GrossFloorAreaGFA__c, UnitOption__r.Internal_Area__c, UnitOption__r.NumberofBedrooms__c,
               UnitOption__r.NumberofCarParks__c, UnitOption__r.PlotNo__c, UnitOption__r.PlotAreasqm__c,UnitOption__r.Name,
               UnitOption__r.TotalGrossSellableAreaGSA__c, UnitOption__r.TotalPrice__c, UnitOption__r.Type__c,
               UnitOption__r.Typology__c, UnitOption__r.Unit__c, UnitOption__r.Unit_Option_Image__c,
               Unit__r.Type__c, Unit__r.Phase__c, Unit__r.UnitClassification__c, Unit__r.Numberofbalcony__c,
               Unit__r.TotalArea__c, Unit__r.PlotNo__c, Unit__r.Project_Name__c, Unit__r.NumberofCarParks__c,Unit__r.PlotAreasqm__c,
               TotalGrossSellableAreaGSA__c, TotalAmount__c, PaymentPlanStructure__c, Unit__r.Name,
               PaymentPlan__c, PaymentPlan__r.Name,
               (SELECT Id, SalesOrder__c FROM Documents__r WHERE Name = 'Signed SPA (Modon)' AND Status__c = 'Uploaded' LIMIT 1)
        FROM SalesOrder__c
        WHERE CustomerAccount__c = :customerId 
          AND Status__c NOT IN ('Cancelled') 
        ORDER BY CreatedDate DESC
        LIMIT 50
    ];

    Set<Id> imageVersionIds = new Set<Id>();
    for (SalesOrder__c so : salesOrders) {
        if (so.Phase_Unit_Image__c != null) {
            imageVersionIds.add(so.Phase_Unit_Image__c);
        }
    }
	system.debug('imageVersionIds---'+imageVersionIds);
    Map<Id, String> imageMap = new Map<Id, String>();
    if (!imageVersionIds.isEmpty()) {
        for (ContentVersion cv : [SELECT Id, VersionData FROM ContentVersion WHERE Id IN :imageVersionIds]) {
            imageMap.put(cv.Id, 'data:image/jpeg;base64,' + EncodingUtil.base64Encode(cv.VersionData));
        }
    }
	system.debug('imageMap---'+imageMap);
    if (salesOrders.isEmpty()) return new List<SalesOrderWrapper>();

    Set<Id> phaseIds = new Set<Id>();
    for (SalesOrder__c so : salesOrders) {
        if (so.Unit__r?.Phase__c != null) {
            phaseIds.add(so.Unit__r.Phase__c);
        }
    }

    Map<Id, String> phaseDescMap = new Map<Id, String>();
    if (!phaseIds.isEmpty()) {
        for (Phase__c phase : [SELECT Id, Description__c FROM Phase__c WHERE Id IN :phaseIds]) {
            phaseDescMap.put(phase.Id, phase.Description__c);
        }
    }

    Set<Id> salesOrderIds = new Set<Id>();
    for (SalesOrder__c so : salesOrders) {
        salesOrderIds.add(so.Id);
    }

    Map<Id, SalesOrderInstallmentSummary> summaryMap = new Map<Id, SalesOrderInstallmentSummary>();
    for (SalesOrderInstallments__c inst : [
        SELECT Id, SalesOrder__c, InstallmentAmount__c, MilestoneNumber__c, PaymentStatus__c, MilestoneDate__c
        FROM SalesOrderInstallments__c
        WHERE SalesOrder__c IN :salesOrderIds
        ORDER BY MilestoneNumber__c ASC
    ]) {
        if (!summaryMap.containsKey(inst.SalesOrder__c)) {
            summaryMap.put(inst.SalesOrder__c, new SalesOrderInstallmentSummary());
        }
        SalesOrderInstallmentSummary summary = summaryMap.get(inst.SalesOrder__c);
        if (inst.PaymentStatus__c == 'Paid') {
            summary.totalPaidInstallments++;
            summary.totalCollectedAmount += (inst.InstallmentAmount__c != null ? inst.InstallmentAmount__c : 0);
        } else {
            summary.totalNotPaidInstallments++;
            summary.balanceAmount += (inst.InstallmentAmount__c != null ? inst.InstallmentAmount__c : 0);
            if (summary.nextMilestoneDate == null) {
                summary.nextMilestoneDate = inst.MilestoneDate__c;
                summary.nextInstallmentAmount = inst.InstallmentAmount__c;
            }
        }
        summary.installmentsNumber = Integer.valueOf(inst.MilestoneNumber__c);
        Decimal totalAmount = summary.totalCollectedAmount + summary.balanceAmount;
        summary.paidPercentage = (totalAmount > 0) ? (summary.totalCollectedAmount / totalAmount) * 100 : 0;
        summary.totalInstallments++;
    }

    List<SalesOrderWrapper> results = new List<SalesOrderWrapper>();
    for (SalesOrder__c so : salesOrders) {
        results.add(new SalesOrderWrapper(so, phaseDescMap, summaryMap.get(so.Id), imageMap));
    }

    return results;
}

public class SalesOrderInstallmentSummary {
    @AuraEnabled public Integer totalPaidInstallments = 0;
    @AuraEnabled public Integer totalNotPaidInstallments = 0;
    @AuraEnabled public Integer totalInstallments = 0;
    @AuraEnabled public Decimal totalCollectedAmount = 0;
    @AuraEnabled public Decimal balanceAmount = 0;
    @AuraEnabled public Date nextMilestoneDate;
    @AuraEnabled public Decimal nextInstallmentAmount = 0;
    @AuraEnabled public Decimal paidPercentage=0;
    @AuraEnabled public Integer installmentsNumber=0;
}

public class SalesOrderWrapper {
    @AuraEnabled public String Id;
    @AuraEnabled public String ProjectName;
    @AuraEnabled public String UnitClass;
    @AuraEnabled public String ImageUrl;
	@AuraEnabled public String SoId;
    @AuraEnabled public String UnitName;
    @AuraEnabled public String UnitNumber;
    @AuraEnabled public String UnitType;
    @AuraEnabled public String NoofBedrooms;
    @AuraEnabled public String NoofBathroom;
    @AuraEnabled public String NoofCars;
    @AuraEnabled public Decimal TotalArea;
    @AuraEnabled public Decimal TotalAmount;
    @AuraEnabled public String PaymentPlan;
    @AuraEnabled public String Noofbalcony;
    @AuraEnabled public String Phasedescription;
    @AuraEnabled public Boolean isSPADisable = true;
    @AuraEnabled public Decimal TotalGrossArea;
    @AuraEnabled public String FloorPlanId;
    @AuraEnabled public string SPAURL;
    @AuraEnabled public SalesOrderInstallmentSummary installmentSummary;

    public SalesOrderWrapper(SalesOrder__c so, Map<Id, String> phaseDescMap, SalesOrderInstallmentSummary summary, Map<Id, String> imageMap) {
        Boolean useOption = so.UnitOption__c != null;
        decimal area = so.Unit__r.TotalArea__c != null ? so.Unit__r.TotalArea__c : so.Unit__r.PlotAreasqm__c;
        this.Id = so.Id;
        this.SoId =so.Name;
        this.ProjectName = so.ProjectName__c;
        this.UnitClass = useOption ? so.UnitOption__r.Typology__c : so.Unit__r.UnitClassification__c;
        this.UnitName = useOption ? so.UnitOption__r.Name : so.Unit__r.Name;
        this.UnitNumber = useOption ? so.UnitOption__r.PlotNo__c : so.Unit__r.PlotNo__c;
        this.UnitType = useOption ? so.UnitOption__r.Type__c : so.Unit__r.Type__c;
        this.NoofBedrooms = useOption ? String.valueOf(so.UnitOption__r.NumberofBedrooms__c) : so.Unit__r.Number_of_Bedrooms__c;
        this.NoofBathroom = String.valueOf(so.Unit__r.Numberofbathroom__c);
        this.NoofCars = useOption ? String.valueOf(so.UnitOption__r.NumberofCarParks__c) : String.valueOf(so.Unit__r.NumberofCarParks__c);
        this.TotalArea = useOption ? so.UnitOption__r.PlotAreasqm__c : area;
        this.TotalAmount = so.TotalAmount__c;
        this.PaymentPlan = so.PaymentPlanStructure__c;
        this.Noofbalcony = useOption ? '' : String.valueOf(so.Unit__r.Numberofbalcony__c);
        this.TotalGrossArea = useOption ? so.UnitOption__r.TotalGrossSellableAreaGSA__c : so.TotalGrossSellableAreaGSA__c;
        this.Phasedescription = (so.Unit__r.Phase__c != null) ? phaseDescMap.get(so.Unit__r.Phase__c) : null;
        this.isSPADisable = (so.Documents__r != null && !so.Documents__r.isEmpty()) ? false : true;
        this.FloorPlanId = useOption ? so.UnitOption__r.Unit__c : so.Unit__c;
        this.ImageUrl = imageMap.containsKey(so.Phase_Unit_Image__c) ? imageMap.get(so.Phase_Unit_Image__c) : null;
        this.installmentSummary = (summary != null) ? summary : new SalesOrderInstallmentSummary();
        this.SPAURL =so.SPAPublicUrl__c;
    }
}


@AuraEnabled(cacheable=true)
public static String getFloorPlan(String recordId) {
  
    // 1. Fetch the record and related ContentDocumentLink
    // recordId = 'a0oVG000001MboL';
    System.debug('recordId:'+recordId);
    List<SalesOrder__c> soList = [
        SELECT Id, Unit__c,FloorPlanPublicURL__c FROM SalesOrder__c WHERE Id = :recordId LIMIT 1
    ];
    
    if (soList.isEmpty()) {
        throw new AuraHandledException('Sales Order not found');
    }
    return soList[0].FloorPlanPublicURL__c;
}


@AuraEnabled(cacheable=true)
public static String getSPA(String recordId){

    //recordId = 'a0oVG000001MboLYAS';
    List<SalesOrder__c> soList = [
        SELECT Id, Unit__c,SPAPublicUrl__c FROM SalesOrder__c WHERE Id = :recordId LIMIT 1
    ];
    
    if (soList.isEmpty()) {
        throw new AuraHandledException('Sales Order not found');
    }
    return soList[0].SPAPublicUrl__c;

}

// @AuraEnabled(cacheable=true)
// public static String getSPA(String recordId) {
//     // Step 1: Find Document__c linked to SalesOrder__c
//     List<Documents__c> docList = [
//         SELECT Id, Name 
//         FROM Documents__c 
//         WHERE SalesOrder__c = :recordId 
//         AND Name = 'Signed SPA (Modon)' 
//         LIMIT 1
//     ];

//     if (docList.isEmpty()) {
//         throw new AuraHandledException('SPA Document__c record not found');
//     }

//     Id documentRecordId = docList[0].Id;

//     // Step 2: Get linked ContentDocument (File)
//     List<ContentDocumentLink> docLinks = [
//         SELECT ContentDocumentId 
//         FROM ContentDocumentLink 
//         WHERE LinkedEntityId = :documentRecordId 
//         LIMIT 1
//     ];

//     if (docLinks.isEmpty()) {
//         throw new AuraHandledException('No File attached to the Document__c record');
//     }

//     // Step 3: Build download URL
//     String fileUrl = '/sfc/servlet.shepherd/document/download/' + docLinks[0].ContentDocumentId;

//     return fileUrl;
// }


@AuraEnabled
public static string getPDF(String recId){
string b64code = EncodingUtil.base64Encode(navigate(recId));
return b64code;
}
public static blob navigate(String recordId){
PageReference pg = new PageReference('/apex/SOA3');
pg.getParameters().put('id',recordId);
//pg.setRedirect(true);
return pg.getContentAsPDF();
}


@AuraEnabled(cacheable=true)
public static List<String> getImageUrls(Id unitId) {
List<String> imageUrls = new List<String>();

List<Attachment> attachments = [
    SELECT Id, Name 
    FROM Attachment 
    WHERE ParentId = :unitId 
    AND Name LIKE '%gallery%'
];

for (Attachment att : attachments) {
    String url = '/servlet/servlet.FileDownload?file=' + att.Id;
    imageUrls.add(url);
}

return imageUrls;
}


@AuraEnabled
public static List<PortalNotificationWrapper> getThisMonthsNotifications() {
    Date startOfMonth = Date.today().toStartOfMonth();
    Date endOfMonth = startOfMonth.addMonths(1);

    List<Portal_Notification__c> notifications = [
        SELECT Name, Event_Date_Time__c, Event_Description__c
        FROM Portal_Notification__c
        WHERE Event_Date_Time__c >= :startOfMonth AND Event_Date_Time__c < :endOfMonth
        ORDER BY Event_Date_Time__c ASC
    ];

    List<PortalNotificationWrapper> wrappedList = new List<PortalNotificationWrapper>();

    for (Portal_Notification__c n : notifications) {
        wrappedList.add(new PortalNotificationWrapper(n.Name, n.Event_Date_Time__c, n.Event_Description__c));
    }

    return wrappedList;
}

public class PortalNotificationWrapper {
    @AuraEnabled public String name { get; set; }
    @AuraEnabled public Datetime eventDateTime { get; set; }
    @AuraEnabled public String eventDescription { get; set; }

    public PortalNotificationWrapper(String name, Datetime eventDateTime, String eventDescription) {
        this.name = name;
        this.eventDateTime = eventDateTime;
        this.eventDescription = eventDescription;
    }
}


@AuraEnabled(cacheable=true)
public static Map<String, String> makeCallout(String param1, String param2) {
    Map<String, String> result = new Map<String, String>();

    try {
        // Query the metadata
        OIC_Credential__mdt config = [
            SELECT Endpoint__c, Username__c, Password__c, Method__c 
            FROM OIC_Credential__mdt 
            WHERE DeveloperName = 'ModonCustomerDPGAPI' 
            LIMIT 1
        ];
        String encodedProject = EncodingUtil.urlEncode('hudayriyat', 'UTF-8').replace('+', '%20');
String encodedUnit = EncodingUtil.urlEncode(param2, 'UTF-8').replace('+', '%20');
String endpoint = config.Endpoint__c + 'project=' + encodedProject + '&unit=' + encodedUnit;
        // Construct the URL with parameters
        // String endpoint = config.Endpoint__c + 'project=' + EncodingUtil.urlEncode(param1, 'UTF-8') + '&unit=' + EncodingUtil.urlEncode(param2, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod(config.Method__c);
        //req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Basic ' +
            EncodingUtil.base64Encode(Blob.valueOf(config.Username__c + ':' + config.Password__c)));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

            if (resMap.containsKey('success') && (Boolean)resMap.get('success') == true) {
                result.put('dpgurl', (String)resMap.get('url'));
            } else {
                result.put('error', (String)resMap.get('message'));
            }
        } else {
            result.put('error', 'HTTP Error: ' + res.getStatus());
        }
    } catch (Exception ex) {
        result.put('error', 'Exception: ' + ex.getMessage());
    }

    return result;
}
}