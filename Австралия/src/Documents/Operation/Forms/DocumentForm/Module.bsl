#Region GeneralPurposeProceduresAndFunctions

&AtServerNoContext
// It receives data set from server for the ContractOnChange procedure.
//
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"Counterparty",
		DriveServer.GetCompany(Company)
	);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// Receives data set from server for the AccountOnChange procedure.
//
// Parameters:
//  Account         - AccountsChart, account according to which you should receive structure.
//
// Returns:
//  Account structure.
// 
Function GetDataAccountOnChange(Account) Export
	
	StructureData = New Structure();
	
	StructureData.Insert("Currency", Account.Currency);
	
	Return StructureData;
	
EndFunction

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(Object,
	,
	Parameters.CopyingValue,
	Parameters.Basis,
	PostingIsAllowed,
	Parameters.FillingValues);
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	DriveClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

#Region EventHandlersOfHeaderAttributes

&AtClient
// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "");
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Company input field.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	Counterparty = StructureData.Counterparty;
	
EndProcedure

#Region TabularSectionAttributeEventHandlers

&AtClient
// Procedure - event handler OnChange of the input field AccountDr.
// Transactions tabular section.
//
Procedure AccountingRecordsAccountDrOnChange(Item)
	
	CurrentRow = Items.AccountingRecords.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.AccountDr);
	
	If Not StructureData.Currency Then
		CurrentRow.CurrencyDr = Undefined;
		CurrentRow.AmountCurDr = 0;
	EndIf;
	
	Items.AccountingRecordsCurrencyDr.ReadOnly = Not StructureData.Currency;
	Items.AccountingRecordsSumCurDt.ReadOnly = Not StructureData.Currency;
	
EndProcedure

