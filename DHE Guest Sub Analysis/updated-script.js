< script runat = "server" >
    Platform.Load("core", "1.1.5");
try {
    var sfUpdateString;
    var deKey = "3009D361-9F05-4F06-A1F6-8241C712DD8F", // TempPauseHandleFiltered_Prod - replace with the external key of the DE holding the query results
        prox = new Script.Util.WSProxy(),
        objectType = "DataExtensionObject[" + deKey + "]",
        cols = ["SubscriberKey", "ContactId", "Email", "UnsubscribeType"],
        moreData = true,
        reqID = null;
    while (moreData) {
        moreData = false;
        var data = reqID == null ?
            prox.retrieve(objectType, cols) :
            prox.getNextBatch(objectType, reqID);
        if (data != null) {
            moreData = data.HasMoreRows;
            reqID = data.RequestID;
            if (data && data.Results) {
                //Write("<br>data.Results = "+Stringify(data));
                //Write("<br>data.Results.length = "+data.Results.length);
                for (var i = 0; i < data.Results.length; i++) {
                    Write("<br>i = " + i);
                    var guestSubkey = data.Results[i].Properties[0].Value;
                    var contactSubkey = data.Results[i].Properties[1].Value;
                    var email = data.Results[i].Properties[2].Value;
                    var unsubscribeType = data.Results[i].Properties[3].Value;
                    Write("guestSubkey = " + guestSubkey + "<br>");
                    Write("contactSubkey = " + contactSubkey + "<br>");
                    Write("unsubscribeType = " + unsubscribeType + "<br>");
                    var options = {
                        SaveOptions: [{
                            'PropertyName': '*',
                            SaveAction: 'UpdateAdd'
                        }]
                    };
                    var resub = {
                        "SubscriberKey": contactSubkey,
                        "Lists": {
                            "ID": '63',
                            "Action": "Update"
                        },
                        "Status": "Active"
                    };
                    //Write("resub = "+Stringify(resub)+"<br>");
                    var subObj = Subscriber.Init(contactSubkey);
                    var updateStatus = subObj.Update(resub);
                    Write("updateStatus = " + Stringify(updateStatus) + "<br>");
                    var resub = {
                        "SubscriberKey": contactSubkey,
                        "Lists": [{
                            ID: 2373,
                            Status: 'Active'
                        }]
                    };

                    var updateStatus = subObj.Update(resub);
                    Write("updateStatus = " + Stringify(updateStatus) + "<br>");
                    var resub = {
                        "SubscriberKey": contactSubkey,
                        "Lists": [{
                            ID: 2374,
                            Status: 'Active'
                        }]
                    };

                    var updateStatus = subObj.Update(resub);
                    Write("updateStatus = " + Stringify(updateStatus) + "<br>");
                    var resub = {
                        "SubscriberKey": contactSubkey,
                        "Lists": [{
                            ID: 2375,
                            Status: 'Active'
                        }]
                    };

                    var updateStatus = subObj.Update(resub);
                    Write("updateStatus = " + Stringify(updateStatus) + "<br>");
                    var resub = {
                        "SubscriberKey": contactSubkey,
                        "Lists": [{
                            ID: 2376,
                            Status: 'Active'
                        }]
                    };

                    var updateStatus = subObj.Update(resub);
                    Write("updateStatus = " + Stringify(updateStatus) + "<br>");
                    var resub = {
                        "SubscriberKey": contactSubkey,
                        "Lists": [{
                            ID: 2377,
                            Status: 'Active'
                        }]
                    };

                    var updateStatus = subObj.Update(resub);
                    Write("updateStatus = " + Stringify(updateStatus) + "<br>");
                    var resub = {
                        "SubscriberKey": contactSubkey,
                        "Lists": [{
                            ID: 2378,
                            Status: 'Active'
                        }]
                    };

                    var updateStatus = subObj.Update(resub);
                    Write("updateStatus = " + Stringify(updateStatus) + "<br>");
                    var resub = {
                        "SubscriberKey": contactSubkey,
                        "Lists": [{
                            ID: 2372,
                            Status: 'Active'
                        }]
                    };

                    var updateStatus = subObj.Update(resub);
                    Write("updateStatus = " + Stringify(updateStatus) + "<br>");

                    var fieldArr = [];
                    var contactfieldArr = [];
                    //fieldArr.push('Temporary_Pause_30_Days__c');
                    //fieldArr.push('False');
                    fieldArr.push('Status__c');
                    fieldArr.push('Subscribed');
                    fieldArr.push('Consent_Collection_Asset__c');
                    fieldArr.push('Dubai Parks and Resorts');
                    fieldArr.push('Consent_Collection_Sub_Asset__c');
                    fieldArr.push('Riverland');
                    fieldArr.push('Consent_Latest_Source__c');
                    fieldArr.push('CPC');

                    contactfieldArr.push('Latest_Channel_Source__c');
                    contactfieldArr.push('CPC - RiverLand');
                    // Nitik 14th Mar24, to differentiate the unsubscribe

                    if (unsubscribeType == "Individual") {
                        // Nitik 14th Mar24, single unsubscribe type
                        var updateSFObject = "";
                        updateSFObject += "\%\%[";
                        updateSFObject += "set @SFUpdateResults = UpdateSingleSalesforceObject('Guest_Subscription__c',";
                        updateSFObject += "'" + guestSubkey + "','" + fieldArr.join("','") + "','Subscription_Date__c',FormatDate(Now(),'" + "iso')";
                        updateSFObject += ") ";
                        updateSFObject += "output(concat(@SFUpdateResults)) ";
                        updateSFObject += "]\%\%";

                        var results = Platform.Function.TreatAsContent(updateSFObject);
                        Write("final result - " + Stringify(results));
                        Write("NewUpdated");
                        var updateSFContactObject = "";
                        updateSFContactObject += "\%\%[";
                        updateSFContactObject += "set @SFUpdateResults = UpdateSingleSalesforceObject('Contact',";
                        updateSFContactObject += "'" + contactSubkey + "','" + contactfieldArr.join("','") + "'";
                        updateSFContactObject += ") ";
                        updateSFContactObject += "output(concat(@SFUpdateResults)) ";
                        updateSFContactObject += "]\%\%";

                        var results = Platform.Function.TreatAsContent(updateSFContactObject);
                        Write("final result ------ " + Stringify(results));
                        Write("NewUpdated");
                    } else {
                        // Nitik 14th Mar24, all unsubscribe type and to retrieve all the guest subscription Id's by calling ampscript function
                        var retriveSFObject = ampScript("SET @retrieve = RetrieveSalesforceObjects(" +
                            "'Guest_Subscription__c', 'Id', 'Contact__c', '=','" + contactSubkey + "') " +
                            "SET @rowCount = RowCount(@retrieve) SET @response = '' " +
                            "IF @rowCount > 0 THEN FOR @counter = 1 TO @rowCount DO " +
                            "SET @row = Row(@retrieve, @counter) " +
                            "SET @id = Field(@row, 'Id') " +
                            "SET @response = Concat(@response, @id, ';') " +
                            "NEXT @counter ENDIF");
                        retriveSFObject = retriveSFObject.split(';');

                        for (var j = 0; j < retriveSFObject.length - 1; j++) {
                            Write('<br> retriveSFObject: ' + retriveSFObject[j] + '<br>');
                            var updateSFObject = "";
                            updateSFObject += "\%\%[";
                            updateSFObject += "set @SFUpdateResults = UpdateSingleSalesforceObject('Guest_Subscription__c',";
                            updateSFObject += "'" + retriveSFObject[j] + "','" + fieldArr.join("','") + "','Subscription_Date__c',FormatDate(Now(),'" + "iso')";
                            updateSFObject += ") ";
                            updateSFObject += "output(concat(@SFUpdateResults)) ";
                            updateSFObject += "]\%\%";

                            var results = Platform.Function.TreatAsContent(updateSFObject);
                            Write("final result - " + Stringify(results));
                            Write("NewUpdated");

                        }
                    }

                    var updateSFContactObject = "";
                    updateSFContactObject += "\%\%[";
                    updateSFContactObject += "set @SFUpdateResults = UpdateSingleSalesforceObject('Contact',";
                    updateSFContactObject += "'" + contactSubkey + "','" + contactfieldArr.join("','") + "','Receive_Updates__c','True'";
                    updateSFContactObject += ") ";
                    updateSFContactObject += "output(concat(@SFUpdateResults)) ";
                    updateSFContactObject += "]\%\%";

                    var results = Platform.Function.TreatAsContent(updateSFContactObject);
                    Write("final result ------ " + Stringify(results));
                    Write("NewUpdated");




                }
            }
        }
    }
} catch (e) {
    Write(Stringify(e));
}

function ampScript(code) {
    var ampBlock = '\%\%[' + code + ']\%\%';
    Platform.Function.TreatAsContent(ampBlock);
    return Variable.GetValue('@response');
} <
/script>