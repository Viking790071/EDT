#Region Internal

// Returns the template of a security profile name for external module.
// The function should return the same value every time it is called.
//
// Parameters:
//  ExternalModule - AnyRef, a reference to an external module.
//
// Return value - String - template of a security profile name containing characters
//  "%1". These characters are replaced with a unique ID later.
//
Function SecurityProfileNamePattern(Val ExternalModule) Export
	
	Kind = Common.ObjectAttributeValue(ExternalModule, "Kind");
	If Kind = Enums.AdditionalReportsAndDataProcessorsKinds.Report Or Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		
		Return "AdditionalReport_%1"; // Do not localize.
		
	Else
		
		Return "AdditionalDataProcessor_%1"; // Do not localize.
		
	EndIf;
	
EndFunction

// Returns an external module icon.
//
//  ExternalModule - AnyRef, a reference to an external module.
//
// Return value - an icon.
//
Function ExternalModuleIcon(Val ExternalModule) Export
	
	Kind = Common.ObjectAttributeValue(ExternalModule, "Kind");
	If Kind = Enums.AdditionalReportsAndDataProcessorsKinds.Report Or Kind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		
		Return PictureLib.Report;
		
	Else
		
		Return PictureLib.DataProcessor;
		
	EndIf;
	
EndFunction

// Returns dictionary of presentations for external container modules.
//
// Returns - Structure:
//  * Nominative - String, external module type presentation in nominative case.
//  * Genitive - String, external module type presentation in genitive case.
//
Function ExternalModuleContainerDictionary() Export
	
	Result = New Structure();
	
	Result.Insert("NominativeCase", NStr("ru = 'Дополнительный отчет или обработка'; en = 'Additional report or data processor'; pl = 'Dodatkowy raport lub procesor danych';es_ES = 'Informe adicional o procesador de datos';es_CO = 'Informe adicional o procesador de datos';tr = 'Ek rapor veya veri işlemcisi';it = 'Ulteriore report o processore dati';de = 'Zusätzlicher Bericht oder Datenverarbeiter'"));
	Result.Insert("Genitive", NStr("ru = 'Дополнительного отчета или обработки'; en = 'Additional report of data processor'; pl = 'Dodatkowe raporty procesora danych';es_ES = 'Informe adicional del procesador de datos';es_CO = 'Informe adicional del procesador de datos';tr = 'Ek rapor veya veri işlemcisi';it = 'Ulteriore report o processore dati';de = 'Zusätzlicher Bericht des Datenverarbeiters'"));
	
	Return Result;
	
EndFunction

// Returns array of reference metadata objects that can be used as external module containers.
//  
//
// Return value - Array (MetadataObject).
//
Function ExternalModuleContainers() Export
	
	Result = New Array();
	Result.Add(Metadata.Catalogs.AdditionalReportsAndDataProcessors);
	Return Result;
	
EndFunction

