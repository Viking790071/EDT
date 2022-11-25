#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefProduction, StructureAdditionalProperties) Export
	
	DocumentAttributes = Common.ObjectAttributesValues(DocumentRefProduction, "OperationKind, SalesOrder, BasisDocument");
	StructureAdditionalProperties.Insert("DocumentAttributes", DocumentAttributes);
	
	// Use by products accounting starting from
	UseByProductsAccountingStartingFrom = Constants.UseByProductsAccountingStartingFrom.Get();
	UseByProductsAccounting = ?(ValueIsFilled(UseByProductsAccountingStartingFrom),
		UseByProductsAccountingStartingFrom <= StructureAdditionalProperties.ForPosting.Date,
		False);
	StructureAdditionalProperties.Insert("UseByProductsAccounting", UseByProductsAccounting);
	
	If DocumentAttributes.OperationKind = Enums.OperationTypesProduction.Assembly Then
		InitializeDocumentDataAssembly(DocumentRefProduction, StructureAdditionalProperties);
	ElsIf DocumentAttributes.OperationKind = Enums.OperationTypesProduction.ConvertFromWIP Then
		InitializeDocumentDataConvertFromWIP(DocumentRefProduction, StructureAdditionalProperties);
	Else
		InitializeDocumentDataDisassembly(DocumentRefProduction, StructureAdditionalProperties);
	EndIf;
	
	GenerateTableAccountingEntriesData(DocumentRefProduction, StructureAdditionalProperties);

	// Accounting
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefProduction, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefProduction, StructureAdditionalProperties);
		
	EndIf;
	
	FinancialAccounting.FillExtraDimensions(DocumentRefProduction, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefProduction, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If the temporary
	// tables "RegisterRecordsProductionOrdersChange"
	// "RegisterRecordsBackordersChange" "RegisterRecordsInventoryChange"
	// "RegisterRecordsReservedProductsChange" contain records, control goods implementation.
	
	If StructureTemporaryTables.RegisterRecordsProductionOrdersChange
		Or StructureTemporaryTables.RegisterRecordsBackordersChange
		Or StructureTemporaryTables.RegisterRecordsInventoryChange
		Or StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		Or StructureTemporaryTables.RegisterRecordsWorkInProgressChange
		Or StructureTemporaryTables.RegisterRecordsStockReceivedFromThirdPartiesChange
		Or StructureTemporaryTables.RegisterRecordsSerialNumbersChange
		Or StructureTemporaryTables.RegisterRecordsReservedProductsChange 
		Or StructureTemporaryTables.RegisterRecordsWorkInProgressStatementChange
		Or StructureTemporaryTables.RegisterRecordsProductionComponentsChange Then
		
		Query = New Query(
		// 0
		"SELECT
		|	RegisterRecordsInventoryInWarehousesChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Ownership) AS OwnershipPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Cell) AS PresentationCell,
		|	InventoryInWarehousesOfBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	REFPRESENTATION(InventoryInWarehousesOfBalance.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryInWarehousesChange.QuantityChange, 0) + ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS BalanceInventoryInWarehouses,
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS QuantityBalanceInventoryInWarehouses
		|FROM
		|	RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange
		|		LEFT JOIN AccumulationRegister.InventoryInWarehouses.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, Products, Characteristic, Batch, Ownership, Cell) IN
		|					(SELECT
		|						RegisterRecordsInventoryInWarehousesChange.Company AS Company,
		|						RegisterRecordsInventoryInWarehousesChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryInWarehousesChange.Products AS Products,
		|						RegisterRecordsInventoryInWarehousesChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryInWarehousesChange.Batch AS Batch,
		|						RegisterRecordsInventoryInWarehousesChange.Ownership AS Ownership,
		|						RegisterRecordsInventoryInWarehousesChange.Cell AS Cell
		|					FROM
		|						RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange)) AS InventoryInWarehousesOfBalance
		|		ON RegisterRecordsInventoryInWarehousesChange.Company = InventoryInWarehousesOfBalance.Company
		|			AND RegisterRecordsInventoryInWarehousesChange.StructuralUnit = InventoryInWarehousesOfBalance.StructuralUnit
		|			AND RegisterRecordsInventoryInWarehousesChange.Products = InventoryInWarehousesOfBalance.Products
		|			AND RegisterRecordsInventoryInWarehousesChange.Characteristic = InventoryInWarehousesOfBalance.Characteristic
		|			AND RegisterRecordsInventoryInWarehousesChange.Batch = InventoryInWarehousesOfBalance.Batch
		|			AND RegisterRecordsInventoryInWarehousesChange.Ownership = InventoryInWarehousesOfBalance.Ownership
		|			AND RegisterRecordsInventoryInWarehousesChange.Cell = InventoryInWarehousesOfBalance.Cell
		|WHERE
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		// 1
		|SELECT
		|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.PresentationCurrency) AS PresentationCurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.InventoryAccountType) AS InventoryAccountTypePresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Ownership) AS OwnershipPresentation,
		|	InventoryBalances.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	REFPRESENTATION(InventoryBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryChange.QuantityChange, 0) + ISNULL(InventoryBalances.QuantityBalance, 0) AS BalanceInventory,
		|	ISNULL(InventoryBalances.QuantityBalance, 0) AS QuantityBalanceInventory,
		|	ISNULL(InventoryBalances.AmountBalance, 0) AS AmountBalanceInventory
		|FROM
		|	RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange
		|		LEFT JOIN AccumulationRegister.Inventory.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject) IN
		|					(SELECT
		|						RegisterRecordsInventoryChange.Company AS Company,
		|						RegisterRecordsInventoryChange.PresentationCurrency AS PresentationCurrency,
		|						RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryChange.InventoryAccountType AS InventoryAccountType,
		|						RegisterRecordsInventoryChange.Products AS Products,
		|						RegisterRecordsInventoryChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryChange.Batch AS Batch,
		|						RegisterRecordsInventoryChange.Ownership AS Ownership,
		|						RegisterRecordsInventoryChange.CostObject AS CostObject
		|					FROM
		|						RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange)) AS InventoryBalances
		|		ON RegisterRecordsInventoryChange.Company = InventoryBalances.Company
		|			AND RegisterRecordsInventoryChange.PresentationCurrency = InventoryBalances.PresentationCurrency
		|			AND RegisterRecordsInventoryChange.StructuralUnit = InventoryBalances.StructuralUnit
		|			AND RegisterRecordsInventoryChange.InventoryAccountType = InventoryBalances.InventoryAccountType
		|			AND RegisterRecordsInventoryChange.Products = InventoryBalances.Products
		|			AND RegisterRecordsInventoryChange.Characteristic = InventoryBalances.Characteristic
		|			AND RegisterRecordsInventoryChange.Batch = InventoryBalances.Batch
		|			AND RegisterRecordsInventoryChange.Ownership = InventoryBalances.Ownership
		|			AND RegisterRecordsInventoryChange.CostObject = InventoryBalances.CostObject
		|WHERE
		|	ISNULL(InventoryBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		// 2
		|SELECT
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(StockReceivedFromThirdPartiesBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsStockReceivedFromThirdPartiesChange.QuantityChange, 0) + ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) AS BalanceStockReceivedFromThirdParties,
		|	ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) AS QuantityBalanceStockReceivedFromThirdParties
		|FROM
		|	RegisterRecordsStockReceivedFromThirdPartiesChange AS RegisterRecordsStockReceivedFromThirdPartiesChange
		|		LEFT JOIN AccumulationRegister.StockReceivedFromThirdParties.Balance(
		|				&ControlTime,
		|				(Company, Products, Characteristic, Batch, Order) IN
		|					(SELECT
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Company AS Company,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Products AS Products,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic AS Characteristic,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Batch AS Batch,
		|						UNDEFINED AS Order
		|					FROM
		|						RegisterRecordsStockReceivedFromThirdPartiesChange AS RegisterRecordsStockReceivedFromThirdPartiesChange)) AS StockReceivedFromThirdPartiesBalances
		|		ON RegisterRecordsStockReceivedFromThirdPartiesChange.Company = StockReceivedFromThirdPartiesBalances.Company
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Products = StockReceivedFromThirdPartiesBalances.Products
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic = StockReceivedFromThirdPartiesBalances.Characteristic
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Batch = StockReceivedFromThirdPartiesBalances.Batch
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Order = StockReceivedFromThirdPartiesBalances.Order
		|WHERE
		|	ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		// 3
		|SELECT
		|	RegisterRecordsBackordersChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.SalesOrder) AS SalesOrderPresentation,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.SupplySource) AS SupplySourcePresentation,
		|	REFPRESENTATION(BackordersBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsBackordersChange.QuantityChange, 0) + ISNULL(BackordersBalances.QuantityBalance, 0) AS BalanceBackorders,
		|	ISNULL(BackordersBalances.QuantityBalance, 0) AS QuantityBalanceBackorders
		|FROM
		|	RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange
		|		LEFT JOIN AccumulationRegister.Backorders.Balance(
		|				&ControlTime,
		|				(Company, SalesOrder, Products, Characteristic, SupplySource) IN
		|					(SELECT
		|						RegisterRecordsBackordersChange.Company AS Company,
		|						RegisterRecordsBackordersChange.SalesOrder AS SalesOrder,
		|						RegisterRecordsBackordersChange.Products AS Products,
		|						RegisterRecordsBackordersChange.Characteristic AS Characteristic,
		|						RegisterRecordsBackordersChange.SupplySource AS SupplySource
		|					FROM
		|						RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange)) AS BackordersBalances
		|		ON RegisterRecordsBackordersChange.Company = BackordersBalances.Company
		|			AND RegisterRecordsBackordersChange.SalesOrder = BackordersBalances.SalesOrder
		|			AND RegisterRecordsBackordersChange.Products = BackordersBalances.Products
		|			AND RegisterRecordsBackordersChange.Characteristic = BackordersBalances.Characteristic
		|			AND RegisterRecordsBackordersChange.SupplySource = BackordersBalances.SupplySource
		|WHERE
		|	ISNULL(BackordersBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		// 4
		|SELECT
		|	RegisterRecordsSerialNumbersChange.LineNumber AS LineNumber,
		|	RegisterRecordsSerialNumbersChange.SerialNumber AS SerialNumberPresentation,
		|	RegisterRecordsSerialNumbersChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsSerialNumbersChange.Products AS ProductsPresentation,
		|	RegisterRecordsSerialNumbersChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsSerialNumbersChange.Batch AS BatchPresentation,
		|	RegisterRecordsSerialNumbersChange.Ownership AS OwnershipPresentation,
		|	RegisterRecordsSerialNumbersChange.Cell AS PresentationCell,
		|	SerialNumbersBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	SerialNumbersBalance.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsSerialNumbersChange.QuantityChange, 0) + ISNULL(SerialNumbersBalance.QuantityBalance, 0) AS BalanceSerialNumbers,
		|	ISNULL(SerialNumbersBalance.QuantityBalance, 0) AS BalanceQuantitySerialNumbers
		|FROM
		|	RegisterRecordsSerialNumbersChange AS RegisterRecordsSerialNumbersChange
		|		INNER JOIN AccumulationRegister.SerialNumbers.Balance(&ControlTime, ) AS SerialNumbersBalance
		|		ON RegisterRecordsSerialNumbersChange.StructuralUnit = SerialNumbersBalance.StructuralUnit
		|			AND RegisterRecordsSerialNumbersChange.Products = SerialNumbersBalance.Products
		|			AND RegisterRecordsSerialNumbersChange.Characteristic = SerialNumbersBalance.Characteristic
		|			AND RegisterRecordsSerialNumbersChange.Batch = SerialNumbersBalance.Batch
		|			AND RegisterRecordsSerialNumbersChange.Ownership = SerialNumbersBalance.Ownership
		|			AND RegisterRecordsSerialNumbersChange.SerialNumber = SerialNumbersBalance.SerialNumber
		|			AND RegisterRecordsSerialNumbersChange.Cell = SerialNumbersBalance.Cell
		|			AND (ISNULL(SerialNumbersBalance.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		// 5
		|SELECT
		|	RegisterRecordsProductionOrdersChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsProductionOrdersChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsProductionOrdersChange.ProductionOrder) AS ProductionOrderPresentation,
		|	REFPRESENTATION(RegisterRecordsProductionOrdersChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsProductionOrdersChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(ProductionOrdersBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsProductionOrdersChange.QuantityChange, 0) + ISNULL(ProductionOrdersBalances.QuantityBalance, 0) AS BalanceProductionOrders,
		|	ISNULL(ProductionOrdersBalances.QuantityBalance, 0) AS QuantityBalanceProductionOrders
		|FROM
		|	RegisterRecordsProductionOrdersChange AS RegisterRecordsProductionOrdersChange
		|		LEFT JOIN AccumulationRegister.ProductionOrders.Balance(
		|				&ControlTime,
		|				(Company, ProductionOrder, Products, Characteristic) IN
		|					(SELECT
		|						RegisterRecordsProductionOrdersChange.Company AS Company,
		|						RegisterRecordsProductionOrdersChange.ProductionOrder AS ProductionOrder,
		|						RegisterRecordsProductionOrdersChange.Products AS Products,
		|						RegisterRecordsProductionOrdersChange.Characteristic AS Characteristic
		|					FROM
		|						RegisterRecordsProductionOrdersChange AS RegisterRecordsProductionOrdersChange)) AS ProductionOrdersBalances
		|		ON RegisterRecordsProductionOrdersChange.Company = ProductionOrdersBalances.Company
		|			AND RegisterRecordsProductionOrdersChange.ProductionOrder = ProductionOrdersBalances.ProductionOrder
		|			AND RegisterRecordsProductionOrdersChange.Products = ProductionOrdersBalances.Products
		|			AND RegisterRecordsProductionOrdersChange.Characteristic = ProductionOrdersBalances.Characteristic
		|WHERE
		|	ISNULL(ProductionOrdersBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ManufacturingProducts.Ref AS Ref,
		|	ManufacturingProducts.Products AS Products,
		|	ManufacturingProducts.Characteristic AS Characteristic,
		|	ManufacturingProducts.Batch AS Batch,
		|	ManufacturingProducts.Ownership AS Ownership
		|INTO TT_FinishedProducts
		|FROM
		|	Document.Manufacturing.Products AS ManufacturingProducts
		|		INNER JOIN Document.Manufacturing AS Manufacturing
		|		ON (Manufacturing.Ref = &Ref)
		|			AND (Manufacturing.OperationKind = VALUE(Enum.OperationTypesProduction.ConvertFromWIP))
		|			AND ManufacturingProducts.Ref = Manufacturing.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	REFPRESENTATION(InventoryBalanceAndTurnovers.Company) AS CompanyPresentation,
		|	REFPRESENTATION(InventoryBalanceAndTurnovers.PresentationCurrency) AS PresentationCurrencyPresentation,
		|	REFPRESENTATION(InventoryBalanceAndTurnovers.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(InventoryBalanceAndTurnovers.InventoryAccountType) AS InventoryAccountTypePresentation,
		|	REFPRESENTATION(InventoryBalanceAndTurnovers.Products) AS ProductsPresentation,
		|	REFPRESENTATION(InventoryBalanceAndTurnovers.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(InventoryBalanceAndTurnovers.Batch) AS BatchPresentation,
		|	REFPRESENTATION(InventoryBalanceAndTurnovers.Ownership) AS OwnershipPresentation,
		|	REFPRESENTATION(InventoryBalanceAndTurnovers.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	SUM(InventoryBalanceAndTurnovers.AmountTurnover) AS AmountBalanceInventory
		|INTO TT_FinishedProductsAmount
		|FROM
		|	TT_FinishedProducts AS TT_FinishedProducts
		|		INNER JOIN AccumulationRegister.Inventory.BalanceAndTurnovers(, &ControlTime, Recorder, , ) AS InventoryBalanceAndTurnovers
		|		ON TT_FinishedProducts.Products = InventoryBalanceAndTurnovers.Products
		|			AND TT_FinishedProducts.Characteristic = InventoryBalanceAndTurnovers.Characteristic
		|			AND TT_FinishedProducts.Ref = InventoryBalanceAndTurnovers.Recorder
		|
		|GROUP BY
		|	REFPRESENTATION(InventoryBalanceAndTurnovers.Company),
		|	REFPRESENTATION(InventoryBalanceAndTurnovers.PresentationCurrency),
		|	REFPRESENTATION(InventoryBalanceAndTurnovers.StructuralUnit),
		|	REFPRESENTATION(InventoryBalanceAndTurnovers.InventoryAccountType),
		|	REFPRESENTATION(InventoryBalanceAndTurnovers.Products),
		|	REFPRESENTATION(InventoryBalanceAndTurnovers.Characteristic),
		|	REFPRESENTATION(InventoryBalanceAndTurnovers.Batch),
		|	REFPRESENTATION(InventoryBalanceAndTurnovers.Ownership),
		|	REFPRESENTATION(InventoryBalanceAndTurnovers.Products.MeasurementUnit)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		// 8
		|SELECT
		|	TT_FinishedProductsAmount.CompanyPresentation AS CompanyPresentation,
		|	TT_FinishedProductsAmount.PresentationCurrencyPresentation AS PresentationCurrencyPresentation,
		|	TT_FinishedProductsAmount.StructuralUnitPresentation AS StructuralUnitPresentation,
		|	TT_FinishedProductsAmount.InventoryAccountTypePresentation AS InventoryAccountTypePresentation,
		|	TT_FinishedProductsAmount.ProductsPresentation AS ProductsPresentation,
		|	TT_FinishedProductsAmount.CharacteristicPresentation AS CharacteristicPresentation,
		|	TT_FinishedProductsAmount.BatchPresentation AS BatchPresentation,
		|	TT_FinishedProductsAmount.OwnershipPresentation AS OwnershipPresentation,
		|	TT_FinishedProductsAmount.MeasurementUnitPresentation AS MeasurementUnitPresentation,
		|	TT_FinishedProductsAmount.AmountBalanceInventory AS AmountBalanceInventory
		|FROM
		|	TT_FinishedProductsAmount AS TT_FinishedProductsAmount
		|WHERE
		|	TT_FinishedProductsAmount.AmountBalanceInventory < 0
		|;
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_FinishedProducts
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TT_FinishedProductsAmount");
		
		// 11
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.ReservedProducts.BalancesControlQueryText();
		
		// 12
		DriveClientServer.AddDelimeter(Query.Text);
		Query.Text = Query.Text + AccumulationRegisters.WorkInProgress.BalancesControlQueryText();
		
		// 13
		DriveClientServer.AddDelimeter(Query.Text);
		Query.Text = Query.Text + AccumulationRegisters.WorkInProgressStatement.BalancesControlQueryText();
		
		// 14
		DriveClientServer.AddDelimeter(Query.Text);
		Query.Text = Query.Text + AccumulationRegisters.CustomerOwnedInventory.BalancesControlQueryText();
		
		// 15
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.ProductionComponents.BalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		Query.SetParameter("Ref", AdditionalProperties.ForPosting.Ref);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			Or Not ResultsArray[1].IsEmpty()
			Or Not ResultsArray[2].IsEmpty()
			Or Not ResultsArray[3].IsEmpty()
			Or Not ResultsArray[4].IsEmpty()
			Or Not ResultsArray[5].IsEmpty()
			Or Not ResultsArray[8].IsEmpty()
			Or Not ResultsArray[11].IsEmpty()
			Or Not ResultsArray[12].IsEmpty() 
			Or Not ResultsArray[13].IsEmpty()
			Or Not ResultsArray[14].IsEmpty()Then
			DocumentObjectProduction = DocumentRefProduction.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		// Negative balance of inventory.
		ElsIf Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		// Negative balance of need for reserved products.
		ElsIf Not ResultsArray[11].IsEmpty() Then
			QueryResultSelection = ResultsArray[11].Select();
			DriveServer.ShowMessageAboutPostingToReservedProductsRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		Else
			DriveServer.CheckAvailableStockBalance(DocumentObjectProduction, AdditionalProperties, Cancel);
		EndIf;
		
		// Negative balance of inventory received.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToStockReceivedFromThirdPartiesRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on the inventories placement.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingToBackordersRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of serial numbers in the warehouse.
		If NOT ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			DriveServer.ShowMessageAboutPostingSerialNumbersRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance by production orders.
		If Not ResultsArray[5].IsEmpty() Then
			QueryResultSelection = ResultsArray[5].Select();
			DriveServer.ShowMessageAboutPostingToProductionOrdersRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative amount of finished product.
		If Not ResultsArray[8].IsEmpty() And Not AdditionalProperties.AccountingPolicy.UseFIFO Then
			QueryResultSelection = ResultsArray[8].Select();
			DriveServer.ShowMessageAboutNegativeAmountInInventoryRegister(DocumentObjectProduction, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of work-in-progress register
		If Not ResultsArray[12].IsEmpty() Then
			QueryResultSelection = ResultsArray[12].Select();
			DriveServer.ShowMessageAboutPostingToWorkInProgressRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of work-in-progress statement.
		If Not ResultsArray[13].IsEmpty() Then
			QueryResultSelection = ResultsArray[13].Select();
			DriveServer.ShowMessageAboutPostingToWorkInProgressStatementRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of customer-owned inventory.
		If Not ResultsArray[14].IsEmpty() Then
			QueryResultSelection = ResultsArray[14].Select();
			DriveServer.ShowMessageAboutPostingToCustomerOwnedInventoryRegisterErrors(
				DocumentObjectProduction,
				QueryResultSelection,
				Cancel,
				AdditionalProperties.WriteMode);
		EndIf;
		
		// Negative balance of production components.
		If Not ResultsArray[15].IsEmpty() Then
			QueryResultSelection = ResultsArray[14].Select();
			DriveServer.ShowMessageAboutPostingToProductionComponentsRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	ObjectParameters = StructureData.ObjectParameters;
	GLAccountsForFilling = New Structure;
	
	If TypeOf(ObjectParameters.SalesOrder) = Type("DocumentRef.SubcontractorOrderReceived") 
		And ObjectParameters.OperationKind = Enums.OperationTypesProduction.ConvertFromWIP
		And StructureData.TabName = "Products" Then
		
		GLAccountsForFilling.Insert("ConsumptionGLAccount", StructureData.ConsumptionGLAccount);

	ElsIf ObjectParameters.OperationKind <> Enums.OperationTypesProduction.ConvertFromWIP
		Or StructureData.TabName <> "Inventory" Then
		
		OwnershipType = Common.ObjectAttributeValue(StructureData.Ownership, "OwnershipType");
		
		If OwnershipType = Enums.InventoryOwnershipTypes.CounterpartysInventory Then
			GLAccountsForFilling.Insert("InventoryReceivedGLAccount", StructureData.InventoryReceivedGLAccount);
		Else
			GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
		EndIf;
		
	EndIf;
	
	If StructureData.TabName = "Inventory"
			And ObjectParameters.OperationKind = Enums.OperationTypesProduction.ConvertFromWIP Then
		
		GLAccountsForFilling.Insert("ConsumptionGLAccount", StructureData.ConsumptionGLAccount);
		
	EndIf;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region InventoryOwnership

Function InventoryOwnershipParameters(DocObject) Export
	
	ParametersSet = New Array;
	
	BasisOrder = Common.ObjectAttributeValue(DocObject.BasisDocument, "BasisDocument");
	
	If TypeOf(BasisOrder) = Type("DocumentRef.SubcontractorOrderReceived") Then
		
		OwnershipParameters = New Structure("Counterparty, Contract");
		FillPropertyValues(OwnershipParameters, BasisOrder);
		
		Parameters = New Structure;
		Parameters.Insert("TableName", "Products");
		Parameters.Insert("OwnershipType", GetOwnershipTypeForCustomerInventory(DocObject.Products, BasisOrder));
		Parameters.Insert("Counterparty", OwnershipParameters.Counterparty);
		Parameters.Insert("Contract", OwnershipParameters.Contract);
		ParametersSet.Add(Parameters);
		
		Parameters = New Structure;
		Parameters.Insert("TableName", "Inventory");
		Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.CustomerProvidedInventory);
		Parameters.Insert("Counterparty", OwnershipParameters.Counterparty);
		Parameters.Insert("Contract", OwnershipParameters.Contract);
		ParametersSet.Add(Parameters);
		
	Else
		
		Parameters = New Structure;
		Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.OwnInventory);
		ParametersSet.Add(Parameters);
		
		Parameters = New Structure;
		Parameters.Insert("TableName", "Products");
		Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.OwnInventory);
		ParametersSet.Add(Parameters);
		
		Parameters = New Structure;
		Parameters.Insert("TableName", "Disposals");
		Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.OwnInventory);
		ParametersSet.Add(Parameters);
		
	EndIf;
	
	Return ParametersSet;
	
EndFunction

#EndRegion

#Region Batches

Function BatchCheckFillingParameters(DocObject) Export
	
	ParametersSet = New Array;
	
	#Region BatchCheckFillingParameters_Products
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "Products");
	
	Warehouses = New Array;
	
	If DocObject.OperationKind = Enums.OperationTypesProduction.Assembly
		Or DocObject.OperationKind = Enums.OperationTypesProduction.ConvertFromWIP Then
		
		WarehouseData = New Structure;
		WarehouseData.Insert("Warehouse", DocObject.ProductsStructuralUnit);
		WarehouseData.Insert("TrackingArea", "Inbound_Transfer");
		Warehouses.Add(WarehouseData);
		
		Parameters.Insert("Warehouses", Warehouses);
		
	ElsIf DocObject.OperationKind = Enums.OperationTypesProduction.Disassembly Then
		
		WarehouseData = New Structure;
		WarehouseData.Insert("Warehouse", DocObject.InventoryStructuralUnit);
		WarehouseData.Insert("TrackingArea", "Outbound_Transfer");
		Warehouses.Add(WarehouseData);
		
		Parameters.Insert("Warehouses", Warehouses);
		
	EndIf;
	
	ParametersSet.Add(Parameters);
	
	#EndRegion
	
	#Region BatchCheckFillingParameters_Inventory
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "Inventory");
	
	Warehouses = New Array;
	
	If DocObject.OperationKind = Enums.OperationTypesProduction.Assembly Then
		
		WarehouseData = New Structure;
		WarehouseData.Insert("Warehouse", DocObject.InventoryStructuralUnit);
		WarehouseData.Insert("TrackingArea", "Outbound_Transfer");
		Warehouses.Add(WarehouseData);
		
		Parameters.Insert("Warehouses", Warehouses);
		
	ElsIf DocObject.OperationKind = Enums.OperationTypesProduction.Disassembly Then
		
		WarehouseData = New Structure;
		WarehouseData.Insert("Warehouse", DocObject.ProductsStructuralUnit);
		WarehouseData.Insert("TrackingArea", "Inbound_Transfer");
		Warehouses.Add(WarehouseData);
		
		Parameters.Insert("Warehouses", Warehouses);
		
	EndIf;
	
	ParametersSet.Add(Parameters);
	
	#EndRegion
	
	#Region BatchCheckFillingParameters_Disposals
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "Disposals");
	
	Warehouses = New Array;
	
	WarehouseData = New Structure;
	WarehouseData.Insert("Warehouse", DocObject.DisposalsStructuralUnit);
	WarehouseData.Insert("TrackingArea", "Inbound_Transfer");
	Warehouses.Add(WarehouseData);
	
	Parameters.Insert("Warehouses", Warehouses);
	
	ParametersSet.Add(Parameters);
	
	#EndRegion
	
	Return ParametersSet;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#Region PrintInterface

