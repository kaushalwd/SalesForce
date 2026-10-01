/**********************************************************************************************************************
* Name               : PassfortTransactionProcessHelper                                                        
* Description        : This class is used to form JSON request and make document upload api callout for passfort transactions of profiles and their documents
* Usage              : Called from PassfortTransactionProcessBatch
* Created By         : PWC IN                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                Date            Comment                                                                       
* 1.0       kishor.sitaram.chaudhari@pwc.com         20 May 2024      Initial Draft   
* 2.0       Dinesh Selvam                            25 Dec 2025      Adding "USA" Mapping Value
* 3.0       MODON CRM TEAM                           13 Jan 2026      Added "Commonwealth of Dominica" value in NationalityVsCodes MAP
* 4.0       MODON CRM TEAM                           25 Mar 2026      Added ProjectInterest__c in Payload
* 5.0       Kumaravel                                26 Mar 2026      Added gender / unit name / source of incomce in Payload
*6.0        Raghu Sharma                             03 Apr 2026      Added Broker Related if block and a Boolean condition to fetch all broker files
*7.0        Sireesha                                 17 Apr 2026      Added Project name if complaince requested from Account and for commertial Plots
*8.0        Arvind                                   10 June 2026     Added the changes for Street Integration
*9.0        Arvind                                   19 June 2026     Fix: Bypass duplicate rule on Account/Contact update
*10.0       Arvind                                   23 June 2026     Fix: Reset JointOwnerCount and primaryApplicantName per record to prevent carryover across records in batch processing
*11.0       Arvind                                   23 June 2026     Fix: s_joint_applicant_name now sends correct name based on whether current contact is primary buyer or joint owner                                                                   
*12.0       Siva                                   17 July 2026     Fix: Resale Product Alis Fix
*13.0.      MODON CRM TEAM                           21 July 2026     Added "Kosovo" value in Nationality NationalityVsCodes
*14.0.      Siva                                   15 AUG 2026     Added flag for commertial plots and secondary matket flags by Siva-15/08/2026
******************************************************************************************************************/

