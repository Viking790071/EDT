
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CopyDynamicAttributes(Parameters.CopyingValue);
		
	If Parameters.Property("TabName") Then
		
		EntriesTabSectionName = ?(IsComplexTypeOfEntries, "Entries", "EntriesSimple");
		ThisObject.CurrentItem = Items[EntriesTabSectionName];
		
		Filter = New Structure;
		Filter.Insert("LineNumber", Parameters.LineNumber);
		
		Rows = Object[EntriesTabSectionName].FindRows(Filter);
		
		If Rows.Count() > 0 Then
			Items[Parameters.TabName].CurrentRow = Rows[0].GetID();
		EndIf;
		
	EndIf;

	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);

	If Not ValueIsFilled(Object.Ref) Then
		
		InitParametersFiltersTabSections();
		
		SetComplexTypeOfEntries();
		
		SetRestrictedStatus();
		
		InitSimpleEntries();
		
		InitSynonyms();
		
		SetTSNumberPresentations();
		
		NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
		
	EndIf;
	
	SetEnabledByRight();
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	InitParametersFiltersTabSections();
	
	SetComplexTypeOfEntries();
	
	SetRestrictedStatus();
	
	InitSimpleEntries();
	
	InitSynonyms();
	
	SetTSNumberPresentations();
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
	CurrentPlanStartDate	= Object.PlanStartDate;
	CurrentPlanEndDate		= Object.PlanEndDate;
	CurrentStartDate		= Object.StartDate;
	CurrentEndDate			= Object.EndDate;
	CurrentStatus			= Object.Status;

EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	SerializeParametersConditions(CurrentObject);
	
	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	SetRestrictedStatus();
	InitSimpleEntries();
	InitSynonyms();
	InitParametersFiltersTabSections();
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	SetTSNumberPresentations();
	ShowSaveStatusWarning();
	
	If WriteParameters.Property("OpenTestTemplateForm") Then
		OpenTestTemplateForm();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetStatusPeriodVisibility();
	SetEntriesTabVisibility();
	SetTSNumberPresentations();
	SetMovingButtonsEnabled();

EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "EntiesFiltersEdit"
		And ValueIsFilled(Parameter) 
		// Form owner checkup
		And Source <> New UUID("00000000-0000-0000-0000-000000000000")
		And Source = UUID
		Then
		
		GetEntriesFiltersFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "Catalog.ObjectsPropertiesValues.Form.ListForm" Then
		CurrentData = Items.Parameters.CurrentData;
		If CurrentData = Undefined Then
			Return;
		EndIf;
		
		CurrentData.Value = SelectedValue;
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure StatusOnChange(Item)
	
	SetDates();
	SetStatusPeriodVisibility();
	
	If Not Items.EndDate.Visible Then
		If Not ValueIsFilled(Object.PlanEndDate) And Not ValueIsFilled(Object.PlanStartDate) Then
			Object.PlanEndDate	 = Object.EndDate;
			Object.PlanStartDate = Object.StartDate;
		EndIf;
		Object.EndDate	 = Undefined;
		Object.StartDate = Undefined;
	Else
		If Not ValueIsFilled(Object.EndDate) And Not ValueIsFilled(Object.StartDate) Then
			Object.EndDate		= Object.PlanEndDate;
			Object.StartDate	= Object.PlanStartDate;
		EndIf;
	EndIf;
	
	ShowSaveStatusWarning();
	
	CurrentStatus = Object.Status;
	
EndProcedure

&AtServer
Procedure ShowSaveStatusWarning() 
	
	If Object.Status <> Common.ObjectAttributeValue(Object.Ref, "Status") Then
		Items.WarningSaveStatus.Visible = True;
		TitleTemplate = MessagesToUserClientServer.GetAccountingTransactionsTemplatesChageStateSaveTemplateWarning();
		Items.DecorationStatus.Title = StringFunctionsClientServer.SubstituteParametersToString(TitleTemplate, Object.Status);
	Else
		Items.WarningSaveStatus.Visible = False;
	EndIf;

EndProcedure

&AtClient
Procedure DocumentTypeOnChange(Item)
		
	If CurrentDocumentType <> Object.DocumentType Then
		
		UpdateDescription(CurrentDocumentType, Object.DocumentType);
		CurrentDocumentType = Object.DocumentType;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DocumentTypeStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.ChartOfAccounts) Then
		
		StandardProcessing = False;
		
		MessageText = NStr("en = 'Chart of accounts is required'; ru = 'Укажите план счетов';pl = 'Plan kont jest wymagany';es_ES = 'Se requiere un diagrama de cuentas';es_CO = 'Se requiere un diagrama de cuentas';tr = 'Hesap planı gerekli';it = 'È richiesto il piano dei conti';de = 'Kontoplan ist ein Pflichtfeld'");
		MessageField = "Object.ChartOfAccounts";
		CommonClientServer.MessageToUser(MessageText, , MessageField);
		
		Return;
	EndIf;
	
	StandardProcessing = False;
		
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("ChartOfAccounts"	, Object.ChartOfAccounts);
	ChoiceFormParameters.Insert("FillDocumentType"	, True);
	ChoiceFormParameters.Insert("CurrentValue"		, Object.DocumentType);
	ChoiceFormParameters.Insert("AttributeName"		, NStr("en = 'document type'; ru = 'тип документа';pl = 'typ dokumentu';es_ES = 'tipo de documento';es_CO = 'tipo de documento';tr = 'belge türü';it = 'tipo di documento';de = 'Dokumententyp'"));
	ChoiceFormParameters.Insert("AttributeID"		, "DocumentType");
	
	AddParameters = New Structure;
	AddParameters.Insert("FieldName", "DocumentType");
	
	ChoiceNotification = New NotifyDescription("DocumentTypeChoiceEnding", ThisObject);
	
	OpenForm("CommonForm.ArbitraryParametersChoiceForm",
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		ChoiceNotification,
		FormWindowOpeningMode.LockOwnerWindow);

EndProcedure

&AtClient
Procedure DocumentTypeChoiceEnding(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) <> Type("Structure") Then
		Return;
	EndIf;

	Object.DocumentType = ClosingResult.Field;
	Object.Description	= StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1: %2 (%3)'; ru = '%1: %2 (%3)';pl = '%1: %2 (%3)';es_ES = '%1: %2 (%3)';es_CO = '%1: %2 (%3)';tr = '%1: %2 (%3)';it = '%1: %2 (%3)';de = '%1: %2 (%3)'"),
		ClosingResult.Synonym,
		Object.TypeOfAccounting,
		Object.ChartOfAccounts);
	Object.DocumentTypeSynonym = ClosingResult.Synonym;
	
	WorkWithArbitraryParametersClient.UpdateObjectSynonymsTS(Object, "DocumentType", 0, ClosingResult.Synonym);
	
EndProcedure

&AtClient
Procedure ChartOfAccountsOnChange(Item)
	
	PrevComplexTypeOfEntries = IsComplexTypeOfEntries;
	
	SetComplexTypeOfEntries();
	SetEntriesTabVisibility();

	If PrevComplexTypeOfEntries <> IsComplexTypeOfEntries Then
		WorkWithArbitraryParametersClient.ClearObjectEntries(PrevComplexTypeOfEntries, Object);
	EndIf;
	
	If CurrentChartOfAccounts <> Object.ChartOfAccounts Then
		
		UpdateDescription(CurrentChartOfAccounts, Object.ChartOfAccounts);
		CurrentChartOfAccounts = Object.ChartOfAccounts;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
EndProcedure

&AtClient
Procedure TypeOfAccountingOnChange(Item)
	
	If CurrentTypeOfAccounting <> Object.TypeOfAccounting Then
		
		UpdateDescription(CurrentTypeOfAccounting, Object.TypeOfAccounting);
		CurrentTypeOfAccounting = Object.TypeOfAccounting;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersParameters

