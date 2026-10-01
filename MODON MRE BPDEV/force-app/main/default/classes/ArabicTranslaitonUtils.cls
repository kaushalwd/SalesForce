/**********************************************************************************************************************
* Name               : ArabicTranslaitonUtils                                                        
* Description        : This class is used to translate Eng to Arabic
* Usage              : 
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           PWC Digital Middle East           12 Jan 2024     Initial Draft       
* 2.0           Milin Kapatel (Horizontal)        09 March 2026     Calling API to get SQ meters in words
******************************************************************************************************************/
public class ArabicTranslaitonUtils {
    
    @InvocableMethod(label='Initiate Callout' description='Initiate callout for Arabic translation' category='Sales Order')
    public static void initiateCallout(List<Id> SOId) {
        String Sales_Order_Id = SOId[0];
        ConvertArabic(Sales_Order_Id);
    }

    @future(callout= true)
    public static void convertArabicWhenAccUpdate(string recId, map<String, String> contactChangedFieldMap, Boolean isNameChanged) {
        Map<String,String> field_key_map = New Map<String, String>{
            '5-1'=>'MailingCityArabic__c',
				'5-2'=>'MailingCountryArabic__c', 
                '5-3'=>'Contact_Name_Arabic__c',
                '5-4'=>'NationalityArabic__c',
				'5-5'=>'Passport_Issuance_Place_Arabic__c',
                '6-1'=>'BrokerAgentNameArabic__c',
                '9-1'=>'AccountnameArabic__c'
        };

         Map<string,map<string,String>> mapofOppAcc=new map<string,map<string,String>>{'5-Contact'=> contactChangedFieldMap};

        if (isNameChanged) {
            mapofOppAcc.put('9-OrganizationAccount', new Map<String,String>{'9-1#_#AccountnameArabic__c'=>'Name'});
        }

        Contact accountContact;
        List<Contact> lst_Contact = [SELECT Id, AccountId, Account.RecordType.DeveloperName, Account.Name, Account.AccountnameArabic__c,
                                        MailingCountryArabic__c, City_FF__c, MailingCityArabic__c, Country_FF__c, Contact_Name_Arabic__c, Name,
                                        NationalityArabic__c, Nationality__c, Passport_Issuance_Place_Arabic__c, PassportIssuancePlace__c
                                        FROM Contact WHERE AccountId =:recId ORDER BY CreatedDate ASC LIMIT 1];
            if(lst_Contact.size() > 0){
               accountContact = lst_Contact.get(0);
            }
        
        map<string,string> mapOfAcctFields = mapofOppAcc.get('5-Contact');
        map<string,string> mapOfOAFields = mapofOppAcc.get('9-OrganizationAccount');
        map<string,string> mapApiNameArbicConvertions = new map<string,string>();
        
        prepareAccountData(mapOfAcctFields, mapApiNameArbicConvertions, accountContact, 'Contact');
        if (isNameChanged) {
            prepareAccountData(mapOfOAFields, mapApiNameArbicConvertions, accountContact, 'Organization Account');
        }

        string body = 'inputString=[';
        string mainBody = '';
        
        for(string strString :mapApiNameArbicConvertions.values()){
            mainBody+='"'+strString+'"'+',';
        }
        mainBody = mainBody.removeEnd(',');
        body+=mainBody+']';
        List<SObject> sObjectsToUpdate =  New List<SObject> ();
        if(mapApiNameArbicConvertions.values().size()>0){
            sObjectsToUpdate = call_arabic_translation_api(body, mapofOppAcc, accountContact.Id, null, recId, field_key_map);
        }

        system.debug('sObjectsToUpdate: ' +sObjectsToUpdate);
        UPDATE sObjectsToUpdate;
    }
    
