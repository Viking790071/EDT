
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CompletedJob	= StyleColors.CompletedJob;
	ErrorNoteText	= StyleColors.ErrorNoteText;
	
	Reread			= NStr("en = 'Reread'; ru = 'Перечитать';pl = 'Wczytaj ponownie';es_ES = 'Leer de nuevo';es_CO = 'Leer de nuevo';tr = 'Tekrar oku';it = 'Rileggi';de = 'Neu lesen'");
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	FillFormAttributes();
	
	FilterRecorderValue = RecordSet.Filter.Recorder.Value;
	FilterRecorderUse	= RecordSet.Filter.Recorder.Use;
	
	RecordSetMasterFilterRecorder = RecordSetMaster.Filter.Recorder;
	RecordSetMasterFilterRecorder.Value	= FilterRecorderValue;
	RecordSetMasterFilterRecorder.Use	= FilterRecorderUse;
	
	RecordSetSimpleFilterRecorder = RecordSetSimple.Filter.Recorder;
	RecordSetSimpleFilterRecorder.Value	= FilterRecorderValue;
	RecordSetSimpleFilterRecorder.Use	= FilterRecorderUse;
	
	RecordSetMasterTable = AccountingApprovalServer.GetRecordSetMasterByRecorder(FilterRecorderValue);
	RecordSetMaster.Load(RecordSetMasterTable);
	
	RecordSetSimpleTable = AccountingApprovalServer.GetRecordSetSimpleByRecorder(FilterRecorderValue);
	RecordSetSimple.Load(RecordSetSimpleTable);
	
	RecordSetMasterSet = FormAttributeToValue("RecordSetMaster");
	RecordSetSimpleSet = FormAttributeToValue("RecordSetSimple");
	
	IsClosingPeriod = PeriodClosingDates.DataChangesDenied(CurrentObject) 
		Or PeriodClosingDates.DataChangesDenied(RecordSetMasterSet)
		Or PeriodClosingDates.DataChangesDenied(RecordSetSimpleSet);
	
	GenerateMasterTables();
	
	TempRecordSetMasterSimple	= RecordSetMasterSimple.Unload();
	TempRecordSetMasterCompound	= RecordSetMasterCompound.Unload();
	
	FillRecordSetsMaster(RecordSetMaster, RecordSetSimpleSet, TempRecordSetMasterSimple, TempRecordSetMasterCompound);
	RecordSetMasterSimple.Load(TempRecordSetMasterSimple);
	RecordSetMasterCompound.Load(TempRecordSetMasterCompound);
	
	RecordSetMasterBeforeEdit.Load(TempRecordSetMasterCompound);
	RecordSetSimpleBeforeEdit.Load(TempRecordSetMasterSimple);
	
	RefreshTotalData();
	
	CompanyPresentationCurrency = Company.PresentationCurrency;
	AmountDrTitle	= StrTemplate(NStr("en = 'Amount Dr (%1)'; ru = 'Сумма Дт (%1)';pl = 'Wartość Wn (%1)';es_ES = 'Importe Débito (%1)';es_CO = 'Importe Débito (%1)';tr = 'Tutar Borç (%1)';it = 'Importo deb (%1)';de = 'Betrag Soll (%1)'")	, CompanyPresentationCurrency);
	AmountCrTitle	= StrTemplate(NStr("en = 'Amount Cr (%1)'; ru = 'Сумма Кт (%1)';pl = 'Wartość Ma (%1)';es_ES = 'Importe Crédito (%1)';es_CO = 'Importe Crédito (%1)';tr = 'Tutar Alacak (%1)';it = 'Importo cred (%1)';de = 'Betrag Haben (%1)'")	, CompanyPresentationCurrency);
	AmountTitle		= StrTemplate(NStr("en = 'Amount (%1)'; ru = 'Сумма (%1)';pl = 'Wartość (%1)';es_ES = 'Importe (%1)';es_CO = 'Importe (%1)';tr = 'Tutar (%1)';it = 'Importo (%1)';de = 'Betrag (%1)'")	, CompanyPresentationCurrency);
	
	For Each Table In MasterTablesMap Do
		
		If Table.Compound Then
			
			Items[StrTemplate("%1AmountDr", Table.TableName)].Title = AmountDrTitle;
			Items[StrTemplate("%1AmountCr", Table.TableName)].Title = AmountCrTitle;
			
		Else
			
			Items[StrTemplate("%1Amount", Table.TableName)].Title = AmountTitle;
			
		EndIf;
		
	EndDo;
	
	If GetFunctionalOption("UseAccountingTemplates") And MasterTablesMap.Count() = 0 Then
		
		Items.CommandBarGroupForm.Visible	= False;
		Items.RecordSetsCommand.Visible		= False;
		Items.GroupCommentTotals.Visible	= False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	SetNewStatus();
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	RecordSetMasterBeforeEdit.Load(RecordSetMaster.Unload());
	RecordSetSimpleBeforeEdit.Load(RecordSetSimple.Unload());
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	ClearMessages();
	RecordSetMasterHasBeenChanged = GatherRecordSets(Cancel);
	
	If RecordSetMasterHasBeenChanged Then
		
		NotifyDescription = New NotifyDescription("AfterQuestionReread", ThisObject);
		QuestionText = MessagesToUserClientServer.GetDataChangedQueryText();
		ButtonsValueList = New ValueList;
		ButtonsValueList.Add(Reread);
		ButtonsValueList.Add(NStr("en = 'Cancel'; ru = 'Отмена';pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal';it = 'Annulla';de = 'Abbrechen'"));
		ShowQueryBox(NotifyDescription, QuestionText, ButtonsValueList);
		
		Cancel = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	WriteRecordSetMaster(Cancel);
	WriteRecordSetSimple(Cancel);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FormManagement();
	FormManagementClient();
	
EndProcedure

