// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Period = Parameters.Date;
	ParentCompany = Parameters.ParentCompany;
	Counterparty = Parameters.Counterparty;
	CashCurrency = Parameters.CashCurrency;
	Ref = Parameters.Ref;
	OperationKind = Parameters.OperationKind;
	DocumentAmount = Parameters.DocumentAmount;
	
	Items.FilteredDebtsContract.Visible = Counterparty.DoOperationsByContracts;
	Items.FilteredDebtsOrder.Visible = Counterparty.DoOperationsByOrders;
	
	Items.DebtsListContract.Visible = Counterparty.DoOperationsByContracts;
	Items.DebtsListOrder.Visible = Counterparty.DoOperationsByOrders;
	
	PresentationCurrency = DriveServer.GetPresentationCurrency(ParentCompany);
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	
	AddressPaymentDetailsInStorage = Parameters.AddressPaymentDetailsInStorage;
	FilteredDebts.Load(GetFromTempStorage(AddressPaymentDetailsInStorage));
	
	// Removing the rows with no amount.
	RowToDeleteArray = New Array;
	For Each CurRow In FilteredDebts Do
		If CurRow.SettlementsAmount = 0 Then
			RowToDeleteArray.Add(CurRow);
		EndIf;
	EndDo;
	
	For Each CurItem In RowToDeleteArray Do
		FilteredDebts.Delete(CurItem);
	EndDo;
	
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	Items.DebtsListExchangeRate.Visible = ForeignExchangeAccounting;
	Items.DebtsListMultiplicity.Visible = ForeignExchangeAccounting;
	
	Items.Totals.Visible = Not ForeignExchangeAccounting;
	
	FillDebts();
	
EndProcedure

// Procedure - OnCreateAtServer event handler.
//
&AtClient
Procedure OnOpen(Cancel)
	
	CalculateAmountTotal();
	
EndProcedure

// Procedure calculates the total amount.
//
&AtClient
Procedure CalculateAmountTotal()
	
	AmountTotal = 0;
	
	For Each CurRow In FilteredDebts Do
		AmountTotal = AmountTotal + CurRow.SettlementsAmount;
	EndDo;
	
EndProcedure

// Procedure - OK button click handler.
//
&AtClient
Procedure OKExecute()
	
	WritePickToStorage();
	Close(DialogReturnCode.OK);
	
EndProcedure

// The procedure places pick-up results in the storage.
//
&AtServer
Procedure WritePickToStorage() 
	
	TableFilteredDebts = FilteredDebts.Unload();
	PutToTempStorage(TableFilteredDebts, AddressPaymentDetailsInStorage);
	
EndProcedure

// Procedure puts selection results in the selection.
//
&AtClient
Procedure DebtsListValueChoice(Item, StandardProcessing, Value)
	
	StandardProcessing = False;
	CurrentRow = Item.CurrentData;
	
	SettlementsAmount = CurrentRow.SettlementsAmount;
	If AskAmount Then
		ShowInputNumber(New NotifyDescription("DebtsListValueChoiceEnd", ThisObject, New Structure("CurrentRow, SettlementsAmount", CurrentRow, SettlementsAmount)), SettlementsAmount, "Enter the amount", , );
		Return;
	EndIf;
	
	DebtsListValueChoiceFragment(SettlementsAmount, CurrentRow);
EndProcedure

&AtClient
Procedure DebtsListValueChoiceEnd(Result, AdditionalParameters) Export
    
    CurrentRow = AdditionalParameters.CurrentRow;
    SettlementsAmount = ?(Result = Undefined, AdditionalParameters.SettlementsAmount, Result);
    
    
    If Not (Result <> Undefined) Then
        Return;
    EndIf;
    
    DebtsListValueChoiceFragment(SettlementsAmount, CurrentRow);

EndProcedure