public class PassfortTransactionProcessHelper {
 private Set<ID> trIds;
    //*13.0
    //Start
    static Map<String, String> NationalityVsCodes = new Map<String, String>{
            'Afghanistan'=>'AFG','Albania'=>'ALB','Algeria'=>'DZA','American Samoa'=>'ASM','Andorra'=>'AND','Angola'=>'AGO','Anguilla'=>'AIA','Antarctica'=>'ATA','Antigua and Barbuda'=>'ATG','Argentina'=>'ARG','Armenia'=>'ARM','Aruba'=>'ABW','Australia'=>'AUS','Austria'=>'AUT','Azerbaijan'=>'AZE','Bahamas'=>'BHS','Bolivia'=>'BOL','British Virgin Islands'=>'VGB','Brunei'=>'BRN',
            'Bahrain'=>'BHR','Bangladesh'=>'BGD','Barbados'=>'BRB','Belarus'=>'BLR','Belgium'=>'BEL','Belize'=>'BLZ','Benin'=>'BEN','Bermuda'=>'BMU','Bhutan'=>'BTN','Bosnia and Herzegovina'=>'BIH','Botswana'=>'BWA','Bouvet Island'=>'BVT','Brazil'=>'BRA','British Indian Ocean Territory'=>'IOT','Bulgaria'=>'BGR','Burkina Faso'=>'BFA','Burundi'=>'BDI',
            'Cambodia'=>'KHM','Cameroon'=>'CMR','Canada'=>'CAN','Chad'=>'TCD','Chile'=>'CHL','China'=>'CHN','Christmas Island'=>'CXR','Colombia'=>'COL','Costa Rica'=>'CRI','Croatia'=>'HRV','Cuba'=>'CUB','Cyprus'=>'CYP','Cape Verde'=>'CPV','Cayman Islands'=>'CYM','Central African Republic'=>'CAF','Cocos [Keeling] Islands'=>'CCK','Comoros'=>'COM','Congo [DRC]'=>'COD','Congo [Republic]'=>'COG','Cook Islands'=>'COK','Cote d\'Ivoire'=>'CIV','Czech Republic'=>'CZE',
            'Denmark'=>'DNK','Djibouti'=>'DJI','Commonwealth of Dominica'=>'DMA','Dominica'=>'DMA','Dominican Republic'=>'DOM','Ecuador'=>'ECU','Egypt'=>'EGY','El Salvador'=>'SLV','Equatorial Guinea'=>'GNQ','Eritrea'=>'ERI','Estonia'=>'EST','Ethiopia'=>'ETH',
            'Fiji'=>'FJI','Finland'=>'FIN','France'=>'FRA','French Guiana'=>'GUF','French Polynesia'=>'PYF','Falkland Islands [Islas Malvinas]'=>'FLK','Faroe Islands'=>'FRO','French Southern Territories'=>'ATF',
            'Gabon'=>'GAB','Georgia'=>'GEO','Germany'=>'DEU','Ghana'=>'GHA','Gibraltar'=>'GIB','Greece'=>'GRC','Greenland'=>'GRL','Grenada'=>'GRD','Guadeloupe'=>'GLP','Guam'=>'GUM','Guatemala'=>'GTM','Guernsey'=>'GGY','Guinea'=>'GIN','Guinea-Bissau'=>'GNB','Guyana'=>'GUY','Gambia'=>'GMB',
            'Haiti'=>'HTI','Heard Island and McDonald Islands'=>'HMD','Honduras'=>'HND','Hong Kong'=>'HKG','Hungary'=>'HUN','Iceland'=>'ISL','India'=>'IND','Indonesia'=>'IDN','Iraq'=>'IRQ','Ireland'=>'IRL','Isle of Man'=>'IMN','Israel'=>'ISR','Italy'=>'ITA','Iran'=>'IRN',
            'Jamaica'=>'JAM','Japan'=>'JPN','Jersey'=>'JEY','Jordan'=>'JOR','Kazakhstan'=>'KAZ','Kenya'=>'KEN','Kiribati'=>'KIR','Kosovo'=>'XKX','Kuwait'=>'KWT','Kyrgyzstan'=>'KGZ','Latvia'=>'LVA','Laos'=>'LAO','Lebanon'=>'LBN','Lesotho'=>'LSO','Liberia'=>'LBR','Libya'=>'LBY','Liechtenstein'=>'LIE','Lithuania'=>'LTU','Luxembourg'=>'LUX','Macedonia [FYROM]'=>'MKD',
            'Madagascar'=>'MDG','Malawi'=>'MWI','Malaysia'=>'MYS','Maldives'=>'MDV','Mali'=>'MLI','Malta'=>'MLT','Martinique'=>'MTQ','Mauritania'=>'MRT','Mauritius'=>'MUS','Mayotte'=>'MYT','Mexico'=>'MEX','Monaco'=>'MCO','Mongolia'=>'MNG','Montenegro'=>'MNE','Montserrat'=>'MSR','Morocco'=>'MAR','Mozambique'=>'MOZ','Macau'=>'MAC','Marshall Islands'=>'MHL','Micronesia'=>'FSM','Moldova'=>'MDA','Myanmar [Burma]'=>'MMR',
            'Namibia'=>'NAM','Nauru'=>'NRU','Nepal'=>'NPL','New Caledonia'=>'NCL','New Zealand'=>'NZL','Nicaragua'=>'NIC','Nigeria'=>'NGA','Niue'=>'NIU','Norfolk Island'=>'NFK','Norway'=>'NOR','Netherlands'=>'NLD','Niger'=>'NER','Northern Mariana Islands'=>'MNP','North Korea'=>'PRK','Oman'=>'OMN','Pakistan'=>'PAK','Palau'=>'PLW','Panama'=>'PAN','Papua New Guinea'=>'PNG','Paraguay'=>'PRY','Peru'=>'PER','Poland'=>'POL','Portugal'=>'PRT','Puerto Rico'=>'PRI',
            'Palestinian Territories'=>'PSE','Philippines'=>'PHL','Pitcairn Islands'=>'PCN','Qatar'=>'QAT','Russia'=>'RUS','Reunion'=>'REU','Romania'=>'ROU','Rwanda'=>'RWA','Saint Kitts and Nevis'=>'KNA','Saint Lucia'=>'LCA','Saint Pierre and Miquelon'=>'SPM','Saint Vincent and the Grenadines'=>'VCT','Samoa'=>'WSM','San Marino'=>'SMR','Sao Tome and Principe'=>'STP','Saudi Arabia'=>'SAU','Senegal'=>'SEN','Serbia'=>'SRB','Seychelles'=>'SYC','Sierra Leone'=>'SLE',
            'Singapore'=>'SGP','Slovakia'=>'SVK','Slovenia'=>'SVN','Solomon Islands'=>'SLB','Somalia'=>'SOM','South Africa'=>'ZAF','South Georgia and the South Sandwich Islands'=>'SGS','South Korea'=>'KOR','Spain'=>'ESP','Sri Lanka'=>'LKA','Suriname'=>'SUR','Svalbard and Jan Mayen'=>'SJM','Switzerland'=>'CHE','Saint Helena'=>'SHN','Sudan'=>'SDN','Swaziland'=>'SWZ','Sweden'=>'SWE','Syria'=>'SYR',
            'Tajikistan'=>'TJK','Thailand'=>'THA','Timor-Leste'=>'TLS','Togo'=>'TGO','Tokelau'=>'TKL','Tonga'=>'TON','Trinidad and Tobago'=>'TTO','Tunisia'=>'TUN','Turkey'=>'TUR','Turkmenistan'=>'TKM','Tuvalu'=>'TUV','Taiwan'=>'TWN','Tanzania'=>'TZA','Turks and Caicos Islands'=>'TCA','U.S. Minor Outlying Islands'=>'UMI','U.S. Virgin Islands'=>'VIR','United Arab Emirates'=>'ARE','United Kingdom'=>'GBR','United States'=>'USA','United States of America'=>'USA','Uganda'=>'UGA','Ukraine'=>'UKR','Uruguay'=>'URY','Uzbekistan'=>'UZB',
            'Vanuatu'=>'VUT','Vatican City'=>'VAT','Venezuela'=>'VEN','Vietnam'=>'VNM','Wallis and Futuna'=>'WLF','Western Sahara'=>'ESH','Yemen'=>'YEM','Zambia'=>'ZMB','Zimbabwe'=>'ZWE'}; /** 2.0 Added the "USA" Country code mapping for 'United States' & 'United States of America **/ /** 3.0 Added "Commonwealth of Dominica" value in NationalityVsCodes MAP **/ //*13.0  Added "Kosovo" value in Nationality NationalityVsCodes- END

                
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
        
        List<Passforttransaction__c> lstPassfortTransaction = [Select Id,Contact__c,Account__c,EntityType__c,transactionId__c,Opportunity__c,Sales_Order__c from Passforttransaction__c where id in :transactionIDs and PassfortTransaction__c = Null];
        for(Passforttransaction__c objPT :lstPassfortTransaction){
            if(objPT.Opportunity__c!=null)
            PTOppIds.add(objPT.Opportunity__c);
            
            if(objPT.Sales_Order__c!=null)
            PTSOIds.add(objPT.Sales_Order__c);
        }
        Map<ID,Integer> mapOfOppVsNoOfJO = new Map<ID,Integer>();
        Map<ID,Integer> mapOfSOVsNoOfJO = new Map<ID,Integer>();

        // 11.0 Arvind Start - Maps to store first JointOwnerAccount name and ID per Opp/SO
        Map<ID,String> mapOfOppVsJOName  = new Map<ID,String>();
        Map<ID,String> mapOfSOVsJOName   = new Map<ID,String>();
        Map<ID,Id>     mapOfOppVsJOAccId = new Map<ID,Id>();
        Map<ID,Id>     mapOfSOVsJOAccId  = new Map<ID,Id>();
        // 11.0 Arvind End