// Generate objects printing forms.
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
		
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "GoodsContentForm") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"GoodsContentForm",
			NStr("en = 'Inventory allocation card'; ru = 'Бланк распределения запасов';pl = 'Karta alokacji zapasów';es_ES = 'Tarjeta de asignación de inventario';es_CO = 'Tarjeta de asignación de inventario';tr = 'Stok dağıtım kartı';it = 'Scheda di allocazione scorte';de = 'Bestandszuordnungskarte'"),
			PrintForm(ObjectsArray, PrintObjects, "GoodsContentForm", PrintParameters.Result));
		
	ElsIf PrintManagement.TemplatePrintRequired(PrintFormsCollection, "GoodsReceivedNote") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"GoodsReceivedNote",
			NStr("en = 'Goods received note'; ru = 'Уведомление о доставке товаров';pl = 'Przyjęcie zewnętrzne';es_ES = 'Nota de recepción de productos';es_CO = 'Nota de recepción de productos';tr = 'Teslim alındı belgesi';it = 'Nota di ricezione merci';de = 'Lieferantenlieferschein'"),
			DataProcessors.PrintGoodsReceivedNote.PrintForm(ObjectsArray, PrintObjects, "GoodsReceivedNote", PrintParameters.Result));
		
	EndIf;
		
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "WarrantyCardPerSerialNumber") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"WarrantyCardPerSerialNumber",
			NStr("en = 'Warranty card (per serial number)'; ru = 'Гарантийный талон (по серийным номерам)';pl = 'Karta gwarancyjna (dla numeru seryjnego)';es_ES = 'Tarjeta de garantía (por número de serie)';es_CO = 'Tarjeta de garantía (por número de serie)';tr = 'Garanti belgesi (seri numarasına göre)';it = 'Certificato di garanzia (per numero di serie)';de = 'Garantiekarte (nach Seriennummer)'"),
			WorkWithProductsServer.PrintWarrantyCard(ObjectsArray, PrintObjects, "PerSerialNumber", PrintParameters.Result));
		
	EndIf;	
															
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "WarrantyCardConsolidated") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"WarrantyCardConsolidated",
			NStr("en = 'Warranty card (consolidated)'; ru = 'Гарантийный талон (общий)';pl = 'Karta gwarancyjna (skonsolidowana)';es_ES = 'Tarjeta de garantía (consolidada)';es_CO = 'Tarjeta de garantía (consolidada)';tr = 'Garanti kartı (konsolide)';it = 'Certificato di garanzia (consolidato)';de = 'Garantiekarte (konsolidiert)'"),
			WorkWithProductsServer.PrintWarrantyCard(ObjectsArray, PrintObjects, "Consolidated", PrintParameters.Result));
		
	EndIf;

	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "GoodsReceivedNote";
	PrintCommand.Presentation				= NStr("en = 'Goods received note'; ru = 'Уведомление о доставке товаров';pl = 'Przyjęcie zewnętrzne';es_ES = 'Nota de recepción de productos';es_CO = 'Nota de recepción de productos';tr = 'Teslim alındı belgesi';it = 'Nota di ricezione merci';de = 'Lieferantenlieferschein'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;

	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "GoodsContentForm";
	PrintCommand.Presentation				= NStr("en = 'Inventory allocation card'; ru = 'Бланк распределения запасов';pl = 'Karta alokacji zapasów';es_ES = 'Tarjeta de asignación de inventario';es_CO = 'Tarjeta de asignación de inventario';tr = 'Stok dağıtım kartı';it = 'Scheda di allocazione scorte';de = 'Bestandszuordnungskarte'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 2;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "WarrantyCardPerSerialNumber";
	PrintCommand.Presentation				= NStr("en = 'Warranty card (per serial number)'; ru = 'Гарантийный талон (по серийным номерам)';pl = 'Karta gwarancyjna (dla numeru seryjnego)';es_ES = 'Tarjeta de garantía (por número de serie)';es_CO = 'Tarjeta de garantía (por número de serie)';tr = 'Garanti belgesi (seri numarasına göre)';it = 'Certificato di garanzia (per numero di serie)';de = 'Garantiekarte (nach Seriennummer)'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 3;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "WarrantyCardConsolidated";
	PrintCommand.Presentation				= NStr("en = 'Warranty card (consolidated)'; ru = 'Гарантийный талон (общий)';pl = 'Karta gwarancyjna (skonsolidowana)';es_ES = 'Tarjeta de garantía (consolidada)';es_CO = 'Tarjeta de garantía (consolidada)';tr = 'Garanti kartı (konsolide)';it = 'Certificato di garanzia (consolidato)';de = 'Garantiekarte (konsolidiert)'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 4;
	
EndProcedure

#EndRegion

#EndRegion

#Region AccountingTemplates

Function EntryTypes() Export 
	
	EntryTypes = New Array;
	
	Return EntryTypes;
	
EndFunction

Function AccountingFields() Export 
	
	AccountingFields = New Map;
	
	Return AccountingFields;
	
EndFunction

#EndRegion

#EndRegion

#Region Internal

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export
	
	Return New Structure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Return New Structure;
	
EndFunction

#EndRegion

#EndRegion 

#Region Private

#Region Assembly

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataAssembly(DocumentRefProduction, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	#Region QueryText
	Query.Text = 
	"SELECT
	|	DocumentHeader.Date AS Date,
	|	DocumentHeader.Ref AS Ref,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentHeader.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN DocumentHeader.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN DocumentHeader.CellInventory
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS CellInventory,
	|	DocumentHeader.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	DocumentHeader.InventoryStructuralUnit AS InventoryStructuralUnit,
	|	DocumentHeader.DisposalsStructuralUnit AS DisposalsStructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN DocumentHeader.ProductsCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS ProductsCell,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN DocumentHeader.DisposalsCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS DisposalsCell,
	|	CASE
	|		WHEN ProductionOrder.BasisDocument IS NULL
	|			THEN CASE
	|					WHEN DocumentHeader.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|							OR DocumentHeader.SalesOrder = VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	|						THEN UNDEFINED
	|					ELSE DocumentHeader.SalesOrder
	|				END
	|		WHEN ProductionOrder.BasisDocument = VALUE(Document.SalesOrder.EmptyRef)
	|				OR ProductionOrder.BasisDocument = VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	|				OR ProductionOrder.BasisDocument REFS Document.ProductionOrder
	|				OR ProductionOrder.BasisDocument REFS Document.SubcontractorOrderIssued
	|			THEN UNDEFINED
	|		ELSE ProductionOrder.BasisDocument
	|	END AS SalesOrder,
	|	UNDEFINED AS CustomerCorrOrder,
	|	DocumentHeader.BasisDocument AS BasisDocument,
	|	CASE
	|		WHEN DocumentHeader.BasisDocument = VALUE(Document.ProductionOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE DocumentHeader.BasisDocument
	|	END AS SupplySource
	|INTO TT_DocumentHeader
	|FROM
	|	Document.Manufacturing AS DocumentHeader
	|		LEFT JOIN Document.ProductionOrder AS ProductionOrder
	|		ON DocumentHeader.BasisDocument = ProductionOrder.Ref
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionProducts.LineNumber AS LineNumber,
	|	TT_DocumentHeader.Date AS Period,
	|	ProductionProducts.ConnectionKey AS ConnectionKey,
	|	TT_DocumentHeader.Ref AS Ref,
	|	TT_DocumentHeader.Company AS Company,
	|	TT_DocumentHeader.PresentationCurrency AS PresentationCurrency,
	|	TT_DocumentHeader.StructuralUnit AS StructuralUnit,
	|	TT_DocumentHeader.Cell AS Cell,
	|	TT_DocumentHeader.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	TT_DocumentHeader.ProductsStructuralUnit AS ProductsStructuralUnitToWarehouse,
	|	TT_DocumentHeader.ProductsCell AS ProductsCell,
	|	ProductionProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN ProductionProducts.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	ProductionProducts.Ownership AS Ownership,
	|	ProductionProducts.Specification AS Specification,
	|	CASE
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.OwnInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|		ELSE VALUE(Enum.InventoryAccountTypes.EmptyRef)
	|	END AS InventoryAccountType,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS CorrInventoryAccountType,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.ConsumptionGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ProductsGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.ConsumptionGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountDr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ProductsAccountDr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE ProductionProducts.ConsumptionGLAccount
	|	END AS ProductsAccountCr,
	|	TT_DocumentHeader.CustomerCorrOrder AS CustomerCorrOrder,
	|	TT_DocumentHeader.BasisDocument AS ProductionOrder,
	|	TT_DocumentHeader.SupplySource AS SupplySource,
	|	ProductionProducts.Quantity * ISNULL(CatalogUOM.Factor, 1) AS Quantity,
	|	0 AS Amount,
	|	TT_DocumentHeader.InventoryStructuralUnit AS InventoryStructuralUnit
	|INTO TemporaryTableProduction
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Document.Manufacturing.Products AS ProductionProducts
	|		ON TT_DocumentHeader.Ref = ProductionProducts.Ref
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (ProductionProducts.MeasurementUnit = CatalogUOM.Ref)
	|		LEFT JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
	|		ON (ProductionProducts.Ownership = CatalogInventoryOwnership.Ref)
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON (ProductionProducts.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON TT_DocumentHeader.ProductsStructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionProductsReservation.LineNumber AS LineNumber,
	|	TT_DocumentHeader.Date AS Period,
	|	TT_DocumentHeader.Company AS Company,
	|	TT_DocumentHeader.PresentationCurrency AS PresentationCurrency,
	|	TT_DocumentHeader.StructuralUnit AS StructuralUnit,
	|	TT_DocumentHeader.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	CASE
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.OwnInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|		ELSE VALUE(Enum.InventoryAccountTypes.EmptyRef)
	|	END AS InventoryAccountType,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS CorrInventoryAccountType,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProductsReservation.ConsumptionGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProductsReservation.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ProductsGLAccount,
	|	ProductionProductsReservation.Products AS Products,
	|	ProductionProductsReservation.Characteristic AS Characteristic,
	|	ProductionProductsReservation.Ownership AS Ownership,
	|	ProductionProductsReservation.Specification AS Specification,
	|	CASE
	|		WHEN ProductionProductsReservation.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR ProductionProductsReservation.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE ProductionProductsReservation.SalesOrder
	|	END AS SalesOrder,
	|	TT_DocumentHeader.SupplySource AS SupplySource,
	|	TT_DocumentHeader.BasisDocument AS ProductionOrder,
	|	TT_DocumentHeader.CustomerCorrOrder AS CustomerCorrOrder,
	|	ProductionProductsReservation.Quantity AS Quantity,
	|	0 AS Amount
	|INTO TemporaryTableProductionReservation
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Document.Manufacturing.Reservation AS ProductionProductsReservation
	|		ON TT_DocumentHeader.Ref = ProductionProductsReservation.Ref
	|		LEFT JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
	|		ON (ProductionProductsReservation.Ownership = CatalogInventoryOwnership.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableProductionReservation.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProductionReservation.Period AS Period,
	|	TableProductionReservation.Company AS Company,
	|	TableProductionReservation.PresentationCurrency AS PresentationCurrency,
	|	UNDEFINED AS PlanningPeriod,
	|	TableProductionReservation.StructuralUnit AS StructuralUnit,
	|	UNDEFINED AS StructuralUnitCorr,
	|	TableProductionReservation.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	TableProductionReservation.InventoryAccountType AS InventoryAccountType,
	|	TableProductionReservation.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TableProductionReservation.GLAccount AS GLAccount,
	|	TableProductionReservation.ProductsGLAccount AS ProductsGLAccount,
	|	UNDEFINED AS CorrGLAccount,
	|	TableProductionReservation.Products AS Products,
	|	UNDEFINED AS ProductsCorr,
	|	TableProductionReservation.Characteristic AS Characteristic,
	|	UNDEFINED AS CharacteristicCorr,
	|	TableProductionReservation.Batch AS Batch,
	|	UNDEFINED AS BatchCorr,
	|	TableProductionReservation.Ownership AS Ownership,
	|	UNDEFINED AS OwnershipCorr,
	|	TableProductionReservation.Specification AS Specification,
	|	UNDEFINED AS SpecificationCorr,
	|	UNDEFINED AS SalesOrder,
	|	TableProductionReservation.ProductionOrder AS ProductionOrder,
	|	TableProductionReservation.CustomerCorrOrder AS CustomerCorrOrder,
	|	UNDEFINED AS AccountDr,
	|	UNDEFINED AS AccountCr,
	|	UNDEFINED AS Content,
	|	CAST(&Production AS STRING(30)) AS ContentOfAccountingRecord,
	|	FALSE AS ProductionExpenses,
	|	SUM(TableProductionReservation.Quantity) AS Quantity,
	|	SUM(TableProductionReservation.Amount) AS Amount,
	|	FALSE AS FixedCost,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableProduction AS TableProductionReservation
	|
	|GROUP BY
	|	TableProductionReservation.Period,
	|	TableProductionReservation.Company,
	|	TableProductionReservation.PresentationCurrency,
	|	TableProductionReservation.StructuralUnit,
	|	TableProductionReservation.ProductsStructuralUnit,
	|	TableProductionReservation.InventoryAccountType,
	|	TableProductionReservation.CorrInventoryAccountType,
	|	TableProductionReservation.GLAccount,
	|	TableProductionReservation.ProductsGLAccount,
	|	TableProductionReservation.Products,
	|	TableProductionReservation.Characteristic,
	|	TableProductionReservation.Batch,
	|	TableProductionReservation.Ownership,
	|	TableProductionReservation.Specification,
	|	TableProductionReservation.ProductionOrder,
	|	TableProductionReservation.CustomerCorrOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	TableProduction.ProductsStructuralUnitToWarehouse AS StructuralUnit,
	|	TableProduction.ProductsCell AS Cell,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.Ownership AS Ownership,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.ProductsCell,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	TableProduction.Ownership
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProductionReservation.Period AS Period,
	|	&Company AS Company,
	|	TableProductionReservation.ProductsStructuralUnit AS StructuralUnit,
	|	TableProductionReservation.Products AS Products,
	|	TableProductionReservation.Characteristic AS Characteristic,
	|	TableProductionReservation.Ownership AS Ownership,
	|	TableProductionReservation.Specification AS Specification,
	|	SUM(TableProductionReservation.Quantity) AS Quantity,
	|	TableProductionReservation.SupplySource AS SupplySource,
	|	TableProductionReservation.Batch AS Batch
	|FROM
	|	TemporaryTableProduction AS TableProductionReservation
	|
	|GROUP BY
	|	TableProductionReservation.Period,
	|	TableProductionReservation.Products,
	|	TableProductionReservation.Characteristic,
	|	TableProductionReservation.Ownership,
	|	TableProductionReservation.Specification,
	|	TableProductionReservation.ProductsStructuralUnit,
	|	TableProductionReservation.SupplySource,
	|	TableProductionReservation.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	TableProduction.ProductionOrder AS ProductionOrder,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.ProductionOrder <> VALUE(Document.ProductionOrder.EmptyRef)
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.ProductionOrder,
	|	TableProduction.Products,
	|	TableProduction.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableAllocation.LineNumber AS LineNumber,
	|	TableAllocation.Ref AS Ref,
	|	TT_DocumentHeader.Date AS Period,
	|	TT_DocumentHeader.StructuralUnit AS StructuralUnit,
	|	TT_DocumentHeader.Cell AS Cell,
	|	TT_DocumentHeader.InventoryStructuralUnit AS InventoryStructuralUnit,
	|	TT_DocumentHeader.InventoryStructuralUnit AS StructuralUnitInventoryToWarehouse,
	|	TT_DocumentHeader.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	TT_DocumentHeader.CellInventory AS CellInventory,
	|	TT_DocumentHeader.BasisDocument AS BasisDocument,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableAllocation.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableAllocation.CorrGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CorrGLAccount,
	|	CASE
	|		WHEN TableAllocation.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedFinishedProducts)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS InventoryAccountType,
	|	CASE
	|		WHEN TableAllocation.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedFinishedProducts)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS CorrInventoryAccountType,
	|	TableAllocation.Products AS Products,
	|	TableAllocation.CorrProducts AS ProductsCorr,
	|	TableAllocation.Characteristic AS Characteristic,
	|	TableAllocation.CorrCharacteristic AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN TableAllocation.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	TableAllocation.Ownership AS Ownership,
	|	CatalogInventoryOwnership.OwnershipType AS OwnershipType,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPoliciesCorr.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPoliciesCorr.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN TableAllocation.CorrBatch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS BatchCorr,
	|	TableAllocation.CorrOwnership AS OwnershipCorr,
	|	TableAllocation.Specification AS SpecificationCorr,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS Specification,
	|	TT_DocumentHeader.SalesOrder AS SalesOrder,
	|	TableAllocation.Quantity AS Quantity,
	|	TableAllocation.CorrQuantity AS CorrQuantity,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableAllocation.CorrGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountDr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableAllocation.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountCr
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Document.Manufacturing.Allocation AS TableAllocation
	|		ON TT_DocumentHeader.Ref = TableAllocation.Ref
	|		LEFT JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
	|		ON (TableAllocation.Ownership = CatalogInventoryOwnership.Ref)
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON (TableAllocation.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON TT_DocumentHeader.InventoryStructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|		INNER JOIN Catalog.Products AS CatalogProductsCorr
	|		ON (TableAllocation.CorrProducts = CatalogProductsCorr.Ref)
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategoriesCorr
	|		ON (CatalogProductsCorr.ProductsCategory = ProductsCategoriesCorr.Ref)
	|			AND (CatalogProductsCorr.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicyCorr
	|		ON TT_DocumentHeader.ProductsStructuralUnit = BatchTrackingPolicyCorr.StructuralUnit
	|			AND (ProductsCategoriesCorr.BatchSettings = BatchTrackingPolicyCorr.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPoliciesCorr
	|		ON (BatchTrackingPolicyCorr.Policy = BatchTrackingPoliciesCorr.Ref)
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProduction.Period AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS EventDate,
	|	VALUE(Enum.SerialNumbersOperations.Receipt) AS Operation,
	|	TableSerialNumbersProducts.SerialNumber AS SerialNumber,
	|	&Company AS Company,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.Ownership AS Ownership,
	|	TableProduction.ProductsStructuralUnitToWarehouse AS StructuralUnit,
	|	TableProduction.ProductsCell AS Cell,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		INNER JOIN Document.Manufacturing.SerialNumbersProducts AS TableSerialNumbersProducts
	|		ON TableProduction.Ref = TableSerialNumbersProducts.Ref
	|			AND TableProduction.ConnectionKey = TableSerialNumbersProducts.ConnectionKey
	|WHERE
	|	TableSerialNumbersProducts.Ref = &Ref
	|	AND &UseSerialNumbers
	|
	|UNION ALL
	|
	|SELECT
	|	TT_DocumentHeader.Date,
	|	VALUE(AccumulationRecordType.Expense),
	|	TT_DocumentHeader.Date,
	|	VALUE(Enum.SerialNumbersOperations.Expense),
	|	TableSerialNumbers.SerialNumber,
	|	&Company,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN TableInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END,
	|	TableInventory.Ownership,
	|	TT_DocumentHeader.InventoryStructuralUnit,
	|	TT_DocumentHeader.CellInventory,
	|	1
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Document.Manufacturing.Inventory AS TableInventory
	|		ON TT_DocumentHeader.Ref = TableInventory.Ref
	|		INNER JOIN Document.Manufacturing.SerialNumbers AS TableSerialNumbers
	|		ON TT_DocumentHeader.Ref = TableSerialNumbers.Ref
	|			AND (TableInventory.ConnectionKey = TableSerialNumbers.ConnectionKey)
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON (TableInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON TT_DocumentHeader.InventoryStructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|WHERE
	|	&UseSerialNumbers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProductionReservation.Period AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	CatalogInventoryOwnership.Counterparty AS Counterparty,
	|	TableProductionReservation.SalesOrder AS SubcontractorOrder,
	|	TableProductionReservation.ProductionOrder AS ProductionOrder,
	|	TableProductionReservation.Products AS Products,
	|	TableProductionReservation.Characteristic AS Characteristic,
	|	SUM(TableProductionReservation.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProductionReservation AS TableProductionReservation
	|		INNER JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
	|		ON (CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory))
	|			AND TableProductionReservation.Ownership = CatalogInventoryOwnership.Ref
	|
	|GROUP BY
	|	TableProductionReservation.Period,
	|	CatalogInventoryOwnership.Counterparty,
	|	TableProductionReservation.SalesOrder,
	|	TableProductionReservation.ProductionOrder,
	|	TableProductionReservation.Products,
	|	TableProductionReservation.Characteristic,
	|	TableProductionReservation.Ownership
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryCostLayer.Period AS Period,
	|	InventoryCostLayer.Recorder AS Recorder,
	|	InventoryCostLayer.LineNumber AS LineNumber,
	|	InventoryCostLayer.Active AS Active,
	|	InventoryCostLayer.RecordType AS RecordType,
	|	InventoryCostLayer.Company AS Company,
	|	InventoryCostLayer.PresentationCurrency AS PresentationCurrency,
	|	InventoryCostLayer.Products AS Products,
	|	InventoryCostLayer.Characteristic AS Characteristic,
	|	InventoryCostLayer.Batch AS Batch,
	|	InventoryCostLayer.Ownership AS Ownership,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN InventoryCostLayer.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	InventoryCostLayer.StructuralUnit AS StructuralUnit,
	|	InventoryCostLayer.CostLayer AS CostLayer,
	|	InventoryCostLayer.CostObject AS CostObject,
	|	InventoryCostLayer.Quantity AS Quantity,
	|	InventoryCostLayer.Amount AS Amount,
	|	InventoryCostLayer.SourceRecord AS SourceRecord,
	|	InventoryCostLayer.VATRate AS VATRate,
	|	InventoryCostLayer.Responsible AS Responsible,
	|	InventoryCostLayer.Department AS Department,
	|	InventoryCostLayer.SourceDocument AS SourceDocument,
	|	InventoryCostLayer.CorrSalesOrder AS CorrSalesOrder,
	|	InventoryCostLayer.CorrStructuralUnit AS CorrStructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN InventoryCostLayer.CorrGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CorrGLAccount,
	|	InventoryCostLayer.RIMTransfer AS RIMTransfer,
	|	InventoryCostLayer.SalesRep AS SalesRep,
	|	InventoryCostLayer.Counterparty AS Counterparty,
	|	InventoryCostLayer.Currency AS Currency,
	|	InventoryCostLayer.SalesOrder AS SalesOrder,
	|	InventoryCostLayer.CorrCostObject AS CorrCostObject,
	|	InventoryCostLayer.CorrProducts AS CorrProducts,
	|	InventoryCostLayer.CorrBatch AS CorrBatch,
	|	InventoryCostLayer.CorrOwnership AS CorrOwnership,
	|	InventoryCostLayer.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	InventoryCostLayer.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	InventoryCostLayer.InventoryAccountType AS InventoryAccountType,
	|	InventoryCostLayer.CorrInventoryAccountType AS CorrInventoryAccountType
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS InventoryCostLayer
	|WHERE
	|	InventoryCostLayer.Recorder = &Ref
	|	AND NOT InventoryCostLayer.SourceRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ManufacturingInventory.LineNumber AS LineNumber,
	|	TT_DocumentHeader.Date AS Period,
	|	TT_DocumentHeader.Company AS Company,
	|	TT_DocumentHeader.InventoryStructuralUnit AS StructuralUnit,
	|	ManufacturingInventory.Products AS Products,
	|	ManufacturingInventory.Characteristic AS Characteristic,
	|	ManufacturingInventory.Batch AS Batch,
	|	TT_DocumentHeader.BasisDocument AS BasisDocument,
	|	ManufacturingInventory.Reserve * ISNULL(CatalogUOM.Factor, 1) AS Reserve,
	|	ManufacturingInventory.InventoryGLAccount AS InventoryGLAccount
	|INTO TemporaryTableReservedProducts
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Document.Manufacturing.Inventory AS ManufacturingInventory
	|		ON TT_DocumentHeader.Ref = ManufacturingInventory.Ref
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (ManufacturingInventory.MeasurementUnit = CatalogUOM.Ref)
	|WHERE
	|	ManufacturingInventory.Reserve > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ManufacturingInventory.LineNumber AS LineNumber,
	|	TT_DocumentHeader.Date AS Period,
	|	TT_DocumentHeader.Company AS Company,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	ManufacturingInventory.Products AS Products,
	|	ManufacturingInventory.Characteristic AS Characteristic,
	|	TT_DocumentHeader.BasisDocument AS ProductionDocument,
	|	ManufacturingInventory.Quantity * ISNULL(CatalogUOM.Factor, 1) AS Quantity
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Document.Manufacturing.Inventory AS ManufacturingInventory
	|		ON TT_DocumentHeader.Ref = ManufacturingInventory.Ref
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (ManufacturingInventory.MeasurementUnit = CatalogUOM.Ref)
	|WHERE
	|	TT_DocumentHeader.BasisDocument <> VALUE(Document.ProductionOrder.EmptyRef)";
	#EndRegion
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	AccountingPolicy = StructureAdditionalProperties.AccountingPolicy;
	
	Query.SetParameter("Ref",						DocumentRefProduction);
	Query.SetParameter("Company",					StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",		StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UseCharacteristics",		AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",				AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins",			AccountingPolicy.UseStorageBins);
	Query.SetParameter("UseSerialNumbers",			AccountingPolicy.UseSerialNumbers);
	Query.SetParameter("UseDefaultTypeOfAccounting",	StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.SetParameter("Production",				NStr("en = 'Production'; ru = 'Производство';pl = 'Produkcja';es_ES = 'Producción';es_CO = 'Producción';tr = 'Üretim';it = 'Produzione';de = 'Produktion'", MainLanguageCode));

	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryGoods", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory",
		StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods.CopyColumns());
		
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses"	, ResultsArray[4].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductionOrders"		, ResultsArray[6].Unload());
	
	// Generate documents posting table structure.
	DriveServer.GenerateTransactionsTable(DocumentRefProduction, StructureAdditionalProperties);
	
	// Generate table by orders placement.
	GenerateTableBackorders(DocumentRefProduction, StructureAdditionalProperties);
	GenerateTableProductRelease(ResultsArray[5].Unload(), StructureAdditionalProperties);

	// Generate materials allocation table.
	StructureAdditionalProperties.TableForRegisterRecords.Insert(
		"TableRawMaterialsConsumptionAssembly", ResultsArray[7].Unload());
	
	// Inventory.
	GenerateTableInventoryForAssembly(DocumentRefProduction, StructureAdditionalProperties);
	
	// Reserved products.
	GenerateTableReservedProductsForAssembly(DocumentRefProduction, StructureAdditionalProperties);
	
	// Reserved components
	GenerateTableReservedProducts(DocumentRefProduction, StructureAdditionalProperties);
	
	// By-products.
	If Not StructureAdditionalProperties.UseByProductsAccounting Then
		DataInitializationByDisposals(DocumentRefProduction, StructureAdditionalProperties);
	EndIf;
	
	// Serial numbers
	QueryResult8 = ResultsArray[8].Unload();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult8);
	If AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", QueryResult8);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
	EndIf;
	
	// Customer-owned inventory
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCustomerOwnedInventory", ResultsArray[9].Unload());
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableWorkInProgress", New ValueTable);
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableWorkInProgressStatement", New ValueTable);
	
	// Inventory cost layer (FIFO)
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryCostLayer", ResultsArray[10].Unload());
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductionComponents", ResultsArray[12].Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryForAssembly(DocumentRefProduction, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	ProductionInventory.LineNumber AS LineNumber,
	|	ProductionInventory.Period AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	ProductionInventory.StructuralUnit AS StructuralUnit,
	|	ProductionInventory.Cell AS Cell,
	|	ProductionInventory.InventoryStructuralUnit AS InventoryStructuralUnit,
	|	ProductionInventory.StructuralUnitInventoryToWarehouse AS StructuralUnitInventoryToWarehouse,
	|	ProductionInventory.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	ProductionInventory.CellInventory AS CellInventory,
	|	ProductionInventory.GLAccount AS GLAccount,
	|	ProductionInventory.CorrGLAccount AS CorrGLAccount,
	|	ProductionInventory.Products AS Products,
	|	ProductionInventory.ProductsCorr AS ProductsCorr,
	|	ProductionInventory.Characteristic AS Characteristic,
	|	ProductionInventory.CharacteristicCorr AS CharacteristicCorr,
	|	ProductionInventory.Batch AS Batch,
	|	ProductionInventory.Ownership AS Ownership,
	|	ProductionInventory.OwnershipType AS OwnershipType,
	|	ProductionInventory.BatchCorr AS BatchCorr,
	|	ProductionInventory.OwnershipCorr AS OwnershipCorr,
	|	ProductionInventory.InventoryAccountType AS InventoryAccountType,
	|	ProductionInventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	ProductionInventory.Specification AS Specification,
	|	ProductionInventory.SpecificationCorr AS SpecificationCorr,
	|	CASE
	|		WHEN ProductionInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR ProductionInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE ProductionInventory.SalesOrder
	|	END AS SalesOrder,
	|	ProductionInventory.Quantity AS Quantity,
	|	ProductionInventory.CorrQuantity AS CorrQuantity,
	|	0 AS Amount,
	|	ProductionInventory.AccountDr AS AccountDr,
	|	ProductionInventory.AccountCr AS AccountCr,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	ProductionInventory.BasisDocument AS ProductionOrder
	|INTO TemporaryTableInventory
	|FROM
	|	&TableRawMaterialsConsumptionAssembly AS ProductionInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.StructuralUnitInventoryToWarehouse AS StructuralUnit,
	|	TableInventory.ProductsStructuralUnit AS StructuralUnitCorr,
	|	TableInventory.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TableInventory.Products AS Products,
	|	TableInventory.ProductsCorr AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	TableInventory.OwnershipCorr AS OwnershipCorr,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.SpecificationCorr AS SpecificationCorr,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.SalesOrder AS CustomerCorrOrder,
	|	TableInventory.AccountDr AS AccountDr,
	|	TableInventory.AccountCr AS AccountCr,
	|	&InventoryDistribution AS Content,
	|	&InventoryDistribution AS ContentOfAccountingRecord,
	|	FALSE AS ProductionExpenses,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	SUM(TableInventory.CorrQuantity) AS CorrQuantity,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	0 AS Amount
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.PlanningPeriod,
	|	TableInventory.StructuralUnitInventoryToWarehouse,
	|	TableInventory.ProductsStructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.InventoryAccountType,
	|	TableInventory.CorrInventoryAccountType,
	|	TableInventory.Products,
	|	TableInventory.ProductsCorr,
	|	TableInventory.Characteristic,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.BatchCorr,
	|	TableInventory.OwnershipCorr,
	|	TableInventory.Specification,
	|	TableInventory.SpecificationCorr,
	|	TableInventory.SalesOrder,
	|	TableInventory.AccountDr,
	|	TableInventory.AccountCr,
	|	TableInventory.ProductsStructuralUnit,
	|	TableInventory.SalesOrder
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.StructuralUnitInventoryToWarehouse AS StructuralUnit,
	|	TableInventory.CellInventory AS Cell,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.StructuralUnitInventoryToWarehouse,
	|	TableInventory.CellInventory,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.Period AS Period,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	CatalogInventoryOwnership.Counterparty AS Counterparty
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|		INNER JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
	|		ON (CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory))
	|			AND TableInventory.Ownership = CatalogInventoryOwnership.Ref
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.Period,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	CatalogInventoryOwnership.Counterparty
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	TableInventory.ProductionOrder AS ProductionDocument
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.SalesOrder,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.ProductionOrder
	|
	|ORDER BY
	|	LineNumber";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefProduction);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	AccountingPolicy = StructureAdditionalProperties.AccountingPolicy;
	Query.SetParameter("UseCharacteristics", AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins", AccountingPolicy.UseStorageBins);
	Query.SetParameter("TableRawMaterialsConsumptionAssembly",
		StructureAdditionalProperties.TableForRegisterRecords.TableRawMaterialsConsumptionAssembly);
	Query.SetParameter("InventoryDistribution", NStr("en = 'Inventory allocation'; ru = 'Распределение запасов';pl = 'Alokacja zapasów';es_ES = 'Asignación del inventario';es_CO = 'Asignación del inventario';tr = 'Stok dağıtımı';it = 'Allocazione scorte';de = 'Bestandszuordnung'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	// Determine table for inventory accounting.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInventory", ResultsArray[1].Unload());
	
	// Inventory autotransfer.
	CalculateTableInventoryForAssembly(DocumentRefProduction, StructureAdditionalProperties);
	
	// Expand table for inventory.
	ResultsSelection = ResultsArray[2].Select();
	While ResultsSelection.Next() Do
		
		TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
		FillPropertyValues(TableRowExpense, ResultsSelection);
		
	EndDo;
 
	// Determine a table of consumed raw material accepted
	// for processing for which you will have to report in the future.
	StructureAdditionalProperties.TableForRegisterRecords.Insert(
		"TableStockReceivedFromThirdParties", ResultsArray[3].Unload());
	
	GoodsConsumed = ResultsArray[3].Unload();
	GoodsConsumed.FillValues(AccumulationRecordType.Receipt, "RecordType");
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsConsumedToDeclare", GoodsConsumed);
	
	// Determine table for movement by the needs of dependent demand positions.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand", ResultsArray[4].Unload());
	GenerateTableInventoryDemandAssembly(DocumentRefProduction, StructureAdditionalProperties);
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableRawMaterialsConsumptionAssembly");
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure CalculateTableInventoryForAssembly(DocumentRefProduction, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnit AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TableInventory.Products AS Products,
	|	TableInventory.Products AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Characteristic AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Batch AS BatchCorr,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.OwnershipCorr AS OwnershipCorr,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.SpecificationCorr AS SpecificationCorr,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.SalesOrder AS CustomerCorrOrder,
	|	UNDEFINED AS SourceDocument,
	|	UNDEFINED AS CorrSalesOrder,
	|	UNDEFINED AS Department,
	|	UNDEFINED AS Responsible,
	|	TableInventory.CorrGLAccount AS AccountDr,
	|	TableInventory.GLAccount AS AccountCr,
	|	&InventoryTransfer AS Content,
	|	&InventoryTransfer AS ContentOfAccountingRecord,
	|	TableInventory.CorrQuantity AS CorrQuantity,
	|	TableInventory.CostObject AS CostObject,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Amount) AS Amount,
	|	FALSE AS FixedCost
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.PlanningPeriod,
	|	TableInventory.StructuralUnit,
	|	TableInventory.InventoryStructuralUnit,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.OwnershipCorr,
	|	TableInventory.CorrQuantity,
	|	TableInventory.Specification,
	|	TableInventory.SpecificationCorr,
	|	TableInventory.SalesOrder,
	|	TableInventory.CostObject,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.SalesOrder,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.GLAccount,
	|	TableInventory.InventoryAccountType,
	|	TableInventory.CorrInventoryAccountType";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("InventoryTransfer", NStr("en = 'Inventory transfer'; ru = 'Перемещение запасов';pl = 'Przesunięcie międzymagazynowe';es_ES = 'Traslado del inventario';es_CO = 'Traslado del inventario';tr = 'Stok transferi';it = 'Trasferimento di scorte';de = 'Bestandsumlagerung'", MainLanguageCode));
	
	TableInventoryMove = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryMove", TableInventoryMove);
	TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
	IsWeightedAverage = StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage;
	
	If IsWeightedAverage Then
	
		#Region CalculateWeightedAverage
		
		Query = New Query;
		Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
		
		// Setting the exclusive lock for the controlled inventory balances.
		Query.Text = 
		"SELECT
		|	TableInventory.Company AS Company,
		|	TableInventory.PresentationCurrency AS PresentationCurrency,
		|	TableInventory.InventoryStructuralUnit AS StructuralUnit,
		|	TableInventory.Products AS Products,
		|	TableInventory.Characteristic AS Characteristic,
		|	TableInventory.Batch AS Batch,
		|	TableInventory.Ownership AS Ownership,
		|	TableInventory.CostObject AS CostObject,
		|	TableInventory.InventoryAccountType AS InventoryAccountType
		|FROM
		|	TemporaryTableInventory AS TableInventory
		|
		|GROUP BY
		|	TableInventory.Company,
		|	TableInventory.InventoryStructuralUnit,
		|	TableInventory.Products,
		|	TableInventory.Characteristic,
		|	TableInventory.PresentationCurrency,
		|	TableInventory.Batch,
		|	TableInventory.Ownership,
		|	TableInventory.CostObject,
		|	TableInventory.InventoryAccountType";
		
		QueryResult = Query.Execute();
		
		Block = New DataLock;
		LockItem = Block.Add("AccumulationRegister.Inventory");
		LockItem.Mode = DataLockMode.Exclusive;
		LockItem.DataSource = QueryResult;

		For Each ColumnQueryResult In QueryResult.Columns Do
			LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
		EndDo;
		Block.Lock();
		
		// Receiving inventory balances by cost.
		Query.Text =
		"SELECT
		|	InventoryBalances.Company AS Company,
		|	InventoryBalances.PresentationCurrency AS PresentationCurrency,
		|	InventoryBalances.StructuralUnit AS StructuralUnit,
		|	InventoryBalances.Products AS Products,
		|	InventoryBalances.Characteristic AS Characteristic,
		|	InventoryBalances.Batch AS Batch,
		|	InventoryBalances.Ownership AS Ownership,
		|	InventoryBalances.CostObject AS CostObject,
		|	InventoryBalances.InventoryAccountType AS InventoryAccountType,
		|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
		|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
		|FROM
		|	(SELECT
		|		InventoryBalances.Company AS Company,
		|		InventoryBalances.PresentationCurrency AS PresentationCurrency,
		|		InventoryBalances.StructuralUnit AS StructuralUnit,
		|		InventoryBalances.Products AS Products,
		|		InventoryBalances.Characteristic AS Characteristic,
		|		InventoryBalances.Batch AS Batch,
		|		InventoryBalances.Ownership AS Ownership,
		|		InventoryBalances.CostObject AS CostObject,
		|		InventoryBalances.InventoryAccountType AS InventoryAccountType,
		|		InventoryBalances.QuantityBalance AS QuantityBalance,
		|		InventoryBalances.AmountBalance AS AmountBalance
		|	FROM
		|		AccumulationRegister.Inventory.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, StructuralUnit, Products, Characteristic, Batch, Ownership, CostObject, InventoryAccountType) IN
		|					(SELECT
		|						TableInventory.Company,
		|						TableInventory.PresentationCurrency,
		|						TableInventory.InventoryStructuralUnit AS StructuralUnit,
		|						TableInventory.Products,
		|						TableInventory.Characteristic,
		|						TableInventory.Batch,
		|						TableInventory.Ownership,
		|						TableInventory.CostObject,
		|						TableInventory.InventoryAccountType
		|					FROM
		|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecordsInventory.Company,
		|		DocumentRegisterRecordsInventory.PresentationCurrency,
		|		DocumentRegisterRecordsInventory.StructuralUnit,
		|		DocumentRegisterRecordsInventory.Products,
		|		DocumentRegisterRecordsInventory.Characteristic,
		|		DocumentRegisterRecordsInventory.Batch,
		|		DocumentRegisterRecordsInventory.Ownership,
		|		DocumentRegisterRecordsInventory.CostObject,
		|		DocumentRegisterRecordsInventory.InventoryAccountType,
		|		CASE
		|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
		|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
		|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
		|				THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
		|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
		|		END
		|	FROM
		|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
		|	WHERE
		|		DocumentRegisterRecordsInventory.Recorder = &Ref
		|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod) AS InventoryBalances
		|
		|GROUP BY
		|	InventoryBalances.Company,
		|	InventoryBalances.PresentationCurrency,
		|	InventoryBalances.StructuralUnit,
		|	InventoryBalances.Products,
		|	InventoryBalances.Characteristic,
		|	InventoryBalances.Batch,
		|	InventoryBalances.Ownership,
		|	InventoryBalances.CostObject,
		|	InventoryBalances.InventoryAccountType";
		
		Query.SetParameter("Ref", DocumentRefProduction);
		Query.SetParameter("ControlTime",
			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
		Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
		
		QueryResult = Query.Execute();
		
		TableInventoryBalancesMove = QueryResult.Unload();
		TableInventoryBalancesMove.Indexes.Add(
			"Company, PresentationCurrency, StructuralUnit,
			|Products, Characteristic, Batch, Ownership, CostObject, InventoryAccountType");
		
		TemporaryTableInventoryTransfer = TableInventoryMove.CopyColumns();
		
		IsEmptyStructuralUnit		= Catalogs.BusinessUnits.EmptyRef();
		EmptyAccount				= ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
		EmptyProducts				= Catalogs.Products.EmptyRef();
		EmptyCharacteristic			= Catalogs.ProductsCharacteristics.EmptyRef();
		EmptyBatch					= Catalogs.ProductsBatches.EmptyRef();
		EmptySalesOrder				= Undefined;
		
		For n = 0 To TableInventoryMove.Count() - 1 Do
			
			RowTableInventoryTransfer = TableInventoryMove[n];
			
			StructureForSearchTransfer = New Structure;
			StructureForSearchTransfer.Insert("Company",				RowTableInventoryTransfer.Company);
			StructureForSearchTransfer.Insert("PresentationCurrency",	RowTableInventoryTransfer.PresentationCurrency);
			StructureForSearchTransfer.Insert("StructuralUnit",			RowTableInventoryTransfer.StructuralUnit);
			StructureForSearchTransfer.Insert("Products",				RowTableInventoryTransfer.Products);
			StructureForSearchTransfer.Insert("Characteristic",			RowTableInventoryTransfer.Characteristic);
			StructureForSearchTransfer.Insert("Batch",					RowTableInventoryTransfer.Batch);
			StructureForSearchTransfer.Insert("Ownership",				RowTableInventoryTransfer.Ownership);
			StructureForSearchTransfer.Insert("CostObject",				RowTableInventoryTransfer.CostObject);
			StructureForSearchTransfer.Insert("InventoryAccountType",	RowTableInventoryTransfer.InventoryAccountType);
			
			QuantityRequiredAvailableBalanceTransfer = RowTableInventoryTransfer.Quantity;
			
			If QuantityRequiredAvailableBalanceTransfer > 0 Then
				
				BalanceRowsArrayDisplacement = TableInventoryBalancesMove.FindRows(StructureForSearchTransfer);
				
				QuantityBalanceDisplacement = 0;
				AmountBalanceMove = 0;
				
				If BalanceRowsArrayDisplacement.Count() > 0 Then
					QuantityBalanceDisplacement = BalanceRowsArrayDisplacement[0].QuantityBalance;
					AmountBalanceMove = BalanceRowsArrayDisplacement[0].AmountBalance;
				EndIf;
				
				If QuantityBalanceDisplacement > 0
					And QuantityBalanceDisplacement > QuantityRequiredAvailableBalanceTransfer Then
					
					AmountToBeWrittenOffMove = Round(
						AmountBalanceMove * QuantityRequiredAvailableBalanceTransfer / QuantityBalanceDisplacement , 2, 1);
					
					BalanceRowsArrayDisplacement[0].QuantityBalance =
						BalanceRowsArrayDisplacement[0].QuantityBalance - QuantityRequiredAvailableBalanceTransfer;
					BalanceRowsArrayDisplacement[0].AmountBalance =
						BalanceRowsArrayDisplacement[0].AmountBalance - AmountToBeWrittenOffMove;
					
				ElsIf QuantityBalanceDisplacement = QuantityRequiredAvailableBalanceTransfer Then
					
					AmountToBeWrittenOffMove = AmountBalanceMove;
					
					BalanceRowsArrayDisplacement[0].QuantityBalance = 0;
					BalanceRowsArrayDisplacement[0].AmountBalance = 0;
				
				Else
					AmountToBeWrittenOffMove = 0;
				EndIf;
				
				// Expense.
				TableRowExpenseMove = TemporaryTableInventoryTransfer.Add();
				FillPropertyValues(TableRowExpenseMove, RowTableInventoryTransfer);
				TableRowExpenseMove.Amount = AmountToBeWrittenOffMove;
				TableRowExpenseMove.Quantity = QuantityRequiredAvailableBalanceTransfer;
				TableRowExpenseMove.SalesOrder = EmptySalesOrder;
				TableRowExpenseMove.Specification = Undefined;
				TableRowExpenseMove.SpecificationCorr = Undefined;
				
			EndIf;
		
		EndDo;
		
		#EndRegion
		
	Else
		
		TemporaryTableInventoryTransfer = TableInventoryMove.Copy();
		
	EndIf;
	
	TemporaryTableInventoryTransfer.Indexes.Add(
		"RecordType, PresentationCurrency, Company, StructuralUnit, Products,
		|Characteristic, Batch, Ownership, CostObject, InventoryAccountType");
	
	AmountForTransfer = 0;
	RowOfTableInventoryToBeTransferred = Undefined;
	UseDefaultTypeOfAccounting = StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting;
	
	TableInventoryInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory;
	TablesProductsToBeTransferred = TableInventoryInventory.CopyColumns();
	
	For n = 0 To TableInventoryInventory.Count() - 1 Do
		
		RowTableInventory = TableInventoryInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("RecordType",				AccumulationRecordType.Expense);
		StructureForSearch.Insert("Company",				RowTableInventory.Company);
		StructureForSearch.Insert("PresentationCurrency",	RowTableInventory.PresentationCurrency);
		StructureForSearch.Insert("StructuralUnit",			RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("Products",				RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic",			RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch",					RowTableInventory.Batch);
		StructureForSearch.Insert("Ownership",				RowTableInventory.Ownership);
		StructureForSearch.Insert("CostObject",				RowTableInventory.CostObject);
		StructureForSearch.Insert("InventoryAccountType",	RowTableInventory.InventoryAccountType);
		
		QuantityRequiredAvailableBalance = RowTableInventory.Quantity;
		
		If QuantityRequiredAvailableBalance > 0 Then
			
			ArrayQuantityBalance = 0;
			ArrayAmountBalance = 0;
			BalanceRowsArray = TemporaryTableInventoryTransfer.FindRows(StructureForSearch);
			For Each RowBalances In BalanceRowsArray Do
				ArrayQuantityBalance = ArrayQuantityBalance + RowBalances.Quantity;
				ArrayAmountBalance = ArrayAmountBalance + RowBalances.Amount;
			EndDo;
			
			QuantityBalance = 0;
			AmountBalance = 0;
			If BalanceRowsArray.Count() > 0 Then
				BalanceRowsArray[0].Quantity = ArrayQuantityBalance;
				BalanceRowsArray[0].Amount = ArrayAmountBalance;
				QuantityBalance = BalanceRowsArray[0].Quantity;
				AmountBalance = BalanceRowsArray[0].Amount;
			EndIf;
			
			If QuantityBalance > 0 And QuantityBalance > QuantityRequiredAvailableBalance Then
				
				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredAvailableBalance / QuantityBalance , 2, 1);
				
				BalanceRowsArray[0].Quantity = BalanceRowsArray[0].Quantity - QuantityRequiredAvailableBalance;
				BalanceRowsArray[0].Amount = BalanceRowsArray[0].Amount - AmountToBeWrittenOff;
				
			ElsIf QuantityBalance = QuantityRequiredAvailableBalance Then

				AmountToBeWrittenOff = AmountBalance;

				BalanceRowsArray[0].Quantity = 0;
				BalanceRowsArray[0].Amount = 0;

			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredAvailableBalance;
			TableRowExpense.ProductionExpenses = True;
			TableRowExpense.SalesOrder = Undefined;
			
			// Receipt.
			If Round(AmountToBeWrittenOff, 2, 1) <> 0
				Or RowTableInventory.CorrQuantity <> 0 Then
				
				TableRowReceipt = TablesProductsToBeTransferred.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.Products = RowTableInventory.ProductsCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.Ownership = RowTableInventory.OwnershipCorr;
				TableRowReceipt.InventoryAccountType = RowTableInventory.CorrInventoryAccountType;
				TableRowReceipt.CorrInventoryAccountType = Enums.InventoryAccountTypes.EmptyRef();
				TableRowReceipt.SalesOrder = RowTableInventory.SalesOrder;
				TableRowReceipt.CustomerCorrOrder = Undefined;
				TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = RowTableInventory.CorrQuantity;
				
				// Generate postings.
				If UseDefaultTypeOfAccounting And (Not IsWeightedAverage Or Round(AmountToBeWrittenOff, 2, 1) <> 0) Then
					RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
					FillPropertyValues(RowTableAccountingJournalEntries, TableRowReceipt);
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If TablesProductsToBeTransferred.Count() > 0 Then
		TablesProductsToBeTransferred.GroupBy(
		"Company,
		|RecordType,
		|PresentationCurrency,
		|Period,
		|PlanningPeriod,
		|ProductsStructuralUnit,
		|ProductionExpenses,
		|Products,
		|Batch,
		|Ownership,
		|CostObject,
		|InventoryAccountType,
		|CorrInventoryAccountType,
		|StructuralUnit,
		|GLAccount,
		|Characteristic,
		|SalesOrder,
		|Quantity,
		|SalesOrder,
		|CorrGLAccount",
		"Amount");
	EndIf;
	
	// Inventory writeoff.
	For Each StringProductsToBeTransferred In TablesProductsToBeTransferred Do
		
		// Receipt
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, StringProductsToBeTransferred);
		
	EndDo;
	
	CollapseAccountingJournalEntries(TableAccountingJournalEntries);
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryInventory");
	
	TablesProductsToBeTransferred = Undefined;
	
	AddOfflineRecords(DocumentRefProduction, StructureAdditionalProperties);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryDemandAssembly(DocumentRefProduction, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	TableInventoryDemand.Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	TableInventoryDemand.SalesOrder AS SalesOrder,
	|	TableInventoryDemand.Products AS Products,
	|	TableInventoryDemand.Characteristic AS Characteristic,
	|	TableInventoryDemand.ProductionOrder AS ProductionDocument
	|FROM
	|	TemporaryTableInventory AS TableInventoryDemand";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.InventoryDemand");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Balance receipt
	Query.Text =
	"SELECT
	|	InventoryDemandBalances.Company AS Company,
	|	InventoryDemandBalances.SalesOrder AS SalesOrder,
	|	InventoryDemandBalances.Products AS Products,
	|	InventoryDemandBalances.Characteristic AS Characteristic,
	|	InventoryDemandBalances.ProductionDocument AS ProductionDocument,
	|	SUM(InventoryDemandBalances.Quantity) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryDemandBalances.Company AS Company,
	|		InventoryDemandBalances.SalesOrder AS SalesOrder,
	|		InventoryDemandBalances.Products AS Products,
	|		InventoryDemandBalances.Characteristic AS Characteristic,
	|		InventoryDemandBalances.ProductionDocument AS ProductionDocument,
	|		SUM(InventoryDemandBalances.QuantityBalance) AS Quantity
	|	FROM
	|		AccumulationRegister.InventoryDemand.Balance(
	|				&ControlTime,
	|				(Company, MovementType, SalesOrder, Products, Characteristic, ProductionDocument) IN
	|					(SELECT
	|						TemporaryTableInventory.Company AS Company,
	|						VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|						TemporaryTableInventory.SalesOrder AS SalesOrder,
	|						TemporaryTableInventory.Products AS Products,
	|						TemporaryTableInventory.Characteristic AS Characteristic,
	|						TemporaryTableInventory.ProductionOrder AS ProductionDocument
	|					FROM
	|						TemporaryTableInventory AS TemporaryTableInventory)) AS InventoryDemandBalances
	|	
	|	GROUP BY
	|		InventoryDemandBalances.Company,
	|		InventoryDemandBalances.SalesOrder,
	|		InventoryDemandBalances.Products,
	|		InventoryDemandBalances.Characteristic,
	|		InventoryDemandBalances.ProductionDocument
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventoryDemand.Company,
	|		DocumentRegisterRecordsInventoryDemand.SalesOrder,
	|		DocumentRegisterRecordsInventoryDemand.Products,
	|		DocumentRegisterRecordsInventoryDemand.Characteristic,
	|		DocumentRegisterRecordsInventoryDemand.ProductionDocument,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventoryDemand.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.InventoryDemand AS DocumentRegisterRecordsInventoryDemand
	|	WHERE
	|		DocumentRegisterRecordsInventoryDemand.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventoryDemand.Period <= &ControlPeriod) AS InventoryDemandBalances
	|
	|GROUP BY
	|	InventoryDemandBalances.Company,
	|	InventoryDemandBalances.SalesOrder,
	|	InventoryDemandBalances.Products,
	|	InventoryDemandBalances.Characteristic,
	|	InventoryDemandBalances.ProductionDocument";
	
	Query.SetParameter("Ref", DocumentRefProduction);
	
	If ValueIsFilled(StructureAdditionalProperties.DocumentAttributes.SalesOrder) Then
		Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Else
		Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	EndIf;
	
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);
	
	QueryResult = Query.Execute();
	
	TableInventoryDemandBalance = QueryResult.Unload();
	TableInventoryDemandBalance.Indexes.Add("Company,SalesOrder,Products,Characteristic,ProductionDocument");
	
	TemporaryTableInventoryDemand = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand.CopyColumns();
	
	For Each RowTablesForInventory In StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company",			RowTablesForInventory.Company);
		StructureForSearch.Insert("SalesOrder",			RowTablesForInventory.SalesOrder);
		StructureForSearch.Insert("Products",			RowTablesForInventory.Products);
		StructureForSearch.Insert("Characteristic",		RowTablesForInventory.Characteristic);
		StructureForSearch.Insert("ProductionDocument",	RowTablesForInventory.ProductionDocument);
		
		BalanceRowsArray = TableInventoryDemandBalance.FindRows(StructureForSearch);
		If BalanceRowsArray.Count() > 0 And BalanceRowsArray[0].QuantityBalance > 0 Then
			
			If RowTablesForInventory.Quantity > BalanceRowsArray[0].QuantityBalance Then
				RowTablesForInventory.Quantity = BalanceRowsArray[0].QuantityBalance;
			EndIf;
			
			TableRowExpense = TemporaryTableInventoryDemand.Add();
			FillPropertyValues(TableRowExpense, RowTablesForInventory);
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand = TemporaryTableInventoryDemand;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableReservedProductsForAssembly(DocumentRefProduction, StructureAdditionalProperties)
	
	TableBackorders = StructureAdditionalProperties.TableForRegisterRecords.TableBackorders;
	TableBackorders.Indexes.Add("RecordType, Company, Products, Characteristic");
	TableBackorders.Sort("Quantity Desc");
	
	TableReservedProducts = DriveServer.EmptyReservedProductsTable();
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods.Count() - 1 Do
		
		RowTableInventoryProducts = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods[n];
		
		// If the production order is filled in
		// then check whether there are placed customers orders in the production order
		If ValueIsFilled(RowTableInventoryProducts.ProductionOrder) And Not ValueIsFilled(RowTableInventoryProducts.SalesOrder) Then
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("RecordType", AccumulationRecordType.Expense);
			StructureForSearch.Insert("Company", RowTableInventoryProducts.Company);
			StructureForSearch.Insert("Products", RowTableInventoryProducts.Products);
			StructureForSearch.Insert("Characteristic", RowTableInventoryProducts.Characteristic);
			
			ArrayPropertiesProducts = TableBackorders.FindRows(StructureForSearch);
			
			If ArrayPropertiesProducts.Count() = 0 Then
				Continue;
			EndIf;
			
			RemainingQuantity = RowTableInventoryProducts.Quantity;
			
			For Each RowAllocationArray In ArrayPropertiesProducts Do
				
				If RowAllocationArray.Quantity > 0 And RemainingQuantity > 0 Then
					
					NewRowReservedTable = TableReservedProducts.Add();
					FillPropertyValues(NewRowReservedTable, RowTableInventoryProducts);
					NewRowReservedTable.SalesOrder = RowAllocationArray.SalesOrder;
					NewRowReservedTable.Quantity = ?(RowAllocationArray.Quantity > RemainingQuantity, RemainingQuantity, RowAllocationArray.Quantity);
					
					RemainingQuantity = RemainingQuantity - NewRowReservedTable.Quantity;
					
					If ValueIsFilled(RowTableInventoryProducts.ProductsStructuralUnit) Then
						NewRowReservedTable.StructuralUnit = RowTableInventoryProducts.ProductsStructuralUnit;
					Else
						NewRowReservedTable.StructuralUnit = RowTableInventoryProducts.StructuralUnit;
					EndIf;
					NewRowReservedTable.GLAccount = RowTableInventoryProducts.ProductsGLAccount;
					
				EndIf;
				
			EndDo;
			
		ElsIf ValueIsFilled(RowTableInventoryProducts.SalesOrder) Then
			
			If ValueIsFilled(RowTableInventoryProducts.ProductsStructuralUnit) Then
				StructuralUnit = RowTableInventoryProducts.ProductsStructuralUnit;
			Else
				StructuralUnit = RowTableInventoryProducts.StructuralUnit;
			EndIf;
			
			NewRowReservedTable = TableReservedProducts.Add();
			FillPropertyValues(NewRowReservedTable, RowTableInventoryProducts);
			
			NewRowReservedTable.StructuralUnit = StructuralUnit;
			NewRowReservedTable.GLAccount = RowTableInventoryProducts.ProductsGLAccount;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableReservedProducts", TableReservedProducts);
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryGoods");
	TableProductsAllocation = Undefined;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableBackorders(DocumentRefProduction, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.Company AS Company,
	|	TableProduction.SalesOrder AS SalesOrder,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.SupplySource AS SupplySource,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProductionReservation AS TableProduction
	|WHERE
	|	TableProduction.SalesOrder <> UNDEFINED
	|	AND TableProduction.SalesOrder REFS Document.SalesOrder
	|
	|GROUP BY
	|	TableProduction.Company,
	|	TableProduction.Period,
	|	TableProduction.Characteristic,
	|	TableProduction.SalesOrder,
	|	TableProduction.SupplySource,
	|	TableProduction.Products";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBackorders", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableProductRelease(TableProductReleasePre, StructureAdditionalProperties)
	
	TableProductRelease = DriveServer.EmptyProductReleaseTable();
	
	For n = 0 To TableProductReleasePre.Count() - 1 Do
		
		RowTableInventory = TableProductReleasePre[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("SupplySource",	RowTableInventory.SupplySource);
		StructureForSearch.Insert("Products",		RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic",	RowTableInventory.Characteristic);
		
		PlacedOrdersTable = StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.Copy(StructureForSearch);
		PlacedOrdersTable.Sort("SalesOrder");
		
		RowTableInventoryQuantity = RowTableInventory.Quantity;
		
		If PlacedOrdersTable.Count() > 0 Then
			
			For Each PlacedOrdersRow In PlacedOrdersTable Do
				
				If RowTableInventoryQuantity > 0 AND PlacedOrdersRow.Quantity >= RowTableInventoryQuantity Then
					
					// Reserve
					NewRowReservedTable = TableProductRelease.Add();
					FillPropertyValues(NewRowReservedTable, RowTableInventory);
					NewRowReservedTable.SalesOrder = PlacedOrdersRow.SalesOrder;
					NewRowReservedTable.Quantity = RowTableInventoryQuantity;
					
					RowTableInventoryQuantity = 0;
					
				ElsIf RowTableInventoryQuantity > 0 AND PlacedOrdersRow.Quantity < RowTableInventoryQuantity Then
					
					// Reserve
					NewRowReservedTable = TableProductRelease.Add();
					FillPropertyValues(NewRowReservedTable, RowTableInventory);
					NewRowReservedTable.SalesOrder = ?(ValueIsFilled(PlacedOrdersRow.SalesOrder), PlacedOrdersRow.SalesOrder, Undefined);
					NewRowReservedTable.Quantity = PlacedOrdersRow.Quantity;
					
					RowTableInventoryQuantity = RowTableInventoryQuantity - PlacedOrdersRow.Quantity;
					
				EndIf;
				
			EndDo;
		Else 
			NewRowReservedTable = TableProductRelease.Add();
			FillPropertyValues(NewRowReservedTable, RowTableInventory);
			
			NewRowReservedTable.Quantity = RowTableInventoryQuantity;
		EndIf;
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductRelease", TableProductRelease);
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRefProduction, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion

#Region Disassembly

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataDisassembly(DocumentRefProduction, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	#Region QueryText
	Query.Text = 
	"SELECT
	|	DocumentHeader.Date AS Date,
	|	DocumentHeader.Ref AS Ref,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentHeader.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN DocumentHeader.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN DocumentHeader.CellInventory
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS CellInventory,
	|	DocumentHeader.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	DocumentHeader.InventoryStructuralUnit AS InventoryStructuralUnit,
	|	DocumentHeader.DisposalsStructuralUnit AS DisposalsStructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN DocumentHeader.ProductsCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS ProductsCell,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN DocumentHeader.DisposalsCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS DisposalsCell,
	|	CASE
	|		WHEN DocumentHeader.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR DocumentHeader.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE DocumentHeader.SalesOrder
	|	END AS SalesOrder,
	|	UNDEFINED AS CustomerCorrOrder,
	|	DocumentHeader.BasisDocument AS BasisDocument,
	|	CASE
	|		WHEN DocumentHeader.BasisDocument = VALUE(Document.ProductionOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE DocumentHeader.BasisDocument
	|	END AS SupplySource
	|INTO TT_DocumentHeader
	|FROM
	|	Document.Manufacturing AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionInventory.LineNumber AS LineNumber,
	|	TT_DocumentHeader.Date AS Period,
	|	ProductionInventory.Ref AS Ref,
	|	ProductionInventory.ConnectionKey AS ConnectionKey,
	|	TT_DocumentHeader.Company AS Company,
	|	TT_DocumentHeader.PresentationCurrency AS PresentationCurrency,
	|	TT_DocumentHeader.StructuralUnit AS StructuralUnit,
	|	TT_DocumentHeader.Cell AS Cell,
	|	TT_DocumentHeader.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	TT_DocumentHeader.ProductsStructuralUnit AS ProductsStructuralUnitToWarehouse,
	|	TT_DocumentHeader.ProductsCell AS ProductsCell,
	|	ProductionInventory.Specification AS Specification,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionInventory.ConsumptionGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ProductsGLAccount,
	|	ProductionInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN ProductionInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	ProductionInventory.Ownership AS Ownership,
	|	CASE
	|		WHEN ProductionInventory.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedFinishedProducts)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS InventoryAccountType,
	|	CASE
	|		WHEN ProductionInventory.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedFinishedProducts)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS CorrInventoryAccountType,
	|	TT_DocumentHeader.CustomerCorrOrder AS CustomerCorrOrder,
	|	TT_DocumentHeader.BasisDocument AS ProductionOrder,
	|	TT_DocumentHeader.SupplySource AS SupplySource,
	|	ProductionInventory.Quantity * ISNULL(CatalogUOM.Factor, 1) AS Quantity,
	|	0 AS Amount
	|INTO TemporaryTableProduction
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Document.Manufacturing.Inventory AS ProductionInventory
	|		ON TT_DocumentHeader.Ref = ProductionInventory.Ref
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (ProductionInventory.MeasurementUnit = CatalogUOM.Ref)
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON (ProductionInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON TT_DocumentHeader.ProductsStructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionInventory.LineNumber AS LineNumber,
	|	TT_DocumentHeader.Date AS Period,
	|	TT_DocumentHeader.Company AS Company,
	|	TT_DocumentHeader.PresentationCurrency AS PresentationCurrency,
	|	TT_DocumentHeader.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ProductsGLAccount,
	|	ProductionInventory.Products AS Products,
	|	ProductionInventory.Characteristic AS Characteristic,
	|	ProductionInventory.Ownership AS Ownership,
	|	CASE
	|		WHEN ProductionInventory.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedFinishedProducts)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS InventoryAccountType,
	|	ProductionInventory.Specification AS Specification,
	|	CASE
	|		WHEN ProductionInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR ProductionInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE ProductionInventory.SalesOrder
	|	END AS SalesOrder,
	|	TT_DocumentHeader.BasisDocument AS ProductionOrder,
	|	TT_DocumentHeader.CustomerCorrOrder AS CustomerCorrOrder,
	|	TT_DocumentHeader.SupplySource AS SupplySource,
	|	ProductionInventory.Quantity AS Quantity,
	|	0 AS Amount
	|INTO TemporaryTableProductionReservation
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Document.Manufacturing.Reservation AS ProductionInventory
	|		ON TT_DocumentHeader.Ref = ProductionInventory.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableProduction.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.Company AS Company,
	|	UNDEFINED AS PlanningPeriod,
	|	TableProduction.PresentationCurrency AS PresentationCurrency,
	|	TableProduction.ProductsStructuralUnit AS StructuralUnit,
	|	UNDEFINED AS StructuralUnitCorr,
	|	TableProduction.ProductsGLAccount AS GLAccount,
	|	UNDEFINED AS CorrGLAccount,
	|	TableProduction.Products AS Products,
	|	UNDEFINED AS ProductsCorr,
	|	TableProduction.Characteristic AS Characteristic,
	|	UNDEFINED AS CharacteristicCorr,
	|	TableProduction.Batch AS Batch,
	|	UNDEFINED AS BatchCorr,
	|	TableProduction.Ownership AS Ownership,
	|	UNDEFINED AS OwnershipCorr,
	|	TableProduction.InventoryAccountType AS InventoryAccountType,
	|	UNDEFINED AS CorrInventoryAccountType,
	|	TableProduction.Specification AS Specification,
	|	UNDEFINED AS SpecificationCorr,
	|	UNDEFINED AS SalesOrder,
	|	TableProduction.ProductionOrder AS ProductionOrder,
	|	TableProduction.CustomerCorrOrder AS CustomerCorrOrder,
	|	UNDEFINED AS AccountDr,
	|	UNDEFINED AS AccountCr,
	|	UNDEFINED AS Content,
	|	CAST(&Production AS STRING(30)) AS ContentOfAccountingRecord,
	|	FALSE AS ProductionExpenses,
	|	SUM(TableProduction.Quantity) AS Quantity,
	|	SUM(TableProduction.Amount) AS Amount,
	|	FALSE AS FixedCost,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.Company,
	|	TableProduction.PresentationCurrency,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	TableProduction.Ownership,
	|	TableProduction.InventoryAccountType,
	|	TableProduction.Specification,
	|	TableProduction.ProductionOrder,
	|	TableProduction.CustomerCorrOrder,
	|	TableProduction.ProductsStructuralUnit,
	|	TableProduction.ProductsGLAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	TableProduction.ProductsStructuralUnitToWarehouse AS StructuralUnit,
	|	TableProduction.ProductsCell AS Cell,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.Ownership AS Ownership,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.ProductsCell,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	TableProduction.Ownership
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	TableProduction.ProductsStructuralUnit AS StructuralUnit,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.Ownership AS Ownership,
	|	TableProduction.Specification AS Specification,
	|	SUM(TableProduction.Quantity) AS Quantity,
	|	TableProduction.SupplySource AS SupplySource
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	TableProduction.Ownership,
	|	TableProduction.Specification,
	|	TableProduction.ProductsStructuralUnit,
	|	TableProduction.SupplySource
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	TableProduction.ProductionOrder AS ProductionOrder,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.ProductionOrder <> VALUE(Document.ProductionOrder.EmptyRef)
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.ProductionOrder,
	|	TableProduction.Products,
	|	TableProduction.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableAllocation.LineNumber AS LineNumber,
	|	TableAllocation.Ref AS Ref,
	|	TT_DocumentHeader.Date AS Period,
	|	TT_DocumentHeader.InventoryStructuralUnit AS StructuralUnit,
	|	TT_DocumentHeader.CellInventory AS Cell,
	|	TT_DocumentHeader.ProductsStructuralUnit AS StructuralUnitCorr,
	|	TT_DocumentHeader.BasisDocument AS BasisDocument,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableAllocation.CorrGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableAllocation.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CorrGLAccount,
	|	TableAllocation.CorrProducts AS Products,
	|	TableAllocation.Products AS ProductsCorr,
	|	TableAllocation.CorrCharacteristic AS Characteristic,
	|	TableAllocation.Characteristic AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPoliciesCorr.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPoliciesCorr.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN TableAllocation.CorrBatch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	TableAllocation.CorrOwnership AS Ownership,
	|	CatalogInventoryOwnership.OwnershipType AS OwnershipType,
	|	CASE
	|		WHEN TableAllocation.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedFinishedProducts)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS InventoryAccountType,
	|	CASE
	|		WHEN TableAllocation.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedFinishedProducts)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS CorrInventoryAccountType,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN TableAllocation.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS BatchCorr,
	|	TableAllocation.Ownership AS OwnershipCorr,
	|	TableAllocation.Specification AS Specification,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS SpecificationCorr,
	|	TT_DocumentHeader.SalesOrder AS SalesOrder,
	|	TableAllocation.Quantity AS Quantity,
	|	0 AS Amount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableAllocation.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountDr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableAllocation.CorrGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountCr,
	|	0 AS CostPercentage
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Document.Manufacturing.Allocation AS TableAllocation
	|		ON TT_DocumentHeader.Ref = TableAllocation.Ref
	|		LEFT JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
	|		ON (TableAllocation.CorrOwnership = CatalogInventoryOwnership.Ref)
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON (TableAllocation.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON TT_DocumentHeader.ProductsStructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|		INNER JOIN Catalog.Products AS CatalogProductsCorr
	|		ON (TableAllocation.CorrProducts = CatalogProductsCorr.Ref)
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategoriesCorr
	|		ON (CatalogProductsCorr.ProductsCategory = ProductsCategoriesCorr.Ref)
	|			AND (CatalogProductsCorr.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicyCorr
	|		ON TT_DocumentHeader.InventoryStructuralUnit = BatchTrackingPolicyCorr.StructuralUnit
	|			AND (ProductsCategoriesCorr.BatchSettings = BatchTrackingPolicyCorr.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPoliciesCorr
	|		ON (BatchTrackingPolicyCorr.Policy = BatchTrackingPoliciesCorr.Ref)
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProduction.Period AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS EventDate,
	|	VALUE(Enum.SerialNumbersOperations.Receipt) AS Operation,
	|	TableSerialNumbers.SerialNumber AS SerialNumber,
	|	&Company AS Company,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.Ownership AS Ownership,
	|	TableProduction.ProductsStructuralUnitToWarehouse AS StructuralUnit,
	|	TableProduction.ProductsCell AS Cell,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		INNER JOIN Document.Manufacturing.SerialNumbers AS TableSerialNumbers
	|		ON TableProduction.Ref = TableSerialNumbers.Ref
	|			AND TableProduction.ConnectionKey = TableSerialNumbers.ConnectionKey
	|WHERE
	|	&UseSerialNumbers
	|
	|UNION ALL
	|
	|SELECT
	|	TT_DocumentHeader.Date,
	|	VALUE(AccumulationRecordType.Expense),
	|	TT_DocumentHeader.Date,
	|	VALUE(Enum.SerialNumbersOperations.Expense),
	|	TableSerialNumbers.SerialNumber,
	|	&Company,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN TableInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END,
	|	TableInventory.Ownership,
	|	TT_DocumentHeader.InventoryStructuralUnit,
	|	TT_DocumentHeader.CellInventory,
	|	1
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Document.Manufacturing.Products AS TableInventory
	|		ON TT_DocumentHeader.Ref = TableInventory.Ref
	|		INNER JOIN Document.Manufacturing.SerialNumbersProducts AS TableSerialNumbers
	|		ON TT_DocumentHeader.Ref = TableSerialNumbers.Ref
	|			AND (TableInventory.ConnectionKey = TableSerialNumbers.ConnectionKey)
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON (TableInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON TT_DocumentHeader.InventoryStructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|WHERE
	|	&UseSerialNumbers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryCostLayer.Period AS Period,
	|	InventoryCostLayer.Recorder AS Recorder,
	|	InventoryCostLayer.LineNumber AS LineNumber,
	|	InventoryCostLayer.Active AS Active,
	|	InventoryCostLayer.RecordType AS RecordType,
	|	InventoryCostLayer.Company AS Company,
	|	InventoryCostLayer.PresentationCurrency AS PresentationCurrency,
	|	InventoryCostLayer.Products AS Products,
	|	InventoryCostLayer.Characteristic AS Characteristic,
	|	InventoryCostLayer.Batch AS Batch,
	|	InventoryCostLayer.Ownership AS Ownership,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN InventoryCostLayer.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	InventoryCostLayer.StructuralUnit AS StructuralUnit,
	|	InventoryCostLayer.CostLayer AS CostLayer,
	|	InventoryCostLayer.CostObject AS CostObject,
	|	InventoryCostLayer.Quantity AS Quantity,
	|	InventoryCostLayer.Amount AS Amount,
	|	InventoryCostLayer.SourceRecord AS SourceRecord,
	|	InventoryCostLayer.VATRate AS VATRate,
	|	InventoryCostLayer.Responsible AS Responsible,
	|	InventoryCostLayer.Department AS Department,
	|	InventoryCostLayer.SourceDocument AS SourceDocument,
	|	InventoryCostLayer.CorrSalesOrder AS CorrSalesOrder,
	|	InventoryCostLayer.CorrStructuralUnit AS CorrStructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN InventoryCostLayer.CorrGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CorrGLAccount,
	|	InventoryCostLayer.RIMTransfer AS RIMTransfer,
	|	InventoryCostLayer.SalesRep AS SalesRep,
	|	InventoryCostLayer.Counterparty AS Counterparty,
	|	InventoryCostLayer.Currency AS Currency,
	|	InventoryCostLayer.SalesOrder AS SalesOrder,
	|	InventoryCostLayer.CorrCostObject AS CorrCostObject,
	|	InventoryCostLayer.CorrProducts AS CorrProducts,
	|	InventoryCostLayer.CorrCharacteristic AS CorrCharacteristic,
	|	InventoryCostLayer.CorrBatch AS CorrBatch,
	|	InventoryCostLayer.CorrOwnership AS CorrOwnership,
	|	InventoryCostLayer.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	InventoryCostLayer.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	InventoryCostLayer.InventoryAccountType AS InventoryAccountType,
	|	InventoryCostLayer.CorrInventoryAccountType AS CorrInventoryAccountType
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS InventoryCostLayer
	|WHERE
	|	InventoryCostLayer.Recorder = &Ref
	|	AND NOT InventoryCostLayer.SourceRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ManufacturingProducts.LineNumber AS LineNumber,
	|	TT_DocumentHeader.Date AS Period,
	|	TT_DocumentHeader.Company AS Company,
	|	TT_DocumentHeader.InventoryStructuralUnit AS StructuralUnit,
	|	ManufacturingProducts.Products AS Products,
	|	ManufacturingProducts.Characteristic AS Characteristic,
	|	ManufacturingProducts.Batch AS Batch,
	|	TT_DocumentHeader.BasisDocument AS BasisDocument,
	|	ManufacturingProducts.Reserve * ISNULL(CatalogUOM.Factor, 1) AS Reserve,
	|	ManufacturingProducts.InventoryGLAccount AS InventoryGLAccount
	|INTO TemporaryTableReservedProducts
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Document.Manufacturing.Products AS ManufacturingProducts
	|		ON TT_DocumentHeader.Ref = ManufacturingProducts.Ref
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (ManufacturingProducts.MeasurementUnit = CatalogUOM.Ref)
	|WHERE
	|	ManufacturingProducts.Reserve > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ManufacturingProducts.LineNumber AS LineNumber,
	|	TT_DocumentHeader.Date AS Period,
	|	TT_DocumentHeader.Company AS Company,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	ManufacturingProducts.Products AS Products,
	|	ManufacturingProducts.Characteristic AS Characteristic,
	|	TT_DocumentHeader.BasisDocument AS ProductionDocument,
	|	ManufacturingProducts.Quantity * ISNULL(CatalogUOM.Factor, 1) AS Quantity
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Document.Manufacturing.Products AS ManufacturingProducts
	|		ON TT_DocumentHeader.Ref = ManufacturingProducts.Ref
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (ManufacturingProducts.MeasurementUnit = CatalogUOM.Ref)
	|WHERE
	|	TT_DocumentHeader.BasisDocument <> VALUE(Document.ProductionOrder.EmptyRef)";

	#EndRegion
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	AccountingPolicy = StructureAdditionalProperties.AccountingPolicy;
	Query.SetParameter("Ref",				DocumentRefProduction);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",		StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UseCharacteristics",		AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",			AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins",			AccountingPolicy.UseStorageBins);
	Query.SetParameter("UseSerialNumbers"		,	AccountingPolicy.UseSerialNumbers);
	Query.SetParameter("UseDefaultTypeOfAccounting",	StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.SetParameter("Production"				, NStr("en = 'Production'; ru = 'Производство';pl = 'Produkcja';es_ES = 'Producción';es_CO = 'Producción';tr = 'Üretim';it = 'Produzione';de = 'Produktion'", MainLanguageCode));

	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryGoods", ResultsArray[3].Unload());
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory",
		StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods.CopyColumns());
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", ResultsArray[4].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductionOrders", ResultsArray[6].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsConsumedToDeclare", New ValueTable);
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefProduction, StructureAdditionalProperties);
	
	// Generate table by orders placement.
	GenerateTableBackorders(DocumentRefProduction, StructureAdditionalProperties);
	GenerateTableProductRelease(ResultsArray[5].Unload(), StructureAdditionalProperties);
	
	// Generate materials allocation table.
	StructureAdditionalProperties.TableForRegisterRecords.Insert(
		"TableOfRawMaterialsConsumptionDisassembling", ResultsArray[7].Unload());
	
	// Inventory.
	GenerateTableInventoryForDisassembly(DocumentRefProduction, StructureAdditionalProperties);
	
	// Products.
	GenerateTableInventoryQuantitiesForDisassembly(DocumentRefProduction, StructureAdditionalProperties);
	
	// Reserved components
	GenerateTableReservedProducts(DocumentRefProduction, StructureAdditionalProperties);
	
	// Disposals.
	If Not StructureAdditionalProperties.UseByProductsAccounting Then
		DataInitializationByDisposals(DocumentRefProduction, StructureAdditionalProperties);
	EndIf;
	
	// Serial numbers
	If StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Count()>0 Then
		QueryResult9 = ResultsArray[8].Unload();
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult9);
		If AccountingPolicy.SerialNumbersBalance Then
			StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", QueryResult9);
		Else
			StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
		EndIf;
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", New ValueTable);
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
	EndIf;
	
	// Customer-owned inventory
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCustomerOwnedInventory", New ValueTable);
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableWorkInProgress", New ValueTable);
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableWorkInProgressStatement", New ValueTable);
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryCostLayer", ResultsArray[9].Unload());
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductionComponents", ResultsArray[11].Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryForDisassembly(DocumentRefProduction, StructureAdditionalProperties)

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	ProductionInventory.LineNumber AS LineNumber,
	|	ProductionInventory.Period AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	ProductionInventory.StructuralUnit AS StructuralUnit,
	|	ProductionInventory.Cell AS Cell,
	|	ProductionInventory.StructuralUnitCorr AS StructuralUnitCorr,
	|	ProductionInventory.GLAccount AS GLAccount,
	|	ProductionInventory.CorrGLAccount AS CorrGLAccount,
	|	ProductionInventory.Products AS Products,
	|	ProductionInventory.ProductsCorr AS ProductsCorr,
	|	ProductionInventory.Characteristic AS Characteristic,
	|	ProductionInventory.CharacteristicCorr AS CharacteristicCorr,
	|	ProductionInventory.Batch AS Batch,
	|	ProductionInventory.Ownership AS Ownership,
	|	ProductionInventory.OwnershipType AS OwnershipType,
	|	ProductionInventory.BatchCorr AS BatchCorr,
	|	ProductionInventory.OwnershipCorr AS OwnershipCorr,
	|	ProductionInventory.InventoryAccountType AS InventoryAccountType,
	|	ProductionInventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	ProductionInventory.Specification AS Specification,
	|	ProductionInventory.SpecificationCorr AS SpecificationCorr,
	|	ProductionInventory.SalesOrder AS SalesOrder,
	|	ProductionInventory.Quantity AS Quantity,
	|	0 AS Amount,
	|	ProductionInventory.AccountDr AS AccountDr,
	|	ProductionInventory.AccountCr AS AccountCr,
	|	ProductionInventory.CostPercentage AS CostPercentage,
	|	ProductionInventory.BasisDocument AS ProductionOrder,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject
	|INTO TemporaryTableInventory
	|FROM
	|	&TableOfRawMaterialsConsumptionDisassembling AS ProductionInventory
	|WHERE
	|	ProductionInventory.Products <> VALUE(Catalog.Products.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnitCorr AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.ProductsCorr AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	TableInventory.OwnershipCorr AS OwnershipCorr,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.SpecificationCorr AS SpecificationCorr,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.SalesOrder AS CustomerCorrOrder,
	|	&InventoryDistribution AS ContentOfAccountingRecord,
	|	FALSE AS ProductionExpenses,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	0 AS Amount,
	|	TableInventory.AccountDr AS AccountDr,
	|	TableInventory.AccountCr AS AccountCr,
	|	&InventoryDistribution AS Content,
	|	TableInventory.CostPercentage AS CostPercentage,
	|	TableInventory.CostObject AS CostObject
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.PlanningPeriod,
	|	TableInventory.GLAccount,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.Products,
	|	TableInventory.ProductsCorr,
	|	TableInventory.Characteristic,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.InventoryAccountType,
	|	TableInventory.CorrInventoryAccountType,
	|	TableInventory.BatchCorr,
	|	TableInventory.OwnershipCorr,
	|	TableInventory.Specification,
	|	TableInventory.SpecificationCorr,
	|	TableInventory.SalesOrder,
	|	TableInventory.AccountDr,
	|	TableInventory.AccountCr,
	|	TableInventory.CostPercentage,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.SalesOrder,
	|	TableInventory.CostObject
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Cell AS Cell,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.StructuralUnit,
	|	TableInventory.Cell
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.Period AS Period,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	CatalogInventoryOwnership.Counterparty AS Counterparty
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|		INNER JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
	|		ON (TableInventory.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory))
	|			AND TableInventory.Ownership = CatalogInventoryOwnership.Ref
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.Period,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	CatalogInventoryOwnership.Counterparty
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	TableInventory.Company AS Company,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	TableInventory.ProductionOrder AS ProductionDocument
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.SalesOrder,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.ProductionOrder
	|
	|ORDER BY
	|	LineNumber";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefProduction);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);	
	AccountingPolicy = StructureAdditionalProperties.AccountingPolicy;
	Query.SetParameter("UseCharacteristics", AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins", AccountingPolicy.UseStorageBins);
	Query.SetParameter("TableOfRawMaterialsConsumptionDisassembling",
		StructureAdditionalProperties.TableForRegisterRecords.TableOfRawMaterialsConsumptionDisassembling);
	Query.SetParameter("InventoryDistribution", NStr("en = 'Inventory allocation'; ru = 'Распределение запасов';pl = 'Alokacja zapasów';es_ES = 'Asignación del inventario';es_CO = 'Asignación del inventario';tr = 'Stok dağıtımı';it = 'Allocazione scorte';de = 'Bestandszuordnung'", MainLanguageCode));
	Query.SetParameter("InventoryTransfer", NStr("en = 'Inventory transfer'; ru = 'Перемещение запасов';pl = 'Przesunięcie międzymagazynowe';es_ES = 'Traslado del inventario';es_CO = 'Traslado del inventario';tr = 'Stok transferi';it = 'Trasferimento di scorte';de = 'Bestandsumlagerung'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	// Determine table for inventory accounting.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInventory", ResultsArray[1].Unload());
	
	// Generate table for inventory accounting.
	CalculateTableInventoryForDisassembly(DocumentRefProduction, StructureAdditionalProperties);
	
	// Expand table for inventory.
	ResultsSelection = ResultsArray[2].Select();
	While ResultsSelection.Next() Do
		
		TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
		FillPropertyValues(TableRowExpense, ResultsSelection);
		
	EndDo;
	
	// Determine a table of consumed raw material accepted for processing for which you will have to report in the future.
	StructureAdditionalProperties.TableForRegisterRecords.Insert(
		"TableStockReceivedFromThirdParties", ResultsArray[3].Unload());
	
	// Determine table for movement by the needs of dependent demand positions.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand", ResultsArray[4].Unload());
	GenerateTableInventoryDemandDisassembly(DocumentRefProduction, StructureAdditionalProperties);
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsConsumedToDeclare", New ValueTable);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure CalculateTableInventoryForDisassembly(DocumentRefProduction, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnitCorr AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Products AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Characteristic AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Batch AS BatchCorr,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.Ownership AS OwnershipCorr,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.Specification AS SpecificationCorr,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.SalesOrder AS CustomerCorrOrder,
	|	TableInventory.CostObject AS CostObject,
	|	UNDEFINED AS SourceDocument,
	|	UNDEFINED AS CorrSalesOrder,
	|	UNDEFINED AS Department,
	|	UNDEFINED AS Responsible,
	|	TableInventory.GLAccount AS AccountDr,
	|	TableInventory.CorrGLAccount AS AccountCr,
	|	"""" AS Content,
	|	"""" AS ContentOfAccountingRecord,
	|	FALSE AS FixedCost,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	TableInventory.Amount AS Amount
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|		LEFT JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
	|		ON TableInventory.Ownership = CatalogInventoryOwnership.Ref
	|
	|GROUP BY
	|	TableInventory.PlanningPeriod,
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.InventoryAccountType,
	|	TableInventory.CorrInventoryAccountType,
	|	TableInventory.Specification,
	|	TableInventory.SalesOrder,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.Amount,
	|	TableInventory.GLAccount,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.Specification,
	|	TableInventory.SalesOrder,
	|	TableInventory.CostObject,
	|	TableInventory.CorrGLAccount";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	TextInventoryTransfer = NStr("en = 'Inventory transfer'; ru = 'Перемещение запасов';pl = 'Przesunięcie międzymagazynowe';es_ES = 'Traslado del inventario';es_CO = 'Traslado del inventario';tr = 'Stok transferi';it = 'Trasferimento di scorte';de = 'Bestandsumlagerung'", MainLanguageCode);
	TextProduction = NStr("en = 'Production'; ru = 'Производство';pl = 'Produkcja';es_ES = 'Producción';es_CO = 'Producción';tr = 'Üretim';it = 'Produzione';de = 'Produktion'", MainLanguageCode);
	
	TableInventoryMove = Query.Execute().Unload();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryMove", TableInventoryMove);
	
	TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
	
	IsWeightedAverage = StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage;
	
	If IsWeightedAverage Then
	
		Query = New Query;
		Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
		
		// Setting the exclusive lock for the controlled inventory balances.
		Query.Text = 
		"SELECT
		|	TableInventory.Company AS Company,
		|	TableInventory.PresentationCurrency AS PresentationCurrency,
		|	TableInventory.StructuralUnit AS StructuralUnit,
		|	TableInventory.Products AS Products,
		|	TableInventory.Characteristic AS Characteristic,
		|	TableInventory.Batch AS Batch,
		|	TableInventory.Ownership AS Ownership,
		|	TableInventory.CostObject AS CostObject,
		|	TableInventory.InventoryAccountType AS InventoryAccountType
		|FROM
		|	TemporaryTableInventory AS TableInventory
		|
		|GROUP BY
		|	TableInventory.Company,
		|	TableInventory.PresentationCurrency,
		|	TableInventory.StructuralUnit,
		|	TableInventory.Products,
		|	TableInventory.Characteristic,
		|	TableInventory.Batch,
		|	TableInventory.Ownership,
		|	TableInventory.CostObject,
		|	TableInventory.InventoryAccountType";
		
		QueryResult = Query.Execute();
		
		Block = New DataLock;
		LockItem = Block.Add("AccumulationRegister.Inventory");
		LockItem.Mode = DataLockMode.Exclusive;
		LockItem.DataSource = QueryResult;

		For Each ColumnQueryResult In QueryResult.Columns Do
			LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
		EndDo;
		Block.Lock();
		
		// Receiving inventory balances by cost.
		Query.Text =
		"SELECT
		|	InventoryBalances.Company AS Company,
		|	InventoryBalances.PresentationCurrency AS PresentationCurrency,
		|	InventoryBalances.StructuralUnit AS StructuralUnit,
		|	InventoryBalances.Products AS Products,
		|	InventoryBalances.Characteristic AS Characteristic,
		|	InventoryBalances.Batch AS Batch,
		|	InventoryBalances.Ownership AS Ownership,
		|	InventoryBalances.CostObject AS CostObject,
		|	InventoryBalances.InventoryAccountType AS InventoryAccountType,
		|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
		|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
		|FROM
		|	(SELECT
		|		InventoryBalances.Company AS Company,
		|		InventoryBalances.PresentationCurrency AS PresentationCurrency,
		|		InventoryBalances.StructuralUnit AS StructuralUnit,
		|		InventoryBalances.Products AS Products,
		|		InventoryBalances.Characteristic AS Characteristic,
		|		InventoryBalances.Batch AS Batch,
		|		InventoryBalances.Ownership AS Ownership,
		|		InventoryBalances.CostObject AS CostObject,
		|		InventoryBalances.InventoryAccountType AS InventoryAccountType,
		|		InventoryBalances.QuantityBalance AS QuantityBalance,
		|		InventoryBalances.AmountBalance AS AmountBalance
		|	FROM
		|		AccumulationRegister.Inventory.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, StructuralUnit, Products, Characteristic, Batch, Ownership, CostObject, InventoryAccountType) IN
		|					(SELECT
		|						TableInventory.Company,
		|						TableInventory.PresentationCurrency,
		|						TableInventory.StructuralUnit AS StructuralUnit,
		|						TableInventory.Products,
		|						TableInventory.Characteristic,
		|						TableInventory.Batch,
		|						TableInventory.Ownership,
		|						TableInventory.CostObject,
		|						TableInventory.InventoryAccountType
		|					FROM
		|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecordsInventory.Company,
		|		DocumentRegisterRecordsInventory.PresentationCurrency,
		|		DocumentRegisterRecordsInventory.StructuralUnit,
		|		DocumentRegisterRecordsInventory.Products,
		|		DocumentRegisterRecordsInventory.Characteristic,
		|		DocumentRegisterRecordsInventory.Batch,
		|		DocumentRegisterRecordsInventory.Ownership,
		|		DocumentRegisterRecordsInventory.CostObject,
		|		DocumentRegisterRecordsInventory.InventoryAccountType,
		|		CASE
		|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
		|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
		|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
		|				THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
		|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
		|		END
		|	FROM
		|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
		|	WHERE
		|		DocumentRegisterRecordsInventory.Recorder = &Ref
		|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod) AS InventoryBalances
		|
		|GROUP BY
		|	InventoryBalances.Company,
		|	InventoryBalances.PresentationCurrency,
		|	InventoryBalances.StructuralUnit,
		|	InventoryBalances.Products,
		|	InventoryBalances.Characteristic,
		|	InventoryBalances.Batch,
		|	InventoryBalances.Ownership,
		|	InventoryBalances.CostObject,
		|	InventoryBalances.InventoryAccountType";
		
		Query.SetParameter("Ref", DocumentRefProduction);
		Query.SetParameter("ControlTime",
			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
		Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
		
		QueryResult = Query.Execute();
		
		TableInventoryBalancesMove = QueryResult.Unload();
		TableInventoryBalancesMove.Indexes.Add(
			"Company, PresentationCurrency, StructuralUnit,
			|Products, Characteristic, Batch, Ownership, CostObject, InventoryAccountType");
		
		TemporaryTableInventoryTransfer = TableInventoryMove.CopyColumns();
		
		IsEmptyStructuralUnit	= Catalogs.BusinessUnits.EmptyRef();
		EmptyAccount			= ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
		EmptyProducts			= Catalogs.Products.EmptyRef();
		EmptyCharacteristic		= Catalogs.ProductsCharacteristics.EmptyRef();
		EmptyBatch				= Catalogs.ProductsBatches.EmptyRef();
		EmptySalesOrder			= Undefined;
		
		For n = 0 To TableInventoryMove.Count() - 1 Do
			
			RowTableInventoryTransfer = TableInventoryMove[n];
			
			StructureForSearchTransfer = New Structure;
			StructureForSearchTransfer.Insert("Company",				RowTableInventoryTransfer.Company);
			StructureForSearchTransfer.Insert("PresentationCurrency",	RowTableInventoryTransfer.PresentationCurrency);
			StructureForSearchTransfer.Insert("StructuralUnit",			RowTableInventoryTransfer.StructuralUnit);
			StructureForSearchTransfer.Insert("Products",				RowTableInventoryTransfer.Products);
			StructureForSearchTransfer.Insert("Characteristic",			RowTableInventoryTransfer.Characteristic);
			StructureForSearchTransfer.Insert("Batch",					RowTableInventoryTransfer.Batch);
			StructureForSearchTransfer.Insert("Ownership",				RowTableInventoryTransfer.Ownership);
			StructureForSearchTransfer.Insert("CostObject",				RowTableInventoryTransfer.CostObject);
			StructureForSearchTransfer.Insert("InventoryAccountType",	RowTableInventoryTransfer.InventoryAccountType);
			
			QuantityRequiredAvailableBalanceTransfer = RowTableInventoryTransfer.Quantity;
			
			If QuantityRequiredAvailableBalanceTransfer > 0 Then
				
				BalanceRowsArrayDisplacement = TableInventoryBalancesMove.FindRows(StructureForSearchTransfer);
				
				QuantityBalanceDisplacement = 0;
				AmountBalanceMove = 0;
				
				If BalanceRowsArrayDisplacement.Count() > 0 Then
					QuantityBalanceDisplacement = BalanceRowsArrayDisplacement[0].QuantityBalance;
					AmountBalanceMove = BalanceRowsArrayDisplacement[0].AmountBalance;
				EndIf;
				
				If QuantityBalanceDisplacement > 0
					And QuantityBalanceDisplacement > QuantityRequiredAvailableBalanceTransfer Then
					
					AmountToBeWrittenOffMove = Round(
						AmountBalanceMove * QuantityRequiredAvailableBalanceTransfer
						/ QuantityBalanceDisplacement , 2, 1);
					
					BalanceRowsArrayDisplacement[0].QuantityBalance = BalanceRowsArrayDisplacement[0].QuantityBalance
						- QuantityRequiredAvailableBalanceTransfer;
					BalanceRowsArrayDisplacement[0].AmountBalance = BalanceRowsArrayDisplacement[0].AmountBalance
						- AmountToBeWrittenOffMove;
					
				ElsIf QuantityBalanceDisplacement = QuantityRequiredAvailableBalanceTransfer Then
					
					AmountToBeWrittenOffMove = AmountBalanceMove;
					
					BalanceRowsArrayDisplacement[0].QuantityBalance = 0;
					BalanceRowsArrayDisplacement[0].AmountBalance = 0;
					
				Else
					AmountToBeWrittenOffMove = 0;
				EndIf;
				
				// Expense.
				TableRowExpenseMove = TemporaryTableInventoryTransfer.Add();
				FillPropertyValues(TableRowExpenseMove, RowTableInventoryTransfer);
				
				TableRowExpenseMove.Specification = Undefined;
				TableRowExpenseMove.SpecificationCorr = Undefined;
				
				TableRowExpenseMove.Amount = AmountToBeWrittenOffMove;
				TableRowExpenseMove.Quantity = QuantityRequiredAvailableBalanceTransfer;
				TableRowExpenseMove.SalesOrder = EmptySalesOrder;
				
			EndIf;
			
		EndDo;
		
	Else
		
		TemporaryTableInventoryTransfer = TableInventoryMove.Copy();
		
	EndIf;
	
	TemporaryTableInventoryTransfer.Indexes.Add(
		"RecordType, PresentationCurrency, Company, StructuralUnit,
		|Products, Characteristic, Batch, Ownership, CostObject, InventoryAccountType");
	
	TableInventoryInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory;
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	For n = 0 To TableInventoryInventory.Count() - 1 Do
		
		RowTableInventory = TableInventoryInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("RecordType", AccumulationRecordType.Receipt);
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("PresentationCurrency", RowTableInventory.PresentationCurrency);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("Products", RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		StructureForSearch.Insert("Ownership", RowTableInventory.Ownership);
		StructureForSearch.Insert("CostObject", RowTableInventory.CostObject);
		StructureForSearch.Insert("InventoryAccountType", RowTableInventory.InventoryAccountType);
		
		Required_Quantity = RowTableInventory.Quantity;
		
		If Required_Quantity > 0 Then
			
			ArrayQuantityBalance = 0;
			ArrayAmountBalance = 0;
			BalanceRowsArray = TemporaryTableInventoryTransfer.FindRows(StructureForSearch);
			For Each RowBalances In BalanceRowsArray Do
				ArrayQuantityBalance = ArrayQuantityBalance + RowBalances.Quantity;
				ArrayAmountBalance = ArrayAmountBalance + RowBalances.Amount;
			EndDo;
			
			QuantityBalance = 0;
			AmountBalance = 0;
			If BalanceRowsArray.Count() > 0 Then
				
				BalanceRowsArray[0].Quantity = ArrayQuantityBalance;
				BalanceRowsArray[0].Amount = ArrayAmountBalance;
				QuantityBalance = BalanceRowsArray[0].Quantity;
				AmountBalance = BalanceRowsArray[0].Amount;
				
				AmountRequired = Round(BalanceRowsArray[0].Amount * Required_Quantity / BalanceRowsArray[0].Quantity, 2, 1);
				
			EndIf;
			
			If QuantityBalance > 0 And QuantityBalance > Required_Quantity Then
				
				AmountToBeWrittenOff = Round(AmountBalance * Required_Quantity / QuantityBalance , 2, 1);
				
				BalanceRowsArray[0].Quantity = BalanceRowsArray[0].Quantity - Required_Quantity;
				BalanceRowsArray[0].Amount = BalanceRowsArray[0].Amount - AmountToBeWrittenOff;
				
			ElsIf QuantityBalance = Required_Quantity Then
				
				AmountToBeWrittenOff = AmountBalance;
				
			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = Required_Quantity;
			TableRowExpense.ProductionExpenses = True;
			TableRowExpense.SalesOrder = RowTableInventory.SalesOrder;
			TableRowExpense.ContentOfAccountingRecord = TextInventoryTransfer;
			
			// Receipt
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
				
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
				
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.Products = RowTableInventory.ProductsCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.Ownership = RowTableInventory.OwnershipCorr;
				TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
				
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsCorr = RowTableInventory.Products;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				TableRowReceipt.OwnershipCorr = RowTableInventory.Ownership;
				TableRowReceipt.InventoryAccountType = RowTableInventory.CorrInventoryAccountType;
				TableRowReceipt.CorrInventoryAccountType = Enums.InventoryAccountTypes.EmptyRef();
				TableRowReceipt.CustomerCorrOrder = Undefined;
				
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = 0;
				
				TableRowReceipt.ContentOfAccountingRecord = TextInventoryTransfer;
				
			EndIf;
			
			// Generate postings.
			If UseDefaultTypeOfAccounting And (Round(AmountToBeWrittenOff, 2, 1) <> 0 Or Not IsWeightedAverage) Then
				RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntries, TableRowExpense);
				RowTableAccountingJournalEntries.Content = TextInventoryTransfer;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	AddOfflineRecords(DocumentRefProduction, StructureAdditionalProperties);
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryInventory");
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryMove");
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryQuantitiesForDisassembly(DocumentRefProduction, StructureAdditionalProperties)
	
	TableBackorders = StructureAdditionalProperties.TableForRegisterRecords.TableBackorders;
	TableBackorders.Indexes.Add("RecordType, Company, Products, Characteristic");
	TableBackorders.Sort("Quantity Desc");
	
	TableReservedProducts = DriveServer.EmptyReservedProductsTable();
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods.Count() - 1 Do
		
		RowTableInventoryProducts = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods[n];
		
		// Generate products release in terms of quantity. If sales order is specified - customer
		// customised if not - then for an empty order.
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, RowTableInventoryProducts);
		
		//// Products autotransfer.
		//GLAccountTransferring = Undefined;
		//If ValueIsFilled(RowTableInventoryProducts.ProductsStructuralUnit) Then
		//	
		//	// Expense.
		//	TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		//	FillPropertyValues(TableRowExpense, RowTableInventoryProducts);
		//	
		//	TableRowExpense.RecordType = AccumulationRecordType.Expense;
		//	TableRowExpense.Specification = Undefined;
		//	
		//	TableRowExpense.StructuralUnitCorr = RowTableInventoryProducts.ProductsStructuralUnit;
		//	TableRowExpense.CorrGLAccount = RowTableInventoryProducts.ProductsGLAccount;
		//	
		//	TableRowExpense.ProductsCorr = RowTableInventoryProducts.Products;
		//	TableRowExpense.CharacteristicCorr = RowTableInventoryProducts.Characteristic;
		//	TableRowExpense.BatchCorr = RowTableInventoryProducts.Batch;
		//	TableRowExpense.OwnershipCorr = RowTableInventoryProducts.Ownership;
		//	TableRowExpense.SpecificationCorr = Undefined;
		//	TableRowExpense.CustomerCorrOrder = RowTableInventoryProducts.SalesOrder;
		//	
		//	TableRowExpense.ContentOfAccountingRecord = NStr("en = 'Inventory transfer'", MainLanguageCode);
		//	TableRowExpense.Content = NStr("en = 'Inventory transfer'", MainLanguageCode);
		//	
		//	// Receipt.
		//	TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		//	FillPropertyValues(TableRowReceipt, RowTableInventoryProducts);
		//	
		//	TableRowReceipt.StructuralUnit = RowTableInventoryProducts.ProductsStructuralUnit;
		//	TableRowReceipt.GLAccount = RowTableInventoryProducts.ProductsGLAccount;
		//	TableRowReceipt.Specification = Undefined;
		//	
		//	GLAccountTransferring = TableRowReceipt.GLAccount;
		//	
		//	TableRowReceipt.StructuralUnitCorr = RowTableInventoryProducts.StructuralUnit;
		//	TableRowReceipt.CorrGLAccount = RowTableInventoryProducts.GLAccount;
		//	
		//	TableRowReceipt.ProductsCorr = RowTableInventoryProducts.Products;
		//	TableRowReceipt.CharacteristicCorr = RowTableInventoryProducts.Characteristic;
		//	TableRowReceipt.BatchCorr = RowTableInventoryProducts.Batch;
		//	TableRowReceipt.OwnershipCorr = RowTableInventoryProducts.Ownership;
		//	TableRowReceipt.SpecificationCorr = Undefined;
		//	TableRowReceipt.CustomerCorrOrder = RowTableInventoryProducts.SalesOrder;
		//	
		//	TableRowReceipt.ContentOfAccountingRecord = NStr("en = 'Inventory transfer'", MainLanguageCode);
		//	TableRowReceipt.Content = NStr("en = 'Inventory transfer'", MainLanguageCode);
		//	
		//EndIf;
		
		// If the production order is filled in then check whether there are placed customers orders in the production order.
		If ValueIsFilled(RowTableInventoryProducts.ProductionOrder) Then
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("RecordType", AccumulationRecordType.Expense);
			StructureForSearch.Insert("Company", RowTableInventoryProducts.Company);
			StructureForSearch.Insert("Products", RowTableInventoryProducts.Products);
			StructureForSearch.Insert("Characteristic", RowTableInventoryProducts.Characteristic);
			
			ArrayPropertiesProducts = TableBackorders.FindRows(StructureForSearch);
			
			If ArrayPropertiesProducts.Count() = 0 Then
				Continue;
			EndIf;
			
			RemainingQuantity = RowTableInventoryProducts.Quantity;
			
			For Each RowAllocationArray In ArrayPropertiesProducts Do
				
				If RowAllocationArray.Quantity > 0 And RemainingQuantity > 0 Then
					
					NewRowReservedTable = TableReservedProducts.Add();
					FillPropertyValues(NewRowReservedTable, RowTableInventoryProducts);
					NewRowReservedTable.SalesOrder = RowAllocationArray.SalesOrder;
					NewRowReservedTable.Quantity = ?(RowAllocationArray.Quantity > RemainingQuantity, RemainingQuantity, RowAllocationArray.Quantity);
					
					RemainingQuantity = RemainingQuantity - NewRowReservedTable.Quantity;
					
					//If ValueIsFilled(RowTableInventoryProducts.ProductsStructuralUnit) Then
					//	NewRowReservedTable.StructuralUnit = RowTableInventoryProducts.ProductsStructuralUnit;
					//Else
					//	NewRowReservedTable.StructuralUnit = RowTableInventoryProducts.StructuralUnit;
					//EndIf;
					//If ValueIsFilled(GLAccountTransferring) Then
					//	NewRowReservedTable.GLAccount = GLAccountTransferring;
					//Else
						NewRowReservedTable.GLAccount = RowTableInventoryProducts.GLAccount;
					//EndIf;
					
				EndIf;
				
			EndDo;
			
		ElsIf ValueIsFilled(RowTableInventoryProducts.SalesOrder) Then
			
			//If ValueIsFilled(RowTableInventoryProducts.ProductsStructuralUnit) Then
			//	StructuralUnit = RowTableInventoryProducts.ProductsStructuralUnit;
			//Else
				//StructuralUnit = RowTableInventoryProducts.StructuralUnit;
			//EndIf;
			
			NewRowReservedTable = TableReservedProducts.Add();
			FillPropertyValues(NewRowReservedTable, RowTableInventoryProducts);
			
			//NewRowReservedTable.StructuralUnit = StructuralUnit;
			//If ValueIsFilled(GLAccountTransferring) Then
			//	NewRowReservedTable.GLAccount = GLAccountTransferring;
			//Else
				NewRowReservedTable.GLAccount = RowTableInventoryProducts.GLAccount;
			//EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableReservedProducts", TableReservedProducts);
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryGoods");
	TableProductsAllocation = Undefined;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryDemandDisassembly(DocumentRefProduction, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	TableInventoryDemand.Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	TableInventoryDemand.SalesOrder AS SalesOrder,
	|	TableInventoryDemand.Products AS Products,
	|	TableInventoryDemand.Characteristic AS Characteristic,
	|	TableInventoryDemand.ProductionOrder AS ProductionDocument
	|FROM
	|	TemporaryTableInventory AS TableInventoryDemand";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.InventoryDemand");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();

	// Receive balance.
	Query.Text =
	"SELECT
	|	InventoryDemandBalances.Company AS Company,
	|	InventoryDemandBalances.SalesOrder AS SalesOrder,
	|	InventoryDemandBalances.Products AS Products,
	|	InventoryDemandBalances.Characteristic AS Characteristic,
	|	InventoryDemandBalances.ProductionDocument AS ProductionDocument,
	|	SUM(InventoryDemandBalances.Quantity) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryDemandBalances.Company AS Company,
	|		InventoryDemandBalances.SalesOrder AS SalesOrder,
	|		InventoryDemandBalances.Products AS Products,
	|		InventoryDemandBalances.Characteristic AS Characteristic,
	|		InventoryDemandBalances.ProductionDocument AS ProductionDocument,
	|		SUM(InventoryDemandBalances.QuantityBalance) AS Quantity
	|	FROM
	|		AccumulationRegister.InventoryDemand.Balance(
	|				&ControlTime,
	|				(Company, MovementType, SalesOrder, Products, Characteristic, ProductionDocument) IN
	|					(SELECT
	|						TemporaryTableInventory.Company AS Company,
	|						VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|						TemporaryTableInventory.SalesOrder,
	|						TemporaryTableInventory.Products AS Products,
	|						TemporaryTableInventory.Characteristic AS Characteristic,
	|						TemporaryTableInventory.ProductionOrder AS ProductionDocument
	|					FROM
	|						TemporaryTableInventory AS TemporaryTableInventory)) AS InventoryDemandBalances
	|	
	|	GROUP BY
	|		InventoryDemandBalances.Company,
	|		InventoryDemandBalances.SalesOrder,
	|		InventoryDemandBalances.Products,
	|		InventoryDemandBalances.Characteristic,
	|		InventoryDemandBalances.ProductionDocument
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventoryDemand.Company,
	|		DocumentRegisterRecordsInventoryDemand.SalesOrder,
	|		DocumentRegisterRecordsInventoryDemand.Products,
	|		DocumentRegisterRecordsInventoryDemand.Characteristic,
	|		DocumentRegisterRecordsInventoryDemand.ProductionDocument,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventoryDemand.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.InventoryDemand AS DocumentRegisterRecordsInventoryDemand
	|	WHERE
	|		DocumentRegisterRecordsInventoryDemand.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventoryDemand.Period <= &ControlPeriod) AS InventoryDemandBalances
	|
	|GROUP BY
	|	InventoryDemandBalances.Company,
	|	InventoryDemandBalances.SalesOrder,
	|	InventoryDemandBalances.Products,
	|	InventoryDemandBalances.Characteristic,
	|	InventoryDemandBalances.ProductionDocument";
	
	Query.SetParameter("Ref", DocumentRefProduction);
	
	If ValueIsFilled(StructureAdditionalProperties.DocumentAttributes.SalesOrder) Then
		Query.SetParameter("ControlTime",
			StructureAdditionalProperties.ForPosting.ControlTime);
	Else
		Query.SetParameter("ControlTime",
			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	EndIf;
	
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);
	
	QueryResult = Query.Execute();
	
	TableInventoryDemandBalance = QueryResult.Unload();
	TableInventoryDemandBalance.Indexes.Add("Company, SalesOrder, Products, Characteristic,ProductionDocument");
	
	TemporaryTableInventoryDemand =
		StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand.CopyColumns();
	
	For Each RowTablesForInventory In StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company",			RowTablesForInventory.Company);
		StructureForSearch.Insert("SalesOrder",			RowTablesForInventory.SalesOrder);
		StructureForSearch.Insert("Products",			RowTablesForInventory.Products);
		StructureForSearch.Insert("Characteristic",		RowTablesForInventory.Characteristic);
		StructureForSearch.Insert("ProductionDocument",	RowTablesForInventory.ProductionDocument);
		
		BalanceRowsArray = TableInventoryDemandBalance.FindRows(StructureForSearch);
		If BalanceRowsArray.Count() > 0 And BalanceRowsArray[0].QuantityBalance > 0 Then
			
			If RowTablesForInventory.Quantity > BalanceRowsArray[0].QuantityBalance Then
				RowTablesForInventory.Quantity = BalanceRowsArray[0].QuantityBalance;
			EndIf;
			
			TableRowExpense = TemporaryTableInventoryDemand.Add();
			FillPropertyValues(TableRowExpense, RowTablesForInventory);
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand = TemporaryTableInventoryDemand;
	
EndProcedure

#EndRegion

#Region ConvertFromWIP

Procedure InitializeDocumentDataConvertFromWIP(DocumentRefProduction, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	#Region QueryText
	Query.Text = 
	"SELECT
	|	DocumentHeader.Date AS Date,
	|	DocumentHeader.Ref AS Ref,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentHeader.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN DocumentHeader.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN DocumentHeader.CellInventory
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS CellInventory,
	|	DocumentHeader.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	DocumentHeader.DisposalsStructuralUnit AS DisposalsStructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN DocumentHeader.ProductsCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS ProductsCell,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN DocumentHeader.DisposalsCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS DisposalsCell,
	|	DocumentHeader.SalesOrder AS SalesOrder,
	|	UNDEFINED AS CustomerCorrOrder,
	|	DocumentHeader.BasisDocument AS BasisDocument,
	|	CASE
	|		WHEN DocumentHeader.BasisDocument = VALUE(Document.ProductionOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE DocumentHeader.BasisDocument
	|	END AS SupplySource
	|INTO TT_DocumentHeader
	|FROM
	|	Document.Manufacturing AS DocumentHeader
	|		LEFT JOIN Document.ProductionOrder AS ProductionOrder
	|		ON DocumentHeader.BasisDocument = ProductionOrder.Ref
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionProducts.LineNumber AS LineNumber,
	|	TT_DocumentHeader.Date AS Period,
	|	ProductionProducts.ConnectionKey AS ConnectionKey,
	|	TT_DocumentHeader.Ref AS Ref,
	|	TT_DocumentHeader.Company AS Company,
	|	TT_DocumentHeader.PresentationCurrency AS PresentationCurrency,
	|	TT_DocumentHeader.StructuralUnit AS StructuralUnit,
	|	TT_DocumentHeader.Cell AS Cell,
	|	TT_DocumentHeader.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	TT_DocumentHeader.ProductsStructuralUnit AS ProductsStructuralUnitToWarehouse,
	|	TT_DocumentHeader.ProductsCell AS ProductsCell,
	|	ProductionProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN ProductionProducts.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	ProductionProducts.Ownership AS Ownership,
	|	CASE
	|		WHEN ProductionProducts.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedFinishedProducts)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS InventoryAccountType,
	|	VALUE(Enum.InventoryAccountTypes.WorkInProgress) AS CorrInventoryAccountType,
	|	ProductionProducts.Specification AS Specification,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ProductsGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountDr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ProductsAccountDr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.ConsumptionGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ProductsAccountCr,
	|	TT_DocumentHeader.CustomerCorrOrder AS CustomerCorrOrder,
	|	TT_DocumentHeader.BasisDocument AS ProductionOrder,
	|	TT_DocumentHeader.SupplySource AS SupplySource,
	|	ProductionProducts.Quantity * ISNULL(CatalogUOM.Factor, 1) AS Quantity,
	|	0 AS Amount
	|INTO TemporaryTableProduction
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Document.Manufacturing.Products AS ProductionProducts
	|		ON TT_DocumentHeader.Ref = ProductionProducts.Ref
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (ProductionProducts.MeasurementUnit = CatalogUOM.Ref)
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON (ProductionProducts.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON TT_DocumentHeader.ProductsStructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_DocumentHeader.Date AS Period,
	|	&Company AS Company,
	|	CASE
	|		WHEN ProductionProducts.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR ProductionProducts.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE ProductionProducts.SalesOrder
	|	END AS SalesOrder,
	|	TT_DocumentHeader.ProductsStructuralUnit AS StructuralUnit,
	|	TT_DocumentHeader.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ProductsGLAccount,
	|	TT_DocumentHeader.BasisDocument AS ProductionOrder,
	|	TT_DocumentHeader.SupplySource AS SupplySource,
	|	ProductionProducts.Products AS Products,
	|	ProductionProducts.Characteristic AS Characteristic,
	|	ProductionProducts.Ownership AS Ownership,
	|	ProductionProducts.Specification AS Specification,
	|	ProductionProducts.Quantity AS Quantity
	|INTO TemporaryTableProductionReservation
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Document.Manufacturing.Reservation AS ProductionProducts
	|		ON TT_DocumentHeader.Ref = ProductionProducts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProduction.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.Company AS Company,
	|	TableProduction.PresentationCurrency AS PresentationCurrency,
	|	UNDEFINED AS PlanningPeriod,
	|	TableProduction.ProductsStructuralUnit AS StructuralUnit,
	|	UNDEFINED AS StructuralUnitCorr,
	|	TableProduction.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	TableProduction.GLAccount AS GLAccount,
	|	TableProduction.ProductsGLAccount AS ProductsGLAccount,
	|	UNDEFINED AS CorrGLAccount,
	|	TableProduction.Products AS Products,
	|	UNDEFINED AS ProductsCorr,
	|	TableProduction.Characteristic AS Characteristic,
	|	UNDEFINED AS CharacteristicCorr,
	|	TableProduction.Batch AS Batch,
	|	UNDEFINED AS BatchCorr,
	|	TableProduction.Ownership AS Ownership,
	|	UNDEFINED AS OwnershipCorr,
	|	TableProduction.InventoryAccountType AS InventoryAccountType,
	|	TableProduction.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TableProduction.Specification AS Specification,
	|	UNDEFINED AS SpecificationCorr,
	|	VALUE(Document.SalesOrder.EmptyRef) AS SalesOrder,
	|	TableProduction.ProductionOrder AS ProductionOrder,
	|	TableProduction.CustomerCorrOrder AS CustomerCorrOrder,
	|	UNDEFINED AS AccountDr,
	|	UNDEFINED AS AccountCr,
	|	UNDEFINED AS Content,
	|	CAST(&Production AS STRING(30)) AS ContentOfAccountingRecord,
	|	FALSE AS ProductionExpenses,
	|	TableProduction.Quantity AS Quantity,
	|	TableProduction.Amount AS Amount,
	|	FALSE AS FixedCost,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	FALSE AS OfflineRecord,
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef) AS IncomeAndExpenseItem
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	FALSE
	|
	|UNION ALL
	|
	|SELECT
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	VALUE(Catalog.ManufacturingActivities.EmptyRef),
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	FALSE,
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|WHERE
	|	FALSE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	TableProduction.ProductsStructuralUnitToWarehouse AS StructuralUnit,
	|	TableProduction.ProductsCell AS Cell,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.Ownership AS Ownership,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.ProductsCell,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	TableProduction.Ownership
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.ProductsStructuralUnit AS StructuralUnit,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Ownership AS Ownership,
	|	TableProduction.Specification AS Specification,
	|	SUM(TableProduction.Quantity) AS Quantity,
	|	TableProduction.SupplySource AS SupplySource
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.Batch,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Ownership,
	|	TableProduction.Specification,
	|	TableProduction.ProductsStructuralUnit,
	|	TableProduction.SupplySource
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	TableProduction.ProductionOrder AS ProductionOrder,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.ProductionOrder <> VALUE(Document.ProductionOrder.EmptyRef)
	|	AND (TableProduction.Products, TableProduction.Characteristic) IN
	|			(SELECT
	|				ProductionOrderProducts.Products AS Products,
	|				ProductionOrderProducts.Characteristic AS Characteristic
	|			FROM
	|				Document.ProductionOrder.Products AS ProductionOrderProducts
	|			WHERE
	|				ProductionOrderProducts.Ref = &ProductionOrder)
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.ProductionOrder,
	|	TableProduction.Products,
	|	TableProduction.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableAllocation.LineNumber AS LineNumber,
	|	TableAllocation.Ref AS Ref,
	|	TT_DocumentHeader.Date AS Period,
	|	TT_DocumentHeader.Company AS Company,
	|	TT_DocumentHeader.ProductsStructuralUnit AS StructuralUnit,
	|	TT_DocumentHeader.ProductsCell AS Cell,
	|	TableAllocation.StructuralUnit AS InventoryStructuralUnit,
	|	TableAllocation.StructuralUnit AS StructuralUnitInventoryToWarehouse,
	|	TT_DocumentHeader.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	TT_DocumentHeader.CellInventory AS CellInventory,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableAllocation.ConsumptionGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ConsumptionGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableAllocation.CorrGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CorrGLAccount,
	|	VALUE(Enum.InventoryAccountTypes.WorkInProgress) AS InventoryAccountType,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS CorrInventoryAccountType,
	|	TableAllocation.Products AS Products,
	|	TableAllocation.CorrProducts AS ProductsCorr,
	|	TableAllocation.Characteristic AS Characteristic,
	|	TableAllocation.CorrCharacteristic AS CharacteristicCorr,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	TableAllocation.Ownership AS Ownership,
	|	CatalogInventoryOwnership.OwnershipType AS OwnershipType,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPoliciesCorr.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPoliciesCorr.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN TableAllocation.CorrBatch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS BatchCorr,
	|	TableAllocation.CorrOwnership AS OwnershipCorr,
	|	TableAllocation.Specification AS SpecificationCorr,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS Specification,
	|	TT_DocumentHeader.SalesOrder AS SalesOrder,
	|	TableAllocation.CorrQuantity AS CorrQuantity,
	|	TableAllocation.Quantity AS Quantity,
	|	TableAllocation.CostObject AS CostObject,
	|	TableAllocation.ByProduct AS ByProduct,
	|	TT_DocumentHeader.PresentationCurrency AS PresentationCurrency,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableAllocation.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount
	|INTO TemporaryTableAllocation
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Document.Manufacturing.Allocation AS TableAllocation
	|		ON TT_DocumentHeader.Ref = TableAllocation.Ref
	|		LEFT JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
	|		ON (TableAllocation.Ownership = CatalogInventoryOwnership.Ref)
	|		INNER JOIN Catalog.Products AS CatalogProductsCorr
	|		ON (TableAllocation.CorrProducts = CatalogProductsCorr.Ref)
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategoriesCorr
	|		ON (CatalogProductsCorr.ProductsCategory = ProductsCategoriesCorr.Ref)
	|			AND (CatalogProductsCorr.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicyCorr
	|		ON TT_DocumentHeader.ProductsStructuralUnit = BatchTrackingPolicyCorr.StructuralUnit
	|			AND (ProductsCategoriesCorr.BatchSettings = BatchTrackingPolicyCorr.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPoliciesCorr
	|		ON (BatchTrackingPolicyCorr.Policy = BatchTrackingPoliciesCorr.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableAllocation.LineNumber AS LineNumber,
	|	TableAllocation.Ref AS Ref,
	|	TableAllocation.Period AS Period,
	|	TableAllocation.StructuralUnit AS StructuralUnit,
	|	TableAllocation.Cell AS Cell,
	|	TableAllocation.InventoryStructuralUnit AS InventoryStructuralUnit,
	|	TableAllocation.StructuralUnitInventoryToWarehouse AS StructuralUnitInventoryToWarehouse,
	|	TableAllocation.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	TableAllocation.CellInventory AS CellInventory,
	|	TableAllocation.ConsumptionGLAccount AS GLAccount,
	|	TableAllocation.ConsumptionGLAccount AS InventoryGLAccount,
	|	TableAllocation.CorrGLAccount AS CorrGLAccount,
	|	TableAllocation.CorrGLAccount AS ProductsGLAccount,
	|	TableAllocation.Products AS Products,
	|	TableAllocation.ProductsCorr AS ProductsCorr,
	|	TableAllocation.Characteristic AS Characteristic,
	|	TableAllocation.CharacteristicCorr AS CharacteristicCorr,
	|	TableAllocation.Batch AS Batch,
	|	TableAllocation.Ownership AS Ownership,
	|	TableAllocation.OwnershipType AS OwnershipType,
	|	TableAllocation.BatchCorr AS BatchCorr,
	|	TableAllocation.OwnershipCorr AS OwnershipCorr,
	|	TableAllocation.InventoryAccountType AS InventoryAccountType,
	|	CASE
	|		WHEN TableAllocation.OwnershipCorr.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedFinishedProducts)
	|		WHEN TableAllocation.OwnershipCorr.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerProvidedInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedComponents)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS CorrInventoryAccountType,
	|	TableAllocation.SpecificationCorr AS SpecificationCorr,
	|	TableAllocation.Specification AS Specification,
	|	TableAllocation.SalesOrder AS SalesOrder,
	|	TableAllocation.CorrQuantity AS CorrQuantity,
	|	TableAllocation.Quantity AS Quantity,
	|	TableAllocation.CorrGLAccount AS AccountDr,
	|	TableAllocation.CorrGLAccount AS ProductsAccountDr,
	|	TableAllocation.ConsumptionGLAccount AS AccountCr,
	|	TableAllocation.ConsumptionGLAccount AS ProductsAccountCr,
	|	TableAllocation.CostObject AS CostObject,
	|	TableAllocation.ByProduct AS ByProduct
	|FROM
	|	TemporaryTableAllocation AS TableAllocation
	|WHERE
	|	NOT TableAllocation.ByProduct
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 0
	|	WorkInProgress.Period AS Period,
	|	WorkInProgress.RecordType AS RecordType,
	|	WorkInProgress.Company AS Company,
	|	WorkInProgress.PresentationCurrency AS PresentationCurrency,
	|	WorkInProgress.StructuralUnit AS StructuralUnit,
	|	WorkInProgress.CostObject AS CostObject,
	|	WorkInProgress.Products AS Products,
	|	WorkInProgress.Characteristic AS Characteristic,
	|	WorkInProgress.Quantity AS Quantity,
	|	WorkInProgress.Amount AS Amount,
	|	WorkInProgress.OfflineRecord AS OfflineRecord
	|FROM
	|	AccumulationRegister.WorkInProgress AS WorkInProgress
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProduction.Period AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS EventDate,
	|	VALUE(Enum.SerialNumbersOperations.Receipt) AS Operation,
	|	TableSerialNumbersProducts.SerialNumber AS SerialNumber,
	|	&Company AS Company,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.Ownership AS Ownership,
	|	TableProduction.ProductsStructuralUnitToWarehouse AS StructuralUnit,
	|	TableProduction.ProductsCell AS Cell,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		INNER JOIN Document.Manufacturing.SerialNumbersProducts AS TableSerialNumbersProducts
	|		ON TableProduction.Ref = TableSerialNumbersProducts.Ref
	|			AND TableProduction.ConnectionKey = TableSerialNumbersProducts.ConnectionKey
	|WHERE
	|	TableSerialNumbersProducts.Ref = &Ref
	|	AND &UseSerialNumbers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProduction.Period AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	CatalogInventoryOwnership.Counterparty AS Counterparty,
	|	TableProduction.SalesOrder AS SubcontractorOrder,
	|	TableProduction.ProductionOrder AS ProductionOrder,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	SUM(TableProduction.Quantity) AS QuantityToIssue,
	|	SUM(TableProduction.Quantity) AS QuantityToInvoice
	|FROM
	|	TemporaryTableProductionReservation AS TableProduction
	|		INNER JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
	|		ON (CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory))
	|			AND TableProduction.Ownership = CatalogInventoryOwnership.Ref
	|
	|GROUP BY
	|	TableProduction.Period,
	|	CatalogInventoryOwnership.Counterparty,
	|	TableProduction.SalesOrder,
	|	TableProduction.ProductionOrder,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Ownership
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(ManufacturingProducts.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TT_DocumentHeader.Date AS Period,
	|	TT_DocumentHeader.Ref AS Ref,
	|	TT_DocumentHeader.Company AS Company,
	|	TT_DocumentHeader.BasisDocument AS ProductionOrder,
	|	ManufacturingProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ManufacturingProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	ManufacturingProducts.Specification AS Specification,
	|	SUM(ManufacturingProducts.Quantity) AS Quantity
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Document.Manufacturing.Products AS ManufacturingProducts
	|		ON TT_DocumentHeader.Ref = ManufacturingProducts.Ref
	|
	|GROUP BY
	|	TT_DocumentHeader.Date,
	|	TT_DocumentHeader.Ref,
	|	TT_DocumentHeader.Company,
	|	TT_DocumentHeader.BasisDocument,
	|	ManufacturingProducts.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ManufacturingProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	ManufacturingProducts.Specification
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryCostLayer.Period AS Period,
	|	InventoryCostLayer.Recorder AS Recorder,
	|	InventoryCostLayer.LineNumber AS LineNumber,
	|	InventoryCostLayer.Active AS Active,
	|	InventoryCostLayer.RecordType AS RecordType,
	|	InventoryCostLayer.Company AS Company,
	|	InventoryCostLayer.PresentationCurrency AS PresentationCurrency,
	|	InventoryCostLayer.Products AS Products,
	|	InventoryCostLayer.Characteristic AS Characteristic,
	|	InventoryCostLayer.Batch AS Batch,
	|	InventoryCostLayer.Ownership AS Ownership,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN InventoryCostLayer.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	InventoryCostLayer.StructuralUnit AS StructuralUnit,
	|	InventoryCostLayer.CostLayer AS CostLayer,
	|	InventoryCostLayer.CostObject AS CostObject,
	|	InventoryCostLayer.Quantity AS Quantity,
	|	InventoryCostLayer.Amount AS Amount,
	|	InventoryCostLayer.SourceRecord AS SourceRecord,
	|	InventoryCostLayer.VATRate AS VATRate,
	|	InventoryCostLayer.Responsible AS Responsible,
	|	InventoryCostLayer.Department AS Department,
	|	InventoryCostLayer.SourceDocument AS SourceDocument,
	|	InventoryCostLayer.CorrSalesOrder AS CorrSalesOrder,
	|	InventoryCostLayer.CorrStructuralUnit AS CorrStructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN InventoryCostLayer.CorrGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CorrGLAccount,
	|	InventoryCostLayer.RIMTransfer AS RIMTransfer,
	|	InventoryCostLayer.SalesRep AS SalesRep,
	|	InventoryCostLayer.Counterparty AS Counterparty,
	|	InventoryCostLayer.Currency AS Currency,
	|	InventoryCostLayer.SalesOrder AS SalesOrder,
	|	InventoryCostLayer.CorrCostObject AS CorrCostObject,
	|	InventoryCostLayer.CorrProducts AS CorrProducts,
	|	InventoryCostLayer.CorrCharacteristic AS CorrCharacteristic,
	|	InventoryCostLayer.CorrBatch AS CorrBatch,
	|	InventoryCostLayer.CorrOwnership AS CorrOwnership,
	|	InventoryCostLayer.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	InventoryCostLayer.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	InventoryCostLayer.InventoryAccountType AS InventoryAccountType,
	|	InventoryCostLayer.CorrInventoryAccountType AS CorrInventoryAccountType
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS InventoryCostLayer
	|WHERE
	|	InventoryCostLayer.Recorder = &Ref
	|	AND NOT InventoryCostLayer.SourceRecord
	|	AND &UseFIFO";
	
	#EndRegion
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	AccountingPolicy = StructureAdditionalProperties.AccountingPolicy;
	
	Query.SetParameter("Ref", DocumentRefProduction);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UseCharacteristics", AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins", AccountingPolicy.UseStorageBins);
	Query.SetParameter("UseSerialNumbers", AccountingPolicy.UseSerialNumbers);
	Query.SetParameter("ProductionOrder", Common.ObjectAttributeValue(DocumentRefProduction, "BasisDocument"));
	Query.SetParameter("UseFIFO", StructureAdditionalProperties.AccountingPolicy.UseFIFO);
	Query.SetParameter("UseDefaultTypeOfAccounting", AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.SetParameter("Production", NStr("en = 'Convert from Work-in-progress'; ru = 'Перевод из ""Незавершенного производства""';pl = 'Konwertuj z Pracy w toku';es_ES = 'Convertir por Trabajo en progreso';es_CO = 'Convertir por Trabajo en progreso';tr = 'İşlem bitişinden dönüştür';it = 'Convertire da Lavori in corso';de = 'Aus Arbeit in Bearbeitung konvertieren'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", ResultsArray[4].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductionOrders", ResultsArray[6].Unload());
	
	// Generate documents posting table structure.
	DriveServer.GenerateTransactionsTable(DocumentRefProduction, StructureAdditionalProperties);
	
	// Generate table by orders placement.
	GenerateTableBackorders(DocumentRefProduction, StructureAdditionalProperties);
	GenerateTableProductRelease(ResultsArray[5].Unload(), StructureAdditionalProperties);
	
	// Generate Products in reserve
	GenerateTableReservedProductsConvertFromWIP(DocumentRefProduction, StructureAdditionalProperties);
	
	// Generate materials allocation table.
	StructureAdditionalProperties.TableForRegisterRecords.Insert(
		"TableRawMaterialsConsumptionAssembly", ResultsArray[8].Unload());
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableWorkInProgress", ResultsArray[9].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryCostLayer", ResultsArray[13].Unload());
	
	// Inventory.
	GenerateTableInventoryForConvertFromWIP(DocumentRefProduction, StructureAdditionalProperties);
	
	// Disposals.
	// Generate table for inventory accounting.
	If StructureAdditionalProperties.UseByProductsAccounting Then
		DataInitializationByByProducts(DocumentRefProduction, StructureAdditionalProperties);
	Else
		DataInitializationByDisposals(DocumentRefProduction, StructureAdditionalProperties);
	EndIf;
	
	// Serial numbers
	QueryResult7 = ResultsArray[10].Unload();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult7);
	If AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", QueryResult7);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
	EndIf;
	
	// Customer-owned inventory
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCustomerOwnedInventory", ResultsArray[11].Unload());
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableStockReceivedFromThirdParties", New ValueTable);
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsConsumedToDeclare", New ValueTable);
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand", New ValueTable);
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableWorkInProgressStatement", ResultsArray[12].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductionComponents", DriveServer.EmptyProductionComponentsTable());
	
EndProcedure

Procedure GenerateTableInventoryForConvertFromWIP(DocumentRefProduction, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	ProductionInventory.LineNumber AS LineNumber,
	|	ProductionInventory.Period AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	ProductionInventory.StructuralUnit AS StructuralUnit,
	|	ProductionInventory.Cell AS Cell,
	|	ProductionInventory.InventoryStructuralUnit AS InventoryStructuralUnit,
	|	ProductionInventory.StructuralUnitInventoryToWarehouse AS StructuralUnitInventoryToWarehouse,
	|	ProductionInventory.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	ProductionInventory.CellInventory AS CellInventory,
	|	ProductionInventory.GLAccount AS GLAccount,
	|	ProductionInventory.InventoryGLAccount AS InventoryGLAccount,
	|	ProductionInventory.CorrGLAccount AS CorrGLAccount,
	|	ProductionInventory.ProductsGLAccount AS ProductsGLAccount,
	|	ProductionInventory.Products AS Products,
	|	ProductionInventory.ProductsCorr AS ProductsCorr,
	|	ProductionInventory.Characteristic AS Characteristic,
	|	ProductionInventory.CharacteristicCorr AS CharacteristicCorr,
	|	ProductionInventory.Batch AS Batch,
	|	ProductionInventory.Ownership AS Ownership,
	|	ProductionInventory.OwnershipType AS OwnershipType,
	|	ProductionInventory.InventoryAccountType AS InventoryAccountType,
	|	ProductionInventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	ProductionInventory.BatchCorr AS BatchCorr,
	|	ProductionInventory.OwnershipCorr AS OwnershipCorr,
	|	ProductionInventory.Specification AS Specification,
	|	ProductionInventory.SpecificationCorr AS SpecificationCorr,
	|	CASE
	|		WHEN ProductionInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR ProductionInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE ProductionInventory.SalesOrder
	|	END AS SalesOrder,
	|	ProductionInventory.CorrQuantity AS CorrQuantity,
	|	ProductionInventory.Quantity AS Quantity,
	|	0 AS Amount,
	|	ProductionInventory.AccountDr AS AccountDr,
	|	ProductionInventory.ProductsAccountDr AS ProductsAccountDr,
	|	ProductionInventory.AccountCr AS AccountCr,
	|	ProductionInventory.ProductsAccountCr AS ProductsAccountCr,
	|	ProductionInventory.CostObject AS CostObject
	|INTO TemporaryTableInventory
	|FROM
	|	&TableRawMaterialsConsumptionAssembly AS ProductionInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.StructuralUnitInventoryToWarehouse AS StructuralUnit,
	|	TableInventory.StructuralUnit AS StructuralUnitCorr,
	|	TableInventory.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.ProductsGLAccount AS ProductsGLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.ProductsCorr AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	TableInventory.OwnershipCorr AS OwnershipCorr,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.SpecificationCorr AS SpecificationCorr,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.SalesOrder AS CustomerCorrOrder,
	|	TableInventory.AccountDr AS AccountDr,
	|	TableInventory.AccountCr AS AccountCr,
	|	TableInventory.ProductsAccountDr AS ProductsAccountDr,
	|	TableInventory.ProductsAccountCr AS ProductsAccountCr,
	|	&InventoryDistribution AS Content,
	|	&InventoryDistribution AS ContentOfAccountingRecord,
	|	FALSE AS ProductionExpenses,
	|	TableInventory.CostObject AS CostObject,
	|	TableInventory.CorrQuantity AS CorrQuantity,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	0 AS Amount
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.PlanningPeriod,
	|	TableInventory.StructuralUnitInventoryToWarehouse,
	|	TableInventory.ProductsStructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.ProductsGLAccount,
	|	TableInventory.Products,
	|	TableInventory.ProductsCorr,
	|	TableInventory.Characteristic,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.InventoryAccountType,
	|	TableInventory.CorrInventoryAccountType,
	|	TableInventory.BatchCorr,
	|	TableInventory.OwnershipCorr,
	|	TableInventory.CorrQuantity,
	|	TableInventory.Specification,
	|	TableInventory.SpecificationCorr,
	|	TableInventory.SalesOrder,
	|	TableInventory.AccountDr,
	|	TableInventory.AccountCr,
	|	TableInventory.ProductsAccountDr,
	|	TableInventory.ProductsAccountCr,
	|	TableInventory.StructuralUnit,
	|	TableInventory.CostObject,
	|	TableInventory.SalesOrder
	|
	|ORDER BY
	|	LineNumber";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefProduction);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	AccountingPolicy = StructureAdditionalProperties.AccountingPolicy;
	Query.SetParameter("UseCharacteristics", AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins", AccountingPolicy.UseStorageBins);
	Query.SetParameter("TableRawMaterialsConsumptionAssembly",
		StructureAdditionalProperties.TableForRegisterRecords.TableRawMaterialsConsumptionAssembly);
	Query.SetParameter("InventoryDistribution", NStr("en = 'Inventory allocation'; ru = 'Распределение запасов';pl = 'Alokacja zapasów';es_ES = 'Asignación del inventario';es_CO = 'Asignación del inventario';tr = 'Stok dağıtımı';it = 'Allocazione scorte';de = 'Bestandszuordnung'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	// Determine table for inventory accounting.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInventory", ResultsArray[1].Unload());
	
	// Inventory autotransfer.
	CalculateTableInventoryForConvertFromWIP(DocumentRefProduction, StructureAdditionalProperties);
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableRawMaterialsConsumptionAssembly");
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure CalculateTableInventoryForConvertFromWIP(DocumentRefProduction, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnit AS StructuralUnitCorr,
	|	TableInventory.InventoryGLAccount AS GLAccount,
	|	TableInventory.GLAccount AS CorrGLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Products AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Characteristic AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Batch AS BatchCorr,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.OwnershipCorr AS OwnershipCorr,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.SpecificationCorr AS SpecificationCorr,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.SalesOrder AS CustomerCorrOrder,
	|	UNDEFINED AS SourceDocument,
	|	UNDEFINED AS CorrSalesOrder,
	|	UNDEFINED AS Department,
	|	UNDEFINED AS Responsible,
	|	TableInventory.GLAccount AS AccountDr,
	|	TableInventory.InventoryGLAccount AS AccountCr,
	|	&InventoryTransfer AS Content,
	|	&InventoryTransfer AS ContentOfAccountingRecord,
	|	TableInventory.CorrQuantity AS CorrQuantity,
	|	TableInventory.CostObject AS CostObject,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Amount) AS Amount,
	|	FALSE AS FixedCost
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.PlanningPeriod,
	|	TableInventory.StructuralUnit,
	|	TableInventory.InventoryStructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.InventoryGLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.OwnershipCorr,
	|	TableInventory.InventoryAccountType,
	|	TableInventory.CorrInventoryAccountType,
	|	TableInventory.CorrQuantity,
	|	TableInventory.Specification,
	|	TableInventory.SpecificationCorr,
	|	TableInventory.SalesOrder,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.SalesOrder,
	|	TableInventory.GLAccount,
	|	TableInventory.CostObject,
	|	TableInventory.InventoryGLAccount";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("InventoryTransfer", NStr("en = 'Inventory transfer'; ru = 'Перемещение запасов';pl = 'Przesunięcie międzymagazynowe';es_ES = 'Traslado del inventario';es_CO = 'Traslado del inventario';tr = 'Stok transferi';it = 'Trasferimento di scorte';de = 'Bestandsumlagerung'", MainLanguageCode));
	
	TableInventoryMove = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryMove", TableInventoryMove);
	
	TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
	
	IsWeightedAverage = StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage;
	
	If IsWeightedAverage Then
	
		Query = New Query;
		Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
		
		// Setting the exclusive lock for the controlled inventory balances.
		Query.Text = 
		"SELECT
		|	TableInventory.Company AS Company,
		|	TableInventory.PresentationCurrency AS PresentationCurrency,
		|	TableInventory.InventoryStructuralUnit AS StructuralUnit,
		|	TableInventory.Products AS Products,
		|	TableInventory.Characteristic AS Characteristic,
		|	TableInventory.Batch AS Batch,
		|	TableInventory.Ownership AS Ownership,
		|	TableInventory.CostObject AS CostObject,
		|	TableInventory.InventoryAccountType AS InventoryAccountType
		|FROM
		|	TemporaryTableInventory AS TableInventory
		|
		|GROUP BY
		|	TableInventory.Company,
		|	TableInventory.InventoryStructuralUnit,
		|	TableInventory.Products,
		|	TableInventory.Characteristic,
		|	TableInventory.PresentationCurrency,
		|	TableInventory.Batch,
		|	TableInventory.Ownership,
		|	TableInventory.CostObject,
		|	TableInventory.InventoryAccountType";
		
		QueryResult = Query.Execute();
		
		Block = New DataLock;
		LockItem = Block.Add("AccumulationRegister.Inventory");
		LockItem.Mode = DataLockMode.Exclusive;
		LockItem.DataSource = QueryResult;

		For Each ColumnQueryResult In QueryResult.Columns Do
			LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
		EndDo;
		Block.Lock();
		
		// Receiving inventory balances by cost.
		Query.Text =
		"SELECT
		|	InventoryBalances.Company AS Company,
		|	InventoryBalances.PresentationCurrency AS PresentationCurrency,
		|	InventoryBalances.StructuralUnit AS StructuralUnit,
		|	InventoryBalances.Products AS Products,
		|	InventoryBalances.Characteristic AS Characteristic,
		|	InventoryBalances.Batch AS Batch,
		|	InventoryBalances.Ownership AS Ownership,
		|	InventoryBalances.CostObject AS CostObject,
		|	InventoryBalances.InventoryAccountType AS InventoryAccountType,
		|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
		|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
		|FROM
		|	(SELECT
		|		DocumentRegisterRecordsInventory.Company AS Company,
		|		DocumentRegisterRecordsInventory.PresentationCurrency AS PresentationCurrency,
		|		DocumentRegisterRecordsInventory.StructuralUnit AS StructuralUnit,
		|		DocumentRegisterRecordsInventory.Products AS Products,
		|		DocumentRegisterRecordsInventory.Characteristic AS Characteristic,
		|		DocumentRegisterRecordsInventory.Batch AS Batch,
		|		DocumentRegisterRecordsInventory.Ownership AS Ownership,
		|		DocumentRegisterRecordsInventory.CostObject AS CostObject,
		|		DocumentRegisterRecordsInventory.InventoryAccountType AS InventoryAccountType,
		|		CASE
		|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
		|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
		|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
		|		END AS QuantityBalance,
		|		CASE
		|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
		|				THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
		|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
		|		END AS AmountBalance
		|	FROM
		|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
		|	WHERE
		|		DocumentRegisterRecordsInventory.Recorder = &Ref
		|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		InventoryBalances.Company,
		|		InventoryBalances.PresentationCurrency,
		|		InventoryBalances.StructuralUnit,
		|		InventoryBalances.Products,
		|		InventoryBalances.Characteristic,
		|		InventoryBalances.Batch,
		|		InventoryBalances.Ownership,
		|		InventoryBalances.CostObject,
		|		InventoryBalances.InventoryAccountType,
		|		InventoryBalances.QuantityBalance,
		|		InventoryBalances.AmountBalance
		|	FROM
		|		AccumulationRegister.Inventory.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, StructuralUnit, Products, Characteristic, Batch, Ownership, CostObject, InventoryAccountType) IN
		|					(SELECT
		|						TableInventory.Company,
		|						TableInventory.PresentationCurrency,
		|						TableInventory.InventoryStructuralUnit AS StructuralUnit,
		|						TableInventory.Products,
		|						TableInventory.Characteristic,
		|						TableInventory.Batch,
		|						TableInventory.Ownership,
		|						TableInventory.CostObject,
		|						TableInventory.InventoryAccountType
		|					FROM
		|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances) AS InventoryBalances
		|
		|GROUP BY
		|	InventoryBalances.Company,
		|	InventoryBalances.PresentationCurrency,
		|	InventoryBalances.StructuralUnit,
		|	InventoryBalances.Products,
		|	InventoryBalances.Characteristic,
		|	InventoryBalances.Batch,
		|	InventoryBalances.Ownership,
		|	InventoryBalances.CostObject,
		|	InventoryBalances.InventoryAccountType";
		
		Query.SetParameter("Ref", DocumentRefProduction);
		Query.SetParameter("ControlTime",
			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
		Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
		
		QueryResult = Query.Execute();
		
		TableInventoryBalancesMove = QueryResult.Unload();
		TableInventoryBalancesMove.Indexes.Add(
			"Company, PresentationCurrency, StructuralUnit, Products, Characteristic, Batch, Ownership, InventoryAccountType");
		
		TemporaryTableInventoryTransfer = TableInventoryMove.CopyColumns();
		
		IsEmptyStructuralUnit		= Catalogs.BusinessUnits.EmptyRef();
		EmptyAccount				= ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
		EmptyProducts				= Catalogs.Products.EmptyRef();
		EmptyCharacteristic			= Catalogs.ProductsCharacteristics.EmptyRef();
		EmptyBatch					= Catalogs.ProductsBatches.EmptyRef();
		EmptySalesOrder				= Undefined;
		
		For n = 0 To TableInventoryMove.Count() - 1 Do
			
			RowTableInventoryTransfer = TableInventoryMove[n];
			
			StructureForSearchTransfer = New Structure;
			StructureForSearchTransfer.Insert("Company",				RowTableInventoryTransfer.Company);
			StructureForSearchTransfer.Insert("PresentationCurrency",	RowTableInventoryTransfer.PresentationCurrency);
			StructureForSearchTransfer.Insert("StructuralUnit",			RowTableInventoryTransfer.StructuralUnit);
			StructureForSearchTransfer.Insert("Products",				RowTableInventoryTransfer.Products);
			StructureForSearchTransfer.Insert("Characteristic",			RowTableInventoryTransfer.Characteristic);
			StructureForSearchTransfer.Insert("Batch",					RowTableInventoryTransfer.Batch);
			StructureForSearchTransfer.Insert("Ownership",				RowTableInventoryTransfer.Ownership);
			StructureForSearchTransfer.Insert("CostObject",				RowTableInventoryTransfer.CostObject);
			StructureForSearchTransfer.Insert("InventoryAccountType",	RowTableInventoryTransfer.InventoryAccountType);
			
			QuantityRequiredAvailableBalanceTransfer = RowTableInventoryTransfer.Quantity;
			
			If QuantityRequiredAvailableBalanceTransfer > 0 Then
				
				BalanceRowsArrayDisplacement = TableInventoryBalancesMove.FindRows(StructureForSearchTransfer);
				
				QuantityBalanceDisplacement = 0;
				AmountBalanceMove = 0;
				
				If BalanceRowsArrayDisplacement.Count() > 0 Then
					QuantityBalanceDisplacement = BalanceRowsArrayDisplacement[0].QuantityBalance;
					AmountBalanceMove = BalanceRowsArrayDisplacement[0].AmountBalance;
				EndIf;
				
				If QuantityBalanceDisplacement > 0
					And QuantityBalanceDisplacement > QuantityRequiredAvailableBalanceTransfer Then
					
					AmountToBeWrittenOffMove = Round(
						AmountBalanceMove * QuantityRequiredAvailableBalanceTransfer / QuantityBalanceDisplacement , 2, 1);
					
					BalanceRowsArrayDisplacement[0].QuantityBalance =
						BalanceRowsArrayDisplacement[0].QuantityBalance - QuantityRequiredAvailableBalanceTransfer;
					BalanceRowsArrayDisplacement[0].AmountBalance =
						BalanceRowsArrayDisplacement[0].AmountBalance - AmountToBeWrittenOffMove;
					
				ElsIf QuantityBalanceDisplacement = QuantityRequiredAvailableBalanceTransfer Then
					
					AmountToBeWrittenOffMove = AmountBalanceMove;
					
					BalanceRowsArrayDisplacement[0].QuantityBalance = 0;
					BalanceRowsArrayDisplacement[0].AmountBalance = 0;
				
				Else
					AmountToBeWrittenOffMove = 0;
				EndIf;
				
				// Expense.
				TableRowExpenseMove = TemporaryTableInventoryTransfer.Add();
				FillPropertyValues(TableRowExpenseMove, RowTableInventoryTransfer);
				TableRowExpenseMove.Amount = AmountToBeWrittenOffMove;
				TableRowExpenseMove.Quantity = QuantityRequiredAvailableBalanceTransfer;
				TableRowExpenseMove.SalesOrder = EmptySalesOrder;
				TableRowExpenseMove.Specification = Undefined;
				TableRowExpenseMove.SpecificationCorr = Undefined;
				
			EndIf;
		
		EndDo;
		
	Else
		
		TemporaryTableInventoryTransfer = TableInventoryMove.Copy();
		
	EndIf;
	
	TemporaryTableInventoryTransfer.Indexes.Add(
		"RecordType, PresentationCurrency, Company, StructuralUnit, Products, Characteristic, Batch, Ownership, CostObject, InventoryAccountType");
	
	AmountForTransfer = 0;
	RowOfTableInventoryToBeTransferred = Undefined;
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	TableInventoryInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory;
	TablesProductsToBeTransferred = TableInventoryInventory.CopyColumns();
	
	For n = 0 To TableInventoryInventory.Count() - 1 Do
		
		RowTableInventory = TableInventoryInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("RecordType",				AccumulationRecordType.Expense);
		StructureForSearch.Insert("Company",				RowTableInventory.Company);
		StructureForSearch.Insert("PresentationCurrency",	RowTableInventory.PresentationCurrency);
		StructureForSearch.Insert("StructuralUnit",			RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("Products",				RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic",			RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch",					RowTableInventory.Batch);
		StructureForSearch.Insert("Ownership",				RowTableInventory.Ownership);
		StructureForSearch.Insert("CostObject",				RowTableInventory.CostObject);
		StructureForSearch.Insert("InventoryAccountType",	RowTableInventory.InventoryAccountType);
		
		QuantityRequiredAvailableBalance = RowTableInventory.Quantity;
		
		If QuantityRequiredAvailableBalance > 0 Then
			
			ArrayQuantityBalance = 0;
			ArrayAmountBalance = 0;
			BalanceRowsArray = TemporaryTableInventoryTransfer.FindRows(StructureForSearch);
			For Each RowBalances In BalanceRowsArray Do
				ArrayQuantityBalance = ArrayQuantityBalance + RowBalances.Quantity;
				ArrayAmountBalance = ArrayAmountBalance + RowBalances.Amount;
			EndDo;
			
			QuantityBalance = 0;
			AmountBalance = 0;
			If BalanceRowsArray.Count() > 0 Then
				BalanceRowsArray[0].Quantity = ArrayQuantityBalance;
				BalanceRowsArray[0].Amount = ArrayAmountBalance;
				QuantityBalance = BalanceRowsArray[0].Quantity;
				AmountBalance = BalanceRowsArray[0].Amount;
			EndIf;
			
			If QuantityBalance > 0 And QuantityBalance > QuantityRequiredAvailableBalance Then
				
				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredAvailableBalance / QuantityBalance , 2, 1);
				
				BalanceRowsArray[0].Quantity = BalanceRowsArray[0].Quantity - QuantityRequiredAvailableBalance;
				BalanceRowsArray[0].Amount = BalanceRowsArray[0].Amount - AmountToBeWrittenOff;
				
			ElsIf QuantityBalance = QuantityRequiredAvailableBalance Then

				AmountToBeWrittenOff = AmountBalance;

				BalanceRowsArray[0].Quantity = 0;
				BalanceRowsArray[0].Amount = 0;

			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredAvailableBalance;
			TableRowExpense.ProductionExpenses = True;
			TableRowExpense.SalesOrder = Undefined;
			
			TableWIPRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableWorkInProgress.Add();
			FillPropertyValues(TableWIPRowExpense, TableRowExpense);
			
			// Receipt.
			If Round(AmountToBeWrittenOff, 2, 1) <> 0
				Or RowTableInventory.CorrQuantity <> 0 Then
				
				TableRowReceipt = TablesProductsToBeTransferred.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.Products = RowTableInventory.ProductsCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.Ownership = RowTableInventory.OwnershipCorr;
				TableRowReceipt.InventoryAccountType = RowTableInventory.CorrInventoryAccountType;
				TableRowReceipt.CorrInventoryAccountType = Enums.InventoryAccountTypes.EmptyRef();
				TableRowReceipt.CostObject = Undefined;
				TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
				TableRowReceipt.CustomerCorrOrder = Undefined;
				TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = RowTableInventory.CorrQuantity;
				
				// Generate postings.
				If UseDefaultTypeOfAccounting Then
					RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
					FillPropertyValues(RowTableAccountingJournalEntries, TableRowReceipt);
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If TablesProductsToBeTransferred.Count() > 0 Then
		TablesProductsToBeTransferred.GroupBy(
		"Company,
		|RecordType,
		|PresentationCurrency,
		|Period,
		|Products,
		|Batch,
		|Ownership,
		|InventoryAccountType,
		|CorrInventoryAccountType,
		|SalesOrder,
		|CostObject,
		|StructuralUnit,
		|GLAccount,
		|SalesOrder,
		|Characteristic,
		|SalesOrder,
		|Quantity",
		"Amount");
	EndIf;
	
	// Inventory writeoff.
	For Each StringProductsToBeTransferred In TablesProductsToBeTransferred Do
		
		// Receipt
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, StringProductsToBeTransferred);
		
	EndDo;
	
	CollapseAccountingJournalEntries(TableAccountingJournalEntries);
	
	AddOfflineRecords(DocumentRefProduction, StructureAdditionalProperties);
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryInventory");
	
	TablesProductsToBeTransferred = Undefined;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DataInitializationByByProducts(DocumentRefProduction, StructureAdditionalProperties)

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	TableAllocation.ByProduct AS ByProduct,
	|	TableAllocation.LineNumber AS LineNumber,
	|	TableAllocation.Ref AS Ref,
	|	TableAllocation.Period AS Period,
	|	TableAllocation.StructuralUnit AS StructuralUnit,
	|	TableAllocation.Cell AS Cell,
	|	TableAllocation.InventoryStructuralUnit AS InventoryStructuralUnit,
	|	TableAllocation.StructuralUnitInventoryToWarehouse AS StructuralUnitInventoryToWarehouse,
	|	TableAllocation.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	TableAllocation.CellInventory AS CellInventory,
	|	TableAllocation.GLAccount AS GLAccount,
	|	TableAllocation.CorrGLAccount AS CorrGLAccount,
	|	TableAllocation.ConsumptionGLAccount AS ConsumptionGLAccount,
	|	TableAllocation.InventoryAccountType AS InventoryAccountType,
	|	TableAllocation.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TableAllocation.Products AS Products,
	|	TableAllocation.ProductsCorr AS ProductsCorr,
	|	TableAllocation.Characteristic AS Characteristic,
	|	TableAllocation.CharacteristicCorr AS CharacteristicCorr,
	|	TableAllocation.Batch AS Batch,
	|	TableAllocation.Ownership AS Ownership,
	|	TableAllocation.OwnershipType AS OwnershipType,
	|	TableAllocation.BatchCorr AS BatchCorr,
	|	TableAllocation.OwnershipCorr AS OwnershipCorr,
	|	TableAllocation.SpecificationCorr AS SpecificationCorr,
	|	TableAllocation.Specification AS Specification,
	|	TableAllocation.SalesOrder AS SalesOrder,
	|	TableAllocation.CorrQuantity AS CorrQuantity,
	|	TableAllocation.Quantity AS Quantity,
	|	TableAllocation.CostObject AS CostObject,
	|	TableAllocation.Company AS Company,
	|	ManufacturingDisposals.Batch AS BP_Batch,
	|	ManufacturingDisposals.Quantity AS BP_Quantity,
	|	ManufacturingDisposals.Ownership AS BP_Ownership,
	|	TableAllocation.CorrQuantity * ManufacturingDisposals.Amount / ManufacturingDisposals.Quantity AS BP_Amount,
	|	TableAllocation.PresentationCurrency AS PresentationCurrency
	|INTO BP_Allocation
	|FROM
	|	TemporaryTableAllocation AS TableAllocation
	|		INNER JOIN Document.Manufacturing.Disposals AS ManufacturingDisposals
	|		ON TableAllocation.ProductsCorr = ManufacturingDisposals.Products
	|			AND TableAllocation.CharacteristicCorr = ManufacturingDisposals.Characteristic
	|WHERE
	|	TableAllocation.ByProduct
	|	AND ManufacturingDisposals.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionWaste.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TT_DocumentHeader.Date AS Period,
	|	TT_DocumentHeader.Company AS Company,
	|	TT_DocumentHeader.StructuralUnit AS StructuralUnit,
	|	TT_DocumentHeader.Cell AS Cell,
	|	TT_DocumentHeader.DisposalsStructuralUnit AS DisposalsStructuralUnit,
	|	TT_DocumentHeader.DisposalsCell AS DisposalsCell,
	|	ProductionWaste.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionWaste.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ProductionWaste.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	ProductionWaste.Ownership AS Ownership,
	|	ProductionWaste.Quantity * ISNULL(CatalogUOM.Factor, 1) AS Quantity,
	|	TT_DocumentHeader.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	TT_DocumentHeader.ProductsCell AS ProductsCell
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Document.Manufacturing.Disposals AS ProductionWaste
	|		ON TT_DocumentHeader.Ref = ProductionWaste.Ref
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (ProductionWaste.MeasurementUnit = CatalogUOM.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	BP_Allocation.Period AS Period,
	|	BP_Allocation.Company AS Company,
	|	BP_Allocation.PresentationCurrency AS PresentationCurrency,
	|	BP_Allocation.Products AS Products,
	|	BP_Allocation.Characteristic AS Characteristic,
	|	BP_Allocation.Batch AS Batch,
	|	BP_Allocation.Ownership AS Ownership,
	|	BP_Allocation.ConsumptionGLAccount AS GLAccount,
	|	BP_Allocation.CorrInventoryAccountType AS InventoryAccountType,
	|	BP_Allocation.InventoryAccountType AS CorrInventoryAccountType,
	|	BP_Allocation.ProductsStructuralUnit AS StructuralUnit,
	|	0 AS Quantity,
	|	SUM(BP_Allocation.BP_Amount) AS Amount,
	|	&ReturnWaste AS ContentOfAccountingRecord,
	|	BP_Allocation.CorrGLAccount AS CorrGLAccount,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	BP_Allocation.ProductsCorr AS ProductsCorr,
	|	BP_Allocation.CharacteristicCorr AS CharacteristicCorr,
	|	BP_Allocation.SpecificationCorr AS SpecificationCorr,
	|	BP_Allocation.OwnershipCorr AS OwnershipCorr,
	|	TRUE AS FixedCost
	|FROM
	|	BP_Allocation AS BP_Allocation
	|
	|GROUP BY
	|	BP_Allocation.Company,
	|	BP_Allocation.PresentationCurrency,
	|	BP_Allocation.Ownership,
	|	BP_Allocation.Products,
	|	BP_Allocation.Batch,
	|	BP_Allocation.Characteristic,
	|	BP_Allocation.Period,
	|	BP_Allocation.ConsumptionGLAccount,
	|	BP_Allocation.CorrInventoryAccountType,
	|	BP_Allocation.InventoryAccountType,
	|	BP_Allocation.CorrGLAccount,
	|	BP_Allocation.ProductsCorr,
	|	BP_Allocation.CharacteristicCorr,
	|	BP_Allocation.SpecificationCorr,
	|	BP_Allocation.OwnershipCorr,
	|	BP_Allocation.ProductsStructuralUnit
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	BP_Allocation.Period,
	|	BP_Allocation.Company,
	|	BP_Allocation.PresentationCurrency,
	|	BP_Allocation.ProductsCorr,
	|	BP_Allocation.CharacteristicCorr,
	|	BP_Allocation.BP_Batch,
	|	BP_Allocation.BP_Ownership,
	|	BP_Allocation.CorrGLAccount,
	|	BP_Allocation.CorrInventoryAccountType,
	|	NULL,
	|	BP_Allocation.InventoryStructuralUnit,
	|	BP_Allocation.BP_Quantity,
	|	SUM(BP_Allocation.BP_Amount),
	|	&ReturnWaste,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL
	|FROM
	|	BP_Allocation AS BP_Allocation
	|
	|GROUP BY
	|	BP_Allocation.Company,
	|	BP_Allocation.PresentationCurrency,
	|	BP_Allocation.InventoryStructuralUnit,
	|	BP_Allocation.Period,
	|	BP_Allocation.ProductsCorr,
	|	BP_Allocation.CharacteristicCorr,
	|	BP_Allocation.BP_Batch,
	|	BP_Allocation.BP_Ownership,
	|	BP_Allocation.ConsumptionGLAccount,
	|	BP_Allocation.BP_Quantity,
	|	BP_Allocation.CorrGLAccount,
	|	BP_Allocation.CorrInventoryAccountType";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefProduction);
	AccountingPolicy = StructureAdditionalProperties.AccountingPolicy;
	Query.SetParameter("UseCharacteristics", AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", AccountingPolicy.UseBatches);
	Query.SetParameter("ReturnWaste", NStr("en = 'Inventory allocation'; ru = 'Распределение запасов';pl = 'Alokacja zapasów';es_ES = 'Asignación del inventario';es_CO = 'Asignación del inventario';tr = 'Stok dağıtımı';it = 'Allocazione delle scorte';de = 'Bestandszuordnung'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	// Determine table for inventory accounting.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryByProducts", ResultsArray[2].Unload());

	// Generate table for inventory accounting.
	GenerateTableInventoryByProducts(DocumentRefProduction, StructureAdditionalProperties);
	
	// Generate table for Inventory cost layer
	GenerateTableInventoryCostLayerForConvertFromWIP(DocumentRefProduction, StructureAdditionalProperties);
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryByProducts");

	// Expand table for inventory.
	ResultsSelection = ResultsArray[1].Select();
	
	While ResultsSelection.Next() Do
		
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
		FillPropertyValues(TableRowReceipt, ResultsSelection);
		
	EndDo;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryByProducts(DocumentRefProduction, StructureAdditionalProperties)
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	FilterStructure = New Structure("Products, Characteristic, Batch, Ownership, GLAccount");
	
	TableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory;
	TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	For Each ByProductsLine In StructureAdditionalProperties.TableForRegisterRecords.TableInventoryByProducts Do
		
		// Inventory record
		FillPropertyValues(FilterStructure, ByProductsLine);
		
		FinishedProductLines = TableInventory.FindRows(FilterStructure);
		
		InventoryLine = TableInventory.Add();
		
		If FinishedProductLines.Count() Then
			
			FillPropertyValues(InventoryLine, FinishedProductLines[0]);
			
		EndIf;
		
		FillPropertyValues(InventoryLine, ByProductsLine);
		
		// Accounting record
		If UseDefaultTypeOfAccounting And ByProductsLine.RecordType = AccumulationRecordType.Expense Then
			AccountingLine = TableAccountingJournalEntries.Add();
			FillPropertyValues(AccountingLine, ByProductsLine);
			AccountingLine.AccountDr = ByProductsLine.CorrGLAccount;
			AccountingLine.AccountCr = ByProductsLine.GLAccount;
			AccountingLine.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
			AccountingLine.Content = ByProductsLine.ContentOfAccountingRecord;
		EndIf;
		
	EndDo;
	
	CollapseAccountingJournalEntries(TableAccountingJournalEntries);
	
EndProcedure

Procedure GenerateTableInventoryCostLayerForConvertFromWIP(DocumentRefProduction, StructureAdditionalProperties)
	
	TableInventoryCostLayer = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryCostLayer;
	
	If StructureAdditionalProperties.AccountingPolicy.UseFIFO Then
		
		For Each ByProductsLine In StructureAdditionalProperties.TableForRegisterRecords.TableInventoryByProducts Do
			
			NewLine = TableInventoryCostLayer.Add();
			FillPropertyValues(NewLine, ByProductsLine);
			NewLine.CostLayer = DocumentRefProduction;
			NewLine.SourceRecord = True;
			
		EndDo;
		
	EndIf;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryCostLayer", TableInventoryCostLayer);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableReservedProductsConvertFromWIP(DocumentRefProduction, StructureAdditionalProperties)
	
	SalesOrder = StructureAdditionalProperties.DocumentAttributes.SalesOrder;
	ProductionOrder = StructureAdditionalProperties.DocumentAttributes.BasisDocument;
	
	TableReservedProducts = DriveServer.EmptyReservedProductsTable();
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	If ValueIsFilled(ProductionOrder) Then
		
		Query.Text =
		"SELECT
		|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
		|	TableProduction.Period AS Period,
		|	TableProduction.Company AS Company,
		|	TableProduction.StructuralUnit AS StructuralUnit,
		|	TableProduction.ProductsStructuralUnit AS ProductsStructuralUnit,
		|	TableProduction.ProductsGLAccount AS ProductsGLAccount,
		|	TableProduction.Products AS Products,
		|	TableProduction.Characteristic AS Characteristic,
		|	TableProduction.Batch AS Batch,
		|	TableProduction.ProductionOrder AS ProductionOrder,
		|	SUM(TableProduction.Quantity) AS Quantity
		|FROM
		|	TemporaryTableProduction AS TableProduction
		|
		|GROUP BY
		|	TableProduction.Period,
		|	TableProduction.Company,
		|	TableProduction.StructuralUnit,
		|	TableProduction.ProductsStructuralUnit,
		|	TableProduction.ProductsGLAccount,
		|	TableProduction.Products,
		|	TableProduction.Characteristic,
		|	TableProduction.Batch,
		|	TableProduction.ProductionOrder";
		
		TableProducts = Query.Execute().Unload();
		
		TableBackorders = StructureAdditionalProperties.TableForRegisterRecords.TableBackorders;
		TableBackorders.Indexes.Add("RecordType, Company, Products, Characteristic");
		
		For n = 0 To TableProducts.Count() - 1 Do
			
			RowTableInventoryProducts = TableProducts[n];
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("RecordType", AccumulationRecordType.Expense);
			StructureForSearch.Insert("Company", RowTableInventoryProducts.Company);
			StructureForSearch.Insert("Products", RowTableInventoryProducts.Products);
			StructureForSearch.Insert("Characteristic", RowTableInventoryProducts.Characteristic);
			
			ArrayPropertiesProducts = TableBackorders.FindRows(StructureForSearch);
			
			If ArrayPropertiesProducts.Count() = 0 Then
				Continue;
			EndIf;
			
			RemainingQuantity = RowTableInventoryProducts.Quantity;
			
			For Each RowAllocationArray In ArrayPropertiesProducts Do
				
				If RowAllocationArray.Quantity > 0 And RemainingQuantity > 0 Then
					
					NewRowReservedTable = TableReservedProducts.Add();
					FillPropertyValues(NewRowReservedTable, RowTableInventoryProducts);
					NewRowReservedTable.SalesOrder = RowAllocationArray.SalesOrder;
					NewRowReservedTable.Quantity = ?(RowAllocationArray.Quantity > RemainingQuantity, RemainingQuantity, RowAllocationArray.Quantity);
					
					RemainingQuantity = RemainingQuantity - NewRowReservedTable.Quantity;
					
					NewRowReservedTable.GLAccount = RowTableInventoryProducts.ProductsGLAccount;
					
					If ValueIsFilled(RowTableInventoryProducts.ProductsStructuralUnit) Then
						NewRowReservedTable.StructuralUnit = RowTableInventoryProducts.ProductsStructuralUnit;
					Else
						NewRowReservedTable.StructuralUnit = RowTableInventoryProducts.StructuralUnit;
					EndIf;
					
					
				EndIf;
				
			EndDo;
			
		EndDo;
		
	ElsIf ValueIsFilled(SalesOrder) Then
		
		Query.Text =
		"SELECT
		|	TableProduction.Period AS Period,
		|	TableProduction.Company AS Company,
		|	CASE
		|		WHEN TableProduction.ProductsStructuralUnit = VALUE(Catalog.BusinessUnits.EmptyRef)
		|			THEN TableProduction.StructuralUnit
		|		ELSE TableProduction.ProductsStructuralUnit
		|	END AS StructuralUnit,
		|	TableProduction.ProductsGLAccount AS GLAccount,
		|	TableProduction.Products AS Products,
		|	TableProduction.Characteristic AS Characteristic,
		|	TableProduction.Batch AS Batch,
		|	TableProduction.SalesOrder AS SalesOrder,
		|	SUM(TableProduction.Quantity) AS Quantity
		|INTO TableProduction
		|FROM
		|	TemporaryTableProduction AS TableProduction
		|
		|GROUP BY
		|	TableProduction.Period,
		|	TableProduction.Company,
		|	TableProduction.StructuralUnit,
		|	TableProduction.ProductsStructuralUnit,
		|	TableProduction.ProductsGLAccount,
		|	TableProduction.Products,
		|	TableProduction.Characteristic,
		|	TableProduction.Batch,
		|	TableProduction.SalesOrder
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SalesOrdersBalance.Company AS Company,
		|	SalesOrdersBalance.SalesOrder AS SalesOrder,
		|	SalesOrdersBalance.Products AS Products,
		|	SalesOrdersBalance.Characteristic AS Characteristic,
		|	SUM(SalesOrdersBalance.QuantityBalance) AS Quantity
		|INTO TableOrderBalance
		|FROM
		|	(SELECT
		|		SalesOrdersBalance.Company AS Company,
		|		SalesOrdersBalance.SalesOrder AS SalesOrder,
		|		SalesOrdersBalance.Products AS Products,
		|		SalesOrdersBalance.Characteristic AS Characteristic,
		|		SalesOrdersBalance.QuantityBalance AS QuantityBalance
		|	FROM
		|		AccumulationRegister.SalesOrders.Balance(&ControlTime, SalesOrder = &SalesOrder) AS SalesOrdersBalance
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		ReservedProductsBalance.Company,
		|		ReservedProductsBalance.SalesOrder,
		|		ReservedProductsBalance.Products,
		|		ReservedProductsBalance.Characteristic,
		|		-ReservedProductsBalance.QuantityBalance
		|	FROM
		|		AccumulationRegister.ReservedProducts.Balance(&ControlTime, SalesOrder = &SalesOrder) AS ReservedProductsBalance
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecordsReservedProducts.Company,
		|		DocumentRegisterRecordsReservedProducts.SalesOrder,
		|		DocumentRegisterRecordsReservedProducts.Products,
		|		DocumentRegisterRecordsReservedProducts.Characteristic,
		|		CASE
		|			WHEN DocumentRegisterRecordsReservedProducts.RecordType = VALUE(AccumulationRecordType.Expense)
		|				THEN -ISNULL(DocumentRegisterRecordsReservedProducts.Quantity, 0)
		|			ELSE ISNULL(DocumentRegisterRecordsReservedProducts.Quantity, 0)
		|		END
		|	FROM
		|		AccumulationRegister.ReservedProducts AS DocumentRegisterRecordsReservedProducts
		|	WHERE
		|		DocumentRegisterRecordsReservedProducts.Recorder = &Ref
		|		AND DocumentRegisterRecordsReservedProducts.Period <= &ControlPeriod) AS SalesOrdersBalance
		|
		|GROUP BY
		|	SalesOrdersBalance.Company,
		|	SalesOrdersBalance.SalesOrder,
		|	SalesOrdersBalance.Products,
		|	SalesOrdersBalance.Characteristic
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TableProduction.Period AS Period,
		|	TableProduction.Company AS Company,
		|	TableProduction.StructuralUnit AS StructuralUnit,
		|	TableProduction.GLAccount AS GLAccount,
		|	TableProduction.Products AS Products,
		|	TableProduction.Characteristic AS Characteristic,
		|	TableProduction.Batch AS Batch,
		|	TableProduction.SalesOrder AS SalesOrder,
		|	CASE
		|		WHEN TableOrderBalance.Quantity > TableProduction.Quantity
		|			THEN TableProduction.Quantity
		|		ELSE TableOrderBalance.Quantity
		|	END AS Quantity
		|INTO TableToReserve
		|FROM
		|	TableProduction AS TableProduction
		|		INNER JOIN TableOrderBalance AS TableOrderBalance
		|		ON TableProduction.Company = TableOrderBalance.Company
		|			AND TableProduction.SalesOrder = TableOrderBalance.SalesOrder
		|			AND TableProduction.Products = TableOrderBalance.Products
		|			AND TableProduction.Characteristic = TableOrderBalance.Characteristic
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
		|	TableToReserve.Period AS Period,
		|	TableToReserve.Company AS Company,
		|	TableToReserve.StructuralUnit AS StructuralUnit,
		|	TableToReserve.GLAccount AS GLAccount,
		|	TableToReserve.Products AS Products,
		|	TableToReserve.Characteristic AS Characteristic,
		|	TableToReserve.Batch AS Batch,
		|	TableToReserve.SalesOrder AS SalesOrder,
		|	TableToReserve.Quantity AS Quantity
		|FROM
		|	TableToReserve AS TableToReserve
		|WHERE
		|	TableToReserve.Quantity > 0";
		
		Query.SetParameter("Ref", DocumentRefProduction);
		Query.SetParameter("SalesOrder", SalesOrder);
		Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
		Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
		
		TableReservedProducts = Query.Execute().Unload();
		
	EndIf;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableReservedProducts", TableReservedProducts);
	
EndProcedure

#EndRegion

#Region Common

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DataInitializationByDisposals(DocumentRefProduction, StructureAdditionalProperties)

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	ProductionWaste.LineNumber AS LineNumber,
	|	TT_DocumentHeader.Company AS Company,
	|	TT_DocumentHeader.PresentationCurrency AS PresentationCurrency,
	|	TT_DocumentHeader.Date AS Period,
	|	TT_DocumentHeader.StructuralUnit AS StructuralUnit,
	|	TT_DocumentHeader.Cell AS Cell,
	|	TT_DocumentHeader.DisposalsStructuralUnit AS DisposalsStructuralUnit,
	|	ProductionWaste.ConsumptionGLAccount AS GLAccount,
	|	ProductionWaste.InventoryGLAccount AS GLAccountWaste,
	|	ProductionWaste.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionWaste.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|				OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN ProductionWaste.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	ProductionWaste.Ownership AS Ownership,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	UNDEFINED AS SalesOrder,
	|	ProductionWaste.Quantity * ISNULL(CatalogUOM.Factor, 1) AS Quantity,
	|	0 AS Amount,
	|	&ReturnWaste AS ContentOfAccountingRecord,
	|	&ReturnWaste AS Content
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Document.Manufacturing.Disposals AS ProductionWaste
	|		ON TT_DocumentHeader.Ref = ProductionWaste.Ref
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (ProductionWaste.MeasurementUnit = CatalogUOM.Ref)
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON ProductionWaste.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON TT_DocumentHeader.DisposalsStructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionWaste.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TT_DocumentHeader.Date AS Period,
	|	TT_DocumentHeader.Company AS Company,
	|	TT_DocumentHeader.StructuralUnit AS StructuralUnit,
	|	TT_DocumentHeader.Cell AS Cell,
	|	TT_DocumentHeader.DisposalsStructuralUnit AS DisposalsStructuralUnit,
	|	TT_DocumentHeader.DisposalsCell AS DisposalsCell,
	|	ProductionWaste.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionWaste.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|				OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN ProductionWaste.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	ProductionWaste.Ownership AS Ownership,
	|	ProductionWaste.Quantity * ISNULL(CatalogUOM.Factor, 1) AS Quantity
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Document.Manufacturing.Disposals AS ProductionWaste
	|		ON TT_DocumentHeader.Ref = ProductionWaste.Ref
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (ProductionWaste.MeasurementUnit = CatalogUOM.Ref)
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON ProductionWaste.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON TT_DocumentHeader.DisposalsStructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefProduction);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	AccountingPolicy = StructureAdditionalProperties.AccountingPolicy;
	Query.SetParameter("UseCharacteristics", AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins", AccountingPolicy.UseStorageBins);
	
	Query.SetParameter("ReturnWaste", NStr("en = 'Recyclable waste'; ru = 'Возвратные отходы';pl = 'Odpady wtórne';es_ES = 'Residuos reciclables';es_CO = 'Residuos reciclables';tr = 'Geri dönüştürülebilir atık';it = 'Rifiuti riciclabili';de = 'Wieder-verwertbarer Abfall'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	// Determine table for inventory accounting.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDisposals", ResultsArray[0].Unload());

	// Generate table for inventory accounting.
	GenerateTableInventoryDisposals(DocumentRefProduction, StructureAdditionalProperties);
	
	// Expand table for inventory.
	ResultsSelection = ResultsArray[1].Select();
	
	While ResultsSelection.Next() Do
		
		TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
		FillPropertyValues(TableRowExpense, ResultsSelection);
		
	EndDo;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryDisposals(DocumentRefProduction, StructureAdditionalProperties)
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDisposals.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDisposals[n];
		
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, RowTableInventory);
		TableRowReceipt.GLAccount = RowTableInventory.GLAccountWaste;
		
		// Reusable scraps autotransfer.
		If ValueIsFilled(RowTableInventory.DisposalsStructuralUnit) Then
			
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.RecordType = AccumulationRecordType.Expense;
			TableRowExpense.GLAccount = RowTableInventory.GLAccountWaste;
			
			TableRowExpense.StructuralUnitCorr = RowTableInventory.DisposalsStructuralUnit;
			TableRowExpense.CorrGLAccount = RowTableInventory.GLAccountWaste;
			
			TableRowExpense.ProductsCorr = RowTableInventory.Products;
			TableRowExpense.CharacteristicCorr = RowTableInventory.Characteristic;
			TableRowExpense.BatchCorr = RowTableInventory.Batch;
			TableRowExpense.OwnershipCorr = RowTableInventory.Ownership;
			TableRowExpense.CustomerCorrOrder = RowTableInventory.SalesOrder;
			
			TableRowExpense.ContentOfAccountingRecord = NStr("en = 'Inventory transfer'; ru = 'Перемещение запасов';pl = 'Przesunięcie międzymagazynowe';es_ES = 'Traslado del inventario';es_CO = 'Transferencia de inventario';tr = 'Stok transferi';it = 'Movimenti di scorte';de = 'Bestandsumlagerung'", MainLanguageCode);
			TableRowExpense.Content = NStr("en = 'Inventory transfer'; ru = 'Перемещение запасов';pl = 'Przesunięcie międzymagazynowe';es_ES = 'Traslado del inventario';es_CO = 'Transferencia de inventario';tr = 'Stok transferi';it = 'Movimenti di scorte';de = 'Bestandsumlagerung'", MainLanguageCode);
			
			// Receipt.
			TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowReceipt, RowTableInventory);
			
			TableRowReceipt.StructuralUnit = RowTableInventory.DisposalsStructuralUnit;
			TableRowReceipt.GLAccount = RowTableInventory.GLAccountWaste;
			
			TableRowReceipt.ContentOfAccountingRecord = NStr("en = 'Inventory transfer'; ru = 'Перемещение запасов';pl = 'Przesunięcie międzymagazynowe';es_ES = 'Traslado del inventario';es_CO = 'Transferencia de inventario';tr = 'Stok transferi';it = 'Movimenti di scorte';de = 'Bestandsumlagerung'", MainLanguageCode);
			TableRowReceipt.Content = NStr("en = 'Inventory transfer'; ru = 'Перемещение запасов';pl = 'Przesunięcie międzymagazynowe';es_ES = 'Traslado del inventario';es_CO = 'Transferencia de inventario';tr = 'Stok transferi';it = 'Movimenti di scorte';de = 'Bestandsumlagerung'", MainLanguageCode);
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryDisposals");
	
EndProcedure

Procedure CollapseAccountingJournalEntries(TableAccountingJournalEntries)
	
	ColumnsNames = "";
	
	For Each TableColumn In TableAccountingJournalEntries.Columns Do
		If TableColumn.Name <> "LineNumber"
			And TableColumn.Name <> "Amount"
			And TableColumn.Name <> "AmountCurCr"
			And TableColumn.Name <> "AmountCurDr" Then
			ColumnsNames = ColumnsNames + TableColumn.Name + ",";
		EndIf;
	EndDo;
	
	ColumnsNames = Left(ColumnsNames, StrLen(ColumnsNames) - 1);
	
	TableAccountingJournalEntries.GroupBy(ColumnsNames, "LineNumber,Amount,AmountCurCr,AmountCurDr");
	
	Index = 1;
	For Each TableLine In TableAccountingJournalEntries Do
		TableLine.LineNumber = Index;
		Index = Index + 1;
	EndDo;
	
EndProcedure

// Function checks if the document is posted and calls the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_ProductionAssembly";
	
	// MultilingualSupport
	If PrintParams = Undefined Then
		LanguageCode = NationalLanguageSupportClientServer.DefaultLanguageCode();
	Else
		LanguageCode = PrintParams.LanguageCode;
	EndIf;
	
	If LanguageCode <> CurrentLanguage().LanguageCode Then 
		SessionParameters.LanguageCodeForOutput = LanguageCode;
	EndIf;
	// End MultilingualSupport
	
	FirstDocument = True;
	
	For Each CurrentDocument In ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		If TemplateName = "GoodsContentForm" Then
			
			Query = New Query();
			Query.SetParameter("CurrentDocument", CurrentDocument);
			
			If CurrentDocument.OperationKind = Enums.OperationTypesProduction.Assembly Then
				
				Query.Text =
				"SELECT ALLOWED
				|	Production.Date AS DocumentDate,
				|	Production.StructuralUnit AS WarehousePresentation,
				|	Production.Cell AS CellPresentation,
				|	Production.Number AS Number,
				|	Production.Company.Prefix AS Prefix,
				|	Production.Inventory.(
				|		LineNumber AS LineNumber,
				|		Products.Warehouse AS Warehouse,
				|		Products.Cell AS Cell,
				|		CASE
				|			WHEN (CAST(Production.Inventory.Products.DescriptionFull AS String(100))) = """"
				|				THEN Production.Inventory.Products.Description
				|			ELSE Production.Inventory.Products.DescriptionFull
				|		END AS InventoryItem,
				|		Products.SKU AS SKU,
				|		Products.Code AS Code,
				|		MeasurementUnit.Description AS MeasurementUnit,
				|		Quantity AS Quantity,
				|		Characteristic,
				|		Products.ProductsType AS ProductsType,
				|		ConnectionKey
				|	),
				|	Production.SerialNumbers.(
				|		SerialNumber,
				|		ConnectionKey
				|	)
				|FROM
				|	Document.Manufacturing AS Production
				|WHERE
				|	Production.Ref = &CurrentDocument
				|
				|ORDER BY
				|	LineNumber";
				
				// MultilingualSupport
				DriveServer.ChangeQueryTextForCurrentLanguage(Query.Text, LanguageCode);
				// End MultilingualSupport
				
				Header = Query.Execute().Select();
				Header.Next();
				
				LinesSelectionInventory = Header.Inventory.Select();
				LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
				
			Else
				
				Query.Text = 
				"SELECT ALLOWED
				|	Production.Date AS DocumentDate,
				|	Production.StructuralUnit AS WarehousePresentation,
				|	Production.Cell AS CellPresentation,
				|	Production.Number AS Number,
				|	Production.Company.Prefix AS Prefix,
				|	Production.Products.(
				|		LineNumber AS LineNumber,
				|		Products.Warehouse AS Warehouse,
				|		Products.Cell AS Cell,
				|		CASE
				|			WHEN (CAST(Production.Products.Products.DescriptionFull AS String(100))) = """"
				|				THEN Production.Products.Products.Description
				|			ELSE Production.Products.Products.DescriptionFull
				|		END AS InventoryItem,
				|		Products.SKU AS SKU,
				|		Products.Code AS Code,
				|		MeasurementUnit.Description AS MeasurementUnit,
				|		Quantity AS Quantity,
				|		Characteristic AS Characteristic,
				|		Products.ProductsType AS ProductsType,
				|		ConnectionKey
				|	),
				|	Production.SerialNumbersProducts.(
				|		SerialNumber,
				|		ConnectionKey
				|	)
				|FROM
				|	Document.Manufacturing AS Production
				|WHERE
				|	Production.Ref = &CurrentDocument";
				
				// MultilingualSupport
				DriveServer.ChangeQueryTextForCurrentLanguage(Query.Text, LanguageCode);
				// End MultilingualSupport
				
				Header = Query.Execute().Select();
				Header.Next();
				
				LinesSelectionInventory = Header.Products.Select();
				LinesSelectionSerialNumbers = Header.SerialNumbersProducts.Select();
				
			EndIf;
			
			SpreadsheetDocument.PrintParametersName = "PARAMETERS_PRINT_Manufacturing_GoodsContentForm";
			
			Template = PrintManagement.PrintFormTemplate("Document.Manufacturing.PF_MXL_GoodsContentForm", LanguageCode);
			
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Production #%1 dated %2'; ru = 'Производство №%1 от %2';pl = 'Produkcja nr %1 z dn. %2';es_ES = 'Producción #%1 fechado %2';es_CO = 'Producción #%1 fechado %2';tr = '%1 no.''lu %2 tarihli üretim';it = 'Produzione #%1 con data %2';de = 'Produktion Nr %1 datiert %2'", LanguageCode),
				DocumentNumber,
				Format(Header.DocumentDate, "DLF=DD"));
													
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("Warehouse");
			TemplateArea.Parameters.WarehousePresentation = Header.WarehousePresentation;
			SpreadsheetDocument.Put(TemplateArea);
			
			If Constants.UseStorageBins.Get() Then
				
				TemplateArea = Template.GetArea("Cell");
				TemplateArea.Parameters.CellPresentation = Header.CellPresentation;
				SpreadsheetDocument.Put(TemplateArea);
				
			EndIf;
			
			TemplateArea = Template.GetArea("PrintingTime");
			TemplateArea.Parameters.PrintingTime = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Date and time of printing: %1. User: %2'; ru = 'Дата и время печати: %1. Пользователь: %2';pl = 'Data i godzina wydruku: %1. Użytkownik: %2';es_ES = 'Fecha y hora de la impresión: %1. Usuario: %2';es_CO = 'Fecha y hora de la impresión: %1. Usuario: %2';tr = 'Yazdırma tarihi ve saati: %1. Kullanıcı: %2';it = 'Data e orario della stampa: %1. Utente: %2';de = 'Datum und Uhrzeit des Druckens: %1. Benutzer: %2'", LanguageCode),
				CurrentSessionDate(),
				Users.CurrentUser());
				
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("TableHeader");
			SpreadsheetDocument.Put(TemplateArea);
			TemplateArea = Template.GetArea("String");
			
			While LinesSelectionInventory.Next() Do

				If Not LinesSelectionInventory.ProductsType = Enums.ProductsTypes.InventoryItem Then
					Continue;
				EndIf;
				
				TemplateArea.Parameters.Fill(LinesSelectionInventory);
				StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(
					LinesSelectionSerialNumbers, LinesSelectionInventory.ConnectionKey);
				
				TemplateArea.Parameters.InventoryItem = DriveServer.GetProductsPresentationForPrinting(
					LinesSelectionInventory.InventoryItem,
					LinesSelectionInventory.Characteristic,
					LinesSelectionInventory.SKU,
					StringSerialNumbers);
					
				SpreadsheetDocument.Put(TemplateArea);
				
			EndDo;
			
			TemplateArea = Template.GetArea("Total");
			SpreadsheetDocument.Put(TemplateArea);	
			
		EndIf;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

Function GetOwnershipTypeForCustomerInventory(Products, SubcontractorOrderReceived)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ManufacturingProducts.Products AS Products
	|INTO TT_Manufacturing
	|FROM
	|	&Products AS ManufacturingProducts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorOrderReceivedProducts.Products AS Products
	|INTO TT_SubcontractorOrder
	|FROM
	|	Document.SubcontractorOrderReceived.Products AS SubcontractorOrderReceivedProducts
	|WHERE
	|	SubcontractorOrderReceivedProducts.Ref = &SubcontractorOrderReceived
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TRUE AS IsCustomerOwnedInventory
	|FROM
	|	TT_Manufacturing AS TT_Manufacturing
	|		INNER JOIN TT_SubcontractorOrder AS TT_SubcontractorOrder
	|		ON TT_Manufacturing.Products = TT_SubcontractorOrder.Products";
	
	Query.SetParameter("Products", Products.Unload());
	Query.SetParameter("SubcontractorOrderReceived", SubcontractorOrderReceived);
	
	QueryResult = Query.Execute();
	
	Return ?(QueryResult.IsEmpty(),
		Enums.InventoryOwnershipTypes.CustomerProvidedInventory,
		Enums.InventoryOwnershipTypes.CustomerOwnedInventory);
	
EndFunction

Procedure AddOfflineRecords(DocumentRefProduction, StructureAdditionalProperties)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Inventory.Period AS Period,
	|	Inventory.Recorder AS Recorder,
	|	Inventory.LineNumber AS LineNumber,
	|	Inventory.Active AS Active,
	|	Inventory.RecordType AS RecordType,
	|	Inventory.Company AS Company,
	|	Inventory.PresentationCurrency AS PresentationCurrency,
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.Ownership AS Ownership,
	|	Inventory.GLAccount AS GLAccount,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.Quantity AS Quantity,
	|	Inventory.Amount AS Amount,
	|	Inventory.StructuralUnitCorr AS StructuralUnitCorr,
	|	Inventory.CorrGLAccount AS CorrGLAccount,
	|	Inventory.ProductsCorr AS ProductsCorr,
	|	Inventory.CharacteristicCorr AS CharacteristicCorr,
	|	Inventory.BatchCorr AS BatchCorr,
	|	Inventory.OwnershipCorr AS OwnershipCorr,
	|	Inventory.CustomerCorrOrder AS CustomerCorrOrder,
	|	Inventory.Specification AS Specification,
	|	Inventory.SpecificationCorr AS SpecificationCorr,
	|	Inventory.CorrSalesOrder AS CorrSalesOrder,
	|	Inventory.SourceDocument AS SourceDocument,
	|	Inventory.Department AS Department,
	|	Inventory.Responsible AS Responsible,
	|	Inventory.VATRate AS VATRate,
	|	Inventory.FixedCost AS FixedCost,
	|	Inventory.ProductionExpenses AS ProductionExpenses,
	|	Inventory.Return AS Return,
	|	Inventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	Inventory.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	Inventory.OfflineRecord AS OfflineRecord,
	|	Inventory.SalesRep AS SalesRep,
	|	Inventory.Counterparty AS Counterparty,
	|	Inventory.Currency AS Currency,
	|	Inventory.SalesOrder AS SalesOrder,
	|	Inventory.CostObject AS CostObject,
	|	Inventory.CostObjectCorr AS CostObjectCorr,
	|	Inventory.InventoryAccountType AS InventoryAccountType,
	|	Inventory.CorrInventoryAccountType AS CorrInventoryAccountType
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Recorder = &Recorder
	|	AND Inventory.OfflineRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountingJournalEntries.Period AS Period,
	|	AccountingJournalEntries.Recorder AS Recorder,
	|	AccountingJournalEntries.LineNumber AS LineNumber,
	|	AccountingJournalEntries.Active AS Active,
	|	AccountingJournalEntries.AccountDr AS AccountDr,
	|	AccountingJournalEntries.AccountCr AS AccountCr,
	|	AccountingJournalEntries.Company AS Company,
	|	AccountingJournalEntries.PlanningPeriod AS PlanningPeriod,
	|	AccountingJournalEntries.CurrencyDr AS CurrencyDr,
	|	AccountingJournalEntries.CurrencyCr AS CurrencyCr,
	|	AccountingJournalEntries.Status AS Status,
	|	AccountingJournalEntries.Amount AS Amount,
	|	AccountingJournalEntries.AmountCurDr AS AmountCurDr,
	|	AccountingJournalEntries.AmountCurCr AS AmountCurCr,
	|	AccountingJournalEntries.Content AS Content,
	|	AccountingJournalEntries.OfflineRecord AS OfflineRecord
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS AccountingJournalEntries
	|WHERE
	|	AccountingJournalEntries.Recorder = &Recorder
	|	AND AccountingJournalEntries.OfflineRecord
	|	AND &UseDefaultTypeOfAccounting
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkInProgress.Period AS Period,
	|	WorkInProgress.Recorder AS Recorder,
	|	WorkInProgress.LineNumber AS LineNumber,
	|	WorkInProgress.Active AS Active,
	|	WorkInProgress.RecordType AS RecordType,
	|	WorkInProgress.Company AS Company,
	|	WorkInProgress.PresentationCurrency AS PresentationCurrency,
	|	WorkInProgress.StructuralUnit AS StructuralUnit,
	|	WorkInProgress.CostObject AS CostObject,
	|	WorkInProgress.Products AS Products,
	|	WorkInProgress.Characteristic AS Characteristic,
	|	WorkInProgress.Quantity AS Quantity,
	|	WorkInProgress.Amount AS Amount,
	|	WorkInProgress.OfflineRecord AS OfflineRecord
	|FROM
	|	AccumulationRegister.WorkInProgress AS WorkInProgress
	|WHERE
	|	WorkInProgress.Recorder = &Recorder
	|	AND WorkInProgress.OfflineRecord";
	
	Query.SetParameter("Recorder", DocumentRefProduction);
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	QueryResult = Query.ExecuteBatch();
	
	InventoryRecords = QueryResult[0].Unload();
	AccountingJournalEntries = QueryResult[1].Unload();
	WIPRecords = QueryResult[2].Unload();
	
	For Each InventoryRecord In InventoryRecords Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(NewRow, InventoryRecord);
	EndDo;
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		
		For Each AccountingJournalEntriesRecord In AccountingJournalEntries Do
			NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
			FillPropertyValues(NewRow, AccountingJournalEntriesRecord);
		EndDo;
	EndIf;
	
	For Each WIPRecord In WIPRecords Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableWorkInProgress.Add();
		FillPropertyValues(NewRow, WIPRecord);
	EndDo;
	
EndProcedure

// Generates a table of reserved components for "ReservedProducts" register
Procedure GenerateTableReservedProducts(DocumentRefProduction, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT DISTINCT
	|	ReservedProducts.Company AS Company,
	|	ReservedProducts.StructuralUnit AS StructuralUnit,
	|	ReservedProducts.Products AS Products,
	|	ReservedProducts.Characteristic AS Characteristic,
	|	ReservedProducts.Batch AS Batch,
	|	ReservedProducts.BasisDocument AS SalesOrder
	|INTO ReservedProducts
	|FROM
	|	TemporaryTableReservedProducts AS ReservedProducts
	|WHERE
	|	ReservedProducts.BasisDocument <> VALUE(Document.ProductionOrder.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ReservedProducts.Company AS Company,
	|	ReservedProducts.StructuralUnit AS StructuralUnit,
	|	ReservedProducts.Products AS Products,
	|	ReservedProducts.Characteristic AS Characteristic,
	|	ReservedProducts.Batch AS Batch,
	|	ReservedProducts.SalesOrder AS SalesOrder
	|FROM
	|	ReservedProducts AS ReservedProducts";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.ReservedProducts");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	Query.Text =
	"SELECT
	|	Balance.Company AS Company,
	|	Balance.StructuralUnit AS StructuralUnit,
	|	Balance.Products AS Products,
	|	Balance.Characteristic AS Characteristic,
	|	Balance.Batch AS Batch,
	|	Balance.SalesOrder AS SalesOrder,
	|	SUM(Balance.Quantity) AS Quantity
	|INTO ReservedProductsBalance
	|FROM
	|	(SELECT
	|		Balance.Company AS Company,
	|		Balance.StructuralUnit AS StructuralUnit,
	|		Balance.Products AS Products,
	|		Balance.Characteristic AS Characteristic,
	|		Balance.Batch AS Batch,
	|		Balance.SalesOrder AS SalesOrder,
	|		Balance.QuantityBalance AS Quantity
	|	FROM
	|		AccumulationRegister.ReservedProducts.Balance(
	|				&AtData,
	|				(Company, StructuralUnit, Products, Characteristic, Batch, SalesOrder) IN
	|					(SELECT
	|						ReservedProducts.Company AS Company,
	|						ReservedProducts.StructuralUnit AS StructuralUnit,
	|						ReservedProducts.Products AS Products,
	|						ReservedProducts.Characteristic AS Characteristic,
	|						ReservedProducts.Batch AS Batch,
	|						ReservedProducts.SalesOrder AS SalesOrder
	|					FROM
	|						ReservedProducts AS ReservedProducts)) AS Balance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsReservedProducts.Company,
	|		DocumentRegisterRecordsReservedProducts.StructuralUnit,
	|		DocumentRegisterRecordsReservedProducts.Products,
	|		DocumentRegisterRecordsReservedProducts.Characteristic,
	|		DocumentRegisterRecordsReservedProducts.Batch,
	|		DocumentRegisterRecordsReservedProducts.SalesOrder,
	|		CASE
	|			WHEN DocumentRegisterRecordsReservedProducts.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRegisterRecordsReservedProducts.Quantity
	|			ELSE -DocumentRegisterRecordsReservedProducts.Quantity
	|		END
	|	FROM
	|		AccumulationRegister.ReservedProducts AS DocumentRegisterRecordsReservedProducts
	|	WHERE
	|		DocumentRegisterRecordsReservedProducts.Recorder = &Ref
	|		AND DocumentRegisterRecordsReservedProducts.Period <= &ControlPeriod) AS Balance
	|
	|GROUP BY
	|	Balance.StructuralUnit,
	|	Balance.Company,
	|	Balance.Characteristic,
	|	Balance.Batch,
	|	Balance.Products,
	|	Balance.SalesOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.InventoryGLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.BasisDocument AS Order,
	|	SUM(TableInventory.Reserve) AS Reserve
	|INTO TemporaryTableInventoryGrouped
	|FROM
	|	TemporaryTableReservedProducts AS TableInventory
	|WHERE
	|	TableInventory.Reserve > 0
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.InventoryGLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Order AS SalesOrder,
	|	CASE
	|		WHEN Balance.Quantity > TableInventory.Reserve
	|			THEN TableInventory.Reserve
	|		ELSE Balance.Quantity
	|	END AS Quantity
	|INTO AvailableReserve
	|FROM
	|	TemporaryTableInventoryGrouped AS TableInventory
	|		INNER JOIN ReservedProductsBalance AS Balance
	|		ON TableInventory.Company = Balance.Company
	|			AND TableInventory.StructuralUnit = Balance.StructuralUnit
	|			AND TableInventory.Products = Balance.Products
	|			AND TableInventory.Characteristic = Balance.Characteristic
	|			AND TableInventory.Batch = Balance.Batch
	|			AND TableInventory.Order = Balance.SalesOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	Reserve.Period AS Period,
	|	Reserve.Company AS Company,
	|	Reserve.StructuralUnit AS StructuralUnit,
	|	Reserve.GLAccount AS GLAccount,
	|	Reserve.Products AS Products,
	|	Reserve.Characteristic AS Characteristic,
	|	Reserve.Batch AS Batch,
	|	Reserve.SalesOrder AS SalesOrder,
	|	Reserve.Quantity AS Quantity
	|FROM
	|	AvailableReserve AS Reserve
	|WHERE
	|	Reserve.Quantity > 0";
	
	Query.SetParameter("Ref", DocumentRefProduction);
	Query.SetParameter("AtData", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	TableReservedProducts = StructureAdditionalProperties.TableForRegisterRecords.TableReservedProducts;
	
	While Selection.Next() Do
		
		NewReservedProductsLine = TableReservedProducts.Add();
		FillPropertyValues(NewReservedProductsLine, Selection);
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf

