///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("Representation") Then
		Items.List.Representation = TableRepresentation[Parameters.Representation];
	EndIf;
	
	ErrorTextOnOpen = ReportMailing.CheckAddRightErrorText();
	If ValueIsFilled(ErrorTextOnOpen) Then
		Raise ErrorTextOnOpen;
	EndIf;
	
	// Set dynamic list filters.
	CommonClientServer.SetDynamicListFilterItem(
		List, "ExecuteOnSchedule", False,
		DataCompositionComparisonType.Equal, , False,
		DataCompositionSettingsItemViewMode.Normal);
	
	CommonClientServer.SetDynamicListFilterItem(
		List, "SchedulePeriodicity", ,
		DataCompositionComparisonType.Equal, , False,
		DataCompositionSettingsItemViewMode.Normal);
	
	CommonClientServer.SetDynamicListFilterItem(
		List, "Prepared", False,
		DataCompositionComparisonType.Equal, , False,
		DataCompositionSettingsItemViewMode.Normal);
	
	CommonClientServer.SetDynamicListFilterItem(
		List, "Author", ,
		DataCompositionComparisonType.Equal, , False,
		DataCompositionSettingsItemViewMode.Normal);
	
	FillListParameter("ChoiceMode");
	FillListParameter("ChoiceFoldersAndItems");
	FillListParameter("MultipleChoice");
	FillListParameter("CurrentRow");
	
	If Not AccessRight("Update", Metadata.Catalogs.ReportMailings) Then
		// Show only personal mailing. Groups and excess columns are hidden.
		Items.List.Representation = TableRepresentation.List;
		CommonClientServer.SetDynamicListFilterItem(List, "IsFolder", False, , , True,
			DataCompositionSettingsItemViewMode.Inaccessible);
	EndIf;
	
	ReportFilter = Parameters.Report;
	SetFilter(False);

	List.Parameters.SetParameterValue("EmptyDate", '00010101');
	List.Parameters.SetParameterValue("NewStatePresentation", NStr("ru = 'Новая'; en = 'New'; pl = 'Nowy';es_ES = 'Nuevo';es_CO = 'Nuevo';tr = 'Yeni';it = 'Nuovo';de = 'Neu'"));
	List.Parameters.SetParameterValue("NotCompletedStatePresentation", NStr("ru = 'Не завершена'; en = 'Not completed'; pl = 'Nie zakończone';es_ES = 'No se ha completado';es_CO = 'No se ha completado';tr = 'Tamamlanmadı';it = 'Non completato';de = 'Nicht abgeschlossen'"));
	List.Parameters.SetParameterValue("CompletedWithErrorsStatePresentation", NStr("ru = 'Выполнена с ошибками'; en = 'Completed with errors'; pl = 'Zakończone z błędami';es_ES = 'Finalizado con errores';es_CO = 'Finalizado con errores';tr = 'Hatalarla tamamlandı';it = 'Completato con errori';de = 'Mit Fehlern abgeschlossen'"));
	List.Parameters.SetParameterValue("CompletedStatePresentation", NStr("ru = 'Завершенные'; en = 'Completed'; pl = 'Zakończono';es_ES = 'Finalizado';es_CO = 'Finalizado';tr = 'Tamamlandı';it = 'Completato';de = 'Abgeschlossen'"));
	
	If Not Common.SubsystemExists("StandardSubsystems.BatchEditObjects")
		Or Not AccessRight("Update", Metadata.Catalogs.ReportMailings) Then
		Items.ChangeSelectedItems.Visible = False;
		Items.ChangeSelectedItemsList.Visible = False;
	EndIf;
	
	If Not AccessRight("EventLog", Metadata) Then
		Items.MailingEvents.Visible = False;
	EndIf;
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	SetListFilter(Settings);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterOnChangeStatus(Item)
	SetFilter();
EndProcedure

&AtClient
Procedure FilterOnChangeReport(Item)
	SetFilter();
EndProcedure

&AtClient
Procedure FilterOnChangeEmployeeResponsible(Item)
	SetFilter();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ChangeSelectedItems(Command)
	ModuleBatchObjectModificationClient = CommonClient.CommonModule("BatchEditObjectsClient");
	ModuleBatchObjectModificationClient.ChangeSelectedItems(Items.List);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	StandardSubsystemsServer.SetDateFieldConditionalAppearance(ThisObject, "List.LastRun", Items.LastRun.Name);
	StandardSubsystemsServer.SetDateFieldConditionalAppearance(ThisObject, "List.SuccessfulStart", Items.SuccessfulStart.Name);

	ConditionalAppearanceItem = List.ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	// Unprepared report mailings
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("IsFolder");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = False;
	DataFilterItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("Prepared");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = False;
	DataFilterItem.Use = True;
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
	AppearanceColorItem.Value = Metadata.StyleItems.InaccessibleCellTextColor.Value;
	AppearanceColorItem.Use = True;
	
EndProcedure

&AtServer
Procedure FillListParameter(varKey)
	If Parameters.Property(varKey) AND ValueIsFilled(Parameters[varKey]) Then
		Items.List[varKey] = Parameters[varKey];
	EndIf;
EndProcedure

&AtServer
Procedure SetFilter(ClearFixedFilters = True)
	
	If ClearFixedFilters Then
		List.Filter.Items.Clear();
	EndIf;
	FilterParameters = New Map();
	FilterParameters.Insert("WithErrors", StateFilter);
	FilterParameters.Insert("Report", ReportFilter);
	FilterParameters.Insert("Author", EmployeeResponsibleFilter);
	SetListFilter(FilterParameters);
EndProcedure

&AtServer
Procedure SetListFilter(FilterParameters)
	
	CommonClientServer.SetDynamicListFilterItem(List, "Author", FilterParameters["Author"],,,
		Not FilterParameters["Author"].IsEmpty());
	CommonClientServer.SetDynamicListFilterItem(List, "WithErrors", FilterParameters["WithErrors"] = "Incomplete",,, 
		FilterParameters["WithErrors"] <> "All" AND ValueIsFilled(FilterParameters["WithErrors"]));
	CommonClientServer.SetDynamicListParameter(List, "ReportFilter", FilterParameters["Report"],
		ValueIsFilled(FilterParameters["Report"]) AND Not FilterParameters["Report"].IsEmpty());
	
EndProcedure

#EndRegion
