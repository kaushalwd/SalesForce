public without sharing class PDFController {
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
    
    public String projectName { get; set; }
    public String projectNameArabic { get; set; }
    public String projectNo { get; set; }
    public String projectPlotNo { get; set; }
    public String area { get; set; }
    public String communityArabic { get; set; }
    public String community { get; set; }
    public String masterCommunityArabic { get; set; }
    public String masterCommunity { get; set; }
    public String sallerPropertyRightsArabic { get; set; }
    public String sallerPropertyRights { get; set; }
    public String projectDeveloperNameArabic { get; set; }
    public String projectDeveloperName { get; set; }
    public String developerRegistration { get; set; }
    public String masterDeveloperName { get; set; }
    public String masterDeveloperNameArabic { get; set; }
    public String serviceCharge { get; set; }
    

    public List<SalesOrderInstallments__c> paymentsRecord{get; set;}
    public list<JointOwner__c > jointOwnersSO{get; set;}
    
    
    public PDFController(ApexPages.StandardController controller) {
        this.salesOrder = (SalesOrder__c)controller.getRecord();
        system.debug('this.salesOrder====='+this.salesOrder);
        currentRecordId  = ApexPages.CurrentPage().getparameters().get('id');
        system.debug('currentRecordId -> ' + currentRecordId);
        FloorPlanAvailable = false;
        designPlan = designPlan != null ? designPlan : '';
        paymentsRecord = [Select id, SalesOrder__c,Name , InstallmentAmount__c,MilestoneNumber__c, CreatedDate, Milestone__c,MilestoneDate__c, MilestoneDescription__c, MilestoneDescriptionSPA__c, MilestoneDescriptionArabicSPA__c, InstalmentPaymentDueDateSPA__c, InstalmentPaymentDueDateArabicSPA__c, instalmentPaymentDueDate__c from SalesOrderInstallments__c where SalesOrder__c != null AND SalesOrder__c =: currentRecordId ORDER BY MilestoneNumber__c ASC  ];
        jointOwnersSO = [SELECT Id,Name,JointOwnerAccount__r.Name,
                         JointOwnerAccount__r.AccountnameArabic__c,
                         JointOwnerAccount__r.Nationality__pc, 
                         JointOwnerAccount__r.NationalityArabic__pc,
                         JointOwnerAccount__r.UAE_Resident_Status__pc,
                         JointOwnerAccount__r.EIDNumber__pc,
                         JointOwnerAccount__r.PassportNumber__pc,
                         JointOwnerAccount__r.PassportIssuancePlace__pc,
                         JointOwnerAccount__r.Passport_Issuance_Place_Arabic__pc,
                         JointOwnerAccount__r.PersonMailingStreet,
                         JointOwnerAccount__r.PersonMailingCity,
                         JointOwnerAccount__r.MailingCityArabic__pc,
                         JointOwnerAccount__r.PersonMailingCountry,
                         JointOwnerAccount__r.MailingCountryArabic__pc,
                         JointOwnerAccount__r.PersonMobilePhone,
                         JointOwnerAccount__r.PersonEmail,
                         JointOwnerAccount__r.PersonMailingPostalCode
                         
                         FROM jointOwner__c WHERE SalesOrder__c = :currentRecordId
                        order by OwnershipPercentage__c,createdDate];

        SalesOrder__c salesOrder = [
            SELECT Id, Unit__c, Unit__r.Name, ProjectName__c
            FROM SalesOrder__c
            WHERE Id = :currentRecordId
            LIMIT 1
        ];
        
        if (salesOrder.ProjectName__c == 'Al Naseem') {
            projectName = 'Al Naseem';
            projectNameArabic = 'ﺍﻟﻨﺴﻴﻢ';
            projectNo = '20240000267837';
            projectPlotNo = 'TMP_PL10, TMP PL11 and TMP_PL13';
            area = 'Al Hudayriat Island';//Al Hudayriat Island
            communityArabic = 'ﺍﻟﻨﺴﻴﻢ';
            community = 'Al Naseem';
            masterCommunityArabic = 'ﺍﻟﺤﺪﻳﺮﻳﺎﺕ ﺳﻨﺘﺮﺍﻝ';
            masterCommunity = 'Hudayriyat Central';
            sallerPropertyRightsArabic = 'اتفاقية تطوير بين المطور الرئيسي والبائع';
            sallerPropertyRights = 'Development Agreement between Master Developer and Seller';
            projectDeveloperNameArabic = 'حديريات للتطوير - ذ.م.م - ش.ش.و';
            projectDeveloperName = 'Hudayriyat Development LLC OPC';
            developerRegistration = '202400568905';
            masterDeveloperName = 'Modon Properties PJSC';
            masterDeveloperNameArabic = '.مدن العقارية ش.م.ع.';
            serviceCharge = 'AED 3.00 per sq.ft';
        } else if (salesOrder.ProjectName__c != NULL && salesOrder.ProjectName__c.contains('Nawayef')) {
            projectName = 'Nawayef West';
            projectNameArabic = 'نوايف غرب ب';
            projectNo = '20240000267566';
            projectPlotNo = 'TMP_PL5';
            area = 'Al Hidayriyyat Island';
            communityArabic = 'نوايف غرب';
            community = 'Nawayef West';
            masterCommunityArabic = 'ﺍﻟﺤﺪﻳﺮﻳﺎﺕ ﺳﻨﺘﺮﺍﻝ';
            masterCommunity = 'Hudayriyat Central'; 
            sallerPropertyRightsArabic = 'اتفاقية التطوير بين المطور الرئيسي والبائع';
            sallerPropertyRights = 'Development Agreement between Master Developer and Seller';
            projectDeveloperNameArabic = 'حديريات للتطوير - ذ.م.م - ش.ش.و';
            projectDeveloperName = 'Hudayriyat Development LLC OPC';
            developerRegistration = '202400568905';
            masterDeveloperName = 'Modon Properties PJSC';
            masterDeveloperNameArabic = 'ﻣﺪﻥ ﺍﻟﻌﻘﺎﺭﻳﺔ ﺵ.ﻡ.ﻉ';
            serviceCharge = 'AED 7.00 per sq.ft';
        }

        Map<String, String> plotnames = new Map<String, String>();
        plotnames.put(salesOrder.Unit__c, salesOrder.Unit__r.Name);
        Set<Id> plotidset = new Set<Id>();

        if (salesOrder.Unit__c != null) {
            plotidSet.add(salesOrder.Unit__c);
            String query = 'SELECT ' + getAllFields('Unit__c') + ' FROM Unit__c WHERE Id IN :plotidset ORDER BY Name';
            plotlist = Database.query(query);
        }

        if (!plotidset.isEmpty()) {
            Set<Id> condocid = new Set<Id>();
            Map<Id, Id> ultoId = new Map<Id, Id>();
            Map<String, Set<String>> unitPlanmap = new Map<String, Set<String>>();
            for (ContentDocumentLink cdl : [SELECT ContentDocumentId,LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId IN :plotidset]) {
                condocid.add(cdl.ContentDocumentId);
                ultoId.put(cdl.ContentDocumentId, cdl.LinkedEntityId);
                plotnames.put(cdl.ContentDocumentId, plotnames.get(cdl.LinkedEntityId));
                if (!unitPlanmap.containsKey(cdl.LinkedEntityId)) {
                    unitPlanmap.put(cdl.LinkedEntityId, new Set<String>());
                }
                unitPlanmap.get(cdl.LinkedEntityId).add(cdl.ContentDocumentId);
            }

            floorplanList = new List<FloorPlan>();
            floorplanMap = new Map<String, List<FloorPlan>>();
            Map<Id, FloorPlan> fltmap = new Map<Id, FloorPlan>();
            for (ContentDocument cd : [SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument WHERE Id IN :condocid AND FileType != 'PDF']) {
                ContentVersion cv = [SELECT VersionData FROM ContentVersion WHERE ContentDocumentId = :cd.Id ORDER BY CreatedDate DESC LIMIT 1];
                FloorPlan fp = new FloorPlan();
                fp.planLink = 'data:image/png;base64,' + EncodingUtil.base64Encode(cv.VersionData);
                fp.isValid = true;
                fp.name = cd.Title;
                fp.pagetype = 'A6';
                fltmap.put(cd.Id, fp);
            }

            if (unitPlanmap.size() > 0) {
                FloorPlanAvailable = true;
                for (String key : unitPlanmap.keySet()) {
                    for (String unid : unitPlanmap.get(key)) {
                        FloorPlan fp = fltmap.get(unid);
                        if (fp != null && fp.name.contains(designPlan)) {
                            FloorPlan f2 = new FloorPlan();
                            f2.planLink = fp.planLink;
                            f2.isValid = fp.isValid;
                            f2.name = fp.name + '-' + plotnames.get(key);
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
        }
          
    }
    public PDFController() {
        // Default constructor
    }
    
    public PageReference savePDF() {
    try {
        // Retrieve parameters from the current page
        currentRecordId = ApexPages.currentPage().getParameters().get('recordId');
        pdfData = ApexPages.currentPage().getParameters().get('pdfData');
        
        System.debug('Current Record ID: ' + currentRecordId);

        // Decode the Base64 PDF data
        Blob pdfBlob = EncodingUtil.base64Decode(pdfData);
        String fileName = 'Step 1.pdf';
        String contentType = 'application/pdf';

        // Create a new ContentVersion
        ContentVersion contentVersion = new ContentVersion();
        contentVersion.Title = fileName;
        contentVersion.PathOnClient = fileName;
        contentVersion.VersionData = pdfBlob;
        contentVersion.IsMajorVersion = true;

        try {
            insert contentVersion;
            system.debug('contentVersion=='+contentVersion);
        } catch (DMLException e) {
            System.debug('Error inserting ContentVersion: ' + e.getMessage());
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error in saving PDF: ' + e.getMessage()));
            return null;
        }

        // Retrieve the ContentDocumentId
        List<ContentVersion> contentVersionList = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1];
        Id contentDocumentId = contentVersionList[0].ContentDocumentId;
        system.debug('currentRecordId===>>'+currentRecordId);

        // Create a new ContentDocumentLink to associate the ContentDocument with the record
        ContentDocumentLink contentDocumentLink = new ContentDocumentLink();
        contentDocumentLink.ContentDocumentId = contentDocumentId;
        contentDocumentLink.LinkedEntityId = currentRecordId;
        contentDocumentLink.ShareType = 'V'; // Viewer permission
        contentDocumentLink.Visibility = 'AllUsers';

        try {
            insert contentDocumentLink;
            system.debug('contentDocumentLink'+contentDocumentLink);
        } catch (DMLException e) {
            System.debug('Error inserting ContentDocumentLink: ' + e.getMessage());
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error in saving PDF: ' + e.getMessage()));
            return null;
        }

        // Redirect to the current record's detail page
        PageReference pr = new PageReference('/' + currentRecordId);
        pr.setRedirect(true);
        return pr;
    } catch (Exception e) {
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error in saving PDF: ' + e.getMessage()));
        return null;
    }
}

    
    
//working code
/*
    public PageReference savePDF() {
        try {
            currentRecordId = ApexPages.currentPage().getParameters().get('recordId');
            pdfData = ApexPages.currentPage().getParameters().get('pdfData');
            
            System.debug('Current Record ID: ' + currentRecordId);
     
            
            //End Code
            Blob pdfBlob = EncodingUtil.base64Decode(pdfData);
           // system.debug('pdfBlob====>>'+pdfBlob);
            Attachment attachment = new Attachment();
            attachment.ParentId = currentRecordId;
            attachment.Name = 'SPA.pdf';
            attachment.Body = pdfBlob;
            attachment.ContentType = 'application/pdf';
            try{
                insert attachment;
                
            }catch(DMLException e){
                system.debug('An error has ooccurred'+e.getMessage());
            }
            
            //system.debug('attachment==>'+attachment);
            
            PageReference pr = new PageReference('/' + currentRecordId);
            pr.setRedirect(true);
            return pr;
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error in saving PDF: ' + e.getMessage()));
            return null;
        }
    }
    */
    
    
    /*
    public PageReference savePDF() {
        try {
            currentRecordId = ApexPages.currentPage().getParameters().get('recordId');
            mappingPdfData = ApexPages.currentPage().getParameters().get('mappingPdfData');
            termsPdfData = ApexPages.currentPage().getParameters().get('termsPdfData');
            layoutPdfData = ApexPages.currentPage().getParameters().get('layoutPdfData');
            System.debug('Current ID: '+currentRecordId);
            System.debug('mappingPdfData ID: '+mappingPdfData);
            System.debug('termsPdfData ID: '+termsPdfData);
            System.debug('layoutPdfData ID: '+layoutPdfData);

            insertPDF(mappingPdfData, 'Mapping.pdf');
            insertPDF(termsPdfData, 'TermsAndConditions.pdf');
            insertPDF(layoutPdfData, 'SPALayout.pdf');

            PageReference pr = new PageReference('/' + currentRecordId);
            pr.setRedirect(true);
            return pr;
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error in saving PDF: ' + e.getMessage()));
            return null;
        }
    }

    private void insertPDF(String pdfData, String fileName) {
        if (pdfData != null) {
            Blob pdfBlob = EncodingUtil.base64Decode(pdfData);
            Attachment attachment = new Attachment();
            attachment.ParentId = currentRecordId;
            attachment.Name = fileName;
            attachment.Body = pdfBlob;
            attachment.ContentType = 'application/pdf';
            insert attachment;
        }
    }
    
    
    */
    
    
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