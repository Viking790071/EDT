#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function GetData(Parameters) Export
	
	Query = New Query;
	
	Query.SetParameter("StartDate", Parameters.StartDate);
	Query.SetParameter("EndDate", Parameters.EndDate);
	Query.SetParameter("Company", Parameters.Company);
	Query.SetParameter("FilterDepartment", ValueIsFilled(Parameters.Department));
	Query.SetParameter("Department", Parameters.Department);
	Query.SetParameter("FilterCounterparty", Parameters.FilterCounterparty);
	Query.SetParameter("Counterparties", Parameters.Counterparties);
	Query.SetParameter("Date", EndOfDay(Parameters.Date));
	
	If Parameters.Property("DataTree") Then
		DataTree = Parameters.DataTree;
		DataTree.GetItems().Clear();
		TreeMode = True;
		DataTable = Undefined;
	Else
		TreeMode = False;
		DataTable = NewDataTable(Parameters.Template);
	EndIf;
	
	If Not Parameters.Property("PresentationCurrency") Then
		Parameters.Insert("PresentationCurrency", DriveServer.GetPresentationCurrency(Parameters.Company));
	EndIf;
	
	Query.Text =
	"SELECT ALLOWED
	|	ActualSalesVolume.Counterparty AS Counterparty,
	|	ActualSalesVolume.Contract AS Contract,
	|	ActualSalesVolume.Products AS Products,
	|	ActualSalesVolume.Characteristic AS Characteristic,
	|	ActualSalesVolume.Batch AS Batch,
	|	ActualSalesVolume.DeliveryStartDate AS DeliveryStartDate,
	|	ActualSalesVolume.DeliveryEndDate AS DeliveryEndDate,
	|	ActualSalesVolume.Quantity AS Quantity
	|INTO TT_ActualSales
	|FROM
	|	AccumulationRegister.ActualSalesVolume AS ActualSalesVolume
	|WHERE
	|	ActualSalesVolume.Company = &Company
	|	AND ActualSalesVolume.Period <= &Date
	|	AND ActualSalesVolume.DeliveryStartDate <= &EndDate
	|	AND ActualSalesVolume.DeliveryEndDate >= &StartDate
	|	AND (NOT &FilterDepartment
	|			OR ActualSalesVolume.Department = &Department)
	|	AND (NOT &FilterCounterparty
	|			OR ActualSalesVolume.Counterparty IN (&Counterparties))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	Sales.Recorder AS Invoice
	|INTO TT_Invoices
	|FROM
	|	AccumulationRegister.Sales AS Sales
	|WHERE
	|	Sales.Company = &Company
	|	AND Sales.Period <= &Date
	|	AND Sales.Quantity > 0
	|	AND Sales.DeliveryStartDate <> DATETIME(1, 1, 1)
	|	AND Sales.DeliveryStartDate <= &EndDate
	|	AND Sales.DeliveryEndDate <> DATETIME(1, 1, 1)
	|	AND Sales.DeliveryEndDate >= &StartDate
	|	AND (NOT &FilterDepartment
	|			OR Sales.Department = &Department)
	|	AND (NOT &FilterCounterparty
	|			OR Sales.Counterparty IN (&Counterparties))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TT_Invoices.Invoice AS Invoice
	|INTO TT_AllInvoices
	|FROM
	|	TT_Invoices AS TT_Invoices
	|
	|UNION
	|
	|SELECT DISTINCT
	|	SalesInvoiceIssuedInvoices.Ref
	|FROM
	|	TT_Invoices AS TT_Invoices
	|		INNER JOIN Document.SalesInvoice.IssuedInvoices AS SalesInvoiceIssuedInvoices
	|		ON TT_Invoices.Invoice = SalesInvoiceIssuedInvoices.Invoice
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON (SalesInvoiceIssuedInvoices.Ref = SalesInvoice.Ref)
	|			AND (SalesInvoice.Posted)
	|			AND (SalesInvoice.OperationKind = VALUE(Enum.OperationTypesSalesInvoice.ClosingInvoice))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Sales.Counterparty AS Counterparty,
	|	SalesInvoice.Contract AS Contract,
	|	Sales.Products AS Products,
	|	Sales.Characteristic AS Characteristic,
	|	Sales.Batch AS Batch,
	|	TT_AllInvoices.Invoice AS Invoice,
	|	SalesInvoice.Date AS InvoiceDate,
	|	Sales.VATRate AS VATRate,
	|	Contracts.SettlementsCurrency AS ContractCurrency,
	|	ISNULL(PriceTypes.Ref, VALUE(Catalog.PriceTypes.EmptyRef)) AS PriceKind,
	|	ISNULL(PriceTypes.PriceIncludesVAT, FALSE) AS PriceIncludesVAT,
	|	Sales.DeliveryStartDate AS DeliveryStartDate,
	|	Sales.DeliveryEndDate AS DeliveryEndDate,
	|	Sales.Quantity AS Quantity,
	|	Sales.Amount + CASE
	|		WHEN ISNULL(PriceTypes.PriceIncludesVAT, FALSE)
	|			THEN Sales.VATAmount
	|		ELSE 0
	|	END AS Amount,
	|	CAST((Sales.Amount + CASE
	|			WHEN ISNULL(PriceTypes.PriceIncludesVAT, FALSE)
	|				THEN Sales.VATAmount
	|			ELSE 0
	|		END) / Sales.Quantity AS NUMBER(15, 2)) AS Price
	|INTO TT_Sales
	|FROM
	|	TT_AllInvoices AS TT_AllInvoices
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON TT_AllInvoices.Invoice = SalesInvoice.Ref
	|		INNER JOIN AccumulationRegister.Sales AS Sales
	|		ON TT_AllInvoices.Invoice = Sales.Recorder
	|		INNER JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON (SalesInvoice.Contract = Contracts.Ref)
	|		LEFT JOIN Catalog.PriceTypes AS PriceTypes
	|		ON (Contracts.PriceKind = PriceTypes.Ref)
	|WHERE
	|	Sales.Company = &Company
	|	AND Sales.Quantity <> 0
	|	AND Sales.DeliveryStartDate <> DATETIME(1, 1, 1)
	|	AND Sales.DeliveryEndDate <> DATETIME(1, 1, 1)
	|	AND (NOT &FilterDepartment
	|			OR Sales.Department = &Department)
	|	AND (NOT &FilterCounterparty
	|			OR Sales.Counterparty IN (&Counterparties))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TT_Sales.Counterparty AS Counterparty,
	|	TT_Sales.Contract AS Contract,
	|	TT_Sales.ContractCurrency AS ContractCurrency,
	|	TT_Sales.Products AS Products,
	|	TT_Sales.Characteristic AS Characteristic,
	|	TT_Sales.Batch AS Batch,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	TT_Sales.Invoice AS Invoice,
	|	TT_Sales.InvoiceDate AS InvoiceDate,
	|	TT_Sales.VATRate AS VATRate,
	|	TT_Sales.PriceKind AS PriceKind,
	|	TT_Sales.PriceIncludesVAT AS PriceIncludesVAT,
	|	TT_Sales.DeliveryStartDate AS DeliveryStartDate,
	|	TT_Sales.DeliveryEndDate AS DeliveryEndDate,
	|	0 AS ActualQuantity,
	|	TT_Sales.Quantity AS InvoicedQuantity,
	|	SalesInvoiceInventory.Price AS Price
	|FROM
	|	TT_Sales AS TT_Sales
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON TT_Sales.Products = CatalogProducts.Ref
	|		INNER JOIN Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		ON TT_Sales.Invoice = SalesInvoiceInventory.Ref
	|			AND TT_Sales.Products = SalesInvoiceInventory.Products
	|			AND TT_Sales.Characteristic = SalesInvoiceInventory.Characteristic
	|			AND TT_Sales.Batch = SalesInvoiceInventory.Batch
	|
	|UNION ALL
	|
	|SELECT
	|	TT_ActualSales.Counterparty,
	|	TT_ActualSales.Contract,
	|	Contracts.SettlementsCurrency,
	|	TT_ActualSales.Products,
	|	TT_ActualSales.Characteristic,
	|	TT_ActualSales.Batch,
	|	CatalogProducts.MeasurementUnit,
	|	NULL,
	|	NULL,
	|	NULL,
	|	ISNULL(PriceTypes.Ref, VALUE(Catalog.PriceTypes.EmptyRef)),
	|	ISNULL(PriceTypes.PriceIncludesVAT, FALSE),
	|	TT_ActualSales.DeliveryStartDate,
	|	TT_ActualSales.DeliveryEndDate,
	|	TT_ActualSales.Quantity,
	|	0,
	|	0
	|FROM
	|	TT_ActualSales AS TT_ActualSales
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON TT_ActualSales.Products = CatalogProducts.Ref
	|		INNER JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON TT_ActualSales.Contract = Contracts.Ref
	|		LEFT JOIN Catalog.PriceTypes AS PriceTypes
	|		ON (Contracts.PriceKind = PriceTypes.Ref)
	|
	|ORDER BY
	|	Counterparty,
	|	Contract,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	DeliveryStartDate,
	|	DeliveryEndDate DESC
	|TOTALS
	|	MAX(ContractCurrency),
	|	MAX(MeasurementUnit),
	|	MIN(DeliveryStartDate),
	|	MAX(DeliveryEndDate)
	|BY
	|	Counterparty,
	|	Contract,
	|	Products,
	|	Characteristic,
	|	Batch
	|AUTOORDER";
	
	SelCounterparty = Query.Execute().Select(QueryResultIteration.ByGroups);
	While SelCounterparty.Next() Do
		SelContract = SelCounterparty.Select(QueryResultIteration.ByGroups);
		While SelContract.Next() Do
			
			If TreeMode Then
				RowLevel1 = DataTree.GetItems().Add();
			Else
				RowLevel1 = DataTable.Add();
			EndIf;
			RowLevel1.Level = 1;
			FillPropertyValues(RowLevel1, SelContract, "DeliveryStartDate, DeliveryEndDate, Counterparty, Contract");
			RowLevel1.DeliveryStartDateError = (RowLevel1.DeliveryStartDate < Parameters.StartDate);
			RowLevel1.DeliveryEndDateError = (RowLevel1.DeliveryEndDate > Parameters.EndDate);
			RowLevel1.ContractCurrencyError = (SelContract.ContractCurrency <> Parameters.PresentationCurrency);
			
			SelProducts = SelContract.Select(QueryResultIteration.ByGroups);
			While SelProducts.Next() Do
				SelCharacteristic = SelProducts.Select(QueryResultIteration.ByGroups);
				While SelCharacteristic.Next() Do
					SelBatch = SelCharacteristic.Select(QueryResultIteration.ByGroups);
					While SelBatch.Next() Do
						
						RowLevel2 = Undefined;
						
						Sel = SelBatch.Select();
						SelCount = Sel.Count();
						Counter = 0;
						While Sel.Next() Do
							
							Counter = Counter + 1;
							
							If RowLevel2 = Undefined Then
								RowLevel2 = NewPeriodRow(RowLevel1, Sel, TreeMode, DataTable);
							ElsIf Sel.DeliveryStartDate > RowLevel2.DeliveryEndDate Then
								ClosePeriodRow(RowLevel2, RowLevel1, Sel, Parameters, TreeMode);
								RowLevel2 = NewPeriodRow(RowLevel1, Sel, TreeMode, DataTable);
							EndIf;
							
							If Not ValueIsFilled(RowLevel2.DeliveryStartDate) Then
								RowLevel2.DeliveryStartDate = Sel.DeliveryStartDate;
							EndIf;
							If Sel.DeliveryEndDate > RowLevel2.DeliveryEndDate Then
								RowLevel2.DeliveryEndDate = Sel.DeliveryEndDate;
							EndIf;
							
							If Sel.ActualQuantity > 0 Then
								
								RowLevel2.ActualQuantity = RowLevel2.ActualQuantity + Sel.ActualQuantity;
								
							Else
								
								If RowLevel2.Price = 0 Then
									RowLevel2.Price = Sel.Price;
								EndIf;
								If Not ValueIsFilled(RowLevel2.VATRate) Then
									RowLevel2.VATRate = Sel.VATRate;
								EndIf;
								
								RowLevel2.InvoicedQuantity = RowLevel2.InvoicedQuantity + Sel.InvoicedQuantity;
								
								If TreeMode Then
									RowLevel3 = RowLevel2.GetItems().Add();
								Else
									RowLevel3 = DataTable.Add();
								EndIf;
								RowLevel3.Level = 3;
								FillPropertyValues(RowLevel3, Sel);
								RowLevel3.DeliveryStartDateError = (RowLevel3.DeliveryStartDate < Parameters.StartDate);
								RowLevel3.DeliveryEndDateError = (RowLevel3.DeliveryEndDate > Parameters.EndDate);
								If RowLevel3.Price <> RowLevel2.Price Then
									RowLevel3.PriceError = True;
									RowLevel2.PriceError = True;
									RowLevel1.PriceError = True;
								EndIf;
								If RowLevel3.VATRate <> RowLevel2.VATRate Then
									RowLevel3.VATRateError = True;
									RowLevel2.VATRateError = True;
									RowLevel1.VATRateError = True;
								EndIf;
								
							EndIf;
							
							If Counter = SelCount Then
								ClosePeriodRow(RowLevel2, RowLevel1, Sel, Parameters, TreeMode);
							EndIf;
							
						EndDo;
						
					EndDo;
				EndDo;
			EndDo;
			
			RowLevel1.CanBeProcessed = RowLevel1.CanBeProcessed
				And Not RowLevel1.DeliveryStartDateError
				And Not RowLevel1.DeliveryEndDateError
				And Not RowLevel1.PriceError
				And Not RowLevel1.VATRateError
				And Not RowLevel1.ContractCurrencyError;
			
			RowLevel1.Process = RowLevel1.CanBeProcessed;
			
		EndDo;
	EndDo;
	
	If Not TreeMode Then
		Return DataTable;
	EndIf;
	
