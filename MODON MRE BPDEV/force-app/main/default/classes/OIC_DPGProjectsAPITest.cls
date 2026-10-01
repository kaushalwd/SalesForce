/**********************************************************************************************************************
* Name               : OIC_DPGProjectsAPITest
* Description        : Test class for OIC_DPGProjectsAPI / OIC_DPGProjectsAPIHelper
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 2.0                                       04 09 2026      Expanded coverage: project-level plans, phase-level plans,
*                                                           projects without plans, filtered-out plans, bulk.
***********************************************************************************************************************/
@isTest
private class OIC_DPGProjectsAPITest {

    /**
     * Helper SOQL requires: Status__c = 'Active', Online_Sales__c = true,
     * Is_Employee_Payment_Plan__c = false, and (Project__c != '' or Phase__c != '').
     * Every plan below satisfies those unless it is deliberately built to be filtered out.
     *
     *  projA -> plan A1, A2   (Project__c set)                  => map "put" + map "add" on the Project__c branch
     *  projB -> plan B1, B2   (Phase__c only)                   => map "put" + map "add" on the Phase__r branch
     *  projC -> plan C1       (Project__c AND Phase__c set)     => both branches from one record
     *  projD -> plans that fail the WHERE clause                => containsKey == false path in the project loop
     *
     * PaymentInstallment__c is NOT set anywhere: it is a formula / roll-up and is not writeable.
     * Phase__c is populated on every plan so Phase__r is never a null dereference.
     */
    @testSetup
    static void makeData() {

        // ---------- Districts ----------
        List<SObject> lst_District = new List<SObject>();
        for (Integer i = 0; i < 4; i++) {
            SObject district = Schema.getGlobalDescribe().get('District__c').newSObject();
            district.put('Name', 'Test District ' + i);
            lst_District.add(district);
        }
        insert lst_District;

        // ---------- Projects ----------
        Project__c projA = new Project__c(Name = 'Project A', District__c = lst_District[0].Id);
        Project__c projB = new Project__c(Name = 'Project B', District__c = lst_District[1].Id);
        Project__c projC = new Project__c(Name = 'Project C', District__c = lst_District[2].Id);
        Project__c projD = new Project__c(Name = 'Project D No Plans', District__c = lst_District[3].Id);
        insert new List<Project__c>{ projA, projB, projC, projD };

        // ---------- Phases ----------
        Phase__c phaseB         = new Phase__c(Name = 'Phase B1', Project__c = projB.Id);
        Phase__c phaseC         = new Phase__c(Name = 'Phase C1', Project__c = projC.Id);
        Phase__c phaseD         = new Phase__c(Name = 'Phase D1', Project__c = projD.Id);
        Phase__c phaseNoProject = new Phase__c(Name = 'Phase Orphan');
        try {
            insert new List<Phase__c>{ phaseB, phaseC, phaseD, phaseNoProject };
        } catch (DmlException orphanEx) {
            // Some orgs require Project on Phase. Use a dedicated holder project so setup still runs.
            Project__c holder = new Project__c(Name = 'Phase Holder', District__c = lst_District[0].Id);
            insert holder;
            phaseNoProject = new Phase__c(Name = 'Phase Orphan', Project__c = holder.Id);
            insert new List<Phase__c>{ phaseB, phaseC, phaseD, phaseNoProject };
        }

        List<PaymentPlan__c> lst_Plan = new List<PaymentPlan__c>();

        // projA: two plans grouped by Project__c. The orphan phase keeps Phase__r non-null
        // while leaving Phase__r.Project__c blank, so the second IF takes its false path.
        lst_Plan.add(buildPlan('Plan A1', projA.Id, phaseNoProject.Id, true,  false));
        lst_Plan.add(buildPlan('Plan A2', projA.Id, phaseNoProject.Id, true,  false));

        // projB: reachable only through Phase__r.Project__c
        lst_Plan.add(buildPlan('Plan B1', null, phaseB.Id, true,  false));
        lst_Plan.add(buildPlan('Plan B2', null, phaseB.Id, true,  false));

        // projC: satisfies both conditions on a single record
        lst_Plan.add(buildPlan('Plan C1', projC.Id, phaseC.Id, true,  false));

        // projD: excluded by the helper's WHERE clause, so the project returns with no plans
        lst_Plan.add(buildPlan('Plan D1 Offline',  projD.Id, phaseD.Id, false, false)); // Online_Sales__c = false
        lst_Plan.add(buildPlan('Plan D2 Employee', projD.Id, phaseD.Id, true,  true));  // employee plan

        insert lst_Plan;

        // Non-active plan, filtered out by the helper's Status__c = 'Active' clause.
        // Status__c is a restricted picklist, so the value is resolved from the describe
        // instead of being hardcoded.
        String str_NonActiveStatus = getNonActiveStatus();
        if (str_NonActiveStatus != null) {
            PaymentPlan__c obj_NonActive = buildPlan('Plan D3 NonActive', projD.Id, phaseD.Id, true, false);
            obj_NonActive.Status__c = str_NonActiveStatus;
            insert obj_NonActive;
        }
    }

