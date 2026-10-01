/**********************************************************************************************************************
* Name               : TestDataFactory                                                    
* Description        : This class is used as a helper for all Testclasses
* Usage              : For Testclasses
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           Raghu.Gajjela@activemindsit.com     		26 Jan 2025     Initial Draft          
* 2.0           ravikumar.pasumarthi@activemindsit.com      20 Jan 2026     Changes as per Case Mgmt 2.0
******************************************************************************************************************/

@isTest
public class TestDataFactory {

    public static Map<String, Id> createTestData() {
	Map<String, Id> ids = new Map<String, Id>();

	// Step 1: Consolidate SOQL queries for Profiles and Record Types
	List<Profile> profiles = [SELECT Id, Name FROM Profile WHERE Name IN ('System Administrator', 'Call Center Mgmt - Maqsam', 'Front Liner')];
	Map<String, Id> profileMap = new Map<String, Id>();
	for (Profile p : profiles) {
		profileMap.put(p.Name, p.Id);
	}

	List<RecordType> recordTypes = [SELECT Id, Name FROM RecordType WHERE SObjectType = 'Account' AND Name IN ('Person Account', 'Organization Account')];
	Map<String, Id> recordTypeMap = new Map<String, Id>();
	for (RecordType rt : recordTypes) {
		recordTypeMap.put(rt.Name, rt.Id);
	}
	User admUser = [select id,name from user where profile.name = 'System Administrator' and isactive = true limit 1];
    
	// Step 2: Create Users in a list and insert them in one DML statement
	String uniqueUsername = 'testuser' + System.currentTimeMillis() + '@example.com';
	List<User> usersToInsert = new List<User>();

	User managerUser = new User(
		Alias = 'muser',
		Email = uniqueUsername,
		EmailEncodingKey = 'UTF-8',
		LastName = 'ManagerUser',
		LanguageLocaleKey = 'en_US',
		LocaleSidKey = 'en_US',
		ProfileId = profileMap.get('System Administrator'),
		TimeZoneSidKey = 'America/Los_Angeles',
		UserName = uniqueUsername,
        ManagerId = admUser.Id
	);
	usersToInsert.add(managerUser);

	User modonTestUser = new User(
		Alias = 'ccuser',
		Email = 'modonTestUser' + System.currentTimeMillis() + '@testorg.com',
		LastName = 'CallCenterUser',
		LanguageLocaleKey = 'en_US',
		EmailEncodingKey = 'UTF-8',
		LocaleSidKey = 'en_US',
		ProfileId = profileMap.get('Call Center Mgmt - Maqsam'),
		TimeZoneSidKey = 'America/Los_Angeles',
		UserName = 'UserAMGS' + System.currentTimeMillis() + '@testorg.com',
        ManagerId = admUser.Id
	);
	usersToInsert.add(modonTestUser);

	User frontLinerUser = new User(
		Alias = 'fluser',
		Email = 'frontliner' + System.currentTimeMillis() + '@testorg.com',
		LastName = 'FrontLinerUser',
		LanguageLocaleKey = 'en_US',
		EmailEncodingKey = 'UTF-8',
		LocaleSidKey = 'en_US',
		ProfileId = profileMap.get('Front Liner'),
		TimeZoneSidKey = 'America/Los_Angeles',
		UserName = 'frontliner' + System.currentTimeMillis() + '@testorg.com',
        ManagerId = admUser.Id
	);
	usersToInsert.add(frontLinerUser);

	insert usersToInsert;

	// Populate the IDs map
	ids.put('ManagerUser', managerUser.Id);
	ids.put('modonTestUser', modonTestUser.Id);
	ids.put('FrontLinerUser', frontLinerUser.Id);

	// Step 4: Create Accounts in a list and insert them in one DML statement
	List<Account> accountsToInsert = new List<Account>();
	Account vipPersonAccount = new Account(
		LastName = 'vipPersonAccount',
		CustomerType__c = 'VIP Client',
		OwnerId = modonTestUser.Id,
		Account_Manager__c = modonTestUser.Id,
		PersonEmail = 'vippersonaccountemail@mail.com',
		RecordTypeId = recordTypeMap.get('Person Account'),
		EIDNumber__pc = '784-1234-1234567-1',
		PersonMobilePhone = '+971888999654'
	);
	accountsToInsert.add(vipPersonAccount);

	Account vipOrganizationAccount = new Account(
		Name = 'AccountVIP',
		CustomerType__c = 'VIP Client',
		OwnerId = modonTestUser.Id,
		Account_Manager__c = modonTestUser.Id,
		RecordTypeId = recordTypeMap.get('Organization Account')
	);
	accountsToInsert.add(vipOrganizationAccount);

	Account nonvipPersonAccount = new Account(
		LastName = 'nonvipPersonAccount',
		CustomerType__c = 'New Client',
		OwnerId = modonTestUser.Id,
		Account_Manager__c = modonTestUser.Id,
		PersonEmail = 'nonvippersonaccountemail@mail.com',
		RecordTypeId = recordTypeMap.get('Person Account'),
		EIDNumber__pc = '784-1234-1234567-1',
		PersonMobilePhone = '+971876543210'
	);
	accountsToInsert.add(nonvipPersonAccount);

	Account nonvipOrganizationaccount = new Account(
		Name = 'nonvipOrganizationaccount',
		CustomerType__c = 'New Client',
		OwnerId = modonTestUser.Id,
		Account_Manager__c = modonTestUser.Id,
		RecordTypeId = recordTypeMap.get('Organization Account')
	);
	accountsToInsert.add(nonvipOrganizationaccount);

	insert accountsToInsert;
	
	// Populate the IDs map
	ids.put('vipPersonAccount', vipPersonAccount.Id);
	ids.put('vipOrganizationAccount', vipOrganizationAccount.Id);
	ids.put('nonvipPersonAccount', nonvipPersonAccount.Id);
	ids.put('nonvipOrganizationaccount', nonvipOrganizationaccount.Id);

	// Step 5: Create Contacts in a list
	List<Contact> contactsToInsert = new List<Contact>();
	Contact vipOrganizationcontact = new Contact(
		FirstName = 'Test',
		LastName = 'Contact',
		AccountId = vipOrganizationAccount.Id,
		EIDNumber__c = ' 784-1234-1234567-1 ',
		OwnerId = modonTestUser.Id,
		Phone = '+971555666999',
		Email = 'TestContact1@gmail.com',
		Is_Active__c = true
	);
	contactsToInsert.add(vipOrganizationcontact);

	Contact nonvipOrganizationcontact = new Contact(
		FirstName = 'Test',
		LastName = 'Contact2',
		AccountId = nonvipOrganizationaccount.Id,
		EIDNumber__c = ' 784-1234-1234567-1 ',
		OwnerId = modonTestUser.Id,
		Phone = '+971876543210',
		Email = 'Test.Contact2@gmail.com',
		Is_Active__c = true
	);
	contactsToInsert.add(nonvipOrganizationcontact);
	
	insert contactsToInsert;

	// Populate the IDs map
	ids.put('vipOrganizationcontact', vipOrganizationcontact.Id);
	ids.put('nonvipOrganizationcontact', nonvipOrganizationcontact.Id);
	
	// Step 6: Create other objects in a list
	List<SObject> otherRecordsToInsert = new List<SObject>();

	Unit__c testUnit = new Unit__c(
		Name = 'Test Unit',
		PlotNo__c = '105',
		UnitClassification__c = 'Villa',
        Status__c = 'Sold',
		Number_of_Bedrooms__c = '5'
	);
        insert testUnit;
	//otherRecordsToInsert.add(testUnit);

	Opportunity testOpportunity = new Opportunity(
		Name = 'Test Opportunity',
		AccountId = vipOrganizationAccount.Id,
		StageName = 'Prospecting',
		CloseDate = Date.today().addDays(30),
		UAE_Resident_Status__c = 'Resident',
		Nationality__c = 'United Arab Emirates',
		EmiratesIDExpiryDate__c = Date.today().addDays(365),
		EIDNumber__c = '784-1234-1234567-1'
	);
        insert testOpportunity;
	//otherRecordsToInsert.add(testOpportunity);

	//insert otherRecordsToInsert;
	
	// The Unit__c record needs the Opportunity ID, so it's updated in a separate list
	testUnit.Opportunity__c = testOpportunity.Id;
	update testUnit;

	// Populate the IDs map
	ids.put('Unit', testUnit.Id);
	ids.put('Opportunity', testOpportunity.Id);

	// Step 7: Create remaining objects
	List<SObject> finalRecordsToInsert = new List<SObject>();

	SalesOrder__c testSalesOrder = new SalesOrder__c(
		CustomerAccount__c = vipOrganizationAccount.Id,
		PrimaryContact__c = vipOrganizationcontact.Id,
		Opportunity__c = testOpportunity.Id,
		Unit__c = testUnit.Id,
		Status__c = 'Completed'
	);
	finalRecordsToInsert.add(testSalesOrder);

	ServiceRequest__c sr = new ServiceRequest__c(
		Name__c = 'Test SR',
		Type__c = 'Next of Kin',
		AccountId__c = nonvipOrganizationaccount.Id,
		DebitNoteAmount__c = 250,
		UnitId__c = testUnit.Id
	);
	finalRecordsToInsert.add(sr);

	insert finalRecordsToInsert;

	// Populate the IDs map
	ids.put('SalesOrder', testSalesOrder.Id);
	ids.put('ServiceRequest', sr.Id);

	// Step 8: Create Cases and insert them in one DML statement
	List<Case> casesToInsert = new List<Case>();

	Case testCase = new Case(
		RunningTestClass__c = true,
		AccountId = vipOrganizationAccount.Id,
		ContactId = vipOrganizationcontact.Id,
		Requestor_Email__c = 'customer@gmail.com',
		Requestor_Name__c = 'Customer',
		Owner_Email__c = 'UserModonTest@testorg.com',
		Customer_Email__c = 'customer@gmail.com',
		Customer_Name__c = 'customername',
		Requestor_Phone__c = '+971555666999',
		Customer_Phone__c = '+971555666999',
		Emirates_Id__c = '784-1234-1234567-1',
		Masked_Emirates_Id__c = '784-2345-4567890-9',
		Account_Manager_Email__c = 'test1@gmail.com',
        Sub_Vertical__c = 'Contact Centre',
		CaseCategory__c = 'Customer Care',
		//CaseSubCategory__c = 'General Enquiry',
		Reason = 'Complex functionality',
		Primary_Assignee__c = modonTestUser.Id,
		Unit__c = testUnit.Id,
		Status = 'New',
		SR_Number__c = '12345',
		Resolution_Comments__c = 'hello hi hello',
		OwnerId = modonTestUser.Id,
		Origin = '800 Modon',
		Description = 'Test description from test methods',
		Approval_Status__c = null,
		Transfer_Comments__c = 'tested',
        New_owner__c = modonTestUser.Id
		//Account_Customer_Type__c = 'Visitor Case'//,
        //Send_Survey__c = false
	);
	casesToInsert.add(testCase);
    
        Case testCase3 = new Case(
		RunningTestClass__c = true,
		//AccountId = vipOrganizationAccount.Id,
		//ContactId = vipOrganizationcontact.Id,
		Requestor_Email__c = 'customer@gmail.com',
		Requestor_Name__c = 'Customer',
		//Owner_Email__c = 'UserModonTest@testorg.com',
		//Customer_Email__c = 'customer@gmail.com',
		//Customer_Name__c = 'customername',
		//Requestor_Phone__c = '+971555666999',
		//Customer_Phone__c = '+971555666999',
		//Emirates_Id__c = '784-1234-1234567-1',
		//Masked_Emirates_Id__c = '784-2345-4567890-9',
		//Account_Manager_Email__c = 'test1@gmail.com',
        //Sub_Vertical__c = 'Post Sales',
		CaseCategory__c = 'Department Action',
		CaseSubCategory__c = 'Financial Services',
		Reason = 'Complex functionality',
		Primary_Assignee__c = modonTestUser.Id,
		Unit__c = testUnit.Id,
		Status = 'New',
        Origin = label.CaseOriginCustomerPortal,
		//SR_Number__c = '12345',
		//Resolution_Comments__c = 'hello hi hello',
		//OwnerId = modonTestUser.Id,
		Description = 'Test description from test methods',
		//Approval_Status__c = null,
		//Transfer_Comments__c = 'tested',
        New_owner__c = modonTestUser.Id
	);
	//casesToInsert.add(testCase3);
        
	insert casesToInsert;

	// Populate the IDs map
	ids.put('TestCase', testCase.Id);
	ids.put('TestCase1', testCase.Id);
	ids.put('TestCase2', testCase.Id);
    ids.put('TestCase3', testCase3.Id);

	// Step 9: Create Round Robin Assignment Matrix Record
	RoundRobinAssignmentMatrix__c roundRobinRecord = new RoundRobinAssignmentMatrix__c(
		User__c = modonTestUser.Id,
		OwnerId = modonTestUser.Id,
		Application_Type__c = 'Service Cloud',
		Language__c = 'English;Russian;Arabic;Mandarin',
		Status__c = 'Available',
		CurrentLoad__c = 5,
		Threshold__c = 10,
		Leave_Today__c = false,
		LastAssignmentTime__c = System.now()
	);
	insert roundRobinRecord;

	ids.put('RoundRobinRecord', roundRobinRecord.Id);

	return ids;
}