&AtClient
Procedure ParametersBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	If Not ValueIsFilled(Object.DocumentType) Then
		
		MessageText	 = MessagesToUserClientServer.GetAccountingTransactionsTemplatesDocumentTypeIsRequiredErrorText();
		MessageField = "Object.DocumentType";
		CommonClientServer.MessageToUser(MessageText, , MessageField, , Cancel);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ParametersParameterStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	TempValues = Items.Parameters.CurrentData.ParameterName;
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("DocumentType"	, Object.DocumentType);
	ChoiceFormParameters.Insert("FillParameters", True);
	ChoiceFormParameters.Insert("AttributeName"	, NStr("en = 'parameter'; ru = 'параметр';pl = 'parametr';es_ES = 'parámetro';es_CO = 'parámetro';tr = 'parametre';it = 'parametro';de = 'Parameter'"));
	ChoiceFormParameters.Insert("AttributeID"	, "Parameter");
	ChoiceFormParameters.Insert("CurrentValue"	, TempValues);
	
	ParametersChoiceNotification = New NotifyDescription("ParametersParameterChoiceEnding", ThisObject);
	
	OpenForm("CommonForm.ArbitraryParametersChoiceForm", 
		ChoiceFormParameters, 
		ThisObject, , , , 
		ParametersChoiceNotification, 
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ParametersValueStartChoice(Item, ChoiceData, StandardProcessing)
		
	CurrentData = Items.Parameters.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.MultipleValuesMode Then
		
		OpenInputValuesInListForm();
		StandardProcessing = False;
		
	Else
		
		TempValues = CurrentData.ValuePresentation;
		
	EndIf;
	
	ParameterNameArray = StrSplit(CurrentData.ParameterName, ".");
	
	If ParameterNameArray.Count() < 3 Or ParameterNameArray[1] <> "AdditionalAttribute" Then
		
		If CurrentData.ValueType.Types().Count() > 1 Then
			Item.TypeRestriction = CurrentData.ValueType;
			Item.ChooseType = True;
		Else
			Item.TypeRestriction = New TypeDescription;
			Item.ChooseType = False;
		EndIf;
		
		Return;
		
	EndIf;
	
	SelectionFormOwner = WorkWithArbitraryParametersClient.GetAdditionalParameterType(ParameterNameArray[2]);
	
	FormFilter = New Structure("Owner", SelectionFormOwner);
	
	FormParameters = New Structure("Filter", FormFilter);
	FormParameters.Insert("ChoiceMode", True);
	
	OpenForm("Catalog.ObjectsPropertiesValues.ChoiceForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure ParametersValueOnChange(Item)
	
	CurrentData = Items.Parameters.CurrentData;
	If CurrentData = Undefined Or CurrentData.MultipleValuesMode Then
		Return;
	EndIf;

	ValueListOneValue = New ValueList;
	ValueListOneValue.Add(CurrentData.ValuePresentation, , True);
	
	If CurrentData.ValuesConnectionKey = 0 Then
		DriveClientServer.FillConnectionKey(Object.Parameters, CurrentData, "ValuesConnectionKey");
	EndIf;
	
	If (Object.Entries.Count() <> 0 
		Or Object.EntriesSimple.Count() <> 0) 
		And TempValues <> CurrentData.ValuePresentation Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("CurrentData"		, CurrentData);
		AdditionalParameters.Insert("OldValue"			, TempValues);
		AdditionalParameters.Insert("ValueListOneValue"	, ValueListOneValue);
				
		ShowQueryBox(New NotifyDescription("ParametersValueChoiceEnd", ThisObject, AdditionalParameters),
			MessagesToUserClientServer.GetAccountingTransactionsTemplatesParameterChangedQuestion(),
			QuestionDialogMode.YesNo, 0);
		
	Else
		
		WorkWithArbitraryParametersClient.SaveValueListByConnectionKey(
			Object.ParametersValues, 
			ValueListOneValue, 
			"Parameters", 
			CurrentData.ValuesConnectionKey, 
			"ConnectionKey");
		
	EndIf;

EndProcedure

&AtClient
Procedure ParametersConditionPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentData	 = Items.Parameters.CurrentData;
	
	TempValues	 = CurrentData.ConditionPresentation;
	
	WorkWithArbitraryParametersClient.SetAvailableComparasingTypesList(CurrentData, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure ParametersConditionPresentationOnChange(Item)
	
	CurrentData = Items.Parameters.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Object.Entries.Count() + Object.EntriesSimple.Count() > 0 
		And TempValues <> CurrentData.ConditionPresentation Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("CurrentData"	, CurrentData);
		AdditionalParameters.Insert("OldValue"		, TempValues);
		
		ShowQueryBox(New NotifyDescription("ParametersConditionPresentationChoiceEnd", ThisObject, AdditionalParameters),
			MessagesToUserClientServer.GetAccountingTransactionsTemplatesParameterChangedQuestion(),
			QuestionDialogMode.YesNo, 0);
		
	Else
		
		FillNewCondition(CurrentData);
		
	EndIf;

EndProcedure

&AtClient
Procedure OpenInputValuesInListForm()

	ChoiceFormParameters = WorkWithArbitraryParametersClient.FilterSelectionParameters(
		Items.Parameters.CurrentData,
		Object.ParametersValues,
		"Parameters");
		
	TempValues = ChoiceFormParameters.ValuesForSelection;
		
	OpenForm("CommonForm.InputValuesInListWithCheckBoxes",
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		New NotifyDescription("ListCompleteChoice", ThisObject),
		FormWindowOpeningMode.LockOwnerWindow);

EndProcedure 

&AtClient
Procedure ListCompleteChoice(SelectionResult, HandlerParameters) Export
	
	If TypeOf(SelectionResult) <> Type("ValueList") Then
		Return;
	EndIf;
	
	CurrentData = Items.Parameters.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;

	If CurrentData.ValuesConnectionKey = 0 Then
		DriveClientServer.FillConnectionKey(Object.Parameters, CurrentData, "ValuesConnectionKey");
	EndIf;
	
	If Object.Entries.Count() + Object.EntriesSimple.Count() > 0 
		And ValuesChanged(TempValues, SelectionResult) Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("CurrentData"		, CurrentData);
		AdditionalParameters.Insert("OldValues"			, TempValues);
		AdditionalParameters.Insert("SelectionResult"	, SelectionResult);
		
		ShowQueryBox(New NotifyDescription("ParametersMultiValuesChoiceEnd", ThisObject, AdditionalParameters),
			MessagesToUserClientServer.GetAccountingTransactionsTemplatesParameterChangedQuestion(),
			QuestionDialogMode.YesNo,
			0);
		
	Else
		
		SetParametersValueOnChange(CurrentData, SelectionResult)
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillParameters(Command)
	
	If Not PlanPeriodValidation() Then
		Return;
	EndIf;
	
	If Object.Parameters.Count() <> 0 Then
		
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("CommandToFillParametersEnd", ThisObject),
			MessagesToUserClientServer.GetAccountingTransactionsTemplatesParameterRefillQuestion(), 
			QuestionDialogMode.YesNo, 0);
		Return;
		
	EndIf;
	
	CommandToFillParametersFragment();
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure ParametersBeforeDeleteRow(Item, Cancel)
	
	If Object.Entries.Count() + Object.EntriesSimple.Count() > 0 Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("RowID", Items.Parameters.CurrentData.GetID());
		
		Notify = New NotifyDescription("DeleteRowEnd", ThisObject, AdditionalParameters);
		
		ShowQueryBox(Notify, 
			MessagesToUserClientServer.GetAccountingTransactionsTemplatesParameterDeletedQuestion(),
			QuestionDialogMode.YesNo,
			0);
		
		Cancel = True;
		
	Else
		
		WorkWithArbitraryParametersClient.DeleteRowsByConnectionKey(Object.ParametersValues, "Parameters", Item.CurrentData.ValuesConnectionKey);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ParametersBeforeEditEnd(Item, NewRow, CancelEdit, Cancel)
	
	If Object.Entries.Count() + Object.EntriesSimple.Count() > 0
		And NewRow Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("RowID"		, Item.CurrentData.GetID());
		
		Notify = New NotifyDescription("EditRowEnd", ThisObject, AdditionalParameters);
		
		ShowQueryBox(Notify, 
			MessagesToUserClientServer.GetAccountingTransactionsTemplatesParameterAddedQuestion(),
			QuestionDialogMode.YesNo,
			0);
		
		CancelEdit	 = True;
		Cancel		 = True;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersEntries

&AtClient
Procedure EntriesFilterPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenFiltersTool("Entries");
	
EndProcedure

&AtClient
Procedure EntriesAccountOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentValue = Items.Entries.CurrentData.Account;
	If ValueIsFilled(CurrentValue) Then
		ShowValue( , CurrentValue);
	EndIf;
	
EndProcedure

&AtClient
Procedure EntriesBeforeDeleteRow(Item, Cancel)
	
	CheckRowsBeforeDeletion(Item.SelectedRows, Cancel, "Entries");
	
EndProcedure

&AtClient
Procedure EntriesAfterDeleteRow(Item)
	
	SetMovingButtonsEnabled();

EndProcedure

&AtClient
Procedure EntriesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentRow = Item.CurrentData;
	
	If Field.Name = "EntriesFilterPresentation" Then
		StandardProcessing = False;
		OpenFiltersTool("Entries");
	ElsIf Field.Name = "EntriesParametersPresentation" Then
		StandardProcessing = False;
		OpenParametersTool("Entries");
	ElsIf Field.Name <> "EntriesContent" Then
		OpenEntryTemplateForm(CurrentRow, Field, "Entries", StandardProcessing);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersEntriesSimple

&AtClient
Procedure EntriesSimpleFilterPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenFiltersTool("EntriesSimple");

EndProcedure

&AtClient
Procedure EntriesSimpleAccountDrOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentValue = Items.EntriesSimple.CurrentData.AccountDr;
	If ValueIsFilled(CurrentValue) Then
		ShowValue( , CurrentValue); 
	EndIf;

EndProcedure

&AtClient
Procedure EntriesSimpleAccountCrOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentValue = Items.EntriesSimple.CurrentData.AccountCr;
	If ValueIsFilled(CurrentValue) Then
		ShowValue( , CurrentValue);
	EndIf;

EndProcedure

&AtClient
Procedure EntriesSimpleBeforeDeleteRow(Item, Cancel)
	
	CheckRowsBeforeDeletion(Item.SelectedRows, Cancel, "EntriesSimple");
	
EndProcedure

&AtClient
Procedure EntriesSimpleAfterDeleteRow(Item)
	
	SetMovingButtonsEnabled();
		
EndProcedure

&AtClient
Procedure EntriesSimpleSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentRow = Item.CurrentData;
	
	If Field.Name = "EntriesSimpleFilterPresentation" Then
		StandardProcessing = False;
		OpenFiltersTool("EntriesSimple");
	ElsIf Field.Name = "EntriesSimpleParametersPresentation" Then
		StandardProcessing = False;
		OpenParametersTool("EntriesSimple");
	ElsIf Field.Name <> "EntriesSimpleContent" Then
		OpenEntryTemplateForm(CurrentRow, Field, "EntriesSimple", StandardProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure EntriesDimensionSetOpening(Item, StandardProcessing)
	
	DimensionSetStartChoiceOrOpenning(StandardProcessing, "Entries", "");
	
EndProcedure

&AtClient
Procedure EntriesDimensionSetStartChoice(Item, ChoiceData, StandardProcessing)
	
	DimensionSetStartChoiceOrOpenning(StandardProcessing, "Entries", "");
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure EntriesSimpleDown(Command)
	
	MoveRowsWithCheck(1);

EndProcedure

&AtClient
Procedure EntriesSimpleUp(Command)
	
	MoveRowsWithCheck(-1);
	
EndProcedure

&AtClient
Procedure MoveRowsWithCheck(Direction)

	EntriesTabSectionName = ?(IsComplexTypeOfEntries, "Entries", "EntriesSimple");
	
	SelectedRowsIDs = Items[EntriesTabSectionName].SelectedRows;
	
	If SelectedRowsIDs.Count() = 0 Then
		Return;
	EndIf;
	
	RowsArray = New Array;
	
	For Each SelectedRowID In SelectedRowsIDs Do
		RowsArray.Add(Object[EntriesTabSectionName].FindByID(SelectedRowID));
	EndDo;
	
	CheckResult = CheckRowsInOneTemplate(RowsArray, EntriesTabSectionName);
	
	If CheckResult.Property("SeveralEntries")
		Or (CheckResult.Property("WholeEntry") And Not CheckResult.WholeEntry) Then
		
		ErrorTemplate = MessagesToUserClientServer.GetAccountingTransactionsTemplatesMoveLineErrorText();
		ErrorMessage  = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate, Direction);
		
		CommonClientServer.MessageToUser(ErrorMessage);
		
	ElsIf CheckResult.Property("WholeEntry") And CheckResult.WholeEntry Then
		
		MoveEntry(RowsArray, Direction);
		RenumerateEntriesTabSection(EntriesTabSectionName);
		
		Modified = True;
		
	EndIf;

EndProcedure

&AtClient
Procedure SelectEntries(Command)
	
	If Not PlanPeriodValidation() Then
		ErrorMessage = MessagesToUserClientServer.GetAccountingTransactionsTemplatesValidityPeriodErrorText();
		CommonClientServer.MessageToUser(ErrorMessage, , "Object.PlanStartDate");
		
		Return;
	EndIf;
	
	TabName = ?(IsComplexTypeOfEntries, "Entries", "EntriesSimple");
	If Object.Status = PredefinedValue("Enum.AccountingEntriesTemplatesStatuses.Active") Then
		StartDate = Object.StartDate;
		EndDate = ?(ValueIsFilled(Object.EndDate), Object.EndDate, Date('39991231'));
	Else		
		StartDate = Object.PlanStartDate;
		EndDate = ?(ValueIsFilled(Object.PlanEndDate), Object.PlanEndDate, Date('39991231'));
	EndIf;

	
	FormParameters = New Structure;
	FormParameters.Insert("StartDate"			, StartDate);
	FormParameters.Insert("EndDate"				, EndDate);
	FormParameters.Insert("Company"				, Object.Company);
	FormParameters.Insert("TypeOfAccounting"	, Object.TypeOfAccounting);
	FormParameters.Insert("DocumentType"		, Object.DocumentType);
	FormParameters.Insert("ChartOfAccounts"		, Object.ChartOfAccounts);
	FormParameters.Insert("Entries"				, Object[TabName]);
	FormParameters.Insert("TemplateParameters"	, Object.Parameters);
	FormParameters.Insert("ParametersValues"	, Object.ParametersValues);
	
	OpenForm("Catalog.AccountingTransactionsTemplates.Form.ChoosingTemplates",
		FormParameters,
		ThisObject,
		,
		,
		,
		New NotifyDescription("SelectionEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure SelectionEnd(Result, AdditionalParameters) Export
	
	If Result <> DialogReturnCode.Cancel
		And Result <> Undefined Then
		
		FillEntriesAtServer(Result);
		SetTSNumberPresentations();
		RenumerateEntriesTabSection("EntriesSimple", True);
		SetMovingButtonsEnabled();
		Modified = True;
		
	EndIf;

EndProcedure

&AtClient
Procedure CommandToFillEntriesFragment()
	
	FillEntriesAtServer();
	SetTSNumberPresentations();
	RenumerateEntriesTabSection(?(IsComplexTypeOfEntries, "Entries", "EntriesSimple"), True);
	SetMovingButtonsEnabled();
	Modified = True;
	
EndProcedure

&AtClient
Procedure EntriesSimpleDimensionSetDrOpening(Item, StandardProcessing)
	
	DimensionSetStartChoiceOrOpenning(StandardProcessing, "EntriesSimple", "Dr");
	
EndProcedure

&AtClient
Procedure EntriesSimpleDimensionSetCrOpening(Item, StandardProcessing)
	
	DimensionSetStartChoiceOrOpenning(StandardProcessing, "EntriesSimple", "Cr");
	
EndProcedure

&AtClient
Procedure EntriesSimpleDimensionSetDrStartChoice(Item, ChoiceData, StandardProcessing)
	
	DimensionSetStartChoiceOrOpenning(StandardProcessing, "EntriesSimple", "Dr");
	
EndProcedure

&AtClient
Procedure EntriesSimpleDimensionSetCrStartChoice(Item, ChoiceData, StandardProcessing)
	
	DimensionSetStartChoiceOrOpenning(StandardProcessing, "EntriesSimple", "Cr");
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SetStatusPeriodVisibility()

	Items.StartDate.Visible = (ValueIsFilled(Object.Status)
		And Object.Status = PredefinedValue("Enum.AccountingEntriesTemplatesStatuses.Active"));
	Items.EndDate.Visible = (ValueIsFilled(Object.Status)
		And Object.Status = PredefinedValue("Enum.AccountingEntriesTemplatesStatuses.Active"));
	Items.PlanDates.Visible = (ValueIsFilled(Object.Status)
		And	Object.Status = PredefinedValue("Enum.AccountingEntriesTemplatesStatuses.Draft"));
	
	If Not Items.EndDate.Visible Then
		Items.PlanDates.Visible = True;
	Else
		Items.PlanDates.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetEntriesTabVisibility()
	
	AvailableStructure = WorkWithArbitraryParametersServerCall.GetChartsOfAccountsData(Object.ChartOfAccounts);
	
	UseExtDimension	= AvailableStructure.UseAnalyticalDimensions;
	UseQuantity		= AvailableStructure.UseQuantity;
	
	If IsComplexTypeOfEntries Then
		
		Items.EntriesSimplePage.Visible		= False;
		Items.EntriesCompoundPage.Visible	= True;
		
		Items.EntriesDimensionSet.Visible				= UseExtDimension;
		Items.EntriesGroupAnalyticalDimensions1.Visible	= UseExtDimension;
		Items.EntriesGroupAnalyticalDimensions2.Visible	= UseExtDimension;
		Items.EntriesGroupAnalyticalDimensions3.Visible	= UseExtDimension;
		Items.EntriesGroupAnalyticalDimensions4.Visible	= UseExtDimension;
		
		Items.EntriesQuantity.Visible = UseQuantity;
		
	Else
		
		Items.EntriesSimplePage.Visible		= True;
		Items.EntriesCompoundPage.Visible	= False;
		
		Items.EntriesSimpleGroupDimensionsSet.Visible			= UseExtDimension;
		Items.EntriesSimpleGroupAnalyticalDimensions1.Visible	= UseExtDimension;
		Items.EntriesSimpleGroupAnalyticalDimensions2.Visible	= UseExtDimension;
		Items.EntriesSimpleGroupAnalyticalDimensions3.Visible	= UseExtDimension;
		Items.EntriesSimpleGroupAnalyticalDimensions4.Visible	= UseExtDimension;
		
		Items.EntriesSimpleGroupQty.Visible = UseQuantity;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetMovingButtonsEnabled()

	Items.UpDown.Enabled = (Object.Entries.Count() <> 0);
	Items.EntriesSimpleUpDown.Enabled = (Object.EntriesSimple.Count() <> 0);

EndProcedure

&AtClient
Procedure OpenFiltersTool(TableName)

	CurrentDataIdentifier	= Items[TableName].CurrentData.GetID();
	ParametersOfFilterTool	= FilterToolParameters(TableName, CurrentDataIdentifier);
	
	OpenForm("Catalog.AccountingEntriesTemplates.Form.FilterEditingTool",
		ParametersOfFilterTool,
		ThisObject,
		,
		,
		,
		,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtServer
Function FilterToolParameters(TableName, RowID)

	CurRowData = Object[TableName].FindByID(RowID);
	If CurRowData.ConnectionKey = 0 Then
		DriveClientServer.FillConnectionKey(Object[TableName], CurRowData, "ConnectionKey");
	EndIf;

	CurrentRowFilterStructure = New Structure("EntryConnectionKey", CurRowData.ConnectionKey);
	CurrentEntryFilters = Object.EntriesFilters.Unload(CurrentRowFilterStructure);
	
	AddressInTemporaryStorage = PutToTempStorage(CurrentEntryFilters, ThisObject.UUID);

	FilterToolParametersStructure = New Structure;
	FilterToolParametersStructure.Insert("AddressInTemporaryStorage", AddressInTemporaryStorage);
	FilterToolParametersStructure.Insert("DocumentType"				, Object.DocumentType);
	FilterToolParametersStructure.Insert("OwnerFormUUID"			, ThisObject.UUID);
	FilterToolParametersStructure.Insert("ConnectionKey"			, CurRowData.ConnectionKey);
	FilterToolParametersStructure.Insert("DataSource"				, CurRowData.DataSource);
	FilterToolParametersStructure.Insert("ReadOnly"					, True);
	
	Return FilterToolParametersStructure;

EndFunction 

&AtClient
Procedure AttributesChoiceEnding(ClosingResult, AdditionalParameters) Export

	If TypeOf(ClosingResult) <> Type("Structure") Then
		Return;
	EndIf;
	If TypeOf(AdditionalParameters) <> Type("Structure") Or Not AdditionalParameters.Property("FieldName") Then
		Return;
	EndIf;
	
	EntriesTabName = ?(IsComplexTypeOfEntries, "Entries", "EntriesSimple");
	
	CurrentData = Items[EntriesTabName].CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentData[AdditionalParameters.FieldName]				= ClosingResult.Field;
	CurrentData[AdditionalParameters.FieldName + "Synonym"]	= ClosingResult.Synonym;
	
	If CurrentData.ConnectionKey = 0 Then
		DriveClientServer.FillConnectionKey(Object[EntriesTabName], CurrentData, "ConnectionKey");
	EndIf;
	
	WorkWithArbitraryParametersClient.UpdateObjectSynonymsTS(Object, AdditionalParameters.FieldName, CurrentData.ConnectionKey, ClosingResult.Synonym);
	
EndProcedure

&AtServer
Procedure SetComplexTypeOfEntries()
	
	IsComplexTypeOfEntries = WorkWithArbitraryParameters.SetComplexTypeOfEntries(Object.ChartOfAccounts, Object.Entries.Count());
	
EndProcedure

&AtServer
Procedure InitParametersFiltersTabSections()
	
	CurrentObject = FormAttributeToValue("Object");
	
	WorkWithArbitraryParameters.GetTableValueStorageAttributes(Object.Parameters					, CurrentObject.Parameters);
	WorkWithArbitraryParameters.GetTableValueStorageAttributes(Object.EntriesFilters				, CurrentObject.EntriesFilters);
	WorkWithArbitraryParameters.GetTableValueStorageAttributes(Object.AdditionalEntriesParameters	, CurrentObject.AdditionalEntriesParameters);
	
EndProcedure

&AtServer
Procedure CopyDynamicAttributes(CopyingRef)
	
	If Not ValueIsFilled(CopyingRef) Then
		Return;
	EndIf;

	CopyingObject = CopyingRef.GetObject();
	
	WorkWithArbitraryParameters.GetTableValueStorageAttributes(Object.Parameters	, CopyingObject.Parameters);
	WorkWithArbitraryParameters.GetTableValueStorageAttributes(Object.EntriesFilters, CopyingObject.EntriesFilters);

EndProcedure 

&AtServer
Procedure SerializeParametersConditions(CurrentObject)
		
	WorkWithArbitraryParameters.SetTableValueStorageAttributes(Object.Parameters	, CurrentObject.Parameters);
	WorkWithArbitraryParameters.SetTableValueStorageAttributes(Object.EntriesFilters, CurrentObject.EntriesFilters);
	WorkWithArbitraryParameters.SetTableValueStorageAttributes(Object.AdditionalEntriesParameters, CurrentObject.AdditionalEntriesParameters);
	
EndProcedure

&AtServer
Procedure InitSimpleEntries()
	
	For Each Row In Object.EntriesSimple Do
		Row.Debit	= Enums.DebitCredit.Dr;
		Row.Credit	= Enums.DebitCredit.Cr;
	EndDo;
	
EndProcedure

&AtServer
Procedure InitSynonyms()
	
	EntriesTabName = ?(IsComplexTypeOfEntries, "Entries", "EntriesSimple");
	
	SynonymTS = Object.ElementsSynonyms;
	
	For Each Row In Object[EntriesTabName] Do
		
		WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "DataSource"			, "DataSourceSynonym");
		WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "Amount"				, "AmountSynonym");
		WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "Period"				, "PeriodSynonym");
		
		If EntriesTabName = "EntriesSimple" Then
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AccountCr"					, "AccountCrSynonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AccountDr"					, "AccountDrSynonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "CurrencyDr"				, "CurrencyDrSynonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "CurrencyCr"				, "CurrencyCrSynonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "QuantityCr"				, "QuantityCrSynonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "QuantityDr"				, "QuantityDrSynonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AmountCurDr"				, "AmountCurDrSynonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AmountCurCr"				, "AmountCurCrSynonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AnalyticalDimensionsDr1"	, "AnalyticalDimensionsDr1Synonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AnalyticalDimensionsDr2"	, "AnalyticalDimensionsDr2Synonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AnalyticalDimensionsDr3"	, "AnalyticalDimensionsDr3Synonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AnalyticalDimensionsDr4"	, "AnalyticalDimensionsDr4Synonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AnalyticalDimensionsCr1"	, "AnalyticalDimensionsCr1Synonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AnalyticalDimensionsCr2"	, "AnalyticalDimensionsCr2Synonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AnalyticalDimensionsCr3"	, "AnalyticalDimensionsCr3Synonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AnalyticalDimensionsCr4"	, "AnalyticalDimensionsCr4Synonym");
		ElsIf EntriesTabName = "Entries" Then
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "Account"				, "AccountSynonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "Currency"				, "CurrencySynonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "Quantity"				, "QuantitySynonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AmountCur"				, "AmountCurSynonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AnalyticalDimensions1"	, "AnalyticalDimensions1Synonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AnalyticalDimensions2"	, "AnalyticalDimensions2Synonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AnalyticalDimensions3"	, "AnalyticalDimensions3Synonym");
			WorkWithArbitraryParameters.FillFormTableRowSynonym(SynonymTS, Row, "AnalyticalDimensions4"	, "AnalyticalDimensions4Synonym");
		EndIf;
	EndDo;

EndProcedure

&AtServer
Function GetEntriesFiltersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	EntriesTabName = ?(IsComplexTypeOfEntries, "Entries", "EntriesSimple");
	
	TableForImport = GetFromTempStorage(AddressInTemporaryStorage);

	// Clear old versions	
	FilterCurrentString	= New Structure("EntryConnectionKey", RowKey);
	DeleteRowsArray		= New FixedArray(Object.EntriesFilters.FindRows(FilterCurrentString));
	
	For Each RowDelete In DeleteRowsArray Do
		Object.EntriesFilters.Delete(RowDelete);
	EndDo;
	
	// Generate presentation for filter line
	StringFilterPresentation = "";
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object.EntriesFilters.Add();
		
		FillPropertyValues(NewRow, ImportRow);
		
		NewRow.EntryConnectionKey = RowKey;
		
		StringFilterPresentation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 %2 %3 %4;'; ru = '%1 %2 %3 %4;';pl = '%1 %2 %3 %4;';es_ES = '%1 %2 %3 %4;';es_CO = '%1 %2 %3 %4;';tr = '%1 %2 %3 %4;';it = '%1 %2 %3 %4;';de = '%1 %2 %3 %4;'"),
			StringFilterPresentation,
			ImportRow.ParameterSynonym,
			ImportRow.ConditionPresentation,
			ImportRow.ValuePresentation);
		
	EndDo;

	ConnectionKeyFilter = New Structure("ConnectionKey", RowKey);

	CurrentEntryRow = Object[EntriesTabName].FindRows(ConnectionKeyFilter);
	If CurrentEntryRow.Count() > 0 Then
		CurrentEntryRow[0].FilterPresentation = StringFilterPresentation;
	EndIf;
	
