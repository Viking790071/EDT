#Region FormEventHandlers

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
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

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Object.Ref.IsEmpty() Then
		Object.Date = BegOfDay(CurrentSessionDate());
		Object.BeginningBalance = GetBeginningBalance(Object.Company, Object.BankAccount, Object.Date, Object.Ref);
		Object.IncomeItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("InterestIncome");
	EndIf;
	
	BookBalance = GetBookBalance(Object.Company, Object.BankAccount, Object.Date, Object.Ref);
	
	If Object.Ref.IsEmpty() Then
		Object.EndingBalance = BookBalance;
	EndIf;
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	SetConditionalAppearance();
	
	FillReconciliationSpec(Object.Date, Object.BankAccount);
	
	SetServiceChargeInterestEarnedFormItemsProperties();
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	ClearedItemsFilter = New Structure("Cleared", True);
	ClearedItemsVT = LineItems.Unload(ClearedItemsFilter, "Transaction, TransactionType, TransactionAmount");
	CurrentObject.ClearedTransactions.Load(ClearedItemsVT);
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("RefreshAccountingTransaction");
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	CheckPaymentExpensesArePaid(Cancel);
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "");
	RefillDataOnKeyAttributesChange();
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	RefillDataOnKeyAttributesChange();
	
EndProcedure

&AtClient
Procedure BankAccountOnChange(Item)
	
	RefillDataOnKeyAttributesChange();
	
EndProcedure

&AtClient
Procedure BeginningBalanceOnChange(Item)
	
	RecalculateBalances(ThisObject, 0, 0, 0);
	
EndProcedure

&AtClient
Procedure EndingBalanceOnChange(Item)
	
	RecalculateBalances(ThisObject, 0, 0, 0);
	
EndProcedure

&AtClient
Procedure UseServiceChargeOnChange(Item)
	
	SetServiceChargeInterestEarnedFormItemsProperties();
	RecalculateBalances(ThisObject, 0, 0, 0);
	
EndProcedure

&AtClient
Procedure ServiceChargeTypeOnChange(Item)
	
	If ValueIsFilled(Object.ServiceChargeType) Then
		
		StructureData = GetDataServiceChargeTypeOnChange(Object.ServiceChargeType);
		
		Object.ServiceChargeCashFlowItem = StructureData.Item;
		Object.ExpenseItem = StructureData.ExpenseItem;
		
		If UseDefaultTypeOfAccounting Then
			Object.ServiceChargeAccount = StructureData.GLExpenseAccount;
		EndIf;
		
		If StructureData.ChargeType = PredefinedValue("Enum.ChargeMethod.Amount") Then
			
			Object.ServiceChargeAmount = StructureData.Value;
			RecalculateBalances(ThisObject, 0, 0, 0);
			
		EndIf;
		
		If Not ValueIsFilled(Object.ServiceChargeDate) Then
			Object.ServiceChargeDate = Object.Date;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ServiceChargeAmountOnChange(Item)
	
	RecalculateBalances(ThisObject, 0, 0, 0);
	
	If Not ValueIsFilled(Object.ServiceChargeDate) Then
		Object.ServiceChargeDate = Object.Date;
	EndIf;
	
EndProcedure

&AtClient
Procedure UseInterestEarnedOnChange(Item)
	
	SetServiceChargeInterestEarnedFormItemsProperties();
	RecalculateBalances(ThisObject, 0, 0, 0);
	
EndProcedure

&AtClient
Procedure InterestEarnedAmountOnChange(Item)
	
	RecalculateBalances(ThisObject, 0, 0, 0);
	
	If Not ValueIsFilled(Object.InterestEarnedDate) Then
		Object.InterestEarnedDate = Object.Date;
	EndIf;
	
EndProcedure

&AtClient
Procedure LineItemsFilterOnChange(Item)
	
	SetLineItemsFilter();
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

