/**********************************************************************************************************************
* Name               : HousingApplicationApi
* Author             : Prateek
* Created On         : 2026-01-19
* Description        : REST API to create/update Housing_Application__c. Supports safe partial updates for status changes.
* URL                : /services/apexrest/v1/housing/applications
**********************************************************************************************************************/
@RestResource(urlMapping='/v1/housing/applications/*')
global with sharing class ADHA_HousingApplicationApi {

    private static final Set<String> ALLOWED_STATUS = new Set<String>{
        'Init', 'PC_Approved', 'PC_Rejected', 'Canceled', 'Cancel_Rejected'
    };

    global class ApplicationRequest {
        public String ApplicationNumber;
        public Applicant Applicant;
        public Decimal LoanValue;
        public Project Project;
        public String Status;
        public Notes Notes;
    }

    global class Applicant {
        public String Name;
        public String Tribe;
        public String Gender;
        public String DOB; // YYYY-MM-DD
        public String EID;
        public String TownName;
        public String FamilyName;
        public String MaritalStatus;
        public Integer NumberOfWives;
        public Integer NumberOfChildren;
        public String PhoneNumber;
        public Decimal Salary;
        public String Email;
        public Passport Passport;
    }

       global class Passport {
    public String PassportNumber;
    public String IssueDate;
    public String ExpiryDate;
}
    
    global class Project {
        public String ProjectID;
        public String Municipality;
        public String Region;
        public String District;
    }

    global class Notes {
        public String Authority;
    }

    global class ApiResponseSuccess {
        public String message;
        public Integer code;
        public String DeveloperReferenceNumber;
        public ApiResponseSuccess(String refNo) {
            message = 'success';
            code = 200;
            DeveloperReferenceNumber = refNo;
        }
    }

    global class ApiResponseError {
        public String message;
        public String code;
        public ApiResponseError(String msg, String codeStr) {
            message = msg;
            code = codeStr;
        }
    }

    @HttpPost
    global static void submitOrUpdateApplication() {
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        try {
            String raw = (RestContext.request.requestBody == null) ? null : RestContext.request.requestBody.toString();
            if (String.isBlank(raw)) {
                writeError(400, 'Request body is empty.');
                return;
            }

            ApplicationRequest body = (ApplicationRequest) JSON.deserialize(raw, ApplicationRequest.class);
            if (body == null) {
                writeError(400, 'Invalid JSON payload.');
                return;
            }

            // Status is required for both create and update (as per your requirement).
            if (String.isBlank(body.Status)) {
                writeError(400, 'Status is required.');
                return;
            }
            if (!ALLOWED_STATUS.contains(body.Status)) {
                writeError(400, 'Invalid Status. Allowed values: Init, PC_Approved, PC_Rejected, Canceled, Cancel_Rejected.');
                return;
            }

            Boolean hasAppNumber = !String.isBlank(body.ApplicationNumber);
            Housing_Application__c app;
            Boolean isUpdate = false;

            // If ApplicationNumber provided, try to find existing record first (safe update scenario).
            if (hasAppNumber) {
                String appNo = body.ApplicationNumber.trim();
                List<Housing_Application__c> existing = [
                    SELECT Id,
                           Application_Number__c,
                           Status__c,
                           Applicant_Name__c,
                           Tribe__c,
                           Gender__c,
                           Date_of_Birth__c,
                           Emirates_ID__c,
                           Town_Name__c,
                           Family_Name__c,
                           Marital_Status__c,
                           Number_Of_Wives__c,
                           Number_Of_Children__c,
                           Phone_Number__c,
                           Salary__c,
                           Project_ID__c,
                           Municipality__c,
                           Region__c,
                           District__c,
                           Authority_Notes__c,
                           Email__c,
                           LoanValue__c,
                           Passport_expiry_date__c,
                           Passport_Issue_Date__c,
                           Passport_Number__c 
                    FROM Housing_Application__c
                    WHERE Application_Number__c = :appNo
                    LIMIT 1
                ];

                if (!existing.isEmpty()) {
                    app = existing[0];
                    isUpdate = true;
                } else {
                    app = new Housing_Application__c(Application_Number__c = appNo);
                }
            } else {
                app = new Housing_Application__c();
            }

            // CREATE validation: if record is new (not found) then Applicant + Project must be present
            // because we don't want “status-only” creating incomplete applications.
            if (!isUpdate) {
                if (body.Applicant == null) { writeError(400, 'Applicant is required for new application creation.'); return; }
                if (body.Project == null)   { writeError(400, 'Project is required for new application creation.'); return; }
                if (!hasAppNumber)          { writeError(400, 'ApplicationNumber is required for new application creation.'); return; }
            }

            // Always update Status (requested)
            app.Status__c = body.Status;

            // Notes: update only if Notes object is present in JSON (avoid wiping existing)
            if (body.Notes != null) {
                // If Authority is explicitly provided as blank, we still keep it blank (caller intent).
                app.Authority_Notes__c = safeTrim(body.Notes.Authority);
            }

            // Applicant: update only if Applicant object is present in JSON
            if (body.Applicant != null) {
                Date dob = parseDobOrNull(body.Applicant.DOB);
                if (body.Applicant.DOB != null && dob == null) {
                    writeError(400, 'Invalid Applicant.DOB. Expected format: YYYY-MM-DD.');
                    return;
                }

                // Assign only when field was sent (null means not sent OR explicitly null; in JSON->Apex it becomes null).
                // If you want to support explicit clearing, tell me and I’ll add a separate flag.
                if (body.Applicant.Name != null)          app.Applicant_Name__c = safeTrim(body.Applicant.Name);
                if (body.Applicant.Tribe != null)         app.Tribe__c = safeTrim(body.Applicant.Tribe);
                if (body.Applicant.Gender != null)        app.Gender__c = safeTrim(body.Applicant.Gender);
                if (body.Applicant.DOB != null)           app.Date_Of_Birth__c = dob;
                if (body.Applicant.EID != null)           app.Emirates_Id__c = safeTrim(body.Applicant.EID);
                if (body.Applicant.TownName != null)      app.Town_Name__c = safeTrim(body.Applicant.TownName);
                if (body.Applicant.FamilyName != null)    app.Family_Name__c = safeTrim(body.Applicant.FamilyName);
                if (body.Applicant.MaritalStatus != null) app.Marital_Status__c = safeTrim(body.Applicant.MaritalStatus);
                if (body.Applicant.NumberOfWives != null) app.Number_Of_Wives__c = body.Applicant.NumberOfWives;
                if (body.Applicant.NumberOfChildren != null) app.Number_Of_Children__c = body.Applicant.NumberOfChildren;
                if (body.Applicant.PhoneNumber != null)   app.Phone_Number__c = safeTrim(body.Applicant.PhoneNumber);
                if (body.Applicant.Salary != null)        app.Salary__c = body.Applicant.Salary;
                if (body.Applicant.Email != null)         app.Email__c = body.Applicant.Email;
            }

            if (body.Applicant.Passport != null) {

    if (body.Applicant.Passport.PassportNumber != null) {
        app.Passport_Number__c =
            safeTrim(body.Applicant.Passport.PassportNumber);
    }

    if (body.Applicant.Passport.IssueDate != null) {

        Date issueDate =
            parseDobOrNull(body.Applicant.Passport.IssueDate);

        if (issueDate == null) {
            writeError(
                400,
                'Invalid Applicant.Passport.IssueDate. Expected format: YYYY-MM-DD.'
            );
            return;
        }

        app.Passport_Issue_Date__c = issueDate;
    }
if (body.LoanValue != null) {
    app.LoanValue__c = body.LoanValue;
}
                
    if (body.Applicant.Passport.ExpiryDate != null) {

        Date expiryDate =
            parseDobOrNull(body.Applicant.Passport.ExpiryDate);

        if (expiryDate == null) {
            writeError(
                400,
                'Invalid Applicant.Passport.ExpiryDate. Expected format: YYYY-MM-DD.'
            );
            return;
        }

        app.Passport_expiry_date__c = expiryDate;
    }
}
            
            
            // Project: update only if Project object is present in JSON
            if (body.Project != null) {
                if (body.Project.ProjectID != null)     app.Project_ID__c = safeTrim(body.Project.ProjectID);
                if (body.Project.Municipality != null)  app.Municipality__c = safeTrim(body.Project.Municipality);
                if (body.Project.Region != null)        app.Region__c = safeTrim(body.Project.Region);
                if (body.Project.District != null)      app.District__c = safeTrim(body.Project.District);
            }
            
            // DML
            if (isUpdate) {
                update app;
            } else {
                insert app;
            }

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(new ApiResponseSuccess(String.valueOf(app.Id))));

        } catch (DmlException dmle) {
            writeError(500, dmle.getDmlMessage(0));
        } catch (Exception e) {
            writeError(500, e.getMessage());
        }
    }

    private static Date parseDobOrNull(String dobStr) {
        if (dobStr == null) return null;
        String s = dobStr.trim();
        if (String.isBlank(s)) return null;
        try {
            return Date.valueOf(s); // YYYY-MM-DD
        } catch (Exception e) {
            return null;
        }
    }

    private static void writeError(Integer httpStatus, String msg) {
        RestContext.response.statusCode = httpStatus;
        String codeStr = String.valueOf(httpStatus == 400 ? 400 : 500);
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(new ApiResponseError(msg, codeStr)));
    }

    private static String safeTrim(String s) {
        return (s == null) ? null : s.trim();
    }
}