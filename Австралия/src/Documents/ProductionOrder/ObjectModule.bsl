#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Procedure fills tabular section according to specification.
//
Procedure FillTabularSectionBySpecification() Export
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProduction.LineNumber AS LineNumber,
	|	TableProduction.Quantity AS Quantity,
	|	TableProduction.Factor AS Factor,
	|	TableProduction.Specification AS Specification
	|INTO TemporaryTableProduction
	|FROM
	|	&TableProduction AS TableProduction
	|WHERE
	|	TableProduction.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)";
	
	Inventory.Clear();
	TableProduction = Products.Unload();
	Array = New Array();
	Array.Add(Type("Number"));
	TypeDescriptionC = New TypeDescription(Array, , ,New NumberQualifiers(10,3));
	TableProduction.Columns.Add("Factor", TypeDescriptionC);
	For Each StringProducts In TableProduction Do
		If ValueIsFilled(StringProducts.MeasurementUnit)
			AND TypeOf(StringProducts.MeasurementUnit) = Type("CatalogRef.UOM") Then
			StringProducts.Factor = Common.ObjectAttributeValue(StringProducts.MeasurementUnit, "Factor");
		Else
			StringProducts.Factor = 1;
		EndIf;
	EndDo;
	Query.SetParameter("TableProduction", TableProduction);
	
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	MIN(TableProduction.LineNumber) AS ProductionLineNumber,
	|	TableProduction.Specification AS ProductionSpecification,
	|	MIN(TableMaterials.LineNumber) AS StructureLineNumber,
	|	TableMaterials.ContentRowType AS ContentRowType,
	|	TableMaterials.Products AS Products,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(TableMaterials.Quantity / TableMaterials.Ref.Quantity * CASE
	|			WHEN TableMaterials.CalculationMethod = VALUE(Enum.BOMContentCalculationMethod.Proportional)
	|				THEN TableProduction.Factor * TableProduction.Quantity
	|			ELSE CASE
	|					WHEN (CAST(TableProduction.Factor * TableProduction.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) = TableProduction.Factor * TableProduction.Quantity / TableMaterials.Ref.Quantity
	|						THEN TableProduction.Factor * TableProduction.Quantity
	|					WHEN (CAST(TableProduction.Factor * TableProduction.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) > TableProduction.Factor * TableProduction.Quantity / TableMaterials.Ref.Quantity
	|						THEN (CAST(TableProduction.Factor * TableProduction.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) * TableMaterials.Ref.Quantity
	|					ELSE ((CAST(TableProduction.Factor * TableProduction.Quantity / TableMaterials.Ref.Quantity AS NUMBER(10, 0))) + 1) * TableMaterials.Ref.Quantity
	|				END
	|		END) AS Quantity,
	|	TableMaterials.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN TableMaterials.ContentRowType = VALUE(Enum.BOMLineType.Node)
	|				AND VALUETYPE(TableMaterials.MeasurementUnit) = TYPE(Catalog.UOM)
	|				AND TableMaterials.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
	|			THEN TableMaterials.MeasurementUnit.Factor
	|		ELSE 1
	|	END AS Factor,
	|	TableMaterials.Specification AS Specification
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON TableProduction.Specification = TableMaterials.Ref,
	|	Constant.UseCharacteristics AS UseCharacteristics
	|WHERE
	|	TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	TableProduction.Specification,
	|	TableMaterials.ContentRowType,
	|	TableMaterials.Products,
	|	TableMaterials.MeasurementUnit,
	|	CASE
	|		WHEN TableMaterials.ContentRowType = VALUE(Enum.BOMLineType.Node)
	|				AND VALUETYPE(TableMaterials.MeasurementUnit) = TYPE(Catalog.UOM)
	|				AND TableMaterials.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
	|			THEN TableMaterials.MeasurementUnit.Factor
	|		ELSE 1
	|	END,
	|	TableMaterials.Specification,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END
	|
	|ORDER BY
	|	ProductionLineNumber,
	|	StructureLineNumber";
	
	SelectionResult = Query.Execute();
	Inventory.Load(SelectionResult.Unload());
	Inventory.GroupBy("Products, Characteristic, MeasurementUnit, Specification", "Quantity");
	
EndProcedure

// Procedure for filling the document basing on Production order.
//
Procedure FillByProductionOrder(FillingData) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	ProductionOrder.Start AS Start,
	|	ProductionOrder.Start AS Finish,
	|	ProductionOrder.OperationKind AS OperationKind,
	|	ProductionOrder.Ref AS BasisDocument,
	|	ProductionOrder.Company AS Company,
	|	ProductionOrder.StructuralUnit AS StructuralUnit,
	|	ProductionOrder.SalesOrderPosition AS SalesOrderPosition,
	|	ProductionOrder.Inventory.(
	|		Products AS Products,
	|		Characteristic AS Characteristic,
	|		MeasurementUnit AS MeasurementUnit,
	|		Quantity AS Quantity,
	|		Specification AS Specification,
	|		Products.ProductsType AS ProductsType,
	|		Products.ReplenishmentMethod AS ReplenishmentMethod,
	|		SalesOrder AS SalesOrder
	|	)
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|WHERE
	|	ProductionOrder.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Products.Clear();
	Inventory.Clear();
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		QueryResultSelection = QueryResult.Select();
		QueryResultSelection.Next();
		FillPropertyValues(ThisObject, QueryResultSelection);
		
		For Each StringInventory In QueryResultSelection.Inventory.Unload() Do
			If Not ValueIsFilled(StringInventory.Products) Then
				Continue;
			EndIf;
			If StringInventory.Quantity <=0 Then
				Continue;
			EndIf;
			If Not ValueIsFilled(StringInventory.Specification) 
				AND StringInventory.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase Then
				Continue;
			EndIf; 
			NewRow = Products.Add();
			FillPropertyValues(NewRow, StringInventory);
		EndDo;
		
		If Products.Count() > 0 Then
			FillTabularSectionBySpecification();
		EndIf;
		
	EndIf;
	
	If OperationKind = Enums.OperationTypesProductionOrder.Disassembly Then
		TabularSectionName = "Inventory";
	Else
		TabularSectionName = "Products";
	EndIf;
	
	OrdersTable = ThisObject[TabularSectionName].Unload(, "SalesOrder");
	OrdersTable.GroupBy("SalesOrder");
	
	If OrdersTable.Count() > 1 Then
		SalesOrderPosition = Enums.AttributeStationing.InTabularSection;
	Else
		SalesOrderPosition = DriveReUse.GetValueOfSetting("SalesOrderPositionInShipmentDocuments");
		If Not ValueIsFilled(SalesOrderPosition) Then
			SalesOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
	EndIf;
	
	If SalesOrderPosition = Enums.AttributeStationing.InTabularSection Then
		SalesOrder = Undefined;
		BasisDocument = Undefined;
	ElsIf OrdersTable.Count() > 0 Then
		
		If Not ValueIsFilled(SalesOrder) Then
			SalesOrder = OrdersTable[0].SalesOrder;
		EndIf;
		
		If Not ValueIsFilled(BasisDocument) Then
			BasisDocument = SalesOrder;
		EndIf;
		
	EndIf;
	
	If Products.Count() > 0 And OperationKind = Enums.OperationTypesProductionOrder.Assembly Then
		FillTabularSectionBySpecification();
	EndIf;
	
EndProcedure

// Procedure for filling the document basing on Sales order.
//
Procedure FillUsingSalesOrder(FillingData, ReplenishmentMethod = Undefined) Export
	
	If Not ValueIsFilled(OperationKind) Then
		If ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production Then
			OperationKind = Enums.OperationTypesProductionOrder.Production;
		ElsIf ReplenishmentMethod = Undefined Then
			OperationKind = Enums.OperationTypesProductionOrder.Production;
		Else
			OperationKind = Enums.OperationTypesProductionOrder.Assembly;
		EndIf;
	EndIf;
	
	If ReplenishmentMethod = Undefined Then
		If OperationKind = Enums.OperationTypesProductionOrder.Production Then
			ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production;
		Else
			ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Assembly;
		EndIf;
	EndIf;
	
	If OperationKind = Enums.OperationTypesProductionOrder.Disassembly Then
		TabularSectionName = "Inventory";
	Else
		TabularSectionName = "Products";
	EndIf;
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SalesOrder.Ref AS BasisRef,
	|	SalesOrder.Posted AS BasisPosted,
	|	SalesOrder.Closed AS BasisClosed,
	|	SalesOrder.OrderState AS OrderState,
	|	SalesOrder.OperationKind AS BasisOperationKind,
	|	SalesOrder.Company AS Company,
	|	CASE
	|		WHEN SalesOrder.SalesStructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			THEN SalesOrder.SalesStructuralUnit
	|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
	|	END AS StructuralUnit,
	|	BEGINOFPERIOD(SalesOrder.ShipmentDate, DAY) AS Start,
	|	ENDOFPERIOD(SalesOrder.ShipmentDate, DAY) AS Finish
	|INTO TTHeader
	|FROM
	|	Document.SalesOrder AS SalesOrder,
	|	Constant.UseInventoryReservation AS UseInventoryReservation
	|WHERE
	|	SalesOrder.Ref IN(&BasisDocument)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TTHeader.BasisRef AS BasisRef,
	|	TTHeader.BasisPosted AS BasisPosted,
	|	TTHeader.BasisClosed AS BasisClosed,
	|	TTHeader.OrderState AS OrderState,
	|	TTHeader.BasisOperationKind AS BasisOperationKind,
	|	TTHeader.Company AS Company,
	|	TTHeader.StructuralUnit AS StructuralUnit
	|FROM
	|	TTHeader AS TTHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TTHeader.Start) AS Start
	|FROM
	|	TTHeader AS TTHeader";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	ResultArray = Query.ExecuteBatch();
	Selection = ResultArray[1].Select();
	
	While Selection.Next() Do
		VerifiedAttributesValues = New Structure("OperationKind, OrderState, Closed, Posted", Selection.BasisOperationKind, Selection.OrderState, Selection.BasisClosed, Selection.BasisPosted);
		Documents.SalesOrder.CheckAbilityOfEnteringBySalesOrder(Selection.BasisRef, VerifiedAttributesValues);
		
		FillPropertyValues(ThisObject, Selection);
	EndDo;
	
	If Not ValueIsFilled(StructuralUnit) Then
		SettingValue = DriveReUse.GetValueOfSetting("MainDepartment");
		If Not ValueIsFilled(SettingValue) And Catalogs.BusinessUnits.DepartmentReadingAllowed(Catalogs.BusinessUnits.MainDepartment) Then
			StructuralUnit = Catalogs.BusinessUnits.MainDepartment;
		EndIf;
	EndIf;
	
	BasisOperationKind = Selection.BasisOperationKind;
	
	Selection = ResultArray[2].Select();
	
	If Selection.Next() Then
		Start	= Selection.Start;
		Finish	= Selection.Start;
	EndIf;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text = Documents.ProductionOrder.QueryTextFillBySalesOrder()
		+ DriveClientServer.GetQueryDelimeter()
		+ "SELECT ALLOWED
		|	MIN(SalesOrderInventory.LineNumber) AS LineNumber,
		|	SalesOrderInventory.Products AS Products,
		|	SalesOrderInventory.Characteristic AS Characteristic,
		|	CASE
		|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
		|			THEN 1
		|		ELSE SalesOrderInventory.MeasurementUnit.Factor
		|	END AS Factor,
		|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
		|	SalesOrderInventory.Specification AS Specification,
		|	ProductsCatalog.ProductsType AS ProductsType,
		|	ProductsCatalog.ReplenishmentMethod AS ReplenishmentMethod,
		|	SUM(SalesOrderInventory.Quantity) AS Quantity,
		|	SalesOrderInventory.Ref AS SalesOrder
		|FROM
		|	Document.SalesOrder.Inventory AS SalesOrderInventory
		|		LEFT JOIN Catalog.BillsOfMaterials AS BillsOfMaterials
		|		ON SalesOrderInventory.Specification = BillsOfMaterials.Ref
		|		LEFT JOIN Catalog.Products AS ProductsCatalog
		|		ON SalesOrderInventory.Products = ProductsCatalog.Ref
		|WHERE
		|	SalesOrderInventory.Ref IN (&BasisDocument)
		|	AND (&OperationKind = VALUE(Enum.OperationTypesProductionOrder.Disassembly)
		|			OR BillsOfMaterials.Ref IS NULL
		|				AND ProductsCatalog.ReplenishmentMethod IN (&ArrayMethods)
		|			OR BillsOfMaterials.OperationKind = &OperationKind
		|				AND NOT ProductsCatalog.ReplenishmentMethod = &Subcontracting)
		|
		|GROUP BY
		|	SalesOrderInventory.Products,
		|	SalesOrderInventory.Characteristic,
		|	SalesOrderInventory.MeasurementUnit,
		|	CASE
		|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
		|			THEN 1
		|		ELSE SalesOrderInventory.MeasurementUnit.Factor
		|	END,
		|	SalesOrderInventory.Specification,
		|	ProductsCatalog.ProductsType,
		|	ProductsCatalog.ReplenishmentMethod,
		|	SalesOrderInventory.Ref
		|
		|ORDER BY
		|	LineNumber";
	
	Subcontracting = Enums.InventoryReplenishmentMethods.Processing;
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("OperationKind", OperationKind);

	ArrayMethods = New Array;
	ArrayMethods.Add(Subcontracting);
	ArrayMethods.Add(ReplenishmentMethod);
	
	Query.SetParameter("ArrayMethods", ArrayMethods);
	Query.SetParameter("Subcontracting", Subcontracting);

	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("SalesOrder, Products,Characteristic");
	
	Products.Clear();
	Inventory.Clear();
	If BalanceTable.Count() > 0 Then
		
		Selection = ResultsArray[1].Select();
		While Selection.Next() Do
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("SalesOrder",		Selection.SalesOrder);
			StructureForSearch.Insert("Products",		Selection.Products);
			StructureForSearch.Insert("Characteristic",	Selection.Characteristic);
			
			BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
			If BalanceRowsArray.Count() = 0 Then
				Continue;
			EndIf;
			
			NewRow = ThisObject[TabularSectionName].Add();
			FillPropertyValues(NewRow, Selection);
			
			QuantityToWriteOff = Selection.Quantity * Selection.Factor;
			BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityToWriteOff;
			If BalanceRowsArray[0].QuantityBalance < 0 Then
				
				NewRow.Quantity = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / Selection.Factor;
				
			EndIf;
			
			If BalanceRowsArray[0].QuantityBalance <= 0 Then
				BalanceTable.Delete(BalanceRowsArray[0]);
			EndIf;
			
		EndDo;
		
	EndIf;
	
	OrdersTable = ThisObject[TabularSectionName].Unload(, "SalesOrder");
	OrdersTable.GroupBy("SalesOrder");
	
	If OrdersTable.Count() > 1 Then
		SalesOrderPosition = Enums.AttributeStationing.InTabularSection;
	Else
		SalesOrderPosition = DriveReUse.GetValueOfSetting("SalesOrderPositionInShipmentDocuments");
		If Not ValueIsFilled(SalesOrderPosition) Then
			SalesOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
	EndIf;
	
	If SalesOrderPosition = Enums.AttributeStationing.InTabularSection Then
		SalesOrder = Undefined;
		BasisDocument = Undefined;
	ElsIf OrdersTable.Count() > 0 Then
		
		If Not ValueIsFilled(SalesOrder) Then
			SalesOrder = OrdersTable[0].SalesOrder;
		EndIf;
		
		If Not ValueIsFilled(BasisDocument) Then
			BasisDocument = SalesOrder;
		EndIf;
		
	EndIf;
	
	If Products.Count() > 0 And OperationKind = Enums.OperationTypesProductionOrder.Assembly Then
		FillTabularSectionBySpecification();
	EndIf;
	
EndProcedure

// Procedure for filling the document basing on Production order.
//
Procedure FillBySubcontractorOrderReceived(FillingData) Export
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SubcontractorOrderReceived.Ref AS BasisRef,
	|	SubcontractorOrderReceived.Posted AS BasisPosted,
	|	SubcontractorOrderReceived.Closed AS BasisClosed,
	|	SubcontractorOrderReceived.OrderState AS BasisState,
	|	CASE
	|		WHEN UseInventoryReservation.Value
	|			THEN SubcontractorOrderReceived.Ref
	|		ELSE VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	|	END AS SalesOrder,
	|	SubcontractorOrderReceived.Ref AS BasisDocument,
	|	SubcontractorOrderReceived.Company AS Company,
	|	SubcontractorOrderReceived.StructuralUnit AS StructuralUnit,
	|	DATEADD(SubcontractorOrderReceived.DateRequired, DAY, -1) AS Start,
	|	SubcontractorOrderReceived.DateRequired AS Finish
	|FROM
	|	Document.SubcontractorOrderReceived AS SubcontractorOrderReceived,
	|	Constant.UseInventoryReservation AS UseInventoryReservation
	|WHERE
	|	SubcontractorOrderReceived.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		VerifiedAttributesValues = New Structure("OrderState, Closed, Posted", Selection.BasisState, Selection.BasisClosed, Selection.BasisPosted);
		Documents.SubcontractorOrderReceived.CheckEnterBasedOnSubcontractorOrder(VerifiedAttributesValues);
	EndIf;
	
	FillPropertyValues(ThisObject, Selection);
	
	SettingValue = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainDepartment");
	StructuralUnit = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
	OperationKind = Enums.OperationTypesProductionOrder.Production;
	
	// Filling out tabular sections.
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SubcontractorOrderReceived.Company AS Company,
	|	SubcontractorOrderReceived.Counterparty AS Counterparty,
	|	SubcontractorOrderReceived.Ref AS SubcontractorOrder,
	|	SubcontractorOrderReceivedProducts.Products AS Products,
	|	SubcontractorOrderReceivedProducts.Characteristic AS Characteristic,
	|	ProductionOrder.Ref AS ProductionOrder
	|INTO TT_Orders
	|FROM
	|	Document.SubcontractorOrderReceived AS SubcontractorOrderReceived
	|		INNER JOIN Document.SubcontractorOrderReceived.Products AS SubcontractorOrderReceivedProducts
	|		ON SubcontractorOrderReceived.Ref = SubcontractorOrderReceivedProducts.Ref
	|			AND (SubcontractorOrderReceived.Ref = &BasisDocument)
	|		LEFT JOIN Document.ProductionOrder AS ProductionOrder
	|		ON SubcontractorOrderReceived.Ref = ProductionOrder.SalesOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SubcontractorOrdersReceivedBalance.Products AS Products,
	|	SubcontractorOrdersReceivedBalance.Characteristic AS Characteristic,
	|	SubcontractorOrdersReceivedBalance.QuantityBalance AS Quantity
	|INTO TT_ProductsBalances
	|FROM
	|	AccumulationRegister.SubcontractorOrdersReceived.Balance(
	|			,
	|			(Company, Counterparty, SubcontractorOrder, Products, Characteristic) IN
	|				(SELECT DISTINCT
	|					TT_Orders.Company AS Company,
	|					TT_Orders.Counterparty AS Counterparty,
	|					TT_Orders.SubcontractorOrder AS SubcontractorOrder,
	|					TT_Orders.Products AS Products,
	|					TT_Orders.Characteristic AS Characteristic
	|				FROM
	|					TT_Orders AS TT_Orders)) AS SubcontractorOrdersReceivedBalance
	|
	|UNION ALL
	|
	|SELECT
	|	ProductionOrders.Products,
	|	ProductionOrders.Characteristic,
	|	-ProductionOrders.Quantity
	|FROM
	|	TT_Orders AS TT_Orders
	|		INNER JOIN AccumulationRegister.ProductionOrders AS ProductionOrders
	|		ON TT_Orders.Company = ProductionOrders.Company
	|			AND TT_Orders.ProductionOrder = ProductionOrders.ProductionOrder
	|			AND TT_Orders.Products = ProductionOrders.Products
	|			AND TT_Orders.Characteristic = ProductionOrders.Characteristic
	|			AND (ProductionOrders.RecordType = VALUE(AccumulationRecordType.Receipt))
	|			AND (ProductionOrders.ProductionOrder <> &Ref)
	|
	|UNION ALL
	|
	|SELECT
	|	ProductionOrders.Products,
	|	ProductionOrders.Characteristic,
	|	ProductionOrders.Quantity
	|FROM
	|	AccumulationRegister.ProductionOrders AS ProductionOrders
	|WHERE
	|	ProductionOrders.Recorder = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsBalances.Products AS Products,
	|	TT_ProductsBalances.Characteristic AS Characteristic,
	|	SUM(TT_ProductsBalances.Quantity) AS Quantity
	|INTO TT_ProductsBalancesGrouped
	|FROM
	|	TT_ProductsBalances AS TT_ProductsBalances
	|
	|GROUP BY
	|	TT_ProductsBalances.Products,
	|	TT_ProductsBalances.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsBalancesGrouped.Products AS Products,
	|	CatalogProducts.ProductsType AS ProductsType,
	|	TT_ProductsBalancesGrouped.Characteristic AS Characteristic,
	|	TT_ProductsBalancesGrouped.Quantity AS Quantity,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	MAX(SubcontractorOrderReceivedProducts.Specification) AS Specification
	|FROM
	|	Document.SubcontractorOrderReceived.Products AS SubcontractorOrderReceivedProducts
	|		INNER JOIN TT_ProductsBalancesGrouped AS TT_ProductsBalancesGrouped
	|		ON SubcontractorOrderReceivedProducts.Products = TT_ProductsBalancesGrouped.Products
	|			AND SubcontractorOrderReceivedProducts.Characteristic = TT_ProductsBalancesGrouped.Characteristic
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON SubcontractorOrderReceivedProducts.Products = CatalogProducts.Ref
	|WHERE
	|	TT_ProductsBalancesGrouped.Quantity <> 0
	|
	|GROUP BY
	|	TT_ProductsBalancesGrouped.Products,
	|	CatalogProducts.ProductsType,
	|	TT_ProductsBalancesGrouped.Characteristic,
	|	TT_ProductsBalancesGrouped.Quantity,
	|	CatalogProducts.MeasurementUnit";
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	
	Products.Load(Query.Execute().Unload());
	
EndProcedure

// Procedure for filling the document basing on Subcontractor order issued.
//
Procedure FillBySubcontractorOrderIssued(FillingData, ReplenishmentMethod) Export

	If Not ValueIsFilled(OperationKind) Then
		If ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production Then
			OperationKind = Enums.OperationTypesProductionOrder.Production;
		ElsIf ReplenishmentMethod = Undefined Then
			OperationKind = Enums.OperationTypesProductionOrder.Production;
		Else
			OperationKind = Enums.OperationTypesProductionOrder.Assembly;
		EndIf;
	EndIf;
	
	AttributeValues = Common.ObjectAttributesValues(FillingData, "Posted, OrderState");
	Documents.SubcontractorOrderIssued.CheckEnterBasedOnSubcontractorOrder(AttributeValues);
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text = Documents.ProductionOrder.QueryTextFillBySubcontractorOrderIssued();
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	
	ArrayMethods = New Array;
	ArrayMethods.Add(Enums.InventoryReplenishmentMethods.Processing);
	ArrayMethods.Add(ReplenishmentMethod);
	
	Query.SetParameter("ReplenishmentMethod", ArrayMethods);
	
	QueryResult = Query.ExecuteBatch();
	
	If QueryResult[6].IsEmpty() Then
		Raise NStr("en = 'Cannot generate a Production order. Orders have already been created for the quantity of components specified in this Subcontractor order issued.'; ru = 'Не удалось создать заказ на производство. Заказы на количество компонентов, указанное в выданном заказе на переработку, уже созданы.';pl = 'Nie można wygenerować Zlecenie produkcyjne. Zlecenia są już utworzone dla ilości komponentów, określonej w tym Wydanym zamówieniu wykonawcy.';es_ES = 'No se ha podido generar una Orden de producción. Ya se han creado órdenes para la cantidad de componentes especificados en esta Orden emitida del subcontratista.';es_CO = 'No se ha podido generar una Orden de producción. Ya se han creado órdenes para la cantidad de componentes especificados en esta Orden emitida del subcontratista.';tr = 'Üretim emri oluşturulamıyor. Bu Düzenlenen alt yüklenici siparişinde belirtilen malzeme miktarı için zaten emirler oluşturuldu.';it = 'Impossibile generare Ordine di produzione. Gli ordini sono già stati creati per la quantità di componenti indicata in questo Ordine di subfornitura emesso.';de = 'Fehler beim Generieren eines Produktionsauftrags. Aufträge sind bereits für die Menge von Komponenten, angegeben in diesem Subunternehmerauftrag ausgestellt, erstellt.'");
	EndIf;

	Selection = QueryResult[1].Select();
	Selection.Next();
	
	SettingValue = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainDepartment");
	
	FillPropertyValues(ThisObject, Selection);
	
	Products.Load(QueryResult[6].Unload());
	
	Inventory.Clear();
	
EndProcedure

// Reservation

Procedure FillColumnReserveByBalances() Export
	
	IsDisassembly = (OperationKind = Enums.OperationTypesProductionOrder.Disassembly);
	
	If IsDisassembly Then
		Products.LoadColumn(New Array(Products.Count()), "Reserve");
	Else
		Inventory.LoadColumn(New Array(Inventory.Count()), "Reserve");
	EndIf;
	
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
	|	&TableInventory AS TableInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
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
	|				(Company, StructuralUnit, Products, Characteristic, Batch) IN
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch
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
	|		AND DocumentRegisterRecordsReservedProducts.Period <= &Period
	|		AND (DocumentRegisterRecordsReservedProducts.Company, DocumentRegisterRecordsReservedProducts.StructuralUnit, DocumentRegisterRecordsReservedProducts.Products, DocumentRegisterRecordsReservedProducts.Characteristic, DocumentRegisterRecordsReservedProducts.Batch) IN
	|				(SELECT
	|					&Company,
	|					&StructuralUnit,
	|					TableInventory.Products,
	|					TableInventory.Characteristic,
	|					TableInventory.Batch
	|				FROM
	|					TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("TableInventory", ?(IsDisassembly, Products.Unload(), Inventory.Unload()));
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnitReserve);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		TotalBalance = Selection.QuantityBalance;
		
		If IsDisassembly Then
			ArrayOfRowsInventory = Products.FindRows(StructureForSearch);
		Else
			ArrayOfRowsInventory = Inventory.FindRows(StructureForSearch);
		EndIf;
		
		For Each StringInventory In ArrayOfRowsInventory Do
			
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
		
	EndDo;
	
EndProcedure

// End Reservation

#EndRegion

#Region EventHandlers

// Procedure - event handler of the OnCopy object.
//
Procedure OnCopy(CopiedObject)
	
	FillOnCopy();
	
EndProcedure

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	Priority = Catalogs.ProductionOrdersPriorities.DefaultPriority();
	
	If TypeOf(FillingData) = Type("Structure")
		And FillingData.Property("DemandPlanning") Then
		FillTabularSectionBySpecification();
	ElsIf TypeOf(FillingData) = Type("Structure")
		And FillingData.Property("SalesOrder") Then
		FillUsingSalesOrder(FillingData.SalesOrder, FillingData.ReplenishmentMethod);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ProductionOrder") Then
		FillByProductionOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SubcontractorOrderReceived") Then
		FillBySubcontractorOrderReceived(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SalesOrder") Then
		FillUsingSalesOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("Structure")
		And FillingData.Property("SubcontractorOrderIssued") Then 
		FillBySubcontractorOrderIssued(FillingData.SubcontractorOrderIssued,  FillingData.ReplenishmentMethod);
	EndIf;
	
	If GetFunctionalOption("UseProductionPlanning") Then
		UseProductionPlanning = (OperationKind = Enums.OperationTypesProductionOrder.Production);
	EndIf;
	
EndProcedure

// Procedure - BeforeWrite event handler.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Closed And OrderState = DriveReUse.GetOrderStatus("ProductionOrderStatuses", "Completed") Then 
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'You cannot make changes to a completed %1.'; ru = 'Нельзя вносить изменения в завершенный %1.';pl = 'Nie możesz wprowadzać zmian w zakończeniu %1.';es_ES = 'No se puede modificar %1 cerrada.';es_CO = 'No se puede modificar %1 cerrada.';tr = 'Tamamlanmış bir %1 üzerinde değişiklik yapılamaz.';it = 'Non potete fare modifiche a un %1 completato.';de = 'Sie können keine Änderungen an einem abgeschlossenen %1 vornehmen.'"), Ref);
		CommonClientServer.MessageToUser(MessageText,,,,Cancel);
		Return;
	EndIf;
	
	ProductsList = "";
	FOUseCharacteristics = Constants.UseCharacteristics.Get();
	For Each StringProducts In Products Do
		
		If Not ValueIsFilled(StringProducts.Products) Then
			Continue;
		EndIf;
		
		CharacteristicPresentation = "";
		If FOUseCharacteristics AND ValueIsFilled(StringProducts.Characteristic) Then
			CharacteristicPresentation = " (" + TrimAll(StringProducts.Characteristic) + ")";
		EndIf;
		
		If ValueIsFilled(ProductsList) Then
			ProductsList = ProductsList + Chars.LF;
		EndIf;
		ProductsList = ProductsList + TrimAll(StringProducts.Products) + CharacteristicPresentation + ", " + StringProducts.Quantity + " " + TrimAll(StringProducts.MeasurementUnit);
		
	EndDo;
	
	If SalesOrderPosition = Enums.AttributeStationing.InHeader Then
		FillSalesOrder();
	Else
		SalesOrder = Undefined;
	EndIf;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Catalogs.CostObjects.UpdateLinkedCostObjectsData(Ref);
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Inventory.Count() > 0 Then
		
		FilterStructure = New Structure("ProductsType", Enums.ProductsTypes.Service);
		ArrayOfStringsServices = Products.FindRows(FilterStructure);
		If Products.Count() = ArrayOfStringsServices.Count() Then
			
			MessageText = NStr("en = 'Demand for materials is not planned for services.
			                   |Services only are indicated in the tabular section ""Products"". It is necessary to clear the tabular section ""Materials"".'; 
			                   |ru = 'Планирование потребностей в материалах не выполняется для услуг.
			                   |В табличной части ""Продукция"" указаны только услуги. Необходимо очистить табличную часть ""Материалы"".';
			                   |pl = 'Planowanie zapotrzebowania na materiały nie jest przewidziane dla usług. 
			                   |W sekcji tabelarycznej ""Produkcja"" wskazano wyłącznie usługi. Należy oczyścić sekcję tabelaryczną ""Materiały"".';
			                   |es_ES = 'Demanda de los materiales no está programada para los servicios.
			                   |Servicios solo están indicados en la sección tabular ""Productos"". Es necesario vaciar la sección tabular ""Materiales"".';
			                   |es_CO = 'Demanda de los materiales no está programada para los servicios.
			                   |Servicios solo están indicados en la sección tabular ""Productos"". Es necesario vaciar la sección tabular ""Materiales"".';
			                   |tr = 'Malzemeler için talep hizmetler için planlanmamıştır. 
			                   | Hizmetler sadece ""Ürünler"" sekme bölümünde belirtilmiştir. ""Malzeme"" sekme bölümünü temizlemek için gereklidir.';
			                   |it = 'Il fabbisogno di materiali non è pianificato per i servizi.
			                   |I servizi sono solo indicati nella sezione tabellare ""Articoli"". E'' necessario cancellare la sezione tabellare ""Materiali"".';
			                   |de = 'Der Materialbedarf für Dienstleistungen ist nicht geplant.
			                   |In der tabellarischen Rubrik ""Produkte"" sind nur die Dienstleistungen aufgeführt. Es ist notwendig, den tabellarischen Abschnitt ""Materialien"" zu löschen.'");
			DriveServer.ShowMessageAboutError(ThisObject, MessageText,,,, Cancel);
			
		EndIf;
		
	EndIf;
	
	If Not Constants.UseProductionOrderStatuses.Get() Then
		
		If Not ValueIsFilled(OrderState) Then
			MessageText = NStr("en = '""Lifecycle status"" is required.'; ru = 'Требуется указать статус документа.';pl = 'Wymagany jest ""Status dokumentu"".';es_ES = 'Se requiere ""Estado de ciclo de vida"".';es_CO = 'Se requiere ""Estado de ciclo de vida"".';tr = '""Yaşam döngüsü durumu"" gerekli.';it = '""Stato del ciclo di vita"" richiesto.';de = '„Status von Lebenszyklus“ ist erforderlich.'");
			DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "OrderState", Cancel);
		EndIf;
		
	EndIf;
	
	If GetFunctionalOption("UseProductionPlanning") = False Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Priority");
	EndIf;
	
	If OperationKind = Enums.OperationTypesProductionOrder.Production Then
		
		CheckedAttributes.Add("Products.Specification");
		
		For Each ProductsLine In Products Do
			
			DifferentDepartmentsMessage = Catalogs.BillsOfMaterials.CheckBillsOfMaterialsOperationsTable(ProductsLine.Specification);
			
			If DifferentDepartmentsMessage <> "" Then
				
				DriveServer.ShowMessageAboutError(ThisObject, DifferentDepartmentsMessage,,,, Cancel);
				
			EndIf;
			
		EndDo;
		
	Else
		
		CheckedAttributes.Add("Inventory");
		
	EndIf;
	
	If GetFunctionalOption("UseInventoryReservation") Then
		
		AreReservationFields = False;
		
		For Each ProductsLine In Products Do
			If ProductsLine.Reserve > 0 Then
				AreReservationFields = True;
				Break;
			EndIf;
		EndDo;
		
		If Not AreReservationFields Then
			For Each InventoryLine In Inventory Do
				If InventoryLine.Reserve > 0 Then
					AreReservationFields = True;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		If AreReservationFields Then
			CheckedAttributes.Add("StructuralUnitReserve");
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - event handler FillingProcessor object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.ProductionOrder.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectInventoryFlowCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectProductionOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectBackorders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectProductRelease(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectManufacturingProcessSupply(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectReservedProducts(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectProductionComponents(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.ProductionOrder.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	ReflectProductionPlanningData(AdditionalProperties, Cancel);
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	Closed = False;
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.ProductionOrder.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	ReflectProductionPlanningData(AdditionalProperties, Cancel, True);
	
EndProcedure

#EndRegion

#Region Private

// Procedure fills document when copying.
//
Procedure FillOnCopy()
	
	If Constants.UseProductionOrderStatuses.Get() Then
		User = Users.CurrentUser();
		SettingValue = DriveReUse.GetValueByDefaultUser(User, "StatusOfNewProductionOrder");
		If ValueIsFilled(SettingValue) Then
			If OrderState <> SettingValue Then
				OrderState = SettingValue;
			EndIf;
		Else
			OrderState = Catalogs.ProductionOrderStatuses.Open;
		EndIf;
	Else
		OrderState = Constants.ProductionOrdersInProgressStatus.Get();
	EndIf;
	
	Closed = False;
	
EndProcedure

Procedure ReflectProductionPlanningData(AdditionalProperties, Cancel, UndoPosting = False)
	
	If GetFunctionalOption("UseProductionPlanning") Then
		
		If Not Cancel And UseProductionPlanning Then
			
			InformationRegisters.ProductionOrdersStates.ReflectOrdersStates(Ref);
			
			If UndoPosting Then
				
				InformationRegisters.ProductionOrdersStates.ClearOrdersStates(Ref);
				
				WIPs = Documents.ProductionOrder.OrderOpenWIPs(Ref);
				
				InformationRegisters.JobsForProductionScheduleCalculation.DeleteJobs(Ref);
				InformationRegisters.JobsForProductionScheduleCalculation.CheckWIPsQueue(WIPs);
				
			ElsIf AdditionalProperties.Property("NeedRecalculation") And AdditionalProperties.NeedRecalculation Then
				
				If OrderState = Catalogs.ProductionOrderStatuses.Open Or Closed Then
					
					WIPs = Documents.ProductionOrder.OrderOpenWIPs(Ref);
					
					InformationRegisters.JobsForProductionScheduleCalculation.DeleteJobs(Ref);
					InformationRegisters.JobsForProductionScheduleCalculation.CheckWIPsQueue(WIPs);
					
				Else
					
					InformationRegisters.JobsForProductionScheduleCalculation.AddAllOperationsOfOrder(Ref);
					
				EndIf;
				
			EndIf;
			
			PriorityHasChanged = False;
			ReflectProductionOrderPriority(PriorityHasChanged);
			If PriorityHasChanged Then
				InformationRegisters.JobsForProductionScheduleCalculation.AddAllOperationsOfOrder(Ref);
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure ReflectProductionOrderPriority(PriorityHasChanged)
	
	PriorityHasChanged = True;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ProductionOrdersPriorities.Priority AS Priority,
	|	ProductionOrdersPrioritiesCat.Order AS Order
	|FROM
	|	InformationRegister.ProductionOrdersPriorities AS ProductionOrdersPriorities,
	|	Catalog.ProductionOrdersPriorities AS ProductionOrdersPrioritiesCat
	|WHERE
	|	ProductionOrdersPriorities.ProductionOrder = &ProductionOrder
	|	AND ProductionOrdersPrioritiesCat.Ref = &Priority";
	
	Query.SetParameter("ProductionOrder", Ref);
	Query.SetParameter("Priority", Priority);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		PriorityHasChanged = (SelectionDetailRecords.Priority <> Priority);
	EndIf;
	
	If PriorityHasChanged Then
		
		NewRecord = InformationRegisters.ProductionOrdersPriorities.CreateRecordManager();
		NewRecord.Priority = Priority;
		NewRecord.PriorityOrder = Common.ObjectAttributeValue(Priority, "Order");
		NewRecord.ProductionOrder = Ref;
		NewRecord.Queue = InformationRegisters.ProductionOrdersPriorities.NewQueueNumber(Priority);
		NewRecord.Write(True);
		
	EndIf;
	
EndProcedure

Procedure FillSalesOrder()

	If OperationKind = Enums.OperationTypesProductionOrder.Disassembly Then
		TableName = "Inventory";
	Else
		TableName = "Products";
	EndIf;
	
	For Each TabularSectionRow In ThisObject[TableName] Do
		TabularSectionRow.SalesOrder = SalesOrder;
	EndDo;

EndProcedure

#EndRegion

#EndIf