&AtClient
Procedure ServiceChargeAccountOnChange(Item)
	
	Structure = New Structure("Object,ServiceChargeAccount,ExpenseItem,IncomeItem,Manual");
	Structure.Object = Object;
	Structure.Manual = True;
	FillPropertyValues(Structure, Object);
	
	GLAccountsInDocumentsServerCall.CheckItemRegistration(Structure);
	FillPropertyValues(Object, Structure);
	
EndProcedure

&AtClient
Procedure InterestEarnedAccountOnChange(Item)
	
	Structure = New Structure("Object,InterestEarnedAccount,IncomeItem,ExpenseItem,Manual");
	Structure.Object = Object;
	FillPropertyValues(Structure, Object);
	
	GLAccountsInDocumentsServerCall.CheckItemRegistration(Structure);
	FillPropertyValues(Object, Structure);
	
EndProcedure

#EndRegion

#Region LineItemsFormTableItemsEventHandlers

&AtClient
Procedure LineItemsClearedOnChange(Item)
	
	Row = Items.LineItems.CurrentData;
	
	If Row.Cleared Then
		RecalculateBalances(ThisObject, Row.TransactionAmount, Row.Payment, Row.Deposit);
	Else
		RecalculateBalances(ThisObject, -Row.TransactionAmount, -Row.Payment, -Row.Deposit);
	EndIf;
	
EndProcedure

&AtClient
Procedure LineItemsBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure LineItemsBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure LineItemsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	ShowValue(Undefined, Item.CurrentData.Transaction);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure RefreshList(Command)
	
	BookBalance = GetBookBalance(Object.Company, Object.BankAccount, Object.Date, Object.Ref);
	FillReconciliationSpec(Object.Date, Object.BankAccount);
	Modified = True;
	SetLineItemsFilter();
	
EndProcedure