EndFunction

#Region EntryTabNumbering

&AtClient
Procedure RenumerateEntriesTabSection(TabSectionName, Init = False)
	
	If Not Init Then
		Object[TabSectionName].Sort("TemplateNumber, EntriesTemplate, EntryLineNumber");
	EndIf;
	
	TemplateIndex = 1;
	CurrentTemplate = Undefined;
	
	For Each EntryRow In Object[TabSectionName] Do
		
		If CurrentTemplate = Undefined Then
			
			CurrentTemplate = EntryRow.EntriesTemplate;
			
		ElsIf CurrentTemplate <> EntryRow.EntriesTemplate Then
			
			TemplateIndex = TemplateIndex + 1;
			CurrentTemplate = EntryRow.EntriesTemplate;
			
		EndIf;
		
		EntryRow.TemplateNumber = TemplateIndex;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SetRowNumberPresentation(TSrow)

	If IsComplexTypeOfEntries Then
		
		TSRow.NumberPresentation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '#%1/%2'; ru = '#%1/%2';pl = '#%1/%2';es_ES = '#%1/%2';es_CO = '#%1/%2';tr = '#%1/%2';it = '#%1/%2';de = '#%1/%2'"),
			TSrow.EntryNumber,
			TSrow.EntryLineNumber);
		
	Else
		TSRow.NumberPresentation = TSrow.EntryNumber;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetTSNumberPresentations()

	For Each Row In Object.Entries Do
		SetRowNumberPresentation(Row);
	EndDo;