    Public static user createUser(string profileName){
        Profile pf=[SELECT id,Name from Profile Where  Name=:profileName LIMIT 1];
        User usr = new User(
            Alias = 'modo1', 
            Email = 'salesforcetest@modon.com', 
            LastName = 'sflast@modon.com', 
            LanguageLocaleKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LocaleSidKey = 'en_US', 
            ProfileId = pf.Id, 
            TimeZoneSidKey = 'America/Los_Angeles', 
            UserName = Math.random()+'sflstfst@modon.com'
        );
        insert usr;
        return usr;
    }
    
    public static List<Account> createListOfAccont(integer noOfPersonAccounts){
        List<Account> accountList = new List<Account>();
        Id PersonAccountRecId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        user userRecord=createUser('System Administrator');
        for(integer i=0;i<noOfPersonAccounts;i++){
            Account nonvipPersonAccount = new Account(LastName = 'nonvipPersonAccount',	CustomerType__c = 'New Client', Account_Manager__c = userRecord.Id,personemail = 'nonvippersonaccountemail@mail.com', RecordTypeId = PersonAccountRecId,  EIDNumber__pc = '784-1234-1234567-1', Phone = '+919876543201',PersonMobilePhone = '+919876543210');
            
            
            accountList.add(nonvipPersonAccount);
        }
        insert accountList;
        return accountList;
    }
    
    
    public static Project__c creatProject(){
        Project__c projectRecord = new Project__c();
        insert projectRecord;
        return projectRecord;
    }
    public static Phase__c creatPhase(){
        Project__c pr=creatProject();
        Phase__c phaseRecord = new Phase__c(
            Project__c =pr.Id);
        insert phaseRecord;
        return phaseRecord;
    }
    
    public static Unit__c createunit(){
        Phase__c ph=creatPhase();
        Unit__c unitRecord = new Unit__c(Name = 'Test Unit',Phase__c=ph.id, PlotNo__c = '105',UnitClassification__c='Villa',Number_of_Bedrooms__c = '8',status__c='Sold');
        insert unitRecord;
        return unitRecord;
    }
   
    public static Opportunity createOpportunity(){
        List<Account> accountRecordsList=new List<Account>();
        accountRecordsList=createListOfAccont(1);
        Unit__c unt=createunit();
        Opportunity opportunityRecord = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = accountRecordsList[0].Id,
            StageName = 'Prospecting',  // Change as per your business logic
            CloseDate = Date.today().addDays(30),
            EmiratesIDExpiryDate__c = Date.today().addDays(30),
            EIDNumber__c = '784-3333-2222222-1',
            Unit__c = unt.Id,
            UAE_Resident_Status__c = 'Resident',
                   
	Nationality__c = 'United Arab Emirates'
        );
        insert opportunityRecord;
        return opportunityRecord;
    }
    
    public static SalesOrder__c createsalesOrder(){
        List<Account> accountRecordsList=new List<Account>();
        accountRecordsList=createListOfAccont(1);
        opportunity opp=createOpportunity();
        Unit__c unt=createunit();
        SalesOrder__c SalesOrderRecord = new SalesOrder__c(
            CustomerAccount__c = accountRecordsList[0].Id,
            //PrimaryContact__c = accountRecordsList[0].Id,
            Status__c = 'Sold',
            Opportunity__c = opp.Id,
            Unit__c = unt.Id
        );
        insert SalesOrderRecord;
        return SalesOrderRecord;
    }
    public static ServiceRequest__c createServiceRequest(string typeval,Id recordTypeId){
        List<Account> accountRecordsList=new List<Account>();
        
        accountRecordsList=createListOfAccont(1);
        Unit__c unt=createunit();
        SalesOrder__c SalesOrderRecord = createsalesOrder();
        ServiceRequest__c serviceRequestRecord = new ServiceRequest__c(
            Name__c = 'Test SR',
            Type__c = typeval,
            RecordTypeId = recordTypeId,
            SalesOrder__c = SalesOrderRecord.id,
            AccountId__c=accountRecordsList[0].Id
            
        );
        insert serviceRequestRecord;
        return serviceRequestRecord;
    }
    
    public static JointOwner__c createJointOwner(){
        opportunity opp=createOpportunity();
        List<Account> accountRecordsList=new List<Account>();
        
        accountRecordsList=createListOfAccont(1);
        JointOwner__c jointOwnerRecord = new JointOwner__c(Opportunity__c = opp.Id,
                                                           JointOwnerAccount__c = accountRecordsList[0].Id,
                                                           OwnershipPercentage__c = 20,
                                                           RelationshipType__c = 'Partner',
                                                           RelationshipSubType__c = 'Sibling');
        INSERT jointOwnerRecord;
        
        return jointOwnerRecord;
    }
    
    Public static Task createTask(Id taskRecordTypeId){
        Task taskRecord = new Task(
            Subject = 'Test Task',
            Status = Constants.TASK_STATUS_OPEN,
            RecordTypeId = taskRecordTypeId
        );
        insert taskRecord;
        return taskRecord;
    }
    
    public static ServiceCatalog__c createServiceCatalog(string catalogType){
        ServiceCatalog__c catalog = new ServiceCatalog__c(Service_Request_Type__c = catalogType);
        insert catalog;
        return catalog;
    } 
    
    public static List<ServiceAction__c> createListOfServiceActions(integer noOfServiceActions,Id catalogrecId){
        List<ServiceAction__c> actions = new List<ServiceAction__c>();
        for(integer i=1;i<noOfServiceActions;i++){ 
            ServiceAction__c serviceActionRec=new ServiceAction__c(
                Name = 'Initial Task+'+i,
                Order__c = i,
                TaskSubject__c = ' Subject'+i,
                ServiceCatalog__c = catalogrecId
            );actions.add(serviceActionRec);
            
        }
        insert actions;
        return actions;      
    }
    
     public static Case createCase() {
        Case c = new Case(Subject = 'Test Case',Send_Survey__C = false);
        insert c;
        return c;
    }
    
    Public static Task createTaskWithSubject(Id taskRecordTypeId,string subjct){
        Task taskRecord = new Task(
            Subject =subjct,
            Status = Constants.TASK_STATUS_OPEN,
            RecordTypeId = taskRecordTypeId
        );
        insert taskRecord;
        return taskRecord;
    }
    
    public static Prospect_Account__c createProspectAccount(Id praccRecordTypeId,id srId){   
        Prospect_Account__c prospect1 = new Prospect_Account__c(
            Account_Name__c = 'Test Business Account',
            Account_Type__c = 'Broker Agency',
            Description__c = 'Business description',
            LegalStructure__c = 'Foreign Company (Non UAE based)',
            profileId__c = '12345',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Salary',
            OtherSourceOfIncome__c = 'Investments',
            TradeLicenseExpiryDate__c = Date.today().addYears(1),
            UAE_Resident_Status__c = 'Resident',
            UAEVATRegisterNumber__c = 'VAT12345',
            UnifiedNumber__c = 'UN12345',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'Other',
            IsTheBusinessEntityRealBeneficiary__c = true,
            //Mobile__c = '1234567890',
            Mobile__c = '+971666777888',
            DateOfEstablishment__c = Date.today().addYears(-5),
            Country__c = 'UAE',
            State__c = 'Abu Dhabi',
            City__c = 'Abu Dhabi',
            Service_Request__c = srId,
            Street__c = 'Street 1',
            PostalCode__c = '00000',
            IsPersonAccount__c =true,
            recordtypeId=praccRecordTypeId
        );
        Insert prospect1 ; 
        
        return prospect1;
    }
    
     public static Lead createModonEgyptLead(String firstName, String lastName, String egyptianId, String status,String mobile) {
        Lead testLead = new Lead(
            FirstName = firstName,
            LastName = lastName,
            Source_Entity__c = 'Modon - Egypt',
            Egyptian_ID__c = egyptianId,
            Status = status,
            MobilePhone = mobile,
            Email = firstName.toLowerCase() + '.' + lastName.toLowerCase() + '@testmail.com',
            LeadSource='800-Modon',
            ProjectInterest__c = 'Ras El Hekma, Egypt'  
        );
        return testLead;
    }
    
    public static void createRoundRobinRecords(List<User> associates) {
        List<Egypt_Round_Robin_Assignment_Matrix__c> records = new List<Egypt_Round_Robin_Assignment_Matrix__c>();
        
        Integer counter = 1;
        for (User assoc : associates) {
            records.add(new Egypt_Round_Robin_Assignment_Matrix__c(
                User__c = assoc.Id,
                User_Number__c = counter
            ));
            counter++;
        }

        insert records;
    }
    
    public static User createDirectorUser() {
        User director = new User(
            FirstName = 'Director',
            LastName = 'One',
            Email = 'director@example.com',
            Username = 'director@example.com.test',
            Alias = 'dir1',
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Modon Egypt - Sales Management' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US'
        );
        insert director;
        return director;
    }

    public static User createManagerUser(Id directorId , String nameSuffix) {
        User manager = new User(
            FirstName = 'Manager',
            LastName = nameSuffix,
            Email = 'associate' + nameSuffix + '@example.com',
            Username = 'associate' + nameSuffix + '@example.com.test',
            Alias = 'mgr1',
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Modon Egypt - Sales Management' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US',
            ManagerId = directorId
        );
        insert manager;
        return manager;
    }

    public static User createAssociateUser(String nameSuffix, Id managerId) {
        User associate = new User(
            FirstName = 'Associate',
            LastName = nameSuffix,
            Email = 'associate' + nameSuffix + '@example.com',
            Username = 'associate' + nameSuffix + '@example.com.test',
            Alias = 'asc',
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Modon Egypt - Sales Management' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US',
            ManagerId = managerId
        );
        insert associate;
        return associate;
    }    
}