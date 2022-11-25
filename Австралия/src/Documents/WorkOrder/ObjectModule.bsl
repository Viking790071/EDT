#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure FillingHandler(FillingData) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.Quote") Then
		
		Query = New Query(QueryTextForFilling());
		Query.SetParameter("Parameter", FillingData);
		ResultsArray = Query.ExecuteBatch();
		
		Header = ResultsArray[0].Unload();
		
		If Header.Count() > 0 Then
			
			FillPropertyValues(ThisObject, Header[0]);
			
			If DocumentCurrency <> DriveServer.GetPresentationCurrency(FillingData.Company) Then
				
				If ValueIsFilled(DocumentCurrency) And Type("CatalogRef.Currencies") = TypeOf(DocumentCurrency) Then
					FillingCurrency = DocumentCurrency;
				Else
					FillingCurrency = Contract.SettlementsCurrency;
				EndIf;
					
				CurrencyStructure = CurrencyRateOperations.GetCurrencyRate(Date, FillingCurrency, Company);
				ExchangeRate = CurrencyStructure.Rate;
				Multiplicity = CurrencyStructure.Repetition;
				ContractCurrencyExchangeRate = CurrencyStructure.Rate;
				ContractCurrencyMultiplicity = CurrencyStructure.Repetition;
				
			EndIf;
			
			Inventory.Clear();
			TabularSection = ResultsArray[1].Unload();
			For Each TabularSectionSelection In TabularSection Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, TabularSectionSelection);
				NewRow.ProductsTypeInventory = (TabularSectionSelection.ProductsProductsType = Enums.ProductsTypes.InventoryItem);
			EndDo;
			
			Works.Clear();
			TabularSection = ResultsArray[2].Unload();
			StructureTimeNorm = New Structure("Products, Characteristic, ProcessingDate");
			ConnectionKey = 0;
			For Each TabularSectionSelection In TabularSection Do
				
				NewRow = Works.Add();
				FillPropertyValues(NewRow, TabularSectionSelection);
				NewRow.ProductsTypeService = (TabularSectionSelection.ProductsProductsType = Enums.ProductsTypes.Service);
				NewRow.Specification = DriveServer.GetDefaultSpecification(TabularSectionSelection.Products, TabularSectionSelection.Characteristic);
				
				StructureTimeNorm.Products = NewRow.Products;
				StructureTimeNorm.Characteristic = NewRow.Characteristic;
				StructureTimeNorm.ProcessingDate = CurrentSessionDate();
				NewRow.StandardHours = DriveServer.GetWorkTimeRate(StructureTimeNorm);
				
				NewRow.ConnectionKey = ConnectionKey;
				ConnectionKey = ConnectionKey + 1;
				
			EndDo;
			
			If GetFunctionalOption("UseAutomaticDiscounts") Then
				TabularSection = ResultsArray[3].Unload();
				For Each SelectionDiscountsMarkups In TabularSection Do
					FillPropertyValues(DiscountsMarkups.Add(), SelectionDiscountsMarkups);
				EndDo;
			EndIf;
			
			// Bundles
			AddedBundles.Clear();
			TabularSection = ResultsArray[4].Unload();
			For Each TabularSectionSelection In TabularSection Do
				NewRow = AddedBundles.Add();
				FillPropertyValues(NewRow, TabularSectionSelection);
			EndDo;
			// End Bundles
			
			RecalculateSalesTax();
			
			DocumentAmount = Inventory.Total("Total") + Works.Total("Total") + SalesTax.Total("Amount");
			
			// Cash flow projection
			PaymentTermsServer.FillPaymentCalendarFromDocument(ThisObject, FillingData);
			PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(ThisObject);
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.RMARequest") Then
		
		Query = New Query;
		Query.Text =
		"SELECT ALLOWED
		|	ExchangeRateSliceLast.Currency AS Currency,
		|	ExchangeRateSliceLast.Rate AS ExchangeRate,
		|	ExchangeRateSliceLast.Repetition AS Multiplicity
		|INTO TemporaryExchangeRate
		|FROM
		|	InformationRegister.ExchangeRate.SliceLast(&DocumentDate, Company = &Company) AS ExchangeRateSliceLast
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	RMARequest.Ref AS BasisDocument,
		|	RMARequest.Company AS Company,
		|	RMARequest.Contract AS Contract,
		|	RMARequest.Counterparty AS Counterparty,
		|	RMARequest.Department AS SalesStructuralUnit,
		|	RMARequest.Location AS Location,
		|	RMARequest.ContactPerson AS ContactPerson,
		|	RMARequest.Equipment AS Equipment,
		|	RMARequest.SerialNumber AS SerialNumber
		|INTO RMARequestTable
		|FROM
		|	Document.RMARequest AS RMARequest
		|WHERE
		|	RMARequest.Ref = &Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	RMARequestTable.BasisDocument AS BasisDocument,
		|	RMARequestTable.Company AS Company,
		|	RMARequestTable.Contract AS Contract,
		|	RMARequestTable.Counterparty AS Counterparty,
		|	RMARequestTable.SalesStructuralUnit AS SalesStructuralUnit,
		|	RMARequestTable.Location AS Location,
		|	RMARequestTable.ContactPerson AS ContactPerson,
		|	RMARequestTable.Equipment AS Equipment,
		|	RMARequestTable.SerialNumber AS SerialNumber,
		|	ISNULL(CounterpartyContracts.SettlementsCurrency, &PresentationCurrency) AS DocumentCurrency
		|INTO RMARequestWithCurrency
		|FROM
		|	RMARequestTable AS RMARequestTable
		|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
		|		ON RMARequestTable.Contract = CounterpartyContracts.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RMARequestWithCurrency.BasisDocument AS BasisDocument,
		|	RMARequestWithCurrency.Company AS Company,
		|	RMARequestWithCurrency.Contract AS Contract,
		|	RMARequestWithCurrency.Counterparty AS Counterparty,
		|	RMARequestWithCurrency.SalesStructuralUnit AS SalesStructuralUnit,
		|	RMARequestWithCurrency.Location AS Location,
		|	RMARequestWithCurrency.ContactPerson AS ContactPerson,
		|	RMARequestWithCurrency.Equipment AS Equipment,
		|	RMARequestWithCurrency.SerialNumber AS SerialNumber,
		|	RMARequestWithCurrency.DocumentCurrency AS DocumentCurrency,
		|	TemporaryExchangeRate.ExchangeRate AS ExchangeRate,
		|	TemporaryExchangeRate.Multiplicity AS Multiplicity,
		|	TemporaryExchangeRate.ExchangeRate AS ContractCurrencyExchangeRate,
		|	TemporaryExchangeRate.Multiplicity AS ContractCurrencyMultiplicity,
		|	CASE
		|		WHEN RMARequestWithCurrency.Location <> VALUE(Catalog.ShippingAddresses.EmptyRef)
		|			THEN VALUE(Enum.DeliveryOptions.Delivery)
		|		ELSE VALUE(Enum.DeliveryOptions.SelfPickup)
		|	END AS DeliveryOption
		|FROM
		|	RMARequestWithCurrency AS RMARequestWithCurrency
		|		LEFT JOIN TemporaryExchangeRate AS TemporaryExchangeRate
		|		ON RMARequestWithCurrency.DocumentCurrency = TemporaryExchangeRate.Currency";
		
		Query.SetParameter("Ref", FillingData);
		Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
		Query.SetParameter("PresentationCurrency", DriveServer.GetPresentationCurrency(FillingData.Company));
		Query.SetParameter("Company", FillingData.Company);
		
		QueryResults = Query.Execute();
		
		Header = QueryResults.Unload();
		
		If Header.Count() > 0 Then
			
			FillPropertyValues(ThisObject, Header[0]);
			
			PaymentTermsServer.FillPaymentCalendarFromContract(ThisObject);
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure FillTabularSectionPerformersByTeams(ArrayOfTeams, PerformersConnectionKey) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	WorkgroupsContent.Employee AS Employee,
	|	EmployeesSliceLast.Position AS Position,
	|	CASE
	|		WHEN WorkgroupsContent.LPR = 0
	|			THEN 1
	|		ELSE WorkgroupsContent.LPR
	|	END AS LPR,
	|	VALUE(Catalog.PayCodes.Work) AS PayCode
	|FROM
	|	Catalog.Teams.Content AS WorkgroupsContent
	|		LEFT JOIN InformationRegister.Employees.SliceLast(&ToDate, Company = &Company) AS EmployeesSliceLast
	|		ON WorkgroupsContent.Employee = EmployeesSliceLast.Employee
	|WHERE
	|	WorkgroupsContent.Ref IN(&ArrayOfTeams)";
	
	Query.SetParameter("ToDate", Date);
	Query.SetParameter("Company", Company);
	Query.SetParameter("ArrayOfTeams", ArrayOfTeams);
	
	EmployeesTable = Query.Execute().Unload();
	
	If PerformersConnectionKey = Undefined Then
		
		For Each TabularSectionRow In Works Do
			
			If TabularSectionRow.Products.ProductsType = Enums.ProductsTypes.Work Then
				
				For Each TSRow In EmployeesTable Do
					
					NewRow = LaborAssignment.Add();
					FillPropertyValues(NewRow, TSRow);
					NewRow.ConnectionKey = TabularSectionRow.ConnectionKey;
					
				EndDo;
				
			EndIf;
			
		EndDo;
		
	Else
		
		For Each TSRow In EmployeesTable Do
			
			NewRow = LaborAssignment.Add();
			FillPropertyValues(NewRow, TSRow);
			NewRow.ConnectionKey = PerformersConnectionKey;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure GoodsFillColumnReserveByBalances() Export
	
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
	|	&TableInventory AS TableInventory
	|WHERE
	|	TableInventory.ProductsTypeInventory";
	
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
	|				(Company, StructuralUnit, Products, Characteristic, Batch, Ownership) In
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
	|				(Company, StructuralUnit, Products, Characteristic, Batch) In
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
	
	Query.SetParameter("Period", Finish);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnitReserve);
	Query.SetParameter("OwnInventory", Catalogs.InventoryOwnership.OwnInventory());
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		TotalBalance = Selection.QuantityBalance;
		ArrayOfRowsInventory = Inventory.FindRows(StructureForSearch);
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

