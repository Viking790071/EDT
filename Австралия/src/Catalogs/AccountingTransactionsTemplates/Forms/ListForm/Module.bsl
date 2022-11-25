#Region FormEventHandlers

&AtClient
Procedure OnOpen(Cancel)
	
	SetFormsElementsEnable();
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
	HasRoleUseChangeStatusTool = Users.IsFullUser() Or AccessManagement.HasRole("UseChangeStatusTool");
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterCompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
EndProcedure

&AtClient
Procedure FilterTypeOfAccountingOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "TypeOfAccounting", FilterTypeOfAccounting, ValueIsFilled(FilterTypeOfAccounting));
	
EndProcedure

&AtClient
Procedure FilterChartOfAccountsOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "ChartOfAccounts", FilterChartOfAccounts, ValueIsFilled(FilterChartOfAccounts));
	
EndProcedure

&AtClient
Procedure FilterStatusOnChange(Item)
	
	SetStatusDateFilter();
	
EndProcedure

&AtClient
Procedure FilterDateOnChange(Item)
	
	SetStatusDateFilter();
	
EndProcedure

&AtClient
Procedure FilterDocumentTypeStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
		
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("ChartOfAccounts" 	, FilterChartOfAccounts);
	ChoiceFormParameters.Insert("FillDocumentType"	, True);
	ChoiceFormParameters.Insert("CurrentValue"		, FilterDocumentType);
	ChoiceFormParameters.Insert("AttributeName"   	, NStr("en = 'document type'; ru = 'тип документа';pl = 'typ dokumentu';es_ES = 'tipo de documento';es_CO = 'tipo de documento';tr = 'belge türü';it = 'tipo di documento';de = 'Dokumententyp'"));
	ChoiceFormParameters.Insert("AttributeID"   	, "DocumentType");
	
	ChoiceNotification = New NotifyDescription("DocumentTypeChoiceEnding", ThisObject);
	
	OpenForm("CommonForm.ArbitraryParametersChoiceForm", ChoiceFormParameters, ThisObject, , , , ChoiceNotification, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure FilterDocumentTypeClearing(Item, StandardProcessing)
	
	FilterDocumentTypeSynonym = Undefined;
	FilterDocumentType  	  = Undefined;

EndProcedure

&AtClient
Procedure DocumentTypeChoiceEnding(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) <> Type("Structure") Then
		Return;
	EndIf;

	FilterDocumentTypeSynonym 	= ClosingResult.Synonym;
	FilterDocumentType  		= ClosingResult.Field;
	
	DriveClientServer.SetListFilterItem(List, "DocumentType", FilterDocumentType, ValueIsFilled(FilterDocumentType));	
	DriveClientServer.SetListFilterItem(List, "DocumentTypeSynonym", FilterDocumentTypeSynonym, ValueIsFilled(FilterDocumentType));	
	
EndProcedure

&AtClient
Procedure FilterDocumentTypeOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "DocumentTypeSynonym", FilterDocumentTypeSynonym, ValueIsFilled(FilterDocumentType));	
	DriveClientServer.SetListFilterItem(List, "DocumentType", FilterDocumentType, ValueIsFilled(FilterDocumentType));	
EndProcedure

&AtClient
Procedure FilterStatusClearing(Item, StandardProcessing)
	
	FilterDate = Undefined;	
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SetStatusActive(Command)
			
	SelectedRows = Items.List.SelectedRows;
	
	If SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	OpenSetStatusTool(SelectedRows, "Active");
	
EndProcedure

&AtClient
Procedure SetStatusDraft(Command)
	
	SelectedRows = Items.List.SelectedRows;
	
	If SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	OpenSetStatusTool(SelectedRows, "Draft");
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SetFormsElementsEnable()
	
	Items.ActionsGroup.Visible = HasRoleUseChangeStatusTool;
	
	If ValueIsFilled(FilterStatus) Then		
		Items.FilterDate.Enabled = True;		
	Else 		
		Items.FilterDate.Enabled = False;
		FilterDate = Undefined;
	EndIf;

EndProcedure

&AtClient
Procedure OpenSetStatusTool(SelectedRows, NewStatus)

	StatusToolParameters = New Structure;
	StatusToolParameters.Insert("Status"			, NewStatus);
	StatusToolParameters.Insert("DateFrom"			, FilterDate);
	StatusToolParameters.Insert("SelectedElements"	, SelectedRows);
	
	OpenForm("Catalog.AccountingEntriesTemplates.Form.SetStatusForm",
		StatusToolParameters,
		ThisObject,
		,
		,
		,
		New NotifyDescription("StatusSetEnding", ThisObject),
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure StatusSetEnding(SelectedValue, AdditionalParameters) Export
	
	Items.List.Refresh();
	RefreshDataRepresentation(Items.List);
	
EndProcedure

&AtServerNoContext
Function GetTemplatesByPeriod(FilterDate, FilterStatus)

	Return InformationRegisters.AccountingEntriesTemplatesStatuses.GetTemplatesArrayByFilters(FilterDate, FilterStatus);

EndFunction

&AtClient
Procedure SetStatusDateFilter()

	If Not ValueIsFilled(FilterDate) Then
		
		DriveClientServer.SetListFilterItem(List, "Status", FilterStatus, ValueIsFilled(FilterStatus));
		DriveClientServer.SetListFilterItem(List, "Ref"   , New Array   , False);
		
	ElsIf ValueIsFilled(FilterStatus) Then	

		TemplatesRefsArray = GetTemplatesByPeriod(FilterDate, FilterStatus);
		
		DriveClientServer.SetListFilterItem(List, "Ref", TemplatesRefsArray, True, DataCompositionComparisonType.InList);
		DriveClientServer.SetListFilterItem(List, "Status", FilterStatus, False);
	
	EndIf;
	
	SetFormsElementsEnable();	

EndProcedure

#EndRegion