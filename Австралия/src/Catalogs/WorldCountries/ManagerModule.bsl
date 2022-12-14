#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchObjectsModification

// Returns the object attributes that are not recommended to be edited using batch attribute 
// modification┬ádata processor.
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToSkipInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("*");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchObjectModification

#EndRegion

#EndRegion

#EndIf

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Not StandardProcessing Then
		// Processed elsewhere.
		Return;
		
	ElsIf Not Parameters.Property("AllowClassifierData") Then
		// Default behavior, catalog picking only.
		Return;
		
	ElsIf True <> Parameters.AllowClassifierData Then
		// Picking from classifier is disabled. It is the default behavior.
		Return;
	EndIf;
	
	ContactInformationManagementInternalServerCall.ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
EndProcedure

#EndRegion

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Gets country data from the countries catalog or from the country classifier.
// It is recommended that you use ContactInformationManagement.WorldCountryData.
//
// Parameters:
//    CountryCode - String, Number - an ARCC country code. If not specified, search by code is not performed.
//    Description - String        - a country description. If not specified, search by description is not performed.
//
// Returns:
//    Structure - the following fields:
//          * Code                - String - an attribute of the found country.
//          * Description       - String - an attribute of the found country.
//          * DescriptionFull - String - an attribute of the found country.
//          * CodeAlpha2          - String - an attribute of the found country.
//          * CodeAlpha3          - String - an attribute of the found country.
//          * Reference             - CatalogRef.WorldCountries - an attribute of the found country.
//    Undefined - the country is not found.
//
Function WorldCountryData(Val CountryCode = Undefined, Val Description = Undefined) Export
	Return ContactsManager.WorldCountryData(CountryCode, Description);
EndFunction

// Gets country data from the country classifier.
// It is recommended that you use ContactsManager.WorldCountryClassifierDataByCode instead.
//
// Parameters:
//    Code - String, Number - an ARCC country code.
//    CodeType - String - Options: CountryCode (by default), Alpha2, Alpha3.
//
// Returns:
//    Structure - the following fields:
//          * Code                - String - an attribute of the found country.
//          * Description       - String - an attribute of the found country.
//          * DescriptionFull - String - an attribute of the found country.
//          * CodeAlpha2          - String - an attribute of the found country.
//          * CodeAlpha3          - String - an attribute of the found country.
//    Undefined - the country is not found.
//
Function WorldCountryClassifierDataByCode(Val Code, CodeType = "CountryCode") Export
	Return ContactsManager.WorldCountryClassifierDataByCode(Code, CodeType);
EndFunction

// Gets country data from the country classifier.
// It is recommended that you use ContactsManager.WorldCountryClassifierDataByDescription instead.
//
// Parameters:
//    Description - String - a country description.
//
// Returns:
//    Structure - the following fields:
//          * Code                - String - an attribute of the found country.
//          * Description       - String - an attribute of the found country.
//          * DescriptionFull - String - an attribute of the found country.
//          * CodeAlpha2          - String - an attribute of the found country.
//          * CodeAlpha3          - String - an attribute of the found country.
//    Undefined - the country is not found.
//
Function WorldCountryClassifierDataByDescription(Val Description) Export
	Return ContactsManager.WorldCountryClassifierDataByDescription(Description);
EndFunction

#EndRegion

#Region Private

Procedure OnSetUpInitialItemsFilling(Settings) Export
	
	Settings.OnInitialItemFilling = False;
	
EndProcedure

// Called upon initial filling of the CountriesOfWorld catalog.
//
// Parameters:
//  LanguageCodes - Array - a list of configuration languages. Applicable to multilanguage configurations.
//  Items   - ValueTable - the source data. Column content matches the attribute set of the 
//                                 CountriesOfWorld catalog.
//
Procedure OnInitialItemsFilling(LanguagesCodes, Items) Export
	
	Item = Items.Add();
	Item.PredefinedDataName = "Russia";
	Item.Code				= "643";
	Item.Description		= NStr("ru = 'đáđ×đíđíđśđ»'; en = 'RUSSIA'; pl = 'ROSJA';es_ES = 'RUSIA';es_CO = 'RUSIA';tr = 'RUSYA';it = 'Russia';de = 'RUSSLAND'", CommonClientServer.DefaultLanguageCode());
	Item.DescriptionFull	= NStr("ru = 'đáđżĐüĐüđŞđ╣Đüđ║đ░ĐĆ đĄđÁđ┤đÁĐÇđ░ĐćđŞĐĆ'; en = 'Russian Federation'; pl = 'Federacja Rosyjska';es_ES = 'Federaci├│n de Rusia';es_CO = 'Federaci├│n de Rusia';tr = 'Rusya Federasyonu';it = 'Federazione Russa';de = 'RUSSISCHE F├ľDERATION'", CommonClientServer.DefaultLanguageCode());
	Item.CodeAlpha2			= "RU";
	Item.CodeAlpha3			= "RUS";
	Item.EEUMember			= True;
	