Procedure MaterialsFillColumnReserveByBalances(MaterialsConnectionKey) Export
	
	If MaterialsConnectionKey = Undefined Then
		Materials.LoadColumn(New Array(Materials.Count()), "Reserve");
	Else
		SearchResult = Materials.FindRows(New Structure("ConnectionKey", MaterialsConnectionKey));
		For Each TabularSectionRow In SearchResult Do
			TabularSectionRow.Reserve = 0;
		EndDo;
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
	|WHERE
	|	CASE
	|			WHEN &SelectionByKeyLinks
	|				THEN TableInventory.ConnectionKey = &ConnectionKey
	|			ELSE TRUE
	|		END";
	
	Query.SetParameter("TableInventory", Materials.Unload());
	Query.SetParameter("SelectionByKeyLinks", ?(MaterialsConnectionKey = Undefined, False, True));
	Query.SetParameter("ConnectionKey", MaterialsConnectionKey);
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
	|		CASE
	|			WHEN DocumentRegisterRecordsReservedProducts.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsReservedProducts.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsReservedProducts.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.ReservedProducts AS DocumentRegisterRecordsReservedProducts
	|	WHERE
	|		DocumentRegisterRecordsReservedProducts.Recorder = &Ref
	|		AND DocumentRegisterRecordsReservedProducts.Period <= &Period
	|		AND DocumentRegisterRecordsReservedProducts.RecordType = VALUE(AccumulationRecordType.Expense)) AS InventoryBalances
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
	Query.SetParameter("StructuralUnit", StructuralUnitReserve);
	Query.SetParameter("OwnInventory", Catalogs.InventoryOwnership.OwnInventory());
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		If MaterialsConnectionKey <> Undefined Then
			StructureForSearch.Insert("ConnectionKey", MaterialsConnectionKey);
		EndIf;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		TotalBalance = Selection.QuantityBalance;
		ArrayOfRowsInventory = Materials.FindRows(StructureForSearch);
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