&AtClient
// Procedure - event handler SelectionStart of the input field CurrencyDr.
// Transactions tabular section.
//
Procedure AccountingRecordsCurrencyDrStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.AccountingRecords.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.AccountDr);
	
	If Not StructureData.Currency Then
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.AccountDr) Then
			ShowMessageBox(Undefined,NStr("en = 'Current GL account does not support multi-currency records.'; ru = 'Текущий счет учета не поддерживает записи в разных валютах.';pl = 'Aktualne konto księgowe nie obsługuje wpisów wielowalutowych.';es_ES = 'Cuenta del libro mayor actual no admite las grabaciones de diferentes monedas.';es_CO = 'Cuenta del libro mayor actual no admite las grabaciones de diferentes monedas.';tr = 'Mevcut muhasebe hesabı çok para birimli kayıtları desteklemiyor.';it = 'Il corrente conto mastro non supporta le registrazioni multi-valuta.';de = 'Das aktuelle Hauptbuch-Konto unterstützt keine Datensätze in mehreren Währungen.'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the GL account first.'; ru = 'Сначала укажите счет учета.';pl = 'Najpierw podaj konto księgowe.';es_ES = 'Especificar la cuenta del libro mayor primero.';es_CO = 'Especificar la cuenta del libro mayor primero.';tr = 'Önce muhasebe hesabını belirtin.';it = 'Specificare il Conto mastro prima di tutto.';de = 'Geben Sie zuerst das Hauptbuch-Konto an.'"));
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the input field CurrencyDr.
// Transactions tabular section.
//
Procedure AccountingRecordsCurrencyDrOnChange(Item)
	
	CurrentRow = Items.AccountingRecords.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.AccountDr);
	
	If Not StructureData.Currency Then
		CurrentRow.CurrencyDr = Undefined;
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.AccountDr) Then
			ShowMessageBox(Undefined,NStr("en = 'Current GL account does not support multi-currency records.'; ru = 'Текущий счет учета не поддерживает записи в разных валютах.';pl = 'Aktualne konto księgowe nie obsługuje wpisów wielowalutowych.';es_ES = 'Cuenta del libro mayor actual no admite las grabaciones de diferentes monedas.';es_CO = 'Cuenta del libro mayor actual no admite las grabaciones de diferentes monedas.';tr = 'Mevcut muhasebe hesabı çok para birimli kayıtları desteklemiyor.';it = 'Il corrente conto mastro non supporta le registrazioni multi-valuta.';de = 'Das aktuelle Hauptbuch-Konto unterstützt keine Datensätze in mehreren Währungen.'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the GL account first.'; ru = 'Сначала укажите счет учета.';pl = 'Najpierw podaj konto księgowe.';es_ES = 'Especificar la cuenta del libro mayor primero.';es_CO = 'Especificar la cuenta del libro mayor primero.';tr = 'Önce muhasebe hesabını belirtin.';it = 'Specificare il Conto mastro prima di tutto.';de = 'Geben Sie zuerst das Hauptbuch-Konto an.'"));
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler SelectionStart of the input field AmountCurrencyDr.
// Transactions tabular section.
//
Procedure AccountingRecordsAmountCurDrStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.AccountingRecords.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.AccountDr);
	
	If Not StructureData.Currency Then
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.AccountDr) Then
			ShowMessageBox(Undefined,NStr("en = 'Current GL account does not support multi-currency records.'; ru = 'Текущий счет учета не поддерживает записи в разных валютах.';pl = 'Aktualne konto księgowe nie obsługuje wpisów wielowalutowych.';es_ES = 'Cuenta del libro mayor actual no admite las grabaciones de diferentes monedas.';es_CO = 'Cuenta del libro mayor actual no admite las grabaciones de diferentes monedas.';tr = 'Mevcut muhasebe hesabı çok para birimli kayıtları desteklemiyor.';it = 'Il corrente conto mastro non supporta le registrazioni multi-valuta.';de = 'Das aktuelle Hauptbuch-Konto unterstützt keine Datensätze in mehreren Währungen.'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the GL account first.'; ru = 'Сначала укажите счет учета.';pl = 'Najpierw podaj konto księgowe.';es_ES = 'Especificar la cuenta del libro mayor primero.';es_CO = 'Especificar la cuenta del libro mayor primero.';tr = 'Önce muhasebe hesabını belirtin.';it = 'Specificare il Conto mastro prima di tutto.';de = 'Geben Sie zuerst das Hauptbuch-Konto an.'"));
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the input field AmountCurrencyDr.
// Transactions tabular section.
//
Procedure AccountingRecordsAmountCurDrOnChange(Item)
	
	CurrentRow = Items.AccountingRecords.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.AccountDr);
	
	If Not StructureData.Currency Then
		CurrentRow.AmountCurDr = 0;
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.AccountDr) Then
			ShowMessageBox(Undefined,NStr("en = 'Current GL account does not support multi-currency records.'; ru = 'Текущий счет учета не поддерживает записи в разных валютах.';pl = 'Aktualne konto księgowe nie obsługuje wpisów wielowalutowych.';es_ES = 'Cuenta del libro mayor actual no admite las grabaciones de diferentes monedas.';es_CO = 'Cuenta del libro mayor actual no admite las grabaciones de diferentes monedas.';tr = 'Mevcut muhasebe hesabı çok para birimli kayıtları desteklemiyor.';it = 'Il corrente conto mastro non supporta le registrazioni multi-valuta.';de = 'Das aktuelle Hauptbuch-Konto unterstützt keine Datensätze in mehreren Währungen.'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the GL account first.'; ru = 'Сначала укажите счет учета.';pl = 'Najpierw podaj konto księgowe.';es_ES = 'Especificar la cuenta del libro mayor primero.';es_CO = 'Especificar la cuenta del libro mayor primero.';tr = 'Önce muhasebe hesabını belirtin.';it = 'Specificare il Conto mastro prima di tutto.';de = 'Geben Sie zuerst das Hauptbuch-Konto an.'"));
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the input field AccountCr.
// Transactions tabular section.
//
Procedure AccountingRecordsAccountCrOnChange(Item)
	
	CurrentRow = Items.AccountingRecords.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.AccountCr);
	
	If Not StructureData.Currency Then
		CurrentRow.CurrencyCr = Undefined;
		CurrentRow.AmountCurCr = 0;
	EndIf;
	
	Items.AccountingRecordsCurrencyCt.ReadOnly = Not StructureData.Currency;
	Items.AccountingRecordsSumCurCt.ReadOnly = Not StructureData.Currency;
	
EndProcedure