Function AdditionalDataProcessorsPermissionRequests(Val FOValue = Undefined) Export
	
	If FOValue = Undefined Then
		FOValue = GetFunctionalOption("UseAdditionalReportsAndDataProcessors");
	EndIf;
	
	Result = New Array();
	
	QueryText =
		"SELECT DISTINCT
		|	AdditionalReportAndDataProcessorPermissions.Ref AS Ref
		|FROM
		|	Catalog.AdditionalReportsAndDataProcessors.Permissions AS AdditionalReportAndDataProcessorPermissions
		|WHERE
		|	AdditionalReportAndDataProcessorPermissions.Ref.Publication <> &Publication";
	Query = New Query(QueryText);
	Query.SetParameter("Publication", Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		Object = Selection.Ref.GetObject();
		NewRequests = AdditionalDataProcessorPermissionRequests(Object, Object.Permissions.Unload(), FOValue);
		CommonClientServer.SupplementArray(Result, NewRequests);
		
	EndDo;
	
	Return Result;
	
EndFunction

Function AdditionalDataProcessorPermissionRequests(Val Object, Val PermissionsInData, Val FOValue = Undefined, Val DeletionMark = Undefined) Export
	
	PermissionsToRequest = New Array();
	
	If FOValue = Undefined Then
		FOValue = GetFunctionalOption("UseAdditionalReportsAndDataProcessors");
	EndIf;
	
	If DeletionMark = Undefined Then
		DeletionMark = Object.DeletionMark;
	EndIf;
	
	ClearPermissions = False;
	
	If Not FOValue Then
		ClearPermissions = True;
	EndIf;
	
	If Object.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled Then
		ClearPermissions = True;
	EndIf;
	
	If DeletionMark Then
		ClearPermissions = True;
	EndIf;
	
	ModuleSafeModeManagerInternal = Common.CommonModule("SafeModeManagerInternal");
	
	If Not ClearPermissions Then
		
		HadPermissions = ModuleSafeModeManagerInternal.ExternalModuleAttachmentMode(Object.Ref) <> Undefined;
		HasPermissions = Object.Permissions.Count() > 0;
		
		If HadPermissions Or HasPermissions Then
			
			If Object.PermissionCompatibilityMode = Enums.AdditionalReportsAndDataProcessorsPermissionCompatibilityModes.Version_2_2_2 Then
				
				PermissionsToRequest = New Array();
				For Each PermissionInData In PermissionsInData Do
					Permission = XDTOFactory.Create(XDTOFactory.Type(ModuleSafeModeManagerInternal.Package(), PermissionInData.PermissionKind));
					PropertiesInData = PermissionInData.Parameters.Get();
					FillPropertyValues(Permission, PropertiesInData);
					PermissionsToRequest.Add(Permission);
				EndDo;
				
			Else
				
				OldPermissions = New Array();
				For Each PermissionInData In PermissionsInData Do
					Permission = XDTOFactory.Create(XDTOFactory.Type("http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/1.0.0.1", PermissionInData.PermissionKind));
					PropertiesInData = PermissionInData.Parameters.Get();
					FillPropertyValues(Permission, PropertiesInData);
					OldPermissions.Add(Permission);
				EndDo;
				
				PermissionsToRequest = AdditionalReportsAndDataProcessorsSafeModeInterface.ConvertVersion_2_1_3_PermissionsTo_2_2_2_VersionPermissions(Object, OldPermissions);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return ModuleSafeModeManagerInternal.PermissionRequestForExternalModule(Object.Ref, PermissionsToRequest);
	
EndFunction

// For internal use only.
Function GenerateSafeModeExtensionSessionKey(Val DataProcessor) Export
	
	Return DataProcessor.UUID();
	
EndFunction

// For internal use only.
Procedure ExecuteSafeModeScenario(Val SessionKey, Val Scenario, Val ExecutableObject, ExecutionParameters, ParametersToSave = Undefined, RelatedObjects = Undefined) Export
	
	Exceptions = AdditionalReportsAndDataProcessorsSafeModeCached.GetAllowedMethods();
	
	If ParametersToSave = Undefined Then
		ParametersToSave = New Structure();
	EndIf;
	
	For Each ScenarioStep In Scenario Do
		
		PerformSafely = True;
		ExecutableVolume = "";
		
		If ScenarioStep.ActionKind = AdditionalReportsAndDataProcessorsSafeModeInterface.DataProcessorMethodCallActionKind() Then
			
			ExecutableVolume = "ExecutableObject." + ScenarioStep.MethodName;
			
		ElsIf ScenarioStep.ActionKind = AdditionalReportsAndDataProcessorsSafeModeInterface.ConfigurationMethodCallActionKind() Then
			
			ExecutableVolume = ScenarioStep.MethodName;
			
			If Exceptions.Find(ScenarioStep.MethodName) <> Undefined Then
				PerformSafely = False;
			EndIf;
			
		Else
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Неизвестный тип действия для этапа сценария: %1'; en = 'Unknown action type for the current scenario step: %1'; pl = 'Nieznany rodzaj czynności dla etapu scenariusza: %1';es_ES = 'Tipo de acción desconocido para la fase del script: %1';es_CO = 'Tipo de acción desconocido para la fase del script: %1';tr = 'Komut dosyası için bilinmeyen eylem türü:%1';it = 'Tipo di azione sconosciuto per il passaggio dello scenario corrente: %1';de = 'Unbekannte Aktionsart für Scriptstufe: %1'"), ScenarioStep.ActionKind);
			
		EndIf;
		
		ParametersNotToSave = New Array();
		
		ParameterSubstring = "";
		
		MethodParameters = ScenarioStep.Parameters;
		For Each MethodParameter In MethodParameters Do
			
			If Not IsBlankString(ParameterSubstring) Then
				ParameterSubstring = ParameterSubstring + ", ";
			EndIf;
			
			If MethodParameter.Kind = AdditionalReportsAndDataProcessorsSafeModeInterface.ValuePropertyKind() Then
				
				ParametersNotToSave.Add(MethodParameter.Value);
				ParameterSubstring = ParameterSubstring
					+ "ParametersNotToSave.Get("
					+ ParametersNotToSave.UBound()
					+ ")";
				
			ElsIf MethodParameter.Kind = AdditionalReportsAndDataProcessorsSafeModeInterface.SessionKeyParameterKind() Then
				
				ParameterSubstring = ParameterSubstring + "SessionKey";
				
			ElsIf MethodParameter.Kind = AdditionalReportsAndDataProcessorsSafeModeInterface.ValueToSaveCollectionParameterKind() Then
				
				ParameterSubstring = ParameterSubstring + "ParametersToSave";
				
			ElsIf MethodParameter.Kind = AdditionalReportsAndDataProcessorsSafeModeInterface.ValueToSaveParameterKind() Then
				
				ParameterSubstring = ParameterSubstring + "ParametersToSave." + MethodParameter.Value;
				
			ElsIf MethodParameter.Kind = AdditionalReportsAndDataProcessorsSafeModeInterface.ParameterKindRelatedObjects() Then
				
				ParameterSubstring = ParameterSubstring + "RelatedObjects";
				
			ElsIf MethodParameter.Kind = AdditionalReportsAndDataProcessorsSafeModeInterface.CommandRunParameterParameterKind() Then
				
				ParameterSubstring = ParameterSubstring + "ExecutionParameters." + MethodParameter.Value;
				
			Else
				
				Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Неизвестный параметр для этапа сценария: %1'; en = 'Unknown parameter kind for the current scenario step: %1'; pl = 'Nieznany parametr dla etapu scenariusza: %1';es_ES = 'Parámetro desconocido para la fase del script: %1';es_CO = 'Parámetro desconocido para la fase del script: %1';tr = 'Komut dosyası için bilinmeyen parametre: %1';it = 'Tipo di parametro sconosciuto per il passaggio dello scenario corrente: %1';de = 'Unbekannter Parameter für Skriptstufe: %1'"), MethodParameter.Kind);
				
			EndIf;
			
		EndDo;
		
		ExecutableVolume = ExecutableVolume + "(" + ParameterSubstring + ")";
		
		If PerformSafely <> (SafeMode() <> False) Then
			SetSafeMode(PerformSafely);
		EndIf;
		
		If Not IsBlankString(ScenarioStep.ResultSaving) Then
			Result = Common.CalculateInSafeMode(ExecutableVolume);
			ParametersToSave.Insert(ScenarioStep.ResultSaving, Result);
		Else
			Common.ExecuteInSafeMode(ExecutableVolume);
		EndIf;
		
	EndDo;
	
EndProcedure

// For internal use only.
Function GeneratePermissionPresentation(Val Permissions) Export
	
	PermissionDescriptions = AdditionalReportsAndDataProcessorsSafeModeCached.Dictionary();
	
	Result = "<HTML><BODY bgColor=#fcfaeb>";
	
	For Each Permission In Permissions Do
		
		PermissionKind = Permission.PermissionKind;
		
		PermissionDetails = PermissionDescriptions.Get(
			XDTOFactory.Type(
				AdditionalReportsAndDataProcessorsSafeModeInterface.Package(),
				PermissionKind));
		
		PermissionPresentation = PermissionDetails.Presentation;
		
		ParameterPresentations = "";
		Parameters = Permission.Parameters.Get();
		
		If Parameters <> Undefined Then
			
			For Each Parameter In Parameters Do
				
				If Not IsBlankString(ParameterPresentations) Then
					ParameterPresentations = ParameterPresentations + ", ";
				EndIf;
				
				ParameterPresentations = ParameterPresentations + String(Parameter.Value);
				
			EndDo;
			
		EndIf;
		
		If Not IsBlankString(ParameterPresentations) Then
			PermissionPresentation = PermissionPresentation + " (" + ParameterPresentations + ")";
		EndIf;
		
		Result = Result + StringFunctionsClientServer.SubstituteParametersToString(
			"<LI><FONT size=2>%1 <A href=""%2"">%3</A></FONT>",
			PermissionPresentation,
			"internal:" + PermissionKind,
			NStr("ru = 'Подробнее...'; en = 'Details...'; pl = 'Więcej…';es_ES = 'Más...';es_CO = 'Más...';tr = 'Daha fazla...';it = 'Dettagli...';de = 'Details...'"));
		
	EndDo;
	
	Result = Result + "</LI></BODY></HTML>";
	
	Return Result;
	
EndFunction

// For internal use only.
Function GenerateDetailedPermissionDetails(Val PermissionKind, Val PermissionParameters) Export
	
	PermissionDescriptions = AdditionalReportsAndDataProcessorsSafeModeCached.Dictionary();
	
	Result = "<HTML><BODY bgColor=#fcfaeb>";
	
	PermissionDetails = PermissionDescriptions.Get(
		XDTOFactory.Type(
			AdditionalReportsAndDataProcessorsSafeModeInterface.Package(),
			PermissionKind));
	
	PermissionPresentation = PermissionDetails.Presentation;
	PermissionDetailed = PermissionDetails.Details;
	
	ParameterDescriptions = Undefined;
	HasParameters = PermissionDetails.Property("Parameters", ParameterDescriptions);
	
	Result = Result + "<P><FONT size=2><A href=""internal:home"">&lt;&lt; Back lot list permissions</A></FONT></P>";
	
	Result = Result + StringFunctionsClientServer.SubstituteParametersToString(
		"<P><STRONG><FONT size=4>%1</FONT></STRONG></P>",
		PermissionPresentation);
	
	Result = Result + StringFunctionsClientServer.SubstituteParametersToString(
		"<P><FONT size=2>%1%2</FONT></P>", PermissionDetailed, ?(
			HasParameters,
			" " + NStr("ru = 'со следующими ограничениями'; en = 'with the following restrictions'; pl = 'z następującymi ograniczeniami';es_ES = 'con las siguientes restricciones';es_CO = 'con las siguientes restricciones';tr = 'aşağıdaki kısıtlamalar ile:';it = 'Con le seguenti restrizioni';de = 'mit folgenden Einschränkungen'") + ":",
			"."));
	
	If HasParameters Then
		
		Result = Result + "<UL>";
		
		For Each Parameter In ParameterDescriptions Do
			
			ParameterName = Parameter.Name;
			ParameterValue = PermissionParameters[ParameterName];
			
			If ValueIsFilled(ParameterValue) Then
				
				ParameterDetails = StringFunctionsClientServer.SubstituteParametersToString(Parameter.Details, ParameterValue);
				
			Else
				
				ParameterDetails = StringFunctionsClientServer.SubstituteParametersToString("<B>%1</B>", Parameter.AnyValueDetails);
				
			EndIf;
			
			Result = Result + StringFunctionsClientServer.SubstituteParametersToString("<LI><FONT size=2>%1</FONT>", ParameterDetails);
			
		EndDo;
		
		Result = Result + "</LI></UL>";
		
	EndIf;
	
	ConsequenceDescriptions = "";
	If PermissionDetails.Property("Consequences", ConsequenceDescriptions) Then
		
		Result = Result + StringFunctionsClientServer.SubstituteParametersToString(
			"<P><FONT size=2><EM>%1</EM></FONT></P>",
			ConsequenceDescriptions);
		
	EndIf;
	
	Result = Result + "<P><FONT size=2><A href=""internal:home"">&lt;&lt; Back lot list permissions</A></FONT></P>";
	
	Result = Result + "</BODY></HTML>";
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See SubsystemIntegrationSSL.ExternalModuleManagersOnRegistration. 
Procedure OnRegisterExternalModulesManagers(Managers) Export
	
	Managers.Add(AdditionalReportsAndDataProcessorsSafeModeInternal);
	
EndProcedure

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources. 
Procedure OnFillPermissionsToAccessExternalResources(PermissionRequests) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	NewRequests = AdditionalDataProcessorsPermissionRequests();
	CommonClientServer.SupplementArray(PermissionRequests, NewRequests);
	
EndProcedure

#EndRegion
