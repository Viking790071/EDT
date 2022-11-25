
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	User = SessionParameters.CurrentExternalUser;
	
	If ValueIsFilled(User) Then
		
		AuthorizationObject = Common.ObjectAttributeValue(User, "AuthorizationObject");
		
		If TypeOf(AuthorizationObject) = Type("CatalogRef.Counterparties") Then
			Counterparty = AuthorizationObject;
		ElsIf TypeOf(AuthorizationObject) = Type("CatalogRef.ContactPersons") Then
			Counterparty = Common.ObjectAttributeValue(AuthorizationObject, "Owner");
		EndIf;
		
	EndIf;
	
	FillStatementOfAccountChart();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure StatementOfAccountChartSelection(Item, ChartValue, StandardProcessing)
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey"						, "Statement");
	FormParameters.Insert("PurposeUseKey"					, "StatementByCounterparty");
	FormParameters.Insert("Filter"							, New Structure("Counterparty", Counterparty));
	FormParameters.Insert("GenerateOnOpen"					, True);
	FormParameters.Insert("ReportOptionsCommandsVisibility"	, True);
	
	OpenForm("Report.StatementOfAccount.Form",
		FormParameters,
		ThisForm,
		UUID);
		
EndProcedure

#EndRegion

#Region Private
	
