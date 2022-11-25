#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure FillByCreditNote(FillingData) Export
	
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("ArrayOfCreditNotes") Then
		ArrayOfCreditNotes = FillingData.ArrayOfCreditNotes;
	Else
		ArrayOfCreditNotes = New Array;
		ArrayOfCreditNotes.Add(FillingData);
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	CreditNote.Ref AS BasisRef,
	|	CreditNote.Posted AS BasisPosted,
	|	CreditNote.Company AS Company,
	|	CreditNote.CompanyVATNumber AS CompanyVATNumber,
	|	CreditNote.StructuralUnit AS StructuralUnit,
	|	CreditNote.Counterparty AS Counterparty,
	|	CreditNote.Contract AS Contract,
	|	VALUE(Enum.OperationTypesGoodsReceipt.SalesReturn) AS OperationType,
	|	CreditNote.DocumentCurrency AS DocumentCurrency,
	|	CreditNote.ExchangeRate AS ExchangeRate,
	|	CreditNote.Multiplicity AS Multiplicity,
	|	CreditNote.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	CreditNote.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	CreditNote.Cell AS Cell
	|FROM
	|	Document.CreditNote AS CreditNote
	|WHERE
	|	CreditNote.Ref IN(&ArrayOfCreditNotes)";
	
	Query.SetParameter("ArrayOfCreditNotes", ArrayOfCreditNotes);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	FillPropertyValues(ThisObject, Selection);
	
	If Not ValueIsFilled(StructuralUnit) Then
		SettingValue = DriveReUse.GetValueOfSetting("MainWarehouse");
		If Not ValueIsFilled(SettingValue) Then
			StructuralUnit = Catalogs.BusinessUnits.MainWarehouse;
		EndIf;
	EndIf;
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Date", CurrentSessionDate());
	DocumentData.Insert("ThisObject", ThisObject);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	DocumentData.Insert("AmountIncludesVAT", AmountIncludesVAT);
	
	Documents.GoodsReceipt.FillByCreditNotes(DocumentData, New Structure("ArrayOfCreditNotes", ArrayOfCreditNotes), Products, SerialNumbers);
	
	OrdersTable = Products.Unload(, "Order, Contract");
	OrdersTable.GroupBy("Order, Contract");
	
	If OrdersTable.Count() > 1 Then
		SalesOrderPosition = Enums.AttributeStationing.InTabularSection;
	Else
		SalesOrderPosition = DriveReUse.GetValueOfSetting("SalesOrderPositionInShipmentDocuments");
		If Not ValueIsFilled(OrderPosition) Then
			SalesOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
	EndIf;
	
	If SalesOrderPosition = Enums.AttributeStationing.InTabularSection Then
		Order = Undefined;
		Contract = Undefined;
	ElsIf OrdersTable.Count() > 0 Then
		
		If Not ValueIsFilled(Order) Then
			Order = OrdersTable[0].Order;
		EndIf;
		
		If Not ValueIsFilled(Contract) Then
			Contract = OrdersTable[0].Contract;
		EndIf;
		
	EndIf;
	
	If Products.Count() = 0 Then
		If ArrayOfCreditNotes.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 has already been received.'; ru = 'Уже получено: %1';pl = '%1 został już odebrany.';es_ES = '%1 ha sido recibido ya.';es_CO = '%1 ha sido recibido ya.';tr = '%1 zaten teslim alındı.';it = '%1 è già stato ricevuto.';de = '%1 wurde bereits eingegangen.'"),
				ArrayOfCreditNotes[0]);
		Else
			MessageText = NStr("en = 'The selected credit notes have already been received.'; ru = 'Выбранные кредитовые авизо уже получены.';pl = 'Wybrane noty kredytowe już zostały otrzymane.';es_ES = 'Las notas de crédito seleccionadas ya se han recibido.';es_CO = 'Las notas de crédito seleccionadas ya se han recibido.';tr = 'Seçilen alacak dekontları zaten teslim alındı.';it = 'Le note di credito selezionato sono già state ricevute.';de = 'Die ausgewählten Gutschriften sind bereits eingegangen.'");
		EndIf;
		CommonClientServer.MessageToUser(MessageText, Ref);
	EndIf;

EndProcedure