EndProcedure

#Region InfobaseUpdate

// Registers world countries for processing.
//
Procedure FillCountriesListToProcess(Parameters) Export
	
	ARCCValues = ContactsManager.EEUMemberCountries();
	
	NewRow                    = ARCCValues.Add();
	NewRow.Code                = "203";
	NewRow.Description       = NStr("ru='đžđĽđĘđíđÜđÉđ» đáđĽđíđčđúđĹđŤđśđÜđÉ'; en = 'CZECH REPUBLIC'; pl = 'REPUBLIKA CZESKA';es_ES = 'REP├ÜBLICA CHECA';es_CO = 'REP├ÜBLICA CHECA';tr = '├çEK CUMHUR─░YET─░';it = 'REPUBBLICA CECA';de = 'TSCHECHISCHE REPUBLIK'");
	NewRow.CodeAlpha2          = "CZ";
	NewRow.CodeAlpha3          = "CZE";
	
	NewRow                    = ARCCValues.Add();
	NewRow.Code                = "270";
	NewRow.Description       = NStr("ru='đôđÉđťđĹđśđ»'; en = 'GAMBIA'; pl = 'GAMBIA';es_ES = 'GAMBIA';es_CO = 'GAMBIA';tr = 'GAMB─░YA';it = 'GAMBIA';de = 'GAMBIA'");
	NewRow.CodeAlpha2          = "GM";
	NewRow.CodeAlpha3          = "GMB";
	NewRow.DescriptionFull = NStr("ru='đáđÁĐüđ┐Đâđ▒đ╗đŞđ║đ░ đôđ░đ╝đ▒đŞĐĆ'; en = 'Republic of the Gambia'; pl = 'Republika Gambia';es_ES = 'Rep├║blica de Gambia';es_CO = 'Rep├║blica de Gambia';tr = 'Gambiya Cumhuriyeti';it = 'Repubblica del Gambia';de = 'Republik Gambia'");
	
	Query = New Query;
	Query.Text = "SELECT
		|	CountryList.Code AS Code,
		|	CountryList.Description AS Description,
		|	CountryList.CodeAlpha2 AS CodeAlpha2,
		|	CountryList.CodeAlpha3 AS CodeAlpha3,
		|	CountryList.DescriptionFull AS DescriptionFull
		|INTO CountryList
		|FROM
		|	&CountryList AS CountryList
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	WorldCountries.Ref AS Ref
		|FROM
		|	CountryList AS CountryList
		|		INNER JOIN Catalog.WorldCountries AS WorldCountries
		|		ON (WorldCountries.Code = CountryList.Code)
		|			AND (WorldCountries.Description = CountryList.Description)
		|			AND (WorldCountries.CodeAlpha2 = CountryList.CodeAlpha2)
		|			AND (WorldCountries.CodeAlpha3 = CountryList.CodeAlpha3)
		|			AND (WorldCountries.DescriptionFull = CountryList.DescriptionFull)";
	
	Query.SetParameter("CountryList", ARCCValues);
	QueryResult = Query.Execute().Unload();
	CountriesToProcess = QueryResult.UnloadColumn("Ref");
	
	InfobaseUpdate.MarkForProcessing(Parameters, CountriesToProcess);
	
EndProcedure

