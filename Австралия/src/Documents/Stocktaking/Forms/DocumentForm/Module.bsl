
#Region FormEventHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues
	);
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	FunctionalCurrency = Constants.FunctionalCurrency.Get();
	
	SetCellVisible();
	
	// Setting the method of Business unit selection depending on FO.
	If Not Constants.UseSeveralDepartments.Get()
		AND Not Constants.UseSeveralWarehouses.Get() Then
		
		Items.StructuralUnit.ListChoiceMode = True;
		Items.StructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		Items.StructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		
	EndIf;
	
	ResetFilterSettings();
	
	//Conditional appearance
	SetConditionalAppearance();
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.Stocktaking.TabularSections.Inventory, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// Peripherals
	UsePeripherals = DriveReUse.UsePeripherals();
	ListOfElectronicScales = EquipmentManagerServerCall.GetEquipmentList("ElectronicScales", , EquipmentManagerServerCall.GetClientWorkplace());
	If ListOfElectronicScales.Count() = 0 Then
		// There are no connected scales.
		Items.InventoryGetWeight.Visible = False;
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	// End Peripherals
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
	Items.InventoryDataImportFromExternalSources.Visible =
		AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
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
	
EndProcedure

// Procedure - event handler BeforeWriteAtServer.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	FilterSettingsStructure = New Structure;
	FilterSettingsStructure.Insert("ProductsList", ProductsList);
	FilterSettingsStructure.Insert("ListProductsGroups", ListProductsGroups);
	FilterSettingsStructure.Insert("ProductsGroupsList", ProductsGroupsList);
	
	CurrentObject.SettingsOfFilters = New ValueStorage(FilterSettingsStructure);
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	UpdateFilterHeaders();
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
EndProcedure

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose(Exit)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals"
	   AND IsInputAvailable() Then
		If EventName = "ScanData" Then
			// Transform preliminary to the expected format
			Data = New Array();
			If Parameter[1] = Undefined Then
				Data.Add(New Structure("Barcode, Quantity", Parameter[0], 1)); // Get a barcode from the basic data
			Else
				Data.Add(New Structure("Barcode, Quantity", Parameter[1][1], 1)); // Get a barcode from the additional data
			EndIf;
			
			BarcodesReceived(Data);
		EndIf;
	EndIf;
	// End Peripherals
	
	If EventName = "SerialNumbersSelection"
		AND ValueIsFilled(Parameter) 
		// Form owner checkup
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID
		Then
		
		ChangedCount = GetSerialNumbersFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
		If ChangedCount Then
			CalculateAmountInTabularSectionLine();
		EndIf; 
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// The function returns the query text for the balances at warehouse.
//
&AtServer
Function GenerateQueryTextByWarehouseBalances()
	
	QueryText =
	"SELECT
	|	FALSE AS FlagInCell,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Products.MeasurementUnit AS MeasurementUnit,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.Ownership AS Ownership,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityAccounting,
	|	SUM(InventoryBalances.AmountBalance) AS AmountAccounting,
	|	SUM(InventoryBalances.QuantityBalance) AS Quantity,
	|	SUM(InventoryBalances.AmountBalance) AS Amount
	|INTO InventoryBalanceReconciliation
	|FROM
	|	AccumulationRegister.Inventory.Balance(
	|			&Period,
	|			Company = &Company
	|				AND StructuralUnit = &StructuralUnit
	|				AND Products IN (&ProductsList)
	|				AND Products IN HIERARCHY (&ListProductsGroups)
	|				AND Products.ProductsCategory IN (&ProductsGroupsList)) AS InventoryBalances
	|WHERE
	|	InventoryBalances.Products <> VALUE(Catalog.Products.EmptyRef)
	|
	|GROUP BY
	|	InventoryBalances.Batch,
	|	InventoryBalances.Ownership,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Products.MeasurementUnit";
	
	Return QueryText;
	
EndFunction

// The function returns the query text for the balances in a cell at the warehouse.
//
&AtServer
Function FormQueryTextOnBalancesInCellInWarehouse()
	
	QueryText =
	"SELECT
	|	TRUE AS FlagInCell,
	|	InventoryInWarehousesOfBalance.Products AS Products,
	|	InventoryInWarehousesOfBalance.Products.MeasurementUnit AS MeasurementUnit,
	|	InventoryInWarehousesOfBalance.Characteristic AS Characteristic,
	|	InventoryInWarehousesOfBalance.Batch AS Batch,
	|	InventoryInWarehousesOfBalance.Ownership AS Ownership,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityAccounting,
	|	SUM(InventoryBalances.AmountBalance) AS AmountAccounting,
	|	SUM(InventoryInWarehousesOfBalance.QuantityBalance) AS Quantity,
	|	SUM(InventoryBalances.AmountBalance) AS Amount
	|INTO InventoryBalanceReconciliation
	|FROM
	|	AccumulationRegister.InventoryInWarehouses.Balance(
	|			&Period,
	|			Company = &Company
	|				AND StructuralUnit = &StructuralUnit
	|				AND Cell = &Cell
	|				AND Products IN (&ProductsList)
	|				AND Products IN HIERARCHY (&ListProductsGroups)
	|				AND Products.ProductsCategory IN (&ProductsGroupsList)) AS InventoryInWarehousesOfBalance
	|		LEFT JOIN AccumulationRegister.Inventory.Balance(
	|				&Period,
	|				Company = &Company
	|					AND StructuralUnit = &StructuralUnit
	|					AND Products IN (&ProductsList)
	|					AND Products IN HIERARCHY (&ListProductsGroups)
	|					AND Products.ProductsCategory IN (&ProductsGroupsList)) AS InventoryBalances
	|		ON InventoryInWarehousesOfBalance.Products = InventoryBalances.Products
	|			AND InventoryInWarehousesOfBalance.Characteristic = InventoryBalances.Characteristic
	|			AND InventoryInWarehousesOfBalance.Batch = InventoryBalances.Batch
	|			AND InventoryInWarehousesOfBalance.Ownership = InventoryBalances.Ownership
	|
	|GROUP BY
	|	InventoryInWarehousesOfBalance.Batch,
	|	InventoryInWarehousesOfBalance.Ownership,
	|	InventoryInWarehousesOfBalance.Products,
	|	InventoryInWarehousesOfBalance.Characteristic,
	|	InventoryInWarehousesOfBalance.Products.MeasurementUnit";
	
	Return QueryText;
	
