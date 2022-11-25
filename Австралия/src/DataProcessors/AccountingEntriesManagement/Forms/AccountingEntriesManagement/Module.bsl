#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	HasRoleEditAccountingEntries = Users.IsFullUser() Or AccessManagement.HasRole("EditAccountingEntries");
	HasRoleApproveAccountingEntries = Users.IsFullUser() Or AccessManagement.HasRole("ApproveAccountingEntries");
	PlanningPeriod = Catalogs.PlanningPeriods.Actual;
	Reread = NStr("en = 'Reread'; ru = 'Перечитать';pl = 'Wczytaj ponownie';es_ES = 'Leer de nuevo';es_CO = 'Leer de nuevo';tr = 'Tekrar oku';it = 'Rileggi';de = 'Neu lesen'");
	
	CurrentDate = CurrentSessionDate();
	FilterPeriodOfSourceDocuments.StartDate = BegOfYear(CurrentDate);
	FilterPeriodOfSourceDocuments.EndDate = EndOfYear(CurrentDate);
	SetPeriod();
	
	SetDocumentListSettings();
	RefreshTypesAtServer();
	FormManagementAtServer();
	
	SetupConditionalAppearance();
	
	CompletedJob = StyleColors.CompletedJob;
	ErrorNoteText = StyleColors.ErrorNoteText;
	
	FillRecordSetMasterCommandBar();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	SetDocumentTypesFilter();
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshAccountingTransaction" Or EventName = "AccountingEntriesManagement" Then
		Items.DocumentList.Refresh();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterCompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(DocumentList, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
	RefreshTypesAtServer();
	SetDocumentTypesFilter();
	
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
		DocumentList,
		"AdjustedManually",
		FilterAdjustedManually,
		FilterAdjustedManually <> Undefined);
	
EndProcedure

&AtClient
Procedure FilterPeriodOnChange(Item)
	
	SetPeriod();
	RefreshTypesAtServer();
	SetDocumentTypesFilter();
	
EndProcedure

&AtClient
Procedure FilterStatusOnChange(Item)
	
	DriveClientServer.SetListFilterItem(DocumentList, "Status", FilterStatus, ValueIsFilled(FilterStatus));
	
EndProcedure

&AtClient
Procedure FilterDocumentTypeStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	NotifyDescription = New NotifyDescription("TypesStartChoiceEnd", ThisObject);
	
	FormParameters = New Structure("ValueList", Types);
	FormParameters.Insert("Title", NStr("en = 'Select document types'; ru = 'Выбор типов документов';pl = 'Wybierz typy dokumentu';es_ES = 'Seleccionar los tipos de documento';es_CO = 'Seleccionar los tipos de documento';tr = 'Belge türlerini seç';it = 'Selezionare i tipi di documento';de = 'Dokumententypen auswählen'"));
	
	OpenForm("CommonForm.SelectValueListItems",
		FormParameters, Item, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow); 
	
EndProcedure

&AtClient
Procedure FilterDocumentTypeClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	Types.FillChecks(True);
	SetDocumentTypesFilter();
	
EndProcedure

&AtClient
Procedure FilterTypeOfAccountingOnChange(Item)
	
	DriveClientServer.SetListFilterItem(
		DocumentList,
		"TypeOfAccounting",
		FilterTypeOfAccounting,
		ValueIsFilled(FilterTypeOfAccounting));
	
	RefreshTypesAtServer();
	SetDocumentTypesFilter();
	
EndProcedure

&AtClient
Procedure FilterGeneratedOnChange(Item)
	
	DriveClientServer.SetListFilterItem(
		DocumentList,
		"EntriesGenerated",
		FilterGenerated,
		ValueIsFilled(FilterGenerated));
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersDocumentList

&AtClient
Procedure DocumentListOnActivateRow(Item) Export

	ItemsDocumentList = Items.DocumentList;
	
	If Modified
		And CurrentItem.Name <> "AdjustedManually"
		And ItemsDocumentList.CurrentRow <> CurrentKey Then
		
		TempCurrentKey					= ItemsDocumentList.CurrentRow;
		ItemsDocumentList.CurrentRow	= CurrentKey;
		CurrentKey						= TempCurrentKey;
		
		QuestionSave(Status);
		Return;
		
	EndIf;
	
	CurrentData = ItemsDocumentList.CurrentData;
	If CurrentData = Undefined Then
		
		RecordSet.Clear();
		RecordSetMaster.Clear();
		RecordSetMasterSimple.Clear();
		
		CurrentRef							= Undefined;
		CurrentAccountingEntriesRecorder	= Undefined;
		CurrentTypeOfAccounting				= Undefined;
		CurrentPresentationCurrency			= Undefined;
		CurrentChartOfAccounts				= Undefined;
		CurrentPeriod						= Undefined;
		CurrentCompany						= Undefined;

		Return;
		
	EndIf;
	
	If CurrentData.Ref <> CurrentRef 
		Or CurrentTypeOfAccounting <> CurrentData.TypeOfAccounting Then
		
		FillPropertyValues(ThisObject, CurrentData, "Status, AdjustedManually, Comment");
		
		CurrentRef							= CurrentData.Ref;
		CurrentKey							= ItemsDocumentList.CurrentRow;
		CurrentAccountingEntriesRecorder	= CurrentData.AccountingEntriesRecorder;
		CurrentTypeOfAccounting				= CurrentData.TypeOfAccounting;
		CurrentPresentationCurrency			= CurrentData.PresentationCurrency;
		CurrentChartOfAccounts				= CurrentData.ChartOfAccounts;
		CurrentPeriod						= CurrentData.Date;
		CurrentCompany						= CurrentData.Company;
		MasterRecordSetStructure			= GetMasterRecordSet(CurrentData.ChartOfAccounts);
		MasterRecordSet						= MasterRecordSetStructure.MasterRecordSet;
		MasterRecordSetSimple				= MasterRecordSetStructure.MasterRecordSetSimple;
		
	EndIf;
	
	GetAccountingEntries(CurrentRef, CurrentTypeOfAccounting, CurrentAccountingEntriesRecorder);
	FormManagement(CurrentData.Ref, CurrentAccountingEntriesRecorder);
	SortRecordSet(Items.RecordSetMaster);
	RefreshTotalData();
	
EndProcedure

&AtServerNoContext
Function GetDocumentName(DocumentRef)
	
	Return DocumentRef.Metadata().Name;
	
EndFunction

&AtClient
Procedure DocumentListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	AccountingTransactionFieldNames = 
		"SourceDocument, DocumentListAmount, DocumentListCurrency";
	
	If Field.Name <> "DocumentListHasFiles"	Or Not Items.DocumentList.CurrentData.HasFiles Then
		
		If StrFind(AccountingTransactionFieldNames, Field.Name) <> 0 Then
			KeyToOpen = CurrentRef;
		Else
			KeyToOpen = CurrentAccountingEntriesRecorder;
		EndIf;
		
		If ValueIsFilled(KeyToOpen) Then
			
			FormParameters = New Structure;
			FormParameters.Insert("Key", KeyToOpen);
			
			OpenForm("Document." + GetDocumentName(KeyToOpen) + ".ObjectForm",
				FormParameters,
				ThisObject,
				True);
				
		EndIf;
		
	Else
		
		FormParameters = New Structure;
		FormParameters.Insert("FileOwner",	CurrentRef);
		FormParameters.Insert("ReadOnly",	Items.RecordSetGroup.ReadOnly);

		OpenForm("DataProcessor.FilesOperations.Form.AttachedFiles",
			FormParameters,
			ThisObject,
			True);
			
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersRecordSet

&AtClient
Procedure RecordSetOnStartEdit(Item, NewRow, Clone)
	
	DocumentListData = Items.DocumentList.CurrentData;
	If DocumentListData = Undefined Then
		Return;
	EndIf;
	
	If NewRow And Not Clone Then
		
		CurrentData = Item.CurrentData;
		
		If CurrentData.Property("Period") Then
			CurrentData.Period = DocumentListData.Date;
		EndIf;
		
		If CurrentData.Property("Company") Then
			CurrentData.Company = DocumentListData.Company;
		EndIf;
		
		If CurrentData.Property("Recorder") Then
			CurrentData.Recorder = DocumentListData.Ref;
		EndIf;
		
		If CurrentData.Property("PlanningPeriod") Then
			CurrentData.PlanningPeriod = PlanningPeriod;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RecordSetOnEditEnd(Item, NewRow, CancelEdit)

	If Not NewRow And Not CancelEdit And AdjustedManually Then
		Item.CurrentData.TransactionTemplate 			= Undefined;
		Item.CurrentData.TransactionTemplateLineNumber	= Undefined;
	EndIf;
	
	SortRecordSet(Item);
	RefreshTotalData();
	
EndProcedure

&AtClient
Procedure AdjustManuallyOnChange(Item)
	
	If MasterRecordSetSimple Then
		CurrentRecordSet = RecordSetMasterSimple;
	ElsIf MasterRecordSet Then
		CurrentRecordSet = RecordSetMaster;
	Else
		CurrentRecordSet = RecordSet;
	EndIf;
	
	If Not AdjustedManually
		And Items.DocumentList.CurrentData.AdjustedManually Then

		Text = NStr("en = 'The adjustments made manually will be removed for all types of accounting for current document.
			|Do you want to continue?'; 
			|ru = 'Корректировки, сделанные вручную, будут удалены для всех типов бухгалтерского учета текущего документа.
			|Продолжить?';
			|pl = 'Korekty wprowadzone ręcznie zostaną usunięte dla wszystkich typów rachunkowości dla bieżącego dokumentu.
			|Czy chcesz kontynuować?';
			|es_ES = 'Los ajustes realizados manualmente se eliminarán para todos los tipos de contabilidad del documento actual. 
			|¿Quiere continuar?';
			|es_CO = 'Los ajustes realizados manualmente se eliminarán para todos los tipos de contabilidad del documento actual. 
			|¿Quiere continuar?';
			|tr = 'Manuel olarak yapılan düzeltmeler mevcut belge için tüm muhasebe türlerinden çıkarılacak.
			|Devam etmek istiyor musunuz?';
			|it = 'Le correzioni manuali apportate saranno rimosse per tutti i tipi di contabilità per il documento corrente.
			|Continuare?';
			|de = 'Die Anpassungen manuell vorgenommen werden für alle Typen der Buchhaltung für dieses Dokument entfernt.
			|Möchten Sie fortfahren?'");
		
		NotificationParameters = New Structure();
		NotificationParameters.Insert("Form", ThisObject);
		NotificationParameters.Insert("DocumentsArray", GetAccountingEntriesRecorders(Items.DocumentList.SelectedRows));
		
		Notification = New NotifyDescription(
			"AdjustManuallyOnChangeEnd",
			AccountingApprovalClient,
			NotificationParameters);
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.No);

	EndIf;
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject, "Comment");
EndProcedure

