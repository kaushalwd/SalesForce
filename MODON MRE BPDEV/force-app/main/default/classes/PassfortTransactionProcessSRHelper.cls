/**********************************************************************************************************************
* Name               : PassfortTransactionProcessSRHelper                                                        
* Description        : This class is used to form JSON request and make document upload api callout for passfort transactions of profiles and their documents
* Usage              : Called from PassfortTransactionProcessBatch
* Created By         : AMGS                                                    
******************************************************************************************************************

* Version       Author                                        Date            Comment                                                                      
* 1.0           prateek.b.bansal@pwc.com                    19 Dec 2023      Initial Draft      
  1.1           raghu.chilukuri@activemindsit.com            14-Jan-2026      Added Broker Registartion related flow Using Two Methods
                                                                             prepareBrokerRegistrationJSON and updateRegistrationRecords
* 1.2           raghu.chilukuri@activemindsit.com           03-Apr-2026     Added debugs For The Production to troubleshoot any production issues and Commented out contact as 
                                                                            sending contact to compliance for Broker Passfort isn't required
* 1.3           upendra.asam@modon.com                       10-Aug-2026     fixed the customer risk issue

**********************************************************************************************/

public class PassfortTransactionProcessSRHelper {
private Set<ID> trIds;      
static Map<String, String> NationalityVsCodes = new Map<String, String>{
        'Afghanistan'=>'AFG','Albania'=>'ALB','Algeria'=>'DZA','American Samoa'=>'ASM','Andorra'=>'AND','Angola'=>'AGO','Anguilla'=>'AIA','Antarctica'=>'ATA','Antigua and Barbuda'=>'ATG','Argentina'=>'ARG','Armenia'=>'ARM','Aruba'=>'ABW','Australia'=>'AUS','Austria'=>'AUT','Azerbaijan'=>'AZE','Bahamas'=>'BHS','Bolivia'=>'BOL','British Virgin Islands'=>'VGB','Brunei'=>'BRN',
        'Bahrain'=>'BHR','Bangladesh'=>'BGD','Barbados'=>'BRB','Belarus'=>'BLR','Belgium'=>'BEL','Belize'=>'BLZ','Benin'=>'BEN','Bermuda'=>'BMU','Bhutan'=>'BTN','Bosnia and Herzegovina'=>'BIH','Botswana'=>'BWA','Bouvet Island'=>'BVT','Brazil'=>'BRA','British Indian Ocean Territory'=>'IOT','Bulgaria'=>'BGR','Burkina Faso'=>'BFA','Burundi'=>'BDI',
        'Cambodia'=>'KHM','Cameroon'=>'CMR','Canada'=>'CAN','Chad'=>'TCD','Chile'=>'CHL','China'=>'CHN','Christmas Island'=>'CXR','Colombia'=>'COL','Costa Rica'=>'CRI','Croatia'=>'HRV','Cuba'=>'CUB','Cyprus'=>'CYP','Cape Verde'=>'CPV','Cayman Islands'=>'CYM','Central African Republic'=>'CAF','Cocos [Keeling] Islands'=>'CCK','Comoros'=>'COM','Congo [DRC]'=>'COD','Congo [Republic]'=>'COG','Cook Islands'=>'COK','Côte d\'Ivoire'=>'CIV','Czech Republic'=>'CZE',
        'Denmark'=>'DNK','Djibouti'=>'DJI','Dominica'=>'DMA','Dominican Republic'=>'DOM','Ecuador'=>'ECU','Egypt'=>'EGY','El Salvador'=>'SLV','Equatorial Guinea'=>'GNQ','Eritrea'=>'ERI','Estonia'=>'EST','Ethiopia'=>'ETH',
        'Fiji'=>'FJI','Finland'=>'FIN','France'=>'FRA','French Guiana'=>'GUF','French Polynesia'=>'PYF','Falkland Islands [Islas Malvinas]'=>'FLK','Faroe Islands'=>'FRO','French Southern Territories'=>'ATF',
        'Gabon'=>'GAB','Georgia'=>'GEO','Germany'=>'DEU','Ghana'=>'GHA','Gibraltar'=>'GIB','Greece'=>'GRC','Greenland'=>'GRL','Grenada'=>'GRD','Guadeloupe'=>'GLP','Guam'=>'GUM','Guatemala'=>'GTM','Guernsey'=>'GGY','Guinea'=>'GIN','Guinea-Bissau'=>'GNB','Guyana'=>'GUY','Gambia'=>'GMB',
        'Haiti'=>'HTI','Heard Island and McDonald Islands'=>'HMD','Honduras'=>'HND','Hong Kong'=>'HKG','Hungary'=>'HUN','Iceland'=>'ISL','India'=>'IND','Indonesia'=>'IDN','Iraq'=>'IRQ','Ireland'=>'IRL','Isle of Man'=>'IMN','Israel'=>'ISR','Italy'=>'ITA','Iran'=>'IRN',
        'Jamaica'=>'JAM','Japan'=>'JPN','Jersey'=>'JEY','Jordan'=>'JOR','Kazakhstan'=>'KAZ','Kenya'=>'KEN','Kiribati'=>'KIR','Kuwait'=>'KWT','Kyrgyzstan'=>'KGZ','Latvia'=>'LVA','Laos'=>'LAO','Lebanon'=>'LBN','Lesotho'=>'LSO','Liberia'=>'LBR','Libya'=>'LBY','Liechtenstein'=>'LIE','Lithuania'=>'LTU','Luxembourg'=>'LUX','Macedonia [FYROM]'=>'MKD',
        'Madagascar'=>'MDG','Malawi'=>'MWI','Malaysia'=>'MYS','Maldives'=>'MDV','Mali'=>'MLI','Malta'=>'MLT','Martinique'=>'MTQ','Mauritania'=>'MRT','Mauritius'=>'MUS','Mayotte'=>'MYT','Mexico'=>'MEX','Monaco'=>'MCO','Mongolia'=>'MNG','Montenegro'=>'MNE','Montserrat'=>'MSR','Morocco'=>'MAR','Mozambique'=>'MOZ','Macau'=>'MAC','Marshall Islands'=>'MHL','Micronesia'=>'FSM','Moldova'=>'MDA','Myanmar [Burma]'=>'MMR',
        'Namibia'=>'NAM','Nauru'=>'NRU','Nepal'=>'NPL','New Caledonia'=>'NCL','New Zealand'=>'NZL','Nicaragua'=>'NIC','Nigeria'=>'NGA','Niue'=>'NIU','Norfolk Island'=>'NFK','Norway'=>'NOR','Netherlands'=>'NLD','Niger'=>'NER','Northern Mariana Islands'=>'MNP','North Korea'=>'PRK','Oman'=>'OMN','Pakistan'=>'PAK','Palau'=>'PLW','Panama'=>'PAN','Papua New Guinea'=>'PNG','Paraguay'=>'PRY','Peru'=>'PER','Poland'=>'POL','Portugal'=>'PRT','Puerto Rico'=>'PRI',
        'Palestinian Territories'=>'PSE','Philippines'=>'PHL','Pitcairn Islands'=>'PCN','Qatar'=>'QAT','Russia'=>'RUS','Réunion'=>'REU','Romania'=>'ROU','Rwanda'=>'RWA','Saint Kitts and Nevis'=>'KNA','Saint Lucia'=>'LCA','Saint Pierre and Miquelon'=>'SPM','Saint Vincent and the Grenadines'=>'VCT','Samoa'=>'WSM','San Marino'=>'SMR','São Tomé and Príncipe'=>'STP','Saudi Arabia'=>'SAU','Senegal'=>'SEN','Serbia'=>'SRB','Seychelles'=>'SYC','Sierra Leone'=>'SLE',
        'Singapore'=>'SGP','Slovakia'=>'SVK','Slovenia'=>'SVN','Solomon Islands'=>'SLB','Somalia'=>'SOM','South Africa'=>'ZAF','South Georgia and the South Sandwich Islands'=>'SGS','South Korea'=>'KOR','Spain'=>'ESP','Sri Lanka'=>'LKA','Suriname'=>'SUR','Svalbard and Jan Mayen'=>'SJM','Switzerland'=>'CHE','Saint Helena'=>'SHN','Sudan'=>'SDN','Swaziland'=>'SWZ','Sweden'=>'SWE','Syria'=>'SYR',
        'Tajikistan'=>'TJK','Thailand'=>'THA','Timor-Leste'=>'TLS','Togo'=>'TGO','Tokelau'=>'TKL','Tonga'=>'TON','Trinidad and Tobago'=>'TTO','Tunisia'=>'TUN','Turkey'=>'TUR','Turkmenistan'=>'TKM','Tuvalu'=>'TUV','Taiwan'=>'TWN','Tanzania'=>'TZA','Turks and Caicos Islands'=>'TCA','U.S. Minor Outlying Islands'=>'UMI','U.S. Virgin Islands'=>'VIR','United Arab Emirates'=>'ARE','United Kingdom'=>'GBR','United States'=>'USA','Uganda'=>'UGA','Ukraine'=>'UKR','Uruguay'=>'URY','Uzbekistan'=>'UZB',
        'Vanuatu'=>'VUT','Vatican City'=>'VAT','Venezuela'=>'VEN','Vietnam'=>'VNM','Wallis and Futuna'=>'WLF','Western Sahara'=>'ESH','Yemen'=>'YEM','Zambia'=>'ZMB','Zimbabwe'=>'ZWE'};

            
    // To form JSON structure using wrapper class and record values. 
public static void prepareProfileJSON(Set<ID> transactionIDs){
    Map<String,String> mapOfAccIdvsProfileId = new Map<String,String>();
    Map<String,String> mapOfConIdvsProfileId = new Map<String,String>();
    Map<String,String> mapOfTrRecIdvsResponse = new Map<String,String>();
    Map<String,String> mapOfTrRecIdvsTrId = new Map<String,String>();
    Map<String,String> mapOfTrRecIdvsDocIds = new Map<String,String>();
    
    PassfortTransactionWrapper.Personal_details objperDet;
    PassfortTransactionWrapper.Contact_details objConDet;
    PassfortTransactionWrapper.Addresses objAddr;
    PassfortTransactionWrapper.Metadata objMtd;
    PassfortTransactionWrapper.collected_data objColData;
    PassfortTransactionWrapper.Ownership_structure objOS;
    
    Set<Id> PTOppIds = new Set<Id>();
    Set<Id> PTSOIds = new Set<Id>();
    
    // List<Passforttransaction__c> lstPassfortTransaction = [Select Id,Contact__c,Account__c,Prospect_Account__c,EntityType__c,transactionId__c,Opportunity__c,Sales_Order__c from Passforttransaction__c where id in :transactionIDs and PassfortTransaction__c = Null];
    // for(Passforttransaction__c objPT :lstPassfortTransaction){
    //     if(objPT.Opportunity__c!=null)
    //     PTOppIds.add(objPT.Opportunity__c);
        
    //     if(objPT.Sales_Order__c!=null)
    //     PTSOIds.add(objPT.Sales_Order__c);
    // }
    // Map<ID,Integer> mapOfOppVsNoOfJO = new Map<ID,Integer>();
    // Map<ID,Integer> mapOfSOVsNoOfJO = new Map<ID,Integer>();
    // List<JointOwner__c> lstJointOwner = [Select Id,Name,Opportunity__c, SalesOrder__c from JointOwner__c Where Opportunity__r.Id IN :PTOppIds OR SalesOrder__r.Id IN :PTSOIds order by Opportunity__c, SalesOrder__c];
    // for(JointOwner__c objJO : lstJointOwner){
    //     if(mapOfOppVsNoOfJO.containsKey(objJO.Opportunity__c)){
    //         integer no = mapOfOppVsNoOfJO.get(objJO.Opportunity__c);
    //         mapOfOppVsNoOfJO.put(objJO.Opportunity__c,no+1);
    //     }else
    //         mapOfOppVsNoOfJO.put(objJO.Opportunity__c,1);
        
    //     if(mapOfSOVsNoOfJO.containsKey(objJO.SalesOrder__c)){
    //         integer num = mapOfSOVsNoOfJO.get(objJO.SalesOrder__c);
    //         mapOfSOVsNoOfJO.put(objJO.SalesOrder__c,num+1);
    //     }else
    //         mapOfSOVsNoOfJO.put(objJO.SalesOrder__c,1);
    // }
    Integer JointOwnerCount=0;
    for(Passforttransaction__c tempRecord : [Select Id,Prospect_Account__r.Occupation__c,Prospect_Account__r.EmployerBusinessName__c,
                                            Prospect_Account__r.First_Name__c,Prospect_Account__r.Last_Name__c,
                                            Prospect_Account__r.Account_Name__c,Prospect_Account__r.RecordType.Name,Prospect_Account__c,Prospect_Account__r.RecordType.DeveloperName,Prospect_Account__r.Full_Name__c,   Prospect_Account__r.City__c,Prospect_Account__r.Country__c,Prospect_Account__r.Email__c,Prospect_Account__r.MailingAddress__c,Prospect_Account__r.Mobile__c,Prospect_Account__r.PostalCode__c,Prospect_Account__r.State__c,Prospect_Account__r.Street__c,
                                            Prospect_Account__r.LegalStructure__c,Prospect_Account__r.OwnershipPercentage__c,Prospect_Account__r.UnifiedNumber__c,Prospect_Account__r.UAEVATRegisterNumber__c,Prospect_Account__r.DateOfEstablishment__c,Prospect_Account__r.PassfortApprovalStatus__c,
                                            Prospect_Account__r.TradeLicenseExpiryDate__c,Prospect_Account__r.Description__c,Prospect_Account__r.profileId__c,Prospect_Account__r.PurposeOfTransaction__c,Prospect_Account__r.PaymentMethod__c,Prospect_Account__r.DeliveryChannel__c,Prospect_Account__r.NoOfPropertyPurchasedWithModon__c,Prospect_Account__r.SourceOfIncome__c,Prospect_Account__r.OtherSourceOfIncome__c,
                                            EntityType__c,transactionId__c,Document__c,Prospect_Account__r.EIDNumber__c,Prospect_Account__r.PassportNumber__c,Prospect_Account__r.Nationality__c,Prospect_Account__r.UAE_Resident_Status__c,Prospect_Account__r.Birthdate__c,Prospect_Account__r.RelationshipType__c,Prospect_Account__r.Is_Primary__c,Prospect_Account__r.Title__c,Prospect_Account__r.Middle_Name__c,Prospect_Account__r.IsPersonAccount__c,PassfortTransaction__c,ParentDocumentIds__c,Opportunity__c,Sales_Order__c,Linked_Shareholder_Details__c
                                            from Passforttransaction__c where id in :transactionIDs and PassfortTransaction__c = Null]){
                                                
                                                PassfortTransactionWrapper objPTW = new PassfortTransactionWrapper();
                                                boolean isCompany = false;
                                                
                                                if(tempRecord.Prospect_Account__r.RecordType.DeveloperName=='Account')
                                                    isCompany = true;
                                                
                                                objPTW.id = tempRecord.transactionId__c;
                                                objPTW.root_id = tempRecord.Prospect_Account__r.profileId__c;
                                                objPTW.invoke_type = tempRecord.Prospect_Account__r.RecordType.DeveloperName == 'Contact' && !tempRecord.Prospect_Account__r.IsPersonAccount__c ?'Update_link':objPTW.root_id != null ? 'Update':'Create';   
                                                
                                                boolean isRefresh = false;
                                                if(tempRecord.Prospect_Account__r.PassfortApprovalStatus__c == 'Approved' || tempRecord.Prospect_Account__r.PassfortApprovalStatus__c == 'Rejected' || tempRecord.Prospect_Account__r.PassfortApprovalStatus__c =='Requires Resubmission'){
                                                    isRefresh = true;
                                                }
                                                
                                                objPTW.refresh = objPTW.invoke_type =='Update' && (isRefresh)?'yes':'no';
                                                
                                                objPTW.role = isCompany? Constants.PASSFORT_TR_ROLE_COMPANY : tempRecord.Prospect_Account__r.IsPersonAccount__c? Constants.PASSFORT_TR_ROLE_INDIVIDUAL:Constants.PASSFORT_TR_ROLE_INDIVIDUAL_ASSOCIATED;
                                                
                                                PassfortTransactionWrapper.Product objPrd = new PassfortTransactionWrapper.Product();
                                                objPrd.alias = Constants.PASSFORT_TR_ALIAS;
                                                
                                                PassfortTransactionWrapper.Applications objApp = new PassfortTransactionWrapper.Applications();
                                                objApp.product = objPrd;        
                                                objPTW.applications  = new List<PassfortTransactionWrapper.Applications>{objApp};
                                                    
                                                /*Start-- Address */
                                                PassfortTransactionWrapper.Address objAdd = new PassfortTransactionWrapper.Address();        
                                                objAdd.type = Constants.PASSFORT_TR_STRUCTURED_ADDRESS_TYPE; 
                                                objAdd.country = NationalityVsCodes.containsKey(tempRecord.Prospect_Account__r.Country__c) ? NationalityVsCodes.get(tempRecord.Prospect_Account__r.Country__c) : 'ARE';  
                                                objAdd.state_province = tempRecord.Prospect_Account__r.State__c;
                                                objAdd.county = tempRecord.Prospect_Account__r.Country__c;

                                                objAdd.Original_freeform_address = tempRecord.Prospect_Account__r.Street__c+', '+tempRecord.Prospect_Account__r.City__c+', '+tempRecord.Prospect_Account__r.Country__c+', '+tempRecord.Prospect_Account__r.State__c+', '+tempRecord.Prospect_Account__r.PostalCode__c;  
                                                if(tempRecord.Prospect_Account__r.RecordType.Name != 'Contact'){
                                                    objAddr = new PassfortTransactionWrapper.Addresses();
                                                    objAddr.address = objAdd;  
                                                    objAddr.type = isCompany? Constants.PASSFORT_TR_REGISTERED_ADDRESS_TYPE : Constants.PASSFORT_TR_STRUCTURED_ADDRESS_TYPE;
                                                }
                                                /*End-- Address */                                                     
                                                PassfortTransactionWrapper.Custom_fields_data objCustFldata = new PassfortTransactionWrapper.Custom_fields_data();
                                                if(!isCompany){
                                                    /*Start-- Personal Details */          
                                                    PassfortTransactionWrapper.Name objName = new PassfortTransactionWrapper.Name();
                                                    objName.given_names = new List<String>{tempRecord.Prospect_Account__r.First_Name__c, tempRecord.Prospect_Account__r.Middle_Name__c};
                                                    objName.family_name = tempRecord.Prospect_Account__r.Last_Name__c   ;
                                                    objName.title = tempRecord.Prospect_Account__r.Title__c;
                                                    
                                                    objperDet = new PassfortTransactionWrapper.Personal_details();
                                                    objperDet.name = objName;
                                                    objperDet.dob = dateFormation(tempRecord.Prospect_Account__r.Birthdate__c);//tempRecord.Contact__r.Birthdate.Year().ToString();
                                                    objperDet.nationality = NationalityVsCodes.get(tempRecord.Prospect_Account__r.Nationality__c);                                  
                                                    /*End-- Personal Details */  
                                                    
                                                        /*Start-- Contact Details */  
                                                        objConDet = new PassfortTransactionWrapper.Contact_details();
                                                        objConDet.phone_number = tempRecord.Prospect_Account__r.Mobile__c !=null ? tempRecord.Prospect_Account__r.Mobile__c.ToString():'';
                                                        objConDet.email = tempRecord.Prospect_Account__r.Email__c.ToString();
                                                        /*End-- Contact Details */  

                                                        /*Start-- Custom Fields */ 
                                                        objCustFldata.s_applicant_ownership= tempRecord.Prospect_Account__r.RelationshipType__c=='Joint Owner P-P'? 'Multiple':'Single'; 
                                                        objCustFldata.s_residence_status= tempRecord.Prospect_Account__r.UAE_Resident_Status__c;
                                                        objCustFldata.s_occupation= tempRecord.Prospect_Account__r.Occupation__c;
                                                        objCustFldata.s_purpose_of_transaction_1= tempRecord.Prospect_Account__r.PurposeOfTransaction__c;             
                                                        objCustFldata.s_source_of_income_1= tempRecord.Prospect_Account__r.SourceOfIncome__c;
                                                        objCustFldata.s_source_of_income_explanation_1= tempRecord.Prospect_Account__r.OtherSourceOfIncome__c;                
                                                        objCustFldata.s_eid=tempRecord.Prospect_Account__r.EIDNumber__c;
                                                        objCustFldata.s_passport_number=tempRecord.Prospect_Account__r.PassportNumber__c;
                                                        objCustFldata.s_employer_business_name=tempRecord.Prospect_Account__r.EmployerBusinessName__c;
                                                        objCustFldata.s_transaction_specific_risk= tempRecord.Prospect_Account__r.PaymentMethod__c;
                                                        objCustFldata.s_channel_risk=tempRecord.Prospect_Account__r.DeliveryChannel__c;
                                                        objCustFldata.n_inventory_count= tempRecord.Prospect_Account__r.NoOfPropertyPurchasedWithModon__c==null?'':tempRecord.Prospect_Account__r.NoOfPropertyPurchasedWithModon__c.toString();
                                                    
                                                }

                                                
                                                //below are corporate specific custom fields
                                                if(isCompany){
                                                    objCustFldata.s_customer_risk= tempRecord.Prospect_Account__r.LegalStructure__c;        
                                                    objCustFldata.s_trade_license= tempRecord.Prospect_Account__r.UnifiedNumber__c;
                                                    objCustFldata.d_trade_license_expiry_date = dateFormation(tempRecord.Prospect_Account__r.TradeLicenseExpiryDate__c);
                                                    objCustFldata.s_purpose_of_transaction = tempRecord.Prospect_Account__r.PurposeOfTransaction__c;
                                                    objCustFldata.s_description_of_business_activity= tempRecord.Prospect_Account__r.Description__c;    
                                                    objCustFldata.s_source_of_income = tempRecord.Prospect_Account__r.SourceOfIncome__c;
                                                    objCustFldata.s_source_of_income_explanation = tempRecord.Prospect_Account__r.OtherSourceOfIncome__c;
                                                    objCustFldata.s_transaction_specific_risk= tempRecord.Prospect_Account__r.PaymentMethod__c;
                                                    objCustFldata.s_channel_risk=tempRecord.Prospect_Account__r.DeliveryChannel__c;
                                                    objCustFldata.n_inventory_count= tempRecord.Prospect_Account__r.NoOfPropertyPurchasedWithModon__c==null?'':tempRecord.Prospect_Account__r.NoOfPropertyPurchasedWithModon__c.toString();
                                                    /*End-- Custom Fields */   
                                                    
                                                    PassfortTransactionWrapper.Tax_ids objtxIds = new PassfortTransactionWrapper.Tax_ids();
                                                    objtxIds.tax_id_type='VAT';
                                                    objtxIds.value= tempRecord.Prospect_Account__r.UAEVATRegisterNumber__c;
                                                    
                                                    /*End-- Metadata Fields */ 
                                                    objMtd = new PassfortTransactionWrapper.Metadata();
                                                    objMtd.country_of_incorporation = NationalityVsCodes.containsKey(tempRecord.Prospect_Account__r.Country__c) ? NationalityVsCodes.get(tempRecord.Prospect_Account__r.Country__c) : 'ARE';
                                                    objMtd.bvd_id='';
                                                    objMtd.name=tempRecord.Prospect_Account__r.Account_Name__c;
                                                    objMtd.incorporation_date=dateFormation(tempRecord.Prospect_Account__r.DateOfEstablishment__c);
                                                    objMtd.company_number= tempRecord.Prospect_Account__r.UnifiedNumber__c==null?'':tempRecord.Prospect_Account__r.UnifiedNumber__c;
                                                    objMtd.tax_ids = new List<PassfortTransactionWrapper.Tax_ids>{objtxIds};
                                                    objMtd.addresses = new List<PassfortTransactionWrapper.Addresses>{objAddr};   

                                                    
                                                }
                                                if(tempRecord.Prospect_Account__r.RecordType.Name == 'Contact' && !tempRecord.Prospect_Account__r.IsPersonAccount__c && tempRecord.Linked_Shareholder_Details__c != null){
                                                    List<String> lstConJSON = (List<string>)JSON.deSerialize(tempRecord.Linked_Shareholder_Details__c,List<string>.class);
                                                            List<PassfortTransactionWrapper.Beneficial_owners> lstBO = new List<PassfortTransactionWrapper.Beneficial_owners>();
                                                            for(String str : lstConJSON){
                                                                PassfortTransactionWrapper.Beneficial_owners objBO = (PassfortTransactionWrapper.Beneficial_owners)JSON.deSerialize(str,PassfortTransactionWrapper.Beneficial_owners.class);
                                                                lstBO.add(objBO);
                                                            }
                                                            objOS = new PassfortTransactionWrapper.Ownership_structure();
                                                            objOS.beneficial_owners = lstBO;
                                                }
                                                /*Start-- collected data */ 
                                                objColData = new PassfortTransactionWrapper.collected_data();
                                                objColData.entity_type = isCompany ? Constants.PASSFORT_ENTITY_TYPE_COMPANY: Constants.PASSFORT_ENTITY_TYPE_INDIVIDUAL; 
                                                
                                                if(!isCompany){
                                                    objColData.personal_details = objperDet;
                                                    objColData.addresses = new List<PassfortTransactionWrapper.Addresses>{objAddr};
                                                    objColData.contact_details = objConDet;
                                                }
                                                
                                                objColData.custom_fields_data = objCustFldata;
                                                
                                                if(isCompany){
                                                    objColData.metadata = objMtd;
                                                    // objColData.ownership_structure = objOS;
                                                }
                                                
                                                objPTW.collected_data = objColData;       
                                                /*Start-- collected data */ 
                                                
                                                String jsonString = Json.serialize(objPTW);
                                                
                                                String endpointURL='';
                                                if(isCompany){
                                                    endpointURL = Constants.PASSFORT_TR_COMPANY_ENDPOINT;
                                                }
                                                else {
                                                    if(tempRecord.Prospect_Account__r.RecordType.Name == 'Contact' && !tempRecord.Prospect_Account__r.IsPersonAccount__c && !tempRecord.Prospect_Account__r.Is_Primary__c){
                                                        endpointURL = Constants.PASSFORT_TR_SHAREHOLDER_ENDPOINT;
                                                    }else if(tempRecord.Prospect_Account__r.RecordType.Name == 'Contact' && !tempRecord.Prospect_Account__r.IsPersonAccount__c && tempRecord.Prospect_Account__r.Is_Primary__c){
                                                    endpointURL = Constants.PASSFORT_TR_PRIMARY_CONTACT_ENDPOINT;
                                                    }else{
                                                        endpointURL = Constants.PASSFORT_TR_INDIVIDUAL_ENDPOINT;
                                                    }
                                                }

                                                System.debug('isCompany: '+isCompany);
                                                System.debug('endpointURL: '+endpointURL);
                                                //Make callout
                                                HTTPResponse res = makeapiCallout(endpointURL,jsonString);
                                                System.debug('res: '+res);
                                                System.debug('res.getStatus(): '+res.getStatus());
                                                if(res.getStatus() == 'OK'){
                                                    Map<String, String> responseMap = (Map<String, String>) JSON.deserialize(res.getBody(), Map<String, String>.class);
                                                    String profileID = responseMap.get('root_id');
                                                    String responseStatus = responseMap.get('status');
                                                    
                                                    if(responseStatus == Constants.PASSFORT_TR_SUCCESS && profileID != Null && profileID!=''){  
                                                        mapOfTrRecIdvsTrId.put(tempRecord.Id,tempRecord.transactionId__c+':'+profileID);
                                                        
                                                        if(tempRecord.ParentDocumentIds__c!='' && tempRecord.ParentDocumentIds__c!=null)
                                                            mapOfTrRecIdvsDocIds.put(tempRecord.Id,tempRecord.ParentDocumentIds__c);
                                                        
                                                        mapOfAccIdvsProfileId.put(tempRecord.Prospect_Account__c,profileID);
                                                        
                                                    }
                                                    System.debug('res.getBody: '+res.getBody()); 
                                                }
                                                mapOfTrRecIdvsResponse.put(tempRecord.Id,res.getBody());
                                            }      
    System.debug('mapOfTrRecIdvsResponse: '+mapOfTrRecIdvsResponse);
    System.debug('mapOfTrRecIdvsTrId: '+mapOfTrRecIdvsTrId);
    updateAccountOrContactRecord(mapOfAccIdvsProfileId,'profileId'); //for updating profile Id on them.
    updateResponseOnTransactionRecord(mapOfTrRecIdvsResponse,mapOfTrRecIdvsTrId); 
    createDocumentTransactionRecords(mapOfTrRecIdvsDocIds);
}

// make api callout and return response
public static HTTPResponse makeapiCallout(String endPoint, String jsonString){
    HttpRequest req = new HttpRequest();
    req.setTimeout(120000);
    req = OIC_CredentialsController.getCredentials(endPoint);   

    system.debug('jsonString -> ' + jsonString);
    req.setBody(jsonString);
    Http http = new Http();
    return http.send(req);        
}



//to format date as required in API request call
public static string dateFormation(Date dtField){       
    if(dtField == null)
        return '';
    else {
        Integer intMonth = dtField.month();
        String strMonth = intMonth<10?'0'+dtField.month().toString():dtField.month().toString();
        Integer intDay = dtField.day();
        String strDay = intDay<10?'0'+dtField.day().toString():dtField.day().toString();
        return dtField.year()+'-'+strMonth+'-'+strDay;
    }
}

//to update Account and contact record to store API response value
public static void updateAccountOrContactRecord(Map<String,String> mapOfAccIdvsProfileId,String fieldToUpdate){
    List<Prospect_Account__c> lstAccToUpdate = new List<Prospect_Account__c>();
    for(Id accId : mapOfAccIdvsProfileId.keySet()){
        Prospect_Account__c acc = new Prospect_Account__c();
        acc.Id = accId;
        if(fieldToUpdate=='profileId'){
        acc.profileId__c = mapOfAccIdvsProfileId.get(accId);
        acc.PassfortApprovalStatus__c = Constants.PASSFORT_APPROVAL_STATUS_IN_REVIEW;
        acc.ProfileUpdateTime__c = System.Now();
        }
        if(fieldToUpdate=='comment')
        acc.PassfortComment__c = mapOfAccIdvsProfileId.get(accId);
        lstAccToUpdate.add(acc);
    }

    if(lstAccToUpdate.size()>0)
        Database.update(lstAccToUpdate,false);
}   

//to update complete JSON response on transaction record
public static void updateResponseOnTransactionRecord(Map<String,String> mapOfTrRecIdvsResponse, Map<String,String>mapOfTrRecIdvsTrId){
    System.debug('mapOfTrRecIdvsResponse: '+mapOfTrRecIdvsResponse);
    List<Passforttransaction__c> lstPtrToUpdate = new List<Passforttransaction__c>();
    for(Id TrRecId : mapOfTrRecIdvsResponse.keySet()){
        Passforttransaction__c ptr = new Passforttransaction__c();
        ptr.Id = TrRecId;
        System.debug('mapOfTrRecIdvsResponse.get(TrRecId): '+mapOfTrRecIdvsResponse.get(TrRecId));
        ptr.response__c = mapOfTrRecIdvsResponse.get(TrRecId);
        if(mapOfTrRecIdvsTrId.containsKey(TrRecId))
        ptr.ProfileId__c = mapOfTrRecIdvsTrId.get(TrRecId).split(':')[1];
        
        lstPtrToUpdate.add(ptr);
    }
    Database.update(lstPtrToUpdate,false);
}

// to create child transaction records for document upload api callout. self lookup is filled here
public static void createDocumentTransactionRecords(Map<String,String> mapOfTrRecIdvsDocIds){
    List<Passforttransaction__c> lstDocPtrToCreate = new List<Passforttransaction__c>();
    Set<Id> DocumentIDs = new Set<Id>();
    for(Id TrRecId : mapOfTrRecIdvsDocIds.keySet()){
        DocumentIDs.clear();
        List<ID> docIds= mapOfTrRecIdvsDocIds.get(TrRecId).split(',');
        DocumentIDs.addAll(docIds);           
        for(Id docId : DocumentIDs){
            Passforttransaction__c docPtr = new Passforttransaction__c();
            docPtr.PassfortTransaction__c = TrRecId; //self lookup to indentify its child to existing record
            docPtr.Document__c = docId;
            docPtr.EntityType__c = Constants.PASSFORT_TR_TYPE_DOCUMENT;
            lstDocPtrToCreate.add(docPtr);
        } 
    }
        Database.insert(lstDocPtrToCreate,false);
}

// to form JSON using wrapper class and record field values
public static void prepareDocumentJSON(Set<ID> transactionIDs){    
    Map<String,String> mapOfTrRecIdvsResponse = new Map<String,String>();
    Map<String,String> mapOfTrRecIdvsTrId = new Map<String,String>();
    //Update Version 1.1 Added Regstration To the Query of passfort Transaction 
    for(Passforttransaction__c tempRecord : [Select Id,transactionId__c,Document__c,Registration__c,Document__r.Name,PassfortTransaction__r.ProfileId__c,Contact__c from Passforttransaction__c where id in :transactionIDs]){
        //query to get latest file of perticular document
        ContentDocumentLink CD = [SELECT ContentDocumentId,LinkedEntity.Name FROM ContentDocumentLink WHERE LinkedEntityId =: tempRecord.Document__c order by ContentDocument.CreatedDate desc limit 1];
        
        ID CD_ID = CD.ContentDocumentId;
        Blob pdfblob = [SELECT VersionData FROM ContentVersion WHERE ContentDocumentId =: CD_ID].VersionData; 
        
        PassfortTransDocumentWrapper objPTDW = new PassfortTransDocumentWrapper();
        objPTDW.data = pdfblob;
        objPTDW.name = tempRecord.Document__r.Name;
        objPTDW.root_id = tempRecord.PassfortTransaction__r.ProfileId__c;
        objPTDW.id = tempRecord.transactionId__c;
        
        String jsonString = Json.serialize(objPTDW);
        
        string endpointURL = Constants.PASSFORT_TR_DOC_UPLOAD_ENDPOINT;
        
        //Make callout
        HTTPResponse res = makeapiCallout(endpointURL,jsonString);
        if(res.getStatus() == 'OK'){
            Map<String, String> responseMap = (Map<String, String>) JSON.deserialize(res.getBody(), Map<String, String>.class);
            String profileID = responseMap.get('file_id');     
            String responseStatus = responseMap.get('status');
            if(responseStatus == Constants.PASSFORT_TR_SUCCESS && profileID != Null && profileID!=''){  
                mapOfTrRecIdvsTrId.put(tempRecord.Id,tempRecord.transactionId__c+':'+profileID); 
            }
        }
        mapOfTrRecIdvsResponse.put(tempRecord.Id,res.getBody());
    }
    System.debug('mapOfTrRecIdvsResponse: '+mapOfTrRecIdvsResponse);
    System.debug('mapOfTrRecIdvsTrId: '+mapOfTrRecIdvsTrId);
    updateResponseOnTransactionRecord(mapOfTrRecIdvsResponse, mapOfTrRecIdvsTrId);
}



