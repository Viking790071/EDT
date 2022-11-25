#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
Procedure InitializeDocumentData(DocumentRefSalesOrder, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	SalesOrderInventory.LineNumber AS LineNumber,
	|	SalesOrderInventory.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	SalesOrderInventory.Ref AS SalesOrder,
	|	SalesOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SalesOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SalesOrderInventory.Quantity
	|		ELSE SalesOrderInventory.Quantity * ISNULL(UOM.Factor, 1)
	|	END AS Quantity,
	|	SalesOrderInventory.ShipmentDate AS ShipmentDate,
	|	CASE
	|		WHEN SalesOrderInventory.DropShipping
	|			THEN CASE
	|					WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|						THEN SalesOrderInventory.Quantity
	|					ELSE SalesOrderInventory.Quantity * ISNULL(UOM.Factor, 1)
	|				END
	|		ELSE 0
	|	END AS DropShippingQuantity
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SalesOrderInventory.MeasurementUnit = UOM.Ref
	|WHERE
	|	SalesOrderInventory.Ref = &Ref
	|	AND (SalesOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND SalesOrderInventory.Ref.Closed = FALSE
	|			OR SalesOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrderMaterials.LineNumber AS LineNumber,
	|	SalesOrderMaterials.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Receipt) AS MovementType,
	|	SalesOrderMaterials.Ref AS SalesOrder,
	|	SalesOrderMaterials.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SalesOrderMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(SalesOrderMaterials.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SalesOrderMaterials.Quantity
	|		ELSE SalesOrderMaterials.Quantity * ISNULL(UOM.Factor, 1)
	|	END AS Quantity
	|FROM
	|	Document.SalesOrder.ConsumerMaterials AS SalesOrderMaterials
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SalesOrderMaterials.MeasurementUnit = UOM.Ref
	|WHERE
	|	SalesOrderMaterials.Ref = &Ref
	|	AND SalesOrderMaterials.Ref.OperationKind = VALUE(Enum.OperationTypesSalesOrder.OrderForProcessing)
	|	AND (SalesOrderMaterials.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND SalesOrderMaterials.Ref.Closed = FALSE
	|			OR SalesOrderMaterials.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Ordering,
	|	SalesOrderInventory.LineNumber AS LineNumber,
	|	SalesOrderInventory.ShipmentDate AS Period,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	SalesOrderInventory.Ref AS Order,
	|	SalesOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SalesOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SalesOrderInventory.Quantity
	|		ELSE SalesOrderInventory.Quantity * ISNULL(UOM.Factor, 1)
	|	END AS Quantity
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SalesOrderInventory.MeasurementUnit = UOM.Ref
	|WHERE
	|	SalesOrderInventory.Ref = &Ref
	|	AND (SalesOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND SalesOrderInventory.Ref.Closed = FALSE
	|			OR SalesOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|	AND NOT SalesOrderInventory.DropShipping
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	SalesOrderMaterials.LineNumber,
	|	SalesOrderMaterials.ReceiptDate,
	|	&Company,
	|	VALUE(Enum.InventoryMovementTypes.Receipt),
	|	SalesOrderMaterials.Ref,
	|	SalesOrderMaterials.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SalesOrderMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	CASE
	|		WHEN VALUETYPE(SalesOrderMaterials.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SalesOrderMaterials.Quantity
	|		ELSE SalesOrderMaterials.Quantity * ISNULL(UOM.Factor, 1)
	|	END
	|FROM
	|	Document.SalesOrder.ConsumerMaterials AS SalesOrderMaterials
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SalesOrderMaterials.MeasurementUnit = UOM.Ref
	|WHERE
	|	SalesOrderMaterials.Ref = &Ref
	|	AND SalesOrderMaterials.Ref.OperationKind = VALUE(Enum.OperationTypesSalesOrder.OrderForProcessing)
	|	AND (SalesOrderMaterials.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND SalesOrderMaterials.Ref.Closed = FALSE
	|			OR SalesOrderMaterials.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrderMaterials.LineNumber AS LineNumber,
	|	SalesOrderMaterials.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	SalesOrderMaterials.Ref AS SalesOrder,
	|	SalesOrderMaterials.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SalesOrderMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SalesOrderMaterials.Ref AS SupplySource,
	|	CASE
	|		WHEN VALUETYPE(SalesOrderMaterials.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SalesOrderMaterials.Quantity
	|		ELSE SalesOrderMaterials.Quantity * ISNULL(UOM.Factor, 1)
	|	END AS Quantity
	|FROM
	|	Document.SalesOrder.ConsumerMaterials AS SalesOrderMaterials
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SalesOrderMaterials.MeasurementUnit = UOM.Ref
	|WHERE
	|	SalesOrderMaterials.Ref = &Ref
	|	AND SalesOrderMaterials.Ref.OperationKind = VALUE(Enum.OperationTypesSalesOrder.OrderForProcessing)
	|	AND (SalesOrderMaterials.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND SalesOrderMaterials.Ref.Closed = FALSE
	|			OR SalesOrderMaterials.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	SalesOrderMaterials.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrderInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	SalesOrderInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	SalesOrderInventory.Ref AS Ref,
	|	SalesOrderInventory.Ref.StructuralUnitReserve AS StructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SalesOrderInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	SalesOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SalesOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN SalesOrderInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	SalesOrderInventory.Ref AS SalesOrder,
	|	CASE
	|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SalesOrderInventory.Reserve
	|		ELSE SalesOrderInventory.Reserve * ISNULL(UOM.Factor, 1)
	|	END AS Quantity
	|INTO TemporaryTableInventory
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SalesOrderInventory.MeasurementUnit = UOM.Ref
	|WHERE
	|	SalesOrderInventory.Ref = &Ref
	|	AND SalesOrderInventory.Reserve > 0
	|	AND (SalesOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND SalesOrderInventory.Ref.Closed = FALSE
	|			OR SalesOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.Closed AS Closed
	|INTO Header
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref = &Ref";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", 					DocumentRefSalesOrder);
	Query.SetParameter("PointInTime", 			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", 				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", 	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",  			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSalesOrders", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryFlowCalendar", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBackorders", ResultsArray[3].Unload());
	
	GenerateTableReservedProducts(DocumentRefSalesOrder, StructureAdditionalProperties);
	
	GenerateTablePaymentCalendar(DocumentRefSalesOrder, StructureAdditionalProperties);
	GenerateTableInvoicesAndOrdersPayment(DocumentRefSalesOrder, StructureAdditionalProperties);
	
	FinancialAccounting.FillExtraDimensions(DocumentRefSalesOrder, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentObjectSalesOrder, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables:
	// - "RegisterRecordsSalesOrdersChange",
	// - "RegisterRecordsInventoryDemandChange",
	// - "RegisterRecordsReservedProductsChange"
	// contain records, execute the control of balances.
		
	If StructureTemporaryTables.RegisterRecordsSalesOrdersChange
		OR StructureTemporaryTables.RegisterRecordsInventoryDemandChange
		OR StructureTemporaryTables.RegisterRecordsReservedProductsChange Then
		
		Query = New Query;
		Query.Text = GenerateQueryTextBalancesSalesOrders() // [0]
			+ GenerateQueryTextBalancesInventoryDemand(); // [1]
		
		Query.Text = Query.Text + AccumulationRegisters.ReservedProducts.BalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		// Negative balance on sales order.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToSalesOrdersRegisterErrors(DocumentObjectSalesOrder, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of need for inventory.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryDemandRegisterErrors(DocumentObjectSalesOrder, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of need for reserved products.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToReservedProductsRegisterErrors(DocumentObjectSalesOrder, QueryResultSelection, Cancel);
		EndIf;
		
		DriveServer.CheckAvailableStockBalance(DocumentObjectSalesOrder, AdditionalProperties, Cancel);
		
		If DocumentObjectSalesOrder.OperationKind = Enums.OperationTypesSalesOrder.OrderForSale Then
			DriveServer.CheckOrderedMinusBackorderedBalance(DocumentObjectSalesOrder.Ref, AdditionalProperties, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

Function ArePerformersWithEmptyEarningSum(Performers) Export
	
	Var Errors;
	MessageTextTemplate = NStr("en = 'Earnings for employee %1 in line %2 are incorrect.'; ru = 'Неверно указана сумма начисления для сотрудника %1 в строке %2.';pl = 'Nieprawidłowe wynagrodzenie pracownika %1 w wierszu %2.';es_ES = 'Ganancias para el empleado %1 en la línea %2 son incorrectas.';es_CO = 'Ganancias para el empleado %1 en la línea %2 son incorrectas.';tr = '%2 satırındaki %1 çalışanı için kazanç yanlıştır.';it = 'I guadagni per il dipendente %1 nella riga %2 non sono corretti.';de = 'Die Bezüge für den Mitarbeiter %1 in Zeile %2 sind falsch.'");
	
	For Each Performer In Performers Do
		
		If Performer.AccruedAmount = 0 Then
			
			SingleErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				MessageTextTemplate,
				Performer.Employee.Description,
				Performer.LineNumber);
			
			CommonClientServer.AddUserError(
				Errors,
				"Object.Performers[%1].Employee", 
				SingleErrorText, 
				Undefined, 
				Performer.LineNumber
				,);
			
		EndIf;
		
	EndDo;
	
	If ValueIsFilled(Errors) Then
		
		CommonClientServer.ReportErrorsToUser(Errors);
		Return True;
		
	EndIf;
	
	Return False;
	
EndFunction

// Checks the possibility of input on the basis.
//
Procedure CheckAbilityOfEnteringBySalesOrder(FillingData, AttributeValues) Export
	
	If AttributeValues.Property("Posted") And Not AttributeValues.Posted Then
		ErrorText = NStr("en = '%1 is not posted. Cannot use it as a base document. Please, post it first.'; ru = 'Документ %1 не проведен. Ввод на основании непроведенного документа запрещен.';pl = '%1 dokument nie został zatwierdzony. Nie można użyć go jako dokumentu źródłowego. Najpierw zatwierdź go.';es_ES = '%1 no se ha enviado. No se puede utilizarlo como un documento de base. Por favor, enviarlo primero.';es_CO = '%1 no se ha enviado. No se puede utilizarlo como un documento de base. Por favor, enviarlo primero.';tr = '%1 kaydedilmediğinden temel belge olarak kullanılamıyor. Lütfen, önce kaydedin.';it = '%1 non pubblicato. Non è possibile utilizzarlo come documento di base. Si prega di pubblicarlo prima di tutto.';de = '%1 wird nicht gebucht. Kann nicht als Basisdokument verwendet werden. Zuerst bitte buchen.'");
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, FillingData);
		Raise ErrorText;
	EndIf;
	
	If AttributeValues.Property("Closed") And AttributeValues.Closed
		And (AttributeValues.Property("WorkOrderReturn") And Constants.UseSalesOrderStatuses.Get()
				Or Not AttributeValues.Property("WorkOrderReturn")) Then
		ErrorText = NStr("en = '%1 is completed. Cannot use a completed order as a base document.'; ru = 'Заказ %1 завершен. Использование завершенного заказа в качестве документа-основания невозможно.';pl = '%1 jest zamknięty. Nie można użyć zamkniętego zamówienia jako dokumentu źródłowego.';es_ES = '%1 se ha finalizado. No se puede utilizarlo un orden finalizado como un documento de base.';es_CO = '%1 se ha finalizado. No se puede utilizarlo un orden finalizado como un documento de base.';tr = '%1 tamamlandı. Tamamlanmış bir siparişi temel belge olarak kullanamazsınız.';it = '%1 è completato. Non è possibile usare un ordine completato come documento base.';de = '%1 ist abgeschlossen. Ein abgeschlossener Auftrag kann nicht als Basisdokument verwendet werden.'");
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, FillingData);
		Raise ErrorText;
	EndIf;
	
	If AttributeValues.Property("OrderState") Then
		
		If Common.ObjectAttributeValue(AttributeValues.OrderState, "OrderStatus") = Enums.OrderStatuses.Open Then
			ErrorText = NStr("en = 'Cannot generate other documents from %1 because its lifecycle status is %2.'; ru = 'Не удалось сформировать прочие документы на основании %1, поскольку его статус документа %2.';pl = 'Nie można wygenerować innych dokumentów z %1, ponieważ jego status dokumentu jest %2.';es_ES = 'No se pueden generar otros documentos de %1 porque el estado de su ciclo de vida es %2.';es_CO = 'No se pueden generar otros documentos de %1 porque el estado de su ciclo de vida es %2.';tr = 'Yaşam döngüsü durumu %2 olduğundan %1 belgesinden başka belge oluşturulamıyor.';it = 'Impossibile generare altri documenti da %1 perché lo stato del ciclo di vita è %2.';de = 'Keine anderen Dokumente aus %1 generiert werden, da sein Status von Lebenszyklus %2ist.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText,
				FillingData, AttributeValues.OrderState);
			Raise ErrorText;
		EndIf;
		
		If AttributeValues.Property("OperationKind") And AttributeValues.Property("GoodsReceipt")
				And AttributeValues.OperationKind <> Enums.OperationTypesSalesOrder.OrderForProcessing Then
			
			ErrorText = NStr("en = 'Cannot use %1 as a base document for Goods Receipt.
				|Please select a sales order with ""Subcontracting"" operation.'; 
				|ru = '%1 не может быть документом-основанием для поступления товаров.
				|Выберите заказ покупателя с видом операции ""Переработка"".';
				|pl = 'Nie można użyć %1 jako dokumentu źródłowego do przyjęcia zewnętrznego.
				|Proszę wybrać zamówienie sprzedaży z operacją ""Podwykonawstwo"".';
				|es_ES = 'No se puede usar %1 como el documento típico para el Recibo de mercancías.
				|Por favor seleccione una orden de venta con operación ""Subcontratación"".';
				|es_CO = 'No se puede usar %1 como el documento típico para el Recibo de mercancías.
				|Por favor seleccione una orden de venta con operación ""Subcontratación"".';
				|tr = '%1, Ambar girişi için temel belge olarak kullanılamaz.
				|Lütfen ""Yüklenici iş emri"" işlemi ile bir satış siparişi seçin.';
				|it = 'Impossibile utilizzare %1 come documento base per le Entrate merci. 
				|Selezionare un ordine cliente con operazione ""Subfornitura"".';
				|de = 'Kann nicht %1 als Basisdokument für den Wareneingang verwenden.
				|Bitte wählen Sie einen Kundenauftrag mit der Operation ""Subunternehmung"" aus.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, FillingData);
			Raise ErrorText;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Function DocumentVATRate(DocumentRef) Export
	
	Return DriveServer.DocumentVATRate(DocumentRef);
	
EndFunction

#Region LibrariesHandlers

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	GLAccountsForFilling = New Structure;
	GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
		
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export
	
	Return New Structure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Return New Structure;
	
EndFunction

#EndRegion

#Region PrintInterface

// Generate printed forms of objects
//
// Incoming:
//  TemplateNames   - String	- Names of layouts separated by commas 
//	ObjectsArray	- Array		- Array of refs to objects that need to be printed 
//	PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection	- Values table	- Generated table documents 
//	OutputParameters		- Structure     - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "Quote") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"Quote",
			NStr("en = 'Quote'; ru = 'Коммерческое предложение';pl = 'Oferta cenowa';es_ES = 'Presupuesto';es_CO = 'Presupuesto';tr = 'Teklif';it = 'Preventivo';de = 'Angebot'"),
			PrintForm(ObjectsArray, PrintObjects, "Quote", PrintParameters.Result));
		
	ElsIf PrintManagement.TemplatePrintRequired(PrintFormsCollection, "ProformaInvoice") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"ProformaInvoice",
			NStr("en = 'Proforma invoice'; ru = 'Проформа-инвойс';pl = 'Faktura proforma';es_ES = 'Factura proforma';es_CO = 'Factura proforma';tr = 'Proforma fatura';it = 'Fattura proforma';de = 'Proforma-Rechnung'"),
			PrintForm(ObjectsArray, PrintObjects, "ProformaInvoice", PrintParameters.Result));
		
	ElsIf PrintManagement.TemplatePrintRequired(PrintFormsCollection, "GuaranteeCard") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"GuaranteeCard",
			NStr("en = 'Warranty card'; ru = 'Гарантийный талон';pl = 'Karta gwarancyjna';es_ES = 'Tarjeta de garantía';es_CO = 'Tarjeta de garantía';tr = 'Garanti belgesi';it = 'Certificato di garanzia';de = 'Garantiekarte'"),
			PrintForm(ObjectsArray, PrintObjects, "GuaranteeCard", PrintParameters.Result));
		
	ElsIf PrintManagement.TemplatePrintRequired(PrintFormsCollection, "Estimate") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"Estimate",
			NStr("en = 'Estimate'; ru = 'Калькуляция';pl = 'Kalkulacja';es_ES = 'Estimado';es_CO = 'Estimado';tr = 'Hesaplama';it = 'Stima';de = 'Schätzen'"),
			PrintForm(ObjectsArray, PrintObjects, "Estimate", PrintParameters.Result));
		
	ElsIf PrintManagement.TemplatePrintRequired(PrintFormsCollection, "OrderConfirmation") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"OrderConfirmation",
			NStr("en = 'Order confirmation'; ru = 'Заказ покупателя';pl = 'Potwierdzenie zamówienia';es_ES = 'Confirmación de pedido';es_CO = 'Confirmación de pedido';tr = 'Sipariş onayı';it = 'Conferma Ordine';de = 'Auftragsbestätigung'"),
			PrintForm(ObjectsArray, PrintObjects, "OrderConfirmation", PrintParameters.Result));
		
	ElsIf PrintManagement.TemplatePrintRequired(PrintFormsCollection, "PickList") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"PickList",
			NStr("en = 'Pick list'; ru = 'Лист сборки';pl = 'Lista kompletacyjna';es_ES = 'Elegir la lista';es_CO = 'Elegir la lista';tr = 'Toplama listesi';it = 'Lista di presa';de = 'Auswahlliste'"),
			DataProcessors.PrintPickList.PrintForm(ObjectsArray, PrintObjects, "PickList", PrintParameters.Result));
		
	ElsIf PrintManagement.TemplatePrintRequired(PrintFormsCollection, "Requisition") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"Requisition",
			NStr("en = 'Requisition'; ru = 'Заявка';pl = 'Zapotrzebowanie';es_ES = 'Solicitud';es_CO = 'Solicitud';tr = 'Talep formu';it = 'Requisizione';de = 'Anforderung'"),
			DataProcessors.PrintRequisition.PrintForm(ObjectsArray, PrintObjects, "Requisition", PrintParameters.Result));
			
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in Sales order printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	// Order confirmation
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "OrderConfirmation";
	PrintCommand.Presentation				= NStr("en = 'Order confirmation'; ru = 'Заказ покупателя';pl = 'Potwierdzenie zamówienia';es_ES = 'Confirmación de pedido';es_CO = 'Confirmación de pedido';tr = 'Sipariş onayı';it = 'Conferma Ordine';de = 'Auftragsbestätigung'");
	PrintCommand.FormsList					= "DocumentForm,ListForm,ShipmentDocumentsListForm,PaymentDocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
	// Pick list
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "PickList";
	PrintCommand.Presentation				= NStr("en = 'Pick list'; ru = 'Лист сборки';pl = 'Lista kompletacyjna';es_ES = 'Elegir la lista';es_CO = 'Elegir la lista';tr = 'Toplama listesi';it = 'Lista di presa';de = 'Auswahlliste'");
	PrintCommand.FormsList					= "DocumentForm,ListForm,ShipmentDocumentsListForm,PaymentDocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 2;
	
	// Quote
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "Quote";
	PrintCommand.Presentation				= NStr("en = 'Quotation'; ru = 'Коммерческое предложение';pl = 'Oferta cenowa';es_ES = 'Presupuesto';es_CO = 'Presupuesto';tr = 'Teklif';it = 'Preventivo';de = 'Angebot'");
	PrintCommand.FormsList					= "DocumentForm,ListForm,ShipmentDocumentsListForm,PaymentDocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 3;
	
	// Proforma invoice
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "ProformaInvoice";
	PrintCommand.Presentation				= NStr("en = 'Proforma invoice'; ru = 'Проформа-инвойс';pl = 'Faktura proforma';es_ES = 'Factura proforma';es_CO = 'Factura proforma';tr = 'Proforma fatura';it = 'Fattura proforma';de = 'Pro-forma-Rechnung'");
	PrintCommand.FormsList					= "DocumentForm,ListForm,ShipmentDocumentsListForm,PaymentDocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 4;
	
	// Contract
	PrintCommand = PrintCommands.Add();
	PrintCommand.Handler					= "DriveClient.GenerateContractForms";
	PrintCommand.ID							= "ContractForm";
	PrintCommand.Presentation				= NStr("en = 'Contract template'; ru = 'Бланк договора';pl = 'Szablon kontraktu';es_ES = 'Modelo de contrato';es_CO = 'Modelo de contrato';tr = 'Sözleşme şablonu';it = 'Modello di contratto';de = 'Vertragsmuster'");
	PrintCommand.FormsList					= "DocumentForm,ListForm,ShipmentDocumentsListForm,PaymentDocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 5;
	
	// Work order
	//
	
	// Documents set
	PrintCommand = PrintCommands.Add();
	
	IdentifierValue = "ProformaInvoice,GuaranteeCard";
	IdentifierValue = StrReplace(IdentifierValue, ",GuaranteeCard", ?(GetFunctionalOption("UseSerialNumbers"), ",GuaranteeCard", ""));
	
	PrintCommand.ID							= IdentifierValue;
	PrintCommand.Presentation				= NStr("en = 'Customizable document set'; ru = 'Настраиваемый комплект документов';pl = 'Dostosowywalny zestaw dokumentów';es_ES = 'Conjunto de documentos personalizables';es_CO = 'Conjunto de documentos personalizables';tr = 'Özelleştirilebilir belge seti';it = 'Set di documenti personalizzabili';de = 'Anpassbarer Dokumentensatz'");
	PrintCommand.FormsList					= "ShipmentDocumentsListForm,PaymentDocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 51;
	
	// Contract
	PrintCommand = PrintCommands.Add();
	PrintCommand.Handler					= "DriveClient.GenerateContractForms";
	PrintCommand.ID							= "ContractForm";
	PrintCommand.Presentation				= NStr("en = 'Contract template'; ru = 'Бланк договора';pl = 'Szablon kontraktu';es_ES = 'Modelo de contrato';es_CO = 'Modelo de contrato';tr = 'Sözleşme şablonu';it = 'Modello di contratto';de = 'Vertragsmuster'");
	PrintCommand.FormsList					= "ShipmentDocumentsListForm,PaymentDocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 96;
	
	// Estimate
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "Estimate";
	PrintCommand.Presentation				= NStr("en = 'Estimate'; ru = 'Калькуляция';pl = 'Kalkulacja';es_ES = 'Estimado';es_CO = 'Estimado';tr = 'Hesaplama';it = 'Stima';de = 'Schätzen'");
	PrintCommand.FormsList					= "DocumentForm,EstimateForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 18;
	
	//Requisition
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "Requisition";
	PrintCommand.Presentation				= NStr("en = 'Requisition'; ru = 'Заявка';pl = 'Zapotrzebowanie';es_ES = 'Solicitud';es_CO = 'Solicitud';tr = 'Talep formu';it = 'Requisizione';de = 'Anforderung'");
	PrintCommand.FormsList					= "ShipmentDocumentsListForm,PaymentDocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 103;
	
	If AccessRight("view", Metadata.DataProcessors.PrintLabelsAndTags) Then
		
		PrintCommand = PrintCommands.Add();
		PrintCommand.Handler = "DriveClient.PrintLabelsAndPriceTagsFromDocuments";
		PrintCommand.ID = "LabelsPrintingFromSalesOrder";
		PrintCommand.Presentation = NStr("en = 'Labels'; ru = 'Этикетки';pl = 'Etykiety';es_ES = 'Etiquetas';es_CO = 'Etiquetas';tr = 'Marka etiketleri';it = 'Etichette';de = 'Etiketten'");
		PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
		PrintCommand.CheckPostingBeforePrint = False;
		PrintCommand.Order = 6;
		
		PrintCommand = PrintCommands.Add();
		PrintCommand.Handler = "DriveClient.PrintLabelsAndPriceTagsFromDocuments";
		PrintCommand.ID = "PriceTagsPrintingFromSalesOrder";
		PrintCommand.Presentation = NStr("en = 'Price tags'; ru = 'Ценники';pl = 'Cenniki';es_ES = 'Etiquetas de precio';es_CO = 'Etiquetas de precio';tr = 'Fiyat etiketleri';it = 'Cartellini di prezzo';de = 'Preisschilder'");
		PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
		PrintCommand.CheckPostingBeforePrint = False;
		PrintCommand.Order = 7;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#Region MessageTemplates

