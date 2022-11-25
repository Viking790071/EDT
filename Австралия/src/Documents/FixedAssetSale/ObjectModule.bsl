#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure fills advances.
//
Procedure FillPrepayment() Export
	
	ParentCompany = DriveServer.GetCompany(Company);
	ExchangeRateMethod = DriveServer.GetExchangeMethod(ParentCompany);
	
	// Filling prepayment details.
	Query = New Query;
	
	QueryText =
	"SELECT ALLOWED
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.DocumentDate AS DocumentDate,
	|	AccountsReceivableBalances.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	SUM(AccountsReceivableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsReceivableBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableAccountsReceivableBalances
	|FROM
	|	(SELECT
	|		AccountsReceivableBalances.Contract AS Contract,
	|		AccountsReceivableBalances.Document AS Document,
	|		AccountsReceivableBalances.Document.Date AS DocumentDate,
	|		AccountsReceivableBalances.Order AS Order,
	|		AccountsReceivableBalances.AmountBalance AS AmountBalance,
	|		AccountsReceivableBalances.AmountCurBalance AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsReceivable.Balance(
	|				&Period,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND Contract = &Contract
	|					AND Order = &Order
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsReceivableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsAccountsReceivable.Contract,
	|		DocumentRegisterRecordsAccountsReceivable.Document,
	|		DocumentRegisterRecordsAccountsReceivable.Document.Date,
	|		DocumentRegisterRecordsAccountsReceivable.Order,
	|		CASE
	|			WHEN DocumentRegisterRecordsAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -DocumentRegisterRecordsAccountsReceivable.Amount
	|			ELSE DocumentRegisterRecordsAccountsReceivable.Amount
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -DocumentRegisterRecordsAccountsReceivable.AmountCur
	|			ELSE DocumentRegisterRecordsAccountsReceivable.AmountCur
	|		END
	|	FROM
	|		AccumulationRegister.AccountsReceivable AS DocumentRegisterRecordsAccountsReceivable
	|	WHERE
	|		DocumentRegisterRecordsAccountsReceivable.Recorder = &Ref
	|		AND DocumentRegisterRecordsAccountsReceivable.Company = &Company
	|		AND DocumentRegisterRecordsAccountsReceivable.Counterparty = &Counterparty
	|		AND DocumentRegisterRecordsAccountsReceivable.Contract = &Contract
	|		AND DocumentRegisterRecordsAccountsReceivable.Order = &Order
	|		AND DocumentRegisterRecordsAccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsReceivableBalances
	|
	|GROUP BY
	|	AccountsReceivableBalances.Document,
	|	AccountsReceivableBalances.Order,
	|	AccountsReceivableBalances.DocumentDate,
	|	AccountsReceivableBalances.Contract.SettlementsCurrency
	|
	|HAVING
	|	SUM(AccountsReceivableBalances.AmountCurBalance) < 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.DocumentDate AS DocumentDate,
	|	AccountsReceivableBalances.SettlementsCurrency AS SettlementsCurrency,
	|	-SUM(AccountsReceivableBalances.AmountCurBalance) AS SettlementsAmount,
	|	-SUM(AccountsReceivableBalances.AmountBalance) AS PaymentAmount,
	|	CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN CASE
	|					WHEN SUM(AccountsReceivableBalances.AmountBalance) <> 0
	|						THEN SUM(AccountsReceivableBalances.AmountCurBalance) / SUM(AccountsReceivableBalances.AmountBalance)
	|					ELSE 1
	|				END
	|		ELSE CASE
	|				WHEN SUM(AccountsReceivableBalances.AmountCurBalance) <> 0
	|					THEN SUM(AccountsReceivableBalances.AmountBalance) / SUM(AccountsReceivableBalances.AmountCurBalance)
	|				ELSE 1
	|			END
	|	END AS ExchangeRate,
	|	1 AS Multiplicity
	|FROM
	|	TemporaryTableAccountsReceivableBalances AS AccountsReceivableBalances
	|
	|GROUP BY
	|	AccountsReceivableBalances.Document,
	|	AccountsReceivableBalances.Order,
	|	AccountsReceivableBalances.DocumentDate,
	|	AccountsReceivableBalances.SettlementsCurrency
	|
	|HAVING
	|	SUM(AccountsReceivableBalances.AmountCurBalance) < 0
	|
	|ORDER BY
	|	DocumentDate";
	
	Query.SetParameter("Order", Undefined);
	
	Query.SetParameter("Company", ParentCompany);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Contract", Contract);
	Query.SetParameter("Period", EndOfDay(Date) + 1);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("ExchangeRateMethod", ExchangeRateMethod);
	
	Query.Text = QueryText;
	
	Prepayment.Clear();
	AmountLeftToDistribute = FixedAssets.Total("Total");
	AmountLeftToDistribute = DriveServer.RecalculateFromCurrencyToCurrency(
		AmountLeftToDistribute,
		ExchangeRateMethod,
		ExchangeRate,
		ContractCurrencyExchangeRate,
		Multiplicity,
		ContractCurrencyMultiplicity);
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	While AmountLeftToDistribute > 0 Do
		
		If SelectionOfQueryResult.Next() Then
			
			If SelectionOfQueryResult.SettlementsAmount <= AmountLeftToDistribute Then // balance amount is less or equal than it is necessary to distribute
				
				NewRow = Prepayment.Add();
				FillPropertyValues(NewRow, SelectionOfQueryResult);
				AmountLeftToDistribute = AmountLeftToDistribute - SelectionOfQueryResult.SettlementsAmount;
				
			Else // Balance amount is greater than it is necessary to distribute
				
				NewRow = Prepayment.Add();
				FillPropertyValues(NewRow, SelectionOfQueryResult);
				NewRow.SettlementsAmount = AmountLeftToDistribute;
				NewRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
					NewRow.SettlementsAmount,
					ExchangeRateMethod,
					SelectionOfQueryResult.ExchangeRate,
					1,
					SelectionOfQueryResult.Multiplicity,
					1);
				AmountLeftToDistribute = 0;
				
			EndIf;
			
			NewRow.AmountDocCur = DriveServer.RecalculateFromCurrencyToCurrency(
				NewRow.SettlementsAmount,
				ExchangeRateMethod,
				ContractCurrencyExchangeRate,
				ExchangeRate,
				ContractCurrencyMultiplicity,
				Multiplicity);
			
		Else
			
			AmountLeftToDistribute = 0;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Executes preliminary control.
//
Procedure RunPreliminaryControl(Cancel)
	
	// Row duplicates.
	Query = New Query();
	
	Query.Text = 
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.FixedAsset
	|INTO DocumentTable
	|FROM
	|	&DocumentTable AS DocumentTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(TableOfDocument1.LineNumber) AS LineNumber,
	|	TableOfDocument1.FixedAsset
	|FROM
	|	DocumentTable AS TableOfDocument1
	|		INNER JOIN DocumentTable AS TableOfDocument2
	|		ON TableOfDocument1.LineNumber <> TableOfDocument2.LineNumber
	|			AND TableOfDocument1.FixedAsset = TableOfDocument2.FixedAsset
	|
	|GROUP BY
	|	TableOfDocument1.FixedAsset
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("DocumentTable", FixedAssets);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		QueryResultSelection = QueryResult.Select();
		While QueryResultSelection.Next() Do
			MessageText = NStr("en = '""%FixedAsset%"" presented in line %LineNumber% the ""Fixed assets"" list is dublicated.'; ru = '""%FixedAsset%"", указанный в строке %LineNumber% списка ""Основные средства"", указан повторно.';pl = '""%FixedAsset%"" przedstawiony w wierszu %LineNumber% listy ""Środki trwałe"" jest zduplikowany.';es_ES = '""%FixedAsset%"" presentado en la línea %LineNumber% de la lista de ""Activos fijos"" está duplicado.';es_CO = '""%FixedAsset%"" presentado en la línea %LineNumber% de la lista de ""Activos fijos"" está duplicado.';tr = '""Sabit kıymetler"" listesinde %LineNumber% satırında gösterilen ""%FixedAsset%"" kopyalanır.';it = '""%FixedAsset%"" presente nella linea %LineNumber% l''elenco ""Cespiti"" è duplicato.';de = 'In Zeile %LineNumber% dargestellte %FixedAsset% wird die Liste ""Anlagevermögen"" dupliziert.'");
			MessageText = StrReplace(MessageText, "%LineNumber%", QueryResultSelection.LineNumber);
			MessageText = StrReplace(MessageText, "%FixedAsset%", QueryResultSelection.FixedAsset);
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"FixedAssets",
				QueryResultSelection.LineNumber,
				"FixedAsset",
				Cancel
			);

		EndDo;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("FixedAssetsList", FixedAssets.UnloadColumn("FixedAsset"));
	
	// Check property states.
	Query.Text =
	"SELECT ALLOWED
	|	FixedAssetStateSliceLast.FixedAsset AS FixedAsset
	|FROM
	|	InformationRegister.FixedAssetStatus.SliceLast(, Company = &Company) AS FixedAssetStateSliceLast
	|;
	|	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	NestedSelect.FixedAsset AS FixedAsset
	|FROM
	|	(SELECT
	|		FixedAssetState.FixedAsset AS FixedAsset,
	|		SUM(CASE
	|				WHEN FixedAssetState.State = VALUE(Enum.FixedAssetStatus.AcceptedForAccounting)
	|					THEN 1
	|				ELSE -1
	|			END) AS CurrentState
	|	FROM
	|		InformationRegister.FixedAssetStatus AS FixedAssetState
	|	WHERE
	|		FixedAssetState.Recorder <> &Ref
	|		AND FixedAssetState.Company = &Company
	|		AND FixedAssetState.FixedAsset IN(&FixedAssetsList)
	|	
	|	GROUP BY
	|		FixedAssetState.FixedAsset) AS NestedSelect
	|WHERE
	|	NestedSelect.CurrentState > 0";
	
	ResultsArray = Query.ExecuteBatch();
	
	ArrayVAStatus = ResultsArray[0].Unload().UnloadColumn("FixedAsset");
	ArrayVAAcceptedForAccounting = ResultsArray[1].Unload().UnloadColumn("FixedAsset");
	
	For Each RowOfFixedAssets In FixedAssets Do
		
		If ArrayVAStatus.Find(RowOfFixedAssets.FixedAsset) = Undefined Then
			MessageText = NStr("en = 'Status is not specified for %FixedAsset%, line %LineNumber% of the ""Fixed assets"" list.'; ru = 'Не указан статус для ""%FixedAsset%"", строка %LineNumber% списка ""Основные средства"".';pl = 'Nie określono statusu dla %FixedAsset%, wiersz %LineNumber% listy ""Środki trwałe"".';es_ES = 'Estado no está especificado para %FixedAsset%, línea %LineNumber% de la lista de ""Activos fijos"".';es_CO = 'Estado no está especificado para %FixedAsset%, línea %LineNumber% de la lista de ""Activos fijos"".';tr = 'Durum ""Sabit kıymetler"" listesinin %LineNumber% satırındaki %FixedAsset% için belirtilmemiştir.';it = 'Lo stato non è specificato per %FixedAsset%, linea %LineNumber% dell''elenco ""Cespiti"".';de = 'Der Status ist für %FixedAsset%, Zeile %LineNumber% der Liste ""Anlagevermögen"" nicht angegeben.'");
			MessageText = StrReplace(MessageText, "%FixedAsset%", TrimAll(String(RowOfFixedAssets.FixedAsset))); 
			MessageText = StrReplace(MessageText, "%LineNumber%",String(RowOfFixedAssets.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"FixedAssets",
				RowOfFixedAssets.LineNumber,
				"FixedAsset",
				Cancel
			);
		ElsIf ArrayVAAcceptedForAccounting.Find(RowOfFixedAssets.FixedAsset) = Undefined Then
			MessageText = NStr("en = 'The current status of %FixedAsset%, line %LineNumber% of the ""Fixed assets"" list, is ""Not recognized"".'; ru = 'Текущий статус ""%FixedAsset%"", строка %LineNumber% списка ""Основные средства"",  ""Не поставлен на учет"".';pl = 'Bieżący status środka trwałego %FixedAsset%, wiersz %LineNumber% listy ""Środki trwałe"" to ""Nieprzyjęty"".';es_ES = 'El estado actual de %FixedAsset%, línea %LineNumber% de la lista de ""Activos fijos"" es ""No reconocido"".';es_CO = 'El estado actual de %FixedAsset%, línea %LineNumber% de la lista de ""Activos fijos"" es ""No reconocido"".';tr = '""Sabit kıymetler"" listesinin %LineNumber% satırındaki %FixedAsset% o an ki durumu ""Tanınmadı"" şeklindedir.';it = 'Lo stato corrente di %FixedAsset%, linea %LineNumber% dell''elento ""Cespiti"", è ""Non riconosciuto"".';de = 'Der aktuelle Status von %FixedAsset%, Zeile %LineNumber% der Liste ""Anlagevermögen"", lautet ""Nicht erkannt"".'");
			MessageText = StrReplace(MessageText, "%FixedAsset%", TrimAll(String(RowOfFixedAssets.FixedAsset))); 
			MessageText = StrReplace(MessageText, "%LineNumber%",String(RowOfFixedAssets.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"FixedAssets",
				RowOfFixedAssets.LineNumber,
				"FixedAsset",
				Cancel
			);
		EndIf;
		
	EndDo;
	
EndProcedure

// Calculates the assets depreciation.
//
Procedure CalculateDepreciation(FixedAsset)
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	FixedAssetParametersSliceLast.Recorder.Company AS Company
	|FROM
	|	InformationRegister.FixedAssetParameters.SliceLast AS FixedAssetParametersSliceLast
	|WHERE
	|	FixedAssetParametersSliceLast.FixedAsset = &FixedAsset";
	
	Query.SetParameter("FixedAsset", FixedAsset);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Company = Selection.Company;
	EndIf;
	
	Query.Text =
	"SELECT ALLOWED
	|	ListOfAmortizableFA.FixedAsset AS FixedAsset,
	|	PRESENTATION(ListOfAmortizableFA.FixedAsset) AS FixedAssetPresentation,
	|	ListOfAmortizableFA.FixedAsset.Code AS Code,
	|	ListOfAmortizableFA.BeginAccrueDepriciation AS BeginAccrueDepriciation,
	|	ListOfAmortizableFA.EndAccrueDepriciation AS EndAccrueDepriciation,
	|	ListOfAmortizableFA.EndAccrueDepreciationInCurrentMonth AS EndAccrueDepreciationInCurrentMonth,
	|	ISNULL(FACost.DepreciationClosingBalance, 0) AS DepreciationClosingBalance,
	|	ISNULL(FACost.DepreciationTurnover, 0) AS DepreciationTurnover,
	|	ISNULL(FACost.CostClosingBalance, 0) AS BalanceCost,
	|	ISNULL(FACost.CostOpeningBalance, 0) AS CostOpeningBalance,
	|	ISNULL(DepreciationBalancesAndTurnovers.CostOpeningBalance, 0) - ISNULL(DepreciationBalancesAndTurnovers.DepreciationOpeningBalance, 0) AS CostAtBegOfYear,
	|	ISNULL(ListOfAmortizableFA.FixedAsset.DepreciationMethod, 0) AS DepreciationMethod,
	|	ISNULL(ListOfAmortizableFA.FixedAsset.InitialCost, 0) AS OriginalCost,
	|	ISNULL(DepreciationParametersSliceLast.ApplyInCurrentMonth, 0) AS ApplyInCurrentMonth,
	|	DepreciationParametersSliceLast.Period AS Period,
	|	CASE
	|		WHEN DepreciationParametersSliceLast.ApplyInCurrentMonth
	|			THEN ISNULL(DepreciationParametersSliceLast.UsagePeriodForDepreciationCalculation, 0)
	|		ELSE ISNULL(DepreciationParametersSliceLastBegOfMonth.UsagePeriodForDepreciationCalculation, 0)
	|	END AS UsagePeriodForDepreciationCalculation,
	|	CASE
	|		WHEN DepreciationParametersSliceLast.ApplyInCurrentMonth
	|			THEN ISNULL(DepreciationParametersSliceLast.CostForDepreciationCalculation, 0)
	|		ELSE ISNULL(DepreciationParametersSliceLastBegOfMonth.CostForDepreciationCalculation, 0)
	|	END AS CostForDepreciationCalculation,
	|	ISNULL(DepreciationSignChange.UpdateAmortAccrued, FALSE) AS UpdateAmortAccrued,
	|	ISNULL(DepreciationSignChange.AccrueInCurMonth, FALSE) AS AccrueInCurMonth,
	|	ISNULL(FixedAssetOutputTurnovers.QuantityTurnover, 0) AS OutputVolume,
	|	CASE
	|		WHEN DepreciationParametersSliceLast.ApplyInCurrentMonth
	|			THEN ISNULL(DepreciationParametersSliceLast.AmountOfProductsServicesForDepreciationCalculation, 0)
	|		ELSE ISNULL(DepreciationParametersSliceLastBegOfMonth.AmountOfProductsServicesForDepreciationCalculation, 0)
	|	END AS AmountOfProductsServicesForDepreciationCalculation
	|INTO TemporaryTableForDepreciationCalculation
	|FROM
	|	(SELECT
	|		SliceFirst.AccrueDepreciation AS BeginAccrueDepriciation,
	|		SliceLast.AccrueDepreciation AS EndAccrueDepriciation,
	|		SliceLast.AccrueDepreciationInCurrentMonth AS EndAccrueDepreciationInCurrentMonth,
	|		SliceLast.FixedAsset AS FixedAsset
	|	FROM
	|		(SELECT
	|			FixedAssetStateSliceFirst.FixedAsset AS FixedAsset,
	|			FixedAssetStateSliceFirst.AccrueDepreciation AS AccrueDepreciation,
	|			FixedAssetStateSliceFirst.AccrueDepreciationInCurrentMonth AS AccrueDepreciationInCurrentMonth,
	|			FixedAssetStateSliceFirst.Period AS Period
	|		FROM
	|			InformationRegister.FixedAssetStatus.SliceLast(
	|					&BeginOfPeriod,
	|					Company = &Company
	|						AND FixedAsset IN (&FixedAssetsList)) AS FixedAssetStateSliceFirst) AS SliceFirst
	|			Full JOIN (SELECT
	|				FixedAssetStateSliceLast.FixedAsset AS FixedAsset,
	|				FixedAssetStateSliceLast.AccrueDepreciation AS AccrueDepreciation,
	|				FixedAssetStateSliceLast.AccrueDepreciationInCurrentMonth AS AccrueDepreciationInCurrentMonth,
	|				FixedAssetStateSliceLast.Period AS Period
	|			FROM
	|				InformationRegister.FixedAssetStatus.SliceLast(
	|						&EndOfPeriod,
	|						Company = &Company
	|							AND FixedAsset IN (&FixedAssetsList)) AS FixedAssetStateSliceLast) AS SliceLast
	|			ON SliceFirst.FixedAsset = SliceLast.FixedAsset) AS ListOfAmortizableFA
	|		LEFT JOIN AccumulationRegister.FixedAssets.BalanceAndTurnovers(
	|				&BegOfYear,
	|				,
	|				,
	|				,
	|				Company = &Company
	|					AND FixedAsset IN (&FixedAssetsList)) AS DepreciationBalancesAndTurnovers
	|		ON ListOfAmortizableFA.FixedAsset = DepreciationBalancesAndTurnovers.FixedAsset
	|		LEFT JOIN AccumulationRegister.FixedAssets.BalanceAndTurnovers(
	|				&BeginOfPeriod,
	|				&EndOfPeriod,
	|				,
	|				,
	|				Company = &Company
	|					AND FixedAsset IN (&FixedAssetsList)) AS FACost
	|		ON ListOfAmortizableFA.FixedAsset = FACost.FixedAsset
	|		LEFT JOIN InformationRegister.FixedAssetParameters.SliceLast(
	|				&EndOfPeriod,
	|				Company = &Company
	|					AND FixedAsset IN (&FixedAssetsList)) AS DepreciationParametersSliceLast
	|		ON ListOfAmortizableFA.FixedAsset = DepreciationParametersSliceLast.FixedAsset
	|		LEFT JOIN InformationRegister.FixedAssetParameters.SliceLast(
	|				&BeginOfPeriod,
	|				Company = &Company
	|					AND FixedAsset IN (&FixedAssetsList)) AS DepreciationParametersSliceLastBegOfMonth
	|		ON ListOfAmortizableFA.FixedAsset = DepreciationParametersSliceLastBegOfMonth.FixedAsset
	|		LEFT JOIN (SELECT
	|			COUNT(DISTINCT TRUE) AS UpdateAmortAccrued,
	|			FixedAssetState.FixedAsset AS FixedAsset,
	|			FixedAssetStateSliceLast.AccrueDepreciationInCurrentMonth AS AccrueInCurMonth
	|		FROM
	|			InformationRegister.FixedAssetStatus AS FixedAssetState
	|				INNER JOIN InformationRegister.FixedAssetStatus.SliceLast(
	|						&EndOfPeriod,
	|						Company = &Company
	|							AND FixedAsset IN (&FixedAssetsList)) AS FixedAssetStateSliceLast
	|				ON FixedAssetState.FixedAsset = FixedAssetStateSliceLast.FixedAsset
	|		WHERE
	|			FixedAssetState.Period between &BeginOfPeriod AND &EndOfPeriod
	|			AND FixedAssetState.Company = &Company
	|			AND FixedAssetState.FixedAsset IN(&FixedAssetsList)
	|		
	|		GROUP BY
	|			FixedAssetState.FixedAsset,
	|			FixedAssetStateSliceLast.AccrueDepreciationInCurrentMonth) AS DepreciationSignChange
	|		ON ListOfAmortizableFA.FixedAsset = DepreciationSignChange.FixedAsset
	|		LEFT JOIN AccumulationRegister.FixedAssetUsage.Turnovers(
	|				&BeginOfPeriod,
	|				&EndOfPeriod,
	|				,
	|				Company = &Company
	|					AND FixedAsset IN (&FixedAssetsList)) AS FixedAssetOutputTurnovers
	|		ON ListOfAmortizableFA.FixedAsset = FixedAssetOutputTurnovers.FixedAsset
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company AS Company,
	|	&Period AS Period,
	|	Table.FixedAsset AS FixedAsset,
	|	Table.FixedAssetPresentation AS FixedAssetPresentation,
	|	Table.Code AS Code,
	|	Table.DepreciationClosingBalance AS DepreciationClosingBalance,
	|	Table.BalanceCost AS BalanceCost,
	|	0 AS Cost,
	|	CASE
	|		WHEN CASE
	|				WHEN Table.DepreciationAmount < Table.TotalLeftToWriteOff
	|					THEN Table.DepreciationAmount
	|				ELSE Table.TotalLeftToWriteOff
	|			END > 0
	|			THEN CASE
	|					WHEN Table.DepreciationAmount < Table.TotalLeftToWriteOff
	|						THEN Table.DepreciationAmount
	|					ELSE Table.TotalLeftToWriteOff
	|				END
	|		ELSE 0
	|	END AS Depreciation
	|INTO TableDepreciationCalculation
	|FROM
	|	(SELECT
	|		CASE
	|			WHEN Table.DepreciationMethod = VALUE(Enum.FixedAssetDepreciationMethods.Linear)
	|				THEN Table.CostForDepreciationCalculation / CASE
	|						WHEN Table.UsagePeriodForDepreciationCalculation = 0
	|							THEN 1
	|						ELSE Table.UsagePeriodForDepreciationCalculation
	|					END
	|			WHEN Table.DepreciationMethod = VALUE(Enum.FixedAssetDepreciationMethods.ProportionallyToProductsVolume)
	|				THEN Table.CostForDepreciationCalculation * Table.OutputVolume / CASE
	|						WHEN Table.AmountOfProductsServicesForDepreciationCalculation = 0
	|							THEN 1
	|						ELSE Table.AmountOfProductsServicesForDepreciationCalculation
	|					END
	|			ELSE 0
	|		END AS DepreciationAmount,
	|		Table.FixedAsset AS FixedAsset,
	|		Table.FixedAssetPresentation AS FixedAssetPresentation,
	|		Table.Code AS Code,
	|		Table.DepreciationClosingBalance AS DepreciationClosingBalance,
	|		Table.BalanceCost AS BalanceCost,
	|		Table.BalanceCost - Table.DepreciationClosingBalance AS TotalLeftToWriteOff
	|	FROM
	|		TemporaryTableForDepreciationCalculation AS Table) AS Table
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTableForDepreciationCalculation
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableFixedAssets.LineNumber AS LineNumber,
	|	TableFixedAssets.FixedAsset AS FixedAsset,
	|	TableFixedAssets.Amount AS Amount,
	|	TableFixedAssets.VATRate AS VATRate,
	|	TableFixedAssets.VATAmount AS VATAmount,
	|	TableFixedAssets.Total AS Total
	|INTO TableFixedAssets
	|FROM
	|	&TableFixedAssets AS TableFixedAssets
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableFixedAssets.LineNumber AS LineNumber,
	|	TableFixedAssets.FixedAsset AS FixedAsset,
	|	TableFixedAssets.Amount AS Amount,
	|	TableFixedAssets.VATRate AS VATRate,
	|	TableFixedAssets.VATAmount AS VATAmount,
	|	TableFixedAssets.Total AS Total,
	|	TableDepreciationCalculation.BalanceCost AS Cost,
	|	TableDepreciationCalculation.Depreciation AS MonthlyDepreciation,
	|	TableDepreciationCalculation.DepreciationClosingBalance AS Depreciation,
	|	TableDepreciationCalculation.BalanceCost - TableDepreciationCalculation.DepreciationClosingBalance AS DepreciatedCost
	|FROM
	|	TableFixedAssets AS TableFixedAssets
	|		LEFT JOIN TableDepreciationCalculation AS TableDepreciationCalculation
	|		ON TableFixedAssets.FixedAsset = TableDepreciationCalculation.FixedAsset
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TableFixedAssets
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TableDepreciationCalculation";
	
	CurDate = CurrentSessionDate();
	
	Query.SetParameter("Period", CurDate);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("BegOfYear", BegOfYear(CurDate));
	Query.SetParameter("BeginOfPeriod", BegOfMonth(CurDate));
	Query.SetParameter("EndOfPeriod", EndOfMonth(CurDate));
	Query.SetParameter("FixedAssetsList", FixedAssets.UnloadColumn("FixedAsset"));
	Query.SetParameter("TableFixedAssets", FixedAssets);
	
	QueryResult = Query.ExecuteBatch();
	
	DepreciationTable = QueryResult[4].Unload();
	
	FixedAssets.Load(DepreciationTable);
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByFixedAssets(FillingData)
	
	NewRow = FixedAssets.Add();
	
	NewRow.FixedAsset = FillingData;
	
	CalculateDepreciation(FillingData);
	
EndProcedure

#EndRegion

#Region EventsHandlers

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("CatalogRef.FixedAssets") Then
		FillByFixedAssets(FillingData);
	EndIf;
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData);
	
	// to be removed on VAT review, also check OnCreateAtServer()
	VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT;
	
	WorkWithVAT.ForbidReverseChargeTaxationTypeDocumentGeneration(ThisObject);
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If ForOpeningBalancesOnly Then
		CheckedAttributes.Clear();
		Return;
	EndIf;
	
	// Preliminary control execution.
	RunPreliminaryControl(Cancel);

	FixedAssetsTotal = FixedAssets.Total("Total");
	SettlementsEvaluationTotal = Prepayment.Total("PaymentAmount");
	
	If Not Counterparty.DoOperationsByContracts Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ValueIsFilled(Counterparty)
	AND Not Counterparty.DoOperationsByContracts
	AND Not ValueIsFilled(Contract) Then
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
	DocumentAmount = FixedAssets.Total("Total");
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	If ForOpeningBalancesOnly Then
		Return;
	EndIf;
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	// Initialization of document data
	Documents.FixedAssetSale.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectFixedAssetStatuses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectFixedAssets(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Creating control of negative balances.
	Documents.FixedAssetSale.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	If ForOpeningBalancesOnly Then
		Return;
	EndIf;
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Creating control of negative balances.
	Documents.FixedAssetSale.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;

EndProcedure

// Procedure - event handler of the OnCopy object.
//
Procedure OnCopy(CopiedObject)
	
	Prepayment.Clear();
	
	ForOpeningBalancesOnly = False;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, AdditionalProperties.WriteMode, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
		
EndProcedure

#EndRegion

#EndIf