EndFunction

#EndRegion

#Region Private

Function NewPeriodRow(RowLevel1, Sel, TreeMode, DataTable)
	
	If TreeMode Then
		RowLevel2 = RowLevel1.GetItems().Add();
	Else
		RowLevel2 = DataTable.Add();
	EndIf;
	RowLevel2.Level = 2;
	FillPropertyValues(RowLevel2, Sel, "Counterparty, Contract, Products, Characteristic, Batch, MeasurementUnit");
	
	Return RowLevel2;
	
EndFunction

Procedure ClosePeriodRow(RowLevel2, RowLevel1, Sel, Parameters, TreeMode)
	
	RowLevel2.DeliveryStartDateError = (RowLevel2.DeliveryStartDate < Parameters.StartDate);
	RowLevel2.DeliveryEndDateError = (RowLevel2.DeliveryEndDate > Parameters.EndDate);
	
	If RowLevel2.Price = 0 Then
		StructureData = New Structure;
		StructureData.Insert("PriceKind", Sel.PriceKind);
		StructureData.Insert("ProcessingDate", Parameters.Date);
		StructureData.Insert("Products", Sel.Products);
		StructureData.Insert("Characteristic", Sel.Characteristic);
		StructureData.Insert("Factor", 1);
		StructureData.Insert("DocumentCurrency", Parameters.PresentationCurrency);
		StructureData.Insert("Company", Parameters.Company);
		RowLevel2.Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
	EndIf;
	If RowLevel2.Price = 0 Then
		RowLevel2.PriceError = True;
		RowLevel1.PriceError = True;
	EndIf;
	
	If Not ValueIsFilled(RowLevel2.VATRate) Then
		RowLevel2.VATRate = Common.ObjectAttributeValue(Sel.Products, "VATRate");
	EndIf;
	If Not ValueIsFilled(RowLevel2.VATRate) Then
		RowLevel2.VATRateError = True;
		RowLevel1.VATRateError = True;
	EndIf;
	
	RowLevel2.Quantity = RowLevel2.ActualQuantity - RowLevel2.InvoicedQuantity;
	
	If RowLevel2.Quantity <> 0 Then
		If Sel.PriceIncludesVAT Then
			RowLevel2.Amount = RowLevel2.Quantity * RowLevel2.Price;
		Else
			Rate = DriveReUse.GetVATRateValue(RowLevel2.VATRate);
			RowLevel2.Amount = RowLevel2.Quantity * RowLevel2.Price * (1 + Rate / 100);
		EndIf;
		RowLevel1.Amount = RowLevel1.Amount + RowLevel2.Amount;
		RowLevel1.CanBeProcessed = True;
	EndIf;
	
	If TreeMode Then
		Template = Reports.ClosingInvoices.GetTemplate("MainDataCompositionSchema");
		TempTable = NewDataTable(Template);
		SortPeriodRowsTree(RowLevel2, TempTable);
	Else
		TempTable = NewDataTable(Parameters.Template);
		SortPeriodRowsTable(RowLevel2, TempTable);
	EndIf;
	
