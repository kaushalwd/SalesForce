public without sharing class EscalationEmailsSend {

    public class InputParams {
        @InvocableVariable(required=true description='List of Ids')
        public string StepIds;
        
        @InvocableVariable(required=true description='Action')
        public String actionType;
         
          @InvocableVariable(required=true description='queueId')
        public String queueIds; 
    }


    @InvocableMethod(label='Send Escalation Emails 2')
    public static void getEmails(List<InputParams> inputs) {

        if (inputs == null || inputs.isEmpty()) {
            return;
        }


        String finEmails = '';
        String finCCEmails = '';
        String finBCCEmails = '';

        List<Id> stepEscalationIds = new List<Id>();

        String actionType = '';
        String queueId = '';


        /*
         * Get input values
         */
        for (InputParams input : inputs) {

            if (
                input != null &&
                !String.isBlank(input.StepIds)
            ) {

                try {

                    stepEscalationIds.add(
                        (Id) input.StepIds
                    );

                } catch (Exception e) {

                    System.debug(
                        'Invalid Step Id: ' +
                        input.StepIds
                    );

                    continue;
                }

                actionType = input.actionType;
                queueId = input.queueIds;
            }
        }


        if (stepEscalationIds.isEmpty()) {
            return;
        }


        /*
         * Get Queue/User email addresses
         */
        String memEmails = '';

        if (!String.isBlank(queueId)) {

            List<GroupMember> members = [
                SELECT
                    Id,
                    UserOrGroupId,
                    UserOrGroup.Email,
                    UserOrGroup.IsActive,
                    GroupId
                FROM GroupMember
                WHERE GroupId = :queueId
                AND UserOrGroup.IsActive = true
            ];


            if (!members.isEmpty()) {

                for (GroupMember mem : members) {

                    if (
                        !String.isBlank(
                            mem.UserOrGroup.Email
                        )
                    ) {

                        memEmails +=
                            (String.isBlank(memEmails)
                                ? ''
                                : ',') +
                            mem.UserOrGroup.Email;
                    }
                }

            } else {

                /*
                 * If queueId is actually a User Id
                 */
                List<User> userList = [
                    SELECT
                        Id,
                        Name,
                        Email
                    FROM User
                    WHERE Id = :queueId
                    LIMIT 1
                ];


                if (
                    !userList.isEmpty() &&
                    !String.isBlank(
                        userList[0].Email
                    )
                ) {

                    memEmails =
                        userList[0].Email;
                }
            }
        }


        /*
         * Get Business Process Step
         */
        List<Business_Process_Step__c> stepList = [

            SELECT
                Id,
                Name,
                Status__c,
                remainder2__c,
                remainder3__c,
                remainderDate1__c,

                Assigned_To__c,
                Assigned_To__r.Name,
                Assigned_To__r.Email,
                Assigned_To__r.ManagerId,
                Assigned_To__r.Manager.Email,
                Process_Flow_Step__r.Is_Management_Step__c,

                OwnerId,
                Owner.Name,

                Process_Flow_Step__c,

                Business_Process__r.Name,
                Business_Process__r.Type__c,

                Business_Process__r.Sales_Order__c,
                Business_Process__r.Sales_Order__r.Name,

                Business_Process__r.Unit__c,
                Business_Process__r.Unit__r.Name,

                Business_Process__r.Milestone__r.Name

            FROM Business_Process_Step__c
            WHERE Id IN :stepEscalationIds
        ];


        if (stepList.isEmpty()) {
            return;
        }


        /*
         * Get Process Flow Step Ids
         */
        Set<Id> procStepIds =
            new Set<Id>();


        for (
            Business_Process_Step__c step :
            stepList
        ) {

            if (
                step.Process_Flow_Step__c != null
            ) {

                procStepIds.add(
                    step.Process_Flow_Step__c
                );
            }
        }


        if (procStepIds.isEmpty()) {
            return;
        }


        /*
         * Get Escalation Configuration
         */
        Map<
            Id,
            List<Step_Escalation__c>
        > escMap =
            new Map<
                Id,
                List<Step_Escalation__c>
            >();


        for (
            Step_Escalation__c esc :
            [
                SELECT
                    Id,
                    Process_Flow_Step__c,
                    BCC_Email__c,
                    CC_Email__c,
                    Department_Head__c,
                    Vertical_Head__c,
                    Trigger_To__c,
                    Escalation_Trigger_Days__c

                FROM Step_Escalation__c

                WHERE Process_Flow_Step__c
                    IN :procStepIds

                ORDER BY
                    Escalation_Trigger_Days__c ASC
            ]
        ) {

            if (
                !escMap.containsKey(
                    esc.Process_Flow_Step__c
                )
            ) {

                escMap.put(
                    esc.Process_Flow_Step__c,
                    new List<Step_Escalation__c>()
                );
            }


            escMap.get(
                esc.Process_Flow_Step__c
            ).add(esc);
        }


        /*
         * Get escalation index
         */
        Integer escalationIndex;

        try {

            escalationIndex =
                Integer.valueOf(actionType);

        } catch (Exception e) {

            System.debug(
                'Invalid actionType: ' +
                actionType
            );

            return;
        }


        /*
         * Determine recipients
         */
        for (
            Business_Process_Step__c step :
            stepList
        ) {

            if (
                step.Process_Flow_Step__c == null ||
                !escMap.containsKey(
                    step.Process_Flow_Step__c
                )
            ) {

                continue;
            }


            List<Step_Escalation__c>
                escalationList =
                    escMap.get(
                        step.Process_Flow_Step__c
                    );


            if (
                escalationIndex < 0 ||
                escalationIndex >=
                    escalationList.size()
            ) {

                System.debug(
                    'Escalation index out of range: ' +
                    escalationIndex
                );

                return;
            }


            Step_Escalation__c es =
                escalationList[
                    escalationIndex
                ];


            String emailList = '';
            String ccList = '';
            String bccList = '';


            List<String> triggerValues =
                new List<String>();


            if (
                !String.isBlank(
                    es.Trigger_To__c
                )
            ) {

                triggerValues =
                    es.Trigger_To__c.split(';');
            }


            /*
             * Process Trigger To values
             */
            for (
                String triggerVal :
                triggerValues
            ) {

                triggerVal =
                    triggerVal.trim();


                /*
                 * Department Head
                 */
                if (
                    triggerVal.equalsIgnoreCase(
                        'Department Head'
                    ) &&
                    !String.isBlank(
                        es.Department_Head__c
                    )
                ) {

                    emailList +=
                        (String.isBlank(emailList)
                            ? ''
                            : ',') +
                        es.Department_Head__c;
                }


                /*
                 * Vertical Head
                 */
                if (
                    triggerVal.equalsIgnoreCase(
                        'Vertical Head'
                    ) &&
                    !String.isBlank(
                        es.Vertical_Head__c
                    )
                ) {

                    emailList +=
                        (String.isBlank(emailList)
                            ? ''
                            : ',') +
                        es.Vertical_Head__c;
                }


                /*
                 * CC Email
                 */
                if (
                    triggerVal.equalsIgnoreCase(
                        'CC Email'
                    ) &&
                    !String.isBlank(
                        es.CC_Email__c
                    )
                ) {

                    ccList +=
                        (String.isBlank(ccList)
                            ? ''
                            : ',') +
                        es.CC_Email__c;
                }


                /*
                 * BCC Email
                 */
                if (
                    triggerVal.equalsIgnoreCase(
                        'BCC Email'
                    ) &&
                    !String.isBlank(
                        es.BCC_Email__c
                    )
                ) {

                    bccList +=
                        (String.isBlank(bccList)
                            ? ''
                            : ',') +
                        es.BCC_Email__c;
                }


                /*
                 * Assigned To
                 */
                if (
                    triggerVal.equalsIgnoreCase(
                        'Assigned TO'
                    ) &&
                    step.Assigned_To__c != null &&
                    step.Assigned_To__r != null &&
                    !String.isBlank(
                        step.Assigned_To__r.Email
                    )
                ) {

                    emailList +=
                        (String.isBlank(emailList)
                            ? ''
                            : ',') +
                        step.Assigned_To__r.Email;
                }


                /*
                 * Assigned To Manager
                 */
                if (
                    triggerVal.equalsIgnoreCase(
                        'Assigned TO Manager'
                    ) &&
                    step.Assigned_To__c != null &&
                    step.Assigned_To__r != null &&
                    step.Assigned_To__r.ManagerId != null &&
                    step.Assigned_To__r.Manager != null &&
                    !String.isBlank(
                        step.Assigned_To__r.Manager.Email
                    )
                ) {

                    emailList +=
                        (String.isBlank(emailList)
                            ? ''
                            : ',') +
                        step.Assigned_To__r.Manager.Email;
                }


                /*
                 * Queue
                 */
                if (
                    triggerVal.equalsIgnoreCase(
                        'Queue'
                    ) &&
                    !String.isBlank(memEmails)
                ) {

                    emailList +=
                        (String.isBlank(emailList)
                            ? ''
                            : ',') +
                        memEmails;
                }
            }


            finEmails = emailList;
            finCCEmails = ccList;
            finBCCEmails = bccList;
        }


        /*
         * No recipients
         */
        if (String.isBlank(finEmails)) {

            System.debug(
                'No email recipients found.'
            );

            return;
        }


        /*
         * Use first step
         */
        Business_Process_Step__c step =
            stepList[0];


        /*
         * Get Email Template
         */
        List<EmailTemplate> templates = [
            SELECT
                Id,
                Subject,
                HtmlValue
            FROM EmailTemplate
            WHERE DeveloperName =
                'Business_Process_Step_Escalation_Notification'
            LIMIT 1
        ];

        EmailTemplate template;
        if (!templates.isEmpty()) {
            template = templates[0];
        } else if (Test.isRunningTest()) {
            template = new EmailTemplate(
                Subject = 'Escalation Notification',
                HtmlValue = '%%BUSINESS_PROCESS%% %%STEP_NAME%% %%STATUS%% %%RECORD_URL%% %%ASSIGNED_TO%% %%BOOKING_ROW%% %%UNIT_ROW%% %%MILESTONE_ROW%%'
            );
        } else {
            return;
        }


        String emailBody =
            template.HtmlValue;


        /*
         * Business Process Name
         */
        String businessProcessName = '';


        if (
            step.Business_Process__r != null &&
            !String.isBlank(
                step.Business_Process__r.Name
            )
        ) {

            businessProcessName =
                step.Business_Process__r.Name;
        }


        /*
         * Sales Order / Booking
         */
        String bookingName = '';

        Boolean hasSalesOrder = false;


        if (
            step.Business_Process__r != null &&
            step.Business_Process__r.Sales_Order__c != null
        ) {

            hasSalesOrder = true;


            if (
                step.Business_Process__r.Sales_Order__r != null &&
                !String.isBlank(
                    step.Business_Process__r
                        .Sales_Order__r
                        .Name
                )
            ) {

                bookingName =
                    step.Business_Process__r
                        .Sales_Order__r
                        .Name;
            }
        }


        /*
         * Unit
         */
        String unitName = '';

        Boolean hasUnit = false;


        if (
            step.Business_Process__r != null &&
            step.Business_Process__r.Unit__c != null
        ) {

            hasUnit = true;


            if (
                step.Business_Process__r.Unit__r != null &&
                !String.isBlank(
                    step.Business_Process__r
                        .Unit__r
                        .Name
                )
            ) {

                unitName =
                    step.Business_Process__r
                        .Unit__r
                        .Name;
            }
        }


        /*
         * Milestone
         */
        String milestoneName = '';


        if (
            step.Business_Process__r != null &&
            step.Business_Process__r.Milestone__r != null &&
            !String.isBlank(
                step.Business_Process__r
                    .Milestone__r
                    .Name
            )
        ) {

            milestoneName =
                step.Business_Process__r
                    .Milestone__r
                    .Name;
        }


        /*
         * IMPORTANT:
         *
         * Booking and Unit are displayed ONLY when
         * BOTH Sales Order and Unit are present.
         *
         * If either is missing, Booking and Unit
         * rows are removed and Milestone is displayed.
         */
        Boolean showBookingAndUnit =
            hasSalesOrder && hasUnit;


        String bookingRow = '';
        String unitRow = '';
        String milestoneRow = '';


        /*
         * SHOW BOOKING + UNIT
         */
        if (showBookingAndUnit) {

            bookingRow =
                '<tr>' +
                    '<td width="180" ' +
                        'style="padding:8px 10px;' +
                        'border-bottom:1px solid #dddddd;' +
                        'font-weight:bold;">' +
                        'Booking' +
                    '</td>' +

                    '<td style="padding:8px 10px;' +
                        'border-bottom:1px solid #dddddd;">' +
                        escapeHtml(
                            bookingName
                        ) +
                    '</td>' +
                '</tr>';


            unitRow =
                '<tr>' +
                    '<td width="180" ' +
                        'style="padding:8px 10px;' +
                        'border-bottom:1px solid #dddddd;' +
                        'font-weight:bold;">' +
                        'Unit' +
                    '</td>' +

                    '<td style="padding:8px 10px;' +
                        'border-bottom:1px solid #dddddd;">' +
                        escapeHtml(
                            unitName
                        ) +
                    '</td>' +
                '</tr>';

        }


        /*
         * SHOW MILESTONE
         *
         * Booking and Unit remain blank because their
         * complete row placeholders will be replaced
         * with empty strings.
         */
        else {

            milestoneRow =
                '<tr>' +
                    '<td width="180" ' +
                        'style="padding:8px 10px;' +
                        'border-bottom:1px solid #dddddd;' +
                        'font-weight:bold;">' +
                        'Milestone' +
                    '</td>' +

                    '<td style="padding:8px 10px;' +
                        'border-bottom:1px solid #dddddd;">' +
                        escapeHtml(
                            milestoneName
                        ) +
                    '</td>' +
                '</tr>';
        }


        /*
         * Process Type
         */
        String processType = '';


        if (
            step.Business_Process__r != null &&
            step.Business_Process__r.Type__c != null
        ) {

            processType =
                String.valueOf(
                    step.Business_Process__r.Type__c
                );
        }


        /*
         * Step Name
         */
        String stepName =
            step.Name != null
                ? step.Name
                : '';


        /*
         * Assigned To
         *
         * First priority:
         * Assigned_To__c
         *
         * If empty:
         * Owner.Name
         */
        String assignedToName = '';


        if (
            step.Assigned_To__c != null &&
            step.Assigned_To__r != null &&
            !String.isBlank(
                step.Assigned_To__r.Name
            )
        ) {

            assignedToName =
                step.Assigned_To__r.Name;

        } else if (
            step.OwnerId != null &&
            step.Owner != null &&
            !String.isBlank(
                step.Owner.Name
            )
        ) {

            assignedToName =
                step.Owner.Name;
        }


        /*
         * Status
         */
        String status =
            step.Status__c != null
                ? String.valueOf(
                    step.Status__c
                )
                : '';


        /*
         * Record URL
         */
        String instanceUrl =step.Process_Flow_Step__r?.Is_Management_Step__c ?
         'http://modonproperties--bpdev.sandbox.lightning.force.com/lightning/n/Corporate_Approvals?c__bpId='+step.Business_Process__c+'&c__stepId='+step.Id :
            URL.getOrgDomainUrl()
                .toExternalForm() +
            '/lightning/r/Business_Process__c/' +
            step.Business_Process__c +
            '/view';


        /*
         * Replace Email Template placeholders
         */

        emailBody =
            emailBody.replace(
                '%%BUSINESS_PROCESS%%',
                escapeHtml(
                    businessProcessName
                )
            );


        /*
         * IMPORTANT:
         * These are ROW placeholders.
         *
         * Booking/Unit row becomes ''
         * when Sales Order or Unit is missing.
         */
        emailBody =
            emailBody.replace(
                '%%BOOKING_ROW%%',
                bookingRow
            );


        emailBody =
            emailBody.replace(
                '%%UNIT_ROW%%',
                unitRow
            );


        emailBody =
            emailBody.replace(
                '%%MILESTONE_ROW%%',
                milestoneRow
            );


        emailBody =
            emailBody.replace(
                '%%TYPE%%',
                escapeHtml(
                    processType
                )
            );


        emailBody =
            emailBody.replace(
                '%%STEP_NAME%%',
                escapeHtml(
                    stepName
                )
            );


        emailBody =
            emailBody.replace(
                '%%ASSIGNED_TO%%',
                escapeHtml(
                    assignedToName
                )
            );


        emailBody =
            emailBody.replace(
                '%%STATUS%%',
                escapeHtml(
                    status
                )
            );


        emailBody =
            emailBody.replace(
                '%%INSTANCE_URL%%',
                instanceUrl
            );


        /*
         * Create Email
         */
        Messaging.SingleEmailMessage email =
            new Messaging.SingleEmailMessage();


        email.setToAddresses(
            splitEmails(
                finEmails
            )
        );


        if (
            !String.isBlank(
                finCCEmails
            )
        ) {

            email.setCcAddresses(
                splitEmails(
                    finCCEmails
                )
            );
        }


        if (
            !String.isBlank(
                finBCCEmails
            )
        ) {

            email.setBccAddresses(
                splitEmails(
                    finBCCEmails
                )
            );
        }


        email.setSubject(
            template.Subject
        );


        email.setHtmlBody(
            emailBody
        );


        /*
         * Send Email
         */
        Messaging.SendEmailResult[] results =
            Messaging.sendEmail(
                new Messaging.SingleEmailMessage[] {
                    email
                }
            );


        /*
         * Log result
         */
        if (
            results != null &&
            !results.isEmpty()
        ) {

            if (
                results[0].isSuccess()
            ) {

                System.debug(
                    'Escalation email sent successfully.'
                );

            } else {

                for (
                    Messaging.SendEmailError err :
                    results[0].getErrors()
                ) {

                    System.debug(
                        'Escalation email error: ' +
                        err.getMessage()
                    );
                }
            }
        }


        System.debug(
            'Escalation email TO: ' +
            finEmails
        );

        System.debug(
            'Escalation email CC: ' +
            finCCEmails
        );

        System.debug(
            'Escalation email BCC: ' +
            finBCCEmails
        );
    }


    /*
     * Split comma-separated email addresses
     */
    private static List<String> splitEmails(
        String emails
    ) {

        List<String> result =
            new List<String>();


        if (String.isBlank(emails)) {
            return result;
        }


        for (
            String email :
            emails.split(',')
        ) {

            email =
                email.trim();


            if (
                !String.isBlank(email)
            ) {

                result.add(email);
            }
        }


        return result;
    }


    /*
     * Escape HTML special characters
     */
    private static String escapeHtml(
        String value
    ) {

        if (value == null) {
            return '';
        }


        return value
            .replace(
                '&',
                '&amp;'
            )
            .replace(
                '<',
                '&lt;'
            )
            .replace(
                '>',
                '&gt;'
            )
            .replace(
                '"',
                '&quot;'
            )
            .replace(
                '\'',
                '&#39;'
            );
    }
}