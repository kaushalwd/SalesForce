# Broker Agency Agreement - Visualforce PDF

## Files

1. `MBP_BrokerAgencyAgreementPDF.page`
2. `MBP_BrokerAgencyAgreementPDFController.cls`
3. `MBP_Modon_Logo.png`

## Salesforce setup

1. Create a Static Resource named `MBP_Modon_Logo`.
2. Upload `MBP_Modon_Logo.png` as the static resource.
3. Create the Visualforce page using `MBP_BrokerAgencyAgreementPDF.page`.
4. Deploy `MBP_BrokerAgencyAgreementPDFController.cls`.
5. The page expects a URL parameter named `id`, containing the `ServiceRequest__c` Id.

Example:

`/apex/MBP_BrokerAgencyAgreementPDF?id=<ServiceRequestId>`

## Dynamic fields

The PDF controller reads the same ServiceRequest/Registration fields already used by the current DocuSign controller:

- Registration__r.Agency_Name__c
- Registration__r.Licensing_Authority__c
- Registration__r.Trade_License_Number__c
- Registration__r.UAE_VAT_Registration_Number__c
- Registration__r.Address_Line_1__c
- Registration__r.City__c
- Registration__r.State__c
- Broker_Agency_Owner_Name__c
- Broker_Agency_Owner_Email__c

The `(2)` agency paragraph is rendered directly by Visualforce, so long agency names and addresses wrap naturally instead of relying on DocuSign TextTab anchors.

## DocuSign integration

For the current controller, the recommended flow is:

1. Call `MBP_BrokerAgencyAgreementPDFController.generateAgreementAndQueueSend(srId)` from the LWC/button.
2. The method synchronously renders the full agreement PDF.
3. It inserts one ContentVersion containing the complete 22-page PDF.
4. It queues the existing `MBP_SendForSignatureController.SendJob`.
5. The existing SendJob sends that ContentVersion to DocuSign.

Remove these dynamic text tabs from the DocuSign recipient:

- `\\agency_name\\`
- `\\agency_authority\\`
- `\\agency_license\\`
- `\\agency_address\\`
- `\\agency_rep\\`
- `\\cover_agency\\`
- `\\made_date\\`

Those values are already printed into the PDF.

Signature/date/stamp anchors can remain temporarily. If you want zero anchors later, replace those signature anchors with `dfsle.Tab.Position` tabs.

## Important

The Visualforce page is generated from the uploaded 22-page agreement content and keeps the source document's page-break structure. Exact pixel-level pagination can still require small CSS adjustments in Salesforce's Visualforce PDF renderer.