&AtClient
Procedure RecordSetSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentRow = Item.CurrentData;
	
	If Field.Name = "RecordSetTransactionTemplateCode"
		And ValueIsFilled(CurrentRow.TransactionTemplate)
		And ValueIsFilled(CurrentRow.TransactionTemplateLineNumber) Then
		
		FormParameters = New Structure;
		FormParameters.Insert("Key"			, CurrentRow.TransactionTemplate);
		FormParameters.Insert("TabName"		, "EntriesSimple");
		FormParameters.Insert("LineNumber"	, CurrentRow.TransactionTemplateLineNumber);
		
		OpenForm("Catalog.AccountingTransactionsTemplates.ObjectForm",
			FormParameters,
			ThisObject,
			,
			,
			,
			,
			FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RecordSetExtDimensionDr1StartChoice(Item, ChoiceData, StandardProcessing)
	Item.TypeRestriction = GetTypesAtServer(Items.RecordSet.CurrentData.ExtDimensionTypeDr1);
EndProcedure

&AtClient
Procedure RecordSetExtDimensionDr2StartChoice(Item, ChoiceData, StandardProcessing)
	Item.TypeRestriction = GetTypesAtServer(Items.RecordSet.CurrentData.ExtDimensionTypeDr2);
EndProcedure

&AtClient
Procedure RecordSetExtDimensionDr3StartChoice(Item, ChoiceData, StandardProcessing)
	Item.TypeRestriction = GetTypesAtServer(Items.RecordSet.CurrentData.ExtDimensionTypeDr3);
EndProcedure

&AtClient
Procedure RecordSetExtDimensionCr1StartChoice(Item, ChoiceData, StandardProcessing)
	Item.TypeRestriction = GetTypesAtServer(Items.RecordSet.CurrentData.ExtDimensionTypeCr1);
EndProcedure

&AtClient
Procedure RecordSetExtDimensionCr2StartChoice(Item, ChoiceData, StandardProcessing)
	Item.TypeRestriction = GetTypesAtServer(Items.RecordSet.CurrentData.ExtDimensionTypeCr2);
EndProcedure

&AtClient
Procedure RecordSetExtDimensionCr3StartChoice(Item, ChoiceData, StandardProcessing)
	Item.TypeRestriction = GetTypesAtServer(Items.RecordSet.CurrentData.ExtDimensionTypeCr3);
EndProcedure
#EndRegion

#Region FormTableItemsEventHandlersRecordSetMaster

&AtClient
Procedure RecordSetMasterOnStartEdit(Item, NewRow, Clone)
	
	If NewRow And Not Clone Then
		
		DocumentListData = Items.DocumentList.CurrentData;
		CurrentData = Item.CurrentData;
		
		If CurrentData.Property("Period") Then
			CurrentData.Period = DocumentListData.Date;
		EndIf;
		
		If CurrentData.Property("Company") Then
			CurrentData.Company = DocumentListData.Company;
		EndIf;
		
		If CurrentData.Property("Recorder") Then
			CurrentData.Recorder = DocumentListData.Ref;
		EndIf;
		
		If CurrentData.Property("PlanningPeriod") Then
			CurrentData.PlanningPeriod = PlanningPeriod;
		EndIf;
		
		If CurrentData.Property("TypeOfAccounting") Then
			CurrentData.TypeOfAccounting = CurrentTypeOfAccounting;
		EndIf;
		
		CurrentData.TypeOfAccounting = CurrentTypeOfAccounting;
		
		Item.CurrentData.RecordSetPicture = -1;
		
		SetPictureInRow(Item.CurrentData);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RecordSetMasterBeforeEditEnd(Item, NewRow, CancelEdit, Cancel)

	If Not NewRow And Not CancelEdit And AdjustedManually Then
		Item.CurrentData.TransactionTemplate 			= Undefined;
		Item.CurrentData.TransactionTemplateLineNumber	= Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure RecordSetMasterSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentRow = Item.CurrentData;
	
	If Field.Name = "RecordSetMasterTransactionTemplateCode"
		And ValueIsFilled(CurrentRow.TransactionTemplate)
		And ValueIsFilled(CurrentRow.TransactionTemplateLineNumber) Then
		
		FormParameters = New Structure;
		FormParameters.Insert("Key"			, CurrentRow.TransactionTemplate);
		FormParameters.Insert("TabName"		, "Entries");
		FormParameters.Insert("LineNumber"	, CurrentRow.TransactionTemplateLineNumber);
		
		OpenForm("Catalog.AccountingTransactionsTemplates.ObjectForm",
			FormParameters,
			ThisObject,
			,
			,
			,
			,
			FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RecordSetMasterRecordTypeOnChange(Item)
	
	CurrentRow = Items.RecordSetMaster.CurrentData;
	
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	
	AttributesForSwap = New Array;
	AttributesForSwap.Add("Amount");
	AttributesForSwap.Add("AmountCur");
	AttributesForSwap.Add("Currency");
	AttributesForSwap.Add("Quantity");
	
	For Each Attribute In AttributesForSwap Do
		
		If CurrentRow.RecordType = AccountingRecordType.Debit Then
			SuffixFrom = "Cr";
			SuffixTo = "Dr";
		Else
			SuffixFrom = "Dr";
			SuffixTo = "Cr";
		EndIf;
		
		CurrentRow[Attribute + SuffixTo] = 
			?(ValueIsFilled(CurrentRow[Attribute + SuffixTo]),
			CurrentRow[Attribute + SuffixTo],
			CurrentRow[Attribute + SuffixFrom]);
		
		CurrentRow[Attribute + SuffixFrom] = Undefined;
		
	EndDo;
	
	SetPictureInRow(CurrentRow);
	
	SortRecordSet(Items.RecordSetMaster);
	MasterAccountingClientServer.RenumerateEntriesTabSection(RecordSetMaster);
	
EndProcedure

&AtClient
Procedure RecordSetMasterAmountCurDrOnChange(Item)
	
	RecordSetCompoundFieldOnChange(AccountingRecordType.Debit, "AmountCurDr", "AmountCur");
	
EndProcedure

&AtClient
Procedure RecordSetMasterAmountCurCrOnChange(Item)
	
	RecordSetCompoundFieldOnChange(AccountingRecordType.Credit, "AmountCurCr", "AmountCur");
	
EndProcedure

&AtClient
Procedure RecordSetMasterAmountDrOnChange(Item)
	
	RecordSetCompoundFieldOnChange(AccountingRecordType.Debit, "AmountDr", "Amount");
	
	RefreshTotalData();
	
EndProcedure

&AtClient
Procedure RecordSetMasterAmountCrOnChange(Item)
	
	RecordSetCompoundFieldOnChange(AccountingRecordType.Credit, "AmountCr", "Amount");
	
	RefreshTotalData();
	
EndProcedure

&AtClient
Procedure RecordSetMasterQuantityDrOnChange(Item)
	
	RecordSetCompoundFieldOnChange(AccountingRecordType.Debit, "QuantityDr", "Quantity");
	
EndProcedure

&AtClient
Procedure RecordSetMasterQuantityCrOnChange(Item)
	
	RecordSetCompoundFieldOnChange(AccountingRecordType.Credit, "QuantityCr", "Quantity");
	
EndProcedure

&AtClient
Procedure RecordSetMasterAccountOnChange(Item)
	
	CurrentTable = Items["RecordSetMaster"];
	OnAccountChangeAtServer("RecordSetMaster", CurrentTable.CurrentRow);
	
EndProcedure

&AtClient
Procedure RecordSetMasterCurrencyDrOnChange(Item)
	
	RecordSetCompoundFieldOnChange(AccountingRecordType.Debit, "CurrencyDr", "Currency");
	
EndProcedure

&AtClient
Procedure RecordSetMasterCurrencyCrOnChange(Item)
	
	RecordSetCompoundFieldOnChange(AccountingRecordType.Credit, "CurrencyCr", "Currency");
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersRecordSetMasterSimple

&AtClient
Procedure RecordSetMasterSimpleOnStartEdit(Item, NewRow, Clone)
	
	If NewRow And Not Clone Then
		
		DocumentListData = Items.DocumentList.CurrentData;
		
		If Item.CurrentData.Property("Period") Then
			Item.CurrentData.Period = DocumentListData.Date;
		EndIf;
		
		If Item.CurrentData.Property("Company") Then
			Item.CurrentData.Company = DocumentListData.Company;
		EndIf;
		
		If Item.CurrentData.Property("Recorder") Then
			Item.CurrentData.Recorder = DocumentListData.Ref;
		EndIf;
		
		If Item.CurrentData.Property("PlanningPeriod") Then
			Item.CurrentData.PlanningPeriod = PlanningPeriod;
		EndIf;
		
		Item.CurrentData.TypeOfAccounting = CurrentTypeOfAccounting;
	EndIf;
	
	If NewRow Then
		RefreshTotalData();
	EndIf;
	
EndProcedure

&AtClient
Procedure RecordSetMasterSimpleBeforeEditEnd(Item, NewRow, CancelEdit, Cancel)

	If Not NewRow And Not CancelEdit And AdjustedManually Then
		Item.CurrentData.TransactionTemplate 			= Undefined;
		Item.CurrentData.TransactionTemplateLineNumber	= Undefined;
		Item.CurrentData.EntryNumber 					= "";
	EndIf;
	
EndProcedure

&AtClient
Procedure RecordSetMasterSimpleOnEditEnd(Item, NewRow, CancelEdit)
	
	RefreshTotalData();
	
EndProcedure

&AtClient
Procedure RecordSetMasterSimpleSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentRow = Item.CurrentData;
	
	If Field.Name = "RecordSetMasterSimpleTransactionTemplateCode"
		And ValueIsFilled(CurrentRow.TransactionTemplate)
		And ValueIsFilled(CurrentRow.TransactionTemplateLineNumber) Then
		
		FormParameters = New Structure;
		FormParameters.Insert("Key"			, CurrentRow.TransactionTemplate);
		FormParameters.Insert("TabName"		, "EntriesSimple");
		FormParameters.Insert("LineNumber"	, CurrentRow.TransactionTemplateLineNumber);
		
		OpenForm("Catalog.AccountingTransactionsTemplates.ObjectForm",
			FormParameters,
			ThisObject,
			,
			,
			,
			,
			FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RecordSetMasterSimpleDebitOnChange(Item)
	
	CurrentTable = Items["RecordSetMasterSimple"];
	OnAccountChangeAtServer("RecordSetMasterSimple", CurrentTable.CurrentRow, "Dr");
	
EndProcedure

&AtClient
Procedure RecordSetMasterSimpleCreditOnChange(Item)
	
	CurrentTable = Items["RecordSetMasterSimple"];
	OnAccountChangeAtServer("RecordSetMasterSimple", CurrentTable.CurrentRow, "Cr");
	
EndProcedure

&AtClient
Procedure RecordSetMasterSimpleExtDimensionDr1StartChoice(Item, ChoiceData, StandardProcessing)
	Item.TypeRestriction = GetTypesAtServer(Items.RecordSetMasterSimple.CurrentData.ExtDimensionTypeDr1);
EndProcedure

&AtClient
Procedure RecordSetMasterSimpleExtDimensionDr2StartChoice(Item, ChoiceData, StandardProcessing)
	Item.TypeRestriction = GetTypesAtServer(Items.RecordSetMasterSimple.CurrentData.ExtDimensionTypeDr2);
EndProcedure

&AtClient
Procedure RecordSetMasterSimpleExtDimensionDr3StartChoice(Item, ChoiceData, StandardProcessing)
	Item.TypeRestriction = GetTypesAtServer(Items.RecordSetMasterSimple.CurrentData.ExtDimensionTypeDr3);
EndProcedure

&AtClient
Procedure RecordSetMasterSimpleExtDimensionDr4StartChoice(Item, ChoiceData, StandardProcessing)
	Item.TypeRestriction = GetTypesAtServer(Items.RecordSetMasterSimple.CurrentData.ExtDimensionTypeDr4);
EndProcedure

&AtClient
Procedure RecordSetMasterSimpleExtDimensionCr1StartChoice(Item, ChoiceData, StandardProcessing)
	Item.TypeRestriction = GetTypesAtServer(Items.RecordSetMasterSimple.CurrentData.ExtDimensionTypeCr1);
EndProcedure

&AtClient
Procedure RecordSetMasterSimpleExtDimensionCr2StartChoice(Item, ChoiceData, StandardProcessing)
	Item.TypeRestriction = GetTypesAtServer(Items.RecordSetMasterSimple.CurrentData.ExtDimensionTypeCr2);
EndProcedure

&AtClient
Procedure RecordSetMasterSimpleExtDimensionCr3StartChoice(Item, ChoiceData, StandardProcessing)
	Item.TypeRestriction = GetTypesAtServer(Items.RecordSetMasterSimple.CurrentData.ExtDimensionTypeCr3);
EndProcedure

&AtClient
Procedure RecordSetMasterSimpleExtDimensionCr4StartChoice(Item, ChoiceData, StandardProcessing)
	Item.TypeRestriction = GetTypesAtServer(Items.RecordSetMasterSimple.CurrentData.ExtDimensionTypeCr4);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Approve(Command)
	
	If Items.DocumentList.CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Modified Then
		QuestionSave(PredefinedValue("Enum.AccountingEntriesStatus.Approved"));
	Else
		Status = PredefinedValue("Enum.AccountingEntriesStatus.Approved");
		SetNewStatus();
	EndIf;
	
EndProcedure

&AtClient
Procedure CancelApproval(Command)
	
	If Items.DocumentList.CurrentData = Undefined Then
		Return;
	EndIf;

	If Modified Then
		QuestionSave(PredefinedValue("Enum.AccountingEntriesStatus.NotApproved"));
	Else
		Status = PredefinedValue("Enum.AccountingEntriesStatus.NotApproved");
		SetNewStatus();
	EndIf;
	
EndProcedure

&AtClient
Procedure Write(Command)
	
	If RecordSetHasBeenChanged() Then
		
		NotifyDescription = New NotifyDescription("AfterQuestionReread", ThisObject);
		QuestionText = MessagesToUserClientServer.GetDataChangedQueryText();
		ButtonsValueList = New ValueList;
		ButtonsValueList.Add(Reread);
		ButtonsValueList.Add(NStr("en = 'Cancel'; ru = 'Отмена';pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal';it = 'Annulla';de = 'Abbrechen'"));
		ShowQueryBox(NotifyDescription, QuestionText, ButtonsValueList);
		
	Else
		
		Cancel = False;
		
		WriteAtServer(, , Cancel);
		
		If Cancel Then
			Return;
		EndIf;
		
		SetNewStatus(True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure WriteMaster(Command)
	
	ClearMessages();
	
	If RecordSetMasterHasBeenChanged() Or RecordSetSimpleHasBeenChanged() Then
		
		NotifyDescription = New NotifyDescription("AfterQuestionReread", ThisObject);
		QuestionText = MessagesToUserClientServer.GetDataChangedQueryText();
		ButtonsValueList = New ValueList;
		ButtonsValueList.Add(Reread);
		ButtonsValueList.Add(NStr("en = 'Cancel'; ru = 'Отмена';pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal';it = 'Annulla';de = 'Abbrechen'"));
		ShowQueryBox(NotifyDescription, QuestionText, ButtonsValueList);
		
	Else
		
		Cancel = False;
		
		WriteAtServer(MasterRecordSetSimple, MasterRecordSet, Cancel);
		
		If Cancel Then
			Return;
		EndIf;
		
		SetNewStatus(True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure GenerateEntries(Command)
	
	ClearMessages();
	Rows = GetAccountingEntriesRecorders(Items.DocumentList.SelectedRows);
	
	Result = CheckRowsAtServer(Rows);
	
	If Result.Approved Then
		
		SendMessagesToUser(Result, Rows, "Approved");
		Return;
		
	ElsIf Result.AdjustedManually
		And Result.Generated Then
		
		SendMessagesToUser(Result, Rows, "AdjustedManuallyGenerated");
		Return;
		
	ElsIf Result.AdjustedManually Then
		
		SendMessagesToUser(Result, Rows, "AdjustedManually");
		Return;
		
	ElsIf Result.Generated Then
		
		SendMessagesToUser(Result, Rows, "Generated");
		Return;
		
	EndIf;
	
	GenerateEntriesEndClient(Rows);
	
EndProcedure

&AtClient
Procedure RefreshData(Command)
	
	RefreshDataAtServer(DocumentList.SettingsComposer, Undefined);
	Items.DocumentList.Refresh();
	
	CurrentData = Items.DocumentList.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	FillPropertyValues(ThisObject, CurrentData, "Status, AdjustedManually, Comment");
	
	DocumentListOnActivateRow(Items.DocumentList);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FormManagementAtServer()

	UseAccountingApproval = GetFunctionalOption("UseAccountingApproval");
	
	Items.Approve.Visible						= UseAccountingApproval;
	Items.CancelApproval.Visible				= UseAccountingApproval;
	Items.Status.Visible						= UseAccountingApproval;
	Items.GroupRecordSetApproveCancel.Visible	= UseAccountingApproval;
	Items.DocumentListApproved.Visible			= UseAccountingApproval;
 	
	Items.RecordSetAdd.Representation				= ButtonRepresentation.PictureAndText;
	Items.RecordSetMasterAdd.Representation			= ButtonRepresentation.PictureAndText;
	Items.RecordSetMasterSimpleAdd.Representation	= ButtonRepresentation.PictureAndText;
	
	Items.RecordSetDelete.OnlyInAllActions	= False;
	Items.RecordSetDelete.Representation	= ButtonRepresentation.Picture;
	
	Items.RecordSetMasterDelete.OnlyInAllActions	= False;
	Items.RecordSetMasterDelete.Representation		= ButtonRepresentation.Picture;
	
	Items.RecordSetMasterSimpleDelete.OnlyInAllActions	= False;
	Items.RecordSetMasterSimpleDelete.Representation	= ButtonRepresentation.Picture;
	
	Items.RecordSetCopy.OnlyInAllActions	= False;
	Items.RecordSetCopy.Representation		= ButtonRepresentation.Picture;
	
	Items.RecordSetMasterCopy.OnlyInAllActions	= False;
	Items.RecordSetMasterCopy.Representation	= ButtonRepresentation.Picture;
	
	Items.RecordSetMasterSimpleCopy.OnlyInAllActions = False;
	Items.RecordSetMasterSimpleCopy.Representation	 = ButtonRepresentation.Picture;
	
	Items.GroupPeriodLineNumber.ReadOnly	= True;
	Items.PlanningPeriod.ReadOnly			= True;
	
EndProcedure

&AtClient
Procedure FormManagement(SourceDocument = Undefined, AccountingEntriesRecorder = False) Export

	DocumentListData = Items.DocumentList.CurrentData;
	
	If DocumentListData = Undefined Then
		CurrentRef							= Undefined;
		CurrentAccountingEntriesRecorder	= Undefined;
		CurrentTypeOfAccounting				= Undefined;
		CurrentPresentationCurrency			= Undefined;
		CurrentChartOfAccounts				= Undefined;
		CurrentPeriod						= Undefined;
		CurrentCompany						= Undefined;
		AccountingEntriesRecorder			= Undefined;
		Status								= Undefined;
		AdjustedManually					= False;
	EndIf;
	
	If SourceDocument = Undefined Then
		SourceDocument = CurrentRef;
	EndIf;
	
	FilterSrtucture = New Structure("Ref", SourceDocument);
	FoundRows = CommonRecordSets.FindRows(FilterSrtucture);
	
	IsClosingPeriod = ?(FoundRows.Count() > 0, True, False);
	For Each Row In FoundRows Do
		IsClosingPeriod = Row.IsClosingPeriod;
	EndDo;
	
	Approved = (Status = PredefinedValue("Enum.AccountingEntriesStatus.Approved"));
	
	If Approved Then
		Items.Status.TextColor = CompletedJob;
	Else
		Items.Status.TextColor = ErrorNoteText;
	EndIf;
	
	Items.FormGenerateEntries.Enabled				= HasRoleEditAccountingEntries And Not IsClosingPeriod;
	Items.GroupApproveCancel.Enabled				= HasRoleApproveAccountingEntries And Not IsClosingPeriod;
	Items.GroupRecordSetApproveCancel.Enabled		= HasRoleApproveAccountingEntries And Not IsClosingPeriod;
	Items.CommandBarFormStandardCommands.Enabled	= HasRoleEditAccountingEntries And AdjustedManually And Not Approved;
	Items.RecordSetGroup.ReadOnly					= Not HasRoleEditAccountingEntries Or IsClosingPeriod Or Approved;
	Items.RecordSetGroupTable.ReadOnly				= Not AdjustedManually;
	
	Items.GroupRecordSetMasterApproveCancel.Enabled		= HasRoleApproveAccountingEntries And Not IsClosingPeriod;
	Items.RecordSetMasterCommandBar.Enabled				= HasRoleEditAccountingEntries And AdjustedManually And Not Approved;
	Items.RecordSetMasterGroupTable.ReadOnly			= Not AdjustedManually;
	
	Items.GroupRecordSetMasterApproveCancelSimple.Enabled		= HasRoleApproveAccountingEntries And Not IsClosingPeriod;
	Items.RecordSetWriteMasterSimple.Enabled					= HasRoleEditAccountingEntries And AdjustedManually And Not Approved;
	Items.RecordSetApproveMasterSimple.Enabled					= HasRoleEditAccountingEntries And AdjustedManually And Not Approved;
	Items.RecordSetCancelMasterSimple.Enabled					= HasRoleEditAccountingEntries And AdjustedManually And Not Approved;
	Items.RecordSetMasterSimpleGroupTable.ReadOnly				= Not AdjustedManually;
	
	If DocumentListData <> Undefined And ValueIsFilled(DocumentListData.ChartOfAccounts) Then
		
		ChartOfAccountsAttributes = GetObjectAttribute(DocumentListData.ChartOfAccounts, "UseQuantity, UseAnalyticalDimensions");
		
		Items.RecordSetMasterExtDimensions.Visible 			= ChartOfAccountsAttributes.UseAnalyticalDimensions;
		Items.RecordSetMasterSimpleExtDimensionsDr.Visible	= ChartOfAccountsAttributes.UseAnalyticalDimensions;
		Items.RecordSetMasterSimpleExtDimensionsCr.Visible	= ChartOfAccountsAttributes.UseAnalyticalDimensions;
		Items.GroupExtDimensionsDr.Visible					= ChartOfAccountsAttributes.UseAnalyticalDimensions;
		Items.GroupExtDimensionsCr.Visible					= ChartOfAccountsAttributes.UseAnalyticalDimensions;
		
		Items.RecordSetMasterQuantityDr.Visible			= ChartOfAccountsAttributes.UseQuantity;
		Items.RecordSetMasterQuantityCr.Visible			= ChartOfAccountsAttributes.UseQuantity;
		Items.RecordSetMasterSimpleQuantityDr.Visible	= ChartOfAccountsAttributes.UseQuantity;
		Items.RecordSetMasterSimpleQuantityCr.Visible	= ChartOfAccountsAttributes.UseQuantity;
	
	EndIf;
	
	If MasterRecordSetSimple Then
		Items.Totals.Visible = True;
		Items.TotalDifference.Visible = False;
		Items.CompanyPresentationCurrency.Visible = False;
		Items.Pages.CurrentPage = Items.RecordSetMasterSimpleGroupTable;
		Items.RecordSetMasterSimpleAmount.Title = StrTemplate(NStr("en = 'Amount (%1)'; ru = 'Сумма (%1)';pl = 'Wartość (%1)';es_ES = 'Importe (%1)';es_CO = 'Importe (%1)';tr = 'Tutar (%1)';it = 'Importo (%1)';de = 'Betrag (%1)'"), CurrentPresentationCurrency);
	ElsIf MasterRecordSet Then
		Items.Totals.Visible = True;
		Items.TotalDifference.Visible = True;
		Items.CompanyPresentationCurrency.Visible = True;
		Items.Pages.CurrentPage = Items.RecordSetMasterGroupTable;
		Items.RecordSetMasterAmountDr.Title = StrTemplate(NStr("en = 'Amount Dr (%1)'; ru = 'Сумма Дт (%1)';pl = 'Wartość Wn (%1)';es_ES = 'Importe Débito (%1)';es_CO = 'Importe Débito (%1)';tr = 'Tutar Borç (%1)';it = 'Importo deb (%1)';de = 'Betrag Soll (%1)'"), CurrentPresentationCurrency);
		Items.RecordSetMasterAmountCr.Title = StrTemplate(NStr("en = 'Amount Cr (%1)'; ru = 'Сумма Кт (%1)';pl = 'Wartość Ma (%1)';es_ES = 'Importe Crédito (%1)';es_CO = 'Importe Crédito (%1)';tr = 'Tutar Alacak (%1)';it = 'Importo cred (%1)';de = 'Betrag Haben (%1)'"), CurrentPresentationCurrency);
	Else
		Items.Totals.Visible = False;
		Items.Pages.CurrentPage = Items.RecordSetGroupTable;
	EndIf;
	
	IsAccountingEntriesRecorder = (AccountingEntriesRecorder <> Undefined);
	
	Items.AdjustedManually.Enabled	= IsAccountingEntriesRecorder;
	Items.Approve.Enabled			= IsAccountingEntriesRecorder;
	Items.CancelApproval.Enabled	= IsAccountingEntriesRecorder;
	
EndProcedure

&AtServer
Procedure SetupConditionalAppearance()
	
	MaxExtDimensions = WorkWithArbitraryParametersServerCall.MaxAnalyticalDimensionsNumber();
	
	ChoiceParameterLinkArray = New Array;
	ChoiceParameterLinkArray.Add(New ChoiceParameterLink("Filter.ChartOfAccounts", "CurrentChartOfAccounts"));
	ChoiceParameterLinkArray.Add(New ChoiceParameterLink("Filter.Date", "CurrentPeriod"));
	ChoiceParameterLinkArray.Add(New ChoiceParameterLink("Filter.Company", "CurrentCompany"));
	
	Items.RecordSetMasterAccount.ChoiceParameterLinks = New FixedArray(ChoiceParameterLinkArray);
	Items.RecordSetMasterSimpleDebit.ChoiceParameterLinks = New FixedArray(ChoiceParameterLinkArray);
	Items.RecordSetMasterSimpleCredit.ChoiceParameterLinks = New FixedArray(ChoiceParameterLinkArray);
	
	For Index = 1 To MaxExtDimensions Do
		MasterAccountingFormGeneration.SetupExtDimensionConditionalAppearance(ThisObject, "RecordSetMaster", Index);
		MasterAccountingFormGeneration.SetupExtDimensionConditionalAppearance(ThisObject, "RecordSetMasterSimple", Index, "Dr");
		MasterAccountingFormGeneration.SetupExtDimensionConditionalAppearance(ThisObject, "RecordSetMasterSimple", Index, "Cr");
	EndDo;
	
	SetupMiscFieldsConditionalAppearance(ThisObject, "RecordSetMaster", "Dr", True);
	SetupMiscFieldsConditionalAppearance(ThisObject, "RecordSetMaster", "Cr", True);
	
	SetupMiscFieldsConditionalAppearance(ThisObject, "RecordSetMasterSimple", "Dr");
	SetupMiscFieldsConditionalAppearance(ThisObject, "RecordSetMasterSimple", "Cr");
	
EndProcedure

&AtServer
Procedure GetAccountingEntriesAtServer()

	RecordSetFromStorage = GetFromTempStorage(RecordSetsAddress);
	
	If Not CommonRecordsSetColumnsAdded Then
		
		AddedAttributesArray = New Array;
		If RecordSetFromStorage.Count() > 0 Then
			
			ColumnsTypeTable = GetColumnsTypeTable();
			
			Columns = ColumnsTypeTable.Columns;
			
			For Each Column In Columns Do
				If Column.Name <> "PointInTime" Then
					AddedAttributesArray.Add(New FormAttribute(Column.Name, Column.ValueType, "CommonRecordSets.RecordSet"));
				EndIf;
			EndDo;
			ChangeAttributes(AddedAttributesArray);
			CommonRecordsSetColumnsAdded = True;
			
		EndIf;
	EndIf;
	
	ValueToFormAttribute(RecordSetFromStorage, "CommonRecordSets");
	
EndProcedure

&AtClient
Function GetAccountingEntries(Ref, TypeOfAccounting, AccountingEntriesRecorder)

	RecordSet.Clear();
	RecordSetBeforeEdit.Clear();
	
	RecordSetMaster.Clear();
	RecordSetMasterBeforeEdit.Clear();
	
	RecordSetMasterSimple.Clear();
	RecordSetSimpleBeforeEdit.Clear();
	
	If MasterRecordSetSimple Then
		CurrentRecordSet 			= RecordSetMasterSimple;
		CurrentRecordSetBeforeEdit  = RecordSetSimpleBeforeEdit;
	ElsIf MasterRecordSet Then
		CurrentRecordSet			= RecordSetMaster;
		CurrentRecordSetBeforeEdit	= RecordSetMasterBeforeEdit;
	Else
		CurrentRecordSet			= RecordSet;
		CurrentRecordSetBeforeEdit	= RecordSetBeforeEdit;
	EndIf;
	
	FilterSrtucture = New Structure;
	FilterSrtucture.Insert("Ref"				, Ref);
	FilterSrtucture.Insert("TypeOfAccounting"	, TypeOfAccounting);
	
	FoundRows = CommonRecordSets.FindRows(FilterSrtucture);
	
	If FoundRows.Count() = 0 And ValueIsFilled(Ref) Then
		
		GetAccountingEntriesAtServer();
		If CurrentRecordSet.Count() = 0 Then
			FoundRows = CommonRecordSets.FindRows(FilterSrtucture);
		EndIf;
		
	EndIf;
	
	For Each Row In FoundRows Do
		
		CollectionRecordSet = Row.RecordSet;
		
		For Each RecordRow In CollectionRecordSet Do
			Record = CurrentRecordSet.Add();
			FillPropertyValues(Record, RecordRow);
			
			Record = CurrentRecordSetBeforeEdit.Add();
			FillPropertyValues(Record, RecordRow);
			
		EndDo;
		
	EndDo;
	
EndFunction

&AtClient
Procedure TypesStartChoiceEnd(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		FormManagement();
		Return;
	EndIf;
	
	Types = Result;
	SetDocumentTypesFilter();
	FormManagement();

EndProcedure

&AtServer
Function GetDocumentTypesAtServer(Types)
	
	ParameterArray = New Array;
	
	For Each DocumentType In Types Do
		
		If DocumentType.Check Then
			ParameterArray.Add(TypeOf(DocumentType.Value.EmptyRefValue));
			FilterDocumentType = ?(IsBlankString(FilterDocumentType), "", FilterDocumentType + "; ")
				+ DocumentType.Presentation;
		EndIf;
		
	EndDo;
	
	Return ParameterArray;
	
EndFunction

&AtClient
Procedure SetDocumentTypesFilter()
	
	FilterDocumentType = "";
	
	ParameterArray = GetDocumentTypesAtServer(Types);
	
	DriveClientServer.SetListFilterItem(
		DocumentList,
		"Type",
		ParameterArray,
		,
		DataCompositionComparisonType.InList);
		
EndProcedure

&AtClient
Procedure SetNewStatus(FillAdjustedManually = False)
	
	ProcedureParameters = New Structure("Status, Comment, UUID");
	FillPropertyValues(ProcedureParameters, ThisObject);
	
	If FillAdjustedManually Then
		ProcedureParameters.Insert("AdjustedManually", AdjustedManually);
	EndIf;
	
	ProcedureParameters.Insert("DocumentsArray", GetAccountingEntriesRecorders(Items.DocumentList.SelectedRows));

	AccountingApprovalClient.SetNewStatus(ThisObject, ProcedureParameters);
	FormManagement();
	
EndProcedure

&AtServerNoContext
Function GetAccountingEntriesRecorders(Val RecordersArray)
	
	Result = New Array;
	
	RecordersTable = New ValueTable;
	RecordersTable.Columns.Add("Ref"							, Metadata.DefinedTypes.AccountingEntriesRecorder.Type);
	RecordersTable.Columns.Add("TypeOfAccounting"				, New TypeDescription("CatalogRef.TypesOfAccounting"));
	RecordersTable.Columns.Add("ChartOfAccounts"				, New TypeDescription("CatalogRef.ChartsOfAccounts"));
	
	For Each Recorder In RecordersArray Do
		Row = RecordersTable.Add();
		FillPropertyValues(Row, Recorder);
	EndDo;
	Query = New Query;
	Query.Text = 
	"SELECT
	|	RecordersTable.TypeOfAccounting AS TypeOfAccounting,
	|	RecordersTable.Ref AS Ref,
	|	RecordersTable.ChartOfAccounts AS ChartOfAccounts
	|INTO Recorders
	|FROM
	|	&Recorders AS RecordersTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountingTransactionDocuments.TypeOfAccounting AS TypeOfAccounting,
	|	AccountingTransactionDocuments.SourceDocument AS Ref,
	|	AccountingTransactionDocuments.ChartOfAccounts AS ChartOfAccounts,
	|	AccountingTransactionDocuments.AccountingEntriesRecorder AS AccountingEntriesRecorder
	|FROM
	|	InformationRegister.AccountingTransactionDocuments AS AccountingTransactionDocuments
	|WHERE
	|	(AccountingTransactionDocuments.SourceDocument, AccountingTransactionDocuments.TypeOfAccounting) IN
	|			(SELECT
	|				Recorders.Ref AS Ref,
	|				Recorders.TypeOfAccounting AS TypeOfAccounting
	|			FROM
	|				Recorders AS Recorders)";
	
	Query.SetParameter("Recorders", RecordersTable);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		ResultRow = New Structure;
		ResultRow.Insert("Ref"						, SelectionDetailRecords.Ref);
		ResultRow.Insert("TypeOfAccounting"			, SelectionDetailRecords.TypeOfAccounting);
		ResultRow.Insert("ChartOfAccounts"			, SelectionDetailRecords.ChartOfAccounts);
		ResultRow.Insert("AccountingEntriesRecorder", SelectionDetailRecords.AccountingEntriesRecorder);
		
		Result.Add(ResultRow);
		
	EndDo;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Procedure DocumentListOnGetDataAtServer(ItemName, Settings, Rows)
	
	RecordersKey = Rows.GetKeys();
	
	RecordersTable = New ValueTable;
	AccountingApprovalServer.DocumentListOnGetDataAtServer(Rows, RecordersKey, RecordersTable);
	
	RecordSetsAddress	= Settings.AdditionalProperties.RecordSetsAddress;
	CommonRecordSets	= GetFromTempStorage(RecordSetsAddress);
	
	RecordersArray = GetAccountingEntriesRecorders(RecordersKey);
	
	For Each Recorder In RecordersArray Do
		
		Filter = New Structure("Ref, TypeOfAccounting");
		FillPropertyValues(Filter, Recorder);
		
		CommonRecordSetsRows = CommonRecordSets.FindRows(Filter);
		If CommonRecordSetsRows.Count() = 0 Then
			Row = CommonRecordSets.Add();
			FillPropertyValues(Row, Recorder);
			
			CurrentRecorder = 
				?(Recorder.AccountingEntriesRecorder = Undefined, Recorder.Ref, Recorder.AccountingEntriesRecorder);
			
			MasterRecordSetStructure = GetMasterRecordSet(Recorder.ChartOfAccounts);
			
			If MasterRecordSetStructure.MasterRecordSetSimple Then
			
				RecordSet = AccountingRegisters.AccountingJournalEntriesSimple.CreateRecordSet();
				RecordSet.Filter.Recorder.Set(CurrentRecorder);
				RecordSet.Read();
				
				RecordSetTable = AccountingApprovalServer.GetRecordSetSimpleByRecorder(CurrentRecorder);
				
				MasterAccounting.FillMiscFields(RecordSetTable);
				
			ElsIf MasterRecordSetStructure.MasterRecordSet Then
				
				RecordSet = AccountingRegisters.AccountingJournalEntriesCompound.CreateRecordSet();
				RecordSet.Filter.Recorder.Set(CurrentRecorder);
				RecordSet.Read();
				
				RecordSetTable = AccountingApprovalServer.GetRecordSetMasterByRecorder(CurrentRecorder);
				
				MasterAccounting.FillMiscFields(RecordSetTable);
				
			Else
				
				RecordSet = AccountingRegisters.AccountingJournalEntries.CreateRecordSet();
				RecordSet.Filter.Recorder.Set(CurrentRecorder);
				RecordSet.Read();
				
				RecordSetTable = RecordSet.Unload();
				
			EndIf;
			
			Row.RecordSet = RecordSetTable.Copy(New Structure("TypeOfAccounting", Recorder.TypeOfAccounting));
			Row.IsClosingPeriod = PeriodClosingDates.DataChangesDenied(RecordSet);
			
		EndIf;
		
	EndDo;
	
	PutToTempStorage(CommonRecordSets, RecordSetsAddress);
	
EndProcedure

&AtServer
Procedure SetDocumentListSettings()
	
	RecordSetsAddress = PutToTempStorage(FormAttributeToValue("CommonRecordSets"), UUID);
	Documentlist.SettingsComposer.Settings.AdditionalProperties.Insert("RecordSetsAddress", RecordSetsAddress);
	
	Fields = New Array;
	Fields.Add("HasFiles");
	
	DocumentList.SetRestrictionsForUseInFilter(Fields);
	DocumentList.SetRestrictionsForUseInGroup(Fields);
	DocumentList.SetRestrictionsForUseInOrder(Fields);

EndProcedure

&AtServer
Procedure WriteAtServer(Simple = False, Master = False, Cancel = False)
	
	If Simple Then
		
		FillCheckProcessing(RecordSetMasterSimple, "RecordSetMasterSimple", False, Cancel);
		If Cancel Then
			Return;
		EndIf;
		
		ObjectRecordSetMaster = FormAttributeToValue("RecordSetMasterSimple");
		
		If CurrentAccountingEntriesRecorder = CurrentRef Then
			
			TempRecordSetMaster = AccountingRegisters.AccountingJournalEntriesSimple.CreateRecordSet();
			TempRecordSetMaster.Filter.Recorder.Set(CurrentAccountingEntriesRecorder);
			TempRecordSetMaster.Read();
			
			TempRecordSetMasterTable = TempRecordSetMaster.Unload();
			Rows = TempRecordSetMasterTable.FindRows(New Structure("TypeOfAccounting", CurrentTypeOfAccounting));
			
			For Each Row In Rows Do
				
				TempRecordSetMasterTable.Delete(Row);
				
			EndDo;
			
			For Each Rec In RecordSetMasterSimple Do
				
				NewRow = TempRecordSetMasterTable.Add();
				FillPropertyValues(NewRow, Rec);
				NewRow.Active = True;
				
			EndDo;
			
			TempRecordSetMaster.Load(TempRecordSetMasterTable);
			TempRecordSetMaster.Write();
			
		Else
			
			ObjectRecordSetMaster.Filter.Recorder.Set(CurrentAccountingEntriesRecorder);
			
			ObjectRecordSetMaster.Write();
			
		EndIf;
		
		
		If Not Cancel Then
			
			RecordSetSimpleBeforeEditObject = FormAttributeToValue("RecordSetSimpleBeforeEdit");
			
			TempRecordSetMasterFromDatabase = ObjectRecordSetMaster.Unload();
			TempRecordSetMasterFromDatabase = TempRecordSetMasterFromDatabase.Copy(
				New Structure("TypeOfAccounting", CurrentTypeOfAccounting));
			
			RecordSetSimpleBeforeEditObject.Load(TempRecordSetMasterFromDatabase);
			
			ValueToFormAttribute(RecordSetSimpleBeforeEditObject, "RecordSetSimpleBeforeEdit");
			
		EndIf;
		
	ElsIf Master Then
		
		FillCheckProcessing(RecordSetMaster, "RecordSetMaster", True, Cancel);
		
		If Cancel Then
			Return;
		EndIf;
		
		ObjectRecordSetMaster = FormAttributeToValue("RecordSetMaster");
		
		If CurrentAccountingEntriesRecorder = CurrentRef Then
			
			TempRecordSetMaster = AccountingRegisters.AccountingJournalEntriesCompound.CreateRecordSet();
			TempRecordSetMaster.Filter.Recorder.Set(CurrentAccountingEntriesRecorder);
			TempRecordSetMaster.Read();
			
			TempRecordSetMasterTable = TempRecordSetMaster.Unload();
			Rows = TempRecordSetMasterTable.FindRows(New Structure("TypeOfAccounting", CurrentTypeOfAccounting));
			
			For Each Row In Rows Do
				
				TempRecordSetMasterTable.Delete(Row);
				
			EndDo;
			
			For Each Rec In RecordSetMaster Do
				
				NewRow = TempRecordSetMasterTable.Add();
				FillPropertyValues(NewRow, Rec);
				NewRow.Active = True;
				
			EndDo;
			
			TempRecordSetMaster.Load(TempRecordSetMasterTable);
			TempRecordSetMaster.Write();
			
		Else
			
			ObjectRecordSetMaster.Filter.Recorder.Set(CurrentAccountingEntriesRecorder);
			
			ObjectRecordSetMaster.Write();
			
		EndIf;
		
		
		If Not Cancel Then
			
			RecordSetMasterBeforeEditObject = FormAttributeToValue("RecordSetMasterBeforeEdit");
			
			TempRecordSetMasterFromDatabase = ObjectRecordSetMaster.Unload();
			TempRecordSetMasterFromDatabase = TempRecordSetMasterFromDatabase.Copy(
				New Structure("TypeOfAccounting", CurrentTypeOfAccounting));
			
			RecordSetMasterBeforeEditObject.Load(TempRecordSetMasterFromDatabase);
			
			ValueToFormAttribute(RecordSetMasterBeforeEditObject, "RecordSetMasterBeforeEdit");
			
		EndIf;
		
	Else
		
		ObjectRecordSet = FormAttributeToValue("RecordSet");
		If CurrentAccountingEntriesRecorder = CurrentRef Then
			
			TempRecordSet = AccountingRegisters.AccountingJournalEntries.CreateRecordSet();
			TempRecordSet.Filter.Recorder.Set(CurrentAccountingEntriesRecorder);
			TempRecordSet.Read();
			
			TempRecordSetTable = TempRecordSet.Unload();
			Rows = TempRecordSetTable.FindRows(New Structure("TypeOfAccounting", CurrentTypeOfAccounting));
			
			For Each Row In Rows Do
				
				TempRecordSetTable.Delete(Row);
				
			EndDo;
			
			For Each Rec In RecordSet Do
				
				NewRow = TempRecordSetTable.Add();
				FillPropertyValues(NewRow, Rec);
				
			EndDo;
			
			TempRecordSet.Load(TempRecordSetTable);
			TempRecordSet.Write();
			
		Else
			
			ObjectRecordSet.Filter.Recorder.Set(CurrentAccountingEntriesRecorder);
			ObjectRecordSet.Write();
			
		EndIf;
		
		RecordSetBeforeEditObject = FormAttributeToValue("RecordSetBeforeEdit");
		
		TempRecordSetFromDatabase = ObjectRecordSet.Unload();
		TempRecordSetFromDatabase = TempRecordSetFromDatabase.Copy(
			New Structure("TypeOfAccounting", CurrentTypeOfAccounting));
		
		RecordSetBeforeEditObject.Load(TempRecordSetFromDatabase);
		
		ValueToFormAttribute(RecordSetBeforeEditObject, "RecordSetBeforeEdit");
		
	EndIf;
	
	UpdateRecordSet();
	
EndProcedure

&AtServer
Procedure UpdateRecordSet()
	
	CommonRecordSetsTable = FormAttributeToValue("CommonRecordSets");
	
	FilterSrtucture = New Structure;
	FilterSrtucture.Insert("Ref"				, CurrentRef);
	FilterSrtucture.Insert("TypeOfAccounting"	, CurrentTypeOfAccounting);
	FoundRows = CommonRecordSetsTable.FindRows(FilterSrtucture);
	
	TempRecordSet = AccountingRegisters.AccountingJournalEntries.CreateRecordSet();
	TempRecordSet.Filter.Recorder.Value	 = CurrentAccountingEntriesRecorder;
	TempRecordSet.Filter.Recorder.Use	 = True;
	TempRecordSet.Read();
	TempRecordSetTable = TempRecordSet.Unload();
	
	TempRecordSetMaster = AccountingRegisters.AccountingJournalEntriesCompound.CreateRecordSet();
	TempRecordSetMasterFilterRecorder = TempRecordSetMaster.Filter.Recorder;
	TempRecordSetMasterFilterRecorder.Value	= CurrentAccountingEntriesRecorder;
	TempRecordSetMasterFilterRecorder.Use	= True;
	TempRecordSetMaster.Read();
	TempRecordSetMasterTable = TempRecordSetMaster.Unload();
	
	TempRecordSetMasterSimple = AccountingRegisters.AccountingJournalEntriesSimple.CreateRecordSet();
	TempRecordSetMasterSimpleFilterRecorder = TempRecordSetMasterSimple.Filter.Recorder;
	TempRecordSetMasterSimpleFilterRecorder.Value	= CurrentAccountingEntriesRecorder;  
	TempRecordSetMasterSimpleFilterRecorder.Use		= True;
	TempRecordSetMasterSimple.Read();
	TempRecordSetMasterSimpleTable = TempRecordSetMasterSimple.Unload();
	
	For Each Row In FoundRows Do
		
		MasterRecordSetStructure = GetMasterRecordSet(Row.ChartOfAccounts);
		
		If MasterRecordSetStructure.MasterRecordSetSimple Then
			
			RecordSetSimple = AccountingRegisters.AccountingJournalEntriesSimple.CreateRecordSet();
			RecordSetSimple.Filter.Recorder.Set(Row.AccountingEntriesRecorder);
			RecordSetSimple.Read();
			
			RecordSetTable = AccountingApprovalServer.GetRecordSetSimpleByRecorder(Row.AccountingEntriesRecorder);
			
			MasterAccounting.FillMiscFields(RecordSetTable);
			
			Row.RecordSet = RecordSetTable.Copy(New Structure("TypeOfAccounting", Row.TypeOfAccounting));
			
			Row.IsClosingPeriod = PeriodClosingDates.DataChangesDenied(RecordSetSimple);
			
		ElsIf MasterRecordSetStructure.MasterRecordSet Then
			
			RecordSetCompound = AccountingRegisters.AccountingJournalEntriesCompound.CreateRecordSet();
			RecordSetCompound.Filter.Recorder.Set(Row.AccountingEntriesRecorder);
			RecordSetCompound.Read();
			
			RecordSetTable = AccountingApprovalServer.GetRecordSetMasterByRecorder(Row.AccountingEntriesRecorder);
			
			MasterAccounting.FillMiscFields(RecordSetTable);
			
			Row.RecordSet = RecordSetTable.Copy(New Structure("TypeOfAccounting", Row.TypeOfAccounting));
			Row.IsClosingPeriod = PeriodClosingDates.DataChangesDenied(RecordSetCompound);
			
		Else
			
			FilterSrtucture	 = New Structure("Recorder, TypeOfAccounting", Row.Ref, Row.TypeOfAccounting);
			Row.RecordSet	 = TempRecordSetTable.Copy(FilterSrtucture);
			
		EndIf;
		
	EndDo;
	
	ValueToFormAttribute(CommonRecordSetsTable, "CommonRecordSets");
	Modified = False;
	
EndProcedure

&AtServer
Procedure RereadAtServer()
	
	If MasterRecordSetSimple Then
		
		RecordSetMasterFromDatabaseTable =
			AccountingApprovalServer.GetRecordSetSimpleByRecorder(CurrentAccountingEntriesRecorder);
		RecordSetMasterFromDatabaseTableFiltered = RecordSetMasterFromDatabaseTable.Copy(New Structure("TypeOfAccounting", CurrentTypeOfAccounting));
		
		RecordSetSimpleBeforeEdit.Load(RecordSetMasterFromDatabaseTableFiltered);
		RecordSetMasterSimple.Load(RecordSetMasterFromDatabaseTableFiltered);
		
	ElsIf MasterRecordSet Then
		
		RecordSetMasterFromDatabaseTable =
			AccountingApprovalServer.GetRecordSetMasterByRecorder(CurrentAccountingEntriesRecorder);
		RecordSetMasterFromDatabaseTableFiltered = RecordSetMasterFromDatabaseTable.Copy(New Structure("TypeOfAccounting", CurrentTypeOfAccounting));
			
		RecordSetMasterBeforeEdit.Load(RecordSetMasterFromDatabaseTableFiltered);
		RecordSetMaster.Load(RecordSetMasterFromDatabaseTableFiltered);
		
	Else
		RecordSetFromDatabase = AccountingRegisters.AccountingJournalEntries.CreateRecordSet();
		RecordSetFromDatabase.Filter.Recorder.Set(CurrentAccountingEntriesRecorder);
		RecordSetFromDatabase.Read();
		RecordSetFromDatabaseTable = RecordSetFromDatabase.Unload();
		
		RecordSetBeforeEdit.Load(RecordSetFromDatabaseTable);
		RecordSet.Load(RecordSetFromDatabaseTable);
	EndIf;
	
	UpdateRecordSet();
	
EndProcedure

&AtServer
Function RecordSetHasBeenChanged()
	
	RecordSetFromDatabase = AccountingRegisters.AccountingJournalEntries.CreateRecordSet();
	RecordSetFromDatabase.Filter.Recorder.Set(CurrentAccountingEntriesRecorder);
	RecordSetFromDatabase.Read();
	
	RecordSetCount = RecordSetFromDatabase.Count();
	
	RecordSetBeforeEditObject = FormAttributeToValue("RecordSetBeforeEdit");
	If RecordSetCount <> RecordSetBeforeEditObject.Count() Then
		Return True;
	EndIf;

	Query = New Query;
	Query.Text = 
	"SELECT TOP 0
	|	AccountingJournalEntries.Period AS Period,
	|	AccountingJournalEntries.Recorder AS Recorder,
	|	AccountingJournalEntries.Active AS Active,
	|	AccountingJournalEntries.AccountDr AS AccountDr,
	|	AccountingJournalEntries.AccountCr AS AccountCr,
	|	AccountingJournalEntries.Company AS Company,
	|	AccountingJournalEntries.PlanningPeriod AS PlanningPeriod,
	|	AccountingJournalEntries.CurrencyDr AS CurrencyDr,
	|	AccountingJournalEntries.CurrencyCr AS CurrencyCr,
	|	AccountingJournalEntries.Amount AS Amount,
	|	AccountingJournalEntries.AmountCurDr AS AmountCurDr,
	|	AccountingJournalEntries.AmountCurCr AS AmountCurCr,
	|	AccountingJournalEntries.Content AS Content,
	|	AccountingJournalEntries.OfflineRecord AS OfflineRecord
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS AccountingJournalEntries";
	
	ResultTable = Query.Execute().Unload();
	
	For Count = 0 To RecordSetCount - 1 Do
		For Each Column In ResultTable.Columns Do
			
			If (Not ValueIsFilled(RecordSetFromDatabase[Count][Column.Name])
				And Not ValueIsFilled(RecordSetBeforeEditObject[Count][Column.Name]))
				Or Column.Name = "LineNumber" Then
				Continue;
			EndIf;
			
			If RecordSetFromDatabase[Count][Column.Name] <> RecordSetBeforeEditObject[Count][Column.Name] Then
				Return True;
			EndIf;
			
		EndDo;
	EndDo;
	
	Return False;
	
EndFunction

&AtServer
Function RecordSetMasterHasBeenChanged()
	
	RecordSetMasterFromDatabase = AccountingRegisters.AccountingJournalEntriesCompound.CreateRecordSet();
	RecordSetMasterFromDatabase.Filter.Recorder.Set(CurrentAccountingEntriesRecorder);
	RecordSetMasterFromDatabase.Read();
	
	TempRecordSetMasterFromDatabase = RecordSetMasterFromDatabase.Unload();
	TempRecordSetMasterFromDatabase = TempRecordSetMasterFromDatabase.Copy(
		New Structure("TypeOfAccounting", CurrentTypeOfAccounting));
	
	RecordSetMasterCount = TempRecordSetMasterFromDatabase.Count();
	
	RecordSetMasterBeforeEditObject = FormAttributeToValue("RecordSetMasterBeforeEdit");
	If RecordSetMasterCount <> RecordSetMasterBeforeEditObject.Count() Then
		Return True;
	EndIf;

	Query = New Query;
	Query.Text = 
	"SELECT TOP 0
	|	AccountingJournalEntriesCompound.Period AS Period,
	|	AccountingJournalEntriesCompound.Recorder AS Recorder,
	|	AccountingJournalEntriesCompound.Active AS Active,
	|	AccountingJournalEntriesCompound.Account AS Account,
	|	AccountingJournalEntriesCompound.Company AS Company,
	|	AccountingJournalEntriesCompound.PlanningPeriod AS PlanningPeriod,
	|	AccountingJournalEntriesCompound.Currency AS Currency,
	|	AccountingJournalEntriesCompound.Amount AS Amount,
	|	AccountingJournalEntriesCompound.AmountCur AS AmountCur,
	|	AccountingJournalEntriesCompound.Content AS Content,
	|	AccountingJournalEntriesCompound.OfflineRecord AS OfflineRecord,
	|	AccountingJournalEntriesCompound.Status AS Status,
	|	AccountingJournalEntriesCompound.TypeOfAccounting AS TypeOfAccounting,
	|	AccountingJournalEntriesCompound.Quantity AS Quantity,
	|	AccountingJournalEntriesCompound.TransactionTemplate AS TransactionTemplate,
	|	AccountingJournalEntriesCompound.TransactionTemplateLineNumber AS TransactionTemplateLineNumber
	|FROM
	|	AccountingRegister.AccountingJournalEntriesCompound AS AccountingJournalEntriesCompound";
	
	ResultTable = Query.Execute().Unload();
	
	For Count = 0 To RecordSetMasterCount - 1 Do
		For Each Column In ResultTable.Columns Do
			
			If (Not ValueIsFilled(RecordSetMasterFromDatabase[Count][Column.Name])
				And Not ValueIsFilled(RecordSetMasterBeforeEditObject[Count][Column.Name]))
				Or Column.Name = "LineNumber" Then
				Continue;
			EndIf;
			
			If TempRecordSetMasterFromDatabase[Count][Column.Name] <> RecordSetMasterBeforeEditObject[Count][Column.Name] Then
				Return True;
			EndIf;
			
		EndDo;
	EndDo;
	
	Return False;
	
EndFunction

&AtServer
Function RecordSetSimpleHasBeenChanged()
	
	RecordSetMasterFromDatabase = AccountingRegisters.AccountingJournalEntriesSimple.CreateRecordSet();
	RecordSetMasterFromDatabase.Filter.Recorder.Set(CurrentAccountingEntriesRecorder);
	RecordSetMasterFromDatabase.Read();
	
	TempRecordSetMasterFromDatabase = RecordSetMasterFromDatabase.Unload();
	TempRecordSetMasterFromDatabase = TempRecordSetMasterFromDatabase.Copy(
		New Structure("TypeOfAccounting", CurrentTypeOfAccounting));
	
	RecordSetMasterCount = TempRecordSetMasterFromDatabase.Count();
	
	RecordSetMasterBeforeEditObject = FormAttributeToValue("RecordSetSimpleBeforeEdit");
	If RecordSetMasterCount <> RecordSetMasterBeforeEditObject.Count() Then
		Return True;
	EndIf;

	Query = New Query;
	Query.Text = 
	"SELECT TOP 0
	|	AccountingJournalEntriesSimple.Period AS Period,
	|	AccountingJournalEntriesSimple.Recorder AS Recorder,
	|	AccountingJournalEntriesSimple.Active AS Active,
	|	AccountingJournalEntriesSimple.Company AS Company,
	|	AccountingJournalEntriesSimple.PlanningPeriod AS PlanningPeriod,
	|	AccountingJournalEntriesSimple.Amount AS Amount,
	|	AccountingJournalEntriesSimple.Content AS Content,
	|	AccountingJournalEntriesSimple.OfflineRecord AS OfflineRecord,
	|	AccountingJournalEntriesSimple.AccountDr AS AccountDr,
	|	AccountingJournalEntriesSimple.AccountCr AS AccountCr,
	|	AccountingJournalEntriesSimple.CurrencyDr AS CurrencyDr,
	|	AccountingJournalEntriesSimple.CurrencyCr AS CurrencyCr,
	|	AccountingJournalEntriesSimple.Status AS Status,
	|	AccountingJournalEntriesSimple.TypeOfAccounting AS TypeOfAccounting,
	|	AccountingJournalEntriesSimple.AmountCurDr AS AmountCurDr,
	|	AccountingJournalEntriesSimple.AmountCurCr AS AmountCurCr,
	|	AccountingJournalEntriesSimple.QuantityDr AS QuantityDr,
	|	AccountingJournalEntriesSimple.QuantityCr AS QuantityCr,
	|	AccountingJournalEntriesSimple.TransactionTemplate AS TransactionTemplate,
	|	AccountingJournalEntriesSimple.TransactionTemplateLineNumber AS TransactionTemplateLineNumber
	|FROM
	|	AccountingRegister.AccountingJournalEntriesSimple AS AccountingJournalEntriesSimple";
	
	ResultTable = Query.Execute().Unload();
	
	For Count = 0 To RecordSetMasterCount - 1 Do
		For Each Column In ResultTable.Columns Do
			
			If (Not ValueIsFilled(RecordSetMasterFromDatabase[Count][Column.Name])
				And Not ValueIsFilled(RecordSetMasterBeforeEditObject[Count][Column.Name]))
				Or Column.Name = "LineNumber" Then
				Continue;
			EndIf;
			
			If TempRecordSetMasterFromDatabase[Count][Column.Name] <> RecordSetMasterBeforeEditObject[Count][Column.Name] Then
				Return True;
			EndIf;
			
		EndDo;
	EndDo;
	
	Return False;
	
EndFunction

&AtClient
Procedure AfterQuestionReread(Result, AdditionalParameters) Export 
	
	If Result = Reread Then
		RereadAtServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure QuestionSave(Status = Undefined) Export 
	
	AdditionalParameters = New Structure;
	If Status <> Undefined Then
		AdditionalParameters.Insert("Status", Status);
	EndIf;
	
	NotifyDescription = New NotifyDescription("AfterQuestionSave", ThisObject, AdditionalParameters);
	QuestionText = NStr("en = 'Data has been changed. Do you want to save the changes?'; ru = 'Данные были изменены. Сохранить изменения?';pl = 'Dane zostały zmienione. Czy chcesz zapisać zmiany?';es_ES = 'Los datos han sido cambiados. ¿Quiere guardar los cambios?';es_CO = 'Los datos han sido cambiados. ¿Quiere guardar los cambios?';tr = 'Veriler değiştirildi. Değişiklikleri kaydetmek istiyor musunuz?';it = 'I dati sono stati modificati. Salvare le modifiche?';de = 'Die Daten wurden geändert. Wollen Sie die Änderungen speichern?'");
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure AfterQuestionSave(Result, AdditionalParameters) Export 
	
	If Result = DialogReturnCode.Yes Then
		
		Cancel = False;
		
		WriteAtServer(MasterRecordSetSimple, MasterRecordSet, Cancel);
		
		If Cancel Then
			Return;
		EndIf;
		
		If AdditionalParameters.Property("Status") Then
			Status = AdditionalParameters.Status;
			SetNewStatus(True);
		EndIf;
		
	ElsIf Result = DialogReturnCode.No Then
		Modified = False;
	EndIf;
		
	GetAccountingEntries(CurrentRef, CurrentTypeOfAccounting, CurrentAccountingEntriesRecorder);
	
	If Items.DocumentList.CurrentRow <> CurrentKey Then
		Items.DocumentList.CurrentRow = CurrentKey;
		DocumentListOnActivateRow(Items.DocumentList);
	EndIf;
		
EndProcedure

&AtServer
Procedure AfterStatusChangingAtServer(ResultAddress) Export

	Result = GetFromTempStorage(ResultAddress);
	
	If TypeOf(Result) = Type("ValueTable")
		And Result.Count() Then
		FillPropertyValues(ThisObject, Result[0]);
	EndIf;

EndProcedure

&AtServer
Function RestoreOriginalEntries() Export
	
	Result = False;
	
	BeginTransaction();
	
	Try
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	AccountingTransactionDocuments.SourceDocument AS Ref,
		|	AccountingTransactionDocuments.TypeOfAccounting AS TypeOfAccounting,
		|	AccountingTransactionDocuments.AccountingEntriesRecorder AS AccountingEntriesRecorder,
		|	ChartsOfAccounts.TypeOfEntries AS TypeOfEntries,
		|	ChartsOfAccounts.ChartOfAccounts AS ChartOfAccounts,
		|	AccountingTransactionDocuments.ChartOfAccounts AS ChartOfAccountsID,
		|	DocumentAccountingEntriesStatuses.ApprovalDate AS ApprovalDate
		|FROM
		|	InformationRegister.AccountingTransactionDocuments AS AccountingTransactionDocuments
		|		LEFT JOIN InformationRegister.DocumentAccountingEntriesStatuses AS DocumentAccountingEntriesStatuses
		|		ON (DocumentAccountingEntriesStatuses.Recorder = AccountingTransactionDocuments.AccountingEntriesRecorder)
		|			AND (DocumentAccountingEntriesStatuses.Company = AccountingTransactionDocuments.Company)
		|			AND (DocumentAccountingEntriesStatuses.TypeOfAccounting = AccountingTransactionDocuments.TypeOfAccounting)
		|		LEFT JOIN Catalog.ChartsOfAccounts AS ChartsOfAccounts
		|		ON AccountingTransactionDocuments.ChartOfAccounts = ChartsOfAccounts.Ref
		|WHERE
		|	DocumentAccountingEntriesStatuses.Recorder = &Recorder";
		Query.SetParameter("Recorder", CurrentAccountingEntriesRecorder);
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		TemplateError = NStr("en = 'Entries for type of accounting %1 are approved. Cannot restore originals.'; ru = 'Проводки для типа бухгалтерского учета %1 уже утверждены. Не удалось восстановить первичные проводки.';pl = 'Wpisy dla typu rachunkowości %1 są zatwierdzane. Nie można ponownie zapisać oryginałów.';es_ES = 'Las entradas de diario de tipo de contabilidad %1 están aprobadas. No se pueden restablecer los originales.';es_CO = 'Las entradas de diario de tipo de contabilidad %1 están aprobadas. No se pueden restablecer los originales.';tr = '%1 muhasebe türü için girişler onaylandı. Orijinaller geri yüklenemez.';it = 'Voci per tipo di contabilità %1 approvate. Impossibile ripristinare le originali.';de = 'Buchungen für Typ der Buchhaltung %1 werden genehmigt. Fehler beim Wiederherstellen von Originalen.'");
		
		Rows = New Array;
		
		Cancel = False;
		
		SetPrivilegedMode(True);
		
		While SelectionDetailRecords.Next() Do
			
			DataKey = New Structure("Ref, TypeOfAccounting, AccountingEntriesRecorder, ChartOfAccounts");
			FillPropertyValues(DataKey, SelectionDetailRecords);
			DataKey.ChartOfAccounts = SelectionDetailRecords.ChartOfAccountsID;
			Rows.Add(New DynamicListRowKey(DataKey));
			
			If SelectionDetailRecords.ChartOfAccounts = Enums.ChartsOfAccounts.MasterChartOfAccounts Then
				If SelectionDetailRecords.TypeOfEntries = Enums.ChartsOfAccountsTypesOfEntries.Compound Then
					RestoreOriginalEntriesMasterContinue(SelectionDetailRecords, Cancel);
				Else
					RestoreOriginalEntriesMasterSimpleContinue(SelectionDetailRecords, Cancel);
				EndIf;
			Else
				RestoreOriginalEntriesContinue(SelectionDetailRecords);
			EndIf;
			
		EndDo;
		
		SetPrivilegedMode(False);
		
		Result = Not Cancel;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'An error occurred while changing the accounting entries status for document %1 due to %2.'; ru = 'При изменении состояния бухгалтерских проводок в документе %1 произошла ошибка. Причина: %2.';pl = 'Wystąpił błąd podczas zmiany statusu wpisów księgowych dla dokumentu %1 z powodu %2.';es_ES = 'Ha ocurrido un error al cambiar el estado de las entradas contables para el documento %1 a causa de %2.';es_CO = 'Ha ocurrido un error al cambiar el estado de las entradas contables para el documento %1 a causa de %2.';tr = '%1 belgesi için muhasebe girişleri durumu değiştirilirken %2 sebebiyle hata oluştu.';it = 'Si è verificato un errore durante la modifica dello stato degli inserimenti contabili per il documento %1 a causa di %2.';de = 'Ein Fehler trat auf beim Ändern des Buchhaltungsstatus für Dokument %1 aufgrund von %2.'",
				DefaultLanguageCode),
			SelectionDetailRecords.Ref,
			DetailErrorDescription(ErrorInfo()));
		
		CommonClientServer.MessageToUser(ErrorInfo().Description);
			
		WriteLogEvent(NStr("en = 'Restore the original accounting entries'; ru = 'Восстановить исходные бухгалтерские проводки';pl = 'Przywróć oryginalne wpisy księgowe';es_ES = 'Restablecer las entradas contables originales';es_CO = 'Restablecer las entradas contables originales';tr = 'Orijinal muhasebe girişlerini geri yükle';it = 'Ripristinare gli inserimenti contabili originali';de = 'Originalbuchhaltungseinträge wiederherstellen'", DefaultLanguageCode),
			EventLogLevel.Error,
			SelectionDetailRecords.Ref.Metadata(),
			,
			ErrorDescription);
		
	EndTry;
	
	Return Result;
	
EndFunction

&AtServer
Procedure RestoreOriginalEntriesContinue(SelectionDetailRecords)
	
	RecordSet.Clear();
	RecordSet.Filter.Recorder.Value = SelectionDetailRecords.AccountingEntriesRecorder;
	RecordSet.Filter.Recorder.Use	= True;
	
	DocumentObject = SelectionDetailRecords.Ref.GetObject();
	AdditionalProperties = DocumentObject.AdditionalProperties;
	DriveServer.InitializeAdditionalPropertiesForPosting(SelectionDetailRecords.Ref, AdditionalProperties);
	
	Cancel = False;
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(SelectionDetailRecords.Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.Insert("PostingTypeOfAccounting", CurrentTypeOfAccounting);
	
	If SelectionDetailRecords.AccountingEntriesRecorder <> SelectionDetailRecords.Ref Then
		AdditionalProperties.ForPosting.Insert("AccountingTransactionDocumentGeneration", True);
	EndIf;
	
	ObjectManager = Common.ObjectManagerByRef(SelectionDetailRecords.Ref);
	ObjectManager.InitializeDocumentData(SelectionDetailRecords.Ref, AdditionalProperties);
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableAccountingJournalEntries") Then
		
		TableAccountingJournalEntries = AdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
		
		For Each Row In TableAccountingJournalEntries Do
			Record = RecordSet.Add();
			FillPropertyValues(Record, Row);
			Record.Recorder = SelectionDetailRecords.AccountingEntriesRecorder;
			Record.Active = True;
		EndDo;
		
		FormAttributeToValue("RecordSet").Write();
		
	EndIf;
	
	WriteAtServer();
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

&AtServer
Procedure RestoreOriginalEntriesMasterContinue(SelectionDetailRecords, Cancel, Simple = False)
	
	DocumentObject = SelectionDetailRecords.Ref.GetObject();
	AdditionalProperties = DocumentObject.AdditionalProperties;
	DriveServer.InitializeAdditionalPropertiesForPosting(SelectionDetailRecords.Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(SelectionDetailRecords.Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.Insert("PostingTypeOfAccounting", SelectionDetailRecords.TypeOfAccounting);
	
	If SelectionDetailRecords.AccountingEntriesRecorder <> SelectionDetailRecords.Ref Then
		AdditionalProperties.ForPosting.Insert("AccountingTransactionDocumentGeneration", True);
	EndIf;
	
	ObjectManager = Common.ObjectManagerByRef(SelectionDetailRecords.Ref);
	ObjectManager.InitializeDocumentData(SelectionDetailRecords.Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	If Simple Then
		
		RecordSetMasterSimple.Clear();
		
		If AdditionalProperties.TableForRegisterRecords.Property("TableAccountingJournalEntriesSimple") Then
			
			TableAccountingJournalEntriesSimple = AdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntriesSimple;
			
			If SelectionDetailRecords.AccountingEntriesRecorder <> Undefined Then
				TempRecordSetMaster = AccountingRegisters.AccountingJournalEntriesSimple.CreateRecordSet();
				
				TempRecordSetMaster.Filter.Recorder.Value = SelectionDetailRecords.AccountingEntriesRecorder;
				TempRecordSetMaster.Filter.Recorder.Use = True;
				
				For Each Row In TableAccountingJournalEntriesSimple Do
					
					Record = TempRecordSetMaster.Add();
					FillPropertyValues(Record, Row);
					Record.Recorder = SelectionDetailRecords.AccountingEntriesRecorder;
					Record.Active = True;
					
					If ValueIsFilled(Row.ExtDimensionTypeCr4) Or ValueIsFilled(Row.ExtDimensionCr4) Then
						Record.ExtDimensionsCr.Insert(Row.ExtDimensionTypeCr4, Row.ExtDimensionCr4);
					EndIf;
					If ValueIsFilled(Row.ExtDimensionTypeCr3) Or ValueIsFilled(Row.ExtDimensionCr3) Then
						Record.ExtDimensionsCr.Insert(Row.ExtDimensionTypeCr3, Row.ExtDimensionCr3);
					EndIf;
					If ValueIsFilled(Row.ExtDimensionTypeCr2) Or ValueIsFilled(Row.ExtDimensionCr2) Then
						Record.ExtDimensionsCr.Insert(Row.ExtDimensionTypeCr2, Row.ExtDimensionCr2);
					EndIf;
					If ValueIsFilled(Row.ExtDimensionTypeCr1) Or ValueIsFilled(Row.ExtDimensionCr1) Then
						Record.ExtDimensionsCr.Insert(Row.ExtDimensionTypeCr1, Row.ExtDimensionCr1);
					EndIf;
					
					If ValueIsFilled(Row.ExtDimensionTypeDr4) Or ValueIsFilled(Row.ExtDimensionDr4) Then
						Record.ExtDimensionsDr.Insert(Row.ExtDimensionTypeDr4, Row.ExtDimensionDr4);
					EndIf;
					If ValueIsFilled(Row.ExtDimensionTypeDr3) Or ValueIsFilled(Row.ExtDimensionDr3) Then
						Record.ExtDimensionsDr.Insert(Row.ExtDimensionTypeDr3, Row.ExtDimensionDr3);
					EndIf;
					If ValueIsFilled(Row.ExtDimensionTypeDr2) Or ValueIsFilled(Row.ExtDimensionDr2) Then
						Record.ExtDimensionsDr.Insert(Row.ExtDimensionTypeDr2, Row.ExtDimensionDr2);
					EndIf;
					If ValueIsFilled(Row.ExtDimensionTypeDr1) Or ValueIsFilled(Row.ExtDimensionDr1) Then
						Record.ExtDimensionsDr.Insert(Row.ExtDimensionTypeDr1, Row.ExtDimensionDr1);
					EndIf;
				
					If Row.TypeOfAccounting = SelectionDetailRecords.TypeOfAccounting Then
						
						RecordRecordSetMaster = RecordSetMasterSimple.Add();
						FillPropertyValues(RecordRecordSetMaster, Row);
						RecordRecordSetMaster.Recorder = SelectionDetailRecords.AccountingEntriesRecorder;
					EndIf;
					
				EndDo;
				
				TempRecordSetMaster.Write();
			EndIf;
			
		EndIf;
	Else
		
		RecordSetMaster.Clear();
		
		If AdditionalProperties.TableForRegisterRecords.Property("TableAccountingJournalEntriesCompound") Then
			
			TableAccountingJournalEntriesCompound = AdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntriesCompound;
			
			If SelectionDetailRecords.AccountingEntriesRecorder <> Undefined Then
				TempRecordSetMaster = AccountingRegisters.AccountingJournalEntriesCompound.CreateRecordSet();
				
				TempRecordSetMaster.Filter.Recorder.Value = SelectionDetailRecords.AccountingEntriesRecorder;
				TempRecordSetMaster.Filter.Recorder.Use = True;
				
				For Each Row In TableAccountingJournalEntriesCompound Do
					
					Record = TempRecordSetMaster.Add();
					FillPropertyValues(Record, Row);
					Record.Recorder = SelectionDetailRecords.AccountingEntriesRecorder;
					Record.Active = True;
					
					If Row.TypeOfAccounting = SelectionDetailRecords.TypeOfAccounting Then
						
						RecordRecordSetMaster = RecordSetMaster.Add();
						FillPropertyValues(RecordRecordSetMaster, Row);
						RecordRecordSetMaster.Recorder = SelectionDetailRecords.AccountingEntriesRecorder;
						
						If RecordRecordSetMaster.RecordType = AccountingRecordType.Credit Then
							RecordRecordSetMaster.AmountCurCr = RecordRecordSetMaster.AmountCur;
							RecordRecordSetMaster.AmountCr = RecordRecordSetMaster.Amount;
							RecordRecordSetMaster.RecordSetPicture = 2;
						Else
							RecordRecordSetMaster.AmountCurDr = RecordRecordSetMaster.AmountCur;
							RecordRecordSetMaster.AmountDr = RecordRecordSetMaster.Amount;
							RecordRecordSetMaster.RecordSetPicture = 1;
						EndIf;
						
					EndIf;
					
				EndDo;
				
				TempRecordSetMaster.Write();
			EndIf;
			
		EndIf;
	EndIf;
	
	WriteAtServer(Simple, True);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

&AtServer
Procedure RestoreOriginalEntriesMasterSimpleContinue(SelectionDetailRecords, Cancel)
	
	RestoreOriginalEntriesMasterContinue(SelectionDetailRecords, Cancel, True);
	
EndProcedure

&AtServer
Procedure RefreshTypesAtServer()
	
	FilterStructure = New Structure;
	FilterStructure.Insert("OldTypes"			, Types);
	FilterStructure.Insert("PeriodStart"		, FilterPeriodOfSourceDocuments.StartDate);
	FilterStructure.Insert("PeriodEnd"			, FilterPeriodOfSourceDocuments.EndDate);
	FilterStructure.Insert("Company"			, FilterCompany);
	FilterStructure.Insert("TypeOfAccounting"	, FilterTypeOfAccounting);
	
	Types = AccountingApprovalServer.GetDocumentTypes(FilterStructure);
	
EndProcedure

&AtServer
Function CheckRowsAtServer(Rows)
	
	Result = New Structure;
	
	RowsTable = New ValueTable;
	RowsTable.Columns.Add("Ref"							, Metadata.DefinedTypes.AccountingEntriesRecorder.Type);
	RowsTable.Columns.Add("AccountingEntriesRecorder"	, Metadata.DefinedTypes.AccountingEntriesRecorder.Type);
	RowsTable.Columns.Add("TypeOfAccounting"			, New TypeDescription("CatalogRef.TypesOfAccounting"));
	
	For Each Row In Rows Do
		NewRow = RowsTable.Add();
		FillPropertyValues(NewRow, Row);
	EndDo;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	RecordersTable.AccountingEntriesRecorder AS AccountingEntriesRecorder,
	|	RecordersTable.TypeOfAccounting AS TypeOfAccounting,
	|	RecordersTable.Ref AS Ref
	|INTO Recorders
	|FROM
	|	&Recorders AS RecordersTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Recorders.Ref AS Recorder,
	|	Recorders.AccountingEntriesRecorder AS AccountingEntriesRecorder,
	|	Recorders.TypeOfAccounting AS TypeOfAccounting,
	|	DocumentAccountingEntriesStatuses.AdjustedManually AS AdjustedManually,
	|	DocumentAccountingEntriesStatuses.EntriesGenerated AS EntriesGenerated,
	|	DocumentAccountingEntriesStatuses.ApprovalDate AS ApprovalDate
	|INTO CheckingData
	|FROM
	|	Recorders AS Recorders
	|		INNER JOIN InformationRegister.DocumentAccountingEntriesStatuses AS DocumentAccountingEntriesStatuses
	|		ON Recorders.Ref = DocumentAccountingEntriesStatuses.Recorder
	|			AND Recorders.TypeOfAccounting = DocumentAccountingEntriesStatuses.TypeOfAccounting
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CheckingData.Recorder AS Ref,
	|	CheckingData.AccountingEntriesRecorder AS AccountingEntriesRecorder,
	|	CheckingData.TypeOfAccounting AS TypeOfAccounting
	|FROM
	|	CheckingData AS CheckingData
	|WHERE
	|	CheckingData.ApprovalDate > DATETIME(1, 1, 1, 0, 0, 0)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CheckingData.Recorder AS Ref,
	|	CheckingData.AccountingEntriesRecorder AS AccountingEntriesRecorder,
	|	CheckingData.TypeOfAccounting AS TypeOfAccounting
	|FROM
	|	CheckingData AS CheckingData
	|WHERE
	|	CheckingData.AdjustedManually
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CheckingData.Recorder AS Ref,
	|	CheckingData.AccountingEntriesRecorder AS AccountingEntriesRecorder,
	|	CheckingData.TypeOfAccounting AS TypeOfAccounting
	|FROM
	|	CheckingData AS CheckingData
	|WHERE
	|	CheckingData.EntriesGenerated = &EntriesGenerated
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CheckingData.Recorder AS Ref,
	|	CheckingData.TypeOfAccounting AS TypeOfAccounting
	|FROM
	|	CheckingData AS CheckingData
	|WHERE
	|	CheckingData.Recorder = CheckingData.AccountingEntriesRecorder";
	
	Query.SetParameter("Recorders"			, RowsTable);
	Query.SetParameter("EntriesGenerated"	, Enums.AccountingEntriesGenerationStatus.Generated);
	QueryResult = Query.ExecuteBatch();
	
	Result.Insert("Approved"		, Not QueryResult[2].IsEmpty());
	Result.Insert("AdjustedManually", Not QueryResult[3].IsEmpty());
	Result.Insert("Generated"		, Not QueryResult[4].IsEmpty());
	Result.Insert("SourceGenerated"	, Not QueryResult[5].IsEmpty());
	
	If Result.Approved Then
		ApprovedDocs.Load(QueryResult[2].Unload());
	EndIf;
	
	If Result.AdjustedManually Then
		AdjustedManuallyDocs.Load(QueryResult[3].Unload());
	EndIf;
	
	If Result.Generated Then
		GeneratedDocs.Load(QueryResult[4].Unload());
	EndIf;
	
	If Result.SourceGenerated Then
		SourceGeneratedDocs.Load(QueryResult[5].Unload());
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure SendMessagesToUser(Result, Rows, TypeOfMessages)
	
	If TypeOfMessages = "Approved" Then
		
		Mode = QuestionDialogMode.YesNo;
		TextMessage = Nstr("en = 'Cannot generate accounting entries. The selected documents include the documents with accounting entries already generated and approved.'; ru = 'Не удалось создать бухгалтерские проводки. Выбранные документы включают документы с уже созданными и утвержденными бухгалтерскими проводками.';pl = 'Nie można wygenerować wpisów księgowych. Wybrane dokumenty obejmują dokumenty z już wygenerowanymi i zatwierdzonymi wpisami księgowymi.';es_ES = 'No se pueden generar entradas contables. Los documentos seleccionados incluyen los documentos con entradas contables ya generadas y aprobadas.';es_CO = 'No se pueden generar entradas contables. Los documentos seleccionados incluyen los documentos con entradas contables ya generadas y aprobadas.';tr = 'Muhasebe girişleri oluşturulamıyor. Seçilen belgeler, zaten oluşturulup onaylanmış muhasebe girişlerine sahip belgeler içeriyor.';it = 'Impossibile generare le voci di contabilità. I documenti selezionati includono i documenti con voci di contabilità già creati e approvati.';de = 'Fehler beim Generieren von Buchungen. Die ausgewählten Dokumente enthalten die Dokumente mit Buchungen bereits generiert und genehmigt.'");
		
		ShowMessageBox(, TextMessage, 0, "Error");
		DriveServer.ShowMessageAboutError(, TextMessage);
		
	ElsIf TypeOfMessages = "AdjustedManuallyGenerated" Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("Result"	, Result);
		AdditionalParameters.Insert("Rows"		, Rows);
		
		Notification	= New NotifyDescription("SendMessagesToUserEnd", ThisObject, AdditionalParameters);
		Mode			= QuestionDialogMode.YesNo;
		QueryMessage = NStr("en = 'The selected documents include the documents with accounting entries generated and the documents with accounting entries generated and manually adjusted. The adjustments will be canceled. For both document lists, the accounting entries will be replaced. Continue?'; ru = 'Выбранные документы включают документы со сформированными бухгалтерскими проводками и документы с бухгалтерскими проводками, сформированными и скорректированными вручную. Корректировки будут отменены. Для обоих списков документов будут изменены бухгалтерские проводки. Продолжить?';pl = 'Wybrane dokumenty obejmują dokumenty z wygenerowanymi wpisami księgowymi i dokumentami z wygenerowanymi i ręcznie dostosowanymi wpisami księgowymi. Korekty zostaną anulowane. Dla obu list dokumentów, wpisy księgowe zostaną zastąpione. Kontynuować?';es_ES = 'Los documentos seleccionados incluyen los documentos con entradas de diario generadas y ajustadas manualmente. Los ajustes se cancelarán. En ambas listas de documentos se sustituirán las entradas contables. ¿Continuar?';es_CO = 'Los documentos seleccionados incluyen los documentos con entradas de diario generadas y ajustadas manualmente. Los ajustes se cancelarán. En ambas listas de documentos se sustituirán las entradas contables. ¿Continuar?';tr = 'Seçilen belgeler oluşturulmuş muhasebe girişleri olan belgeleri ve oluşturulup manuel olarak düzeltilmiş muhasebe girişleri olan belgeleri içeriyor. Düzeltmeler iptal edilecek. Her iki belge listesi için, muhasebe girişleri değiştirilecek. Devam edilsin mi?';it = 'I documenti selezionati includono i documenti con voci di contabilità create e quelli corretti manualmente. Le correzioni saranno annullate. Per entrambi gli elenchi del documento, le voci di contabilità saranno sostituite. Continuare?';de = 'Die ausgewählten Dokumente enthalten die Dokumente mit Buchungen generiert und die Dokumente mit Buchungen generiert und manuell angepasst. Die Anpassungen werden gelöscht. Für beide Dokumentenlisten, werden die Buchungen ersetzt. Weiter?'");
		
		ShowQueryBox(Notification, QueryMessage, Mode, 0);
		
		ErrorMessageTemplate = NStr("en = 'Document: %1, Type of accounting: %2. Entries adjusted manually'; ru = 'Документ: %1, Тип бухгалтерского учета: %2. Проводки скорректированы вручную';pl = 'Dokument: %1, Typ rachunkowości: %2. Wpisy zostały skorygowane ręcznie';es_ES = 'Documento: %1, Tipo de contabilidad: %2. Entradas de diario ajustadas manualmente';es_CO = 'Documento: %1, Tipo de contabilidad: %2. Entradas de diario ajustadas manualmente';tr = 'Belge: %1, Muhasebe türü: %2. Girişler manuel olarak düzeltildi';it = 'Documento: %1. Tipo di contabilità: %2. Voci corrette manualmente';de = 'Dokument: %1, Typ der Buchhaltung: %2. Buchungen manuell angepasst'");
		For Each Row In AdjustedManuallyDocs Do
			
			Filter = New Structure;
			Filter.Insert("Ref"							, Row.Ref);
			Filter.Insert("AccountingEntriesRecorder"	, Row.AccountingEntriesRecorder);
			Filter.Insert("TypeOfAccounting"			, Row.TypeOfAccounting);
			
			RowsGenerated = GeneratedDocs.FindRows(Filter);
			If RowsGenerated.Count() > 0 Then
				ErrorMessageTemplate = NStr("en = 'Document: %1, Type of accounting: %2. Entries generated and adjusted manually'; ru = 'Документ: %1, Тип бухгалтерского учета: %2. Проводки сформированы и скорректированы вручную';pl = 'Dokument: %1, Typ rachunkowości: %2. Wpisy zostały wygenerowane i skorygowane ręcznie';es_ES = 'Documento: %1, Tipo de contabilidad: %2. Entradas de diario generadas y ajustadas manualmente';es_CO = 'Documento: %1, Tipo de contabilidad: %2. Entradas de diario generadas y ajustadas manualmente';tr = 'Belge: %1, Muhasebe türü: %2. Girişler oluşturuldu ve manuel olarak düzeltildi';it = 'Documento: %1, Tipo di contabilità:%2. Voci create e corrette manualmente';de = 'Dokument: %1, Typ der Buchhaltung: %2. Buchungen generiert und manuell angepasst'");
			EndIf;
			
			ErrorMessage = StrTemplate(ErrorMessageTemplate, Row.Ref, Row.TypeOfAccounting);
			DriveServer.ShowMessageAboutError(, ErrorMessage);
			
		EndDo;
		
		ErrorMessageTemplate = NStr("en = 'Document: %1, Type of accounting: %2. Entries generated'; ru = 'Документ: %1, Тип бухгалтерского учета: %2. Проводки сформированы';pl = 'Dokument: %1, Typ rachunkowości: %2. Wpisy zostały wygenerowane';es_ES = 'Documento: %1, Tipo de contabilidad: %2. Entradas de diario generadas';es_CO = 'Documento: %1, Tipo de contabilidad: %2. Entradas de diario generadas';tr = 'Belge: %1, Muhasebe türü: %2. Girişler oluşturuldu';it = 'Documento: %1. Tipo di contabilità: %2. Voci create';de = 'Dokument: %1, Typ der Buchhaltung: %2. Buchungen generiert'");
		For Each Row In GeneratedDocs Do
			
			Filter = New Structure;
			Filter.Insert("Ref"							, Row.Ref);
			Filter.Insert("AccountingEntriesRecorder"	, Row.AccountingEntriesRecorder);
			Filter.Insert("TypeOfAccounting"			, Row.TypeOfAccounting);
			
			RowsAdjustedManually = AdjustedManuallyDocs.FindRows(Filter);
			If RowsAdjustedManually.Count() > 0 Then
				Continue;
			EndIf;
			
			ErrorMessage = StrTemplate(ErrorMessageTemplate, Row.Ref, Row.TypeOfAccounting);
			DriveServer.ShowMessageAboutError(, ErrorMessage);
			
		EndDo;
		
	ElsIf TypeOfMessages = "AdjustedManually" Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("Result"	, Result);
		AdditionalParameters.Insert("Rows"		, Rows);
		
		Notification = New NotifyDescription("SendMessagesToUserEnd", ThisObject, AdditionalParameters);
		Mode		 = QuestionDialogMode.YesNo;
		QueryMessage = NStr("en = 'The selected documents include the documents with accounting entries manually adjusted. The adjustments will be canceled. The accounting entries will be replaced. Continue?'; ru = 'Выбранные документы включают документы с бухгалтерскими проводками, скорректированными вручную. Корректировки будут отменены, а бухгалтерские проводки – заменены. Продолжить?';pl = 'Wybrane dokumenty obejmują dokumenty z ręcznie skorygowanymi wpisami księgowymi. Wpisy księgowe zostaną zastąpione. Kontynuować?';es_ES = 'Los documentos seleccionados incluyen los documentos con entradas de diario ajustadas manualmente. Los ajustes se cancelarán. Las entradas de diario serán reemplazadas. ¿Continuar?';es_CO = 'Los documentos seleccionados incluyen los documentos con entradas de diario ajustadas manualmente. Los ajustes se cancelarán. Las entradas de diario serán reemplazadas. ¿Continuar?';tr = 'Seçilen belgeler manuel olarak düzeltilmiş muhasebe girişleri olan belgeler içeriyor. Düzeltmeler iptal edilecek. Muhasebe girişleri değiştirilecek. Devam edilsin mi?';it = 'I documenti selezionati includono documenti con voci di contabilità corrette manualmente. Le correzioni saranno annullate e sostituite. Continuare?';de = 'Die ausgewählten Dokumente enthalten die Dokumente mit Buchungen manuell angepasst. Die Anpassungen werden gelöscht. Die Buchungen werden ersetzt. Weiter?'");
		
		ShowQueryBox(Notification, QueryMessage, Mode, 0);
		
		ErrorMessageTemplate = NStr("en = 'Document: %1, Type of accounting: %2. Entries adjusted manually'; ru = 'Документ: %1, Тип бухгалтерского учета: %2. Проводки скорректированы вручную';pl = 'Dokument: %1, Typ rachunkowości: %2. Wpisy zostały skorygowane ręcznie';es_ES = 'Documento: %1, Tipo de contabilidad: %2. Entradas de diario ajustadas manualmente';es_CO = 'Documento: %1, Tipo de contabilidad: %2. Entradas de diario ajustadas manualmente';tr = 'Belge: %1, Muhasebe türü: %2. Girişler manuel olarak düzeltildi';it = 'Documento: %1. Tipo di contabilità: %2. Voci corrette manualmente';de = 'Dokument: %1, Typ der Buchhaltung: %2. Buchungen manuell angepasst'");
		For Each Row In AdjustedManuallyDocs Do
			
			ErrorMessage = StrTemplate(ErrorMessageTemplate, Row.Ref, Row.TypeOfAccounting);
			DriveServer.ShowMessageAboutError(, ErrorMessage);
			
		EndDo;
		
	ElsIf TypeOfMessages = "Generated" Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("Result"	, Result);
		AdditionalParameters.Insert("Rows"		, Rows);
		
		Notification = New NotifyDescription("SendMessagesToUserEnd", ThisObject, AdditionalParameters);
		Mode		 = QuestionDialogMode.YesNo;
		QueryMessage = NStr("en = 'The selected documents include the documents with accounting entries generated. These accounting entries will be replaced. Continue?'; ru = 'Выбранные документы включают документы со сформированными бухгалтерскими проводками. Эти бухгалтерские проводки будут заменены. Продолжить?';pl = 'Wybrane dokumenty obejmują dokumenty z wygenerowanymi wpisami księgowymi. Te wpisy księgowe zostaną zastąpione. Kontynuować?';es_ES = 'Los documentos seleccionados incluyen los documentos con entradas de diario generadas. Estas entradas contables serán sustituidas. ¿Continuar?';es_CO = 'Los documentos seleccionados incluyen los documentos con entradas de diario generadas. Estas entradas contables serán sustituidas. ¿Continuar?';tr = 'Seçilen belgeler oluşturulmuş muhasebe girişleri olan belgeler içeriyor. Bu muhasebe girişleri değiştirilecek. Devam edilsin mi?';it = 'I documenti selezionati includono documenti con voci di contabilità create. Queste voci di contabilità saranno sostituite. Continuare?';de = 'Die ausgewählten Dokumente enthalten die Dokumente mit Buchungen generiert. Diese Buchungen werden ersetzt. Weiter?'");
		
		ShowQueryBox(Notification, QueryMessage, Mode, 0);
		
		ErrorMessageTemplate = NStr("en = 'Document: %1, Type of accounting: %2. Entries generated'; ru = 'Документ: %1, Тип бухгалтерского учета: %2. Проводки сформированы';pl = 'Dokument: %1, Typ rachunkowości: %2. Wpisy zostały wygenerowane';es_ES = 'Documento: %1, Tipo de contabilidad: %2. Entradas de diario generadas';es_CO = 'Documento: %1, Tipo de contabilidad: %2. Entradas de diario generadas';tr = 'Belge: %1, Muhasebe türü: %2. Girişler oluşturuldu';it = 'Documento: %1. Tipo di contabilità: %2. Voci create';de = 'Dokument: %1, Typ der Buchhaltung: %2. Buchungen generiert'");
		For Each Row In GeneratedDocs Do
			
			ErrorMessage = StrTemplate(ErrorMessageTemplate, Row.Ref, Row.TypeOfAccounting);
			DriveServer.ShowMessageAboutError(, ErrorMessage);
			
		EndDo;
		
	EndIf;

EndProcedure

&AtClient
Procedure GenerateEntriesEndClient(Rows)

	GenerateEntriesEnd(Rows);
	Items.DocumentList.Refresh();
	
	AdjustedManually = False;
	
	CurrentData = Items.DocumentList.CurrentData;
	
	If CurrentData <> Undefined Then
		
		CurrentRef							= Undefined;
		CurrentKey							= Items.DocumentList.CurrentRow;
		CurrentAccountingEntriesRecorder	= CurrentData.AccountingEntriesRecorder;
		CurrentTypeOfAccounting				= CurrentData.TypeOfAccounting;
		CurrentPresentationCurrency			= CurrentData.PresentationCurrency;
		CurrentChartOfAccounts				= CurrentData.ChartOfAccounts;
		CurrentPeriod						= CurrentData.Date;
		CurrentCompany						= CurrentData.Company;
		MasterRecordSetStructure			= GetMasterRecordSet(CurrentData.ChartOfAccounts);
		MasterRecordSet						= MasterRecordSetStructure.MasterRecordSet;
		MasterRecordSetSimple				= MasterRecordSetStructure.MasterRecordSetSimple;
		GetAccountingEntries(CurrentRef, CurrentTypeOfAccounting, CurrentAccountingEntriesRecorder);
		
		FormManagement(CurrentData.Ref, CurrentAccountingEntriesRecorder);
		
	EndIf;
	
	DocumentListOnActivateRow(Items.DocumentList);
	
EndProcedure

&AtServer
Procedure GenerateEntriesEnd(Rows)

	RecordersTable = New ValueTable;
	
	RecordersTable.Columns.Add("Ref"						, Metadata.DefinedTypes.AccountingEntriesRecorder.Type);
	RecordersTable.Columns.Add("Company"					, New TypeDescription("CatalogRef.Companies"));
	RecordersTable.Columns.Add("Date"						, New TypeDescription("Date"));
	RecordersTable.Columns.Add("AccountingEntriesRecorder"	, Metadata.DefinedTypes.AccountingEntriesRecorder.Type);
	RecordersTable.Columns.Add("TypeOfAccounting"			, New TypeDescription("CatalogRef.TypesOfAccounting"));
	RecordersTable.Columns.Add("AdjustedManually"			, New TypeDescription("Boolean"));
	
	For Each Recorder In Rows Do
		
		NewRow = RecordersTable.Add();
		FillPropertyValues(NewRow, Recorder);
		
		NewRow.Company			= NewRow.Ref.Company;
		NewRow.Date				= NewRow.Ref.Date;
		NewRow.AdjustedManually	= False;
		
	EndDo;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	AccountingTransactionDocuments.SourceDocument AS Ref,
	|	AccountingTransactionDocuments.TypeOfAccounting AS TypeOfAccounting,
	|	AccountingTransactionDocuments.AccountingEntriesRecorder AS AccountingEntriesRecorder,
	|	ISNULL(DocumentAccountingEntriesStatuses.AdjustedManually, FALSE) AS AdjustedManually,
	|	AccountingTransactionDocuments.Company AS Company,
	|	AccountingTransactionDocuments.SourceDocument.Date AS Date
	|FROM
	|	InformationRegister.AccountingTransactionDocuments AS AccountingTransactionDocuments
	|		LEFT JOIN InformationRegister.DocumentAccountingEntriesStatuses AS DocumentAccountingEntriesStatuses
	|		ON (DocumentAccountingEntriesStatuses.Recorder = AccountingTransactionDocuments.SourceDocument)
	|			AND (DocumentAccountingEntriesStatuses.Company = AccountingTransactionDocuments.Company)
	|			AND (DocumentAccountingEntriesStatuses.TypeOfAccounting = AccountingTransactionDocuments.TypeOfAccounting)
	|WHERE
	|	AccountingTransactionDocuments.SourceDocument IN(&RecordersArray)";
	
	Query.SetParameter("RecordersArray", RecordersTable.UnloadColumn("Ref"));
	
	QueryResult = Query.Execute();
	
	RecordersTableAdjustedManually = QueryResult.Unload();
	
	RecordersAdjustedManually = RecordersTableAdjustedManually.Copy(, "Ref");
	RecordersAdjustedManually.GroupBy("Ref");
	
	For Each RecorderRef In RecordersAdjustedManually Do
		
		Filter = New Structure;
		Filter.Insert("Ref", RecorderRef.Ref);
		RecorderRows = RecordersTableAdjustedManually.FindRows(Filter);
		
		If RecorderRows[0].AdjustedManually Then
			
			For Each RecorderRow In RecorderRows Do
				
				Filter = New Structure;
				Filter.Insert("Ref"				, RecorderRow.Ref);
				Filter.Insert("TypeOfAccounting", RecorderRow.TypeOfAccounting);
				Filter.Insert("AccountingEntriesRecorder", RecorderRow.AccountingEntriesRecorder);
				
				TableRows = RecordersTable.FindRows(Filter);
				
				If TableRows.Count() = 0 Then
					
					NewRow = RecordersTable.Add();
					FillPropertyValues(NewRow, RecorderRow);
					
				Else
					For Each TableRow In TableRows Do
						TableRow.AdjustedManually = True;
					EndDo;
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	TypesOfAccountingTable.TypeOfAccounting AS TypeOfAccounting,
	|	TypesOfAccountingTable.Company AS Company,
	|	TypesOfAccountingTable.Date AS Date,
	|	TypesOfAccountingTable.Ref AS Ref
	|INTO TypesOfAccountingTable
	|FROM
	|	&Recorders AS TypesOfAccountingTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CompaniesTypesOfAccountingSliceLast.Company AS Company,
	|	MAX(CompaniesTypesOfAccountingSliceLast.Period) AS Period,
	|	CompaniesTypesOfAccountingSliceLast.StartDate AS StartDate,
	|	CompaniesTypesOfAccountingSliceLast.TypeOfAccounting AS TypeOfAccounting,
	|	CompaniesTypesOfAccountingSliceLast.ChartOfAccounts AS ChartOfAccounts,
	|	CompaniesTypesOfAccountingSliceLast.Inactive AS Inactive,
	|	ENDOFPERIOD(CompaniesTypesOfAccountingSliceLast.EndDate, DAY) AS EndDate,
	|	CompaniesTypesOfAccountingSliceLast.EntriesPostingOption AS EntriesPostingOption
	|INTO CompaniesTypesOfAccountingDates
	|FROM
	|	InformationRegister.CompaniesTypesOfAccounting.SliceLast(
	|			,
	|			(Company, TypeOfAccounting) IN
	|				(SELECT
	|					TypesOfAccountingTable.Company AS Company,
	|					TypesOfAccountingTable.TypeOfAccounting AS TypeOfAccounting
	|				FROM
	|					TypesOfAccountingTable AS TypesOfAccountingTable)) AS CompaniesTypesOfAccountingSliceLast
	|
	|GROUP BY
	|	CompaniesTypesOfAccountingSliceLast.Company,
	|	CompaniesTypesOfAccountingSliceLast.StartDate,
	|	CompaniesTypesOfAccountingSliceLast.TypeOfAccounting,
	|	CompaniesTypesOfAccountingSliceLast.ChartOfAccounts,
	|	CompaniesTypesOfAccountingSliceLast.Inactive,
	|	CompaniesTypesOfAccountingSliceLast.EntriesPostingOption,
	|	ENDOFPERIOD(CompaniesTypesOfAccountingSliceLast.EndDate, DAY)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CompaniesTypesOfAccountingDates.Company AS Company,
	|	CompaniesTypesOfAccountingDates.TypeOfAccounting AS TypeOfAccounting,
	|	CompaniesTypesOfAccountingDates.ChartOfAccounts AS ChartOfAccounts
	|FROM
	|	CompaniesTypesOfAccountingDates AS CompaniesTypesOfAccountingDates
	|		INNER JOIN TypesOfAccountingTable AS Recorders
	|		ON CompaniesTypesOfAccountingDates.Company = Recorders.Company
	|			AND CompaniesTypesOfAccountingDates.TypeOfAccounting = Recorders.TypeOfAccounting
	|			AND CompaniesTypesOfAccountingDates.StartDate <= Recorders.Date
	|			AND (CompaniesTypesOfAccountingDates.EndDate >= Recorders.Date
	|				OR NOT CompaniesTypesOfAccountingDates.Inactive)";
	
	Query.SetParameter("Recorders", RecordersTable);
	QueryResult = Query.Execute();
	
	TypesOfAccountingTable = QueryResult.Unload();
	RowsArray = New Array;
	
	ErrorMessages		= New Array;
	DefaultLanguageCode	= CommonClientServer.DefaultLanguageCode();
	ErrorTemplate		= NStr("en = 'An error occurred while generating the accounting entries for document %1, type of accounting %2 due to %3.'; ru = 'При создании бухгалтерских проводок для документа %1, тип бухгалтерского учета %2 произошла ошибка. Причина: %3.';pl = 'Wystąpił błąd podczas generowania wpisów księgowych dla dokumentu %1, typu rachunkowości %2 z powodu %3.';es_ES = 'Se ha producido un error al generar las entradas contables del documento %1, tipo de contabilidad %2 a causa de %3.';es_CO = 'Se ha producido un error al generar las entradas contables del documento %1, tipo de contabilidad %2 a causa de %3.';tr = '%2 muhasebe türündeki %1 belgesi için muhasebe girişleri oluşturulurken %3 nedeniyle hata oluştu.';it = 'Si è verificato un errore durante la creazione delle voci di contabilità per il documento %1, tipo di contabilità %2 a causa di %3.';de = 'Fehler beim Generieren von Buchungen für Dokument %1, Typ der Buchhaltung%2 wegen%3.'",
		DefaultLanguageCode);
	
	For Each Row In RecordersTable Do
		
		BeginTransaction();
		
		Try
			
			Filter = New Structure;
			Filter.Insert("Company"			, Row.Company);
			Filter.Insert("TypeOfAccounting", Row.TypeOfAccounting);
			
			TableRows = TypesOfAccountingTable.FindRows(Filter);
			
			If TableRows.Count() > 0 Then
				
				ChartOfAccounts = TableRows[0].ChartOfAccounts;
				
				SetPrivilegedMode(True);
				
				UpdateRows = False;
				Cancel = False;
				AccountingTemplatesPosting.CreateRefreshTransactionDocument(
					Row.Ref,
					Row.TypeOfAccounting,
					Row.AccountingEntriesRecorder,
					ChartOfAccounts,
					False,
					Cancel,
					UpdateRows);
					
				SetPrivilegedMode(False);
					
				If Not Cancel Or UpdateRows Then
					
					DataKey = New Structure("Ref, TypeOfAccounting, ChartOfAccounts");
					FillPropertyValues(DataKey, Row);
					DataKey.ChartOfAccounts = ChartOfAccounts;
					RowsArray.Add(New DynamicListRowKey(DataKey));
					
				EndIf;
				
			EndIf;
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			ErrorStructure = New Structure;
			ErrorStructure.Insert("ErrorDescription", StrTemplate(ErrorTemplate, Row.Ref, Row.TypeOfAccounting, DetailErrorDescription(ErrorInfo())));
			ErrorStructure.Insert("Ref"				, Row.Ref);
			ErrorMessages.Add(ErrorStructure);
			
		EndTry;
		
	EndDo;
	
	If ErrorMessages.Count() = 0 Then
		
		For Each RecorderRef In RecordersAdjustedManually Do
			
			Filter = New Structure;
			Filter.Insert("Ref", RecorderRef.Ref);
			RecorderRows = RecordersTableAdjustedManually.FindRows(Filter);
			
			If RecorderRows[0].AdjustedManually Then
				
				RecordSetDocumentAccountingEntriesStatuses = InformationRegisters.DocumentAccountingEntriesStatuses.CreateRecordSet();
				RecordSetDocumentAccountingEntriesStatuses.Filter.Recorder.Set(RecorderRef.Ref);
				RecordSetDocumentAccountingEntriesStatuses.Read();
				For Each RecordSetDocumentAccountingEntriesStatus In RecordSetDocumentAccountingEntriesStatuses Do
					RecordSetDocumentAccountingEntriesStatus.AdjustedManually = False;
				EndDo;
				RecordSetDocumentAccountingEntriesStatuses.Write();
				
			EndIf;
			
		EndDo;
		
		RefreshDataAtServer(DocumentList.SettingsComposer, RowsArray);
		
		Items.DocumentList.Refresh();
		
	Else
		
		For Each ErrorMessage In ErrorMessages Do
			
			CommonClientServer.MessageToUser(ErrorMessage.ErrorDescription, ErrorMessage.Ref);
			
			WriteLogEvent(
				NStr("en = 'Restore the original accounting entries'; ru = 'Восстановить первичные бухгалтерские проводки';pl = 'Przywróć oryginalne wpisy księgowe';es_ES = 'Restablecer las entradas contables originales';es_CO = 'Restablecer las entradas contables originales';tr = 'Orijinal muhasebe girişlerini geri yükle';it = 'Ripristinare gli inserimenti contabili originali';de = 'Originalbuchhaltungseinträge wiederherstellen'", DefaultLanguageCode),
				EventLogLevel.Error,
				ErrorMessage.Ref.Metadata(),
				,
				ErrorMessage.ErrorDescription);
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SendMessagesToUserEnd(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		
		GenerateEntriesEndClient(AdditionalParameters.Rows);
		
	EndIf;

EndProcedure

&AtServer
Procedure RefreshDataAtServer(Val SettingsComposer, Rows) Export
	
	RecordSetsAddress		= SettingsComposer.Settings.AdditionalProperties.RecordSetsAddress;
	CommonRecordSetsTemp	= GetFromTempStorage(RecordSetsAddress);
	
	If Rows = Undefined Then
		
		RecordersArray = New Array;
		For Each Row In CommonRecordSetsTemp Do
			
			KeyStructure = New Structure;
			KeyStructure.Insert("Ref"						, Row.Ref);
			KeyStructure.Insert("AccountingEntriesRecorder"	, Row.AccountingEntriesRecorder);
			KeyStructure.Insert("TypeOfAccounting"			, Row.TypeOfAccounting);
			KeyStructure.Insert("ChartOfAccounts"			, Row.ChartOfAccounts);
			
			RecordersArray.Add(New DynamicListRowKey(KeyStructure));
		
		EndDo;
		
	Else
		
		RecordersArray = GetAccountingEntriesRecorders(Rows);
		
	EndIf;
	
	For Each Recorder In RecordersArray Do
		
		Filter = New Structure("Ref, TypeOfAccounting, AccountingEntriesRecorder");
		FillPropertyValues(Filter, Recorder);
		
		CommonRecordSetsRows = CommonRecordSetsTemp.FindRows(Filter);
		
		For Each Row In CommonRecordSetsRows Do
			CommonRecordSetsTemp.Delete(Row);
		EndDo;
		
		Row = CommonRecordSetsTemp.Add();
		FillPropertyValues(Row, Recorder);
		
		CurrentRecorder = 
			?(Recorder.AccountingEntriesRecorder = Undefined, Recorder.Ref, Recorder.AccountingEntriesRecorder);
		
		MasterRecordSetStructure = GetMasterRecordSet(Recorder.ChartOfAccounts);
		
		If MasterRecordSetStructure.MasterRecordSetSimple Then
			
			RegisterRecordSet = AccountingRegisters.AccountingJournalEntriesSimple.CreateRecordSet();
			RegisterRecordSet.Filter.Recorder.Set(CurrentRecorder);
			RegisterRecordSet.Read();
			
			RecordSetTable = AccountingApprovalServer.GetRecordSetSimpleByRecorder(CurrentRecorder);
			
		ElsIf MasterRecordSetStructure.MasterRecordSet Then
			
			RegisterRecordSet = AccountingRegisters.AccountingJournalEntriesCompound.CreateRecordSet();
			RegisterRecordSet.Filter.Recorder.Set(CurrentRecorder);
			RegisterRecordSet.Read();
			
			RecordSetTable = AccountingApprovalServer.GetRecordSetMasterByRecorder(CurrentRecorder);
			
		Else
			
			RegisterRecordSet = AccountingRegisters.AccountingJournalEntries.CreateRecordSet();
			RegisterRecordSet.Filter.Recorder.Set(CurrentRecorder);
			RegisterRecordSet.Read();
			
			RecordSetTable = RegisterRecordSet.Unload();
			
		EndIf;
		
		MasterAccounting.FillMiscFields(RecordSetTable);
		
		Row.RecordSet = RecordSetTable.Copy(New Structure("TypeOfAccounting", Recorder.TypeOfAccounting));
		Row.IsClosingPeriod = PeriodClosingDates.DataChangesDenied(RegisterRecordSet);
		
	EndDo;
	
	PutToTempStorage(CommonRecordSetsTemp, RecordSetsAddress);
	ValueToFormAttribute(CommonRecordSetsTemp, "CommonRecordSets");
	
EndProcedure

&AtServerNoContext
Function GetMasterRecordSet(ChartOfAccounts)
	
	MasterRecordSet			= False;
	MasterRecordSetSimple	= False;
	
	If ValueIsFilled(ChartOfAccounts) Then
		
		MasterRecordSet = AccountingApprovalServer.GetMasterByChartOfAccounts(ChartOfAccounts);
		
		MasterRecordSetSimple = 
			MasterRecordSet And ChartOfAccounts.TypeOfEntries = Enums.ChartsOfAccountsTypesOfEntries.Simple;
		
	EndIf;

	Return New Structure("MasterRecordSet, MasterRecordSetSimple", MasterRecordSet, MasterRecordSetSimple);
	
EndFunction

&AtServer
Function GetColumnsTypeTable()
	
	RecordSetTable 		 		= RecordSet.Unload();
	RecordSetMasterTable 		= RecordSetMaster.Unload();
	RecordSetMasterSimpleTable 	= RecordSetMasterSimple.Unload();
	
	CheckedTablesArray = New Array;
	
	CheckedTablesArray.Add(RecordSetTable);
	CheckedTablesArray.Add(RecordSetMasterTable);
	CheckedTablesArray.Add(RecordSetMasterSimpleTable);

	AttributesTable = New ValueTable;
	
	AttributesTable.Columns.Add("AttributeName");
	
	TypesMapTable = New ValueTable;
	
	TypesMapTable.Columns.Add("AttributeName");
	TypesMapTable.Columns.Add("AttributeType");
	
	For Each CheckedTable In CheckedTablesArray Do
	
		For Each Column In CheckedTable.Columns Do
			
			SearchStructure = New Structure("AttributeName",Column.Name);
			
			FoundRows = AttributesTable.FindRows(SearchStructure);
			If FoundRows.Count() = 0 Then
				NewRow	= AttributesTable.Add();
				
				NewRow.AttributeName = Column.Name;
			EndIf;
			
			ColumnType		= Column.ValueType;
			ColumnAllTypes	= ColumnType.Types();
			
			For Each CurrentType In ColumnAllTypes Do
				
				SearchStructure = New Structure("AttributeName, AttributeType",Column.Name,CurrentType);
				
				FoundRows = TypesMapTable.FindRows(SearchStructure);
				
				If FoundRows.Count() = 0 Then
					NewRow	= TypesMapTable.Add();
					
					NewRow.AttributeName = Column.Name;
					NewRow.AttributeType = CurrentType;
				EndIf;
				
			EndDo;
		EndDo;
	EndDo;
	
	ColumnsTypeTable = New ValueTable;
	
	For Each AttributeRow In AttributesTable Do
		
		ArrayOfTypes = New Array;
		
		SearchStructure = New Structure("AttributeName",AttributeRow.AttributeName);
		
		FoundRows = TypesMapTable.FindRows(SearchStructure);
		
		For Each Row In FoundRows Do
			ArrayOfTypes.Add(Row.AttributeType);
		EndDo;
		
		ColumnsTypeTable.Columns.Add(AttributeRow.AttributeName, New TypeDescription(ArrayOfTypes));
		
	EndDo;
	
	Return ColumnsTypeTable;
	
EndFunction

&AtClient
Procedure SetPictureInRow(CurrentRow)
	
	If CurrentRow.RecordType = AccountingRecordType.Credit And CurrentRow.Active Then
		CurrentRow.RecordSetPicture = 2;
	ElsIf CurrentRow.RecordType = AccountingRecordType.Credit And NOT CurrentRow.Active Then
		CurrentRow.RecordSetPicture = 4;
	ElsIf CurrentRow.RecordType = AccountingRecordType.Debit And CurrentRow.Active Then
		CurrentRow.RecordSetPicture = 1;
	ElsIf CurrentRow.RecordType = AccountingRecordType.Debit And Not CurrentRow.Active Then
		CurrentRow.RecordSetPicture = 3;
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshTotalData()

	TotalDebits		= 0;
	TotalCredits	= 0;
	For Each Row In RecordSetMaster Do
		
		If Row.RecordType = AccountingRecordType.Debit Then
			TotalDebits		= TotalDebits	 + Row.Amount;
		Else
			TotalCredits	= TotalCredits	 + Row.Amount;
		EndIf;
		
	EndDo;
	
	For Each Row In RecordSetMasterSimple Do
		
		TotalDebits		= TotalDebits	 + Row.Amount;
		TotalCredits	= TotalCredits	 + Row.Amount;
		
	EndDo;
	
	TotalDifference = TotalDebits - TotalCredits;

EndProcedure

&AtServerNoContext
Function GetTypesAtServer(DimensionType)

	If ValueIsFilled(DimensionType) Then
		Return DimensionType.ValueType;
	Else
		Return New TypeDescription("Undefined"); 
	EndIf;

EndFunction

&AtClient
Procedure RecordSetMasterExtDimension1StartChoice(Item, ChoiceData, StandardProcessing)
	Item.TypeRestriction = GetTypesAtServer(Items.RecordSetMaster.CurrentData.ExtDimensionType1);
EndProcedure

&AtClient
Procedure RecordSetMasterExtDimension2StartChoice(Item, ChoiceData, StandardProcessing)
	Item.TypeRestriction = GetTypesAtServer(Items.RecordSetMaster.CurrentData.ExtDimensionType2);
EndProcedure

&AtClient
Procedure RecordSetMasterExtDimension3StartChoice(Item, ChoiceData, StandardProcessing)
	Item.TypeRestriction = GetTypesAtServer(Items.RecordSetMaster.CurrentData.ExtDimensionType3);
EndProcedure

&AtClient
Procedure RecordSetMasterExtDimension4StartChoice(Item, ChoiceData, StandardProcessing)
	Item.TypeRestriction = GetTypesAtServer(Items.RecordSetMaster.CurrentData.ExtDimensionType4);
EndProcedure

&AtServerNoContext
Function GetObjectAttribute(Ref, Attributes)
	Return Common.ObjectAttributesValues(Ref, Attributes);
EndFunction

&AtServer
Procedure SetupMiscFieldsConditionalAppearance(Form, TableName, Suffix = "", Compound = False)
	
	If Not Compound Then
	
		// Quantity
		ItemAppearance = Form.ConditionalAppearance.Items.Add();
		
		FilterItemGroup = WorkWithForm.CreateFilterItemGroup(ItemAppearance.Filter, DataCompositionFilterItemsGroupType.NotGroup);
		
		WorkWithForm.AddFilterItem(FilterItemGroup,
			TableName + ".UseQuantity" + Suffix,
			True,
			DataCompositionComparisonType.Equal);
			
		WorkWithForm.AddAppearanceField(ItemAppearance, TableName + "Quantity" + Suffix);
		WorkWithForm.AddConditionalAppearanceItem(ItemAppearance, "Enabled", False);
		
		// Currency
		ItemAppearance = Form.ConditionalAppearance.Items.Add();
		
		FilterItemGroup = WorkWithForm.CreateFilterItemGroup(ItemAppearance.Filter, DataCompositionFilterItemsGroupType.NotGroup);
		
		WorkWithForm.AddFilterItem(FilterItemGroup,
			TableName + ".UseCurrency" + Suffix,
			True,
			DataCompositionComparisonType.Equal);
			
		WorkWithForm.AddAppearanceField(ItemAppearance, TableName + "Currency" + Suffix);
		WorkWithForm.AddAppearanceField(ItemAppearance, TableName + "AmountCur" + Suffix);
		WorkWithForm.AddAppearanceField(ItemAppearance, TableName + "AmountCur" + Suffix);
		WorkWithForm.AddConditionalAppearanceItem(ItemAppearance, "Enabled", False);
	
	Else
		
		ItemAppearance = Form.ConditionalAppearance.Items.Add();
		
		FilterItemGroup = WorkWithForm.CreateFilterItemGroup(ItemAppearance.Filter, DataCompositionFilterItemsGroupType.NotGroup);
		
		WorkWithForm.AddFilterItem(FilterItemGroup,
			TableName + ".RecordType",
			?(Suffix = "Dr", AccountingRecordType.Debit, AccountingRecordType.Credit),
			DataCompositionComparisonType.Equal);
			
		WorkWithForm.AddFilterItem(FilterItemGroup,
			TableName + ".UseQuantity",
			True,
			DataCompositionComparisonType.Equal);
			
		WorkWithForm.AddAppearanceField(ItemAppearance, TableName + "Quantity" + Suffix);
		WorkWithForm.AddConditionalAppearanceItem(ItemAppearance, "Enabled", False);
		
		ItemAppearance = Form.ConditionalAppearance.Items.Add();
		
		FilterItemGroup = WorkWithForm.CreateFilterItemGroup(ItemAppearance.Filter, DataCompositionFilterItemsGroupType.NotGroup);
		
		WorkWithForm.AddFilterItem(FilterItemGroup,
			TableName + ".RecordType",
			?(Suffix = "Dr", AccountingRecordType.Debit, AccountingRecordType.Credit),
			DataCompositionComparisonType.Equal);
			
		WorkWithForm.AddFilterItem(FilterItemGroup,
			TableName + ".UseCurrency",
			True,
			DataCompositionComparisonType.Equal);
			
		WorkWithForm.AddAppearanceField(ItemAppearance, TableName + "Currency" + Suffix);
		WorkWithForm.AddAppearanceField(ItemAppearance, TableName + "AmountCur" + Suffix);
		WorkWithForm.AddConditionalAppearanceItem(ItemAppearance, "Enabled", False);
		
		ItemAppearance = Form.ConditionalAppearance.Items.Add();
		
		WorkWithForm.AddFilterItem(ItemAppearance.Filter,
			TableName + ".RecordType",
			?(Suffix = "Dr", AccountingRecordType.Credit, AccountingRecordType.Debit),
			DataCompositionComparisonType.Equal);
			
		WorkWithForm.AddAppearanceField(ItemAppearance, TableName + "Amount" + Suffix);
		WorkWithForm.AddConditionalAppearanceItem(ItemAppearance, "Enabled", False);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnAccountChangeAtServer(TableName, CurrentRowId, Suffix = Undefined)
	
	RowData = ThisObject[TableName].FindByID(CurrentRowId);
	RowsArray = CommonClientServer.ValueInArray(RowData);
	
	If Suffix <> Undefined Then
		
		SuffixesArray = New Array;
		SuffixesArray.Add(Suffix);
		
		MasterAccounting.FillMiscFields(RowsArray, SuffixesArray);
		
	Else
		
		MasterAccounting.FillMiscFields(RowsArray);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SortRecordSet(Item)
	
	IsSortOrderAsc = String(AccountingRecordType.Debit) < String(AccountingRecordType.Credit);
	
	If IsSortOrderAsc Then
		ThisObject[Item.Name].Sort("EntryNumber, RecordType");
	Else
		ThisObject[Item.Name].Sort("EntryNumber, RecordType Desc");
	EndIf;
	
EndProcedure

&AtServer
Procedure SetPeriod()

	Filter = DocumentList.Filter;
	CommonClientServer.DeleteFilterItems(Filter, "Date");
	
	If ValueIsFilled(FilterPeriodOfSourceDocuments.StartDate) Then
	
		CommonClientServer.AddCompositionItem(
			Filter,
			"Date",
			DataCompositionComparisonType.GreaterOrEqual,
			FilterPeriodOfSourceDocuments.StartDate,
			,
			ValueIsFilled(FilterPeriodOfSourceDocuments.StartDate));
			
	EndIf;
	
	If ValueIsFilled(FilterPeriodOfSourceDocuments.EndDate) Then
		
		CommonClientServer.AddCompositionItem(
			Filter,
			"Date",
			DataCompositionComparisonType.LessOrEqual,
			FilterPeriodOfSourceDocuments.EndDate,
			,
			ValueIsFilled(FilterPeriodOfSourceDocuments.EndDate));
		
	EndIf;

EndProcedure

&AtServer
Procedure FillCheckProcessing(ObjectRecordSetMaster, TableName, Compound, Cancel)
	
	For Each Row In ObjectRecordSetMaster Do
		
		AttributesToCheck = New Array;
		
		If Compound Then
			
			If Not ValueIsFilled(Row.Account) Then
				AttributesToCheck.Add(New Structure("Account, Field", "Account", "Account"));
			EndIf;
			
		Else
			
			If Not ValueIsFilled(Row.AccountDr) Then
				AttributesToCheck.Add(New Structure("Account, Field", "AccountDr", "Debit"));
			EndIf;
			
			If Not ValueIsFilled(Row.AccountCr) Then
				AttributesToCheck.Add(New Structure("Account, Field", "AccountCr", "Credit"));
			EndIf;
			
		EndIf;
		
		For Each AttributeName In AttributesToCheck Do
		
			ColumnTitle = Items[TableName + AttributeName.Field].Title;
			
			CommonClientServer.MessageToUser(
				StrTemplate(NStr("en = 'The ""%1"" field is required.'; ru = 'Поле ""%1"" не заполнено.';pl = 'Pole ""%1"" jest wymagane.';es_ES = 'El campo ""%1"" es obligatorio.';es_CO = 'El campo ""%1"" es obligatorio.';tr = '""%1"" alanı zorunlu.';it = 'Il campo ""%1"" è richiesto.';de = 'Das ""%1"" Feld ist nicht erforderlich.'"), ColumnTitle),
				,
				CommonClientServer.PathToTabularSection(TableName, Row.LineNumber, AttributeName.Account),
				,
				Cancel);
			
		EndDo;
		
	EndDo;
	
	If Not Cancel Then
		
		AccountingJournalEntries = New ValueTable;
		AccountingJournalEntries.Columns.Add("Period"			, New TypeDescription("Date"));
		AccountingJournalEntries.Columns.Add("Account"			, New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts"));
		AccountingJournalEntries.Columns.Add("AccountDr"		, New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts"));
		AccountingJournalEntries.Columns.Add("AccountCr"		, New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts"));
		AccountingJournalEntries.Columns.Add("RecordType"		, New TypeDescription("AccountingRecordType"));
		AccountingJournalEntries.Columns.Add("Amount"			, New TypeDescription("Number"));
		AccountingJournalEntries.Columns.Add("EntryNumber"		, New TypeDescription("Number"));
		AccountingJournalEntries.Columns.Add("LineNumber"		, New TypeDescription("Number"));
		
		FieldsListCompound	= "Period, LineNumber, EntryNumber, Account, RecordType";
		FieldsListSimple	= "Period, LineNumber, AccountDr, AccountCr, Amount";
		For Each EntryRow In ObjectRecordSetMaster Do
			
			NewRow = AccountingJournalEntries.Add();
			If Compound Then
				
				FillPropertyValues(NewRow, EntryRow, FieldsListCompound);
				
				NewRow.Amount = ?(NewRow.RecordType = AccountingRecordType.Debit, EntryRow.AmountDr, EntryRow.AmountCr);
				
			Else
				
				FillPropertyValues(NewRow, EntryRow, FieldsListSimple);
				
				NewRow.EntryNumber = EntryRow.LineNumber;
				
			EndIf;
			
		EndDo;
		
		EntriesTable = New Array;
		EntriesTableRow = New Structure;
		EntriesTableRow.Insert("TypeOfAccounting"	, CurrentTypeOfAccounting);
		EntriesTableRow.Insert("ChartOfAccounts"	, CurrentChartOfAccounts);
		EntriesTableRow.Insert("Entries"			, AccountingJournalEntries);
		EntriesTable.Add(EntriesTableRow);
		
		If AdjustedManually Then
			AccountingTemplatesPosting.CheckTransactionsFilling(CurrentAccountingEntriesRecorder, EntriesTable, Cancel, True);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AddEntry(Command)
	
	CurrentTableName = "RecordSetMaster";
	
	DefaultData = New Structure;
	DefaultData.Insert("Company", CurrentCompany);
	DefaultData.Insert("Period"	, CurrentPeriod);
	
	CurrentRowLineNumber = MasterAccountingClientServer.AddEntry(ThisObject[CurrentTableName], DefaultData, "AccountingEntriesManagement");
	
	TableIsFilled = (ThisObject[CurrentTableName].Count() <> 0);
	Items[CurrentTableName + "ExtraButtonEntriesUp"].Enabled	= TableIsFilled;
	Items[CurrentTableName + "ExtraButtonEntriesDown"].Enabled	= TableIsFilled;
	Items[CurrentTableName + "ContextMenuEntriesUp"].Enabled	= TableIsFilled;
	Items[CurrentTableName + "ContextMenuEntriesDown"].Enabled	= TableIsFilled;
	
	Items[CurrentTableName].CurrentRow = CurrentRowLineNumber;
	
EndProcedure

&AtClient
Procedure AddEntryLine(Command)
	
	CurrentTableName = "RecordSetMaster";
	
	CurrentData = Items[CurrentTableName].CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	IsComplexTypeOfEntries = IsComplexTypeOfEntries(CurrentChartOfAccounts, ThisObject[CurrentTableName].Count());
	
	DefaultData = New Structure;
	DefaultData.Insert("Company", CurrentCompany);
	DefaultData.Insert("Period"	, CurrentPeriod);
	DefaultData.Insert("CurrentIndex", ThisObject[CurrentTableName].IndexOf(CurrentData));
	DefaultData.Insert("IsComplexTypeOfEntries", IsComplexTypeOfEntries);
	
	CurrentRowLineNumber = MasterAccountingClientServer.AddEntryLine(ThisObject[CurrentTableName], DefaultData, "AccountingEntriesManagement");
	Items[CurrentTableName].CurrentRow = CurrentRowLineNumber;
	
EndProcedure

&AtClient
Procedure EntriesUp(Command)
	
	CurrentTableName = "RecordSetMaster";
	
	IsComplexTypeOfEntries = IsComplexTypeOfEntries(CurrentChartOfAccounts, ThisObject[CurrentTableName].Count());
	
	If IsComplexTypeOfEntries Then
		SelectedRowsIDs = Items[CurrentTableName].SelectedRows;
		RowsArray = New Array;
		
		SortedSelectedRowsIDs = SortSelectedRowsArray(CurrentTableName, SelectedRowsIDs);
		
		For Each SelectedRowID In SortedSelectedRowsIDs Do
			RowsArray.Add(ThisObject[CurrentTableName].FindByID(SelectedRowID));
		EndDo;
		
		DefaultData = New Structure;
		DefaultData.Insert("Company", CurrentCompany);
		DefaultData.Insert("Period"	, CurrentPeriod);
		DefaultData.Insert("RowsArray"	, RowsArray);
		DefaultData.Insert("Direction"	, -1);
		
		MasterAccountingClientServer.MoveEntriesUpDown(ThisObject[CurrentTableName], DefaultData, "AccountingEntriesManagement");
		
	EndIf;
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure EntriesDown(Command)
	
	CurrentTableName = "RecordSetMaster";
	
	IsComplexTypeOfEntries = IsComplexTypeOfEntries(CurrentChartOfAccounts, ThisObject[CurrentTableName].Count());
	
	If IsComplexTypeOfEntries Then
		SelectedRowsIDs = Items[CurrentTableName].SelectedRows;
		RowsArray = New Array;
		
		SortedSelectedRowsIDs = SortSelectedRowsArray(CurrentTableName, SelectedRowsIDs);
		
		For Each SelectedRowID In SortedSelectedRowsIDs Do
			RowsArray.Add(ThisObject[CurrentTableName].FindByID(SelectedRowID));
		EndDo;
		
		DefaultData = New Structure;
		DefaultData.Insert("Company", CurrentCompany);
		DefaultData.Insert("Period"	, CurrentPeriod);
		DefaultData.Insert("RowsArray"	, RowsArray);
		DefaultData.Insert("Direction"	, 1);
		
		MasterAccountingClientServer.MoveEntriesUpDown(ThisObject[CurrentTableName], DefaultData, "AccountingEntriesManagement");
		
	EndIf;
	
	Modified = True;

EndProcedure

&AtClient
Procedure CopyEntriesRows(Command)
	
	CurrentTableName = "RecordSetMaster";
	
	IsComplexTypeOfEntries = IsComplexTypeOfEntries(CurrentChartOfAccounts, ThisObject[CurrentTableName].Count());
	
	If IsComplexTypeOfEntries Then
		
		SelectedRowsIDs = Items[CurrentTableName].SelectedRows;
		RowsArray = New Array;
		
		SortedSelectedRowsIDs = SortSelectedRowsArray(CurrentTableName, SelectedRowsIDs);
		
		For Each SelectedRowID In SortedSelectedRowsIDs Do
			RowsArray.Add(ThisObject[CurrentTableName].FindByID(SelectedRowID));
		EndDo;
		
		DefaultData = New Structure;
		DefaultData.Insert("Company", CurrentCompany);
		DefaultData.Insert("Period"	, CurrentPeriod);
		DefaultData.Insert("RowsArray"	, RowsArray);
		DefaultData.Insert("Direction"	, 1);
		
		CurrentRowId = MasterAccountingClientServer.CopyEntriesRows(ThisObject[CurrentTableName], DefaultData, "AccountingEntriesManagement");
		If CurrentRowId <> Undefined Then
			Items[CurrentTableName].CurrentRow = CurrentRowId;
		EndIf;
		
	EndIf;
	
	RefreshTotalData();
	Modified = True;
	
EndProcedure

&AtServer
Function IsComplexTypeOfEntries(ChartOfAccounts, Count)
	
	Return WorkWithArbitraryParameters.SetComplexTypeOfEntries(ChartOfAccounts, Count);
	
EndFunction

&AtServer
Function SortSelectedRowsArray(CurrentTableName, SelectedRowsIDs) 
	
	SelectedRowsArray = New Array;
	
	For Each SelectedRowID In SelectedRowsIDs Do
		SelectedRowsArray.Add(ThisObject[CurrentTableName].FindByID(SelectedRowID));
	EndDo;
	
	TempEntries = ThisObject[CurrentTableName].Unload(SelectedRowsArray);
	TempEntries.Sort("EntryNumber, EntryLineNumber");
	
	SelectedRowsArray.Clear();
	
	Filter = New Structure("EntryNumber, EntryLineNumber");
		
	For Each Row In TempEntries Do
		
		FillPropertyValues(Filter, Row); 
		
		RowsByFilter = ThisObject[CurrentTableName].FindRows(Filter);
		
		If RowsByFilter.Count() > 0 Then
			SelectedRowsArray.Add(RowsByFilter[0].GetID());
		EndIf;
		
	EndDo;
	
	Return SelectedRowsArray;
	
EndFunction

&AtServer
Procedure FillRecordSetMasterCommandBar()
	
	TableName = "RecordSetMaster";
	
	NewButton = Items.Insert(TableName + "ExtraButtonAddEntry"		, Type("FormButton"), Items[TableName].CommandBar, Items.RecordSetMasterDelete);
	NewButton.CommandName = "AddEntry";
	NewButton.Title = NStr("en = 'Add entry'; ru = 'Добавить проводку';pl = 'Dodaj wpis';es_ES = 'Añadir entrada de diario';es_CO = 'Añadir entrada de diario';tr = 'Giriş ekle';it = 'Aggiungere voce';de = 'Buchung hinzufügen'");
	
	NewButton = Items.Insert(TableName + "ExtraButtonAddEntryLine"	, Type("FormButton"), Items[TableName].CommandBar, Items.RecordSetMasterDelete);
	NewButton.CommandName = "AddEntryLine";
	NewButton.Title = NStr("en = 'Add entry line'; ru = 'Добавить строку проводки';pl = 'Dodaj wiersz wpisu';es_ES = 'Añadir línea de entrada de diario';es_CO = 'Añadir línea de entrada de diario';tr = 'Giriş satırı ekle';it = 'Aggiungere riga di voce';de = 'Buchungszeile hinzufügen'");
	
	NewButton = Items.Insert(TableName + "ExtraButtonCopyEntriesRows"	, Type("FormButton"), Items[TableName].CommandBar, Items.RecordSetMasterDelete);
	NewButton.CommandName = "CopyEntriesRows";
	NewButton.Title = NStr("en = 'Copy'; ru = 'Скопировать';pl = 'Kopiuj';es_ES = 'Copia';es_CO = 'Copia';tr = 'Kopyala';it = 'Copia';de = 'Kopieren'");
	
	NewButton = Items.Insert(TableName + "ExtraButtonEntriesUp"	, Type("FormButton"), Items[TableName].CommandBar, Items.RecordSetWriteMaster);
	NewButton.CommandName = "EntriesUp";
	
	NewButton = Items.Insert(TableName + "ExtraButtonEntriesDown"	, Type("FormButton"), Items[TableName].CommandBar, Items.RecordSetWriteMaster);
	NewButton.CommandName = "EntriesDown";
	
	NewButton = Items.Add(TableName + "ContextMenuAddEntry"		, Type("FormButton"), Items[TableName].ContextMenu);
	NewButton.CommandName = "AddEntry";
	NewButton.Title = NStr("en = 'Add entry'; ru = 'Добавить проводку';pl = 'Dodaj wpis';es_ES = 'Añadir entrada de diario';es_CO = 'Añadir entrada de diario';tr = 'Giriş ekle';it = 'Aggiungere voce';de = 'Buchung hinzufügen'");
	
	NewButton = Items.Add(TableName + "ContextMenuAddEntryLine"	, Type("FormButton"), Items[TableName].ContextMenu);
	NewButton.CommandName = "AddEntryLine";
	NewButton.Title = NStr("en = 'Add entry line'; ru = 'Добавить строку проводки';pl = 'Dodaj wiersz wpisu';es_ES = 'Añadir línea de entrada de diario';es_CO = 'Añadir línea de entrada de diario';tr = 'Giriş satırı ekle';it = 'Aggiungere riga di voce';de = 'Buchungszeile hinzufügen'");
	
	NewButton = Items.Add(TableName + "ContextMenuCopyEntriesRows"	, Type("FormButton"), Items[TableName].ContextMenu);
	NewButton.CommandName = "CopyEntriesRows";
	
	NewButton = Items.Add(TableName + "ContextMenuEntriesUp"	, Type("FormButton"), Items[TableName].ContextMenu);
	NewButton.CommandName = "EntriesUp";
	
	NewButton = Items.Add(TableName + "ContextMenuEntriesDown"	, Type("FormButton"), Items[TableName].ContextMenu);
	NewButton.CommandName = "EntriesDown";
	
	For Each ButtonItem In Items.RecordSetMasterCommandBar.ChildItems Do
		
		If StrEndsWith(ButtonItem.Name, "Add") > 0 
			Or StrEndsWith(ButtonItem.Name, "Move") > 0
			Or StrEndsWith(ButtonItem.Name, "Copy") > 0 Then
			ButtonItem.Visible = False;
		EndIf;
		
	EndDo;
	
	Items[TableName + "ContextMenuAdd"].Visible = False;
	Items[TableName + "ContextMenuCopy"].Visible = False;
	Items[TableName + "ContextMenuMoveUp"].Visible = False;
	Items[TableName + "ContextMenuMoveDown"].Visible = False;
	
EndProcedure

&AtClient
Procedure RecordSetMasterSimpleAmountOnChange(Item)
	RefreshTotalData();
EndProcedure

&AtClient
Procedure RecordSetMasterAfterDeleteRow(Item)
	
	CurrentTableName = "RecordSetMaster";
	
	MasterAccountingClientServer.RenumerateEntriesTabSection(ThisObject[CurrentTableName]);
	
	RefreshTotalData();
	
EndProcedure

&AtClient
Procedure RecordSetMasterSimpleAfterDeleteRow(Item)
	RefreshTotalData();
EndProcedure

&AtClient
Procedure RecordSetCompoundFieldOnChange(RecordTypeToCheck, FieldName, ResultField)
	
	CurrentRow = Items.RecordSetMaster.CurrentData;
	
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	
	If CurrentRow.RecordType = RecordTypeToCheck Then
		CurrentRow[ResultField] = CurrentRow[FieldName];
	EndIf;
	
EndProcedure

#EndRegion