Procedure FillByPurchaseOrder(FillingData) Export
	
	// Document basis and document setting.
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("OrdersArray") Then
		OrdersArray = FillingData.OrdersArray;
	Else
		OrdersArray = New Array;
		OrdersArray.Add(FillingData);
		Order = FillingData;
	EndIf;
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	ExchangeRatesSliceLast.Currency AS Currency,
	|	ExchangeRatesSliceLast.Company AS Company,
	|	ExchangeRatesSliceLast.Rate AS ExchangeRate,
	|	ExchangeRatesSliceLast.Repetition AS Multiplicity
	|INTO TemporaryTableExchangeRatesSliceLatest
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS ExchangeRatesSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PurchaseOrder.Ref AS BasisRef,
	|	PurchaseOrder.Posted AS BasisPosted,
	|	PurchaseOrder.Closed AS Closed,
	|	PurchaseOrder.OrderState AS OrderState,
	|	PurchaseOrder.Company AS Company,
	|	PurchaseOrder.CompanyVATNumber AS CompanyVATNumber,
	|	PurchaseOrder.StructuralUnitReserve AS StructuralUnit,
	|	PurchaseOrder.Counterparty AS Counterparty,
	|	PurchaseOrder.Contract AS Contract,
	|	PurchaseOrder.DocumentCurrency AS DocumentCurrency,
	|	PurchaseOrder.VATTaxation AS VATTaxation,
	|	PurchaseOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	PurchaseOrder.IncludeVATInPrice AS IncludeVATInPrice,
	|	PurchaseOrder.DiscountType AS DiscountType,
	|	PurchaseOrder.OperationKind AS OperationKind
	|INTO TT_PurchaseOrders
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|WHERE
	|	PurchaseOrder.Ref IN(&OrdersArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TT_PurchaseOrders.BasisRef AS BasisRef,
	|	TT_PurchaseOrders.BasisPosted AS BasisPosted,
	|	TT_PurchaseOrders.Closed AS Closed,
	|	TT_PurchaseOrders.OrderState AS OrderState,
	|	TT_PurchaseOrders.Company AS Company,
	|	TT_PurchaseOrders.CompanyVATNumber AS CompanyVATNumber,
	|	TT_PurchaseOrders.StructuralUnit AS StructuralUnit,
	|	TT_PurchaseOrders.Counterparty AS Counterparty,
	|	TT_PurchaseOrders.Contract AS Contract,
	|	TT_PurchaseOrders.DocumentCurrency AS DocumentCurrency,
	|	TT_PurchaseOrders.VATTaxation AS VATTaxation,
	|	TT_PurchaseOrders.AmountIncludesVAT AS AmountIncludesVAT,
	|	TT_PurchaseOrders.IncludeVATInPrice AS IncludeVATInPrice,
	|	ISNULL(CounterpartyContracts.SettlementsCurrency, VALUE(Catalog.Currencies.EmptyRef)) AS SettlementsCurrency,
	|	TT_PurchaseOrders.DiscountType AS DiscountType,
	|	TT_PurchaseOrders.OperationKind AS OperationKind
	|INTO TT_PurchaseOrdersCurrency
	|FROM
	|	TT_PurchaseOrders AS TT_PurchaseOrders
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON TT_PurchaseOrders.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_PurchaseOrdersCurrency.BasisRef AS BasisRef,
	|	TT_PurchaseOrdersCurrency.BasisPosted AS BasisPosted,
	|	TT_PurchaseOrdersCurrency.Closed AS Closed,
	|	TT_PurchaseOrdersCurrency.OrderState AS OrderState,
	|	TT_PurchaseOrdersCurrency.Company AS Company,
	|	TT_PurchaseOrdersCurrency.CompanyVATNumber AS CompanyVATNumber,
	|	TT_PurchaseOrdersCurrency.StructuralUnit AS StructuralUnit,
	|	TT_PurchaseOrdersCurrency.Counterparty AS Counterparty,
	|	TT_PurchaseOrdersCurrency.Contract AS Contract,
	|	CASE
	|		WHEN TT_PurchaseOrdersCurrency.OperationKind = VALUE(Enum.OperationTypesPurchaseOrder.OrderForDropShipping)
	|			THEN VALUE(Enum.OperationTypesGoodsReceipt.DropShipping)
	|		ELSE VALUE(Enum.OperationTypesGoodsReceipt.PurchaseFromSupplier)
	|	END AS OperationType,
	|	TT_PurchaseOrdersCurrency.DocumentCurrency AS DocumentCurrency,
	|	TT_PurchaseOrdersCurrency.VATTaxation AS VATTaxation,
	|	TT_PurchaseOrdersCurrency.AmountIncludesVAT AS AmountIncludesVAT,
	|	TT_PurchaseOrdersCurrency.IncludeVATInPrice AS IncludeVATInPrice,
	|	ISNULL(ExchangeRatesSliceLast.ExchangeRate, 1) AS ExchangeRate,
	|	ISNULL(ExchangeRatesSliceLast.Multiplicity, 1) AS Multiplicity,
	|	ISNULL(SettlementsExchangeRatesSliceLast.ExchangeRate, 1) AS ContractCurrencyExchangeRate,
	|	ISNULL(SettlementsExchangeRatesSliceLast.Multiplicity, 1) AS ContractCurrencyMultiplicity,
	|	TT_PurchaseOrdersCurrency.DiscountType AS DiscountType
	|FROM
	|	TT_PurchaseOrdersCurrency AS TT_PurchaseOrdersCurrency
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ExchangeRatesSliceLast
	|		ON TT_PurchaseOrdersCurrency.DocumentCurrency = ExchangeRatesSliceLast.Currency
	|			AND TT_PurchaseOrdersCurrency.Company = ExchangeRatesSliceLast.Company
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS SettlementsExchangeRatesSliceLast
	|		ON TT_PurchaseOrdersCurrency.SettlementsCurrency = SettlementsExchangeRatesSliceLast.Currency
	|			AND TT_PurchaseOrdersCurrency.Company = SettlementsExchangeRatesSliceLast.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	GoodsInvoicedNotReceived.SupplierInvoice AS SupplierInvoice
	|FROM
	|	TT_PurchaseOrdersCurrency AS TT_PurchaseOrdersCurrency
	|		INNER JOIN AccumulationRegister.GoodsInvoicedNotReceived AS GoodsInvoicedNotReceived
	|		ON TT_PurchaseOrdersCurrency.BasisRef = GoodsInvoicedNotReceived.PurchaseOrder";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	
	QueryResults = Query.ExecuteBatch();
	
	Selection = QueryResults[3].Select();
	While Selection.Next() Do
		VerifiedAttributesValues = New Structure("OrderState, Closed, Posted", Selection.OrderState, Selection.Closed, Selection.BasisPosted);
		Documents.PurchaseOrder.CheckEnteringAbilityOnTheBasisOfVendorOrder(Selection.BasisRef, VerifiedAttributesValues);
	EndDo;
	
	FillPropertyValues(ThisObject, Selection);
	
	If Not ValueIsFilled(StructuralUnit) Then
		SettingValue = DriveReUse.GetValueOfSetting("MainWarehouse");
		If Not ValueIsFilled(SettingValue) Then
			StructuralUnit = Catalogs.BusinessUnits.MainWarehouse;
		EndIf;
	EndIf;
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	DocumentData.Insert("AmountIncludesVAT", AmountIncludesVAT);
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	DocumentData.Insert("ContinentalMethod", AccountingPolicy.ContinentalMethod);
	DocumentData.Insert("OperationType", OperationType);
	
	Documents.GoodsReceipt.FillByPurchaseOrders(DocumentData, New Structure("OrdersArray", OrdersArray), Products);
	
	InvoicesArray = QueryResults[4].Unload().UnloadColumn("SupplierInvoice");
	If InvoicesArray.Count() Then
		
		InvoicedProducts = Products.UnloadColumns();
		Documents.GoodsReceipt.FillBySupplierInvoices(DocumentData, New Structure("InvoicesArray", InvoicesArray), InvoicedProducts);
		
		For Each InvoicedProductsRow In InvoicedProducts Do
			If Not OrdersArray.Find(InvoicedProductsRow.Order) = Undefined Then
				FillPropertyValues(Products.Add(), InvoicedProductsRow);
			EndIf;
		EndDo;
		
	EndIf;
	
	DiscountsAreCalculated = False;
	
	OrdersTable = Products.Unload(, "Order, Contract");
	OrdersTable.GroupBy("Order, Contract");
	If OrdersTable.Count() > 1 Then
		OrderPosition = Enums.AttributeStationing.InTabularSection;
	Else
		OrderPosition = DriveReUse.GetValueOfSetting("PurchaseOrderPositionInReceiptDocuments");
		If Not ValueIsFilled(OrderPosition) Then
			OrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
	EndIf;
	
	If OrderPosition = Enums.AttributeStationing.InTabularSection Then
		Order = Undefined;
		Contract = Undefined;
	ElsIf Not ValueIsFilled(Order) Then
		
		If OrdersTable.Count() > 0 Then
			Order = OrdersTable[0].Order;
			Contract = OrdersTable[0].Contract;
		ElsIf OrdersArray.Count() > 0 Then
			Order = OrdersArray[0];
		EndIf;
		
	EndIf;
	
	If Products.Count() = 0 Then
		If OrdersArray.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 has already been received.'; ru = 'Уже получено: %1';pl = '%1 został już odebrany.';es_ES = '%1 ha sido recibido ya.';es_CO = '%1 ha sido recibido ya.';tr = '%1 zaten teslim alındı';it = '%1 è già stato ricevuto.';de = '%1 wurde bereits eingegangen.'"),
				OrdersArray[0]);
		Else
			MessageText = NStr("en = 'The selected orders have already been received.'; ru = 'Выбранные заказы уже получены.';pl = 'Wybrane zamówienia zostały już odebrane.';es_ES = 'Las órdenes seleccionadas han sido recibidas ya.';es_CO = 'Las órdenes seleccionadas han sido recibidas ya.';tr = 'Seçilen siparişler zaten alındı.';it = 'Gli ordini selezionati sono già stati ricevuti.';de = 'Die ausgewählten Aufträge sind bereits eingegangen.'");
		EndIf;
		CommonClientServer.MessageToUser(MessageText, Ref);
	EndIf;
	
EndProcedure

Procedure FillBySalesInvoice(FillingData) Export
	
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("ArrayOfSalesInvoices") Then
		InvoicesArray = FillingData.ArrayOfSalesInvoices;
	Else
		InvoicesArray = New Array;
		InvoicesArray.Add(FillingData);
		Order = FillingData;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	SalesInvoice.Ref AS BasisRef,
	|	SalesInvoice.Posted AS BasisPosted,
	|	SalesInvoice.Company AS Company,
	|	SalesInvoice.CompanyVATNumber AS CompanyVATNumber,
	|	SalesInvoice.StructuralUnit AS StructuralUnit,
	|	SalesInvoice.Counterparty AS Counterparty,
	|	SalesInvoice.Contract AS Contract,
	|	SalesInvoice.DocumentCurrency AS DocumentCurrency,
	|	SalesInvoice.ExchangeRate AS ExchangeRate,
	|	SalesInvoice.Multiplicity AS Multiplicity,
	|	SalesInvoice.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	SalesInvoice.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	SalesInvoice.VATTaxation AS VATTaxation,
	|	SalesInvoice.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesInvoice.IncludeVATInPrice AS IncludeVATInPrice,
	|	VALUE(Enum.OperationTypesGoodsReceipt.SalesReturn) AS OperationType,
	|	SalesInvoice.Cell AS Cell
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Ref IN(&InvoicesArray)";
	
	Query.SetParameter("InvoicesArray", InvoicesArray);
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	FillPropertyValues(ThisObject, Selection);
	
	If Not ValueIsFilled(StructuralUnit) Then
		SettingValue = DriveReUse.GetValueOfSetting("MainWarehouse");
		If Not ValueIsFilled(SettingValue) Then
			StructuralUnit = Catalogs.BusinessUnits.MainWarehouse;
		EndIf;
	EndIf;
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Date", CurrentSessionDate());
	DocumentData.Insert("ThisObject",ThisObject);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	
	Documents.GoodsReceipt.FillBySalesInvoices(DocumentData, New Structure("SalesInvoicesArray", InvoicesArray), Products, SerialNumbers);
	
	OrdersTable = Products.Unload(, "Order, Contract");
	OrdersTable.GroupBy("Order, Contract");
	If OrdersTable.Count() > 1 Then
		SalesOrderPosition = Enums.AttributeStationing.InTabularSection;
	Else
		SalesOrderPosition = DriveReUse.GetValueOfSetting("SalesOrderPositionInShipmentDocuments");
		If Not ValueIsFilled(OrderPosition) Then
			SalesOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
	EndIf;
	
	If SalesOrderPosition = Enums.AttributeStationing.InTabularSection Then
		Order = Undefined;
		Contract = Undefined;
	ElsIf Not ValueIsFilled(Order) Then
		If OrdersTable.Count() > 0 Then
			Order = OrdersTable[0].Order;
			Contract = OrdersTable[0].Contract;
		EndIf;
	EndIf;
	
	If Products.Count() = 0 Then
		If InvoicesArray.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 has already been received.'; ru = 'Уже получено: %1';pl = '%1 został już odebrany.';es_ES = '%1 ha sido recibido ya.';es_CO = '%1 ha sido recibido ya.';tr = '%1 zaten teslim alındı';it = '%1 è già stato ricevuto.';de = '%1 wurde bereits eingegangen.'"),
				InvoicesArray[0]);
		Else
			MessageText = NStr("en = 'The selected invoices have already been received.'; ru = 'Товар по выбранным инвойсам уже получен.';pl = 'Wybrane faktury zostały już odebrane.';es_ES = 'Las facturas recibidas han sido recibidas ya.';es_CO = 'Las facturas recibidas han sido recibidas ya.';tr = 'Seçilen faturalar zaten alındı.';it = 'Le fatture selezionate sono già state ricevute.';de = 'Die ausgewählten Rechnungen sind bereits eingegangen.'");
		EndIf;
		Raise MessageText;
	EndIf;
	
