
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Users.RolesAvailable("FullRights") Then
		Cancel = True;
		Return;
	EndIf;
	
	If Constants.EachGLAccountIsMappedToIncomeAndExpenseItem.Get() = False Then
		AddPrefilledIncomeAndExpenseItems();
	EndIf;
	
	UseDefaultTypeOfAccounting = True;
	
	If Constants.EachGLAccountIsMappedToIncomeAndExpenseItem.Get() Then
		FillProfitEstimationMapping();
	Else
		FillMapping();
	EndIf;
	
	If Mapping.Count() = 0 Then
		Constants.EachGLAccountIsMappedToIncomeAndExpenseItem.Set(True);
		Constants.EachProfitEstimationGLAccountIsMappedToIncomeAndExpenseItem.Set(True);
		Cancel = True;
	EndIf;
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	SetConstantValues(UseDefaultTypeOfAccounting);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure MappingSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "MappingViewDocuments" Then
		
		CurrentData = Mapping.FindByID(SelectedRow);
		
		FormParameters = New Structure("VariantKey, Filter, GenerateOnOpen", 
			"Default", 
			New Structure("GLAccount", CurrentData.GLAccount), 
			True);
		
		OpenForm("Report.ProfitAndLossAccountRecorders.Form", FormParameters, , CurrentData.GLAccount);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure MappingIncomeAndExpenseItemOnChange(Item)
	FormManagement();
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ProcessDataCommand(Command)
	
	TimeConsuming = SaveMappingAtServer();
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.MessageText = NStr("en = 'Data processing...'; ru = 'Обработка данных...';pl = 'Przetwarzanie danych...';es_ES = 'Procesamiento de datos...';es_CO = 'Procesamiento de datos...';tr = 'Veri işleniyor...';it = 'Elaborazione dati...';de = 'Datenverarbeitung...'");
	
	NotifyDescription = New NotifyDescription("DataProcessedOnComletion", ThisObject);
	TimeConsumingOperationsClient.WaitForCompletion(TimeConsuming, NotifyDescription, IdleParameters);
	
EndProcedure

&AtClient
Procedure DataProcessedOnComletion(Result, AdditionParameters) Export
	
	If Result = Undefined Or Result.Status = "Canceled" Then
		Return;
	ElsIf Result.Status = "Error" Then
		CommonClientServer.MessageToUser(Result.BriefErrorPresentation);
	ElsIf Result.Status = "Completed" Then
		If IsEmptyDefaultItems() Then
			NotifyDescription = New NotifyDescription("OnMappingProcessingCompletion", ThisObject);
			OpenForm("Catalog.DefaultIncomeAndExpenseItems.ListForm", New Structure("FromMapping", True), ThisObject,,,
				,NotifyDescription,FormWindowOpeningMode.LockOwnerWindow);
			CommonClientServer.MessageToUser(Nstr("en = 'Not all items are filled in by default. Please fill it in manually.'; ru = 'Не все статьи заполнились по умолчанию. Заполните их вручную.';pl = 'Nie wszystkie pozycje są wypełnione domyślnie. Wypełnij je ręcznie.';es_ES = 'No todos los artículos se rellenan por defecto. Por favor, rellénelos manualmente.';es_CO = 'No todos los artículos se rellenan por defecto. Por favor, rellénelos manualmente.';tr = 'Tüm öğeler varsayılan olarak doldurulamadı. Lütfen, manuel olarak doldurun.';it = 'Non tutti gli elementi sono compilati da impostazione predefinita. Compilarli manualmente.';de = 'Nicht alle Positionen sind standardmäßig aufgefüllt. Bitte füllen Sie sie manuell auf.'"));
		Else
			Close();
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnMappingProcessingCompletion(Result, AdditionParameters) Export
	
	If TypeOf(Result) = Type("Structure") Then
		If Result.Property("OtherExpenses") And ValueIsFilled(Result.OtherExpenses) Then
			FillInPOSTerminalsExpenseItems(Result.OtherExpenses);
		EndIf;
	EndIf;
	
	Close(True);
	
