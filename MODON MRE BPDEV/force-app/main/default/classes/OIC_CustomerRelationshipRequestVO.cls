/**********************************************************************************************************************
* Name               : OIC_CustomerRelationshipRequestVO
* Description        : Payload VO for the OIC CreateCustomerRelationshipAPI callout. Built by
*                       OIC_CustomerRelationshipCallout and serialized as the callout request body, and reused
*                       as-is to deserialize the callout response (Oracle echoes the same shape back plus
*                       RelationshipId/Status/ErrorMessage).
* Usage              : Built by OIC_CustomerRelationshipCallout and serialized as the callout body
* Created By         : Karunakar
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Karunakar                           24 Aug 2026     Initial Draft
**********************************************************************************************************************/
public class OIC_CustomerRelationshipRequestVO {
    public String SubjectPartyId = '';
    public String SubjectSfPartyId = '';
    public String SubjectType = '';
    public String ObjectPartyId = '';
    public String ObjectSfPartyId = '';
    public String ObjectType = '';
    public String Type = '';
    public String SubjectAccountId = '';
    public String SubjectSfAccountId = '';
    public String ObjectAccountId = '';
    public String ObjectSfAccountId = '';
    public String RelationshipId = '';
    public String RelationshipSfId = '';
    public String Status = '';
    public String ErrorMessage = '';
}