// StandardSubsystems.MessageTemplates

// It is called when preparing message templates and allows you to override a list of attributes and attachments.
//
// Parameters:
//  Attributes - ValueTree - a list of template attributes.
//    * Name            - String - a unique name of a common attribute.
//    * Presentation  - String - a common attribute presentation.
//    * Type            - Type - an attribute type. It is a string by default.
//    * Format         - String - a value output format for numbers, dates, strings, and boolean values.
//  Attachments - ValueTable - print forms and attachments, where:
//    * Name           - String - a unique attachment name.
//    * Presentation - String - an option presentation.
//    * FileType      - String - an attachment type that matches the file extension: pdf, png, jpg, mxl, and so on.
//  AdditionalParameters - Structure - additional information on the message template.
//
Procedure OnPrepareMessageTemplate(Attributes, Attachments, AdditionalParameters) Export
	
EndProcedure

// It is called upon creating messages from template to fill in values of attributes and attachments.
//
// Parameters:
//  Message - Structure - a structure with the following keys:
//    * AttributesValues - Map - a list of attributes used in the template.
//      ** Key     - String - an attribute name in the template.
//      ** Value - String - a filling value in the template.
//    * CommonAttributesValues - Map - a list of common attributes used in the template.
//      ** Key     - String - an attribute name in the template.
//      ** Value - String - a filling value in the template.
//    * Attachments - Map - attribute values
//      ** Key     - String - an attachment name in the template.
//      ** Value - BinaryData, String - binary data or an address in a temporary storage of the attachment.
//    * AdditionalParameters - Structure - additional message parameters.
//  MessageSubject - AnyRef - a reference to an object that is a data source.
//  AdditionalParameters - Structure - additional information on the message template.
//
Procedure OnCreateMessage(Message, MessageSubject, AdditionalParameters) Export
	