&AtClient
Procedure CheckAll(Command)
	
	For Each LineItem In LineItems Do
		LineItem.Cleared = True;
	EndDo;
	
	Object.ClearedAmount = LineItems.Total("TransactionAmount");
	Object.ClearedCreditsDeposits = LineItems.Total("Deposit");
	Object.ClearedDebitsPayments = LineItems.Total("Payment");
	
	UnclearedCredits = 0;
	UnclearedDebits = 0;
	
	RecalculateBalances(ThisObject, 0, 0, 0);
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	For Each LineItem In LineItems Do
		LineItem.Cleared = False;
	EndDo;
	
	Object.ClearedAmount = 0;
	Object.ClearedCreditsDeposits = 0;
	Object.ClearedDebitsPayments= 0;
	
	UnclearedCredits = LineItems.Total("Deposit");
	UnclearedDebits = LineItems.Total("Payment");
	
	RecalculateBalances(ThisObject, 0, 0, 0);
	
	Modified = True;
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function GetBeginningBalance(Company, BankAccount, StatementDate, Ref)
	
	Query = New Query(
	"SELECT ALLOWED TOP 1
	|	BankReconciliation.EndingBalance AS EndingBalance
	|FROM
	|	Document.BankReconciliation AS BankReconciliation
	|WHERE
	|	BankReconciliation.DeletionMark = FALSE
	|	AND BankReconciliation.Posted = TRUE
	|	AND BankReconciliation.Company = &Company
	|	AND BankReconciliation.BankAccount = &BankAccount
	|	AND BankReconciliation.Date < &StatementDate
	|	AND BankReconciliation.Ref <> &Ref
	|
	|ORDER BY
	|	BankReconciliation.PointInTime DESC");
	
	Query.SetParameter("Company", Company);
	Query.SetParameter("BankAccount", BankAccount);
	Query.SetParameter("StatementDate", StatementDate);
	Query.SetParameter("Ref", Ref);
	
	Sel = Query.Execute().Select();
	If Sel.Next() > 0 Then 
		Return Sel.EndingBalance;
	Else
		Return 0;
	EndIf;
	
EndFunction

&AtServerNoContext
Function GetBookBalance(Company, BankAccount, StatementDate, Ref)
	
	CashQuery = New Query(
	"SELECT ALLOWED
	|	CashAssetsBalance.AmountCurBalance AS Amount
	|INTO TT_CashAssets
	|FROM
	|	AccumulationRegister.CashAssets.Balance(
	|			&StatementDate,
	|			Company = &Company
	|				AND BankAccountPettyCash = &BankAccount) AS CashAssetsBalance
	|
	|UNION ALL
	|
	|SELECT
	|	CASE
	|		WHEN CashAssets.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -CashAssets.AmountCur
	|		ELSE CashAssets.AmountCur
	|	END
	|FROM
	|	AccumulationRegister.CashAssets AS CashAssets
	|WHERE
	|	CashAssets.Recorder = &Recorder
	|	AND CashAssets.Company = &Company
	|	AND CashAssets.BankAccountPettyCash = &BankAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(TT_CashAssets.Amount) AS Amount
	|FROM
	|	TT_CashAssets AS TT_CashAssets");
	
	CashQuery.SetParameter("Company", Company);
	CashQuery.SetParameter("BankAccount", BankAccount);
	CashQuery.SetParameter("StatementDate", EndOfDay(StatementDate) + 1);
	CashQuery.SetParameter("Recorder", Ref);
	
	Sel = CashQuery.Execute().Select();
	If Sel.Next() Then 
		Return Sel.Amount;
	Else
		Return 0;
	EndIf;
	
EndFunction

&AtServer
Procedure SetConditionalAppearance()
	
	Item = ConditionalAppearance.Items.Add();
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleDataColor);
	
	FilterItem = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("LineItems.Cleared");
	FilterItem.RightValue = New DataCompositionField("LineItems.ClearedFilter");
	FilterItem.ComparisonType = DataCompositionComparisonType.NotEqual;
	
	FilterItem = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("LineItemsFilter");
	FilterItem.RightValue = 0;
	FilterItem.ComparisonType = DataCompositionComparisonType.Greater;
	
	FieldsItem = Item.Fields.Items.Add();
	FieldsItem.Field = New DataCompositionField("LineItems");
	
EndProcedure

&AtServer
Procedure FillReconciliationSpec(Date, BankAccount)
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	BankReconciliationBalance.Transaction AS Transaction,
	|	BankReconciliationBalance.TransactionType AS TransactionType,
	|	BankReconciliationBalance.AmountBalance AS TransactionAmount
	|INTO TT_Balances
	|FROM
	|	AccumulationRegister.BankReconciliation.Balance(&Period, BankAccount = &BankAccount) AS BankReconciliationBalance
	|
	|UNION ALL
	|
	|SELECT
	|	BankReconciliation.Transaction,
	|	BankReconciliation.TransactionType,
	|	BankReconciliation.Amount
	|FROM
	|	AccumulationRegister.BankReconciliation AS BankReconciliation
	|WHERE
	|	BankReconciliation.Recorder = &Ref
	|	AND BankReconciliation.BankAccount = &BankAccount
	|	AND BankReconciliation.Active
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Balances.Transaction AS Transaction,
	|	TT_Balances.TransactionType AS TransactionType,
	|	SUM(TT_Balances.TransactionAmount) AS TransactionAmount
	|INTO TT_Transactions
	|FROM
	|	TT_Balances AS TT_Balances
	|
	|GROUP BY
	|	TT_Balances.Transaction,
	|	TT_Balances.TransactionType
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TT_Transactions.Transaction AS Transaction,
	|	TT_Transactions.TransactionType AS TransactionType,
	|	TT_Transactions.TransactionAmount AS TransactionAmount,
	|	DocumentHeader.Number AS DocNumber,
	|	DocumentHeader.Date AS Date,
	|	CASE
	|		WHEN DocumentHeader.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash)
	|				AND DocumentHeader.BankAccount = &BankAccount
	|			THEN DocumentHeader.BankAccountPayee
	|		ELSE DocumentHeader.BankAccount
	|	END AS Counterparty
	|INTO TT_TransactionsWithDocsData
	|FROM
	|	TT_Transactions AS TT_Transactions
	|		INNER JOIN Document.CashTransfer AS DocumentHeader
	|		ON TT_Transactions.Transaction = DocumentHeader.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	TT_Transactions.Transaction,
	|	TT_Transactions.TransactionType,
	|	TT_Transactions.TransactionAmount,
	|	DocumentHeader.Number,
	|	DocumentHeader.Date,
	|	CASE
	|		WHEN DocumentHeader.FromAccount = &BankAccount
	|			THEN DocumentHeader.ToAccount
	|		ELSE DocumentHeader.FromAccount
	|	END
	|FROM
	|	TT_Transactions AS TT_Transactions
	|		INNER JOIN Document.ForeignCurrencyExchange AS DocumentHeader
	|		ON TT_Transactions.Transaction = DocumentHeader.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	TT_Transactions.Transaction,
	|	TT_Transactions.TransactionType,
	|	TT_Transactions.TransactionAmount,
	|	DocumentHeader.Number,
	|	DocumentHeader.Date,
	|	CASE
	|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.ToAdvanceHolder)
	|				OR DocumentHeader.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.IssueLoanToEmployee)
	|			THEN DocumentHeader.AdvanceHolder
	|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Other)
	|				OR DocumentHeader.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Taxes)
	|				OR DocumentHeader.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Salary)
	|			THEN DocumentHeader.Item
	|		ELSE DocumentHeader.Counterparty
	|	END
	|FROM
	|	TT_Transactions AS TT_Transactions
	|		INNER JOIN Document.PaymentExpense AS DocumentHeader
	|		ON TT_Transactions.Transaction = DocumentHeader.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	TT_Transactions.Transaction,
	|	TT_Transactions.TransactionType,
	|	TT_Transactions.TransactionAmount,
	|	DocumentHeader.Number,
	|	DocumentHeader.Date,
	|	CASE
	|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromAdvanceHolder)
	|				OR DocumentHeader.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByEmployee)
	|			THEN DocumentHeader.AdvanceHolder
	|		WHEN DocumentHeader.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.Taxes)
	|				OR DocumentHeader.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.Other)
	|				OR DocumentHeader.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.CurrencyPurchase)
	|			THEN DocumentHeader.Item
	|		ELSE DocumentHeader.Counterparty
	|	END
	|FROM
	|	TT_Transactions AS TT_Transactions
	|		INNER JOIN Document.PaymentReceipt AS DocumentHeader
	|		ON TT_Transactions.Transaction = DocumentHeader.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	BankReconciliation.Ref AS Ref
	|INTO TT_BankReconciliation
	|FROM
	|	Document.BankReconciliation AS BankReconciliation
	|WHERE
	|	BankReconciliation.Ref = &Ref
	|	AND BankReconciliation.BankAccount = &BankAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	BankReconciliationClearedTransactions.Transaction AS Transaction,
	|	BankReconciliationClearedTransactions.TransactionType AS TransactionType,
	|	TRUE AS Cleared
	|INTO TT_ClearedTransactions
	|FROM
	|	TT_BankReconciliation AS TT_BankReconciliation
	|		INNER JOIN Document.BankReconciliation.ClearedTransactions AS BankReconciliationClearedTransactions
	|		ON TT_BankReconciliation.Ref = BankReconciliationClearedTransactions.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_TransactionsWithDocsData.Transaction AS Transaction,
	|	TT_TransactionsWithDocsData.TransactionType AS TransactionType,
	|	TT_TransactionsWithDocsData.TransactionAmount AS TransactionAmount,
	|	TT_TransactionsWithDocsData.DocNumber AS DocNumber,
	|	TT_TransactionsWithDocsData.Date AS Date,
	|	TT_TransactionsWithDocsData.Counterparty AS Counterparty,
	|	CASE
	|		WHEN TT_TransactionsWithDocsData.TransactionAmount > 0
	|			THEN TT_TransactionsWithDocsData.TransactionAmount
	|		ELSE 0
	|	END AS Deposit,
	|	CASE
	|		WHEN TT_TransactionsWithDocsData.TransactionAmount < 0
	|			THEN -TT_TransactionsWithDocsData.TransactionAmount
	|		ELSE 0
	|	END AS Payment,
	|	ISNULL(TT_ClearedTransactions.Cleared, FALSE) AS Cleared
	|FROM
	|	TT_TransactionsWithDocsData AS TT_TransactionsWithDocsData
	|		LEFT JOIN TT_ClearedTransactions AS TT_ClearedTransactions
	|		ON TT_TransactionsWithDocsData.Transaction = TT_ClearedTransactions.Transaction
	|			AND TT_TransactionsWithDocsData.TransactionType = TT_ClearedTransactions.TransactionType
	|
	|ORDER BY
	|	Date,
	|	Transaction,
	|	TransactionType";
	
	Query.SetParameter("Ref", Object.Ref);
	Query.SetParameter("Period", EndOfDay(Date) + 1);
	Query.SetParameter("BankAccount", BankAccount);
	
	VTResult = Query.Execute().Unload();
	LineItems.Load(VTResult);
	
	Object.ClearedAmount = 0;
	Object.ClearedCreditsDeposits = 0;
	Object.ClearedDebitsPayments = 0;
	ClearedRows = LineItems.FindRows(New Structure("Cleared", True));
	For Each ClearedRow In ClearedRows Do
		Object.ClearedAmount = Object.ClearedAmount + ClearedRow.TransactionAmount;
		Object.ClearedCreditsDeposits = Object.ClearedCreditsDeposits + ClearedRow.Deposit;
		Object.ClearedDebitsPayments = Object.ClearedDebitsPayments + ClearedRow.Payment;
	EndDo;
	
	UnclearedCredits = 0;
	UnclearedDebits = 0;
	UnclearedRows = LineItems.FindRows(New Structure("Cleared", False));
	For Each UnclearedRow In UnclearedRows Do
		UnclearedCredits = UnclearedCredits + UnclearedRow.Deposit;
		UnclearedDebits = UnclearedDebits + UnclearedRow.Payment;
	EndDo;
	
	RecalculateBalances(ThisObject, 0, 0, 0);
	