&AtClient
// Procedure - event handler SelectionStart of the input field CurrencyCr.
// Transactions tabular section.
//
Procedure AccountingRecordsCurrencyCrStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.AccountingRecords.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.AccountCr);
	
	If Not StructureData.Currency Then
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.AccountCr) Then
			ShowMessageBox(Undefined,NStr("en = 'Current GL account does not support multi-currency records.'; ru = 'Текущий счет учета не поддерживает записи в разных валютах.';pl = 'Aktualne konto księgowe nie obsługuje wpisów wielowalutowych.';es_ES = 'Cuenta del libro mayor actual no admite las grabaciones de diferentes monedas.';es_CO = 'Cuenta del libro mayor actual no admite las grabaciones de diferentes monedas.';tr = 'Mevcut muhasebe hesabı çok para birimli kayıtları desteklemiyor.';it = 'Il corrente conto mastro non supporta le registrazioni multi-valuta.';de = 'Das aktuelle Hauptbuch-Konto unterstützt keine Datensätze in mehreren Währungen.'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the GL account first.'; ru = 'Сначала укажите счет учета.';pl = 'Najpierw podaj konto księgowe.';es_ES = 'Especificar la cuenta del libro mayor primero.';es_CO = 'Especificar la cuenta del libro mayor primero.';tr = 'Önce muhasebe hesabını belirtin.';it = 'Specificare il Conto mastro prima di tutto.';de = 'Geben Sie zuerst das Hauptbuch-Konto an.'"));
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the input field CurrencyCr.
// Transactions tabular section.
//
Procedure AccountingRecordsCurrencyCrOnChange(Item)
	
	CurrentRow = Items.AccountingRecords.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.AccountCr);
	
	If Not StructureData.Currency Then
		CurrentRow.CurrencyCr = Undefined;
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.AccountCr) Then
			ShowMessageBox(Undefined,NStr("en = 'Current GL account does not support multi-currency records.'; ru = 'Текущий счет учета не поддерживает записи в разных валютах.';pl = 'Aktualne konto księgowe nie obsługuje wpisów wielowalutowych.';es_ES = 'Cuenta del libro mayor actual no admite las grabaciones de diferentes monedas.';es_CO = 'Cuenta del libro mayor actual no admite las grabaciones de diferentes monedas.';tr = 'Mevcut muhasebe hesabı çok para birimli kayıtları desteklemiyor.';it = 'Il corrente conto mastro non supporta le registrazioni multi-valuta.';de = 'Das aktuelle Hauptbuch-Konto unterstützt keine Datensätze in mehreren Währungen.'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the GL account first.'; ru = 'Сначала укажите счет учета.';pl = 'Najpierw podaj konto księgowe.';es_ES = 'Especificar la cuenta del libro mayor primero.';es_CO = 'Especificar la cuenta del libro mayor primero.';tr = 'Önce muhasebe hesabını belirtin.';it = 'Specificare il Conto mastro prima di tutto.';de = 'Geben Sie zuerst das Hauptbuch-Konto an.'"));
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler SelectionStart of the input field AmountCurrencyCr.
// Transactions tabular section.
//
Procedure AccountingRecordsAmountCurCrStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.AccountingRecords.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.AccountCr);
	
	If Not StructureData.Currency Then
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.AccountCr) Then
			ShowMessageBox(Undefined,NStr("en = 'Current GL account does not support multi-currency records.'; ru = 'Текущий счет учета не поддерживает записи в разных валютах.';pl = 'Aktualne konto księgowe nie obsługuje wpisów wielowalutowych.';es_ES = 'Cuenta del libro mayor actual no admite las grabaciones de diferentes monedas.';es_CO = 'Cuenta del libro mayor actual no admite las grabaciones de diferentes monedas.';tr = 'Mevcut muhasebe hesabı çok para birimli kayıtları desteklemiyor.';it = 'Il corrente conto mastro non supporta le registrazioni multi-valuta.';de = 'Das aktuelle Hauptbuch-Konto unterstützt keine Datensätze in mehreren Währungen.'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the GL account first.'; ru = 'Сначала укажите счет учета.';pl = 'Najpierw podaj konto księgowe.';es_ES = 'Especificar la cuenta del libro mayor primero.';es_CO = 'Especificar la cuenta del libro mayor primero.';tr = 'Önce muhasebe hesabını belirtin.';it = 'Specificare il Conto mastro prima di tutto.';de = 'Geben Sie zuerst das Hauptbuch-Konto an.'"));
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the input field AmountCurrencyCr.
// Transactions tabular section.
//
Procedure AccountingRecordsAmountCurCrOnChange(Item)
	
	CurrentRow = Items.AccountingRecords.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.AccountCr);
	
	If Not StructureData.Currency Then
		CurrentRow.AmountCurCr = 0;
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.AccountCr) Then
			ShowMessageBox(Undefined,NStr("en = 'Current GL account does not support multi-currency records.'; ru = 'Текущий счет учета не поддерживает записи в разных валютах.';pl = 'Aktualne konto księgowe nie obsługuje wpisów wielowalutowych.';es_ES = 'Cuenta del libro mayor actual no admite las grabaciones de diferentes monedas.';es_CO = 'Cuenta del libro mayor actual no admite las grabaciones de diferentes monedas.';tr = 'Mevcut muhasebe hesabı çok para birimli kayıtları desteklemiyor.';it = 'Il corrente conto mastro non supporta le registrazioni multi-valuta.';de = 'Das aktuelle Hauptbuch-Konto unterstützt keine Datensätze in mehreren Währungen.'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the GL account first.'; ru = 'Сначала укажите счет учета.';pl = 'Najpierw podaj konto księgowe.';es_ES = 'Especificar la cuenta del libro mayor primero.';es_CO = 'Especificar la cuenta del libro mayor primero.';tr = 'Önce muhasebe hesabını belirtin.';it = 'Specificare il Conto mastro prima di tutto.';de = 'Geben Sie zuerst das Hauptbuch-Konto an.'"));
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
EndProcedure

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

#EndRegion

#EndRegion

#EndRegion