&AtClient
Procedure RereadData(Command)
	
	Read();
	FormManagement();
	FormManagementClient();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AdjustManuallyOnChange(Item)
	
	AdjustManuallyOnChangeEndCallback = New NotifyDescription("AdjustManuallyOnChangeEnd", ThisObject);
	
	NotificationParameters = New Structure;
	NotificationParameters.Insert("Form", ThisObject);
	NotificationParameters.Insert("Document", Document);
	NotificationParameters.Insert("AdjustManuallyOnChangeEndCallback", AdjustManuallyOnChangeEndCallback);
	
	NotifyDescription = New NotifyDescription("AdjustManuallyOnChangeEnd", AccountingApprovalClient,
		NotificationParameters);
	
	If Not AdjustedManually Then
		
		Text = NStr("en = 'The entries will be updated and saved. Continue?'; ru = 'Проводки будут обновлены и сохранены. Продолжить?';pl = 'Wpisy zostaną zaktualizowane i zapisane? Kontynuować?';es_ES = 'Las entradas de diario se actualizarán y se guardarán. ¿Continuar?';es_CO = 'Las entradas de diario se actualizarán y se guardarán. ¿Continuar?';tr = 'Girişler güncellenip kaydedilecek. Devam edilsin mi?';it = 'Le voci saranno aggiornate e salvate. Continuare?';de = 'Die Buchungen werden aktualisiert und gespeichert. Weiter?'");
		ShowQueryBox(NotifyDescription, Text, QuestionDialogMode.YesNo, , DialogReturnCode.No);
		
		Return;

	EndIf;
	
	ExecuteNotifyProcessing(AdjustManuallyOnChangeEndCallback, AdjustedManually);
	FormManagement();
	FormManagementClient();
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject, "Comment");
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersRecordSet

&AtClient
Procedure RecordSetOnStartEdit(Item, NewRow, Clone)
	
	If NewRow And Not Clone Then
		
		If Item.CurrentData.Property("Period") Then
			Item.CurrentData.Period = Period;
		EndIf;
		
		If Item.CurrentData.Property("Company") And ValueIsFilled(Company) Then
			Item.CurrentData.Company = Company;
		EndIf;
		
		If Item.CurrentData.Property("Recorder") And ValueIsFilled(Document) Then
			Item.CurrentData.Recorder = Document;
		EndIf;
		
		If Item.CurrentData.Property("PlanningPeriod") Then
			Item.CurrentData.PlanningPeriod = PlanningPeriod;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RecordSetOnEditEnd(Item, NewRow, CancelEdit)
	
	If Not NewRow And Not CancelEdit And AdjustedManually Then
		Item.CurrentData.TransactionTemplate			= Undefined;
		Item.CurrentData.TransactionTemplateLineNumber	= Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExtDimensionDr1StartChoice(Item, ChoiceData, StandardProcessing)
	Item.TypeRestriction = GetTypesAtServer(Items.RecordSet.CurrentData.ExtDimensionTypeDr1);
EndProcedure

&AtClient
Procedure ExtDimensionDr2StartChoice(Item, ChoiceData, StandardProcessing)
	Item.TypeRestriction = GetTypesAtServer(Items.RecordSet.CurrentData.ExtDimensionTypeDr2);
EndProcedure

&AtClient
Procedure ExtDimensionDr3StartChoice(Item, ChoiceData, StandardProcessing)
	Item.TypeRestriction = GetTypesAtServer(Items.RecordSet.CurrentData.ExtDimensionTypeDr3);
EndProcedure

&AtClient
Procedure ExtDimensionCr1StartChoice(Item, ChoiceData, StandardProcessing)
	Item.TypeRestriction = GetTypesAtServer(Items.RecordSet.CurrentData.ExtDimensionTypeCr1);
EndProcedure

&AtClient
Procedure ExtDimensionCr2StartChoice(Item, ChoiceData, StandardProcessing)
	Item.TypeRestriction = GetTypesAtServer(Items.RecordSet.CurrentData.ExtDimensionTypeCr2);
EndProcedure

&AtClient
Procedure ExtDimensionCr3StartChoice(Item, ChoiceData, StandardProcessing)
	Item.TypeRestriction = GetTypesAtServer(Items.RecordSet.CurrentData.ExtDimensionTypeCr3);
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersRecordSetMaster

&AtClient
Procedure Attachable_RecordSetSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentRow = Item.CurrentData;
	
	If Field.Name = Item.Name + "TransactionTemplateCode"
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
			Item.CurrentData.Period = Period;
		EndIf;
		
		If Item.CurrentData.Property("Company") And ValueIsFilled(Company) Then
			Item.CurrentData.Company = Company;
		EndIf;
		
		If Item.CurrentData.Property("Recorder") And ValueIsFilled(Document) Then
			Item.CurrentData.Recorder = Document;
		EndIf;
		
		If Item.CurrentData.Property("PlanningPeriod") Then
			Item.CurrentData.PlanningPeriod = PlanningPeriod;
		EndIf;
		
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
		RefreshTotalData();
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetOnEditEnd(Item, NewRow, CancelEdit)

	If Not CancelEdit And AdjustedManually Then
		Item.CurrentData.TransactionTemplate			= Undefined;
		Item.CurrentData.TransactionTemplateCode		= Undefined;
		Item.CurrentData.TransactionTemplateLineNumber	= Undefined;
	EndIf;
	
	SortRecordSet(Item.Name);
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetOnChange(Item, NewRow, CancelEdit)

	LineNumber = 1;
	
	For Each Row In ThisObject[Item.Name] Do
		Row.LineNumber = LineNumber;
		LineNumber = LineNumber + 1;
	EndDo;
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetRecordTypeOnChange(Item)
	
	TableName = StrReplace(Item.Name, "RecordType", "");
	
	CurrentRow = Items[TableName].CurrentData; 
		
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
	
	SortRecordSet(TableName);
	MasterAccountingClientServer.RenumerateEntriesTabSection(ThisObject[TableName]);
	
	RefreshTotalData();
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetAmountCurDrOnChange(Item)
	
	RecordSetCompoundFieldOnChange(Item.Name, AccountingRecordType.Debit, "AmountCurDr", "AmountCur");
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetAmountCurCrOnChange(Item)
	
	RecordSetCompoundFieldOnChange(Item.Name, AccountingRecordType.Credit, "AmountCurCr", "AmountCur");
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetAmountDrOnChange(Item)
	
	RecordSetCompoundFieldOnChange(Item.Name, AccountingRecordType.Debit, "AmountDr", "Amount");
	
	RefreshTotalData();
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetAmountCrOnChange(Item)
	
	RecordSetCompoundFieldOnChange(Item.Name, AccountingRecordType.Credit, "AmountCr", "Amount");
	
	RefreshTotalData();
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetAmountOnChange(Item)
	
	RefreshTotalData();
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetMasterAccountDrOnChange(Item)
	
	CurrentTable = Items[CurrentTableName(ThisObject)];
	OnAccountChangeAtServer(CurrentTable.CurrentRow, "Dr");
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetMasterAccountCrOnChange(Item)
	
	CurrentTable = Items[CurrentTableName(ThisObject)];
	OnAccountChangeAtServer(CurrentTable.CurrentRow, "Cr");
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetMasterAccountOnChange(Item)
	
	CurrentTable = Items[CurrentTableName(ThisObject)];
	OnAccountChangeAtServer(CurrentTable.CurrentRow);
		
EndProcedure

&AtClient
Procedure Attachable_RecordSetAfterDeleteRow(Item)
	
	CurrentTableName = CurrentTableName(ThisObject);
	
	IsComplexTypeOfEntries = IsComplexTypeOfEntries(ChartOfAccounts, ThisObject[CurrentTableName].Count());
	
	If IsComplexTypeOfEntries Then
		
		MasterAccountingClientServer.RenumerateEntriesTabSection(ThisObject[CurrentTableName]);
		
		RenumerateLineNumbersInRecordSet(CurrentTableName, IsComplexTypeOfEntries);
	
	EndIf;
	
	RefreshTotalData();
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetCurrencyDrOnChange(Item)
	
	RecordSetCompoundFieldOnChange(Item.Name, AccountingRecordType.Debit, "CurrencyDr", "Currency");
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetCurrencyCrOnChange(Item)
	
	RecordSetCompoundFieldOnChange(Item.Name, AccountingRecordType.Credit, "CurrencyCr", "Currency");
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetQuantityDrOnChange(Item)
	
	RecordSetCompoundFieldOnChange(Item.Name, AccountingRecordType.Debit, "QuantityDr", "Quantity");
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetQuantityCrOnChange(Item)
	
	RecordSetCompoundFieldOnChange(Item.Name, AccountingRecordType.Credit, "QuantityCr", "Quantity");
	
EndProcedure

&AtClient
Procedure Attachable_RecordSetMasterExtDimensionStartChoice(Item, ChoiceData, StandardProcessing)
	
	If StrFind(Item.Name, "ExtDimension1") Then
		TableName = StrReplace(Item.Name, "ExtDimension1", "");
		ExtDimensionTypeName = "ExtDimensionType1"  
	ElsIf StrFind(Item.Name, "ExtDimension2") Then
		TableName = StrReplace(Item.Name, "ExtDimension2", ""); 
		ExtDimensionTypeName = "ExtDimensionType2"  
	ElsIf StrFind(Item.Name, "ExtDimension3") Then
		TableName = StrReplace(Item.Name, "ExtDimension3", ""); 
		ExtDimensionTypeName = "ExtDimensionType3"  
	ElsIf StrFind(Item.Name, "ExtDimension4") Then
		TableName = StrReplace(Item.Name, "ExtDimension4", ""); 
		ExtDimensionTypeName = "ExtDimensionType4"  
	Else
		Return;
	EndIf;	
	
	CurrentData = Items[TableName].CurrentData;
	
	Item.TypeRestriction = GetTypesAtServer(CurrentData[ExtDimensionTypeName]);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersRecordSetMasterSimple

&AtClient
Procedure Attachable_RecordSetMasterSimpleExtDimensionStartChoice(Item, ChoiceData, StandardProcessing)
	
	If StrFind(Item.Name, "ExtDimensionCr1") Then
		TableName = StrReplace(Item.Name, "ExtDimensionCr1", "");
		ExtDimensionTypeName = "ExtDimensionTypeCr1"  
	ElsIf StrFind(Item.Name, "ExtDimensionCr2") Then
		TableName = StrReplace(Item.Name, "ExtDimensionCr2", ""); 
		ExtDimensionTypeName = "ExtDimensionTypeCr2"  
	ElsIf StrFind(Item.Name, "ExtDimensionCr3") Then
		TableName = StrReplace(Item.Name, "ExtDimensionCr3", ""); 
		ExtDimensionTypeName = "ExtDimensionTypeCr3"  
	ElsIf StrFind(Item.Name, "ExtDimensionCr4") Then
		TableName = StrReplace(Item.Name, "ExtDimensionCr4", ""); 
		ExtDimensionTypeName = "ExtDimensionTypeCr4"  
	ElsIf StrFind(Item.Name, "ExtDimensionDr1") Then
		TableName = StrReplace(Item.Name, "ExtDimensionDr1", "");
		ExtDimensionTypeName = "ExtDimensionTypeDr1"  
	ElsIf StrFind(Item.Name, "ExtDimensionDr2") Then
		TableName = StrReplace(Item.Name, "ExtDimensionDr2", ""); 
		ExtDimensionTypeName = "ExtDimensionTypeDr2"  
	ElsIf StrFind(Item.Name, "ExtDimensionDr3") Then
		TableName = StrReplace(Item.Name, "ExtDimensionDr3", ""); 
		ExtDimensionTypeName = "ExtDimensionTypeDr3"  
	ElsIf StrFind(Item.Name, "ExtDimensionDr4") Then
		TableName = StrReplace(Item.Name, "ExtDimensionDr4", ""); 
		ExtDimensionTypeName = "ExtDimensionTypeDr4"  
	Else
		Return;
	EndIf;	
	
	CurrentData = Items[TableName].CurrentData;
	
	Item.TypeRestriction = GetTypesAtServer(CurrentData[ExtDimensionTypeName]);

