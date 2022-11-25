#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRef, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	SubcontractorOrderReceivedProducts.LineNumber AS LineNumber,
	|	SubcontractorOrderReceived.Ref AS Recorder,
	|	SubcontractorOrderReceived.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	SubcontractorOrderReceived.Company AS Company,
	|	SubcontractorOrderReceived.Counterparty AS Counterparty,
	|	SubcontractorOrderReceived.Ref AS SubcontractorOrder,
	|	SubcontractorOrderReceivedProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorOrderReceivedProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(SubcontractorOrderReceivedProducts.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SubcontractorOrderReceivedProducts.Quantity
	|		ELSE SubcontractorOrderReceivedProducts.Quantity * SubcontractorOrderReceivedProducts.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.SubcontractorOrderReceived.Products AS SubcontractorOrderReceivedProducts
	|		INNER JOIN Document.SubcontractorOrderReceived AS SubcontractorOrderReceived
	|		ON SubcontractorOrderReceivedProducts.Ref = SubcontractorOrderReceived.Ref
	|WHERE
	|	SubcontractorOrderReceived.Ref = &Ref
	|	AND (SubcontractorOrderReceived.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND SubcontractorOrderReceived.Closed = FALSE
	|			OR SubcontractorOrderReceived.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorOrderReceivedInventory.LineNumber AS LineNumber,
	|	SubcontractorOrderReceived.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	SubcontractorOrderReceived.Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Receipt) AS MovementType,
	|	SubcontractorOrderReceived.Ref AS SalesOrder,
	|	SubcontractorOrderReceivedInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorOrderReceivedInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(SubcontractorOrderReceivedInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SubcontractorOrderReceivedInventory.Quantity
	|		ELSE SubcontractorOrderReceivedInventory.Quantity * SubcontractorOrderReceivedInventory.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.SubcontractorOrderReceived.Inventory AS SubcontractorOrderReceivedInventory
	|		INNER JOIN Document.SubcontractorOrderReceived AS SubcontractorOrderReceived
	|		ON SubcontractorOrderReceivedInventory.Ref = SubcontractorOrderReceived.Ref
	|WHERE
	|	SubcontractorOrderReceived.Ref = &Ref
	|	AND (SubcontractorOrderReceived.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND SubcontractorOrderReceived.Closed = FALSE
	|			OR SubcontractorOrderReceived.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorOrderReceivedProducts.LineNumber AS LineNumber,
	|	SubcontractorOrderReceived.Date AS Period,
	|	SubcontractorOrderReceived.Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	SubcontractorOrderReceivedProducts.Ref AS Order,
	|	SubcontractorOrderReceivedProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorOrderReceivedProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(SubcontractorOrderReceivedProducts.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SubcontractorOrderReceivedProducts.Quantity
	|		ELSE SubcontractorOrderReceivedProducts.Quantity * SubcontractorOrderReceivedProducts.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.SubcontractorOrderReceived.Products AS SubcontractorOrderReceivedProducts
	|		INNER JOIN Document.SubcontractorOrderReceived AS SubcontractorOrderReceived
	|		ON SubcontractorOrderReceivedProducts.Ref = SubcontractorOrderReceived.Ref
	|WHERE
	|	SubcontractorOrderReceived.Ref = &Ref
	|	AND (SubcontractorOrderReceived.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND SubcontractorOrderReceived.Closed = FALSE
	|			OR SubcontractorOrderReceived.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorOrderReceivedProducts.LineNumber AS LineNumber,
	|	SubcontractorOrderReceived.Date AS Period,
	|	SubcontractorOrderReceived.Company AS Company,
	|	SubcontractorOrderReceived.StructuralUnit AS StructuralUnit,
	|	SubcontractorOrderReceivedProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorOrderReceivedProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SubcontractorOrderReceived.Ref AS SalesOrder,
	|	SubcontractorOrderReceivedProducts.Specification AS Specification,
	|	&Ownership AS Ownership,
	|	CASE
	|		WHEN VALUETYPE(SubcontractorOrderReceivedProducts.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SubcontractorOrderReceivedProducts.Quantity
	|		ELSE SubcontractorOrderReceivedProducts.Quantity * SubcontractorOrderReceivedProducts.MeasurementUnit.Factor
	|	END AS QuantityPlan
	|FROM
	|	Document.SubcontractorOrderReceived.Products AS SubcontractorOrderReceivedProducts
	|		INNER JOIN Document.SubcontractorOrderReceived AS SubcontractorOrderReceived
	|		ON SubcontractorOrderReceivedProducts.Ref = SubcontractorOrderReceived.Ref
	|WHERE
	|	SubcontractorOrderReceived.Ref = &Ref
	|	AND (SubcontractorOrderReceived.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND SubcontractorOrderReceived.Closed = FALSE
	|			OR SubcontractorOrderReceived.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	LineNumber";
	
	OwnershipParameters = New Structure;
	OwnershipParameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.CustomerProvidedInventory);
	OwnershipParameters.Insert("Counterparty", DocumentRef.Counterparty);
	OwnershipParameters.Insert("Contract", DocumentRef.Contract);
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("Ownership", Catalogs.InventoryOwnership.GetByParameters(OwnershipParameters));
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSubcontractorOrdersReceived", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryFlowCalendar", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductRelease", ResultsArray[3].Unload());
	
	GenerateTablePaymentCalendar(DocumentRef, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRef, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	If StructureTemporaryTables.RegisterRecordsSubcontractorOrdersReceivedChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsSubcontractorOrdersReceivedChange.LineNumber AS LineNumber,
		|	RegisterRecordsSubcontractorOrdersReceivedChange.Company AS Company,
		|	RegisterRecordsSubcontractorOrdersReceivedChange.Counterparty AS Counterparty,
		|	RegisterRecordsSubcontractorOrdersReceivedChange.SubcontractorOrder AS SubcontractorOrder,
		|	RegisterRecordsSubcontractorOrdersReceivedChange.Products AS Products,
		|	RegisterRecordsSubcontractorOrdersReceivedChange.Characteristic AS Characteristic,
		|	SubcontractorOrdersReceivedBalances.Products.MeasurementUnit AS MeasurementUnit,
		|	ISNULL(RegisterRecordsSubcontractorOrdersReceivedChange.QuantityChange, 0) + ISNULL(SubcontractorOrdersReceivedBalances.QuantityBalance, 0) AS Balance,
		|	ISNULL(SubcontractorOrdersReceivedBalances.QuantityBalance, 0) AS QuantityBalance
		|FROM
		|	RegisterRecordsSubcontractorOrdersReceivedChange AS RegisterRecordsSubcontractorOrdersReceivedChange
		|		INNER JOIN AccumulationRegister.SubcontractorOrdersReceived.Balance(&ControlTime, ) AS SubcontractorOrdersReceivedBalances
		|		ON RegisterRecordsSubcontractorOrdersReceivedChange.Company = SubcontractorOrdersReceivedBalances.Company
		|			AND RegisterRecordsSubcontractorOrdersReceivedChange.Counterparty = SubcontractorOrdersReceivedBalances.Counterparty
		|			AND RegisterRecordsSubcontractorOrdersReceivedChange.SubcontractorOrder = SubcontractorOrdersReceivedBalances.SubcontractorOrder
		|			AND RegisterRecordsSubcontractorOrdersReceivedChange.Products = SubcontractorOrdersReceivedBalances.Products
		|			AND RegisterRecordsSubcontractorOrdersReceivedChange.Characteristic = SubcontractorOrdersReceivedBalances.Characteristic
		|			AND (ISNULL(SubcontractorOrdersReceivedBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty() Then
			DocumentObject = DocumentRef.GetObject();
		EndIf;
		
		// Negative balance on subcontractor orders received.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToSubcontractorOrdersReceivedRegisterErrors(DocumentObject, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CheckEnterBasedOnSubcontractorOrder(AttributeValues) Export
	
	If AttributeValues.Property("Posted") Then
		If Not AttributeValues.Posted Then
			Raise NStr("en = 'Please select a posted document.'; ru = 'Выберите проведенный документ.';pl = 'Wybierz zatwierdzony dokument.';es_ES = 'Por favor, seleccione un documento enviado.';es_CO = 'Por favor, seleccione un documento enviado.';tr = 'Lütfen, kaydedilmiş bir belge seçin.';it = 'Si prega di selezionare un documento pubblicato.';de = 'Bitte wählen Sie ein gebuchtes Dokument aus.'");
		EndIf;
	EndIf;
	
	If AttributeValues.Property("Closed") Then
		If AttributeValues.Closed Then
			Raise NStr("en = 'Please select an order that is not completed.'; ru = 'Выберите незавершенный заказ.';pl = 'Wybierz zamówienie, które nie zostało zakończone.';es_ES = 'Por favor, seleccione un orden que no esté finalizado.';es_CO = 'Por favor, seleccione un orden que no esté finalizado.';tr = 'Lütfen, tamamlanmamış bir sipariş seçin.';it = 'Si prega di selezionare un ordine che non è stato completato.';de = 'Bitte wählen Sie einen noch nicht abgeschlossenen Auftrag aus.'");
		EndIf;
	EndIf;
	
	If AttributeValues.Property("OrderState") Then
		If AttributeValues.OrderState.OrderStatus = Enums.OrderStatuses.Open Then
			Raise NStr("en = 'Cannot generate documents from orders with status ""Open"".'; ru = 'Не удалось создать документы на основании заказов с статусом ""Открыт"".';pl = 'Nie można wygenerować dokumentów z zamówień ze statusem ""Otwarte"".';es_ES = 'No se pueden generar documentos de las órdenes con estado ""Abrir"".';es_CO = 'No se pueden generar documentos de las órdenes con estado ""Abrir"".';tr = 'Durumu ""Açık"" olan siparişlerden belge oluşturulamaz.';it = 'Impossibile generare documenti da ordini con stato ""Aperto"".';de = 'Dokumente können nicht aus Aufträgen mit dem Status ""Offen"" generiert werden.'");
		EndIf;
	EndIf;
	
EndProcedure

#Region LibrariesHandlers

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export

EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

#EndRegion

#Region Internal

Function GetSubcontractorOrderStringStatuses() Export
	
	StatusesStructure = DriveServer.GetOrderStringStatuses();
	
	Return StatusesStructure;
	
EndFunction

#EndRegion

#Region Private

// Cash flow projection table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod", StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("AdvanceDates", PaymentTermsServer.PaymentInAdvanceDates());
	
	Query.Text =
	"SELECT
	|	SubcontractorOrderReceived.Ref AS Ref,
	|	SubcontractorOrderReceived.DateRequired AS DateRequired,
	|	SubcontractorOrderReceived.AmountIncludesVAT AS AmountIncludesVAT,
	|	SubcontractorOrderReceived.PaymentMethod AS PaymentMethod,
	|	SubcontractorOrderReceived.Contract AS Contract,
	|	SubcontractorOrderReceived.PettyCash AS PettyCash,
	|	SubcontractorOrderReceived.DocumentCurrency AS DocumentCurrency,
	|	SubcontractorOrderReceived.BankAccount AS BankAccount,
	|	SubcontractorOrderReceived.Closed AS Closed,
	|	SubcontractorOrderReceived.OrderState AS OrderState,
	|	SubcontractorOrderReceived.ExchangeRate AS ExchangeRate,
	|	SubcontractorOrderReceived.Multiplicity AS Multiplicity,
	|	SubcontractorOrderReceived.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	SubcontractorOrderReceived.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	SubcontractorOrderReceived.CashAssetType AS CashAssetType
	|INTO Document
	|FROM
	|	Document.SubcontractorOrderReceived AS SubcontractorOrderReceived
	|WHERE
	|	SubcontractorOrderReceived.Ref = &Ref
	|	AND SubcontractorOrderReceived.SetPaymentTerms
	|	AND NOT SubcontractorOrderReceived.Closed
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.PaymentDate AS Period,
	|	Document.PaymentMethod AS PaymentMethod,
	|	Document.Ref AS Quote,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	Document.PettyCash AS PettyCash,
	|	Document.DocumentCurrency AS DocumentCurrency,
	|	Document.BankAccount AS BankAccount,
	|	Document.Ref AS Ref,
	|	Document.ExchangeRate AS ExchangeRate,
	|	Document.Multiplicity AS Multiplicity,
	|	Document.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	Document.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	CASE
	|		WHEN Document.AmountIncludesVAT
	|			THEN DocumentTable.PaymentAmount
	|		ELSE DocumentTable.PaymentAmount + DocumentTable.PaymentVATAmount
	|	END AS PaymentAmount,
	|	Document.CashAssetType AS CashAssetType
	|INTO PaymentCalendar
	|FROM
	|	Document AS Document
	|		INNER JOIN Catalog.SubcontractorOrderReceivedStatuses AS SubcontractorOrderReceivedStatuses
	|		ON Document.OrderState = SubcontractorOrderReceivedStatuses.Ref
	|			AND (SubcontractorOrderReceivedStatuses.OrderStatus IN (VALUE(Enum.OrderStatuses.InProcess), VALUE(Enum.OrderStatuses.Completed)))
	|		INNER JOIN Document.SubcontractorOrderReceived.PaymentCalendar AS DocumentTable
	|		ON Document.Ref = DocumentTable.Ref
	|			AND DocumentTable.PaymentBaselineDate IN (&AdvanceDates)
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON Document.Contract = CounterpartyContracts.Ref
	|		INNER JOIN Constant.UsePaymentCalendar AS UsePaymentCalendar
	|		ON (UsePaymentCalendar.Value)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PaymentCalendar.Period AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	PaymentCalendar.PaymentMethod AS PaymentMethod,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	PaymentCalendar.Ref AS Quote,
	|	VALUE(Catalog.CashFlowItems.PaymentFromCustomers) AS Item,
	|	CASE
	|		WHEN PaymentCalendar.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN PaymentCalendar.PettyCash
	|		WHEN PaymentCalendar.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN PaymentCalendar.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash,
	|	PaymentCalendar.SettlementsCurrency AS Currency,
	|	CAST(PaymentCalendar.PaymentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN PaymentCalendar.ExchangeRate * PaymentCalendar.ContractCurrencyMultiplicity / (PaymentCalendar.ContractCurrencyExchangeRate * PaymentCalendar.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (PaymentCalendar.ExchangeRate * PaymentCalendar.ContractCurrencyMultiplicity / (PaymentCalendar.ContractCurrencyExchangeRate * PaymentCalendar.Multiplicity))
	|		END AS NUMBER(15, 2)) AS Amount
	|FROM
	|	PaymentCalendar AS PaymentCalendar";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

#EndRegion 

#EndIf
