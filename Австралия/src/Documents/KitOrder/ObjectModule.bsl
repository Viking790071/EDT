#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

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
			And TypeOf(StringProducts.MeasurementUnit) = Type("CatalogRef.UOM") Then
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

// Procedure for filling the document basing on Sales order.
//
Procedure FillUsingSalesOrder(FillingData) Export
	
	If OperationKind = Enums.OperationTypesKitOrder.Disassembly Then
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
	|	SalesOrder.OrderState AS BasisState,
	|	SalesOrder.OperationKind AS BasisOperationKind,
	|	SalesOrder.Company AS Company,
	|	CASE
	|		WHEN SalesOrder.SalesStructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			THEN SalesOrder.SalesStructuralUnit
	|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
	|	END AS StructuralUnit,
	|	BEGINOFPERIOD(SalesOrder.ShipmentDate, DAY) AS Start,
	|	ENDOFPERIOD(SalesOrder.ShipmentDate, DAY) AS Finish
	|FROM
	|	Document.SalesOrder AS SalesOrder,
	|	Constant.UseInventoryReservation AS UseInventoryReservation
	|WHERE
	|	SalesOrder.Ref In (&BasisDocument)";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		VerifiedAttributesValues = New Structure(
			"OperationKind, OrderStatus, Closed, Posted",
			Selection.BasisOperationKind,
			Selection.BasisState,
			Selection.BasisClosed,
			Selection.BasisPosted);
		Documents.SalesOrder.CheckAbilityOfEnteringBySalesOrder(Selection.BasisRef, VerifiedAttributesValues);
		
	EndDo;
	
	FillPropertyValues(ThisObject, Selection);
	BasisOperationKind = Selection.BasisOperationKind;
		
	If Not ValueIsFilled(StructuralUnit) Then
		SettingValue = DriveReUse.GetValueOfSetting("MainDepartment");
		If Not ValueIsFilled(SettingValue) Then
			StructuralUnit = Catalogs.BusinessUnits.MainDepartment;
		EndIf;
	EndIf;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance,
	|	OrdersBalance.SalesOrder AS SalesOrder
	|FROM
	|	(SELECT
	|		OrdersBalance.Products AS Products,
	|		OrdersBalance.Characteristic AS Characteristic,
	|		OrdersBalance.QuantityBalance AS QuantityBalance,
	|		OrdersBalance.SalesOrder AS SalesOrder
	|	FROM
	|		AccumulationRegister.SalesOrders.Balance(, SalesOrder IN (&BasisDocument)) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		ReservedProductsBalances.Products,
	|		ReservedProductsBalances.Characteristic,
	|		-ReservedProductsBalances.QuantityBalance,
	|		ReservedProductsBalances.SalesOrder
	|	FROM
	|		AccumulationRegister.ReservedProducts.Balance(, SalesOrder IN (&BasisDocument)) AS ReservedProductsBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		PlacementBalances.Products,
	|		PlacementBalances.Characteristic,
	|		-PlacementBalances.QuantityBalance,
	|		PlacementBalances.SalesOrder
	|	FROM
	|		AccumulationRegister.Backorders.Balance(, SalesOrder IN (&BasisDocument)) AS PlacementBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsBackorders.Products,
	|		DocumentRegisterRecordsBackorders.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsBackorders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN -ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|		END,
	|		DocumentRegisterRecordsBackorders.SalesOrder
	|	FROM
	|		AccumulationRegister.Backorders AS DocumentRegisterRecordsBackorders
	|	WHERE
	|		DocumentRegisterRecordsBackorders.Recorder = &Ref
	|		AND DocumentRegisterRecordsBackorders.SalesOrder IN(&BasisDocument)) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic,
	|	OrdersBalance.SalesOrder
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
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
	|	SalesOrderInventory.Products.ProductsType AS ProductsType,
	|	SUM(SalesOrderInventory.Quantity) AS Quantity,
	|	SalesOrderInventory.Ref AS SalesOrder
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|WHERE
	|	SalesOrderInventory.Ref IN(&BasisDocument)
	|	AND (SalesOrderInventory.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)
	|			OR SalesOrderInventory.Products.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Assembly)
	|			OR &OperationKind = VALUE(Enum.OperationTypesProductionOrder.Disassembly))
	|
	|GROUP BY
	|	SalesOrderInventory.Products,
	|	SalesOrderInventory.Characteristic,
	|	SalesOrderInventory.MeasurementUnit,
	|	SalesOrderInventory.Products.ProductsType,
	|	CASE
	|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE SalesOrderInventory.MeasurementUnit.Factor
	|	END,
	|	SalesOrderInventory.Specification,
	|	SalesOrderInventory.Ref
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("OperationKind", OperationKind);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("SalesOrder, Products, Characteristic");
	
	Products.Clear();
	Inventory.Clear();
	If BalanceTable.Count() > 0 Then
		
		Selection = ResultsArray[1].Select();
		While Selection.Next() Do
			
			If TabularSectionName = "Inventory"
				And Selection.ProductsType <> Enums.ProductsTypes.InventoryItem Then
				Continue;
			EndIf;
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("Products",		Selection.Products);
			StructureForSearch.Insert("Characteristic",	Selection.Characteristic);
			StructureForSearch.Insert("SalesOrder",		Selection.SalesOrder);
			
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

	If Products.Count() > 0 Then
		FillTabularSectionBySpecification();
	EndIf;
	
EndProcedure

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
	
	If TypeOf(FillingData) = Type("Structure")
		And FillingData.Property("DemandPlanning") Then
		FillTabularSectionBySpecification();
	ElsIf TypeOf(FillingData) = Type("Structure")
		And FillingData.Property("SalesOrder") Then
		FillUsingSalesOrder(FillingData.SalesOrder);
	EndIf;
	
EndProcedure

// Procedure - BeforeWrite event handler.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Closed And OrderState = DriveReUse.GetOrderStatus("KitOrderStatuses", "Completed") Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = ' %1 is completed. Editing is not allowed.'; ru = ' %1 завершен. Редактирование запрещено.';pl = ' %1 jest zakończone. Edycja nie jest dozwolona.';es_ES = ' %1 ha sido finalizado. La edición no está permitida.';es_CO = ' %1 ha sido finalizado. La edición no está permitida.';tr = ' %1 tamamlandı. Düzenleme yapılamaz.';it = ' %1 completato. Impossibile effettuare modifiche.';de = ' %1 ist abgeschlossen. Bearbeitung ist nicht gestattet.'"), Ref);
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
		If FOUseCharacteristics And ValueIsFilled(StringProducts.Characteristic) Then
			CharacteristicPresentation = " (" + TrimAll(StringProducts.Characteristic) + ")";
		EndIf;
		
		If ValueIsFilled(ProductsList) Then
			ProductsList = ProductsList + Chars.LF;
		EndIf;
		ProductsList = ProductsList
			+ TrimAll(StringProducts.Products)
			+ CharacteristicPresentation
			+ ", "
			+ StringProducts.Quantity
			+ " "
			+ TrimAll(StringProducts.MeasurementUnit);
		
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
			
			MessageText = NStr("en = 'The Finished products tab includes only products with the Service type. Components for such products are not included in demand planning. Clear the Components tab.'; ru = 'Во вкладке Готовая продукция представлена только номенклатура с типом Услуга. Компоненты для такой номенклатуры не включаются в расчет потребностей. Очистите вкладку Компоненты.';pl = 'Karta ""Gotowe produkty"" zawiera tylko produkty z typem ""Usługa"". Komponenty dla takich produktów nie wchodzą do planowania zapotrzebowania. Wyczyść kartę Komponenty.';es_ES = 'La pestaña Productos terminados incluye sólo los productos con el tipo de Servicio. Los Componentes de estos productos no se incluyen en la planificación de la demanda. Vacíe la pestaña Componentes.';es_CO = 'La pestaña Productos terminados incluye sólo los productos con el tipo de Servicio. Los Componentes de estos productos no se incluyen en la planificación de la demanda. Vacíe la pestaña Componentes.';tr = 'Nihai ürünler sekmesi sadece Hizmet türünde ürünler içeriyor. Bu tür ürünler için talep planlamaya malzeme eklenmez. Malzemeler sekmesini temizleyin.';it = 'La scheda Articoli finiti include solamente gli articoli con tipo Servizio. Le componenti per tali articoli non sono incluse nella pianificazione della domanda. Cancellare la scheda Componenti.';de = 'Die Registerkarte ""Fertigprodukte"" enthält nur Produkte mit dem Dienstleistungstyp. Komponenten für diese Produkte sind nicht in die Bedarfsplanung eingeschlossen. Löschen Sie die Registerkarte ""Komponenten"".'");
			DriveServer.ShowMessageAboutError(ThisObject, MessageText,,,, Cancel);
			
		EndIf;
		
	EndIf;
	
	If Not Constants.UseKitOrderStatuses.Get() Then
		
		If Not ValueIsFilled(OrderState) Then
			MessageText = NStr("en = '""Lifecycle status"" is required.'; ru = 'Требуется указать статус документа.';pl = 'Wymagany jest ""Status dokumentu"".';es_ES = 'Se requiere ""Estado de ciclo de vida"".';es_CO = 'Se requiere ""Estado de ciclo de vida"".';tr = '""Yaşam döngüsü durumu"" gerekli.';it = '""Stato del ciclo di vita"" richiesto.';de = '""Status von Lebenszyklus"" ist erforderlich.'");
			DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "OrderState", Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - event handler FillingProcessor object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.KitOrder.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectInventoryFlowCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectKitOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectBackorders(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.KitOrder.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
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
	Documents.KitOrder.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

#EndRegion

#Region Private

// Procedure fills document when copying.
//
Procedure FillOnCopy()
	
	If Constants.UseKitOrderStatuses.Get() Then
		User = Users.CurrentUser();
		SettingValue = DriveReUse.GetValueByDefaultUser(User, "StatusOfNewProductionOrder");
		If ValueIsFilled(SettingValue) Then
			If OrderState <> SettingValue Then
				OrderState = SettingValue;
			EndIf;
		Else
			OrderState = Catalogs.KitOrderStatuses.Open;
		EndIf;
	Else
		OrderState = Constants.KitOrdersInProgressStatus.Get();
	EndIf;
	
	Closed = False;
	
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
