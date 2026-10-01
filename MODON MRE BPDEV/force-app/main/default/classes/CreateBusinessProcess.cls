/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
* 2.0           sivannaryana.p@modon.com     20-07-2026      Default Process Changes
* 3.0           sivannaryana.p@modon.com     30-07-2026      Default Process Changes 
**********************************************************************************************************************/
public without sharing class CreateBusinessProcess {
     
    @AuraEnabled(cacheable=true)
    public static List<Process_Flow__c> getProcessFlows(string recId) {
        Id recordId = recId;
        String sObjName = recordId.getSObjectType().getDescribe().getName();
        if(sObjName == 'Booking__c'){
           // return [SELECT Id, Name FROM Process_Flow__c where Active__c = true];
        }
        else if(sObjName == 'Tower__c'){
            //return [SELECT Id, Name FROM Process_Flow__c where Active_for_tower__c = true];
        }
        else if(sObjName == 'Unit__c'){
           // return [SELECT Id, Name FROM Process_Flow__c where Active_for_unit__c = true];
        }  
            return null;  
    }
   
    @AuraEnabled
    public static String createPreRegistration(String bookingId, String processId) {
        system.debug('****************** Create Business Process *************');
        // Validate input
        if (processId == null || processId == '') {
           return 'Invalid Inputs..!';
        }

        // 4.0 EOI Refund Approval has no booking (Sales Order / Sales Order Installment /
        // Milestone) to associate with, so bookingId is allowed to be null for that flow
        // only — every other flow keeps requiring bookingId as before.
        Process_Flow__c processflow=[select ID,Name from Process_Flow__c where ID=:processId];
        if(processflow.Name!='EOI Refund Approval'){
            if (bookingId == null || bookingId == '') {
               return 'Invalid Inputs..!';
            }
        }

         Id recordId;
         String sObjName = '';

        SalesOrder__c so=new SalesOrder__c();
        SalesOrderInstallments__c soi=new SalesOrderInstallments__c();
        if (bookingId != null && bookingId != '') {
            recordId = bookingId;
            sObjName = recordId.getSObjectType().getDescribe().getName();

            if (sObjName == 'SalesOrder__c')
               so=[Select Id,Unit__c, Unit__r.Phase__c,CustomerAccount__c,Unit__r.Phase__r.Project__c,PrimaryContact__c,Collection_Associate__c from SalesOrder__c where Id=:bookingId LIMIT 1];
             if (sObjName == 'SalesOrderInstallments__c')
               //3.0
                 soi=[Select Id,SalesOrder__c,SalesOrder__r.Unit__c, SalesOrder__r.Unit__r.Phase__c,SalesOrder__r.CustomerAccount__c,SalesOrder__r.Unit__r.Phase__r.Project__c,SalesOrder__r.Collection_Associate__c,SalesOrder__r.PrimaryContact__c from SalesOrderInstallments__c  where Id=:bookingId LIMIT 1];
        }


        // Fetch Process Flow
        
        List<Process_Flow__c> listProcess = [
            SELECT Id, Name, Active__c, /*Active_for_unit__c, Active_for_tower__c,*/
            Initial_Submitter_Roles__c, Initial_submitter_User_Ids__c,/* Initial_Submitter_Users__c,*/
            /*Is_Event__c,*/ Process_Flow_Unique_Name__c, /*Record_Creator__c, Record_Owner__c,*/Is_check_List__c,Milestone_To_Complete_In_Hours__c
            FROM Process_Flow__c
            WHERE Id = :processId
            LIMIT 1
        ];
       
        Business_Process__c objBP = new Business_Process__c();
        if (!listProcess.isEmpty()) {
            Process_Flow__c process = listProcess[0];
            // Create Business Process Object
           
           
            if (sObjName == 'SalesOrder__c') {objBP.Sales_Order__c = bookingId;
            objBP.Account__c=  so!=null && so.CustomerAccount__c!=null ? so.CustomerAccount__c: null;
            objBP.Contact__c= so!=null && so.PrimaryContact__c!=null ? so.PrimaryContact__c: null; 
            objBP.Unit__c= so!=null && so.Unit__c!=null ? so.Unit__c: null; 
            objBP.Phase__c= so!=null && objBP.Unit__c!=null && so.Unit__r.Phase__c!=null ? so.Unit__r.Phase__c: null; 
            objBP.Project__c= so!=null && objBP.Phase__c!=null && so.Unit__r.Phase__r.Project__c!=null ? so.Unit__r.Phase__r.Project__c: null;                                  
                                             }
             if (sObjName == 'SalesOrderInstallments__c') {//
            objBP.Sales_Order_Installment__c=bookingId;     
            objBP.Sales_Order__c = soi!=null ? soi.SalesOrder__c : null ;
            objBP.Account__c=  soi!=null && soi.SalesOrder__r.CustomerAccount__c!=null ? soi.SalesOrder__r.CustomerAccount__c: null;
            objBP.Contact__c= soi!=null && soi.SalesOrder__r.PrimaryContact__c!=null ? soi.SalesOrder__r.PrimaryContact__c: null; 
            objBP.Unit__c= soi!=null && soi.SalesOrder__r.Unit__c!=null ? soi.SalesOrder__r.Unit__c: null; 
            objBP.Phase__c= soi!=null && objBP.Unit__c!=null && soi.SalesOrder__r.Unit__r.Phase__c!=null ? soi.SalesOrder__r.Unit__r.Phase__c: null; 
            objBP.Project__c= so!=null && objBP.Phase__c!=null && soi.SalesOrder__r.Unit__r.Phase__r.Project__c!=null ? soi.SalesOrder__r.Unit__r.Phase__r.Project__c: null;                                  
                                             }
            if(sObjName == 'Milestone__c')   
            {
             Milestone__c mil=[Select id, Phase__c, Phase__r.Project__c from Milestone__c where Id=:bookingId];   
             objBP.Milestone__c= bookingId;  
             objBP.Phase__c=mil!=null && mil.Phase__c!=null ? mil.Phase__c: null;
             objBP.Project__c=objBP.Phase__c!=null && mil.Phase__r.Project__c!=null ? mil.Phase__r.Project__c : null;

            }                              
           
            objBP.Process_Flow__c = process.Id;
            objBP.Status__c = 'In Progress';
            objBP.Start_Date__c = System.now();
            objBP.Is_check_List__c =process.Is_check_List__c;
            objBP.Milestone_To_Complete_In_Hours__c=process.Milestone_To_Complete_In_Hours__c;
            objBP.Type__c=process.Process_Flow_Unique_Name__c;
            insert objBP;
           
            // Fetch Steps and Documents
            List<Process_Flow_Step__c> processFlowStepsList = [
                SELECT Id, Expression__c, Active__c, Description__c, Process_Flow__c, Name, canMassUpdate__c,isSingleUser__c,Is_check_List__c,Is_Process_End__c,Step_Entry_Criteria__c,Skip_Step_To_Reopen__c,
                Setp_No__c, Department__c, Department_Queue__c, Duration_To_Complete_In_Days__c,section_Name__c,Section_Number__c,Duration_To_Complete_In_Hourss__c,Is_Single_Level_Required_Info__c,Choose_Next_Owner__c,Is_Reject_Button_Required__c,Is_Required_More_Button_Required__c
                ,Is_Review_Comments_Req__c, View_review_comments__c,Is_Assigned_TO__c,Dont_Activate__c,Activate_On_Creation__c,Is_Multi_Select_Reopen__c,Is_Management_Step__c,Assigned_to_Request_Creator__c,Include_In_Reopen__c /*, ( SELECT Id,Name,Field_API_Name__c,Process_Flow_Step__c,Operator__c,Value__c  FROM Process_Flow_Step_Criterias__r )*/ FROM Process_Flow_Step__c
                WHERE Process_Flow__c = :process.Id
                AND Active__c = true order by Setp_No__c ASC
            ];
 
            // Context values for evaluation
            Map<String, Object> context = new Map<String, Object>{
                'ProfileName' => [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId()].Profile.Name
            };
           
           
            // Create Business Process Steps
            List<Business_Process_Step__c> listToCreateBPS = new List<Business_Process_Step__c>();
            Integer stepNumber = 1;
            for (Process_Flow_Step__c step : processFlowStepsList) {
                 Boolean createStep = false;
                if (step.Active__c) {
                        createStep = true;
                }
                // 5. If valid → create BPS record
                if (createStep) {
                    //3.0 
                    listToCreateBPS.add(createBusinessProcessStep(stepNumber, step, objBP.Id,so,soi));
                    stepNumber++;
                }
               
               
            }
           
            // Insert Steps
            if (!listToCreateBPS.isEmpty()) {
                insert listToCreateBPS;
            }
           
            String openOrAcceptedStepId = '';
            Map<String, String> stepNameAndIdMap = new Map<String, String>();
            for(Business_Process_Step__c step : listToCreateBPS) {
                if(step.Status__c == 'Open' || step.Status__c == 'Accepted'){
                    openOrAcceptedStepId = step.Id;
                }
                stepNameAndIdMap.put(step.Name, step.Id);
                System.debug('step.Name -->' + step.Name + ' <-- step.Id -->'+ step.Id);
            }
            if(openOrAcceptedStepId != ''){
                objBP.Current_Business_Process_Step__c = openOrAcceptedStepId;
                update objBP;
            }
 
            List<Process_Flow_Document__c> processFlowDocumentList = [
                SELECT Id, Name, Document_Upload_Criteria__c, Record_Creation_Criteria__c, Active__c, Process_Flow__c, Process_Flow_Step__r.Step_Name__c, Document_Entry_Criteria__c/*,
                ( SELECT Id,Name,Field_API_Name__c,Process_Flow_Step__c,Operator__c,Value__c  FROM Process_Flow_Step_Criterias__r )*/
                FROM Process_Flow_Document__c
                WHERE Process_Flow__c = :process.Id
                AND Active__c = true
            ];
           
            system.debug('--------------------------processFlowDocumentList = '+processFlowDocumentList.size());
           
            // Create Business Process Documents
            List<String> documentNames = new List<String>();
            List<Business_Process_Documents__c> listToCreateBDS = new List<Business_Process_Documents__c>();
            for (Process_Flow_Document__c doc : processFlowDocumentList) {
                system.debug(' doc.Id = '+doc.Id + '----------------doc.name = '+doc.Name);
                system.debug(' doc.Active__c = '+doc.Active__c);
                Boolean createDocument = false;
                if (doc.Active__c) {
                    //system.debug(' doc.Document_Entry_Criteria__c = '+doc.Document_Entry_Criteria__c);
                    //system.debug(' doc.Process_Flow_Step_Criterias__r.size() = '+doc.Process_Flow_Step_Criterias__r.size());
                    /*
                    if (doc.Document_Entry_Criteria__c != null && doc.Process_Flow_Step_Criterias__r.size() > 0) {
                       
                        // 1. Evaluate all criteria and store results
                        Map<String, Boolean> results = new Map<String, Boolean>();
                        Integer index = 1;
                        for (Process_Flow_Step_Criteria__c criteria : doc.Process_Flow_Step_Criterias__r) {
                            results.put(String.valueOf(index), evaluateDocumentCriteria(criteria, objBP));
                            System.debug(' results = '+results);
                            index++;
                        }
                        system.debug('results = '+results);
                       
                        // 2. Replace placeholders in expression with true/false
                        String expr = doc.Document_Entry_Criteria__c;
                        for (String key : results.keySet()) {
                            expr = expr.replace(key, String.valueOf(results.get(key)));
                        }
                        system.debug('expr.size()'+expr);
                       
                        // 3. Replace AND/OR with Apex boolean operators
                        expr = expr.replaceAll('AND', '&&').replaceAll('OR', '||');
                       
                        // 4. Evaluate final expression
                        createDocument = Boolean.valueOf( evaluateExpression(expr) ); // <- custom parser/evaluator
                       
                    }
                    else {*/
                        // If no criteria → always create step
                        createDocument = true;
                   // }
                }
               
               System.debug(' createDocument  ==> '+createDocument);
                // 5. If valid → create BPS record
                if (createDocument) {
                   
                     system.debug('documentNames = '+documentNames);
           
                    if(!documentNames.contains(doc.Name)) {
                        Business_Process_Documents__c newDoc = new Business_Process_Documents__c();
                        newDoc.Name = doc.Name;
                        newDoc.Business_Process__c = objBP.Id;
                        newDoc.Process_Flow_Document__c=doc.Id;
                        newDoc.Business_Process_Step_Name__c = doc.Process_Flow_Step__r.Step_Name__c;
                        if(doc.Process_Flow_Step__r.Step_Name__c != null && stepNameAndIdMap.ContainsKey(doc.Process_Flow_Step__r.Step_Name__c)) {
                            newDoc.Business_Process_Step__c =  stepNameAndIdMap.get(doc.Process_Flow_Step__r.Step_Name__c);
                        }
                       
                        listToCreateBDS.add(newDoc);
                    }
                    documentNames.add(doc.Name);
                   
                }
            }
           
            system.debug('documentNames = '+documentNames);
            system.debug('processFlowDocumentList size = '+processFlowDocumentList.size());
            system.debug('listToCreateBDS size = '+listToCreateBDS.size());
            system.debug('listToCreateBDS size = '+listToCreateBDS.size());
            system.debug('listToCreateBDS size = '+listToCreateBDS.size());
            if (!listToCreateBDS.isEmpty()) {
                insert listToCreateBDS;
            }
           
        }
        return objBP.Id;
    }
 
    Public static Business_Process_Step__c createBusinessProcessStep(Integer stepNumber, Process_Flow_Step__c objFPS, 
                                                                     Id businessProcessId, SalesOrder__c so,SalesOrderInstallments__c soi) {
        System.debug('*******************createBusinessProcessStep method called************************');                                                              
        Business_Process_Step__c newObj = new Business_Process_Step__c();
       
        if((objFPS.Description__c)!=null && (objFPS.Description__c).length()>80){
            newObj.Name = (objFPS.Description__c).substring(0, 80);
        }else{
            newObj.Name  = objFPS.Description__c;
        }
        newObj.Business_Process_Steps_Name_Custom__c = objFPS.Description__c;
        newObj.Business_Process__c = businessProcessId;
       
        newObj.Sequence__c = stepNumber;
        newObj.Step__c = 'Step '+ String.valueOf(stepNumber) ;
    
        if( stepNumber == 1 && objFPs.Dont_Activate__c==false) {
            newObj.Status__c = objFPs.isSingleUser__c ? 'Accepted' : 'Open';
            newObj.Assigned_Time__c = System.now();
        }else if(objFPs.Activate_On_Creation__c){
            newObj.Status__c = objFPs.isSingleUser__c ? 'Accepted' : 'Open';
            newObj.Assigned_Time__c = System.now();
        } else{
            newObj.Status__c = 'Not Actioned';
        }
       
        System.debug('*****************newObj = '+newObj);
        
        Id ownerId = objFPS.Department_Queue__c;
        if(objFPs.isSingleUser__c) {
            Id queueGroupId = objFPS.Department_Queue__c;        
           
            Set<Id> userIds = new Set<Id>();
            Set<Id> groupIds = new Set<Id>();
           
            for (GroupMember gm : [SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :queueGroupId ]) {
                if (gm.UserOrGroupId.getSObjectType() == User.SObjectType) {
                    userIds.add(gm.UserOrGroupId);
                } else {
                    groupIds.add(gm.UserOrGroupId);
                }
            }
           
            system.debug('groupIds --> '+groupIds);
            system.debug('userIds --> '+userIds);
            if (!groupIds.isEmpty() && userIds.isEmpty()) {
                for (GroupMember gm2 : [ SELECT UserOrGroupId FROM GroupMember WHERE GroupId IN :groupIds ]) {
                    if (gm2.UserOrGroupId.getSObjectType() == User.SObjectType) {
                        userIds.add(gm2.UserOrGroupId);
                    }
                }
                system.debug('userIds --------> '+userIds);
            }
            if(!userIds.isEmpty()){
                List<Id> userIdList = new List<Id>(userIds);
               // ownerId = userIdList[0];
                newObj.Assigned_To__c= userIdList[0];
               // newObj.Status__c='Accepted';
            }
           
        }
       //3.0 
        if(newObj.Name == 'Collections Customer Engagement' || newObj.Name == 'Send Default1 Notice' 
           || newObj.Name == 'Collections Customer Negotiations' 
           || newObj.Name == 'Customer Solutions Status Update'
           || newObj.Name == 'Send Default2 Notice'){
                System.debug('*******************Inside collection Associate Assignment***********************');
                System.debug('*******************Inside collection Associate Assignment***********************'+so.Collection_Associate__c);
               if (soi!=null && soi.SalesOrder__r.Collection_Associate__c!=null){
                   newObj.Assigned_To__c= soi.SalesOrder__r.Collection_Associate__c;
                   // newObj.Status__c='Accepted';
               }
        }
                                                                        
                                                                         
       newObj.Assign_to_the_Collection_Associate__c = objFPS.Assign_to_the_Collection_Associate__c;                                                                 
       if (newObj.Assign_to_the_Collection_Associate__c){
            newObj.Assigned_To__c= soi.SalesOrder__r.Collection_Associate__c;
       }

        system.debug('ownerId --------------------> '+ownerId);
        //newObj.Assigned_To__c= ownerId;
        newObj.Department__c = objFPS.Department__c;
        newObj.ownerId = ownerId; //objFPS.Department_Queue__c;
        newObj.Original_Queue_Id__c = objFPS.Department_Queue__c;
        newObj.TAT__c = Integer.valueOf(objFPS.Duration_To_Complete_In_Days__c);
        newObj.section_Name__c=objFPS.section_Name__c;
        newObj.Section_Number__c=objFPS.Section_Number__c;
       
        newObj.canMassUpdate__c = objFPs.canMassUpdate__c;
        newObj.isSingleUser__c = objFPs.isSingleUser__c;
        newObj.Is_check_List__c = objFPs.Is_check_List__c;
        newObj.Is_Process_End__c = objFPs.Is_Process_End__c;
        newObj.Is_Review_Comments_Req__c=objFPs.Is_Review_Comments_Req__c;
        newObj.View_review_comments__c=objFPs.View_review_comments__c;
        newObj.Milestone_To_Complete_In_Hours__c=objFPs.Duration_To_Complete_In_Hourss__c;
        newObj.Is_Single_Level_Required_Info__c=objFPs.Is_Single_Level_Required_Info__c;
        newObj.Process_Flow_Step__c=objFPs.ID;
        newObj.Is_Multi_Select_Reopen__c = objFPs.Is_Multi_Select_Reopen__c;
        newObj.Is_Management_Step__c = objFPs.Is_Management_Step__c;
        newObj.Assigned_to_Request_Creator__c = objFPs.Assigned_to_Request_Creator__c;
        newObj.Include_In_Reopen__c = objFPs.Include_In_Reopen__c;
        if( newObj.Assigned_to_Request_Creator__c ){
             newObj.Assigned_To__c= UserInfo.getUserId();                                                                  
        }
 
        newObj.Is_Reject_Button_Required__c=objFPs.Is_Reject_Button_Required__c;
        newObj.Is_Required_More_Button_Required__c=objFPs.Is_Required_More_Button_Required__c;
        newObj.Choose_Next_Owner__c=objFPs.Choose_Next_Owner__c;
        newObj.Is_Assigned_TO__c = objFPs.Is_Assigned_TO__c;
        newObj.Skip_Step_To_Reopen__c = objFPs.Skip_Step_To_Reopen__c;
        System.debug('newObj --> '+newObj);
        return newObj;
    }

    /*
    // Utility method to evaluate Step Criteria
    @TestVisible
    private static Boolean evaluateCriteria(Process_Flow_Step_Criteria__c criteria, Map<String, Object> context) {
        String fieldApi = criteria.Field_API_Name__c;
        String operator = criteria.Operator__c;
        String value = criteria.Value__c;
        Boolean result = false;
 
        // Example: resolve special cases like Profile, UserName, Booking.Name etc.
        String fieldValue = '';
        if (fieldApi == 'User.Profile.Name') {
            fieldValue = (String)context.get('ProfileName');
        } else if (fieldApi == 'User.Name') {
            fieldValue = (String)context.get('UserName');
        } else if (fieldApi == 'Booking.Name') {
            fieldValue = (String)context.get('BookingName');
        } else {
            fieldValue = ''; // fallback or extend for other fields
        }
        system.debug('fieldValue = '+fieldValue);
 
        switch on operator {
            when 'Equal To'      { result = fieldValue == value; }
            when 'Not Equal To'  { result = fieldValue != value; }
            when 'Contains'      { result = fieldValue != null && fieldValue.contains(value); }
            when 'Not Contains'  { result = fieldValue == null || !fieldValue.contains(value); }
            when 'Starts with'   { result = fieldValue != null && fieldValue.startsWith(value); }
            when 'Ends with'     { result = fieldValue != null && fieldValue.endsWith(value); }
            when else            { result = false; }
        }
        return result;
    }
    */
   
    /*
    @TestVisible
    public static Boolean evaluateDocumentCriteria(Process_Flow_Step_Criteria__c criteria, Business_Process__c bp){
        System.debug('*********************************************evaluateDocumentCriteria method called********************************************');
        Boolean result = false;
        String actualValue = '';
       
       
        String fieldApi = criteria.Field_API_Name__c;
        String operator = criteria.Operator__c;
        String expectedValue  = criteria.Value__c;
       
       
        if (String.isBlank(fieldApi) || bp == null) {
            System.debug('Missing fieldApi or Business Process is null');
            return false;
        }
       
        System.debug('bp = '+bp);
        if (bp.getSObjectType().getDescribe().fields.getMap().containsKey(fieldApi)) {
            Object val = bp.get(fieldApi);
            system.debug('val = '+val);
            if (val != null) actualValue = String.valueOf(val);
        } else {
            System.debug('Invalid Field_API_Name__c: ' + fieldApi);
            return false;
        }
       
        system.debug('actualValue = '+actualValue +'---------expectedValue = '+expectedValue);
        System.debug(' Evaluating: ' + fieldApi + ' (' + actualValue + ') ' + operator + ' ' + expectedValue);
 
        // Evaluate based on operator
        switch on operator {
            when 'Equal To' {
                result = actualValue == expectedValue;
            }
            when 'Not Equal To' {
                result = actualValue != expectedValue;
            }
            when 'Contains' {
                result = actualValue != null && actualValue.contains(expectedValue);
            }
            when 'Not Contains' {
                result = actualValue == null || !actualValue.contains(expectedValue);
            }
            when 'Starts With' {
                result = actualValue != null && actualValue.startsWith(expectedValue);
            }
            when 'Ends With' {
                result = actualValue != null && actualValue.endsWith(expectedValue);
            }
            when 'Is Blank' {
                result = String.isBlank(actualValue);
            }
            when 'Is Not Blank' {
                result = !String.isBlank(actualValue);
            }
            when else {
                System.debug(' Unsupported operator: ' + operator);
                result = false;
            }
        }
       
        system.debug(' return avlue @@@@@@@@@@@@@@@@@@@'+result);
        return result;
    }
 
    @TestVisible
    public static Boolean evaluateExpression(String expression) {
        expression = expression.replaceAll('\\s+', ''); // remove spaces
        return evaluateLogical(expression);
    }
 
    private static Boolean evaluateLogical(String expr) {
        // Simple recursive evaluator for AND/OR with parentheses
        while (expr.contains('(')) {
            String innner = expr.substring(expr.lastIndexOf('(')+1, expr.indexOf(')', expr.lastIndexOf('(')));
            Boolean innerVal = evaluateLogical(innner);
            expr = expr.substring(0, expr.lastIndexOf('(')) + innerVal + expr.substring(expr.indexOf(')', expr.lastIndexOf('('))+1);
        }
 
        // Now expr has only true/false and &&,||
        List<String> parts = expr.split('\\|\\|');
        for (String part : parts) {
            if (evaluateAndPart(part)) return true;
        }
        return false;
    }
 
    private static Boolean evaluateAndPart(String expr) {
        for (String part : expr.split('&&')) {
            if (part.trim() == 'false') return false;
        }
        return true;
    }
   */
  }