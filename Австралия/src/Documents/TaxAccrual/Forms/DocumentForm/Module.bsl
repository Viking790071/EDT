#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("Counterparty", DriveServer.GetCompany(Company));
	
	ProcessingCompanyVATNumbers(False);
	
	Return StructureData;
	
EndFunction

// Sets choice parameter links depending on operation kind.
//
&AtServer
Procedure SetChoiceParameterLinks()
	
	If Not UseDefaultTypeOfAccounting Then
		Return;
	EndIf;
	
	NewArray = New Array();
	
	If Object.OperationKind = Enums.OperationTypesTaxAccrual.Accrual Then
		NewArray.Add(Enums.GLAccountsTypes.Expenses);
		NewArray.Add(Enums.GLAccountsTypes.OtherExpenses);
		NewArray.Add(Enums.GLAccountsTypes.WorkInProgress);
		NewArray.Add(Enums.GLAccountsTypes.IncomeTax);
	Else
		NewArray.Add(Enums.GLAccountsTypes.Revenue);
		NewArray.Add(Enums.GLAccountsTypes.OtherIncome);
		NewArray.Add(Enums.GLAccountsTypes.WorkInProgress);
		NewArray.Add(Enums.GLAccountsTypes.IncomeTax);
	EndIf;
	
	AccountTypesArray = New FixedArray(NewArray);
	NewParameter = New ChoiceParameter("Filter.TypeOfAccount", AccountTypesArray);
	NewArray = New Array();
	NewArray.Add(NewParameter);
	
	NewParameter = New ChoiceParameter("IncludeCostOfOther", True);
	NewArray.Add(NewParameter);
	
	NewParameter = New ChoiceParameter("IncludeInIncomeOther", True);
	NewArray.Add(NewParameter);
	
	NewParameters = New FixedArray(NewArray);
	
	Items.Taxes.ChildItems.TaxesCorrespondence.ChoiceParameters = NewParameters;
	
EndProcedure

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	StructureArray = New Array();
	
	Expenses = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "Taxes");
	GLAccountsInDocuments.CompleteStructureData(Expenses, ObjectParameters, "Taxes");
	StructureArray.Add(Expenses);
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, GetGLAccounts);
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed);
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ProcessingCompanyVATNumbers();
	
	SettingsAccordingToOperationKind();
	
	DefaultExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("OtherExpenses");
	DefaultIncomeItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("OtherIncome");
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	FillAddedColumns();
	
	SetIncomeAndExpenseItemsVisibility();
	
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
	FillAddedColumns();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
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

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	FillAddedColumns();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("RefreshAccountingTransaction");
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, SelectedValue);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersTaxes

&AtClient
Procedure TaxTypeOfTaxOnChange(Item)
	
	CurrentData = Items.Taxes.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	FillIncomeAndExpenseItems(Items.Taxes.CurrentRow);
	
EndProcedure

&AtClient
Procedure TaxesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "TaxesIncomeAndExpenseItems" Then
		StandardProcessing = False;
		IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Taxes");
	EndIf;
	
EndProcedure

&AtClient
Procedure TaxesIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "Expenses", StandardProcessing);
	
EndProcedure

&AtClient
Procedure TaxesOnActivateCell(Item)
	
	CurrentData = Items.Taxes.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Taxes.CurrentItem;
		If TableCurrentColumn.Name = "TaxesIncomeAndExpenseItems"
			And Not CurrentData.IncomeAndExpenseItemsFilled Then
			SelectedRow = Items.Taxes.CurrentRow;
			IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Taxes");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure TaxesOnStartEdit(Item, NewRow, Clone)
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);
	
EndProcedure

&AtClient
Procedure TaxesOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure TaxesCorrespondenceOnChange(Item)
	
	CurData = Items.Taxes.CurrentData;
	If CurData <> Undefined Then
		
		StructureData = New Structure("
		|TabName,
		|Object,
		|Correspondence,
		|IncomeAndExpenseItems,
		|IncomeAndExpenseItemsFilled,
		|ExpenseItem,
		|IncomeItem,
		|Manual");
		StructureData.Object 	= Object;
		StructureData.TabName 	= "Taxes";
		StructureData.Manual 	= True;
		FillPropertyValues(StructureData, CurData);
		
		GLAccountsInDocumentsServerCall.CheckItemRegistration(StructureData);
		FillPropertyValues(CurData, StructureData);
		
		FillIncomeAndExpenseItems(Items.Taxes.CurrentRow);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TaxesRegisterExpenseOnChange(Item)
	
	CurrentData = Items.Taxes.CurrentData;
	
	If CurrentData <> Undefined And Not CurrentData.RegisterExpense Then
		CurrentData.ExpenseItem = PredefinedValue("Catalog.IncomeAndExpenseItems.EmptyRef");
		FillAddedColumns();
	EndIf;
	
EndProcedure

&AtClient
Procedure TaxesRegisterIncomeOnChange(Item)
	
	CurrentData = Items.Taxes.CurrentData;
	
	If CurrentData <> Undefined And Not CurrentData.RegisterIncome Then
		CurrentData.IncomeItem = PredefinedValue("Catalog.IncomeAndExpenseItems.EmptyRef");
		FillAddedColumns();
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfHeaderAttributes

// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "");
	
	ProcessingCompanyVATNumbers();
	
EndProcedure

// Procedure - event handler OnChange of the Company input field.
// In procedure the document number is cleared,
// and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	Counterparty = StructureData.Counterparty;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	Object.DocumentCurrency = DriveServer.GetPresentationCurrency(ParentCompany);	
	
EndProcedure

// Procedure - event handler OnChange of the OperationKind input field.
//
&AtClient
Procedure OperationKindOnChange(Item)
	
	FillIncomeAndExpenseItems();
	SettingsAccordingToOperationKind();
	
EndProcedure

&AtServer
Procedure SettingsAccordingToOperationKind()
	
	SetIncomeAndExpenseItemsVisibility();
	SetChoiceParameterLinks();
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);
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

#Region Private

&AtServer
Procedure SetIncomeAndExpenseItemsVisibility()
	
	IsAccrualOperation = (Object.OperationKind = Enums.OperationTypesTaxAccrual.Accrual);
	
	IncomeAndExpenseItemsInDocuments.SetRegistrationAttributesVisibility(
		ThisObject, "TaxesRegisterIncome", Not UseDefaultTypeOfAccounting And Not IsAccrualOperation);
		
	IncomeAndExpenseItemsInDocuments.SetRegistrationAttributesVisibility(
		ThisObject, "TaxesRegisterExpense", Not UseDefaultTypeOfAccounting And IsAccrualOperation);
	
EndProcedure

&AtServer
Procedure FillIncomeAndExpenseItems(CurrentData = Undefined)
	
	IsAccrual = Object.OperationKind = Enums.OperationTypesTaxAccrual.Accrual;
	EmptyItem = Catalogs.IncomeAndExpenseItems.EmptyRef();
	
	If CurrentData = Undefined Then
		For Each Row In Object.Taxes Do
			FillIncomeAndExpenseItemsInRow(Row, IsAccrual, EmptyItem);
		EndDo;
	Else
		Row = Object.Taxes.FindByID(CurrentData);
		FillIncomeAndExpenseItemsInRow(Row, IsAccrual, EmptyItem);
	EndIf;
	
	FillAddedColumns();
	
EndProcedure

&AtServer
Procedure FillIncomeAndExpenseItemsInRow(Row, IsAccrual, EmptyItem)
	
	IsIncomeAndExpenseGLA = GLAccountsInDocumentsServerCall.IsIncomeAndExpenseGLA(Row.Correspondence);
	Register = ?(UseDefaultTypeOfAccounting, IsIncomeAndExpenseGLA, True);
	
	If IsAccrual Then
		Row.ExpenseItem = ?(Register, DefaultExpenseItem, EmptyItem);
		Row.RegisterExpense = Register;
		
		Row.IncomeItem = EmptyItem;
		Row.RegisterIncome = False;
	Else
		Row.IncomeItem = ?(Register, DefaultIncomeItem, EmptyItem);
		Row.RegisterIncome = Register;
		
		Row.ExpenseItem = EmptyItem;
		Row.RegisterExpense = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion
