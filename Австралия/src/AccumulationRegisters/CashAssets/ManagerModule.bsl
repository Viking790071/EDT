#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Procedure creates an empty temporary table of records change.
//
Procedure CreateEmptyTemporaryTableChange(AdditionalProperties) Export
	
	If Not AdditionalProperties.Property("ForPosting")
	 OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then	
		Return;		
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	Query = New Query(
	"SELECT TOP 0
	|	CashAssets.LineNumber AS LineNumber,
	|	CashAssets.Company AS Company,
	|	CashAssets.PresentationCurrency AS PresentationCurrency,
	|	CashAssets.PaymentMethod AS PaymentMethod,
	|	CashAssets.BankAccountPettyCash AS BankAccountPettyCash,
	|	CashAssets.Currency AS Currency,
	|	CashAssets.Amount AS SumBeforeWrite,
	|	CashAssets.Amount AS AmountChange,
	|	CashAssets.Amount AS AmountOnWrite,
	|	CashAssets.AmountCur AS AmountCurBeforeWrite,
	|	CashAssets.AmountCur AS SumCurChange,
	|	CashAssets.AmountCur AS SumCurOnWrite
	|INTO RegisterRecordsCashAssetsChange
	|FROM
	|	AccumulationRegister.CashAssets AS CashAssets");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsCashAssetsChange", False);
	
EndProcedure

Function BalancesControlQueryText(OnlyOverdraft = False) Export
	
	Text =
	"SELECT
	|	RegisterRecordsCashAssetsChange.LineNumber AS LineNumber,
	|	REFPRESENTATION(RegisterRecordsCashAssetsChange.Company) AS CompanyPresentation,
	|	REFPRESENTATION(RegisterRecordsCashAssetsChange.PresentationCurrency) AS PresentationCurrencyPresentation,
	|	REFPRESENTATION(RegisterRecordsCashAssetsChange.BankAccountPettyCash) AS BankAccountCashPresentation,
	|	REFPRESENTATION(RegisterRecordsCashAssetsChange.Currency) AS CurrencyPresentation,
	|	REFPRESENTATION(RegisterRecordsCashAssetsChange.PaymentMethod) AS PaymentMethodRepresentation,
	|	RegisterRecordsCashAssetsChange.PaymentMethod AS PaymentMethod,
	|	ISNULL(CashAssetsBalances.AmountBalance, 0) AS AmountBalance,
	|	ISNULL(CashAssetsBalances.AmountCurBalance, 0) + ISNULL(OverdraftLimitsSliceLast.Limit, 0) AS AmountCurBalance,
	|	RegisterRecordsCashAssetsChange.SumCurChange + ISNULL(CashAssetsBalances.AmountCurBalance, 0) + ISNULL(OverdraftLimitsSliceLast.Limit, 0) AS BalanceCashAssets,
	|	RegisterRecordsCashAssetsChange.SumBeforeWrite AS SumBeforeWrite,
	|	RegisterRecordsCashAssetsChange.AmountOnWrite AS AmountOnWrite,
	|	RegisterRecordsCashAssetsChange.AmountChange AS AmountChange,
	|	RegisterRecordsCashAssetsChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
	|	RegisterRecordsCashAssetsChange.SumCurOnWrite AS SumCurOnWrite,
	|	RegisterRecordsCashAssetsChange.SumCurChange AS SumCurChange
	|FROM
	|	RegisterRecordsCashAssetsChange AS RegisterRecordsCashAssetsChange
	|		LEFT JOIN CashAssetsBalances AS CashAssetsBalances
	|		ON RegisterRecordsCashAssetsChange.Company = CashAssetsBalances.Company
	|			AND RegisterRecordsCashAssetsChange.PresentationCurrency = CashAssetsBalances.PresentationCurrency
	|			AND RegisterRecordsCashAssetsChange.PaymentMethod = CashAssetsBalances.PaymentMethod
	|			AND RegisterRecordsCashAssetsChange.BankAccountPettyCash = CashAssetsBalances.BankAccountPettyCash
	|			AND RegisterRecordsCashAssetsChange.Currency = CashAssetsBalances.Currency
	|		LEFT JOIN Catalog.BankAccounts AS CatalogBankAccounts
	|		ON RegisterRecordsCashAssetsChange.BankAccountPettyCash = CatalogBankAccounts.Ref
	|		LEFT JOIN InformationRegister.OverdraftLimits.SliceLast(
	|				,
	|				&Date >= StartDate
	|					AND (&Date <= EndDate
	|						OR EndDate = DATETIME(1, 1, 1))) AS OverdraftLimitsSliceLast
	|		ON RegisterRecordsCashAssetsChange.BankAccountPettyCash = OverdraftLimitsSliceLast.BankAccount
	|			AND (ISNULL(CatalogBankAccounts.UseOverdraft, FALSE))
	|WHERE
	|	ISNULL(CashAssetsBalances.AmountCurBalance, 0) + ISNULL(OverdraftLimitsSliceLast.Limit, 0) < 0
	|	AND NOT ISNULL(CatalogBankAccounts.AllowNegativeBalance, FALSE)
	|
	|ORDER BY
	|	LineNumber";
	
	If OnlyOverdraft Then
		Text = StrReplace(Text, "LEFT JOIN InformationRegister.OverdraftLimits", "INNER JOIN InformationRegister.OverdraftLimits");
	EndIf;
	
	Return Text;
	
EndFunction

Procedure GenerateTableCashAssetsBalances(StructureTemporaryTables, AdditionalProperties) Export
	
	Query = New Query(
	"SELECT
	|	CashAssetsBalances.Company AS Company,
	|	CashAssetsBalances.PresentationCurrency AS PresentationCurrency,
	|	CashAssetsBalances.PaymentMethod AS PaymentMethod,
	|	CashAssetsBalances.BankAccountPettyCash AS BankAccountPettyCash,
	|	CashAssetsBalances.Currency AS Currency,
	|	CashAssetsBalances.AmountCurBalance AS AmountCurBalance,
	|	CashAssetsBalances.AmountBalance AS AmountBalance
	|INTO CashAssetsBalances
	|FROM
	|	AccumulationRegister.CashAssets.Balance(
	|			&ControlTime,
	|			(Company, PresentationCurrency, PaymentMethod, BankAccountPettyCash, Currency) IN
	|				(SELECT
	|					RegisterRecordsCashAssetsChange.Company AS Company,
	|					RegisterRecordsCashAssetsChange.PresentationCurrency AS PresentationCurrency,
	|					RegisterRecordsCashAssetsChange.PaymentMethod AS PaymentMethod,
	|					RegisterRecordsCashAssetsChange.BankAccountPettyCash AS BankAccountPettyCash,
	|					RegisterRecordsCashAssetsChange.Currency AS Currency
	|				FROM
	|					RegisterRecordsCashAssetsChange AS RegisterRecordsCashAssetsChange)) AS CashAssetsBalances");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
	
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("CashAssetsBalances", False);
	
EndProcedure

// Controls the occurrence of negative balances regardless of value in Constants.CheckStockBalanceOnPosting.
//
Procedure IndependentCashAssetsRunControl(DocumentRef, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables contain records, it is
	// necessary to execute negative balance control.
	If StructureTemporaryTables.RegisterRecordsCashAssetsChange Then
		
		Query = New Query;
		Query.Text = BalancesControlQueryText(True);
		
		GenerateTableCashAssetsBalances(StructureTemporaryTables, AdditionalProperties);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		Query.SetParameter("Date", AdditionalProperties.ForPosting.Date);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty() Then
			DocumentObject = DocumentRef.GetObject();
			
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToCashAssetsRegisterErrors(DocumentObject, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf