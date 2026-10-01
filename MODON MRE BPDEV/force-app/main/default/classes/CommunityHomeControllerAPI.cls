/**
* @description       : Community/Portal Home APIs (bulkified)
* @author            : Krishna Chaitanya
* @last modified on  : 08-27-2025
* @last modified by  : Krishna Chaitanya
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Krishna Chaitanya   27 Aug 2025         Initial Draft
* 2.0           Manoj               10 Oct 2025         Logic update and performance improvements
* 3.0           Manoj               16 Nov 2025         Multi-account handling added:
*                                                       - Same email mapped to multiple accounts
*                                                       - Additional validation using EID and/or Passport
*                                                       - Response returns validated data or empty result
*                                                       - Applicable for all account types
*4.0           Manoj               08 Jan 2026         Add the Gross Floor Area (GFA) logic to show area
*5.0           Manoj               09 Jan 2026         Add the Chat and joint owners logic to show area
*6.0		   Manoj			   15 Jan 2026		   Add the Joint Owner Filter if we have duplicates account 
*7.0		   Manoj			   10 Mar 2026		   add All Joint Owner Filter
*8.0		   Arvind			   02 Jul 2026		   BUG FIX: When customer is a joint owner on any Sales Order
*                                                     
**/
public without sharing class CommunityHomeControllerAPI {
    
    
    @AuraEnabled(cacheable=true)
    public static List<SalesOrderWrapper> getSalesOrdersByCustomer(Id customerId, string eidNumber, string passportNumber) { //3.0 Multi accounts
        //list<string> projectFilter = getfilters(System.Label.CP_ProjectName);new 
        list<string> projectFilter =new list<string>();
        list<string> statusFilter = getfilters(System.Label.CP_SO_Statusfilters);
        system.debug('projectFilter--'+projectFilter);
        system.debug('projectFilter--'+statusFilter);
        set<id> salesOrderJoinmtIds =new set<id>();
        List<SalesOrder__c> salesOrders = new List<SalesOrder__c>(); //5.0 JointOwner where logic
        for(JointOwner__c Jointids: [select id,name,SalesOrder__c,SalesOrder__r.name,JointOwnerAccount__r.name from JointOwner__c where JointOwnerAccount__c = :customerId  AND SalesOrder__c != null and SalesOrder__r.Status__c NOT IN : statusFilter]){
            salesOrderJoinmtIds.add(Jointids.SalesOrder__c);
        }
      /**
     * 3.0
     * Fetch Sales Orders for Community user.
     * Supports multi-account scenario where same email exists for multiple accounts.
     * Additional validation using EID and/or Passport Number is applied when required.
     */
        string MIREExcludelst = System.Label.MIRE_Exclude_List;
        
        for (String c2 : MIREExcludelst.split(',')) {
           if (c2 != null && c2.contains('^')) {
                    projectFilter.add(c2.replace('^', ',').trim());
            } else {
                    projectFilter.add(c2.trim());
            }
        }        
        
        System.debug('MIREList :' +projectFilter);
        
        string query = ' SELECT Id, ProjectName__c, Name, Image_Name_pc__c,Unit__r.TotalGrossSellableAreaGSA__c,SPAPublicUrl__c, PortalImageName__c, Unit__c, UnitOption__c,Unit__r.Number_of_Bedrooms__c, Unit__r.Phase__r.Description__c, Unit__r.Numberofbathroom__c,UnitOption__r.AdditionalPrice__c, UnitOption__r.AED_SQM__c, UnitOption__r.AreaUnitofMeasure__c,UnitOption__r.BalconyArea__c, UnitOption__r.BasePrice__c, UnitOption__r.Description__c,UnitOption__r.GrossFloorAreaGFA__c, UnitOption__r.Internal_Area__c, UnitOption__r.NumberofBedrooms__c,UnitOption__r.NumberofCarParks__c, UnitOption__r.PlotNo__c, UnitOption__r.PlotAreasqm__c, UnitOption__r.Name,'+
            'UnitOption__r.TotalGrossSellableAreaGSA__c, UnitOption__r.TotalPrice__c, UnitOption__r.Type__c,UnitOption__r.Typology__c, UnitOption__r.Unit__c, UnitOption__r.Unit_Option_Image__c,Unit__r.Type__c, Unit__r.Phase__c, Unit__r.UnitClassification__c, Unit__r.Numberofbalcony__c,Unit__r.TotalArea__c, Unit__r.PlotNo__c, Unit__r.Project_Name__c, Unit__r.NumberofCarParks__c, Unit__r.PlotAreasqm__c,TotalGrossSellableAreaGSA__c, TotalAmount__c, PaymentPlanStructure__c, Unit__r.Name, Unit__r.GrossFloorAreaGFA__c,PaymentPlan__c, PaymentPlan__r.Name, PhaseImagePublicURL__c,(SELECT Id, SalesOrder__c FROM Documents__r WHERE Name =  \'Signed SPA (Modon) \' AND Status__c =  \'Uploaded \' LIMIT 1)  FROM SalesOrder__c '+          
            'WHERE Status__c NOT IN : statusFilter and Unit__r.Project_Name__c NOT IN : projectFilter ';
        
         /**
         * 3.0 Multi-account validation logic
         * Priority:
         * 1. Both EID + Passport provided → strict match
         * 2. Only EID provided
         * 3. Only Passport provided
         * 4. No additional identifiers → fallback to customerId or joint ownership
         *
         * 8.0 FIX: Every branch below now also allows CustomerAccount__c = :customerId
         * so that a customer's DIRECTLY/PRIMARILY owned Sales Orders are always returned,
         * regardless of whether EID/Passport was supplied or whether they match a
         * JO1__r-JO6__r joint owner slot. Previously, primary-owned Sales Orders were
         * silently excluded whenever the customer was a joint owner on ANY Sales Order
         * and an eidNumber/passportNumber was passed in.
         */
        if (salesOrderJoinmtIds.size() > 0) { //6.0 start add the duplicates 
            // 3.0  Multi accounts
            // Passport + EID both exist
            // 7.0 add All Joint Owner Filter
            // 8.0 FIX: added "OR CustomerAccount__c = :customerId" so primary-owned SOs are not dropped
            if (eidNumber != null && passportNumber != null) {
                query += ' AND ('
                       +   '((JO1__r.EIDNumber__c = :eidNumber OR JO2__r.EIDNumber__c = :eidNumber OR JO3__r.EIDNumber__c = :eidNumber OR JO4__r.EIDNumber__c = :eidNumber OR JO5__r.EIDNumber__c = :eidNumber OR JO6__r.EIDNumber__c = :eidNumber)'
                       +   ' AND (JO1__r.PassportNumber__c = :passportNumber OR JO2__r.PassportNumber__c = :passportNumber OR JO3__r.PassportNumber__c = :passportNumber OR JO4__r.PassportNumber__c = :passportNumber OR JO5__r.PassportNumber__c = :passportNumber OR JO6__r.PassportNumber__c = :passportNumber))'
                       +   ' OR CustomerAccount__c = :customerId'
                       + ')';
            }
            
            //3.0 Multi accounts Only EID
            // 7.0 add All Joint Owner Filter
            // 8.0 FIX: added "OR CustomerAccount__c = :customerId" so primary-owned SOs are not dropped
            else if (eidNumber != null && passportNumber == null) {
                query += ' AND ('
                       +   '(JO1__r.EIDNumber__c = :eidNumber OR JO2__r.EIDNumber__c = :eidNumber OR JO3__r.EIDNumber__c = :eidNumber OR JO4__r.EIDNumber__c = :eidNumber OR JO5__r.EIDNumber__c = :eidNumber OR JO6__r.EIDNumber__c = :eidNumber)'
                       +   ' OR CustomerAccount__c = :customerId'
                       + ')';
            }
            
            //3.0 Multi accounts Only Passport
            // 7.0 add All Joint Owner Filter
            // 8.0 FIX: added "OR CustomerAccount__c = :customerId" so primary-owned SOs are not dropped
            else if (eidNumber == null && passportNumber != null) {
                query += ' AND ('
                       +   '(JO1__r.PassportNumber__c = :passportNumber OR JO2__r.PassportNumber__c = :passportNumber OR JO3__r.PassportNumber__c = :passportNumber OR JO4__r.PassportNumber__c = :passportNumber OR JO5__r.PassportNumber__c = :passportNumber OR JO6__r.PassportNumber__c = :passportNumber)'
                       +   ' OR CustomerAccount__c = :customerId'
                       + ')';
            } //6.0 End
            // No filters
            else {
                query += ' AND (CustomerAccount__c = :customerId OR id =: salesOrderJoinmtIds )';
            }
            
            //3.0 Multi accounts ORDER + LIMIT always added at the end
            query += ' ORDER BY CreatedDate DESC LIMIT 200';
            // SOQL injection fix: portal identifiers bound via queryWithBinds.
            salesOrders = Database.queryWithBinds(
                query,
                new Map<String, Object>{
                    'statusFilter' => statusFilter,
                    'projectFilter' => projectFilter,
                    'eidNumber' => eidNumber,
                    'passportNumber' => passportNumber,
                    'customerId' => customerId,
                    'salesOrderJoinmtIds' => salesOrderJoinmtIds
                },
                AccessLevel.SYSTEM_MODE
            );
            system.debug('salesOrderssoql----'+salesOrders.size() );
            system.debug('salesOrderssoql----'+salesOrders);
            
        }else {
             // 3.0 Same validation logic when no joint ownership exists
            if (eidNumber != null && passportNumber != null) {
                query += ' AND CustomerAccount__r.PassportNumber__pc = :passportNumber ' +
                    'AND CustomerAccount__r.EIDNumber__pc = :eidNumber';
            }
            
            //3.0 Only EID
            else if (eidNumber != null && passportNumber == null) {
                query += ' AND CustomerAccount__r.EIDNumber__pc = :eidNumber';
            }
            
            // 3.0 Only Passport
            else if (eidNumber == null && passportNumber != null) {
                query += ' AND CustomerAccount__r.PassportNumber__pc = :passportNumber';
            }
            // No filters
            else {
                query +=  ' AND (CustomerAccount__c = :customerId )';
            }      
            //3.0 ORDER + LIMIT always added at the end
            query += ' ORDER BY CreatedDate DESC LIMIT 200';
            salesOrders = Database.queryWithBinds(
                query,
                new Map<String, Object>{
                    'statusFilter' => statusFilter,
                    'projectFilter' => projectFilter,
                    'eidNumber' => eidNumber,
                    'passportNumber' => passportNumber,
                    'customerId' => customerId
                },
                AccessLevel.SYSTEM_MODE
            );
            system.debug('salesOrderssoql----'+salesOrders.size() );
            system.debug('salesOrderssoql----'+salesOrders);
            
        }
        
        if (salesOrders.isEmpty()) return new List<SalesOrderWrapper>();
        
        
        /**
         * BULK OPTIMIZATION
         * - Fetch Phase descriptions in one query
         * - Fetch Installment summaries in one query
         * - Fetch public image URLs in one query
         */
        Set<Id> phaseIds = new Set<Id>();
        for (SalesOrder__c so : salesOrders) {
            if (so.Unit__r != null && so.Unit__r.Phase__c != null) {
                phaseIds.add(so.Unit__r.Phase__c);
            }
        }
        
        Map<Id, String> phaseDescMap = new Map<Id, String>();
        if (!phaseIds.isEmpty()) {
            for (Phase__c phase : [
                SELECT Id, Description__c FROM Phase__c WHERE Id IN :phaseIds
            ]) {
                phaseDescMap.put(phase.Id, phase.Description__c);
            }
        }
        
        // Build summary of installments (single SOQL)
        Set<Id> salesOrderIds = new Set<Id>();
        for (SalesOrder__c so : salesOrders) salesOrderIds.add(so.Id);
        
        Map<Id, SalesOrderInstallmentSummary> summaryMap = new Map<Id, SalesOrderInstallmentSummary>();
        if (!salesOrderIds.isEmpty()) {
            for(Invoice__c  Inv : [select id,InvoiceStatus__c,TotalPaidAmount__c,AppliedAmount__c,InvoiceAmount__c,InvoiceBalance__c, SalesOrderInstallment__r.SalesOrder__c,SalesOrderInstallment__r.SalesOrder__r.Totalpaidamount__c, SalesOrderInstallment__r.SalesOrder__r.TotalAmount__c,SalesOrderInstallment__r.InstallmentAmount__c, SalesOrderInstallment__r.MilestoneNumber__c, SalesOrderInstallment__r.PaymentStatus__c, SalesOrderInstallment__r.MilestoneDate__c from Invoice__c where SalesOrderInstallment__r.SalesOrder__c IN :salesOrderIds
                                   and InvoiceStatus__c != 'Cancelled' ORDER BY SalesOrderInstallment__r.MilestoneNumber__c ASC ]){
                                       if (!summaryMap.containsKey(Inv.SalesOrderInstallment__r.SalesOrder__c)) {
                                           summaryMap.put(Inv.SalesOrderInstallment__r.SalesOrder__c, new SalesOrderInstallmentSummary());
                                       }
                                       SalesOrderInstallmentSummary summary = summaryMap.get(Inv.SalesOrderInstallment__r.SalesOrder__c);
                                       
                                       if (Inv.InvoiceStatus__c == 'Paid' || Inv.InvoiceStatus__c == 'Partially Paid') {
                                           summary.totalPaidInstallments++;
                                           summary.totalpaidCollectedAmount += (Inv.TotalPaidAmount__c != null ? Inv.TotalPaidAmount__c : 0);
                                           system.debug('summary.totalpaidCollectedAmount---'+summary.totalpaidCollectedAmount);
                                       } 
                                       if(Inv.InvoiceStatus__c == 'Generated'){ //5.0 Add Chat
                                           summary.totalNotPaidInstallments++;
                                           summary.balanceAmount += (Inv.InvoiceBalance__c != null ? Inv.InvoiceBalance__c : 0);
                                           if (summary.nextMilestoneDate == null) {
                                               summary.nextMilestoneDate = Inv.SalesOrderInstallment__r.MilestoneDate__c;
                                               summary.nextInstallmentAmount = Inv.InvoiceBalance__c;
                                           }
                                       }
                                       summary.installmentsNumber = Integer.valueOf(Inv.SalesOrderInstallment__r.MilestoneNumber__c);
                                       Decimal totalAmount = summary.totalpaidCollectedAmount ;
                                       system.debug('totalAmount---'+totalAmount);
                                       summary.totalCollectedAmount =Inv.SalesOrderInstallment__r.SalesOrder__r.TotalAmount__c;
                                       summary.paidPercentage = (totalAmount > 0) ? ( totalAmount/summary.totalCollectedAmount) * 100 : 0;
                                       summary.totalInstallments++;
                                   }
        }
        
        // BULK: get all image URLs in one go (no SOQL-in-loop)
        Map<Id, String> soToImageUrl = ContentPublicURLHelper.getPublicLinksForSalesOrders(salesOrderIds);
        
        // Build results
        List<SalesOrderWrapper> results = new List<SalesOrderWrapper>();
        for (SalesOrder__c so : salesOrders) {
            results.add(new SalesOrderWrapper(
                so,
                phaseDescMap,
                summaryMap.get(so.Id),
                soToImageUrl.get(so.Id)
            ));
        }
        return results;
    }
    // ================== Helper & Wrapper Classes (unchanged) ==================
    // SalesOrderInstallmentSummary
    // SalesOrderWrapper
    // Notifications, Floor Plan, SPA, Callouts, Filters
    public class SalesOrderInstallmentSummary {
        @AuraEnabled public Integer totalPaidInstallments = 0;
        @AuraEnabled public Integer totalNotPaidInstallments = 0;
        @AuraEnabled public Integer totalInstallments = 0;
        @AuraEnabled public Decimal totalCollectedAmount = 0;
        @AuraEnabled public Decimal balanceAmount = 0;
        @AuraEnabled public Date nextMilestoneDate;
        @AuraEnabled public Decimal nextInstallmentAmount = 0;
        @AuraEnabled public Decimal paidPercentage = 0;
        @AuraEnabled public Integer installmentsNumber = 0;
        @AuraEnabled public Decimal totalpaidCollectedAmount =0;
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
        @AuraEnabled public String SPAURL;
        @AuraEnabled public String DisplayImageName;
        @AuraEnabled public SalesOrderInstallmentSummary installmentSummary;
        
        public SalesOrderWrapper(
            SalesOrder__c so,
            Map<Id, String> phaseDescMap,
            SalesOrderInstallmentSummary summary,
            String imageUrl
        ) {
            Boolean useOption = (so.UnitOption__c != null);
            Decimal area = null;
            //4.0 Add 
                 area= (so.Unit__r != null && so.Unit__r.PlotAreasqm__c != null) ? so.Unit__r.PlotAreasqm__c : so.Unit__r.TotalArea__c;
            
            this.Id = so.Id;
            this.SoId = so.Name;
            this.ProjectName = so.ProjectName__c;
            this.UnitClass = useOption ? so.UnitOption__r.Typology__c : (so.Unit__r != null ? so.Unit__r.UnitClassification__c : null);
                this.UnitName = so.Unit__r.Name;
            this.UnitNumber = so.Unit__r.PlotNo__c;
            this.UnitType = useOption ? so.UnitOption__r.Type__c : (so.Unit__r != null ? so.Unit__r.Type__c : null);
                this.NoofBedrooms = useOption ? String.valueOf(so.UnitOption__r.NumberofBedrooms__c)
                : (so.Unit__r != null ? so.Unit__r.Number_of_Bedrooms__c : null);
                    this.NoofBathroom = (so.Unit__r != null) ? String.valueOf(so.Unit__r.Numberofbathroom__c) : null;
            this.NoofCars = useOption ? String.valueOf(so.UnitOption__r.NumberofCarParks__c)
                : (so.Unit__r != null ? String.valueOf(so.Unit__r.NumberofCarParks__c) : null);
                    this.TotalArea = useOption ? so.UnitOption__r.PlotAreasqm__c : area;
            this.TotalAmount = so.TotalAmount__c;
            this.PaymentPlan = so.PaymentPlanStructure__c;
            this.Noofbalcony =  useOption ? '' : (so.Unit__r != null ? String.valueOf(so.Unit__r.Numberofbalcony__c) : null);
                if(useOption == true){ //5.0 Option logic
                    this.TotalGrossArea = useOption && so.UnitOption__r.TotalGrossSellableAreaGSA__c !=null ? so.UnitOption__r.TotalGrossSellableAreaGSA__c : so.UnitOption__r.GrossFloorAreaGFA__c;
                }else{
                   this.TotalGrossArea = so.Unit__r.TotalGrossSellableAreaGSA__c != null ? so.Unit__r.TotalGrossSellableAreaGSA__c : so.Unit__r.GrossFloorAreaGFA__c;
                }
                 
            this.Phasedescription = (so.Unit__r != null && so.Unit__r.Phase__c != null) ? phaseDescMap.get(so.Unit__r.Phase__c) : null;
            this.isSPADisable = (so.Documents__r != null && !so.Documents__r.isEmpty()) ? false : true;
            this.FloorPlanId = useOption ? so.UnitOption__r.Unit__c : so.Unit__c;
            this.ImageUrl = imageUrl;
            this.installmentSummary = (summary != null) ? summary : new SalesOrderInstallmentSummary();
            this.DisplayImageName = so.Image_Name_pc__c;
            this.SPAURL = so.SPAPublicUrl__c;
        }
    }
    
    // =============== Other APIs (unchanged) ===============
    /**
 * Returns Floor Plan public URL for the given Sales Order
 * Used by Community UI to display floor plan document
 * 
 */
    @AuraEnabled(cacheable=true)
    public static String getFloorPlan(String recordId) {
        List<SalesOrder__c> soList = [
            SELECT Id, Unit__c, FloorPlanPublicURL__c FROM SalesOrder__c WHERE Id = :recordId LIMIT 1
        ];
        if (soList.isEmpty()) {
            throw new AuraHandledException('Sales Order not found');
        }
        return soList[0].FloorPlanPublicURL__c;
    }
    /**
 * Returns SPA (Sales & Purchase Agreement) public URL
 * Used by Community UI to view signed SPA document
 * **/
    @AuraEnabled(cacheable=true)
    public static String getSPA(String recordId) {
        List<SalesOrder__c> soList = [
            SELECT Id, Unit__c, SPAPublicUrl__c FROM SalesOrder__c WHERE Id = :recordId LIMIT 1
        ];
        if (soList.isEmpty()) {
            throw new AuraHandledException('Sales Order not found');
        }
        return soList[0].SPAPublicUrl__c;
    }
    /**
 * Generates PDF for the given Sales Order
 * Returns Base64 encoded PDF content
 *
 */
    @AuraEnabled
    public static String getPDF(String recId) {
        String b64code = EncodingUtil.base64Encode(navigate(recId));
        return b64code;
    }
    public static Blob navigate(String recordId) {
        PageReference pg = new PageReference('/apex/SOA3');
        pg.getParameters().put('id', recordId);
        return pg.getContentAsPDF();
    }
    /**
 * Returns gallery image URLs for a Unit
 * Used to display unit images in Community
 * 
 */
    @AuraEnabled(cacheable=true)
    public static List<String> getImageUrls(Id unitId) {
        List<String> imageUrls = new List<String>();
        for (Attachment att : [
            SELECT Id, Name
            FROM Attachment
            WHERE ParentId = :unitId
            AND Name LIKE '%gallery%'
        ]) {
            imageUrls.add('/servlet/servlet.FileDownload?file=' + att.Id);
        }
        return imageUrls;
    }
    /**
 * Fetches portal notifications for the current month
 * Used for Community notification section
 * 
 */
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
    /**
 * Wrapper class for portal notifications
 * 
 */
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
    /**
 * Makes external callout to DPG API to retrieve URL
 * Credentials are stored in Custom Metadata
 * 
 */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> makeCallout(String param1, String param2) {
        Map<String, String> result = new Map<String, String>();
        try {
            OIC_Credential__mdt config ;
            if(!test.isRunningTest()){
                config = [
                    SELECT Endpoint__c, Username__c, Password__c, Method__c
                    FROM OIC_Credential__mdt
                    WHERE DeveloperName = 'ModonCustomerDPGAPI'
                    LIMIT 1
                ];
            }
            String encodedProject = EncodingUtil.urlEncode('hudayriyat', 'UTF-8').replace('+', '%20');
            String encodedUnit = EncodingUtil.urlEncode(param2, 'UTF-8').replace('+', '%20');
            String endpoint = config.Endpoint__c + 'project=' + encodedProject + '&unit=' + encodedUnit;
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod(config.Method__c);
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
    /**
 * Utility method to split comma-separated custom label values
 * Used for project and status filtering
 *
 */
    public static List<String> getfilters(string customlablename) {
        String labelValue = customlablename;
        
        List<String> filterString = new List<String>();
        if (String.isNotBlank(labelValue)) {
            if (labelValue.contains(',')) {
                // Split by comma and trim spaces
                for (String s : labelValue.split(',')) {
                    filterString.add(s.trim());
                }
            } else {
                // No comma, just single value
                filterString.add(labelValue.trim());
            }
        }
        return filterString;
    }
}