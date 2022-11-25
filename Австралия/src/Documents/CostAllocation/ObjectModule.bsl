#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Procedure fills tabular section according to specification.
//
Procedure FillTabularSectionBySpecification(BySpecification, RequiredQuantity, UsedMeasurementUnit, OnRequest) Export
    
	Query = New Query(
	"SELECT
	|	MAX(BillsOfMaterialsContent.LineNumber) AS BillsOfMaterialsContentLineNumber,
	|	BillsOfMaterialsContent.Products AS Products,
	|	BillsOfMaterialsContent.ContentRowType AS ContentRowType,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN BillsOfMaterialsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	BillsOfMaterialsContent.MeasurementUnit AS MeasurementUnit,
	|	BillsOfMaterialsContent.Specification AS Specification,
	|	SUM(CASE
	|			WHEN VALUETYPE(&MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN BillsOfMaterialsContent.Quantity / BillsOfMaterialsContent.Ref.Quantity * &Quantity
	|			ELSE BillsOfMaterialsContent.Quantity / BillsOfMaterialsContent.Ref.Quantity * &Factor * &Quantity
	|		END) AS Quantity,
	|	&SalesOrder AS SalesOrder
	|FROM
	|	Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|WHERE
	|	BillsOfMaterialsContent.Ref = &Specification
	|	AND BillsOfMaterialsContent.Products.ProductsType = &ProductsType
	|
	|GROUP BY
	|	BillsOfMaterialsContent.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN BillsOfMaterialsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	BillsOfMaterialsContent.MeasurementUnit,
	|	BillsOfMaterialsContent.Specification,
	|	BillsOfMaterialsContent.ContentRowType,
	|	BillsOfMaterialsContent.CostPercentage
	|
	|ORDER BY
	|	BillsOfMaterialsContentLineNumber,
	|	Products,
	|	Characteristic,
	|	Specification");
	
	Query.SetParameter("UseCharacteristics",	Constants.UseCharacteristics.Get());
	Query.SetParameter("ProcessingDate",		EndOfDay(Date));
	Query.SetParameter("SalesOrder",			OnRequest);
	Query.SetParameter("Specification",			BySpecification);
	Query.SetParameter("Quantity",				RequiredQuantity);
	Query.SetParameter("MeasurementUnit",		UsedMeasurementUnit);
	
	If TypeOf(UsedMeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		Query.SetParameter("Factor", 1);
	Else
		Query.SetParameter("Factor", UsedMeasurementUnit.Factor);
	EndIf;
	
	Query.SetParameter("ProductsType", Enums.ProductsTypes.InventoryItem);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		If Selection.ContentRowType = Enums.BOMLineType.Node Then
			
			FillTabularSectionBySpecification(Selection.Specification, Selection.Quantity, Selection.MeasurementUnit, OnRequest);
			
		Else
			
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
			
		EndIf;
		
	EndDo;

EndProcedure

// Procedure allocates tabular section by specification.
//
Procedure DistributeTabularSectionBySpecification(OnLine, TemporaryTableDistribution, ProductionSpecification) Export
	
	Query = New Query(
	"SELECT
	|	MAX(BillsOfMaterialsContent.LineNumber) AS BillsOfMaterialsContentLineNumber,
	|	BillsOfMaterialsContent.ContentRowType AS ContentRowType,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN BillsOfMaterialsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	BillsOfMaterialsContent.MeasurementUnit AS MeasurementUnit,
	|	BillsOfMaterialsContent.Specification AS Specification,
	|	SUM(CASE
	|			WHEN VALUETYPE(&MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN BillsOfMaterialsContent.Quantity / BillsOfMaterialsContent.Ref.Quantity * &Quantity
	|			ELSE BillsOfMaterialsContent.Quantity / BillsOfMaterialsContent.Ref.Quantity * &Factor * &Quantity
	|		END) AS Quantity,
	|	&Products AS Products,
	|	&ProductCharacteristic AS ProductCharacteristic,
	|	&ProductionBatch AS ProductionBatch,
	|	&SalesOrder AS SalesOrder
	|FROM
	|	Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|WHERE
	|	BillsOfMaterialsContent.Ref = &Specification
	|	AND BillsOfMaterialsContent.Products.ProductsType = &ProductsType
	|
	|GROUP BY
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN BillsOfMaterialsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	BillsOfMaterialsContent.MeasurementUnit,
	|	BillsOfMaterialsContent.Specification,
	|	BillsOfMaterialsContent.ContentRowType,
	|	BillsOfMaterialsContent.CostPercentage
	|
	|ORDER BY
	|	BillsOfMaterialsContentLineNumber");
	
	Query.SetParameter("UseCharacteristics",		Constants.UseCharacteristics.Get());
	Query.SetParameter("ProcessingDate",			EndOfDay(Date));
	Query.SetParameter("Products",					OnLine.Products);
	Query.SetParameter("ProductCharacteristic",		OnLine.ProductCharacteristic);
	Query.SetParameter("ProductionBatch",			OnLine.ProductionBatch);
	Query.SetParameter("SalesOrder",				OnLine.SalesOrder);
	Query.SetParameter("Specification",				OnLine.Specification);
	Query.SetParameter("Quantity",					OnLine.Quantity);
	Query.SetParameter("MeasurementUnit",			OnLine.MeasurementUnit);
	
	If TypeOf(OnLine.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		Query.SetParameter("Factor", 1);
	Else
		Query.SetParameter("Factor", OnLine.MeasurementUnit.Factor);
	EndIf;
	
	Query.SetParameter("ProductsType", Enums.ProductsTypes.InventoryItem);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		If Selection.ContentRowType = Enums.BOMLineType.Node Then
			
			DistributeTabularSectionBySpecification(Selection, TemporaryTableDistribution, ProductionSpecification);
			
		Else
			
			NewRow = TemporaryTableDistribution.Add();
			FillPropertyValues(NewRow, Selection);
			NewRow.ProductionSpecification = ProductionSpecification;
			
		EndIf;
		
	EndDo;

EndProcedure

// Procedure fills inventory according to standards.
//
Procedure RunInventoryFillingByStandards() Export
	
	Inventory.Clear();
	InventoryDistribution.Clear();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CostAllocationProducts.Specification AS Specification,
	|	CostAllocationProducts.SalesOrder AS SalesOrder,
	|	CostAllocationProducts.LineNumber AS LineNumber,
	|	CostAllocationProducts.Quantity AS Quantity
	|INTO TemporaryTableProduction
	|FROM
	|	&CostAllocationProducts AS CostAllocationProducts
	|WHERE
	|	CostAllocationProducts.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BillsOfMaterialsContent.LineNumber AS BillsOfMaterialsContentLineNumber,
	|	BillsOfMaterialsContent.ContentRowType AS ContentRowType,
	|	BillsOfMaterialsContent.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN BillsOfMaterialsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	BillsOfMaterialsContent.MeasurementUnit AS MeasurementUnit,
	|	BillsOfMaterialsContent.Specification AS Specification,
	|	TemporaryTableProduction.SalesOrder AS SalesOrder,
	|	SUM(BillsOfMaterialsContent.Quantity / BillsOfMaterialsContent.Ref.Quantity * TemporaryTableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TemporaryTableProduction
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		ON TemporaryTableProduction.Specification = BillsOfMaterialsContent.Ref
	|WHERE
	|	BillsOfMaterialsContent.Products.ProductsType = &ProductsType
	|
	|GROUP BY
	|	BillsOfMaterialsContent.Products,
	|	BillsOfMaterialsContent.Specification,
	|	BillsOfMaterialsContent.ContentRowType,
	|	TemporaryTableProduction.SalesOrder,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN BillsOfMaterialsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	BillsOfMaterialsContent.MeasurementUnit,
	|	BillsOfMaterialsContent.LineNumber,
	|	TemporaryTableProduction.LineNumber
	|
	|ORDER BY
	|	TemporaryTableProduction.LineNumber,
	|	BillsOfMaterialsContentLineNumber,
	|	Products,
	|	Characteristic,
	|	Specification,
	|	SalesOrder";
	
	UseCharacteristics = Constants.UseCharacteristics.Get(); 
	
	TemporaryTableProduction = Products.Unload();
	
	For Each StringTT In TemporaryTableProduction Do
		If TypeOf(StringTT.MeasurementUnit) = Type("CatalogRef.UOM") Then
			StringTT.Quantity = StringTT.Quantity * StringTT.MeasurementUnit.Factor;
		EndIf;	
	EndDo;	
	
	Query.SetParameter("CostAllocationProducts", TemporaryTableProduction);
	Query.SetParameter("UseCharacteristics", 	UseCharacteristics);
	
	Query.SetParameter("ProductsType", Enums.ProductsTypes.InventoryItem);
	
	TableInventory = Query.Execute().Unload();
	For Each VTRow In TableInventory Do
		
		If VTRow.ContentRowType = Enums.BOMLineType.Node Then
			
			FillTabularSectionBySpecification(VTRow.Specification, VTRow.Quantity, VTRow.MeasurementUnit, VTRow.SalesOrder);
									
		Else	
			
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, VTRow);
						
		EndIf;	
		
	EndDo;	
	
	Inventory.GroupBy("Products, Characteristic, MeasurementUnit, SalesOrder, Specification", "Quantity");
	
	ConnectionKey = 0;
	For Each TabularSectionRow In Inventory Do
		TabularSectionRow.ConnectionKey = ConnectionKey;
		ConnectionKey = ConnectionKey + 1;
	EndDo;	
	
EndProcedure

// Procedure fills inventory according to standards.
//
Procedure RunInventoryFillingByBalance() Export
	
	Inventory.Clear();
	InventoryDistribution.Clear();
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SUM(InventoryBalances.QuantityBalance) AS Quantity,
	|	ISNULL(InventoryBalances.Products, VALUE(Catalog.Products.EmptyRef)) AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.Products.MeasurementUnit AS MeasurementUnit,
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit
	|FROM
	|	AccumulationRegister.Inventory.Balance(&ProcessingDate, ) AS InventoryBalances
	|WHERE
	|	InventoryBalances.QuantityBalance > 0
	|	AND InventoryBalances.Products <> VALUE(Catalog.Products.EmptyRef)
	|	AND InventoryBalances.Company = &Company
	|	AND InventoryBalances.StructuralUnit = &StructuralUnit
	|
	|GROUP BY
	|	InventoryBalances.Batch,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Products.MeasurementUnit,
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit
	|
	|ORDER BY
	|	Products,
	|	Characteristic,
	|	Batch";
	
	Query.SetParameter("ProcessingDate", EndOfDay(Date));
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnit);
	
	ConnectionKey = 0;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, Selection);
		NewRow.ConnectionKey = ConnectionKey;
		
		ConnectionKey = ConnectionKey + 1;
		
	EndDo;	
	
EndProcedure

// Procedure allocates inventory according to quantity.
//
Procedure RunInventoryDistributionByStandards() Export
	
	InventoryDistribution.Clear();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CostAllocationProducts.Products AS Products,
	|	CostAllocationProducts.Characteristic AS ProductCharacteristic,
	|	CostAllocationProducts.Batch AS ProductionBatch,
	|	CostAllocationProducts.SalesOrder AS SalesOrder,
	|	CostAllocationProducts.Specification AS Specification,
	|	CostAllocationProducts.Quantity AS Quantity
	|INTO TemporaryTableProduction
	|FROM
	|	&CostAllocationProducts AS CostAllocationProducts
	|WHERE
	|	CostAllocationProducts.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableProduction.Products AS Products,
	|	TemporaryTableProduction.ProductCharacteristic AS ProductCharacteristic,
	|	TemporaryTableProduction.ProductionBatch AS ProductionBatch,
	|	TemporaryTableProduction.SalesOrder AS SalesOrder,
	|	TemporaryTableProduction.Specification AS ProductionSpecification,
	|	BillsOfMaterialsContent.ContentRowType AS ContentRowType,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN BillsOfMaterialsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	BillsOfMaterialsContent.MeasurementUnit AS MeasurementUnit,
	|	BillsOfMaterialsContent.Specification AS Specification,
	|	SUM(BillsOfMaterialsContent.Quantity / BillsOfMaterialsContent.Ref.Quantity * TemporaryTableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TemporaryTableProduction
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		ON TemporaryTableProduction.Specification = BillsOfMaterialsContent.Ref
	|WHERE
	|	BillsOfMaterialsContent.Products.ProductsType = &ProductsType
	|
	|GROUP BY
	|	TemporaryTableProduction.Products,
	|	TemporaryTableProduction.ProductCharacteristic,
	|	TemporaryTableProduction.ProductionBatch,
	|	TemporaryTableProduction.Specification,
	|	BillsOfMaterialsContent.Specification,
	|	BillsOfMaterialsContent.ContentRowType,
	|	TemporaryTableProduction.SalesOrder,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN BillsOfMaterialsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	BillsOfMaterialsContent.MeasurementUnit";
	
	UseCharacteristics = Constants.UseCharacteristics.Get(); 
	
	TemporaryTableProduction = Products.Unload();
	
	For Each StringTT In TemporaryTableProduction Do
		If TypeOf(StringTT.MeasurementUnit) = Type("CatalogRef.UOM") Then
			StringTT.Quantity = StringTT.Quantity * StringTT.MeasurementUnit.Factor;
		EndIf;
	EndDo;
	
	Query.SetParameter("CostAllocationProducts", TemporaryTableProduction);
	Query.SetParameter("UseCharacteristics", 	UseCharacteristics);
	
	Query.SetParameter("ProductsType", Enums.ProductsTypes.InventoryItem);
	
	TemporaryTableDistribution = Query.Execute().Unload();
	
	For n = 0 To TemporaryTableDistribution.Count() - 1 Do
		
		VTRow = TemporaryTableDistribution[n];
		
		If VTRow.ContentRowType = Enums.BOMLineType.Node Then
			
			DistributeTabularSectionBySpecification(VTRow, TemporaryTableDistribution, VTRow.ProductionSpecification);
			
		EndIf;
		
	EndDo;

	For Each TabularSectionRow In Inventory Do
		
		SearchStructure = New Structure;
		SearchStructure.Insert("Products", 		TabularSectionRow.Products);
		SearchStructure.Insert("Characteristic", 		TabularSectionRow.Characteristic);
		SearchStructure.Insert("MeasurementUnit", 	TabularSectionRow.MeasurementUnit);
		SearchStructure.Insert("SalesOrder", 	TabularSectionRow.SalesOrder);
		SearchStructure.Insert("Specification", 		TabularSectionRow.Specification);
		
		CountToDistribution = TabularSectionRow.Quantity;
		
		SearchingArray = TemporaryTableDistribution.FindRows(SearchStructure);
		For Each ArrayRow In SearchingArray Do
			
			If CountToDistribution > 0 Then
				
				ArrayRow.Quantity = min(ArrayRow.Quantity, CountToDistribution);
				CountToDistribution = CountToDistribution - ArrayRow.Quantity;
				
				NewRow = InventoryDistribution.Add();
				NewRow.Quantity			= ArrayRow.Quantity;
				NewRow.Products			= ArrayRow.Products;
				NewRow.Characteristic	= ArrayRow.ProductCharacteristic;
				NewRow.Batch			= ArrayRow.ProductionBatch;
				NewRow.SalesOrder		= ArrayRow.SalesOrder;
				NewRow.Specification	= ArrayRow.ProductionSpecification;
				NewRow.ConnectionKey	= TabularSectionRow.ConnectionKey;
				
			Else
				
				Break;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Procedure allocates inventory according to quantity.
//
Procedure RunInventoryDistributionByCount() Export
	
	InventoryDistribution.Clear();
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.ConnectionKey AS ConnectionKey,
	|	TableInventory.Quantity AS Quantity
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory";
	
	Query.SetParameter("TableInventory", Inventory.Unload());
	
	Query.Execute();
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.MeasurementUnit AS MeasurementUnit,
	|	TableProduction.Specification AS Specification,
	|	TableProduction.SalesOrder AS SalesOrder,
	|	TableProduction.Quantity AS Quantity
	|INTO TemporaryTableProduction
	|FROM
	|	&TableProduction AS TableProduction";
	
	Query.SetParameter("TableProduction", Products.Unload());
	
	Query.Execute();
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableProduction.Products AS Products,
	|	TemporaryTableProduction.Characteristic AS Characteristic,
	|	TemporaryTableProduction.Batch AS Batch,
	|	TemporaryTableProduction.MeasurementUnit AS MeasurementUnit,
	|	TemporaryTableProduction.Specification AS Specification,
	|	TemporaryTableProduction.SalesOrder AS SalesOrder,
	|	TemporaryTableInventory.ConnectionKey AS ConnectionKey,
	|	TemporaryTableProduction.Quantity AS Quantity,
	|	TemporaryTableInventory.Quantity AS TotalAmountCount
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory,
	|	TemporaryTableProduction AS TemporaryTableProduction
	|TOTALS
	|	SUM(Quantity)
	|BY
	|	ConnectionKey";
	
	SelectionKeyLinks = Query.Execute().Select(QueryResultIteration.ByGroups, "ConnectionKey");
	While SelectionKeyLinks.Next() Do
		
		InitQuantity = 0;
		DistributionBaseQuantity = SelectionKeyLinks.Quantity;
		SelectionDetailing = SelectionKeyLinks.Select();
		While SelectionDetailing.Next() Do
			
			NewRow = InventoryDistribution.Add();
			NewRow.ConnectionKey = SelectionDetailing.ConnectionKey;
			NewRow.Products = SelectionDetailing.Products;
			NewRow.Characteristic = SelectionDetailing.Characteristic;
			NewRow.Batch = SelectionDetailing.Batch;
			NewRow.SalesOrder = SelectionDetailing.SalesOrder;
			NewRow.Specification = SelectionDetailing.Specification;
			
			NewRow.Quantity = ?(DistributionBaseQuantity <> 0, Round((SelectionDetailing.TotalAmountCount - InitQuantity) * SelectionDetailing.Quantity / DistributionBaseQuantity, 3, 1),0);
			DistributionBaseQuantity = DistributionBaseQuantity - SelectionDetailing.Quantity;
			InitQuantity = InitQuantity + NewRow.Quantity;
			
		EndDo;
		
	EndDo;
	
	TempTablesManager.Close();
	
EndProcedure

// Procedure fills expenses according to balances.
//
Procedure RunExpenseFillingByBalance() Export
	
	Costs.Clear();
	CostAllocation.Clear();
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SUM(InventoryBalances.AmountBalance) AS Amount
	|FROM
	|	AccumulationRegister.Inventory.Balance(
	|			&ProcessingDate,
	|			Company = &Company
	|				AND StructuralUnit = &StructuralUnit
	|				AND Products = VALUE(Catalog.Products.EmptyRef)
	|				AND InventoryAccountType = VALUE(Enum.InventoryAccountTypes.WorkInProgress)) AS InventoryBalances
	|WHERE
	|	InventoryBalances.AmountBalance > 0";
	
	Query.SetParameter("ProcessingDate", EndOfDay(Date));
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnit);
	
	ConnectionKey = 0;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		NewRow = Costs.Add();
		FillPropertyValues(NewRow, Selection);
		NewRow.ConnectionKey = ConnectionKey;
		
		ConnectionKey = ConnectionKey + 1;
		
	EndDo;
	
EndProcedure

// Procedure allocates expenses according to quantity.
//
Procedure RunCostingByCount() Export
	
	CostAllocation.Clear();
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableCosts.ConnectionKey AS ConnectionKey,
	|	TableCosts.Amount AS Amount
	|INTO TemporaryTableCost
	|FROM
	|	&TableCosts AS TableCosts";
	
	Query.SetParameter("TableCosts", Costs.Unload());
	Query.Execute();
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.MeasurementUnit AS MeasurementUnit,
	|	TableProduction.Specification AS Specification,
	|	TableProduction.SalesOrder AS SalesOrder,
	|	TableProduction.LineNumber AS LineNumber,
	|	TableProduction.Quantity AS Quantity
	|INTO TemporaryTableProduction
	|FROM
	|	&TableProduction AS TableProduction";
	
	Query.SetParameter("TableProduction", Products.Unload());
	Query.Execute();
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableProduction.Products AS Products,
	|	TemporaryTableProduction.Characteristic AS Characteristic,
	|	TemporaryTableProduction.Batch AS Batch,
	|	TemporaryTableProduction.MeasurementUnit AS MeasurementUnit,
	|	TemporaryTableProduction.Specification AS Specification,
	|	TemporaryTableProduction.SalesOrder AS SalesOrder,
	|	TemporaryTableProduction.LineNumber AS LineNumber,
	|	TemporaryTableCost.ConnectionKey AS ConnectionKey,
	|	TemporaryTableProduction.Quantity AS Quantity,
	|	TemporaryTableCost.Amount AS Amount
	|FROM
	|	TemporaryTableProduction AS TemporaryTableProduction
	|		INNER JOIN TemporaryTableCost AS TemporaryTableCost
	|		ON (TRUE)
	|
	|ORDER BY
	|	ConnectionKey,
	|	LineNumber,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	Specification,
	|	SalesOrder
	|TOTALS
	|	SUM(Quantity)
	|BY
	|	ConnectionKey";
	
	SelectionKeyLinks = Query.Execute().Select(QueryResultIteration.ByGroups, "ConnectionKey");
	While SelectionKeyLinks.Next() Do
		
		SrcAmount = 0;
		DistributionBase = SelectionKeyLinks.Quantity;
		SelectionDetailing = SelectionKeyLinks.Select();
		While SelectionDetailing.Next() Do
			
			NewRow = CostAllocation.Add();
			NewRow.ConnectionKey = SelectionDetailing.ConnectionKey;
			NewRow.Products = SelectionDetailing.Products;
			NewRow.Characteristic = SelectionDetailing.Characteristic;
			NewRow.Batch = SelectionDetailing.Batch;
			NewRow.SalesOrder = SelectionDetailing.SalesOrder;
			NewRow.Specification = SelectionDetailing.Specification;
			
			NewRow.Amount = ?(DistributionBase <> 0, Round((SelectionDetailing.Amount - SrcAmount) * SelectionDetailing.Quantity / DistributionBase, 2, 1),0);
			DistributionBase = DistributionBase - SelectionDetailing.Quantity;
			SrcAmount = SrcAmount + NewRow.Amount;
			
		EndDo;
		
	EndDo;
	
	TempTablesManager.Close();
	
EndProcedure

// Procedure fills products according to release.
//
Procedure RunProductsFillingByOutput() Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	ProductReleaseTurnovers.Products AS Products,
	|	ProductReleaseTurnovers.Characteristic AS Characteristic,
	|	ProductReleaseTurnovers.Batch AS Batch,
	|	ProductReleaseTurnovers.Products.MeasurementUnit AS MeasurementUnit,
	|	ProductReleaseTurnovers.Specification AS Specification,
	|	CASE
	|		WHEN &UseInventoryReservation
	|			THEN ProductReleaseTurnovers.SalesOrder
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS SalesOrder,
	|	SUM(ProductReleaseTurnovers.QuantityTurnover) AS Quantity
	|INTO ProductReleaseTable
	|FROM
	|	AccumulationRegister.ProductRelease.Turnovers(
	|			&StartDate,
	|			&EndDate,
	|			,
	|			Company = &Company
	|				AND StructuralUnit = &StructuralUnit
	|				AND Products.ProductsType <> &ProductsTypeService) AS ProductReleaseTurnovers
	|
	|GROUP BY
	|	ProductReleaseTurnovers.Characteristic,
	|	ProductReleaseTurnovers.Specification,
	|	ProductReleaseTurnovers.Batch,
	|	ProductReleaseTurnovers.Products,
	|	ProductReleaseTurnovers.SalesOrder,
	|	ProductReleaseTurnovers.Products.MeasurementUnit
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductReleaseTable.Products AS Products,
	|	ProductReleaseTable.Characteristic AS Characteristic,
	|	ProductReleaseTable.Batch AS Batch,
	|	ProductReleaseTable.MeasurementUnit AS MeasurementUnit,
	|	ProductReleaseTable.Specification AS Specification,
	|	ProductReleaseTable.SalesOrder AS SalesOrder,
	|	ProductReleaseTable.Quantity AS Quantity
	|FROM
	|	ProductReleaseTable AS ProductReleaseTable
	|WHERE
	|	NOT ProductReleaseTable.SalesOrder REFS Document.WorkOrder
	|
	|ORDER BY
	|	Products,
	|	Characteristic,
	|	Batch,
	|	Specification,
	|	SalesOrder";
	
	Query.SetParameter("UseInventoryReservation", Constants.UseInventoryReservation.Get());
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnit);
	Query.SetParameter("ProductsTypeService", Enums.ProductsTypes.Service);
	Query.SetParameter("StartDate", PeriodOpenDate);
	Query.SetParameter("EndDate", EndOfDay(Date));
	
	Products.Load(Query.Execute().Unload());
	
EndProcedure

#EndRegion

#Region EventHandlers

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If TypeOf(FillingData) = Type("DocumentRef.Production") Then
		
		Query = New Query(
		"SELECT ALLOWED
		|	Production.Ref AS BasisDocument,
		|	Production.OperationKind AS OperationKind,
		|	Production.Company AS Company,
		|	Production.StructuralUnit AS StructuralUnit,
		|	Production.Cell AS Cell,
		|	Production.SalesOrder AS SalesOrder,
		|	Production.Products.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		Batch AS Batch,
		|		Quantity AS Quantity,
		|		MeasurementUnit AS MeasurementUnit,
		|		Specification AS Specification
		|	) AS Products,
		|	Production.Inventory.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		Batch AS Batch,
		|		Quantity AS Quantity,
		|		MeasurementUnit AS MeasurementUnit,
		|		Specification AS Specification
		|	) AS Inventory
		|FROM
		|	Document.Production AS Production
		|WHERE
		|	Production.Ref = &Ref");
		
		Query.SetParameter("Ref", FillingData);
		
		QueryResultSelection = Query.Execute().Select();
		If QueryResultSelection.Next() Then
			
			If QueryResultSelection.OperationKind = Enums.OperationTypesProduction.Disassembly Then
				TabularSectionName = "Inventory";
			Else
				TabularSectionName = "Products";
			EndIf;
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionProducts = QueryResultSelection[TabularSectionName].Select();
			While SelectionProducts.Next() Do
				NewRow = Products.Add();
				NewRow.Products 		= SelectionProducts.Products;
				NewRow.Characteristic 		= SelectionProducts.Characteristic;
				NewRow.Batch 				= SelectionProducts.Batch;
				NewRow.MeasurementUnit 	= SelectionProducts.MeasurementUnit;
				NewRow.Quantity 			= SelectionProducts.Quantity;
				NewRow.Specification 		= SelectionProducts.Specification;
				NewRow.SalesOrder		= QueryResultSelection.SalesOrder;
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.Manufacturing") Then
		
		Query = New Query(
		"SELECT ALLOWED
		|	Production.Ref AS BasisDocument,
		|	Production.OperationKind AS OperationKind,
		|	Production.Company AS Company,
		|	Production.StructuralUnit AS StructuralUnit,
		|	Production.Cell AS Cell,
		|	Production.SalesOrder AS SalesOrder,
		|	Production.Products.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		Batch AS Batch,
		|		Quantity AS Quantity,
		|		MeasurementUnit AS MeasurementUnit,
		|		Specification AS Specification
		|	) AS Products,
		|	Production.Inventory.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		Batch AS Batch,
		|		Quantity AS Quantity,
		|		MeasurementUnit AS MeasurementUnit,
		|		Specification AS Specification
		|	) AS Inventory
		|FROM
		|	Document.Manufacturing AS Production
		|WHERE
		|	Production.Ref = &Ref");
		
		Query.SetParameter("Ref", FillingData);
		
		QueryResultSelection = Query.Execute().Select();
		If QueryResultSelection.Next() Then
			
			If QueryResultSelection.OperationKind = Enums.OperationTypesProduction.Disassembly Then
				TabularSectionName = "Inventory";
			Else
				TabularSectionName = "Products";
			EndIf;
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionProducts = QueryResultSelection[TabularSectionName].Select();
			While SelectionProducts.Next() Do
				NewRow = Products.Add();
				FillPropertyValues(NewRow, SelectionProducts);
				NewRow.SalesOrder = QueryResultSelection.SalesOrder;
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ProductionOrder") Then
		
		Query = New Query(
		"SELECT ALLOWED
		|	ProductionOrder.Ref AS BasisDocument,
		|	ProductionOrder.Company AS Company,
		|	ProductionOrder.OperationKind AS OperationKind,
		|	ProductionOrder.StructuralUnit AS StructuralUnit,
		|	ProductionOrder.SalesOrder AS SalesOrder,
		|	ProductionOrder.Products.(
		|		Products AS Products,
		|		Products.ProductsType AS ProductsType,
		|		Characteristic AS Characteristic,
		|		Quantity AS Quantity,
		|		MeasurementUnit AS MeasurementUnit,
		|		Specification AS Specification
		|	) AS Products,
		|	ProductionOrder.Inventory.(
		|		Products AS Products,
		|		Products.ProductsType AS ProductsType,
		|		Characteristic AS Characteristic,
		|		Quantity AS Quantity,
		|		MeasurementUnit AS MeasurementUnit,
		|		Specification AS Specification
		|	) AS Inventory
		|FROM
		|	Document.ProductionOrder AS ProductionOrder
		|WHERE
		|	ProductionOrder.Ref = &Ref");
		
		Query.SetParameter("Ref", FillingData);
		Query.SetParameter("ProductsType", Enums.ProductsTypes.Service);
		
		QueryResultSelection = Query.Execute().Select();
		If QueryResultSelection.Next() Then
			
			If QueryResultSelection.OperationKind = Enums.OperationTypesProductionOrder.Disassembly Then
				NameTSProducts = "Inventory";
				NameTSInventory = "Products";
			Else
				NameTSProducts = "Products";
				NameTSInventory = "Inventory";
			EndIf;
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionProducts = QueryResultSelection[NameTSProducts].Select();
			While SelectionProducts.Next() Do
				If SelectionProducts.ProductsType = Enums.ProductsTypes.Service Then
					Continue;
				EndIf;
				NewRow = Products.Add();
				NewRow.Products 		= SelectionProducts.Products;
				NewRow.Characteristic 		= SelectionProducts.Characteristic;
				NewRow.MeasurementUnit 	= SelectionProducts.MeasurementUnit;
				NewRow.Quantity 			= SelectionProducts.Quantity;
				NewRow.Specification 		= SelectionProducts.Specification;
				NewRow.SalesOrder		= QueryResultSelection.SalesOrder;
			EndDo;
			
			ConnectionKey = 0;
			SelectionInventory = QueryResultSelection[NameTSInventory].Select();
			While SelectionInventory.Next() Do
				If SelectionProducts.ProductsType = Enums.ProductsTypes.InventoryItem Then
					NewRow = Inventory.Add();
					NewRow.Products 		= SelectionInventory.Products;
					NewRow.Characteristic 		= SelectionInventory.Characteristic;
					NewRow.MeasurementUnit 	= SelectionInventory.MeasurementUnit;
					NewRow.Quantity 			= SelectionInventory.Quantity;
					NewRow.Specification 		= SelectionInventory.Specification;
					NewRow.SalesOrder		= QueryResultSelection.SalesOrder;
					NewRow.ConnectionKey			= ConnectionKey;
					ConnectionKey = ConnectionKey + 1;
				EndIf;
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SalesOrder")
		AND FillingData.OperationKind = Enums.OperationTypesSalesOrder.OrderForSale Then
		
		Query = New Query(
		"SELECT ALLOWED
		|	SalesOrder.Ref AS BasisDocument,
		|	SalesOrder.Company AS Company,
		|	CASE
		|		WHEN SalesOrder.SalesStructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN SalesOrder.SalesStructuralUnit
		|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
		|	END AS StructuralUnit,
		|	SalesOrder.Inventory.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		Quantity AS Quantity,
		|		MeasurementUnit AS MeasurementUnit,
		|		Specification AS Specification,
		|		Ref AS SalesOrder,
		|		Products.ProductsType AS ProductsType
		|	) AS Inventory
		|FROM
		|	Document.SalesOrder AS SalesOrder
		|WHERE
		|	SalesOrder.Ref = &Ref");
		
		Query.SetParameter("Ref", FillingData);
		
		QueryResultSelection = Query.Execute().Select();
		If QueryResultSelection.Next() Then
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionInventory = QueryResultSelection.Inventory.Select();
			While SelectionInventory.Next() Do
				
				If SelectionInventory.ProductsType <> Enums.ProductsTypes.Service Then
				
					NewRow = Products.Add();
					NewRow.Products 		= SelectionInventory.Products;
					NewRow.Characteristic 		= SelectionInventory.Characteristic;
					NewRow.MeasurementUnit 	= SelectionInventory.MeasurementUnit;
					NewRow.Quantity 			= SelectionInventory.Quantity;
					NewRow.Specification		= SelectionInventory.Specification;
					NewRow.SalesOrder		= SelectionInventory.SalesOrder;
					
					FillTabularSectionBySpecification(SelectionInventory.Specification, SelectionInventory.Quantity, SelectionInventory.MeasurementUnit, SelectionInventory.SalesOrder);
					
				EndIf;
				
			EndDo;
			
			Inventory.GroupBy("Products, Characteristic, MeasurementUnit, SalesOrder, Specification", "Quantity");
			
			ConnectionKey = 0;
			For Each TabularSectionRow In Inventory Do
				TabularSectionRow.ConnectionKey = ConnectionKey;
				ConnectionKey = ConnectionKey + 1;
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SalesOrder")
		AND FillingData.OperationKind = Enums.OperationTypesSalesOrder.OrderForProcessing Then
		
		Query = New Query(
		"SELECT ALLOWED
		|	SalesOrder.Ref AS BasisDocument,
		|	SalesOrder.Company AS Company,
		|	CASE
		|		WHEN SalesOrder.SalesStructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			THEN SalesOrder.SalesStructuralUnit
		|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
		|	END AS StructuralUnit,
		|	SalesOrder.Inventory.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		Quantity AS Quantity,
		|		MeasurementUnit AS MeasurementUnit,
		|		Specification AS Specification,
		|		Ref AS SalesOrder,
		|		Products.ProductsType AS ProductsType
		|	) AS Inventory,
		|	SalesOrder.ConsumerMaterials.(
		|		Products AS Products,
		|		Characteristic AS Characteristic,
		|		Quantity AS Quantity,
		|		MeasurementUnit AS MeasurementUnit,
		|		Ref AS SalesOrder
		|	) AS ConsumerMaterials
		|FROM
		|	Document.SalesOrder AS SalesOrder
		|WHERE
		|	SalesOrder.Ref = &Ref");
		 
		Query.SetParameter("Ref", FillingData);
		
		QueryResultSelection = Query.Execute().Select();
		If QueryResultSelection.Next() Then
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			SelectionMaterials = QueryResultSelection.ConsumerMaterials.Select();
			
			SelectionInventory = QueryResultSelection.Inventory.Select();
			While SelectionInventory.Next() Do
				
				If SelectionInventory.ProductsType <> Enums.ProductsTypes.Service Then
				
					NewRow = Products.Add();
					NewRow.Products 		= SelectionInventory.Products;
					NewRow.Characteristic 		= SelectionInventory.Characteristic;
					NewRow.MeasurementUnit 	= SelectionInventory.MeasurementUnit;
					NewRow.Quantity 			= SelectionInventory.Quantity;
					NewRow.Specification		= SelectionInventory.Specification;
					NewRow.SalesOrder		= SelectionInventory.SalesOrder;
					
					If SelectionMaterials.Count() = 0 Then
						FillTabularSectionBySpecification(SelectionInventory.Specification, SelectionInventory.Quantity, SelectionInventory.MeasurementUnit, SelectionInventory.SalesOrder);
					EndIf;
					
				EndIf;
				
			EndDo;
			
			While SelectionMaterials.Next() Do
				
				NewRow = Inventory.Add();
				NewRow.Products 		= SelectionMaterials.Products;
				NewRow.Characteristic 		= SelectionMaterials.Characteristic;
				NewRow.MeasurementUnit 	= SelectionMaterials.MeasurementUnit;
				NewRow.Quantity 			= SelectionMaterials.Quantity;
				NewRow.SalesOrder		= SelectionMaterials.SalesOrder;
				
			EndDo;
			
			Inventory.GroupBy("Products, Characteristic, MeasurementUnit, SalesOrder, Specification", "Quantity");
			
			ConnectionKey = 0;
			For Each TabularSectionRow In Inventory Do
				TabularSectionRow.ConnectionKey = ConnectionKey;
				ConnectionKey = ConnectionKey + 1;
			EndDo;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("Structure") Then
		FillPropertyValues(ThisObject, FillingData);
	EndIf;
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)

	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Inventory.Total("Quantity") <> InventoryDistribution.Total("Quantity") Then

		MessageText = NStr("en = 'Quantity of inventory does not match those of the allocation.'; ru = 'Количество запасов не соответствует количеству распределения!';pl = 'Ilość zapasów nie odpowiada ilości alokacji.';es_ES = 'Cantidad del inventario no coincide con aquella de la asignación.';es_CO = 'Cantidad del inventario no coincide con aquella de la asignación.';tr = 'Stok miktarı, tahsis miktarı ile uyuşmuyor.';it = 'Quantità di scorte non corrisponde a quelle della dotazione.';de = 'Die Bestandsmenge stimmt nicht mit der der Zuordnung überein.'");
		DriveServer.ShowMessageAboutError(ThisObject, MessageText,,,"Inventory",Cancel);
			
	EndIf;
	
	If Costs.Total("Amount") <> CostAllocation.Total("Amount") Then

		MessageText = NStr("en = 'Amount of expenses does not correspond to the allocation amount.'; ru = 'Сумма расходов не соответствует сумме распределения!';pl = 'Suma kosztów nie odpowiada sumie podziału!';es_ES = 'Importe de los gastos no corresponde al importe de la asignación.';es_CO = 'Importe de los gastos no corresponde al importe de la asignación.';tr = 'Gider tutarı tahsis tutarına karşılık gelmez.';it = 'Importo delle spese non corrisponde alla quantità di assegnazione.';de = 'Die Höhe der Ausgaben entspricht nicht der Verteilung.'");
		DriveServer.ShowMessageAboutError(ThisObject, MessageText,,,"Costs",Cancel);
			
	EndIf;
	
	If PeriodOpenDate > Date Then
		
		MessageText = NStr("en = 'The start date cannot be later than the end date.'; ru = 'Дата начала не может быть позже даты окончания.';pl = 'Data rozpoczęcia nie może być późniejsza niż data zakończenia.';es_ES = 'La fecha del inicio no puede ser posterior a la fecha del fin.';es_CO = 'La fecha del inicio no puede ser posterior a la fecha del fin.';tr = 'Başlangıç tarihi bitiş tarihinden sonra olamaz.';it = 'La data di inizio non può essere successiva a quella di fine.';de = 'Das Startdatum darf nicht nach dem Enddatum liegen.'");
		DriveServer.ShowMessageAboutError(ThisObject, MessageText,,,"PeriodOpenDate",Cancel);
		
	EndIf;
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	// Document data initialization.
	Documents.CostAllocation.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryAccepted(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.CostAllocation.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	
	// Initialization of additional properties to undo the posting of a document.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.CostAllocation.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;
		
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Write, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;

EndProcedure

#EndRegion

#EndIf