EndProcedure

&AtClient
Procedure WriteData(Command)
	Write();
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ApproveAndClose(Command)
	
	ClearMessages();
	
	If Modified Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("Status", PredefinedValue("Enum.AccountingEntriesStatus.Approved"));
		AdditionalParameters.Insert("Close", True);
		QuestionaSave(AdditionalParameters);
	Else
		Status = PredefinedValue("Enum.AccountingEntriesStatus.Approved"); 
		SetNewStatus();
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure CancelApproval(Command)
	
	If Modified Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("Status", PredefinedValue("Enum.AccountingEntriesStatus.NotApproved"));
		AdditionalParameters.Insert("Close", False);
		QuestionaSave(AdditionalParameters);
	Else
		Status = PredefinedValue("Enum.AccountingEntriesStatus.NotApproved"); 
		SetNewStatus();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure FormManagement() Export
	
	Approved = (Status = PredefinedValue("Enum.AccountingEntriesStatus.Approved"));
	Editable = HasRoleEditAccountingEntries And AdjustedManually And Not Approved;
	
	If Approved Then
		Items.Status.TextColor = CompletedJob;
	Else
		Items.Status.TextColor = ErrorNoteText;
	EndIf;

	Items.AdjustedManually.ReadOnly	= Approved Or Not HasRoleEditAccountingEntries;
	Items.RereadData.Enabled		=  Editable;
	
	Items.RecordSetCommandBarGroup.Enabled	= Editable;
	Items.RecordSetAdd.Representation 		= ButtonRepresentation.PictureAndText;
	
	Items.RecordSetDelete.OnlyInAllActions	= False;
	Items.RecordSetDelete.Representation	= ButtonRepresentation.Picture;
	
	Items.RecordSetCopy.OnlyInAllActions	= False;
	Items.RecordSetCopy.Representation		= ButtonRepresentation.Picture;
	
	For Each MapRow In MasterTablesMap Do
		
		If MapRow.Compound Then
			Items[MapRow.TableName + "CommandBar"].Enabled = Editable;
		EndIf;
		
		Items[MapRow.TableName].ReadOnly = Not Editable;
		
		Items[MapRow.TableName + "Add"].Representation		= ButtonRepresentation.PictureAndText;
		Items[MapRow.TableName + "Delete"].OnlyInAllActions	= False;
		Items[MapRow.TableName + "Delete"].Representation	= ButtonRepresentation.Picture;
		Items[MapRow.TableName + "Copy"].OnlyInAllActions	= False;
		Items[MapRow.TableName + "Copy"].Representation		= ButtonRepresentation.Picture;
		
		Items[MapRow.PageName].ReadOnly = Not HasRoleEditAccountingEntries
			Or Not AdjustedManually
			Or Approved
			Or IsClosingPeriod;
		
	EndDo;
	
	Items.GroupPeriodLineNumber.ReadOnly	= True;
	Items.PlanningPeriod.ReadOnly			= True;
	
	Items.Status.Visible						= Posted;
	Items.RecordSetGroup.ReadOnly				= Not HasRoleEditAccountingEntries Or Not AdjustedManually Or Approved;
	
	Items.GroupApproveCancel.Enabled = HasRoleApproveAccountingEntries 
		And (Posted Or TypeOf(Document) = Type("DocumentRef.AccountingTransaction"))
		And Not IsClosingPeriod;
	ReadOnly = IsClosingPeriod Or Not (Posted Or TypeOf(Document) = Type("DocumentRef.AccountingTransaction"));
	
	CountTabs						= 0;
	ShowRecordSetGroup				= False;
	ShowRecordSetMasterGroup		= False;
	ShowRecordSetMasterGroupSimple	= False;
	
	If RecordSet.Count() > 0 Then
		ShowRecordSetGroup = True;
		CountTabs = CountTabs + 1;
	EndIf;
	
	CountTabs = CountTabs + MasterTablesMap.Count();
	
	Items.RecordSetGroup.Visible = ShowRecordSetGroup;
	
	CompoundRecordSet	= False;
	CurrentPage			= Items.Pages.CurrentPage;
	
	FoundRows = New Array;
	If CurrentPage <> Undefined Then
		FoundRows = MasterTablesMap.FindRows(New Structure("PageName", CurrentPage.Name));
	ElsIf MasterTablesMap.Count() > 0 Then
		FoundRows.Add(MasterTablesMap[0]);
	EndIf;
	
	If FoundRows.Count() > 0 Then
		
		ChartOfAccounts	 = FoundRows[0].ChartOfAccounts;
		TypeOfAccounting = FoundRows[0].TypeOfAccounting;
		Items.TotalDifference.Visible = FoundRows[0].Compound;
		Items.CompanyPresentationCurrency.Visible = FoundRows[0].Compound;
		
	EndIf;
	
	If CountTabs < 2 Then
		
		Items.Pages.PagesRepresentation = FormPagesRepresentation.None;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillFormAttributes()
	
	If Not ValueIsFilled(Document) And Parameters <> Undefined Then
		Document = Parameters.Filter.Recorder;
	EndIf;
	
	HasRoleEditAccountingEntries = Users.IsFullUser() Or AccessManagement.HasRole("EditAccountingEntries");
	HasRoleApproveAccountingEntries = Users.IsFullUser() Or AccessManagement.HasRole("ApproveAccountingEntries");
	PlanningPeriod = Catalogs.PlanningPeriods.Actual;
	Posted = Common.ObjectAttributeValue(Document, "Posted");
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	DocumentAccountingEntriesStatuses.Period AS Period,
	|	DocumentAccountingEntriesStatuses.Company AS Company,
	|	DocumentAccountingEntriesStatuses.Status AS Status,
	|	DocumentAccountingEntriesStatuses.AdjustedManually AS AdjustedManually,
	|	DocumentAccountingEntriesStatuses.Comment AS Comment,
	|	DocumentAccountingEntriesStatuses.DocumentCurrency AS DocumentCurrency
	|FROM
	|	InformationRegister.DocumentAccountingEntriesStatuses AS DocumentAccountingEntriesStatuses
	|WHERE
	|	DocumentAccountingEntriesStatuses.Recorder = &Document";
	
	Query.SetParameter("Document", Document);
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		FillPropertyValues(ThisObject, Selection);
	Else
		
		AttributeList = "Date, Company";
		
		If Common.HasObjectAttribute("DocumentCurrency", Document.Metadata()) Then
			AttributeList = AttributeList + ", DocumentCurrency";
		EndIf;
		
		DocumentAttributes = Common.ObjectAttributesValues(Document, AttributeList);
		Period = DocumentAttributes.Date;
		Company = DocumentAttributes.Company;
		
		DocumentCurrency = Catalogs.Currencies.EmptyRef();
		DocumentAttributes.Property("DocumentCurrency", DocumentCurrency);
		
		Status = Enums.AccountingEntriesStatus.NotApproved;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetNewStatus()
	
	ProcedureParameters = New Structure("Document, Status, AdjustedManually, Comment, UUID");
	FillPropertyValues(ProcedureParameters, ThisObject);
	
	AccountingApprovalClient.SetNewStatus(ThisObject, ProcedureParameters);
	FormManagement();
	
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
Function RestoreOriginalEntries() Export
	
	Return MasterAccountingServerCall.RestoreOriginalEntries(Document, Document);
	