EndProcedure

Procedure FillBySupplierInvoice(FillingData) Export
	
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("InvoicesArray") Then
		InvoicesArray = FillingData.InvoicesArray;
	Else
		InvoicesArray = New Array;
		InvoicesArray.Add(FillingData);
		Order = FillingData;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	SupplierInvoice.Ref AS BasisRef,
	|	SupplierInvoice.Posted AS BasisPosted,
	|	SupplierInvoice.Company AS Company,
	|	SupplierInvoice.CompanyVATNumber AS CompanyVATNumber,
	|	SupplierInvoice.StructuralUnit AS StructuralUnit,
	|	SupplierInvoice.Counterparty AS Counterparty,
	|	SupplierInvoice.Contract AS Contract,
	|	CASE
	|		WHEN SupplierInvoice.OperationKind = VALUE(Enum.OperationTypesSupplierInvoice.DropShipping)
	|			THEN VALUE(Enum.OperationTypesGoodsReceipt.DropShipping)
	|		ELSE VALUE(Enum.OperationTypesGoodsReceipt.PurchaseFromSupplier)
	|	END AS OperationType,
	|	SupplierInvoice.DiscountType AS DiscountType
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	SupplierInvoice.Ref IN(&InvoicesArray)";
	
	Query.SetParameter("InvoicesArray", InvoicesArray);
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		VerifiedAttributesValues = New Structure("Posted", Selection.BasisPosted);
		Documents.SupplierInvoice.CheckAbilityOfEnteringBySupplierInvoice(Selection.BasisRef, VerifiedAttributesValues);
	EndDo;
	
	FillPropertyValues(ThisObject, Selection);
	
	If Not ValueIsFilled(StructuralUnit) Then
		SettingValue = DriveReUse.GetValueOfSetting("MainWarehouse");
		If Not ValueIsFilled(SettingValue) Then
			StructuralUnit = Catalogs.BusinessUnits.MainWarehouse;
		EndIf;
	EndIf;
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	DocumentData.Insert("ContinentalMethod", AccountingPolicy.ContinentalMethod);
	DocumentData.Insert("OperationType", OperationType);
	
	Documents.GoodsReceipt.FillBySupplierInvoices(DocumentData, New Structure("InvoicesArray", InvoicesArray), Products);
	
	DiscountsAreCalculated = False;
	
	OrdersTable = Products.Unload(, "Order, Contract");
	OrdersTable.GroupBy("Order, Contract");
	If OrdersTable.Count() > 1 Then
		OrderPosition = Enums.AttributeStationing.InTabularSection;
	Else
		OrderPosition = DriveReUse.GetValueOfSetting("PurchaseOrderPositionInReceiptDocuments");
		If Not ValueIsFilled(OrderPosition) Then
			OrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
	EndIf;
	
	If OrderPosition = Enums.AttributeStationing.InTabularSection Then
		Order = Undefined;
		Contract = Undefined;
	ElsIf Not ValueIsFilled(Order) Then
		If OrdersTable.Count() > 0 Then
			Order = OrdersTable[0].Order;
			Contract = OrdersTable[0].Contract;
		EndIf;
	EndIf;
	
	If Products.Count() = 0 Then
		If InvoicesArray.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 has already been received.'; ru = 'Уже получено: %1';pl = '%1 został już odebrany.';es_ES = '%1 ha sido recibido ya.';es_CO = '%1 ha sido recibido ya.';tr = '%1 zaten teslim alındı';it = '%1 è già stato ricevuto.';de = '%1 wurde bereits eingegangen.'"),
				InvoicesArray[0]);
		Else
			MessageText = NStr("en = 'The selected invoices have already been received.'; ru = 'Товар по выбранным инвойсам уже получен.';pl = 'Wybrane faktury zostały już odebrane.';es_ES = 'Las facturas recibidas han sido recibidas ya.';es_CO = 'Las facturas recibidas han sido recibidas ya.';tr = 'Seçilen faturalar zaten alındı.';it = 'Le fatture selezionate sono già state ricevute.';de = 'Die ausgewählten Rechnungen sind bereits eingegangen.'");
		EndIf;
		Raise MessageText;
	EndIf;
	
EndProcedure

