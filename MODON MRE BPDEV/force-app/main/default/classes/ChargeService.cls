/**
 * @description       : 
 * @author            : Krishna Chaitanya
 * @group             : 
 * @last modified on  : 02-13-2026
 * @last modified by  : Krishna Chaitanya
 * * --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Krishna   	            02-13-2026     Initial Draft       
* 2.0           Kumar 				    20-02-2026     Update By pass the invoice creation and Add Logic for Vat
* 3.0			Manoj					20-02-2026	   update ADM & Dari Fee login on charge 
* 4.0           Sireesha				25-05-2026	 Added Extension fee logic 
***********************************************************************************************************************
**/
public class ChargeService { 
    
    public static void createChargesOnSR(List<ServiceRequest__c> serviceRequestList) {
        
        Set<string> typeSet = new Set<string>();
        Set<string> phaseIds = new Set<string>();
        Set<string> subTypeSet = new Set<string>();
        Set<string> recordTypeSet = new Set<string>();
        List<Charge__c> chargeList = new List<Charge__c>();

        Map<string,string>recordTypeMap = new Map<string,string>();
        Map<string,string>salesOrderAccountMap = new Map<string,string>();
        Map<string,List<Financial_Setup__c>> financialSetupMap = new Map<string,List<Financial_Setup__c>>();
        
        List<ServiceRequest__c>srList = [
            select Id,RecordType.DeveloperName,SubType__c,Type__c,UnitId__r.Phase__c,SalesOrder__c,Selling_Price__c ,
            SalesOrder__r.TotalAmount__c,SalesOrder__r.CustomerAccount__c,Penality_Charge__c,Is_NOC_Extended__c,Penality_Fee__c
            from ServiceRequest__c
            where Id IN:serviceRequestList
        ];
        
        for(ServiceRequest__c sr : srList){
        
            if(sr.RecordType.DeveloperName != null)recordTypeSet.add(sr.RecordType.DeveloperName);
            if(sr.SubType__c != null)subTypeSet.add(sr.SubType__c);
            if(sr.UnitId__r.Phase__c != null)phaseIds.add(sr.UnitId__r.Phase__c);
            if(sr.SalesOrder__c != null && sr.SalesOrder__r.CustomerAccount__c != null ){
                salesOrderAccountMap.put(sr.SalesOrder__c,sr.SalesOrder__r.CustomerAccount__c); 
            }
        }
        
        if(phaseIds != null){
        
            //2.0 Add vat fileds 
            for(Financial_Setup__c fs : [Select id, value__c,Penality_Charge__c,Default_Amount__c , Phase__c,SR_RecordType__c,Type__c,Fee_Type__c,Sub_Type__c,Nationality__c,VAT_Percnetage__c,Tax_Code__c,VATAmount__c
                from Financial_Setup__c
                where Phase__c IN :phaseIds
                and SR_RecordType__c IN : recordTypeSet
                and Phase__c != null 
                and Sub_Type__c != null
                and Type__c != null
                and SR_RecordType__c != null
            ]){
                
                for(string st : fs.Sub_Type__c.split(';')){
                    
                    string keyFs = fs.Phase__c+'-'+fs.SR_RecordType__c+'-'+st;
                    if(financialSetupMap.get(keyFs)==null)financialSetupMap.put(keyFs,new List<Financial_Setup__c>());
                    financialSetupMap.get(keyFs).add(fs);
                }
                if(fs.Type__c != null)typeSet.add(fs.Type__c);
            }
            system.debug('--------------financialSetupMap-->'+financialSetupMap);

            for(RecordType rt : [SELECT iD,SobjectType,Name,DeveloperName FROM RecordType where SobjectType ='Charge__c' and Name IN:typeSet]){
                recordTypeMap.put(rt.Name,rt.Id);
            }
            system.debug('--------------recordTypeMap-->'+recordTypeMap);

            system.debug('financialSetupMap-->'+financialSetupMap);
            if(financialSetupMap.size() >0){  
                
                for(ServiceRequest__c sr : srList){
            
                    if(sr.UnitId__r.Phase__c != null && sr.RecordType.DeveloperName != null && sr.Type__c != null ){
                        
                        string keyFs = sr.UnitId__r.Phase__c+'-'+sr.RecordType.DeveloperName+'-'+sr.Type__c;
                        List<Financial_Setup__c> fsList = financialSetupMap.containskey(keyFs) && financialSetupMap.get(keyFs) != null ? financialSetupMap.get(keyFs) :new List<Financial_Setup__c>();
                                
                        if(fsList != null && fsList.size()>0){
                            
                            for(Financial_Setup__c financialSetup : fsList){
                                double  AmountCalculated = 0 ;
                                String recordTypeChargeId;
                               
                                if((sr.Penality_Charge__c == false && financialSetup.Type__c <> Constants.PENALITY_TYPE) && (sr.Is_NOC_Extended__c == false && financialSetup.Type__c <> 'Extension Fee')){
                                    //3.0 start ADM & Dari Fee Change update 
                                    decimal sellingPrice = 0;
                                    if(financialSetup.Type__c == 'ADM & Dari Fee'){
                                         sellingPrice = sr.Selling_Price__c != null ? sr.Selling_Price__c : 0;                                    
                                    }else{
                                        sellingPrice = sr.SalesOrder__r.TotalAmount__c != null ? sr.SalesOrder__r.TotalAmount__c : 0;                                    
                                    }
                                    //3.0 End ADM & Dari Fee Change update 
                                    decimal defaultAmount =financialSetup.Default_Amount__c != null ? financialSetup.Default_Amount__c : 0;
                                    AmountCalculated = (financialSetup.Fee_Type__c== Constants.PERECENTAGE_BASED_CALCULATION) ? ((sellingPrice * financialSetup.Value__c) / 100) + defaultAmount: financialSetup.Value__c;
                                    recordTypeChargeId = recordTypeMap.containskey(financialSetup.Type__c) && recordTypeMap.get(financialSetup.Type__c) != null ? recordTypeMap.get(financialSetup.Type__c) :'';
                                }else if(sr.Penality_Charge__c == true  && financialSetup.Type__c == Constants.PENALITY_TYPE){
                                     decimal penalityCharge = financialSetup.Penality_Charge__c != null ? financialSetup.Penality_Charge__c : 0;
                                    AmountCalculated = (financialSetup.Fee_Type__c== Constants.PERECENTAGE_BASED_CALCULATION) ? (penalityCharge * financialSetup.Value__c) / 100 : financialSetup.Value__c;
                                    recordTypeChargeId = recordTypeMap.containskey(financialSetup.Type__c) && recordTypeMap.get(financialSetup.Type__c) != null ? recordTypeMap.get(financialSetup.Type__c) :'';
                                }else if(sr.Is_NOC_Extended__c == true  && financialSetup.Type__c == 'Extension Fee'){//Added 4.0 for extension fee
                                    decimal sellingPrice = 0; 
                     				 sellingPrice = sr.SalesOrder__r.TotalAmount__c != null ? sr.SalesOrder__r.TotalAmount__c : 0;                                    
                                    decimal defaultAmount =financialSetup.Default_Amount__c != null ? financialSetup.Default_Amount__c : 0;
                                    AmountCalculated = (financialSetup.Fee_Type__c== Constants.PERECENTAGE_BASED_CALCULATION) ? ((sellingPrice * financialSetup.Value__c) / 100) + defaultAmount: financialSetup.Value__c;
                                    recordTypeChargeId = recordTypeMap.containskey(financialSetup.Type__c) && recordTypeMap.get(financialSetup.Type__c) != null ? recordTypeMap.get(financialSetup.Type__c) :'';
             }
                                if(recordTypeChargeId != '' && AmountCalculated >0){
                                    Charge__c chargeCreate = createCharge(AmountCalculated,recordTypeChargeId,financialSetup,sr);
                                    chargeList.add(chargeCreate);

                                }
                            }
                        }
                    }
                }               
            }
            
            if(chargeList.size()>0){
                
                insert chargeList;
                List<Invoice__c> invoiceList = new List<Invoice__c>();
                for(Charge__c charge : chargeList){
                    if(charge.Type__c != 'ADM & Dari Fee' && charge.Type__c != 'Modon Fee'){ // 2.0 for the By pass invoice
                        if(salesOrderAccountMap.containskey(charge.Sales_Order__c) &&  salesOrderAccountMap.get(charge.Sales_Order__c) != null){
                           Invoice__c inv =  createChargeInvoice(charge,salesOrderAccountMap.get(charge.Sales_Order__c));
                           invoiceList.add(inv);
                        }
                    }
                }
                
                if(invoiceList.size()>0)insert invoiceList;
            }
        }
    }
    