&AtClient
Procedure DebtsListValueChoiceFragment(Val SettlementsAmount, Val CurrentRow)
    
    Var NewRow, Rows, SearchStructure;
    
    CurrentRow.SettlementsAmount = SettlementsAmount;
    
    SearchStructure = New Structure("Contract, Document, Order", CurrentRow.Contract, CurrentRow.Document, CurrentRow.Order);
    Rows = FilteredDebts.FindRows(SearchStructure);
    
    If Rows.Count() > 0 Then
        NewRow = Rows[0];
        NewRow.SettlementsAmount = NewRow.SettlementsAmount + SettlementsAmount;
    Else 
        NewRow = FilteredDebts.Add();
        FillPropertyValues(NewRow, CurrentRow);
    EndIf;
    
    Items.FilteredDebts.CurrentRow = NewRow.GetID();
    
    CalculateAmountTotal();
    FillDebts();

EndProcedure

// Procedure - DragStart of list DebtsList event handler.
//
&AtClient
Procedure DebtsListDragStart(Item, DragParameters, StandardProcessing)
	
	CurrentData = Item.CurrentData;
	Structure = New Structure;
	Structure.Insert("Document", CurrentData.Document);
	Structure.Insert("Order", CurrentData.Order);
	Structure.Insert("SettlementsAmount", CurrentData.SettlementsAmount);
	Structure.Insert("Contract", CurrentData.Contract);
	If CurrentData.Property("ExchangeRate") Then
		Structure.Insert("ExchangeRate", CurrentData.ExchangeRate);
	EndIf;
	If CurrentData.Property("Multiplicity") Then
		Structure.Insert("Multiplicity", CurrentData.Multiplicity);
	EndIf;
	
	DragParameters.Value = Structure;
	
	DragParameters.AllowedActions = DragAllowedActions.Copy;
	
EndProcedure

// Procedure - DragChek of list FilteredDebts event handler.
//
&AtClient
Procedure FilteredDebtsDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	DragParameters.Action = DragAction.Copy;
	
EndProcedure

// Procedure - DragChek of list FilteredDebts event handler.
//
&AtClient
Procedure FilteredDebtsDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
	ParametersStructure = DragParameters.Value;
	
	SettlementsAmount = ParametersStructure.SettlementsAmount;
	If AskAmount Then
		ShowInputNumber(New NotifyDescription("FilteredDebtsDragEnd", ThisObject, New Structure("StructureParameters,SettlementsAmount", ParametersStructure, SettlementsAmount)), SettlementsAmount, "Enter the amount", , );
        Return;
	EndIf;
	
	FilteredDebtsDragFragment(ParametersStructure, SettlementsAmount);
EndProcedure

&AtClient
Procedure FilteredDebtsDragEnd(Result, AdditionalParameters) Export
    
    ParametersStructure = AdditionalParameters.ParametersStructure;
    SettlementsAmount = ?(Result = Undefined, AdditionalParameters.SettlementsAmount, Result);
    
    
    If Not (Result <> Undefined) Then
        Return;
    EndIf;
    
    FilteredDebtsDragFragment(ParametersStructure, SettlementsAmount);

EndProcedure

&AtClient
Procedure FilteredDebtsDragFragment(Val ParametersStructure, Val SettlementsAmount)
    
    Var NewRow, Rows, SearchStructure;
    
    ParametersStructure.SettlementsAmount = SettlementsAmount;
    
    SearchStructure = New Structure("Contract, Document, Order", ParametersStructure.Contract, ParametersStructure.Document, ParametersStructure.Order);
    Rows = FilteredDebts.FindRows(SearchStructure);
    
    If Rows.Count() > 0 Then
        NewRow = Rows[0];
        NewRow.SettlementsAmount = NewRow.SettlementsAmount + SettlementsAmount;
    Else 
        NewRow = FilteredDebts.Add();
        FillPropertyValues(NewRow, ParametersStructure);
    EndIf;
    
    Items.FilteredDebts.CurrentRow = NewRow.GetID();
    
    CalculateAmountTotal();
    FillDebts();