        // 11.0 Arvind - Added JointOwnerAccount__c and JointOwnerAccount__r.Name to query
        List<JointOwner__c> lstJointOwner = [
            Select Id, Name,
                   JointOwnerAccount__c,
                   JointOwnerAccount__r.Name,
                   Opportunity__c,
                   SalesOrder__c
            from JointOwner__c
            Where Opportunity__r.Id IN :PTOppIds
            OR SalesOrder__r.Id IN :PTSOIds
            order by Opportunity__c, SalesOrder__c
        ];

        for(JointOwner__c objJO : lstJointOwner){
            // existing count logic — unchanged
            if(mapOfOppVsNoOfJO.containsKey(objJO.Opportunity__c)){
                integer no = mapOfOppVsNoOfJO.get(objJO.Opportunity__c);
                mapOfOppVsNoOfJO.put(objJO.Opportunity__c,no+1);
            }else
                mapOfOppVsNoOfJO.put(objJO.Opportunity__c,1);
            
            if(mapOfSOVsNoOfJO.containsKey(objJO.SalesOrder__c)){
                integer num = mapOfSOVsNoOfJO.get(objJO.SalesOrder__c);
                mapOfSOVsNoOfJO.put(objJO.SalesOrder__c,num+1);
            }else
                mapOfSOVsNoOfJO.put(objJO.SalesOrder__c,1);

            // 11.0 Arvind Start - Store FIRST JointOwnerAccount name and ID only
            // In case of multiple joint owners only the first one is used
            if(objJO.Opportunity__c != null
               && !mapOfOppVsJOAccId.containsKey(objJO.Opportunity__c)){
                mapOfOppVsJOAccId.put(objJO.Opportunity__c, objJO.JointOwnerAccount__c);
                mapOfOppVsJOName.put(objJO.Opportunity__c, objJO.JointOwnerAccount__r.Name);
            }
            if(objJO.SalesOrder__c != null
               && !mapOfSOVsJOAccId.containsKey(objJO.SalesOrder__c)){
                mapOfSOVsJOAccId.put(objJO.SalesOrder__c, objJO.JointOwnerAccount__c);
                mapOfSOVsJOName.put(objJO.SalesOrder__c, objJO.JointOwnerAccount__r.Name);
            }
            // 11.0 Arvind End
        }

