@IsTest
private class BRConstantsTest {
    @IsTest
    static void testConstantsCoverage() {
        Map<String, Schema.RecordTypeInfo> contactRtByName = Schema.SObjectType.Contact.getRecordTypeInfosByName();
        Map<String, Schema.RecordTypeInfo> accountRtByName = Schema.SObjectType.Account.getRecordTypeInfosByName();

        Boolean hasBrokerAgentRt = contactRtByName != null && contactRtByName.containsKey('Broker Agent');
        Boolean hasBrokerAgencyRt = accountRtByName != null && accountRtByName.containsKey('Broker Agency');

        if (hasBrokerAgentRt && hasBrokerAgencyRt) {
            String v1 = BRConstants.ACTION_STATUS_APPROVED;
            String v2 = BRConstants.ACTION_STATUS_REJECTED;
            String v3 = BRConstants.ACTION_STATUS_SIGNED;
            String v4 = BRConstants.ACTION_STATUS_VOIDED;
            String v5 = BRConstants.ACTION_STATUS_RMI;
            String v6 = BRConstants.ACTION_STATUS_COMPLETED;

            String v7 = BRConstants.SERVICE_REQUEST_TASK1;
            String v8 = BRConstants.SERVICE_REQUEST_TASK2;
            String v9 = BRConstants.SERVICE_REQUEST_TASK3;
            String v10 = BRConstants.SERVICE_REQUEST_TASK4;
            String v11 = BRConstants.SERVICE_REQUEST_TASK5;
            String v12 = BRConstants.TASK_STATUS_CLOSED;

            String v13 = BRConstants.AGENT_TYPE_OWNER;
            String v14 = BRConstants.AGENT_TYPE_AGENCYADMIN;
            String v15 = BRConstants.AGENT_TYPE_AGENT;

            String v16 = BRConstants.ACCOUNT_STATUS_PENDINGVERIFICATION;
            String v17 = BRConstants.ACCOUNT_STATUS_ACTIVE;

            String v18 = BRConstants.MODON_PARTNER_COMMUNITY_PROFILE;
            String v19 = BRConstants.MODON_PARTNER_COMMUNITY_PROFILE_INT;
            String v20 = BRConstants.MODON_LIMITED_LOGIN_ACCESS;
            String v21 = BRConstants.MODON_AGENT_ACCESS;
            String v22 = BRConstants.MODON_AGENCY_OWNER_ACCESS;
            String v23 = BRConstants.MODON_AGENCY_ADMIN_ACCESS;

            String v24 = BRConstants.RETIRED;
            String v25 = BRConstants.CONVERTED_LEAD;
            String v26 = BRConstants.UNIT_STATUS_SOLD;

            String v27 = BRConstants.BROKER_AGENT_RT;
            String v28 = BRConstants.BROKER_AGENCY_RT;

            String v29 = BRConstants.COMM_ACTION_TYPES;
            String v30 = BRConstants.COMM_ACTION_REGIONS;
            String v31 = BRConstants.COMM_ACTION_COUNTRIES;
            String v32 = BRConstants.COMM_ACTION_STATES;
            String v33 = BRConstants.COMM_ACTION_INTERNAL_ROLES;
            String v34 = BRConstants.COMM_ACTION_AGENCIES;
            String v35 = BRConstants.COMM_ACTION_ORG_WIDE_EMAILS;
            String v36 = BRConstants.COMM_ACTION_AGENCY_CONTACTS;
            String v37 = BRConstants.COMM_ACTION_USERS_BY_ROLES;
            String v38 = BRConstants.COMM_ACTION_DRAFTS;
            String v39 = BRConstants.COMM_ACTION_UPLOAD_FILES;
            String v40 = BRConstants.COMM_ACTION_LINK_FILES;
            String v41 = BRConstants.COMM_ACTION_BANNER_URL;
            String v42 = BRConstants.COMM_ACTION_PREVIEW_HTML;
            String v43 = BRConstants.COMM_ACTION_SEND_TEST_EMAIL;
            String v44 = BRConstants.COMM_ACTION_PROCESS_COMMUNICATION;
            String v45 = BRConstants.COMM_ACTION_PUBLISH_DRAFTS;
            String v46 = BRConstants.COMM_ACTION_SEND_EMAIL_AFTER_APPROVAL;
            String v47 = BRConstants.COMM_ACTION_UPDATE_AGENCY_MAPPING_STATUS;
            String v48 = BRConstants.COMM_ACTION_SEND_COMMUNICATION_EMAILS;

            String v49 = BRConstants.COMMUNICATION_TYPE_INTERNAL;
            String v50 = BRConstants.COMMUNICATION_TYPE_EXTERNAL;
            String v51 = BRConstants.AGENT_TYPE_ALL;

            String v52 = BRConstants.REGION_ALL;
            String v53 = BRConstants.REGION_DOMESTIC;
            String v54 = BRConstants.REGION_INTERNATIONAL;

            String v55 = BRConstants.CONTEXT_GENERAL;
            String v56 = BRConstants.CONTEXT_EVENT;

            String v57 = BRConstants.COUNTRY_UAE;
            String v58 = BRConstants.EMIRATE_DUBAI;
            String v59 = BRConstants.EMIRATE_ABU_DHABI;
            String v60 = BRConstants.EMIRATE_SHARJAH;
            String v61 = BRConstants.EMIRATE_AJMAN;
            String v62 = BRConstants.EMIRATE_RAS_AL_KHAIMAH;
            String v63 = BRConstants.EMIRATE_FUJAIRAH;
            String v64 = BRConstants.EMIRATE_UMM_AL_QUWAIN;

            String v65 = BRConstants.SENT_OPTION_SEND_NOW;
            String v66 = BRConstants.SENT_OPTION_SEND_LATER;
            String v67 = BRConstants.SENT_OPTION_SAVE_AS_DRAFT;

            String v68 = BRConstants.COMM_APPROVAL_PENDING;
            String v69 = BRConstants.COMM_APPROVAL_DRAFT;

            String v70 = BRConstants.MAPPING_STATUS_ASSIGNED;
            String v71 = BRConstants.MAPPING_STATUS_UNASSIGNED;

            String v72 = BRConstants.PORTAL_TYPE_CUSTOMER;
            String v73 = BRConstants.FILE_PREFIX_BANNER;
            String v74 = BRConstants.FILE_SHARETYPE_VIEW;
            String v75 = BRConstants.FILE_VISIBILITY_ALL_USERS;
            String v76 = BRConstants.DEFAULT_FROM_NAME;
            String v77 = BRConstants.DEFAULT_NO_COUNTRY;
            String v78 = BRConstants.APPROVAL_PROCESS_COMMUNICATION;
            String v79 = BRConstants.APPROVAL_COMMENT_SUBMIT;
            String v80 = BRConstants.APPROVAL_COMMENT_SUBMIT_DRAFT;

            List<String> emirates = BRConstants.UAE_EMIRATES;

            System.debug(v1);  System.debug(v2);  System.debug(v3);  System.debug(v4);  System.debug(v5);
            System.debug(v6);  System.debug(v7);  System.debug(v8);  System.debug(v9);  System.debug(v10);
            System.debug(v11); System.debug(v12); System.debug(v13); System.debug(v14); System.debug(v15);
            System.debug(v16); System.debug(v17); System.debug(v18); System.debug(v19); System.debug(v20);
            System.debug(v21); System.debug(v22); System.debug(v23); System.debug(v24); System.debug(v25);
            System.debug(v26); System.debug(v27); System.debug(v28); System.debug(v29); System.debug(v30);
            System.debug(v31); System.debug(v32); System.debug(v33); System.debug(v34); System.debug(v35);
            System.debug(v36); System.debug(v37); System.debug(v38); System.debug(v39); System.debug(v40);
            System.debug(v41); System.debug(v42); System.debug(v43); System.debug(v44); System.debug(v45);
            System.debug(v46); System.debug(v47); System.debug(v48); System.debug(v49); System.debug(v50);
            System.debug(v51); System.debug(v52); System.debug(v53); System.debug(v54); System.debug(v55);
            System.debug(v56); System.debug(v57); System.debug(v58); System.debug(v59); System.debug(v60);
            System.debug(v61); System.debug(v62); System.debug(v63); System.debug(v64); System.debug(v65);
            System.debug(v66); System.debug(v67); System.debug(v68); System.debug(v69); System.debug(v70);
            System.debug(v71); System.debug(v72); System.debug(v73); System.debug(v74); System.debug(v75);
            System.debug(v76); System.debug(v77); System.debug(v78); System.debug(v79); System.debug(v80);
            System.debug(emirates);
        }
    }
}