EndProcedure

Procedure SortPeriodRowsTree(ParentRow, TempTable)
	
	ParentRows = ParentRow.GetItems();
	
	For Each Row In ParentRows Do
		FillPropertyValues(TempTable.Add(), Row);
	EndDo;
	
	TempTable.Sort("InvoiceDate Asc, Invoice Asc");
	
	ParentRows.Clear();
	
	For Each Row In TempTable Do
		FillPropertyValues(ParentRows.Add(), Row);
	EndDo;
	
EndProcedure

Procedure SortPeriodRowsTable(ParentRow, TempTable)
	
	Table = ParentRow.Owner();
	ParentRowNumber = Table.IndexOf(ParentRow) + 1;
	
	While Table.Count() > ParentRowNumber Do
		FillPropertyValues(TempTable.Add(), Table[ParentRowNumber]);
		Table.Delete(ParentRowNumber);
	EndDo;
	
	TempTable.Sort("InvoiceDate Asc, Invoice Asc");
	
	For Each Row In TempTable Do
		FillPropertyValues(Table.Add(), Row);
	EndDo;
	
EndProcedure

Function NewDataTable(Template)
	
	DataTable = New ValueTable;
	
	DataSet = Template.DataSets.Find("DataSet1");
	For Each Field In DataSet.Fields Do
		DataTable.Columns.Add(Field.Field, Field.ValueType);
	EndDo;
	
	Return DataTable;
	
EndFunction

#EndRegion

#EndIf