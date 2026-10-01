/**********************************************************************************************************************
* Name               : OIC_ManageInventoryMaster                                                        
* Description        : This class contains main integration methods for Oracle-Salesforce integration callouts.
* Usage              : Used across Triggers and Batch classes used for PropertyMaster
* Created By         : active Minds                                                  
* --------------------------------------------------------------------------------------------------------------------
Version         Author      Date             Comment
 * 1.0          Manoj     25-04-2026       Initial Draft
 * 2.0			Manoj	  12-05-2026	   add So Id
 * 3.0			Manoj	  24-05-2026	   Add new mapping 
***********************************************************************************************************************/
public class OIC_ManageInventoryMaster {
	/**
     * Description : Builds unit/SO payload and sends it to    
     *               Oracle via OIC inventory master callout.  
     */
    public static void getPropertyMaster(List<SObject> scope, String sObjectType) {

        try {
            List<OIC_RequestWrapperController.UnitRecord> unitWrapList =
                new List<OIC_RequestWrapperController.UnitRecord>();

            if (sObjectType == 'SalesOrder') {

                List<SalesOrder__c> soList = (List<SalesOrder__c>) scope;

                for (SalesOrder__c soObj : soList) {
                    OIC_RequestWrapperController.UnitRecord unitWrapObj =
                        new OIC_RequestWrapperController.UnitRecord();

                    unitWrapObj.bu_name                     = soObj.Unit__r.Phase__r.EntityName__c;
                    unitWrapObj.record_id                   = soObj.Id;
                    unitWrapObj.pass_id                     = soObj.Unit__r.Pass_id__c != null ? Decimal.valueOf(soObj.Unit__r.Pass_id__c) : null; // 2.0
                    unitWrapObj.project_name                = soObj.ProjectName__c;
                    unitWrapObj.project_number              = soObj.Unit__r.Phase__r.Project__r.ProjectNumber__c;
                    unitWrapObj.building_id                 = null;
                    unitWrapObj.building_name               = soObj.Unit__r.Building_Name__c;
                    unitWrapObj.building_number             = soObj.Unit__r.BuildingNo__c;
                    unitWrapObj.unit_id                     = soObj.Unit__c;
                    unitWrapObj.unit_type                   = soObj.Unit__r.Type__c;
                    unitWrapObj.unit_number                 = soObj.Unit__r.ADGMUnitNumber__c != null
                                                                ? soObj.Unit__r.ADGMUnitNumber__c
                                                                : soObj.Unit__r.PlotNo__c;
                    unitWrapObj.unit_name                   = soObj.Unit__r.Name;
                    unitWrapObj.unit_category               = soObj.Unit__r.UnitClassification__c;
                    unitWrapObj.unit_status                 = soObj.Unit__r.Status__c;
                    unitWrapObj.unit_launch_date            = soObj.Unit__r.Unit_Launch_Date__c;
                    unitWrapObj.unit_end_date               = null;
                    unitWrapObj.unit_description            = soObj.Unit__r.Description__c;
                    unitWrapObj.sqmt                        = soObj.Unit__r.UnitClassification__c == 'Plot' ? soObj.Unit__r.GrossFloorAreaGFA__c:soObj.Unit__r.TotalGrossSellableAreaGSA__c;
                    unitWrapObj.updated_date_of_unit        = Date.valueOf(soObj.Unit__r.LastModifiedDate);
                    unitWrapObj.sold_status                 = soObj.Unit__r.Status__c == 'Sold' ? 'Yes' : 'No';
                    unitWrapObj.gross_sale_price            = soObj.Unit__r.TotalPrice__c;
                    unitWrapObj.net_sale_price              = soObj.TotalAmount__c;
                    unitWrapObj.minimum_selling_price       = soObj.Unit__r.BasePrice__c;
                    unitWrapObj.realised_collections        = soObj.Totalpaidamount__c;
                    unitWrapObj.over_all_status             = soObj.Status__c;
                    unitWrapObj.dp_status                   = soObj.Down_Payment_Status__c;
                    unitWrapObj.spa_signed_status           = soObj.SPAStatus__c;
                    unitWrapObj.customer_code               = soObj.CustomerAccount__c;
                    unitWrapObj.customer_name               = soObj.CustomerAccount__r.Name;
                    unitWrapObj.spa_status                  = soObj.SPAStatus__c;
                    unitWrapObj.total_invocie_amount        = soObj.Totalpaidamount__c;
                    unitWrapObj.received                    = soObj.Totalpaidamount__c;
                    unitWrapObj.unit_sold_Date              = soObj.Unit__r.Unit_Sold_Date__c;
                    unitWrapObj.phase_name                  = soObj.Phase_Name__c;
                    unitWrapObj.total_area                  = soObj.Unit__r.PlotAreasqm__c;
                    unitWrapObj.spa_date                    = soObj.SPACustomerSignedDate__c;
                    unitWrapObj.spa_amount                  = soObj.TotalAmount__c;
                    unitWrapObj.approval_or_inventory_status = soObj.Unit__r.ApprovalStatus__c;
                    unitWrapObj.external_sales_commission  =soObj.External_Commission_Amount__c;
                    unitWrapObj.internal_sales_commission  =soObj.Indirect_Commission_Amount__c;
                    unitWrapObj.sales_commission        = soObj.Sales_Commission__c;
                    unitWrapObj.discount_cash 			= soObj.Discount_Amount__c;
                    unitWrapObj.discount_adm_or_adgm   =soObj.Discount_on_ADM_fee_Amount__c;
                    unitWrapObj.so_id = soObj.id; // 2.0
                    //Start 3.0
                    unitWrapObj.so_number = soObj.id;
                    unitWrapObj.so_name = soObj.Name;
                    unitWrapObj.plot_area = soObj.Unit__r.TotalArea__c != null ? soObj.Unit__r.TotalArea__c : soObj.Unit__r.PlotAreasqm__c;
                    unitWrapObj.unit_classification = soObj.Unit__r.Category__c;
                    unitWrapObj.gfa = soObj.Unit__r.GrossFloorAreaGFA__c;
                    unitWrapObj.gsa = soObj.Unit__r.TotalGrossSellableAreaGSA__c; // End 3.0
                    unitWrapObj.no_of_bedrooms = soObj.Unit__r.Number_of_Bedrooms__c;
                    unitWrapObj.project_launch_date = soObj.Unit__r.Project_Launch_Date__c;
                    unitWrapList.add(unitWrapObj);
                }

            } else if (sObjectType == 'Unit') {

                List<Unit__c> unitList = (List<Unit__c>) scope;

                for (Unit__c unObj : unitList) {
                    OIC_RequestWrapperController.UnitRecord unitWrapObj =
                        new OIC_RequestWrapperController.UnitRecord();

                    unitWrapObj.bu_name                     = unObj.Phase__r.EntityName__c;
                    unitWrapObj.record_id                   = unObj.Id;
                    unitWrapObj.pass_id                     = unObj.Pass_id__c != null ?Decimal.valueOf(unObj.Pass_id__c): null; //2.0
                    unitWrapObj.project_name                = unObj.Phase__r.Project__r.Name;
                    unitWrapObj.project_number              = unObj.Phase__r.Project__r.ProjectNumber__c;
                    unitWrapObj.building_id                 = null;
                    unitWrapObj.building_name               = unObj.Building_Name__c;
                    unitWrapObj.building_number             = unObj.BuildingNo__c;
                    unitWrapObj.unit_id                     = unObj.Id;       // Unit__c has no Unit__c lookup to itself
                    unitWrapObj.unit_type                   = unObj.Type__c;
                    unitWrapObj.unit_number                 = unObj.ADGMUnitNumber__c != null
                                                                ? unObj.ADGMUnitNumber__c
                                                                : unObj.PlotNo__c;
                    unitWrapObj.unit_name                   = unObj.Name;
                    unitWrapObj.unit_category               = unObj.UnitClassification__c;
                    unitWrapObj.unit_status                 = unObj.Status__c;
                    unitWrapObj.unit_launch_date            = unObj.Unit_Launch_Date__c;
                    unitWrapObj.unit_end_date               = null;
                    unitWrapObj.unit_description            = unObj.Description__c;
                    unitWrapObj.sqmt                        = unObj.UnitClassification__c == 'Plot' ? unObj.GrossFloorAreaGFA__c:unObj.TotalGrossSellableAreaGSA__c;
                    unitWrapObj.updated_date_of_unit        = Date.valueOf(unObj.LastModifiedDate);
                    unitWrapObj.sold_status                 = unObj.Status__c == 'Sold' ? 'Yes' : 'No';
                    unitWrapObj.gross_sale_price            = unObj.TotalPrice__c;
                    unitWrapObj.net_sale_price              = null;           // TotalAmount__c not on Unit__c
                    unitWrapObj.minimum_selling_price       = unObj.BasePrice__c;
                    unitWrapObj.realised_collections        = null;
                    unitWrapObj.over_all_status             = null;
                    unitWrapObj.dp_status                   = null;
                    unitWrapObj.spa_signed_status           = null;
                    unitWrapObj.customer_code               = null;
                    unitWrapObj.customer_name               = null;
                    unitWrapObj.spa_status                  = null;
                    unitWrapObj.total_invocie_amount        = null;
                    unitWrapObj.received                    = null;
                    unitWrapObj.unit_sold_Date              = unObj.Unit_Sold_Date__c;
                    unitWrapObj.phase_name                  = unObj.Phase__r.Name;
                    unitWrapObj.total_area                  = unObj.PlotAreasqm__c;
                    unitWrapObj.spa_date                    = null;
                    unitWrapObj.spa_amount                  = null;
                    unitWrapObj.approval_or_inventory_status = unObj.ApprovalStatus__c; // Fixed: no Unit__r on Unit__c
                    unitWrapObj.external_sales_commission  =0;
                    unitWrapObj.internal_sales_commission  =0;
                    unitWrapObj.sales_commission        = 0;
                    unitWrapObj.discount_cash 			= 0;
                    unitWrapObj.discount_adm_or_adgm   =0;
                    //start 3.0
                    unitWrapObj.plot_area = unObj.TotalArea__c != null ? unObj.TotalArea__c : unObj.PlotAreasqm__c;
                    unitWrapObj.unit_classification = unObj.Category__c;
                    unitWrapObj.gfa = unObj.GrossFloorAreaGFA__c;
                    unitWrapObj.gsa = unObj.TotalGrossSellableAreaGSA__c;  //End 3.0
                    unitWrapObj.no_of_bedrooms = unObj.Number_of_Bedrooms__c;
                    unitWrapObj.project_launch_date = unObj.Project_Launch_Date__c;
                    unitWrapList.add(unitWrapObj);
                }
            }

            // ── HTTP Callout (shared for both sObjectTypes) ──────────────────
            HttpRequest req = new HttpRequest();
            req = OIC_CredentialsController.getCredentials('ModonFusionPropertyMasterData');
            req.setTimeout(120000);

            OIC_RequestWrapperController.UnitRecordWrapperList unitRecordWrapperList =
                new OIC_RequestWrapperController.UnitRecordWrapperList();
            unitRecordWrapperList.RequestArray = unitWrapList;

            String proWrappString = JSON.serialize(unitRecordWrapperList);
            System.debug('JSON.serialize(unitRecordWrapperList)==> ' + proWrappString);

            Blob   binaryData    = Blob.valueOf(proWrappString);
            String base64String  = EncodingUtil.base64Encode(binaryData);

            OIC_RequestWrapperController.Base64Wrapper wrapper =
                new OIC_RequestWrapperController.Base64Wrapper();
            wrapper.Base64RequestPayload = base64String;

            req.setBody(JSON.serialize(wrapper));
            System.debug('JSON.serialize(wrapper)==> ' + JSON.serialize(wrapper));

            Http         http = new Http();
            HTTPResponse res  = http.send(req);
            System.debug('Inventory Master Res: '       + res);
            System.debug('Inventory Master Res Body: '  + res.getBody());

            String custResponseBody = res.getBody();

            if (String.isNotBlank(custResponseBody)) {

                OIC_RequestWrapperController.Base64ResponseWrapper base64RespWrap =
                    (OIC_RequestWrapperController.Base64ResponseWrapper)
                        JSON.deserialize(custResponseBody,
                            OIC_RequestWrapperController.Base64ResponseWrapper.class);

                Blob   custResponseBlobActual   = null;
                String custResponseStringActual = null;

                if (String.isNotBlank(base64RespWrap.Base64Response)) {
                    custResponseBlobActual = EncodingUtil.base64Decode(base64RespWrap.Base64Response);
                }
                if (custResponseBlobActual != null) {
                    custResponseStringActual = custResponseBlobActual.toString();
                }

                System.debug('custResponseStringActual: ' + custResponseStringActual);

                if (custResponseStringActual != null) {

                    OIC_RequestWrapperController.OICResponseWrapperList custResponseObjectActual =
                        (OIC_RequestWrapperController.OICResponseWrapperList)
                            JSON.deserialize(custResponseStringActual,
                                OIC_RequestWrapperController.OICResponseWrapperList.class);

                    if (custResponseObjectActual != null) {

                        List<Unit__c>         lstRecordToUpdate    = new List<Unit__c>();
                        Set<String>           recordIds            = new Set<String>();
                        Map<String, Integer>  mp_recId_NoOfReTries = new Map<String, Integer>();

                        for (OIC_RequestWrapperController.OICResponseWrapper resp
                                : custResponseObjectActual.ResponseArray) {
                            recordIds.add(resp.Sfid);
                        }

                        if (!recordIds.isEmpty()) {
                            for (Unit__c rec : [
                                SELECT Id, OICNoOfRetries__c
                                FROM   Unit__c
                                WHERE  Id IN :recordIds
                                AND    OICNoOfRetries__c != null
                            ]) {
                                mp_recId_NoOfReTries.put(rec.Id, Integer.valueOf(rec.OICNoOfRetries__c));
                            }
                        }

                        // Pre-load error message metadata once
                        Map<String, String> errorMsgMap = new Map<String, String>();
                        for (Integration_Error_Messages__mdt m : [
                            SELECT System_Error_Msg__c, User_Error_Msg__c
                            FROM   Integration_Error_Messages__mdt
                            WHERE  IsActive__c = true
                            AND    Application_Type__c = 'EBS'
                        ]) {
                            errorMsgMap.put(m.System_Error_Msg__c, m.User_Error_Msg__c);
                        }

                        for (OIC_RequestWrapperController.OICResponseWrapper resp
                                : custResponseObjectActual.ResponseArray) {

                            Unit__c recordToUpdate   = new Unit__c();
                            recordToUpdate.Id = resp.Sfid;

                            if (resp.Status == 'S') {
                                recordToUpdate.OICNoOfRetries__c      = null;
                                recordToUpdate.Pass_id__c             = resp.OracleId;
                                recordToUpdate.OICIntegrationMessage__c = null;
                                recordToUpdate.OICIntegrationStatus__c  = resp.Status;

                            } else if (resp.Status == 'E') {
                                recordToUpdate.OICIntegrationStatus__c = resp.Status;

                                if (resp.ErrorMsg != null) {
                                    String userErrorMsg =
                                        UserErrorMessage.getUserErrorMessage(resp.ErrorMsg, errorMsgMap);

                                    if (resp.ErrorMsg.contains('Unknown integration error')) {
                                        recordToUpdate.OICIntegrationMessage__c =
                                            'Required information is not updated in Salesforce. Please contact support';
                                    } else if (userErrorMsg == null) {
                                        recordToUpdate.OICIntegrationMessage__c =
                                            'Required information is not updated in Salesforce. Please contact support, '
                                            + resp.ErrorMsg;
                                    } else {
                                        recordToUpdate.OICIntegrationMessage__c = userErrorMsg;
                                    }
                                }

                                if (!mp_recId_NoOfReTries.isEmpty()
                                        && mp_recId_NoOfReTries.containsKey(resp.Sfid)
                                        && mp_recId_NoOfReTries.get(resp.Sfid) != null) {
                                    recordToUpdate.OICNoOfRetries__c =
                                        mp_recId_NoOfReTries.get(resp.Sfid) + 1;
                                } else {
                                    recordToUpdate.OICNoOfRetries__c = 1;
                                }
                            }

                            lstRecordToUpdate.add(recordToUpdate);
                        }

                        if (!lstRecordToUpdate.isEmpty()) {
                            update lstRecordToUpdate;
                        }
                    }
                }

                // Log the callout (success or error)
                LoggerService.save(
                    LoggerService.createAPILog(
                        'Inventory Master API',
                        'OIC_ManageInventoryMaster',     
                        'getPropertyMaster',
                        proWrappString,
                        custResponseStringActual,
                        'Status Code: ' + res.getStatusCode() + '; Status: ' + res.getStatus(),
                        'Callout Log'
                    )
                );
            }

        } catch (Exception ex) {
            LoggerService.save(
                LoggerService.createApexLog(
                    ex,
                    'Inventory Master API',
                    'OIC_ManageInventoryMaster',
                    'getPropertyMaster'          
                )
            );
        }
    }
}