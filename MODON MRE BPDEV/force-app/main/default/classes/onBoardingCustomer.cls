/**
* @description       : Community/Portal user On bording
* @author            : Manoj
* @last modified on  : 02-23-2026
* @last modified by  : Manoj
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj   	        13 Oct 2025   		Initial Draft 
* 2.0           Manoj   	        09 Dec 2025   		Remove logic 
* 3.0			Manoj				10 Jan 2026			Add SOQL and update other filters
														Communication Matrix
* 4.0			Manoj				13 Jan 2026			Add Bypass the email trigger filters
* 5.0           Manoj				28 Feb 2026			Add creating JOIN owner logic is add  Update the filters for Customer Segemnt and Joint Owner user creation alos
* 6.0 			Manoj				10 Mar 2026			Add All joint owners and error for logic		
-------------------------------------------------------------------------------------------------------------------------**/
global class onBoardingCustomer implements Database.Batchable<SObject>,Database.AllowsCallouts {
    global Database.QueryLocator start(Database.BatchableContext bc) {  
        //3.0 add the Record Type
        list<string> accRecordTypeName =new list<string>();
        accRecordTypeName.add('Person Account');
        accRecordTypeName.add('Organization Account');
        //5.0 Add the Joint Owner 
        string Qry ='select id,CustomerAccount__c,CustomerAccount__r.name,CustomerAccount__r.RecordType.name,Status__c,Unit__c,CustomerAccount__r.IsCustomerPortal,JO1__c,JO1__r.AccountId, JO1__r.Account.IsCustomerPortal,JO2__c,JO2__r.Account.IsCustomerPortal,JO2__r.AccountId, JO3__c,JO3__r.AccountId,JO3__r.Account.IsCustomerPortal,JO4__c,JO4__r.AccountId, JO4__r.Account.IsCustomerPortal,JO5__c,JO5__r.AccountId, JO5__r.Account.IsCustomerPortal,JO6__c,JO6__r.AccountId, JO6__r.Account.IsCustomerPortal from SalesOrder__c where  CustomerAccount__r.RecordType.name IN :accRecordTypeName';
        string SalesOrderIdsLable = System.Label.CPSalesOrderIds;
        string CustomerSegment = System.Label.CustomerSegment;
        string CustomerSegmentGroup = System.Label.CustomerSegmentGroup;
        list<id> SalesOrderIds=new list<id>();
        if(SalesOrderIdsLable.contains(',')){
            system.debug('22---'+SalesOrderIdsLable);
            SalesOrderIds = SalesOrderIdsLable.split(',');
        }else{
            system.debug('26---'+SalesOrderIdsLable);
            if(!SalesOrderIdsLable.contains('null') ){
                SalesOrderIds =new List<String>{SalesOrderIdsLable};
            }
        }   
        list<string> statusValues =new List<string>();
        string statusValuesLables = System.Label.CPSOStatus;
        
        if(statusValuesLables.contains(',')){
            system.debug('22---'+statusValuesLables);
            statusValues = statusValuesLables.split(',');
        }else{
            system.debug('26---'+statusValuesLables);
            if(!statusValuesLables.contains('null') ){
                statusValues =new List<String>{statusValuesLables};
        	}
        }
        if(statusValues != null){ //3.0 and 5.0 update Where logic 
            qry +=' AND Status__c IN :statusValues';
        }//3.0 Start add the Project filters
        string MIREExcludelst = System.Label.MIRE_Exclude_List;
        list<string> projectFilter =new list<string>();
        
        for (String c2 : MIREExcludelst.split(',')) {
            if (c2 != null && c2.contains('^')) {
                projectFilter.add(c2.replace('^', ',').trim());
            } else {
                projectFilter.add(c2.trim());
            }
        }   //3.0 End
        if(projectFilter != null){
            qry += ' AND ProjectName__c  NOt IN : projectFilter';
        }
        system.debug('SalesOrderIds----'+SalesOrderIds);
        if( SalesOrderIds.size() > 0 ){            
            qry +=' AND CustomerAccount__c = :SalesOrderIds ';
        }
        system.debug('qry----'+qry);
        If(!CustomerSegment.contains('null')){ //5.0 Add the Customer Segemnt 
            
            qry +=' AND CustomerAccount__r.Customer_Segemnt_Group__c =: CustomerSegmentGroup  AND CustomerAccount__r.Customer_Segmentation__c = :CustomerSegment and CustomerAccount__r.Isduplicate__c = false';
        }
        
        if(Test.isRunningTest()){
            return Database.getQueryLocator([
                SELECT Id, CustomerAccount__c, CustomerAccount__r.Name, CustomerAccount__r.RecordType.Name, Status__c, Unit__c, CustomerAccount__r.IsCustomerPortal, JO1__c, JO1__r.AccountId, JO1__r.Account.IsCustomerPortal, JO2__c, JO2__r.Account.IsCustomerPortal, JO2__r.AccountId, JO3__c, JO3__r.AccountId, JO3__r.Account.IsCustomerPortal, JO4__c, JO4__r.AccountId, JO4__r.Account.IsCustomerPortal, JO5__c, JO5__r.AccountId, JO5__r.Account.IsCustomerPortal, JO6__c, JO6__r.AccountId, JO6__r.Account.IsCustomerPortal FROM SalesOrder__c LIMIT 1
            ]);
        }
        
        system.debug('44-- '+qry);
        return Database.getQueryLocator(qry);        
        
    }
    global void execute(Database.BatchableContext bc, List<SalesOrder__c> scope) {
        system.debug('executeMethod==========');
        //3.0 add only Active User 
        set<id> newCPAccountids=new set<id>();         
        for(SalesOrder__c recSo : scope){
            //5.0  start Add the Joint Owner
            //6.0 Add All joint owners
                if(recSo.CustomerAccount__r.IsCustomerPortal == false){               
                	newCPAccountids.add(recSo.CustomerAccount__c); 
                }
                if(recSo.JO1__c != null && recSo.JO1__r.Account.IsCustomerPortal == false){               
                	newCPAccountids.add(recSo.JO1__r.AccountId);                
            	}
                if(recSo.JO2__c != null && recSo.JO2__r.Account.IsCustomerPortal == false){               
                	newCPAccountids.add(recSo.JO2__r.AccountId);                
            	}
                if(recSo.JO3__c != null && recSo.JO3__r.Account.IsCustomerPortal == false){               
                	newCPAccountids.add(recSo.JO3__r.AccountId);                
            	}
                if(recSo.JO4__c != null && recSo.JO4__r.Account.IsCustomerPortal == false){               
                	newCPAccountids.add(recSo.JO4__r.AccountId);                
            	}
                if(recSo.JO5__c != null && recSo.JO5__r.Account.IsCustomerPortal == false){               
                	newCPAccountids.add(recSo.JO5__r.AccountId);                
            	}
                if(recSo.JO6__c != null && recSo.JO6__r.Account.IsCustomerPortal == false){               
                	newCPAccountids.add(recSo.JO6__r.AccountId);                
            	}            
            //5.0 End Add the Joint Owner
            //6.0 End
        }
        if(newCPAccountids.size() > 0){
            createNewPortlauser(newCPAccountids);
        }        
        system.debug('28--- done with method calling');
    }

    
    global void finish(Database.BatchableContext bc) {
        
    }
    
    public static void createNewPortlauser(set<id> newCPAccountids){
        list<Contact> conList = [SELECT Id, FirstName, LastName, Email, EIDNumber__c,MailingCity, MailingCountry, MailingState, MailingStreet, MailingPostalCode, MobilePhone,Account.EIDNumber__pc,Account.PersonMailingStreet, Account.PersonMailingCity, Account.PersonMailingState, 
                                 Account.RecordType.name,Account.PersonMailingPostalCode, Account.PersonMailingCountry  FROM Contact  WHERE AccountId = :  newCPAccountids];
        
        system.debug('29--- ' + conList );
        
        list<User> usersToCreate =new list<User>();
        for(Contact conRec : conList){
            
            User newUserRec = new User();
            newUserRec.Username = conRec.Email;
            newUserRec.Email = conRec.Email;
            newUserRec.FirstName = conRec.FirstName;
            newUserRec.LastName = conRec.LastName;
            newUserRec.Phone = conRec.MobilePhone;
            newUserRec.Alias = conRec.LastName.length() >= 5 ? conRec.LastName.substring(0, 5) : conRec.LastName;
            newUserRec.TimeZoneSidKey = 'Asia/Dubai';
            newUserRec.LocaleSidKey = 'en_US';
            newUserRec.EmailEncodingKey = 'UTF-8';
            newUserRec.LanguageLocaleKey = 'en_US';
            newUserRec.ContactId = conRec.Id;
            newUserRec.ProfileId = '00eVH00000LdgMf';// 00eVG000002II6z
            newUserRec.IsActive = true;
            newUserRec.EmiratesIDNumber__c=conRec.Account.RecordType.name == 'Organization Account' ? conRec.EIDNumber__c:conRec.Account.EIDNumber__pc;
            newUserRec.Street = conRec.Account.RecordType.name == 'Organization Account' ? conRec.MailingStreet:conRec.Account.PersonMailingStreet;
            newUserRec.City = conRec.Account.RecordType.name == 'Organization Account' ? conRec.MailingCity:conRec.Account.PersonMailingCity;
            newUserRec.State = conRec.Account.RecordType.name == 'Organization Account' ? conRec.MailingState:conRec.Account.PersonMailingState;
            newUserRec.PostalCode = conRec.Account.RecordType.name == 'Organization Account' ? conRec.MailingPostalCode:conRec.Account.PersonMailingPostalCode;
            newUserRec.Country = conRec.Account.RecordType.name == 'Organization Account' ? conRec.MailingCountry:conRec.Account.PersonMailingCountry;
            Blob stringBlob = Blob.valueOf(newUserRec.Username);			
            String base64Encoded = EncodingUtil.base64Encode(stringBlob);
            newUserRec.EmailBase64String__c = base64Encoded;    
            system.debug('newUserRec---'+newUserRec);
            usersToCreate.add(newUserRec);            
        }
        
        if (!usersToCreate.isEmpty()) {
            
            // This allows partial success: if one record fails, others can still be inserted.
            Database.SaveResult[] results = Database.insert(usersToCreate, false);
            
            // Iterate through the results to check the outcome for each record
            for (Integer i = 0; i < results.size(); i++) { //5.0 Add loop results
                    Database.SaveResult sr = results[i];
                    User attemptedUser = usersToCreate[i];
                if (sr.isSuccess()) {
                    // Operation was successful for this record
                    System.debug('Successfully inserted contact with ID: ' + sr.getId());
                    // Step 2: Attempt password reset
                    try {
                        string newPassword =PasswordGenerator.generatePassword();
                        System.setPassword(sr.getId(), newPassword);                                     
                        system.debug('newPassword :' + newPassword);
                        // 3.0 Add logic for Communication Matrix                         
                        if(System.Label.StopEmailOnonBoardingCustomer == 'true'){ // 4.0 Add bypass 
                            if(sr.getId() != null){
                                user createuser = [SELECT Id, Email, Username,FirstName, EmiratesIDNumber__c,LastName,Street, City, 
                                               State, Country, PostalCode,Phone,Contact.AccountId FROM User 
                                               where id =:sr.getId()];
                                 String emailTemplateName = System.Label.Email_CustomerPortalEmail;                        
                                 SendGridNotificationUtility.sendEmail(null, createuser.id, emailTemplateName, createuser.Email, 'customercare@modon.com',
                                                                                       'MODON Customer Care',null,null, 'Customer Portal', 'Customer Management', null, null, createuser.id);
                            }                      
                        }
                        
                    }catch(Exception ex){
                        System.debug('Failed to resetPassword.'+ex);
                        LoggerService.save(LoggerService.createAPILog('Creat Password Customer Portal User','onBoardingCustomer','newPassword User',ex.getMessage(), ex.getMessage(), 'Error Message: ' +ex.getMessage(), 'Apex Log'));
                    }
                } else {
                     //6.0 Error for logic
                    // Operation failed for this record
                    System.debug('Failed to insert contact.');
                    // Retrieve and log the errors for the failed record
                    for (Database.Error error : sr.getErrors()) {
                        System.debug('Error Status Code: ' + error.getStatusCode());
                        System.debug('Error Message: ' + error.getMessage());
                        System.debug('Fields Affected: ' + error.getFields());
                        //5.0 Add Error Account
                        String errorDetails = 'AccountId: ' + attemptedUser.ContactId +
                              ' | Username: ' + attemptedUser.Username +
                              ' | Email: ' + attemptedUser.Email ;
        
        				System.debug('Error Details: ' + errorDetails);
                        
                        LoggerService.save(LoggerService.createAPILog('Creat New Customer Portal User','onBoardingCustomer','Create User',error.getMessage(), errorDetails, 'Error : 400', 'Apex Log'));
                    }
                }
            }
        }
    }
}