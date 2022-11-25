#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	SetPrivilegedMode(True);
	
	StandardProcessing = False;
	Cancel = False;
	
	ReportSettings = SettingsComposer.GetSettings();
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);
	
	ExternalDataSets = GetExternalDataSets(ReportSettings, Cancel, ResultDocument);
	
	If Cancel Then
	
		Return;
	
	EndIf; 
	
	// Create and initialize a composition processor
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, DetailsData, True);
	
	// Create and initialize the result output processor
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	OutputProcessor.Output(CompositionProcessor);
	
EndProcedure

#EndRegion

#Region Private

Function GetExternalDataSets(ReportSettings, Cancel, ResultDocument)
	
	Result = New Structure;
	
	SubscriptionPlan = New ValueList;
	
	For Each Item In ReportSettings.DataParameters.Items Do
		
		If String(Item.Parameter) = "SubscriptionPlan" Then
			
			If ValueIsFilled(Item.Value) Then
				If TypeOf(Item.Value) = Type("ValueList") Then
					SubscriptionPlan = Item.Value;
				Else
					SubscriptionPlan.Add(Item.Value);
				EndIf;
			EndIf;
			
		EndIf;
		
		If String(Item.Parameter) = "Period" Then
			
			PeriodReport = Item.Value;
			
			StartDate = PeriodReport.StartDate;
			EndDate = PeriodReport.EndDate;
			
		EndIf;
		
	EndDo;
	
	If SubscriptionPlan.Count() = 0 Then
		
		If SettingsComposer.UserSettings.AdditionalProperties.VariantKey = "Supplier" Then
			
			Raise NStr("en = 'Cannot generate the report. Supplier schedules are not enabled.'; ru = 'Не удалось создать отчет. Графики поставщиков не включены.';pl = 'Nie można wygenerować raportu. Harmonogramy dostawców nie są włączone.';es_ES = 'No se puede generar el informe. Los horarios del proveedor no están activados.';es_CO = 'No se puede generar el informe. Los horarios del proveedor no están activados.';tr = 'Rapor oluşturulamıyor. Tedarikçi programları etkinleştirilmedi.';it = 'Impossibile generare il report. Non sono stati abilitati i programmi dei fornitori.';de = 'Der Bericht kann nicht generiert werden. Lieferantenzeitpläne sind nicht aktiviert.'");
			
			Return Result;
			
		Else 
			
			Raise NStr("en = 'Cannot generate the report. Subscription plans are not enabled.'; ru = 'Не удалось сформировать отчет. Тарифы подписки не включены.';pl = 'Nie można wygenerować raportu. Plany subskrypcji nie są włączone.';es_ES = 'No se puede generar el informe. Los planes de suscripción no están activados.';es_CO = 'No se puede generar el informe. Los planes de suscripción no están activados.';tr = 'Rapor oluşturulmadı. Abonelik planları etkinleştirilmedi.';it = 'Impossibile generare il report. Non sono stati abilitati i piani di abbonamento.';de = 'Der Bericht kann nicht generiert werden. Abonnementspläne sind nicht aktiviert.'");
			
			Return Result;
			
		EndIf;
		
	EndIf;
	
	If StartDate = Date(1, 1, 1) 
		And EndDate <> Date(1, 1, 1) Then
		
		Raise NStr("en = 'The period start date is required.'; ru = 'Требуется указать дату начала периода.';pl = 'Wymagana jest data rozpoczęcia okresu.';es_ES = 'Se requiere la fecha de inicio del período.';es_CO = 'Se requiere la fecha de inicio del período.';tr = 'Dönem başlangıç tarihi gerekli.';it = 'È richiesta la data di inizio del periodo.';de = 'Das Startdatum des Zeitraums ist erforderlich.'");
		
		Return Result;
		
	EndIf;
	
	ValueTableResult = New ValueTable;
	
	For Each ItemPlan In SubscriptionPlan Do
		
		ValueTableBySubscriptionPlan = GetValueTableBySubscriptionPlan(ItemPlan.Value, StartDate, EndDate);
		
		If ValueTableResult.Columns.Count() = 0 Then
			
			ValueTableResult = ValueTableBySubscriptionPlan.CopyColumns();
			
		EndIf;
		
		If ValueTableBySubscriptionPlan.Count() = 0 Then
			
			Continue;
			
		EndIf;
		
		For Each LineValueTable In ValueTableBySubscriptionPlan Do
			
			NewLineTableResult = ValueTableResult.Add();
			
			FillPropertyValues(NewLineTableResult, LineValueTable);
			
		EndDo;
		
	EndDo;
	
	Result.Insert("ValueTablePlannedDates", ValueTableResult);
	
	Return Result;
	
EndFunction

Function GetValueTableBySubscriptionPlan(SubscriptionPlan, Val StartDate, Val EndDate)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	Subscriptions.SubscriptionPlan AS SubscriptionPlan,
	|	MIN(Subscriptions.StartDate) AS StartDate
	|FROM
	|	InformationRegister.Subscriptions AS Subscriptions
	|WHERE
	|	Subscriptions.SubscriptionPlan = &SubscriptionPlan
	|
	|GROUP BY
	|	Subscriptions.SubscriptionPlan";
	
	Query.SetParameter("SubscriptionPlan", SubscriptionPlan);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		StartDate = Max(StartDate, SelectionDetailRecords.StartDate);
		
	EndDo;
	
	ValueTablePlannedDates = New ValueTable;
	ValueTablePlannedDates.Columns.Add("Counterparty", New TypeDescription("CatalogRef.Counterparties"));
	ValueTablePlannedDates.Columns.Add("Contract", New TypeDescription("CatalogRef.CounterpartyContracts"));
	ValueTablePlannedDates.Columns.Add("PlannedDate", New TypeDescription("Date", , , , New DateQualifiers(DateFractions.Date)));
	ValueTablePlannedDates.Columns.Add("SubscriptionPlan", New TypeDescription("CatalogRef.SubscriptionPlans"));
	ValueTablePlannedDates.Columns.Add("ActualDate", New TypeDescription("Date", , , , New DateQualifiers(DateFractions.Date)));
	
	StructurePlan = Common.ObjectAttributesValues(SubscriptionPlan, 
		"ChargeFrequency, ScheduledJobUUID, UseCustomSchedule");
	
	If Not StructurePlan.UseCustomSchedule Then
		
		DaysCounter = BegOfDay(StartDate);
		
		If StructurePlan.ChargeFrequency = Enums.Periodicity.Month Then
			
			DaysCounter = BegOfMonth(StartDate);
			
		ElsIf StructurePlan.ChargeFrequency = Enums.Periodicity.Year Then
			
			DaysCounter = BegOfYear(StartDate);
			
		EndIf;
		
		While DaysCounter <= EndDate Do
			
			If ScheduledJobs.FindByUUID(StructurePlan.ScheduledJobUUID).Schedule.ExecutionRequired(DaysCounter) Then
				
				If DaysCounter < StartDate 
					And StructurePlan.ChargeFrequency = Enums.Periodicity.Month Then
					
					DaysCounter = BegOfMonth(AddMonth(DaysCounter, 1));
					Continue;
					
				ElsIf DaysCounter < StartDate
					And StructurePlan.ChargeFrequency = Enums.Periodicity.Year Then
					
					DaysCounter = BegOfMonth(AddMonth(DaysCounter, 12));
					Continue;
					
				EndIf;
				
				NewLine = ValueTablePlannedDates.Add();
				
				NewLine.SubscriptionPlan	= SubscriptionPlan;
				NewLine.Counterparty		= Catalogs.Counterparties.EmptyRef();
				NewLine.Contract			= Catalogs.CounterpartyContracts.EmptyRef();
				NewLine.PlannedDate			= DaysCounter;
				NewLine.ActualDate			= Date(1, 1, 1);
				
				If StructurePlan.ChargeFrequency = Enums.Periodicity.Month Then
					
					DaysCounter = BegOfMonth(AddMonth(DaysCounter, 1));
					Continue;
					
				ElsIf StructurePlan.ChargeFrequency = Enums.Periodicity.Year Then
					
					DaysCounter = BegOfMonth(AddMonth(DaysCounter, 12));
					Continue;
					
				EndIf;
				
			EndIf; 
			
			DaysCounter = DaysCounter + 86400;
			
		EndDo;
		
	EndIf;

	If Not StructurePlan.UseCustomSchedule Then
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED
		|	ValueTablePlannedDates.PlannedDate AS PlannedDate,
		|	ValueTablePlannedDates.Counterparty AS Counterparty,
		|	ValueTablePlannedDates.Contract AS Contract,
		|	ValueTablePlannedDates.SubscriptionPlan AS SubscriptionPlan,
		|	ValueTablePlannedDates.ActualDate AS ActualDate
		|INTO TT_ValueTablePlannedDates
		|FROM
		|	&ValueTablePlannedDates AS ValueTablePlannedDates
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	GeneratedDocumentsData.SubscriptionPlan AS SubscriptionPlan,
		|	GeneratedDocumentsData.PlannedDate AS PlannedDate,
		|	GeneratedDocumentsData.ActualDate AS ActualDate,
		|	GeneratedDocumentsData.Counterparty AS Counterparty,
		|	GeneratedDocumentsData.Contract AS Contract
		|INTO TT_PrevGeneratedDocumentsData
		|FROM
		|	InformationRegister.GeneratedDocumentsData AS GeneratedDocumentsData
		|WHERE
		|	GeneratedDocumentsData.SubscriptionPlan = &SubscriptionPlan
		|	AND GeneratedDocumentsData.PlannedDate BETWEEN &BeginOfPeriod AND &EndOfPeriod
		|
		|UNION ALL
		|
		|SELECT
		|	TT_ValueTablePlannedDates.SubscriptionPlan,
		|	TT_ValueTablePlannedDates.PlannedDate,
		|	TT_ValueTablePlannedDates.ActualDate,
		|	Subscriptions.Counterparty,
		|	Subscriptions.Contract
		|FROM
		|	TT_ValueTablePlannedDates AS TT_ValueTablePlannedDates
		|		INNER JOIN InformationRegister.Subscriptions AS Subscriptions
		|		ON TT_ValueTablePlannedDates.SubscriptionPlan = Subscriptions.SubscriptionPlan
		|			AND (Subscriptions.StartDate <= TT_ValueTablePlannedDates.PlannedDate)
		|			AND (Subscriptions.EndDate >= TT_ValueTablePlannedDates.PlannedDate
		|				OR Subscriptions.EndDate = DATETIME(1, 1, 1))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	TT_PrevGeneratedDocumentsData.SubscriptionPlan AS SubscriptionPlan,
		|	TT_PrevGeneratedDocumentsData.PlannedDate AS PlannedDate,
		|	MAX(TT_PrevGeneratedDocumentsData.ActualDate) AS ActualDate,
		|	TT_PrevGeneratedDocumentsData.Counterparty AS Counterparty,
		|	TT_PrevGeneratedDocumentsData.Contract AS Contract,
		|	CASE
		|		WHEN MAX(TT_PrevGeneratedDocumentsData.ActualDate) = DATETIME(1, 1, 1)
		|			THEN 0
		|		ELSE DATEDIFF(TT_PrevGeneratedDocumentsData.PlannedDate, MAX(TT_PrevGeneratedDocumentsData.ActualDate), DAY)
		|	END AS DiffDates
		|FROM
		|	TT_PrevGeneratedDocumentsData AS TT_PrevGeneratedDocumentsData
		|
		|GROUP BY
		|	TT_PrevGeneratedDocumentsData.SubscriptionPlan,
		|	TT_PrevGeneratedDocumentsData.PlannedDate,
		|	TT_PrevGeneratedDocumentsData.Counterparty,
		|	TT_PrevGeneratedDocumentsData.Contract";
		
		Query.SetParameter("ValueTablePlannedDates", ValueTablePlannedDates);
		Query.SetParameter("SubscriptionPlan", SubscriptionPlan);
		Query.SetParameter("BeginOfPeriod", StartDate);
		Query.SetParameter("EndOfPeriod", EndDate);
		
		ValueTablePlannedDates = Query.Execute().Unload();
		
	Else 
	
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED
		|	GeneratedDocumentsData.SubscriptionPlan AS SubscriptionPlan,
		|	GeneratedDocumentsData.PlannedDate AS PlannedDate,
		|	DATETIME(1, 1, 1) AS ActualDate,
		|	VALUE(Catalog.Counterparties.EmptyRef) AS Counterparty,
		|	VALUE(Catalog.CounterpartyContracts.EmptyRef) AS Contract
		|INTO TT_ValueTablePlannedDates
		|FROM
		|	InformationRegister.GeneratedDocumentsData AS GeneratedDocumentsData
		|WHERE
		|	GeneratedDocumentsData.SubscriptionPlan = &SubscriptionPlan
		|	AND GeneratedDocumentsData.PlannedDate BETWEEN &BeginOfPeriod AND &EndOfPeriod
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	GeneratedDocumentsData.SubscriptionPlan AS SubscriptionPlan,
		|	GeneratedDocumentsData.PlannedDate AS PlannedDate,
		|	GeneratedDocumentsData.ActualDate AS ActualDate,
		|	GeneratedDocumentsData.Counterparty AS Counterparty,
		|	GeneratedDocumentsData.Contract AS Contract
		|INTO TT_PrevGeneratedDocumentsData
		|FROM
		|	InformationRegister.GeneratedDocumentsData AS GeneratedDocumentsData
		|WHERE
		|	GeneratedDocumentsData.SubscriptionPlan = &SubscriptionPlan
		|	AND GeneratedDocumentsData.PlannedDate BETWEEN &BeginOfPeriod AND &EndOfPeriod
		|	AND GeneratedDocumentsData.Counterparty <> VALUE(Catalog.Counterparties.EmptyRef)
		|	AND GeneratedDocumentsData.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)
		|
		|UNION ALL
		|
		|SELECT
		|	TT_ValueTablePlannedDates.SubscriptionPlan,
		|	TT_ValueTablePlannedDates.PlannedDate,
		|	TT_ValueTablePlannedDates.ActualDate,
		|	Subscriptions.Counterparty,
		|	Subscriptions.Contract
		|FROM
		|	TT_ValueTablePlannedDates AS TT_ValueTablePlannedDates
		|		INNER JOIN InformationRegister.Subscriptions AS Subscriptions
		|		ON TT_ValueTablePlannedDates.SubscriptionPlan = Subscriptions.SubscriptionPlan
		|			AND (Subscriptions.StartDate <= TT_ValueTablePlannedDates.PlannedDate)
		|			AND (Subscriptions.EndDate >= TT_ValueTablePlannedDates.PlannedDate
		|				OR Subscriptions.EndDate = DATETIME(1, 1, 1))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	TT_PrevGeneratedDocumentsData.SubscriptionPlan AS SubscriptionPlan,
		|	TT_PrevGeneratedDocumentsData.PlannedDate AS PlannedDate,
		|	MAX(TT_PrevGeneratedDocumentsData.ActualDate) AS ActualDate,
		|	TT_PrevGeneratedDocumentsData.Counterparty AS Counterparty,
		|	TT_PrevGeneratedDocumentsData.Contract AS Contract,
		|	CASE
		|		WHEN MAX(TT_PrevGeneratedDocumentsData.ActualDate) = DATETIME(1, 1, 1)
		|			THEN 0
		|		ELSE DATEDIFF(TT_PrevGeneratedDocumentsData.PlannedDate, MAX(TT_PrevGeneratedDocumentsData.ActualDate), DAY)
		|	END AS DiffDates
		|FROM
		|	TT_PrevGeneratedDocumentsData AS TT_PrevGeneratedDocumentsData
		|
		|GROUP BY
		|	TT_PrevGeneratedDocumentsData.SubscriptionPlan,
		|	TT_PrevGeneratedDocumentsData.PlannedDate,
		|	TT_PrevGeneratedDocumentsData.Counterparty,
		|	TT_PrevGeneratedDocumentsData.Contract";
		
		Query.SetParameter("SubscriptionPlan", SubscriptionPlan);
		Query.SetParameter("BeginOfPeriod", StartDate);
		Query.SetParameter("EndOfPeriod", EndDate);
		
		ValueTablePlannedDates = Query.Execute().Unload();
		
	EndIf;
	
	Return ValueTablePlannedDates;

EndFunction

#EndRegion

#EndIf