    @future(callout= true)
    public static void ConvertArabic(string recId){
        Map<String,String> field_key_map = New Map<String, String>{
            '5-1'=>'MailingCityArabic__c',
				'5-2'=>'MailingCountryArabic__c', 
                '5-3'=>'Contact_Name_Arabic__c',
                '5-4'=>'NationalityArabic__c',
				'5-5'=>'Passport_Issuance_Place_Arabic__c',
                '6-1'=>'BrokerAgentNameArabic__c',
                /*'7-1'=>'TotalamountinwordsArabic__c',
                '8-1'=>'Instalment_Payment_Due_Date_Arabic__c',
				'8-2'=>'Milestone_Description_Arabic__c',*/
                '9-1'=>'AccountnameArabic__c'
        };
         Map<string,map<string,String>> mapofOppAcc=new map<string,map<string,String>>{
			// DATA FROM ACCOUNT
            '5-Contact'=>new Map<String,String>{
				'5-1#_#MailingCityArabic__c'=>'City_FF__c',
				'5-2#_#MailingCountryArabic__c'=>'Country_FF__c', 
                '5-3#_#Contact_Name_Arabic__c'=>'Name',
                '5-4#_#NationalityArabic__c'=>'Nationality__c',
				'5-5#_#Passport_Issuance_Place_Arabic__c'=>'PassportIssuancePlace__c'
			},
			// DATA FROM OPPORTUNITY
			'6-Opportunity'=>new Map<String,String>{
				'6-1#_#BrokerAgentNameArabic__c'=>'BrokerAgentName__c'
			},
			// DATA FROM SALES ORDER
			/*'7-SalesOrder__c'=>new Map<String,String>{
				'7-1#_#TotalamountinwordsArabic__c'=>'Totalamountinwords__c'
			},*/
			// DATA FROM SALES ORDER INSTALMENT
			/*'8-SalesOrderInstallments__c'=>new Map<String,String>{
				'8-1#_#Instalment_Payment_Due_Date_Arabic__c'=>'InstalmentPaymentDueDate__c',
				'8-2#_#Milestone_Description_Arabic__c'=>'MilestoneDescription__c'
			},*/
            // DATA FROM ORG ACCOUNT
			'9-OrganizationAccount'=>new Map<String,String>{
				'9-1#_#AccountnameArabic__c'=>'Name'
			}
        };

        String objName = Utility.getObjectNameFromId(recId);
        Boolean isAccountObject = objName.equals('Account');
        
        SalesOrder__c objSO;
        Contact accountContact;
        if (!isAccountObject) {
            objSO = [SELECT Id, Name, Totalamountinwords__c, TotalamountinwordsArabic__c, TotalAmount__c, 
                                Opportunity__c, Opportunity__r.BrokerAgentName__c, Opportunity__r.BrokerAgentNameArabic__c,
                                Opportunity__r.AccountId, Opportunity__r.Account.RecordType.DeveloperName, 
                                Opportunity__r.Account.Name, Opportunity__r.Account.AccountnameArabic__c,
                                Opportunity__r.PrimaryContact__c, Opportunity__r.PrimaryContact__r.MailingCountryArabic__c, Opportunity__r.PrimaryContact__r.City_FF__c, 
                                Opportunity__r.PrimaryContact__r.MailingCityArabic__c, Opportunity__r.PrimaryContact__r.Country_FF__c,
                                Opportunity__r.PrimaryContact__r.Contact_Name_Arabic__c, Opportunity__r.PrimaryContact__r.Name, Opportunity__r.PrimaryContact__r.NationalityArabic__c, 
                                Opportunity__r.PrimaryContact__r.Nationality__c,
                                Opportunity__r.PrimaryContact__r.Passport_Issuance_Place_Arabic__c, Opportunity__r.PrimaryContact__r.PassportIssuancePlace__c
                                FROM SalesOrder__c WHERE ID =:recId
                                ];
        } else {
            List<Contact> lst_Contact = [SELECT Id, AccountId, Account.RecordType.DeveloperName, Account.Name, Account.AccountnameArabic__c,
                                        MailingCountryArabic__c, City_FF__c, MailingCityArabic__c, Country_FF__c, Contact_Name_Arabic__c, Name,
                                        NationalityArabic__c, Nationality__c, Passport_Issuance_Place_Arabic__c, PassportIssuancePlace__c
                                        FROM Contact WHERE AccountId =:recId ORDER BY CreatedDate ASC LIMIT 1];
            if(lst_Contact.size() > 0){
               accountContact = lst_Contact.get(0);
            }
        }
        
       /* List<SalesOrderInstallments__c> soi_list =[SELECT Id, Name, MilestoneNumber__c, Instalment_Payment_Due_Date_Arabic__c, InstalmentPaymentDueDate__c, 
                                                   Milestone_Description_Arabic__c, MilestoneDescription__c FROM SalesOrderInstallments__c WHERE SalesOrder__c=:recId 
                                                   ORDER BY MilestoneNumber__c ASC];*/
        
        
        map<string,string> mapOfAcctFields = mapofOppAcc.get('5-Contact');
        map<string,string> mapOfOAFields = mapofOppAcc.get('9-OrganizationAccount');

        map<string,string> mapOfOppFields = new map<string,string>();
        map<string,string> mapOfSOFields = new map<string,string>();
        if (!isAccountObject) {
            mapOfOppFields = mapofOppAcc.get('6-Opportunity');
            mapOfSOFields = mapofOppAcc.get('7-SalesOrder__c');
        }
        //map<string,string> mapOfSOIFields = mapofOppAcc.get('8-SalesOrderInstallments__c');
        
        /*system.debug('mapOfAcctFields: ' +mapOfAcctFields);
        system.debug('mapOfOppFields: ' +mapOfOppFields);
        system.debug('mapOfSOFields: ' +mapOfSOFields);
        system.debug('mapOfSOIFields: ' +mapOfSOIFields);
        system.debug('mapOfOAFields: ' +mapOfOAFields);*/
        
        map<string,string> mapApiNameArbicConvertions = new map<string,string>();
        

        if (!isAccountObject) {
            preapreData(mapOfAcctFields, mapApiNameArbicConvertions, objSO, null, 'Contact');
            preapreData(mapOfOAFields, mapApiNameArbicConvertions, objSO, null, 'Organization Account');
            preapreData(mapOfOppFields, mapApiNameArbicConvertions, objSO, null, 'Opportunity');
        } else {
            prepareAccountData(mapOfAcctFields, mapApiNameArbicConvertions, accountContact, 'Contact');
            prepareAccountData(mapOfOAFields, mapApiNameArbicConvertions, accountContact, 'Organization Account');
        }

        //preapreData(mapOfSOFields, mapApiNameArbicConvertions, objSO, null, 'Sales Order');
        //preapreData(mapOfSOIFields, mapApiNameArbicConvertions, objSO, soi_list, 'Sales Order Instalment');
        
        system.debug('mapApiNameArbicConvertions.values(): ' + mapApiNameArbicConvertions.values());
        system.debug('mapApiNameArbicConvertions.values().size(): ' + mapApiNameArbicConvertions.values().size());
        string body = 'inputString=[';
        string mainBody = '';
        
        for(string strString :mapApiNameArbicConvertions.values()){
            mainBody+='"'+strString+'"'+',';
        }
        mainBody = mainBody.removeEnd(',');
        body+=mainBody+']';
        system.debug('The body:----' +body);
        List<SObject> sObjectsToUpdate =  New List<SObject> ();
        if(mapApiNameArbicConvertions.values().size()>0){
            Id conId = isAccountObject ? accountContact.Id : objSO.Opportunity__r.PrimaryContact__c;
            Id oppId = isAccountObject ? null : objSO.Opportunity__c;
            Id accId = isAccountObject ? recId : objSO.Opportunity__r.AccountId;

            sObjectsToUpdate = call_arabic_translation_api(body, mapofOppAcc, conId, oppId, accId, field_key_map);
        }
        system.debug('sObjectsToUpdate: ' +sObjectsToUpdate);
        
        if (!isAccountObject) {
            // number to arabic word
            SObject update_so = objSO.Id.getSObjectType().newSObject(objSO.Id); // update sales order
            update_so.put('TotalamountinwordsArabic__c', Amount_in_ArabicWords(String.valueOf(objSO.TotalAmount__c)));
            sObjectsToUpdate.add(update_so);
            system.debug('sObjectsToUpdate: ' +sObjectsToUpdate);
        }

        UPDATE sObjectsToUpdate;
    }
    
