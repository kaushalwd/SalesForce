public class ManageChequesController {
    
    public Final Static Set<String> SO_STATUS = new Set<String> {'Completed', 'Cancelled', 'Cancelled SR', 'Voided'};
    public Final Static Set<String> SOI_STATUS = new Set<String> {'Not Paid', 'Partially Paid'}; 
    public Final static Set<String> INVOICE_STATUS = new Set<String> { 'Generated', 'Partially Paid'}; 
    public Static SalesOrder__c thisSo = new SalesOrder__c();
                
        //method to get projects
        @AuraEnabled
        public static List<Project__c> getAllProjects(){
            try{
                return [SELECT Id,Name, (SELECT Id,Name, Project__c FROM BuildingsSections__r) from Project__c WITH SECURITY_ENFORCED ORDER BY Name ];
            }catch (Exception e) {
                throw new AuraHandledException(e.getMessage());
            }   
        }
    
    @AuraEnabled 
    public static Integer getChequesCount(String recordId) {
        try {
            system.debug('recordId.....'+ recordId);
            if(recordId == null || recordId == '') {
                return [SELECT Count() from Cheque_Details__c WHERE Status__c != 'Processed'];
            } else {
                SalesOrder__c thisOrder = getSalesOrder(recordId);
                if(thisOrder == null) {
                    throw new AuraHandledException('You cannot add cheques for this SalesOrder');
                }
                
                return [SELECT Count() from Cheque_Details__c WHERE Status__c != 'Processed' AND  Unit__c =: thisOrder.Unit__c];
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static boolean showChequeDetails( string recordId){
        try {
            SalesOrder__c thisOrder = getSalesOrder(recordId);
            return true;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    @AuraEnabled
    public static List<ChequeWrapper> getChequeWrappers(String offsetValue, String pageSize, String recordId) {
        List<ChequeWrapper> chequeWrappers = new List<ChequeWrapper>();
        Integer offset = (offsetValue == null || offsetValue == '') ? 0 : Integer.valueOf(offsetValue);
        Integer limitSize = (pageSize == null || pageSize == '') ? 10 : Integer.valueOf(pageSize);
        system.debug('offsetValue....'+offsetValue);
        system.debug('pageSize....'+pageSize);
        
        String query;  
        system.debug('recordId.....'+recordId);
        // SOQL injection fix: pagination and unit filter bound via queryWithBinds.
        Map<String, Object> chequeBinds = new Map<String, Object>{
            'limitSize' => limitSize,
            'offset' => offset
        };
        if(recordId == null || recordId == '') {
            query = 'SELECT ' + Utility.getAllFields('Cheque_Details__c') + ' ,Sales_Order__r.Name, Sales_Order__r.ClientName__c,  Sales_Order__r.CustomerAccount__c, Sales_Order_Installment__r.Name, Sales_Order_Installment__r.PaymentStatus__c FROM Cheque_Details__c '; 
            query += ' WHERE Status__c != \'Processed\' ORDER BY Id ASC LIMIT :limitSize OFFSET :offset';
        } else {
            thisSo = getSalesOrder(recordId);
            system.debug('thisOrder....' + thisSo.Unit__c);
            Id unitVal = thisSo.Unit__c;
            chequeBinds.put('unitVal', unitVal);
            query = 'SELECT ' + Utility.getAllFields('Cheque_Details__c') + ' ,Sales_Order__r.Name, Sales_Order__r.ClientName__c,  Sales_Order__r.CustomerAccount__c, Sales_Order_Installment__r.Name, Sales_Order_Installment__r.PaymentStatus__c FROM Cheque_Details__c '; 
            query += ' WHERE Status__c != \'Processed\' AND Unit__c = :unitVal ORDER BY Id ASC LIMIT :limitSize OFFSET :offset';
        }
        
        List<Cheque_Details__c> chequeDetails = (List<Cheque_Details__c>) Database.queryWithBinds(query, chequeBinds, AccessLevel.SYSTEM_MODE);
        Set<Id> unitIds = new Set<Id>();
        
        if(chequeDetails.size() > 0 ) {
            for(Cheque_Details__c thisCd : chequeDetails) { 
                if(thisCd.Unit__c != null) {
                    unitIds.add(thisCd.Unit__c);
                    system.debug('units....'+thisCd.Unit__c);
                }
            }
        } /** else if(recordId != null && recordId != '') {
            query = 'SELECT ' + Utility.getAllFields('Cheque_Details__c') + ' ,Sales_Order__r.Name, Sales_Order__r.ClientName__c,  Sales_Order__r.CustomerAccount__c, Sales_Order_Installment__r.Name, Sales_Order_Installment__r.PaymentStatus__c FROM Cheque_Details__c '; 
            query += ' WHERE Status__c != \'Processed\'    ORDER BY Id ASC LIMIT '+pageSize+' OFFSET '+offset;
            chequeDetails = Database.query(query);
            if(thisSo.Unit__c != null) {
                unitIds.add(thisSo.Unit__c);
            }           
        } **/  
        
      //  if(!unitIds.isEmpty()) {
            chequeWrappers = getWrappers(unitIds, chequeDetails, chequeWrappers, recordId);
      //  }
        return chequeWrappers;
    }
    
    public static SalesOrder__c getSalesOrder(String recordId) {
        try {
            SalesOrder__c thisOrder = [SELECT Id, Unit__c FROM SalesOrder__c WHERE Id =:recordId AND Status__c NOT IN :SO_STATUS LIMIT 1];
            return thisOrder;
        } catch(Exception ex) {
            throw new AuraHandledException('You cannot add cheques for this SalesOrder');
        }
    }   
    
    
    public static List<chequeWrapper> getWrappers(Set<Id> unitIds, List<Cheque_Details__c> chequeDetails, List<chequeWrapper> wrapper, String recordId) {
        if(!chequeDetails.isEmpty()) {
            Set<Id> soiIds = new Set<Id> ();
            Set<Id> soIds = new Set<Id> ();
            Map<Id, Invoice__c>  soiByInvoice;
            Map<Id, Map<SalesOrder__c, List<SalesOrderInstallments__c>>> unitToSoliMap = unitIds.isEmpty() ? new Map<Id, Map<SalesOrder__c, List<SalesOrderInstallments__c>>>() : getUnitToSoliMap(unitIds, soiIds, soIds, recordId);

            if(!(soiIds.isEmpty() && soIds.isEmpty())) {
                soiByInvoice = getSoiByInvoice(soiIds, soIds);
                system.debug(soiByInvoice);
            }
            
            for(Cheque_Details__c thisCd : chequeDetails) {
                Map<SalesOrder__c, List<SalesOrderInstallments__c> > mapSoli = unitToSoliMap.containsKey(thisCd.Unit__c) ? unitToSoliMap.get(thisCd.Unit__c) : new  Map<SalesOrder__c, List<SalesOrderInstallments__c> >();
                SalesOrder__c thisOrder;
                if(mapSoli != null &&  !mapSoli.isEmpty()) {
                    List<SalesOrder__c> salesOrders = new List<SalesOrder__c>();
                    salesOrders.addAll(mapSoli.keySet());
                    thisOrder = salesOrders[0];
                }
                SalesOrderInstallments__c installments = (thisCd.MileStoneNumber__c != 'ADM' && thisCd.MileStoneNumber__c != null &&  thisOrder!= null) ? getSOIfromMileStone(thisCd.MileStoneNumber__c, mapSoli.get(thisOrder)) : null;
                ChequeWrapper chequeWrapper = new ChequeWrapper();
                chequeWrapper.Id  = thisCd.Id;
                chequeWrapper.link  = '/'+ thisCd.Id;
                chequeWrapper.chequeNumber = thisCd.Cheque_No__c;   
                chequeWrapper.amount = thisCd.Amount__c;  
                chequeWrapper.chequeDate  = thisCd.Cheque_Date__c;  
                chequeWrapper.mileStone = thisCd.MileStoneNumber__c;  
                chequeWrapper.bankName = thisCd.Bank__c;  
                chequeWrapper.chequeIssuer = thisCd.Cheque_Issuer__c;  
                chequeWrapper.accountNumber = thisCd.Account_Number__c;
                chequeWrapper.salesOrderName = thisCd.Sales_Order__c == null ? (thisOrder != null ? thisOrder.Name : '') : thisCd.Sales_Order__r.Name;
                chequeWrapper.salesOrderInstallmentName = thisCd.Sales_Order_Installment__c == null ? (installments != null ? installments.Name : '') : thisCd.Sales_Order_Installment__r.Name;
                chequeWrapper.unitName = thisCd.UnitName__c;
                chequeWrapper.salesOrderLink = thisCd.Sales_Order__c == null ? (thisOrder != null ? '/'+ thisOrder.Id : null) : '/'+ thisCd.Sales_Order__r.Id;
                system.debug(thisOrder);
                system.debug(thisCd);
                chequeWrapper.unit = thisCd.Unit__c == null ? (thisOrder != null && thisOrder.Unit__c != null ? thisOrder.Unit__c : null) : thisCd.Unit__c;
                chequeWrapper.iBAN = thisCd.IBAN_No__c;
                chequeWrapper.status = thisCd.Sales_Order_Installment__c == null ?  (installments != null ? installments.PaymentStatus__c : '') :thisCd.Sales_Order_Installment__r.PaymentStatus__c;
                chequeWrapper.isSelected =  thisCd.Status__c == 'Pending' ? true : false;
                chequeWrapper.salesOrderId = thisCd.Sales_Order__r.Id == null ? (thisOrder != null ? thisOrder.Id : null) : + thisCd.Sales_Order__r.Id;
                chequeWrapper.salesOrderInstallmentId = thisCd.Sales_Order_Installment__c == null ? (installments != null ?  installments.Id : null) :  thisCd.Sales_Order_Installment__r.Id;
                chequeWrapper.soiLink = thisCd.Sales_Order_Installment__c == null ? (installments != null ? '/'+ installments.Id : '') : '/'+ thisCd.Sales_Order_Installment__r.Id;
                chequeWrapper.customerName = thisCd.Sales_Order__c == null ?  (thisOrder != null ? thisOrder.ClientName__c : '' ) : thisCd.Sales_Order__r.ClientName__c; 
                chequeWrapper.customerId =  thisCd.Sales_Order__c == null ?  (thisOrder != null ? thisOrder.CustomerAccount__c : null ) :  thisCd.Sales_Order__r.CustomerAccount__c; 
                chequeWrapper.customerLink = thisCd.Sales_Order__c == null ?  (thisOrder != null ? '/'+ thisOrder.CustomerAccount__c : null ) : '/'+ thisCd.Sales_Order__r.CustomerAccount__c;
                if(thisCd.MileStoneNumber__c != null && thisCd.MileStoneNumber__c == 'ADM' && chequeWrapper.salesOrderId != null)  {
                    system.debug('salesORder....'+ chequeWrapper.salesOrderId);
                    chequeWrapper.invoiceId =  (soiByInvoice.containsKey(chequeWrapper.salesOrderId)) ? soiByInvoice.get(chequeWrapper.salesOrderId).Id : null;
                    chequeWrapper.chargeId =  chequeWrapper.invoiceId != null ? soiByInvoice.get(chequeWrapper.salesOrderId).Charge__c : null;
                } else {
                    system.debug('soiByInvoice'+ soiByInvoice);
                    system.debug('chequeWrapper'+ chequeWrapper.salesOrderInstallmentId);
                    chequeWrapper.invoiceId = (chequeWrapper.salesOrderInstallmentId != null && chequeWrapper.salesOrderInstallmentId != '')  ? 
                       ((soiByInvoice!= null && !soiByInvoice.isEmpty() && soiByInvoice.containsKey(chequeWrapper.salesOrderInstallmentId))? soiByInvoice.get(chequeWrapper.salesOrderInstallmentId).Id : null) : null;
                }
                List<Map<String, String>> options = new List<Map<String, String>>();
                Map<Id, Invoice__c> soiByInvoices = new Map<Id, Invoice__c>();
                system.debug(thisCd.Unit__c +'mileStone'+ unitToSoliMap);
                system.debug(thisCd.Unit__c +'mileStone'+ thisCd.MileStoneNumber__c);
                if((thisCd.MileStoneNumber__c == null || thisCd.MileStoneNumber__c == '') && thisCd.Unit__c != null) {
                    Map<SalesOrder__c, List<SalesOrderInstallments__c>> soBySoi;
                    if(thisSo.Unit__c != null ) {
                    	soBySoi = unitToSoliMap.get(thisSo.Unit__c);    
                    } else if(thisCd.Unit__c != null && thisCd.Sales_Order__c != null) {
                        soBySoi = unitToSoliMap.get(thisCd.Unit__c);
                    }  
                    List<SalesOrderInstallments__c> sois;
                    system.debug('soBySoi...'+soBySoi);
                    if(soBySoi != null && !soBySoi.isEmpty()) {
                          for(SalesOrder__c thisSos : soBySoi.keySet()) {
                            if(thisSos.Id == thisSo.Id || thisSos.Id == thisCd.Sales_Order__c) {
                                sois = soBySoi.get(thisSos);
                            }
                        }
                    }

                    if(sois != null && !sois.isEmpty()) {
                        for(SalesOrderInstallments__c thisSoi : sois) {
                            Map<String, String> option = new Map<String, String>();
                            system.debug('thisSoi...'+ thisSoi);
                            option = new Map<String, String>();
                            option.put('label', thisSoi.MileStoneNumber__c != null ? String.valueOf(thisSoi.MileStoneNumber__c) : '');
                            option.put('value', thisSoi.Id);
                            options.add(option);
                            Invoice__c thisInvoice =  soiByInvoice.containsKey(thisSoi.Id) ? soiByInvoice.get(thisSoi.Id) : new Invoice__c();
                            soiByInvoices.put(thisSoi.Id, thisInvoice);
                    	}
                    }
                    if(soiByInvoice.containsKey(thisSo.Id)) {
                        Map<String, String> option = new Map<String, String>();
                       	option.put('label', 'ADM');
                    	option.put('value', thisSo.Id);
                    	options.add(option);
                        Invoice__c thisInvoice =  soiByInvoice.containsKey(thisSo.Id) ? soiByInvoice.get(thisSo.Id) : new Invoice__c();
                        soiByInvoices.put(thisSo.Id, thisInvoice);
                    }
                    system.debug(options);
                } else {
                    if(thisCd.MileStoneNumber__c == 'ADM') {
                        Map<String, String> option = new Map<String, String>();
                        option.put('label', 'ADM');
                        option.put('value', chequeWrapper.salesOrderId);
                        options.add(option);
                        String soId = (chequeWrapper.salesOrderId != null && chequeWrapper.salesOrderId != '')  ? chequeWrapper.salesOrderId : null;
                        chequeWrapper.balanceAmount =  (soId != null && soiByInvoice.containsKey(soId)) ? soiByInvoice.get(soId).InvoiceBalance__c : 0 ;
                        if(soId != null) {
                            soiByInvoices.put(soId, soiByInvoice.get(soId));
                        }
                        
                    } else {
                        Map<String, String> option = new Map<String, String>();
                        option.put('label', thisCd.MileStoneNumber__c);
                        option.put('value', chequeWrapper.salesOrderInstallmentId);
                        options.add(option);
                        String soiId = (chequeWrapper.salesOrderInstallmentId != null && chequeWrapper.salesOrderInstallmentId != '')  ? chequeWrapper.salesOrderInstallmentId : null;
                        chequeWrapper.balanceAmount =  soiByInvoice != null && soiId != null && soiByInvoice.containsKey(soiId) ? soiByInvoice.get(soiId).InvoiceBalance__c : 0 ;
                        if(soiId != null && soiByInvoice != null) {
                            soiByInvoices.put(soiId, soiByInvoice.get(soiId));
                        }
                    }
                }
                chequeWrapper.soiOptions = options;
                chequeWrapper.soiInvoice = soiByInvoices;
                wrapper.add(chequeWrapper);
            }
        }
        return wrapper;
    }
    
    public static Map<Id, Invoice__c> getSoiByInvoice(Set<Id> soiIds, Set<Id> soIds) {
        Map<Id, Invoice__c> soiByInvoice = new Map<Id, Invoice__c>();
        system.debug('soIds'+ soIds);
        for(Invoice__c thisInvoice : [SELECT Id, Sales_Order__c, Is_ADM_Fees_and_Dari_charges__c, InvoiceStatus__c, Charge__c, SalesOrderInstallment__c, InvoiceBalance__c, InvoiceDate__c FROM Invoice__c 
                                      WHERE (SalesOrderInstallment__c IN: soiIds OR Sales_Order__c IN : soIds) AND InvoiceStatus__c IN: INVOICE_STATUS ORDER BY InvoiceDate__c DESC]) {
                                          system.debug('thisInvoice'+ thisInvoice);
                                          if(thisInvoice.Is_ADM_Fees_and_Dari_charges__c){
                                              soiByInvoice.put(thisInvoice.Sales_Order__c, thisInvoice);
                                          } else {
                                              soiByInvoice.put(thisInvoice.SalesOrderInstallment__c, thisInvoice);
                                          }
                                      }
        return soiByInvoice;
    }
    
    public static SalesOrderInstallments__c getSOIfromMileStone(String mileStone, List<SalesOrderInstallments__c> soliList) {
        try{
            Integer mileStoneNumber = mileStone == 'ADM' ? null : Integer.valueOf(mileStone);
            for(SalesOrderInstallments__c soli : soliList) {
                if(soli.MileStoneNumber__c == mileStoneNumber) {
                    return soli;
                }
            }
        } catch(Exception e) {
            System.debug('Exception :' + e.getMessage());
        }
      
        return null;
    }
    @AuraEnabled 
    public static List<ChequeWrapper> getUnitData(String projectName,  String phaseId, String unitSearchKey, Date startDate, Date endDate, String customerSearchKey, String chequeNoSearchKey, String payeeSearchKey) {
        system.debug('unitSearchKey'+ unitSearchKey);
        system.debug('projectName'+ projectName);
        system.debug('startDate'+ startDate);
        system.debug('phaseId'+ phaseId);
        List<ChequeWrapper> wrappers = new List<ChequeWrapper>();
        // String query = 'SELECT ' + Utility.getAllFields('Unit__c') + ' FROM Unit__c ';
        String query = 'SELECT id FROM Unit__c WHERE ';
        system.debug(query);
        // SOQL injection fix: LWC search/filter values bound via queryWithBinds.
        Map<String, Object> unitBinds = new Map<String, Object>();
        if( projectName != 'All' && projectName != '' && projectName != null) {        
            query +=' Phase__r.Project__c = :projectName ';
            unitBinds.put('projectName', projectName);
            system.debug(query);
           	if(phaseId != null && phaseId != '' && phaseId !='All' ){
            	query +='  AND Phase__c = :phaseId ';
                unitBinds.put('phaseId', phaseId);
            	system.debug(query);
        	}
        } else if(projectName == 'All' ) {
            if(phaseId != null && phaseId != '' && phaseId !='All' ){
                query +=' Phase__c = :phaseId ';
                unitBinds.put('phaseId', phaseId);
                system.debug(query);
            } else {
                query +=' Phase__r.Project__c != null ';
            }
        }
       
        query += ' AND Status__c != \'Available\' ';
        system.debug(query);
         system.debug('unitSearchKey'+ unitSearchKey);
        
        String unitSearchPattern = String.isNotBlank(unitSearchKey) ? unitSearchKey + '%' : null;
        if(unitSearchPattern != null) {
            query += ' AND Name LIKE :unitSearchPattern'; 
            unitBinds.put('unitSearchPattern', unitSearchPattern);
        }
        Set<Id> unitIds = new Set<Id>();
        system.debug(query);
        for(Unit__c thisUnit : (List<Unit__c>) Database.queryWithBinds(query, unitBinds, AccessLevel.SYSTEM_MODE)) {
            unitIds.add(thisUnit.Id);
        }
        
        if(!unitIds.isEmpty()) {
            query = 'SELECT ' + Utility.getAllFields('Cheque_Details__c') + ',Sales_Order__r.Name, Sales_Order__r.ClientName__c,  Sales_Order__r.CustomerAccount__c, Sales_Order_Installment__r.Name, Sales_Order_Installment__r.PaymentStatus__c FROM Cheque_Details__c '; 
            query += ' WHERE Status__c != \'Processed\'  AND Unit__c IN: unitIds';
            Map<String, Object> detailBinds = new Map<String, Object>{
                'unitIds' => unitIds
            };
            if(startDate != null) {
                query += ' AND Cheque_Date__c >= :startDate ';
                detailBinds.put('startDate', startDate);
            }
            if(endDate != null) {
                query += ' AND Cheque_Date__c <= :endDate';
                detailBinds.put('endDate', endDate);
            }
            String custSearchPattern = (customerSearchKey != null && customerSearchKey != '') ? customerSearchKey + '%' : null;
            if(custSearchPattern != null) {
                query += ' AND Sales_Order__r.ClientName__c LIKE :custSearchPattern';
                detailBinds.put('custSearchPattern', custSearchPattern);
            }
            String chequeNoPattern = (chequeNoSearchKey != null && chequeNoSearchKey != '') ? chequeNoSearchKey + '%' : null;
            if(chequeNoPattern != null) {
                query += ' AND Cheque_No__c LIKE :chequeNoPattern';
                detailBinds.put('chequeNoPattern', chequeNoPattern);
            }
            String payeePattern = (payeeSearchKey != null && payeeSearchKey != '') ? payeeSearchKey + '%' : null;
            if(payeePattern != null) {
                query += ' AND Payee__c LIKE :payeePattern';
                detailBinds.put('payeePattern', payeePattern);
            }
            List<Cheque_Details__c> details = (List<Cheque_Details__c>) Database.queryWithBinds(query, detailBinds, AccessLevel.SYSTEM_MODE);
            system.debug('details'+ details);
            wrappers = getWrappers(unitIds, details, wrappers, null);
        }
        return wrappers;
    }

    public static Map<Id, Map<SalesOrder__c, List<SalesOrderInstallments__c>>>  getUnitToSoliMap(Set<Id> unitIds, Set<Id> soiIds, Set<Id> soIds, String recordId) {
        Map<Id, Map<SalesOrder__c, List<SalesOrderInstallments__c>>> unitToSoliMap = new Map<Id, Map<SalesOrder__c, List<SalesOrderInstallments__c>>>();
        if(!unitIds.isEmpty()) {
            String querySI = 'SELECT ' + Utility.getAllFields('SalesOrderInstallments__c') + ' FROM Sales_Order_Installments__r WHERE PaymentStatus__c IN: SOI_STATUS';           
            String query =  'SELECT ClientName__c, Id, Name, CustomerAccount__c, Unit__c , ('+ querySI +' )  FROM SalesOrder__c  WHERE Unit__c IN :unitIds AND Status__c NOT IN:SO_STATUS'; 
            // SOQL injection fix: unit/record filters bound via queryWithBinds.
            Map<String, Object> soBinds = new Map<String, Object>{
                'SOI_STATUS' => SOI_STATUS,
                'unitIds' => unitIds,
                'SO_STATUS' => SO_STATUS
            };
            if(recordId != null && recordId != '') {
                query += ' AND Id=:recordId';
                soBinds.put('recordId', recordId);
            }
            Map<Id, SalesOrder__c>  salesOrders = new Map<Id, SalesOrder__c> ();
            for(SalesOrder__c thisOrder : (List<SalesOrder__c>) Database.queryWithBinds(query, soBinds, AccessLevel.SYSTEM_MODE)) {
                system.debug(thisORder);
                system.debug(thisOrder.Sales_Order_Installments__r);
                soIds.add(thisOrder.Id);
                salesOrders.put(thisOrder.Id, thisOrder);                
            }
            
            
            Map<Id, SalesOrder__c> unitBySalesOrder = new Map<Id, SalesOrder__c>();
            Map<Id, List<SalesOrderInstallments__c>> SOListBySOId = new Map<Id, List<SalesOrderInstallments__c>>();
            if(salesOrders.size() > 0 ) {               
                for(SalesOrder__c   thisSo : salesOrders.values()) {  
                    if(!unitBySalesOrder.containsKey(thisSo.Unit__c)) {
                        unitBySalesOrder.put(thisSo.Unit__c, thisSo);
                    }
                    if(!SOListBySOId.containsKey(thisSo.Id)) {
                        List<SalesOrderInstallments__c> soIs = new List<SalesOrderInstallments__c>();
                        for(SalesOrderInstallments__c thisInstallment : thisSo.Sales_Order_Installments__r) {
                            soIs.add(thisInstallment);
                            soiIds.add(thisInstallment.Id);
                        }
                        SOListBySOId.put(thisSo.Id, soIs); 
                    }                        
                }
                for(Id thisUnitId : unitBySalesOrder.keySet()) {
                    if(!unitToSoliMap.containsKey(thisUnitId)) {
                        unitToSoliMap.put(thisUnitId, new Map<SalesOrder__c, List<SalesOrderInstallments__c>>());
                    }
                    if(SOListBySOId.containsKey(unitBySalesOrder.get(thisUnitId).Id)) {
                        unitToSoliMap.get(thisUnitId).put(unitBySalesOrder.get(thisUnitId), SOListBySOId.get(unitBySalesOrder.get(thisUnitId).Id));
                    } else {
                        unitToSoliMap.get(thisUnitId).put(unitBySalesOrder.get(thisUnitId), new List<SalesOrderInstallments__c>());
                    }
                }                                
                return unitToSoliMap;
            } 
        }
        return unitToSoliMap;
    }
    
    public class ChequeWrapper {
        @AuraEnabled public Id Id {get; set;}
        @AuraEnabled public  String  chequeNumber {get; set;}
        @AuraEnabled public  String  link {get; set;}
        @AuraEnabled public Date chequeDate {get; set;} 
        @AuraEnabled public Decimal amount {get; set;}
        @AuraEnabled public String bankName {get; set;} 
        @AuraEnabled public String chequeIssuer {get; set;} 
        @AuraEnabled public String accountNumber {get; set;}
        @AuraEnabled public String salesOrderName {get; set;}
        @AuraEnabled public String salesOrderId {get; set;} 
        @AuraEnabled public String mileStone {get; set;} 
        @AuraEnabled public String salesOrderInstallmentId {get; set;}
        @AuraEnabled public String salesOrderInstallmentName {get; set;}
        @AuraEnabled public String status   {get; set;} 
        @AuraEnabled public String customerName {get; set;}
        @AuraEnabled public String customerId   {get; set;}
        @AuraEnabled public Boolean isSelected   {get; set;}
        @AuraEnabled public String unitName{get; set;}
        @AuraEnabled public String unit{get; set;}
        @AuraEnabled public Decimal balanceAmount {get; set;}
        @AuraEnabled public String action {get;set;}
        @AuraEnabled public String invoiceId {get; set;}  
        @AuraEnabled public String iBAN {get; set;}
        @AuraEnabled public String soiLink {get; set;}  
        @AuraEnabled public String customerLink {get; set;}
        @AuraEnabled public String salesOrderLink {get; set;}
        @AuraEnabled public List<Map<String, String>> soiOptions {get; set;}
        @AuraEnabled public Map<Id, Invoice__c> soiInvoice {set;get;}
        @AuraEnabled public String chargeId {set;get;}
    }
    
  
    
    @AuraEnabled
    public static List<Map<String,string>> getAllBuildings(){
        List<Map<String,string>> filtersToReturn = new List<Map<String,string>>();
        Map<string,string> tempMap=new Map<string,string>();  
        tempMap.put('label', 'All');  
        tempMap.put('value', 'All');
        try {
            for(Phase__c  thisBuilding: [Select Id,Name from Phase__c order by Name] ){            
                tempMap.put('label',thisBuilding.Name);
                tempMap.put('value',thisBuilding.id);
                filtersToReturn.add(tempMap);
            }
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return null;
    }
    
    
    @AuraEnabled 
    public static List<SalesOrder__c> getAllSalesOrders(String projectName, String phaseName, String unitId) {
        String query = 'SELECT ' + Utility.getAllFields('SalesOrder__c') + ' FROM SalesOrder__c WHERE  Status__c !=\'Cancelled\' AND  Status__c != \'Closed\'';        
        // SOQL injection fix: optional filters bound via queryWithBinds.
        Map<String, Object> soBinds = new Map<String, Object>();
        if(phaseName != null && phaseName != '') {
            query += ' AND Phase_Name__c =:phaseName';
            soBinds.put('phaseName', phaseName);
        }
        if(projectName != null &&  projectName != '') {
            query += ' AND ProjectName__c =:projectName';
            soBinds.put('projectName', projectName);
        }
        if(unitId != null &&  unitId != '') {
            query += ' AND Unit__c =:unitId';
            soBinds.put('unitId', unitId);
        }
        
        query += ' ORDER BY CreatedDate DESC LIMIT 9999';
        return (List<SalesOrder__c>) Database.queryWithBinds(query, soBinds, AccessLevel.SYSTEM_MODE);
    }
    
    @AuraEnabled
    public static void unSelectCheque(ChequeWrapper thisWrapper) {
        if(thisWrapper != null ) {
            Cheque_Details__c thisDetails = new Cheque_Details__c ();
            thisDetails.Id = thisWrapper.Id;
            thisDetails.Status__c = 'New';
            DataBase.SaveResult results = DataBase.update(thisDetails, false);
        } 
    }
    
    @AuraEnabled
    public static List<Map<String, string>> saveChequeDetails(List<ChequeWrapper> wrappers, String action) {
        if(wrappers != null && !wrappers.isEmpty()) {
            List<Map<String, string>> chequeIdByMessage = new  List<Map<String, string>>();
            try {
                Map<Id, Cheque_Details__c> chequeMap = new Map<Id, Cheque_Details__c>();                
                Map<Id, Receipt__c> receipByChequetMap = new Map<Id, Receipt__c>();                
                Map<Id, Receipt__c> chequeByReceipt = new  Map<Id, Receipt__c>();
                Map<Id, String> chequeIdByError = new  Map<Id, String>();
                for(ChequeWrapper thisWrapper : wrappers) {
                    system.debug('wrapper'+ thisWrapper);
                   
                    Cheque_Details__c thisDetails = new Cheque_Details__c ();
                    thisDetails.Id = thisWrapper.Id;
                    thisDetails.Amount__c = thisWrapper.amount;
                    thisDetails.Status__c = action == 'save' ? 'Pending' : 'Processed';
                    thisDetails.Cheque_No__c = thisWrapper.chequeNumber;
                    thisDetails.Cheque_Date__c = thisWrapper.chequeDate;
                    thisDetails.MileStoneNumber__c = thisWrapper.mileStone;
                    thisDetails.Bank__c = thisWrapper.bankName;
                    thisDetails.Cheque_Issuer__c= thisWrapper.chequeIssuer ;
                    thisDetails.Account_Number__c = thisWrapper.AccountNumber;
                    System.debug('unit...'+ thisWrapper.Unit);
                    thisDetails.Unit__c = thisWrapper.Unit;
                    if(thisDetails.MileStoneNumber__c != 'ADM') { 
                        thisDetails.Sales_Order_Installment__c = (thisWrapper.salesOrderInstallmentId != null && thisWrapper.salesOrderInstallmentId !='') ?
                        thisWrapper.salesOrderInstallmentId : null; 
                    }
                    thisDetails.Sales_Order__c = (thisWrapper.salesOrderId != null && thisWrapper.salesOrderId != '') ? thisWrapper.salesOrderId : null;
                    
                    thisDetails.Invoice__c = thisWrapper.invoiceId;   
                    chequeMap.put(thisDetails.Id, thisDetails);
                    if(action == 'confirm' && thisWrapper.mileStone != null && thisWrapper.mileStone != '') {
                        Receipt__c thisReceipt = new Receipt__c();
                        thisReceipt.Account__c = thisWrapper.customerId != null ? thisWrapper.customerId : thisWrapper.customerId;
                        thisReceipt.BankName__c =  thisWrapper.bankName;
                        thisReceipt.ChequeDate__c = thisWrapper.chequeDate;
                        thisReceipt.Cheque_Number__c = thisWrapper.chequeNumber;
                        thisReceipt.Last4Digit__c = thisWrapper.iBAN != null ? Decimal.valueOf((thisWrapper.iBAN).right(4).trim()) : null;
                        thisReceipt.Modeofpayment__c = 'Cheque';
                        if( thisWrapper.mileStone == 'ADM') {
                            system.debug('from ADM' + thisWrapper.salesOrderId);
                            thisReceipt.SalesOrder__c = (thisWrapper.salesOrderId != null && thisWrapper.salesOrderId != '') ? thisWrapper.salesOrderId : null;
                        } else {
                            system.debug('from NON ADM' + thisWrapper.salesOrderId);
                            thisReceipt.SalesOrderInstallment__c =  (thisWrapper.salesOrderInstallmentId != null && thisWrapper.salesOrderInstallmentId !='')? thisWrapper.salesOrderInstallmentId : null;
                        }                        
                        thisReceipt.TotalAmount__c = thisWrapper.amount;
                        thisReceipt.Status__c = 'In Progress';
                        thisReceipt.Cheque_Details__c = thisWrapper.Id;
                        thisReceipt.Charge__c = thisWrapper.chargeId != null ? thisWrapper.chargeId : null;
                        //thisReceipt.SalesOrder__c = (thisWrapper.salesOrderId != null && thisWrapper.salesOrderId != '') ? thisWrapper.salesOrderId.subString(1) : null;
                        system.debug(thisReceipt);
                        receipByChequetMap.put(thisReceipt.Cheque_Details__c, thisReceipt);
                    }
                }

                if(!receipByChequetMap.isEmpty()) {
                    DataBase.SaveResult[] results = DataBase.insert(receipByChequetMap.values(), false);
                    Integer index = 0;
                    for(Database.saveResult thisResult: results ) {
                        if(!thisResult.isSuccess()) {
                            chequeIdByError.put(receipByChequetMap.values()[index].Cheque_Details__c, thisResult.getErrors()[0].getMessage());
                        } else {
                            chequeByReceipt.put(receipByChequetMap.values()[index].Cheque_Details__c, receipByChequetMap.values()[index]);
                        	index++;
                    	}
                	}
                }

                if(!chequeByReceipt.isEmpty()) {
                    List<ContentDocumentLink> links = new List<ContentDocumentLink>();
                    for(ContentDocumentLink thisLink : [SELECT Id, ContentDocumentId, LinkedEntityId, ShareType, Visibility FROM ContentDocumentLink  WHERE LinkedEntityId IN: chequeByReceipt.keyset()]) {
                        if(chequeByReceipt.containsKey(thisLink.LinkedEntityId)) {
                            ContentDocumentLink cloneLink = thisLink.Clone();
                            cloneLink.Id = null;
                            cloneLink.LinkedEntityId = chequeByReceipt.get(thisLink.LinkedEntityId).Id;
                            links.add(cloneLink);
                        }
                    }
                    if(!links.isEmpty()) {
                        system.debug('links'+ links);
                        Database.SaveResult[] results = Database.insert(links, false); 
                    }
                }

                if(!chequeMap.isEmpty()) {
                    List<Cheque_Details__c> chequeDetailsToUpdate = new List<Cheque_Details__c>();
                    for(Id thisId : chequeMap.keySet()) {   
                        Map<String, String> keyValue = new Map<String, String>();
                        if(action == 'confirm' ) { 
                            if(chequeIdByError.containsKey(thisId)) {
                                keyValue.put('key' ,chequeMap.get(thisId).Cheque_No__c);
                                keyValue.put('value', chequeIdByError.get(thisId));
                                keyValue.put('type', 'false');
                            }
                            if(chequeByReceipt.containsKey(thisId)) {
                                Cheque_Details__c thisCheque = chequeMap.get(thisId);
                                thisCheque.Status__c = 'Processed';
                                chequeDetailsToUpdate.add(thisCheque);
                                keyValue.put('key' ,chequeMap.get(thisId).Cheque_No__c);
                                keyValue.put('value', 'Payment Details are added successfully');
                                keyValue.put('type', 'true');
                            }
                            chequeIdByMessage.add(keyValue);
                        } else if(action != 'confirm'){
                            chequeDetailsToUpdate.add(chequeMap.get(thisId));
                        }
                    }
                    system.debug(chequeDetailsToUpdate+ 'chequeDetailsToUpdate');

                    if(!chequeDetailsToUpdate.isEmpty()) {
                        Database.SaveResult[] res = Database.update(chequeDetailsToUpdate, false);
                        if(!res.isEmpty() && action != 'confirm') {                            
                            for(Integer index = 0; index < res.size();  index++ ) {
                                system.debug(res[index]+'chequeIdByMessage' +chequeDetailsToUpdate[index].Cheque_No__c);
                                Map<String, String> keyValue = new Map<String, String>();
                                keyValue.put('key', chequeDetailsToUpdate[index].Cheque_No__c);
                                if(!res[index].isSuccess()) {
                                    keyValue.put('value', res[index].getErrors()[0].getMessage());
                                    keyValue.put('type', 'false');
                                } else {
                                    keyValue.put('value', 'Cheque Details are updated successfully');
                                    keyValue.put('type', 'true');
                                }
                                chequeIdByMessage.add(keyValue);
                            }
                            system.debug('chequeIdByMessage'+ chequeIdByMessage);
                        }
                    }                 
                }
            } catch (Exception ex) {
                Map<String, String> messages = new Map<String, String>();
                messages.put('type', 'false');
                messages.put('key', 'eroor');
                messages.put('value', ex.getMessage());
				
                    chequeIdByMessage.add(messages);
                //throw new AuraHandledException(ex.getMessage());
            }             
            return chequeIdByMessage;
        }
        return null;
    }
    
    @AuraEnabled 
    public static SalesOrderWrapper getSalesOrderWrapper(String unitId) {
        if(unitId != '' && unitId != null) {
            //String queryInvoice = 'SELECT ' + Utility.getAllFields('Invoice__c') + ' FROM Invoice__c WHERE SalesOrderInstallment__c IN: soiIds AND InvoiceStatus__c IN: INVOICE_STATUS';
            String queryCharge = 'SELECT ' + Utility.getAllFields('Charge__c') + ' FROM Charge__r  WHERE PaymentStatus__c IN: SOI_STATUS';
            String querySI = 'SELECT ' + Utility.getAllFields('SalesOrderInstallments__c') + ' FROM Sales_Order_Installments__r WHERE PaymentStatus__c IN: SOI_STATUS';           
            String query =  'SELECT ClientName__c, Id, Name, CustomerAccount__c, Unit__c , ('+ querySI +' ), ('+ queryCharge+')  FROM SalesOrder__c  WHERE Unit__c = :unitId AND Status__c NOT IN:SO_STATUS'; 
            Map<Id, SalesOrder__c>  salesOrders = new Map<Id, SalesOrder__c> ();
            SalesOrderWrapper thisWrapper = new SalesOrderWrapper();
            // SOQL injection fix: unit/status filters bound via queryWithBinds.
            List<SalesOrder__c> salesOrdersList = (List<SalesOrder__c>) Database.queryWithBinds(
                query,
                new Map<String, Object>{
                    'SOI_STATUS' => SOI_STATUS,
                    'unitId' => unitId,
                    'SO_STATUS' => SO_STATUS
                },
                AccessLevel.SYSTEM_MODE
            );
            Set<Id> soiIds = new Set<Id>();
            if(salesOrdersList.size() > 0) {
                thisWrapper.soName = salesOrdersList[0].Name;
                thisWrapper.soId = salesOrdersList[0].Id;
                thisWrapper.soLink = '/'+ salesOrdersList[0].Id;
                thisWrapper.soiOptions = new List<Map<String, String>>();
                for(SalesOrderInstallments__c  thisInstalment: salesOrdersList[0].Sales_Order_Installments__r) {
                    Map<String, String> options = new Map<String, String>();
                    options.put('label', String.valueOf(thisInstalment.MileStoneNumber__c));
                    options.put('value', thisInstalment.Id);
                    thisWrapper.soiOptions.add(options); 
                    soiIds.add(thisInstalment.Id);                  
                }
                system.debug('soiIds'+ soiIds);
                system.debug(salesOrdersList[0].Charge__r);
                charge__c thisCharge = salesOrdersList[0].Charge__r.size() > 0 ? salesOrdersList[0].Charge__r[0] : null;
                system.debug(salesOrdersList[0].Charge__r);
                Map<Id, Invoice__c> soiByInvoice = new Map<Id, Invoice__c>();
                Map<String, double> soiBalance = new Map<String, Double>();
                try {
                    String queryInvoice = 'SELECT Id, Sales_Order__c, Is_ADM_Fees_and_Dari_charges__c, Charge__c, InvoiceStatus__c, SalesOrderInstallment__c, SalesOrderInstallment__r.MilestoneNumber__c, InvoiceBalance__c, InvoiceDate__c FROM Invoice__c ';
                    queryInvoice += 'WHERE InvoiceStatus__c IN: INVOICE_STATUS ';
                    Id chargeId = thisCharge != null ? thisCharge.Id : null;
                    Map<String, Object> invoiceBinds = new Map<String, Object>{
                        'INVOICE_STATUS' => INVOICE_STATUS,
                        'soiIds' => soiIds
                    };
                    if(thisCharge != null) {
                        queryInvoice += ' AND (SalesOrderInstallment__c IN: soiIds OR Charge__c = :chargeId)';
                        invoiceBinds.put('chargeId', chargeId);
                    } else {
                        queryInvoice += ' AND SalesOrderInstallment__c IN: soiIds';
                    }
                    
                    for(Invoice__c thisInvoice : (List<Invoice__c>) Database.queryWithBinds(queryInvoice, invoiceBinds, AccessLevel.SYSTEM_MODE)) {
                                                      system.debug('thisInvoice'+ thisInvoice);
                                                      if(thisInvoice.Is_ADM_Fees_and_Dari_charges__c){
                                                          soiByInvoice.put(thisInvoice.Sales_Order__c, thisInvoice);
                                                          soiBalance.put(thisInvoice.Sales_Order__c, thisInvoice.InvoiceBalance__c);
                                                          Map<String, String> options = new Map<String, String>();
                                                            options.put('label', 'ADM');
                                                            options.put('value', thisInvoice.Sales_Order__c);
                                                            thisWrapper.soiOptions.add(options);

                                                      } else {
                                                          soiByInvoice.put(thisInvoice.SalesOrderInstallment__c, thisInvoice);
                                                          soiBalance.put(String.valueOf(thisInvoice.SalesOrderInstallment__r.MilestoneNumber__c), thisInvoice.InvoiceBalance__c);
                                                      }
                                                  }
                    thisWrapper.soiBalance = soiBalance;
                    thisWrapper.soiInvoice = soiByInvoice;
                }   catch(Exception e) {
                    throw new AuraHandledException(e.getMessage());
                }
                return thisWrapper;
            }
            return null;
        } else {
            throw new AuraHandledException('Unit Id cannot be null or empty');  
        }
    }
    
    public class SalesOrderWrapper {
       public @AuraEnabled String soName {set;get;}
       public @AuraEnabled String soId {set;get;}
       public @AuraEnabled String soLink {set;get;}
       public @AuraEnabled List<Map<String, String>> soiOptions {set;get;}
       public @AuraEnabled Map<String, double> soiBalance {set;get;}
       public @AuraEnabled Map<Id, Invoice__c> soiInvoice {set;get;}
    }
}