EndProcedure

&AtClient
Procedure MoveEntry(RowsArray, Direction)

	For Each Row In RowsArray Do
		Row.TemplateNumber = Row.TemplateNumber + 1.1 * Direction;
	EndDo;
		
EndProcedure

&AtServer
Procedure FillParametersAtServer()
	
	Object.Parameters.Clear();
	Object.Entries.Clear();
	Object.EntriesSimple.Clear();
	Object.EntriesFilters.Clear();
	Object.ElementsSynonyms.Clear();
	Object.ParametersValues.Clear();
	
	Modified = True;
	
	TemplateAttributes = New Structure("Company, TypeOfAccounting, DocumentType, ChartOfAccounts");
	FillPropertyValues(TemplateAttributes, Object);
	
	If Object.Status = Enums.AccountingEntriesTemplatesStatuses.Active Then
		
		StartDate = Object.StartDate;
		EndDate = ?(ValueIsFilled(Object.EndDate), Object.EndDate, Date('39991231'));
		
	Else
		
		StartDate = Object.PlanStartDate;
		EndDate = ?(ValueIsFilled(Object.PlanEndDate), Object.PlanEndDate, Date('39991231'));
		
	EndIf;
	
	TemplateAttributes.Insert("StartDate"	, StartDate);
	TemplateAttributes.Insert("EndDate"		, EndDate);
	
	StructureData = WorkWithArbitraryParameters.FillFromEntriesTemplates(TemplateAttributes, New Array, True);
	
	CurrentObject = FormAttributeToValue("Object");
	
	CurrentObject.Parameters.Load(StructureData.Parameters);
	CurrentObject.ParametersValues.Load(StructureData.ParametersValues);
	
	ValueToFormAttribute(CurrentObject, "Object");
	
	WorkWithArbitraryParameters.GetTableValueStorageAttributes(Object.Parameters, CurrentObject.Parameters);
	
EndProcedure

&AtClient
Procedure CommandToFillParametersEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	CommandToFillParametersFragment();

EndProcedure

&AtClient
Procedure CommandToFillParametersFragment()
	
	FillParametersAtServer();

EndProcedure