    public static void preapreData(map<string,string> mapOfAcctFields, map<string,string> mapApiNameArbicConvertions, SalesOrder__c objSO, List<SalesOrderInstallments__c> soi_list, String obj){
        
        for(string acctField :mapOfAcctFields.keyset()){
            //if(objOppty.Account.get(acctField)==null || objOppty.Account.get(acctField)==''){
            string data = mapOfAcctFields.get(acctField);
            String sequence = acctField.split('#_#')[0] + '#_#';
            String obj_Field = acctField.split('#_#')[1];
            //system.debug('sequence:---' +sequence);
            system.debug('Englsih Field:---' +data);
            string value;
            if(obj != 'Sales Order Instalment'){
                value = (obj == 'Contact' && (string.valueOf(objSO.Opportunity__r.PrimaryContact__r.get(data)) != null && string.valueOf(objSO.Opportunity__r.PrimaryContact__r.get(obj_Field)) == null)) ? sequence + string.valueOf(objSO.Opportunity__r.PrimaryContact__r.get(data)) : 
                (obj == 'Opportunity' && (string.valueOf(objSO.Opportunity__r.get(data)) != null && string.valueOf(objSO.Opportunity__r.get(obj_Field)) == null)) ? sequence + string.valueOf(objSO.Opportunity__r.get(data)) : 
                /*(obj == 'Sales Order' && (string.valueOf(objSO.get(data)) != null)) ? sequence + string.valueOf(objSO.get(data)) : */
                (obj == 'Organization Account' && (string.valueOf(objSO.Opportunity__r.Account.get(data)) != null && string.valueOf(objSO.Opportunity__r.Account.get(obj_Field)) == null)) ? sequence + string.valueOf(objSO.Opportunity__r.Account.get(data)):null;
                system.debug('Englsih value:---' +value);
                if(value != null){mapApiNameArbicConvertions.put(obj+data,value);}
            }/*else{
                if(soi_list.size()>0){
                    for(Integer i=0; i<soi_list.size(); i++){
                        value = sequence + String.valueOf(soi_list[i].MilestoneNumber__c) + '@_@' + String.valueOf(soi_list[i].get(data));
                        system.debug('Englsih value:---' +value);
                        mapApiNameArbicConvertions.put(obj+data+i,value);
                    }
                }
            }*/
        }
    }


