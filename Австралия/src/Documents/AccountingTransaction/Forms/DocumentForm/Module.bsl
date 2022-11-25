
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ValueIsFilled(Object.Ref) Then
		OnCreateReadAtServer();
	EndIf;
	
	FillAttributesByCompany();
	
	GreenColor = StyleColors.CompletedJob;
	RedColor = StyleColors.ErrorNoteText;
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.AccountingRegisters.AccountingJournalEntries, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
	IsClosingPeriod = PeriodClosingDates.DataChangesDenied(CurrentObject);
	DocumentDate = CurrentObject.Date;
	
	OnCreateReadAtServer();
	
	RefreshTotalData();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	MasterTablesCommands();
	
EndProcedure

&AtClient
Procedure RereadData(Command)
	
	Read();
	MasterTablesCommands();
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	For Each TableMapRow In MasterTablesMap Do
		
		Table = ThisObject[TableMapRow.TableName];
		Compound = TableMapRow.Compound;
		
		For Each Row In Table Do
			
			AttributesToCheck = New Array;
			
			If Compound Then
				
				If Not ValueIsFilled(Row.Account) Then
					AttributesToCheck.Add("Account");
				EndIf;
				
			Else
				
				If Not ValueIsFilled(Row.AccountDr) Then
					AttributesToCheck.Add("AccountDr");
				EndIf;
				
				If Not ValueIsFilled(Row.AccountCr) Then
					AttributesToCheck.Add("AccountCr");
				EndIf;
				
			EndIf;
			
			For Each AttributeName In AttributesToCheck Do
			
				ColumnTitle = Items[TableMapRow.TableName + AttributeName].Title;
				
				CommonClientServer.MessageToUser(
					StrTemplate(NStr("en = 'The ""%1"" field is required.'; ru = 'Поле ""%1"" не заполнено.';pl = 'Pole ""%1"" jest wymagane.';es_ES = 'El campo ""%1"" es obligatorio.';es_CO = 'El campo ""%1"" es obligatorio.';tr = '""%1"" alanı zorunlu.';it = 'Il campo ""%1"" è richiesto.';de = 'Das ""%1"" Feld ist erforderlich.'"), ColumnTitle),
					,
					CommonClientServer.PathToTabularSection(TableMapRow.TableName, Row.LineNumber, AttributeName),
					,
					Cancel);
				
			EndDo;
			
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
		
		For Each TableMapRow In MasterTablesMap Do
			
			Table = ThisObject[TableMapRow.TableName];
			Compound = TableMapRow.Compound;
			
			For Each EntryRow In Table Do
				
				NewRow = AccountingJournalEntries.Add();
				If Compound Then
					NewRow.Period			= EntryRow.Period;
					NewRow.LineNumber		= EntryRow.LineNumber;
					NewRow.EntryNumber		= EntryRow.EntryNumber;
					NewRow.Account			= EntryRow.Account;
					NewRow.RecordType		= EntryRow.RecordType;
					NewRow.Amount			= ?(NewRow.RecordType = AccountingRecordType.Debit, EntryRow.AmountDr, EntryRow.AmountCr);
				Else
					NewRow.Period			= EntryRow.Period;
					NewRow.LineNumber		= EntryRow.LineNumber;
					NewRow.EntryNumber		= EntryRow.EntryNumber;
					NewRow.AccountDr		= EntryRow.AccountDr;
					NewRow.AccountCr		= EntryRow.AccountCr;
					NewRow.RecordType		= EntryRow.RecordType;
					NewRow.Amount			= EntryRow.Amount;
				EndIf;
				
			EndDo;
			
		EndDo;
		
		EntriesTable = New Array;
		EntriesTableRow = New Structure;
		EntriesTableRow.Insert("TypeOfAccounting"	, Object.TypeOfAccounting);
		EntriesTableRow.Insert("ChartOfAccounts"	, Object.ChartOfAccounts);
		EntriesTableRow.Insert("Entries"			, AccountingJournalEntries);
		EntriesTable.Add(EntriesTableRow);
		
		If AdjustedManually Then
			AccountingTemplatesPosting.CheckTransactionsFilling(Object, EntriesTable, Cancel, True);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	SetTitle(CurrentObject.Ref);
	
	If WriteParameters.WriteMode = DocumentWriteMode.UndoPosting
		Or WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		Read();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	MasterTablesCommands();
	Notify("AccountingEntriesManagement");
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	MasterAccounting.ConvertEntryTablesIntoRecordSet(
		ThisObject, 
		MasterTablesMap, 
		CurrentObject.RegisterRecords.AccountingJournalEntriesSimple,
		CurrentObject.RegisterRecords.AccountingJournalEntriesCompound);
	
	CurrentObject.RegisterRecords.AccountingJournalEntries.Write = Modified;
	CurrentObject.RegisterRecords.AccountingJournalEntriesSimple.Write = Modified;
	CurrentObject.RegisterRecords.AccountingJournalEntriesCompound.Write = Modified;
	CurrentObject.RegisterRecords.DocumentAccountingEntriesStatuses.Write = Modified;
	
	CurrentObject.AdditionalProperties.Insert("AdjustedManually", AdjustedManually);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CompanyOnChange(Item)
	
	If Object.Company = PreviousCompany Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Company) Then
		
		Object.DocumentCurrency = Undefined;
		FormManagement();
		Return;
		
	EndIf;
	
	AccountingSettingsCheck = IsAccountingSettingsApplicable(Object.TypeOfAccounting, Object.ChartOfAccounts, Object.Company, Object.Date);
	If AccountingSettingsCheck.IsTypeOfAccountingApplicable
		And AccountingSettingsCheck.IsChartOfAccountsApplicable Then
		
		SetupTypesOfAccountingTable();
		FillCompanyInEntryTable();
		PreviousCompany = Object.Company;
		
		Return;
		
	EndIf;
	
	If Not AccountingSettingsCheck.IsTypeOfAccountingApplicable Then
		
		MessageText = StrTemplate(MessagesToUserClientServer.GetAccountingTransactionCompanyTypeOfAccountingOnChangeQueryText(False),
			Object.TypeOfAccounting,
			Object.Company,
			Format(Object.Date, "DLF=D"));
		
	Else
		
		MessageText = StrTemplate(MessagesToUserClientServer.GetAccountingTransactionCompanyTypeOfAccountingOnChangeQueryText(True),
			Object.ChartOfAccounts,
			Object.Company,
			Object.TypeOfAccounting,
			Format(Object.Date, "DLF=D"));
		
	EndIf;
	
	NotifyDescription = New NotifyDescription("CompanyOnChangeEnd", ThisObject, AccountingSettingsCheck);
	ShowQueryBox(NotifyDescription, MessageText, QuestionDialogMode.YesNo, , DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure TypeOfAccountingOnChange(Item)
	
	If Not ValueIsFilled(Object.TypeOfAccounting) Then
		
		Object.ChartOfAccounts = Undefined;
		GenerateMasterTables();
		Items.TotalDifference.Visible = False;
		
		Return;
		
	EndIf;
	
	Filter = New Structure;
	Filter.Insert("TypeOfAccounting", Object.TypeOfAccounting);
	
	NewChartOfAccounts = TypesOfAccountingTable.FindRows(Filter)[0].ChartOfAccounts;
	
	If Not ValueIsFilled(CurrentTableName)
		Or ThisObject[CurrentTableName].Count() = 0 Then
		
		Object.ChartOfAccounts = NewChartOfAccounts;
		TypeOfAccountingOnChangeFragmentAtServer();
		MasterTablesCommands();
		FormManagementClient();
		Return;
		
	EndIf;
	
	If NewChartOfAccounts <> Object.ChartOfAccounts Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("NewChartOfAccounts", NewChartOfAccounts);
		
		MessageText = StrTemplate(MessagesToUserClientServer.GetAccountingTransactionCompanyTypeOfAccountingOnChangeQueryText(),
			Object.ChartOfAccounts,
			Object.Company,
			Object.TypeOfAccounting,
			Format(Object.Date, "DLF=D"));
		
		Notification = New NotifyDescription("TypeOfAccountingOnChangeEnd", ThisObject, AdditionalParameters);
		ShowQueryBox(Notification, MessageText, QuestionDialogMode.YesNo, , DialogReturnCode.No);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TemplateOpening(Item, StandardProcessing)

	StandardProcessing = False;

	Template.ShowChooseItem(, NStr("en = 'List of templates'; ru = 'Список шаблонов';pl = 'Lista szablonów';es_ES = 'Lista de plantillas';es_CO = 'Lista de plantillas';tr = 'Şablon listesi';it = 'Elenco di modelli';de = 'Liste von Vorlagen'"));
	
EndProcedure

&AtClient
Procedure AdjustManuallyOnChange(Item)
	
	AdjustManuallyOnChangeEndCallback = New NotifyDescription("AdjustManuallyOnChangeEnd", ThisObject);
	
	NotificationParameters = New Structure;
	NotificationParameters.Insert("Form", ThisObject);
	NotificationParameters.Insert("Document", Object.Ref);
	NotificationParameters.Insert("AdjustManuallyOnChangeEndCallback", AdjustManuallyOnChangeEndCallback);
	
	NotifyDescription = New NotifyDescription("AdjustManuallyOnChangeEnd", ThisObject,
		NotificationParameters);
	
	If ThisObject[CurrentTableName].Count() > 0 And Not AdjustedManually Then
		
		Text = MessagesToUserClientServer.GetEntriesTableUpdateQueryText();
		ShowQueryBox(NotifyDescription, Text, QuestionDialogMode.YesNo, , DialogReturnCode.No);
		
		Return;
		
	EndIf;
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersRecordSetMaster

&AtClient
Procedure Attachable_RecordSetSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentRow = Item.CurrentData;
	
	If (Field.Name = Item.Name + "TransactionTemplate" 
		Or Field.Name = Item.Name + "TransactionTemplateCode") 
		And ValueIsFilled(CurrentRow.TransactionTemplate)
		And ValueIsFilled(CurrentRow.TransactionTemplateLineNumber) Then
		
		TabName = "EntriesSimple";
		
		FoundRows = MasterTablesMap.FindRows(New Structure("TableName", Item.Name));
		
		If FoundRows.Count() > 0 And FoundRows[0].Compound Then
			TabName = "Entries";
		EndIf;
		
		FormParameters = New Structure;
		FormParameters.Insert("Key"			, CurrentRow.TransactionTemplate);
		FormParameters.Insert("TabName"		, TabName);
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
Procedure Attachable_RecordSetOnStartEdit(Item, NewRow, Clone)
	
	If NewRow And Not Clone Then
		
		If Item.CurrentData.Property("Period") Then
			Item.CurrentData.Period = Object.Date;
		EndIf;
		
		If Item.CurrentData.Property("Company") And ValueIsFilled(Object.Company) Then
			Item.CurrentData.Company = Object.Company;
		EndIf;
		
		If Item.CurrentData.Property("Recorder") And ValueIsFilled(Object.Ref) Then
			Item.CurrentData.Recorder = Object.Ref;
		EndIf;
		
		Item.CurrentData.PlanningPeriod = PlanningPeriod;
		
		Item.CurrentData.Active = True;
		
		FoundRows = MasterTablesMap.FindRows(New Structure("TableName", Item.Name));
		
		Item.CurrentData.RecordSetPicture = -1;
		
		If FoundRows.Count() > 0 Then
			
			Item.CurrentData.TypeOfAccounting = FoundRows[0].TypeOfAccounting;
			
			If FoundRows[0].Compound Then 
				SetPictureInRow(Item.CurrentData);
			EndIf;
		EndIf;
		
	EndIf;
	
	If NewRow Then
		
		Item.CurrentData.TransactionTemplate			= Undefined;
		Item.CurrentData.TransactionTemplateLineNumber	= 0;
		Item.CurrentData.EntryNumber = "";
		
		RefreshTotalData();
		
	Else
		
		CurrentData = GetRowData(Item, Item.CurrentData, Item.Name);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetOnEditEnd(Item, NewRow, CancelEdit)

	If Not CancelEdit And AdjustedManually Then
		Item.CurrentData.TransactionTemplate			= Undefined;
		Item.CurrentData.TransactionTemplateLineNumber	= Undefined;
	EndIf;
	
	SortRecordSet(Item.Name);
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetOnChange(Item, NewRow, CancelEdit)

	SortRecordSet(Item.Name);
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetBeforeDeleteRow(Item, Cancel)
	
	If Not Cancel Then
		RefreshTotalData();
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetAfterDeleteRow(Item)
	
	IsComplexTypeOfEntries = IsComplexTypeOfEntries(Object.ChartOfAccounts, ThisObject[CurrentTableName].Count());
	
	If IsComplexTypeOfEntries Then
		
		MasterAccountingClientServer.RenumerateEntriesTabSection(ThisObject[CurrentTableName]);
		
		RenumerateLineNumbersInRecordSet(CurrentTableName, IsComplexTypeOfEntries);
	
	EndIf;
	
	RefreshTotalData();
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetRecordTypeOnChange(Item)
	
	CurrentRow = Items[CurrentTableName].CurrentData;
	
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
	
	SortRecordSet(CurrentTableName);
	MasterAccountingClientServer.RenumerateEntriesTabSection(ThisObject[CurrentTableName]);
	
	RefreshTotalData();
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetAmountCurDrOnChange(Item)
	
	CurrentRow = Items[CurrentTableName].CurrentData;
	
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	
	If CurrentRow.RecordType = AccountingRecordType.Debit Then
		CurrentRow.AmountCur = CurrentRow.AmountCurDr;
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetAmountCurCrOnChange(Item)
	
	CurrentRow = Items[CurrentTableName].CurrentData;
	
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	
	If CurrentRow.RecordType = AccountingRecordType.Credit Then
		CurrentRow.AmountCur = CurrentRow.AmountCurCr;
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetAmountDrOnChange(Item)
	
	CurrentRow = Items[CurrentTableName].CurrentData;
	
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	
	If CurrentRow.RecordType = AccountingRecordType.Debit Then
		CurrentRow.Amount = CurrentRow.AmountDr;
	EndIf;
	
	RefreshTotalData();
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetAmountCrOnChange(Item)
	
	CurrentRow = Items[CurrentTableName].CurrentData;
	
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	
	If CurrentRow.RecordType = AccountingRecordType.Credit Then
		CurrentRow.Amount = CurrentRow.AmountCr;
	EndIf;
	
	RefreshTotalData();
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetAmountOnChange(Item)
	
	CurrentRow = Items[CurrentTableName].CurrentData;
	
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	
	RefreshTotalData();
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetMasterAccountCrOnChange(Item)
	
	CurrentTable = Items[CurrentTableName];
	OnAccountChangeAtServer(CurrentTable.CurrentRow, "Cr");
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetMasterAccountOnChange(Item)
	
	CurrentTable = Items[CurrentTableName];
	OnAccountChangeAtServer(CurrentTable.CurrentRow);
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetMasterAccountDrOnChange(Item)
	
	CurrentTable = Items[CurrentTableName];
	OnAccountChangeAtServer(CurrentTable.CurrentRow, "Dr");
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

#Region LibrariesHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Object);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Object, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure
// End StandardSubsystems.AttachableCommands

#EndRegion

#Region DataImportFromExternalSources

&AtClient
Procedure DataImportFromExternalSources(Command)
	
	Cancel = False;
	AccountingEntriesSettings = DataImportFromExternalSourcesClient.GetAccountingEntriesSettings(ThisObject, CurrentTableName, Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	DataLoadSettings.Insert("FillingObjectFullName", "AccountingRegister.AccountingJournalEntriesCompound");
	DataLoadSettings.Insert("Title", NStr("en = 'Import accounting entries from file'; ru = 'Загрузить бухгалтерские проводки из файла';pl = 'Import wpisów księgowych z pliku';es_ES = 'Importar entradas de diario desde un archivo';es_CO = 'Importar entradas de diario desde un archivo';tr = 'Muhasebe girişlerini dosyadan içe aktar';it = 'Importare voci di contabilità da file';de = 'Buchungen aus Datei importieren'"));
	DataLoadSettings.Insert("AccountingEntriesSettings", AccountingEntriesSettings);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("AccountingEntriesSettings", AccountingEntriesSettings);
	AdditionalParameters.Insert("TableName", CurrentTableName);
	NotifyDescription = New NotifyDescription("DataImportFromExternalSourcesEnd", ThisObject, AdditionalParameters);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure DataImportFromExternalSourcesEnd(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		
		ImportResult.Insert("TableName", AdditionalParameters.TableName);
		ProcessPreparedData(ImportResult);
		SortRecordSet(CurrentTableName);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult, ThisObject[ImportResult.TableName]);
	RefreshTotalData();
	
EndProcedure

#EndRegion

&AtClient
Procedure Approve(Command)
	
	ClearMessages();
	
	If Modified Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("Status", PredefinedValue("Enum.AccountingEntriesStatus.Approved"));
		QuestionSave(AdditionalParameters);
		
	Else

		Status = PredefinedValue("Enum.AccountingEntriesStatus.Approved");
		SetNewStatus(False);
	
	EndIf;
	
EndProcedure

&AtClient
Procedure CancelApproval(Command)
	
	If Status = PredefinedValue("Enum.AccountingEntriesStatus.NotApproved") Or Not Object.Posted Then
		Return;
	EndIf;
	
	ClearMessages();
	
	If Modified Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("Status", PredefinedValue("Enum.AccountingEntriesStatus.NotApproved"));
		QuestionSave(AdditionalParameters);
		
	Else
		
		Status = PredefinedValue("Enum.AccountingEntriesStatus.NotApproved");
		SetNewStatus(False);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ApproveAndClose(Command)
	
	If Modified Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("CloseAfterWrite", True);
		AdditionalParameters.Insert("Status", PredefinedValue("Enum.AccountingEntriesStatus.Approved"));
		QuestionSave(AdditionalParameters);
		
	Else
		
		Status = PredefinedValue("Enum.AccountingEntriesStatus.Approved");
		SetNewStatus(True);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure OnCreateReadAtServer()
	
	CanApproveAccountingEntries = Users.RolesAvailable("ApproveAccountingEntries")
		And GetFunctionalOption("UseAccountingApproval");
	
	SetupTypesOfAccountingTable();
	
	PreviousCompany = Object.Company;
	PreviousDate = Object.Date;
	PreviousTypeOfAccounting = Object.TypeOfAccounting;
	PreviousChartOfAccounts = Object.ChartOfAccounts;
	
	GenerateMasterTables();
	FillFormAttributes();
	FillRecordSetsMaster();
	
	UpdateApprovalStatus();
	UpdatePostingStatus();
	
	FormManagement();
	
	SetTitle(Object.Ref);
	RefreshTotalData();
	
EndProcedure

&AtClient
Procedure QuestionSave(AdditionalParameters) Export 
	
	NotifyDescription	= New NotifyDescription("AfterQuestionSave", ThisObject, AdditionalParameters);
	QuestionText		= MessagesToUserClientServer.GetDataSaveQueryText();
	
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure AfterQuestionSave(Result, AdditionalParameters) Export
	
	CloseAfterWrite = AdditionalParameters.Property("CloseAfterWrite");
	
	If Result = DialogReturnCode.Yes Then
		
		WriteAndApprove(AdditionalParameters.Status, CloseAfterWrite);
		
	ElsIf Result = DialogReturnCode.No Then
		
		Modified = False;
		Read();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetNewStatus(CloseAfterApprove = False)
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("CloseAfterApprove", CloseAfterApprove);
	NotifyDescription = New NotifyDescription("ProcessStatusChange", ThisObject, AdditionalParameters);
	
	ProcedureParameters = New Structure("Document, Status, Comment, UUID");
	FillPropertyValues(ProcedureParameters, ThisObject);
	ProcedureParameters.Insert("AdjustedManually", AdjustedManually Or Object.IsManual);
	
	ProcedureParameters.Document = Object.Ref;
	
	AccountingApprovalClient.SetNewStatus(ThisObject, ProcedureParameters, NotifyDescription);
	
EndProcedure

&AtServer
Procedure FormManagement() Export

	Approved = (Status = PredefinedValue("Enum.AccountingEntriesStatus.Approved"));
	CanEditEntries = ((AdjustedManually Or Object.IsManual) And Not Approved);
	
	If Approved Then
		Items.Status.TextColor = GreenColor;
	Else
		Items.Status.TextColor = RedColor;
	EndIf;
	
	If CanApproveAccountingEntries Then
		
		Items.AdjustedManually.ReadOnly	= Approved;

		If Items.Find("FormPost") <> Undefined Then
			Items.FormPost.Enabled = Not Approved;
		EndIf;
		If Items.Find("FormPostAndClose") <> Undefined Then
			Items.FormPostAndClose.Enabled = Not Approved;
		EndIf;
		If Items.Find("FormPosting") <> Undefined Then
			Items.FormPosting.Enabled = Not Approved;
		EndIf;
		If Items.Find("FormUndoPosting") <> Undefined Then
			Items.FormUndoPosting.Enabled = Not Approved;
		EndIf;
		If Items.Find("FormWrite") <> Undefined Then
			Items.FormWrite.Enabled = Not Approved;
		EndIf;
		If Items.Find("FormSetDeletionMark") <> Undefined Then
			Items.FormSetDeletionMark.Enabled = Not Approved;
		EndIf;
		If Items.Find("FormRereadData") <> Undefined Then
			Items.FormRereadData.Enabled = Not Approved;
		EndIf;
		If Items.Find("FormCommonCommandObjectFill") <> Undefined Then
			Items.FormCommonCommandObjectFill.Enabled = Not Approved;
		EndIf;
		
	EndIf;
	
	If Items.Find("FormRereadData") <> Undefined Then
		Items.FormRereadData.Enabled = Items.FormRereadData.Enabled And CanEditEntries;
	EndIf;

	Items.AdjustedManually.Visible = Not Object.IsManual;
	Items.Company.ReadOnly = ValueIsFilled(Object.BasisDocument);
	Items.BasisDocument.Visible = Not Object.IsManual;
	Items.TypeOfAccounting.ReadOnly = Not Object.IsManual;
	Items.Template.Visible = Not Object.IsManual;
	Items.GroupApproval.Visible = CanApproveAccountingEntries;
	Items.Description.Visible = Object.IsManual;
	
	For Each MapRow In MasterTablesMap Do
		
		Id = StrReplace(MapRow.TableName, "RecordSetMaster_", "");
		Items["RecordSetGroupTemplate_" + Id].Visible = Not Object.IsManual;
		Items[MapRow.TableName].ReadOnly = Not CanEditEntries;
		Items[MapRow.TableName + "LineNumber"].Visible = Not MapRow.Compound;
		Items.TotalDifference.Visible = MapRow.Compound;
		Items.CompanyPresentationCurrency.Visible = MapRow.Compound;
		
		If MapRow.Compound Then
			Items[MapRow.TableName + "CommandBar"].Enabled = CanEditEntries;
			
			Items[MapRow.TableName + "NumberPresentation"].Visible = True;
			
			Items[MapRow.TableName + "AmountDr"].Title = 
				StrTemplate(NStr("en = 'Amount Dr (%1)'; ru = 'Сумма Дт (%1)';pl = 'Wartość Wn (%1)';es_ES = 'Importe Débito (%1)';es_CO = 'Importe Débito (%1)';tr = 'Tutar Borç (%1)';it = 'Importo deb (%1)';de = 'Betrag Soll (%1)'"),
				String(Object.DocumentCurrency));
				
			Items[MapRow.TableName + "AmountCr"].Title = 
				StrTemplate(NStr("en = 'Amount Cr (%1)'; ru = 'Сумма Кт (%1)';pl = 'Wartość Ma (%1)';es_ES = 'Importe Crédito (%1)';es_CO = 'Importe Crédito (%1)';tr = 'Tutar Alacak (%1)';it = 'Importo cred (%1)';de = 'Betrag Haben (%1)'"),
				String(Object.DocumentCurrency));
				
		Else
			
			Items[MapRow.TableName + "EntryNumber"].Visible = False;
			
			Items[MapRow.TableName + "Amount"].Title = 
				StrTemplate(NStr("en = 'Amount (%1)'; ru = 'Сумма (%1)';pl = 'Wartość (%1)';es_ES = 'Importe (%1)';es_CO = 'Importe (%1)';tr = 'Tutar (%1)';it = 'Importo (%1)';de = 'Betrag (%1)'"),
				String(Object.DocumentCurrency));
				
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure AfterStatusChangingAtServer(ResultAddress) Export

	Result = GetFromTempStorage(ResultAddress);
	
	If TypeOf(Result) = Type("ValueTable")
		And Result.Count() Then
		FillPropertyValues(ThisObject, Result[0]);
	EndIf;

EndProcedure

&AtClient
Function GetRowData(Item, CurrentRow, ItemName)
	
	Result = New Structure;

	For Each ChildItem In Item.ChildItems Do
		
		If TypeOf(ChildItem) = Type("FormField") Then
			
			Name = StrReplace(ChildItem.Name, ItemName, "");
			Result.Insert(Name, CurrentRow[Name]);
			
		ElsIf TypeOf(ChildItem) = Type("FormGroup") Then
			
			TempResultStructure = GetRowData(ChildItem, CurrentRow, ItemName);
			
			For Each Element In TempResultStructure Do
				
				Result.Insert(Element.Key, Element.Value);
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	Return Result;

EndFunction

&AtServer
Procedure FillFormAttributes()
	
	PlanningPeriod = Catalogs.PlanningPeriods.Actual;
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	DocumentAccountingEntriesStatuses.Status AS Status,
	|	DocumentAccountingEntriesStatuses.AdjustedManually AS AdjustedManually
	|FROM
	|	InformationRegister.DocumentAccountingEntriesStatuses AS DocumentAccountingEntriesStatuses
	|WHERE
	|	DocumentAccountingEntriesStatuses.Recorder = &Document
	|	AND DocumentAccountingEntriesStatuses.TypeOfAccounting = &TypeOfAccounting";
	
	Query.SetParameter("Document"			, Object.Ref);
	Query.SetParameter("TypeOfAccounting"	, Object.TypeOfAccounting);
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		FillPropertyValues(ThisObject, Selection);
	Else
		Status = Enums.AccountingEntriesStatus.NotApproved;
	EndIf;
	
	Query = New Query;
	Query.Text	=
	"SELECT DISTINCT
	|	AccountingTransactionTemplates.Template AS Template
	|FROM
	|	Document.AccountingTransaction.Templates AS AccountingTransactionTemplates
	|WHERE
	|	AccountingTransactionTemplates.Ref = &Ref";
	
	Query.SetParameter("Ref", Object.Ref);
	
	QueryResult = Query.Execute();
	
	Template.LoadValues(QueryResult.Unload().UnloadColumn("Template"));
	
EndProcedure

&AtClient
Procedure SetPictureInRow(CurrentRow)
	
	If CurrentRow.RecordType = AccountingRecordType.Credit And CurrentRow.Active Then
		CurrentRow.RecordSetPicture = 2;
	ElsIf CurrentRow.RecordType = AccountingRecordType.Credit And Not CurrentRow.Active Then
		CurrentRow.RecordSetPicture = 4;
	ElsIf CurrentRow.RecordType = AccountingRecordType.Debit And CurrentRow.Active Then
		CurrentRow.RecordSetPicture = 1;
	ElsIf CurrentRow.RecordType = AccountingRecordType.Debit And Not CurrentRow.Active Then
		CurrentRow.RecordSetPicture = 3;
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshTotalData()
	
	MasterAccounting.RefreshTotalData(ThisObject);
	
EndProcedure

&AtServer
Procedure FillRecordSetsMaster()
	
	For Each MapRow In MasterTablesMap Do

		CurrentTable = ThisObject[MapRow.TableName];
		
		If MapRow.TypeOfEntries = Enums.ChartsOfAccountsTypesOfEntries.Simple Then
			RecordSetTable = Object.RegisterRecords.AccountingJournalEntriesSimple;
			NewTable = AccountingRegisters.AccountingJournalEntriesSimple.GetSimplePresentation(RecordSetTable.Unload());
		Else
			RecordSetTable = Object.RegisterRecords.AccountingJournalEntriesCompound;
			NewTable = AccountingRegisters.AccountingJournalEntriesCompound.GetCompoundPresentation(RecordSetTable.Unload());
		EndIf;
		
		MasterAccounting.FillMiscFields(NewTable);
		
		CurrentTable.Load(NewTable);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SetTitle(Ref)

	TitleParameters = New Structure;
	TitleParameters.Insert("Ref", Ref);
	TitleParameters.Insert("Number", Object.Number);
	TitleParameters.Insert("Date", Object.Date);
	TitleParameters.Insert("Posted", Object.Posted);
	TitleParameters.Insert("IsManual", Object.IsManual);
	TitleParameters.Insert("DeletionMark", Object.DeletionMark);
	
	Title = Documents.AccountingTransaction.GetTitle(TitleParameters);
	
EndProcedure

&AtServer
Procedure SetupTypesOfAccountingTable()
	
	If Not ValueIsFilled(Object.Company) Then
		TypesOfAccountingTable.Clear();
		Return;
	EndIf;
	
	TypesOfAccountingValueTable = AccountingTemplatesPosting.GetApplicableTypesOfAccounting(
		Object.Company,
		Documents.AccountingTransaction.GetAcountingPolicyDate(Object),
		Catalogs.TypesOfAccounting.EmptyRef(),
		Undefined,
		True);
		
	TypesOfAccountingTable.Load(TypesOfAccountingValueTable);
	
	Items.TypeOfAccounting.ChoiceList.LoadValues(
		TypesOfAccountingTable.Unload(, "TypeOfAccounting").UnloadColumn("TypeOfAccounting"));
	
EndProcedure

&AtServer
Procedure OnAccountChangeAtServer(CurrentRowId, Suffix = Undefined)
	
	RowData = ThisObject[MasterTablesMap[0].TableName].FindByID(CurrentRowId);
	RowsArray = CommonClientServer.ValueInArray(RowData);
	
	If Suffix <> Undefined Then
		
		SuffixesArray = New Array;
		SuffixesArray.Add(Suffix);
		
		MasterAccounting.FillMiscFields(RowsArray, SuffixesArray);
		
	Else
		
		MasterAccounting.FillMiscFields(RowsArray);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateApprovalStatus()
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	DocumentAccountingEntriesStatuses.Status AS Status
	|FROM
	|	InformationRegister.DocumentAccountingEntriesStatuses AS DocumentAccountingEntriesStatuses
	|WHERE
	|	DocumentAccountingEntriesStatuses.Recorder = &Document";
	
	Query.SetParameter("Document", Object.Ref);
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next()
		And Selection.Status = Enums.AccountingEntriesStatus.Approved Then
		
		DocumentApprovalStatus = NStr("en = 'Approved'; ru = 'Утверждена';pl = 'Zatwierdzony';es_ES = 'Aprobado';es_CO = 'Aprobado';tr = 'Onaylandı';it = 'Approvato';de = 'Genehmigt'");
		Items.DocumentApprovalStatus.TextColor = GreenColor;
		
	Else
		
		DocumentApprovalStatus = NStr("en = 'Not approved'; ru = 'Не утверждена';pl = 'Nie zatwierdzony';es_ES = 'No aprobado';es_CO = 'No aprobado';tr = 'Onaylanmadı';it = 'Non approvato';de = 'Nicht genehmigt'");
		Items.DocumentApprovalStatus.TextColor = RedColor;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdatePostingStatus()
	
	If Object.Posted Then
		DocumentPostingStatus = NStr("en = 'Posted'; ru = 'Проведена';pl = 'Zatwierdzony';es_ES = 'Enviado';es_CO = 'Enviado';tr = 'Kaydedildi';it = 'Pubblicato';de = 'Gebucht'");
		Items.DocumentPostingStatus.TextColor = GreenColor;
	Else
		DocumentPostingStatus = NStr("en = 'Not posted'; ru = 'Не проведена';pl = 'Niezatwierdzone';es_ES = 'Sin contabilizar';es_CO = 'Sin contabilizar';tr = '(onaylanmadı)';it = 'Non pubblicato';de = 'Nicht gebucht'");
		Items.DocumentPostingStatus.TextColor = RedColor;
	EndIf;
	
	If Object.DeletionMark Then
		DocumentPostingStatus = NStr("en = 'Marked for deletion'; ru = 'Помечена на удаление';pl = 'Zaznaczony do usunięcia';es_ES = 'Marcado para borrar';es_CO = 'Marcado para borrar';tr = 'Silinmek üzere işaretlendi';it = 'Contrassegnato per l''eliminazione';de = 'Zum Löschen markiert'");
		Items.DocumentPostingStatus.TextColor = RedColor;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCompanyInEntryTable()
	
	CompanyData = Common.ObjectAttributesValues(Object.Company, "PresentationCurrency");
	Object.DocumentCurrency = CompanyData.PresentationCurrency;
	
	For Each MasterTableRow In MasterTablesMap Do
		
		For Each TableRow In ThisObject[MasterTableRow.TableName] Do
			TableRow.Company = Object.Company;
		EndDo;
		
	EndDo;
	
	FormManagement();
	
EndProcedure

&AtServer
Procedure FillDateInEntryTable()
	
	For Each MasterTableRow In MasterTablesMap Do
		
		For Each TableRow In ThisObject[MasterTableRow.TableName] Do
			TableRow.Period = Object.Date;
		EndDo;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure TypeOfAccountingOnChangeEnd(Result, AdditionalParameters) Export
	
	If Not Result = DialogReturnCode.Yes Then
		Object.TypeOfAccounting = PreviousTypeOfAccounting;
		Return;
	EndIf;
	
	Object.ChartOfAccounts = AdditionalParameters.NewChartOfAccounts;
	TypeOfAccountingOnChangeFragmentAtServer();
	FormManagementClient();
	
EndProcedure

&AtServer
Procedure TypeOfAccountingOnChangeFragmentAtServer()
	
	PreviousTypeOfAccounting = Object.TypeOfAccounting;
	GenerateMasterTables();
	
EndProcedure

&AtServer
Procedure FillAttributesByCompany()
	
	If Not ValueIsFilled(Object.Ref)
		And ValueIsFilled(Object.Company)
		And ValueIsFilled(Object.TypeOfAccounting)
		And ValueIsFilled(Object.ChartOfAccounts) Then
		
		GenerateMasterTables();
		FillRecordSetsMaster();
		FormManagement();
		RefreshTotalData();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ProcessDateChange()
	
	AccountingSettingsCheck = IsAccountingSettingsApplicable(Object.TypeOfAccounting, Object.ChartOfAccounts, Object.Company, Object.Date);
	If AccountingSettingsCheck.IsTypeOfAccountingApplicable
		And AccountingSettingsCheck.IsChartOfAccountsApplicable Then
		
		DateOnChangeEndAtServer(AccountingSettingsCheck);
		Return;
		
	EndIf;
	
	If Not AccountingSettingsCheck.IsTypeOfAccountingApplicable Then
		
		MessageText = StrTemplate(MessagesToUserClientServer.GetAccountingTransactionDateChangeQueryText(False),
			Object.TypeOfAccounting,
			Object.Company,
			Format(Object.Date, "DLF=D"));
		
	Else
		
		MessageText = StrTemplate(MessagesToUserClientServer.GetAccountingTransactionDateChangeQueryText(True),
			Object.ChartOfAccounts,
			Object.Company,
			Object.TypeOfAccounting,
			Format(Object.Date, "DLF=D"));
		
	EndIf;
	
	NotifyDescription = New NotifyDescription("ProcessDateChangeEnd", ThisObject, AccountingSettingsCheck);
	ShowQueryBox(NotifyDescription, MessageText, QuestionDialogMode.YesNo, , DialogReturnCode.No);
	
EndProcedure

&AtServer
Function IsAccountingSettingsApplicable(TypeOfAccounting, ChartOfAccounts, Company, Date)
	Result = New Structure;
	Result.Insert("IsTypeOfAccountingApplicable", True);
	Result.Insert("IsChartOfAccountsApplicable", True);
	Result.Insert("ChartOfAccounts", Undefined);
	If Not ValueIsFilled(TypeOfAccounting) Then
		Return Result;
	EndIf;
	
	TypesOfAccounting = InformationRegisters.CompaniesTypesOfAccounting.GetTypesOfAccountingTable(Company, Date);
	
	Filter = New Structure;
	Filter.Insert("TypeOfAccounting", TypeOfAccounting);
	
	TypesOfAccountingRows = TypesOfAccounting.FindRows(Filter);
	
	If TypesOfAccountingRows.Count() = 0 Then
		Result.IsTypeOfAccountingApplicable = False;
		Return Result;
	EndIf;
	
	For Each Row In TypesOfAccountingRows Do
		
		If Row.ChartOfAccounts = ChartOfAccounts Then
			Result.IsChartOfAccountsApplicable = True;
		Else
			Result.IsChartOfAccountsApplicable = False;
			Result.ChartOfAccounts = Row.ChartOfAccounts;
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

&AtClient
Procedure ProcessDateChangeEnd(Result, AdditionalParameters) Export
	
	If Not Result = DialogReturnCode.Yes Then
		
		Object.Date = DocumentDate;
		Return;
		
	EndIf;
	
	DateOnChangeEndAtServer(AdditionalParameters);
	
EndProcedure

&AtServer
Procedure DateOnChangeEndAtServer(AdditionalParameters)
	
	DocumentDate = Object.Date;
	
	If Not AdditionalParameters.IsTypeOfAccountingApplicable Then
	
		PreviousTypeOfAccounting = Catalogs.TypesOfAccounting.EmptyRef();
		Object.TypeOfAccounting = Catalogs.TypesOfAccounting.EmptyRef();
		
	EndIf;
	
	If Not AdditionalParameters.IsChartOfAccountsApplicable Then
		
		Object.ChartOfAccounts = AdditionalParameters.ChartOfAccounts;
		GenerateMasterTables();
		
	EndIf;
	
	SetupTypesOfAccountingTable();
	FillDateInEntryTable();
	
EndProcedure

&AtClient
Procedure CompanyOnChangeEnd(Result, AdditionalParameters) Export
	
	If Not Result = DialogReturnCode.Yes Then
		
		Object.Company = PreviousCompany;
		Return;
		
	EndIf;
	
	CompanyOnChangeEndAtServer(AdditionalParameters);
	MasterTablesCommands();
	FormManagementClient();

EndProcedure

&AtServer
Procedure CompanyOnChangeEndAtServer(AdditionalParameters)
	
	PreviousCompany = Object.Company;
	
	If Not AdditionalParameters.IsTypeOfAccountingApplicable Then
		
		PreviousTypeOfAccounting = Catalogs.TypesOfAccounting.EmptyRef();
		Object.TypeOfAccounting = Catalogs.TypesOfAccounting.EmptyRef();
		
	EndIf;
	
	If Not AdditionalParameters.IsChartOfAccountsApplicable Then
		
		Object.ChartOfAccounts = AdditionalParameters.ChartOfAccounts;
		GenerateMasterTables();
		
	EndIf;
	
	SetupTypesOfAccountingTable();
	FillCompanyInEntryTable();
	
EndProcedure

&AtClient
Procedure ProcessStatusChange(Result, AdditionalParameters) Export
	
	DocumentAccountingEntriesStatusesRecordSet = Object.RegisterRecords.DocumentAccountingEntriesStatuses;
	
	For Each Record In DocumentAccountingEntriesStatusesRecordSet Do
		Record.Status = Result;
	EndDo;
	
	Status = Result;
	
	If AdditionalParameters.CloseAfterApprove Then
		
		Close();
		
	EndIf;
	
	FormManagement();

EndProcedure

&AtClient
Procedure WriteAndApprove(NewStatus, CloseAfterWrite = False)
	
	WriteParameters = New Structure;
	WriteParameters.Insert("WriteMode", DocumentWriteMode.Posting);
	
	If Write(WriteParameters) Then
		
		Status = NewStatus;
		SetNewStatus(CloseAfterWrite);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure RestoreOriginalEntriesAtServer()
	
	Cancel = False;
	
	SetPrivilegedMode(True);

	BeginTransaction();
	Try
		
		AccountingEntriesTables = AccountingTemplatesPosting.GetAccountingEntriesTablesStructure(
			Object.BasisDocument,
			Cancel,
			Object.TypeOfAccounting);
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Cancel = True;
		Return;
		
	EndTry;
	
	SetPrivilegedMode(False);

	If Cancel Then
		Return;
	EndIf;
	
	TableAccountingJournalEntriesCompound	= AccountingEntriesTables.TableAccountingJournalEntriesCompound;
	TableAccountingJournalEntriesSimple		= AccountingEntriesTables.TableAccountingJournalEntriesSimple;
	
	If MasterTablesMap.Count() > 0 Then
		
		If Not Cancel And TableAccountingJournalEntriesCompound <> Undefined And TableAccountingJournalEntriesCompound.Count() > 0 Then
			
			ThisObject[MasterTablesMap[0].TableName].Load(TableAccountingJournalEntriesCompound);
			InitialTable = ThisObject[MasterTablesMap[0].TableName].Unload();
			
			AccountingRegisters.AccountingJournalEntriesCompound.SetEntryNumbers(InitialTable);
			NewTable = AccountingRegisters.AccountingJournalEntriesCompound.GetCompoundPresentation(InitialTable);
			
		ElsIf Not Cancel And TableAccountingJournalEntriesSimple <> Undefined And TableAccountingJournalEntriesSimple.Count() > 0 Then
			
			NewTable = AccountingRegisters.AccountingJournalEntriesSimple.GetSimplePresentation(TableAccountingJournalEntriesSimple);
			
		EndIf;
		
		MasterAccounting.FillMiscFields(NewTable);
		ThisObject[MasterTablesMap[0].TableName].Load(NewTable);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure GenerateMasterTables()
	
	MasterAccountingParameters = New Structure;
	MasterAccountingParameters.Insert("ChartOfAccounts", Object.ChartOfAccounts);
	MasterAccountingParameters.Insert("TypeOfAccounting", Object.TypeOfAccounting);

	MasterAccountingFormGeneration.GenerateMasterTables(ThisObject, MasterAccountingParameters, "Pages");
	
	For Each TableRow In MasterTablesMap Do
		
		Items.Move(Items[TableRow.PageName], Items.Pages, Items.GroupAdditionalInfo);
		Items.Pages.CurrentPage = Items[TableRow.PageName];
		Items[TableRow.PageName].Title = NStr("en = 'Entries'; ru = 'Проводки';pl = 'Wpisy';es_ES = 'Entradas de diario';es_CO = 'Entradas de diario';tr = 'Girişler';it = 'Voci';de = 'Buchungen'");
		CurrentTableName = TableRow.TableName;
		Items.TotalDifference.Visible = Not TableRow.Compound;
		
		Items[TableRow.PageName].ReadOnly = Not ValueIsFilled(Object.TypeOfAccounting);
		
	EndDo;
	
	Items.RecordSetTable.Visible = False;
	
EndProcedure

&AtServer
Procedure MasterTablesCommands()
	MasterAccountingFormGeneration.MasterTablesCommands(ThisObject);
EndProcedure

&AtClient
Procedure AdjustManuallyOnChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		RestoreOriginalEntriesAtServer();
		FormManagement();
		
	Else
		
		AdjustedManually = Not AdjustedManually;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SortRecordSet(ItemName)
	
	IsComplexTypeOfEntries = IsComplexTypeOfEntries(Object.ChartOfAccounts, ThisObject[CurrentTableName].Count());
	
	If IsComplexTypeOfEntries Then
		
		IsSortOrderAsc = String(AccountingRecordType.Debit) < String(AccountingRecordType.Credit);
		
		If IsSortOrderAsc Then
			ThisObject[ItemName].Sort("EntryNumber, RecordType");
		Else
			ThisObject[ItemName].Sort("EntryNumber, RecordType Desc");
		EndIf;
		
	EndIf;
	
	RenumerateLineNumbersInRecordSet(ItemName, IsComplexTypeOfEntries);
	
EndProcedure

&AtServer
Procedure RenumerateLineNumbersInRecordSet(ItemName, Compound)
	
	If Compound Then
		
		EntryNumber = 0;
		
		For Each Row In ThisObject[ItemName] Do
			
			If EntryNumber <> Row.EntryNumber Then
				EntryNumber		= Row.EntryNumber;
				EntryLineNumber = 1;
			EndIf;
			
			Row.EntryLineNumber = EntryLineNumber;
			Row.NumberPresentation = StrTemplate("%1/%2", EntryNumber, EntryLineNumber);
			EntryLineNumber		= EntryLineNumber + 1;
			
		EndDo;
		
	Else
		
		LineNumber = 1;
		
		For Each Row In ThisObject[ItemName] Do
			
			Row.LineNumber = LineNumber;
			LineNumber		= LineNumber + 1;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FormManagementClient()
	
	For Each MapRow In MasterTablesMap Do
		
		If MapRow.Compound Then
			
			For Each ButtonItem In Items[MapRow.TableName + "CommandBar"].ChildItems Do
				
				If StrFind(ButtonItem.Name, "ExtraButton") = 0 Then
					ButtonItem.Visible = False;
				EndIf;
				
			EndDo;
			
			Items[MapRow.TableName + "ContextMenuAdd"].Visible = False;
			Items[MapRow.TableName + "ContextMenuCopy"].Visible = False;
			Items[MapRow.TableName + "ContextMenuMoveUp"].Visible = False;
			Items[MapRow.TableName + "ContextMenuMoveDown"].Visible = False;
			
		EndIf;
		
		ID = StrReplace(MapRow.PageName, "Page_", "");
		Items[StrTemplate("RecordSetGroupTemplate_%1", ID)].Visible = False;
		
		Items.TotalDifference.Visible = MapRow.Compound;
	
	EndDo;
	
EndProcedure

&AtClient
Procedure AddEntry(Command)
	
	DefaultData = New Structure;
	DefaultData.Insert("Company", Object.Company);
	DefaultData.Insert("Period"	, Object.Date);
	
	CurrentRowLineNumber = MasterAccountingClientServer.AddEntry(ThisObject[CurrentTableName], DefaultData, "AccountingTransaction");
	
	RenumerateLineNumbersInRecordSet(CurrentTableName, True);
	
	TableIsFilled = (ThisObject[CurrentTableName].Count() <> 0);
	Items[CurrentTableName+"ExtraButtonEntriesUp"].Enabled 		= TableIsFilled;
	Items[CurrentTableName+"ExtraButtonEntriesDown"].Enabled 	= TableIsFilled;
	Items[CurrentTableName+"ContextMenuEntriesUp"].Enabled 		= TableIsFilled;
	Items[CurrentTableName+"ContextMenuEntriesDown"].Enabled 	= TableIsFilled;

	Items[CurrentTableName].CurrentRow = CurrentRowLineNumber;
	
EndProcedure

&AtClient
Procedure AddEntryLine(Command)
	
	CurrentTableData = Items[CurrentTableName].CurrentData;
	If CurrentTableData = Undefined Then
		Return;
	EndIf;
	
	IsComplexTypeOfEntries = IsComplexTypeOfEntries(Object.ChartOfAccounts, ThisObject[CurrentTableName].Count());
	
	DefaultData = New Structure;
	DefaultData.Insert("Company", Object.Company);
	DefaultData.Insert("Period"	, Object.Date);
	DefaultData.Insert("CurrentIndex", ThisObject[CurrentTableName].IndexOf(CurrentTableData));
	DefaultData.Insert("IsComplexTypeOfEntries", IsComplexTypeOfEntries);
	
	CurrentRowLineNumber = MasterAccountingClientServer.AddEntryLine(ThisObject[CurrentTableName], DefaultData, "AccountingTransaction");
	
	RenumerateLineNumbersInRecordSet(CurrentTableName, True);
	
	Items[CurrentTableName].CurrentRow = CurrentRowLineNumber;
	
EndProcedure

&AtClient
Procedure EntriesUp(Command)
	
	IsComplexTypeOfEntries = IsComplexTypeOfEntries(Object.ChartOfAccounts, ThisObject[CurrentTableName].Count());
	
	If IsComplexTypeOfEntries Then
		SelectedRowsIDs = Items[CurrentTableName].SelectedRows;
		RowsArray = New Array;
		
		SortedSelectedRowsIDs = SortSelectedRowsArray(CurrentTableName, SelectedRowsIDs);
		
		For Each SelectedRowID In SortedSelectedRowsIDs Do
			RowsArray.Add(ThisObject[CurrentTableName].FindByID(SelectedRowID));
		EndDo;
		DefaultData = New Structure;
		DefaultData.Insert("Company"	, Object.Company);
		DefaultData.Insert("Period"		, Object.Date);
		DefaultData.Insert("RowsArray"	, RowsArray);
		DefaultData.Insert("Direction"	, -1);
		
		MasterAccountingClientServer.MoveEntriesUpDown(ThisObject[CurrentTableName], DefaultData, "AccountingTransaction");
		
		RenumerateLineNumbersInRecordSet(CurrentTableName, True);
	
	EndIf;
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure EntriesDown(Command)
	
	IsComplexTypeOfEntries = IsComplexTypeOfEntries(Object.ChartOfAccounts, ThisObject[CurrentTableName].Count());
	
	If IsComplexTypeOfEntries Then
		SelectedRowsIDs = Items[CurrentTableName].SelectedRows;
		RowsArray = New Array;
		
		SortedSelectedRowsIDs = SortSelectedRowsArray(CurrentTableName, SelectedRowsIDs);
		
		For Each SelectedRowID In SortedSelectedRowsIDs Do
			RowsArray.Add(ThisObject[CurrentTableName].FindByID(SelectedRowID));
		EndDo;
		DefaultData = New Structure;
		DefaultData.Insert("Company"	, Object.Company);
		DefaultData.Insert("Period"		, Object.Date);
		DefaultData.Insert("RowsArray"	, RowsArray);
		DefaultData.Insert("Direction"	, 1);
		
		MasterAccountingClientServer.MoveEntriesUpDown(ThisObject[CurrentTableName], DefaultData, "AccountingTransaction");
		
		RenumerateLineNumbersInRecordSet(CurrentTableName, True);
	
	EndIf;
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure CopyEntriesRows(Command)
	
	IsComplexTypeOfEntries = IsComplexTypeOfEntries(Object.ChartOfAccounts, ThisObject[CurrentTableName].Count());
	
	If IsComplexTypeOfEntries Then
		
		SelectedRowsIDs = Items[CurrentTableName].SelectedRows;
		RowsArray = New Array;
		
		SortedSelectedRowsIDs = SortSelectedRowsArray(CurrentTableName, SelectedRowsIDs);
		
		For Each SelectedRowID In SortedSelectedRowsIDs Do
			RowsArray.Add(ThisObject[CurrentTableName].FindByID(SelectedRowID));
		EndDo;
		
		DefaultData = New Structure;
		DefaultData.Insert("Company"	, Object.Company);
		DefaultData.Insert("Period"		, Object.Date);
		DefaultData.Insert("RowsArray"	, RowsArray);
		
		CurrentRowId = MasterAccountingClientServer.CopyEntriesRows(ThisObject[CurrentTableName], DefaultData, "AccountingTransaction");
		If CurrentRowId <> Undefined Then
			Items[CurrentTableName].CurrentRow = CurrentRowId;
		EndIf;
		
		RenumerateLineNumbersInRecordSet(CurrentTableName, True);

	EndIf;
	
	RefreshTotalData();
	Modified = True;
	
EndProcedure

&AtClient
Procedure DeleteEntry(Command)
	
	IsComplexTypeOfEntries = IsComplexTypeOfEntries(Object.ChartOfAccounts, ThisObject[CurrentTableName].Count());
	
	If IsComplexTypeOfEntries Then
		
		RowsArray = New Array;
		For Each SelectedRowID In Items[CurrentTableName].SelectedRows Do
			RowsArray.Add(ThisObject[CurrentTableName].FindByID(SelectedRowID));
		EndDo;
		
		For Each Row In RowsArray Do
			ThisObject[CurrentTableName].Delete(Row);
		EndDo;
		
		Attachable_RecordSetAfterDeleteRow(Items[CurrentTableName]);
		
		Modified = True;
		
	EndIf;
	
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

&AtClient
Procedure TypeOfAccountingClearing(Item, StandardProcessing)
	
	Object.ChartOfAccounts = Undefined;
	GenerateMasterTables();
	Items.TotalDifference.Visible = False;
	
EndProcedure

#EndRegion