EndProcedure

&AtClient
Procedure ResetToDefaultCommand(Command)
	FillMapping();
EndProcedure

&AtClient
Procedure CloseCommand(Command)
	
	Exit(False);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure AddPrefilledIncomeAndExpenseItems()
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	PrimaryChartOfAccounts.Description AS Description,
	|	MAX(CASE
	|			WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
	|				THEN VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales)
	|			WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|				THEN VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|			WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|				THEN VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|			WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|			WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|				THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|			WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|				THEN VALUE(Catalog.IncomeAndExpenseTypes.Revenue)
	|		END) AS IncomeAndExpenseType,
	|	MAX(PrimaryChartOfAccounts.MethodOfDistribution) AS MethodOfDistribution,
	|	MAX(CASE
	|			WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|					OR PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|				THEN TRUE
	|			ELSE FALSE
	|		END) AS IsIncome,
	|	MAX(CASE
	|			WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
	|					OR PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|					OR PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|					OR PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|					OR PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|				THEN TRUE
	|			ELSE FALSE
	|		END) AS IsExpense
	|FROM
	|	ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		LEFT JOIN Catalog.IncomeAndExpenseItems AS IncomeAndExpenseItems
	|		ON PrimaryChartOfAccounts.Description = IncomeAndExpenseItems.Description
	|			AND (NOT IncomeAndExpenseItems.IsFolder)
	|		LEFT JOIN Catalog.DefaultGLAccounts AS DefaultGLAccounts
	|		ON PrimaryChartOfAccounts.Ref = DefaultGLAccounts.GLAccount
	|WHERE
	|	PrimaryChartOfAccounts.TypeOfAccount IN (VALUE(Enum.GLAccountsTypes.CostOfSales), VALUE(Enum.GLAccountsTypes.Expenses), VALUE(Enum.GLAccountsTypes.IndirectExpenses), VALUE(Enum.GLAccountsTypes.OtherExpenses), VALUE(Enum.GLAccountsTypes.OtherIncome), VALUE(Enum.GLAccountsTypes.Revenue))
	|	AND IncomeAndExpenseItems.Ref IS NULL
	|	AND CASE
	|			WHEN DefaultGLAccounts.Ref IS NULL
	|				THEN TRUE
	|			ELSE DefaultGLAccounts.Ref <> VALUE(Catalog.DefaultGLAccounts.GoodsInTransit)
	|		END
	|
	|GROUP BY
	|	PrimaryChartOfAccounts.Description";
	
	Selection = Query.Execute().Select();
	
	BeginTransaction();
	
	Try
		
		While Selection.Next() Do
			
			CatalogObject = Catalogs.IncomeAndExpenseItems.CreateItem();
			FillPropertyValues(CatalogObject, Selection);
			
			InfobaseUpdate.WriteObject(CatalogObject);
			
		EndDo;
		
		UndefinedElem = Catalogs.IncomeAndExpenseItems.Undefined.GetObject();
		UndefinedElem.IsExpense = True;
		UndefinedElem.IsIncome = True;
		
		InfobaseUpdate.WriteObject(UndefinedElem);
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot save catalog ""%1"". Details: %2'; ru = 'Не удалось записать справочник ""%1"". Подробнее: %2';pl = 'Nie można zapisać katalogu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';tr = '""%1"" kataloğu kaydedilemiyor. Ayrıntılar: %2';it = 'Impossibile salvare il catalogo ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Katalogs ""%1"". Details: %2'", CommonClientServer.DefaultLanguageCode()),
			Object,
			BriefErrorDescription(ErrorInfo()));
		
		WriteLogEvent(
			InfobaseUpdate.EventLogEvent(),
			EventLogLevel.Error,
			Metadata.Catalogs.IncomeAndExpenseItems,
			,
			ErrorDescription);
		
		Return;
		
	EndTry;
	