EndFunction

&AtClient
Procedure QuestionaSave(AdditionalParameters) Export 
	
	NotifyDescription = New NotifyDescription("AfterQuestionaSave", ThisObject, AdditionalParameters);
	QuestionText = NStr("en = 'Data has been changed. Do you want to save the changes?'; ru = 'Данные были изменены. Сохранить изменения?';pl = 'Dane zostały zmienione. Czy chcesz zapisać zmiany?';es_ES = 'Los datos han sido cambiados. ¿Quiere guardar los cambios?';es_CO = 'Los datos han sido cambiados. ¿Quiere guardar los cambios?';tr = 'Veriler değiştirildi. Değişiklikleri kaydetmek istiyor musunuz?';it = 'I dati sono stati modificati. Salvare le modifiche?';de = 'Die Daten wurden geändert. Wollen Sie die Änderungen speichern?'");
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure AfterQuestionaSave(Result, AdditionalParameters) Export 
	
	If Result = DialogReturnCode.Yes Then
		
		Cancel = False;
		WriteResult = Write();
		
		If WriteResult Then
			WriteRecordSetMaster(Cancel);
			WriteRecordSetSimple(Cancel);
			
			If Not Cancel And AdditionalParameters.Close Then
				Close();
			EndIf;
		
			Status = AdditionalParameters.Status;
			SetNewStatus();
		EndIf;
		
	ElsIf Result = DialogReturnCode.No Then
		
		Modified = False;
		If AdditionalParameters.Close Then
			Close();
		Else
			Read();
			ReadRecordSetMasterAtServer();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ReadRecordSetMasterAtServer()

	RecordSetMasterTable = AccountingApprovalServer.GetRecordSetMasterByRecorder(Document);
	RecordSetMaster.Load(RecordSetMasterTable);
	
EndProcedure

&AtServer
Procedure WriteRecordSetMaster(Cancel)
	
	RecordSetObject = FormAttributeToValue("RecordSetMaster");
	RecordSetObject.Write();
	
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

&AtClient
Procedure PagesOnCurrentPageChange(Item, CurrentPage)
	
	CurrentPage = Items.Pages.CurrentPage; 
	
	FoundRows = MasterTablesMap.FindRows(New Structure("PageName", CurrentPage.Name));
	
	If FoundRows.Count() > 0 Then
		
		ChartOfAccounts	 = FoundRows[0].ChartOfAccounts;
		TypeOfAccounting = FoundRows[0].TypeOfAccounting;
		Items.TotalDifference.Visible = FoundRows[0].Compound;
		Items.CompanyPresentationCurrency.Visible = FoundRows[0].Compound;
		RefreshTotalData();
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetTypesAtServer(DimensionType)

	If ValueIsFilled(DimensionType) Then
		Return DimensionType.ValueType;
	Else
		Return New TypeDescription("Undefined"); 
	EndIf;

EndFunction

&AtServer
Procedure GenerateMasterTables()
	
	MasterAccountingParameters = New Structure;
	MasterAccountingParameters.Insert("Recorder", Document);
	MasterAccountingParameters.Insert("Company"	, Company);
	MasterAccountingParameters.Insert("Period"	, Period);
	MasterAccountingFormGeneration.GenerateMasterTables(ThisObject, MasterAccountingParameters, "Pages");
	
EndProcedure