EndFunction

// The function returns the query text by accounting data of the warehouse.
//
&AtServer
Function GenerateQueryTextAccountingDataAtWarehouse()
	
	QueryText =
	"SELECT
	|	FALSE AS FlagInCell,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Products.MeasurementUnit AS MeasurementUnit,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.Ownership AS Ownership,
	|	SUM(InventoryBalances.QuantityBalance) AS Quantity,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityAccounting,
	|	SUM(InventoryBalances.AmountBalance) AS AmountAccounting
	|INTO TemporaryTableInventoryBalances
	|FROM
	|	AccumulationRegister.Inventory.Balance(
	|			&Period,
	|			Company = &Company
	|				AND StructuralUnit = &StructuralUnit
	|				AND (Products, Characteristic, Batch, Ownership) IN
	|					(SELECT
	|						Stocktaking.Products AS Products,
	|						Stocktaking.Characteristic AS Characteristic,
	|						Stocktaking.Batch AS Batch,
	|						Stocktaking.Ownership AS Ownership
	|					FROM
	|						Stocktaking AS Stocktaking)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Products,
	|	InventoryBalances.Products.MeasurementUnit,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.Ownership
	|
	|INDEX BY
	|	Products,
	|	Characteristic,
	|	Batch,
	|	Ownership";
	
	Return QueryText + Chars.LF +
		";
		|
		|////////////////////////////////////////////////////////////////////////////////"
		+ Chars.LF;
	
EndFunction

// The function returns the query text for the accounting data in a cells of the warehouse.
//
&AtServer
Function IssueQueryTextAccountsDataInCellInInventory()
	
	QueryText =
	"SELECT ALLOWED
	|	TRUE AS FlagInCell,
	|	InventoryInWarehousesOfBalance.Products AS Products,
	|	InventoryInWarehousesOfBalance.Products.MeasurementUnit AS MeasurementUnit,
	|	InventoryInWarehousesOfBalance.Characteristic AS Characteristic,
	|	InventoryInWarehousesOfBalance.Batch AS Batch,
	|	InventoryInWarehousesOfBalance.Ownership AS Ownership,
	|	SUM(InventoryInWarehousesOfBalance.QuantityBalance) AS Quantity,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityAccounting,
	|	SUM(InventoryBalances.AmountBalance) AS AmountAccounting
	|INTO TemporaryTableInventoryBalances
	|FROM
	|	AccumulationRegister.InventoryInWarehouses.Balance(
	|			&Period,
	|			Company = &Company
	|				AND StructuralUnit = &StructuralUnit
	|				AND Cell = &Cell
	|				AND (Products, Characteristic, Batch, Ownership) IN
	|					(SELECT
	|						Stocktaking.Products AS Products,
	|						Stocktaking.Characteristic AS Characteristic,
	|						Stocktaking.Batch AS Batch,
	|						Stocktaking.Ownership AS Ownership
	|					FROM
	|						Stocktaking AS Stocktaking)) AS InventoryInWarehousesOfBalance
	|		LEFT JOIN AccumulationRegister.Inventory.Balance(
	|				&Period,
	|				Company = &Company
	|					AND StructuralUnit = &StructuralUnit) AS InventoryBalances
	|		ON InventoryInWarehousesOfBalance.Products = InventoryBalances.Products
	|			AND InventoryInWarehousesOfBalance.Characteristic = InventoryBalances.Characteristic
	|			AND InventoryInWarehousesOfBalance.Batch = InventoryBalances.Batch
	|			AND InventoryInWarehousesOfBalance.Ownership = InventoryBalances.Ownership
	|
	|GROUP BY
	|	InventoryInWarehousesOfBalance.Products,
	|	InventoryInWarehousesOfBalance.Products.MeasurementUnit,
	|	InventoryInWarehousesOfBalance.Characteristic,
	|	InventoryInWarehousesOfBalance.Batch,
	|	InventoryInWarehousesOfBalance.Ownership
	|
	|INDEX BY
	|	Products,
	|	Characteristic,
	|	Batch,
	|	Ownership";
	
	Return QueryText + Chars.LF +
		";
		|
		|////////////////////////////////////////////////////////////////////////////////"
		+ Chars.LF;
	
EndFunction

// The procedure fills in the "Inventory" tabular section by
// balance
&AtServer
Procedure FillByBalanceAtWarehouse()
	
	Object.Inventory.Clear();
	Object.SerialNumbers.Clear();
	
	ThereIsFilterByProducts = ProductsList.Count() > 0;
	ThereIsFilterByProductsGroups = ListProductsGroups.Count() > 0;
	ThereIsFilterByProductsCategories = ProductsGroupsList.Count() > 0;
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	If ValueIsFilled(Object.Cell) Then
		Query.Text = FormQueryTextOnBalancesInCellInWarehouse();
		Query.SetParameter("Cell", Object.Cell);
	Else
		Query.Text = GenerateQueryTextByWarehouseBalances();
	EndIf;
	
	Query.SetParameter("Period", EndOfDay(Object.Date));
	Query.SetParameter("Company", ParentCompany);
	Query.SetParameter("StructuralUnit", Object.StructuralUnit);
	
	If ThereIsFilterByProducts Then
		Query.SetParameter("ProductsList", ProductsList);
	Else
		Query.Text = StrReplace(Query.Text, "AND Products IN (&ProductsList)", "");
	EndIf;
	
	If ThereIsFilterByProductsGroups Then
		Query.SetParameter("ListProductsGroups", ListProductsGroups);
	Else
		Query.Text = StrReplace(Query.Text, "AND Products IN HIERARCHY (&ListProductsGroups)", "");
	EndIf;
	
	If ThereIsFilterByProductsCategories Then
		Query.SetParameter("ProductsGroupsList", ProductsGroupsList);
	Else
		Query.Text = StrReplace(Query.Text, "AND Products.ProductsCategory IN (&ProductsGroupsList)", "");
	EndIf;
	
	Query.Execute();
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	CASE
	|		WHEN CtlProducts.Parent = VALUE(Catalog.Products.EmptyRef)
	|				AND Not CtlProducts.IsFolder
	|			THEN 0
	|		ELSE 1
	|	END AS Order,
	|	CtlProducts.Description AS Description,
	|	InventoryBalanceReconciliation.Products AS Products,
	|	InventoryBalanceReconciliation.MeasurementUnit AS MeasurementUnit,
	|	InventoryBalanceReconciliation.Characteristic AS Characteristic,
	|	InventoryBalanceReconciliation.Batch AS Batch,
	|	InventoryBalanceReconciliation.Ownership AS Ownership,
	|	ISNULL(InventoryBalanceReconciliation.QuantityAccounting, 0) AS QuantityAccounting,
	|	ISNULL(InventoryBalanceReconciliation.AmountAccounting, 0) AS AmountAccounting,
	|	CASE
	|		WHEN ISNULL(InventoryBalanceReconciliation.QuantityAccounting, 0) <= 0
	|				OR ISNULL(InventoryBalanceReconciliation.Amount, 0) = 0
	|			THEN 0
	|		ELSE ISNULL(InventoryBalanceReconciliation.Amount, 0) / ISNULL(InventoryBalanceReconciliation.QuantityAccounting, 0)
	|	END AS PriceAccount,
	|	ISNULL(InventoryBalanceReconciliation.Quantity, 0) AS Quantity,
	|	ISNULL(InventoryBalanceReconciliation.Amount, 0) AS Amount,
	|	CASE
	|		WHEN InventoryBalanceReconciliation.FlagInCell
	|			THEN CASE
	|					WHEN ISNULL(InventoryBalanceReconciliation.Quantity, 0) < 0
	|						THEN -ISNULL(InventoryBalanceReconciliation.Quantity, 0)
	|					ELSE 0
	|				END
	|		ELSE CASE
	|				WHEN ISNULL(InventoryBalanceReconciliation.QuantityAccounting, 0) < 0
	|					THEN -ISNULL(InventoryBalanceReconciliation.QuantityAccounting, 0)
	|				ELSE 0
	|			END
	|	END AS Deviation
	|FROM
	|	Catalog.Products AS CtlProducts
	|		LEFT JOIN InventoryBalanceReconciliation AS InventoryBalanceReconciliation
	|		ON CtlProducts.Ref = InventoryBalanceReconciliation.Products
	|WHERE
	|	CtlProducts.Ref IN (&ProductsList)
	|	AND CtlProducts.Ref IN HIERARCHY(&ListProductsGroups)
	|	AND CtlProducts.ProductsCategory IN(&ProductsGroupsList)
	|
	|ORDER BY
	|	Order DESC,
	|	Description HIERARCHY";
	
	If ThereIsFilterByProducts Then
		Query.SetParameter("ProductsList", ProductsList);
	Else
		Query.Text = StrReplace(Query.Text, "CtlProducts.Ref IN (&ProductsList)", "TRUE");
	EndIf;
	
	If ThereIsFilterByProductsGroups Then
		Query.SetParameter("ListProductsGroups", ListProductsGroups);
	Else
		Query.Text = StrReplace(Query.Text, "AND CtlProducts.Ref IN HIERARCHY(&ListProductsGroups)", "");
	EndIf;
	
	If ThereIsFilterByProductsCategories Then
		Query.SetParameter("ProductsGroupsList", ProductsGroupsList);
	Else
		Query.Text = StrReplace(Query.Text, "AND CtlProducts.ProductsCategory IN(&ProductsGroupsList)", "");
	EndIf;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		If Not ValueIsFilled(Selection.Products) Then
			Continue;
		EndIf;
		
		If ValueIsFilled(Object.Cell)
			AND Selection.Quantity <> Selection.QuantityAccounting
			AND Selection.Quantity <> 0 Then
			
			NewRow = Object.Inventory.Add();
			FillPropertyValues(NewRow, Selection);
			
			NewRow.QuantityAccounting = Selection.Quantity;
			
			If Selection.PriceAccount = 0 Then
				NewRow.Price = 0;
				NewRow.Amount = 0;
			Else
				NewRow.Price = ?(Selection.PriceAccount < 0, Selection.PriceAccount * (-1), Selection.PriceAccount);
				NewRow.Amount = NewRow.Price * NewRow.Quantity;
			EndIf;
			
			NewRow.AmountAccounting = NewRow.Amount;
			
		ElsIf Selection.QuantityAccounting <> 0 Then
			
			NewRow = Object.Inventory.Add();
			FillPropertyValues(NewRow, Selection);
			
			If Selection.PriceAccount = 0 Then
				NewRow.Amount = 0;
			Else
				NewRow.Price = ?(Selection.PriceAccount < 0, Selection.PriceAccount * (-1), Selection.PriceAccount);
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// The procedure fills in the Inventory tabular section by accounting data.
// 
&AtServer
Procedure FillOnlyAccountingData()
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableCosts.Products AS Products,
	|	TableCosts.Characteristic AS Characteristic,
	|	TableCosts.Batch AS Batch,
	|	TableCosts.Ownership AS Ownership,
	|	TableCosts.MeasurementUnit AS MeasurementUnit,
	|	TableCosts.Quantity AS Quantity,
	|	TableCosts.Price AS Price,
	|	TableCosts.Amount AS Amount
	|INTO Stocktaking
	|FROM
	|	&TableCosts AS TableCosts";
	
	Query.SetParameter("TableCosts", Object.Inventory.Unload());
	
	Query.Execute();
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	If ValueIsFilled(Object.Cell) Then
		QueryText = IssueQueryTextAccountsDataInCellInInventory();
		Query.SetParameter("Cell", Object.Cell);
	Else
		QueryText = GenerateQueryTextAccountingDataAtWarehouse();
	EndIf;
	
	Query.Text = QueryText +
	"SELECT
	|	StocktakingInventory.Products AS Products,
	|	StocktakingInventory.Characteristic AS Characteristic,
	|	StocktakingInventory.Batch AS Batch,
	|	StocktakingInventory.Ownership AS Ownership,
	|	StocktakingInventory.MeasurementUnit AS MeasurementUnit,
	|	StocktakingInventory.Quantity AS Quantity,
	|	StocktakingInventory.Price AS Price,
	|	StocktakingInventory.Amount AS Amount,
	|	ISNULL(TTInventoryRemains.Quantity, 0) / ISNULL(StocktakingInventory.MeasurementUnit.Factor, 1) AS QuantityInCell,
	|	ISNULL(TTInventoryRemains.QuantityAccounting, 0) / ISNULL(StocktakingInventory.MeasurementUnit.Factor, 1) AS QuantityAccounting,
	|	ISNULL(TTInventoryRemains.AmountAccounting, 0) AS AmountAccounting,
	|	CASE
	|		WHEN TTInventoryRemains.FlagInCell
	|			THEN StocktakingInventory.Quantity - ISNULL(TTInventoryRemains.Quantity, 0) / ISNULL(StocktakingInventory.MeasurementUnit.Factor, 1)
	|		ELSE StocktakingInventory.Quantity - ISNULL(TTInventoryRemains.QuantityAccounting, 0) / ISNULL(StocktakingInventory.MeasurementUnit.Factor, 1)
	|	END AS Deviation
	|FROM
	|	Stocktaking AS StocktakingInventory
	|		LEFT JOIN TemporaryTableInventoryBalances AS TTInventoryRemains
	|		ON StocktakingInventory.Products = TTInventoryRemains.Products
	|			AND StocktakingInventory.Characteristic = TTInventoryRemains.Characteristic
	|			AND StocktakingInventory.Batch = TTInventoryRemains.Batch
	|			AND StocktakingInventory.Ownership = TTInventoryRemains.Ownership";
	
	Query.SetParameter("Company", ParentCompany);
	Query.SetParameter("StructuralUnit", Object.StructuralUnit);
	Query.SetParameter("Period", EndOfDay(Object.Date));
	Query.SetParameter("Ref", Object.Ref);
	
	ResultsArray = Query.ExecuteBatch();
	
	If ValueIsFilled(Object.Cell) Then
		
		Object.Inventory.Clear();
		Object.SerialNumbers.Clear();
		
		Selection = ResultsArray[1].Select();
		While Selection.Next() Do
			
			NewRow = Object.Inventory.Add();
			FillPropertyValues(NewRow, Selection);
			
			If Selection.QuantityInCell <> Selection.QuantityAccounting Then
				
				NewRow.QuantityAccounting = Selection.QuantityInCell;
				If Selection.QuantityInCell = 0
					OR Selection.QuantityAccounting <= 0
					OR Selection.AmountAccounting = 0 Then
					NewRow.AmountAccounting = 0;
				Else
					NewRow.AmountAccounting = Selection.AmountAccounting / Selection.QuantityAccounting * NewRow.QuantityAccounting;
				EndIf;
				
			EndIf;
			
		EndDo;
		
	Else
		
		Object.Inventory.Load(ResultsArray[1].Unload());
		
	EndIf;
	
EndProcedure

// Gets data set from server.
//
&AtServerNoContext
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("ParentCompany", DriveServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	Return StructureData;
	
EndFunction

// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
&AtServerNoContext
Function GetDataMeasurementUnitOnChange(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
	StructureData = New Structure;
	
	If CurrentMeasurementUnit = Undefined Then
		StructureData.Insert("CurrentFactor", 1);
	Else
		StructureData.Insert("CurrentFactor", CurrentMeasurementUnit.Factor);
	EndIf;
	
	If MeasurementUnit = Undefined Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", MeasurementUnit.Factor);
	EndIf;
	
	Return StructureData;
	
EndFunction

// Sets the cell visible.
//
&AtServer
Procedure SetCellVisible()
	
	If Not ValueIsFilled(Object.StructuralUnit)
		OR Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail Then
		Items.Cell.Enabled = False;
	Else
		Items.Cell.Enabled = True;
	EndIf;
	
EndProcedure

// Procedure set conditional appearance
//
&AtServer
Procedure SetConditionalAppearance()
	
	//InventoryQuantity
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.Inventory.Quantity");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= 0;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = 'Missing'; ru = 'Отсутствуют';pl = 'Brak';es_ES = 'Falta';es_CO = 'Falta';tr = 'Eksik';it = 'Mancante';de = 'Fehlt'"));
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("InventoryQuantity");
	FieldAppearance.Use = True;
	
EndProcedure

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.InventoryPrice);
	
	Return Fields;
	
