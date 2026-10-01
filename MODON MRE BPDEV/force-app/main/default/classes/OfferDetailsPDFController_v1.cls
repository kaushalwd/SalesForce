/**********************************************************************************************************************
* Name               : OfferDetailsPDFController_v1                                                        
* Description        : This class is used as controller for offer details pdf
* Usage              : offer details pdf generation
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date                  Comment                                                                       
* 1.1          prateek.bansal@modon.com     8 Dec 2025         Added unit classification for bashayer project 
* 1.2          raghu.chilukuri@activemindsit.com    08/03/26   As requested by the Business Addded Boolean to show agency and agent names in regards for Broker
* 1.3          raghu.chilukuri@activemindsit.com    25/03/26    Added constants into Brconstants class related to broker and called them here and Created two varibales for Broker related Flow
* 1.4          raghu.chilukuri@activemindsit.com    26/03/26    Added Extra record type Broker Agency for the contacts  so as to Use Boolean For Them also
* 1.5		   prateek.bansal@modon.com				1 May 2026	Added Masterplan URL for virtual link
* 1.5		   sami.azam@modon.com				    5 June 2026	Added escrow account condition for Golf
******************************************************************************************************************/
public without sharing class OfferDetailsPDFController_v1 {
    
    public string customerName {get; set;}
    public string randomString {get; set;}
    public string island {get; set;}
    public Unit__c unitObj {get;set;}
    public Unit_Option__c unitOptnObj {get;set;}
    public PaymentPlan__c paymentPlanObj {get;set;}
    public string todayDate {get; set;}
    
    public string accountName {get;set;}
    public string bankName {get;set;}
    public string ibanNumber {get;set;}
    public string swiftCode {get;set;}
    public string accountNumber {get;set;}
    public VirtualAccount__c virtualAccountDetails {get;set;}
    public Decimal basePrice {get;set;}
    public Decimal totalPrice {get;set;}
    
    public Date estimatedCompletionDate {get; set;}
    public String numberOfBedroom {get; set;}
    public Decimal internalArea {get; set;}
    public Decimal balconyArea {get; set;}
    public String projectName {get;set;}
    public Decimal plotArea {get; set;}
    public String imageURL { get; set; }
    public String exteriorURL { get; set; }
    public String phaseName { get; set; }
    public Id projectId {get;set;}
    public Decimal GSAArea {get;set;}
    public List<String> interiorImages { get; set; }
    public List<String> exteriorImages { get; set; }
    public List<String> GFfloorPlanImages { get; set; }
    public List<String> FFfloorPlanImages { get; set; }
    public List<String> DPGImages { get; set; }
    public String dpgLink {get;set;}
    
    
    /*update Version 1.2
    @description: 
    *If the offer is from Broker Portal we have to Show Agency and Agentname in the Regards so
    * so added a Boolean for It
    */
    public String regardsName { get; set; }
    public Boolean isBrokerAgencyUser { get; set; }
    
    
    public OfferDetailsPDFController_v1() {
        String opportunityId = ApexPages.currentPage().getParameters().get('id');
        String currentUnit = ApexPages.currentPage().getParameters().get('currentUnit');
        String selectedPayment = ApexPages.currentPage().getParameters().get('selectedPayment');
        String selectedUnitOption = ApexPages.currentPage().getParameters().get('unitOption');
        String selectedDesign = ApexPages.currentPage().getParameters().get('selectedDesign');
        dpgLink = ApexPages.currentPage().getParameters().get('dpgLink');
        System.debug('dpgLink: '+ dpgLink);
        customerName = ApexPages.currentPage().getParameters().get('customerName');
        if(opportunityId != null && opportunityId!=''){
            opportunity opty = [select id,Account.Name from opportunity where id = :opportunityId];
            if(customerName ==null || customerName ==''){
                customerName=opty.Account.Name;
            } 
        }
        todayDate = System.today().format();
        randomString = generateRandomString(7);
        
  //New Line
        User u = [
            SELECT Id, FirstName, LastName, ContactId, AccountId,Account.Name, Account.RecordType.Name,Contact.Name, Contact.RecordType.Name FROM User
            WHERE Id = :UserInfo.getUserId() LIMIT 1];
        
        /* Update Version 1.3
          @description :
            * Updated Record Type checks to use values from BRConstants instead of hardcoded names.
       */
        
        Boolean accountIsBroker =(u.AccountId != null && u.Account != null && u.Account.RecordType != null && u.Account.RecordType.Name == BRConstants.BROKER_AGENCY_RT_NAME);
        //Update Version 1.4 Added BROKER_AGENCY_RT_NAME as production is Having Few Contacts With That Record Type
        Boolean contactIsBroker =(u.ContactId != null && u.Contact != null && u.Contact.RecordType != null && (
        u.Contact.RecordType.Name == BRConstants.BROKER_AGENT_RT_NAME ||
        u.Contact.RecordType.Name == BRConstants.BROKER_AGENCY_RT_NAME));
        //update version 1.3 ends here
        
        isBrokerAgencyUser = accountIsBroker && contactIsBroker;
        
        if (isBrokerAgencyUser) {
            regardsName = '[' + u.Account.Name + '  -  ' + u.Contact.Name + ']';
        }
           else {
            String fn = (u.FirstName == null) ? '' : u.FirstName;
            String ln = (u.LastName == null) ? '' : u.LastName;
            regardsName = (fn + ' ' + ln).trim();
        }
       //1.6 5 June 2026	Added escrow account condition for Golf
        List<VirtualAccount__c> vaLst = [SELECT Id, Name, Escrow_Bank_Name__c,EscrowAccountNameText__c, ESCROWAccountName__c, Escrow_Account_Name__c, SwiftCode__c, VirtualAccountNumber__c, VirtualIBANNumber__c FROM VirtualAccount__c WHERE Unit__c = :currentUnit AND Status__c = 'Available'];
        
        if(!vaLst.isEmpty()){
            virtualAccountDetails = vaLst[0];
            if(string.isNotBlank(virtualAccountDetails.VirtualAccountNumber__c)){
                virtualAccountDetails.VirtualAccountNumber__c = virtualAccountDetails.VirtualAccountNumber__c.replaceAll('(.{4})(?!$)', '$1 ');    
            }
            if(String.isNotBlank(virtualAccountDetails.VirtualIBANNumber__c)){
                virtualAccountDetails.VirtualIBANNumber__c = virtualAccountDetails.VirtualIBANNumber__c.replaceAll('(.{4})(?!$)', '$1 ');
            }
            

            // ibanNumber = virtualAccountDetails.VirtualIBANNumber__c;
            // ibanNumber = ibanNumber.replaceAll('(.{4})(?!$)', '$1 ');

            // ibanNumber = unitOptnObj.Unit__r.Phase__r.EscrowAccount__r.IBANNo__c;
            // ibanNumber = ibanNumber.replaceAll('(.{4})(?!$)', '$1 ');
        }

        if(selectedUnitOption!=null && selectedUnitOption!=''){
            unitOptnObj = getUnitOption(selectedUnitOption);
            basePrice = unitOptnObj.BasePrice__c;
            totalPrice = unitOptnObj.TotalPrice__c;
            island = unitOptnObj.Unit__r.Island_Name__c;
            numberOfBedroom = String.valueOf(unitOptnObj.NumberofBedrooms__c);
            internalArea = unitOptnObj.Internal_Area__c;
            balconyArea = unitOptnObj.BalconyArea__c;
            projectName = unitOptnObj.Unit__r.Phase__r.Project__r.Name;
            plotArea = unitOptnObj.PlotAreasqm__c;
            projectId = unitOptnObj.Unit__r.Phase__r.Project__r.Id;
            phaseName = unitOptnObj.Unit__r.Phase__r.Name;
            
            GSAArea = unitOptnObj.TotalGrossSellableAreaGSA__c ?? unitOptnObj.Unit__r.TotalArea__c;

            // accountName = unitOptnObj.Unit__r.Phase__r.EscrowAccount__r.BeneficiaryName__c;
            // bankName = unitOptnObj.Unit__r.Phase__r.EscrowAccount__r.BankName__c;
            // ibanNumber = unitOptnObj.Unit__r.Phase__r.EscrowAccount__r.IBANNo__c;
            // ibanNumber = ibanNumber.replaceAll('(.{4})(?!$)', '$1 ');
            // System.debug(ibanNumber);
            // swiftCode = unitOptnObj.Unit__r.Phase__r.EscrowAccount__r.SwiftCode__c;
            // accountNumber  = unitOptnObj.Unit__r.Phase__r.EscrowAccount__r.AccountNumber__c;

            ImageCategoryWrapper imagesMap = getImageUrlsByCategory(projectId,projectName,numberofBedroom,selectedDesign);
            interiorImages = imagesMap.interiorImages;
            exteriorImages = imagesMap.exteriorImages;
            GFfloorPlanImages = imagesMap.GFfloorPlanImages;
            FFfloorPlanImages = imagesMap.FFfloorPlanImages;
            DPGImages = imagesMap.DPGImages;
        }
        else if(currentUnit!=null && currentUnit!=''){
            unitObj = getUnitDetails(currentUnit);
            dpgLink = String.isNotBlank(unitObj.Masterplan_URL__c) ? unitObj.Masterplan_URL__c : System.Label.Modon_Interactive;
            basePrice = unitObj.BasePrice__c;
            totalPrice = unitObj.TotalPrice__c;
            island = unitObj.Island_Name__c;
            numberOfBedroom = unitObj.Number_of_Bedrooms__c;
            internalArea = unitObj.Internal_Area__c;
            balconyArea = unitObj.BalconyArea__c;
            projectName = unitObj.Phase__r.Project__r.Name;
            plotArea = unitObj.PlotAreasqm__c;
            projectId = unitObj.Phase__r.Project__r.Id;
            phaseName = unitObj.Phase__r.Name;
            GSAArea = unitObj.TotalGrossSellableAreaGSA__c ?? unitObj.TotalArea__c;

            accountName = unitObj.Phase__r.EscrowAccount__r.BeneficiaryName__c;
            bankName = unitObj.Phase__r.EscrowAccount__r.BankName__c;
            ibanNumber = unitObj.Phase__r.EscrowAccount__r.IBANNo__c;
            swiftCode = unitObj.Phase__r.EscrowAccount__r.SwiftCode__c;
            accountNumber  = unitObj.Phase__r.EscrowAccount__r.AccountNumber__c;

            ImageCategoryWrapper imagesMap = getImageUrlsByCategory(projectId,projectName,numberofBedroom,selectedDesign);
            interiorImages = imagesMap.interiorImages;
            exteriorImages = imagesMap.exteriorImages;
            GFfloorPlanImages = imagesMap.GFfloorPlanImages;
            FFfloorPlanImages = imagesMap.FFfloorPlanImages;
            DPGImages = imagesMap.DPGImages;
        }
        Integer i = 0;
        if(selectedPayment!=null && selectedPayment!=''){
            paymentPlanObj = getPaymentDetails(selectedPayment);
            for(PaymentInstallements__c pi: paymentPlanObj.Payment_Installments__r){
                i++;
                if(paymentPlanObj.Payment_Installments__r.size() == i){
                    estimatedCompletionDate = pi.MilestoneDate__c;
                }
            }
        }
        if(selectedUnitOption!=null && selectedUnitOption!=''){
            string fileName = 'Offer-'+unitOptnObj.Name+'-'+customerName+'-'+todayDate;
            Apexpages.currentPage().getHeaders().put('content-disposition', 'inline; filename='+fileName+'.pdf'); 
        }else{
            string fileName = 'Offer-'+unitObj.Name+'-'+customerName+'-'+todayDate;
            Apexpages.currentPage().getHeaders().put('content-disposition', 'inline; filename='+fileName+'.pdf');
        }
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
        return [SELECT Id, Name, BasePrice__c, TotalPrice__c, PlotAreasqm__c, GrossFloorAreaGFA__c,Unit__r.Island_Name__c, Unit__c,Unit__r.Name,Unit__r.Phase__r.Project__r.Name,Unit__r.Phase__r.Project__r.Id,Unit__r.TotalPrice__c,Unit__r.TotalArea__c,Unit__r.Masterplan_URL__c,		//v1.5
                TotalGrossSellableAreaGSA__c,TerraceArea__c,Type__c,Model__c, Garage__c,NumberofBedrooms__c,Internal_Area__c,BalconyArea__c,Typology__c,Unit__r.Phase__r.Name,Unit__r.Typology__c,Unit__r.Phase__r.ADMAccountName__c,Unit__r.Phase__r.ADMAccountNumber__c,Unit__r.Phase__r.ADMBankName__c,
                Unit__r.Phase__r.EscrowAccount__r.Name, Unit__r.Phase__r.EscrowAccount__r.BankName__c, Unit__r.Phase__r.EscrowAccount__r.AccountNumber__c, Unit__r.Phase__r.EscrowAccount__r.SwiftCode__c, Unit__r.Phase__r.EscrowAccount__r.IBANNo__c,
                Unit__r.Phase__r.EscrowAccount__r.BeneficiaryName__c,Unit__r.Phase__r.ADMIBANNumber__c,Unit__r.Phase__r.SwiftCode__c
                FROM Unit_Option__c WHERE Id = :selectedUnitOption];
    }
    
    private Unit__c getUnitDetails(Id unitId){
        return [SELECT Id, Name, Phase__r.Name, TotalPrice__c, Phase__c, Phase__r.Project__c, BasePrice__c, PlotAreasqm__c,TotalArea__c ,
                GrossFloorAreaGFA__c,TotalGrossSellableAreaGSA__c,TerraceArea__c,Type__c,Model__c,Number_of_Bedrooms__c,Internal_Area__c,BalconyArea__c,
                Phase__r.Project__r.Name, Garage__c,Typology__c,Island_Name__c,Phase__r.ADMAccountName__c,Phase__r.ADMAccountNumber__c,Phase__r.ADMBankName__c,Masterplan_URL__c,		//v1.5
                Phase__r.EscrowAccount__r.Name, Phase__r.EscrowAccount__r.BankName__c, Phase__r.EscrowAccount__r.AccountNumber__c, Phase__r.EscrowAccount__r.SwiftCode__c, Phase__r.EscrowAccount__r.IBANNo__c,
                Phase__r.EscrowAccount__r.BeneficiaryName__c,Phase__r.ADMIBANNumber__c,Phase__r.SwiftCode__c,UnitClassification__c          //v1.1 
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
    public static ImageCategoryWrapper getImageUrlsByCategory(Id projectId, String projectName, String numberOfBedroom, String selectedDesign) {
        ImageCategoryWrapper result = new ImageCategoryWrapper();
        List<ContentDocumentLink> docLinks = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :projectId];
        
        if (!docLinks.isEmpty()) {
            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink link : docLinks) {
                docIds.add(link.ContentDocumentId);
            }
            
            List<ContentVersion> contentVersions = [SELECT Id, Title, ContentDocumentId FROM ContentVersion WHERE ContentDocumentId IN :docIds AND IsLatest = true];
            String bedroomPrefix = '';
            Pattern p = Pattern.compile('^(\\d+)');
            for (ContentVersion cv : contentVersions) {
                if (String.isBlank(cv.Title)) continue;
                
                String titleLower = cv.Title.toLowerCase();
                String imageUrl = '/sfc/servlet.shepherd/version/download/' + cv.Id;
                Matcher m = p.matcher(cv.Title.trim());
                system.debug('Matcher value-->>'+m);
                system.debug('Matcher cv.Title.trim()-->>'+cv.Title.trim());
                system.debug('bedroomPrefix--->>'+bedroomPrefix);
                system.debug('m.find()--->>'+m.find());
                if (m.find()) { bedroomPrefix = m.group(1); }  
                system.debug('bedroomPrefix-->>'+bedroomPrefix);
                system.debug('bedroomPrefix-->>>'+numberOfBedroom);
                if (bedroomPrefix == numberOfBedroom) {
                    if (titleLower.contains('interior')) {
                        result.interiorImages.add(imageUrl);
                    } else if ((titleLower.contains('exterior') && projectName != 'Al Naseem') || (titleLower.contains(selectedDesign.toLowerCase()) && projectName == 'Al Naseem')) {
                        result.exteriorImages.add(imageUrl);
                    } else if (titleLower.contains('ground floor')) {
                        result.GFfloorPlanImages.add(imageUrl);
                    } else if (titleLower.contains('first floor')) {
                        result.FFfloorPlanImages.add(imageUrl);
                    } 
                }
                if (titleLower.contains('dpg')) {
                    result.DPGImages.add(imageUrl);
                }
            }
        }
        return result;
    }

    public class ImageCategoryWrapper {
        public List<String> interiorImages { get; set; }
        public List<String> exteriorImages { get; set; }
        public List<String> GFfloorPlanImages { get; set; }
        public List<String> FFfloorPlanImages { get; set; }
        public List<String> DPGImages { get; set; }
        
        public ImageCategoryWrapper() {
            interiorImages = new List<String>();
            exteriorImages = new List<String>();
            GFfloorPlanImages = new List<String>();
            FFfloorPlanImages = new List<String>();
            DPGImages = new List<String>();
        }
    }
}