&AtServer
Function GetDifferentParameters(CommonParameters, EntriesParameters)
	
	TempCommonParameters = New ValueTable;
	TempCommonParameters.Columns.Add("ParameterName");
	TempCommonParameters.Columns.Add("Condition");
	TempCommonParameters.Columns.Add("ValuePresentation");
	TempCommonParameters.Columns.Add("MultipleValuesMode");
	
	TempEntriesParameters = EntriesParameters.Copy();
	
	For Each Row In CommonParameters Do
		
		NewRow = TempCommonParameters.Add();
		
		FillPropertyValues(NewRow,Row);
		
		NewRow.Condition		 = Row.Condition.Get();

	EndDo;
	
	RowsArray = New Array;
	For Each Row In TempEntriesParameters Do
		
		Filter = New Structure;
		Filter.Insert("ParameterName"		, Row.ParameterName);
		Filter.Insert("Condition"			, Row.Condition.Get());
		Filter.Insert("ValuePresentation"	, Row.ValuePresentation);
		Filter.Insert("MultipleValuesMode"	, Row.MultipleValuesMode);
		
		Rows = TempCommonParameters.FindRows(Filter);
		
		If Rows.Count() > 0 Then
			RowsArray.Add(Row);
		EndIf;
		
	EndDo;

	For Each Row In RowsArray Do
		TempEntriesParameters.Delete(Row);
	EndDo;

	
	Return TempEntriesParameters;
	
EndFunction

&AtServer
Procedure FillEntriesAtServer(RefsListAddress = Undefined)
	
	Object.AdditionalEntriesParameters.Clear();
	
	CurrentObject = FormAttributeToValue("Object");
	
	WorkWithArbitraryParameters.SetTableValueStorageAttributes(Object.Parameters, CurrentObject.Parameters); 
	
	WorkWithArbitraryParameters.DeleteAllRowsByMetadataName(CurrentObject.ParametersValues, "AdditionalEntriesParameters");
	WorkWithArbitraryParameters.DeleteAllRowsByMetadataName(CurrentObject.ParametersValues, "EntriesFilters");
	
	If RefsListAddress = Undefined Then
		
		TemplateParameters = Object.Parameters.Unload();
		TemplateParameters.Columns.Add("ParameterValues");
		For Each Parameter In TemplateParameters Do
			
			Parameter.ParameterValues = WorkWithArbitraryParameters.GetValuesArray(Object.ParametersValues, Parameter.ValuesConnectionKey, "Parameters");
			
		EndDo;
		
		TemplateAttributes = New Structure("Company, TypeOfAccounting, DocumentType, ChartOfAccounts");
		FillPropertyValues(TemplateAttributes, Object);
		
		If Object.Status = Enums.AccountingEntriesTemplatesStatuses.Active Then
			
			StartDate = Object.StartDate;
			EndDate = ?(ValueIsFilled(Object.EndDate), Object.EndDate, Date('39991231'));
			
		Else
			
			StartDate = Object.PlanStartDate;
			EndDate = ?(ValueIsFilled(Object.PlanEndDate), Object.PlanEndDate, Date('39991231'));
			
		EndIf;
		
		TemplateAttributes.Insert("StartDate"	, StartDate);
		TemplateAttributes.Insert("EndDate"		, EndDate);
		
		StructureData = WorkWithArbitraryParameters.FillFromEntriesTemplates(TemplateAttributes, TemplateParameters, False);
	Else
		StructureData = WorkWithArbitraryParameters.FillFromSelectedEntriesTemplates(RefsListAddress, False);
	EndIf;
		
	CurrentObject.Entries.Load(StructureData.Entries);
	CurrentObject.EntriesSimple.Load(StructureData.EntriesSimple);
	CurrentObject.EntriesFilters.Load(StructureData.EntriesFilters);
	CurrentObject.ElementsSynonyms.Load(StructureData.ElementsSynonyms);
	CurrentObject.EntriesDefaultAccounts.Load(StructureData.EntriesDefaultAccounts);
	
	For Each Row In StructureData.ParametersValuesEntries Do
		
		NewRow = CurrentObject.ParametersValues.Add();
		FillPropertyValues(NewRow, Row);
		
	EndDo;
	
	TableDiffParameters = GetDifferentParameters(CurrentObject.Parameters, StructureData.Parameters);
	For Each Row In TableDiffParameters Do
		
		Filter = New Structure;
		Filter.Insert("Ref", Row.Ref);
		EntriesRows = StructureData.Entries.FindRows(Filter);
		
		For Each EntriesRow In EntriesRows Do
			
			NewRow = CurrentObject.AdditionalEntriesParameters.Add();
			
			FillPropertyValues(NewRow, Row);
			
			NewRow.EntryConnectionKey = EntriesRow.ConnectionKey;
			DriveClientServer.FillConnectionKey(CurrentObject.AdditionalEntriesParameters, NewRow, "ValuesConnectionKey");
			
			FilterRow = New Structure;
			FilterRow.Insert("Ref"				, Row.Ref);
			FilterRow.Insert("ConnectionKey"	, Row.ValuesConnectionKey);
			ParametersValuesRows = StructureData.ParametersValues.FindRows(FilterRow);
			
			For Each ParametersValuesRow In ParametersValuesRows Do
				NewParametersValuesRow				 = CurrentObject.ParametersValues.Add();
				NewParametersValuesRow.Value		 = ParametersValuesRow.Value;
				NewParametersValuesRow.MetadataName	 = "AdditionalEntriesParameters";
				NewParametersValuesRow.ConnectionKey = NewRow.ValuesConnectionKey;
			EndDo;
			
		EndDo;
		
		EntriesRows = StructureData.EntriesSimple.FindRows(Filter);
		
		For Each EntriesRow In EntriesRows Do
			
			NewRow = CurrentObject.AdditionalEntriesParameters.Add();
			
			FillPropertyValues(NewRow, Row);
			
			NewRow.EntryConnectionKey = EntriesRow.ConnectionKey;
			DriveClientServer.FillConnectionKey(CurrentObject.AdditionalEntriesParameters, NewRow, "ValuesConnectionKey");
			
			FilterRow = New Structure;
			FilterRow.Insert("Ref"				, Row.Ref);
			FilterRow.Insert("ConnectionKey"	, Row.ValuesConnectionKey);
			ParametersValuesRows = StructureData.ParametersValues.FindRows(FilterRow);
			
			For Each ParametersValuesRow In ParametersValuesRows Do
				NewParametersValuesRow				 = CurrentObject.ParametersValues.Add();
				NewParametersValuesRow.Value		 = ParametersValuesRow.Value;
				NewParametersValuesRow.MetadataName	 = "AdditionalEntriesParameters";
				NewParametersValuesRow.ConnectionKey = NewRow.ValuesConnectionKey;
			EndDo;
			
		EndDo;
		
	EndDo;
	
	For Each Row In CurrentObject.Entries Do
		Row.ParametersPresentation = GeneratePresentationForParametersInRow(CurrentObject.AdditionalEntriesParameters, Row);
	EndDo;
	
	For Each Row In CurrentObject.EntriesSimple Do
		Row.ParametersPresentation = GeneratePresentationForParametersInRow(CurrentObject.AdditionalEntriesParameters, Row);
	EndDo;
	
	ValueToFormAttribute(CurrentObject,"Object");
	
	WorkWithArbitraryParameters.GetTableValueStorageAttributes(Object.Parameters					, CurrentObject.Parameters);
	WorkWithArbitraryParameters.GetTableValueStorageAttributes(Object.EntriesFilters				, CurrentObject.EntriesFilters);
	WorkWithArbitraryParameters.GetTableValueStorageAttributes(Object.AdditionalEntriesParameters	, CurrentObject.AdditionalEntriesParameters);
	
	InitSimpleEntries();
	InitSynonyms();
	
EndProcedure

&AtServer
Function GeneratePresentationForParametersInRow(TableData, RowData)
	
	Filter = New Structure;
	Filter.Insert("EntryConnectionKey",RowData.ConnectionKey);
	Rows = TableData.FindRows(Filter);
	
	StringParametersPresentation = "";
	
	For Each Row In Rows Do
		
		StringParametersPresentation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 %2 %3 %4;'; ru = '%1 %2 %3 %4;';pl = '%1 %2 %3 %4;';es_ES = '%1 %2 %3 %4;';es_CO = '%1 %2 %3 %4;';tr = '%1 %2 %3 %4;';it = '%1 %2 %3 %4;';de = '%1 %2 %3 %4;'"),
			StringParametersPresentation,
			Row.ParameterSynonym,
			TrimAll(Row.Condition.Get()),
			Row.ValuePresentation);
		
	EndDo;
	
	Return TrimAll(StringParametersPresentation);
	
EndFunction 

&AtClient
Procedure FillEntries(Command)
	
	If Not PlanPeriodValidation() Then
		Return;
	EndIf;
	
	If Object.Entries.Count() <> 0 Or Object.EntriesSimple.Count() <> 0 Then
		
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("CommandToFillEntriesEnd", ThisObject),
			MessagesToUserClientServer.GetAccountingTransactionsTemplatesEntriesRefillQuestion(),
			QuestionDialogMode.YesNo, 0);
		Return;
		
	EndIf;
	
	CommandToFillEntriesFragment();
	
EndProcedure

&AtClient
Procedure CommandToFillEntriesEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	CommandToFillEntriesFragment();
	
EndProcedure

&AtClient
Procedure EntriesParametersPresentationStartChoice(Item, ChoiceData, StandardProcessing)

	StandardProcessing = False;
	OpenParametersTool("Entries");
	
EndProcedure

&AtClient
Procedure EntriesSimpleParametersPresentationStartChoice(Item, ChoiceData, StandardProcessing)

	StandardProcessing = False;
	OpenParametersTool("EntriesSimple");
	
EndProcedure