EndFunction

// Peripherals
// Procedure gets data by barcodes.
//
&AtServerNoContext
Procedure GetDataByBarCodes(StructureData)
	
	// Transform weight barcodes.
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		InformationRegisters.Barcodes.ConvertWeightBarcode(CurBarcode);
		
	EndDo;
	
	DataByBarCodes = InformationRegisters.Barcodes.GetDataByBarCodes(StructureData.BarcodesArray);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		BarcodeData = DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() <> 0 Then
			
			StructureProductsData = New Structure();
			StructureProductsData.Insert("Products", BarcodeData.Products);
			BarcodeData.Insert("StructureProductsData", GetDataProductsOnChange(StructureProductsData));
			
			If Not ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit  = BarcodeData.Products.MeasurementUnit;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureData.Insert("DataByBarCodes", DataByBarCodes);
	
EndProcedure

&AtClient
Function FillByBarcodesData(BarcodesData)
	
	UnknownBarcodes = New Array;
	
	If TypeOf(BarcodesData) = Type("Array") Then
		BarcodesArray = BarcodesData;
	Else
		BarcodesArray = New Array;
		BarcodesArray.Add(BarcodesData);
	EndIf;
	
	StructureData = New Structure();
	StructureData.Insert("BarcodesArray", BarcodesArray);
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			TSRowsArray = Object.Inventory.FindRows(New Structure("Products,Characteristic,Batch,MeasurementUnit",BarcodeData.Products,BarcodeData.Characteristic,BarcodeData.Batch,BarcodeData.MeasurementUnit));
			If TSRowsArray.Count() = 0 Then
				
				NewRow = Object.Inventory.Add();
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.Amount = NewRow.Quantity * NewRow.Price;
				Items.Inventory.CurrentRow = NewRow.GetID();
				
				// Rejection calculation.
				NewRow.Deviation = NewRow.Quantity - NewRow.QuantityAccounting;
				
			Else
				
				NewRow = TSRowsArray[0];
				NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
				NewRow.Amount = NewRow.Quantity * NewRow.Price;
				Items.Inventory.CurrentRow = NewRow.GetID();
				
				// Rejection calculation.
				NewRow.Deviation = NewRow.Quantity - NewRow.QuantityAccounting;
				
			EndIf;
			
			If BarcodeData.Property("SerialNumber") AND ValueIsFilled(BarcodeData.SerialNumber) Then
				WorkWithSerialNumbersClientServer.AddSerialNumberToString(NewRow, BarcodeData.SerialNumber, Object);
			EndIf;
			
			Modified = True;
			
		EndIf;
	EndDo;
	
	Return UnknownBarcodes;

EndFunction

// Procedure processes the received barcodes.
//
&AtClient
Procedure BarcodesReceived(BarcodesData)
	
	UnknownBarcodes = FillByBarcodesData(BarcodesData);
	
	ReturnParameters = Undefined;
	
	If UnknownBarcodes.Count() > 0 Then
		
		Notification = New NotifyDescription("BarcodesAreReceivedEnd", ThisForm, UnknownBarcodes);
		
		OpenForm(
			"InformationRegister.Barcodes.Form.BarcodesRegistration",
			New Structure("UnknownBarcodes", UnknownBarcodes), ThisForm,,,,Notification
		);
		
		Return;
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedEnd(ReturnParameters, Parameters) Export
	
	UnknownBarcodes = Parameters;
	
	If ReturnParameters <> Undefined Then
		
		BarcodesArray = New Array;
		
		For Each ArrayElement In ReturnParameters.RegisteredBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		For Each ArrayElement In ReturnParameters.ReceivedNewBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		UnknownBarcodes = FillByBarcodesData(BarcodesArray);
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedFragment(UnknownBarcodes) Export
	
	For Each CurUndefinedBarcode In UnknownBarcodes Do
		
		MessageString = NStr("en = 'Barcode data is not found: %1%; quantity: %2%'; ru = 'Данные по штрихкоду не найдены: %1%; количество: %2%';pl = 'Nie znaleziono danych kodu kreskowego: %1%; ilość: %2%';es_ES = 'Datos del código de barras no encontrados: %1%; cantidad: %2%';es_CO = 'Datos del código de barras no encontrados: %1%; cantidad: %2%';tr = 'Barkod verisi bulunamadı: %1%; miktar: %2%';it = 'Il codice a barre non è stato trovato: %1%; quantità: %2%';de = 'Barcode-Daten wurden nicht gefunden: %1%; Menge: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Quantity);
		CommonClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

// End Peripherals

// Recalculates prices of the document tabular section.
//
&AtClient
Procedure RefillTabularSectionPricesByPriceKind(PriceKind)
	
	DataStructure = New Structure;
	DocumentTabularSection = New Array;
	
	DataStructure.Insert("Date", Object.Date);
	DataStructure.Insert("Company", ParentCompany);
	DataStructure.Insert("PriceKind", PriceKind);
	DataStructure.Insert("DocumentCurrency", FunctionalCurrency);
	
	For Each TSRow In Object.Inventory Do
		
		TSRow.Price = 0;
		
		If Not ValueIsFilled(TSRow.Products) Then
			Continue;
		EndIf; 
		
		TabularSectionRow = New Structure();
		TabularSectionRow.Insert("Products", TSRow.Products);
		TabularSectionRow.Insert("Characteristic", TSRow.Characteristic);
		TabularSectionRow.Insert("MeasurementUnit", TSRow.MeasurementUnit);
		TabularSectionRow.Insert("Price", 0);
		
		DocumentTabularSection.Add(TabularSectionRow);
		
	EndDo;
	
	DriveServer.GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection);
	
	For Each TSRow In DocumentTabularSection Do
		
		SearchStructure = New Structure;
		SearchStructure.Insert("Products", TSRow.Products);
		SearchStructure.Insert("Characteristic", TSRow.Characteristic);
		SearchStructure.Insert("MeasurementUnit", TSRow.MeasurementUnit);
		
		SearchResult = Object.Inventory.FindRows(SearchStructure);
		
		For Each ResultRow In SearchResult Do
			
			ResultRow.Price = TSRow.Price;
			ResultRow.Amount = ResultRow.Quantity * ResultRow.Price;
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtClient
Function GenerateFilterHeaderFromList(ItemList)
	
	FilterHeaderString = "";
	For Each ItemOfList In ItemList Do
		
		FilterHeaderString = FilterHeaderString + ?(FilterHeaderString = "","","; ") + ItemOfList.Presentation;
		
	EndDo;
	
	If FilterHeaderString = "" Then
		FilterHeaderString = NStr("en = 'Filter not set'; ru = 'Отбор не установлен';pl = 'Nie wybrano filtru';es_ES = 'Filtro no establecido';es_CO = 'Filtro no establecido';tr = 'Filtre seçilmedi';it = 'Filtro non impostato';de = 'Filter nicht gesetzt'");
	EndIf;
	
	Return FilterHeaderString;
	
EndFunction

// It updates the headers of the filters for inventory count conditions.
//
&AtClient
Procedure UpdateFilterHeaders()

	ListTitle = GenerateFilterHeaderFromList(ProductsList);
	Items.SetFilterByProducts.Title = ListTitle;
	
	ListTitle = GenerateFilterHeaderFromList(ListProductsGroups);
	Items.SetFilterByProductsGroups.Title = ListTitle;
	
	ListTitle = GenerateFilterHeaderFromList(ProductsGroupsList);
	Items.SetFilterByProductsCategories.Title = ListTitle;

EndProcedure

// Restores the settings of filters of reconciliation conditions.
//
&AtServer
Procedure ResetFilterSettings()

	FilterSettingsStructure = FormAttributeToValue("Object").SettingsOfFilters.Get();
	If TypeOf(FilterSettingsStructure) = Type("Structure") Then
		FilterSettingsStructure.Property("ProductsList", ProductsList);
		FilterSettingsStructure.Property("ListProductsGroups", ListProductsGroups);
		FilterSettingsStructure.Property("ProductsGroupsList", ProductsGroupsList);
	EndIf;

EndProcedure

&AtClient
Procedure ClearFilterConditionByProducts()

	ProductsList.Clear();
	Items.SetFilterByProducts.Title = NStr("en = 'Filter not set'; ru = 'Отбор не установлен';pl = 'Nie wybrano filtru';es_ES = 'Filtro no establecido';es_CO = 'Filtro no establecido';tr = 'Filtre seçilmedi';it = 'Filtro non impostato';de = 'Filter nicht gesetzt'");

EndProcedure

&AtClient
Procedure ClearFilterCriteriaByProductAndServicesGroups()

	ListProductsGroups.Clear();
	Items.SetFilterByProductsGroups.Title = NStr("en = 'Filter not set'; ru = 'Отбор не установлен';pl = 'Nie wybrano filtru';es_ES = 'Filtro no establecido';es_CO = 'Filtro no establecido';tr = 'Filtre seçilmedi';it = 'Filtro non impostato';de = 'Filter nicht gesetzt'");

EndProcedure