Procedure FillByRMARequest(FillingData) Export
	
	RMARequestArray = New Array;
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("RMARequestArray") Then
		RMARequestArray = FillingData.RMARequestArray;
	Else
		RMARequestArray.Add(FillingData.Ref);
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	RMARequest.Ref AS BasisDocument,
	|	RMARequest.Company AS Company,
	|	RMARequest.Department AS Department,
	|	RMARequest.Counterparty AS Counterparty,
	|	RMARequest.Contract AS Contract,
	|	VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromAThirdParty) AS OperationType,
	|	RMARequest.Equipment AS Equipment,
	|	RMARequest.Characteristic AS Characteristic,
	|	RMARequest.SerialNumber AS SerialNumber
	|INTO RMARequestTable
	|FROM
	|	Document.RMARequest AS RMARequest
	|WHERE
	|	RMARequest.Ref IN(&RMARequestArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RMARequestTable.Company AS Company,
	|	RMARequestTable.Department AS Department,
	|	RMARequestTable.Counterparty AS Counterparty,
	|	RMARequestTable.Contract AS Contract,
	|	RMARequestTable.OperationType AS OperationType
	|FROM
	|	RMARequestTable AS RMARequestTable
	|
	|GROUP BY
	|	RMARequestTable.Department,
	|	RMARequestTable.Counterparty,
	|	RMARequestTable.Contract,
	|	RMARequestTable.OperationType,
	|	RMARequestTable.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RMARequestTable.BasisDocument AS BasisDocument,
	|	RMARequestTable.Contract AS Contract,
	|	RMARequestTable.Equipment AS Products,
	|	RMARequestTable.Characteristic AS Characteristic,
	|	RMARequestTable.SerialNumber AS SerialNumber,
	|	Products.MeasurementUnit AS MeasurementUnit,
	|	1 AS Quantity,
	|	Products.UseSerialNumbers AS UseSerialNumbers,
	|	Products.VATRate AS VATRAte
	|FROM
	|	RMARequestTable AS RMARequestTable
	|		INNER JOIN Catalog.Products AS Products
	|		ON RMARequestTable.Equipment = Products.Ref";
	
	Query.SetParameter("RMARequestArray", RMARequestArray);
	
	QueryResult = Query.ExecuteBatch();
	
	Header = QueryResult[1].Unload();
	
	If Header.Count() > 0 Then
		
		FillPropertyValues(ThisObject, Header[0]);
		
		If Not ValueIsFilled(StructuralUnit) Then
			SettingValue = DriveReUse.GetValueOfSetting("MainWarehouse");
			If Not ValueIsFilled(SettingValue) Then
				StructuralUnit = Catalogs.BusinessUnits.MainWarehouse;
			EndIf;
		EndIf;
		
		Products.Clear();
		SerialNumbers.Clear();
		
		ProductsTable = QueryResult[2].Unload();
		
		If ProductsTable.Count() > 0 Then
			
			For Each RowProductsTable In ProductsTable Do
				
				ProductsRow = Products.Add();
				
				FillPropertyValues(ProductsRow, RowProductsTable);
				
				If RowProductsTable.UseSerialNumbers AND ValueIsFilled(RowProductsTable.SerialNumber) Then
					
					WorkWithSerialNumbersClientServer.FillConnectionKey(Products, ProductsRow, "ConnectionKey");
					WorkWithSerialNumbers.AddRowByConnectionKeyAndSerialNumber(ThisObject, Undefined, ProductsRow.ConnectionKey, RowProductsTable.SerialNumber);
					
					ProductsRow.SerialNumbers = WorkWithSerialNumbers.StringSerialNumbers(SerialNumbers, ProductsRow.ConnectionKey);
					
				EndIf;
				
			EndDo;
			
			ContractTable = Products.Unload(, "Contract");
			ContractTable.GroupBy("Contract");
			
			If ContractTable.Count() > 1 Then
				OrderPosition = Enums.AttributeStationing.InTabularSection;
			Else
				OrderPosition = Enums.AttributeStationing.InHeader;
			EndIf;
			
			If OrderPosition = Enums.AttributeStationing.InTabularSection Then
				
				Contract = Undefined;
				
			ElsIf NOT ValueIsFilled(Contract) Then
				
				If ContractTable.Count() > 0 Then
					Contract = ContractTable[0].Contract;
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure FillBySalesOrder(FillingData) Export
	
	Order = FillingData;
	
	AttributeValues = Common.ObjectAttributesValues(FillingData, 
			New Structure("Company, CompanyVATNumber, Ref, OperationKind, Counterparty, Contract, OrderState, Closed, Posted"));
	
	AttributeValues.Insert("WorkOrderReturn");
	AttributeValues.Insert("GoodsReceipt");
	
	Documents.SalesOrder.CheckAbilityOfEnteringBySalesOrder(FillingData, AttributeValues);
	
	FillPropertyValues(ThisObject, AttributeValues, "Company, CompanyVATNumber, Counterparty, Contract");
	
	Products.Clear();
	If AttributeValues.OperationKind = Enums.OperationTypesSalesOrder.OrderForProcessing Then
		OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromAThirdParty;
		FillBySalesOrderForProcessing(FillingData);
	EndIf;
	
EndProcedure

Procedure FillBySalesOrderForProcessing(FillingData)
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	DemandBalances.Products AS Products,
	|	DemandBalances.Characteristic AS Characteristic,
	|	SUM(DemandBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		DemandBalances.Products AS Products,
	|		DemandBalances.Characteristic AS Characteristic,
	|		DemandBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.InventoryDemand.Balance(
	|				,
	|				SalesOrder = &BasisDocument
	|					AND MovementType = VALUE(Enum.InventoryMovementTypes.Receipt)) AS DemandBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventoryDemand.Products,
	|		DocumentRegisterRecordsInventoryDemand.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventoryDemand.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.InventoryDemand AS DocumentRegisterRecordsInventoryDemand
	|	WHERE
	|		DocumentRegisterRecordsInventoryDemand.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventoryDemand.SalesOrder = &BasisDocument) AS DemandBalances
	|
	|GROUP BY
	|	DemandBalances.Products,
	|	DemandBalances.Characteristic
	|
	|HAVING
	|	SUM(DemandBalances.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.Company AS Company
	|INTO TT_SalesOrders
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	MIN(SalesOrderConsumerMaterials.LineNumber) AS LineNumber,
	|	SalesOrderConsumerMaterials.Products AS Products,
	|	SalesOrderConsumerMaterials.Characteristic AS Characteristic,
	|	SalesOrderConsumerMaterials.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	SalesOrderConsumerMaterials.Ref AS Order,
	|	SalesOrderConsumerMaterials.Ref AS BasisDocument,
	|	SUM(SalesOrderConsumerMaterials.Quantity) AS Quantity,
	|	ProductsCatalog.VATRate AS VATRate
	|FROM
	|	TT_SalesOrders AS TT_SalesOrders
	|		INNER JOIN Document.SalesOrder.ConsumerMaterials AS SalesOrderConsumerMaterials
	|		ON TT_SalesOrders.Ref = SalesOrderConsumerMaterials.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (SalesOrderConsumerMaterials.Products = ProductsCatalog.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (SalesOrderConsumerMaterials.MeasurementUnit = UOM.Ref)
	|
	|GROUP BY
	|	SalesOrderConsumerMaterials.Products,
	|	SalesOrderConsumerMaterials.Characteristic,
	|	SalesOrderConsumerMaterials.MeasurementUnit,
	|	ISNULL(UOM.Factor, 1),
	|	SalesOrderConsumerMaterials.Ref,
	|	ProductsCatalog.VATRate
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("BasisDocument",	FillingData);
	Query.SetParameter("Ref",			Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("Products, Characteristic");
	
	If BalanceTable.Count() > 0 Then
		
		Selection = ResultsArray[2].Select();
		While Selection.Next() Do
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("Products", Selection.Products);
			StructureForSearch.Insert("Characteristic", Selection.Characteristic);
			
			BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
			If BalanceRowsArray.Count() = 0 Then
				Continue;
			EndIf;
			
			NewRow = Products.Add();
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
		
	Else
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'All third-party components for %1 have already been received.'; ru = 'Все сторонние компоненты для %1 уже получены.';pl = 'Wszystkie komponenty trzecich stron do %1 już zostały odebrane.';es_ES = 'Todos los componentes de terceros para%1 ya han sido recibidos.';es_CO = 'Todos los componentes de terceros para%1 ya han sido recibidos.';tr = '%1 için tüm üçüncü taraf malzemeleri zaten alındı.';it = 'Tutte le componenti di terze parti per %1 sono già state ricevute.';de = 'Drittlieferant-Gesamtmaterialbestand für %1 wurde bereits erhalten.'"),
			FillingData);
			
		Raise ErrorText;
		
	EndIf;
	
EndProcedure

Procedure FillByGoodsIssue(FillingData) Export
	
	Company			= FillingData.Company;
	CompanyVATNumber= FillingData.CompanyVATNumber;
	Counterparty	= FillingData.Counterparty;
	Contract		= FillingData.Contract;
	StructuralUnit	= FillingData.StructuralUnit;
	Cell			= FillingData.Cell;
	OperationType	= Enums.OperationTypesGoodsReceipt.ReturnFromAThirdParty;
	VATTaxation		= FillingData.VATTaxation;
	
	Products.Clear();
	For Each TabularSectionRow In FillingData.Products Do
		
		NewRow = Products.Add();
		FillPropertyValues(NewRow, TabularSectionRow);
		
		If Not ValueIsFilled(NewRow.VATRate) Then
			NewRow.VATRate = Common.ObjectAttributeValue(NewRow.Products, "VATRate");
		EndIf;
		
		NewRow.Order			= Undefined;
		NewRow.BasisDocument	= FillingData.Ref;
		
	EndDo;

	WorkWithSerialNumbers.FillTSSerialNumbersByConnectionKey(ThisObject, FillingData, "Products");
	
EndProcedure

Procedure FillByVATInvoiceForICT(FillingData) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	VATInvoiceForICT.AmountIncludesVAT AS AmountIncludesVAT,
	|	VATInvoiceForICT.Company AS Company,
	|	VATInvoiceForICT.DocumentCurrency AS DocumentCurrency,
	|	VALUE(Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer) AS OperationType,
	|	VATInvoiceForICT.StructuralUnitDestination AS StructuralUnit,
	|	VATInvoiceForICT.VATTaxationDestination AS VATTaxation,
	|	VATInvoiceForICT.AutomaticVATCalculation AS AutomaticVATCalculation,
	|	VATInvoiceForICT.DestinationVATNumber AS CompanyVATNumber
	|FROM
	|	Document.VATInvoiceForICT AS VATInvoiceForICT
	|WHERE
	|	VATInvoiceForICT.Ref = &VATInvoiceForICT
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	VATInvoiceForICTInventoryDestination.Ref AS BasisDocument,
	|	VATInvoiceForICTInventoryDestination.Products AS Products,
	|	VATInvoiceForICTInventoryDestination.Characteristic AS Characteristic,
	|	VATInvoiceForICTInventoryDestination.Batch AS Batch,
	|	VATInvoiceForICTInventoryDestination.MeasurementUnit AS MeasurementUnit,
	|	VATInvoiceForICTInventoryDestination.Price AS Price,
	|	SUM(VATInvoiceForICTInventoryDestination.Quantity) AS Quantity,
	|	SUM(VATInvoiceForICTInventoryDestination.Amount) AS Amount,
	|	SUM(VATInvoiceForICTInventoryDestination.Amount) - VATInvoiceForICTInventoryDestination.Price * SUM(VATInvoiceForICTInventoryDestination.Quantity) AS DiscountAmount,
	|	CASE
	|		WHEN VATInvoiceForICTInventoryDestination.Price * SUM(VATInvoiceForICTInventoryDestination.Quantity) = 0
	|			THEN 0
	|		ELSE (VATInvoiceForICTInventoryDestination.Price * SUM(VATInvoiceForICTInventoryDestination.Quantity) - SUM(VATInvoiceForICTInventoryDestination.Amount)) / VATInvoiceForICTInventoryDestination.Price * SUM(VATInvoiceForICTInventoryDestination.Quantity)
	|	END AS DiscountPercent,
	|	VATInvoiceForICTInventoryDestination.VATRate AS VATRate,
	|	SUM(VATInvoiceForICTInventoryDestination.VATAmount) AS VATAmount,
	|	SUM(VATInvoiceForICTInventoryDestination.Total) AS Total,
	|	VATInvoiceForICTInventoryDestination.SerialNumbers AS SerialNumbers,
	|	VATInvoiceForICTInventoryDestination.ConnectionKey AS ConnectionKey
	|FROM
	|	Document.VATInvoiceForICT.InventoryDestination AS VATInvoiceForICTInventoryDestination
	|WHERE
	|	VATInvoiceForICTInventoryDestination.Ref = &VATInvoiceForICT
	|
	|GROUP BY
	|	VATInvoiceForICTInventoryDestination.Characteristic,
	|	VATInvoiceForICTInventoryDestination.Products,
	|	VATInvoiceForICTInventoryDestination.Batch,
	|	VATInvoiceForICTInventoryDestination.MeasurementUnit,
	|	VATInvoiceForICTInventoryDestination.SerialNumbers,
	|	VATInvoiceForICTInventoryDestination.Ref,
	|	VATInvoiceForICTInventoryDestination.ConnectionKey,
	|	VATInvoiceForICTInventoryDestination.Price,
	|	VATInvoiceForICTInventoryDestination.VATRate";
	
	Query.SetParameter("VATInvoiceForICT", FillingData.Ref);
	
	QueryResult = Query.ExecuteBatch();
	
	Header = QueryResult[0].Unload();
	ProductsTable = QueryResult[1].Unload();
	
	If Header.Count() > 0 Then
		
		FillPropertyValues(ThisObject, Header[0]);
		
		If Not ValueIsFilled(StructuralUnit) Then
			SettingValue = DriveReUse.GetValueOfSetting("MainWarehouse");
			If Not ValueIsFilled(SettingValue) Then
				StructuralUnit = Catalogs.BusinessUnits.MainWarehouse;
			EndIf;
		EndIf;
		
	EndIf;
	
	Products.Load(ProductsTable);
	
	WorkWithSerialNumbers.FillTSSerialNumbersByConnectionKey(ThisObject, FillingData);
	
EndProcedure

Procedure FillByStructure(FillingData) Export
	
	If FillingData.Property("InvoicesArray") Then
		FillBySupplierInvoice(FillingData);
	ElsIf FillingData.Property("OrdersArray") Then
		FillByPurchaseOrder(FillingData);
	ElsIf FillingData.Property("RMARequestArray") Then
		FillByRMARequest(FillingData);
	ElsIf FillingData.Property("ArrayOfSalesInvoices") Then
		FillBySalesInvoice(FillingData);
	ElsIf FillingData.Property("ArrayOfCreditNotes") Then
		FillByCreditNote(FillingData);
	ElsIf FillingData.Property("SubcontractorOrderRef") Then
		FillBySubcontractorOrderIssued(FillingData);
	EndIf;
	
EndProcedure

Procedure FillBySubcontractorOrderIssued(FillingData) Export
	
	OrdersArray = New Array;
	
	If TypeOf(FillingData) = Type("Structure") And FillingData.Property("SubcontractorOrderRef") Then
		Order = FillingData.SubcontractorOrderRef;
		OperationType = FillingData.OperationType;
	Else
		Order = FillingData;
		OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractor;
	EndIf;
	
	OrdersArray.Add(Order);
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SubcontractorOrderIssued.Ref AS Order,
	|	SubcontractorOrderIssued.Company AS Company,
	|	SubcontractorOrderIssued.CompanyVATNumber AS CompanyVATNumber,
	|	SubcontractorOrderIssued.StructuralUnit AS StructuralUnit,
	|	SubcontractorOrderIssued.Counterparty AS Counterparty,
	|	SubcontractorOrderIssued.Contract AS Contract
	|FROM
	|	Document.SubcontractorOrderIssued AS SubcontractorOrderIssued
	|WHERE
	|	SubcontractorOrderIssued.Ref IN (&OrdersArray)";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	FillPropertyValues(ThisObject, Selection);
	
	If OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractor Then
		
		Documents.GoodsReceipt.FillBySubcontractorOrders(
			New Structure("Ref", Ref),
			New Structure("OrdersArray", OrdersArray),
			Products);
		
		If Products.Count() = 0 Then
			If OrdersArray.Count() = 1 Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'For %1, the finished products and by-products have already been received.'; ru = 'Для %1 уже получена готовая и побочная продукция.';pl = 'Dla %1, gotowe produkty i produkty uboczne już zostały otrzymane.';es_ES = 'Para %1, ya se han recibido los productos y subproductos terminados.';es_CO = 'Para %1, ya se han recibido los productos y subproductos terminados.';tr = '%1 için nihai ürünler ve yan ürünler zaten alındı.';it = 'Per %1, sono già stati ricevuti gli articoli finiti e scarti e residui.';de = 'Für %1 sind die Fertigprodukte und Nebenprodukte bereits eingegangen.'"),
					OrdersArray[0]);
			Else
				MessageText = NStr("en = 'For the selected subcontractor orders, the finished products and by-products have already been received.'; ru = 'Для выбранных заказов на переработку уже получена готовая и побочная продукция.';pl = 'Dla wybranych zamówień podwykonawcy, gotowe produkty i produkty uboczne zostały już otrzymane.';es_ES = 'Para las ordenes del subcontratista seleccionado, ya se han recibido los productos y subproductos terminados.';es_CO = 'Para las ordenes del subcontratista seleccionado, ya se han recibido los productos y subproductos terminados.';tr = 'Seçilen alt yüklenici siparişleri için nihai ürünler ve yan ürünler zaten alındı.';it = 'Per gli ordini di subfornitura selezionati, gli articoli finiti e scarti e residui sono già stati ricevuti.';de = 'Für die ausgewählten Subunternehmeraufträge sind die Fertigprodukte und Nebenprodukte bereits eingegangen.'");
			EndIf;
			CommonClientServer.MessageToUser(MessageText, Ref);
		EndIf;
		
	ElsIf OperationType = Enums.OperationTypesGoodsReceipt.ReturnFromSubcontractor Then
		
		Documents.GoodsReceipt.FillBySubcontractorOrdersReturn(
			New Structure("Ref", Ref),
			New Structure("OrdersArray", OrdersArray),
			Products);
		
		If Products.Count() = 0 Then
			If OrdersArray.Count() = 1 Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'For %1, the components have already been returned.'; ru = 'Для %1 компоненты уже возвращены.';pl = 'Dla %1, komponenty już zostały zwrócone.';es_ES = 'Para %1, ya se han devuelto los componentes.';es_CO = 'Para %1, ya se han devuelto los componentes.';tr = '%1 için malzemeler zaten iade edildi.';it = 'Per %1, le componenti sono già state restituite.';de = 'Für %1 wurden die Komponenten bereits zurückgegeben.'"),
					OrdersArray[0]);
			Else
				MessageText = NStr("en = 'For the selected subcontractor orders, the components have already been returned.'; ru = 'Для выбранных заказов на переработку компоненты уже возвращены.';pl = 'Dla wybranych zamówień podwykonawcy, komponenty zostały już zwrócone.';es_ES = 'Para las órdenes del subcontratista seleccionado, ya se han devuelto los componentes.';es_CO = 'Para las órdenes del subcontratista seleccionado, ya se han devuelto los componentes.';tr = 'Seçilen alt yüklenici siparişleri için malzemeler zaten iade edildi.';it = 'Per gli ordini di subfornitura selezionati, le componenti sono già state restituite.';de = 'Für die ausgewählten Subunternehmeraufträge wurden die Komponenten bereits zurückgegeben.'");
			EndIf;
			CommonClientServer.MessageToUser(MessageText, Ref);
		EndIf;
		
	EndIf;
	
EndProcedure

// begin Drive.FullVersion
Procedure FillBySubcontractorOrderReceived(FillingData) Export
	
	OrdersArray = New Array;
	
	If TypeOf(FillingData) = Type("Structure") And FillingData.Property("SubcontractorOrderRef") Then
		Order = FillingData.SubcontractorOrderRef;
		OperationType = FillingData.OperationType;
	Else
		Order = FillingData;
		OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer;
	EndIf;
	
	OrdersArray.Add(Order);
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SubcontractorOrderReceived.Ref AS Order,
	|	SubcontractorOrderReceived.Company AS Company,
	|	SubcontractorOrderReceived.CompanyVATNumber AS CompanyVATNumber,
	|	SubcontractorOrderReceived.StructuralUnit AS StructuralUnit,
	|	SubcontractorOrderReceived.Counterparty AS Counterparty,
	|	SubcontractorOrderReceived.Contract AS Contract
	|FROM
	|	Document.SubcontractorOrderReceived AS SubcontractorOrderReceived
	|WHERE
	|	SubcontractorOrderReceived.Ref IN (&OrdersArray)";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	FillPropertyValues(ThisObject, Selection);
	
	If OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer Then
		
		Documents.GoodsReceipt.FillBySubcontractorOrdersReceived(
			New Structure("Ref", Ref),
			New Structure("OrdersArray", OrdersArray),
			Products);
		
		If Products.Count() = 0 Then
			If OrdersArray.Count() = 1 Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'For %1, the components have already been received.'; ru = 'Для %1 компоненты уже получены.';pl = 'Dla %1, komponenty już zostały otrzymane.';es_ES = 'Para %1, ya se han recibido los componentes.';es_CO = 'Para %1, ya se han recibido los componentes.';tr = '%1 için malzemeler zaten alındı.';it = 'Per %1, le componenti sono già state ricevute.';de = 'Für %1 wurden die Komponenten bereits erhalten.'"),
					OrdersArray[0]);
			Else
				MessageText = NStr("en = 'For this Subcontractor order received, Goods receipts have already been registered. They include all components required for this Subcontractor order received.'; ru = 'Поступления товаров для данного полученного заказа на переработку уже зарегистрированы. Они включают в себя все компоненты, необходимые для этого полученного заказа на переработку.';pl = 'Dla tego otrzymanego Zamówienia zleceniodawcy, Przyjęcia towarów są już zarejestrowane. Zawierają oni wszystkie wymagane komponenty dla tego otrzymanego Zamówienia zleceniodawcy.';es_ES = 'Para esta orden recibida del Subcontratista, las entradas de Mercancías ya están registradas. Estas incluyen todos los componentes requeridos para esta orden recibida del Subcontratista.';es_CO = 'Para esta orden recibida del Subcontratista, las entradas de Mercancías ya están registradas. Estas incluyen todos los componentes requeridos para esta orden recibida del Subcontratista.';tr = 'Bu Alınan alt yüklenici siparişi için Ambar girişleri kayıtları var. Bunlar, bu Alınan alt yüklenici siparişi için gerekli tüm malzemeleri içeriyor.';it = 'Per questo Ordine di subfornitura ricevuto, le ricevute del articoli sono già state registrate. Includono tutte le componenti richieste per questo Ordine di subfornitura ricevuto.';de = 'Für diesen Subunternehmerauftrag erhalten, wurden die Wareneingänge bereits registriert. Sie enthalten alle Komponente erforderlich für diesen Subunternehmerauftrag erhalten.'");
			EndIf;
			CommonClientServer.MessageToUser(MessageText, Ref);
		EndIf;
		
	EndIf;
	