&AtServer
Procedure FillRecordSetsMaster(RecordSetMasterTable, RecordSetSimpleTable, RecordSetMasterSimpleTable, RecordSetMasterCompoundTable)
	
	RecordSetMasterSimpleTable.Clear();
	RecordSetMasterCompoundTable.Clear();
	
	TablesMap = New Map;
	
	For Each MapRow In MasterTablesMap Do
		ThisObject[MapRow.TableName].Clear();
		
		If MapRow.Compound Then 
			TablesMap.Insert(MapRow.TableName, RecordSetMasterCompoundTable.CopyColumns());
		Else
			TablesMap.Insert(MapRow.TableName, RecordSetMasterSimpleTable.CopyColumns());
		EndIf;
	EndDo;
	
	For Each Row In RecordSetMaster Do
		
		SearchStructure = New Structure("TypeOfAccounting, TypeOfEntries", Row.TypeOfAccounting, Row.Account.ChartOfAccounts.TypeOfEntries);
		
		FoundRows = MasterTablesMap.FindRows(SearchStructure);
		
		If FoundRows.Count() > 0 Then
			
			CurrentTable = TablesMap.Get(FoundRows[0].TableName);
			
			TableName = FoundRows[0].TableName;
			
			NewRow = CurrentTable.Add();
			FillPropertyValues(NewRow, Row);
			
		EndIf;

		NewRow = RecordSetMasterCompoundTable.Add();
		FillPropertyValues(NewRow, Row);
		
	EndDo;
	
	For Each Row In RecordSetSimple Do
		
		SearchStructure = New Structure("TypeOfAccounting, TypeOfEntries", Row.TypeOfAccounting, Enums.ChartsOfAccountsTypesOfEntries.Simple);
		
		FoundRows = MasterTablesMap.FindRows(SearchStructure);
		
		If FoundRows.Count() > 0 Then
			
			CurrentTable = TablesMap.Get(FoundRows[0].TableName);
			
			TableName = FoundRows[0].TableName;
			
			NewRow = CurrentTable.Add();
			FillPropertyValues(NewRow, Row);
			
		EndIf;

		NewRow = RecordSetMasterSimpleTable.Add();
		FillPropertyValues(NewRow, Row);
		
	EndDo;
	
	For Each MapRow In MasterTablesMap Do

		CurrentTable = ThisObject[MapRow.TableName]; 
		
		MapTable = TablesMap.Get(MapRow.TableName);
		
		Index = 1;
		For Each Row In MapTable Do
			
			Row.LineNumber = Index;
			Index = Index + 1;
			
		EndDo;
		
		MasterAccounting.FillMiscFields(MapTable);
		
		CurrentTable.Load(MapTable);
		
	EndDo;
	
	Index = 1;
	For Each Row In RecordSetMasterSimpleTable Do
		
		Row.LineNumber = Index;
		Index = Index + 1;
		
	EndDo;
	
	Index = 1;
	For Each Row In RecordSetMasterCompoundTable Do
		
		Row.LineNumber = Index;
		Index = Index + 1;
		
	EndDo;
	
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

&AtClient
Procedure AdjustManuallyOnChangeEnd(IsAdjustedManually, AdditionalParameters) Export
	
	If Not IsAdjustedManually Then
		Read();
		FormManagement();
		FormManagementClient();
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function CurrentTableName(Form, DataField = "TableName")
	
	Items = Form.Items;
	CurrentPage = Items.Pages.CurrentPage;
	MasterTablesMap = Form.MasterTablesMap;
	
	Row = Undefined;
	
	If CurrentPage <> Undefined Then
		
		FoundRows = MasterTablesMap.FindRows(New Structure("PageName", CurrentPage.Name));
		If FoundRows.Count() > 0 Then
			Row = FoundRows[0];
		EndIf;
		
	Else
		Row = MasterTablesMap[0];
	EndIf;
	
	Return ?(Row = Undefined, "", Row[DataField]);
	
EndFunction

&AtServer
Procedure SortRecordSet(ItemName)
	
	IsSortOrderAsc = String(AccountingRecordType.Debit) < String(AccountingRecordType.Credit);
	
	If IsSortOrderAsc Then
		ThisObject[ItemName].Sort("EntryNumber, RecordType");
	Else
		ThisObject[ItemName].Sort("EntryNumber, RecordType Desc");
	EndIf;
	
	CurrentTableName = CurrentTableName(ThisObject);
	
	RenumerateLineNumbersInRecordSet(ItemName, IsComplexTypeOfEntries(ChartOfAccounts, ThisObject[CurrentTableName].Count()));
	
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
			
			Row.LineNumber	= LineNumber;
			LineNumber		= LineNumber + 1;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure WriteRecordSetSimple(Cancel)
	
	RecordSetObject = FormAttributeToValue("RecordSetSimple");
	RecordSetObject.Write();
	
	
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
					StrTemplate(NStr("en = 'The ""%1"" field is required.'; ru = 'Поле ""%1"" не заполнено.';pl = 'Pole ""%1"" jest wymagane.';es_ES = 'El campo ""%1"" es obligatorio.';es_CO = 'El campo ""%1"" es obligatorio.';tr = '""%1"" alanı zorunlu.';it = 'Il campo ""%1"" è richiesto.';de = 'Das ""%1"" Feld ist nicht erforderlich.'"), ColumnTitle),
					,
					CommonClientServer.PathToTabularSection(TableMapRow.TableName, Row.LineNumber, AttributeName),
					,
					Cancel);
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure FormManagementClient()
	
	CurrentTableName = CurrentTableName(ThisObject);
	IsCompound = False;
	For Each MapRow In MasterTablesMap Do
		
		If MapRow.TableName = CurrentTableName Then
			IsCompound = MapRow.Compound;
		EndIf;
		
	EndDo;
	
	If CurrentTableName <> "" Then
		
		For Each ButtonItem In Items[CurrentTableName + "CommandBar"].ChildItems Do
			
			If StrFind(ButtonItem.Name, "ExtraButton") = 0 Then
				ButtonItem.Visible = Not IsCompound;
			Else
				ButtonItem.Visible = True;
			EndIf;
			Items[MapRow.TableName + "ContextMenuAdd"].Visible = Not IsCompound;
			Items[MapRow.TableName + "ContextMenuCopy"].Visible = Not IsCompound;
			Items[MapRow.TableName + "ContextMenuMoveUp"].Visible = Not IsCompound;
			Items[MapRow.TableName + "ContextMenuMoveDown"].Visible = Not IsCompound;
			
		EndDo;
		
	EndIf;
		
