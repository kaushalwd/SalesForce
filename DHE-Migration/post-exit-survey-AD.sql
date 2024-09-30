Select
M.id,
M.FirstName,
M.GuestSubsId,
M.LastName,
M.OriginAsset,
M.OriginSubAsset,
M.RecordTypeId,
M.RegistrationLanguage,
M.EmailPreference,
M.Email,
M.Asset,
M.SubAsset,
M.Phone,
M.OptOutStatus,
M.Locale,
sur.InvitationLink,
sur.ParticipantId,
sur.SurveyId,
MAX(sur.SurveyDate) AS LatestSurveyDate,
M.WhatsappPreference,
IIF(Replace(M.CountryCode,'+','') = Substring(Replace(M.Phone,'+',''),0,len(Replace(M.CountryCode,'+',''))+1), Replace(M.Phone,'+',''), Concat(Replace(M.CountryCode,'+',''),Replace(M.Phone,'+',''))) AS MergedPhone
FROM [MasterDE_AD_Copy] AS m
INNER JOIN [Master_SurveyInvitation_Salesforce_Copy] AS sur
ON sur.SurveyId = m.id
And m.Status = 'Subscribed' and m.TempPause30Days = 'False'
And (m.EmailPreference = 'True' or m. WhatsAppPreference = 'True')
And (m.RecordTypeId = '012060000015KARAA2' or m.RecordTypeId = '012Qs0000023cPRIAY')
And
(M.CountryCode='374' or M.Phone like '374%' or
M.CountryCode='994' or M.Phone like '994%' or
M.CountryCode='973' or M.Phone like '973%' or
M.CountryCode='995' or M.Phone like '995%' or
M.CountryCode='98' or M.Phone like '98%' or
M.CountryCode='964' or M.Phone like '964%' or
M.CountryCode='972' or M.Phone like '972%' or
M.CountryCode='962' or M.Phone like '962%' or
M.CountryCode='965' or M.Phone like '965%' or
M.CountryCode='961' or M.Phone like '961%' or
M.CountryCode='968' or M.Phone like '968%' or
M.CountryCode='974' or M.Phone like '974%' or
M.CountryCode='966' or M.Phone like '966%' or
M.CountryCode='963' or M.Phone like '963%' or
M.CountryCode='90' or M.Phone like '90%' or
M.CountryCode='993' or M.Phone like '993%' or
M.CountryCode='971' or M.Phone like '971%' or
M.CountryCode='967' or M.Phone like '967%' or
M.CountryCode='20' or M.Phone like '20%' or
M.CountryCode='357' or M.Phone like '357%' or
M.CountryCode='970' or M.Phone like '970%' or
M.CountryCode='91' or M.Phone like '91%'
) 
AND
(M.Phone like '0%' OR M.Phone like '+%' OR Replace(M.CountryCode,'+','')=Substring(M.Phone,0,len(M.CountryCode)))
And m.Email like '%@horizontal.com%' 