&AtServer
Function ParametersToolParameters(TableName, RowID)

	CurRowData = Object[TableName].FindByID(RowID);
	If CurRowData.ConnectionKey = 0 Then
		DriveClientServer.FillConnectionKey(Object[TableName], CurRowData, "ConnectionKey");
	EndIf;
	
	CurrentRowFilterStructure = New Structure("EntryConnectionKey", CurRowData.ConnectionKey);
	CurrentAdditionalEntriesParameters = Object.AdditionalEntriesParameters.Unload(CurrentRowFilterStructure);
	
	AddressInTemporaryStorage = PutToTempStorage(CurrentAdditionalEntriesParameters, ThisObject.UUID);

	FilterToolParametersStructure = New Structure;
	FilterToolParametersStructure.Insert("AddressInTemporaryStorage", AddressInTemporaryStorage);
	FilterToolParametersStructure.Insert("DocumentType"				, Object.DocumentType); 
	FilterToolParametersStructure.Insert("OwnerFormUUID"			, ThisObject.UUID);
	FilterToolParametersStructure.Insert("ConnectionKey"			, CurRowData.ConnectionKey);
	FilterToolParametersStructure.Insert("DataSource"				, CurRowData.DataSource);
	FilterToolParametersStructure.Insert("ReadOnly"					, True);
	FilterToolParametersStructure.Insert("ParameterSynonymTitle"	, "Parameter");
	
	Return FilterToolParametersStructure;

EndFunction 