    public static void prepareAccountData(map<string,string> mapOfAcctFields, map<string,string> mapApiNameArbicConvertions, Contact con, String obj){
        for(string acctField :mapOfAcctFields.keyset()){
            string data = mapOfAcctFields.get(acctField);
            String sequence = acctField.split('#_#')[0] + '#_#';
            String obj_Field = acctField.split('#_#')[1];
            string value;
            value = (con != null && obj == 'Contact' && (string.valueOf(con.get(data)) != null)) ? sequence + string.valueOf(con.get(data)) :
            (con != null && obj == 'Organization Account' && (string.valueOf(con.Account.get(data)) != null)) ? sequence + string.valueOf(con.Account.get(data)):null;

            if(value != null){mapApiNameArbicConvertions.put(obj+data,value);}
        }
    }
    
    public static List<SObject> process_responce(TranslationWrapper objTranslationWrap, Map<string,map<string,String>> mapofOppAcc,
    Id conId, Id oppId, Id accId, Map<String,String> field_key_map
    /*List<SalesOrderInstallments__c> soi_list,*/){
        //List<SObject> sObjectsToUpdate = new List<SObject>();
        SObject update_opp;
        SObject update_con = conId.getSObjectType().newSObject(conId); // update contact
        //SObject update_so = objSO.Id.getSObjectType().newSObject(objSO.Id); // update sales order
        SObject update_acc = accId.getSObjectType().newSObject(accId); // update account
        Map<String, SObject> sobj_key_map = New Map<String, SObject>{'5'=>update_con, /*'7'=>update_so,*/ '9'=>update_acc};
        if (oppId != null) {
            update_opp = oppId.getSObjectType().newSObject(oppId); // update opportunity
            sobj_key_map.put('6', update_opp);
        }

        for(TranslationWrapper.TranslationData objtranslation :objTranslationWrap.arabicNames){
            system.debug('objtranslation: ' + objtranslation);
            
            String field_key = String.valueOf(objtranslation.arabic).split('#_#')[0];
            String field_value = String.valueOf(objtranslation.arabic).split('#_#')[1];
            if(!field_key.startsWith('8')){
                sobj_key_map.get(field_key.split('-')[0]).put(field_key_map.get(field_key),field_value);
            }
        }
        List<SObject> sObjectsToUpdate = New List<SObject>{update_con, /*update_so,*/ update_acc};
        if (oppId != null) {
            sObjectsToUpdate.add(update_opp);
        }

        /*Map<String, SObject> instalment_milestonenumber_map = New Map<String, SObject>();
        for(SalesOrderInstallments__c rec:soi_list){
            SObject update_soi = rec.Id.getSObjectType().newSObject(rec.Id); // update sales order instalment
            for(TranslationWrapper.TranslationData objtranslation :objTranslationWrap.arabicNames){
                
                String field_key = String.valueOf(objtranslation.arabic).split('#_#')[0];
                
                if(field_key.startsWith('8')){
                    //system.debug('objtranslation: ' + objtranslation);
                    String field_milestone = String.valueOf(objtranslation.arabic).split('#_#')[1].split('@_@')[0];
                    String field_value = String.valueOf(objtranslation.arabic).split('#_#')[1].split('@_@')[1];
                    
                    String milestone_num = String.valueOf(rec.MilestoneNumber__c);
                    if(field_milestone == milestone_num){
                        if(instalment_milestonenumber_map.containsKey(milestone_num)){
                            instalment_milestonenumber_map.get(milestone_num).put(field_key_map.get(field_key),field_value);
                        }else{
                            update_soi.put(field_key_map.get(field_key),field_value);
                            instalment_milestonenumber_map.put(milestone_num,update_soi);
                        }
                    }
                }
            }
        }
		sObjectsToUpdate.addAll(instalment_milestonenumber_map.values());*/
        return sObjectsToUpdate;
    }
    
    public static String Amount_in_ArabicWords(String amount){
        String result;
        Arabic_Translation_Settings__mdt ArabicSettings = Arabic_Translation_Settings__mdt.getInstance('Number_to_ArabicWord');
        String end_piont = ArabicSettings.Endpoint_URL__c + '?inputNumber='+amount;
        http insHttp = new Http();
        HttpRequest httpReq = new HttpRequest();
        httpReq.setHeader('Content-Type','application/x-www-form-urlencoded');
        httpReq.setHeader('Accept','*/*');
        httpReq.setHeader('Accept-Encoding','gzip, deflate, br');
        httpReq.setHeader('Connection','keep-alive');
        httpReq.setHeader('Authorization', ArabicSettings.Authorization__c);
        httpReq.setMethod('GET');
        httpReq.setTimeout(120000);
        httpReq.setEndpoint(end_piont);
        
        HttpResponse httpResponse = new HttpResponse();
        try{
            httpResponse = insHttp.send(httpReq);
            system.debug('httpResponse: ' + httpResponse);
            system.debug('httpResponse: ' + httpResponse.getBody());
            for (String headerKey : httpResponse.getHeaderKeys()) {
                System.debug('httpResponse.getHeader(' + headerKey + '): ' + httpResponse.getHeader(headerKey));
            }
            
            if(httpResponse.getStatusCode() == 200){
                
                result = httpResponse.getBody();
                String pattern = '\\b' + 'إماراتياً' + '\\b';
                result = result.replaceAll(pattern, '');
                pattern = '\\b' + 'إماراتي' + '\\b';
                result = result.replaceAll(pattern, '');
            }
        }Catch (Exception ex){
            system.debug('Exception number to arabic: ' + ex);
        }
        
        return result + ' فقط';
    }
    