EndProcedure

&AtClient
Procedure AddEntry(Command)
	
	CurrentTableName = CurrentTableName(ThisObject);
	
	DefaultData = New Structure;
	DefaultData.Insert("Company", Company);
	DefaultData.Insert("Period"	, Period);
	
	CurrentRowLineNumber = MasterAccountingClientServer.AddEntry(ThisObject[CurrentTableName], DefaultData, "DocumentAccountingEntries");
	
	TableIsFilled = (ThisObject[CurrentTableName].Count() <> 0);
	Items[CurrentTableName+"ExtraButtonEntriesUp"].Enabled 		= TableIsFilled;
	Items[CurrentTableName+"ExtraButtonEntriesDown"].Enabled 	= TableIsFilled;
	Items[CurrentTableName+"ContextMenuEntriesUp"].Enabled 		= TableIsFilled;
	Items[CurrentTableName+"ContextMenuEntriesDown"].Enabled 	= TableIsFilled;

	Items[CurrentTableName].CurrentRow = CurrentRowLineNumber;
	
	RenumerateLineNumbersInRecordSet(CurrentTableName, True);
	
EndProcedure

&AtClient
Procedure AddEntryLine(Command)
	
	CurrentTableName = CurrentTableName(ThisObject);
	
	CurrentData = Items[CurrentTableName].CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	IsComplexTypeOfEntries = IsComplexTypeOfEntries(ChartOfAccounts, ThisObject[CurrentTableName].Count());
	
	DefaultData = New Structure;
	DefaultData.Insert("Company", Company);
	DefaultData.Insert("Period"	, Period);
	DefaultData.Insert("CurrentIndex", ThisObject[CurrentTableName].IndexOf(CurrentData));
	DefaultData.Insert("IsComplexTypeOfEntries", IsComplexTypeOfEntries);
	
	CurrentRowLineNumber = MasterAccountingClientServer.AddEntryLine(ThisObject[CurrentTableName], DefaultData, "DocumentAccountingEntries");
	Items[CurrentTableName].CurrentRow = CurrentRowLineNumber;
	
	RenumerateLineNumbersInRecordSet(CurrentTableName, True);
	
EndProcedure

&AtClient
Procedure EntriesUp(Command)
	
	CurrentTableName = CurrentTableName(ThisObject);
	
	IsComplexTypeOfEntries = IsComplexTypeOfEntries(ChartOfAccounts, ThisObject[CurrentTableName].Count());
	
	If IsComplexTypeOfEntries Then
		SelectedRowsIDs = Items[CurrentTableName].SelectedRows;
		RowsArray = New Array;
		
		SortedSelectedRowsIDs = SortSelectedRowsArray(CurrentTableName, SelectedRowsIDs);
		
		For Each SelectedRowID In SortedSelectedRowsIDs Do
			RowsArray.Add(ThisObject[CurrentTableName].FindByID(SelectedRowID));
		EndDo;
		DefaultData = New Structure;
		DefaultData.Insert("Company"	, Company);
		DefaultData.Insert("Period"		, Period);
		DefaultData.Insert("RowsArray"	, RowsArray);
		DefaultData.Insert("Direction"	, -1);
		
		MasterAccountingClientServer.MoveEntriesUpDown(ThisObject[CurrentTableName], DefaultData, "DocumentAccountingEntries");
		
		RenumerateLineNumbersInRecordSet(CurrentTableName, True);
		
	EndIf;
	
	Modified = True;

	
EndProcedure

&AtClient
Procedure EntriesDown(Command)
	
	CurrentTableName = CurrentTableName(ThisObject);
	
	IsComplexTypeOfEntries = IsComplexTypeOfEntries(ChartOfAccounts, ThisObject[CurrentTableName].Count());
	
	If IsComplexTypeOfEntries Then
		SelectedRowsIDs = Items[CurrentTableName].SelectedRows;
		RowsArray = New Array;
		
		SortedSelectedRowsIDs = SortSelectedRowsArray(CurrentTableName, SelectedRowsIDs);
		
		For Each SelectedRowID In SortedSelectedRowsIDs Do
			RowsArray.Add(ThisObject[CurrentTableName].FindByID(SelectedRowID));
		EndDo;
		DefaultData = New Structure;
		DefaultData.Insert("Company"	, Company);
		DefaultData.Insert("Period"		, Period);
		DefaultData.Insert("RowsArray"	, RowsArray);
		DefaultData.Insert("Direction"	, 1);
		
		MasterAccountingClientServer.MoveEntriesUpDown(ThisObject[CurrentTableName], DefaultData, "DocumentAccountingEntries");
		
		RenumerateLineNumbersInRecordSet(CurrentTableName, True);
		
	EndIf;
	
	Modified = True;

EndProcedure

