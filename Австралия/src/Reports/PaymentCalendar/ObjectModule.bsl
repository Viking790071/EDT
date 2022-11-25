#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)

	StandardProcessing = False;
	
	DriveReports.FillPeriodicityFormat(DataCompositionSchema);
	FillFlowPresentationExpression(DataCompositionSchema);
	
	ReportSettings = SettingsComposer.GetSettings();
	ReportParameters = PrepareReportParameters(ReportSettings);
	
	DriveReports.SetReportAppearanceTemplate(ReportSettings);
	DriveReports.OutputReportTitle(ReportParameters, ResultDocument);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);

	TableCalendar = GetTableCalendar(ReportParameters);	
	ExternalDataSets = New Structure("TableCalendar", TableCalendar);
	
	// Create and initialize a composition processor
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, DetailsData, True);

	// Create and initialize the result output processor
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);

	// Indicate the output begin
	OutputProcessor.BeginOutput();
	TableFixed = False;

	ResultDocument.FixedTop = 0;
	// Main cycle of the report output
	While True Do
		// Get the next item of a composition result 
		ResultItem = CompositionProcessor.Next();

		If ResultItem = Undefined Then
			// The next item is not received - end the output cycle
			Break;
		Else
			// Fix header
			If  Not TableFixed 
				  AND ResultItem.ParameterValues.Count() > 0 
				  AND TypeOf(SettingsComposer.Settings.Structure[0]) <> Type("DataCompositionChart") Then

				TableFixed = True;
				ResultDocument.FixedTop = ResultDocument.TableHeight;

			EndIf;
			// Item is received - output it using an output processor
			OutputProcessor.OutputItem(ResultItem);
		EndIf;
	EndDo;

	OutputProcessor.EndOutput();

EndProcedure

Function PrepareReportParameters(ReportSettings)
	
	BeginOfPeriod = Date(1,1,1);
	EndOfPeriod  = Date(1,1,1);
	Periodicity = 1;
	TitleOutput = False;
	Title = NStr("en = 'Cash flow projection'; ru = 'Планирование ДДС';pl = 'Preliminarz płatności';es_ES = 'Calendario de pagos';es_CO = 'Calendario de pagos';tr = 'Nakit akışı projeksiyonu';it = 'Scadenzario';de = 'Cashflow-Projektion'");
	
	ParameterPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("Period"));
	If ParameterPeriod <> Undefined AND ParameterPeriod.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess Then
		If ParameterPeriod.Use
			AND ValueIsFilled(ParameterPeriod.Value) Then
			
			BeginOfPeriod = ParameterPeriod.Value.StartDate;
			EndOfPeriod  = ParameterPeriod.Value.EndDate;
		EndIf;
	EndIf;
	
	ParameterPeriodicity = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("Periodicity"));
	If ParameterPeriodicity <> Undefined AND ParameterPeriodicity.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess Then
		If ParameterPeriodicity.Use
			AND ValueIsFilled(ParameterPeriodicity.Value) Then
			
			Periodicity = ParameterPeriodicity.Value;
		EndIf;
	EndIf;
	
	ParameterOutputTitle = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("TitleOutput"));
	If ParameterOutputTitle <> Undefined
		AND ParameterOutputTitle.Use Then
		
		TitleOutput = ParameterOutputTitle.Value;
	EndIf;
	
	OutputParameter = ReportSettings.OutputParameters.FindParameterValue(New DataCompositionParameter("Title"));
	If OutputParameter <> Undefined
		AND OutputParameter.Use Then
		Title = OutputParameter.Value;
	EndIf;
	
	ReportParameters = New Structure;
	ReportParameters.Insert("BeginOfPeriod", BeginOfPeriod);
	ReportParameters.Insert("EndOfPeriod", EndOfPeriod);
	ReportParameters.Insert("Periodicity", Periodicity);
	ReportParameters.Insert("TitleOutput", TitleOutput);
	ReportParameters.Insert("Title", Title);
	ReportParameters.Insert("ReportId", "PaymentCalendar");
	ReportParameters.Insert("ReportSettings", ReportSettings);
		
	Return ReportParameters;
	
EndFunction

