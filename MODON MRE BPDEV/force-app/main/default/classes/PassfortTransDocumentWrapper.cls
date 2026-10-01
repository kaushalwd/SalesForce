/**********************************************************************************************************************
* Name               : PassfortTransDocumentWrapper                                                        
* Description        : This class wrapper class for creating document upload api request JSON for passfort transactions
* Usage              : used in PassfortTransDocumentQueueable class
* Created By         : PWC IN                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                Date            Comment                                                                       
* 1.0       kishor.sitaram.chaudhari@pwc.com         20 May 2024      Initial Draft       
******************************************************************************************************************/
public class PassfortTransDocumentWrapper {
    public blob data;
    public String name;
    public String root_id;
    public String id;
}