Procedure UpdateWorldCountriesByCountryClassifier(Parameters) Export
	
	WorldCountryRef = InfobaseUpdate.SelectRefsToProcess(Parameters.PositionInQueue, "Catalog.WorldCountries");
	
	ObjectsWithIssuesCount = 0;
	ObjectsProcessed = 0;
	
	While WorldCountryRef.Next() Do
		Try
			
			ARCCData = ContactsManager.WorldCountryClassifierDataByCode(WorldCountryRef.Ref.Code);
			
			If ARCCData <> Undefined Then
				WorldCountry = WorldCountryRef.Ref.GetObject();
				FillPropertyValues(WorldCountry, ARCCData);
				InfobaseUpdate.WriteData(WorldCountry);
			EndIf;
			
			ObjectsProcessed = ObjectsProcessed + 1;
			
		Except
			// If you cannot process a world country, try again.
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'đŁđÁ Đâđ┤đ░đ╗đżĐüĐî đżđ▒ĐÇđ░đ▒đżĐéđ░ĐéĐî ĐüĐéĐÇđ░đŻĐâ: %1 đ┐đż đ┐ĐÇđŞĐçđŞđŻđÁ: %2'; en = 'Cannot process country: %1 due to: %2'; pl = 'Nie uda┼éo si─Ö przetworzy─ç kraju: %1 z powodu: %2';es_ES = 'No se ha podido procesar el pa├şs %1 debido a: %2';es_CO = 'No se ha podido procesar el pa├şs %1 debido a: %2';tr = '├ťlke i┼členemedi: %1 nedeni: %2';it = 'Impossibile elaborare la nazione: %1 a causa di: %2';de = 'Das Land konnte nicht bearbeitet werden: %1 aus folgendem Grund: %2'"),
					WorldCountryRef.Ref, DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Warning,
				Metadata.Catalogs.WorldCountries, WorldCountryRef.Ref, MessageText);
		EndTry;
	EndDo;
	
	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.PositionInQueue, "Catalog.WorldCountries");
	
	If ObjectsProcessed = 0 AND ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'đčĐÇđżĐćđÁđ┤ĐâĐÇđÁ UpdateCountriesByClassifier đŻđÁ Đâđ┤đ░đ╗đżĐüĐî đżđ▒ĐÇđ░đ▒đżĐéđ░ĐéĐî đŻđÁđ║đżĐéđżĐÇĐőđÁ ĐüĐéĐÇđ░đŻĐő đ╝đŞĐÇđ░(đ┐ĐÇđżđ┐ĐâĐëđÁđŻĐő): %1'; en = 'The UpdateCountriesByClassifier procedure cannot process some countries (skipped): %1.'; pl = 'Procedurze UpdateCountriesByClassifier nie uda┼éo si─Ö przetworzy─ç niekt├│rych pa┼ästw ┼Ťwiata (pomini─Öte): %1';es_ES = 'El procedimiento UpdateCountriesByClassifier no ha podido procesar algunos pa├şses del mundo(saltados): %1';es_CO = 'El procedimiento UpdateCountriesByClassifier no ha podido procesar algunos pa├şses del mundo(saltados): %1';tr = 'UpdateCountriesByClassifier prosed├╝r├╝ baz─▒ ├╝lkeleri i┼čleyemedi (atland─▒): %1.';it = 'La procedura UpdateCountriesByClassifier non pu├▓ elaborare alcuni paesi (saltati): %1.';de = 'Das Verfahren UpdateCountriesByClassifier konnte f├╝r einige L├Ąnder der Welt nicht durchgef├╝hrt werden (weggelassen): %1.'"), 
				ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			Metadata.Catalogs.WorldCountries,,
				StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'đčĐÇđżĐćđÁđ┤ĐâĐÇđ░ UpdateCountriesByClassifier đżđ▒ĐÇđ░đ▒đżĐéđ░đ╗đ░ đżĐçđÁĐÇđÁđ┤đŻĐâĐÄ đ┐đżĐÇĐćđŞĐÄ ĐüĐéĐÇđ░đŻ đ╝đŞĐÇđ░: %1'; en = 'The UpdateCountriesByClassifier procedure has processed countries: %1.'; pl = 'Procedura UpdateCountriesByClassifier przetworzy┼éa kolejn─ů parti─Ö pa┼ästw ┼Ťwiata: %1';es_ES = 'El procedimiento UpdateCountriesByClassifier ha procesado unos pa├şses del mundo: %1';es_CO = 'El procedimiento UpdateCountriesByClassifier ha procesado unos pa├şses del mundo: %1';tr = 'UpdateCountriesByClassifier prosed├╝r├╝ ├╝lkeleri i┼čledi: %1.';it = 'La procedura UpdateCountriesByClassifier ha elaborato i paesi: %1.';de = 'Das Verfahren UpdateCountriesByClassifier hat eine weitere Reihe von L├Ąndern der Welt bearbeitet: %1.'"),
					ObjectsProcessed));
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf

