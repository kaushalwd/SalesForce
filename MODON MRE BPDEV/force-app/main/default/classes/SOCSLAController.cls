/**
 * @***************************************           : ***************************************
 * @Name                                              : Enter description here
 * @Description                                       : Enter description here
 * @Usage                                             : Enter usage here
 * @Author                                            : AMGS
 * @------------------------------------------------  : ------------------------------------------------
 * @Version Comment                                   : 1.0
 * @Author                                            : Fatima Khan
 * @Date                                              : 10-23-2025
 * @***************************************           : ***************************************

public with sharing class SOCSLAController {
    @AuraEnabled
    public static SalesOrder__c updateAndFetchSLA(Id recordId) {
        SalesOrder__c so = [
            SELECT Id, SLA_Start_Date_Time__c, SLA_End_Date_Time__c, SLA_Hours__c, Sub_Status__c
            FROM SalesOrder__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        if (so.SLA_Start_Date_Time__c != null && so.SLA_Hours__c != null) {
            Decimal hours = so.SLA_Hours__c;

            Integer wholeHours = Math.floor(hours).intValue();
            Integer minutes = Math.round((hours - wholeHours) * 60);

            Datetime endTime = so.SLA_Start_Date_Time__c
                .addHours(wholeHours)
                .addMinutes(minutes);

            so.SLA_End_Date_Time__c = endTime;
            update so;
        }

        return [
            SELECT Id, SLA_Start_Date_Time__c, SLA_End_Date_Time__c, SLA_Hours__c, Sub_Status__c
            FROM SalesOrder__c
            WHERE Id = :recordId
            LIMIT 1
        ];
    }
     @AuraEnabled
    public static void upsertTaskRecord(
        Id whatId,
        Id ownerId,
        String subject,
        Date dueDate,
        String status,
        Id taskId
    ) {
        Task task;
        if (taskId != null) {
            try {
                task = [SELECT Id FROM Task WHERE Id = :taskId LIMIT 1];
            } catch (Exception e) {
                task = null;
            }
        }

        if (task == null) {
            task = new Task();
        }

        task.WhatId = whatId;
        task.OwnerId = ownerId;
        task.Subject = subject;
        task.ActivityDate = dueDate;
        task.Status = status;

        upsert task;
    }
}
**/
public with sharing class SOCSLAController {

   

    @AuraEnabled
    public static SalesOrder__c updateAndFetchSLA(Id recordId) {
        SalesOrder__c so = [
            SELECT Id, SLA_Start_Date_Time__c, SLA_End_Date_Time__c, SLA_Hours__c, Sub_Status__c, OwnerId
            FROM SalesOrder__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        if (so.SLA_Hours__c == null || so.SLA_Hours__c == 0) {
            so.SLA_Start_Date_Time__c = null;
            so.SLA_End_Date_Time__c = null;
            return so; 
        }

        if (so.SLA_Start_Date_Time__c != null && so.SLA_Hours__c != null) {
            Decimal hours = so.SLA_Hours__c;
            Integer wholeHours = Math.floor(hours).intValue();
            Integer minutes = Math.round((hours - wholeHours) * 60);

            Datetime endTime = so.SLA_Start_Date_Time__c
                .addHours(wholeHours)
                .addMinutes(minutes);

            so.SLA_End_Date_Time__c = endTime;
            //update so;
        }

        // if (so.SLA_End_Date_Time__c != null && so.SLA_End_Date_Time__c < System.now()) {
        //     upsertTaskRecord(
        //         so.Id,                      
        //         so.OwnerId,                  
        //         'Overdue SLA Follow-up',    
        //         Date.today(),               
        //         'Open',                      
        //         null                         
        //     );
        // }

        return [
            SELECT Id, SLA_Start_Date_Time__c, SLA_End_Date_Time__c, SLA_Hours__c, Sub_Status__c
            FROM SalesOrder__c
            WHERE Id = :recordId
            LIMIT 1
        ];
    }

    @AuraEnabled(cacheable=true)
    public static SalesOrder__c getSLAFields(Id recordId) {
        return [
            SELECT Id, SLA_Start_Date_Time__c, SLA_End_Date_Time__c, Sub_Status__c
            FROM SalesOrder__c
            WHERE Id = :recordId
            LIMIT 1
        ];
    }




    @AuraEnabled
    public static void upsertTaskRecord(
        Id whatId,
        Id ownerId,
        String subject,
        Date dueDate,
        String status,
        Id taskId
    ) {
        Task task;
        if (taskId != null) {
            try {
                task = [SELECT Id FROM Task WHERE Id = :taskId LIMIT 1];
            } catch (Exception e) {
                task = null;
            }
        }

        if (task == null) {
            task = new Task();
        }

        task.WhatId = whatId;
        task.OwnerId = ownerId;
        task.Subject = subject;
        task.ActivityDate = dueDate;
        task.Status = status;

        upsert task;
    }
}