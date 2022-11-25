
#Region GeneralPurposeProceduresAndFunctions

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetCompanyDataOnChange(Company, DocumentCurrency)
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"Counterparty",
		DriveServer.GetCompany(Company)		
	);
	
	If Company = Catalogs.Companies.EmptyRef() Then
		DocumentCurrency = Catalogs.Currencies.EmptyRef()
	Else
		DocumentCurrency = DriveServer.GetPresentationCurrency(Company);
	EndIf;
	
	Return StructureData;
	
EndFunction

// Calculates the assets depreciation.
//
&AtServerNoContext
Procedure CalculateDepreciation(AddressFixedAssetsInStorage, Date, ParentCompany)
	
	TableFixedAssets = GetFromTempStorage(AddressFixedAssetsInStorage);
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	Query.SetParameter("Period", Date);
	Query.SetParameter("Company", ParentCompany);
	Query.SetParameter("BegOfYear", BegOfYear(Date));
	Query.SetParameter("BeginOfPeriod", BegOfMonth(Date));
	Query.SetParameter("EndOfPeriod", EndOfMonth(Date));
	Query.SetParameter("FixedAssetsList", TableFixedAssets.UnloadColumn("FixedAsset"));
	Query.SetParameter("TableFixedAssets", TableFixedAssets);
	
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
	|	TableFixedAssets.FixedAsset AS FixedAsset
	|INTO TableFixedAssets
	|FROM
	|	&TableFixedAssets AS TableFixedAssets
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableFixedAssets.LineNumber AS LineNumber,
	|	TableFixedAssets.FixedAsset AS FixedAsset,
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
	
	QueryResult = Query.ExecuteBatch();
	
	DepreciationTable = QueryResult[4].Unload();
	
	PutToTempStorage(DepreciationTable, AddressFixedAssetsInStorage);
	
EndProcedure

// The function puts the FixedAssets tabular section
// to the temporary storage and returns an address
//
&AtServer
Function PlaceFixedAssetsToStorage()
	
	Return PutToTempStorage(
		Object.FixedAssets.Unload(,
			"LineNumber,
			|FixedAsset"
		),
		UUID
	);
	
EndFunction

// The function receives the FixedAssets tabular section from the temporary storage.
//
&AtServer
Procedure GetFixedAssetsFromStorage(AddressFixedAssetsInStorage)
	
	TableFixedAssets = GetFromTempStorage(AddressFixedAssetsInStorage);
	Object.FixedAssets.Clear();
	For Each RowFixedAssets In TableFixedAssets Do
		
		String = Object.FixedAssets.Add();
		FillPropertyValues(String, RowFixedAssets);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure SetFixedAssetsCalculatedEnabled()
	
	Items.FixedAssetsCalculated.Enabled = Not Object.Posted;
	
EndProcedure

&AtClient
Procedure IncomeAndExpenseItemsOnChangeConditions()
	
	Items.ExpenseItem.Visible = Not UseDefaultTypeOfAccounting
									Or IsIncomeAndExpenseGLA(Object.Correspondence);
	Items.ExpenseItem.Enabled = Object.RegisterExpense;
	
	If Items.RegisterExpense.Visible Then
		Items.ExpenseItem.TitleLocation = FormItemTitleLocation.None;
	Else
		Items.ExpenseItem.TitleLocation = FormItemTitleLocation.Auto;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function IsIncomeAndExpenseGLA(Correspondence)
	Return GLAccountsInDocuments.IsIncomeAndExpenseGLA(Correspondence);
EndFunction

&AtClient
Procedure SetDefaultValueForIncomeAndExpenseItem()
	
	If Items.ExpenseItem.Visible And Not ValueIsFilled(Object.ExpenseItem) 
		And Object.RegisterExpense Then
		Object.ExpenseItem = DefaultExpenseItem;
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - event handler "OnCreateAtServer".
// The procedure implements
// - initialization of form parameters,
// - setting of the form functional options parameters.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(Object,
	,
	Parameters.CopyingValue,
	Parameters.Basis,
	PostingIsAllowed,
	Parameters.FillingValues);
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	If Object.Company = Catalogs.Companies.EmptyRef() Then
		DocumentCurrency = Catalogs.Currencies.EmptyRef()
	Else 
		DocumentCurrency = DriveServer.GetPresentationCurrency(Object.Company);
	EndIf;
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	IncomeAndExpenseItemsInDocuments.SetRegistrationAttributesVisibility(ThisObject,
		"RegisterExpense", Not UseDefaultTypeOfAccounting);
	
	DefaultExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("OtherExpenses");
	If Object.Ref.IsEmpty() Then
		Object.RegisterExpense = Not UseDefaultTypeOfAccounting
									Or IsIncomeAndExpenseGLA(Object.Correspondence);
		If Object.RegisterExpense Then
			Object.ExpenseItem = DefaultExpenseItem;
		EndIf;
	EndIf;
	
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
	
	SetFixedAssetsCalculatedEnabled();
	IncomeAndExpenseItemsOnChangeConditions();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
// Procedure - event handler AfterWriting.
//
Procedure AfterWrite(WriteParameters)
	
	SetFixedAssetsCalculatedEnabled();
	
	Notify("FixedAssetsStatesUpdate");
	Notify("RefreshAccountingTransaction");
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
		
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	

EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure - the Calculate command action handler.
//
&AtClient
Procedure Calculate(Command)
	
	If Object.Posted Then
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("CalculateEnd", ThisObject);
	
	If Object.FixedAssets.Count() > 0 Then
		ShowQueryBox(NotifyDescription,
			NStr("en = 'Entered data will be recalculated. Continue?'; ru = 'Введенные данные будут пересчитаны! Продолжить?';pl = 'Wprowadzone dane zostaną przeliczone. Kontynuować?';es_ES = 'Datos introducidos se recalcularán. ¿Continuar?';es_CO = 'Datos introducidos se recalcularán. ¿Continuar?';tr = 'Girilen veriler yeniden hesaplanacaktır. Devam et?';it = 'I dati inseriti verranno ricalcolati. Proseguire?';de = 'Die eingegebenen Daten werden neu berechnet. Fortsetzen?'"), 
			QuestionDialogMode.YesNo);
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure CalculateEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	CalculateEndAtServer(Object.Date, ParentCompany);
	
EndProcedure

&AtServer
Procedure CalculateEndAtServer(Date, ParentCompany) Export
	
	AddressFixedAssetsInStorage = PlaceFixedAssetsToStorage();
	CalculateDepreciation(AddressFixedAssetsInStorage, Date, ParentCompany);
	GetFixedAssetsFromStorage(AddressFixedAssetsInStorage);
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "");
	
EndProcedure

// Procedure - event handler OnChange of the Company input field.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company, DocumentCurrency);
	Counterparty = StructureData.Counterparty;
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

// Procedure - OnChange event handler of
// the Cost edit box of the FixedAssets tabular section.
//
&AtClient
Procedure FixedAssetsCostOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	TabularSectionRow.DepreciatedCost = TabularSectionRow.Cost - TabularSectionRow.Depreciation;
	
EndProcedure

// Procedure - OnChange event handler of
// the Depreciation edit box of the FixedAssets tabular section.
//
&AtClient
Procedure FixedAssetsDepreciationOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	TabularSectionRow.Depreciation = ?(
		TabularSectionRow.Depreciation > TabularSectionRow.Cost,
		TabularSectionRow.Cost,
		TabularSectionRow.Depreciation
	);
	TabularSectionRow.DepreciatedCost = TabularSectionRow.Cost - TabularSectionRow.Depreciation;
	DepreciationInCurrentMonthMax = TabularSectionRow.Cost - TabularSectionRow.Depreciation;
	TabularSectionRow.MonthlyDepreciation = ?(
		TabularSectionRow.MonthlyDepreciation > DepreciationInCurrentMonthMax,
		DepreciationInCurrentMonthMax,
		TabularSectionRow.MonthlyDepreciation
	);
	
EndProcedure

// Procedure - OnChange event handler of
// the ResidualCost edit box of the FixedAssets tabular section.
//
&AtClient
Procedure FixedAssetsDepreciatedCostOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	TabularSectionRow.DepreciatedCost = ?(
		TabularSectionRow.DepreciatedCost > TabularSectionRow.Cost,
		TabularSectionRow.Cost,
		TabularSectionRow.DepreciatedCost
	);
	TabularSectionRow.Depreciation = TabularSectionRow.Cost - TabularSectionRow.DepreciatedCost;
	DepreciationInCurrentMonthMax = TabularSectionRow.Cost - TabularSectionRow.Depreciation;
	TabularSectionRow.MonthlyDepreciation = ?(
		TabularSectionRow.MonthlyDepreciation > DepreciationInCurrentMonthMax,
		DepreciationInCurrentMonthMax,
		TabularSectionRow.MonthlyDepreciation
	);
	
EndProcedure

// Procedure - OnChange event handler of
// the DepreciationForMonth edit box of the FixedAssets tabular section.
//
&AtClient
Procedure FixedAssetsDepreciationForMonthOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	DepreciationInCurrentMonthMax = TabularSectionRow.Cost - TabularSectionRow.Depreciation;
	TabularSectionRow.MonthlyDepreciation = ?(
		TabularSectionRow.MonthlyDepreciation > DepreciationInCurrentMonthMax,
		DepreciationInCurrentMonthMax,
		TabularSectionRow.MonthlyDepreciation
	);
	
EndProcedure

&AtClient
Procedure CorrespondenceOnChange(Item)
	
	Structure = New Structure("Object,Correspondence,ExpenseItem,Manual");
	Structure.Object = Object;
	FillPropertyValues(Structure, Object);
	
	GLAccountsInDocumentsServerCall.CheckItemRegistration(Structure);
	FillPropertyValues(Object, Structure);
	
	IncomeAndExpenseItemsOnChangeConditions();
	SetDefaultValueForIncomeAndExpenseItem();
	
EndProcedure

&AtClient
Procedure RegisterExpenseOnChange(Item)
	
	If Not Object.RegisterExpense Then
		Object.ExpenseItem = PredefinedValue("Catalog.IncomeAndExpenseItems.EmptyRef");
	EndIf;
	
	IncomeAndExpenseItemsOnChangeConditions();
	SetDefaultValueForIncomeAndExpenseItem();
	
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