Procedure RecalculateSalesTax() Export
	
	SalesTax.Clear();
	
	If ValueIsFilled(SalesTaxRate) Then
		
		InventoryTaxable = Inventory.Unload(New Structure("Taxable", True));
		WorksTaxable = Works.Unload(New Structure("Taxable", True));
		AmountTaxable = InventoryTaxable.Total("Total") + WorksTaxable.Total("Total");
		
		If AmountTaxable <> 0 Then
			
			Combined = Common.ObjectAttributeValue(SalesTaxRate, "Combined");
			
			If Combined Then
				
				Query = New Query;
				Query.Text =
				"SELECT
				|	SalesTaxRatesTaxComponents.Component AS SalesTaxRate,
				|	SalesTaxRatesTaxComponents.Rate AS SalesTaxPercentage,
				|	CAST(&AmountTaxable * SalesTaxRatesTaxComponents.Rate / 100 AS NUMBER(15, 2)) AS Amount
				|FROM
				|	Catalog.SalesTaxRates.TaxComponents AS SalesTaxRatesTaxComponents
				|WHERE
				|	SalesTaxRatesTaxComponents.Ref = &Ref";
				
				Query.SetParameter("Ref", SalesTaxRate);
				Query.SetParameter("AmountTaxable", AmountTaxable);
				
				SalesTax.Load(Query.Execute().Unload());
				
			Else
				
				NewRow = SalesTax.Add();
				NewRow.SalesTaxRate = SalesTaxRate;
				NewRow.SalesTaxPercentage = SalesTaxPercentage;
				NewRow.Amount = Round(AmountTaxable * SalesTaxPercentage / 100, 2, RoundMode.Round15as20);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	CalculateInventoryAndWorksSalesTaxAmount();
	
EndProcedure