&AtClient
Procedure OpenParametersTool(TableName)

	CurrentDataIdentifier = Items[TableName].CurrentData.GetID();
	ParametersOfEntities = ParametersToolParameters(TableName, CurrentDataIdentifier);
		
	OpenForm("Catalog.AccountingEntriesTemplates.Form.FilterEditingTool", ParametersOfEntities, ThisForm, , , , , FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Function CheckRowsInOneTemplate(RowsArray, EntriesTabSectionName)

	EntryTemplatesArray = New Array;
	ReturnStructure		= New Structure;
	
	For Each TSRow In RowsArray Do
		
		If EntryTemplatesArray.Find(TSRow.EntriesTemplate) = Undefined Then
			EntryTemplatesArray.Add(TSRow.EntriesTemplate);
		EndIf;
		
	EndDo;
	
	EntriesLinesCount = 0;
	For Each EntryTemplate In EntryTemplatesArray Do
		
		EntryTmpltFilter = New Structure("EntriesTemplate", EntryTemplate);
		EntriesLines	 = Object[EntriesTabSectionName].FindRows(EntryTmpltFilter);
		
		EntriesLinesCount = EntriesLinesCount + EntriesLines.Count();
		
	EndDo;
	
	If EntriesLinesCount = RowsArray.Count() Then
		ReturnStructure.Insert("WholeEntry"		, True);
	Else 
		ReturnStructure.Insert("WholeEntry"		, False);
	EndIf;
	ReturnStructure.Insert("EntriesTemplates", EntryTemplatesArray);
	
	Return ReturnStructure;
	
EndFunction

#EndRegion

&AtClient
Procedure OpenEntryTemplateForm(CurrentRow, Field, TabSectionName, Val StandardProcessing)
	
	StandartProcessingFieldsNames = "EntriesSimpleParametersPresentation,
		|EntriesSimpleFilterPresentation,
		|EntriesParametersPresentation,
		|EntriesFilterPresentation,
		|EntriesDimensionSet,
		|EntriesSimpleDimensionSetCr,
		|EntriesSimpleDimensionSetDr";
	
	If Not ValueIsFilled(CurrentRow.EntriesTemplate) 
		Or StrFind(StandartProcessingFieldsNames, Field.Name) Then
		
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("Key"		, CurrentRow.EntriesTemplate);
	FormParameters.Insert("ReadOnly", True);
	
	If StrFind(Field.Name, "ParametersPresentation") Then
		
		FormParameters.Insert("TabName", "Parameters");
		
	Else
		
		FormParameters.Insert("TabName"			, TabSectionName);
		FormParameters.Insert("FieldName"		, Field.Name);
		FormParameters.Insert("EntryLineNumber"	, CurrentRow.EntryLineNumber);
		
		If TabSectionName = "Entries" Then
			FormParameters.Insert("EntryNumber", CurrentRow.EntryNumber);
		EndIf;
		
	EndIf;
	
	OpenForm("Catalog.AccountingEntriesTemplates.ObjectForm", 
		FormParameters, 
		ThisObject, 
		,
		,
		,
		, 
		FormWindowOpeningMode.LockWholeInterface);
	

EndProcedure

&AtClient
Procedure DeleteRowEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		CurrentRow = Object.Parameters.FindByID(AdditionalParameters.RowID);
		WorkWithArbitraryParametersClient.DeleteRowsByConnectionKey(Object.ParametersValues, "Parameters", CurrentRow.ValuesConnectionKey);
		Object.Parameters.Delete(CurrentRow);
		
		ClearEntries();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearEntries()
	
	For Each Row In Object.EntriesFilters Do
		
		WorkWithArbitraryParametersClient.DeleteRowsByConnectionKey(
			Object.ParametersValues, 
			"EntriesFilters", 
			Row.ValuesConnectionKey);

	EndDo;
	
	For Each Row In Object.AdditionalEntriesParameters Do
		
		WorkWithArbitraryParametersClient.DeleteRowsByConnectionKey(
			Object.ParametersValues, 
			"AdditionalEntriesParameters", 
			Row.ValuesConnectionKey);

	EndDo;
	
	For Each Row In Object.Entries Do
		
		WorkWithArbitraryParametersClient.DeleteAllRowsByConnectionKey(
			Object.ElementsSynonyms, 
			Row.ConnectionKey, 
			"ConnectionKey");
	
	EndDo;
	
	For Each Row In Object.EntriesSimple Do
		
		WorkWithArbitraryParametersClient.DeleteAllRowsByConnectionKey(
			Object.ElementsSynonyms, 
			Row.ConnectionKey, 
			"ConnectionKey");
	
	EndDo;
	
	Object.Entries.Clear();
	Object.EntriesSimple.Clear();
	Object.EntriesFilters.Clear();
	Object.AdditionalEntriesParameters.Clear();
	
	SetMovingButtonsEnabled();
	
EndProcedure

&AtClient
Procedure EditRowEnd(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		
		ClearEntries();
		
	Else
		
		CurrentRow = Object.Parameters.FindByID(AdditionalParameters.RowID);
		Object.Parameters.Delete(CurrentRow);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ParametersParameterChoiceEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		ClearEntries();
		
		CurrentData		 = AdditionalParameters.CurrentData;
		ClosingResult	 = AdditionalParameters.ClosingResult;
		
		FillNewParameter(CurrentData, ClosingResult);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillNewParameter(CurrentData, ClosingResult)
	
	CurrentData.ParameterName		= ClosingResult.Field;
	CurrentData.ParameterSynonym	= ClosingResult.Synonym;
	CurrentData.ValueType			= ClosingResult.ValueType;
	CurrentData.ValuePresentation	= ClosingResult.ValueType.AdjustValue(CurrentData.ValuePresentation);
	CurrentData.MultipleValuesMode	= WorkWithArbitraryParametersClient.ListSelectionIsAvailable(CurrentData.ConditionPresentation);
	
	If CurrentData.ValuesConnectionKey = 0 Then
		DriveClientServer.FillConnectionKey(Object.Parameters, CurrentData, "ValuesConnectionKey");
	EndIf;
	
	ValueListOneValue = New ValueList;
	ValueListOneValue.Add(CurrentData.ValuePresentation, , True);
	
	WorkWithArbitraryParametersClient.SaveValueListByConnectionKey(
		Object.ParametersValues, 
		ValueListOneValue, 
		"Parameters", 
		CurrentData.ValuesConnectionKey, 
		"ConnectionKey");

EndProcedure

&AtClient
Procedure ParametersParameterChoiceEnding(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) <> Type("Structure") Then
		Return;
	EndIf;

	CurrentData = Items.Parameters.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If (Object.Entries.Count() <> 0 
		Or Object.EntriesSimple.Count() <> 0)
		And TempValues <> ClosingResult.Field Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("CurrentData"	, CurrentData);
		AdditionalParameters.Insert("ClosingResult"	, ClosingResult);
		
		Notify = New NotifyDescription("ParametersParameterChoiceEnd", ThisObject, AdditionalParameters);
		
		ShowQueryBox(Notify,
			MessagesToUserClientServer.GetAccountingTransactionsTemplatesParameterChangedQuestion(),
			QuestionDialogMode.YesNo,
			0);
		
	Else
		
		FillNewParameter(CurrentData, ClosingResult);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ParametersConditionPresentationChoiceEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		ClearEntries();
		
		CurrentData = AdditionalParameters.CurrentData;
		
		FillNewCondition(CurrentData);
		
	Else
		
		FillOldCondition(AdditionalParameters.CurrentData, AdditionalParameters.OldValue);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillOldCondition(CurrentData, OldValue)
	
	CurrentData.ConditionPresentation = OldValue;
	
EndProcedure

&AtClient
Procedure FillNewCondition(CurrentData)
	
	CurrentMultipleValuesMode = CurrentData.MultipleValuesMode;
	
	CurrentData.MultipleValuesMode = WorkWithArbitraryParametersClient.ListSelectionIsAvailable(CurrentData.ConditionPresentation);
	
	If CurrentData.MultipleValuesMode <> CurrentMultipleValuesMode And CurrentMultipleValuesMode Then
		
		WorkWithArbitraryParametersClient.ProcessMultipleToSingleValue(Object.ParametersValues,	"Parameters", CurrentData);
		
	EndIf; 
	
EndProcedure

&AtClient
Procedure ParametersValueChoiceEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		ClearEntries();
		
		CurrentData		 = AdditionalParameters.CurrentData;
		
		WorkWithArbitraryParametersClient.SaveValueListByConnectionKey(
			Object.ParametersValues,
			AdditionalParameters.ValueListOneValue,
			"Parameters",
			CurrentData.ValuesConnectionKey,
			"ConnectionKey");
		
	Else
		
		CurrentData = AdditionalParameters.CurrentData;
		CurrentData.ValuePresentation = TempValues;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ParametersMultiValuesChoiceEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		ClearEntries();
		
		CurrentData		 = AdditionalParameters.CurrentData;
		SelectionResult	 = AdditionalParameters.SelectionResult;
		
		SetParametersValueOnChange(CurrentData, SelectionResult)
				
	EndIf;
	
EndProcedure

&AtClient
Procedure SetParametersValueOnChange(CurrentData, SelectionResult)
	
	WorkWithArbitraryParametersClient.SaveValueListByConnectionKey(
		Object.ParametersValues,
		SelectionResult,
		"Parameters",
		CurrentData.ValuesConnectionKey,
		"ConnectionKey");
	CurrentData.ValuePresentation = WorkWithArbitraryParametersClient.ValueArrayPresentation(SelectionResult);
	
EndProcedure

&AtClient
Function ValuesChanged(OldData, NewData)
	
	Result = False;
	
	For Each Item In NewData Do
		
		OldItem	 = OldData.FindByValue(Item.Value);
		
		Result	 = Result Or OldItem = Undefined Or Not Item.Check;
		
	EndDo;
	
	If Not Result Then
		
		For Each Item In OldData Do
			
			NewItem	 = NewData.FindByValue(Item.Value);
			
			Result	 = Result Or NewItem = Undefined Or Not NewItem.Check;
			
		EndDo;
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure DimensionSetStartChoiceOrOpenning(StandardProcessing, TabName, NameAdding)

	StandardProcessing = False;
	
	CurrentData = Items[TabName].CurrentData;
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("ReadOnly"								, True);
	ChoiceFormParameters.Insert("NameAdding"							, NameAdding);
	ChoiceFormParameters.Insert("DataSource"							, CurrentData.DataSource);
	ChoiceFormParameters.Insert("DocumentType"							, Object.DocumentType);
	ChoiceFormParameters.Insert("CurrentAnalyticalDimensionsSetValue"	, CurrentData["AnalyticalDimensionsSet" + NameAdding]);
	
	AnalyticalDimensionsArray = New Array;
	If ValueIsFilled(CurrentData["AnalyticalDimensionsType" + NameAdding + "1"]) Then
		
		AnalyticalDimensionsArray.Add(New Structure("AnalyticalDimensionType, AnalyticalDimensionValue, AnalyticalDimensionValueSynonym", 
			CurrentData["AnalyticalDimensionsType" + NameAdding + "1"], 
			CurrentData["AnalyticalDimensions" + NameAdding + "1"], 
			CurrentData["AnalyticalDimensions" + NameAdding + "1Synonym"]));
		
		If ValueIsFilled(CurrentData["AnalyticalDimensionsType" + NameAdding + "2"]) Then
			
			AnalyticalDimensionsArray.Add(New Structure("AnalyticalDimensionType, AnalyticalDimensionValue, AnalyticalDimensionValueSynonym", 
				CurrentData["AnalyticalDimensionsType" + NameAdding + "2"], 
				CurrentData["AnalyticalDimensions" + NameAdding + "2"], 
				CurrentData["AnalyticalDimensions" + NameAdding + "2Synonym"]));
			
			If ValueIsFilled(CurrentData["AnalyticalDimensionsType" + NameAdding + "3"]) Then
				
				AnalyticalDimensionsArray.Add(New Structure("AnalyticalDimensionType, AnalyticalDimensionValue, AnalyticalDimensionValueSynonym", 
					CurrentData["AnalyticalDimensionsType" + NameAdding + "3"], 
					CurrentData["AnalyticalDimensions" + NameAdding + "3"], 
					CurrentData["AnalyticalDimensions" + NameAdding + "3Synonym"]));
					
					If ValueIsFilled(CurrentData["AnalyticalDimensionsType" + NameAdding + "4"]) Then
						
						AnalyticalDimensionsArray.Add(New Structure("AnalyticalDimensionType, AnalyticalDimensionValue, AnalyticalDimensionValueSynonym", 
						CurrentData["AnalyticalDimensionsType" + NameAdding + "4"], 
						CurrentData["AnalyticalDimensions" + NameAdding + "4"], 
						CurrentData["AnalyticalDimensions" + NameAdding + "4Synonym"]));
						
					EndIf;
					
			EndIf;
			
		EndIf;
		
	EndIf;
		
	ChoiceFormParameters.Insert("CurrentAnalyticalDimensions", AnalyticalDimensionsArray);
	
	AddParameters = New Structure;
	AddParameters.Insert("FieldName", "AnalyticalDimensionsSet" + NameAdding);
	
	ParametersChoiceNotification = New NotifyDescription("AttributesChoiceEnding", ThisObject, AddParameters);
	
	OpenForm("Catalog.AccountingEntriesTemplates.Form.DimensionSetEditingTool", 
		ChoiceFormParameters, 
		ThisObject,
		,
		,
		,
		ParametersChoiceNotification,
		FormWindowOpeningMode.LockOwnerWindow);

EndProcedure

&AtClient
Function PlanPeriodValidation()

	If Object.Status = PredefinedValue("Enum.AccountingEntriesTemplatesStatuses.Draft") 
		And Not ValueIsFilled(Object.PlanStartDate) Then
		
		ErrMessage = MessagesToUserClientServer.GetAccountingTransactionsTemplatesValidityPeriodErrorText();
		CommonClientServer.MessageToUser(ErrMessage, , "Object.PlanStartDate");
		
		Return False;
		
	ElsIf Object.Status = PredefinedValue("Enum.AccountingEntriesTemplatesStatuses.Draft")
		And ValueIsFilled(Object.PlanEndDate)
		And Object.PlanEndDate < Object.PlanStartDate Then
		
		ErrMessage = MessagesToUserClientServer.GetAccountingTemplatesValidityPeriodPlannedDateTillErrorText();
		CommonClientServer.MessageToUser(ErrMessage, , "Object.PlanEndDate");
		
		Return False;
			
	ElsIf Object.Status = PredefinedValue("Enum.AccountingEntriesTemplatesStatuses.Active")
		And Not ValueIsFilled(Object.StartDate) Then
		
		ErrMessage = MessagesToUserClientServer.GetAccountingTransactionsTemplatesValidityPeriodErrorText();
		CommonClientServer.MessageToUser(ErrMessage, , "Object.StartDate");
		
		Return False;
		
	ElsIf Object.Status = PredefinedValue("Enum.AccountingEntriesTemplatesStatuses.Active") And ValueIsFilled(Object.EndDate)
		And Object.EndDate < Object.StartDate Then
		
		ErrMessage = MessagesToUserClientServer.GetAccountingTemplatesValidityPeriodDateTillErrorText();
		CommonClientServer.MessageToUser(ErrMessage, , "Object.EndDate");
		
		Return False;
		
	EndIf;
	
	Return True;

EndFunction

&AtClient
Procedure SetDates()
	
	If Object.Status = PredefinedValue("Enum.AccountingEntriesTemplatesStatuses.Active") Then
		Object.EndDate	 = Object.PlanEndDate;
		Object.StartDate = Object.PlanStartDate;
		
		CurrentEndDate	 = Object.EndDate;
		CurrentStartDate = Object.StartDate;
		
		Object.PlanEndDate	 = Undefined;
		Object.PlanStartDate = Undefined;
		
		CurrentPlanEndDate	 = Undefined;
		CurrentPlanStartDate = Undefined;
		
	ElsIf Object.Status = PredefinedValue("Enum.AccountingEntriesTemplatesStatuses.Draft") Then
		
		Object.PlanEndDate	 = Object.EndDate;
		Object.PlanStartDate = Object.StartDate;
		
		CurrentPlanEndDate	 = Object.PlanEndDate;
		CurrentPlanStartDate = Object.PlanStartDate;
		
		Object.EndDate	 = Undefined;
		Object.StartDate = Undefined;
		
		CurrentEndDate	 = Undefined;
		CurrentStartDate = Undefined;
		
	EndIf;
EndProcedure

&AtClient
Procedure PlanStartDateOnChange(Item)
	
	If ValueIsFilled(Object.PlanEndDate) And Object.PlanStartDate > Object.PlanEndDate Then
		
		ClearMessages();
		
		MessageText = MessagesToUserClientServer.GetAccountingTemplatesValidityPeriodPlannedDateFromErrorText();
		
		Object.PlanStartDate = CurrentPlanStartDate;
		
		CommonClientServer.MessageToUser(MessageText, , "PlanStartDate", "Object.PlanStartDate");
		
	Else
		CurrentPlanStartDate = Object.PlanStartDate;
	EndIf;
	
	CheckValidityPeriodOfEntries();
	
EndProcedure

&AtClient
Procedure PlanEndDateOnChange(Item)

	If ValueIsFilled(Object.PlanStartDate) 
		And ValueIsFilled(Object.PlanEndDate)
		And Object.PlanStartDate > Object.PlanEndDate Then
		
		ClearMessages();
		
		MessageText = MessagesToUserClientServer.GetAccountingTemplatesValidityPeriodPlannedDateTillErrorText();
		
		Object.PlanEndDate = CurrentPlanEndDate;
		
		CommonClientServer.MessageToUser(MessageText, , "PlanEndDate", "Object.PlanEndDate");
		
	Else
		CurrentPlanEndDate = Object.PlanEndDate;
	EndIf;
	
	CheckValidityPeriodOfEntries();
	
EndProcedure

&AtClient
Procedure StartDateOnChange(Item)
	
	ClearMessages();
	If ValueIsFilled(Object.EndDate) And Object.StartDate > Object.EndDate Then
		
		ClearMessages();
		
		MessageText = MessagesToUserClientServer.GetAccountingTemplatesValidityPeriodDateFromErrorText();
		
		Object.StartDate = CurrentStartDate;
		
		CommonClientServer.MessageToUser(MessageText, , "StartDate", "Object.StartDate");
		
	Else
		CurrentStartDate = Object.StartDate;
	EndIf;
	
	CheckValidityPeriodOfEntries();
	
EndProcedure

&AtClient
Procedure EndDateOnChange(Item)
	
	ClearMessages();
	If ValueIsFilled(Object.StartDate) 
		And ValueIsFilled(Object.EndDate)
		And Object.StartDate > Object.EndDate Then
		
		ClearMessages();
		
		MessageText = MessagesToUserClientServer.GetAccountingTemplatesValidityPeriodDateTillErrorText();
		
		Object.EndDate = CurrentEndDate;
		
		CommonClientServer.MessageToUser(MessageText, , "EndDate", "Object.EndDate");
		
	Else
		CurrentEndDate = Object.EndDate;
	EndIf;
	
	CheckValidityPeriodOfEntries();
	
EndProcedure

&AtServer
Procedure SetRestrictedStatus()

	If Object.Status = Enums.AccountingEntriesTemplatesStatuses.Draft Then
		SetReadOnlyFormAttributes(False);
	Else
		SetReadOnlyFormAttributes(True);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetReadOnlyFormAttributes(Restriction)

	Items.Company.ReadOnly			= Restriction;
	Items.Category.ReadOnly			= Restriction;
	Items.TypeOfAccounting.ReadOnly = Restriction;
	Items.ChartOfAccounts.ReadOnly	= Restriction;
	Items.DocumentType.ReadOnly		= Restriction;
	
	Items.ParametersFillParameters.Enabled = Not Restriction;
	Items.ParametersPage.ReadOnly		= Restriction;
	Items.AdditionalInfoPage.ReadOnly	= Restriction;
	
	If IsComplexTypeOfEntries Then
		VisibleTables("Entries", Restriction);
	Else
		VisibleTables("EntriesSimple", Restriction);
	EndIf;
	
EndProcedure

&AtServer
Procedure VisibleTables(TableName, Restriction)

	ItemTable = Items[TableName];
	
	If ItemTable.Visible = True Then
		
		ItemTable.ContextMenu.Enabled	= Not Restriction;
		ItemTable.CommandBar.Enabled	= Not Restriction;
		ItemTable.ChangeRowSet			= Not Restriction;
		ItemTable.ChangeRowOrder		= Not Restriction;
		
		Items[TableName + "ParametersPresentation"].ReadOnly	= Restriction;
		Items[TableName + "FilterPresentation"].ReadOnly		= Restriction;
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckValidityPeriodOfEntries(Cancel = False)
	
	CurrentObject = FormAttributeToValue("Object");
	CurrentObject.CheckTemplatesPeriods(Cancel);
		
EndProcedure

&AtClient
Procedure DeleteRowsWithTemplate(TabName, EntriesTemplates)
	
	For Each EntriesTemplate In EntriesTemplates Do
		
		RowsArrayWholeTemplate = Object[TabName].FindRows(New Structure("EntriesTemplate", EntriesTemplate));
		
		For Each TSRow In RowsArrayWholeTemplate Do
			
			WorkWithArbitraryParametersClient.DeleteAllRowsByConnectionKey(Object[TabName]			, TSRow.ConnectionKey, "ConnectionKey");
			WorkWithArbitraryParametersClient.DeleteAllRowsByConnectionKey(Object.ElementsSynonyms	, TSRow.ConnectionKey, "ConnectionKey");
			WorkWithArbitraryParametersClient.DeleteAllRowsByConnectionKey(Object.EntriesFilters	, TSRow.ConnectionKey, "EntryConnectionKey");
			
		EndDo;
		
	EndDo;
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure DeleteRowsEntriesEnd(Result, AdditionalProperties) Export
	
	If Result = DialogReturnCode.Yes Then
		DeleteRowsWithTemplate(AdditionalProperties.TabName, AdditionalProperties.EntriesTemplates);
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckRowsBeforeDeletion(SelectedRows, Cancel, TabName)
	
	SelectedRowsIDs = SelectedRows;
	RowsArray		= New Array;
	
	For Each SelectedRowID In SelectedRowsIDs Do
		RowsArray.Add(Object[TabName].FindByID(SelectedRowID));
	EndDo;
	
	CheckResult = CheckRowsInOneTemplate(RowsArray, TabName);
	
	If CheckResult.WholeEntry Then
		
		DeleteRowsWithTemplate(TabName, CheckResult.EntriesTemplates);
		
	Else
		
		AdditionalProperties = New Structure;
		AdditionalProperties.Insert("TabName"			, TabName);
		AdditionalProperties.Insert("EntriesTemplates"	, CheckResult.EntriesTemplates);
		
		NotifyDescription = New NotifyDescription("DeleteRowsEntriesEnd", ThisObject, AdditionalProperties);
		TextMessage = NStr("en = 'You have selected to delete only a part of the entry lines belonging to the same entries templates. 
			|If you continue, all the entry lines of these entries templates will be deleted. 
			|Continue?'; 
			|ru = 'Вы собираетесь удалить строки проводок, принадлежащие определенным шаблонам проводок. 
			|При продолжении все строки проводок этих шаблонов проводок будут удалены. 
			|Продолжить?';
			|pl = 'Została wybrana do usunięcia tylko część wierszy wpisów należących do tych samych szablonów wpisów. 
			|W razie kontynuowania, wszystkie wierszy wpisów tych szablonów wpisów zostaną usunięte. 
			|Kontynuować?';
			|es_ES = 'Has seleccionado eliminar sólo una parte de las líneas de entrada de diario pertenecientes a las mismas plantillas de entradas de diario. 
			|Si continúas, se borrarán todas las líneas de entrada de diario de estas plantillas de entradas de diario. 
			|¿Continuar?';
			|es_CO = 'Has seleccionado eliminar sólo una parte de las líneas de entrada de diario pertenecientes a las mismas plantillas de entradas de diario. 
			|Si continúas, se borrarán todas las líneas de entrada de diario de estas plantillas de entradas de diario. 
			|¿Continuar?';
			|tr = 'Aynı giriş şablonlarına ait giriş satırlarının sadece bir kısmını silmeyi seçtiniz. 
			|Devam ederseniz, bu giriş şablonlarının tüm giriş satırları silinecek. 
			|Devam edilsin mi?';
			|it = 'Hai selezionato di eliminare solo una parte delle righe di voe che appartengono agli stessi modelli di voce.
			|Continuando, tutte le righe di voce di questi modelli di voce saranno eliminati. 
			|Continuare?';
			|de = 'Sie haben Sich entschieden einen Teil von Buchungszeilen aus denselben Buchungsvorlagen nur löschen. 
			|Wenn Sie fortfahren, werden alle Buchungszeilen dieser Buchungsvorlagen gelöscht. 
			|Weiter?'");
		
		ShowQueryBox(NotifyDescription, TextMessage, QuestionDialogMode.YesNo, 0);
		
		Cancel = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateDescription(OldData, NewData)
	
	If Not ValueIsFilled(OldData) Then
		Object.Description = StrTemplate("%1: %2 (%3)", ?(ValueIsFilled(Object.DocumentType), Object.DocumentType.Synonym, ""), Object.TypeOfAccounting, Object.ChartOfAccounts);
	ElsIf TypeOf(OldData) = Type("CatalogRef.MetadataObjectIDs")
		Or TypeOf(OldData) = Type("CatalogRef.ExtensionObjectIDs") Then
		
		NewDataSynonym = "";
		If ValueIsFilled(NewData) Then
			NewDataSynonym = NewData.Synonym;
		EndIf;
		Object.Description = StrReplace(Object.Description, OldData.Synonym, NewDataSynonym);
		
	Else
		Object.Description = StrReplace(Object.Description, OldData, NewData);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetEnabledByRight()
	
	HasRights = AccessRight("Edit", Metadata.Catalogs.AccountingTransactionsTemplates);
	
	If Not HasRights Then
		SetItemsEnabled(Items.Parameters.CommandBar.ChildItems, False);
		SetItemsEnabled(Items.Parameters.ContextMenu.ChildItems, False);
		SetItemsEnabled(Items.Entries.CommandBar.ChildItems, False);
		SetItemsEnabled(Items.Entries.ContextMenu.ChildItems, False);
		SetItemsEnabled(Items.EntriesSimple.CommandBar.ChildItems, False);
		SetItemsEnabled(Items.EntriesSimple.ContextMenu.ChildItems, False);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetItemsEnabled(Group, Enabled)
	For Each Item In Group Do
		If TypeOf(Item) = Type("CommandGroup")
			Or TypeOf(Item) = Type("FormGroup") Then
			SetItemsEnabled(Item.ChildItems, Enabled)
		Else
			Item.Enabled = Enabled;
		EndIf;
	EndDo;
EndProcedure

&AtClient
Procedure TestTemplate(Command)
	
	If Modified Or Not ValueIsFilled(Object.Ref) Then
		
		MessageText = NStr("en = 'The template will be saved. Continue?'; ru = 'Шаблон будет сохранен. Продолжить?';pl = 'Szablon zostanie zapisany. Kontynuować?';es_ES = 'La plantilla será guardada. ¿Continuar?';es_CO = 'La plantilla será guardada. ¿Continuar?';tr = 'Şablon kaydedilecek. Devam edilsin mi?';it = 'Il modello verrà salvato. Continuare?';de = 'Die Vorlage wird gespeichert. Weiter?'");
		Notification = New NotifyDescription("TestTemplateEnd", ThisObject);
		
		ShowQueryBox(Notification, MessageText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
		
		Return;
		
	EndIf;
	
	OpenTestTemplateForm();
	
EndProcedure

&AtClient
Procedure TestTemplateEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		WriteParameters = New Structure;
		WriteParameters.Insert("OpenTestTemplateForm", True);
		Write(WriteParameters);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenTestTemplateForm()
	
	FormParameters = New Structure("Template", Object.Ref);
	OpenForm("DataProcessor.AccountingTemplatesTesting.Form.AccountingTemplateTesting",
		FormParameters,
		ThisObject,
		Object.Ref,
		,
		,
		,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion