/* Version       Author                          Date            Comment                                                                      
* 1.0           raghu.chilukuri@activemindsit.com    19 Dec 2023      Initial Draft(Communication Record Creation,Approvalprocess,emailsending)      
* 1.1           raghu.chilukuri@activemindsit.com    08/03/26         code Refinement
* 1.2           raghu.chilukuri@activemindsit.com    12/03/26         Added Event context handling and validation for Event/Activity before sending communication,Removed a Script exception code and also the Internal Communication type
* 1.2           raghu.chilukuri@activemindsit.com    06/04/26         Added an Extra recordtype for Contact Query as they are Some Old contacts with Record Type Broker Agency
* 1.3           raghu.chilukuri@activemindsit.com    20/04/26         Added Whatsapp logic
**********************************************************************************************
*/
 
public with sharing class CommunicationController {

    /**
     * @description Fetches communication related data based on action.
     * @param action Requested fetch action.
     * @param params Additional input values from UI.
     * @return Response object for the requested action.
     */
    @AuraEnabled(cacheable=true)
    public static Object fetchData(String action, Map<String, Object> params) {
        if (params == null) {
            params = new Map<String, Object>();
        }

        if (action == BRConstants.COMM_ACTION_TYPES) {
            return new List<String>{
                   // BRConstants.COMMUNICATION_TYPE_INTERNAL,
                BRConstants.COMMUNICATION_TYPE_EXTERNAL
            };
        }

        if (action == BRConstants.COMM_ACTION_REGIONS) {
            return new List<String>{
                BRConstants.REGION_ALL,
                BRConstants.REGION_DOMESTIC,
                BRConstants.REGION_INTERNATIONAL
            };
        }

        if (action == BRConstants.COMM_ACTION_COUNTRIES) {
            String selectedRegion = (String) params.get('region');
            List<String> countryValues = new List<String>();

            Schema.DescribeFieldResult countryDescribeResult = Communication__c.Country__c.getDescribe();
            for (Schema.PicklistEntry picklistEntry : countryDescribeResult.getPicklistValues()) {
                if (picklistEntry.isActive()) {
                    countryValues.add(picklistEntry.getLabel());
                }
            }

            if (selectedRegion == BRConstants.REGION_DOMESTIC) {
                return new List<String>{ BRConstants.COUNTRY_UAE };
            }

            if (selectedRegion == BRConstants.REGION_INTERNATIONAL) {
                List<String> internationalCountries = new List<String>();
                for (String countryName : countryValues) {
                    if (countryName != BRConstants.COUNTRY_UAE) {
                        internationalCountries.add(countryName);
                    }
                }
                return internationalCountries;
            }

            return countryValues;
        }

        if (action == BRConstants.COMM_ACTION_STATES) {
            String selectedCountry = (String) params.get('country');
            String selectedRegion = (String) params.get('region');

            if (String.isBlank(selectedCountry) || selectedCountry != BRConstants.COUNTRY_UAE) {
                return new List<Map<String, String>>();
            }

            List<Map<String, String>> stateOptions = new List<Map<String, String>>();
            for (String emirateName : BRConstants.UAE_EMIRATES) {
                stateOptions.add(new Map<String, String>{
                    'label' => emirateName,
                    'value' => emirateName
                });
            }
            return stateOptions;
        }

        if (action == BRConstants.COMM_ACTION_INTERNAL_ROLES) {
            List<UserRole> userRoles = [
                SELECT Id, Name
                FROM UserRole
                WHERE PortalType != :BRConstants.PORTAL_TYPE_CUSTOMER
                ORDER BY Name
            ];

            List<Map<String, String>> roleOptions = new List<Map<String, String>>();
            for (UserRole userRole : userRoles) {
                roleOptions.add(new Map<String, String>{
                    'label' => userRole.Name,
                    'value' => userRole.Id
                });
            }
            return roleOptions;
        }

        if (action == BRConstants.COMM_ACTION_AGENCIES) {
            String selectedRegion = (String) params.get('region');
            List<String> selectedCountries = parseStringList(params.get('selectedCountries'));
            List<String> selectedStates = parseStringList(params.get('selectedStates'));

            // SOQL injection fix: bind constants and user-selected country/state values (no string concat into literals).
            Id brokerAgencyRt = BRConstants.BROKER_AGENCY_RT;
            String uaeCountry = BRConstants.COUNTRY_UAE;
            Map<String, Object> accountBinds = new Map<String, Object>{
                'brokerAgencyRt' => brokerAgencyRt,
                'uaeCountry' => uaeCountry
            };

            String accountQuery =
                'SELECT Id, Name, BillingCountry, BillingState ' +
                'FROM Account ' +
                'WHERE RecordTypeId = :brokerAgencyRt';

            if (selectedRegion == BRConstants.REGION_DOMESTIC) {
                accountQuery += ' AND BillingCountry = :uaeCountry';

                if (!selectedStates.isEmpty()) {
                    accountBinds.put('selectedStates', selectedStates);
                    accountQuery += ' AND BillingState IN :selectedStates';
                }
            } else if (selectedRegion == BRConstants.REGION_INTERNATIONAL) {
                List<String> internationalCountries = new List<String>();
                for (String countryName : selectedCountries) {
                    if (String.isBlank(countryName)) {
                        continue;
                    }
                    if (countryName == BRConstants.COUNTRY_UAE) {
                        continue;
                    }
                    internationalCountries.add(countryName);
                }
                if (!internationalCountries.isEmpty()) {
                    accountBinds.put('selectedCountries', internationalCountries);
                    accountQuery += ' AND BillingCountry IN :selectedCountries';
                }
            } else if (selectedRegion == BRConstants.REGION_ALL) {
                List<String> allCountries = new List<String>();
                for (String countryName : selectedCountries) {
                    if (String.isBlank(countryName)) {
                        continue;
                    }
                    allCountries.add(countryName);
                }
                if (!allCountries.isEmpty()) {
                    accountBinds.put('selectedCountries', allCountries);
                    accountQuery += ' AND BillingCountry IN :selectedCountries';
                }

                if (selectedCountries.contains(BRConstants.COUNTRY_UAE) && !selectedStates.isEmpty()) {
                    accountBinds.put('selectedStates', selectedStates);
                    accountQuery += ' AND BillingState IN :selectedStates';
                }
            }

            accountQuery += ' ORDER BY Name';

            List<Account> agencyAccounts = Database.queryWithBinds(
                accountQuery,
                accountBinds,
                AccessLevel.SYSTEM_MODE
            );
            List<Map<String, String>> agencyOptions = new List<Map<String, String>>();

            for (Account agencyAccount : agencyAccounts) {
                agencyOptions.add(new Map<String, String>{
                    'label' => agencyAccount.Name + ' (' +
                        (agencyAccount.BillingCountry != null ? agencyAccount.BillingCountry : BRConstants.DEFAULT_NO_COUNTRY) +
                        (agencyAccount.BillingState != null ? ' - ' + agencyAccount.BillingState : '') + ')',
                    'value' => agencyAccount.Id
                });
            }
            return agencyOptions;
        }

        if (action == BRConstants.COMM_ACTION_ORG_WIDE_EMAILS) {
            List<OrgWideEmailAddress> orgWideEmailAddresses = [
                SELECT Id, Address, DisplayName
                FROM OrgWideEmailAddress
                ORDER BY DisplayName
            ];

            List<Map<String, String>> emailOptions = new List<Map<String, String>>();
            for (OrgWideEmailAddress orgWideEmailAddress : orgWideEmailAddresses) {
                emailOptions.add(new Map<String, String>{
                    'label' => orgWideEmailAddress.DisplayName + ' (' + orgWideEmailAddress.Address + ')',
                    'value' => orgWideEmailAddress.Address
                });
            }
            return emailOptions;
        }

        if (action == BRConstants.COMM_ACTION_AGENCY_CONTACTS) {
            List<String> selectedAgencyIds = parseStringList(params.get('agencyIds'));
            List<String> selectedBrokerTypes = parseStringList(params.get('brokerTypes'));
            List<Map<String, String>> contactOptions = new List<Map<String, String>>();
                        /*Update Version 1.2
            @description : added recordtypes as a Set
            */
            set<id> contactrecordTypeIds = new set<id>{BRConstants.BROKER_AGENT_RT,BRConstants.BROKER_CONTACT_AGENCY_RT};

            if (selectedAgencyIds.isEmpty()) {
                return contactOptions;
            }
            
            /*Update version 1.2
            Description : updated the Query as per the contact set
            */

            List<Contact> contactRecords;
            if (selectedBrokerTypes.isEmpty() || selectedBrokerTypes.contains(BRConstants.AGENT_TYPE_ALL)) {
                contactRecords = [
                    SELECT Id, Name, Email, AccountId, Agent_Status__c, Account.Name, Broker_Type__c
                    FROM Contact
                    WHERE AccountId IN :selectedAgencyIds
                    AND RecordTypeId in:contactrecordTypeIds
                    AND Email != null
                    AND Agent_Status__c = :BRConstants.ACCOUNT_STATUS_ACTIVE
                    ORDER BY Name
                ];
            } else {
                           /*Update version 1.2
            Description : updated the Query as per the contact set
            */
                contactRecords = [
                    SELECT Id, Name, Email, AccountId, Agent_Status__c, Account.Name, Broker_Type__c
                    FROM Contact
                    WHERE AccountId IN :selectedAgencyIds
                    AND RecordTypeId in:contactrecordTypeIds
                    AND Email != null
                    AND Agent_Status__c = :BRConstants.ACCOUNT_STATUS_ACTIVE
                    AND Broker_Type__c IN :selectedBrokerTypes
                    ORDER BY Name
                ];
            }

            for (Contact contactRecord : contactRecords) {
                contactOptions.add(new Map<String, String>{
                    'id' => contactRecord.Id,
                    'name' => contactRecord.Name,
                    'email' => contactRecord.Email,
                    'accountName' => contactRecord.Account != null ? contactRecord.Account.Name : null,
                    'brokerType' => contactRecord.Broker_Type__c
                });
            }
            return contactOptions;
        }

        if (action == BRConstants.COMM_ACTION_USERS_BY_ROLES) {
            List<String> roleIds = parseStringList(params.get('roleIds'));
            List<Map<String, String>> userOptions = new List<Map<String, String>>();

            if (roleIds.isEmpty()) {
                return userOptions;
            }

            List<User> activeUsers = [
                SELECT Id, Name, Email, UserRoleId, UserRole.Name
                FROM User
                WHERE UserRoleId IN :roleIds
                AND IsActive = true
                AND Email != null
                ORDER BY UserRole.Name, Name
            ];

            for (User userRecord : activeUsers) {
                userOptions.add(new Map<String, String>{
                    'id' => userRecord.Id,
                    'name' => userRecord.Name,
                    'email' => userRecord.Email,
                    'roleName' => userRecord.UserRole != null ? userRecord.UserRole.Name : null,
                    'roleId' => userRecord.UserRoleId
                });
            }
            return userOptions;
        }

        if (action == BRConstants.COMM_ACTION_DRAFTS) {
            List<Communication__c> draftCommunications = [
                SELECT Id, Name, Subject__c, Communication_Type__c, Region__c, Country__c, states__c, CreatedDate, CreatedBy.Name,
                       Scheduled_Date_and_Time__c, Email_Sent__c
                FROM Communication__c
                WHERE Sent_Options__c = :BRConstants.SENT_OPTION_SAVE_AS_DRAFT
                AND Email_Sent__c = false
                ORDER BY CreatedDate DESC
            ];

            List<Map<String, Object>> draftOptions = new List<Map<String, Object>>();
            for (Communication__c draftRecord : draftCommunications) {
                draftOptions.add(new Map<String, Object>{
                    'id' => draftRecord.Id,
                    'name' => draftRecord.Name,
                    'subject' => draftRecord.Subject__c,
                    'communicationType' => draftRecord.Communication_Type__c,
                    'region' => draftRecord.Region__c,
                    'country' => draftRecord.Country__c,
                    'state' => draftRecord.states__c,
                    'createdDate' => draftRecord.CreatedDate,
                    'createdBy' => draftRecord.CreatedBy != null ? draftRecord.CreatedBy.Name : null,
                    'scheduledDateTime' => draftRecord.Scheduled_Date_and_Time__c,
                    'emailSent' => draftRecord.Email_Sent__c
                });
            }
            return draftOptions;
        }

        return null;
    }

    /**
     * @description Handles create/update/process operations for communications.
     * @param action Requested mutation action.
     * @param params Additional input values from UI.
     * @return Response object for the requested action.
     */
    @AuraEnabled
    public static Object mutate(String action, Map<String, Object> params) {
        if (params == null) {
            params = new Map<String, Object>();
        }

        if (action == BRConstants.COMM_ACTION_UPLOAD_FILES) {
            List<Object> rawFiles = (List<Object>) params.get('files');
            if (rawFiles == null) {
                rawFiles = new List<Object>();
            }

            List<ContentVersion> contentVersionsToInsert = new List<ContentVersion>();
            List<String> originalFileNames = new List<String>();

            for (Object rawFile : rawFiles) {
                Map<String, Object> fileData = toStringKeyMap(rawFile);
                String fileName = (String) fileData.get('fileName');
                String base64Data = (String) fileData.get('base64Data');

                if (String.isBlank(fileName) || String.isBlank(base64Data)) {
                    continue;
                }

                Blob fileBlob = EncodingUtil.base64Decode(base64Data);

                ContentVersion contentVersion = new ContentVersion();
                contentVersion.Title = fileName.contains('.') ? fileName.substringBeforeLast('.') : fileName;
                contentVersion.PathOnClient = fileName;
                contentVersion.VersionData = fileBlob;

                contentVersionsToInsert.add(contentVersion);
                originalFileNames.add(fileName);
            }

            if (contentVersionsToInsert.isEmpty()) {
                return new List<Map<String, Object>>();
            }

            insert contentVersionsToInsert;

            List<Id> contentVersionIds = new List<Id>();
            for (ContentVersion contentVersionRecord : contentVersionsToInsert) {
                contentVersionIds.add(contentVersionRecord.Id);
            }

            List<ContentVersion> insertedContentVersions = [
                SELECT Id, ContentDocumentId, Title
                FROM ContentVersion
                WHERE Id IN :contentVersionIds
            ];

            List<Map<String, Object>> uploadResponse = new List<Map<String, Object>>();
            for (Integer indexValue = 0; indexValue < insertedContentVersions.size(); indexValue++) {
                uploadResponse.add(new Map<String, Object>{
                    'contentDocumentId' => (String) insertedContentVersions[indexValue].ContentDocumentId,
                    'title' => insertedContentVersions[indexValue].Title,
                    'fileName' => (indexValue < originalFileNames.size() ? originalFileNames[indexValue] : null)
                });
            }
            return uploadResponse;
        }

        if (action == BRConstants.COMM_ACTION_LINK_FILES) {
            Id communicationId = (Id) params.get('communicationId');
            List<String> contentDocumentIds = parseStringList(params.get('contentDocumentIds'));

            if (communicationId == null || contentDocumentIds.isEmpty()) {
                return true;
            }

            List<ContentDocumentLink> contentDocumentLinks = new List<ContentDocumentLink>();
            for (String contentDocumentIdValue : contentDocumentIds) {
                if (String.isBlank(contentDocumentIdValue)) {
                    continue;
                }

                contentDocumentLinks.add(new ContentDocumentLink(
                    ContentDocumentId = (Id) contentDocumentIdValue,
                    LinkedEntityId = communicationId,
                    ShareType = BRConstants.FILE_SHARETYPE_VIEW,
                    Visibility = BRConstants.FILE_VISIBILITY_ALL_USERS
                ));
            }

            if (!contentDocumentLinks.isEmpty()) {
                insert contentDocumentLinks;
            }
            return true;
        }

        if (action == BRConstants.COMM_ACTION_BANNER_URL) {
            String contentDocumentId = (String) params.get('contentDocumentId');
            return getPublicUrlForContentDocument((Id) contentDocumentId);
        }

        if (action == BRConstants.COMM_ACTION_PREVIEW_HTML) {
            String subject = (String) params.get('subject');
            String htmlBody = (String) params.get('htmlBody');
            Boolean hasBanner = (Boolean) params.get('hasBanner');
            String bannerUrl = (String) params.get('bannerUrl');

            Communication__c mockCommunication = new Communication__c(
                Subject__c = subject,
                HTML_Body__c = htmlBody
            );
            return buildEmailHtml(mockCommunication, hasBanner == true ? bannerUrl : null);
        }

        if (action == BRConstants.COMM_ACTION_SEND_TEST_EMAIL) {
            String subject = (String) params.get('subject');
            String htmlBody = (String) params.get('htmlBody');
            String ccAddresses = (String) params.get('ccAddresses');
            String bccAddresses = (String) params.get('bccAddresses');
            String fromEmailAddress = (String) params.get('fromAddress');

            List<String> testRecipients = parseStringList(params.get('recipientEmails'));
            List<String> attachmentIds = parseStringList(params.get('attachmentIds'));

            List<String> validRecipients = new List<String>();
            for (String recipientEmail : testRecipients) {
                if (isValidEmail(recipientEmail)) {
                    validRecipients.add(recipientEmail);
                }
            }

            if (validRecipients.isEmpty()) {
                throw new AuraHandledException('Please enter at least one valid email address');
            }

            String bannerUrl = null;
            Set<Id> allDocumentIds = new Set<Id>();
            for (String attachmentId : attachmentIds) {
                if (String.isNotBlank(attachmentId)) {
                    allDocumentIds.add((Id) attachmentId);
                }
            }

            Map<Id, String> titleByDocumentId = new Map<Id, String>();
            if (!allDocumentIds.isEmpty()) {
                for (ContentDocument contentDocument : [
                    SELECT Id, Title
                    FROM ContentDocument
                    WHERE Id IN :allDocumentIds
                ]) {
                    titleByDocumentId.put(contentDocument.Id, contentDocument.Title);
                }
            }

            List<Id> regularDocumentIds = new List<Id>();
            for (Id documentId : titleByDocumentId.keySet()) {
                String documentTitle = titleByDocumentId.get(documentId);
                if (documentTitle != null && documentTitle.startsWith(BRConstants.FILE_PREFIX_BANNER)) {
                    if (bannerUrl == null) {
                        bannerUrl = getPublicUrlForContentDocument(documentId);
                    }
                } else {
                    regularDocumentIds.add(documentId);
                }
            }

            Communication__c mockCommunication = new Communication__c(
                Subject__c = subject,
                HTML_Body__c = htmlBody,
                CC__c = ccAddresses,
                BCC__c = bccAddresses
            );
            String emailBody = buildEmailHtml(mockCommunication, bannerUrl);

            List<Map<String, Object>> personalizations = new List<Map<String, Object>>();

            for (String recipientEmail : validRecipients) {
                personalizations.add(new Map<String, Object>{
                    'to' => new List<Map<String, Object>>{
                        new Map<String, Object>{ 'email' => recipientEmail }
                    }
                });
            }

            for (String ccEmail : parseEmailTokens(ccAddresses)) {
                personalizations.add(new Map<String, Object>{
                    'to' => new List<Map<String, Object>>{
                        new Map<String, Object>{ 'email' => ccEmail }
                    }
                });
            }

            for (String bccEmail : parseEmailTokens(bccAddresses)) {
                personalizations.add(new Map<String, Object>{
                    'to' => new List<Map<String, Object>>{
                        new Map<String, Object>{ 'email' => bccEmail }
                    }
                });
            }

            String personalizationsJson = JSON.serialize(personalizations);

            List<ContentDocumentLink> attachmentLinks = new List<ContentDocumentLink>();
            if (!regularDocumentIds.isEmpty()) {
                Map<Id, ContentDocument> documentMap = new Map<Id, ContentDocument>([
                    SELECT Id, Title, FileExtension, FileType
                    FROM ContentDocument
                    WHERE Id IN :regularDocumentIds
                ]);

                for (Id documentId : regularDocumentIds) {
                    ContentDocument contentDocument = documentMap.get(documentId);
                    if (contentDocument == null) {
                        continue;
                    }

                    ContentDocumentLink attachmentLink = new ContentDocumentLink();
                    attachmentLink.ContentDocumentId = documentId;
                    attachmentLink.ContentDocument = contentDocument;
                    attachmentLinks.add(attachmentLink);
                }
            }

            BP_SendGridUtilityClass.sendEmailWithAttachments(
                personalizationsJson,
                BRConstants.DEFAULT_FROM_NAME,
                fromEmailAddress,
                subject,
                emailBody,
                true,
                attachmentLinks
            );

            return 'Test email sent successfully to ' + validRecipients.size() + ' recipient(s)';
        }

        if (action == BRConstants.COMM_ACTION_PROCESS_COMMUNICATION) {
            Savepoint savePointReference = Database.setSavepoint();
            try {
                String context = (String) params.get('context');
                if (String.isBlank(context)) {
                    context = BRConstants.CONTEXT_GENERAL;
                }

                String sentOption = (String) params.get('sentOption');
                String communicationType = (String) params.get('communicationType');

                Communication__c communicationRecord = new Communication__c();
                communicationRecord.Subject__c = (String) params.get('subject');
                communicationRecord.HTML_Body__c = (String) params.get('htmlBody');
                communicationRecord.Small_Banner__c = (String) params.get('smallBanner');
                communicationRecord.CC__c = (String) params.get('ccAddresses');
                communicationRecord.BCC__c = (String) params.get('bccAddresses');
                communicationRecord.From_Address__c = (String) params.get('fromAddress');
                communicationRecord.Sent_Options__c = sentOption;
                communicationRecord.Email_Sent__c = false;
                communicationRecord.OwnerId = UserInfo.getUserId();

            if (context == BRConstants.CONTEXT_EVENT) {
            /* Update Version 1.2
            @description :
            * Added logic to check Event context and retrieve Event Id from input parameters.
            */
                     Id eventId = (Id) params.get('eventId');
                    communicationRecord.Communication_Type__c = BRConstants.COMMUNICATION_TYPE_EXTERNAL;
                    communicationRecord.EventorActivity__c = (String) params.get('eventId');

                    List<String> agencyIds = parseStringList(params.get('agencyIds'));
                    communicationRecord.Region__c = BRConstants.REGION_ALL;

                    if (!agencyIds.isEmpty()) {
                        List<Account> agencyAccounts = [
                            SELECT Id, BillingCountry, BillingState
                            FROM Account
                            WHERE Id IN :agencyIds
                            AND RecordTypeId = :BRConstants.BROKER_AGENCY_RT
                        ];

                        Set<String> countrySet = new Set<String>();
                        Set<String> stateSet = new Set<String>();

                        for (Account agencyAccount : agencyAccounts) {
                            if (agencyAccount.BillingCountry != null) {
                                countrySet.add(agencyAccount.BillingCountry);
                            }
                            if (agencyAccount.BillingState != null) {
                                stateSet.add(agencyAccount.BillingState);
                            }
                        }

                        communicationRecord.Country__c = String.join(new List<String>(countrySet), ';');
                        communicationRecord.states__c = String.join(new List<String>(stateSet), ';');
                    }
                } else {
                    communicationRecord.Communication_Type__c = communicationType;
                    communicationRecord.Region__c = (String) params.get('region');
                    communicationRecord.Country__c = String.join(parseStringList(params.get('selectedCountries')), ';');
                    communicationRecord.states__c = String.join(parseStringList(params.get('selectedStates')), ';');
                }

                if (sentOption == BRConstants.SENT_OPTION_SEND_NOW || sentOption == BRConstants.SENT_OPTION_SEND_LATER) {
                    communicationRecord.Communication_Approval__c = BRConstants.COMM_APPROVAL_PENDING;
                }
                if (sentOption == BRConstants.SENT_OPTION_SAVE_AS_DRAFT) {
                    communicationRecord.Communication_Approval__c = BRConstants.COMM_APPROVAL_DRAFT;
                }

                Object scheduledDateTimeValue = params.get('scheduledDateTime');
                if (sentOption == BRConstants.SENT_OPTION_SEND_LATER && scheduledDateTimeValue != null && String.isNotBlank(String.valueOf(scheduledDateTimeValue))) {
                    communicationRecord.Scheduled_Date_and_Time__c = DateTime.valueOf(String.valueOf(scheduledDateTimeValue));
                }

                List<String> selectedRecipients = parseStringList(params.get('selectedRecipients'));
                if (!selectedRecipients.isEmpty()) {
                    communicationRecord.Recipient_Types_Selected__c = String.join(selectedRecipients, ';');
                }

                insert communicationRecord;

                List<String> attachmentIds = parseStringList(params.get('attachmentIds'));
                if (!attachmentIds.isEmpty()) {
                    List<ContentDocumentLink> contentDocumentLinks = new List<ContentDocumentLink>();
                    for (String attachmentId : attachmentIds) {
                        if (String.isBlank(attachmentId)) {
                            continue;
                        }

                        contentDocumentLinks.add(new ContentDocumentLink(
                            ContentDocumentId = (Id) attachmentId,
                            LinkedEntityId = communicationRecord.Id,
                            ShareType = BRConstants.FILE_SHARETYPE_VIEW,
                            Visibility = BRConstants.FILE_VISIBILITY_ALL_USERS
                        ));
                    }
                    if (!contentDocumentLinks.isEmpty()) {
                        insert contentDocumentLinks;
                    }
                }

                if (context == BRConstants.CONTEXT_EVENT) {
                    List<String> agencyIds = parseStringList(params.get('agencyIds'));
                    List<String> contactIds = parseStringList(params.get('contactIds'));
                                        /*Update Version 1.2
                    description : added a recordtype Set for contacts
                    */
                    set<id> EventcontactrecordTypeIds = new set<id>{BRConstants.BROKER_AGENT_RT,BRConstants.BROKER_CONTACT_AGENCY_RT};
                    String eventId = (String) params.get('eventId');

                    List<Agency_Mapping__c> agencyMappingsToInsert = new List<Agency_Mapping__c>();
                    Set<Id> selectedAgencyIdSet = new Set<Id>();
                    for (String agencyIdValue : agencyIds) {
                        if (String.isNotBlank(agencyIdValue)) {
                            selectedAgencyIdSet.add((Id) agencyIdValue);
                        }
                    }

                    List<Agency_Mapping__c> agencyMappingsToUpsert = new List<Agency_Mapping__c>();
                    Map<Id, Agency_Mapping__c> existingAgencyMappings = new Map<Id, Agency_Mapping__c>();

                    if (!selectedAgencyIdSet.isEmpty()) {
                        for (Agency_Mapping__c agencyMappingRecord : [
                            SELECT Id, Agency__c, Communication__c, Event_and_Activity__c, Status__c
                            FROM Agency_Mapping__c
                            WHERE Event_and_Activity__c = :eventId
                            AND Agency__c IN :selectedAgencyIdSet
                        ]) {
                            existingAgencyMappings.put(agencyMappingRecord.Agency__c, agencyMappingRecord);
                        }
                    }

                    for (Id agencyId : selectedAgencyIdSet) {
                        if (existingAgencyMappings.containsKey(agencyId)) {
                            Agency_Mapping__c existingAgencyMapping = existingAgencyMappings.get(agencyId);

                            if (existingAgencyMapping.Communication__c != communicationRecord.Id || existingAgencyMapping.Status__c != BRConstants.MAPPING_STATUS_ASSIGNED) {
                                existingAgencyMapping.Communication__c = communicationRecord.Id;
                                existingAgencyMapping.Status__c = BRConstants.MAPPING_STATUS_ASSIGNED;
                                agencyMappingsToUpsert.add(existingAgencyMapping);
                            }
                        } else {
                            agencyMappingsToUpsert.add(new Agency_Mapping__c(
                                Communication__c = communicationRecord.Id,
                                Agency__c = agencyId,
                                Event_and_Activity__c = eventId,
                                Status__c = BRConstants.MAPPING_STATUS_ASSIGNED
                            ));
                        }
                    }

                    if (!agencyMappingsToUpsert.isEmpty()) {
                        upsert agencyMappingsToUpsert;
                    }

                    if (!agencyMappingsToInsert.isEmpty()) {
                        insert agencyMappingsToInsert;
                    }

                    Map<Id, Id> agencyToMappingIdMap = new Map<Id, Id>();
                    for (Agency_Mapping__c agencyMappingRecord : [
                        SELECT Id, Agency__c
                        FROM Agency_Mapping__c
                        WHERE Communication__c = :communicationRecord.Id
                        AND Agency__c IN :selectedAgencyIdSet
                    ]) {
                        agencyToMappingIdMap.put(agencyMappingRecord.Agency__c, agencyMappingRecord.Id);
                    }

                    Set<Id> selectedContactIdSet = new Set<Id>();
                    for (String contactIdValue : contactIds) {
                        if (String.isNotBlank(contactIdValue)) {
                            selectedContactIdSet.add((Id) contactIdValue);
                        }
                    }
                                   /*Update version 1.2
                    @description : Updated the query according to new Set
                     */


                    if (!selectedContactIdSet.isEmpty() && !agencyToMappingIdMap.isEmpty()) {
                        List<Contact> contactRecords = [
                            SELECT Id, AccountId
                            FROM Contact
                            WHERE Id IN :selectedContactIdSet
                           AND RecordTypeId in:EventcontactrecordTypeIds
                        ];

                        Set<String> existingMappingKeys = new Set<String>();
                        for (AgentMapping__c agentMappingRecord : [
                            SELECT Id, AgencyMapping__c, Agent__c
                            FROM AgentMapping__c
                            WHERE AgencyMapping__c IN :agencyToMappingIdMap.values()
                        ]) {
                            existingMappingKeys.add(agentMappingRecord.AgencyMapping__c + '_' + agentMappingRecord.Agent__c);
                        }

                        List<AgentMapping__c> agentMappingsToInsert = new List<AgentMapping__c>();
                        for (Contact contactRecord : contactRecords) {
                            if (contactRecord.AccountId == null) {
                                continue;
                            }
                            if (!agencyToMappingIdMap.containsKey(contactRecord.AccountId)) {
                                continue;
                            }

                            String mappingKey = agencyToMappingIdMap.get(contactRecord.AccountId) + '_' + contactRecord.Id;
                            if (existingMappingKeys.contains(mappingKey)) {
                                continue;
                            }

                            agentMappingsToInsert.add(new AgentMapping__c(
                                AgencyMapping__c = agencyToMappingIdMap.get(contactRecord.AccountId),
                                Agency__c = contactRecord.AccountId,
                                Agent__c = contactRecord.Id
                            ));
                        }

                        if (!agentMappingsToInsert.isEmpty()) {
                            insert agentMappingsToInsert;
                        }
                    }
                } else {
                    if (communicationType == BRConstants.COMMUNICATION_TYPE_EXTERNAL) {
                        List<String> agencyIds = parseStringList(params.get('selectedAgencies'));
                        Set<Id> selectedAgencyIdSet = new Set<Id>();
                                                /*Update version 1.2
                        @description : added a New set for recordtypes
                         */
                        set<id> ExternalcommcontactrecordTypeIds = new set<id>{BRConstants.BROKER_AGENT_RT,BRConstants.BROKER_CONTACT_AGENCY_RT};
                        for (String agencyIdValue : agencyIds) {
                            if (String.isNotBlank(agencyIdValue)) {
                                selectedAgencyIdSet.add((Id) agencyIdValue);
                            }
                        }

                        List<Agency_Mapping__c> agencyMappingsToInsert = new List<Agency_Mapping__c>();
                        if (!selectedAgencyIdSet.isEmpty()) {
                            Set<Id> existingAgencyIds = new Set<Id>();
                            for (Agency_Mapping__c existingAgencyMapping : [
                                SELECT Id, Agency__c
                                FROM Agency_Mapping__c
                                WHERE Communication__c = :communicationRecord.Id
                                AND Agency__c IN :selectedAgencyIdSet
                            ]) {
                                existingAgencyIds.add(existingAgencyMapping.Agency__c);
                            }

                            for (Id agencyId : selectedAgencyIdSet) {
                                if (!existingAgencyIds.contains(agencyId)) {
                                    agencyMappingsToInsert.add(new Agency_Mapping__c(
                                        Communication__c = communicationRecord.Id,
                                        Agency__c = agencyId,
                                        Status__c = BRConstants.MAPPING_STATUS_ASSIGNED
                                    ));
                                }
                            }

                            if (!agencyMappingsToInsert.isEmpty()) {
                                insert agencyMappingsToInsert;
                            }

                            Map<Id, Id> agencyToMappingIdMap = new Map<Id, Id>();
                            for (Agency_Mapping__c agencyMappingRecord : [
                                SELECT Id, Agency__c
                                FROM Agency_Mapping__c
                                WHERE Communication__c = :communicationRecord.Id
                                AND Agency__c IN :selectedAgencyIdSet
                            ]) {
                                agencyToMappingIdMap.put(agencyMappingRecord.Agency__c, agencyMappingRecord.Id);
                            }

                            List<String> contactIds = parseStringList(params.get('selectedContacts'));
                            Set<Id> selectedContactIdSet = new Set<Id>();
                            for (String contactIdValue : contactIds) {
                                if (String.isNotBlank(contactIdValue)) {
                                    selectedContactIdSet.add((Id) contactIdValue);
                                }
                            }
                            
                            /*Update version 1.2
                            @description : added new Set query
                            */

                            if (!selectedContactIdSet.isEmpty() && !agencyToMappingIdMap.isEmpty()) {
                                List<Contact> contactRecords = [
                                    SELECT Id, AccountId
                                    FROM Contact
                                    WHERE Id IN :selectedContactIdSet
                                  AND RecordTypeId in:ExternalcommcontactrecordTypeIds
                                ];

                                Set<String> existingMappingKeys = new Set<String>();
                                for (AgentMapping__c agentMappingRecord : [
                                    SELECT Id, AgencyMapping__c, Agent__c
                                    FROM AgentMapping__c
                                    WHERE AgencyMapping__c IN :agencyToMappingIdMap.values()
                                ]) {
                                    existingMappingKeys.add(agentMappingRecord.AgencyMapping__c + '_' + agentMappingRecord.Agent__c);
                                }

                                List<AgentMapping__c> agentMappingsToInsert = new List<AgentMapping__c>();
                                for (Contact contactRecord : contactRecords) {
                                    if (contactRecord.AccountId == null) {
                                        continue;
                                    }
                                    if (!agencyToMappingIdMap.containsKey(contactRecord.AccountId)) {
                                        continue;
                                    }

                                    String mappingKey = agencyToMappingIdMap.get(contactRecord.AccountId) + '_' + contactRecord.Id;
                                    if (existingMappingKeys.contains(mappingKey)) {
                                        continue;
                                    }

                                    agentMappingsToInsert.add(new AgentMapping__c(
                                        AgencyMapping__c = agencyToMappingIdMap.get(contactRecord.AccountId),
                                        Agency__c = contactRecord.AccountId,
                                        Agent__c = contactRecord.Id
                                    ));
                                }

                                if (!agentMappingsToInsert.isEmpty()) {
                                    insert agentMappingsToInsert;
                                }
                            }
                        }
                         }
                    /*
                    } else if (communicationType == BRConstants.COMMUNICATION_TYPE_INTERNAL) {
                        List<String> userIds = parseStringList(params.get('selectedUsers'));
                        if (!userIds.isEmpty()) {
                            List<User> activeUsers = [
                                SELECT Id
                                FROM User
                                WHERE Id IN :userIds
                                AND IsActive = true
                            ];

                            List<Internal_Commuincation_Mapping__c> internalMappingsToInsert = new List<Internal_Commuincation_Mapping__c>();
                            for (User userRecord : activeUsers) {
                                internalMappingsToInsert.add(new Internal_Commuincation_Mapping__c(
                                    Internal_communication__c = communicationRecord.Id,
                                    User_mapping__c = userRecord.Id
                                ));
                            }

                            if (!internalMappingsToInsert.isEmpty()) {
                                insert internalMappingsToInsert;
                            }
                        }
                    }
                         */
                }

                Integer agencyCount = [
                    SELECT COUNT()
                    FROM Agency_Mapping__c
                    WHERE Communication__c = :communicationRecord.Id
                ];

                Integer agentCount = [
                    SELECT COUNT()
                    FROM AgentMapping__c
                    WHERE AgencyMapping__c IN (
                        SELECT Id
                        FROM Agency_Mapping__c
                        WHERE Communication__c = :communicationRecord.Id
                    )
                ];

                     /*
                Integer internalCount = [
                    SELECT COUNT()
                    FROM Internal_Commuincation_Mapping__c
                    WHERE Internal_communication__c = :communicationRecord.Id
                ];
                */

                if (sentOption == BRConstants.SENT_OPTION_SEND_NOW || sentOption == BRConstants.SENT_OPTION_SEND_LATER) {
                    try {
                        Approval.ProcessSubmitRequest approvalRequest = new Approval.ProcessSubmitRequest();
                        approvalRequest.setObjectId(communicationRecord.Id);
                        approvalRequest.setComments(BRConstants.APPROVAL_COMMENT_SUBMIT);
                        approvalRequest.setSubmitterId(UserInfo.getUserId());
                        approvalRequest.setProcessDefinitionNameOrId(BRConstants.APPROVAL_PROCESS_COMMUNICATION);
                        approvalRequest.setSkipEntryCriteria(true);
                        Approval.process(approvalRequest);
                    } catch (Exception ignoreException) {
                    }

                    if (context == BRConstants.CONTEXT_EVENT) {
                        return 'Event communication submitted for approval with ' + agencyCount + ' agencies and ' + agentCount + ' contacts.';
                    }
                    if (communicationType == BRConstants.COMMUNICATION_TYPE_EXTERNAL) {
                        return 'Communication submitted for approval with ' + agencyCount + ' agencies and ' + agentCount + ' agents.';
                    }
                    // return 'Communication submitted for approval with ' + internalCount + ' internal users.';
                    return 'Communication submitted for approval successfully.';
                }

                if (sentOption == BRConstants.SENT_OPTION_SAVE_AS_DRAFT) {
                    if (context == BRConstants.CONTEXT_EVENT) {
                        return 'Event draft saved successfully with ' + agencyCount + ' agencies and ' + agentCount + ' contacts.';
                    }
                    if (communicationType == BRConstants.COMMUNICATION_TYPE_EXTERNAL) {
                        return 'Draft saved successfully with ' + agencyCount + ' agencies and ' + agentCount + ' agents.';
                    }
   // return 'Draft saved successfully with ' + internalCount + ' internal users.';
                    return 'Draft saved successfully.';
                }

                return 'Communication processed successfully.';

            } catch (Exception exceptionValue) {
                Database.rollback(savePointReference);
                                throw new AuraHandledException('Error processing communication: ' + exceptionValue.getMessage());
            }
        }

        if (action == BRConstants.COMM_ACTION_PUBLISH_DRAFTS) {
            List<String> draftIds = parseStringList(params.get('draftIds'));
            if (draftIds.isEmpty()) {
                return 'No drafts selected.';
            }

            List<Communication__c> draftCommunications = [
                SELECT Id, OwnerId
                FROM Communication__c
                WHERE Id IN :draftIds
                AND Sent_Options__c = :BRConstants.SENT_OPTION_SAVE_AS_DRAFT
                AND Email_Sent__c = false
            ];

            if (draftCommunications.isEmpty()) {
                return 'No eligible drafts found.';
            }

            List<Communication__c> communicationsToUpdate = new List<Communication__c>();
            for (Communication__c draftRecord : draftCommunications) {
                communicationsToUpdate.add(new Communication__c(
                    Id = draftRecord.Id,
                    Communication_Approval__c = BRConstants.COMM_APPROVAL_PENDING,
                    Sent_Options__c = BRConstants.SENT_OPTION_SEND_NOW
                ));
            }
            update communicationsToUpdate;

            for (Communication__c draftRecord : draftCommunications) {
                try {
                    Approval.ProcessSubmitRequest approvalRequest = new Approval.ProcessSubmitRequest();
                    approvalRequest.setObjectId(draftRecord.Id);
                    approvalRequest.setComments(BRConstants.APPROVAL_COMMENT_SUBMIT_DRAFT);
                    approvalRequest.setSubmitterId(draftRecord.OwnerId);
                    approvalRequest.setProcessDefinitionNameOrId(BRConstants.APPROVAL_PROCESS_COMMUNICATION);
                    approvalRequest.setSkipEntryCriteria(true);
                    Approval.process(approvalRequest);
                } catch (Exception ignoreException) {
                }
            }

            return 'Successfully published ' + draftCommunications.size() + ' draft(s). Communication submitted for approval.';
        }

        if (action == BRConstants.COMM_ACTION_SEND_EMAIL_AFTER_APPROVAL) {
            Id communicationId = (Id) params.get('communicationId');
            if (communicationId == null) {
                return 'ERROR: Missing communicationId';
            }

        /* Update Version 1.2 starts Here 
            @description :
            * Modified query to include EventorActivity__c field from Communication.
            * Added validation to ensure associated Event/Activity is in 'Published' status before sending email.
            * Prevents communication email if Event/Activity is not published.
        */

            Communication__c communicationRecord = [
                SELECT Id, Communication_Approval__c, Email_Sent__c,EventorActivity__c
                FROM Communication__c
                WHERE Id = :communicationId
            ];

            if (communicationRecord.EventorActivity__c != null) {
                Event_and_Activity__c evt = [SELECT Id, Status__c FROM Event_and_Activity__c
                    WHERE Id = :communicationRecord.EventorActivity__c ];

                if (evt.Status__c != BRConstants.EVENT_OR_ACTIVITY_PUBLISHED) {
                    return 'ERROR: Event must be Published before sending communication email.';
                }
            }

            //Update Version 1.2 Ends Here 

            if (communicationRecord.Communication_Approval__c != BRConstants.ACTION_STATUS_APPROVED) {
                return 'ERROR: Communication must be approved before sending.';
            }
            if (communicationRecord.Email_Sent__c == true) {
                return 'ERROR: Email has already been sent.';
            }

            communicationRecord.Email_Sent__c = true;
            update communicationRecord;

            System.enqueueJob(new CommunicationBatchEmailSender(communicationId));
            return 'SUCCESS: Email sending started.';
        }

        /*Update version 1.3
        @description : Added whatsapp logic
        */

        if (action == BRConstants.COMM_ACTION_SEND_WHATSAPP) {

            List<String> contactIds = parseStringList(params.get('contactIds'));
            String message = (String) params.get('message');

            if (contactIds == null || contactIds.isEmpty()) {
                throw new AuraHandledException('No contacts selected for WhatsApp.');
            }

            if (String.isBlank(message)) {
                throw new AuraHandledException('WhatsApp message cannot be empty.');
            }

            mbpCommunicationWhatsAppService.sendWhatsAppMessages(contactIds, message);

            return 'WhatsApp messages triggered successfully for ' + contactIds.size() + ' contact(s).';
        }

        // update version 1.3 Upto here

        if (action == BRConstants.COMM_ACTION_UPDATE_AGENCY_MAPPING_STATUS) {
            String mappingId = (String) params.get('mappingId');
            String newStatus = (String) params.get('newStatus');

            if (String.isBlank(mappingId) || String.isBlank(newStatus)) {
                return true;
            }

            Agency_Mapping__c agencyMappingRecord = [
                SELECT Id, Status__c
                FROM Agency_Mapping__c
                WHERE Id = :mappingId
            ];

            if (agencyMappingRecord.Status__c != newStatus) {
                agencyMappingRecord.Status__c = newStatus;
                update agencyMappingRecord;

                if (newStatus == BRConstants.MAPPING_STATUS_UNASSIGNED) {
                    List<AgentMapping__c> agentMappings = [
                        SELECT Id
                        FROM AgentMapping__c
                        WHERE AgencyMapping__c = :agencyMappingRecord.Id
                    ];

                    if (!agentMappings.isEmpty()) {
                        delete agentMappings;
                    }
                    delete agencyMappingRecord;
                }
            }
            return true;
        }

        return null;
    }

    /**
     * @description Handles portal specific communication actions.
     * @param action Requested portal action.
     * @param params Additional input values from UI.
     * @return Response object for the requested action.
     */
    @AuraEnabled(cacheable=true)
    public static Object portal(String action, Map<String, Object> params) {
        if (params == null) {
            params = new Map<String, Object>();
        }

        if (action == BRConstants.COMM_ACTION_SEND_COMMUNICATION_EMAILS) {
            Id communicationId = (Id) params.get('communicationId');
            if (communicationId == null) {
                return false;
            }

            Communication__c communicationRecord = [
                SELECT Id, Subject__c, HTML_Body__c, CC__c, BCC__c, Communication_Type__c, From_Address__c
                FROM Communication__c
                WHERE Id = :communicationId
            ];

            Id bannerDocumentId = null;
            List<ContentDocumentLink> regularAttachments = new List<ContentDocumentLink>();

            for (ContentDocumentLink contentDocumentLink : [
                SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension, ContentDocument.FileType
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :communicationId
            ]) {
                if (bannerDocumentId == null &&
                    contentDocumentLink.ContentDocument != null &&
                    contentDocumentLink.ContentDocument.Title != null &&
                    contentDocumentLink.ContentDocument.Title.startsWith(BRConstants.FILE_PREFIX_BANNER)) {
                    bannerDocumentId = contentDocumentLink.ContentDocumentId;
                } else {
                    regularAttachments.add(contentDocumentLink);
                }
            }

            String bannerUrl = bannerDocumentId != null ? getPublicUrlForContentDocument(bannerDocumentId) : null;
            String emailBody = buildEmailHtml(communicationRecord, bannerUrl);

            Set<String> recipientEmails = new Set<String>();
            if (communicationRecord.Communication_Type__c == BRConstants.COMMUNICATION_TYPE_EXTERNAL) {
                for (AgentMapping__c agentMappingRecord : [
                    SELECT Agent__r.Email
                    FROM AgentMapping__c
                    WHERE AgencyMapping__c IN (
                        SELECT Id
                        FROM Agency_Mapping__c
                        WHERE Communication__c = :communicationId
                    )
                    AND Agent__r.Email != null
                    AND Agent__r.Agent_Status__c = :BRConstants.ACCOUNT_STATUS_ACTIVE
                ]) {
                    if (isValidEmail(agentMappingRecord.Agent__r.Email)) {
                        recipientEmails.add(agentMappingRecord.Agent__r.Email);
                    }
                }
              } /* else {
                for (Internal_Commuincation_Mapping__c internalMappingRecord : [
                    SELECT User_mapping__r.Email
                    FROM Internal_Commuincation_Mapping__c
                    WHERE Internal_communication__c = :communicationId
                    AND User_mapping__r.IsActive = true
                    AND User_mapping__r.Email != null
                ]) {
                    if (isValidEmail(internalMappingRecord.User_mapping__r.Email)) {
                        recipientEmails.add(internalMappingRecord.User_mapping__r.Email);
                    }
                }
        } */

            List<String> toRecipients = new List<String>(recipientEmails);

            List<Map<String, Object>> ccList = new List<Map<String, Object>>();
            List<Map<String, Object>> bccList = new List<Map<String, Object>>();

            for (String ccEmail : parseEmailTokens(communicationRecord.CC__c)) {
                ccList.add(new Map<String, Object>{ 'email' => ccEmail });
            }
            for (String bccEmail : parseEmailTokens(communicationRecord.BCC__c)) {
                bccList.add(new Map<String, Object>{ 'email' => bccEmail });
            }

            List<Map<String, Object>> personalizations = new List<Map<String, Object>>();
            for (String recipientEmail : toRecipients) {
                personalizations.add(new Map<String, Object>{
                    'to' => new List<Map<String, Object>>{
                        new Map<String, Object>{ 'email' => recipientEmail }
                    }
                });
            }

            for (String ccEmail : parseEmailTokens(communicationRecord.CC__c)) {
                personalizations.add(new Map<String, Object>{
                    'to' => new List<Map<String, Object>>{
                        new Map<String, Object>{ 'email' => ccEmail }
                    }
                });
            }

            for (String bccEmail : parseEmailTokens(communicationRecord.BCC__c)) {
                personalizations.add(new Map<String, Object>{
                    'to' => new List<Map<String, Object>>{
                        new Map<String, Object>{ 'email' => bccEmail }
                    }
                });
            }

            String personalizationsJson = JSON.serialize(personalizations);

            BP_SendGridUtilityClass.sendEmailWithAttachments(
                personalizationsJson,
                BRConstants.DEFAULT_FROM_NAME,
                communicationRecord.From_Address__c,
                communicationRecord.Subject__c,
                emailBody,
                true,
                regularAttachments
            );

            update new Communication__c(
                Id = communicationId,
                Communication_Approval__c = BRConstants.ACTION_STATUS_APPROVED,
                Email_Sent__c = true
            );
            return true;
        }
        if (action == 'getPortalCommunications') {
    String filterType = (String) params.get('filterType');

    User currentUser = [
        SELECT Id, ContactId, Email
        FROM User
        WHERE Id = :UserInfo.getUserId()
        LIMIT 1
    ];

    if (currentUser.ContactId == null) {
        return new List<Map<String, Object>>();
    }

    Set<Id> communicationIds = new Set<Id>();

    for (AgentMapping__c agentMappingRecord : [
        SELECT AgencyMapping__r.Communication__c
        FROM AgentMapping__c
        WHERE Agent__c = :currentUser.ContactId
        AND AgencyMapping__r.Communication__c != null
    ]) {
        communicationIds.add(agentMappingRecord.AgencyMapping__r.Communication__c);
    }

    for (Communication__c ownCommunication : [
        SELECT Id
        FROM Communication__c
        WHERE CreatedById = :UserInfo.getUserId()
    ]) {
        communicationIds.add(ownCommunication.Id);
    }

    if (communicationIds.isEmpty()) {
        return new List<Map<String, Object>>();
    }

    // SOQL injection fix: explicit binds for Id set (Approved status is a constant literal).
    String communicationQuery =
        'SELECT Id, Name, Subject__c, HTML_Body__c, CC__c, BCC__c, From_Address__c, ' +
        'CreatedDate, CreatedBy.Name, CreatedBy.Email, Communication_Type__c, ' +
        'Sent_Options__c, Email_Sent__c, Communication_Approval__c, Broker_View_Status__c ' +
        'FROM Communication__c ' +
        'WHERE Id IN :communicationIds ' +
        'AND Communication_Approval__c = \'Approved\' ' +
        'ORDER BY CreatedDate DESC';

    List<Communication__c> communicationRecords = Database.queryWithBinds(
        communicationQuery,
        new Map<String, Object>{ 'communicationIds' => communicationIds },
        AccessLevel.SYSTEM_MODE
    );

    Map<Id, List<Map<String, Object>>> attachmentsByCommunication = new Map<Id, List<Map<String, Object>>>();
    Map<Id, String> bannerUrlByCommunication = new Map<Id, String>();

    for (ContentDocumentLink contentDocumentLink : [
        SELECT LinkedEntityId,
               ContentDocumentId,
               ContentDocument.Title,
               ContentDocument.FileExtension,
               ContentDocument.FileType,
               ContentDocument.ContentSize
        FROM ContentDocumentLink
        WHERE LinkedEntityId IN :communicationIds
        ORDER BY ContentDocument.CreatedDate DESC
    ]) {
        if (!attachmentsByCommunication.containsKey(contentDocumentLink.LinkedEntityId)) {
            attachmentsByCommunication.put(contentDocumentLink.LinkedEntityId, new List<Map<String, Object>>());
        }

        String documentTitle = contentDocumentLink.ContentDocument != null
            ? contentDocumentLink.ContentDocument.Title
            : null;

        Boolean isBanner = documentTitle != null && documentTitle.startsWith(BRConstants.FILE_PREFIX_BANNER);
        String publicUrl = '/sfc/servlet.shepherd/document/download/' + contentDocumentLink.ContentDocumentId;

        if (isBanner && bannerUrlByCommunication.get(contentDocumentLink.LinkedEntityId) == null) {
            bannerUrlByCommunication.put(contentDocumentLink.LinkedEntityId, publicUrl);
        }

        attachmentsByCommunication.get(contentDocumentLink.LinkedEntityId).add(new Map<String, Object>{
            'id' => (String) contentDocumentLink.ContentDocumentId,
            'name' => documentTitle,
            'fileExtension' => contentDocumentLink.ContentDocument != null ? contentDocumentLink.ContentDocument.FileExtension : null,
            'fileType' => contentDocumentLink.ContentDocument != null ? contentDocumentLink.ContentDocument.FileType : null,
            'size' => contentDocumentLink.ContentDocument != null ? contentDocumentLink.ContentDocument.ContentSize : null,
            'downloadUrl' => publicUrl,
            'isBanner' => isBanner
        });
    }

    List<Map<String, Object>> portalResponse = new List<Map<String, Object>>();

    for (Communication__c communicationRecord : communicationRecords) {
        String bannerUrl = bannerUrlByCommunication.get(communicationRecord.Id);

        String contentHtml = communicationRecord.HTML_Body__c != null
            ? communicationRecord.HTML_Body__c.trim()
            : '';

        contentHtml = contentHtml.replaceAll('(?is)<style[^>]*>.*?</style>', '');
        contentHtml = contentHtml.replaceAll('(?is)<head[^>]*>.*?</head>', '');
        contentHtml = contentHtml.replaceAll('(?is)<!DOCTYPE[^>]*>', '');
        contentHtml = contentHtml.replaceAll('(?is)<html[^>]*>', '');
        contentHtml = contentHtml.replaceAll('(?is)</html>', '');
        contentHtml = contentHtml.replaceAll('(?is)<body[^>]*>', '');
        contentHtml = contentHtml.replaceAll('(?is)</body>', '');

        String bannerSection = '';
        if (String.isNotBlank(bannerUrl)) {
            bannerSection =
                '<div style="text-align:center; margin:0 0 20px 0;">' +
                '<img src="' + bannerUrl + '" alt="Banner" style="max-width:100%; height:auto; display:block; margin:0 auto;" />' +
                '</div>';
        }

        String finalHtmlBody =
            '<div style="background:#f4f4f4; padding:0; margin:0;">' +
            '  <div style="max-width:600px; margin:0 auto; background:#ffffff;">' +
            '    <div style="padding:0; line-height:0; font-size:0; text-align:center;">' +
            '      <img src="__HEADER_IMAGE__" alt="Modon Header" style="width:100%; max-width:600px; height:auto; display:block; margin:0 auto;" />' +
            '    </div>' +
                     bannerSection +
            '    <div style="padding:20px; font-family:Arial,sans-serif; line-height:1.6; color:#333333;">' +
                         contentHtml +
            '    </div>' +
            '    <div style="padding:20px 30px 10px 30px; font-family:Arial,sans-serif; font-size:16px; line-height:20px; color:#000000;">' +
            '      <p style="margin:0;">Best Regards,</p>' +
            '      <p style="margin:4px 0 0 0; font-weight:bold;">Modon</p>' +
            '    </div>' +
            '    <div style="background:#000000; padding:10px 15px;">' +
            '      <table width="100%" cellpadding="0" cellspacing="0" role="presentation" style="border-collapse:collapse;">' +
            '        <tr>' +
            '          <td width="70%" valign="top" style="color:#ffffff; font-family:Arial,sans-serif; font-size:11px; line-height:16px;">' +
            '            FOLLOW US ON SOCIAL MEDIA' +
            '            <table cellpadding="0" cellspacing="0" role="presentation" style="margin-top:8px; border-collapse:collapse;">' +
            '              <tr>' +
            '                <td style="padding-right:8px;"><a href="https://www.linkedin.com/company/modon/" target="_blank"><img src="__LINKEDIN_ICON__" width="20" height="20" style="border:0; display:block;" /></a></td>' +
            '                <td style="padding-right:8px;"><a href="https://www.instagram.com/modonproperties" target="_blank"><img src="__INSTAGRAM_ICON__" width="20" height="20" style="border:0; display:block;" /></a></td>' +
            '                <td style="padding-right:8px;"><a href="https://x.com/ModonProperties" target="_blank"><img src="__TWITTER_ICON__" width="20" height="20" style="border:0; display:block;" /></a></td>' +
            '                <td style="padding-right:8px;"><a href="https://www.facebook.com/modonproperties" target="_blank"><img src="__FACEBOOK_ICON__" width="20" height="20" style="border:0; display:block;" /></a></td>' +
            '                <td style="padding-right:8px;"><a href="https://www.youtube.com/@ModonRealEstate-n9p" target="_blank"><img src="__YOUTUBE_ICON__" width="20" height="20" style="border:0; display:block;" /></a></td>' +
            '              </tr>' +
            '            </table>' +
            '          </td>' +
            '          <td width="30%" align="right" valign="middle">' +
            '            <a href="https://www.modon.com/" target="_blank">' +
            '              <img src="__WHITE_LOGO__" width="100" height="18" style="border:0; display:block; margin-left:auto;" />' +
            '            </a>' +
            '          </td>' +
            '        </tr>' +
            '      </table>' +
            '    </div>' +
            '  </div>' +
            '</div>';

        List<Map<String, Object>> communicationAttachments = attachmentsByCommunication.containsKey(communicationRecord.Id)
            ? attachmentsByCommunication.get(communicationRecord.Id)
            : new List<Map<String, Object>>();

        portalResponse.add(new Map<String, Object>{
            'id' => communicationRecord.Id,
            'name' => communicationRecord.Name,
            'subject' => communicationRecord.Subject__c,
            'htmlBody' => finalHtmlBody,
            'fromAddress' => communicationRecord.From_Address__c,
            'ccAddresses' => communicationRecord.CC__c,
            'bccAddresses' => communicationRecord.BCC__c,
            'createdDate' => communicationRecord.CreatedDate,
            'createdByName' => communicationRecord.CreatedBy != null ? communicationRecord.CreatedBy.Name : null,
            'createdByEmail' => communicationRecord.CreatedBy != null ? communicationRecord.CreatedBy.Email : null,
            'communicationType' => communicationRecord.Communication_Type__c,
            'sentOption' => communicationRecord.Sent_Options__c,
            'emailSent' => communicationRecord.Email_Sent__c,
            'approvalStatus' => communicationRecord.Communication_Approval__c,
            'viewStatus' => communicationRecord.Broker_View_Status__c,
            'attachments' => communicationAttachments,
            'hasBanner' => String.isNotBlank(bannerUrl),
            'bannerUrl' => bannerUrl
        });
    }

    return portalResponse;
}

                if (action == 'markCommunicationViewed') {
            Id communicationId = (Id) params.get('communicationId');

            if (communicationId == null) {
                return true;
            }

            List<Communication__c> communicationRecords = [
                SELECT Id, Broker_View_Status__c
                FROM Communication__c
                WHERE Id = :communicationId
                LIMIT 1
            ];

            if (!communicationRecords.isEmpty() &&
                communicationRecords[0].Broker_View_Status__c != 'Viewed') {
                communicationRecords[0].Broker_View_Status__c = 'Viewed';
                update communicationRecords[0];
            }

            return true;
        }


        return null;
    }

    /**
     * @description Converts any supported object into a String-keyed map.
     * @param inputObject Raw input object.
     * @return String keyed map.
     */
    private static Map<String, Object> toStringKeyMap(Object inputObject) {
        Map<String, Object> outputMap = new Map<String, Object>();
        if (inputObject == null) {
            return outputMap;
        }

        if (inputObject instanceof Map<String, Object>) {
            return (Map<String, Object>) inputObject;
        }

        if (inputObject instanceof Map<Object, Object>) {
            Map<Object, Object> rawMap = (Map<Object, Object>) inputObject;
            for (Object keyValue : rawMap.keySet()) {
                outputMap.put(String.valueOf(keyValue), rawMap.get(keyValue));
            }
            return outputMap;
        }

        if (inputObject instanceof String) {
            Object parsedObject = JSON.deserializeUntyped((String) inputObject);
            return toStringKeyMap(parsedObject);
        }

        Object serializedParsedObject = JSON.deserializeUntyped(JSON.serialize(inputObject));
        return toStringKeyMap(serializedParsedObject);
    }

    /**
     * @description Parses a string/list/object input into a trimmed string list.
     * @param inputValue Input value.
     * @return Parsed string list.
     */
    private static List<String> parseStringList(Object inputValue) {
        List<String> outputList = new List<String>();
        if (inputValue == null) {
            return outputList;
        }

        if (inputValue instanceof List<String>) {
            for (String stringValue : (List<String>) inputValue) {
                if (String.isNotBlank(stringValue)) {
                    outputList.add(stringValue.trim());
                }
            }
            return outputList;
        }

        if (inputValue instanceof List<Object>) {
            for (Object objectValue : (List<Object>) inputValue) {
                if (objectValue != null && String.isNotBlank(String.valueOf(objectValue))) {
                    outputList.add(String.valueOf(objectValue).trim());
                }
            }
            return outputList;
        }

        String stringValue = String.valueOf(inputValue);
        if (String.isBlank(stringValue)) {
            return outputList;
        }

        for (String splitValue : stringValue.split(',|;')) {
            if (String.isNotBlank(splitValue)) {
                outputList.add(splitValue.trim());
            }
        }
        return outputList;
    }

    /**
     * @description Parses comma/semicolon separated emails and returns valid unique emails.
     * @param rawEmails Raw email text.
     * @return List of valid unique emails.
     */
    private static List<String> parseEmailTokens(String rawEmails) {
        List<String> outputEmails = new List<String>();
        if (String.isBlank(rawEmails)) {
            return outputEmails;
        }

        Set<String> uniqueEmails = new Set<String>();
        for (String emailToken : rawEmails.split(',|;')) {
            String emailAddress = emailToken != null ? emailToken.trim() : null;
            if (isValidEmail(emailAddress)) {
                uniqueEmails.add(emailAddress);
            }
        }

        outputEmails.addAll(uniqueEmails);
        return outputEmails;
    }

    /**
     * @description Validates email format.
     * @param emailAddress Email to validate.
     * @return True when email format is valid.
     */
    private static Boolean isValidEmail(String emailAddress) {
        if (String.isBlank(emailAddress)) {
            return false;
        }

        Pattern emailPattern = Pattern.compile('^[a-zA-Z0-9._|\\\\%#~`=?&/$^*!}{+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$');
        return emailPattern.matcher(emailAddress.trim()).matches();
    }

    /**
     * @description Returns public download/view URL for the latest version of a file.
     * @param contentDocumentId ContentDocument Id.
     * @return Public URL.
     */
    private static String getPublicUrlForContentDocument(Id contentDocumentId) {
        try {
            if (contentDocumentId == null) {
                return null;
            }

            List<ContentVersion> contentVersions = [
                SELECT Id, Title
                FROM ContentVersion
                WHERE ContentDocumentId = :contentDocumentId
                AND IsLatest = true
            ];
            if (contentVersions.isEmpty()) {
                return null;
            }

            ContentVersion latestContentVersion = contentVersions[0];

            List<ContentDistribution> existingDistributions = [
                SELECT Id, ContentDownloadUrl, DistributionPublicUrl
                FROM ContentDistribution
                WHERE ContentVersionId = :latestContentVersion.Id
            ];
            if (!existingDistributions.isEmpty()) {
                return existingDistributions[0].ContentDownloadUrl != null
                    ? existingDistributions[0].ContentDownloadUrl
                    : existingDistributions[0].DistributionPublicUrl;
            }

            ContentDistribution contentDistribution = new ContentDistribution(
                Name = latestContentVersion.Title,
                ContentVersionId = latestContentVersion.Id,
                PreferencesAllowViewInBrowser = true,
                PreferencesAllowOriginalDownload = true
            );
            insert contentDistribution;

            List<ContentDistribution> createdDistributions = [
                SELECT ContentDownloadUrl, DistributionPublicUrl
                FROM ContentDistribution
                WHERE Id = :contentDistribution.Id
            ];
            if (createdDistributions.isEmpty()) {
                return null;
            }

            return createdDistributions[0].ContentDownloadUrl != null
                ? createdDistributions[0].ContentDownloadUrl
                : createdDistributions[0].DistributionPublicUrl;
        } catch (Exception exceptionValue) {
            return null;
        }
    }

    /**
     * @description Builds final email HTML including optional banner.
     * @param communicationRecord Communication record.
     * @param bannerUrl Public banner URL.
     * @return Final email HTML.
     */
    private static String buildEmailHtml(Communication__c communicationRecord, String bannerUrl) {
        String bodyHtml = '';

        if (String.isNotBlank(bannerUrl)) {
            bodyHtml += '<div align="center" style="margin:0 auto 20px auto;max-width:600px;display:block;padding:10px;">';
            bodyHtml += '<img src="' + bannerUrl + '" alt="Banner" width="600" style="max-width:100%;height:auto;border:0;display:block;margin:0 auto;" />';
            bodyHtml += '</div>';
        }

        if (String.isNotBlank(communicationRecord.HTML_Body__c)) {
            String contentHtml = communicationRecord.HTML_Body__c.trim();
            contentHtml = contentHtml.replaceAll('<style[^>]*>.*?</style>', '');
            contentHtml = contentHtml.replaceAll('<head>.*?</head>', '');
            contentHtml = contentHtml.replaceAll('<div[^>]*>', '<div>');
            contentHtml = contentHtml.replaceAll('<p[^>]*>', '<p style="margin:0 0 15px 0;">');
            contentHtml = contentHtml.replaceAll('<h1[^>]*>', '<h1 style="font-size:24px;margin:0 0 15px 0;">');
            contentHtml = contentHtml.replaceAll('<h2[^>]*>', '<h2 style="font-size:20px;margin:0 0 15px 0;">');
            contentHtml = contentHtml.replaceAll('<h3[^>]*>', '<h3 style="font-size:18px;margin:0 0 15px 0;">');
            contentHtml = contentHtml.replaceAll('<table[^>]*>', '<table border="0" cellpadding="0" cellspacing="0" width="100%">');

            bodyHtml += '<div style="padding:20px;font-family:Arial,sans-serif;line-height:1.6;color:#333333;max-width:600px;margin:0 auto;">' + contentHtml + '</div>';
        }

        return MBP_ModonEmailUtilityClass.getFullEmailHtml(bodyHtml);
    }
}