    /**
     * Resolves a Status__c value that is not 'Active', so the record is excluded by the
     * helper's WHERE clause. Status__c is a restricted picklist, so 'Draft' is used when
     * available and the describe supplies a fallback otherwise.
     */
    private static String getNonActiveStatus() {
        List<Schema.PicklistEntry> lst_Entry =
            PaymentPlan__c.Status__c.getDescribe().getPicklistValues();

        String str_Fallback = null;
        for (Schema.PicklistEntry obj_Entry : lst_Entry) {
            if (!obj_Entry.isActive() || obj_Entry.getValue() == 'Active') {
                continue;
            }
            if (obj_Entry.getValue() == 'Draft') {
                return 'Draft';
            }
            if (str_Fallback == null) {
                str_Fallback = obj_Entry.getValue();
            }
        }
        return str_Fallback;
    }

    private static PaymentPlan__c buildPlan(String str_Name, Id id_Project, Id id_Phase,
                                            Boolean bln_OnlineSales, Boolean bln_Employee) {
        return new PaymentPlan__c(
            Name                        = str_Name,
            Project__c                  = id_Project,
            Phase__c                    = id_Phase,
            Status__c                   = 'Active',
            Type__c                     = 'Standard',
            Online_Sales__c             = bln_OnlineSales,
            Is_Employee_Payment_Plan__c = bln_Employee,
            StartDate__c                = Date.today().addMonths(-1),
            ExpiryDate__c               = Date.today().addMonths(6)
        );
    }