Procedure CalculateInventoryAndWorksSalesTaxAmount() Export
	
	If Inventory.Count() > 0 Or Works.Count() > 0 Then
		
		InventoryTaxable	= Inventory.Unload(New Structure("Taxable", True));
		WorksTaxable		= Works.Unload(New Structure("Taxable", True));
		TaxableAmount		= InventoryTaxable.Total("Total") + WorksTaxable.Total("Total");
		SalesTaxAmount		= SalesTax.Total("Amount");
		
		LastTaxableRow = Undefined;
		TabularSalesTaxAmount = 0;
		
		For Each Row In Inventory Do
			
			If Row.Taxable And TaxableAmount <> 0 Then
				Row.SalesTaxAmount		= Round(SalesTaxAmount * Row.Total / TaxableAmount, 2, RoundMode.Round15as20);
				LastTaxableRow			= Row;
				TabularSalesTaxAmount	= TabularSalesTaxAmount + Row.SalesTaxAmount;
			Else
				Row.SalesTaxAmount = 0;
			EndIf;
			
		EndDo;
		
		For Each Row In Works Do
			
			If Row.Taxable And TaxableAmount <> 0 Then
				Row.SalesTaxAmount		= Round(SalesTaxAmount * Row.Total / TaxableAmount, 2, RoundMode.Round15as20);
				LastTaxableRow			= Row;
				TabularSalesTaxAmount	= TabularSalesTaxAmount + Row.SalesTaxAmount;
			Else
				Row.SalesTaxAmount = 0;
			EndIf;
			
		EndDo;
		
		If LastTaxableRow <> Undefined And SalesTaxAmount <> TabularSalesTaxAmount Then
			LastTaxableRow.SalesTaxAmount = LastTaxableRow.SalesTaxAmount + SalesTaxAmount - TabularSalesTaxAmount;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlers

Procedure OnCopy(CopiedObject)
	
	Author = Users.CurrentUser();
	
	If Constants.UseWorkOrderStatuses.Get() Then
		SettingValue = DriveReUse.GetValueByDefaultUser(Author, "StatusOfNewWorkOrder");
		If ValueIsFilled(SettingValue) Then
			If OrderState <> SettingValue Then
				OrderState = SettingValue;
			EndIf;
		Else
			OrderState = Catalogs.WorkOrderStatuses.Open;
		EndIf;
	Else
		OrderState = Constants.WorkOrdersInProgressStatus.Get();
	EndIf;
	
	Closed = False;
	
	If SerialNumbersMaterials.Count() Then
		
		For Each MaterialsLine In Materials Do
			MaterialsLine.SerialNumbers = "";
		EndDo;
		
		SerialNumbersMaterials.Clear();
		
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("Structure")
		AND FillingData.Property("Products") Then
		
		Products = FillingData.Products;
		TabularSection = New ValueTable;
		TabularSection.Columns.Add("Products");
		NewRow = TabularSection.Add();
		NewRow.Products = Products;
		
		If Products.ProductsType = Enums.ProductsTypes.InventoryItem Then
			NameTS = "Inventory";
		ElsIf Products.ProductsType = Enums.ProductsTypes.Service
			Or Products.ProductsType = Enums.ProductsTypes.Work Then
			NameTS = "Works";
		Else
			NameTS = "";
		EndIf;
		
		FillingData = New Structure;
		If ValueIsFilled(NameTS) Then
			FillingData.Insert(NameTS, TabularSection);
		EndIf;
		
	EndIf;

	If Common.RefTypeValue(FillingData) Then
		ObjectFillingDrive.FillDocument(ThisObject, FillingData, "FillingHandler");
	Else
		ObjectFillingDrive.FillDocument(ThisObject, FillingData);
	EndIf;
	
	If TypeOf(FillingData) = Type("CatalogRef.Counterparties") Then
		
		PaymentTermsServer.FillPaymentCalendarFromContract(ThisObject);
		
	EndIf;
	
	FillByDefault();
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Closed And OrderState = DriveReUse.GetOrderStatus("WorkOrderStatuses", "Completed") Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'You cannot make changes to a completed %1.'; ru = 'Нельзя вносить изменения в завершенный %1.';pl = 'Nie możesz wprowadzać zmian w zakończeniu %1.';es_ES = 'No se puede modificar %1 cerrada.';es_CO = 'No se puede modificar %1 cerrada.';tr = 'Tamamlanmış bir %1 üzerinde değişiklik yapılamaz.';it = 'Non potete fare modifiche a un %1 completato.';de = 'Sie können keine Änderungen an einem abgeschlossenen %1 vornehmen.'"), Ref);
		CommonClientServer.MessageToUser(MessageText,,,,Cancel);
		Return;
	EndIf;

	If ValueIsFilled(Counterparty)
		AND Not Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(Contract) Then
			Contract = Counterparty.ContractByDefault;
	EndIf;
	
	SubtotalsTable = Inventory.Unload();
	For Each WorkLine In Works Do
		NewLine = SubtotalsTable.Add();
		FillPropertyValues(NewLine, WorkLine);
		NewLine.Quantity = WorkLine.Quantity * WorkLine.StandardHours;
	EndDo;
	
	CalculateInventoryAndWorksSalesTaxAmount();
	
	Totals = DriveServer.CalculateSubtotal(SubtotalsTable, AmountIncludesVAT, SalesTax);
	
	DocumentAmount = Totals.DocumentTotal;
	DocumentTax = Totals.DocumentTax;
	DocumentSubtotal = Totals.DocumentSubtotal;
	
	ChangeDate = CurrentSessionDate();
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
	InventoryOwnershipServer.FillMainTableColumn(ThisObject, WriteMode, Cancel);
	
	If WriteMode = DocumentWriteMode.Posting And QuotationStatuses.CheckQuotationStatusToConverted(BasisDocument) Then
		AdditionalProperties.Insert("QuoteStatusToConverted", True);
	EndIf;
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	Documents.WorkOrder.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	//Limit Exceed Control (if the "Override credit limit settings" it not set)
	If Not OverrideCreditLimitSettings Then
		
		DriveServer.CheckLimitsExceed(ThisObject, True, Cancel);
		
	EndIf;
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryFlowCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectWorkOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectReservedProducts(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTimesheet(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryAccepted(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Serial numbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.WriteRecordSets(ThisObject);
	
	Documents.WorkOrder.RunControl(ThisObject, AdditionalProperties, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	Closed = False;
	
	// Initialization of additional properties to undo document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.WorkOrder.RunControl(ThisObject, AdditionalProperties, Cancel, True);
	
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;
		
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	PostExpensesByWorkOrder = AccountingPolicy.PostExpensesByWorkOrder;
	
	If Not Counterparty.DoOperationsByContracts Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	If OrderState.OrderStatus = Enums.OrderStatuses.InProcess
		OR OrderState.OrderStatus = Enums.OrderStatuses.Completed Then
		
		CheckedAttributes.Add("Start");
		CheckedAttributes.Add("Finish");
		
	EndIf;
	
	If OrderState.OrderStatus = Enums.OrderStatuses.Completed Then
		
		CheckedAttributes.Add("LaborAssignment.Position");
		CheckedAttributes.Add("LaborAssignment.PayCode");
		
	EndIf;
	
	If Materials.Count() > 0 OR Inventory.Count() > 0 Then
		CheckedAttributes.Add("StructuralUnitReserve");
	EndIf;
	
	If Inventory.Total("Reserve") > 0 Then
		
		For Each StringInventory In Inventory Do
		
			If StringInventory.Reserve > 0
			AND Not ValueIsFilled(StructuralUnitReserve) Then
				
				MessageText = NStr("en = 'The reserve warehouse is required.'; ru = 'Не заполнен склад резерва';pl = 'Nie jest wypełniony magazyn rezerwy.';es_ES = 'Se requiere un almacén de reserva.';es_CO = 'Se requiere un almacén de reserva.';tr = 'Yedek ambar gerekiyor.';it = 'È richiesto il magazzino di riserva.';de = 'Das Reservelager ist erforderlich.'");
				DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "StructuralUnitReserve", Cancel);
				
			EndIf;
		
		EndDo;
	
	EndIf;
	
	If Constants.UseInventoryReservation.Get() Then
		
		For Each StringInventory In Inventory Do
			
			If StringInventory.Reserve > StringInventory.Quantity Then	
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The quantity of items to be reserved in line #%1 of the Goods list exceeds the available quantity.'; ru = 'В строке №%1 табл. части ""Товары, услуги"" количество резервируемых позиций превышает общее количество запасов.';pl = 'Ilość pozycji do zarezerwowania w wierszu nr %1 listy Towary przekracza dostępną ilość.';es_ES = 'La cantidad de artículos para reservar en la línea #%1 de la lista Mercancías excede la cantidad disponible.';es_CO = 'La cantidad de artículos para reservar en la línea #%1 de la lista Mercancías excede la cantidad disponible.';tr = 'Mallar listesinin no.%1 satırında rezerve edilecek öğe miktarı mevcut miktarı geçiyor.';it = 'La quantità di elementi che devono essere riservati in linea #%1 delle Merci elenco supera la quantità disponibile.';de = 'Die Menge der zu reservierenden Artikel in der Zeile Nr. %1 der Warenliste übersteigt die verfügbare Menge.'"),
					StringInventory.LineNumber),
					"Inventory",
					StringInventory.LineNumber,
					"Reserve",
					Cancel);
				
			EndIf;
			
		EndDo;
		
		For Each StringInventory In Materials Do
			
			If StringInventory.Reserve > StringInventory.Quantity Then
				
				DriveServer.ShowMessageAboutError(
				ThisObject,
				StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The quantity of items to be reserved in line #%1 of the Materials list exceeds the available quantity.'; ru = 'В строке №%1 табл. части ""Материалы"" количество резервируемых позиций превышает общее количество запасов.';pl = 'Liczba pozycji do zarezerwowania w wierszu nr %1 listy Materiały przekracza dostępną ilość.';es_ES = 'La cantidad de artículos para reservar en la línea #%1 de la lista Materiales excede la cantidad disponible.';es_CO = 'La cantidad de artículos para reservar en la línea #%1 de la lista Materiales excede la cantidad disponible.';tr = 'Malzemeler listesinin %1 numaralı satırında rezerve edilecek öğelerin miktarı mevcut miktarı geçiyor.';it = 'La quantità di elementi che devono essere riservati nella linea #%1 dell''elenco Materiali supera la quantità disponibile.';de = 'Die Menge der zu reservierenden Positionen in der Zeile Nr %1 der Materialliste übersteigt die verfügbare Menge.'"),
				StringInventory.LineNumber),
				"Materials",
				StringInventory.LineNumber,
				"Reserve",
				Cancel);
				
			EndIf;
			
		EndDo;
		
		// Serial numbers
		If OrderState.OrderStatus = Enums.OrderStatuses.Completed And PostExpensesByWorkOrder Then
			WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel,
				Materials,
				SerialNumbersMaterials,
				StructuralUnitReserve,
				ThisObject,
				"ConnectionKeySerialNumbers");
		EndIf;
		
	EndIf;
	
	If Not Constants.UseWorkOrderStatuses.Get() Then
		
		If Not ValueIsFilled(OrderState) Then
			MessageText = NStr("en = 'The order status is required. Specify the available statuses in Accounting settings > Sales.'; ru = 'Поле ""Состояние заказа"" не заполнено. В настройках параметров учета необходимо установить значения состояний.';pl = 'Wymagany jest status zamówienia. Określ dostępne statusy w menu Ustawienia rachunkowości > Sprzedaż.';es_ES = 'Se requiere el estado de orden. Especificar los estados disponibles en Configuraciones de la contabilidad > Ventas.';es_CO = 'Se requiere el estado de orden. Especificar los estados disponibles en Configuraciones de la contabilidad > Ventas.';tr = 'Emir durumu gereklidir. Mevcut durumlar Muhasebe ayarları > Satış altında belirtin.';it = 'Lo stato dell''ordine è necessario. Specificare gli stati disponibili in Contabilità impostazioni > Vendite.';de = 'Der Status von Kundenauftrag ist erforderlich. Geben Sie die verfügbaren Status unter Buchhaltungseinstellungen > Verkauf an.'");
			DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "OrderState", Cancel);
		EndIf;
		
	EndIf;
	
	// 100% discount.
	ThereAreManualDiscounts = GetFunctionalOption("UseManualDiscounts");
	ThereAreAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscounts"); // AutomaticDiscounts
	
	If ThereAreManualDiscounts OR ThereAreAutomaticDiscounts Then
		For Each StringInventory In Inventory Do
			
			// AutomaticDiscounts
			CurAmount					= StringInventory.Price * StringInventory.Quantity;
			ManualDiscountCurAmount		= ?(ThereAreManualDiscounts, ROUND(CurAmount * StringInventory.DiscountMarkupPercent / 100, 2), 0);
			AutomaticDiscountCurAmount	= ?(ThereAreAutomaticDiscounts, StringInventory.AutomaticDiscountAmount, 0);
			CurAmountDiscounts			= ManualDiscountCurAmount + AutomaticDiscountCurAmount;
			
			If StringInventory.DiscountMarkupPercent <> 100 AND CurAmountDiscounts < CurAmount
				AND Not ValueIsFilled(StringInventory.Amount) Then
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Amount is required in line #%1 of the Products list.'; ru = 'Не заполнена колонка ""Сумма"" в строке %1 списка ""Товары, работы, услуги"".';pl = 'W wierszu nr %1 listy Towary wymagana jest kwota.';es_ES = 'Se requiere el importe en la línea #%1 de la lista Productos.';es_CO = 'Se requiere el importe en la línea #%1 de la lista Productos.';tr = 'Tutar ürün listesinin no.%1 satırında gereklidir.';it = 'L''importo è richiesto nella linea #%1 dell''elenco Articoli.';de = 'Der Betrag wird in Zeile Nr %1 der Produktliste benötigt.'"),
						StringInventory.LineNumber),
					"Inventory",
					StringInventory.LineNumber,
					"Amount",
					Cancel);
					
			EndIf;
		EndDo;
	EndIf;
	
	If ThereAreManualDiscounts Then
		For Each WorkRow In Works Do
			
			// AutomaticDiscounts
			CurAmount					= WorkRow.Price * WorkRow.Quantity * WorkRow.StandardHours;
			ManualDiscountCurAmount		= ?(ThereAreManualDiscounts, ROUND(CurAmount * WorkRow.DiscountMarkupPercent / 100, 2), 0);
			AutomaticDiscountCurAmount	= ?(ThereAreAutomaticDiscounts, WorkRow.AutomaticDiscountAmount, 0);
			CurAmountDiscounts			= ManualDiscountCurAmount + AutomaticDiscountCurAmount;
			
			If WorkRow.DiscountMarkupPercent <> 100 AND CurAmountDiscounts < CurAmount
				AND Not ValueIsFilled(WorkRow.Amount) Then
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Amount is required in line #%1 of the Work list.'; ru = 'В строке #%1 списка Работ требуется указать сумму.';pl = 'W wierszu nr %1 listy Praca wymagana jest kwota.';es_ES = 'Se requiere el importe en la línea #%1 de la Lista trabajo.';es_CO = 'Se requiere el importe en la línea #%1 de la Lista trabajo.';tr = 'Tutar İş listesinin no.%1 satırında gereklidir.';it = 'L''importo è richiesto nella linea #%1 dell''elenco lavori.';de = 'Der Betrag wird in der Zeile Nr %1 der Arbeitsliste benötigt.'"),
						WorkRow.LineNumber),
					"Works",
					WorkRow.LineNumber,
					"Amount",
					Cancel);
				
			EndIf;
		EndDo;
	EndIf;
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
	// Also check filling of the employees Earnings
	Documents.WorkOrder.ArePerformersWithEmptyEarningSum(LaborAssignment);
	
	// Bundles
	BundlesServer.CheckTableFilling(ThisObject, "Inventory", Cancel);
	// End Bundles
	
	If OrderState.OrderStatus = Enums.OrderStatuses.Completed And PostExpensesByWorkOrder Then
		BatchesServer.CheckFilling(ThisObject, Cancel);
	EndIf;
	
	// Cash flow projection
	Amount = Inventory.Total("Amount") + Works.Total("Amount") + SalesTax.Total("Amount");
	VATAmount = Inventory.Total("VATAmount") + Works.Total("VATAmount");
	
	PaymentTermsServer.CheckRequiredAttributes(ThisObject, CheckedAttributes, Cancel);
	PaymentTermsServer.CheckCorrectPaymentCalendar(ThisObject, Cancel, Amount, VATAmount);	
	
	// Register expense
	For Each Row In Materials Do
		If Row.RegisterExpense And Not ValueIsFilled(Row.ExpenseItem) Then
			
			ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'On the Materials tab, in line #%1, an expense item is required.'; ru = 'На вкладке ""Материалы"" в строке %1 требуется указать статью расходов.';pl = 'Na karcie materiały, w wierszu nr %1, pozycja rozchodów jest wymagana.';es_ES = 'En la pestaña Materiales, en la línea #%1, se requiere un artículo de gastos.';es_CO = 'En la pestaña Materiales, en la línea #%1, se requiere un artículo de gastos.';tr = 'Malzemeler sekmesinin %1 nolu satırında gider kalemi gerekli.';it = 'Nella scheda Materiali, nella riga #%1, è richiesta una voce di uscita.';de = 'Eine Position von Kosten ist in der Zeile Nr. %1 auf der Registerkarte Materialien erforderlich.'"),
				Row.LineNumber);
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				ErrorMessage,
				"Materials",
				Row.LineNumber,
				"ExpenseItem",
				Cancel);
			
		EndIf;
	EndDo;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
	If AdditionalProperties.Property("QuoteStatusToConverted") And AdditionalProperties.QuoteStatusToConverted Then
		QuotationStatuses.SetQuotationStatus(BasisDocument, Catalogs.QuotationStatuses.Converted);
	EndIf;
	
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, AdditionalProperties.WriteMode, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
		