EndProcedure

// Procedure - handler of clicking the Refresh button.
//
&AtClient
Procedure Refresh(Command)
	
	FillDebts();
	
EndProcedure

// Procedure - handler of clicking the AskAmount button.
//
&AtClient
Procedure AskAmount(Command)
	
	AskAmount = Not AskAmount;
	Items.AskAmount.Check = AskAmount;
	
EndProcedure

// Procedure - OnChange of list FilteredDebts event handler.
//
&AtClient
Procedure FilteredDebtsOnChange(Item)
	
	CalculateAmountTotal();
	FillDebts();
	
EndProcedure

// Procedure - OnStartEdit of list FilteredDebts event handler.
//
&AtClient
Procedure FilteredDebtsOnStartEdit(Item, NewRow, Copy)
	
	If Copy Then
		CalculateAmountTotal();
		FillDebts();
	EndIf;
	
EndProcedure

// Procedure is filling the payment details.
//
&AtServer
Procedure FillPaymentDetails()
	
	// Filling default payment details.
	Query = New Query;
	Query.Text =
	
	"SELECT ALLOWED
	|	AccountsPayableBalances.Company AS Company,
	|	AccountsPayableBalances.Contract AS Contract,
	|	CounterpartyContracts.CashFlowItem AS Item,
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.SettlementsType AS SettlementsType,
	|	SUM(AccountsPayableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsPayableBalances.AmountCurBalance) AS AmountCurBalance,
	|	AccountsPayableBalances.Document.Date AS DocumentDate,
	|	SUM(CAST(AccountsPayableBalances.AmountCurBalance * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN ExchangeRateOfDocument.Rate * SettlementsExchangeRate.Repetition / (SettlementsExchangeRate.Rate * ExchangeRateOfDocument.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SettlementsExchangeRate.Rate * ExchangeRateOfDocument.Repetition / (ExchangeRateOfDocument.Rate * SettlementsExchangeRate.Repetition)
	|			END AS NUMBER(15, 2))) AS AmountCurrDocument,
	|	ExchangeRateOfDocument.Rate AS CashAssetsRate,
	|	ExchangeRateOfDocument.Repetition AS CashMultiplicity,
	|	SettlementsExchangeRate.Rate AS ExchangeRate,
	|	SettlementsExchangeRate.Repetition AS Multiplicity
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.Company AS Company,
	|		AccountsPayableBalances.Contract AS Contract,
	|		AccountsPayableBalances.Document AS Document,
	|		AccountsPayableBalances.Order AS Order,
	|		AccountsPayableBalances.SettlementsType AS SettlementsType,
	|		ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AmountBalance,
	|		ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsPayable.Balance(
	|				,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND &TextOfContractSelection
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsVendorSettlements.Company,
	|		DocumentRegisterRecordsVendorSettlements.Contract,
	|		DocumentRegisterRecordsVendorSettlements.Document,
	|		DocumentRegisterRecordsVendorSettlements.Order,
	|		DocumentRegisterRecordsVendorSettlements.SettlementsType,
	|		CASE
	|			WHEN DocumentRegisterRecordsVendorSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsVendorSettlements.Amount, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsVendorSettlements.Amount, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsVendorSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsVendorSettlements.AmountCur, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsVendorSettlements.AmountCur, 0)
	|		END
	|	FROM
	|		AccumulationRegister.AccountsPayable AS DocumentRegisterRecordsVendorSettlements
	|	WHERE
	|		DocumentRegisterRecordsVendorSettlements.Recorder = &Ref
	|		AND DocumentRegisterRecordsVendorSettlements.Period <= &Period
	|		AND DocumentRegisterRecordsVendorSettlements.Company = &Company
	|		AND DocumentRegisterRecordsVendorSettlements.Counterparty = &Counterparty
	|		AND DocumentRegisterRecordsVendorSettlements.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalances
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Period, Currency = &Currency AND Company = &Company) AS ExchangeRateOfDocument
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Period, Company = &Company) AS SettlementsExchangeRate
	|		ON AccountsPayableBalances.Contract.SettlementsCurrency = SettlementsExchangeRate.Currency
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON AccountsPayableBalances.Contract = CounterpartyContracts.Ref
	|WHERE
	|	AccountsPayableBalances.AmountCurBalance > 0
	|
	|GROUP BY
	|	AccountsPayableBalances.Company,
	|	AccountsPayableBalances.Contract,
	|	CounterpartyContracts.CashFlowItem,
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.SettlementsType,
	|	AccountsPayableBalances.Document.Date,
	|	ExchangeRateOfDocument.Rate,
	|	ExchangeRateOfDocument.Repetition,
	|	SettlementsExchangeRate.Rate,
	|	SettlementsExchangeRate.Repetition
	|
	|ORDER BY
	|	DocumentDate";
		
	Query.SetParameter("Company", 				ParentCompany);
	Query.SetParameter("Counterparty", 			Counterparty);
	Query.SetParameter("Period", 				Period);
	Query.SetParameter("Currency", 				CashCurrency);
	Query.SetParameter("Ref", 					Ref);
	Query.SetParameter("ExchangeRateMethod",	DriveServer.GetExchangeMethod(ParentCompany));
	
	NeedFilterByContracts = DriveReUse.CounterpartyContractsControlNeeded();
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Ref, OperationKind);
	If Counterparty.DoOperationsByContracts And NeedFilterByContracts Then
		Query.Text = StrReplace(Query.Text, "&TextOfContractSelection", "Contract.ContractKind IN (&ContractTypesList)");
		Query.SetParameter("ContractTypesList", ContractTypesList);
	Else
		Query.Text = StrReplace(Query.Text, "&TextOfContractSelection", "TRUE");
	EndIf;
	
	ContractByDefault = Catalogs.CounterpartyContracts.GetDefaultContractByCompanyContractKind(
		Counterparty,
		ParentCompany,
		ContractTypesList);
	
	StructureContractCurrencyRateByDefault = CurrencyRateOperations.GetCurrencyRate(Period, ContractByDefault.SettlementsCurrency, ParentCompany);
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	FilteredDebts.Clear();
	
	AmountLeftToDistribute = DocumentAmount;
	
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Period, CashCurrency, ParentCompany);
	
	ExchangeRate = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Rate
	);
	Multiplicity = ?(
		StructureByCurrency.Rate = 0,
		1,
		StructureByCurrency.Repetition
	);
	
	ExchangeRateMethod = DriveServer.GetExchangeMethod(ParentCompany);
	
	While AmountLeftToDistribute > 0 Do
		
		NewRow = FilteredDebts.Add();
		
		If SelectionOfQueryResult.Next() Then
			
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			
			If SelectionOfQueryResult.AmountCurrDocument <= AmountLeftToDistribute Then // balance amount is less or equal than it is necessary to distribute
				
				NewRow.SettlementsAmount = SelectionOfQueryResult.AmountCurBalance;
				AmountLeftToDistribute = AmountLeftToDistribute - SelectionOfQueryResult.AmountCurrDocument;
				
			Else // Balance amount is greater than it is necessary to distribute
				
				NewRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
					AmountLeftToDistribute,
					ExchangeRateMethod,
					SelectionOfQueryResult.CashAssetsRate,
					SelectionOfQueryResult.ExchangeRate,
					SelectionOfQueryResult.CashMultiplicity,
					SelectionOfQueryResult.Multiplicity
				);
				AmountLeftToDistribute = 0;
				
			EndIf;
			
		Else
			
			NewRow.Contract = ContractByDefault;
			NewRow.ExchangeRate = ?(
				StructureContractCurrencyRateByDefault.Rate = 0,
				1,
				StructureContractCurrencyRateByDefault.Rate
			);
			NewRow.Multiplicity = ?(
				StructureContractCurrencyRateByDefault.Repetition = 0,
				1,
				StructureContractCurrencyRateByDefault.Repetition
			);
			NewRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
				AmountLeftToDistribute,
				ExchangeRateMethod,
				ExchangeRate,
				NewRow.ExchangeRate,
				Multiplicity,
				NewRow.Multiplicity
			);
			NewRow.AdvanceFlag = True;
			AmountLeftToDistribute = 0;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure - Handler of clicking the FillAutomatically button.