&AtClient
Procedure ClearFilterCriteriaByProductsCategories()

	ProductsGroupsList.Clear();
	Items.SetFilterByProductsCategories.Title = NStr("en = 'Filter not set'; ru = 'Отбор не установлен';pl = 'Nie wybrano filtru';es_ES = 'Filtro no establecido';es_CO = 'Filtro no establecido';tr = 'Filtre seçilmedi';it = 'Filtro non impostato';de = 'Filter nicht gesetzt'");

EndProcedure

&AtClient
Procedure OpenSerialNumbersSelection()
		
	CurrentDataIdentifier = Items.Inventory.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier);
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);

EndProcedure

&AtServer
Function GetSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey);
	
EndFunction

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier)
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier, False);
	
EndFunction

&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	// Deviation calculation.
	TabularSectionRow.Deviation = TabularSectionRow.Quantity - TabularSectionRow.QuantityAccounting;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
	// Serial numbers
	If UseSerialNumbersBalance<>Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, TabularSectionRow);
	EndIf;
	
EndProcedure

#Region WorkWithSelection

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure Pick(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'stocktaking'; ru = 'инвентаризация';pl = 'inwentaryzacja';es_ES = 'inventario';es_CO = 'inventario';tr = 'stok sayımı';it = 'inventario';de = 'inventur'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, True);
	SelectionParameters.Insert("Company", ParentCompany);
	NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseSelection", ThisObject);
	OpenForm("DataProcessor.ProductsSelection.Form.MainForm",
			SelectionParameters,
			ThisObject,
			True,
			,
			,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		// Rejection calculation.
		NewRow.Deviation = NewRow.Quantity - NewRow.QuantityAccounting;
		
	EndDo;
	
EndProcedure

// Peripherals
// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("en = 'Enter barcode'; ru = 'Введите штрихкод';pl = 'Wprowadź kod kreskowy';es_ES = 'Introducir el código de barras';es_CO = 'Introducir el código de barras';tr = 'Barkod girin';it = 'Inserisci codice a barre';de = 'Geben Sie den Barcode ein'"));

EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
    
    CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
    
    
    If Not IsBlankString(CurBarcode) Then
        BarcodesReceived(New Structure("Barcode, Quantity", TrimAll(CurBarcode), 1));
    EndIf;

EndProcedure

// Procedure - event handler Action of the GetWeight command
//
&AtClient
Procedure GetWeight(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow = Undefined Then
		
		ShowMessageBox(Undefined, NStr("en = 'Select a line for which the weight should be received.'; ru = 'Необходимо выбрать строку, для которой необходимо получить вес.';pl = 'Wybierz wiersz, dla którego trzeba uzyskać wagę.';es_ES = 'Seleccionar una línea para la cual el peso tienen que recibirse.';es_CO = 'Seleccionar una línea para la cual el peso tienen que recibirse.';tr = 'Ağırlığın alınması gereken bir satır seçin.';it = 'Selezionare una linea dove il peso deve essere ricevuto';de = 'Wählen Sie eine Zeile, für die das Gewicht empfangen werden soll.'"));
		
	ElsIf EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		
		NotifyDescription = New NotifyDescription("GetWeightEnd", ThisObject, TabularSectionRow);
		EquipmentManagerClient.StartWeightReceivingFromElectronicScales(NotifyDescription, UUID);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure GetWeightEnd(Weight, Parameters) Export
	
	TabularSectionRow = Parameters;
	
	If Not Weight = Undefined Then
		If Weight = 0 Then
			MessageText = NStr("en = 'Electronic scales returned zero weight.'; ru = 'Электронные весы вернули нулевой вес.';pl = 'Waga elektroniczna zwróciła zerową wagę.';es_ES = 'Escalas electrónicas han devuelto el peso cero.';es_CO = 'Escalas electrónicas han devuelto el peso cero.';tr = 'Elektronik tartı sıfır ağırlık gösteriyor.';it = 'Le bilance elettroniche hanno dato peso pari a zero.';de = 'Die elektronische Waagen gaben Nullgewicht zurück.'");
			CommonClientServer.MessageToUser(MessageText);
		Else
			// Weight is received.
			TabularSectionRow.Quantity = Weight;
			TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
			
			// Rejection calculation.
			TabularSectionRow.Deviation = TabularSectionRow.Quantity - TabularSectionRow.QuantityAccounting;
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - ImportDataFromDTC command handler.
//
&AtClient
Procedure ImportDataFromDCT(Command)
	
	NotificationsAtImportFromDCT = New NotifyDescription("ImportFromDCTEnd", ThisObject);
	EquipmentManagerClient.StartImportDataFromDCT(NotificationsAtImportFromDCT, UUID);
	
EndProcedure

&AtClient
Procedure ImportFromDCTEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array") 
	   AND Result.Count() > 0 Then
		BarcodesReceived(Result);
	EndIf;
	
EndProcedure

// End Peripherals

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			
			GetInventoryFromStorage(InventoryAddressInStorage, "Inventory", True, True);
			
			Modified = True;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseVariantsSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If ClosingResult.WereMadeChanges And Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			TabularSectionName = "Inventory";
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			
			// Clear inventory
			Filter = New Structure;
			Filter.Insert("Products", ClosingResult.FilterProducts);
			
			RowsToDelete = Object[TabularSectionName].FindRows(Filter);
			For Each RowToDelete In RowsToDelete Do
				WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(
					Object.SerialNumbers, RowToDelete,, UseSerialNumbersBalance);
				Object[TabularSectionName].Delete(RowToDelete);
			EndDo;
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, True);
			
			RowsToRecalculate = Object[TabularSectionName].FindRows(Filter);
			For Each RowToRecalculate In RowsToRecalculate Do
				CalculateAmountInTabularSectionLine(RowToRecalculate);
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlersOfHeaderAttributes

// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the
// date of a document this document is found in
// another period of documents enumeration, and in this case the procedure assigns new unique number to the document.
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
	StructureData = GetCompanyDataOnChange(Object.Company);
	ParentCompany = StructureData.ParentCompany;
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
EndProcedure

// Procedure - event handler OnChange of the StructuralUnit input field.
//
&AtClient
Procedure StructuralUnitOnChange(Item)
	
	SetCellVisible();
	
EndProcedure

// Procedure - event handler Field opening StructuralUnit.
//
&AtClient
Procedure StructuralUnitOpening(Item, StandardProcessing)
	
	If Items.StructuralUnit.ListChoiceMode
		AND Not ValueIsFilled(Object.StructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTabularSectionsCommandPanelsActions

// Procedure - FillInByBalanceOnWarehouse button clicking handler.
// 
&AtClient
Procedure CommandFillByBalanceAtWarehouse()

	If Object.Inventory.Count() > 0 Then
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("FillCommandByBalanceOnWarehouseEnd", ThisObject), NStr("en = 'Tabular section will be cleared. Continue?'; ru = 'Табличная часть будет очищена! Продолжить выполнение операции?';pl = 'Sekcja tabelaryczna zostanie wyczyszczona. Kontynuować?';es_ES = 'Sección tabular se vaciará. ¿Continuar?';es_CO = 'Sección tabular se vaciará. ¿Continuar?';tr = 'Tablo bölümü silinecek. Devam edilsin mi?';it = 'La sezione tabellare sarà annullata. Proseguire?';de = 'Der Tabellenabschnitt wird gelöscht. Fortsetzen?'"), QuestionDialogMode.YesNo, 0);
        Return; 
	EndIf;

	FillCommandByBalanceOnWarehouseFragment();
EndProcedure

&AtClient
Procedure FillCommandByBalanceOnWarehouseEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response <> DialogReturnCode.Yes Then
        Return;
    EndIf; 
    
    FillCommandByBalanceOnWarehouseFragment();

EndProcedure

&AtClient
Procedure FillCommandByBalanceOnWarehouseFragment()
    
    FillByBalanceAtWarehouse();

EndProcedure

// Procedure - FillOnlyAccountingData click handler.
// 
&AtClient
Procedure CommandFillOnlyAccountingData()
	
	If Object.Inventory.Count() > 0 Then
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("CommandFillOnlyAccountingDataEnd", ThisObject), NStr("en = 'Accounting data will be cleared. Continue?'; ru = 'Учетные данные будут очищены! Продолжить?';pl = 'Dane księgowe zostaną oczyszczone. Kontynuować?';es_ES = 'Datos de la contabilidad se eliminarán. ¿Continuar?';es_CO = 'Datos de la contabilidad se eliminarán. ¿Continuar?';tr = 'Muhasebe verileri silinecek. Devam et?';it = 'I dati contabili saranno annullati. Proseguire?';de = 'Buchhaltungsdaten werden gelöscht. Fortsetzen?'"), QuestionDialogMode.YesNo, 0);
        Return; 
	Else
		Return;
	EndIf;
	
	CommandFillOnlyAccountingDataFragment();