&AtServer
Procedure FillStatementOfAccountChart()
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	AccountsReceivableBalancesAndTurnovers.Contract AS Contract
	|INTO TemporaryTableContracts
	|FROM
	|	AccumulationRegister.AccountsReceivable.BalanceAndTurnovers(&BeginOfPeriodFirstMonth, &EndOfPeriodLastMonth, Month, , Counterparty = &Counterparty) AS AccountsReceivableBalancesAndTurnovers
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON AccountsReceivableBalancesAndTurnovers.Contract = CounterpartyContracts.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON AccountsReceivableBalancesAndTurnovers.Counterparty = Counterparties.Ref
	|WHERE
	|	CASE
	|			WHEN &UseContractRestrictionsTurnOff
	|				THEN TRUE
	|			WHEN Counterparties.DoOperationsByContracts
	|					AND CounterpartyContracts.VisibleToExternalUsers
	|				THEN TRUE
	|			WHEN NOT Counterparties.DoOperationsByContracts
	|				THEN TRUE
	|			ELSE FALSE
	|		END
	|
	|UNION ALL
	|
	|SELECT
	|	AccountsPayableBalancesAndTurnovers.Contract
	|FROM
	|	AccumulationRegister.AccountsPayable.BalanceAndTurnovers(&BeginOfPeriodFirstMonth, &EndOfPeriodLastMonth, Month, , Counterparty = &Counterparty) AS AccountsPayableBalancesAndTurnovers
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON AccountsPayableBalancesAndTurnovers.Contract = CounterpartyContracts.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON AccountsPayableBalancesAndTurnovers.Counterparty = Counterparties.Ref
	|WHERE
	|	CASE
	|			WHEN &UseContractRestrictionsTurnOff
	|				THEN TRUE
	|			WHEN Counterparties.DoOperationsByContracts
	|					AND CounterpartyContracts.VisibleToExternalUsers
	|				THEN TRUE
	|			WHEN NOT Counterparties.DoOperationsByContracts
	|				THEN TRUE
	|			ELSE FALSE
	|		END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableContracts.Contract AS Contract
	|INTO TemporaryTableContractsGroup
	|FROM
	|	TemporaryTableContracts AS TemporaryTableContracts
	|
	|GROUP BY
	|	TemporaryTableContracts.Contract
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	&BeginOfPeriodFirstMonth AS MonthPeriod,
	|	TemporaryTableContractsGroup.Contract AS Contract,
	|	CASE
	|		WHEN ISNULL(AccountsReceivableBalancesAndTurnovers.AmountClosingBalance, 0) > 0
	|			THEN ISNULL(AccountsReceivableBalancesAndTurnovers.AmountClosingBalance, 0)
	|		ELSE 0
	|	END - CASE
	|		WHEN ISNULL(AccountsReceivableBalancesAndTurnovers.AmountClosingBalance, 0) < 0
	|			THEN -ISNULL(AccountsReceivableBalancesAndTurnovers.AmountClosingBalance, 0)
	|		ELSE 0
	|	END AS TotalClosingBalance
	|INTO TemporaryTableStatement
	|FROM
	|	TemporaryTableContractsGroup AS TemporaryTableContractsGroup
	|		LEFT JOIN AccumulationRegister.AccountsReceivable.BalanceAndTurnovers(&BeginOfPeriodFirstMonth, &EndOfPeriodFirstMonth, Month, , Counterparty = &Counterparty) AS AccountsReceivableBalancesAndTurnovers
	|		ON TemporaryTableContractsGroup.Contract = AccountsReceivableBalancesAndTurnovers.Contract
	|
	|UNION ALL
	|
	|SELECT
	|	&BeginOfPeriodFirstMonth,
	|	TemporaryTableContractsGroup.Contract,
	|	CASE
	|		WHEN ISNULL(AccountsPayableBalancesAndTurnovers.AmountClosingBalance, 0) < 0
	|			THEN -ISNULL(AccountsPayableBalancesAndTurnovers.AmountClosingBalance, 0)
	|		ELSE 0
	|	END - CASE
	|		WHEN ISNULL(AccountsPayableBalancesAndTurnovers.AmountClosingBalance, 0) > 0
	|			THEN ISNULL(AccountsPayableBalancesAndTurnovers.AmountClosingBalance, 0)
	|		ELSE 0
	|	END
	|FROM
	|	TemporaryTableContractsGroup AS TemporaryTableContractsGroup
	|		LEFT JOIN AccumulationRegister.AccountsPayable.BalanceAndTurnovers(&BeginOfPeriodFirstMonth, &EndOfPeriodFirstMonth, Month, , Counterparty = &Counterparty) AS AccountsPayableBalancesAndTurnovers
	|		ON TemporaryTableContractsGroup.Contract = AccountsPayableBalancesAndTurnovers.Contract
	|
	|UNION ALL
	|
	|SELECT
	|	&BeginOfPeriodSecondMonth,
	|	TemporaryTableContractsGroup.Contract,
	|	CASE
	|		WHEN ISNULL(AccountsReceivableBalancesAndTurnovers.AmountClosingBalance, 0) > 0
	|			THEN ISNULL(AccountsReceivableBalancesAndTurnovers.AmountClosingBalance, 0)
	|		ELSE 0
	|	END - CASE
	|		WHEN ISNULL(AccountsReceivableBalancesAndTurnovers.AmountClosingBalance, 0) < 0
	|			THEN -ISNULL(AccountsReceivableBalancesAndTurnovers.AmountClosingBalance, 0)
	|		ELSE 0
	|	END
	|FROM
	|	TemporaryTableContractsGroup AS TemporaryTableContractsGroup
	|		LEFT JOIN AccumulationRegister.AccountsReceivable.BalanceAndTurnovers(&BeginOfPeriodSecondMonth, &EndOfPeriodSecondMonth, Month, , Counterparty = &Counterparty) AS AccountsReceivableBalancesAndTurnovers
	|		ON TemporaryTableContractsGroup.Contract = AccountsReceivableBalancesAndTurnovers.Contract
	|
	|UNION ALL
	|
	|SELECT
	|	&BeginOfPeriodSecondMonth,
	|	TemporaryTableContractsGroup.Contract,
	|	CASE
	|		WHEN ISNULL(AccountsPayableBalancesAndTurnovers.AmountClosingBalance, 0) < 0
	|			THEN -ISNULL(AccountsPayableBalancesAndTurnovers.AmountClosingBalance, 0)
	|		ELSE 0
	|	END - CASE
	|		WHEN ISNULL(AccountsPayableBalancesAndTurnovers.AmountClosingBalance, 0) > 0
	|			THEN ISNULL(AccountsPayableBalancesAndTurnovers.AmountClosingBalance, 0)
	|		ELSE 0
	|	END
	|FROM
	|	TemporaryTableContractsGroup AS TemporaryTableContractsGroup
	|		LEFT JOIN AccumulationRegister.AccountsPayable.BalanceAndTurnovers(&BeginOfPeriodSecondMonth, &EndOfPeriodSecondMonth, Month, , Counterparty = &Counterparty) AS AccountsPayableBalancesAndTurnovers
	|		ON TemporaryTableContractsGroup.Contract = AccountsPayableBalancesAndTurnovers.Contract
	|
	|UNION ALL
	|
	|SELECT
	|	&BeginOfPeriodLastMonth,
	|	TemporaryTableContractsGroup.Contract,
	|	CASE
	|		WHEN ISNULL(AccountsReceivableBalancesAndTurnovers.AmountClosingBalance, 0) > 0
	|			THEN ISNULL(AccountsReceivableBalancesAndTurnovers.AmountClosingBalance, 0)
	|		ELSE 0
	|	END - CASE
	|		WHEN ISNULL(AccountsReceivableBalancesAndTurnovers.AmountClosingBalance, 0) < 0
	|			THEN -ISNULL(AccountsReceivableBalancesAndTurnovers.AmountClosingBalance, 0)
	|		ELSE 0
	|	END
	|FROM
	|	TemporaryTableContractsGroup AS TemporaryTableContractsGroup
	|		LEFT JOIN AccumulationRegister.AccountsReceivable.BalanceAndTurnovers(&BeginOfPeriodLastMonth, &EndOfPeriodLastMonth, Month, , Counterparty = &Counterparty) AS AccountsReceivableBalancesAndTurnovers
	|		ON TemporaryTableContractsGroup.Contract = AccountsReceivableBalancesAndTurnovers.Contract
	|
	|UNION ALL
	|
	|SELECT
	|	&BeginOfPeriodLastMonth,
	|	TemporaryTableContractsGroup.Contract,
	|	CASE
	|		WHEN ISNULL(AccountsPayableBalancesAndTurnovers.AmountClosingBalance, 0) < 0
	|			THEN -ISNULL(AccountsPayableBalancesAndTurnovers.AmountClosingBalance, 0)
	|		ELSE 0
	|	END - CASE
	|		WHEN ISNULL(AccountsPayableBalancesAndTurnovers.AmountClosingBalance, 0) > 0
	|			THEN ISNULL(AccountsPayableBalancesAndTurnovers.AmountClosingBalance, 0)
	|		ELSE 0
	|	END
	|FROM
	|	TemporaryTableContractsGroup AS TemporaryTableContractsGroup
	|		LEFT JOIN AccumulationRegister.AccountsPayable.BalanceAndTurnovers(&BeginOfPeriodLastMonth, &EndOfPeriodLastMonth, Month, , Counterparty = &Counterparty) AS AccountsPayableBalancesAndTurnovers
	|		ON TemporaryTableContractsGroup.Contract = AccountsPayableBalancesAndTurnovers.Contract
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableStatement.MonthPeriod AS MonthPeriod,
	|	TemporaryTableStatement.Contract AS Contract,
	|	SUM(TemporaryTableStatement.TotalClosingBalance) AS TotalClosingBalance
	|FROM
	|	TemporaryTableStatement AS TemporaryTableStatement
	|
	|GROUP BY
	|	TemporaryTableStatement.MonthPeriod,
	|	TemporaryTableStatement.Contract
	|
	|ORDER BY
	|	MonthPeriod,
	|	Contract
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableStatement.Contract AS Contract,
	|	PRESENTATION(TemporaryTableStatement.Contract) AS ContractPresentation
	|FROM
	|	TemporaryTableStatement AS TemporaryTableStatement
	|
	|GROUP BY
	|	TemporaryTableStatement.Contract";
	
	CurrentSessionDate = CurrentSessionDate();
	
	BegOfMonth = BegOfMonth(CurrentSessionDate);
	
	BeginOfPeriodFirstMonth = AddMonth(BegOfMonth, -2);
	EndOfPeriodFirstMonth = EndOfMonth(BeginOfPeriodFirstMonth);
	
	BeginOfPeriodSecondMonth = AddMonth(BegOfMonth, -1);
	EndOfPeriodSecondMonth = EndOfMonth(BeginOfPeriodSecondMonth);
	
	BeginOfPeriodLastMonth = BegOfMonth(CurrentSessionDate); 
	EndOfPeriodLastMonth = EndOfMonth(CurrentSessionDate); 
	
	Query.SetParameter("BeginOfPeriodFirstMonth"	, BeginOfPeriodFirstMonth);
	Query.SetParameter("EndOfPeriodFirstMonth"		, EndOfPeriodFirstMonth);
	Query.SetParameter("BeginOfPeriodSecondMonth"	, BeginOfPeriodSecondMonth);
	Query.SetParameter("EndOfPeriodSecondMonth"		, EndOfPeriodSecondMonth);
	Query.SetParameter("BeginOfPeriodLastMonth"		, BeginOfPeriodLastMonth);
	Query.SetParameter("EndOfPeriodLastMonth"		, EndOfPeriodLastMonth);
	Query.SetParameter("Counterparty"				, Counterparty);
	Query.SetParameter("UseContractRestrictionsTurnOff",
		Not GetFunctionalOption("UseContractRestrictionsForExternalUsers"));
	
	QueryResult = Query.ExecuteBatch();
	
	SeriesSelection = QueryResult[QueryResult.Count() - 1].Select();
	
	SeriesMap = New Map;
	
	StatementOfAccountChart.Clear();
	StatementOfAccountChart.AutoMinValue = False;
	
	StatementOfAccountChart.AutoTransposition = False;
	
	SeriesPosition = 0;
	While SeriesSelection.Next() Do
		
		NewSeries = StatementOfAccountChart.Series.Add(SeriesSelection.ContractPresentation);
		
		SeriesMap.Insert(SeriesSelection.Contract, SeriesPosition);
		
		SeriesPosition = SeriesPosition + 1;
		
	EndDo;
	
	SelectionDetailRecords = QueryResult[QueryResult.Count() - 2].Select();
	
	While SelectionDetailRecords.Next() Do

		CurrentSeries = SeriesMap.Get(SelectionDetailRecords.Contract);
		
		Point = StatementOfAccountChart.SetPoint(Format(SelectionDetailRecords.MonthPeriod, NStr("en = 'DF=''MMM yyyy'''; ru = 'ДФ=''МММ гггг''';pl = 'DF = ''MMM yyyy''';es_ES = 'DF=''MMM yyyy''';es_CO = 'DF=''MMM yyyy''';tr = 'DF=''MMM yyyy''';it = 'DF=''MMM yyyy''';de = 'DF=''MMM yyyy'''")));
				
		StatementOfAccountChart.SetValue(Point
			, CurrentSeries
			, SelectionDetailRecords.TotalClosingBalance
			, Undefined
			, Format(SelectionDetailRecords.TotalClosingBalance, "ND=15; NFD=2"));
		
	EndDo;
	
	StatementOfAccountChart.AutoTransposition = True;
	
EndProcedure

&AtClient
Procedure RefreshChart(Command)
	
	FillStatementOfAccountChart();
	
EndProcedure

#EndRegion