//
&AtClient
Procedure FillAutomatically(Command)
	
	FillPaymentDetails();
	CalculateAmountTotal();
	FillDebts();
	
EndProcedure

// Procedure fills the debt list.
//
&AtServer
Procedure FillDebts()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	FilteredDebts.Contract AS Contract,
	|	FilteredDebts.Document AS Document,
	|	CASE
	|		WHEN FilteredDebts.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|				OR FilteredDebts.Order = VALUE(Document.SubcontractorOrderIssued.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE FilteredDebts.Order
	|	END AS Order,
	|	FilteredDebts.SettlementsAmount AS SettlementsAmount
	|INTO TableFilteredDebts
	|FROM
	|	&TableFilteredDebts AS FilteredDebts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsPayableBalances.Company AS Company,
	|	AccountsPayableBalances.Contract AS Contract,
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.AmountCurBalance AS AmountCurBalance
	|INTO AccountsPayableTable
	|FROM
	|	AccumulationRegister.AccountsPayable.Balance(
	|			,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalances
	|
	|UNION ALL
	|
	|SELECT
	|	&Company,
	|	FilteredDebts.Contract,
	|	FilteredDebts.Document,
	|	FilteredDebts.Order,
	|	-FilteredDebts.SettlementsAmount
	|FROM
	|	TableFilteredDebts AS FilteredDebts
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentRegisterRecordsVendorSettlements.Company,
	|	DocumentRegisterRecordsVendorSettlements.Contract,
	|	DocumentRegisterRecordsVendorSettlements.Document,
	|	DocumentRegisterRecordsVendorSettlements.Order,
	|	CASE
	|		WHEN DocumentRegisterRecordsVendorSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -DocumentRegisterRecordsVendorSettlements.AmountCur
	|		ELSE DocumentRegisterRecordsVendorSettlements.AmountCur
	|	END
	|FROM
	|	AccumulationRegister.AccountsPayable AS DocumentRegisterRecordsVendorSettlements
	|WHERE
	|	DocumentRegisterRecordsVendorSettlements.Recorder = &Ref
	|	AND DocumentRegisterRecordsVendorSettlements.Period <= &Period
	|	AND DocumentRegisterRecordsVendorSettlements.Company = &Company
	|	AND DocumentRegisterRecordsVendorSettlements.Counterparty = &Counterparty
	|	AND DocumentRegisterRecordsVendorSettlements.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AccountsPayableTable.Document AS Document
	|INTO DocumentTable
	|FROM
	|	AccountsPayableTable AS AccountsPayableTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	TRUE AS ExistsEPD,
	|	SupplierInvoiceEarlyPaymentDiscounts.Ref AS SupplierInvoice
	|INTO EarlyPaymentDiscountsExist
	|FROM
	|	Document.SupplierInvoice.EarlyPaymentDiscounts AS SupplierInvoiceEarlyPaymentDiscounts
	|		INNER JOIN DocumentTable AS DocumentTable
	|		ON SupplierInvoiceEarlyPaymentDiscounts.Ref = DocumentTable.Document
	|WHERE
	|	ENDOFPERIOD(SupplierInvoiceEarlyPaymentDiscounts.DueDate, DAY) >= &Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	AccountingJournalEntries.Recorder AS Recorder,
	|	AccountingJournalEntries.Period AS Period
	|INTO EntriesRecorderPeriod
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS AccountingJournalEntries
	|		INNER JOIN DocumentTable AS DocumentTable
	|		ON AccountingJournalEntries.Recorder = DocumentTable.Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsPayableTable.Company AS Company,
	|	AccountsPayableTable.Contract AS Contract,
	|	AccountsPayableTable.Document AS Document,
	|	AccountsPayableTable.Order AS Order,
	|	AccountsPayableTable.AmountCurBalance AS AmountCurBalance,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	CounterpartyContracts.CashFlowItem AS Item,
	|	ISNULL(EarlyPaymentDiscountsExist.ExistsEPD, FALSE) AS ExistsEPD,
	|	ISNULL(EntriesRecorderPeriod.Period, DATETIME(1, 1, 1)) AS DocumentDate
	|INTO AccountsPayableContract
	|FROM
	|	AccountsPayableTable AS AccountsPayableTable
	|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON AccountsPayableTable.Contract = CounterpartyContracts.Ref
	|		LEFT JOIN EarlyPaymentDiscountsExist AS EarlyPaymentDiscountsExist
	|		ON AccountsPayableTable.Document = EarlyPaymentDiscountsExist.SupplierInvoice
	|		LEFT JOIN EntriesRecorderPeriod AS EntriesRecorderPeriod
	|		ON AccountsPayableTable.Document = EntriesRecorderPeriod.Recorder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsPayableContract.Company AS Company,
	|	AccountsPayableContract.Contract AS Contract,
	|	AccountsPayableContract.Item AS Item,
	|	AccountsPayableContract.Document AS Document,
	|	AccountsPayableContract.DocumentDate AS DocumentDate,
	|	AccountsPayableContract.Order AS Order,
	|	SUM(AccountsPayableContract.AmountCurBalance) AS SettlementsAmount,
	|	MAX(SettlementsExchangeRate.Rate) AS ExchangeRate,
	|	MAX(SettlementsExchangeRate.Repetition) AS Multiplicity,
	|	AccountsPayableContract.ExistsEPD AS ExistsEPD
	|INTO AccountsPayableGrouped
	|FROM
	|	AccountsPayableContract AS AccountsPayableContract
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Period, Company = &Company) AS SettlementsExchangeRate
	|		ON AccountsPayableContract.SettlementsCurrency = SettlementsExchangeRate.Currency
	|
	|GROUP BY
	|	AccountsPayableContract.Company,
	|	AccountsPayableContract.Contract,
	|	AccountsPayableContract.Item,
	|	AccountsPayableContract.Document,
	|	AccountsPayableContract.DocumentDate,
	|	AccountsPayableContract.Order,
	|	AccountsPayableContract.ExistsEPD
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsPayableGrouped.Company AS Company,
	|	AccountsPayableGrouped.Contract AS Contract,
	|	AccountsPayableGrouped.Item AS Item,
	|	AccountsPayableGrouped.Document AS Document,
	|	AccountsPayableGrouped.DocumentDate AS DocumentDate,
	|	AccountsPayableGrouped.Order AS Order,
	|	AccountsPayableGrouped.SettlementsAmount AS SettlementsAmount,
	|	AccountsPayableGrouped.ExchangeRate AS ExchangeRate,
	|	AccountsPayableGrouped.Multiplicity AS Multiplicity,
	|	AccountsPayableGrouped.ExistsEPD AS ExistsEPD
	|FROM
	|	AccountsPayableGrouped AS AccountsPayableGrouped
	|WHERE
	|	AccountsPayableGrouped.SettlementsAmount > 0
	|
	|ORDER BY
	|	AccountsPayableGrouped.DocumentDate";
	
	Query.SetParameter("Company", ParentCompany);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Period", Period);
	Query.SetParameter("TableFilteredDebts", FilteredDebts.Unload());
	Query.SetParameter("Ref", Ref);
	
	DebtsList.Load(Query.Execute().Unload());
	
EndProcedure

// Procedure - BeforeStartAdding of list FilteredDebts event  handler.
//
&AtClient
Procedure FilteredDebtsBeforeAddingStart(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure
