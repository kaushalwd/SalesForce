public class SPA_ReemHillsPdfController {
    
    public String currentRecordId;
    public integer index {get;set;}
    public string inWords {get;set;}
    public Decimal No_of_installments{get;set;}
    public Account acc {get;set;}
    public String contactName{get;set;}
    public string delimitedString {get;set;}
    public Unit__c inv {get;set;}
   // public List<Receipt__c> PaymentPlanDetails {get;set;}
    public Decimal UnitTotalAreaSQF {get;set;}
    public Decimal UnitTotalAreaSQM{get;set;}
    public Decimal BalconyAreaSQM{get;set;}
    public Decimal internalAreaSQM{get;set;}
    public Decimal plotAreaSQM{get;set;}
    public Decimal plotAreaSQF{get;set;}
    public String contactEmail{get;set;}
    public String contactMobile{get;set;}
    public Map<String, String> allocParking{get;set;}

    public String signed {get;set;}
    public Phase__c phaseMDTFields{get;set;}
    public string inWordsRegFee {get;set;}
    public String personEmailStr{get;set;}
    public String secondAppEmailStr{get;set;}
    
    public JointOwnerWrapper[] jointOwners {get;set;}
    
    public Decimal jointRemainingPercent{get;set;}
    
    public Decimal salesOrderFinalValue {get;set;}
    public SalesOrderInstallments__c[] installments {get;set;}
    public Date completionDate {get;set;}
    
    //Falak Code start
    public boolean FloorPlanAvailable{get;set;}
    public list<Unit__c> plotlist {get;set;}
    public string designPlan{get;set;}
    //falak code end
    
    
    public SPA_ReemHillsPdfController(ApexPages.StandardController controller){
        currentRecordId  = ApexPages.CurrentPage().getparameters().get('id');

        phaseMDTFields = new Phase__c();

        FloorPlanAvailable = false; 
        designPlan = designPlan != null ? designPlan : '';
        map<string,string> plotnames = new map<string,string>(); 
        SalesOrder__c book = [select Id, TotalAmount__c,CustomerAccount__c,Unit__c,PaymentPlan__c,Unit__r.name,Unit__r.Typology__c, Unit__r.Internal_Area__c, PaymentPlan__r.Name,
                              Unit__r.PlotAreasqm__c, Unit__r.BalconyArea__c, Unit__r.phase__c, ReservationFee__c from SalesOrder__c where Id =: currentRecordId]; // using ReservationFee__c not found Registration_Fee__c

        salesOrderFinalValue = book.TotalAmount__c;
        PaymentInstallements__c[] paymentInstallments = [SELECT Id, MilestoneDate__c FROM PaymentInstallements__c WHERE Name = 'On Completion' AND PaymentInstallment__c = :book.PaymentPlan__c LIMIT 1];
        if (!paymentInstallments.isEmpty()) {
            completionDate = paymentInstallments[0].MilestoneDate__c;
        }


        Boolean isDiscountPaymentPlan = String.isNotEmpty(book.PaymentPlan__r.Name) ?
            book.PaymentPlan__r.Name.containsIgnoreCase('50%') || book.PaymentPlan__r.Name.containsIgnoreCase('100%') : false;
		installments = [SELECT Id, Name, InstallmentAmount__c, Milestone__c, MilestoneDescriptionSPA__c, MilestoneDate__c from SalesOrderInstallments__c WHERE SalesOrder__c =: currentRecordId order by MilestoneNumber__c asc];
        if (isDiscountPaymentPlan) {
            Decimal discount = book.PaymentPlan__r.Name.containsIgnoreCase('50%') ? 0.04 : 0.07;
            for (SalesOrderInstallments__c installment: installments) {
                installment.InstallmentAmount__c = installment.InstallmentAmount__c - (installment.InstallmentAmount__c * discount);
            }

            salesOrderFinalValue = salesOrderFinalValue - (salesOrderFinalValue * discount);
        }

        JointOwner__c[] jointOwnerList = [SELECT Id, JointOwnerAccount__c,
                                       JointOwnerAccount__r.Name, JointOwnerAccount__r.Salutation, JointOwnerAccount__r.Nationality__pc, JointOwnerAccount__r.EIDNumber__pc,
                                       JointOwnerAccount__r.PassportNumber__pc, JointOwnerAccount__r.BillingStreet, JointOwnerAccount__r.BillingCity, JointOwnerAccount__r.BillingState,
                                       JointOwnerAccount__r.BillingpostalCode, JointOwnerAccount__r.BillingCountry, JointOwnerAccount__r.PersonMobilePhone, JointOwnerAccount__r.PersonEmail,
                                       OwnershipPercentage__c FROM JointOwner__c WHERE SalesOrder__c = :book.Id];
        
        Decimal totalPercent = 0;
        jointOwners = new List<JointOwnerWrapper>();
        for (JointOwner__c joint: jointOwnerList) {
            JointOwnerWrapper wrapper = new JointOwnerWrapper();
            wrapper.Name = joint.JointOwnerAccount__r.Name;
            wrapper.postalCode = joint.JointOwnerAccount__r.BillingpostalCode;
            wrapper.ownership = Integer.valueOf(joint.OwnershipPercentage__c);
            wrapper.email = joint.JointOwnerAccount__r.PersonEmail;
            wrapper.mobile = joint.JointOwnerAccount__r.PersonMobilePhone;
            wrapper.country = joint.JointOwnerAccount__r.BillingCountry;
            wrapper.street = joint.JointOwnerAccount__r.BillingStreet;
            wrapper.city = joint.JointOwnerAccount__r.BillingCity;
            wrapper.state = joint.JointOwnerAccount__r.BillingState;
            wrapper.passNo = joint.JointOwnerAccount__r.PassportNumber__pc;
            wrapper.eidNo = joint.JointOwnerAccount__r.EIDNumber__pc;
            wrapper.nationality = joint.JointOwnerAccount__r.Nationality__pc;
            wrapper.salutation = joint.JointOwnerAccount__r.Salutation;
            
            jointOwners.add(wrapper);
            totalPercent += joint.OwnershipPercentage__c;
        }

        jointRemainingPercent = 100 - totalPercent;
        jointRemainingPercent = Integer.valueOf(jointRemainingPercent);
        delimitedString = '';

        if(book.Unit__r.phase__c != null){
            List<Phase__c> p = [SELECT Id,Phase_code__c, PhaseNameArabic__c, Name, Sector_No__c, Plot_number__c, Project_Number__c, Project_s_Land_Acquisition_byseller__c, Developer_Registration_Number__c,
                                	Account_Trustee_Name__c, EscrowAccount__r.name, EscrowAccount__r.BankName__c, EscrowAccount__r.Branch__c,
                                    EscrowAccount__r.AccountNumber__c, EscrowAccount__r.IBANNo__c, EscrowAccount__r.SwiftCode__c FROM Phase__c where Id = :book.Unit__r.Phase__c];
        	if(!p.isEmpty()) {
                phaseMDTFields = p[0];
            }
        }
        List<Contact> ContactList = [Select id,name,Email,Phone from contact where AccountId =: book.CustomerAccount__c limit 1];
        if(ContactList.size() > 0){
            contactName = ContactList[0].Name;
            contactEmail = ContactList[0].Email; 
            contactMobile = ContactList[0].Phone;
        }
        
        // In words start
       if (book.TotalAmount__c  != null && book.TotalAmount__c  >= 0) {
         
            Integer n = Integer.valueOf(book.TotalAmount__c);
            string amo = NumberToText.convert(n);
            string amo1 = amo.remove(',');
            inWords = amo1;
           
            Integer regFee = Integer.valueOf(book.ReservationFee__c);
            string regAmo = NumberToText.convert(regFee);
            string amoReg = regAmo.remove(',');
            inWordsRegFee = amoReg;
           
        } else {
            inWords = '';
            inWordsRegFee ='';
        }
        //In words end

        String invalidNumbers = '[^0-9]'; 
        if(book.Unit__r.Internal_Area__c > 0 && book.Unit__r.BalconyArea__c > 0){
            UnitTotalAreaSQF = book.Unit__r.Internal_Area__c + book.Unit__r.BalconyArea__c;
            internalAreaSQM = (book.Unit__r.Internal_Area__c * 0.092903).setScale(0);
            BalconyAreaSQM = (book.Unit__r.BalconyArea__c * 0.092903).setScale(0);
            UnitTotalAreaSQM = internalAreaSQM + BalconyAreaSQM;
        }
        else if(book.Unit__r.Internal_Area__c > 0) {
            UnitTotalAreaSQF = book.Unit__r.Internal_Area__c;
            UnitTotalAreaSQM = (UnitTotalAreaSQF * 0.092903).setScale(0);
    		internalAreaSQM = (book.Unit__r.Internal_Area__c * 0.092903).setScale(0);
            
        }else if(book.Unit__r.BalconyArea__c > 0){
            UnitTotalAreaSQF = book.Unit__r.BalconyArea__c;
            UnitTotalAreaSQM = (UnitTotalAreaSQF * 0.092903).setScale(0);
            BalconyAreaSQM = (book.Unit__r.BalconyArea__c * 0.092903).setScale(0);
        }
        if(book.Unit__r.PlotAreasqm__c > 0){
            plotAreaSQM =  (book.Unit__r.PlotAreasqm__c * 0.092903).setScale(0);
            plotAreaSQF = (book.Unit__r.PlotAreasqm__c * 10.7639).setScale(0);
        }

        //New Code
        plotnames.put(book.Unit__c,book.Unit__r.name);
        set<id> plotidset = new set<id>();
        System.debug('plotidset : '+plotidset);
        if(book.Unit__c != null){
        	plotidSet.add(book.Unit__c);
            // SOQL injection fix: plot Ids bound via queryWithBinds (SELECT fields from schema describe only).
            String query = 'Select '+ getAllFields('Unit__c') + ' from Unit__c where id in :plotidset order by name';
            plotlist = new List<Unit__c>();
            plotlist = Database.queryWithBinds(
                query,
                new Map<String, Object>{ 'plotidset' => plotidset },
                AccessLevel.SYSTEM_MODE
            );
            System.debug(plotList);
        }
        
        if(!plotidset.isempty()){
            floorplanList = new list<floorPlan>();        
            
            set<id> condocid = new set<id>();
            map<id,id> ultoId = new map<id,id>();
            map<string,set<string>> unitPlanmap = new map<string,set<string>>();
            for(ContentDocumentLink cdl : [SELECT Id, LinkedEntityId, ContentDocumentId FROM ContentDocumentLink  WHERE LinkedEntityId in : plotidset order by LinkedEntityId]){
                condocid.add(cdl.ContentDocumentId); 
                ultoId.put(cdl.ContentDocumentId,cdl.LinkedEntityId);
                system.debug(cdl.ContentDocumentId+'<==cdl.LinkedEntityId ==>'+cdl.LinkedEntityId); 
                plotnames.put(cdl.ContentDocumentId, plotnames.get(cdl.LinkedEntityId));
                if(!unitPlanmap.containsKey(cdl.LinkedEntityId)){
                    unitPlanmap.put(cdl.LinkedEntityId, new set<string>());
                }
                unitPlanmap.get(cdl.LinkedEntityId).add(cdl.ContentDocumentId);
            }
            
            system.debug('unitPlanmap='+unitPlanmap); 
            
            floorplanList = new list<floorplan>();
            floorplanMap = new map<string,list<floorplan>>();
            map<id,floorPlan> fltmap = new map<id,floorplan>();
            for(ContentDocument cd : [SELECT Id,Title, LatestPublishedVersionId FROM ContentDocument where id in :condocid and filetype != 'PDF' order by Title]){
                floorPlan fp = new floorPlan();
                fp.planLink = '/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_Png&versionId='+cd.LatestPublishedVersionId;
                fp.isValid = true;
                fp.name = cd.title;
                fp.pagetype = 'A6';
                
                
                    fltmap.put(cd.id,fp);
                
                
            }
            if(unitPlanmap.size()>0){
                FloorPlanAvailable = true;
                System.debug('Unit Plan Map');
                for(string key : unitPlanmap.keyset()){
                    system.debug('Key=='+key);
                    
                    for(string unid : unitPlanmap.get(key)){
                        floorPlan fp = fltmap.get(unid);
                        
                        system.debug('unid=='+unid);
                        system.debug('fp=='+fp);
                        system.debug('plotnames.get(key)=='+plotnames.get(key));
                        if(fp != null && fp.name.contains(designPlan)){
                            floorPlan f2 = new floorPlan();
                            f2.planLink = fp.planLink;
                            f2.isValid = fp.isValid;
                            f2.name = fp.name+'-'+plotnames.get(key);
                            f2.plodId = plotnames.get(key);
                            f2.pagetype = fp.pagetype;
                            system.debug('f2=='+f2);
                            if(!floorplanMap.containsKey(f2.plodId)){
                                floorplanMap.put(f2.plodId,new list<floorplan>());
                            }
                            floorplanMap.get(f2.plodId).add(f2);
                        }
                        
                    }
                    //floorplanMap.get(plotnames.get(key)).sort();
                    
                    
                }
            }
        }
        System.debug('floorPlanMap'+floorplanMap);
        System.debug('plotName'+plotlist);
    }
    
    public map<string,list<floorplan>> floorplanMap {get;set;}
    public list<floorPlan> floorplanList{get;set;}
    
    public class floorplan{
        public String planLink{get;set;}
        public Boolean isValid{get;set;}
        public String name{get;set;}
        public String plodId{get;set;}
        public String pagetype{get;set;}
    }
    
    public static String getAllFields(String sobjectName) {
        Set<String> fieldNames = Schema.getGlobalDescribe().get(sobjectName).getDescribe().fields.getMap().keySet();
        return String.join(new List<String>(fieldNames), ',');
    }
    
    public class JointOwnerWrapper {
        public String Name {get;set;}
        public String postalCode {get;set;}
        public Integer ownership {get;set;}
        public String email {get;set;}
        public String mobile {get;set;}
        public String country {get;set;}
        public String street {get;set;}
        public String city {get;set;}
        public String state {get;set;}
        public String passNo {get;set;}
        public String eidNo {get;set;}
        public String nationality {get;set;}
        public String salutation {get;set;}
    }
    
}