EndProcedure

// Fills in a list of text message recipients when sending a message generated from template.
//
// Parameters:
//   SMSMessageRecipients - ValueTable - a list of text message recipients.
//     * PhoneNumber - String - a phone number to send a text message to.
//     * Presentation - String - a text message recipient presentation.
//     * Contact       - Arbitrary - a contact that owns the phone number.
//  MessageSubject - AnyRef - a reference to an object that is a data source.
//                   - Structure  - a structure describing template parameters:
//    * Subject               - AnyRef - a reference to an object that is a data source.
//    * ArbitraryParameters - Map - a filled list of arbitrary parameters.
//
Procedure OnFillRecipientsPhonesInMessage(SMSMessageRecipients, MessageSubject) Export
	
EndProcedure

// Fills in a list of email recipients upon sending a message generated from a template.
//
// Parameters:
//   MailRecipients - ValueTable - a list of mail recipients.
//     * Address           - String - a recipient email address.
//     * Presentation   - String - an email recipient presentation.
//     * Contact         - Arbitrary - a contact that owns the email address.
//  MessageSubject - AnyRef - a reference to an object that is a data source.
//                   - Structure  - a structure describing template parameters:
//    * Subject               - AnyRef - a reference to an object that is a data source.
//    * ArbitraryParameters - Map - a filled list of arbitrary parameters.
//
Procedure OnFillRecipientsEmailsInMessage(EmailRecipients, MessageSubject) Export
	
EndProcedure

// End StandardSubsystems.MessageTemplates

#EndRegion

// StandardSubsystems.Interactions

// Get counterparty and contact persons.
//
// Parameters:
//  Subject  - DocumentRef.GoodsIssue - the document whose contacts you need to get.
//
// Returns:
//   Array   - array of contacts.
// 
Function GetContacts(Subject) Export
	
	If Not ValueIsFilled(Subject) Then
		Return New Array;
	EndIf;
	
	Return DriveContactInformationServer.GetContactsRefs(Subject);
	
EndFunction

// End StandardSubsystems.Interactions

#Region ToDoList

// StandardSubsystems.ToDoList

// See ToDoListOverridable.OnDetermineToDoListHandlers. 
Procedure OnFillToDoList(ToDoList) Export
	
	If Not AccessRight("Edit", Metadata.Documents.SalesOrder) Then
		Return;
	EndIf;
	
	ResponsibleStructure = DriveServer.ResponsibleStructure();
	DocumentsCount = DocumentsCount(ResponsibleStructure.List);
	DocumentsID = "SalesOrders";
	
	// Sales orders
	ToDo				= ToDoList.Add();
	ToDo.ID				= DocumentsID;
	ToDo.HasUserTasks	= (DocumentsCount.AllSalesOrders > 0);
	ToDo.Presentation	= NStr("en = 'Sales orders'; ru = 'Заказы покупателей';pl = 'Zamówienia sprzedaży';es_ES = 'Órdenes de ventas';es_CO = 'Órdenes de ventas';tr = 'Satış siparişleri';it = 'Ordini di vendita';de = 'Kundenaufträge'");
	ToDo.Owner			= Metadata.Subsystems.Sales;
	
	// Fulfillment is expired
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("PastPerformance");
	OpenParameters.Insert("Responsible", ResponsibleStructure);
	OpenParameters.Insert("SalesOrder");
	
	ToDo				= ToDoList.Add();
	ToDo.ID				= "BuyersOrdersExecutionExpired";
	ToDo.HasUserTasks	= (DocumentsCount.BuyersOrdersExecutionExpired > 0);
	ToDo.Important		= True;
	ToDo.Presentation	= NStr("en = 'Fulfillment is expired'; ru = 'Срок исполнения заказа истек';pl = 'Wykonanie wygasło';es_ES = 'Se ha vencido el plazo de cumplimiento';es_CO = 'Se ha vencido el plazo de cumplimiento';tr = 'Yerine getirme süresi doldu';it = 'L''adempimento è in ritardo';de = 'Ausfüllung ist abgelaufen'");
	ToDo.Count			= DocumentsCount.BuyersOrdersExecutionExpired;
	ToDo.Form			= "Document.SalesOrder.ListForm";
	ToDo.FormParameters	= OpenParameters;
	ToDo.Owner			= DocumentsID;
	
	// Payment is overdue
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("OverduePayment");
	OpenParameters.Insert("Responsible", ResponsibleStructure);
	OpenParameters.Insert("SalesOrder");
	
	ToDo				= ToDoList.Add();
	ToDo.ID				= "BuyersOrdersPaymentExpired";
	ToDo.HasUserTasks	= (DocumentsCount.BuyersOrdersPaymentExpired > 0);
	ToDo.Important		= True;
	ToDo.Presentation	= NStr("en = 'Payment is overdue'; ru = 'Оплата просрочена';pl = 'Płatność jest zaległa';es_ES = 'Pago vencido';es_CO = 'Pago vencido';tr = 'Ödemenin vadesi geçmiş';it = 'Pagamento in ritardo';de = 'Die Zahlung ist überfällig'");
	ToDo.Count			= DocumentsCount.BuyersOrdersPaymentExpired;
	ToDo.Form			= "Document.SalesOrder.ListForm";
	ToDo.FormParameters	= OpenParameters;
	ToDo.Owner			= DocumentsID;
	
	// For today
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("ForToday");
	OpenParameters.Insert("Responsible", ResponsibleStructure);
	OpenParameters.Insert("SalesOrder");
	
	ToDo				= ToDoList.Add();
	ToDo.ID				= "SalesOrdersForToday";
	ToDo.HasUserTasks	= (DocumentsCount.SalesOrdersForToday > 0);
	ToDo.Presentation	= NStr("en = 'For today'; ru = 'На сегодня';pl = 'Na dzisiaj';es_ES = 'Para hoy';es_CO = 'Para hoy';tr = 'Bugün itibarıyla';it = 'Odierni';de = 'Für Heute'");
	ToDo.Count			= DocumentsCount.SalesOrdersForToday;
	ToDo.Form			= "Document.SalesOrder.ListForm";
	ToDo.FormParameters	= OpenParameters;
	ToDo.Owner			= DocumentsID;
	
	// In progress
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("InProcess");
	OpenParameters.Insert("Responsible", ResponsibleStructure);
	OpenParameters.Insert("SalesOrder");
	
	ToDo				= ToDoList.Add();
	ToDo.ID				= "BuyersOrdersInWork";
	ToDo.HasUserTasks	= (DocumentsCount.BuyersOrdersInWork > 0);
	ToDo.Presentation	= NStr("en = 'In progress'; ru = 'В работе';pl = 'W toku';es_ES = 'En progreso';es_CO = 'En progreso';tr = 'İşlemde';it = 'In lavorazione';de = 'In Bearbeitung'");
	ToDo.Count			= DocumentsCount.BuyersOrdersInWork;
	ToDo.Form			= "Document.SalesOrder.ListForm";
	ToDo.FormParameters	= OpenParameters;
	ToDo.Owner			= DocumentsID;
	
	// New
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("AreNew");
	OpenParameters.Insert("Responsible", ResponsibleStructure);
	OpenParameters.Insert("SalesOrder");
	
	ToDo				= ToDoList.Add();
	ToDo.ID				= "BuyersNewOrders";
	ToDo.HasUserTasks	= (DocumentsCount.BuyersNewOrders > 0);
	ToDo.Presentation	= NStr("en = 'New'; ru = 'Новый';pl = 'Nowy';es_ES = 'Nuevo';es_CO = 'Nuevo';tr = 'Yeni';it = 'Nuovo';de = 'Neu'");
	ToDo.Count			= DocumentsCount.BuyersNewOrders;
	ToDo.Form			= "Document.SalesOrder.ListForm";
	ToDo.FormParameters	= OpenParameters;
	ToDo.Owner			= DocumentsID;
	
EndProcedure

// End StandardSubsystems.ToDoList

#EndRegion

#EndRegion

#Region DropShipping

Function GetPropertyIsDropShippingOfSalesOrder(RefSalesOrder) Export
	
	Result = False;
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	SalesOrderInventory.DropShipping AS DropShipping
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|WHERE
	|	SalesOrderInventory.Ref = &SalesOrder
	|	AND SalesOrderInventory.DropShipping";
	
	Query.SetParameter("SalesOrder", RefSalesOrder);
	
	QueryResult = Query.Execute();
	
	SelectionPropertyDS = QueryResult.Select();
	
	While SelectionPropertyDS.Next() Do
		If SelectionPropertyDS.DropShipping Then
			Result = True;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion

#EndRegion

#Region Internal

Function GetSalesOrderStringStatuses() Export
	
	StatusesStructure = DriveServer.GetOrderStringStatuses();
	
	Return StatusesStructure;
	
EndFunction

#EndRegion

#EndIf

#Region EventHandlers

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	StandardProcessing = False;
	Fields.Add("Ref");
	Fields.Add("Date");
	Fields.Add("Number");
	Fields.Add("OperationKind");
	Fields.Add("Posted");
	Fields.Add("DeletionMark");
	
EndProcedure

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	User = UsersClientServer.CurrentUser();
	
	If TypeOf(User) = Type("CatalogRef.ExternalUsers") Then
		If FormType = "ListForm" Then
			StandardProcessing = False;
			SelectedForm = "ListFormForExternalUsers";
		ElsIf FormType = "ChoiceForm" Then
			StandardProcessing = False;
			SelectedForm = "ChoiceFormForExternalUsers";
		EndIf;
	EndIf;
	
EndProcedure

#EndIf

#EndRegion

#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

#Region Private

Procedure GenerateTableReservedProducts(DocumentRefSalesOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	Table.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.GLAccount AS GLAccount,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.Batch AS Batch,
	|	Table.SalesOrder AS SalesOrder,
	|	Table.Quantity AS Quantity
	|FROM
	|	TemporaryTableInventory AS Table
	|";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableReservedProducts", QueryResult.Unload());
	
EndProcedure

// Cash flow projection table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRefSalesOrder, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRefSalesOrder);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod", StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("AdvanceDates", PaymentTermsServer.PaymentInAdvanceDates());
	
	Query.Text =
	"SELECT
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.ShipmentDate AS ShipmentDate,
	|	SalesOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesOrder.PaymentMethod AS PaymentMethod,
	|	SalesOrder.Contract AS Contract,
	|	SalesOrder.PettyCash AS PettyCash,
	|	SalesOrder.DocumentCurrency AS DocumentCurrency,
	|	SalesOrder.BankAccount AS BankAccount,
	|	SalesOrder.Closed AS Closed,
	|	SalesOrder.OrderState AS OrderState,
	|	SalesOrder.ExchangeRate AS ExchangeRate,
	|	SalesOrder.Multiplicity AS Multiplicity,
	|	SalesOrder.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	SalesOrder.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	SalesOrder.CashAssetType AS CashAssetType
	|INTO Document
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref = &Ref
	|	AND SalesOrder.SetPaymentTerms
	|	AND NOT SalesOrder.Closed
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
	|		INNER JOIN Catalog.SalesOrderStatuses AS SalesOrderStatuses
	|		ON Document.OrderState = SalesOrderStatuses.Ref
	|			AND (SalesOrderStatuses.OrderStatus IN (VALUE(Enum.OrderStatuses.InProcess), VALUE(Enum.OrderStatuses.Completed)))
	|		INNER JOIN Document.SalesOrder.PaymentCalendar AS DocumentTable
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