EndProcedure

&AtServer
Procedure FormManagement()
	
	Items.ProcessDataCommand.Enabled = IsEachGLAccoutMapped();
	
	ErrorRows = Mapping.FindRows(New Structure("IncomeAndExpenseItem", PredefinedValue("Catalog.IncomeAndExpenseItems.EmptyRef")));
	
	Items.ProcessDataCommand.Enabled = (ErrorRows.Count() = 0);
	
	If Constants.EachGLAccountIsMappedToIncomeAndExpenseItem.Get() Then
		Items.DecorationDescription.Title =
			NStr("en = 'Since release 1.4.1, instead of GL accounts, income and expense items will be applied for the profit estimation of Sales orders.
				|Please map GL accounts to income and expense items. Otherwise, you will not be able to work with 1C:Drive.'; 
				|ru = 'Начиная с версии 1.4.1, для оценки прибыльности заказов покупателей вместо счетов учета будут применяться статьи доходов и расходов.
				|Необходимо сопоставить счета учета со статьями доходов и расходов. В противном случае вы не сможете работать с 1C:Drive.';
				|pl = 'Zaczynając od wydania 1.4.1, zamiast kont księgowych, do szacowania zysków Zamówień sprzedaży będą stosowane pozycje rozchodów i dochodów.
				|Zmapuj konta księgowe do pozycji dochodów i rozchodów. W przeciwnym razie nie można będzie pracować z 1C:Drive.';
				|es_ES = 'Desde la versión 1.4.1, en lugar de las cuentas del libro mayor, se aplicarán las partidas de ingresos y gastos para la estimación de beneficios de los pedidos de ventas. 
				|Por favor, asigne las cuentas del libro mayor a las partidas de ingresos y gastos. De lo contrario, no podrá trabajar con 1C:Drive.';
				|es_CO = 'Desde la versión 1.4.1, en lugar de las cuentas del libro mayor, se aplicarán las partidas de ingresos y gastos para la estimación de beneficios de los pedidos de ventas. 
				|Por favor, asigne las cuentas del libro mayor a las partidas de ingresos y gastos. De lo contrario, no podrá trabajar con 1C:Drive.';
				|tr = '1.4.1 sürümünden itibaren Satış siparişlerinin kar tahmini için Muhasebe hesapları yerine gelir ve gider kalemleri uygulanacak.
				|Lütfen, Muhasebe hesaplarını gelir ve gider kalemleriyle eşleştirin. Aksi takdirde, 1C:Drive ile çalışamazsınız.';
				|it = 'Dalla versione 1.4.1, invece dei conti mastro, le voci di entrata e uscita saranno applicate per la stima dell''utile degli Ordini cliente. 
				|Mappare i conti mastro in voci di entrata e uscita, altrimenti non sarà possibile lavorare con 1C:Drive.';
				|de = 'Seit Freigabe 1.4.1, werden Positionen von Einnahmen und Ausgaben statt Hauptbuch-Konten für die Gewinnschätzung von Kundenaufträgen verwendet.
				|Bitte mappen Sie Hauptbuch-Konten zu Positionen Einnahmen und Ausgaben. Sonst können Sie nicht mit 1C:Drive arbeiten.'");
	EndIf;
	
EndProcedure

&AtServer
Function IsEachGLAccoutMapped()
	
	MappingTable = GetMappingTable();
	
	If MappingTable.Count() = 0 Then
		Return True;
	EndIf;
	
	Return MappingTable.Find(Catalogs.IncomeAndExpenseItems.EmptyRef(), "IncomeAndExpenseItem") = Undefined;
	
EndFunction

&AtServer
Procedure FillMapping()
	
	Mapping.Load(GetMappingTable());
	
EndProcedure

&AtServer
Procedure FillProfitEstimationMapping()
	
	Mapping.Load(GetProfitEstimationMappingTable());
	
EndProcedure

&AtServer
Function GetMappingTable()
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text =
	"SELECT DISTINCT
	|	IncomeAndExpenses.GLAccount AS GLAccount,
	|	PrimaryChartOfAccounts.Description AS Description,
	|	CASE
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.Revenue)
	|	END AS IncomeAndExpenseType,
	|	UNDEFINED AS IsIncome
	|INTO TT_GLAccounts
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS IncomeAndExpenses
	|		INNER JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON IncomeAndExpenses.GLAccount = PrimaryChartOfAccounts.Ref
	|			AND (IncomeAndExpenses.GLAccount <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	IncomeAndExpensesBudget.GLAccount,
	|	PrimaryChartOfAccounts.Description,
	|	CASE
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.Revenue)
	|	END,
	|	UNDEFINED
	|FROM
	|	AccumulationRegister.IncomeAndExpensesBudget AS IncomeAndExpensesBudget
	|		INNER JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON IncomeAndExpensesBudget.GLAccount = PrimaryChartOfAccounts.Ref
	|			AND (IncomeAndExpensesBudget.GLAccount <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	FixedAssetParameters.GLExpenseAccount,
	|	PrimaryChartOfAccounts.Description,
	|	CASE
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.Revenue)
	|	END,
	|	UNDEFINED
	|FROM
	|	InformationRegister.FixedAssetParameters AS FixedAssetParameters
	|		INNER JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON FixedAssetParameters.GLExpenseAccount = PrimaryChartOfAccounts.Ref
	|			AND (FixedAssetParameters.GLExpenseAccount <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	FinancialResult.GLAccount,
	|	PrimaryChartOfAccounts.Description,
	|	CASE
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.Revenue)
	|	END,
	|	UNDEFINED
	|FROM
	|	AccumulationRegister.FinancialResult AS FinancialResult
	|		INNER JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON FinancialResult.GLAccount = PrimaryChartOfAccounts.Ref
	|			AND (FinancialResult.GLAccount <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	FinancialResultForecast.GLAccount,
	|	PrimaryChartOfAccounts.Description,
	|	CASE
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.Revenue)
	|	END,
	|	UNDEFINED
	|FROM
	|	AccumulationRegister.FinancialResultForecast AS FinancialResultForecast
	|		INNER JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON FinancialResultForecast.GLAccount = PrimaryChartOfAccounts.Ref
	|			AND (FinancialResultForecast.GLAccount <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	CompensationPlan.GLExpenseAccount,
	|	PrimaryChartOfAccounts.Description,
	|	CASE
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.Revenue)
	|	END,
	|	UNDEFINED
	|FROM
	|	InformationRegister.CompensationPlan AS CompensationPlan
	|		INNER JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON CompensationPlan.GLExpenseAccount = PrimaryChartOfAccounts.Ref
	|			AND (CompensationPlan.GLExpenseAccount <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	WriteOffCostAdjustment.GLAccount,
	|	PrimaryChartOfAccounts.Description,
	|	CASE
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.Revenue)
	|	END,
	|	UNDEFINED
	|FROM
	|	InformationRegister.WriteOffCostAdjustment AS WriteOffCostAdjustment
	|		INNER JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON WriteOffCostAdjustment.GLAccount = PrimaryChartOfAccounts.Ref
	|			AND (WriteOffCostAdjustment.GLAccount <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	EarningAndDeductionTypes.GLExpenseAccount,
	|	PrimaryChartOfAccounts.Description,
	|	CASE
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.Revenue)
	|	END,
	|	UNDEFINED
	|FROM
	|	Catalog.EarningAndDeductionTypes AS EarningAndDeductionTypes
	|		INNER JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON EarningAndDeductionTypes.GLExpenseAccount = PrimaryChartOfAccounts.Ref
	|			AND (EarningAndDeductionTypes.GLExpenseAccount <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	CounterpartiesGLAccounts.DiscountAllowed,
	|	PrimaryChartOfAccounts.Description,
	|	CASE
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.Revenue)
	|	END,
	|	UNDEFINED
	|FROM
	|	InformationRegister.CounterpartiesGLAccounts AS CounterpartiesGLAccounts
	|		INNER JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON CounterpartiesGLAccounts.DiscountAllowed = PrimaryChartOfAccounts.Ref
	|			AND (CounterpartiesGLAccounts.DiscountAllowed <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	CounterpartiesGLAccounts.DiscountReceived,
	|	PrimaryChartOfAccounts.Description,
	|	CASE
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.Revenue)
	|	END,
	|	UNDEFINED
	|FROM
	|	InformationRegister.CounterpartiesGLAccounts AS CounterpartiesGLAccounts
	|		INNER JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON CounterpartiesGLAccounts.DiscountReceived = PrimaryChartOfAccounts.Ref
	|			AND (CounterpartiesGLAccounts.DiscountReceived <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	ProductGLAccounts.Revenue,
	|	PrimaryChartOfAccounts.Description,
	|	CASE
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.Revenue)
	|	END,
	|	UNDEFINED
	|FROM
	|	InformationRegister.ProductGLAccounts AS ProductGLAccounts
	|		INNER JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON ProductGLAccounts.Revenue = PrimaryChartOfAccounts.Ref
	|			AND (ProductGLAccounts.Revenue <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	ProductGLAccounts.COGS,
	|	PrimaryChartOfAccounts.Description,
	|	CASE
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.Revenue)
	|	END,
	|	UNDEFINED
	|FROM
	|	InformationRegister.ProductGLAccounts AS ProductGLAccounts
	|		INNER JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON ProductGLAccounts.COGS = PrimaryChartOfAccounts.Ref
	|			AND (ProductGLAccounts.COGS <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	ProductGLAccounts.SalesReturn,
	|	PrimaryChartOfAccounts.Description,
	|	CASE
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.Revenue)
	|	END,
	|	UNDEFINED
	|FROM
	|	InformationRegister.ProductGLAccounts AS ProductGLAccounts
	|		INNER JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON ProductGLAccounts.SalesReturn = PrimaryChartOfAccounts.Ref
	|			AND (ProductGLAccounts.SalesReturn <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	ProductGLAccounts.PurchaseReturn,
	|	PrimaryChartOfAccounts.Description,
	|	CASE
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.Revenue)
	|	END,
	|	UNDEFINED
	|FROM
	|	InformationRegister.ProductGLAccounts AS ProductGLAccounts
	|		INNER JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON ProductGLAccounts.PurchaseReturn = PrimaryChartOfAccounts.Ref
	|			AND (ProductGLAccounts.PurchaseReturn <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	ProductGLAccounts.CostOfSales,
	|	PrimaryChartOfAccounts.Description,
	|	CASE
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.Revenue)
	|	END,
	|	UNDEFINED
	|FROM
	|	InformationRegister.ProductGLAccounts AS ProductGLAccounts
	|		INNER JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON ProductGLAccounts.CostOfSales = PrimaryChartOfAccounts.Ref
	|			AND (ProductGLAccounts.CostOfSales <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	DefaultGLAccounts.GLAccount,
	|	PrimaryChartOfAccounts.Description,
	|	CASE
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.Revenue)
	|	END,
	|	FALSE
	|FROM
	|	Catalog.DefaultGLAccounts AS DefaultGLAccounts
	|		INNER JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON DefaultGLAccounts.GLAccount = PrimaryChartOfAccounts.Ref
	|			AND (DefaultGLAccounts.GLAccount <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|			AND (DefaultGLAccounts.Ref = VALUE(Catalog.DefaultGLAccounts.CommissionExpensesOnLoansBorrowed))
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	DefaultGLAccounts.GLAccount,
	|	PrimaryChartOfAccounts.Description,
	|	CASE
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.Revenue)
	|	END,
	|	TRUE
	|FROM
	|	Catalog.DefaultGLAccounts AS DefaultGLAccounts
	|		INNER JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON DefaultGLAccounts.GLAccount = PrimaryChartOfAccounts.Ref
	|			AND (DefaultGLAccounts.GLAccount <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|			AND (DefaultGLAccounts.Ref = VALUE(Catalog.DefaultGLAccounts.CommissionIncomeOnLoansLent))
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	SalesOrderEstimate.Products,
	|	PrimaryChartOfAccounts.Description,
	|	CASE
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.Revenue)
	|	END,
	|	UNDEFINED
	|FROM
	|	Document.SalesOrder.Estimate AS SalesOrderEstimate
	|		INNER JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON SalesOrderEstimate.Products = PrimaryChartOfAccounts.Ref
	|			AND (SalesOrderEstimate.Products <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT
	|	Inventory.GLAccount,
	|	PrimaryChartOfAccounts.Description,
	|	VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads),
	|	FALSE
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|		INNER JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON Inventory.GLAccount = PrimaryChartOfAccounts.Ref
	|			AND (Inventory.GLAccount <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|			AND (PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses))
	|
	|UNION ALL
	|
	|SELECT
	|	Inventory.CorrGLAccount,
	|	PrimaryChartOfAccounts.Description,
	|	VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads),
	|	FALSE
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|		INNER JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON Inventory.CorrGLAccount = PrimaryChartOfAccounts.Ref
	|			AND (Inventory.CorrGLAccount <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|			AND (PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses))
	|
	|UNION ALL
	|
	|SELECT
	|	PrimaryChartOfAccounts.Ref,
	|	PrimaryChartOfAccounts.Description,
	|	CASE
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.Revenue)
	|	END,
	|	UNDEFINED
	|FROM
	|	ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|WHERE
	|	PrimaryChartOfAccounts.FinancialStatement = VALUE(Enum.FinancialStatement.ProfitAndLossStatement)
	|	AND PrimaryChartOfAccounts.TypeOfAccount IN (VALUE(Enum.GLAccountsTypes.CostOfSales), VALUE(Enum.GLAccountsTypes.Expenses), VALUE(Enum.GLAccountsTypes.IndirectExpenses), VALUE(Enum.GLAccountsTypes.OtherExpenses), VALUE(Enum.GLAccountsTypes.OtherIncome), VALUE(Enum.GLAccountsTypes.Revenue))
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	SalesOrderEstimate.Products,
	|	PrimaryChartOfAccounts.Description,
	|	CASE
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.Revenue)
	|	END,
	|	UNDEFINED
	|FROM
	|	Document.SalesOrder.Estimate AS SalesOrderEstimate
	|		INNER JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON SalesOrderEstimate.Products = PrimaryChartOfAccounts.Ref";
	
	// begin Drive.FullVersion
	Query.Text = Query.Text + DriveClientServer.GetQueryUnion() + "
	|
	|SELECT DISTINCT
	|	PredeterminedOverheadRates.OverheadsGLAccount,
	|	PrimaryChartOfAccounts.Description,
	|	CASE
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.Revenue)
	|	END,
	|	UNDEFINED
	|FROM
	|	InformationRegister.PredeterminedOverheadRates AS PredeterminedOverheadRates
	|		INNER JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON PredeterminedOverheadRates.OverheadsGLAccount = PrimaryChartOfAccounts.Ref
	|			AND (PredeterminedOverheadRates.OverheadsGLAccount <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))";
	// end Drive.FullVersion
	
	Query.Execute();
	
	Query.Text =
	"SELECT DISTINCT
	|	TT_GLAccounts.GLAccount AS GLAccount,
	|	ISNULL(MappingGLAccountsToIncomeAndExpenseItemsSliceLast.IncomeAndExpenseItem, ISNULL(IncomeAndExpenseItems.Ref, VALUE(Catalog.IncomeAndExpenseItems.Undefined))) AS IncomeAndExpenseItem,
	|	CASE
	|		WHEN ISNULL(MappingGLAccountsToIncomeAndExpenseItemsSliceLast.IncomeAndExpenseItem, ISNULL(IncomeAndExpenseItems.Ref, VALUE(Catalog.IncomeAndExpenseItems.Undefined))) = VALUE(Catalog.IncomeAndExpenseItems.Undefined)
	|			THEN 0
	|		ELSE 1
	|	END AS Order,
	|	&ViewDocuments AS ViewDocuments
	|FROM
	|	TT_GLAccounts AS TT_GLAccounts
	|		LEFT JOIN Catalog.IncomeAndExpenseItems AS IncomeAndExpenseItems
	|		ON TT_GLAccounts.Description = IncomeAndExpenseItems.Description
	|			AND TT_GLAccounts.IncomeAndExpenseType = IncomeAndExpenseItems.IncomeAndExpenseType
	|			AND (CASE
	|				WHEN TT_GLAccounts.IsIncome = UNDEFINED
	|					THEN TRUE
	|				ELSE TT_GLAccounts.IsIncome = IncomeAndExpenseItems.IsIncome
	|			END)
	|		LEFT JOIN InformationRegister.MappingGLAccountsToIncomeAndExpenseItems.SliceLast AS MappingGLAccountsToIncomeAndExpenseItemsSliceLast
	|		ON TT_GLAccounts.GLAccount = MappingGLAccountsToIncomeAndExpenseItemsSliceLast.GLAccount
	|
	|ORDER BY
	|	Order,
	|	TT_GLAccounts.GLAccount.Order";
	
	Query.SetParameter("ViewDocuments", NStr("en = 'View documents...'; ru = 'Просмотреть документы...';pl = 'Wyświetl dokumenty...';es_ES = 'Visualización de documentos...';es_CO = 'Visualización de documentos...';tr = 'Belgeleri görüntüle...';it = 'Visualizzazione documenti...';de = 'Dokumenten anzeigen...'"));
	
	Return Query.Execute().Unload();
	