EndProcedure
// end Drive.FullVersion 

#EndRegion

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.CreditNote") Then
		
		AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(FillingData.Date, FillingData.Company);
		If Not AccountingPolicy.UseGoodsReturnFromCustomer Then
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Company %1 doesn''t use goods receipt for posting inventory entries at %2 (specify this option in accounting policy)'; ru = 'Организация %1 не использует поступления товаров для проведения движений по запасам на %2 (укажите данную опцию в учетной политике)';pl = 'Firma %1 nie stosuje przyjęcia zewnętrznego do zatwierdzenia wpisów o zapasach na %2 (wybierz tę opcję w polityce rachunkowości)';es_ES = 'Empresa %1 no utiliza el recibo de mercancías para el envío de las entradas de diario de inventario en %2 (especificar esta opción en la política de contabilidad)';es_CO = 'Empresa %1 no utiliza el recibo de mercancías para el envío de las entradas de inventario en %2 (especificar esta opción en la política de contabilidad)';tr = '%1 iş yeri, %2 bölümünde stok girişlerini kaydetmek için ambar girişi kullanmıyor (muhasebe politikasında bu seçeneği belirtin)';it = 'L''azienda %1 non utilizza la ricezione merce per la pubblicazione degli inserimenti delle scorte in %2 (indicare questa opzione nella politica contabile)';de = 'Die Firma %1 verwendet keinen Wareneingang für Buchung des Bestands bei %2 (diese Option in der Bilanzierungsrichtlinie angeben)'"),
				FillingData.Company,
				Format(FillingData.Date, "DLF=D"))
			
		EndIf;
			
	EndIf;
	
	FillingStrategy = New Map;
	FillingStrategy[Type("Structure")]								= "FillByStructure";
	FillingStrategy[Type("DocumentRef.CreditNote")]					= "FillByCreditNote";
	FillingStrategy[Type("DocumentRef.PurchaseOrder")]				= "FillByPurchaseOrder";
	FillingStrategy[Type("DocumentRef.SalesInvoice")]				= "FillBySalesInvoice";
	FillingStrategy[Type("DocumentRef.SupplierInvoice")]			= "FillBySupplierInvoice";
	FillingStrategy[Type("DocumentRef.SalesOrder")]					= "FillBySalesOrder";
	FillingStrategy[Type("DocumentRef.GoodsIssue")]					= "FillByGoodsIssue";
	FillingStrategy[Type("DocumentRef.RMARequest")]					= "FillByRMARequest";
	FillingStrategy[Type("DocumentRef.VATInvoiceForICT")]			= "FillByVATInvoiceForICT";
	FillingStrategy[Type("DocumentRef.SubcontractorOrderIssued")]	= "FillBySubcontractorOrderIssued";
	// begin Drive.FullVersion
	FillingStrategy[Type("DocumentRef.SubcontractorOrderReceived")]	= "FillBySubcontractorOrderReceived";
	// end Drive.FullVersion 
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy, "Order");
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If OperationType = Enums.OperationTypesGoodsReceipt.IntraCommunityTransfer Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
	ElsIf OperationType <> Enums.OperationTypesGoodsReceipt.SalesReturn
		And OrderPosition = Enums.AttributeStationing.InHeader 
		Or OperationType = Enums.OperationTypesGoodsReceipt.SalesReturn
		And SalesOrderPosition = Enums.AttributeStationing.InHeader Then
		CheckedAttributes.Add("Contract");
	Else
		CheckedAttributes.Add("Products.Contract");
	EndIf;
	
	DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Products.Price");
	DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Products.Amount");
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	If AccountingPolicy.ContinentalMethod And OperationType = Enums.OperationTypesGoodsReceipt.PurchaseFromSupplier Then
		
		MessagePattern = NStr("en = 'The ""%1"" is required on line #%2 of the ""Products"" list.'; ru = 'В строке %2 списка товаров необходимо указать ""%1"".';pl = 'Tu ""%1"" jest wymagane we wierszu #%2 listy ""Produkty"".';es_ES = 'El ""%1"" se requiere en línea #%2 de la lista de ""Productos"".';es_CO = 'El ""%1"" se requiere en línea #%2 de la lista de ""Productos"".';tr = '""Ürünler"" listesinin #%2 satırında ""%1"" gerekir.';it = 'Il ""%1"" è richiesto nella linea #%2 dell''elenco ""Articoli"".';de = 'Das ""%1"" ist in der Zeile Nr %2 der Liste ""Produkte"" erforderlich.'");
		DocMetadataAttributes = Metadata().TabularSections.Products.Attributes;
		AttributesToBeChecked = New Array;
		AttributesToBeChecked.Add("Price");
		AttributesToBeChecked.Add("Amount");
		
		For Each ProductsRow In Products Do
			If Not ValueIsFilled(ProductsRow.SupplierInvoice) Then
				For Each AttributeBeingChecked In AttributesToBeChecked Do
					If Not ValueIsFilled(ProductsRow[AttributeBeingChecked]) Then
						FieldPresentation = DocMetadataAttributes[AttributeBeingChecked].Presentation();
						ErrorText = StringFunctionsClientServer.SubstituteParametersToString(MessagePattern, FieldPresentation, Format(ProductsRow.LineNumber, "NZ=0; NG=0"));
						Field = CommonClientServer.PathToTabularSection("Products", ProductsRow.LineNumber, AttributeBeingChecked);
						CommonClientServer.MessageToUser(ErrorText, ThisObject, Field, , Cancel);
					EndIf;
				EndDo;
			EndIf;
		EndDo;
		
	Else
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "DocumentCurrency");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "VATTaxation");
		
	EndIf;
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Products, SerialNumbers, StructuralUnit, ThisObject);
	
	BatchesServer.CheckFilling(ThisObject, Cancel);
	
	AdvanceInvoicingDateCheck(Cancel);
	
	If OperationType <> Enums.OperationTypesGoodsReceipt.SalesReturn Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Products.SalesDocument");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Products.SalesReturnItem");
	EndIf;
	
	If VATTaxation <> Enums.VATTaxationTypes.SubjectToVAT
		Or OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractor
		// begin Drive.FullVersion
		Or OperationType = Enums.OperationTypesGoodsReceipt.ReturnFromSubcontractor 
		Or OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer
		// end Drive.FullVersion
		Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Products.VATRate");
	EndIf;
	
	// Drop shipping
	If OperationType = Enums.OperationTypesGoodsReceipt.DropShipping Then
		
		MessageTextEmptyOrder = NStr(
			"en = 'Order is required when Operation is Drop shipping.'; ru = 'При операции «Дропшиппинг» поле «Заказ» обязательно для заполнения.';pl = 'Zamówienie jest wymagane przy Operacji Dropshipping.';es_ES = 'El pedido es necesario cuando la Operación es Envío directo.';es_CO = 'El pedido es necesario cuando la Operación es Envío directo.';tr = 'İşlem ""Stoksuz satış"" olduğunda sipariş gereklidir.';it = 'È richiesto l''Ordine quando l''Operazione è Dropshipping.';de = 'Bei der Operation Streckengeschäft ist ein Auftrag nötig.'");
		MessageText = NStr(
			"en = 'The specified order does not include products for drop shipping. 
			|Specify an order including products with the ""Drop shipping"" checkbox selected.'; 
			|ru = 'В указанный заказ не входит номенклатура для дропшиппинга. 
			|Укажите заказ, включающий номенклатуру, с установленным флажком «Дропшиппинг».';
			|pl = 'Wybrane zamówienie nie zawiera produktów do dropshippingu. 
			|Wybierz zamówienie zawierające produkty z zaznaczonym polem wyboru „Dropshipping”.';
			|es_ES = 'El pedido especificado no incluye productos para el envío directo.
			|Especifique un pedido que incluya productos con la casilla de verificación ""Envío directo"" seleccionada.';
			|es_CO = 'El pedido especificado no incluye productos para el envío directo.
			|Especifique un pedido que incluya productos con la casilla de verificación ""Envío directo"" seleccionada.';
			|tr = 'Belirtilen sipariş stoksuz satış ürünü içermiyor. 
			|""Stoksuz satış"" onay kutusu seçili ürünler içeren bir sipariş belirtin.';
			|it = 'L''ordine specificato non include articoli per dropshipping. 
			|Specificare un ordine che includa articoli con la casella di controllo ""Dropshipping"" selezionata.';
			|de = 'Der angegebene Auftrag enthält keine Produkte für Streckengeschäft. 
			|Geben Sie einen Auftrag mit Produkten mit dem aktivierten Kontrollkästchen ""Streckengeschäft"" ein.'");
		
		EnumPurchaseOrderDS = Enums.OperationTypesPurchaseOrder.OrderForDropShipping;
		
		If OrderPosition = Enums.AttributeStationing.InHeader Then
			If Not ValueIsFilled(Order) Then
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageTextEmptyOrder,
					Undefined,
					Undefined,
					"Order",
					Cancel);
			ElsIf Common.ObjectAttributeValue(Order, "OperationKind") <> EnumPurchaseOrderDS Then
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					Undefined,
					Undefined,
					"Order",
					Cancel);
			EndIf;
		Else 
			For Each ItemProducts In Products Do
				OperationPO = Common.ObjectAttributeValue(ItemProducts.Order, "OperationKind");
				If Not ValueIsFilled(ItemProducts.Order) Then
					DriveServer.ShowMessageAboutError(
						ThisObject,
						MessageTextEmptyOrder,
						"Products",
						ItemProducts.LineNumber,
						Undefined,
						Cancel);
				ElsIf Common.ObjectAttributeValue(ItemProducts.Order, "OperationKind") <> EnumPurchaseOrderDS Then
					DriveServer.ShowMessageAboutError(
						ThisObject,
						MessageText,
						"Products",
						ItemProducts.LineNumber,
						Undefined,
						Cancel);
				EndIf;
			EndDo;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If OperationType <> Enums.OperationTypesGoodsReceipt.SalesReturn
		And OrderPosition = Enums.AttributeStationing.InHeader 
		Or OperationType = Enums.OperationTypesGoodsReceipt.SalesReturn
		And SalesOrderPosition = Enums.AttributeStationing.InHeader Then
		
		For Each TabularSectionRow In Products Do
			TabularSectionRow.Order = Order;
			TabularSectionRow.Contract = Contract;
		EndDo;
	Else
		Order = Undefined;
		Contract = Undefined;
	EndIf;
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	If (AccountingPolicy.ContinentalMethod
		And (OperationType = Enums.OperationTypesGoodsReceipt.PurchaseFromSupplier
			Or OperationType = Enums.OperationTypesGoodsReceipt.DropShipping))
			Or OperationType = Enums.OperationTypesGoodsReceipt.SalesReturn 
			Or OperationType = Enums.OperationTypesGoodsReceipt.IntraCommunityTransfer
			Or Documents.GoodsReceipt.ThereIsAdvanceInvoice(Products.UnloadColumn("SupplierInvoice")) Then
		Totals = DriveServer.CalculateSubtotalPurchases(Products.Unload(), AmountIncludesVAT);
		FillPropertyValues(ThisObject, Totals);
	Else
		DocumentCurrency = Undefined;
		ExchangeRate = 1;
		Multiplicity = 1;
		ContractCurrencyExchangeRate = 1;
		ContractCurrencyMultiplicity = 1;
		VATTaxation = Undefined;
		AmountIncludesVAT = False;
		IncludeVATInPrice = False;
		DocumentAmount = 0;
		DocumentTax = 0;
		DocumentSubtotal = 0;
		For Each ProdRow In Products Do
			ProdRow.Price = 0;
			ProdRow.Amount = 0;
			ProdRow.VATAmount = 0;
			ProdRow.Total = 0;
		EndDo;
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
	InventoryOwnershipServer.FillMainTableColumn(ThisObject, WriteMode, Cancel);
	
	If Not AdjustedReserved Then
		InventoryReservationServer.FillReservationTable(ThisObject, WriteMode, Cancel);
	EndIf;
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	DriveServer.CheckAvailabilityOfGoodsReturn(ThisObject, Cancel);
	
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	Documents.GoodsReceipt.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectReservedProducts(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPurchases(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPurchaseOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSalesOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsReceivedNotInvoiced(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsInvoicedNotReceived(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryAccepted(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectStockTransferredToThirdParties(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectBackorders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryCostLayer(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSubcontractorOrders(AdditionalProperties, RegisterRecords, Cancel);
	// begin Drive.FullVersion
	DriveServer.ReflectSubcontractComponents(AdditionalProperties, RegisterRecords, Cancel);
	// end Drive.FullVersion
	
	// Serial numbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Goods in transit
	If WorkWithVATServerCall.MultipleVATNumbersAreUsed() Then
		DriveServer.ReflectGoodsInTransit(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.GoodsReceipt.RunControl(Ref, AdditionalProperties, Cancel);
	
	// begin Drive.FullVersion
	CheckInventoryDemandFromSubcontractingCustomer(Cancel);
	// end Drive.FullVersion
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	If Not Cancel Then
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
	EndIf;
	
	// Control of occurrence of a negative balance.
	Documents.GoodsReceipt.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	InventoryReservationServer.ClearReserves(ThisObject);
	
	If Not Cancel Then
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
	EndIf;
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	Author = Users.CurrentUser();
	IncomingNumber = "";
	IncomingDate = "";
	
	If SerialNumbers.Count() Then
		
		For Each ProductsLine In Products Do
			ProductsLine.SerialNumbers = "";
		EndDo;
		
		SerialNumbers.Clear();
		
	EndIf;
	
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
	
	// begin Drive.FullVersion
	If Not Cancel 
		And Not AdditionalProperties.Posted
		And AdditionalProperties.WriteMode = DocumentWriteMode.Posting Then
		CheckReceiptFromSubcontractingCustomer(Cancel);
	EndIf;
	// end Drive.FullVersion
	
EndProcedure

#EndRegion

#Region Private

Procedure AdvanceInvoicingDateCheck(Cancel)
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	MAX(GoodsInvoicedNotReceived.Period) AS Period
	|FROM
	|	AccumulationRegister.GoodsInvoicedNotReceived AS GoodsInvoicedNotReceived
	|WHERE
	|	GoodsInvoicedNotReceived.SupplierInvoice IN(&Invoices)
	|	AND GoodsInvoicedNotReceived.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND GoodsInvoicedNotReceived.Period >= &Date";
	Query.SetParameter("Invoices", Products.UnloadColumn("SupplierInvoice"));
	Query.SetParameter("Date", Date);
	
	Sel = Query.Execute().Select();
	If Sel.Next() And ValueIsFilled(Sel.Period) Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'A goods receipt must be dated later than the Invoice and Customs declaration it is subordinated to (%1).'; ru = 'Дата поступления товаров должна быть позже, чем дата соответствующего инвойса и таможенной декларации (%1).';pl = 'Przyjęcie towarów powinno być datowane późniejszą datą, niż deklaracja celna i faktury, do której ma stosunek (%1).';es_ES = 'La recepción de productos debe ser fechada posteriormente que la Factura y la Declaración de aduanas subordinadas a (%1).';es_CO = 'La recepción de productos debe ser fechada posteriormente que la Factura y la Declaración de aduanas subordinadas a (%1).';tr = 'Ambar girişi, (%1) ''e tabi olduğu Fatura ve Gümrük beyannamesinden daha geç bir tarih olarak düzenlenmelidir.';it = 'Una ricezione di merce deve avere una data successiva alla fattura e alla dichiarazione doganale a cui è legata (%1).';de = 'Ein Wareneingang muss später datiert werden als die Rechnungs- und Zollanmeldung, der er (%1) unterstellt ist.'"),
			Sel.Period);
		
		CommonClientServer.MessageToUser(MessageText, ThisObject, "Date", , Cancel);
		
	EndIf;
	
EndProcedure

// begin Drive.FullVersion

Procedure CheckInventoryDemandFromSubcontractingCustomer(Cancel)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	If OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer
		And ValueIsFilled(Order) 
		And TypeOf(Order) = Type("DocumentRef.SubcontractorOrderReceived") 
		And StructureTemporaryTables.RegisterRecordsInventoryDemandChange Then
		
		Query = New Query("SELECT
		|	RegisterRecordsInventoryDemandChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryDemandChange.Company AS CompanyPresentation,
		|	RegisterRecordsInventoryDemandChange.MovementType AS MovementTypePresentation,
		|	RegisterRecordsInventoryDemandChange.SalesOrder AS SalesOrderPresentation,
		|	RegisterRecordsInventoryDemandChange.Products AS ProductsPresentation,
		|	RegisterRecordsInventoryDemandChange.Characteristic AS CharacteristicPresentation,
		|	InventoryDemandBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryDemandChange.QuantityChange, 0) + ISNULL(InventoryDemandBalances.QuantityBalance, 0) AS BalanceInventoryDemand,
		|	ISNULL(InventoryDemandBalances.QuantityBalance, 0) AS QuantityBalanceInventoryDemand
		|FROM
		|	RegisterRecordsInventoryDemandChange AS RegisterRecordsInventoryDemandChange
		|		INNER JOIN AccumulationRegister.InventoryDemand.Balance(&ControlTime, ) AS InventoryDemandBalances
		|		ON RegisterRecordsInventoryDemandChange.Company = InventoryDemandBalances.Company
		|			AND RegisterRecordsInventoryDemandChange.MovementType = InventoryDemandBalances.MovementType
		|			AND RegisterRecordsInventoryDemandChange.SalesOrder = InventoryDemandBalances.SalesOrder
		|			AND RegisterRecordsInventoryDemandChange.Products = InventoryDemandBalances.Products
		|			AND RegisterRecordsInventoryDemandChange.Characteristic = InventoryDemandBalances.Characteristic
		|			AND (ISNULL(InventoryDemandBalances.QuantityBalance, 0) < 0)");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		QueryResult = Query.Execute(); 		
		If Not QueryResult.IsEmpty() Then
			QueryResultSelection = QueryResult.Select();
			DriveServer.ShowMessageAboutPostingToInventoryDemandRegisterErrors(ThisObject, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;	
	
EndProcedure

Procedure CheckReceiptFromSubcontractingCustomer(Cancel)
	
	If OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer
		And ValueIsFilled(Order) 
		And TypeOf(Order) = Type("DocumentRef.SubcontractorOrderReceived") Then
		
		Query = New Query;
		Query.Text =
		"SELECT ALLOWED TOP 1
		|	TRUE AS VrtField
		|FROM
		|	Document.GoodsIssue AS GoodsIssue
		|WHERE
		|	GoodsIssue.OperationType = VALUE(Enum.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer)
		|	AND GoodsIssue.Order = &Order
		|	AND GoodsIssue.Posted";
		
		Query.SetParameter("Order", Order);
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			
			MessageText = NStr("en = 'The Goods receipt cannot be posted. There are Goods issue documents
								|with the ""Return to subcontracting customer"" operation.'; 
								|ru = 'Не удается провести поступление товаров. Есть документы ""Отпуск товаров""
								|с операцией ""Возврат давальцу"".';
								|pl = 'Przyjęcie towarów nie może być zatwierdzone. Istnieją dokumenty Wydanie zewnętrzne
								|z operacją ""Zwrot do nabywcy usług podwykonawstwa"".';
								|es_ES = 'No se puede enviar el recibo de Productos. Hay documentos de Salida de mercancías
								|con la operación ""Devolución al cliente subcontratado"".';
								|es_CO = 'No se puede enviar el recibo de Productos. Hay documentos de Salida de productos
								|con la operación ""Devolución al cliente subcontratado"".';
								|tr = 'Ambar girişi kaydedilemiyor. ""Alt yüklenici müşteriye iade"" işlemli
								|Ambar çıkışı belgeleri var.';
								|it = 'Il Documento di trasporto non può essere pubblicato. Ci sono documenti di Spedizione merce/Ddt
								|con l''operazione ""Restituire al cliente in subfornitura"".';
								|de = 'Der Wareneingang kann nicht gebucht werden. Es gibt Dokumente Warenausgang 
								|mit Operation ""Zurück zu Kunde mit Subunternehmerbestellung"".'");
			
			CommonClientServer.MessageToUser(MessageText, , , , Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// end Drive.FullVersion

#EndRegion

#EndIf