    // Update Version 1.1 Starts Here 

    /**
     * @description Prepares broker registration payloads for Passfort, performs company profile callouts,
     *              stores response details, updates registration profile information, and creates related
     *              document transaction records when required.
     * @param transactionIDs Set of Passforttransaction__c record Ids to process for broker registration.
     */
    public static void prepareBrokerRegistrationJSON(Set<ID> transactionIDs) {
           //update version 1.2
    System.debug('================ BROKER PASSFORT DEBUG START ================');
    System.debug('Input Transaction Ids ==> ' + transactionIDs);
    //Update version 1.2 Ends
        Map<String, String> mapOfRegIdvsProfileId = new Map<String, String>();
        Map<String, String> mapOfTrRecIdvsResponse = new Map<String, String>();
        Map<String, String> mapOfTrRecIdvsTrId = new Map<String, String>();
        Map<String, String> mapOfTrRecIdvsDocIds = new Map<String, String>();
        
        for(Passforttransaction__c tempRecord : [
            SELECT Id, Registration__c, Registration__r.Company_Name_as_per_Trade_License__c,
            Registration__r.Company_Email_Address__c, Registration__r.Trade_License_Number__c,
            Registration__r.Street_Name__c, Registration__r.City__c, Registration__r.State__c,
            Registration__r.Postal_Code__c, Registration__r.Country__c,
            Registration__r.Mobile_Number__c, Registration__r.Website__c,
            Registration__r.Type_of_Registration__c, Registration__r.Expiry_Date__c,
            Registration__r.Issuance_Date__c, Registration__r.Licensing_Authority__c,
            Registration__r.UAE_VAT_Registration_Number__c,
            Registration__r.VAT_Certificate_Type__c, Registration__r.Bank_Name__c,
            Registration__r.Bank_Country__c, Registration__r.IBAN_Country_Bank_Code__c,
            Registration__r.Account_Number__c, Registration__r.SWIFT_Sort_Code__c,
            Registration__r.profileId__c, Registration__r.PassfortApprovalStatus__c,
            Registration__r.ProfileUpdateTime__c, Registration__r.LegalStructure__c,
            Registration__r.Description__c, Registration__r.PurposeOfTransaction__c,
            Registration__r.PaymentMethod__c, Registration__r.DeliveryChannel__c,
            Registration__r.NoOfPropertyPurchasedWithModon__c,
            Registration__r.SourceOfIncome__c, Registration__r.OtherSourceOfIncome__c,
            EntityType__c, TransactionId__c, ParentDocumentIds__c
            FROM Passforttransaction__c 
            WHERE Id IN :transactionIDs 
            AND Registration__c != null
            AND EntityType__c = :Constants.PASSFORT_TR_TYPE_COMPANY
            AND PassfortTransaction__c = NULL
        ]) {
               //update version 1.2 Starts here
        System.debug('Transaction Record Id ==> ' + tempRecord.Id);
        System.debug('Registration Id ==> ' + tempRecord.Registration__c);
        System.debug('TransactionId__c ==> ' + tempRecord.TransactionId__c);
        System.debug('Company Name ==> ' + tempRecord.Registration__r.Company_Name_as_per_Trade_License__c);
        System.debug('Email ==> ' + tempRecord.Registration__r.Company_Email_Address__c);
        System.debug('Trade License ==> ' + tempRecord.Registration__r.Trade_License_Number__c);
        System.debug('Country ==> ' + tempRecord.Registration__r.Country__c);
        System.debug('Source Of Income ==> ' + tempRecord.Registration__r.SourceOfIncome__c);
        System.debug('Other Source Of Income ==> ' + tempRecord.Registration__r.OtherSourceOfIncome__c);
        //update version 1.2 ends
            
            Boolean isCompany = true;
            
            PassfortTransactionWrapper objPTW = new PassfortTransactionWrapper();
            objPTW.id = tempRecord.TransactionId__c;
            objPTW.root_id = tempRecord.Registration__r.profileId__c;
            objPTW.invoke_type = objPTW.root_id != null ? Constants.BROKER_PASSFORT_INVOKE_TYPE_UPDATE : Constants.BROKER_PASSFORT_INVOKE_TYPE_CREATE;

            Boolean isRefresh = false;
            if(tempRecord.Registration__r.PassfortApprovalStatus__c == Constants.BROKER_PASSFORT_STATUS_APPROVED || 
               tempRecord.Registration__r.PassfortApprovalStatus__c == Constants.BROKER_PASSFORT_STATUS_REJECTED || 
               tempRecord.Registration__r.PassfortApprovalStatus__c == Constants.BROKER_PASSFORT_STATUS_REQUIRES_RESUBMISSION){
                   isRefresh = true;
               }
            
            objPTW.refresh = objPTW.invoke_type == Constants.BROKER_PASSFORT_INVOKE_TYPE_UPDATE && isRefresh
                ? Constants.BROKER_PASSFORT_REFRESH_YES
                : Constants.BROKER_PASSFORT_REFRESH_NO;
            objPTW.role = Constants.PASSFORT_TR_ROLE_COMPANY;
            
            PassfortTransactionWrapper.Product objPrd = new PassfortTransactionWrapper.Product();
            objPrd.alias = Constants.PASSFORT_TR_BR_ALIAS;
            PassfortTransactionWrapper.Applications objApp = new PassfortTransactionWrapper.Applications();
            objApp.product = objPrd;        
            objPTW.applications = new List<PassfortTransactionWrapper.Applications>{objApp};
                
            PassfortTransactionWrapper.Address objAdd = new PassfortTransactionWrapper.Address();        
            objAdd.type = Constants.PASSFORT_TR_STRUCTURED_ADDRESS_TYPE; 
            objAdd.country = NationalityVsCodes.containsKey(tempRecord.Registration__r.Country__c) ? 
                NationalityVsCodes.get(tempRecord.Registration__r.Country__c) : Constants.BROKER_PASSFORT_COUNTRY_CODE_ARE;
            objAdd.state_province = tempRecord.Registration__r.State__c;
            objAdd.county = tempRecord.Registration__r.Country__c;
            
            objAdd.Original_freeform_address = 
                tempRecord.Registration__r.Street_Name__c + ', ' + 
                tempRecord.Registration__r.City__c + ', ' + 
                tempRecord.Registration__r.Country__c + ', ' + 
                tempRecord.Registration__r.State__c + ', ' + 
                tempRecord.Registration__r.Postal_Code__c;
            
            PassfortTransactionWrapper.Addresses objAddr = new PassfortTransactionWrapper.Addresses();
            objAddr.address = objAdd;  
            objAddr.type = Constants.PASSFORT_TR_REGISTERED_ADDRESS_TYPE;

            PassfortTransactionWrapper.Tax_ids objtxIds = new PassfortTransactionWrapper.Tax_ids();
            objtxIds.tax_id_type = Constants.BROKER_PASSFORT_TAX_ID_TYPE_VAT;
            objtxIds.value = tempRecord.Registration__r.UAE_VAT_Registration_Number__c;
            
            PassfortTransactionWrapper.Metadata objMtd = new PassfortTransactionWrapper.Metadata();
            objMtd.country_of_incorporation = Constants.BROKER_PASSFORT_COUNTRY_CODE_ARE;
            objMtd.bvd_id = Constants.BROKER_PASSFORT_DEFAULT_BVD_ID;
            objMtd.name = tempRecord.Registration__r.Company_Name_as_per_Trade_License__c;
            objMtd.incorporation_date = dateFormation(tempRecord.Registration__r.Issuance_Date__c);
            objMtd.company_number = tempRecord.Registration__r.Trade_License_Number__c;
            objMtd.tax_ids = new List<PassfortTransactionWrapper.Tax_ids>{objtxIds};
            objMtd.addresses = new List<PassfortTransactionWrapper.Addresses>{objAddr};
 
            PassfortTransactionWrapper.Custom_fields_data objCustFldata = new PassfortTransactionWrapper.Custom_fields_data();
            //vesrion 1.3 starts here
            objCustFldata.s_customer_risk =String.isNotBlank(tempRecord.Registration__r.LegalStructure__c)? tempRecord.Registration__r.LegalStructure__c: Constants.BROKER_PASSFORT_DEFAULT_CUSTOMER_RISK;
            //version 1.3 ends here
       
            objCustFldata.s_trade_license = tempRecord.Registration__r.Trade_License_Number__c;
            objCustFldata.d_trade_license_expiry_date = dateFormation(tempRecord.Registration__r.Expiry_Date__c);
            objCustFldata.s_purpose_of_transaction = String.isNotBlank(tempRecord.Registration__r.PurposeOfTransaction__c) ? 
                tempRecord.Registration__r.PurposeOfTransaction__c : Constants.BROKER_PASSFORT_DEFAULT_PURPOSE_OF_TRANSACTION;
            objCustFldata.s_description_of_business_activity = tempRecord.Registration__r.Description__c;
            objCustFldata.s_source_of_income = String.isNotBlank(tempRecord.Registration__r.SourceOfIncome__c) ? 
                tempRecord.Registration__r.SourceOfIncome__c : Constants.BROKER_PASSFORT_DEFAULT_SOURCE_OF_INCOME;
            objCustFldata.s_source_of_income_explanation = String.isNotBlank(tempRecord.Registration__r.OtherSourceOfIncome__c) ? 
                tempRecord.Registration__r.OtherSourceOfIncome__c : Constants.BROKER_PASSFORT_DEFAULT_EMPTY;
            objCustFldata.s_transaction_specific_risk = String.isNotBlank(tempRecord.Registration__r.PaymentMethod__c) ? 
                tempRecord.Registration__r.PaymentMethod__c : Constants.BROKER_PASSFORT_DEFAULT_TRANSACTION_SPECIFIC_RISK;
            objCustFldata.s_channel_risk = String.isNotBlank(tempRecord.Registration__r.DeliveryChannel__c) ? 
                tempRecord.Registration__r.DeliveryChannel__c : Constants.BROKER_PASSFORT_DEFAULT_CHANNEL_RISK;
            objCustFldata.n_inventory_count = tempRecord.Registration__r.NoOfPropertyPurchasedWithModon__c == null ? 
                Constants.BROKER_PASSFORT_DEFAULT_EMPTY : tempRecord.Registration__r.NoOfPropertyPurchasedWithModon__c.toString();
            /*update version 1.2 starts Here
            @description: As contacts isn't required For broker compliance 
            commented it out'*/
            /*PassfortTransactionWrapper.Contact_details objConDet = new PassfortTransactionWrapper.Contact_details();
            objConDet.phone_number = tempRecord.Registration__r.Mobile_Number__c != null ? 
                tempRecord.Registration__r.Mobile_Number__c : Constants.BROKER_PASSFORT_DEFAULT_EMPTY;
            objConDet.email = tempRecord.Registration__r.Company_Email_Address__c != null ? 
                tempRecord.Registration__r.Company_Email_Address__c : Constants.BROKER_PASSFORT_DEFAULT_EMPTY;*/
                /*Update version 1.2 Ends Here*/

            PassfortTransactionWrapper.collected_data objColData = new PassfortTransactionWrapper.collected_data();
            objColData.entity_type = Constants.PASSFORT_ENTITY_TYPE_COMPANY;
            objColData.custom_fields_data = objCustFldata;
            objColData.metadata = objMtd;
            //Update version 1.2
           //objColData.contact_details = objConDet;
            objColData.addresses = new List<PassfortTransactionWrapper.Addresses>{objAddr};
            objPTW.collected_data = objColData;
            
            String jsonString = Json.serialize(objPTW);
            String endpointURL = Constants.PASSFORT_TR_COMPANY_ENDPOINT;
               //update version 1.2 Starts Here
        System.debug('FULL REQUEST JSON ==> ' + JSON.serializePretty(objPTW));
        System.debug('ENDPOINT ==> ' + endpointURL);
        //update version 1.2 Ends here

            HTTPResponse res = makeapiCallout(endpointURL, jsonString);
            
        //update version 1.2 Starts Here
        System.debug('RESPONSE STATUS CODE ==> ' + (res != null ? res.getStatusCode() : null));
        System.debug('RESPONSE STATUS ==> ' + (res != null ? res.getStatus() : null));
        System.debug('RESPONSE BODY ==> ' + (res != null ? res.getBody() : null));
        //Update version 1.2 Ends Here

            if(res != null && res.getStatus() == Constants.BROKER_PASSFORT_RESPONSE_STATUS_OK){
                String body = res.getBody();
                if(String.isNotBlank(body) && body != Constants.BROKER_PASSFORT_EMPTY_JSON_RESPONSE){
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(body);
                    String profileID = (String) responseMap.get('root_id');
                    String responseStatus = (String) responseMap.get('status');
                    
                    if(responseStatus == Constants.PASSFORT_TR_SUCCESS && String.isNotBlank(profileID)){
                        mapOfTrRecIdvsTrId.put(tempRecord.Id, tempRecord.TransactionId__c + ':' + profileID);
                        
                        if(String.isNotBlank(tempRecord.ParentDocumentIds__c)) {
                            mapOfTrRecIdvsDocIds.put(tempRecord.Id, tempRecord.ParentDocumentIds__c);
                        }
                        
                        mapOfRegIdvsProfileId.put(tempRecord.Registration__c, profileID);
                    }
                }
            }
            mapOfTrRecIdvsResponse.put(tempRecord.Id, res != null ? res.getBody() : Constants.BROKER_PASSFORT_DEFAULT_EMPTY);
        }
        
        updateRegistrationRecords(mapOfRegIdvsProfileId);
        updateResponseOnTransactionRecord(mapOfTrRecIdvsResponse, mapOfTrRecIdvsTrId);
        
        if (!mapOfTrRecIdvsDocIds.isEmpty()) {
            Set<Id> parentIdsWithDocs = new Set<Id>();
            for(Passforttransaction__c doc : [
                SELECT PassfortTransaction__c 
                FROM Passforttransaction__c 
                WHERE PassfortTransaction__c IN :mapOfTrRecIdvsDocIds.keySet()
                AND EntityType__c = :Constants.PASSFORT_TR_TYPE_DOCUMENT
                LIMIT 1
            ]) {
                parentIdsWithDocs.add(doc.PassfortTransaction__c);
            }

            Map<String,String> filteredDocIds = new Map<String,String>();
            for(String trId : mapOfTrRecIdvsDocIds.keySet()) {
                if(!parentIdsWithDocs.contains(trId)) {
                    filteredDocIds.put(trId, mapOfTrRecIdvsDocIds.get(trId));
                }
            }

            if (!filteredDocIds.isEmpty()) {
                createDocumentTransactionRecords(filteredDocIds);
            }
        }
    }

    /**
     * @description Updates broker registration records with Passfort profile Id, review status,
     *              and latest profile update timestamp.
     * @param mapOfRegIdvsProfileId Map of Registration__c Id to Passfort profile Id.
     */
    public static void updateRegistrationRecords(Map<String, String> mapOfRegIdvsProfileId) {
        List<Registration__c> regsToUpdate = new List<Registration__c>();
        
        for(Id regId : mapOfRegIdvsProfileId.keySet()){
            Registration__c reg = new Registration__c();
            reg.Id = regId;
            reg.profileId__c = mapOfRegIdvsProfileId.get(regId);
            reg.PassfortApprovalStatus__c = Constants.PASSFORT_APPROVAL_STATUS_IN_REVIEW;
            reg.ProfileUpdateTime__c = System.now();
            regsToUpdate.add(reg);
        }
        
        if(regsToUpdate.size() > 0) {
            Database.update(regsToUpdate, false);
        }
    }

    //Update Version 1.1 Ends Here
}