&AtClient
Procedure CopyEntriesRows(Command)
	
	CurrentTableName = CurrentTableName(ThisObject);
	
	IsComplexTypeOfEntries = IsComplexTypeOfEntries(ChartOfAccounts, ThisObject[CurrentTableName].Count());
	
	If IsComplexTypeOfEntries Then
		
		SelectedRowsIDs = Items[CurrentTableName].SelectedRows;
		RowsArray = New Array;
		
		SortedSelectedRowsIDs = SortSelectedRowsArray(CurrentTableName, SelectedRowsIDs);
		
		For Each SelectedRowID In SortedSelectedRowsIDs Do
			RowsArray.Add(ThisObject[CurrentTableName].FindByID(SelectedRowID));
		EndDo;
		
		DefaultData = New Structure;
		DefaultData.Insert("Company"	, Company);
		DefaultData.Insert("Period"		, Period);
		DefaultData.Insert("RowsArray"	, RowsArray);
		DefaultData.Insert("Direction"	, 1);
		
		CurrentRowId = MasterAccountingClientServer.CopyEntriesRows(ThisObject[CurrentTableName], DefaultData, "DocumentAccountingEntries");
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
	
	CurrentTableName = CurrentTableName(ThisObject);
	
	IsComplexTypeOfEntries = IsComplexTypeOfEntries(ChartOfAccounts, ThisObject[CurrentTableName].Count());
	
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
Procedure Reread(Command)
	
	Read();
	FormManagement();
	
EndProcedure

&AtServer
Function GatherRecordSets(Cancel)
	
	If RecordSetMasterCompoundHasBeenChanged() Or RecordSetMasterSimpleHasBeenChanged() Then
		Return True;
	EndIf;
	
	If MasterTablesMap.Count() = 0 Then
		Return False;
	EndIf;
	
	RecordSetMaster.Clear();
	RecordSetSimple.Clear();
	EntriesTable = New Array;
	
	For Each TablesRow In MasterTablesMap Do
		
		AccountingJournalEntries = New ValueTable;
		AccountingJournalEntries.Columns.Add("Period"			, New TypeDescription("Date"));
		AccountingJournalEntries.Columns.Add("Account"			, New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts"));
		AccountingJournalEntries.Columns.Add("AccountDr"		, New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts"));
		AccountingJournalEntries.Columns.Add("AccountCr"		, New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts"));
		AccountingJournalEntries.Columns.Add("RecordType"		, New TypeDescription("AccountingRecordType"));
		AccountingJournalEntries.Columns.Add("Amount"			, New TypeDescription("Number"));
		AccountingJournalEntries.Columns.Add("EntryNumber"		, New TypeDescription("Number"));
		AccountingJournalEntries.Columns.Add("LineNumber"		, New TypeDescription("Number"));
		
		For Each Row In ThisObject[TablesRow.TableName] Do
			
			NewRow = AccountingJournalEntries.Add();
			If TablesRow.Compound Then
				NewRow.Period			= Row.Period;
				NewRow.LineNumber		= Row.LineNumber;
				NewRow.EntryNumber		= Row.EntryNumber;
				NewRow.Account			= Row.Account;
				NewRow.RecordType		= Row.RecordType;
				NewRow.Amount			= ?(NewRow.RecordType = AccountingRecordType.Debit, Row.AmountDr, Row.AmountCr);
			Else
				NewRow.Period			= Row.Period;
				NewRow.LineNumber		= Row.LineNumber;
				NewRow.EntryNumber		= Row.LineNumber;
				NewRow.AccountDr		= Row.AccountDr;
				NewRow.AccountCr		= Row.AccountCr;
				NewRow.RecordType		= Row.RecordType;
				NewRow.Amount			= Row.Amount;
			EndIf;
			
			If TablesRow.Compound Then
				NewRow = RecordSetMaster.Add();
			Else
				NewRow = RecordSetSimple.Add();
			EndIf;
			
			FillPropertyValues(NewRow, Row);
			
		EndDo;
		
		EntriesTableRow = New Structure;
		EntriesTableRow.Insert("TypeOfAccounting"	, TablesRow.TypeOfAccounting);
		EntriesTableRow.Insert("ChartOfAccounts"	, TablesRow.ChartOfAccounts);
		EntriesTableRow.Insert("Entries"			, AccountingJournalEntries);
		EntriesTable.Add(EntriesTableRow);
		
	EndDo;
	
	If AdjustedManually Then
		AccountingTemplatesPosting.CheckTransactionsFilling(Document, EntriesTable, Cancel, AdjustedManually);
	EndIf;
	
	Return False;
	
EndFunction

&AtServer
Function RecordSetMasterCompoundHasBeenChanged()
	
	RecordSetMasterFromDatabase = AccountingRegisters.AccountingJournalEntriesCompound.CreateRecordSet();
	RecordSetMasterFromDatabase.Filter.Recorder.Set(Document);
	RecordSetMasterFromDatabase.Read();
	
	TempRecordSetMasterFromDatabase = RecordSetMasterFromDatabase.Unload();
	
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
	|	AccountingJournalEntriesCompound.TransactionTemplate AS TransactionTemplate,
	|	AccountingJournalEntriesCompound.TransactionTemplateLineNumber AS TransactionTemplateLineNumber,
	|	AccountingJournalEntriesCompound.Quantity AS Quantity,
	|	AccountingJournalEntriesCompound.TypeOfAccounting AS TypeOfAccounting,
	|	AccountingJournalEntriesCompound.Status AS Status
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
Function RecordSetMasterSimpleHasBeenChanged()
	
	RecordSetMasterFromDatabase = AccountingRegisters.AccountingJournalEntriesSimple.CreateRecordSet();
	RecordSetMasterFromDatabase.Filter.Recorder.Set(Document);
	RecordSetMasterFromDatabase.Read();
	
	TempRecordSetMasterFromDatabase = RecordSetMasterFromDatabase.Unload();
	
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
		Reread("");
	EndIf;
	
EndProcedure

&AtClient
Procedure RecordSetCompoundFieldOnChange(ItemName, RecordTypeToCheck, FieldName, ResultField)
	
	TableName = StrReplace(ItemName, FieldName, "");
	
	CurrentRow = Items[TableName].CurrentData;
	
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	
	If CurrentRow.RecordType = RecordTypeToCheck Then
		CurrentRow[ResultField] = CurrentRow[FieldName];
	EndIf;
	
EndProcedure

#EndRegion