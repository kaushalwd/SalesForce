%%[ set @parameters= concat ('?','sfid', '=',  [Contactkey]) ]%%  %%=v(@parameters)=%%

%%[ set @parameters= concat ('?','sfid', '=',  [subscriberId] ]%%  %%=v(@parameters)=%%

%%[ set @str = [subscriberId] set @cpcparameters= concat ('?','sfid', '=',  @str,'#communications') ]%%  %%=v(@cpcparameters)=%%

%%[  set @str = [subscriberId]  set @id = Base64Encode(@str) set @cpcparameters= concat ('?','sfid', '=',  @id,'#communications') ]%%  %%=v(@cpcparameters)=%%

%%[ set @str = [subscriberId] set @cpcparameters= concat ('?','sfid', '=',  @str,'#communications') ]%%  %%=v(@cpcparameters)=%%

%%[


    %%[  set @str = _subscriberkey  set @id = Base64Encode(@str) set @cpcparameters= concat ('?','sfid', '=',  @id,'#communications') ]%%  %%=v(@cpcparameters)=%%


    var @numOfKids
        /*SET @crmIdEn = "0036M000049KdzZQAS" 
        SET @crmIdEn = QueryParameter("sfid")
        SET @crmId = Base64Decode(@crmIdEn)*/
        SET @crmId = _subscriberkey
        IF (empty(@crmId)) THEN
        SET @crmIdEn = QueryParameter("sfid")
        SET @crmId = Base64Decode(@crmIdEn)
        SET @methodType= 'Old'
          IF (empty(@crmId)) THEN
          SET @crmId = RequestParameter("sfid")
            IF (empty(@crmId)) THEN
             SET @crmId = QueryParameter("sfid")
            ENDIF
         ENDIF
        ENDIF