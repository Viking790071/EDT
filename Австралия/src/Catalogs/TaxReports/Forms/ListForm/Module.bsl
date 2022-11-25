
#Region FormCommandsEventHandlers

&AtClient
Procedure OpenReport(Command)
	
	If Items.List.CurrentData = Undefined Then
		Return;
	Else
		RefCurrentData = Items.List.CurrentData.Ref;
	EndIf;
	
	ParametersOfDataProcessor = GetParametersOfDataProcessor(RefCurrentData);

	ParametersOfDataProcessor.Insert("ReferenceTaxReport", ParametersOfDataProcessor.Ref); 
	
	Cancel = False;
	
	NameDataProcessor = ConnectExternalDataProcessor(ParametersOfDataProcessor, Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	//GetNameDataProcessor(RefCurrentData);
	
	OpenForm("ExternalDataProcessor." + NameDataProcessor + ".Form",
		ParametersOfDataProcessor,
		ThisObject,
		,,,,
		FormWindowOpeningMode.Independent);
		
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterCompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
EndProcedure


&AtClient
Procedure FilterStatusOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "ReportStatus", FilterStatus, ValueIsFilled(FilterStatus));
	
EndProcedure


&AtClient
Procedure FilterTaxReportTemplateOnChange(Item)
	
	DriveClientServer.SetListFilterItem(
		List, 
		"TaxReportTemplate", 
		FilterTaxReportTemplate, 
		ValueIsFilled(FilterTaxReportTemplate));
	
EndProcedure
	
	
&AtClient
Procedure FilterPeriodOnChange(Item)
	
	DriveClientServer.SetListFilterItem(
		List,
		"BeginOfPeriod",
		FilterPeriod.StartDate,
		ValueIsFilled(FilterPeriod.StartDate),
		DataCompositionComparisonType.GreaterOrEqual);
		
	DriveClientServer.SetListFilterItem(
		List,
		"EndOfPeriod",
		FilterPeriod.EndDate,
		ValueIsFilled(FilterPeriod.EndDate),
		DataCompositionComparisonType.LessOrEqual);	
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function ConnectExternalDataProcessor(ParametersOfDataProcessor, Cancel)
	
	NameDataProcessor = Catalogs.TaxReports.GetExternalDataProcessor(ParametersOfDataProcessor, Cancel);
	
	Return NameDataProcessor;
	
EndFunction

&AtServerNoContext
Function GetParametersOfDataProcessor(RefCurrentData)
	
	Return Common.ObjectAttributesValues(RefCurrentData,
		"Company, BeginOfPeriod, EndOfPeriod, IsFilled, Ref, ReportStatus");
	
EndFunction

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshTaxReportList" Then
		Items.List.Refresh();
	EndIf;
	
EndProcedure

#EndRegion