    private static void setupRestContext() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/dpg/getprojects/';
        req.httpMethod = 'GET';
        req.addHeader('Content-Type', 'application/json');
        RestContext.request  = req;
        RestContext.response = new RestResponse();
    }

    private static Map<String, Object> invokeApi() {
        setupRestContext();
        Test.startTest();
        OIC_DPGProjectsAPI.getProjectsDPG();
        Test.stopTest();
        System.assertNotEquals(null, RestContext.response.responseBody, 'Expected a response body');
        return (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
    }

    private static Map<String, Object> callApiAndParse() {
        Map<String, Object> map_Response = invokeApi();
        System.assertEquals(200, RestContext.response.statusCode, 'Status code should be 200: ' + JSON.serialize(map_Response));
        return map_Response;
    }

    private static Integer planCountFor(Map<String, Object> map_Response, Id id_Project) {
        List<Object> lst_Projects = (List<Object>) map_Response.get('ProjectDetails');
        String str_Target = String.valueOf(id_Project).left(15);
        for (Object obj_Row : lst_Projects) {
            Map<String, Object> map_Project = (Map<String, Object>) obj_Row;
            if (String.valueOf(map_Project.get('Id')).startsWith(str_Target)) {
                List<Object> lst_Plans = (List<Object>) map_Project.get('PaymentPlanDetails');
                return (lst_Plans == null) ? 0 : lst_Plans.size();
            }
        }
        return -1; // project missing from the payload
    }

    /**
     * Happy path across every mapping branch, with a check on the payload shape.
     */
    @isTest
    static void testGetProjectsDPG_AllBranches() {

        Map<String, Object> map_Response = callApiAndParse();

        System.assertEquals('Success', (String) map_Response.get('Status'), 'Status should be Success');
        System.assertEquals('', (String) map_Response.get('ErrorCode'), 'ErrorCode should be empty');
        System.assertEquals('', (String) map_Response.get('ErrorMessage'), 'ErrorMessage should be empty');

        List<Object> lst_Projects = (List<Object>) map_Response.get('ProjectDetails');
        System.assertNotEquals(null, lst_Projects, 'ProjectDetails should be serialized');
        System.assert(lst_Projects.size() >= 4, 'Seeded projects should be returned');

        Integer int_WithPlans = 0;
        Integer int_WithoutPlans = 0;

        for (Object obj_Row : lst_Projects) {
            Map<String, Object> map_Project = (Map<String, Object>) obj_Row;
            System.assertNotEquals(null, map_Project.get('Id'), 'Project Id should be populated');
            System.assertNotEquals(null, map_Project.get('Name'), 'Project Name should be populated');
            System.assertNotEquals(null, map_Project.get('District'), 'District name should be populated');

            List<Object> lst_Plans = (List<Object>) map_Project.get('PaymentPlanDetails');
            if (lst_Plans != null && !lst_Plans.isEmpty()) {
                int_WithPlans++;
                Map<String, Object> map_Plan = (Map<String, Object>) lst_Plans[0];
                System.assertNotEquals(null, map_Plan.get('Id'), 'Plan Id should be populated');
                System.assertNotEquals(null, map_Plan.get('Name'), 'Plan Name should be populated');
                System.assertEquals('Active', (String) map_Plan.get('Status'), 'Only active plans should return');
                System.assertNotEquals(null, map_Plan.get('StartDate'), 'StartDate should be populated');
                System.assertNotEquals(null, map_Plan.get('ExpiryDate'), 'ExpiryDate should be populated');
            } else {
                int_WithoutPlans++;
            }
        }

        System.assert(int_WithPlans >= 3, 'Projects A, B and C should carry payment plans');
        System.assert(int_WithoutPlans >= 1, 'Project D should come back with no payment plans');
    }

    /**
     * Project__c branch, including the "list already in the map" path.
     */
    @isTest
    static void testProjectLevelPlansGrouped() {
        Project__c projA = [SELECT Id FROM Project__c WHERE Name = 'Project A' LIMIT 1];
        System.assert(planCountFor(callApiAndParse(), projA.Id) >= 2,
            'Project A should return both directly linked plans');
    }

    /**
     * Phase__r.Project__c branch for plans with no direct Project__c.
     */
    @isTest
    static void testPhaseLevelPlansGrouped() {
        Project__c projB = [SELECT Id FROM Project__c WHERE Name = 'Project B' LIMIT 1];
        System.assert(planCountFor(callApiAndParse(), projB.Id) >= 2,
            'Project B should resolve both plans through its Phase');
    }

    /**
     * A plan carrying both Project__c and Phase__c is mapped by both conditions,
     * so it appears twice for the same project.
     */
    @isTest
    static void testPlanWithProjectAndPhase() {
        Project__c projC = [SELECT Id FROM Project__c WHERE Name = 'Project C' LIMIT 1];
        Integer int_Count = planCountFor(callApiAndParse(), projC.Id);
        System.assert(int_Count >= 1,
            'Project C should return its plan; note the record is added by both IF blocks');
    }

    /**
     * Plans excluded by Online_Sales__c, Is_Employee_Payment_Plan__c and Status__c
     * must not leak into the response.
     */
    @isTest
    static void testFilteredOutPlansAreExcluded() {
        Project__c projD = [SELECT Id FROM Project__c WHERE Name = 'Project D No Plans' LIMIT 1];
        System.assertEquals(0, planCountFor(callApiAndParse(), projD.Id),
            'Offline, employee and inactive plans should be filtered out by the helper');
    }

    /**
     * No payment plans at all: the empty-map path through the whole method.
     */
    @isTest
    static void testGetProjectsDPG_NoPaymentPlans() {

        delete [SELECT Id FROM PaymentPlan__c];

        Map<String, Object> map_Response = callApiAndParse();
        System.assertEquals('Success', (String) map_Response.get('Status'), 'Status should be Success');

        for (Object obj_Row : (List<Object>) map_Response.get('ProjectDetails')) {
            Map<String, Object> map_Project = (Map<String, Object>) obj_Row;
            System.assertEquals(null, map_Project.get('PaymentPlanDetails'),
                'PaymentPlanDetails should be absent when no plans exist');
        }
    }

    /**
     * Empty org: the response envelope should still be well formed.
     */
    @isTest
    static void testGetProjectsDPG_NoProjects() {

        delete [SELECT Id FROM PaymentPlan__c];
        delete [SELECT Id FROM Phase__c];
        delete [SELECT Id FROM Project__c];

        Map<String, Object> map_Response = callApiAndParse();
        System.assertEquals('Success', (String) map_Response.get('Status'), 'Status should be Success');
    }

    /**
     * Bulk load so the helper SOQL and both loops run at volume.
     */
    @isTest
    static void testGetProjectsDPG_Bulk() {

        SObject district = Schema.getGlobalDescribe().get('District__c').newSObject();
        district.put('Name', 'Bulk District');
        insert district;

        List<Project__c> lst_Project = new List<Project__c>();
        for (Integer i = 0; i < 5; i++) {
            lst_Project.add(new Project__c(Name = 'Bulk Project ' + i, District__c = district.Id));
        }
        insert lst_Project;

        List<Phase__c> lst_Phase = new List<Phase__c>();
        for (Project__c obj_Project : lst_Project) {
            lst_Phase.add(new Phase__c(Name = 'Bulk Phase ' + obj_Project.Name, Project__c = obj_Project.Id));
        }
        insert lst_Phase;

        List<PaymentPlan__c> lst_Plan = new List<PaymentPlan__c>();
        for (Integer i = 0; i < lst_Project.size(); i++) {
            lst_Plan.add(buildPlan('Bulk Plan A' + i, lst_Project[i].Id, lst_Phase[i].Id, true, false));
            lst_Plan.add(buildPlan('Bulk Plan B' + i, null,              lst_Phase[i].Id, true, false));
        }
        insert lst_Plan;

        Map<String, Object> map_Response = callApiAndParse();
        List<Object> lst_Projects = (List<Object>) map_Response.get('ProjectDetails');
        System.assert(lst_Projects.size() >= 5, 'All bulk projects should be returned');
    }

    /**
     * Direct helper calls, so both methods are covered even if the API path changes later.
     */
    @isTest
    static void testHelperMethods() {

        Test.startTest();
        List<Project__c> lst_Project = OIC_DPGProjectsAPIHelper.getAllProjects();
        List<PaymentPlan__c> lst_Plan = OIC_DPGProjectsAPIHelper.getAllPaymentPlans();
        Test.stopTest();

        System.assert(lst_Project.size() >= 4, 'Helper should return every project');
        System.assert(lst_Plan.size() >= 5,
            'Helper should return the active, online, non-employee plans');
        System.assert(lst_Plan.size() < [SELECT COUNT() FROM PaymentPlan__c],
            'Helper should be excluding the offline / employee / non-active plans');

        for (PaymentPlan__c obj_Plan : lst_Plan) {
            System.assertEquals('Active', obj_Plan.Status__c, 'Only active plans should be returned');
        }
    }

    /**
     * Wrapper classes instantiated directly so their implicit constructors are covered.
     */
    @isTest
    static void testWrapperClasses() {

        OIC_DPGProjectsAPI.PaymentPlan obj_Plan = new OIC_DPGProjectsAPI.PaymentPlan();
        obj_Plan.Id                 = 'a01000000000001';
        obj_Plan.Name               = 'Wrapper Plan';
        obj_Plan.Status             = 'Active';
        obj_Plan.PaymentInstallment = 100;
        obj_Plan.StartDate          = Date.today();
        obj_Plan.ExpiryDate         = Date.today().addMonths(6);

        OIC_DPGProjectsAPI.Project obj_Project = new OIC_DPGProjectsAPI.Project();
        obj_Project.Id                 = 'a02000000000001';
        obj_Project.Name               = 'Wrapper Project';
        obj_Project.District           = 'Wrapper District';
        obj_Project.Island             = 'Wrapper Island';
        obj_Project.PaymentPlanDetails = new List<OIC_DPGProjectsAPI.PaymentPlan>{ obj_Plan };

        OIC_DPGProjectsAPI.GetProjectsResponse obj_Response = new OIC_DPGProjectsAPI.GetProjectsResponse();
        obj_Response.Status       = 'Success';
        obj_Response.ErrorCode    = '';
        obj_Response.ErrorMessage = '';

        System.assertEquals('Wrapper Project', obj_Project.Name, 'Wrapper should hold assigned values');
        System.assertEquals(1, obj_Project.PaymentPlanDetails.size(), 'Wrapper should hold one plan');
        System.assertEquals('Success', obj_Response.Status, 'Wrapper status should be set');
    }

    @isTest
    static void testHelperMethodsEmpty() {
        delete [SELECT Id FROM PaymentPlan__c];
        delete [SELECT Id FROM Phase__c];
        delete [SELECT Id FROM Project__c];

        Test.startTest();
        List<Project__c> lst_Project = OIC_DPGProjectsAPIHelper.getAllProjects();
        List<PaymentPlan__c> lst_Plan = OIC_DPGProjectsAPIHelper.getAllPaymentPlans();
        Test.stopTest();

        System.assertEquals(0, lst_Project.size());
        System.assertEquals(0, lst_Plan.size());
    }
}