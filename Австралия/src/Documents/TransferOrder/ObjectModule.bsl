#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
#Region EventHandlers

Procedure OnCopy(CopiedObject)
	
	FillOnCopy();

EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	If SalesOrderPosition = Enums.AttributeStationing.InHeader Then
		
		For Each TabularSectionRow In Inventory Do
			
			TabularSectionRow.SalesOrder = SalesOrder;
			
		EndDo;
		
	EndIf;	
	
	If ShipmentDatePosition = Enums.AttributeStationing.InHeader Then
		For Each TabularSectionRow In Inventory Do
			If TabularSectionRow.ShipmentDate <> ShipmentDate Then
				TabularSectionRow.ShipmentDate = ShipmentDate;
			EndIf;
		EndDo;
	EndIf;

	
	If Not Constants.UseSeveralLinesOfBusiness.Get() Then
		
		For Each Row In Inventory Do
			If OperationKind = Enums.OperationTypesTransferOrder.WriteOffToExpenses Then
				
				Row.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
				
			EndIf;
		EndDo;
		
	EndIf;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

// In the event handler of the FillingProcessor document
// - filling the document according to reconciliation of products at the place of storage.
//
Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.WorkOrder") Then
		
		Query = New Query(
		"SELECT ALLOWED
		|	WorkOrder.Ref AS BasisDocument,
		|	VALUE(Enum.OperationTypesTransferOrder.WriteOffToExpenses) AS OperationKind,
		|	WorkOrder.Company AS Company,
		|	WorkOrder.InventoryWarehouse AS StructuralUnit,
		|	WorkOrder.SalesStructuralUnit AS StructuralUnitPayee,
		|	WorkOrder.Materials.(
		|		Ref AS Ref,
		|		LineNumber AS LineNumber,
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		Batch AS Batch,
		|		Quantity AS Quantity,
		|		Reserve AS Reserve,
		|		ReserveShipment AS ReserveShipment,
		|		MeasurementUnit AS MeasurementUnit
		|	) AS Materials
		|FROM
		|	Document.WorkOrder AS WorkOrder
		|		INNER JOIN InformationRegister.AccountingPolicy.SliceLast(, ) AS AccountingPolicySliceLast
		|		ON WorkOrder.Company = AccountingPolicySliceLast.Company
		|WHERE
		|	WorkOrder.Ref = &BasisDocument
		|	AND NOT AccountingPolicySliceLast.PostExpensesByWorkOrder");
		
		Query.SetParameter("BasisDocument", FillingData);
		
		Inventory.Clear();
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionMaterials = QueryResultSelection.Materials.Select();
			While SelectionMaterials.Next() Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, SelectionMaterials);
			EndDo;
			
		EndIf;
		
	// begin Drive.FullVersion
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ProductionOrder")
		AND FillingData.OperationKind = Enums.OperationTypesProductionOrder.Assembly Then
		
		Query = New Query( 
		"SELECT ALLOWED
		|	ProductionOrder.Ref AS BasisDocument,
		|	ProductionOrder.StructuralUnit AS StructuralUnitPayee,
		|	ProductionOrder.Company AS Company,
		|	VALUE(Enum.OperationTypesTransferOrder.Transfer) AS OperationKind,
		|	CASE
		|		WHEN StructuralUnitSource.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR StructuralUnitSource.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN StructuralUnitSource.TransferSource
		|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
		|	END AS StructuralUnit,
		|	ProductionOrder.Inventory.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		MeasurementUnit AS MeasurementUnit,
		|		Quantity AS Quantity,
		|		Ref.SalesOrder AS SalesOrder
		|	)
		|FROM
		|	Document.ProductionOrder AS ProductionOrder
		|		LEFT JOIN Catalog.BusinessUnits AS StructuralUnitSource
		|		ON ProductionOrder.StructuralUnit = StructuralUnitSource.Ref
		|WHERE
		|	ProductionOrder.Ref = &BasisDocument");
		
		Query.SetParameter("BasisDocument", FillingData);
		
		Inventory.Clear();
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionInventory = QueryResultSelection.Inventory.Select();
			While SelectionInventory.Next() Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, SelectionInventory);
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ProductionOrder") 
		AND FillingData.OperationKind = Enums.OperationTypesProductionOrder.Disassembly Then
		
		Query = New Query(
		"SELECT ALLOWED
		|	ProductionOrder.Ref AS BasisDocument,
		|	ProductionOrder.StructuralUnit AS StructuralUnitPayee,
		|	ProductionOrder.Company AS Company,
		|	VALUE(Enum.OperationTypesTransferOrder.Transfer) AS OperationKind,
		|	CASE
		|		WHEN StructuralUnitSource.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR StructuralUnitSource.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN StructuralUnitSource.TransferSource
		|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
		|	END AS StructuralUnit,
		|	ProductionOrder.Products.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		MeasurementUnit AS MeasurementUnit,
		|		Quantity AS Quantity
		|	)
		|FROM
		|	Document.ProductionOrder AS ProductionOrder
		|		LEFT JOIN Catalog.BusinessUnits AS StructuralUnitSource
		|		ON ProductionOrder.StructuralUnit = StructuralUnitSource.Ref
		|WHERE
		|	ProductionOrder.Ref = &BasisDocument");
		
		Query.SetParameter("BasisDocument", FillingData);
		
		Inventory.Clear();
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionProducts = QueryResultSelection.Products.Select();
			While SelectionProducts.Next() Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, SelectionProducts);
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ProductionOrder")
		AND FillingData.OperationKind = Enums.OperationTypesProductionOrder.Production Then
		
		FillByProductionOrderProduction(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ManufacturingOperation") Then
		
		FillByWIP(FillingData);
		
	// end Drive.FullVersion
	
	ElsIf TypeOf(FillingData) = Type("DocumentRef.KitOrder")
		AND FillingData.OperationKind = Enums.OperationTypesKitOrder.Assembly Then
		
		Query = New Query( 
		"SELECT ALLOWED
		|	KitOrder.Ref AS BasisDocument,
		|	KitOrder.StructuralUnit AS StructuralUnitPayee,
		|	KitOrder.Company AS Company,
		|	VALUE(Enum.OperationTypesTransferOrder.Transfer) AS OperationKind,
		|	CASE
		|		WHEN StructuralUnitTransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR StructuralUnitTransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN StructuralUnitSource.TransferSource
		|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
		|	END AS StructuralUnit,
		|	KitOrder.Inventory.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		MeasurementUnit AS MeasurementUnit,
		|		Quantity AS Quantity,
		|		Ref.SalesOrder AS SalesOrder
		|	) AS Inventory
		|FROM
		|	Document.KitOrder AS KitOrder
		|		LEFT JOIN Catalog.BusinessUnits AS StructuralUnitSource
		|		ON KitOrder.StructuralUnit = StructuralUnitSource.Ref
		|		LEFT JOIN Catalog.BusinessUnits AS StructuralUnitTransferSource
		|		ON (StructuralUnitSource.TransferSource = StructuralUnitTransferSource.Ref)
		|WHERE
		|	KitOrder.Ref = &BasisDocument");
		
		Query.SetParameter("BasisDocument", FillingData);
		
		Inventory.Clear();
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionInventory = QueryResultSelection.Inventory.Select();
			While SelectionInventory.Next() Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, SelectionInventory);
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.KitOrder") 
		AND FillingData.OperationKind = Enums.OperationTypesKitOrder.Disassembly Then
		
		Query = New Query(
		"SELECT ALLOWED
		|	KitOrder.Ref AS BasisDocument,
		|	KitOrder.StructuralUnit AS StructuralUnitPayee,
		|	KitOrder.Company AS Company,
		|	VALUE(Enum.OperationTypesTransferOrder.Transfer) AS OperationKind,
		|	CASE
		|		WHEN StructuralUnitTransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
		|				OR StructuralUnitTransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN StructuralUnitSource.TransferSource
		|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
		|	END AS StructuralUnit,
		|	KitOrder.Products.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		MeasurementUnit AS MeasurementUnit,
		|		Quantity AS Quantity
		|	) AS Products
		|FROM
		|	Document.KitOrder AS KitOrder
		|		LEFT JOIN Catalog.BusinessUnits AS StructuralUnitSource
		|		ON KitOrder.StructuralUnit = StructuralUnitSource.Ref
		|		LEFT JOIN Catalog.BusinessUnits AS StructuralUnitTransferSource
		|		ON (StructuralUnitSource.TransferSource = StructuralUnitTransferSource.Ref)
		|WHERE
		|	KitOrder.Ref = &BasisDocument");
		
		Query.SetParameter("BasisDocument", FillingData);
		
		Inventory.Clear();
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionProducts = QueryResultSelection.Products.Select();
			While SelectionProducts.Next() Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, SelectionProducts);
			EndDo;
			
		EndIf;
		
	EndIf;
	
	FillByDefault();
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
	EndIf;
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Inventory.Count() = 0 Then
		Return;
	EndIf;
	
	If ShipmentDatePosition = Enums.AttributeStationing.InTabularSection Then
		CheckedAttributes.Delete(CheckedAttributes.Find("ShipmentDate"));
	Else
		CheckedAttributes.Delete(CheckedAttributes.Find("Inventory.ShipmentDate"));
	EndIf;
		
	If Constants.UseInventoryReservation.Get() Then
		
		For Each StringInventory In Inventory Do
			
			If StringInventory.Reserve > StringInventory.Quantity Then
				
				MessageText = NStr("en = 'In row #%Number% of the ""Inventory"" section, the quantity reserved exceeds the total inventory quantity.'; ru = 'В строке №%Number% части ""Запасы"" зарезервированное количество превышает общее количество запасов.';pl = 'W wierszu nr %Number% w sekcji ""Zapasy"", ilość zarezerwowana przekracza ogólną ilość zapasów.';es_ES = 'En la fila #%Number% de la sección ""Inventario"", la cantidad reservada supera la cantidad total de inventario.';es_CO = 'En la fila #%Number% de la sección ""Inventario"", la cantidad reservada supera la cantidad total de inventario.';tr = '""Envanter"" bölümündeki #%Number% satırında ayrılan miktar toplam stok miktarını aşıyor.';it = 'Nella riga #%Number% della sezione ""Scorte"", la quantità riservata eccede il totlare delle scorte.';de = 'In Zeile Nr%Number% des Abschnitts ""Bestand"" übersteigt die reservierte Menge die gesamte Bestandsmenge.'");
				MessageText = StrReplace(MessageText, "%Number%", StringInventory.LineNumber);
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Inventory",
					StringInventory.LineNumber,
					"Reserve",
					Cancel);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If Not Constants.UseTransferOrderStatuses.Get() Then
		
		If Not ValueIsFilled(OrderState) Then
			MessageText = NStr("en = 'The order status is required. Specify the available statuses in Settings>Accounting settings>Warehouse.'; ru = 'Поле ""Состояние заказа"" не заполнено. В настройках параметров учета необходимо установить значения состояний.';pl = 'Wymagany jest status zamówienia. Określ dostępne statusy w menu Ustawienia>Ustawienia rachunkowości>Magazyn.';es_ES = 'Se requiere el estado de orden. Especificar los estados disponibles en Configuración>Configuraciones de contabilidad>Almacén.';es_CO = 'Se requiere el estado de orden. Especificar los estados disponibles en Configuración>Configuraciones de contabilidad>Almacén.';tr = 'Emir durumu gereklidir. Ayarlar>Muhasebe ayarları>Depo kısmından mevcut durumları belirleyin.';it = 'Lo stato dell''ordine è richiesto. Specificare gli stati disponibile in Impostazioni->Impostazioni contabili->Magazzino.';de = 'Der Auftragsstatus ist erforderlich. Geben Sie die verfügbaren Status unter Einstellungen>Einstellungen für die Buchhaltung>Lager an.'");
			DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "OrderState", Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.TransferOrder.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectInventoryFlowCalendar(AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.ReflectTransferOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectReservedProducts(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.TransferOrder.RunControl(Ref, AdditionalProperties, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);

	// Control
	Documents.TransferOrder.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

#EndRegion

#Region Internal

// Procedure fills the Inventory tabular section by balances at warehouse.
//
Procedure FillInventoryByInventoryBalances() Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	InventoryInWarehousesOfBalance.Company AS Company,
	|	InventoryInWarehousesOfBalance.Products AS Products,
	|	InventoryInWarehousesOfBalance.Products.MeasurementUnit AS MeasurementUnit,
	|	InventoryInWarehousesOfBalance.Characteristic AS Characteristic,
	|	InventoryInWarehousesOfBalance.Batch AS Batch,
	|	InventoryInWarehousesOfBalance.StructuralUnit AS StructuralUnit,
	|	SUM(InventoryInWarehousesOfBalance.QuantityBalance) AS Quantity
	|FROM
	|	(SELECT
	|		InventoryInWarehouses.Company AS Company,
	|		InventoryInWarehouses.Products AS Products,
	|		InventoryInWarehouses.Characteristic AS Characteristic,
	|		InventoryInWarehouses.Batch AS Batch,
	|		InventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|		InventoryInWarehouses.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.InventoryInWarehouses.Balance(
	|				,
	|				Company = &Company
	|					AND StructuralUnit = &StructuralUnit) AS InventoryInWarehouses
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventoryInWarehouses.Company,
	|		DocumentRegisterRecordsInventoryInWarehouses.Products,
	|		DocumentRegisterRecordsInventoryInWarehouses.Characteristic,
	|		DocumentRegisterRecordsInventoryInWarehouses.Batch,
	|		DocumentRegisterRecordsInventoryInWarehouses.StructuralUnit,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventoryInWarehouses.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventoryInWarehouses.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventoryInWarehouses.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.InventoryInWarehouses AS DocumentRegisterRecordsInventoryInWarehouses
	|	WHERE
	|		DocumentRegisterRecordsInventoryInWarehouses.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventoryInWarehouses.Period <= &Period
	|		AND DocumentRegisterRecordsInventoryInWarehouses.RecordType = VALUE(AccumulationRecordType.Expense)) AS InventoryInWarehousesOfBalance
	|WHERE
	|	InventoryInWarehousesOfBalance.QuantityBalance > 0
	|
	|GROUP BY
	|	InventoryInWarehousesOfBalance.Company,
	|	InventoryInWarehousesOfBalance.Products,
	|	InventoryInWarehousesOfBalance.Characteristic,
	|	InventoryInWarehousesOfBalance.Batch,
	|	InventoryInWarehousesOfBalance.StructuralUnit,
	|	InventoryInWarehousesOfBalance.Products.MeasurementUnit";
	
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnit);
	
	SalesOrder = Undefined;
	BasisDocument = Undefined;
	Inventory.Load(Query.Execute().Unload());
	
EndProcedure

// Procedure fills out the Quantity column according to reserves to be ordered.
//
Procedure FillColumnReserveByBalances() Export
	
	Inventory.LoadColumn(New Array(Inventory.Count()), "Reserve");
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory";
	
	Query.SetParameter("TableInventory", Inventory.Unload());
	Query.Execute();
	
	Query.Text =
	"SELECT ALLOWED
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				(Company, StructuralUnit, Products, Characteristic, Batch, Ownership) IN
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						&OwnInventory
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		ReservedProductsBalances.Company,
	|		ReservedProductsBalances.StructuralUnit,
	|		ReservedProductsBalances.Products,
	|		ReservedProductsBalances.Characteristic,
	|		ReservedProductsBalances.Batch,
	|		-ReservedProductsBalances.QuantityBalance
	|	FROM
	|		AccumulationRegister.ReservedProducts.Balance(
	|				,
	|				(Company, StructuralUnit, Products, Characteristic, Batch) IN
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS ReservedProductsBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsReservedProducts.Company,
	|		DocumentRegisterRecordsReservedProducts.StructuralUnit,
	|		DocumentRegisterRecordsReservedProducts.Products,
	|		DocumentRegisterRecordsReservedProducts.Characteristic,
	|		DocumentRegisterRecordsReservedProducts.Batch,
	|		DocumentRegisterRecordsReservedProducts.Quantity
	|	FROM
	|		AccumulationRegister.ReservedProducts AS DocumentRegisterRecordsReservedProducts
	|	WHERE
	|		DocumentRegisterRecordsReservedProducts.Recorder = &Ref
	|		AND DocumentRegisterRecordsReservedProducts.Period <= &Period) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnit);
	Query.SetParameter("OwnInventory", Catalogs.InventoryOwnership.OwnInventory());
	
	TableOfPeriods = New ValueTable();
	TableOfPeriods.Columns.Add("ShipmentDate");
	TableOfPeriods.Columns.Add("StringInventory");
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		ArrayOfRowsInventory = Inventory.FindRows(StructureForSearch);
		For Each StringInventory In ArrayOfRowsInventory Do
			NewRow = TableOfPeriods.Add();
			NewRow.ShipmentDate = StringInventory.ShipmentDate;
			NewRow.StringInventory = StringInventory;
		EndDo;
		
		TotalBalance = Selection.QuantityBalance;
		TableOfPeriods.Sort("ShipmentDate");
		For Each TableOfPeriodsRow In TableOfPeriods Do
			StringInventory = TableOfPeriodsRow.StringInventory;
			TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance / StringInventory.MeasurementUnit.Factor);
			If StringInventory.Quantity >= TotalBalance Then
				StringInventory.Reserve = TotalBalance;
				TotalBalance = 0;
			Else
				StringInventory.Reserve = StringInventory.Quantity;
				TotalBalance = TotalBalance - StringInventory.Quantity;
				TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance * StringInventory.MeasurementUnit.Factor);
			EndIf;
		EndDo;
		
		TableOfPeriods.Clear();
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

