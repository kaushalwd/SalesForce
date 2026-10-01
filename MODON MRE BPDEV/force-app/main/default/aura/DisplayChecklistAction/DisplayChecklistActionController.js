({ 
    doInit: function (component, event, helper) { 
        var action = component.get("c.getSalesOrderSubStatus"); 
        action.setParams({ recordId: component.get("v.recordId") }); 
        action.setCallback(
            this, function (response) { 
                var state = response.getState();
                 if (state === "SUCCESS") { 
                    var subStatus = response.getReturnValue(); 
                    if (subStatus != null) { 
                        var recordId = component.get("v.recordId"); 
                        var navUrl = '/lightning/n/SalesChecklistPage?c__recordId=' + recordId;
                        window.open(navUrl, '_blank'); } $A.get("e.force:closeQuickAction").fire(); } 
                    else { 
                        console.error("Failed to fetch Sub_Status__c:", response.getError()); 
                        $A.get("e.force:closeQuickAction").fire(); } 
            }
        ); 
        $A.enqueueAction(action); 
    }, handleClick: function (component, event, helper) { } 
})