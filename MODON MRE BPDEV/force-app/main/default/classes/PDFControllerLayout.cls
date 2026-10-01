public without sharing class PDFControllerLayout {
    private final SalesOrder__c salesOrder;
    public String pdfData { get; set; }
    public String currentRecordId { get; set; }
    
    public boolean FloorPlanAvailable { get; set; }
    public List<Unit__c> plotlist { get; set; }

    public String designPlan { get; set; }
    public Map<String, List<FloorPlan>> floorplanMap { get; set; }
    public List<FloorPlan> floorplanList { get; set; }
    
    public String mappingPdfData { get; set; }
    public String termsPdfData { get; set; }
    public String layoutPdfData { get; set; }
    
    public Boolean naseemProject {get; set;} 
    public Boolean nawayefProject {get; set;}

    public Boolean showNawayefHeightCategory {get; set;}
    public Boolean showNawayefHomeCategory {get; set;}
    public Boolean showNawayefMansionCategory {get; set;}
    
    
    public String styleName {get; set;}
    public String paletteID {get; set;}
    
    
    public PDFControllerLayout(ApexPages.StandardController controller) {
        this.salesOrder = (SalesOrder__c)controller.getRecord();
        system.debug('this.salesOrder====='+this.salesOrder);
        currentRecordId  = ApexPages.CurrentPage().getparameters().get('id');
        
        FloorPlanAvailable = false;
        designPlan = designPlan != null ? designPlan : '';

        SalesOrder__c salesOrder = [
            SELECT Id, Unit__c, Unit__r.Name, Unit__r.Phase__r.Name, Unit__r.category__c, UnitOption__c, UnitOption__r.Name, UnitOption__r.category__c, Unit__r.Description__c, FitoutPalete__c, ProjectName__c FROM SalesOrder__c
            WHERE Id = :currentRecordId
            LIMIT 1
        ];
        
        if (salesOrder.FitoutPalete__c == 'Dark') {
            paletteID = 'Dark palette';
        } else if (salesOrder.FitoutPalete__c == 'Light') {
            paletteID = 'Light palette';
        }
        

        naseemProject = salesOrder.ProjectName__c == 'Al Naseem';
        System.debug(nawayefProject);
        nawayefProject = (salesOrder.ProjectName__c.indexOf('Nawayef') != -1) ? true : false; 
        system.debug('==>' + nawayefProject);
        showNawayefHeightCategory = nawayefProject && salesOrder.UnitOption__r.category__c == 'HEIGHTS';
        showNawayefHomeCategory = nawayefProject && salesOrder.UnitOption__r.category__c == 'HOMES';
        showNawayefMansionCategory = nawayefProject && salesOrder.UnitOption__r.category__c == 'Mansions';
        if (showNawayefHeightCategory || showNawayefHomeCategory || showNawayefMansionCategory) {
            styleName = showNawayefHeightCategory ? 'Heights Type ' : showNawayefMansionCategory ? 'Mansions' : 'Homes Type ';
            if(showNawayefHeightCategory || showNawayefHomeCategory){
                if (salesOrder.UnitOption__r.Name.contains('Type 1')) {
                    styleName += '01';
                } else if (salesOrder.UnitOption__r.Name.contains('Type 2')) {
                    styleName += '02';
                } else if (salesOrder.UnitOption__r.Name.contains('Type 3')) {
                    styleName += '03';
                } else if (salesOrder.UnitOption__r.Name.contains('Type 4')) {
                    styleName += '04';
                } else if (salesOrder.UnitOption__r.Name.contains('Type 5')) {
                    styleName += '05';
                } else if (salesOrder.UnitOption__r.Name.contains('Type 6')) {
                    styleName += '06';
                } else if (salesOrder.UnitOption__r.Name.contains('Type 7')) {
                    styleName += '07';
                } else if (salesOrder.UnitOption__r.Name.contains('Type 8')) {
                    styleName += '08';
                }
            }
        }
        
        
        Map<String, String> plotnames = new Map<String, String>();
        Set<Id> plotidset = new Set<Id>();
        //Set<Id> plotOptionSet = new Set<Id>();

        if (salesOrder.Unit__c != null && salesOrder.Unit__r.Phase__r.Name != 'NAWAYEF WEST A') {
            plotidSet.add(salesOrder.Unit__c);
            String selectFields = String.escapeSingleQuotes(getAllFields('Unit__c'));
            String query = 'SELECT ' + selectFields + ' FROM Unit__c WHERE Id IN :plotidset ORDER BY Name';
            plotlist = (List<Unit__c>) Database.queryWithBinds(
                query,
                new Map<String, Object>{ 'plotidset' => plotidset },
                AccessLevel.SYSTEM_MODE
            );  
            plotnames.put(salesOrder.Unit__c, salesOrder.Unit__r.Name);
            List<ContentDocumentLink> cdlTemp = [SELECT ContentDocumentId,LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId IN :plotidset];
            System.debug('cdlTemp.size(): '+cdlTemp.size());
            if(cdlTemp.size() == 0 && salesOrder.UnitOption__c != null){
             plotidSet.add(salesOrder.UnitOption__c); 
             plotnames.put(salesOrder.UnitOption__c, salesOrder.Unit__r.Name);
            }
        }
        //Added on 20 Dec 2024
        if (salesOrder.UnitOption__c != null && salesOrder.Unit__r.Phase__r.Name == 'NAWAYEF WEST A') {
            System.debug('Unit Option will be Selected');
            plotidSet.add(salesOrder.Unit__c);
            String selectFields = String.escapeSingleQuotes(getAllFields('Unit__c'));
            String query = 'SELECT ' + selectFields + ' FROM Unit__c WHERE Id IN :plotidset ORDER BY Name';
            plotlist = (List<Unit__c>) Database.queryWithBinds(
                query,
                new Map<String, Object>{ 'plotidset' => plotidset },
                AccessLevel.SYSTEM_MODE
            ); 
            plotidset.add(salesOrder.UnitOption__c);
            plotnames.put(salesOrder.UnitOption__c, salesOrder.Unit__r.Name);
        }
        System.debug('Unit/UnitOption: '+plotidset);
        if (!plotidset.isEmpty()) {
            Set<Id> condocid = new Set<Id>();
            Map<Id, Id> ultoId = new Map<Id, Id>();
            Map<String, Set<String>> unitPlanmap = new Map<String, Set<String>>();
            for (ContentDocumentLink cdl : [SELECT ContentDocumentId,LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId IN :plotidset]) {
                condocid.add(cdl.ContentDocumentId);
                System.debug(condocid);
                ultoId.put(cdl.ContentDocumentId, cdl.LinkedEntityId);
                plotnames.put(cdl.ContentDocumentId, plotnames.get(cdl.LinkedEntityId));
                if (!unitPlanmap.containsKey(cdl.LinkedEntityId)) {
                    unitPlanmap.put(cdl.LinkedEntityId, new Set<String>());
                }
                unitPlanmap.get(cdl.LinkedEntityId).add(cdl.ContentDocumentId);
            }
            System.debug(unitPlanmap); 
            floorplanList = new List<FloorPlan>();
            floorplanMap = new Map<String, List<FloorPlan>>();
            Map<Id, FloorPlan> fltmap = new Map<Id, FloorPlan>();
            for (ContentDocument cd : [SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument WHERE Id IN :condocid]) {
                system.debug('cd.Id -> ' + cd.Id);
                ContentVersion cv = [SELECT VersionData FROM ContentVersion WHERE ContentDocumentId = :cd.Id ORDER BY CreatedDate DESC LIMIT 1];
                FloorPlan fp = new FloorPlan();
                fp.planLink = 'data:image/png;base64,' + EncodingUtil.base64Encode(cv.VersionData);
                fp.isValid = true;
                fp.name = cd.Title;
                fp.pagetype = 'A6';
                fltmap.put(cd.Id, fp);
            }
            System.debug(plotnames);
            if (unitPlanmap.size() > 0) {
                FloorPlanAvailable = true;
                for (String key : unitPlanmap.keySet()) {
                    for (String unid : unitPlanmap.get(key)) {
                        FloorPlan fp = fltmap.get(unid);
                        if (fp != null && fp.name.contains(designPlan)) {
                            FloorPlan f2 = new FloorPlan();
                            f2.planLink = fp.planLink;
                            f2.isValid = fp.isValid;
                            f2.name = fp.name;// + '-' + plotnames.get(key);
                            f2.plodId = plotnames.get(key);
                            f2.pagetype = fp.pagetype;
                            if (!floorplanMap.containsKey(f2.plodId)) {
                                floorplanMap.put(f2.plodId, new List<FloorPlan>());
                            }
                            floorplanMap.get(f2.plodId).add(f2);
                        }
                    }
                }
            }
            System.debug(floorplanMap);
            System.debug(FloorPlanAvailable);
            System.debug(SalesOrder.Unit__r.Phase__r.Name == 'NAWAYEF WEST A'); 
            System.debug('plotLIst: '+plotlist);
        }
          
    }
    public PDFControllerLayout() {
        // Default constructor
    }
    
   public PageReference savePDF() {
    try {
        currentRecordId = ApexPages.currentPage().getParameters().get('recordId');
        pdfData = ApexPages.currentPage().getParameters().get('pdfData');

        System.debug('Current Record ID: ' + currentRecordId);

        // Decode the Base64 PDF data
        Blob pdfBlob = EncodingUtil.base64Decode(pdfData);
        String fileName = 'Step 2.pdf';
        String contentType = 'application/pdf';

        // Create a new ContentVersion
        ContentVersion contentVersion = new ContentVersion();
        contentVersion.Title = fileName;
        contentVersion.PathOnClient = fileName;
        contentVersion.VersionData = pdfBlob;
        contentVersion.IsMajorVersion = true;
        contentVersion.Origin = 'H';

        try {
            insert contentVersion;
        } catch (DMLException e) {
            System.debug('Error inserting ContentVersion: ' + e.getMessage());
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error in saving PDF: ' + e.getMessage())); return null;
        }
        List<contentDocumentLink> contentDocumentLinkList = new List<contentDocumentLink>();
        List<ContentVersion> contentVersionList = [SELECT ContentDocumentId FROM ContentVersion WHERE title = 'Terms_and_conditions' LIMIT 1];

        ContentDocumentLinkHelper.insertContentDocumentLinks(contentVersion.Id, currentRecordId,contentVersionList[0].ContentDocumentId );

        try {
        } catch (DMLException e) {
            System.debug('Error inserting ContentDocumentLink: ' + e.getMessage());
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error in saving PDF: ' + e.getMessage())); return null;
        }

        PageReference pr = new PageReference('/' + currentRecordId); pr.setRedirect(true); return pr;
    } catch (Exception e) {
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error in saving PDF: ' + e.getMessage()));
        return null;
    }
}
    
    public static String getAllFields(String sobjectName) {
        Set<String> fieldNames = Schema.getGlobalDescribe().get(sobjectName).getDescribe().fields.getMap().keySet();
        return String.join(new List<String>(fieldNames), ',');
    }

    public class FloorPlan {
        public String planLink { get; set; }
        public Boolean isValid { get; set; }
        public String name { get; set; }
        public String plodId { get; set; }
        public String pagetype { get; set; }
    }
     
}