// Generating procedure for the table of invoices for payment.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTableInvoicesAndOrdersPayment(DocumentRefSalesOrder, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRefSalesOrder);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("ExchangeRateMethod", StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref AS Quote,
	|	CAST(DocumentTable.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DocumentTable.ExchangeRate * DocumentTable.ContractCurrencyMultiplicity / (DocumentTable.ContractCurrencyExchangeRate * DocumentTable.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DocumentTable.ExchangeRate * DocumentTable.ContractCurrencyMultiplicity / (DocumentTable.ContractCurrencyExchangeRate * DocumentTable.Multiplicity))
	|		END AS NUMBER(15, 2)) AS Amount,
	|	DocumentTable.Counterparty AS Counterparty
	|INTO SalesOrderTable
	|FROM
	|	Document.SalesOrder AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND NOT DocumentTable.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|	AND NOT(DocumentTable.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND DocumentTable.Ref.Closed)
	|	AND DocumentTable.DocumentAmount <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrderTable.Period AS Period,
	|	SalesOrderTable.Company AS Company,
	|	SalesOrderTable.Quote AS Quote,
	|	SalesOrderTable.Amount AS Amount
	|FROM
	|	SalesOrderTable AS SalesOrderTable
	|		INNER JOIN Catalog.Counterparties AS Counterparties
	|		ON SalesOrderTable.Counterparty = Counterparties.Ref
	|WHERE
	|	Counterparties.DoOperationsByOrders";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInvoicesAndOrdersPayment", QueryResult.Unload());
	
EndProcedure

// Function returns query text by the balance of SalesOrders register.
//
Function GenerateQueryTextBalancesSalesOrders()
	
	QueryText =
	"SELECT
	|	RegisterRecordsSalesOrdersChange.LineNumber AS LineNumber,
	|	RegisterRecordsSalesOrdersChange.Company AS CompanyPresentation,
	|	RegisterRecordsSalesOrdersChange.SalesOrder AS OrderPresentation,
	|	RegisterRecordsSalesOrdersChange.Products AS ProductsPresentation,
	|	RegisterRecordsSalesOrdersChange.Characteristic AS CharacteristicPresentation,
	|	SalesOrdersBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
	|	ISNULL(RegisterRecordsSalesOrdersChange.QuantityChange, 0) + ISNULL(SalesOrdersBalances.QuantityBalance, 0) AS BalanceSalesOrders,
	|	ISNULL(SalesOrdersBalances.QuantityBalance, 0) AS QuantityBalanceSalesOrders
	|FROM
	|	RegisterRecordsSalesOrdersChange AS RegisterRecordsSalesOrdersChange
	|		INNER JOIN AccumulationRegister.SalesOrders.Balance(&ControlTime, ) AS SalesOrdersBalances
	|		ON RegisterRecordsSalesOrdersChange.Company = SalesOrdersBalances.Company
	|			AND RegisterRecordsSalesOrdersChange.SalesOrder = SalesOrdersBalances.SalesOrder
	|			AND RegisterRecordsSalesOrdersChange.Products = SalesOrdersBalances.Products
	|			AND RegisterRecordsSalesOrdersChange.Characteristic = SalesOrdersBalances.Characteristic
	|			AND (ISNULL(SalesOrdersBalances.QuantityBalance, 0) < 0)
	|
	|ORDER BY
	|	LineNumber";
	
	Return QueryText + DriveClientServer.GetQueryDelimeter();
	
EndFunction

// Function returns query text by the balance of InventoryDemand register.
//
Function GenerateQueryTextBalancesInventoryDemand()
	
	QueryText =
	"SELECT
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
	|			AND (ISNULL(InventoryDemandBalances.QuantityBalance, 0) < 0)
	|
	|ORDER BY
	|	LineNumber";
	
	Return QueryText + DriveClientServer.GetQueryDelimeter();
	
EndFunction

#Region ToDoList

Function DocumentsCount(EmployeesList)
	
	Result = New Structure;
	Result.Insert("BuyersOrdersExecutionExpired",	0);
	Result.Insert("BuyersOrdersPaymentExpired",		0);
	Result.Insert("SalesOrdersForToday",			0);
	Result.Insert("BuyersNewOrders",				0);
	Result.Insert("BuyersOrdersInWork",				0);
	Result.Insert("AllSalesOrders",					0);
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	COUNT(DISTINCT CASE
	|			WHEN DocSalesOrder.Posted
	|					AND SalesOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND NOT RunSchedule.Order IS NULL
	|					AND RunSchedule.Period < &StartOfDayIfCurrentDateTimeSession
	|				THEN DocSalesOrder.Ref
	|		END) AS BuyersOrdersExecutionExpired,
	|	COUNT(DISTINCT CASE
	|			WHEN DocSalesOrder.Posted
	|					AND DocSalesOrder.SetPaymentTerms
	|					AND SalesOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND NOT PaymentSchedule.Quote IS NULL
	|					AND PaymentSchedule.Period < &StartOfDayIfCurrentDateTimeSession
	|				THEN DocSalesOrder.Ref
	|		END) AS BuyersOrdersPaymentExpired,
	|	COUNT(DISTINCT CASE
	|			WHEN DocSalesOrder.Posted
	|					AND SalesOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND NOT RunSchedule.Order IS NULL
	|					AND RunSchedule.Period = &StartOfDayIfCurrentDateTimeSession
	|				THEN DocSalesOrder.Ref
	|			WHEN DocSalesOrder.Posted
	|					AND DocSalesOrder.SetPaymentTerms
	|					AND SalesOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND NOT PaymentSchedule.Quote IS NULL
	|					AND PaymentSchedule.Period = &StartOfDayIfCurrentDateTimeSession
	|				THEN DocSalesOrder.Ref
	|		END) AS SalesOrdersForToday,
	|	COUNT(DISTINCT CASE
	|			WHEN UseSalesOrderStatuses.Value
	|				THEN CASE
	|						WHEN SalesOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|							THEN DocSalesOrder.Ref
	|					END
	|			ELSE CASE
	|					WHEN NOT DocSalesOrder.Posted
	|							AND SalesOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|						THEN DocSalesOrder.Ref
	|				END
	|		END) AS BuyersNewOrders,
	|	COUNT(DISTINCT CASE
	|			WHEN DocSalesOrder.Posted
	|					AND SalesOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				THEN DocSalesOrder.Ref
	|		END) AS BuyersOrdersInWork,
	|	COUNT(DISTINCT DocSalesOrder.Ref) AS AllSalesOrders
	|FROM
	|	Document.SalesOrder AS DocSalesOrder
	|		LEFT JOIN InformationRegister.OrderFulfillmentSchedule AS RunSchedule
	|		ON DocSalesOrder.Ref = RunSchedule.Order
	|			AND (RunSchedule.Period <= &StartOfDayIfCurrentDateTimeSession)
	|		{LEFT JOIN InformationRegister.OrdersPaymentSchedule AS PaymentSchedule
	|		ON DocSalesOrder.Ref = PaymentSchedule.Quote
	|			AND (PaymentSchedule.Period <= &StartOfDayIfCurrentDateTimeSession)}
	|		INNER JOIN Catalog.SalesOrderStatuses AS SalesOrderStatuses
	|		ON DocSalesOrder.OrderState = SalesOrderStatuses.Ref,
	|	Constant.UseSalesOrderStatuses AS UseSalesOrderStatuses
	|WHERE
	|	NOT DocSalesOrder.Closed
	|	AND DocSalesOrder.Responsible IN(&EmployeesList)
	|	AND NOT DocSalesOrder.DeletionMark";
	
	Query.SetParameter("EmployeesList",							EmployeesList);
	Query.SetParameter("StartOfDayIfCurrentDateTimeSession",	BegOfDay(CurrentSessionDate()));
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		FillPropertyValues(Result, SelectionDetailRecords);
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

Function PrintEstimate(ObjectArray, PrintObjects, TemplateName, PrintParams)
	Var FirstDocument, FirstRowNumber;
	
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
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_SalesOrder";

	FirstDocument = True;
	
	SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_PF_MXL_Estimate";
	
	Template = PrintManagement.PrintFormTemplate("Document.SalesOrder.PF_MXL_Estimate", LanguageCode);
	ShowCost = SystemSettingsStorage.Load("SalesOrder", "ShowCost");
	If TypeOf(ShowCost)<>Type("Boolean") Then
		ShowCost = IsInRole("FullRights");
	EndIf; 
	
	Query = New Query();
	Query.SetParameter("ObjectArray", ObjectArray);
	Query.Text =
	"SELECT ALLOWED
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.Number AS Number,
	|	SalesOrder.Date AS Date,
	|	SalesOrder.Company AS Company,
	|	SalesOrder.Counterparty AS Counterparty,
	|	SalesOrder.EstimateIsCalculated AS EstimateIsCalculated,
	|	SalesOrder.DocumentAmount AS DocumentAmount
	|INTO Orders
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref IN(&ObjectArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesOrderInventory.Ref AS Ref,
	|	SalesOrderInventory.LineNumber AS LineNumber,
	|	SalesOrderInventory.Products AS Products,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	SalesOrderInventory.Specification AS Specification,
	|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	SalesOrderInventory.Quantity AS Quantity,
	|	SalesOrderInventory.Total AS Total,
	|	SalesOrderInventory.Total / (1 - (SalesOrderInventory.DiscountMarkupPercent + SalesOrderInventory.AutomaticDiscountsPercent) / 100) - SalesOrderInventory.Total AS DiscountAmount,
	|	SalesOrderInventory.ConnectionKey AS ConnectionKey
	|INTO Inventory
	|FROM
	|	Orders AS Orders
	|		LEFT JOIN Document.SalesOrder.Inventory AS SalesOrderInventory
	|		ON Orders.Ref = SalesOrderInventory.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	Orders.Ref,
	|	MAX(SalesOrderInventory.LineNumber) + 1,
	|	NULL,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef),
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef),
	|	NULL,
	|	1,
	|	NULL,
	|	0,
	|	-1
	|FROM
	|	Orders AS Orders
	|		LEFT JOIN Document.SalesOrder.Inventory AS SalesOrderInventory
	|		ON Orders.Ref = SalesOrderInventory.Ref
	|
	|GROUP BY
	|	Orders.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesOrderEstimate.Ref AS Ref,
	|	SalesOrderEstimate.Products AS Products,
	|	SalesOrderEstimate.Characteristic AS Characteristic,
	|	SalesOrderEstimate.Specification AS Specification,
	|	SalesOrderEstimate.Quantity AS Quantity,
	|	SalesOrderEstimate.MeasurementUnit AS MeasurementUnit,
	|	SalesOrderEstimate.Cost AS Cost,
	|	SalesOrderEstimate.ConnectionKey AS ConnectionKey,
	|	SalesOrderEstimate.Source AS Source
	|INTO Estimates
	|FROM
	|	Document.SalesOrder.Estimate AS SalesOrderEstimate
	|WHERE
	|	SalesOrderEstimate.Ref IN(&ObjectArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Orders.Ref AS Ref,
	|	Orders.Number AS Number,
	|	Orders.Date AS DocumentDate,
	|	Orders.Company AS Company,
	|	Orders.Counterparty AS Counterparty,
	|	Orders.Company.Prefix AS Prefix,
	|	Orders.EstimateIsCalculated AS EstimateIsCalculated,
	|	Orders.DocumentAmount AS DocumentAmount,
	|	Estimates.ConnectionKey AS ConnectionKey,
	|	CASE
	|		WHEN VALUETYPE(Estimates.Products) = TYPE(ChartOfAccounts.PrimaryChartOfAccounts)
	|			THEN Estimates.Products.Description
	|		WHEN (CAST(Estimates.Products.DescriptionFull AS STRING(1000))) = """"
	|			THEN Estimates.Products.Description
	|		ELSE CAST(Estimates.Products.DescriptionFull AS STRING(1000))
	|	END AS Products,
	|	Estimates.Characteristic AS Characteristic,
	|	Estimates.Specification AS Specification,
	|	Estimates.Quantity AS Quantity,
	|	Estimates.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(Estimates.Products.SKU, """") AS SKU,
	|	ISNULL(CASE
	|			WHEN VALUETYPE(Inventory.Products) = TYPE(ChartOfAccounts.PrimaryChartOfAccounts)
	|				THEN Inventory.Products.Description
	|			WHEN (CAST(Inventory.Products.DescriptionFull AS STRING(1000))) = """"
	|				THEN Inventory.Products.Description
	|			ELSE CAST(Inventory.Products.DescriptionFull AS STRING(1000))
	|		END, UNDEFINED) AS ProductsProduct,
	|	ISNULL(Inventory.Characteristic, UNDEFINED) AS CharacteristicProduct,
	|	ISNULL(Inventory.Specification, UNDEFINED) AS SpecificationProduct,
	|	ISNULL(Inventory.MeasurementUnit, UNDEFINED) AS MeasurementUnitProduct,
	|	ISNULL(Inventory.Quantity, UNDEFINED) AS ProductQuantity,
	|	ISNULL(Inventory.Products.SKU, """") AS SKUProduct,
	|	ISNULL(Inventory.LineNumber, 999999) AS InventoriesLineNumber,
	|	CASE
	|		WHEN Inventory.Products IS NULL
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AdditionalMaterial,
	|	Estimates.Cost AS Cost,
	|	Inventory.Total AS Total,
	|	Inventory.DiscountAmount AS Discount
	|FROM
	|	Orders AS Orders
	|		LEFT JOIN Estimates AS Estimates
	|			LEFT JOIN Inventory AS Inventory
	|			ON Estimates.Ref = Inventory.Ref
	|				AND (Estimates.ConnectionKey = Inventory.ConnectionKey
	|						AND Estimates.Source = VALUE(Enum.EstimateRowsSources.InventoryItem)
	|					OR Inventory.ConnectionKey = -1
	|						AND Estimates.Source = VALUE(Enum.EstimateRowsSources.Delivery)
	|						AND Estimates.Products = Inventory.Products)
	|		ON Orders.Ref = Estimates.Ref
	|WHERE
	|	Orders.EstimateIsCalculated
	|
	|UNION ALL
	|
	|SELECT
	|	Orders.Ref,
	|	Orders.Number,
	|	Orders.Date,
	|	Orders.Company,
	|	Orders.Counterparty,
	|	Orders.Company.Prefix,
	|	Orders.EstimateIsCalculated,
	|	Orders.DocumentAmount,
	|	Inventory.ConnectionKey,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	Inventory.Products,
	|	Inventory.Characteristic,
	|	Inventory.Specification,
	|	Inventory.MeasurementUnit,
	|	Inventory.Quantity,
	|	Inventory.Products.SKU,
	|	Inventory.LineNumber,
	|	FALSE,
	|	0,
	|	Inventory.Total,
	|	Inventory.DiscountAmount
	|FROM
	|	Orders AS Orders
	|		LEFT JOIN Inventory AS Inventory
	|			LEFT JOIN Estimates AS Estimates
	|			ON Inventory.Ref = Estimates.Ref
	|				AND (Estimates.ConnectionKey = Inventory.ConnectionKey
	|						AND Estimates.Source = VALUE(Enum.EstimateRowsSources.InventoryItem)
	|					OR Inventory.ConnectionKey = -1
	|						AND Estimates.Source = VALUE(Enum.EstimateRowsSources.Delivery)
	|						AND Estimates.Products = Inventory.Products)
	|		ON Orders.Ref = Inventory.Ref
	|WHERE
	|	(Estimates.Ref IS NULL
	|			OR NOT Orders.EstimateIsCalculated)
	|
	|ORDER BY
	|	Ref,
	|	InventoriesLineNumber
	|TOTALS
	|	MAX(Number),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(Counterparty),
	|	MAX(Prefix),
	|	MAX(EstimateIsCalculated),
	|	MAX(DocumentAmount),
	|	MAX(ProductsProduct),
	|	MAX(CharacteristicProduct),
	|	MAX(SpecificationProduct),
	|	MAX(MeasurementUnitProduct),
	|	MAX(ProductQuantity),
	|	MAX(SKUProduct),
	|	SUM(Cost),
	|	MAX(Total),
	|	MAX(Discount)
	|BY
	|	Ref,
	|	InventoriesLineNumber";
	
	// MultilingualSupport
	DriveServer.ChangeQueryTextForCurrentLanguage(Query.Text, LanguageCode);
	// End MultilingualSupport
	
	Header = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	While Header.Next() Do
				
		FirstRowNumber = SpreadsheetDocument.TableHeight + 1;
				
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Company,
			Header.DocumentDate,
			,
			,
			,
			LanguageCode);
		InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Counterparty,
			Header.DocumentDate,
			,
			,
			,
			LanguageCode);
		
		DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
		
		If Not Header.EstimateIsCalculated Then
			TextMessage = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Order #%1, %2 not estimated'; ru = 'Калькуляция заказа №%1, %2 не выполнена';pl = 'Zamówienie nr %1, %2 nie jest oszacowane';es_ES = 'Pedido #%1, %2 no estimado';es_CO = 'Pedido #%1, %2 no estimado';tr = 'Sipariş no. %1, %2 hesaplanmadı';it = 'Ordine #%1, %2 non stimato';de = 'Auftrag Nr.%1, %2 nicht kalkuliert'"),
				DocumentNumber,
				Format(Header.DocumentDate, "DLF=D"));
			CommonClientServer.MessageToUser(TextMessage);
			Continue;
		EndIf; 
		
		TemplateArea = Template.GetArea("Title");
		TemplateArea.Parameters.HeaderText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Sales order estimate #%1 dated %2'; ru = 'Калькуляция заказа покупателя №%1 от %2';pl = 'Szacowanie zamówień sprzedaży nr %1 z dn. %2';es_ES = 'Estimación del pedido de cliente #%1 fechado %2';es_CO = 'Estimación del pedido de cliente #%1 fechado %2';tr = '%1 No.''lu %2 tarihli satış siparişi tahmini';it = 'Ordine cliente stimato #%1 datato %2';de = 'Kundenauftragskalkulation Nr. %1 von %2'", LanguageCode),
			DocumentNumber,
			Format(Header.DocumentDate, "DLF=DD"));
		
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Customer");
		TemplateArea.Parameters.RecipientPresentation = DriveServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr,TIN,LegalAddress,PhoneNumbers,");
		SpreadsheetDocument.Put(TemplateArea);
		
		
		TemplateArea = Template.GetArea("TableHeader");
		SpreadsheetDocument.Put(TemplateArea);
		RowArea = Template.GetArea("String");
		ContentRegion = Template.GetArea("Content");
		
		LineNumber = 0;
		SpreadsheetDocument.StartRowAutoGrouping();
		
		ProductsSelection = Header.Select(QueryResultIteration.ByGroups);
		While ProductsSelection.Next() Do
			
			If ValueIsFilled(ProductsSelection.ProductsProduct) Then
				
				LineNumber = LineNumber + 1;
				
				RowArea.Parameters.Fill(ProductsSelection);
				RowArea.Parameters.InventoryItem = DriveServer.GetProductsPresentationForPrinting(
				ProductsSelection.ProductsProduct, 
				ProductsSelection.CharacteristicProduct, 
				ProductsSelection.SKUProduct);
				RowArea.Parameters.LineNumber = Format(LineNumber, "NG=0");
				SpreadsheetDocument.Put(RowArea, 0);
				
			EndIf; 
			
			ContentSelection = ProductsSelection.Select();
			While ContentSelection.Next() Do
				
				If Not ValueIsFilled(ContentSelection.Products) OR ContentSelection.Products=ContentSelection.ProductsProduct Then
					Continue;
				EndIf; 
				
				If ContentSelection.AdditionalMaterial Then
					
					LineNumber = LineNumber + 1;
					
					RowArea.Parameters.Fill(ContentSelection);
					RowArea.Parameters.InventoryItem = DriveServer.GetProductsPresentationForPrinting(
					ContentSelection.Products, 
					ContentSelection.Characteristic, 
					ContentSelection.SKU);
					RowArea.Parameters.ProductQuantity = ContentSelection.Quantity;
					RowArea.Parameters.MeasurementUnitProduct = ContentSelection.MeasurementUnit;
					RowArea.Parameters.LineNumber = Format(LineNumber, "NG=0");
					SpreadsheetDocument.Put(RowArea, 0);
					Continue;
					
				EndIf;
				
				ContentRegion.Parameters.Fill(ContentSelection);
				
				ContentRegion.Parameters.InventoryItem = DriveServer.GetProductsPresentationForPrinting(
				ContentSelection.Products, 
				ContentSelection.Characteristic, 
				ContentSelection.SKU);
				
				SpreadsheetDocument.Put(ContentRegion, 1);
			
			EndDo; 
			
		EndDo;
		
		SpreadsheetDocument.EndRowAutoGrouping();
		TemplateArea = Template.GetArea("Footer");
		TemplateArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstRowNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	If Not ShowCost Then
		SpreadsheetDocument.DeleteArea(SpreadsheetDocument.Area(, 23, , 25), SpreadsheetDocumentShiftType.Horizontal);
	EndIf;
	
	Return SpreadsheetDocument;
	
EndFunction

