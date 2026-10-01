/**********************************************************************************************************************
* Name               : OfferDetailsPDFController                                                        
* Description        : This class is used to generate the PDF
* Usage              : OfferDetailsPDF VF Page                                                          
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com     19 Dec 2023      Initial Draft       
******************************************************************************************************************/
public without sharing class OfferDetailsPDFController {

    public string customerName {get; set;}
    public string randomString {get; set;}
    public Unit__c unitObj {get;set;}
    public Unit_Option__c unitOptnObj {get;set;}
    public PaymentPlan__c paymentPlanObj {get;set;}
    public string todayDate {get; set;}

    public Decimal basePrice {get;set;}
    public Decimal totalPrice {get;set;}

    public Decimal garage {get;set;}
    public Decimal sellableArea {get;set;}
    public Decimal terraceArea {get;set;}
    public Decimal floorArea {get;set;}

    public string type {get; set;}
    public string model {get;set;}
    public Date estimatedCompletionDate {get; set;}
    public String numberOfBedroom {get; set;}
    public Decimal internalArea {get; set;}
    public Decimal balconyArea {get; set;}
    
    public FloorPlan floorPlanLayout {get; set;}
    
    public OfferDetailsPDFController() {
        String opportunityId = ApexPages.currentPage().getParameters().get('id');
        String currentUnit = ApexPages.currentPage().getParameters().get('currentUnit');
        String selectedPayment = ApexPages.currentPage().getParameters().get('selectedPayment');
        String selectedUnitOption = ApexPages.currentPage().getParameters().get('unitOption');
        customerName = ApexPages.currentPage().getParameters().get('customerName');
        if(opportunityId != null && opportunityId!=''){
            opportunity opty = [select id,Account.Name from opportunity where id = :opportunityId];
            if(customerName ==null || customerName ==''){
                customerName=opty.Account.Name;
            } 
        }
        todayDate = System.today().format();
        randomString = generateRandomString(7);
        if(currentUnit!=null && currentUnit!=''){
            unitObj = getUnitDetails(currentUnit);
            basePrice = unitObj.BasePrice__c;
            totalPrice = unitObj.TotalPrice__c;

            garage = unitObj.Garage__c;
            sellableArea = unitObj.TotalGrossSellableAreaGSA__c;
            terraceArea = unitObj.TerraceArea__c;
            type = unitObj.type__c;
            model = unitObj.model__c;
            floorArea = unitObj.GrossFloorAreaGFA__c;
            numberOfBedroom = unitObj.Number_of_Bedrooms__c;
            internalArea = unitObj.Internal_Area__c;
            balconyArea = unitObj.BalconyArea__c;
        }
        if(selectedPayment!=null && selectedPayment!=''){
            paymentPlanObj = getPaymentDetails(selectedPayment);
            //Below code snippet is written by Arbaz-Aphidas
            //start
            for(PaymentInstallements__c pi: paymentPlanObj.Payment_Installments__r){
                if(pi.IsHandoverPayment__c){
                    estimatedCompletionDate = pi.MilestoneDate__c;
                }
            }
            //end
        }
        if(selectedUnitOption!=null && selectedUnitOption!=''){
            unitOptnObj = getUnitOption(selectedUnitOption);
            basePrice = unitOptnObj.BasePrice__c;
            totalPrice = unitOptnObj.TotalPrice__c;

            garage = unitOptnObj.Garage__c;
            sellableArea = unitOptnObj.TotalGrossSellableAreaGSA__c;
            terraceArea = unitOptnObj.TerraceArea__c;
            type = unitOptnObj.type__c;
            model = unitOptnObj.model__c;
            floorArea = unitOptnObj.GrossFloorAreaGFA__c;
            numberOfBedroom = String.valueof(unitOptnObj.NumberofBedrooms__c);
            internalArea = unitOptnObj.Internal_Area__c;
            balconyArea = unitOptnObj.BalconyArea__c;
        }

        system.debug('basePrice==>' + basePrice);
        system.debug('totalPrice==>' + totalPrice);

        ContentDocumentLink cdl = getSitePlan(selectedUnitOption, currentUnit);
        if (cdl != null) {
            floorPlanLayout = new FloorPlan();
            floorPlanLayout.planLink = '/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_Png&versionId='+cdl.ContentDocument.LatestPublishedVersionId;
            floorPlanLayout.name = cdl.ContentDocument.Title;
            floorPlanLayout.pagetype = 'A6';
        }

        
        string fileName = 'Offer-'+unitObj.Name+'-'+customerName+'-'+todayDate;
        Apexpages.currentPage().getHeaders().put('content-disposition', 'inline; filename='+fileName+'.pdf');
    }

    public static String generateRandomString(Integer len) {
        final String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        String randStr = '';
        while (randStr.length() < len) {
           Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
           randStr += chars.substring(idx, idx+1);
        }
        return randStr; 
    }

    Unit_Option__c getUnitOption(String selectedUnitOption){
        return [SELECT Id, BasePrice__c, TotalPrice__c, PlotAreasqm__c, GrossFloorAreaGFA__c,
        TotalGrossSellableAreaGSA__c,TerraceArea__c,Type__c,Model__c, Garage__c,NumberofBedrooms__c,Internal_Area__c,BalconyArea__c
        FROM Unit_Option__c WHERE Id = :selectedUnitOption];
    }

    private Unit__c getUnitDetails(Id unitId){
        return [SELECT Id, Name, Phase__r.Name, TotalPrice__c, Phase__c, Phase__r.Project__c, BasePrice__c, PlotAreasqm__c,
        GrossFloorAreaGFA__c,TotalGrossSellableAreaGSA__c,TerraceArea__c,Type__c,Model__c,Number_of_Bedrooms__c,Internal_Area__c,BalconyArea__c,
        Phase__r.Project__r.Name, Garage__c
                    FROM Unit__c 
                    WHERE Id = : unitId];
    }

    private PaymentPlan__c getPaymentDetails(Id paymentId){
        return [SELECT Id, Name, 
                    (SELECT Id, Name, BrokerPayout__c, IsHandoverPayment__c, Milestone__c, MilestoneDate__c, MilestoneDescription__c,
                    MilestoneNumber__c, SalesAgentPayout__c FROM Payment_Installments__r ORDER BY MilestoneNumber__c) 
                    FROM PaymentPlan__c 
                    WHERE Id = :paymentId];
    }
    
    private ContentDocumentLink getSitePlan(String selectedUnitOption, String currentUnit) {
        ContentDocumentLink cdl;
        Id targetId = String.isEmpty(selectedUnitOption) ? currentUnit : selectedUnitOption;
        List<ContentDocumentLink> cdls = [
            SELECT Id, ContentDocumentId, ContentDocument.Title, ContentDocument.LatestPublishedVersionId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :targetId 
              AND ContentDocument.LatestPublishedVersion.IsLatest = true 
            LIMIT 1
        ];
        
        if (!cdls.isEmpty()) {
            cdl = cdls[0];
        } else if (!String.isEmpty(selectedUnitOption)) {
            // Fallback to currentUnit if selectedUnitOption had no attachments
            List<ContentDocumentLink> fallbackCdls = [
                SELECT Id, ContentDocumentId, ContentDocument.Title, ContentDocument.LatestPublishedVersionId 
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :currentUnit 
                  AND ContentDocument.LatestPublishedVersion.IsLatest = true 
                LIMIT 1
            ];
            if (!fallbackCdls.isEmpty()) {
                cdl = fallbackCdls[0];
            }
        }
        
        return cdl;
    }
    
    
    public class FloorPlan {
        public String planLink { get; set; }
        public String name { get; set; }
        public String pagetype { get; set; }
    }
}