Procedure FillOnCopy()
	
	SetTransferOrderState();
	
	Closed = False;
	
EndProcedure

Procedure FillByDefault()
	
	SetTransferOrderState();
	
EndProcedure

Procedure SetTransferOrderState()
	
	If Constants.UseTransferOrderStatuses.Get() Then
		SettingValue = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "StatusOfNewTransferOrder");
		If ValueIsFilled(SettingValue) Then
			If OrderState <> SettingValue Then
				OrderState = SettingValue;
			EndIf;
		Else
			OrderState = Catalogs.TransferOrderStatuses.Open;
		EndIf;
	Else
		OrderState = Constants.TransferOrdersInProgressStatus.Get();
	EndIf;
	
EndProcedure

// begin Drive.FullVersion

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Document ManufacturingOperation - Data on filling the document.
//
Procedure FillByWIP(FillingData)
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	|	ManufacturingOperation.Company AS Company,
	|	ManufacturingOperation.InventoryStructuralUnit AS StructuralUnitPayee,
	|	ManufacturingOperation.Ref AS BasisDocument,
	|	ManufacturingOperation.Posted AS BasisPosted
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|WHERE
	|	ManufacturingOperation.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ManufacturingOperationInventory.Products AS Products,
	|	ManufacturingOperationInventory.Characteristic AS Characteristic,
	|	ManufacturingOperationInventory.Batch AS Batch,
	|	ManufacturingOperationInventory.Quantity AS Quantity,
	|	ManufacturingOperationInventory.MeasurementUnit AS MeasurementUnit
	|FROM
	|	Document.ManufacturingOperation.Inventory AS ManufacturingOperationInventory
	|		INNER JOIN Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
	|		ON ManufacturingOperationInventory.Ref = ManufacturingOperationActivities.Ref
	|			AND ManufacturingOperationInventory.ActivityConnectionKey = ManufacturingOperationActivities.ConnectionKey
	|			AND (ManufacturingOperationActivities.StartDate = DATETIME(1, 1, 1))
	|WHERE
	|	ManufacturingOperationInventory.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	QueryResult = Query.ExecuteBatch();
	If Not QueryResult[0].IsEmpty() Then
		
		QueryResultSelection = QueryResult[0].Select();
		QueryResultSelection.Next();
		
		VerifiedAttributesValues = New Structure;
		VerifiedAttributesValues.Insert("Posted", QueryResultSelection.BasisPosted);
		Documents.ManufacturingOperation.CheckAbilityOfEnteringByWorkInProgress(FillingData, VerifiedAttributesValues);
		
		FillPropertyValues(ThisObject, QueryResultSelection);
		
	EndIf;
	
	Inventory.Clear();
	If FillingData.Inventory.Count() = 0 Then
		
		MessageToUser = NStr("en = 'Cannot perform the action. The Work-in-progress does not include any components.'; ru = 'Не удалось выполнить действие. Документ ""Незавершенное производство"" не содержит компоненты.';pl = 'Nie można wykonać działania. Praca w toku nie zawiera żadnych komponentów.';es_ES = 'No se puede realizar la acción. El trabajo en progreso no incluye ningún componente.';es_CO = 'No se puede realizar la acción. El trabajo en progreso no incluye ningún componente.';tr = 'İşlem gerçekleştirilemiyor. İşlem bitişi hiç malzeme içermiyor.';it = 'Impossibile eseguire l''azione. Il Lavoro in corso non include alcuna componente.';de = 'Fehler beim Erfüllen der Aktion. Die Arbeit in Bearbeitung enthält keine Komponenten.'");
		Raise MessageToUser;
		
	ElsIf Not QueryResult[1].IsEmpty() Then
		
		QueryResultSelection = QueryResult[1].Select();
		While QueryResultSelection.Next() Do
			NewLine = Inventory.Add();
			FillPropertyValues(NewLine, QueryResultSelection);
		EndDo;
		
	Else
		
		MessageToUser = NStr("en = 'Cannot perform the action. In the Work-in-progress, all operations have start dates. 
			|This means that all components are consumed in these operations. Such components are not available for other orders or transfers.'; 
			|ru = 'Не удалось выполнить действие. В документе ""Незавершенное производство"" все операции имеют даты начала. 
			|Это означает, что в этих операциях используются все компоненты. Такие компоненты недоступны для других заказов и перемещений.';
			|pl = 'Nie można wykonać działania. W Pracy w toku, wszystkie operacje mają daty początkowe. 
			|Znaczy to, że wszystkie komponenty są spożywane w tych operacjach. Takie komponenty nie są dostępne dla innych zamówień lub przeniesień.';
			|es_ES = 'No se puede realizar la acción. En el trabajo en progreso, todas las operaciones tienen fecha de inicio. 
			|Esto significa que todos los componentes se consumen en estas operaciones. Estos componentes no están disponibles para otras órdenes o transferencias.';
			|es_CO = 'No se puede realizar la acción. En el trabajo en progreso, todas las operaciones tienen fecha de inicio. 
			|Esto significa que todos los componentes se consumen en estas operaciones. Estos componentes no están disponibles para otras órdenes o transferencias.';
			|tr = 'İşlem gerçekleştirilemiyor. İşlem bitişindeki tüm malzemelerin başlangıç tarihi bulunuyor. 
			|Başka bir deyişle, tüm malzemeler bu işlemlerde kullanılıyor. Bu malzemeler diğer siparişler veya transferler için kullanılamaz.';
			|it = 'Impossibile eseguire l''azione. Nel Lavoro in corso tutte le operazioni hanno data di inizio. 
			|Ciò significa che tutte le componenti sono utilizzate in tali operazioni. Tali componenti non sono disponibili per altri ordini o trasferimenti.';
			|de = 'Fehler beim Erfüllen der Aktion. In der Arbeit in Bearbeitung haben alle Operationen Startdaten. 
			|Dies bedeutet dass alle Komponenten in diesen Operationen verbraucht werden. Diese Komponenten sind für andere Aufträge oder Transfer nicht verfügbar.'");
		Raise MessageToUser;
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Document ProductionOrder - Data on filling the document.
//
Procedure FillByProductionOrderProduction(FillingData)
	
	Query = New Query(
	"SELECT ALLOWED
	|	ProductionOrder.Ref AS BasisDocument,
	|	ProductionOrder.Company AS Company,
	|	ProductionOrder.Posted AS BasisPosted,
	|	ProductionOrder.Closed AS Closed,
	|	ProductionOrder.OrderState AS OrderState
	|INTO TT_ProdOrder
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|WHERE
	|	ProductionOrder.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProdOrder.BasisDocument AS BasisDocument,
	|	TT_ProdOrder.Company AS Company,
	|	TT_ProdOrder.BasisPosted AS BasisPosted,
	|	TT_ProdOrder.Closed AS Closed,
	|	TT_ProdOrder.OrderState AS OrderState
	|FROM
	|	TT_ProdOrder AS TT_ProdOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ManufacturingOperation.InventoryStructuralUnit AS StructuralUnitPayee
	|FROM
	|	TT_ProdOrder AS TT_ProdOrder
	|		INNER JOIN Document.ManufacturingOperation AS ManufacturingOperation
	|		ON TT_ProdOrder.BasisDocument = ManufacturingOperation.BasisDocument
	|			AND (ManufacturingOperation.Posted)
	|
	|GROUP BY
	|	ManufacturingOperation.InventoryStructuralUnit
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ManufacturingOperationInventory.Products AS Products,
	|	ManufacturingOperationInventory.Characteristic AS Characteristic,
	|	ManufacturingOperationInventory.Batch AS Batch,
	|	ManufacturingOperationInventory.Quantity AS Quantity,
	|	ManufacturingOperationInventory.MeasurementUnit AS MeasurementUnit
	|FROM
	|	TT_ProdOrder AS TT_ProdOrder
	|		INNER JOIN Document.ManufacturingOperation AS ManufacturingOperation
	|		ON TT_ProdOrder.BasisDocument = ManufacturingOperation.BasisDocument
	|			AND (ManufacturingOperation.Posted)
	|		INNER JOIN Document.ManufacturingOperation.Inventory AS ManufacturingOperationInventory
	|		ON (ManufacturingOperation.Ref = ManufacturingOperationInventory.Ref)
	|		INNER JOIN Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
	|		ON (ManufacturingOperationInventory.Ref = ManufacturingOperationActivities.Ref)
	|			AND (ManufacturingOperationInventory.ActivityConnectionKey = ManufacturingOperationActivities.ConnectionKey)
	|			AND (ManufacturingOperationActivities.StartDate = DATETIME(1, 1, 1))");
	
	Query.SetParameter("BasisDocument", FillingData);
	
	QueryResult = Query.ExecuteBatch();
	If Not QueryResult[1].IsEmpty() Then
		
		QueryResultSelection = QueryResult[1].Select();
		QueryResultSelection.Next();
		
		VerifiedAttributesValues = New Structure;
		VerifiedAttributesValues.Insert("OrderState", 	QueryResultSelection.OrderState);
		VerifiedAttributesValues.Insert("Closed", 		QueryResultSelection.Closed);
		VerifiedAttributesValues.Insert("Posted", 		QueryResultSelection.BasisPosted);
		Documents.ProductionOrder.VerifyEnteringAbilityByProductionOrder(QueryResultSelection.BasisDocument, VerifiedAttributesValues);
		
		FillPropertyValues(ThisObject, QueryResultSelection);
		
	EndIf;
	
	If Not QueryResult[2].IsEmpty() Then
		
		QueryResultSelection = QueryResult[2].Select();
		If QueryResultSelection.Count() = 1 Then
			QueryResultSelection.Next();		
			FillPropertyValues(ThisObject, QueryResultSelection);
		EndIf;
		
	Else
		
		MessageToUser = NStr("en = 'Cannot perform the action. The Production order does not have a linked Work-in-progress yet. 
			|This means there are no components available for transfer yet. From the Production order, generate Work-in-progress and specify components. Then try again.'; 
			|ru = 'Не удалось выполнить действие. Заказ на производство еще не связан с документом ""Незавершенное производство"". 
			|Это означает, что пока нет доступных для перемещения компонентов. На основании заказа на производство создайте ""Незавершенное производство"" и укажите компоненты. Затем повторите попытку.';
			|pl = 'Nie można wykonać działania. Zlecenie produkcyjne nie ma jeszcze powiązanych prac w toku. 
			|Znaczy to, że nie ma jeszcze komponentów dostępnych do przeniesienia. Ze Zlecenia produkcyjnego, wygeneruj Pracę w toku i wybierz komponenty. Następnie spróbuj ponownie.';
			|es_ES = 'No se puede realizar la acción. La orden de producción aún no tiene un enlace de Trabajo en progreso. 
			|Esto significa que todavía no hay componentes disponibles para la transferencia. Desde la orden de producción, genere un Trabajo en progreso y especifique los componentes. A continuación, inténtelo de nuevo.';
			|es_CO = 'No se puede realizar la acción. La orden de producción aún no tiene un enlace de Trabajo en progreso. 
			|Esto significa que todavía no hay componentes disponibles para la transferencia. Desde la orden de producción, genere un Trabajo en progreso y especifique los componentes. A continuación, inténtelo de nuevo.';
			|tr = 'İşlem gerçekleştirilemiyor. Üretim emri için henüz bağlantılı bir İşlem bitişi yok. 
			|Başka bir deyişle, henüz transfer için kullanılabilecek malzeme yok. Üretim emrinden İşlem bitişi oluşturun, malzeme belirtin ve tekrar deneyin.';
			|it = 'Impossibile eseguire l''azione. L''Ordine di produzione non ha ancora un Lavoro in corso collegato. 
			|Ciò significa che non ci sono ancora componenti disponibili per il trasferimento. Dall''Ordine di produzione generare il Lavoro in corso e specificare le componenti, poi riprovare.';
			|de = 'Fehler beim Erfüllen der Aktion. Der Produktionsauftrag hat noch keine verbundene Arbeit in Bearbeitung. 
			|Dies bedeutet dass es noch keine für Transfer verfügbaren Komponenten gibt. Generieren Sie eine Arbeit in Bearbeitung aus dem Produktionsauftrag und geben die Komponenten ein. Dann versuchen Sie erneut.'");
		Raise MessageToUser;
		
	EndIf;
	
	Inventory.Clear();
	If Not QueryResult[3].IsEmpty() Then
		
		QueryResultSelection = QueryResult[3].Select();
		While QueryResultSelection.Next() Do
			NewLine = Inventory.Add();
			FillPropertyValues(NewLine, QueryResultSelection);
		EndDo;
		
	Else
		
		MessageToUser = NStr("en = 'Cannot perform the action. In the Work-in-progress, all operations have start dates. 
			|This means that all components are consumed in these operations. Such components are not available for other orders or transfers.'; 
			|ru = 'Не удалось выполнить действие. В документе ""Незавершенное производство"" все операции имеют даты начала. 
			|Это означает, что в этих операциях используются все компоненты. Такие компоненты недоступны для других заказов и перемещений.';
			|pl = 'Nie można wykonać działania. W Pracy w toku, wszystkie operacje mają daty początkowe. 
			|Znaczy to, że wszystkie komponenty są spożywane w tych operacjach. Takie komponenty nie są dostępne dla innych zamówień lub przeniesień.';
			|es_ES = 'No se puede realizar la acción. En el trabajo en progreso, todas las operaciones tienen fecha de inicio. 
			|Esto significa que todos los componentes se consumen en estas operaciones. Estos componentes no están disponibles para otras órdenes o transferencias.';
			|es_CO = 'No se puede realizar la acción. En el trabajo en progreso, todas las operaciones tienen fecha de inicio. 
			|Esto significa que todos los componentes se consumen en estas operaciones. Estos componentes no están disponibles para otras órdenes o transferencias.';
			|tr = 'İşlem gerçekleştirilemiyor. İşlem bitişindeki tüm malzemelerin başlangıç tarihi bulunuyor. 
			|Başka bir deyişle, tüm malzemeler bu işlemlerde kullanılıyor. Bu malzemeler diğer siparişler veya transferler için kullanılamaz.';
			|it = 'Impossibile eseguire l''azione. Nel Lavoro in corso tutte le operazioni hanno data di inizio. 
			|Ciò significa che tutte le componenti sono utilizzate in tali operazioni. Tali componenti non sono disponibili per altri ordini o trasferimenti.';
			|de = 'Fehler beim Erfüllen der Aktion. In der Arbeit in Bearbeitung haben alle Operationen Startdaten. 
			|Dies bedeutet dass alle Komponenten in diesen Operationen verbraucht werden. Diese Komponenten sind für andere Aufträge oder Transfer nicht verfügbar.'");
		Raise MessageToUser;
		
	EndIf;
	
EndProcedure
// end Drive.FullVersion

#EndRegion
	
#EndIf