EndFunction

&AtServer
Function GetProfitEstimationMappingTable()
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	SalesOrderEstimate.Products AS GLAccount,
	|	PrimaryChartOfAccounts.Description AS Description,
	|	CASE
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.OtherIncome)
	|		WHEN PrimaryChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
	|			THEN VALUE(Catalog.IncomeAndExpenseTypes.Revenue)
	|	END AS IncomeAndExpenseType,
	|	UNDEFINED AS IsIncome
	|INTO TT_GLAccounts
	|FROM
	|	Document.SalesOrder.Estimate AS SalesOrderEstimate
	|		INNER JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON SalesOrderEstimate.Products = PrimaryChartOfAccounts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TT_GLAccounts.GLAccount AS GLAccount,
	|	ISNULL(MappingGLAccountsToIncomeAndExpenseItemsSliceLast.IncomeAndExpenseItem, ISNULL(IncomeAndExpenseItems.Ref, VALUE(Catalog.IncomeAndExpenseItems.Undefined))) AS IncomeAndExpenseItem,
	|	CASE
	|		WHEN ISNULL(MappingGLAccountsToIncomeAndExpenseItemsSliceLast.IncomeAndExpenseItem, ISNULL(IncomeAndExpenseItems.Ref, VALUE(Catalog.IncomeAndExpenseItems.Undefined))) = VALUE(Catalog.IncomeAndExpenseItems.Undefined)
	|			THEN 0
	|		ELSE 1
	|	END AS Order,
	|	&ViewDocuments AS ViewDocuments
	|FROM
	|	TT_GLAccounts AS TT_GLAccounts
	|		LEFT JOIN Catalog.IncomeAndExpenseItems AS IncomeAndExpenseItems
	|		ON TT_GLAccounts.Description = IncomeAndExpenseItems.Description
	|			AND TT_GLAccounts.IncomeAndExpenseType = IncomeAndExpenseItems.IncomeAndExpenseType
	|			AND (CASE
	|				WHEN TT_GLAccounts.IsIncome = UNDEFINED
	|					THEN TRUE
	|				ELSE TT_GLAccounts.IsIncome = IncomeAndExpenseItems.IsIncome
	|			END)
	|		LEFT JOIN InformationRegister.MappingGLAccountsToIncomeAndExpenseItems.SliceLast AS MappingGLAccountsToIncomeAndExpenseItemsSliceLast
	|		ON TT_GLAccounts.GLAccount = MappingGLAccountsToIncomeAndExpenseItemsSliceLast.GLAccount
	|
	|ORDER BY
	|	Order,
	|	TT_GLAccounts.GLAccount.Order";
	
	Query.SetParameter("ViewDocuments", NStr("en = 'View documents...'; ru = 'Просмотреть документы...';pl = 'Wyświetl dokumenty...';es_ES = 'Visualización de documentos...';es_CO = 'Visualización de documentos...';tr = 'Belgeleri görüntüle...';it = 'Visualizzazione documenti...';de = 'Dokumenten anzeigen...'"));
	
	Return Query.Execute().Unload();
	
