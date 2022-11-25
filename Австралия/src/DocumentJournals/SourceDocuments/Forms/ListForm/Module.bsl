
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetListSettings();
	Types = AccountingApprovalServer.GetDocumentTypes();

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterCompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
EndProcedure

&AtClient
Procedure FilterAdjustedManuallyStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	ChoiceData = New ValueList;
	ChoiceData.Add(True);
	ChoiceData.Add(False);	
	
EndProcedure

&AtClient
Procedure FilterAdjustedManuallyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(
		List,
		"AdjustedManually",
		FilterAdjustedManually,
		FilterAdjustedManually <> Undefined);
	
EndProcedure

&AtClient
Procedure FilterPeriodOnChange(Item)
	
	Filter = List.Filter;
	CommonClientServer.DeleteFilterItems(Filter, "Date"); 
	
	If ValueIsFilled(FilterPeriod.StartDate) Then
	
		CommonClientServer.AddCompositionItem(
			Filter,
			"Date",
			DataCompositionComparisonType.GreaterOrEqual,
			FilterPeriod.StartDate,
			,
			ValueIsFilled(FilterPeriod.StartDate));
			
	EndIf;
	
	If ValueIsFilled(FilterPeriod.EndDate) Then
		
		CommonClientServer.AddCompositionItem(
			Filter,
			"Date",
			DataCompositionComparisonType.LessOrEqual,
			FilterPeriod.EndDate,
			,
			ValueIsFilled(FilterPeriod.EndDate));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FilterStatusOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Status", FilterStatus, ValueIsFilled(FilterStatus));
	
EndProcedure

&AtClient
Procedure FilterDocumentTypeStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	NotifyDescription = New NotifyDescription("TypesStartChoiceEnd", ThisObject); 
	
	FormParameters = New Structure("ValueList", Types);
	FormParameters.Insert("Title", NStr("en = 'Select document types'; ru = 'Выбор типов документов';pl = 'Wybierz typy dokumentów';es_ES = 'Seleccionar los tipos de documento';es_CO = 'Seleccionar los tipos de documento';tr = 'Belge türlerini seç';it = 'Selezionare i tipi di documento';de = 'Dokumententypen auswählen'"));
	
	OpenForm("CommonForm.SelectValueListItems",
		FormParameters, Item, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow); 
	
EndProcedure

&AtClient
Procedure FilterDocumentTypeClearing(Item, StandardProcessing)
	
	Types.FillChecks(True);
	SetDocumentTypesFilter();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtServerNoContext
Procedure ListOnGetDataAtServer(ItemName, Settings, Rows)
	AccountingApprovalServer.DocumentListOnGetDataAtServer(Rows, Undefined, Undefined, True);
EndProcedure

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name <> "HasFiles"
		Or Not Items.List.CurrentData.HasFiles Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("FileOwner",	SelectedRow);

	OpenForm("DataProcessor.FilesOperations.Form.AttachedFiles",
		FormParameters,
		ThisObject,
		True);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetListSettings()

	Fields = New Array;
	Fields.Add("HasFiles");
	
	List.SetRestrictionsForUseInFilter(Fields);
	List.SetRestrictionsForUseInGroup(Fields);
	List.SetRestrictionsForUseInOrder(Fields);

EndProcedure

&AtClient
Procedure SetDocumentTypesFilter()
	
	ParameterArray = New Array;
	
	For Each DocumentType In Types Do
		
		If DocumentType.Check Then
			ParameterArray.Add(DocumentType.Value);	
		EndIf;
		
	EndDo;
	
	DriveClientServer.SetListFilterItem(
		List,
		"Type",
		ParameterArray,
		,
		DataCompositionComparisonType.InList);
		
EndProcedure
	
&AtClient
Procedure TypesStartChoiceEnd(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	Types = Result;
	SetDocumentTypesFilter();

EndProcedure

#EndRegion
