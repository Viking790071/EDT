#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Parameters.DataProcessorsKind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalDataProcessor Then
		Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Мои дополнительные обработки (%1)'; en = 'My additional data processors (%1)'; pl = 'Moje dodatkowe procedury przetwarzania (%1)';es_ES = 'Mis procesamientos adicionales (%1)';es_CO = 'Mis procesamientos adicionales (%1)';tr = 'Ek veri işlemcilerim (%1)';it = 'I miei elaboratori dati aggiuntivi (%1)';de = 'Meine zusätzlichen Bearbeitungen (%1)'"), 
			AdditionalReportsAndDataProcessors.SectionPresentation(Parameters.SectionRef));
	ElsIf Parameters.DataProcessorsKind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Мои дополнительные отчеты (%1)'; en = 'My additional reports (%1)'; pl = 'Moje sprawozdania dodatkowe (%1)';es_ES = 'Mis informes adicionales (%1)';es_CO = 'Mis informes adicionales (%1)';tr = 'Ek raporlarım (%1)';it = 'I miei report aggiuntivi (%1)';de = 'Meine zusätzlichen Berichte (%1)'"), 
			AdditionalReportsAndDataProcessors.SectionPresentation(Parameters.SectionRef));
	EndIf;
	
	CommandTypes = New Array;
	CommandTypes.Add(Enums.AdditionalDataProcessorsCallMethods.ClientMethodCall);
	CommandTypes.Add(Enums.AdditionalDataProcessorsCallMethods.ServerMethodCall);
	CommandTypes.Add(Enums.AdditionalDataProcessorsCallMethods.OpeningForm);
	CommandTypes.Add(Enums.AdditionalDataProcessorsCallMethods.ScenarioInSafeMode);
	
	Query = AdditionalReportsAndDataProcessors.NewQueryByAvailableCommands(Parameters.DataProcessorsKind, Parameters.SectionRef, , CommandTypes, False);
	ResultTable = Query.Execute().Unload();
	UsedCommands.Load(ResultTable);
	
	If CommonClientServer.IsMobileClient() Then
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ClearAll(Command)
	For Each TableRow In UsedCommands Do
		TableRow.Use = False;
	EndDo;
EndProcedure

&AtClient
Procedure SelectAll(Command)
	For Each TableRow In UsedCommands Do
		TableRow.Use = True;
	EndDo;
EndProcedure

&AtClient
Procedure OK(Command)
	WriteUserDataProcessorSet();
	NotifyChoice("MyReportsAndDataProcessorsSetupDone");
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure WriteUserDataProcessorSet()
	Table = UsedCommands.Unload();
	Table.Columns.Ref.Name        = "AdditionalReportOrDataProcessor";
	Table.Columns.ID.Name = "CommandID";
	Table.Columns.Use.Name = "Available";
	MeasurementsValues = New Structure("User", UsersClientServer.AuthorizedUser());
	ResourcesValues  = New Structure;
	SetPrivilegedMode(True);
	InformationRegisters.DataProcessorAccessUserSettings.WriteSettingsPackage(Table, MeasurementsValues, ResourcesValues, False);
EndProcedure

#EndRegion