EndFunction

&AtServer
Function SaveMappingAtServer()
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Data processing...'; ru = 'Обработка данных...';pl = 'Przetwarzanie danych...';es_ES = 'Procesamiento de datos...';es_CO = 'Procesamiento de datos...';tr = 'Veri işleniyor...';it = 'Elaborazione dati...';de = 'Datenverarbeitung...'");
	
	If Constants.EachGLAccountIsMappedToIncomeAndExpenseItem.Get() Then
		
		ProcedureParameters = New Structure;
		ProcedureParameters.Insert("MappingTable", Mapping.Unload());
		
		Return TimeConsumingOperations.ExecuteInBackground(
			"DataProcessors.MappingGLAccountsToIncomeAndExpenseItems.SaveProfitEstimationMapping",
			ProcedureParameters, 
			ExecutionParameters);
		
	EndIf;
	
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	ProcedureParameters.Insert("MappingTable", Mapping.Unload());
	
	Return TimeConsumingOperations.ExecuteInBackground(
		"DataProcessors.MappingGLAccountsToIncomeAndExpenseItems.SaveMapping",
		ProcedureParameters, 
		ExecutionParameters);
	
EndFunction

&AtServerNoContext
Procedure SetConstantValues(UseDefaultTypeOfAccounting = Undefined)
	
	If UseDefaultTypeOfAccounting <> Undefined Then
		Constants.UseDefaultTypeOfAccounting.Set(UseDefaultTypeOfAccounting);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function IsEmptyDefaultItems()
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
	|	DefaultIncomeAndExpenseItems.Ref AS Ref
	|FROM
	|	Catalog.DefaultIncomeAndExpenseItems AS DefaultIncomeAndExpenseItems
	|WHERE
	|	DefaultIncomeAndExpenseItems.IncomeAndExpenseItem = VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

&AtServerNoContext
Procedure FillInPOSTerminalsExpenseItems(OtherExpenses)
	
	Query = New Query;
	Query.Text = "SELECT
	|	POSTerminals.Ref AS Ref
	|FROM
	|	Catalog.POSTerminals AS POSTerminals
	|WHERE
	|	NOT POSTerminals.DeletionMark
	|	AND POSTerminals.ExpenseItem = VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		POS = Selection.Ref.GetObject();
		POS.ExpenseItem = OtherExpenses;
		InfobaseUpdate.WriteObject(POS);
	EndDo;
	
EndProcedure

#EndRegion