    public static Charge__c createCharge(decimal amount,string recordTypeChargeId,Financial_Setup__c financialSetup,ServiceRequest__c sr){
        
        Charge__c charge= new Charge__c();
        charge.Name = financialSetup.Type__c;
        charge.Amount__c = amount;
        charge.recordTypeId = recordTypeChargeId;
        charge.PaymentStatus__c = Constants.INSTALLMENT_PAYMENT_STATUS_NOT_PAID;
        charge.VAT_Amount__c = (financialSetup.VAT_Percnetage__c != null && financialSetup.VAT_Percnetage__c >0) ? (amount * financialSetup.VAT_Percnetage__c)/100 : 0;          
        charge.Sales_Order__c = sr.SalesOrder__c;
        charge.Service_Request__c=sr.id;
        //2.0 Add Logic for Vat
        charge.Tax_Code__c =financialSetup.Tax_Code__c;
        charge.VAT_Percentage__c=financialSetup.VAT_Percnetage__c;
        charge.Type__c=financialSetup.Type__c;
        return charge;
    }
    
    public static Invoice__c createChargeInvoice(Charge__c charge,string accId ){
    
        Invoice__c invObj = new Invoice__c();
        invObj.Sales_Order__c= charge.Sales_Order__c ;
        Decimal vatAmount = (charge.VAT_Amount__c != null) ? charge.VAT_Amount__c :0;
        invObj.InvoiceAmount__c = charge.Amount__c +vatAmount ;
        invObj.InvoiceDate__c = system.today();
        invObj.Account__c = accId;
        invObj.Charge__c = charge.Id;
        invObj.Is_ADM_Fees_and_Dari_charges__c = charge.Type__c == 'ADM & Dari Fee' ? true :false;
        return invObj;
    }
}