EndProcedure

#EndRegion

#Region Private

Function QueryTextForFilling()
	
	Text = "SELECT ALLOWED
	       |	Quote.Ref AS BasisDocument,
	       |	Quote.VATTaxation AS VATTaxation,
	       |	Quote.Company AS Company,
		   |	Quote.CompanyVATNumber AS CompanyVATNumber,
	       |	Quote.DiscountCard AS DiscountCard,
	       |	Quote.ExchangeRate AS ExchangeRate,
	       |	Quote.DiscountPercentByDiscountCard AS DiscountPercentByDiscountCard,
	       |	Quote.Multiplicity AS Multiplicity,
	       |	Quote.Contract AS Contract,
	       |	Quote.AmountIncludesVAT AS AmountIncludesVAT,
	       |	Quote.Counterparty AS Counterparty,
	       |	Quote.DocumentCurrency AS DocumentCurrency,
	       |	Quote.BankAccount AS BankAccount,
	       |	Quote.PettyCash AS PettyCash,
	       |	Quote.PaymentMethod AS PaymentMethod,
	       |	Quote.DiscountsAreCalculated AS DiscountsAreCalculated,
	       |	Quote.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	       |	Quote.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	       |	Quote.CashAssetType AS CashAssetType,
	       |	Quote.PriceKind AS PriceKind,
	       |	Quote.SalesTaxRate AS SalesTaxRate,
	       |	Quote.SalesTaxPercentage AS SalesTaxPercentage
	       |FROM
	       |	Document.Quote AS Quote
	       |WHERE
	       |	Quote.Ref = &Parameter
	       |;
	       |
	       |////////////////////////////////////////////////////////////////////////////////
	       |SELECT ALLOWED
	       |	QuoteInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	       |	QuoteInventory.Amount AS Amount,
	       |	QuoteInventory.Products AS Products,
	       |	QuoteInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	       |	QuoteInventory.Products.ProductsType AS ProductsProductsType,
	       |	QuoteInventory.Characteristic AS Characteristic,
	       |	QuoteInventory.Price AS Price,
	       |	QuoteInventory.Content AS Content,
	       |	QuoteInventory.Quantity AS Quantity,
	       |	QuoteInventory.MeasurementUnit AS MeasurementUnit,
	       |	QuoteInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	       |	QuoteInventory.VATRate AS VATRate,
	       |	QuoteInventory.VATAmount AS VATAmount,
	       |	QuoteInventory.Total AS Total,
	       |	QuoteInventory.ConnectionKey AS ConnectionKey,
	       |	QuoteInventory.BundleProduct AS BundleProduct,
	       |	QuoteInventory.BundleCharacteristic AS BundleCharacteristic,
	       |	QuoteInventory.CostShare AS CostShare,
	       |	QuoteInventory.Taxable AS Taxable
	       |FROM
	       |	Document.Quote.Inventory AS QuoteInventory
	       |		INNER JOIN Catalog.Products AS ProductsTable
	       |		ON QuoteInventory.Products = ProductsTable.Ref
	       |		INNER JOIN Document.Quote AS Quote
	       |		ON QuoteInventory.Ref = Quote.Ref
	       |			AND QuoteInventory.Variant = Quote.PreferredVariant
	       |WHERE
	       |	QuoteInventory.Ref = &Parameter
	       |	AND ProductsTable.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	       |;
	       |
	       |////////////////////////////////////////////////////////////////////////////////
	       |SELECT ALLOWED
	       |	QuoteInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	       |	QuoteInventory.Amount AS Amount,
	       |	QuoteInventory.Products AS Products,
	       |	QuoteInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	       |	QuoteInventory.Products.ProductsType AS ProductsProductsType,
	       |	QuoteInventory.Characteristic AS Characteristic,
	       |	QuoteInventory.Price AS Price,
	       |	QuoteInventory.Content AS Content,
	       |	QuoteInventory.Quantity AS Quantity,
	       |	QuoteInventory.MeasurementUnit AS MeasurementUnit,
	       |	QuoteInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	       |	QuoteInventory.VATRate AS VATRate,
	       |	QuoteInventory.VATAmount AS VATAmount,
	       |	QuoteInventory.Total AS Total,
	       |	QuoteInventory.ConnectionKey AS ConnectionKey,
	       |	QuoteInventory.Taxable AS Taxable
	       |FROM
	       |	Document.Quote.Inventory AS QuoteInventory
	       |		INNER JOIN Catalog.Products AS ProductsTable
	       |		ON QuoteInventory.Products = ProductsTable.Ref
	       |		INNER JOIN Document.Quote AS Quote
	       |		ON QuoteInventory.Ref = Quote.Ref
	       |			AND QuoteInventory.Variant = Quote.PreferredVariant
	       |WHERE
	       |	QuoteInventory.Ref = &Parameter
	       |	AND (ProductsTable.ProductsType = VALUE(Enum.ProductsTypes.Service)
	       |			OR ProductsTable.ProductsType = VALUE(Enum.ProductsTypes.Work))
	       |;
	       |
	       |////////////////////////////////////////////////////////////////////////////////
	       |SELECT ALLOWED
	       |	QuoteDiscountsMarkups.ConnectionKey AS ConnectionKey,
	       |	QuoteDiscountsMarkups.DiscountMarkup AS DiscountMarkup,
	       |	QuoteDiscountsMarkups.Amount AS Amount
	       |FROM
	       |	Document.Quote.DiscountsMarkups AS QuoteDiscountsMarkups
	       |WHERE
	       |	QuoteDiscountsMarkups.Ref = &Parameter
	       |;
	       |
	       |////////////////////////////////////////////////////////////////////////////////
	       |SELECT ALLOWED
	       |	QuoteAddedBundles.BundleProduct AS BundleProduct,
	       |	QuoteAddedBundles.BundleCharacteristic AS BundleCharacteristic,
	       |	QuoteAddedBundles.Quantity AS Quantity
	       |FROM
	       |	Document.Quote.AddedBundles AS QuoteAddedBundles
	       |WHERE
	       |	QuoteAddedBundles.Ref = &Parameter";
	
	Return Text;
	
EndFunction

Procedure FillByDefault()

	If Constants.UseWorkOrderStatuses.Get() Then
		SettingValue = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "StatusOfNewWorkOrder");
		If ValueIsFilled(SettingValue) Then
			If OrderState <> SettingValue Then
				OrderState = SettingValue;
			EndIf;
		Else
			OrderState = Catalogs.WorkOrderStatuses.Open;
		EndIf;
	Else
		OrderState = Constants.WorkOrdersInProgressStatus.Get();
	EndIf;

EndProcedure

#EndRegion

#EndIf
