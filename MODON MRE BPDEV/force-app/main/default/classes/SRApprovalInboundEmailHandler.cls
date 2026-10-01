/** Name              : ServiceRequestApprovalEmailHandler
 * description        :               
 *Created By          : Active Minds
 *********************************************************************************
*  Version  Author          Date        Notes
** 1.0      Manoj           15 Mar 2026    Initial
**********************************************************************************/
global class SRApprovalInboundEmailHandler implements Messaging.InboundEmailHandler {

    global Messaging.InboundEmailResult handleInboundEmail(
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope envelope
    ) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        result.success = true;

        try {
            // ── 1. Extract SR Id from subject ────────────────────────────────
            Id srId = extractSRId(email.subject);
            if (srId == null) return result;

            // ── 2. Parse APPROVED / REJECTED ────────────────────────────────
            String action = parseAction(email.plainTextBody);
            if (action == null) return result;

            // ── 3. Extract comments below the keyword ────────────────────────
            String comments = extractComments(email.plainTextBody, action);

            // ── 4. Find SR — one-time gate via Email_Approval_Status__c ──────
            List<ServiceRequest__c> srList = [
                SELECT Id, Name, Email_Approval_Status__c, Approval_Comments__c
                FROM ServiceRequest__c
                WHERE Id = :srId
                AND Email_Approval_Status__c = 'Pending'
                LIMIT 1
            ];
            if (srList.isEmpty()) return result;

            ServiceRequest__c sr = srList[0];

            // ── 5. Find open ProcessInstanceWorkitem ─────────────────────────
            List<ProcessInstanceWorkitem> workItems = [
                SELECT Id
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstance.TargetObjectId = :srId
                AND ProcessInstance.Status = 'Pending'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (workItems.isEmpty()) return result;

            // ── 6. Process Approve / Reject on the Approval Record ───────────
            Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
            req.setWorkitemId(workItems[0].Id);
            req.setAction(action);   // 'Approve' or 'Reject'
            req.setComments(
                action.toUpperCase() + ' by: ' + envelope.fromAddress +
                '\nDate: ' + System.now().format('dd-MMM-yyyy HH:mm z') +
                (String.isNotBlank(comments) ? '\nComments: ' + comments : '')
            );

            Approval.ProcessResult approvalResult ;
			user adminUserId  = [select id,Profile.name from user where IsActive =true and Profile.name = 'System Administrator' limit 1];
                if (adminUserId.id != null) {
                    req.setNextApproverIds(new List<Id>{ adminUserId.id });
                }
        
                approvalResult = Approval.process(req, true); // true = skipEntryCriteria

        
            // Only update SR if approval API succeeded
            if (!approvalResult.isSuccess()) {
                System.debug('Approval API Error: ' +
                    JSON.serialize(approvalResult.getErrors()));
                return result;
            }

            // ── 7. Update SR — one-time gate + save comments ─────────────────
            sr.Email_Approval_Status__c  = (action == 'Approve') ? 'Approved' : 'Rejected';
            sr.Approval_Comments__c      =
                'Response : ' + action.toUpperCase() + '\n' +
                'From     : ' + envelope.fromAddress + '\n' +
                'On       : ' + System.now().format('dd-MMM-yyyy HH:mm z') + '\n' +
                'Comments : ' + (String.isNotBlank(comments) ? comments : 'None provided');
            update sr;

        } catch (Exception e) {
            System.debug('SRApprovalInboundEmailHandler Error: '
                + e.getMessage() + '\n' + e.getStackTraceString());
        }

        return result;
    }

    // ── Extract Salesforce Id from [SRID:xxxxx] in subject ───────────────────
    private Id extractSRId(String subject) {
        if (String.isBlank(subject)) return null;
        Pattern p = Pattern.compile('\\[SRID:([a-zA-Z0-9]{15,18})\\]');
        Matcher m = p.matcher(subject);
        if (m.find()) {
            try { return (Id) m.group(1); }
            catch (Exception e) { return null; }
        }
        return null;
    }

    // ── First non-blank line must be APPROVED or REJECTED ────────────────────
    private String parseAction(String body) {
        if (String.isBlank(body)) return null;
        for (String line : body.split('\n')) {
            String t = line.trim().toUpperCase();
            if (String.isBlank(t)) continue;
            if (t.startsWith('APPROVED')) return 'Approve';
            if (t.startsWith('REJECTED')) return 'Reject';
            break; // First non-blank line is not a keyword — stop
        }
        return null;
    }

    // ── Capture all lines after keyword, before quoted reply marker ──────────
    private String extractComments(String body, String action) {
        if (String.isBlank(body)) return '';
        List<String> lines        = body.split('\n');
        Boolean      actionFound  = false;
        List<String> commentLines = new List<String>();
        String       keyword      = (action == 'Approve') ? 'APPROVED' : 'REJECTED';

        for (String line : lines) {
            String trimmed = line.trim();
            if (trimmed.startsWith('>') ||
                trimmed.startsWith('--') ||
                (trimmed.startsWith('On ') && trimmed.contains('wrote:'))) break;

            if (!actionFound) {
                if (trimmed.toUpperCase().startsWith(keyword)) actionFound = true;
                continue;
            }
            if (String.isNotBlank(trimmed)) commentLines.add(trimmed);
        }
        return String.join(commentLines, '\n').trim();
    }
}