    public static List<SObject> call_arabic_translation_api(String body, Map<string,map<string,String>> mapofOppAcc, Id conId, Id oppId, Id accId, Map<String,String> field_key_map){
        List<SObject> sObjectsToUpdate = New List<SObject> ();
        Arabic_Translation_Settings__mdt lstArabicSettings = Arabic_Translation_Settings__mdt.getInstance('Arabic');
        http insHttp = new Http();
        HttpRequest httpReq = new HttpRequest();
        if(lstArabicSettings != null){
            httpReq.setHeader('Content-Type','application/x-www-form-urlencoded');
            httpReq.setHeader('Accept','*/*');
            httpReq.setHeader('Accept-Encoding','gzip, deflate, br');
            httpReq.setHeader('Connection','keep-alive');
            httpReq.setHeader('Authorization', lstArabicSettings.Authorization__c);
            httpReq.setBody(body);
            httpReq.setMethod('POST');
            httpReq.setTimeout(120000);
            httpReq.setEndpoint(lstArabicSettings.Endpoint_URL__c);
        }
        system.debug('httpReq: ' + httpReq);
        system.debug('httpReq.getBody(): ' + httpReq.getBody());
        system.debug('httpReq.getHeader(Content-Type): ' + httpReq.getHeader('Content-Type'));
        system.debug('httpReq.getHeader(Authorization): ' + httpReq.getHeader('Authorization'));
        system.debug('httpReq.getHeader(Accept): ' + httpReq.getHeader('Accept'));
        system.debug('httpReq.getHeader(Accept-Encoding): ' + httpReq.getHeader('Accept-Encoding'));
        system.debug('httpReq.getHeader(Connection): ' + httpReq.getHeader('Connection'));
        HttpResponse httpResponse = new HttpResponse();
        try{
            httpResponse = insHttp.send(httpReq);
            system.debug('httpResponse: ' + httpResponse);
            system.debug('httpResponse body: ' + httpResponse.getBody());
            for (String headerKey : httpResponse.getHeaderKeys()) {
                System.debug('httpResponse.getHeader(' + headerKey + '): ' + httpResponse.getHeader(headerKey));
            }
            
            if(httpResponse.getStatusCode() == 200){
                TranslationWrapper objTranslationWrap;
                if(Test.isRunningTest()){
                    string httpResonseBody='{"arabicNames":[{"english":"5-1#_#kolkata","arabic":"5-1#_#كولكاتا"},{"english":"5-2#_#india","arabic":"5-2#_#إنديا"},{"english":"5-3#_#test name primary","arabic":"5-3#_#تيست نام بريماري"},{"english":"5-4#_#united arab emirates","arabic":"5-4#_#أُنيتيد عرب إميراتيس"},{"english":"5-5#_#null","arabic":"5-5#_#نول"},{"english":"6-1#_#brok agent","arabic":"6-1#_#بروس أجينت"}]}';
                    objTranslationWrap=TranslationWrapper.parse(httpResonseBody);
                }else{
                    objTranslationWrap =  TranslationWrapper.parse(httpResponse.getBody());
                }
                system.debug('objTranslationWrap: ' +objTranslationWrap);
                system.debug('objTranslationWrap.result: ' +objTranslationWrap.result);
                if(objTranslationWrap.result != 'Failure'){
                    sObjectsToUpdate =  process_responce(objTranslationWrap, mapofOppAcc, conId, oppId, accId, /*soi_list,*/ field_key_map);
                }
            }else{
                
            }
        }Catch(Exception ex){
            system.debug('Exception: ' + ex + ' => ' + ex.getMessage() + ' => ' + ex.getLineNumber());
        }
        return sObjectsToUpdate;
    }

    //2.0
    public static String Area_in_ArabicWordsSqMeterSqCentimeter(String amount){
        String result;
        Arabic_Translation_Settings__mdt ArabicSettings = Arabic_Translation_Settings__mdt.getInstance('Number_to_ArabicWord');
        String end_piont = ArabicSettings.Endpoint_URL__c + '?inputNumber='+amount;
        http insHttp = new Http();
        HttpRequest httpReq = new HttpRequest();
        httpReq.setHeader('Content-Type','application/x-www-form-urlencoded');
        httpReq.setHeader('Accept','*/*');
        httpReq.setHeader('Accept-Encoding','gzip, deflate, br');
        httpReq.setHeader('Connection','keep-alive');
        httpReq.setHeader('Authorization', ArabicSettings.Authorization__c);
        httpReq.setMethod('GET');
        httpReq.setTimeout(120000);
        httpReq.setEndpoint(end_piont);
        
        HttpResponse httpResponse = new HttpResponse();
        try{
            httpResponse = insHttp.send(httpReq);
            system.debug('httpResponse: ' + httpResponse);
            system.debug('httpResponse: ' + httpResponse.getBody());
            for (String headerKey : httpResponse.getHeaderKeys()) {
                System.debug('httpResponse.getHeader(' + headerKey + '): ' + httpResponse.getHeader(headerKey));
            }
            
            if(httpResponse.getStatusCode() == 200){
                
                result = httpResponse.getBody();
                String pattern;
                pattern = 'درهماً إماراتياً';
                result = result.replaceAll(pattern, 'متر مربع');
                pattern = 'فلس';
                result = result.replaceAll(pattern, 'سنتيمتر مربع');
            }
        }Catch (Exception ex){
            system.debug('Exception number to arabic: ' + ex);
        }
        
        return result;
    }
}