EndProcedure

&AtClientAtServerNoContext
Procedure RecalculateBalances(Form, Amount, Debit, Credit)
	
	Object = Form.Object;
	
	Object.ClearedAmount = Object.ClearedAmount + Amount;
	Object.ClearedCreditsDeposits = Object.ClearedCreditsDeposits + Credit;
	Object.ClearedDebitsPayments = Object.ClearedDebitsPayments + Debit;
	
	Object.ClearedBalance = Object.BeginningBalance + Object.ClearedAmount;
	
	Object.ClearedDifference = Object.EndingBalance - Object.ClearedBalance;
	If Object.UseServiceCharge Then
		Object.ClearedDifference = Object.ClearedDifference + Object.ServiceChargeAmount;
	EndIf;
	If Object.UseInterestEarned Then
		Object.ClearedDifference = Object.ClearedDifference - Object.InterestEarnedAmount;
	EndIf;
	
	Form.UnclearedCredits	= Form.UnclearedCredits - Credit;
	Form.UnclearedDebits	= Form.UnclearedDebits - Debit;
	
	Form.AdjustedBookBalance = Object.EndingBalance + Form.UnclearedCredits - Form.UnclearedDebits;
	
	Form.BankToBookDifference = Form.AdjustedBookBalance - Form.BookBalance;
	If Object.UseServiceCharge Then
		Form.BankToBookDifference = Form.BankToBookDifference + Object.ServiceChargeAmount;
	EndIf;
	If Object.UseInterestEarned Then
		Form.BankToBookDifference = Form.BankToBookDifference - Object.InterestEarnedAmount;
	EndIf;
	
EndProcedure

&AtServer
Procedure RefillDataOnKeyAttributesChange()
	
	If Not ValueIsFilled(Object.Date) Then
		Object.Date = CurrentSessionDate();
	EndIf;
	
	Object.BeginningBalance = GetBeginningBalance(Object.Company, Object.BankAccount, Object.Date, Object.Ref);
	BookBalance = GetBookBalance(Object.Company, Object.BankAccount, Object.Date, Object.Ref);
	
	FillReconciliationSpec(Object.Date, Object.BankAccount);
	
EndProcedure

&AtServer
Procedure SetServiceChargeInterestEarnedFormItemsProperties()
	
	Items.GroupServiceChargeItems.ReadOnly = Not Object.UseServiceCharge;
	Items.GroupClearedBalanceServiceCharge.Visible = Object.UseServiceCharge;
	Items.GroupBankToBookDifferenceServiceCharge.Visible = Object.UseServiceCharge;
	
	Items.ServiceChargeType.AutoMarkIncomplete = Object.UseServiceCharge;
	If Not Object.UseServiceCharge Then
		Items.ServiceChargeType.MarkIncomplete = False;
	EndIf;
	
	Items.ServiceChargeCashFlowItem.AutoMarkIncomplete = Object.UseServiceCharge;
	If Not Object.UseServiceCharge Then
		Items.ServiceChargeCashFlowItem.MarkIncomplete = False;
	EndIf;
	
	Items.ExpenseItem.AutoMarkIncomplete = Object.UseServiceCharge;
	If Not Object.UseServiceCharge Then
		Items.ExpenseItem.MarkIncomplete = False;
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		Items.ServiceChargeAccount.AutoMarkIncomplete = Object.UseServiceCharge;
		If Not Object.UseServiceCharge Then
			Items.ServiceChargeAccount.MarkIncomplete = False;
		EndIf;
	Else
		Items.ServiceChargeAccount.Visible = False;
	EndIf;
	
	Items.ServiceChargeAmount.AutoMarkIncomplete = Object.UseServiceCharge;
	If Not Object.UseServiceCharge Then
		Items.ServiceChargeAmount.MarkIncomplete = False;
	EndIf;
	
	Items.ServiceChargeDate.AutoMarkIncomplete = Object.UseServiceCharge;
	If Not Object.UseServiceCharge Then
		Items.ServiceChargeDate.MarkIncomplete = False;
	EndIf;
	
	Items.GroupInterestEarnedItems.ReadOnly = Not Object.UseInterestEarned;
	Items.GroupClearedBalanceInterestEarned.Visible = Object.UseInterestEarned;
	Items.GroupBankToBookDifferenceInterestEarned.Visible = Object.UseInterestEarned;
	
	Items.InterestEarnedCashFlowItem.AutoMarkIncomplete = Object.UseInterestEarned;
	If Not Object.UseInterestEarned Then
		Items.InterestEarnedCashFlowItem.MarkIncomplete = False;
	EndIf;
	
	Items.IncomeItem.AutoMarkIncomplete = Object.UseInterestEarned;
	If Not Object.UseInterestEarned Then
		Items.IncomeItem.MarkIncomplete = False;
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		Items.InterestEarnedAccount.AutoMarkIncomplete = Object.UseInterestEarned;
		If Not Object.UseInterestEarned Then
			Items.InterestEarnedAccount.MarkIncomplete = False;
		EndIf;
	Else
		Items.InterestEarnedAccount.Visible = False;
	EndIf;
	
	Items.InterestEarnedAmount.AutoMarkIncomplete = Object.UseInterestEarned;
	If Not Object.UseInterestEarned Then
		Items.InterestEarnedAmount.MarkIncomplete = False;
	EndIf;
	
	Items.InterestEarnedDate.AutoMarkIncomplete = Object.UseInterestEarned;
	If Not Object.UseInterestEarned Then
		Items.InterestEarnedDate.MarkIncomplete = False;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetDataServiceChargeTypeOnChange(ServiceChargeType)
	
	Return Common.ObjectAttributesValues(
		ServiceChargeType,
		"ExpenseItem,
		|GLExpenseAccount,
		|ChargeType,
		|Value,
		|Item");

EndFunction

&AtClient
Procedure SetLineItemsFilter()
	
	If LineItemsFilter = 0 Then
		
		Items.LineItems.RowFilter = Undefined;
		
	Else
		
		For Each Row In LineItems Do
			Row.ClearedFilter = Row.Cleared;
		EndDo;
		
		Items.LineItems.RowFilter = New FixedStructure("ClearedFilter", Boolean(2 - LineItemsFilter));
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckPaymentExpensesArePaid(Cancel)
	
	Query = New Query;
	
	Query.Text =
	"SELECT
	|	Transactions.LineNumber AS LineNumber,
	|	Transactions.Transaction AS Transaction
	|INTO TT_Transactions
	|FROM
	|	&Transactions AS Transactions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	MIN(TT_Transactions.LineNumber) AS LineNumber
	|FROM
	|	TT_Transactions AS TT_Transactions
	|		INNER JOIN Document.PaymentExpense AS PaymentExpense
	|		ON TT_Transactions.Transaction = PaymentExpense.Ref
	|WHERE
	|	NOT PaymentExpense.Paid
	|
	|GROUP BY
	|	TT_Transactions.Transaction
	|
	|ORDER BY
	|	LineNumber";
	
	ClearedTransactions = LineItems.Unload(New Structure("Cleared", True), "Transaction");
	ClearedTransactions.Columns.Add("LineNumber", Common.TypeDescriptionNumber(10));
	For Each Row In ClearedTransactions Do
		Row.LineNumber = ClearedTransactions.IndexOf(Row) + 1;
	EndDo;
	
	Query.SetParameter("Transactions", ClearedTransactions);
	
	Sel = Query.Execute().Select();
	
	While Sel.Next() Do
		
			MessageText = NStr("en = 'The transaction cannot be cleared.
							|The Paid option is not enabled in the Bank payment document.'; 
							|ru = 'Операция не может быть зачтена.
							|В документе ""Списание со счета"" не отмечена опция ""Оплачено"".';
							|pl = 'Transakcja nie może być rozliczona.
							|Opcja Opłacono nie jest włączona w dokumencie Płatności bankowej.';
							|es_ES = 'La transacción no puede liquidarse. 
							|La opción de Pagar no está habilitada en el documento de pago bancario.';
							|es_CO = 'La transacción no puede liquidarse. 
							|La opción de Pagar no está habilitada en el documento de pago bancario.';
							|tr = 'İşlem silinemiyor.
							|Ödendi seçeneği Banka ödeme belgesinde etkin değil.';
							|it = 'La transazione non può essere compensato.
							|L''opzione di pagamento non è abilitata nel documento di pagamento bancario.';
							|de = 'Die Transaktion kann nicht verrechnet werden.
							|Die Option Bezahlt ist im Überweisungsbeleg nicht aktiviert.'");
			CommonClientServer.MessageToUser(
				MessageText,
				,
				StringFunctionsClientServer.SubstituteParametersToString(
					"LineItems[%1].Transaction",
					XMLString(Sel.LineNumber - 1)),
				,
				Cancel);
		
	EndDo;
	
EndProcedure

#Region LibrariesHandlers

#Region StandardSubsystems_Properties

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	
	PropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributeItems()
	
	PropertyManager.UpdateAdditionalAttributesItems(ThisObject);
	
EndProcedure

#EndRegion

#Region StandardSubsystems_AttachableCommands

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

#EndRegion

#EndRegion

#EndRegion