Function PrintOrderConfirmation(ObjectsArray, PrintObjects, TemplateName, PrintParams)
	
	DisplayPrintOption = (PrintParams <> Undefined);
	
	StructureFlags			= DriveServer.GetStructureFlags(DisplayPrintOption, PrintParams);
	StructureSecondFlags	= DriveServer.GetStructureSecondFlags(DisplayPrintOption, PrintParams);
	CounterShift			= DriveServer.GetCounterShift(StructureFlags);
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_OrderConfirmation";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	Query.SetParameter("IsPriceBeforeDiscount", StructureSecondFlags.IsPriceBeforeDiscount);
	Query.SetParameter("IsDiscount", StructureFlags.IsDiscount);
	
	#Region PrintOrderConfirmationQueryText
	
	Query.Text = 
	"SELECT ALLOWED
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.Number AS Number,
	|	SalesOrder.Date AS Date,
	|	SalesOrder.Company AS Company,
	|	SalesOrder.CompanyVATNumber AS CompanyVATNumber,
	|	SalesOrder.Counterparty AS Counterparty,
	|	SalesOrder.Contract AS Contract,
	|	SalesOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesOrder.DocumentCurrency AS DocumentCurrency,
	|	SalesOrder.ShipmentDate AS ShipmentDate,
	|	CAST(SalesOrder.Comment AS STRING(1024)) AS Comment,
	|	SalesOrder.ShippingAddress AS ShippingAddress,
	|	SalesOrder.ContactPerson AS ContactPerson,
	|	SalesOrder.DeliveryOption AS DeliveryOption,
	|	SalesOrder.StructuralUnitReserve AS StructuralUnit
	|INTO SalesOrders
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.Number AS DocumentNumber,
	|	SalesOrder.Date AS DocumentDate,
	|	SalesOrder.Company AS Company,
	|	SalesOrder.CompanyVATNumber AS CompanyVATNumber,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	SalesOrder.Counterparty AS Counterparty,
	|	SalesOrder.Contract AS Contract,
	|	CASE
	|		WHEN SalesOrder.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN SalesOrder.ContactPerson
	|		WHEN CounterpartyContracts.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN CounterpartyContracts.ContactPerson
	|		ELSE Counterparties.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	SalesOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesOrder.DocumentCurrency AS DocumentCurrency,
	|	SalesOrder.ShipmentDate AS ShipmentDate,
	|	SalesOrder.Comment AS Comment,
	|	SalesOrder.ShippingAddress AS ShippingAddress,
	|	SalesOrder.DeliveryOption AS DeliveryOption,
	|	SalesOrder.StructuralUnit AS StructuralUnit
	|INTO Header
	|FROM
	|	SalesOrders AS SalesOrder
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON SalesOrder.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON SalesOrder.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON SalesOrder.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesOrderInventory.Ref AS Ref,
	|	SalesOrderInventory.LineNumber AS LineNumber,
	|	SalesOrderInventory.Products AS Products,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	SalesOrderInventory.Batch AS Batch,
	|	SalesOrderInventory.Quantity AS Quantity,
	|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN SalesOrderInventory.Quantity = 0
	|			THEN 0
	|		ELSE CASE
	|				WHEN SalesOrderInventory.DiscountMarkupPercent > 0
	|						OR SalesOrderInventory.AutomaticDiscountAmount > 0
	|					THEN (SalesOrderInventory.Price * SalesOrderInventory.Quantity - SalesOrderInventory.AutomaticDiscountAmount - SalesOrderInventory.Price * SalesOrderInventory.Quantity * SalesOrderInventory.DiscountMarkupPercent / 100) / SalesOrderInventory.Quantity
	|				ELSE SalesOrderInventory.Price
	|			END
	|	END AS Price,
	|	SalesOrderInventory.Price AS PurePrice,
	|	SalesOrderInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	SalesOrderInventory.Total - SalesOrderInventory.VATAmount AS Amount,
	|	SalesOrderInventory.VATRate AS VATRate,
	|	SalesOrderInventory.VATAmount AS VATAmount,
	|	SalesOrderInventory.Total AS Total,
	|	SalesOrderInventory.Content AS Content,
	|	SalesOrderInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	SalesOrderInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	SalesOrderInventory.ConnectionKey AS ConnectionKey,
	|	SalesOrderInventory.BundleProduct AS BundleProduct,
	|	SalesOrderInventory.BundleCharacteristic AS BundleCharacteristic,
	|	CASE
	|		WHEN SalesOrderInventory.DiscountMarkupPercent + SalesOrderInventory.AutomaticDiscountsPercent > 100
	|			THEN 100
	|		ELSE SalesOrderInventory.DiscountMarkupPercent + SalesOrderInventory.AutomaticDiscountsPercent
	|	END AS DiscountPercent,
	|	SalesOrderInventory.Amount AS PureAmount,
	|	ISNULL(VATRates.Rate, 0) AS NumberVATRate,
	|	CAST(SalesOrderInventory.Quantity * SalesOrderInventory.Price - SalesOrderInventory.Amount AS NUMBER(15, 2)) AS DiscountAmount
	|INTO FilteredInventory
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|		LEFT JOIN Catalog.VATRates AS VATRates
	|		ON SalesOrderInventory.VATRate = VATRates.Ref
	|WHERE
	|	SalesOrderInventory.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Counterparty AS Counterparty,
	|	Header.Contract AS Contract,
	|	Header.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Header.AmountIncludesVAT AS AmountIncludesVAT,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	Header.ShipmentDate AS ShipmentDate,
	|	Header.Comment AS Comment,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|			THEN CAST(FilteredInventory.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
	|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """" AS ContentUsed,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END AS CharacteristicDescription,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END AS BatchDescription,
	|	CatalogProducts.UseSerialNumbers AS UseSerialNumbers,
	|	MIN(FilteredInventory.ConnectionKey) AS ConnectionKey,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
	|	SUM(FilteredInventory.Quantity) AS Quantity,
	|	CASE
	|		WHEN &IsPriceBeforeDiscount
	|			THEN FilteredInventory.PurePrice
	|		ELSE FilteredInventory.Price
	|	END AS Price,
	|	SUM(FilteredInventory.AutomaticDiscountAmount) AS AutomaticDiscountAmount,
	|	FilteredInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	SUM(FilteredInventory.Amount) AS Amount,
	|	SUM(CAST(FilteredInventory.PurePrice * CASE
	|				WHEN CatalogProducts.IsFreightService
	|					THEN FilteredInventory.Quantity
	|				ELSE 0
	|			END * CASE
	|				WHEN Header.AmountIncludesVAT
	|					THEN 1 / (1 + FilteredInventory.NumberVATRate / 100)
	|				ELSE 1
	|			END AS NUMBER(15, 2))) AS Freight,
	|	FilteredInventory.VATRate AS VATRate,
	|	SUM(FilteredInventory.VATAmount) AS VATAmount,
	|	SUM(FilteredInventory.Total) AS Total,
	|	SUM(CASE
	|			WHEN &IsDiscount
	|				THEN CASE
	|						WHEN Header.AmountIncludesVAT
	|							THEN CAST(FilteredInventory.Quantity * FilteredInventory.PurePrice / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|						ELSE CAST(FilteredInventory.Quantity * FilteredInventory.PurePrice AS NUMBER(15, 2))
	|					END
	|			ELSE CASE
	|					WHEN Header.AmountIncludesVAT
	|						THEN CAST((FilteredInventory.Quantity * FilteredInventory.PurePrice - FilteredInventory.DiscountAmount) / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|					ELSE CAST(FilteredInventory.Quantity * FilteredInventory.PurePrice - FilteredInventory.DiscountAmount AS NUMBER(15, 2))
	|				END
	|		END * CASE
	|			WHEN CatalogProducts.IsFreightService
	|				THEN 0
	|			ELSE 1
	|		END) AS Subtotal,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.Batch AS Batch,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	Header.ShippingAddress AS ShippingAddress,
	|	Header.DeliveryOption AS DeliveryOption,
	|	Header.StructuralUnit AS StructuralUnit,
	|	CatalogProducts.IsFreightService AS IsFreightService,
	|	FilteredInventory.BundleProduct AS BundleProduct,
	|	FilteredInventory.BundleCharacteristic AS BundleCharacteristic,
	|	FilteredInventory.DiscountPercent AS DiscountPercent,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST(FilteredInventory.DiscountAmount / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|			ELSE FilteredInventory.DiscountAmount
	|		END) AS DiscountAmount,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST(FilteredInventory.PureAmount / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|			ELSE FilteredInventory.PureAmount
	|		END) AS NetAmount,
	|	FilteredInventory.PurePrice AS PurePrice
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (FilteredInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (FilteredInventory.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.ProductsBatches AS CatalogBatches
	|		ON (FilteredInventory.Batch = CatalogBatches.Ref)
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOM.Ref)
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOMClassifier.Ref)
	|
	|GROUP BY
	|	FilteredInventory.VATRate,
	|	Header.Company,
	|	Header.CompanyVATNumber,
	|	Header.Counterparty,
	|	Header.Contract,
	|	CatalogProducts.SKU,
	|	Header.CounterpartyContactPerson,
	|	Header.AmountIncludesVAT,
	|	Header.Comment,
	|	CASE
	|		WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|			THEN CAST(FilteredInventory.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	Header.ShipmentDate,
	|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """",
	|	Header.CompanyLogoFile,
	|	Header.DocumentNumber,
	|	Header.DocumentCurrency,
	|	Header.Ref,
	|	Header.DocumentDate,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	CatalogProducts.UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.DiscountMarkupPercent,
	|	FilteredInventory.Products,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.Batch,
	|	FilteredInventory.MeasurementUnit,
	|	Header.ShippingAddress,
	|	Header.DeliveryOption,
	|	Header.StructuralUnit,
	|	CatalogProducts.IsFreightService,
	|	FilteredInventory.BundleProduct,
	|	FilteredInventory.BundleCharacteristic,
	|	FilteredInventory.DiscountPercent,
	|	CASE
	|		WHEN &IsPriceBeforeDiscount
	|			THEN FilteredInventory.PurePrice
	|		ELSE FilteredInventory.Price
	|	END,
	|	FilteredInventory.Price,
	|	FilteredInventory.PurePrice
	|
	|UNION ALL
	|
	|SELECT
	|	Header.Ref,
	|	Header.DocumentNumber,
	|	Header.DocumentDate,
	|	Header.Company,
	|	Header.CompanyVATNumber,
	|	Header.CompanyLogoFile,
	|	Header.Counterparty,
	|	Header.Contract,
	|	Header.CounterpartyContactPerson,
	|	Header.AmountIncludesVAT,
	|	Header.DocumentCurrency,
	|	Header.ShipmentDate,
	|	Header.Comment,
	|	SalesOrderWorks.LineNumber,
	|	CatalogProducts.SKU,
	|	CASE
	|		WHEN (CAST(SalesOrderWorks.Content AS STRING(1024))) <> """"
	|			THEN CAST(SalesOrderWorks.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	(CAST(SalesOrderWorks.Content AS STRING(1024))) <> """",
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	"""",
	|	CatalogProducts.UseSerialNumbers,
	|	SalesOrderWorks.ConnectionKey,
	|	CatalogUOMClassifier.Description,
	|	CAST(SalesOrderWorks.Quantity * SalesOrderWorks.Factor * SalesOrderWorks.Multiplicity AS NUMBER(15, 3)),
	|	CASE
	|		WHEN &IsPriceBeforeDiscount
	|			THEN SalesOrderWorks.Price
	|		ELSE CASE
	|				WHEN SalesOrderWorks.Quantity = 0
	|					THEN 0
	|				ELSE SalesOrderWorks.Amount / SalesOrderWorks.Quantity
	|			END
	|	END,
	|	SalesOrderWorks.AutomaticDiscountAmount,
	|	SalesOrderWorks.DiscountMarkupPercent,
	|	SalesOrderWorks.Amount,
	|	0,
	|	SalesOrderWorks.VATRate,
	|	SalesOrderWorks.VATAmount,
	|	SalesOrderWorks.Total,
	|	CASE
	|		WHEN &IsDiscount
	|			THEN CASE
	|					WHEN Header.AmountIncludesVAT
	|						THEN CAST(SalesOrderWorks.Quantity * SalesOrderWorks.Price / (1 + ISNULL(VATRates.Rate, 0) / 100) AS NUMBER(15, 2))
	|					ELSE CAST(SalesOrderWorks.Quantity * SalesOrderWorks.Price AS NUMBER(15, 2))
	|				END
	|		ELSE CASE
	|				WHEN Header.AmountIncludesVAT
	|					THEN CAST(SalesOrderWorks.Amount / (1 + ISNULL(VATRates.Rate, 0) / 100) AS NUMBER(15, 2))
	|				ELSE CAST(SalesOrderWorks.Amount AS NUMBER(15, 2))
	|			END
	|	END,
	|	CatalogProducts.Ref,
	|	CatalogCharacteristics.Ref,
	|	VALUE(Catalog.ProductsBatches.EmptyRef),
	|	CatalogUOMClassifier.Ref,
	|	Header.ShippingAddress,
	|	Header.DeliveryOption,
	|	Header.StructuralUnit,
	|	CatalogProducts.IsFreightService,
	|	NULL,
	|	NULL,
	|	CASE
	|		WHEN SalesOrderWorks.DiscountMarkupPercent + SalesOrderWorks.AutomaticDiscountsPercent > 100
	|			THEN 100
	|		ELSE SalesOrderWorks.DiscountMarkupPercent + SalesOrderWorks.AutomaticDiscountsPercent
	|	END,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN CAST(SalesOrderWorks.Quantity * SalesOrderWorks.Price - SalesOrderWorks.Amount / (1 + ISNULL(VATRates.Rate, 0) / 100) AS NUMBER(15, 2))
	|		ELSE CAST(SalesOrderWorks.Quantity * SalesOrderWorks.Price - SalesOrderWorks.Amount AS NUMBER(15, 2))
	|	END,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN CAST(SalesOrderWorks.Amount / (1 + ISNULL(VATRates.Rate, 0) / 100) AS NUMBER(15, 2))
	|		ELSE SalesOrderWorks.Amount
	|	END,
	|	0
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.SalesOrder.Works AS SalesOrderWorks
	|		ON Header.Ref = SalesOrderWorks.Ref
	|		LEFT JOIN Catalog.VATRates AS VATRates
	|		ON (SalesOrderWorks.VATRate = VATRates.Ref)
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (SalesOrderWorks.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (SalesOrderWorks.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (CatalogProducts.MeasurementUnit = CatalogUOMClassifier.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyVATNumber AS CompanyVATNumber,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Counterparty AS Counterparty,
	|	Tabular.Contract AS Contract,
	|	Tabular.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Tabular.AmountIncludesVAT AS AmountIncludesVAT,
	|	Tabular.DocumentCurrency AS DocumentCurrency,
	|	Tabular.ShipmentDate AS ShipmentDate,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.ContentUsed AS ContentUsed,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Price AS Price,
	|	CASE
	|		WHEN Tabular.AutomaticDiscountAmount = 0
	|			THEN Tabular.DiscountMarkupPercent
	|		WHEN Tabular.Subtotal = 0
	|			THEN 0
	|		ELSE CAST((Tabular.Subtotal - Tabular.Amount) / Tabular.Subtotal * 100 AS NUMBER(15, 2))
	|	END AS DiscountRate,
	|	Tabular.Amount AS Amount,
	|	Tabular.Freight AS FreightTotal,
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	Tabular.DiscountAmount AS DiscountAmount,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	Tabular.ShippingAddress AS ShippingAddress,
	|	Tabular.DeliveryOption AS DeliveryOption,
	|	Tabular.StructuralUnit AS StructuralUnit,
	|	Tabular.BundleProduct AS BundleProduct,
	|	Tabular.BundleCharacteristic AS BundleCharacteristic,
	|	Tabular.Products AS Products,
	|	Tabular.DiscountPercent AS DiscountPercent,
	|	Tabular.NetAmount AS NetAmount
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyVATNumber),
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(Contract),
	|	MAX(CounterpartyContactPerson),
	|	MAX(AmountIncludesVAT),
	|	MAX(DocumentCurrency),
	|	MAX(ShipmentDate),
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	SUM(FreightTotal),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	SUM(DiscountAmount),
	|	MAX(ShippingAddress),
	|	MAX(DeliveryOption),
	|	MAX(StructuralUnit)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	FilteredInventory AS FilteredInventory
	|		INNER JOIN Tabular AS Tabular
	|		ON FilteredInventory.Products = Tabular.Products
	|			AND FilteredInventory.DiscountMarkupPercent = Tabular.DiscountMarkupPercent
	|			AND FilteredInventory.PurePrice = Tabular.PurePrice
	|			AND FilteredInventory.VATRate = Tabular.VATRate
	|			AND (NOT Tabular.ContentUsed)
	|			AND FilteredInventory.Ref = Tabular.Ref
	|			AND FilteredInventory.Characteristic = Tabular.Characteristic
	|			AND FilteredInventory.MeasurementUnit = Tabular.MeasurementUnit
	|			AND FilteredInventory.Batch = Tabular.Batch
	|		INNER JOIN Document.SalesInvoice.SerialNumbers AS SalesOrderSerialNumbers
	|			LEFT JOIN Catalog.SerialNumbers AS SerialNumbers
	|			ON SalesOrderSerialNumbers.SerialNumber = SerialNumbers.Ref
	|		ON (SalesOrderSerialNumbers.ConnectionKey = FilteredInventory.ConnectionKey)
	|			AND FilteredInventory.Ref = SalesOrderSerialNumbers.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(Tabular.LineNumber) AS LineNumber,
	|	Tabular.Ref AS Ref,
	|	SUM(Tabular.Quantity) AS Quantity
	|FROM
	|	Tabular AS Tabular
	|WHERE
	|	NOT Tabular.IsFreightService
	|
	|GROUP BY
	|	Tabular.Ref";
	
	#EndRegion
	
	// MultilingualSupport
	If PrintParams = Undefined Then
		LanguageCode = NationalLanguageSupportClientServer.DefaultLanguageCode();
	Else
		LanguageCode = PrintParams.LanguageCode;
	EndIf;
	
	If LanguageCode <> CurrentLanguage().LanguageCode Then 
		SessionParameters.LanguageCodeForOutput = LanguageCode;
	EndIf;
	
	DriveServer.ChangeQueryTextForCurrentLanguage(Query.Text, LanguageCode);
	// End MultilingualSupport
	
	ResultArray = Query.ExecuteBatch();
	
	FirstDocument = True;
	
	Header 				= ResultArray[4].Select(QueryResultIteration.ByGroupsWithHierarchy);
	SerialNumbersSel	= ResultArray[5].Select();
	TotalLineNumber		= ResultArray[6].Unload();
	
	// Bundles
	TableColumns = ResultArray[4].Columns;
	// End Bundles
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_SalesOrder_OrderConfirmation";
		
		Template = PrintManagement.PrintFormTemplate("Document.SalesOrder.PF_MXL_OrderConfirmation", LanguageCode);
		
		#Region PrintOrderConfirmationTitleArea
		
		StringNameLineArea = "Title";
		TitleArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
		TitleArea.Parameters.Fill(Header);
		
		IsPictureLogo = False;
		If ValueIsFilled(Header.CompanyLogoFile) Then
			
			PictureData = AttachedFiles.GetBinaryFileData(Header.CompanyLogoFile);
			If ValueIsFilled(PictureData) Then
				
				TitleArea.Drawings.Logo.Picture = New Picture(PictureData);
				
				IsPictureLogo = True;
				
			EndIf;
			
		Else
			
			TitleArea.Drawings.Delete(TitleArea.Drawings.Logo);
			
		EndIf;
		
		SpreadsheetDocument.Put(TitleArea);
		
		DriveServer.AddPartAdditionalToAreaWithShift(
			Template,
			SpreadsheetDocument,
			CounterShift,
			StringNameLineArea,
			"PartAdditional" + StringNameLineArea);
		
		If IsPictureLogo Then
			DriveServer.MakeShiftPictureWithShift(SpreadsheetDocument.Drawings.Logo, CounterShift - 1);
		EndIf;
		
		#EndRegion
		
		#Region PrintOrderConfirmationCompanyInfoArea
		
		StringNameLineArea = "CompanyInfo";
		CompanyInfoArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Company, Header.DocumentDate, , , Header.CompanyVATNumber, LanguageCode);
		CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
		BarcodesInPrintForms.AddBarcodeToTableDocument(CompanyInfoArea, Header.Ref);
		
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		DriveServer.AddPartAdditionalToAreaWithShift(
			Template,
			SpreadsheetDocument,
			CounterShift,
			StringNameLineArea,
			"PartAdditional" + StringNameLineArea);
		
		IsPictureBarcode = GetFunctionalOption("UseBarcodesInPrintForms");	
		If IsPictureBarcode Then
			DriveServer.MakeShiftPictureWithShift(SpreadsheetDocument.Drawings.DocumentBarcode, CounterShift - 1);
		EndIf;
			
		#EndRegion
		
		#Region PrintOrderConfirmationCounterpartyInfoArea
		
		StringNameLineArea = "CounterpartyInfo";
		CounterpartyInfoArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
		CounterpartyInfoArea.Parameters.Fill(Header);
		
		InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Counterparty,
			Header.DocumentDate,
			,
			,
			,
			LanguageCode);
		CounterpartyInfoArea.Parameters.Fill(InfoAboutCounterparty);
		
		TitleParameters = New Structure;
		TitleParameters.Insert("TitleShipTo", NStr("en = 'Ship to'; ru = 'Грузополучатель';pl = 'Dostawa do';es_ES = 'Enviar a';es_CO = 'Enviar a';tr = 'Sevk et';it = 'Spedire a';de = 'Versand an'", LanguageCode));
		TitleParameters.Insert("TitleShipDate", NStr("en = 'Ship date'; ru = 'Дата доставки';pl = 'Data wysyłki';es_ES = 'Fecha de envío';es_CO = 'Fecha de envío';tr = 'Gönderme tarihi';it = 'Data di spedizione';de = 'Versanddatum'", LanguageCode));
		
		If Header.DeliveryOption = Enums.DeliveryOptions.SelfPickup Then
			
			InfoAboutPickupLocation	= DriveServer.InfoAboutLegalEntityIndividual(
				Header.StructuralUnit,
				Header.DocumentDate,
				,
				,
				,
				LanguageCode);
			ResponsibleEmployee		= InfoAboutPickupLocation.ResponsibleEmployee;
			
			If NOT IsBlankString(InfoAboutPickupLocation.FullDescr) Then
				CounterpartyInfoArea.Parameters.FullDescrShipTo = InfoAboutPickupLocation.FullDescr;
			EndIf;
			
			If NOT IsBlankString(InfoAboutPickupLocation.DeliveryAddress) Then
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutPickupLocation.DeliveryAddress;
			EndIf;
			
			If ValueIsFilled(ResponsibleEmployee) Then
				CounterpartyInfoArea.Parameters.CounterpartyContactPerson = ResponsibleEmployee.Description;
			EndIf;
			
			If NOT IsBlankString(InfoAboutPickupLocation.PhoneNumbers) Then
				CounterpartyInfoArea.Parameters.PhoneNumbers = InfoAboutPickupLocation.PhoneNumbers;
			EndIf;
			
			TitleParameters.TitleShipTo		= NStr("en = 'Pickup location'; ru = 'Место самовывоза';pl = 'Miejsce odbioru osobistego';es_ES = 'Ubicación de recogida';es_CO = 'Ubicación de recogida';tr = 'Toplama yeri';it = 'Punto di presa';de = 'Abholort'", LanguageCode);
			TitleParameters.TitleShipDate	= NStr("en = 'Pickup date'; ru = 'Дата самовывоза';pl = 'Data odbioru osobistego';es_ES = 'Fecha de recogida';es_CO = 'Fecha de recogida';tr = 'Toplama tarihi';it = 'Data di presa';de = 'Abholdatum'", LanguageCode);
			
		Else
			
			InfoAboutShippingAddress	= DriveServer.InfoAboutShippingAddress(Header.ShippingAddress);
			InfoAboutContactPerson		= DriveServer.InfoAboutContactPerson(Header.CounterpartyContactPerson);
		
			If NOT IsBlankString(InfoAboutShippingAddress.DeliveryAddress) Then
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutShippingAddress.DeliveryAddress;
			EndIf;
			
			If NOT IsBlankString(InfoAboutContactPerson.PhoneNumbers) Then
				CounterpartyInfoArea.Parameters.PhoneNumbers = InfoAboutContactPerson.PhoneNumbers;
			EndIf;
			
		EndIf;
		
		CounterpartyInfoArea.Parameters.Fill(TitleParameters);
		
		If IsBlankString(CounterpartyInfoArea.Parameters.DeliveryAddress) Then
			
			If Not IsBlankString(InfoAboutCounterparty.ActualAddress) Then
				
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutCounterparty.ActualAddress;
				
			Else
				
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutCounterparty.LegalAddress;
				
			EndIf;
			
		EndIf;
		
		CounterpartyInfoArea.Parameters.PaymentTerms = PaymentTermsServer.TitleStagesOfPayment(Header.Ref);
		If ValueIsFilled(CounterpartyInfoArea.Parameters.PaymentTerms) Then
			CounterpartyInfoArea.Parameters.PaymentTermsTitle = PaymentTermsServer.PaymentTermsPrintTitle();
		EndIf;
		
		SpreadsheetDocument.Put(CounterpartyInfoArea);
		
		DriveServer.AddPartAdditionalToAreaWithShift(
			Template,
			SpreadsheetDocument,
			CounterShift,
			StringNameLineArea,
			"PartAdditional" + StringNameLineArea);
		
		#EndRegion
		
		#Region PrintOrderConfirmationCommentArea
		
		StringNameLineArea = "Comment";
		CommentArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
		CommentArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(CommentArea);
		
		DriveServer.AddPartAdditionalToAreaWithShift(
			Template,
			SpreadsheetDocument,
			CounterShift,
			StringNameLineArea,
			"PartAdditional" + StringNameLineArea);
		
		#EndRegion
		
		#Region PrintOrderConfirmationTotalsAreaPrefill
		
		TotalsAreasArray	= New Array;
		TotalsArea			= New SpreadsheetDocument;
		
		StringNameLineTotalArea = ?(StructureFlags.IsDiscount, "LineTotal", "LineTotalWithoutDiscount");
		
		StringNameTotalAreaStart		= ?(StructureFlags.IsDiscount, "PartStartLineTotal", "PartStartLineTotalWithoutDiscount");
		StringNameTotalAreaAdditional	= ?(StructureFlags.IsDiscount, "PartAdditional", "PartAdditionalWithoutDiscount");
		StringNameTotalAreaEnd			= ?(StructureFlags.IsDiscount, "PartEndLineTotal", "PartEndLineTotalWithoutDiscount");
		
		LineTotalArea = Template.GetArea(StringNameLineTotalArea + "|" + StringNameTotalAreaStart);
		LineTotalArea.Parameters.Fill(Header);
			
		SearchStructure = New Structure("Ref", Header.Ref);
		
		SearchArray = TotalLineNumber.FindRows(SearchStructure);
		If SearchArray.Count() > 0 Then
			LineTotalArea.Parameters.Quantity	= SearchArray[0].Quantity;
			LineTotalArea.Parameters.LineNumber	= SearchArray[0].LineNumber;
		Else
			LineTotalArea.Parameters.Quantity	= 0;
			LineTotalArea.Parameters.LineNumber	= 0;
		EndIf;
		
		TotalsArea.Put(LineTotalArea);
			
		DriveServer.AddPartAdditionalToAreaWithShift(
			Template,
			TotalsArea,
			CounterShift + 1,
			StringNameLineTotalArea,
			"PartAdditional" + StringNameLineTotalArea);
			
		LineTotalEndArea = Template.GetArea(StringNameLineTotalArea + "|" + StringNameTotalAreaEnd);
		LineTotalEndArea.Parameters.Fill(Header);
		
		TotalsArea.Join(LineTotalEndArea);
		
		TotalsAreasArray.Add(TotalsArea);
		
		#EndRegion
		
		#Region PrintOrderConfirmationLinesArea
		
		CounterBundle = DriveServer.GetCounterBundle();
			
		If DisplayPrintOption 
			And PrintParams.CodesPosition <> Enums.CodesPositionInPrintForms.SeparateColumn Then
			
			StringNameLineHeader	= "LineHeaderWithoutCode";
			StringNameLineSection	= "LineSectionWithoutCode";
			
			StringPostfix 			= "LineWithoutCode";
			
		Else
			
			StringNameLineHeader	= "LineHeader";
			StringNameLineSection	= "LineSection";
			
			StringPostfix 			= "Line";
			
		EndIf;
		
		StringNameStartPart		= "PartStart"+StringPostfix;
		StringNamePrice			= ?(StructureSecondFlags.IsPriceBeforeDiscount, "PartPriceBefore", "PartPrice")+StringPostfix;
		StringNameVATPart		= "PartVAT"+StringPostfix;
		StringNameDiscount		= "PartDiscount"+StringPostfix;
		StringNameNetAmount		= "PartNetAmount"+StringPostfix;
		StringNameTotalPart		= "PartTotal"+StringPostfix;
		
		// Start
		
		LineHeaderAreaStart		= Template.GetArea(StringNameLineHeader + "|" + StringNameStartPart);
		LineSectionAreaStart	= Template.GetArea(StringNameLineSection + "|" + StringNameStartPart);
		
		SpreadsheetDocument.Put(LineHeaderAreaStart);
		
		// Price
		
		LineHeaderAreaPrice = Template.GetArea(StringNameLineHeader + "|" + StringNamePrice);
		LineSectionAreaPrice = Template.GetArea(StringNameLineSection + "|" + StringNamePrice);
			
		SpreadsheetDocument.Join(LineHeaderAreaPrice);
		
		// Discount 
		
		If StructureFlags.IsDiscount Then
			
			LineHeaderAreaDiscount = Template.GetArea(StringNameLineHeader + "|" + StringNameDiscount);
			LineSectionAreaDiscount = Template.GetArea(StringNameLineSection + "|" + StringNameDiscount);
			
			SpreadsheetDocument.Join(LineHeaderAreaDiscount);
			
		EndIf;
		
		// Tax
		
		If StructureSecondFlags.IsTax Then
			
			LineHeaderAreaVAT		= Template.GetArea(StringNameLineHeader + "|" + StringNameVATPart);
			LineSectionAreaVAT		= Template.GetArea(StringNameLineSection + "|" + StringNameVATPart);
			
			SpreadsheetDocument.Join(LineHeaderAreaVAT);
			
		EndIf;
		
		// Net amount
		
		If StructureFlags.IsNetAmount Then
			
			LineHeaderAreaNetAmount = Template.GetArea(StringNameLineHeader + "|" + StringNameNetAmount);
			LineSectionAreaNetAmount = Template.GetArea(StringNameLineSection + "|" + StringNameNetAmount);
			
			SpreadsheetDocument.Join(LineHeaderAreaNetAmount);
			
		EndIf;
		
		// Total
		
		If StructureFlags.IsLineTotal Then
			
			LineHeaderAreaTotal		= Template.GetArea(StringNameLineHeader + "|" + StringNameTotalPart);
			LineSectionAreaTotal	= Template.GetArea(StringNameLineSection + "|" + StringNameTotalPart);
			
			SpreadsheetDocument.Join(LineHeaderAreaTotal);
			
		EndIf;
		
		SeeNextPageArea	= DriveServer.GetAreaDocumentFooters(Template, "SeeNextPage", CounterShift);
		EmptyLineArea	= Template.GetArea("EmptyLine");
		PageNumberArea	= DriveServer.GetAreaDocumentFooters(Template, "PageNumber", CounterShift);
		
		PageNumber = 0;
		
		AreasToBeChecked = New Array;
		
		// Bundles
		TableInventoty = BundlesServer.AssemblyTableByBundles(Header.Ref, Header, TableColumns, LineTotalArea);
		EmptyColor = LineSectionAreaStart.CurrentArea.TextColor;
		// End Bundles
		
		PricePrecision = PrecisionAppearancetServer.CompanyPrecision(Header.Company);
		
		For Each TabSelection In TableInventoty Do
			
			If TypeOf(TabSelection.FreightTotal) = Type("Number")
				And TabSelection.FreightTotal <> 0 Then
				Continue;
			EndIf;
			
			LineSectionAreaStart.Parameters.Fill(TabSelection);
			LineSectionAreaPrice.Parameters.Fill(TabSelection);
			LineSectionAreaPrice.Parameters.Price = Format(TabSelection.Price,
				"NFD= " + PricePrecision);
			
			If StructureFlags.IsDiscount Then
				
				If Not TabSelection.DiscountPercent = Undefined Then
					LineSectionAreaDiscount.Parameters.SignPercent = "%";
				Else
					LineSectionAreaDiscount.Parameters.SignPercent = "";
				EndIf;
				
				LineSectionAreaDiscount.Parameters.Fill(TabSelection);
				
			EndIf;
			
			If StructureSecondFlags.IsTax Then
				LineSectionAreaVAT.Parameters.Fill(TabSelection);
			EndIf;
			
			If StructureFlags.IsNetAmount Then
				LineSectionAreaNetAmount.Parameters.Fill(TabSelection);
			EndIf;
			
			If StructureFlags.IsLineTotal Then
				LineSectionAreaTotal.Parameters.Fill(TabSelection);
			EndIf;
			
			DriveClientServer.ComplimentProductDescription(LineSectionAreaStart.Parameters.ProductDescription, TabSelection, SerialNumbersSel);
			
			// Display selected codes if functional option is turned on.
			If DisplayPrintOption Then
				CodesPresentation = PrintManagementServerCallDrive.GetCodesPresentation(PrintParams, TabSelection.Products);
				If PrintParams.CodesPosition = Enums.CodesPositionInPrintForms.SeparateColumn Then
					LineSectionAreaStart.Parameters.SKU = CodesPresentation;
				ElsIf PrintParams.CodesPosition = Enums.CodesPositionInPrintForms.ProductColumn Then
					LineSectionAreaStart.Parameters.ProductDescription = 
						LineSectionAreaStart.Parameters.ProductDescription + Chars.CR + CodesPresentation;
				EndIf;
			EndIf;
			
			
			// Bundles
			
			BundleColor =  BundlesServer.GetBundleComponentsColor(TabSelection, EmptyColor);
			
			LineSectionAreaStart.Area(1,1,1,CounterBundle).TextColor = BundleColor;
			LineSectionAreaPrice.CurrentArea.TextColor = BundleColor;
			If StructureFlags.IsDiscount Then
				LineSectionAreaDiscount.CurrentArea.TextColor = BundleColor;
			EndIf;
			If StructureSecondFlags.IsTax Then
				LineSectionAreaVAT.Area(1,1,1,2).TextColor = BundleColor;
			EndIf;
			If StructureFlags.IsNetAmount Then
				LineSectionAreaNetAmount.CurrentArea.TextColor = BundleColor;
			EndIf;
			If StructureFlags.IsLineTotal Then
				LineSectionAreaTotal.CurrentArea.TextColor = BundleColor;
			EndIf;
			
			// End Bundles
			
			AreasToBeChecked.Clear();
			AreasToBeChecked.Add(LineSectionAreaStart);
			For Each Area In TotalsAreasArray Do
				AreasToBeChecked.Add(Area);
			EndDo;
			AreasToBeChecked.Add(PageNumberArea);
			
			If Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
				
				SpreadsheetDocument.Put(LineSectionAreaStart);
				SpreadsheetDocument.Join(LineSectionAreaPrice);
				If StructureFlags.IsDiscount Then
					SpreadsheetDocument.Join(LineSectionAreaDiscount);
				EndIf;
				If StructureSecondFlags.IsTax Then
					SpreadsheetDocument.Join(LineSectionAreaVAT);
				EndIf;
				If StructureFlags.IsNetAmount Then
					SpreadsheetDocument.Join(LineSectionAreaNetAmount);
				EndIf;
				If StructureFlags.IsLineTotal Then
					SpreadsheetDocument.Join(LineSectionAreaTotal);
				EndIf;
				
			Else
				
				SpreadsheetDocument.Put(SeeNextPageArea);
				
				AreasToBeChecked.Clear();
				AreasToBeChecked.Add(EmptyLineArea);
				AreasToBeChecked.Add(PageNumberArea);
				
				For i = 1 To 50 Do
					
					If Not Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
						Or i = 50 Then
						
						PageNumber = PageNumber + 1;
						PageNumberArea.Parameters.PageNumber = PageNumber;
						SpreadsheetDocument.Put(PageNumberArea);
						Break;
						
					Else
						
						SpreadsheetDocument.Put(EmptyLineArea);
						
					EndIf;
					
				EndDo;
				
				SpreadsheetDocument.PutHorizontalPageBreak();
				#Region PrintTitleArea
				
				SpreadsheetDocument.Put(TitleArea);
				StringNameLineArea = "Title";
				DriveServer.AddPartAdditionalToAreaWithShift(
					Template,
					SpreadsheetDocument,
					CounterShift,
					StringNameLineArea,
					"PartAdditional" + StringNameLineArea); 
					
				If IsPictureLogo Then
					DriveServer.MakeShiftPictureWithShift(SpreadsheetDocument.Drawings.Logo, CounterShift - 1);
				EndIf;
				
				#EndRegion
				
				// Header
				
				SpreadsheetDocument.Put(LineHeaderAreaStart);
				SpreadsheetDocument.Join(LineHeaderAreaPrice);
				If StructureFlags.IsDiscount Then
					SpreadsheetDocument.Join(LineHeaderAreaDiscount);
				EndIf;
				If StructureSecondFlags.IsTax Then
					SpreadsheetDocument.Join(LineHeaderAreaVAT);
				EndIf;
				If StructureFlags.IsNetAmount Then
					SpreadsheetDocument.Join(LineHeaderAreaNetAmount);
				EndIf;
				If StructureFlags.IsLineTotal Then
					SpreadsheetDocument.Join(LineHeaderAreaTotal);
				EndIf;
				
				// Section
				
				SpreadsheetDocument.Put(LineSectionAreaStart);
				SpreadsheetDocument.Join(LineSectionAreaPrice);
				If StructureFlags.IsDiscount Then
					SpreadsheetDocument.Join(LineSectionAreaDiscount);
				EndIf;
				If StructureSecondFlags.IsTax Then
					SpreadsheetDocument.Join(LineSectionAreaVAT);
				EndIf;
				If StructureFlags.IsNetAmount Then
					SpreadsheetDocument.Join(LineSectionAreaNetAmount);
				EndIf;
				If StructureFlags.IsLineTotal Then
					SpreadsheetDocument.Join(LineSectionAreaTotal);
				EndIf;
				
			EndIf;
			
		EndDo;
		
		#EndRegion
		
		#Region PrintOrderConfirmationTotalsArea
		
		For Each Area In TotalsAreasArray Do
			
			SpreadsheetDocument.Put(Area);
			
		EndDo;
		
		#Region PrintAdditionalAttributes
		If DisplayPrintOption And PrintParams.AdditionalAttributes
			And PrintManagementServerCallDrive.HasAdditionalAttributes(Header.Ref) Then
			
			SpreadsheetDocument.Put(EmptyLineArea);
			
				StringNameLineArea = "AdditionalAttributesStaticHeader";
				
				AddAttribHeader = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
				SpreadsheetDocument.Put(AddAttribHeader);
				
				DriveServer.AddPartAdditionalToAreaWithShift(
					Template,
					SpreadsheetDocument,
					CounterShift,
					StringNameLineArea,
					"PartAdditional" + StringNameLineArea);
				
				SpreadsheetDocument.Put(EmptyLineArea);
				
				AddAttribHeader = Template.GetArea("AdditionalAttributesHeader");
				SpreadsheetDocument.Put(AddAttribHeader);
				
				AddAttribRow = Template.GetArea("AdditionalAttributesRow");
				
				For each Attr In Header.Ref.AdditionalAttributes Do
					AddAttribRow.Parameters.AddAttributeName = Attr.Property.Title;
					AddAttribRow.Parameters.AddAttributeValue = Attr.Value;
					SpreadsheetDocument.Put(AddAttribRow);                
				EndDo;
				
			EndIf;
			#EndRegion
			
		AreasToBeChecked.Clear();
		AreasToBeChecked.Add(EmptyLineArea);
		AreasToBeChecked.Add(PageNumberArea);
		
		For i = 1 To 50 Do
			
			If Not Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
				Or i = 50 Then
				
				PageNumber = PageNumber + 1;
				PageNumberArea.Parameters.PageNumber = PageNumber;
				SpreadsheetDocument.Put(PageNumberArea);
				Break;
				
			Else
				
				SpreadsheetDocument.Put(EmptyLineArea);
				
			EndIf;
			
		EndDo;
		
		#EndRegion
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// Function checks if the document is posted and calls
// the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined)
	
	If TemplateName = "Quote" Then
		
		Return DataProcessors.PrintQuote.PrintQuote(ObjectsArray, PrintObjects, TemplateName, PrintParams);
		
	ElsIf TemplateName = "ProformaInvoice" Then
		
		Return DataProcessors.PrintQuote.PrintProformaInvoice(ObjectsArray, PrintObjects, TemplateName, PrintParams);
				
	ElsIf TemplateName = "Estimate" Then
		
		Return PrintEstimate(ObjectsArray, PrintObjects, TemplateName, PrintParams);
		
	ElsIf TemplateName = "OrderConfirmation" Then
		
		Return PrintOrderConfirmation(ObjectsArray, PrintObjects, TemplateName, PrintParams);
		
	EndIf;
	
EndFunction

#EndRegion

#EndRegion

#EndRegion

#EndIf