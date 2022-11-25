#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	Company = DriveServer.GetCompany(Object.Company);
	Object.DocumentCurrency = DriveServer.GetPresentationCurrency(Company);
	
	UpdateFormVisibilityAttributes();
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	If UseDefaultTypeOfAccounting Then
		
		For Each CurrentRow In Object.Expenses Do
			CurrentRow.TypeOfAccount = CurrentRow.GLExpenseAccount.TypeOfAccount;
		EndDo;
		
		FillAddedColumns();
		
	EndIf;
	
	IncomeAndExpenseItemsInDocuments.SetRegistrationAttributesVisibility(
		ThisObject, "ExpensesRegisterExpense");
	
	FormManagement(ThisForm);
	
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

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_ChartOfAccountPrimaryChartOfAccounts" Then
		If ValueIsFilled(Parameter)
			AND Object.Correspondence = Parameter Then
			
			UpdateFormVisibilityAttributes();
			FormManagement(ThisObject);
			
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, SelectedValue);
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	FillAddedColumns();
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("RefreshAccountingTransaction");
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "");
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number 		= "";
	StructureData		= GetDataCompanyOnChange(Object.Company);
	Company				= StructureData.Company;
	Object.DocumentCurrency	= StructureData.DocumentCurrency;
	
EndProcedure

&AtClient
Procedure CorrespondenceOnChange(Item)
	
	UpdateFormVisibilityAttributes();
	FormManagement(ThisObject);
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	StructureData = GetDataCounterpartyOnChange(Object.Counterparty, Object.Company, Object.Date);
	
	Object.Contract = StructureData.Contract;
	
EndProcedure

&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	FormParameters = GetChoiceFormParameters(Object.Ref, Object.Company, Object.Counterparty, Object.Contract);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OtherSettlementsAccountingOnChange(Item)
	
	FormManagement(ThisObject);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersTableExpenses

&AtClient
Procedure ExpensesGLExpenseAccountOnChange(Item)
	
	CurData = Items.Expenses.CurrentData;
	If CurData <> Undefined Then
		
		AccountParameters		= GetGLExpenseAccountParametersOnChange(CurData.GLExpenseAccount);
		CurData.TypeOfAccount	= AccountParameters.TypeOfAccount;
		
		StructureData = New Structure("
		|TabName,
		|Object,
		|GLExpenseAccount,
		|IncomeAndExpenseItems,
		|IncomeAndExpenseItemsFilled,
		|ExpenseItem,
		|RegisterExpense,
		|Manual");
		StructureData.Object = Object;
		StructureData.TabName = "Expenses";
		FillPropertyValues(StructureData, CurData);
		
		GLAccountsInDocumentsServerCall.CheckItemRegistration(StructureData);
		FillPropertyValues(CurData, StructureData);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpensesCounterpartyOnChange(Item)
	
	CurrentData = Items.Expenses.CurrentData;
	CurrentData.Contract = GetContractByDefault(Object.Ref, CurrentData.Counterparty, Object.Company)
	
EndProcedure

&AtClient
Procedure ExpensesCounterpartyStartChoice(Item, ChoiceData, StandardProcessing)
	
	If UseDefaultTypeOfAccounting Then
		
		CurrentData = Items.Expenses.CurrentData;
		If CurrentData.TypeOfAccount <> PredefinedValue("Enum.GLAccountsTypes.AccountsPayable") 
			And CurrentData.TypeOfAccount <> PredefinedValue("Enum.GLAccountsTypes.AccountsReceivable") Then
			
			StandardProcessing = False;
			Message = New UserMessage;
			Message.Text = NStr("en = 'For this type of account, you do not need to specify a counterparty'; ru = 'Для данного типа счета не требуется указывать контрагента';pl = 'Dla danego rodzaju konta określenie kontrahenta nie jest konieczne';es_ES = 'Para este tipo de cuenta, usted no necesita especificar una contraparte';es_CO = 'Para este tipo de cuenta, usted no necesita especificar una contraparte';tr = 'Bu tür bir hesap için, cari hesabın belirtilmesine gerek yok';it = 'Per questo tipo di conto, non è necessario specificare una controparte';de = 'Für diese Art von Konto müssen Sie keinen Geschäftspartner angeben'");
			Message.Message();
			
		EndIf;
	
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpensesContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	TablePartRow = Items.Expenses.CurrentData;
	If UseDefaultTypeOfAccounting
		And TablePartRow.TypeOfAccount <> PredefinedValue("Enum.GLAccountsTypes.AccountsPayable") 
		And TablePartRow.TypeOfAccount <> PredefinedValue("Enum.GLAccountsTypes.AccountsReceivable") Then
		
		StandardProcessing = False;
		Message = New UserMessage;
		Message.Text = NStr("en = 'For this type of account, you do not need to specify a contract'; ru = 'Для данного типа счета не требуется указывать договор';pl = 'Dla danego rodzaju konta określenie umowy nie jest konieczne';es_ES = 'Para este tipo de cuenta, usted no necesita especificar un contrato';es_CO = 'Para este tipo de cuenta, usted no necesita especificar un contrato';tr = 'Bu tür bir hesap için, sözleşmenin belirtilmesine gerek yok.';it = 'Per questo tipo di conto, non è necessario specificare un contratto';de = 'Für diese Art von Konto müssen Sie keinen Vertrag angeben'");
		Message.Message();
		
	ElsIf TablePartRow <> Undefined Then
		
		FormParameters = GetChoiceFormParameters(Object.Ref, Object.Company, TablePartRow.Counterparty, TablePartRow.Contract);
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpensesIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "Expenses", StandardProcessing);
	
EndProcedure

&AtClient
Procedure ExpensesOnStartEdit(Item, NewRow, Copy)
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Copy);
	
	If NewRow And Not UseDefaultTypeOfAccounting Then
		Item.CurrentData.RegisterExpense = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpensesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "ExpensesIncomeAndExpenseItems" Then
		StandardProcessing = False;
		IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Expenses");
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpensesOnActivateCell(Item)
	
	CurrentData = Items.Expenses.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Expenses.CurrentItem;
		If TableCurrentColumn.Name = "ExpensesIncomeAndExpenseItems"
			And Not CurrentData.IncomeAndExpenseItemsFilled Then
			SelectedRow = Items.Expenses.CurrentRow;
			IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Expenses");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpensesOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure ExpensesRegisterExpenseOnChange(Item)
	
	CurrentData = Items.Expenses.CurrentData;
	
	If CurrentData <> Undefined And Not CurrentData.RegisterExpense Then
		CurrentData.ExpenseItem = PredefinedValue("Catalog.IncomeAndExpenseItems.EmptyRef");
		FillAddedColumns();
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClientAtServerNoContext
Procedure FormManagement(Form)

	Object	= Form.Object;
	Items	= Form.Items;
	
	Items.Contract.Visible = Form.DoOperationsByContracts;
	
	Items.Counterparty.Visible	= False;
	Items.Contract.Visible		= False;
	
	Items.ExpensesContract.Visible		= Object.OtherSettlementsAccounting And Not Form.UseDefaultTypeOfAccounting;
	Items.ExpensesCounterparty.Visible	= Object.OtherSettlementsAccounting And Not Form.UseDefaultTypeOfAccounting;
	
	If Object.OtherSettlementsAccounting Then
		
		If Not Form.UseDefaultTypeOfAccounting
			Or Form.UseDefaultTypeOfAccounting
				And (Form.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.AccountsReceivable")
					Or Form.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.AccountsPayable")) Then
				
			Items.Counterparty.Visible = True;
			Items.Contract.Visible = Form.DoOperationsByContracts;
			
		EndIf;
		
	EndIf;
	
	SetChoiceParametersByOtherSettlementsAccountingAtServer(Form);
	
EndProcedure

&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company)
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company);
	
EndFunction

&AtServerNoContext
Function GetChoiceFormParameters(Document, Company, Counterparty, Contract)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Document);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", Counterparty.DoOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractType", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

&AtServerNoContext
// Gets data set from server.
//
Function GetDataCompanyOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Company));
	StructureData.Insert("DocumentCurrency", DriveServer.GetPresentationCurrency(Company));
	
	Return StructureData;
	
EndFunction

&AtServer
Function GetDataCounterpartyOnChange(Counterparty, Company, Date)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company);
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"Contract",
		ContractByDefault
	);
	
	DoOperationsByContracts = Common.ObjectAttributeValue(Counterparty, "DoOperationsByContracts");
	SetVisibilitySettlementAttributes(ThisForm);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetGLExpenseAccountParametersOnChange(Account)
	
	Parameters = New Structure("TypeOfAccount");
	
	Parameters.Insert("TypeOfAccount", Account.TypeOfAccount);
	
	Return Parameters;
	
EndFunction

&AtClientAtServerNoContext
Procedure SetChoiceParametersByOtherSettlementsAccountingAtServer(Form)

	SetChoiceParametersByOtherSettlementsAccountingAtServerForItem(Form, Form.Items.Correspondence);
	SetChoiceParametersByOtherSettlementsAccountingAtServerForItem(Form, Form.Items.ExpensesGLExpenseAccount);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetChoiceParametersByOtherSettlementsAccountingAtServerForItem(Form, Item)

	Items = Form.Items;
	
	ItemChoiceParameters	= New Array;
	FilterByAccountType		= New Array;
	
	For Each Parameter In Item.ChoiceParameters Do
		If Form.UseDefaultTypeOfAccounting And Parameter.Name = "Filter.TypeOfAccount" Then
			
			For Each TypeOfAccount In Parameter.Value Do
				If TypeOfAccount <> PredefinedValue("Enum.GLAccountsTypes.AccountsPayable")
					AND TypeOfAccount <> PredefinedValue("Enum.GLAccountsTypes.AccountsReceivable")
					AND TypeOfAccount <> PredefinedValue("Enum.GLAccountsTypes.Capital") Then
					FilterByAccountType.Add(TypeOfAccount);
				EndIf;
			EndDo;
			
			If Form.Object.OtherSettlementsAccounting Then
				If FilterByAccountType.Find(PredefinedValue("Enum.GLAccountsTypes.AccountsReceivable")) = Undefined Then
					FilterByAccountType.Add(PredefinedValue("Enum.GLAccountsTypes.AccountsReceivable"));
				EndIf;
				If FilterByAccountType.Find(PredefinedValue("Enum.GLAccountsTypes.AccountsPayable")) = Undefined Then
					FilterByAccountType.Add(PredefinedValue("Enum.GLAccountsTypes.AccountsPayable"));
				EndIf;
				If Item = Items.Correspondence Then
					If FilterByAccountType.Find(PredefinedValue("Enum.GLAccountsTypes.Capital")) = Undefined Then
						FilterByAccountType.Add(PredefinedValue("Enum.GLAccountsTypes.Capital"));
					EndIf;
				EndIf;
			EndIf;
			
			ItemChoiceParameters.Add(New ChoiceParameter("Filter.TypeOfAccount", New FixedArray(FilterByAccountType)));
		Else
			ItemChoiceParameters.Add(Parameter);
		EndIf;
	EndDo;
	
	Item.ChoiceParameters = New FixedArray(ItemChoiceParameters);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetVisibilitySettlementAttributes(Form)
	
	FormManagement(Form);
	
EndProcedure

&AtServer
Procedure UpdateFormVisibilityAttributes()
	
	AttributesRow		= "DoOperationsByContracts";
	AttributesValues	= Common.ObjectAttributesValues(Object.Counterparty, AttributesRow);
	FillPropertyValues(ThisForm, AttributesValues, AttributesRow);
	
	AttributesRow		= "TypeOfAccount";
	AttributesValues	= Common.ObjectAttributesValues(Object.Correspondence, AttributesRow);
	FillPropertyValues(ThisForm, AttributesValues, AttributesRow);
	
EndProcedure

#Region GLAccounts

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	
	Header = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, "Header", Object);
	GLAccountsInDocuments.CompleteCounterpartyStructureData(Header, ObjectParameters, "Header");
	
	StructureData = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, "Expenses");
	GLAccountsInDocuments.CompleteCounterpartyStructureData(StructureData, ObjectParameters, "Expenses");
	
	StructureArray = New Array();
	StructureArray.Add(Header);
	StructureArray.Add(StructureData);
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, GetGLAccounts);
	
	IncomeAndExpenseItems = Header.IncomeAndExpenseItems;
	
EndProcedure

#EndRegion

#EndRegion

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

#Region Initialize

ThisIsNewRow = False;

#EndRegion