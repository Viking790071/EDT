
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	ReportOptionProperties = New Structure("VariantKey, ObjectKey",
		"CounterpartyContactInformation", "Report.CounterpartyContactInformation");
	
	ReportVariantSettingsLinker = DriveReportsServerCall.ReportVariantSettingsLinker(ReportOptionProperties);
	
	ReportVariantUserSettings = ReportVariantSettingsLinker.UserSettings;

	Counterparty = UserCounterparty();
	
	CounterpartyParameter = New DataCompositionParameter("Counterparty");
	
	For Each SettingsRow In ReportVariantUserSettings.Items Do
		
		If SettingsRow.Parameter = CounterpartyParameter Then
			SettingsRow.Use = True;
			SettingsRow.Value = Counterparty;
		EndIf;
		
	EndDo;
	 
	FormParameters = New Structure;
	FormParameters.Insert("UserSettings"					, ReportVariantUserSettings);
	FormParameters.Insert("Filter"							, New Structure("Counterparty", Counterparty));
	FormParameters.Insert("GenerateOnOpen"					, True);
	FormParameters.Insert("ReportOptionsCommandsVisibility"	, False);
		
	OpenForm("Report.CounterpartyContactInformation.Form",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
	
EndProcedure

&AtServer
Function UserCounterparty()
	
	Counterparty = Catalogs.Counterparties.EmptyRef();
	
	User = SessionParameters.CurrentExternalUser;
	
	If ValueIsFilled(User) Then
		
		AuthorizationObject = Common.ObjectAttributeValue(User, "AuthorizationObject");
		
		If TypeOf(AuthorizationObject) = Type("CatalogRef.Counterparties") Then 
			Counterparty = AuthorizationObject;
		ElsIf TypeOf(AuthorizationObject) = Type("CatalogRef.ContactPersons") Then 
			Counterparty = Common.ObjectAttributeValue(AuthorizationObject, "Owner");
		EndIf;
		
	EndIf;
	
	Return Counterparty;
	
EndFunction

#EndRegion