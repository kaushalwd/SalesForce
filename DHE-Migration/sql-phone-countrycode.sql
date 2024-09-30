SELECT
id,
CountryCode,
phone,
IIF(Replace(CountryCode,'+','') = Substring(Replace(Phone,'+',''),0,len(Replace(CountryCode,'+',''))+1), Replace(Phone,'+',''), Concat(Replace(CountryCode,'+',''),Replace(Phone,'+',''))) AS MergedPhone
FROM Ent.MasterDE_AD
WHERE
(CountryCode='+374' or Phone like '374%' or
CountryCode='+994' or Phone like '994%' or
CountryCode='+973' or Phone like '973%' or
CountryCode='+995' or Phone like '995%' or
CountryCode='+98' or Phone like '98%' or
CountryCode='+964' or Phone like '964%' or
CountryCode='+972' or Phone like '972%' or
CountryCode='+962' or Phone like '962%' or
CountryCode='+965' or Phone like '965%' or
CountryCode='+961' or Phone like '961%' or
CountryCode='+968' or Phone like '968%' or
CountryCode='+974' or Phone like '974%' or
CountryCode='+966' or Phone like '966%' or
CountryCode='+963' or Phone like '963%' or
CountryCode='+90' or Phone like '90%' or
CountryCode='+993' or Phone like '993%' or
CountryCode='+971' or Phone like '971%' or
CountryCode='+967' or Phone like '967%' or
CountryCode='+20' or Phone like '20%' or
CountryCode='+357' or Phone like '357%' or
CountryCode='+970' or Phone like '970%'
) AND
(phone like '0%' OR phone like '+%' OR Replace(CountryCode,'+','')=Substring(Phone,0,len(CountryCode)))
And FirstName like '%AKASH%' 