Function GetTableCalendar(ReportParameters)
	
	BeginOfPeriod = ReportParameters.BeginOfPeriod;
	EndOfPeriod = ReportParameters.EndOfPeriod;
	Periodicity = ReportParameters.Periodicity;
	
	If Periodicity = 1 Then
		PeriodType = "DAY";
	ElsIf Periodicity = 2 Then
		PeriodType = "WEEK";
	ElsIf Periodicity = 3 Then
		PeriodType = "TENDAYS";
	ElsIf Periodicity = 4 Then
		PeriodType = "MONTH";
	ElsIf Periodicity = 5 Then
		PeriodType = "QUARTER";
	ElsIf Periodicity = 6 Then
		PeriodType = "HALFYEAR";
	ElsIf Periodicity = 7 Then
		PeriodType = "YEAR";
	EndIf;
	
	BankCashAccountTypeArray = New Array;
	BankCashAccountTypeArray.Add(Type("CatalogRef.BankAccounts"));
	BankCashAccountTypeArray.Add(Type("CatalogRef.CashAccounts"));

	NumberTypeDescription = New TypeDescription("Number",,, New NumberQualifiers(15,2));
	
	PaymentCalendarTable = New ValueTable;
	PaymentCalendarTable.Columns.Add("Company", New TypeDescription("CatalogRef.Companies"));
	PaymentCalendarTable.Columns.Add("Currency", New TypeDescription("CatalogRef.Currencies"));
	PaymentCalendarTable.Columns.Add("Item", New TypeDescription("CatalogRef.CashFlowItems"));
	PaymentCalendarTable.Columns.Add("CashAssetType", New TypeDescription("EnumRef.CashAssetTypes"));
	PaymentCalendarTable.Columns.Add("BankAccountPettyCash", New TypeDescription(BankCashAccountTypeArray));
	PaymentCalendarTable.Columns.Add("Recorder");
	PaymentCalendarTable.Columns.Add("PlannedAmount", NumberTypeDescription);
	PaymentCalendarTable.Columns.Add("ActualAmount", NumberTypeDescription);
	PaymentCalendarTable.Columns.Add("Period", New TypeDescription("Date"));
	PaymentCalendarTable.Columns.Add("Flow", New TypeDescription("Number"));
	
	Query = New Query;
	QueryText = 
	"SELECT ALLOWED
	|	CashAssetsBalance.Company AS Company,
	|	CashAssetsBalance.PaymentMethod AS PaymentMethod,
	|	CashAssetsBalance.BankAccountPettyCash AS BankAccountPettyCash,
	|	CashAssetsBalance.Currency AS Currency,
	|	CashAssetsBalance.AmountCurBalance AS AmountBalance,
	|	CASE
	|		WHEN &Periodicity = 1
	|			THEN BEGINOFPERIOD(&BeginOfPeriod, DAY)
	|		WHEN &Periodicity = 2
	|			THEN BEGINOFPERIOD(&BeginOfPeriod, WEEK)
	|		WHEN &Periodicity = 3
	|			THEN BEGINOFPERIOD(&BeginOfPeriod, TENDAYS)
	|		WHEN &Periodicity = 4
	|			THEN BEGINOFPERIOD(&BeginOfPeriod, MONTH)
	|		WHEN &Periodicity = 5
	|			THEN BEGINOFPERIOD(&BeginOfPeriod, QUARTER)
	|		WHEN &Periodicity = 6
	|			THEN BEGINOFPERIOD(&BeginOfPeriod, HALFYEAR)
	|		WHEN &Periodicity = 7
	|			THEN BEGINOFPERIOD(&BeginOfPeriod, YEAR)
	|	END AS Period
	|INTO Balances
	|FROM
	|	AccumulationRegister.CashAssets.Balance(&BeginOfPeriod, ) AS CashAssetsBalance
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PaymentCalendarTurnovers.Company AS Company,
	|	PaymentCalendarTurnovers.Currency AS Currency,
	|	PaymentCalendarTurnovers.Item AS Item,
	|	PaymentCalendarTurnovers.PaymentMethod AS PaymentMethod,
	|	PaymentCalendarTurnovers.BankAccountPettyCash AS BankAccountPettyCash,
	|	PaymentCalendarTurnovers.Recorder AS Recorder,
	|	PaymentCalendarTurnovers.PaymentConfirmationStatus AS PaymentConfirmationStatus,
	|	PaymentCalendarTurnovers.AmountTurnover AS AmountTurnover,
	|	PaymentCalendarTurnovers.PaymentAmountTurnover AS PaymentAmountTurnover,
	|	CASE
	|		WHEN &Periodicity = 1
	|			THEN PaymentCalendarTurnovers.DayPeriod
	|		WHEN &Periodicity = 2
	|			THEN PaymentCalendarTurnovers.WeekPeriod
	|		WHEN &Periodicity = 3
	|			THEN PaymentCalendarTurnovers.TenDaysPeriod
	|		WHEN &Periodicity = 4
	|			THEN PaymentCalendarTurnovers.MonthPeriod
	|		WHEN &Periodicity = 5
	|			THEN PaymentCalendarTurnovers.QuarterPeriod
	|		WHEN &Periodicity = 6
	|			THEN PaymentCalendarTurnovers.HalfYearPeriod
	|		WHEN &Periodicity = 7
	|			THEN PaymentCalendarTurnovers.YearPeriod
	|	END AS Period,
	|	CASE
	|		WHEN PaymentCalendarTurnovers.AmountTurnover > 0
	|				OR PaymentCalendarTurnovers.PaymentAmountTurnover > 0
	|			THEN 2
	|		WHEN PaymentCalendarTurnovers.AmountTurnover < 0
	|				OR PaymentCalendarTurnovers.PaymentAmountTurnover < 0
	|			THEN 3
	|	END AS Flow
	|INTO PaymentCalendar
	|FROM
	|	AccumulationRegister.PaymentCalendar.Turnovers(&BeginOfPeriod, &EndOfPeriod, Auto, ) AS PaymentCalendarTurnovers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ISNULL(PaymentCalendar.Company, Balances.Company) AS Company,
	|	ISNULL(PaymentCalendar.Currency, Balances.Currency) AS Currency,
	|	ISNULL(PaymentCalendar.Item, VALUE(Catalog.CashFlowItems.EmptyRef)) AS Item,
	|	ISNULL(PaymentCalendar.PaymentMethod, Balances.PaymentMethod) AS PaymentMethod,
	|	ISNULL(PaymentCalendar.BankAccountPettyCash, Balances.BankAccountPettyCash) AS BankAccountPettyCash,
	|	ISNULL(PaymentCalendar.Recorder, VALUE(Document.SalesInvoice.EmptyRef)) AS Recorder,
	|	ISNULL(PaymentCalendar.AmountTurnover, 0) AS AmountTurnover,
	|	ISNULL(PaymentCalendar.PaymentAmountTurnover, 0) AS PaymentAmountTurnover,
	|	ISNULL(PaymentCalendar.Period, Balances.Period) AS Period,
	|	ISNULL(Balances.AmountBalance, 0) AS AmountBalance,
	|	ISNULL(PaymentCalendar.Flow, 0) AS Flow
	|FROM
	|	Balances AS Balances
	|		FULL JOIN PaymentCalendar AS PaymentCalendar
	|		ON Balances.Company = PaymentCalendar.Company
	|			AND Balances.Currency = PaymentCalendar.Currency
	|			AND Balances.PaymentMethod = PaymentCalendar.PaymentMethod
	|			AND Balances.BankAccountPettyCash = PaymentCalendar.BankAccountPettyCash
	|			AND Balances.Period = PaymentCalendar.Period
	|
	|ORDER BY
	|	Period
	|TOTALS
	|	SUM(AmountTurnover),
	|	SUM(PaymentAmountTurnover),
	|	SUM(AmountBalance)
	|BY
	|	Company,
	|	Currency,
	|	PaymentMethod,
	|	BankAccountPettyCash,
	|	Period PERIODS(#PeriodType, &BeginOfPeriod, &EndOfPeriod)";
	
	Query.SetParameter("BeginOfPeriod", BeginOfPeriod);
	Query.SetParameter("EndOfPeriod", 	EndOfPeriod);
	Query.SetParameter("Periodicity", 	Periodicity);
	
	Query.Text = StrReplace(QueryText, "#PeriodType", PeriodType);
	QueryResult = Query.Execute();
	
	SelectionCompany = QueryResult.Select(QueryResultIteration.ByGroups); 
	While SelectionCompany.Next() Do
		SelectionCurrency = SelectionCompany.Select(QueryResultIteration.ByGroups);
		While SelectionCurrency.Next() Do
			SelectionCashAssetType = SelectionCurrency.Select(QueryResultIteration.ByGroups);
			While SelectionCashAssetType.Next() Do
				SelectionBankAccountPettyCash = SelectionCashAssetType.Select(QueryResultIteration.ByGroups);
				While SelectionBankAccountPettyCash.Next() Do
					
					PlannedAmount = 0;
					ActualAmount = 0;
					OpeningBalance = 0;
					
					SelectionPeriod = SelectionBankAccountPettyCash.Select(QueryResultIteration.ByGroups, "Period", "ALL");
					While SelectionPeriod.Next() Do
						Selection = SelectionPeriod.Select();
						
						CountRows = Selection.Count();
						
						If CountRows = 0 Then
							
							// Opening balance without turnovers
							NewRow = PaymentCalendarTable.Add();
							FillPropertyValues(NewRow, SelectionPeriod);
							NewRow.Flow = 1;
							
							If SelectionPeriod.Period = BeginOfPeriod Then
								OpeningBalance = ?(OpeningBalance <> 0, OpeningBalance, SelectionPeriod.AmountBalance);
								NewRow.PlannedAmount = OpeningBalance;
								NewRow.ActualAmount = OpeningBalance;
							Else
								NewRow.PlannedAmount = PlannedAmount;
								NewRow.ActualAmount = ActualAmount;
							EndIf;
							
							// Closing balance without turnovers
							NewRow = PaymentCalendarTable.Add();
							FillPropertyValues(NewRow, SelectionPeriod);
							NewRow.Flow = 4;
							
							If SelectionPeriod.Period = BeginOfPeriod Then
								OpeningBalance = ?(OpeningBalance <> 0, OpeningBalance, SelectionPeriod.AmountBalance);
								NewRow.PlannedAmount = OpeningBalance;
								NewRow.ActualAmount = OpeningBalance;
							Else
								NewRow.PlannedAmount = PlannedAmount;
								NewRow.ActualAmount = ActualAmount;
							EndIf;
							
						Else
							// Opening balance with turnovers
							NewRow = PaymentCalendarTable.Add();
							FillPropertyValues(NewRow, SelectionPeriod);
							NewRow.Flow = 1;
							
							OpeningAmountBalance = SelectionPeriod.AmountBalance/CountRows;
							
							If SelectionPeriod.Period = BeginOfPeriod Then
								OpeningBalance = ?(OpeningBalance <> 0, OpeningBalance, OpeningAmountBalance);
								NewRow.PlannedAmount = OpeningBalance;
								NewRow.ActualAmount = OpeningBalance;
							Else
								NewRow.PlannedAmount = PlannedAmount + OpeningAmountBalance;
								NewRow.ActualAmount = ActualAmount + OpeningAmountBalance;
							EndIf;
							
							// Turnovers
							While Selection.Next() Do
								If Selection.AmountTurnover <> 0 Or Selection.PaymentAmountTurnover <> 0  Then 
									NewRow = PaymentCalendarTable.Add();
									FillPropertyValues(NewRow, Selection);
									NewRow.PlannedAmount = Selection.AmountTurnover;
									NewRow.ActualAmount = Selection.PaymentAmountTurnover;
								EndIf;
								
								ActualAmount  = ActualAmount + Selection.PaymentAmountTurnover;
								PlannedAmount = PlannedAmount  + Selection.AmountTurnover;
								
								AmountBalance = Selection.AmountBalance;
							EndDo;
							
							// Closing balance with turnovers
							NewRow = PaymentCalendarTable.Add();
							FillPropertyValues(NewRow, SelectionPeriod);
							NewRow.Flow = 4;
							
							PlannedAmount = PlannedAmount + AmountBalance;
							ActualAmount  = ActualAmount + AmountBalance;
							
							NewRow.PlannedAmount = PlannedAmount;
							NewRow.ActualAmount  = ActualAmount;
							
						EndIf;
					EndDo;
				EndDo;
			EndDo;
		EndDo;
	EndDo;
	
	Return PaymentCalendarTable;
	
EndFunction

Procedure FillFlowPresentationExpression(DataCompositionSchema)
	
	Period = DataCompositionSchema.DataSets.DataSet1.Fields.Find("Flow"); 
	OpeningBalance = NStr("en = '""Opening balance""'; ru = '""Начальный остаток""';pl = '""Saldo początkowe""';es_ES = '""Saldo de entrada""';es_CO = '""Saldo de entrada""';tr = '""Açılış bakiyesi""';it = '""Bilancio di apertura""';de = '""Anfangssaldo""'");
	Inflow = NStr("en = '""Inflow""'; ru = '""Приход""';pl = '""Przychód""';es_ES = '""Entrada""';es_CO = '""Entrada""';tr = '""Giren para""';it = '""Flusso in ingresso""';de = '""Zufluss""'");
	Outflow = NStr("en = '""Outflow""'; ru = '""Расход""';pl = '""Odpływ""';es_ES = '""Salida""';es_CO = '""Salida""';tr = '""Çıkış""';it = '""Flusso in uscita""';de = '""Abfluss""'");
	ClosingBalance = NStr("en = '""Closing balance""'; ru = '""Конечный остаток""';pl = '""Saldo końcowe""';es_ES = '""Saldo de cierre""';es_CO = '""Saldo de cierre""';tr = '""Kapanış bakiyesi""';it = '""Bilancio di chiusura""';de = '""Abschlusssaldo""'");
	
	Period.PresentationExpression = StringFunctionsClientServer.SubstituteParametersToString(
		"CASE WHEN Flow = 1 THEN %1  
		|WHEN Flow = 2 THEN %2
		|WHEN Flow = 3 THEN %3
		|WHEN Flow = 4 THEN %4 END",
		OpeningBalance, Inflow, Outflow, ClosingBalance);
		
EndProcedure

#EndIf