EndProcedure

&AtClient
Procedure CommandFillOnlyAccountingDataEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response <> DialogReturnCode.Yes Then
        Return;
    EndIf; 
    
    CommandFillOnlyAccountingDataFragment();

EndProcedure

&AtClient
Procedure CommandFillOnlyAccountingDataFragment()
    
    FillOnlyAccountingData();

EndProcedure

// Procedure - FillByPriceKind click handler.
// 
&AtClient
Procedure CommandFillByPriceKind(Command)
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("CommandFillByPriceKindEnd1", ThisObject), NStr("en = 'Prices will be refilled. Continue?'; ru = 'Цены будут перезаполнены! Продолжить?';pl = 'Ceny będą wypełnione ponownie. Kontynuować?';es_ES = 'Precios se volverán a rellenar. ¿Continuar?';es_CO = 'Precios se volverán a rellenar. ¿Continuar?';tr = 'Fiyatlar yeniden doldurulacak. Devam et?';it = 'I prezzi saranno ricompilati. Continuare?';de = 'Die Preise werden nachgefüllt. Fortsetzen?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure CommandFillByPriceKindEnd1(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response <> DialogReturnCode.Yes Then
        Return;
    EndIf;
    
    PriceKind = Undefined;
    
    
    OpenForm("Catalog.PriceTypes.Form.ChoiceForm",,,,,, New NotifyDescription("CommandFillByPriceKindEnd", ThisObject));

EndProcedure

&AtClient
Procedure CommandFillByPriceKindEnd(Result, AdditionalParameters) Export
    
    PriceKind = Result;
    
    If TypeOf(PriceKind) = Type("CatalogRef.PriceTypes") Then
        RefillTabularSectionPricesByPriceKind(PriceKind);
    EndIf;

EndProcedure

// Procedure - CommandZeroOutQuantityAndAmount click handler.
// 
&AtClient
Procedure CommandZeroQuantityAndTheAmount(Command)
	
	If Object.Inventory.Count() > 0 Then
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("CommandZeroOutQuantityAndAmountEnd", ThisObject), NStr("en = 'Counted quantity and Amount columns will be cleared. Continue?'; ru = 'Колонки ""Количество"" и ""Сумма"" будут очищены! Продолжить?';pl = 'Liczone ilości i kolumny Wartość zostaną wyczyszczone. Kontynuować?';es_ES = 'Las columnas de la Cantidad contada y el Importe se eliminarán. ¿Continuar?';es_CO = 'Las columnas de la Cantidad contada y el Importe se eliminarán. ¿Continuar?';tr = 'Hesaplanan miktar ve Tutar sütunu temizlenecektir. Devam et?';it = 'Le colonne ""Quantità"" e ""Importo"" saranno cancellate! Continuare?';de = 'Die gezählten Mengen und die Summen-Spalten werden gelöscht. Fortsetzen?'"), QuestionDialogMode.YesNo, 0);
        Return;
	Else
		Return;
	EndIf;
	
	CommandZeroOutQuantityAndAmountFragment();
EndProcedure

&AtClient
Procedure CommandZeroOutQuantityAndAmountEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response <> DialogReturnCode.Yes Then
        Return;
    EndIf;
    
    CommandZeroOutQuantityAndAmountFragment();

EndProcedure

&AtClient
Procedure CommandZeroOutQuantityAndAmountFragment()
    
    Var TabularSectionRow;
    
    For Each TabularSectionRow In Object.Inventory Do
        
        TabularSectionRow.Quantity = 0;
        TabularSectionRow.Amount 		= 0;
        TabularSectionRow.Deviation = TabularSectionRow.Quantity - TabularSectionRow.QuantityAccounting;
        
    EndDo;
    
    Modified = True;

EndProcedure

&AtClient
Procedure ClearFilterByProductsClick(Item)
	
	ClearFilterConditionByProducts();
	
EndProcedure

&AtClient
Procedure ClearFilterByProductsGroupsClick(Item)
	
	ClearFilterCriteriaByProductAndServicesGroups();
	
EndProcedure

&AtClient
Procedure ClearFilterByProductsCategoriesClick(Item)
	
	ClearFilterCriteriaByProductsCategories();
	
EndProcedure

#EndRegion

#Region TabularSectionAttributeEventHandlers

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Products", TabularSectionRow.Products);
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	TabularSectionRow.QuantityAccounting = 0;
	TabularSectionRow.AmountAccounting = 0;
	
	// Rejection calculation.
	TabularSectionRow.Deviation = TabularSectionRow.Quantity - TabularSectionRow.QuantityAccounting;
	
	// Serial numbers
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow,,UseSerialNumbersBalance);
	
EndProcedure

&AtClient
Procedure InventoryCharacteristicStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.Inventory.CurrentData;
	
	If DriveClient.UseMatrixForm(CurrentRow.Products) Then
		
		StandardProcessing = False;
		
		TabularSectionName	= "Inventory";
		SelectionParameters	= DriveClient.GetMatrixParameters(ThisObject, TabularSectionName, False);
		NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseVariantsSelection", ThisObject);
		OpenForm("Catalog.ProductsCharacteristics.Form.MatrixFormWithAvailableQuantity",
			SelectionParameters,
			ThisObject,
			True,
			,
			,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
&AtClient
Procedure InventoryMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow.MeasurementUnit = ValueSelected 
		OR TabularSectionRow.Price = 0 Then
		Return;
	EndIf;
	
	CurrentFactor = 0;
	If TypeOf(TabularSectionRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		CurrentFactor = 1;
	EndIf;
	
	Factor = 0;
	If TypeOf(ValueSelected) = Type("CatalogRef.UOMClassifier") Then
		Factor = 1;
	EndIf;
	
	If CurrentFactor = 0 AND Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit, ValueSelected);
	ElsIf CurrentFactor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit);
	ElsIf Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(,ValueSelected);
	ElsIf CurrentFactor = 1 AND Factor = 1 Then
		StructureData = New Structure("CurrentFactor, Factor", 1, 1);
	EndIf;
	
	If StructureData.CurrentFactor <> 0 AND StructureData.Factor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
		TabularSectionRow.Quantity = TabularSectionRow.Quantity * StructureData.CurrentFactor / StructureData.Factor;
		TabularSectionRow.QuantityAccounting = TabularSectionRow.QuantityAccounting * StructureData.CurrentFactor / StructureData.Factor;
	EndIf;
	
	// Rejection calculation.
	TabularSectionRow.Deviation = TabularSectionRow.Quantity - TabularSectionRow.QuantityAccounting;
	
EndProcedure

// Procedure - OnChange event handler
// of the Quantity input field in the Inventory tabular section line.
// Recalculates the amount in the tabular section line.
//
&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - OnChange event handler of the
// Price input field in the Inventory tabular section line.
// Recalculates the amounts in the tabular section line.
//
&AtClient
Procedure InventoryPriceOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
EndProcedure

// Procedure - OnChange event handler of the
// Amount input field in the Inventory tabular section line.
// Recalculates prices in the tabular section line.
//
&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	StringPrice = ?(TabularSectionRow.Quantity = 0, 0, TabularSectionRow.Amount / TabularSectionRow.Quantity);
	
	TabularSectionRow.Price = ?(StringPrice < 0, -1 * StringPrice, StringPrice);
	
EndProcedure

&AtClient
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	OpenSerialNumbersSelection();
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	// Serial numbers
	CurrentData = Items.Inventory.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(
		Object.SerialNumbers, CurrentData,, UseSerialNumbersBalance);
EndProcedure

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Clone)
	
	If NewRow AND Clone Then
		Item.CurrentData.ConnectionKey = 0;
		Item.CurrentData.SerialNumbers = "";
	EndIf;

	If Item.CurrentItem.Name = "InventorySerialNumbers" Then
		OpenSerialNumbersSelection();
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SetFilterByProducts(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("FilterKind", "FilterByProducts");
	FormParameters.Insert("ListValueSelection", ProductsList);
	
	Notification = New NotifyDescription("SetFilterEnd",ThisForm);
	OpenForm("Document.Stocktaking.Form.ChoiceFormValuesSelection", FormParameters, ThisForm,,,,Notification);
	
EndProcedure

&AtClient
Procedure SetFilterByProductsGroups(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("FilterKind", "FilterByProductsGroups");
	FormParameters.Insert("ListValueSelection", ListProductsGroups);
	
	Notification = New NotifyDescription("SetFilterEnd",ThisForm);
	OpenForm("Document.Stocktaking.Form.ChoiceFormValuesSelection", FormParameters, ThisForm,,,,Notification);
	
EndProcedure

&AtClient
Procedure SetFilterByProductsCategories(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("FilterKind", "FilterByProductsCategories");
	FormParameters.Insert("ListValueSelection", ProductsGroupsList);
	
	Notification = New NotifyDescription("SetFilterEnd",ThisForm);
	OpenForm("Document.Stocktaking.Form.ChoiceFormValuesSelection", FormParameters, ThisForm,,,,Notification);
	
EndProcedure

&AtClient
Procedure SetFilterEnd(Result,Parameters) Export
	
	If TypeOf(Result) = Type("Structure") Then
		
		ListValueSelection = GetFromTempStorage(Result.SelectionValueListAddress);
		ListTitle = GenerateFilterHeaderFromList(ListValueSelection);
		
		FilterKind = Result.FilterKind;
		If FilterKind = "FilterByProducts" Then
			ProductsList = ListValueSelection;
			Items.SetFilterByProducts.Title = ListTitle;
		ElsIf FilterKind = "FilterByProductsGroups" Then
			ListProductsGroups = ListValueSelection;
			Items.SetFilterByProductsGroups.Title = ListTitle;
		Else
			ProductsGroupsList = ListValueSelection;
			Items.SetFilterByProductsCategories.Title = ListTitle;
		EndIf;
		
	EndIf;
	
EndProcedure

#Region DataImportFromExternalSources

&AtClient
Procedure LoadFromFileInventory(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName",	"Stocktaking.Inventory");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import inventory from file'; ru = 'Загрузка запасов из файла';pl = 'Import zapasów z pliku';es_ES = 'Importar el inventario del archivo';es_CO = 'Importar el inventario del archivo';tr = 'Stoku dosyadan içe aktar';it = 'Importazione delle scorte da file';de = 'Bestand aus Datei importieren'"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		ProcessPreparedData(ImportResult);
		Modified = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult, Object);
	
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

#EndRegion