        Integer JointOwnerCount=0;
        //4.0 Start
        //Added flag for commertial plots and secondary matket flags by Siva-15/08/2026
        for(Passforttransaction__c tempRecord : [Select Id,Contact__r.MailingStreet,Account__r.BillingStreet,Contact__c,Contact__r.FirstName,Contact__r.MobilePhone,Contact__r.MiddleName,Contact__r.LastName,Contact__r.Birthdate,Contact__r.Nationality__c,Contact__r.Title,Contact__r.Phone,Contact__r.Email,Contact__r.MailingCity,Contact__r.MailingState,Contact__r.MailingCountry,Contact__r.MailingAddress,
                                                 Contact__r.UAE_Resident_Status__c,Contact__r.Occupation__c,Contact__r.PurposeOfTransaction__c,Contact__r.SourceOfIncome__c,Contact__r.OtherSourceOfIncome__c,Contact__r.DeliveryChannel__c,Contact__r.AreYouRealBeneficiaryOfThis__c,Contact__r.NoOfPropertyPurchasedWithModon__c,
                                                 Contact__r.EIDNumber__c,Contact__r.PassportNumber__c,Contact__r.PaymentMethod__c,Contact__r.profileId__c,Contact__r.EmployerBusinessName__c,Contact__r.PassfortApprovalStatus__c,Contact__r.AreYouPoliticallyExposedPersonPEP__c,
                                                 Contact__r.AccountId,
                                                 Account__c,Account__r.Name,Account__r.BillingCity,Account__r.BillingCountry,Account__r.BillingState,Account__r.BillingAddress,Account__r.LegalStructure__c,Account__r.UnifiedNumber__c,Account__r.UAEVATRegisterNumber__c,Account__r.DateOfEstablishment__c,Account__r.PassfortApprovalStatus__c,
                                                 Account__r.TradeLicenseExpiryDate__c,Account__r.Description,Account__r.AccountNumber,Account__r.profileId__c,Account__r.PurposeOfTransaction__c,Account__r.PaymentMethod__c,Account__r.DeliveryChannel__c,Account__r.NoOfPropertyPurchasedWithModon__c,Account__r.SourceOfIncome__c,Account__r.OtherSourceOfIncome__c,
                                                 EntityType__c,transactionId__c,Document__c,PassfortTransaction__c,ParentDocumentIds__c,Opportunity__c,Sales_Order__c,Linked_Shareholder_Details__c, Sales_Order__r.Opportunity__r.Account.Name, Opportunity__r.Account.Name, Sales_Order__r.ProjectName__c, Sales_Order__r.Unit__r.Name, Opportunity__r.Project__r.Name, Opportunity__r.ProjectInterest__c, Contact__r.GenderIdentity,
                                                 Account__r.Resale_Account__C,Contact__r.Account.Resale_Account__c,Is_Commercial__c,Is_Secondary_Market__c
                                                 from Passforttransaction__c where id in :transactionIDs and PassfortTransaction__c = Null]){//4.0 End
                                                  //8.0 Arvind the Query for Street   

                                                     // 10.0 Arvind Start - Reset per-record variables to prevent value carryover across records in batch processing
                                                     JointOwnerCount = 0;
                                                     String primaryApplicantName = null;
                                                     // 10.0 Arvind End

                                                     PassfortTransactionWrapper objPTW = new PassfortTransactionWrapper();
                                                     boolean isCompany = false;
                                                     
                                                     if(tempRecord.EntityType__c == Constants.PASSFORT_TR_TYPE_COMPANY || tempRecord.EntityType__c == Constants.PASSFORT_TR_TYPE_SHAREHOLDER_LINK)
                                                         isCompany = true;
                                                     
                                                     objPTW.id = tempRecord.transactionId__c;
                                                     objPTW.root_id = isCompany? tempRecord.Account__r.profileId__c: tempRecord.Contact__r.profileId__c;
                                                     objPTW.invoke_type = tempRecord.EntityType__c == Constants.PASSFORT_TR_TYPE_SHAREHOLDER_LINK?'Update_link':objPTW.root_id != null ? 'Update':'Create';   
                                                    
                                                     boolean isRefresh = false;
                                                     if(isCompany && (tempRecord.Account__r.PassfortApprovalStatus__c == 'Approved' || tempRecord.Account__r.PassfortApprovalStatus__c == 'Rejected' || tempRecord.Account__r.PassfortApprovalStatus__c =='Requires Resubmission'))
                                                      isRefresh = true;
                                                     if(!isCompany && (tempRecord.Contact__r.PassfortApprovalStatus__c == 'Approved' || tempRecord.Contact__r.PassfortApprovalStatus__c == 'Rejected' || tempRecord.Account__r.PassfortApprovalStatus__c =='Requires Resubmission'))
                                                      isRefresh = true;
                                                     
                                                     objPTW.refresh = objPTW.invoke_type =='Update' && (isRefresh)?'yes':'no';
                                                     
                                                     objPTW.role = isCompany? Constants.PASSFORT_TR_ROLE_COMPANY : tempRecord.EntityType__c == Constants.PASSFORT_TR_TYPE_SHAREHOLDER? Constants.PASSFORT_TR_ROLE_INDIVIDUAL_ASSOCIATED:Constants.PASSFORT_TR_ROLE_INDIVIDUAL;
                                                         //updated as part of Version 7.0
                                                         //PassfortTransactionWrapper.Product objPrd = new PassfortTransactionWrapper.Product();
                                                         //objPrd.alias = Constants.PASSFORT_TR_ALIAS;
                                                         String projectValue = getProjectValue(tempRecord);
                                                     PassfortTransactionWrapper.Product objPrd = new PassfortTransactionWrapper.Product();
                                                        objPrd.alias = getProductAlias(projectValue,tempRecord);
                                                    
                                                     PassfortTransactionWrapper.Applications objApp = new PassfortTransactionWrapper.Applications();
                                                     objApp.product = objPrd;        
                                                     objPTW.applications  = new List<PassfortTransactionWrapper.Applications>{objApp};
                                                         
                                                     /*Start-- Address */
                                                     PassfortTransactionWrapper.Address objAdd = new PassfortTransactionWrapper.Address();        
                                                     objAdd.type = Constants.PASSFORT_TR_STRUCTURED_ADDRESS_TYPE; 
                                                     objAdd.country = NationalityVsCodes.containsKey(isCompany? tempRecord.Account__r.BillingCountry : tempRecord.Contact__r.MailingCountry) ? NationalityVsCodes.get(isCompany? tempRecord.Account__r.BillingCountry : tempRecord.Contact__r.MailingCountry) : 'ARE';  
                                                     objAdd.state_province = isCompany? tempRecord.Account__r.BillingState : tempRecord.Contact__r.MailingState; 
                                                     objAdd.county = isCompany? tempRecord.Account__r.BillingCity : tempRecord.Contact__r.MailingCity;
                                                     objAdd.route = isCompany? tempRecord.Account__r.BillingStreet : tempRecord.Contact__r.MailingStreet; // 8.0 Arvind Map the Street to the Route
                                                     
                                                     Address addr;
                                                     if(isCompany)
                                                         addr = tempRecord.Account__r.BillingAddress; 
                                                     else
                                                         addr = tempRecord.Contact__r.MailingAddress; 
                                                     if(addr!=null)
                                                         objAdd.Original_freeform_address =  addr.getStreet()+', '+addr.getCity()+', '+addr.getCountry()+', '+addr.getState()+', '+addr.getPostalCode();  
                                                     
                                                     if(tempRecord.EntityType__c != Constants.PASSFORT_TR_TYPE_SHAREHOLDER){
                                                         objAddr = new PassfortTransactionWrapper.Addresses();
                                                         objAddr.address = objAdd;  
                                                         objAddr.type = isCompany? Constants.PASSFORT_TR_REGISTERED_ADDRESS_TYPE : Constants.PASSFORT_TR_STRUCTURED_ADDRESS_TYPE;
                                                     }
                                                     /*End-- Address */                                                     
                                                     
                                                     if(!isCompany){
                                                         /*Start-- Personal Details */          
                                                         PassfortTransactionWrapper.Name objName = new PassfortTransactionWrapper.Name();
                                                         objName.given_names = new List<String>{tempRecord.Contact__r.FirstName, tempRecord.Contact__r.MiddleName};
                                                         objName.family_name = tempRecord.Contact__r.LastName;
                                                         objName.title = tempRecord.Contact__r.Title;
                                                         
                                                         objperDet = new PassfortTransactionWrapper.Personal_details();
                                                         objperDet.name = objName;
                                                         objperDet.dob = dateFormation(tempRecord.Contact__r.Birthdate);//tempRecord.Contact__r.Birthdate.Year().ToString();
                                                         objperDet.nationality = NationalityVsCodes.get(tempRecord.Contact__r.Nationality__c);
                                                         // 5.0
                                                         if(tempRecord.Contact__r.GenderIdentity == 'Male' || tempRecord.Contact__r.GenderIdentity == 'Female'){
                                                            objperDet.gender = tempRecord.Contact__r.GenderIdentity; 
                                                         }                      
                                                         //objperDet.gender = tempRecord.Contact__r.GenderIdentity; 
                                                         /*End-- Personal Details */  
                                                         
                                                         if(tempRecord.EntityType__c != Constants.PASSFORT_TR_TYPE_SHAREHOLDER){ 
                                                             /*Start-- Contact Details */  
                                                             objConDet = new PassfortTransactionWrapper.Contact_details();
                                                             objConDet.phone_number = tempRecord.Contact__r.MobilePhone !=null ? tempRecord.Contact__r.MobilePhone.ToString():'';
                                                             objConDet.email = tempRecord.Contact__r.Email.ToString();
                                                             /*End-- Contact Details */  
                                                         }
                                                     }
                                                     
                                                     /*Start-- Custom Fields */ 
                                                     PassfortTransactionWrapper.Custom_fields_data objCustFldata = new PassfortTransactionWrapper.Custom_fields_data();
                                                     if(!isCompany && tempRecord.EntityType__c != Constants.PASSFORT_TR_TYPE_SHAREHOLDER){
                                                        //4.0 Start
                                                        // 10.0 Arvind - primaryApplicantName declared at loop level and reset above, removing local declaration here
                                                             // updated as part of Version 7.0
                                                             String projectValueInd = getProjectValue(tempRecord);
                                                         /*if(tempRecord.Sales_Order__c!=null && mapOfSOVsNoOfJO.containsKey(tempRecord.Sales_Order__c)) {
                                                            JointOwnerCount=mapOfSOVsNoOfJO.get(tempRecord.Sales_Order__c);
                                                            primaryApplicantName = tempRecord.Sales_Order__r.Opportunity__r.Account.Name;
                                                            objCustFldata.s_project_name = tempRecord.Sales_Order__r.ProjectName__c;
                                                         } else if(tempRecord.Opportunity__c!=null && mapOfOppVsNoOfJO.containsKey(tempRecord.Opportunity__c)) {
                                                            JointOwnerCount=mapOfOppVsNoOfJO.get(tempRecord.Opportunity__c);
                                                            primaryApplicantName = tempRecord.Opportunity__r.Account.Name;
                                                          //objCustFldata.s_project_name = tempRecord.Opportunity__r.Project__r.Name;
                                                            objCustFldata.s_project_name = tempRecord.Opportunity__r.ProjectInterest__c;
                                                         }*/
                                                         if(tempRecord.Sales_Order__c != null) { 
                                                             if(mapOfSOVsNoOfJO.containsKey(tempRecord.Sales_Order__c)) {
                                                                 JointOwnerCount = mapOfSOVsNoOfJO.get(tempRecord.Sales_Order__c);
                                                             }
                                                             // 11.0 Arvind Start - Smart joint applicant name logic for Sales Order
                                                             // Check if current contact is the joint owner or primary buyer
                                                             Id joAccId = mapOfSOVsJOAccId.get(tempRecord.Sales_Order__c);
                                                             if(joAccId != null && joAccId == tempRecord.Contact__r.AccountId){
                                                                 // Current contact IS the joint owner → send primary buyer name
                                                                 primaryApplicantName = tempRecord.Sales_Order__r.Opportunity__r.Account.Name;
                                                             } else {
                                                                 // Current contact IS the primary buyer → send joint owner name
                                                                 if(mapOfSOVsJOName.containsKey(tempRecord.Sales_Order__c)){
                                                                     primaryApplicantName = mapOfSOVsJOName.get(tempRecord.Sales_Order__c);
                                                                 }
                                                             }
                                                             // 11.0 Arvind End
                                                             objCustFldata.s_unit_name = tempRecord.Sales_Order__r.Unit__r.Name; //5.0

                                                         } else if(tempRecord.Opportunity__c != null) {
                                                             if(mapOfOppVsNoOfJO.containsKey(tempRecord.Opportunity__c)) {
                                                                 JointOwnerCount = mapOfOppVsNoOfJO.get(tempRecord.Opportunity__c);
                                                             }
                                                             // 11.0 Arvind Start - Smart joint applicant name logic for Opportunity
                                                             // Check if current contact is the joint owner or primary buyer
                                                             Id joAccId = mapOfOppVsJOAccId.get(tempRecord.Opportunity__c);
                                                             if(joAccId != null && joAccId == tempRecord.Contact__r.AccountId){
                                                                 // Current contact IS the joint owner → send primary buyer name
                                                                 primaryApplicantName = tempRecord.Opportunity__r.Account.Name;
                                                             } else {
                                                                 // Current contact IS the primary buyer → send joint owner name
                                                                 if(mapOfOppVsJOName.containsKey(tempRecord.Opportunity__c)){
                                                                     primaryApplicantName = mapOfOppVsJOName.get(tempRecord.Opportunity__c);
                                                                 }
                                                             }
                                                             // 11.0 Arvind End
                                                             objCustFldata.s_unit_name = tempRecord.Sales_Order__r.Unit__r.Name; // 5.0
                                                         }//4.0 End
                                                             // updated as part of Version 7.0
                                                             objCustFldata.s_project_name = projectValueInd;
                                                         objCustFldata.s_applicant_ownership= JointOwnerCount==0?'Single':JointOwnerCount==1?'Joint':'Multiple'; 
                                                         objCustFldata.s_residence_status= tempRecord.Contact__r.UAE_Resident_Status__c;
                                                         objCustFldata.s_occupation= tempRecord.Contact__r.Occupation__c;
                                                         objCustFldata.s_purpose_of_transaction_1= tempRecord.Contact__r.PurposeOfTransaction__c;             
                                                         objCustFldata.s_source_of_income_1= tempRecord.Contact__r.SourceOfIncome__c;
                                                         objCustFldata.s_source_of_income_explanation_1= tempRecord.Contact__r.OtherSourceOfIncome__c;                
                                                         objCustFldata.s_are_you_the_real_beneficiary_of_this_transaction=tempRecord.Contact__r.AreYouRealBeneficiaryOfThis__c?'yes':'no';                
                                                         objCustFldata.s_eid=tempRecord.Contact__r.EIDNumber__c;
                                                         objCustFldata.s_passport_number=tempRecord.Contact__r.PassportNumber__c;
                                                         objCustFldata.s_employer_business_name=tempRecord.Contact__r.EmployerBusinessName__c;
                                                         objCustFldata.s_transaction_specific_risk= tempRecord.Contact__r.PaymentMethod__c;
                                                         objCustFldata.s_channel_risk=tempRecord.Contact__r.DeliveryChannel__c;
                                                         objCustFldata.s_pep=tempRecord.Contact__r.AreYouPoliticallyExposedPersonPEP__c ? 'Yes' : 'No';
                                                         objCustFldata.n_inventory_count= tempRecord.Contact__r.NoOfPropertyPurchasedWithModon__c==null?'':tempRecord.Contact__r.NoOfPropertyPurchasedWithModon__c.toString();
                                                         if (String.isNotBlank(primaryApplicantName) && JointOwnerCount > 0) {
                                                            objCustFldata.s_joint_applicant_name = primaryApplicantName;
                                                         }
                                                     } 
                                                     
                                                     //below are corporate specific custom fields — NO CHANGE
                                                     if(isCompany){
                                                         objCustFldata.s_customer_risk= tempRecord.Account__r.LegalStructure__c;        
                                                         objCustFldata.s_trade_license= tempRecord.Account__r.UnifiedNumber__c;
                                                         objCustFldata.d_trade_license_expiry_date = dateFormation(tempRecord.Account__r.TradeLicenseExpiryDate__c);
                                                         objCustFldata.s_purpose_of_transaction = tempRecord.Account__r.PurposeOfTransaction__c;
                                                         objCustFldata.s_description_of_business_activity= tempRecord.Account__r.Description;    
                                                         objCustFldata.s_source_of_income = tempRecord.Account__r.SourceOfIncome__c; //5.0
                                                         objCustFldata.s_source_of_income_explanation = tempRecord.Account__r.OtherSourceOfIncome__c; // 5.0
                                                         objCustFldata.s_transaction_specific_risk= tempRecord.Account__r.PaymentMethod__c;
                                                         objCustFldata.s_channel_risk=tempRecord.Account__r.DeliveryChannel__c;
                                                         objCustFldata.n_inventory_count= tempRecord.Account__r.NoOfPropertyPurchasedWithModon__c==null?'':tempRecord.Account__r.NoOfPropertyPurchasedWithModon__c.toString();
                                                         // Map project
                                                             // updated as part of Version 7.0
                                                             String projectValueCom = getProjectValue(tempRecord);
                                                         if(tempRecord.Sales_Order__c != null) {
                                                                // objCustFldata.s_project_name = projectValueCom;
                                                               // objCustFldata.s_project_name = tempRecord.Sales_Order__r.ProjectName__c;
                                                            objCustFldata.s_unit_name = tempRecord.Sales_Order__r.Unit__r.Name; // 5.0
                                                         } else if(tempRecord.Opportunity__c != null) {
                                              //4.0 Start  //objCustFldata.s_project_name = tempRecord.Opportunity__r.Project__r.Name;
                                                                 //objCustFldata.s_project_name = tempRecord.Opportunity__r.ProjectInterest__c; //4.0 End
                                                         }
                                                         /*End-- Custom Fields */   
                                                         
                                                         //PassfortTransactionWrapper.Tax_ids objtxIds = new PassfortTransactionWrapper.Tax_ids();
                                                         //objtxIds.tax_id_type='VAT';
                                                         //objtxIds.value='';//tempRecord.Account__r.UAEVATRegisterNumber__c;
                                                            // updated as part of Version 7.0
                                                                objCustFldata.s_project_name = projectValueCom;
                                                         
                                                         /*End-- Metadata Fields */ 
                                                         objMtd = new PassfortTransactionWrapper.Metadata();
                                                         objMtd.country_of_incorporation = NationalityVsCodes.containsKey(tempRecord.Account__r.BillingCountry)?NationalityVsCodes.get(tempRecord.Account__r.BillingCountry):'ARE';
                                                         objMtd.bvd_id='';
                                                         objMtd.name=tempRecord.Account__r.Name;
                                                         objMtd.incorporation_date=dateFormation(tempRecord.Account__r.DateOfEstablishment__c);
                                                         //objMtd.company_number= tempRecord.Account__r.UnifiedNumber__c==null?'':tempRecord.Account__r.UnifiedNumber__c.ToString();
                                                         objMtd.company_number= tempRecord.Account__r.UnifiedNumber__c == null ? '' : String.valueOf(tempRecord.Account__r.UnifiedNumber__c);
                                                         //objMtd.tax_ids = new List<PassfortTransactionWrapper.Tax_ids>{objtxIds};
                                                         objMtd.addresses = new List<PassfortTransactionWrapper.Addresses>{objAddr};  

                                                         String vat = tempRecord.Account__r.UAEVATRegisterNumber__c;

                                                        if (String.isNotBlank(vat)) {
                                                            PassfortTransactionWrapper.Tax_ids objtxIds = new PassfortTransactionWrapper.Tax_ids();
                                                            objtxIds.tax_id_type = 'VAT';
                                                            objtxIds.value = vat;

                                                            objMtd.tax_ids = new List<PassfortTransactionWrapper.Tax_ids>{ objtxIds };
                                                        } else {
                                                            objMtd.tax_ids = null; 
                                                        }
                                                         /*End-- Metadata Fields */ 
                                                         
                                                             if(tempRecord.EntityType__c == Constants.PASSFORT_TR_TYPE_SHAREHOLDER_LINK){
                                                                 List<String> lstConJSON = (List<string>)JSON.deSerialize(tempRecord.Linked_Shareholder_Details__c,List<string>.class);
                                                                 List<PassfortTransactionWrapper.Beneficial_owners> lstBO = new List<PassfortTransactionWrapper.Beneficial_owners>();
                                                                 for(String str : lstConJSON){
                                                                     PassfortTransactionWrapper.Beneficial_owners objBO = (PassfortTransactionWrapper.Beneficial_owners)JSON.deSerialize(str,PassfortTransactionWrapper.Beneficial_owners.class);
                                                                     lstBO.add(objBO);
                                                                 }
                                                                 objOS = new PassfortTransactionWrapper.Ownership_structure();
                                                                 objOS.beneficial_owners = lstBO;
                                                             }
                                                      }
                                                     
                                                     /*Start-- collected data */ 
                                                     objColData = new PassfortTransactionWrapper.collected_data();
                                                     objColData.entity_type = isCompany ? Constants.PASSFORT_ENTITY_TYPE_COMPANY: Constants.PASSFORT_ENTITY_TYPE_INDIVIDUAL; 
                                                     // Only send entity_type for Individual
                                                     
                                                     if(!isCompany){
                                                         objColData.personal_details = objperDet;
                                                         objColData.address_history = new List<PassfortTransactionWrapper.Addresses>{objAddr};
                                                         objColData.contact_details = objConDet;
                                                     }
                                                     
                                                     objColData.custom_fields_data = objCustFldata;
                                                     
                                                     if(isCompany){
                                                         objColData.metadata = objMtd;
                                                         objColData.ownership_structure = objOS;
                                                     }
                                                     
                                                     objPTW.collected_data = objColData;       
                                                     /*End-- collected data */ 
                                                     
                                                     String jsonString = Json.serialize(objPTW);
                                                     
                                                     String endpointURL='';
                                                     if(isCompany)
                                                         endpointURL = Constants.PASSFORT_TR_COMPANY_ENDPOINT;
                                                     else if(tempRecord.EntityType__c == Constants.PASSFORT_TR_TYPE_INDIVIDUAL)
                                                         endpointURL = Constants.PASSFORT_TR_INDIVIDUAL_ENDPOINT;
                                                     else if(tempRecord.EntityType__c == Constants.PASSFORT_TR_TYPE_SHAREHOLDER)
                                                         endpointURL = Constants.PASSFORT_TR_SHAREHOLDER_ENDPOINT;
                                                     else if(tempRecord.EntityType__c == Constants.PASSFORT_TR_TYPE_PRIMARY_CONTACT)
                                                         endpointURL = Constants.PASSFORT_TR_PRIMARY_CONTACT_ENDPOINT;
                                                    if (isCompany && tempRecord.Account__r.DateOfEstablishment__c == null) {
                                                        mapOfTrRecIdvsResponse.put(tempRecord.Id, '{"status":"Errored","message":"Missing Date of Establishment (incorporation_date) for company."}');
                                                        continue;
                                                    }
                                                    System.debug('Outgoing JSON => ' + jsonString);
                                                     //Make callout
                                                     HTTPResponse res = makeapiCallout(endpointURL,jsonString);
                                                     if(res.getStatus() == 'OK'){
                                                         Map<String, String> responseMap = (Map<String, String>) JSON.deserialize(res.getBody(), Map<String, String>.class);
                                                         String profileID = responseMap.get('root_id');
                                                         String responseStatus = responseMap.get('status');
                                                         
                                                         if(responseStatus == Constants.PASSFORT_TR_SUCCESS && profileID != Null && profileID!=''){  
                                                             mapOfTrRecIdvsTrId.put(tempRecord.Id,tempRecord.transactionId__c+':'+profileID);
                                                             
                                                             if(tempRecord.ParentDocumentIds__c!='' && tempRecord.ParentDocumentIds__c!=null)
                                                                 mapOfTrRecIdvsDocIds.put(tempRecord.Id,tempRecord.ParentDocumentIds__c);
                                                             
                                                             if(isCompany)                                       
                                                                 mapOfAccIdvsProfileId.put(tempRecord.Account__c,profileID);
                                                             else
                                                                 mapOfConIdvsProfileId.put(tempRecord.Contact__c,profileID);
                                                         }
                                                     }
                                                     mapOfTrRecIdvsResponse.put(tempRecord.Id,res.getBody());
                                                 }      
        updateAccountOrContactRecord(mapOfAccIdvsProfileId,mapOfConIdvsProfileId,'profileId'); //for updating profile Id on them.
        updateResponseOnTransactionRecord(mapOfTrRecIdvsResponse,mapOfTrRecIdvsTrId); 
        createDocumentTransactionRecords(mapOfTrRecIdvsDocIds);
    }
    
    // make api callout and return response
    public static HTTPResponse makeapiCallout(String endPoint, String jsonString){
        HttpRequest req = new HttpRequest();
        req.setTimeout(120000);
        req = OIC_CredentialsController.getCredentials(endPoint);
        System.debug('Resolved endpoint [' + endPoint + '] => ' + req.getEndpoint());
        System.debug('HTTP Method => ' + req.getMethod());

        req.setBody(jsonString);
        Http http = new Http();
        return http.send(req);        
    }
    
    //general method to check if any field value is null or blank
    public static string nullCheck(String strField){
        if(strField == null || strField == '')
            return '';
        else 
            return strField;
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
    public static void updateAccountOrContactRecord(Map<String,String> mapOfAccIdvsProfileId, Map<String,String> mapOfConIdvsProfileId,String fieldToUpdate){

        // 9.0 - Arvind - Start: Build DMLOptions to bypass duplicate rule block on Account and Contact updates
        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.DuplicateRuleHeader.allowSave = true;
        dmlOptions.DuplicateRuleHeader.runAsCurrentUser = true;
        // 9.0 - Arvind - End

        List<Account> lstAccToUpdate = new List<Account>();
        for(Id accId : mapOfAccIdvsProfileId.keySet()){
            Account acc = new Account();
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
        
        if(lstAccToUpdate.size()>0){
            // 9.0 - Arvind - Start: Apply DMLOptions to each Account to bypass duplicate rule
            for(Account acc : lstAccToUpdate){
                acc.setOptions(dmlOptions);
            }
            // 9.0 - Arvind - End
            Database.update(lstAccToUpdate,false);
        }
                
        List<Contact> lstConToUpdate = new List<Contact>();
        for(Id conId :  mapOfConIdvsProfileId.keySet()){
            Contact con = new Contact();
            con.Id = conId;
            if(fieldToUpdate=='profileId'){
             con.profileId__c = mapOfConIdvsProfileId.get(conId);
             con.PassfortApprovalStatus__c = Constants.PASSFORT_APPROVAL_STATUS_IN_REVIEW;
             con.ProfileUpdateTime__c = System.Now();
            }
            if(fieldToUpdate=='comment')
             con.PassfortComment__c = mapOfConIdvsProfileId.get(conId);   
            lstConToUpdate.add(con);
        }
        
        if(lstConToUpdate.size()>0){
            // 9.0 - Arvind - Start: Apply DMLOptions to each Contact to bypass duplicate rule
            for(Contact con : lstConToUpdate){
                con.setOptions(dmlOptions);
            }
            // 9.0 - Arvind - End
            Database.update(lstConToUpdate,false);
        }
    }   
    
    //to update complete JSON response on transaction record
    public static void updateResponseOnTransactionRecord(Map<String,String> mapOfTrRecIdvsResponse, Map<String,String>mapOfTrRecIdvsTrId){
        List<Passforttransaction__c> lstPtrToUpdate = new List<Passforttransaction__c>();
        for(Id TrRecId : mapOfTrRecIdvsResponse.keySet()){
            Passforttransaction__c ptr = new Passforttransaction__c();
            ptr.Id = TrRecId;
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
        //Update version 6.0 added registration and PassfortTransaction__r.Registration__c to the Query for Broker Flow
        for(Passforttransaction__c tempRecord : [Select Id,transactionId__c,Document__c,Document__r.Name,PassfortTransaction__r.ProfileId__c,Registration__c,PassfortTransaction__r.Registration__c from Passforttransaction__c where id in :transactionIDs OR PassfortTransaction__c in :transactionIDs]){
            if (tempRecord.Document__c == null) {
                continue;
            }
            
            /*Update version 6.0 Boolean Variable for Broker Flow starts Here
            @description : as the Broker Flow requirement is to send all the document's files to the Compliance 
            Without disturbing the existing flow we put a Boolean and an If block that will only be true If its Broker Flow
            */
            
            Boolean isBrokerFlow =  tempRecord.PassfortTransaction__r.Registration__c != null;

            if(isBrokerFlow){
            List<ContentDocumentLink> CDs = [SELECT ContentDocumentId,LinkedEntity.Name FROM ContentDocumentLink WHERE LinkedEntityId =: tempRecord.Document__c order by ContentDocument.CreatedDate desc];

            for(ContentDocumentLink CD : CDs){
                ID CD_ID = CD.ContentDocumentId;
                Blob pdfblob = [SELECT VersionData FROM ContentVersion WHERE ContentDocumentId =: CD_ID ORDER BY VersionNumber DESC LIMIT 1].VersionData; 
                
                PassfortTransDocumentWrapper objPTDW = new PassfortTransDocumentWrapper();
                objPTDW.data = pdfblob;
                objPTDW.name = tempRecord.Document__r.Name;
                objPTDW.root_id = tempRecord.PassfortTransaction__r.ProfileId__c;
                objPTDW.id = tempRecord.transactionId__c;
                
                String jsonString = Json.serialize(objPTDW);
                
                string endpointURL = Constants.PASSFORT_TR_DOC_UPLOAD_ENDPOINT;
                
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
        } //Upadte version 6.0 Broker Flow ends here 
          else{

            //query to get latest file of perticular document
            ContentDocumentLink[] CDs = [SELECT ContentDocumentId,LinkedEntity.Name FROM ContentDocumentLink WHERE LinkedEntityId =: tempRecord.Document__c order by ContentDocument.CreatedDate desc limit 1];
            
            if(!CDs.isEmpty()){
                ContentDocumentLink CD = CDs[0];
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
         }
        }
        updateResponseOnTransactionRecord(mapOfTrRecIdvsResponse, mapOfTrRecIdvsTrId);
    }
                /** version 7.0
        * Method to fetch Project value for Passfort transact*on
        * Priority:
        * 1. Sales Order Project Name
        * 2. Opportunity Project Interest
        */
        private static String getProjectValue(Passforttransaction__c tempRecord) {
            // Check if Sales Order is available and has Project Name
            if (tempRecord.Sales_Order__c != null && String.isNotBlank(tempRecord.Sales_Order__r.ProjectName__c)) {
                return tempRecord.Sales_Order__r.ProjectName__c.trim();
            }
             // If Sales Order is not available, check Opportunity Project Interest
            if (tempRecord.Opportunity__c != null && String.isNotBlank(tempRecord.Opportunity__r.ProjectInterest__c)) {
                return tempRecord.Opportunity__r.ProjectInterest__c.trim();
            }
            return null;
        }
                /** version 7.0
        * Method to determine Product Alias based on Project value
        * Logic:
        * - If project contains 'Commercial' → return 'MODON Commercial'
        * - Else → return default Passfort Alias
        * Added flag for commertial plots and secondary market by Siva-15/08/2026
        */
       private static String getProductAlias(String projectValue,Passforttransaction__c passfortRecord) {
           
            if (passfortRecord == null) {
                return Constants.PASSFORT_TR_ALIAS;
            }
        
            // Secondary Market / Resale
            if (passfortRecord.Is_Secondary_Market__c == true) {
                return System.Label.PASSFORT_TR_ALIAS_RESALE;
            }
        
            // Commercial
            if (passfortRecord.Is_Commercial__c == true) {
                return System.Label.Modon_Commercial;
            }
        
            // Default
            return Constants.PASSFORT_TR_ALIAS;
        } 
    }