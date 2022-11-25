#Region Public

Procedure CheckFilling(DocObject, Cancel) Export
	
	UseBatches = GetFunctionalOption("UseBatches");
	If Not UseBatches Then
		Return;
	EndIf;
	
	ParametersSet = DocumentParameters(DocObject);
	
	For Each Parameters In ParametersSet Do
		
		If Parameters.Warehouses.Count() = 0 Then
			Continue;
		EndIf;
		
		GetCheckDataTable(Parameters, DocObject);
		
		If Not Parameters.Property("UnconditionalFillCheck") Then
			PolicyNotSetErrors(Parameters, DocObject, Cancel);
		EndIf;
		
		If Parameters.CheckDataTable.Count() = 0 Then
			Continue;
		EndIf;
		
		FillingChecking(Parameters, DocObject, Cancel);
		
	EndDo;
	
EndProcedure

Function TrackingMethod(Product, StructuralUnit) Export
	
	Query = New Query;
	
	Query.SetParameter("Product", Product);
	Query.SetParameter("StructuralUnit", StructuralUnit);
	
	Query.Text =
	"SELECT
	|	CatalogProducts.ProductsCategory AS ProductsCategory,
	|	CatalogProducts.UseBatches AS UseBatches
	|INTO TT_Products
	|FROM
	|	Catalog.Products AS CatalogProducts
	|WHERE
	|	CatalogProducts.Ref = &Product
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) AS TrackingMethod
	|FROM
	|	TT_Products AS TT_Products
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON TT_Products.ProductsCategory = ProductsCategories.Ref
	|			AND (TT_Products.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|			AND (BatchTrackingPolicy.StructuralUnit = &StructuralUnit)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)";
	
	Sel = Query.Execute().Select();
	
	If Sel.Next() Then
		
		Return Sel.TrackingMethod;
		
	Else
		
		Return Enums.BatchTrackingMethods.EmptyRef();
		
	EndIf;
	
EndFunction

Function ReferentialTrackingMethod(Product, StructuralUnit) Export
	
	TrackingMethod = TrackingMethod(Product, StructuralUnit);
	
	Return (TrackingMethod = Enums.BatchTrackingMethods.Referential);
	
EndFunction

Function FEFOTrackingMethod(Product, StructuralUnit) Export
	
	TrackingMethod = TrackingMethod(Product, StructuralUnit);
	
	Return (TrackingMethod = Enums.BatchTrackingMethods.FEFO);
	
EndFunction

Procedure AddFillBatchesByFEFOCommands(Form, TableName = "") Export
	
	NewCommand = Form.Commands.Add("FillBatchesByFEFO" + TableName + "_All");
	NewCommand.Title = NStr("en = 'In all lines'; ru = 'Во всех строках';pl = 'We wsyzstkich wierszach';es_ES = 'En todas las líneas';es_CO = 'En todas las líneas';tr = 'Tüm satırlarda';it = 'In tutte le righe';de = 'In allen Zeilen'");
	NewCommand.Action = "Attachable_FillBatchesByFEFO" + TableName + "_All";
	NewCommand.ModifiesStoredData = True;
	
	NewItem = Form.Items.Add(NewCommand.Name, Type("FormButton"), Form.Items["FillBatchesByFEFO" + TableName]);
	NewItem.CommandName = NewCommand.Name;
	
	NewCommand = Form.Commands.Add("FillBatchesByFEFO" + TableName + "_Selected");
	NewCommand.Title = NStr("en = 'In highlighted lines'; ru = 'В выделенных строках';pl = 'W podświetlonych wierszach';es_ES = 'En las líneas destacadas';es_CO = 'En las líneas destacadas';tr = 'Vurgulanan satırlarda';it = 'Nelle righe evidenziate';de = 'In hervorgehobenen Zeilen'");
	NewCommand.Action = "Attachable_FillBatchesByFEFO" + TableName + "_Selected";
	NewCommand.ModifiesStoredData = True;
	
	NewItem = Form.Items.Add(NewCommand.Name, Type("FormButton"), Form.Items["FillBatchesByFEFO" + TableName]);
	NewItem.CommandName = NewCommand.Name;
	
EndProcedure

Function FillByFEFOApplicable(Parameters) Export
	
	If Parameters.CurrentRow = Undefined Then
		Return False;
	EndIf;
	
	Product = Parameters.CurrentRow.Products;
	
	If Not ValueIsFilled(Product) Then
		Return False;
	EndIf;
	
	IsFEFOTrackingMethod = FEFOTrackingMethod(Product, Parameters.StructuralUnit);
	
	If Not IsFEFOTrackingMethod And Parameters.ShowMessages Then
		
		If Not Parameters.Property("TableName") Then
			Parameters.Insert("TableName", "Inventory");
		EndIf;
		
		MessageText = NStr("en = 'The FEFO tracking method is not set up for this product.'; ru = 'Метод FEFO не настроен для данной номенклатуры.';pl = 'Metoda śledzenia FEFO nie jest skonfigurowana dla tego produktu.';es_ES = 'El método de gestión FEFO no está configurado para este producto.';es_CO = 'El método de gestión FEFO no está configurado para este producto.';tr = 'Bu ürün için FEFO takip yöntemi ayarlanmadı.';it = 'Il metodo di tracciamento FEFO non è impostato per questo prodotto.';de = 'Die FEFO-Tracking-Methode ist für dieses Produkt nicht eingerichtet.'");
		CommonClientServer.MessageToUser(MessageText,
			,
			CommonClientServer.PathToTabularSection(Parameters.TableName,
				Parameters.CurrentRow.LineNumber, "Products"),
			"Object");
		
	EndIf;
	
	Return IsFEFOTrackingMethod;
	
EndFunction

Function FillByFEFOData(Parameters) Export
	
	If Not Parameters.Property("TableName") Then
		Parameters.Insert("TableName", "Inventory");
	EndIf;
	If Not Parameters.Property("Cell") Then
		Parameters.Insert("Cell", Catalogs.Cells.EmptyRef());
	EndIf;
	
	If Not Parameters.Property("OwnershipType") Then
		Ref = Parameters.Object.Ref;
		DocManager = Common.ObjectManagerByRef(Ref);
		OwnershipParametersSet = DocManager.InventoryOwnershipParameters(Parameters.Object);
		If TypeOf(OwnershipParametersSet) = Type("Array") Then
			For Each OwnershipParameters In OwnershipParametersSet Do
				If Not OwnershipParameters.Property("TableName")
					Or OwnershipParameters.TableName = Parameters.TableName Then
					Break;
				EndIf;
			EndDo;
		Else
			OwnershipParameters = OwnershipParametersSet;
		EndIf;
		If OwnershipParameters.Property("OwnershipType") Then
			Parameters.Insert("OwnershipType", OwnershipParameters.OwnershipType);
		Else
			Parameters.Insert("OwnershipType", Undefined);
		EndIf;
	EndIf;
	
	Query = New Query;
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", Parameters.Company);
	Query.SetParameter("StructuralUnit", Parameters.StructuralUnit);
	Query.SetParameter("Cell", Parameters.Cell);
	Query.SetParameter("OwnershipType", Parameters.OwnershipType);
	CurrentRow = Parameters.CurrentRow;
	Query.SetParameter("LineNumber", CurrentRow.LineNumber);
	Query.SetParameter("Products", CurrentRow.Products);
	Query.SetParameter("Characteristic", CurrentRow.Characteristic);
	
	If Parameters.Property("SalesOrder") Then
		If TypeOf(Parameters.SalesOrder) = Type("String") Then
			SalesOrder = CurrentRow[Parameters.SalesOrder];
		Else
			SalesOrder = Parameters.SalesOrder;
		Endif;
		If Not ValueIsFilled(Parameters.SalesOrder) Then
			SalesOrder = Undefined;
		EndIf;
	Else
		SalesOrder = Undefined;
	EndIf;
	Query.SetParameter("SalesOrder", SalesOrder);
	
	Columns = "LineNumber, Products, Characteristic, Batch, Quantity, MeasurementUnit";
	If Parameters.Property("SalesOrder") And TypeOf(Parameters.SalesOrder) = Type("String") Then
		Columns = Columns + ", Reserve, " + Parameters.SalesOrder;
		Table = Parameters.Object[Parameters.TableName].Unload( , Columns);
		Table.Columns[Parameters.SalesOrder].Name = "SalesOrder";
	Else
		Table = Parameters.Object[Parameters.TableName].Unload( , Columns);
		Table.Columns.Add("Reserve", New TypeDescription("Number"));
		Table.Columns.Add("SalesOrder", New TypeDescription("DocumentRef.SalesOrder"));
	EndIf;
	Query.SetParameter("Table", Table);
	
	Query.Text =
	"SELECT
	|	Table.LineNumber AS LineNumber,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.Batch AS Batch,
	|	Table.Quantity AS Quantity,
	|	Table.MeasurementUnit AS MeasurementUnit,
	|	Table.Reserve AS Reserve,
	|	Table.SalesOrder AS SalesOrder
	|INTO TT_Table
	|FROM
	|	&Table AS Table
	|WHERE
	|	Table.Products = &Products
	|	AND Table.Characteristic = &Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Table.LineNumber AS LineNumber,
	|	TT_Table.Products AS Products,
	|	TT_Table.Characteristic AS Characteristic,
	|	TT_Table.Batch AS Batch,
	|	TT_Table.Quantity AS Quantity,
	|	TT_Table.Reserve AS Reserve,
	|	TT_Table.SalesOrder AS SalesOrder,
	|	ISNULL(UOM.Factor, 1) AS Factor
	|INTO TT_TableWithFactor
	|FROM
	|	TT_Table AS TT_Table
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON TT_Table.MeasurementUnit = UOM.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_TableWithFactor.Factor AS Factor
	|INTO TT_CurRowFactor
	|FROM
	|	TT_TableWithFactor AS TT_TableWithFactor
	|WHERE
	|	TT_TableWithFactor.LineNumber = &LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_TableWithFactor.Batch AS Batch,
	|	TT_TableWithFactor.Quantity * TT_TableWithFactor.Factor AS Quantity
	|INTO TT_AlreadySelected
	|FROM
	|	TT_TableWithFactor AS TT_TableWithFactor
	|WHERE
	|	TT_TableWithFactor.LineNumber <> &LineNumber
	|	AND TT_TableWithFactor.Batch <> VALUE(Catalog.ProductsBatches.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_TableWithFactor.Batch AS Batch,
	|	TT_TableWithFactor.Reserve * TT_TableWithFactor.Factor AS Quantity
	|INTO TT_SelectedReserves
	|FROM
	|	TT_TableWithFactor AS TT_TableWithFactor
	|WHERE
	|	TT_TableWithFactor.LineNumber <> &LineNumber
	|	AND TT_TableWithFactor.Batch <> VALUE(Catalog.ProductsBatches.EmptyRef)
	|	AND TT_TableWithFactor.Reserve > 0
	|	AND TT_TableWithFactor.SalesOrder <> &SalesOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ReservedProductsBalance.Batch AS Batch,
	|	ReservedProductsBalance.QuantityBalance AS Quantity
	|INTO TT_ReservesUngrouped
	|FROM
	|	AccumulationRegister.ReservedProducts.Balance(
	|			,
	|			Company = &Company
	|				AND StructuralUnit = &StructuralUnit
	|				AND Products = &Products
	|				AND Characteristic = &Characteristic
	|				AND SalesOrder <> &SalesOrder) AS ReservedProductsBalance
	|
	|UNION ALL
	|
	|SELECT
	|	ReservedProducts.Batch,
	|	CASE
	|		WHEN ReservedProducts.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN ReservedProducts.Quantity
	|		ELSE -ReservedProducts.Quantity
	|	END
	|FROM
	|	AccumulationRegister.ReservedProducts AS ReservedProducts
	|WHERE
	|	ReservedProducts.Recorder = &Ref
	|	AND ReservedProducts.Company = &Company
	|	AND ReservedProducts.StructuralUnit = &StructuralUnit
	|	AND ReservedProducts.Products = &Products
	|	AND ReservedProducts.Characteristic = &Characteristic
	|	AND ReservedProducts.SalesOrder <> &SalesOrder
	|
	|UNION ALL
	|
	|SELECT
	|	TT_SelectedReserves.Batch,
	|	-TT_SelectedReserves.Quantity
	|FROM
	|	TT_SelectedReserves AS TT_SelectedReserves
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ReservesUngrouped.Batch AS Batch,
	|	SUM(TT_ReservesUngrouped.Quantity) AS Quantity
	|INTO TT_Reserves
	|FROM
	|	TT_ReservesUngrouped AS TT_ReservesUngrouped
	|
	|GROUP BY
	|	TT_ReservesUngrouped.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryOwnership.Ref AS Ref
	|INTO TT_Ownership
	|FROM
	|	Catalog.InventoryOwnership AS InventoryOwnership
	|WHERE
	|	InventoryOwnership.OwnershipType = &OwnershipType
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryInWarehousesBalance.Batch AS Batch,
	|	InventoryInWarehousesBalance.QuantityBalance AS Quantity
	|INTO TT_BalancesUngrouped
	|FROM
	|	AccumulationRegister.InventoryInWarehouses.Balance(
	|			,
	|			Company = &Company
	|				AND StructuralUnit = &StructuralUnit
	|				AND Cell = &Cell
	|				AND Products = &Products
	|				AND Characteristic = &Characteristic
	|				AND (&OwnershipType = UNDEFINED
	|					OR Ownership IN
	|						(SELECT
	|							TT_Ownership.Ref
	|						FROM
	|							TT_Ownership AS TT_Ownership))) AS InventoryInWarehousesBalance
	|
	|UNION ALL
	|
	|SELECT
	|	InventoryInWarehouses.Batch,
	|	CASE
	|		WHEN InventoryInWarehouses.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN InventoryInWarehouses.Quantity
	|		ELSE -InventoryInWarehouses.Quantity
	|	END
	|FROM
	|	AccumulationRegister.InventoryInWarehouses AS InventoryInWarehouses
	|WHERE
	|	InventoryInWarehouses.Recorder = &Ref
	|	AND InventoryInWarehouses.Company = &Company
	|	AND InventoryInWarehouses.StructuralUnit = &StructuralUnit
	|	AND InventoryInWarehouses.Cell = &Cell
	|	AND InventoryInWarehouses.Products = &Products
	|	AND InventoryInWarehouses.Characteristic = &Characteristic
	|	AND (&OwnershipType = UNDEFINED
	|			OR InventoryInWarehouses.Ownership IN
	|				(SELECT
	|					TT_Ownership.Ref
	|				FROM
	|					TT_Ownership AS TT_Ownership))
	|
	|UNION ALL
	|
	|SELECT
	|	TT_AlreadySelected.Batch,
	|	-TT_AlreadySelected.Quantity
	|FROM
	|	TT_AlreadySelected AS TT_AlreadySelected
	|
	|UNION ALL
	|
	|SELECT
	|	TT_Reserves.Batch,
	|	-TT_Reserves.Quantity
	|FROM
	|	TT_Reserves AS TT_Reserves
	|WHERE
	|	TT_Reserves.Quantity > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_BalancesUngrouped.Batch AS Batch,
	|	SUM(TT_BalancesUngrouped.Quantity) AS Quantity
	|INTO TT_Balances
	|FROM
	|	TT_BalancesUngrouped AS TT_BalancesUngrouped
	|
	|GROUP BY
	|	TT_BalancesUngrouped.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Balances.Batch AS Batch,
	|	TT_Balances.Quantity / TT_CurRowFactor.Factor AS Quantity
	|FROM
	|	TT_Balances AS TT_Balances
	|		LEFT JOIN Catalog.ProductsBatches AS ProductsBatches
	|		ON TT_Balances.Batch = ProductsBatches.Ref,
	|	TT_CurRowFactor AS TT_CurRowFactor
	|WHERE
	|	TT_Balances.Quantity > 0
	|
	|ORDER BY
	|	ProductsBatches.ExpirationDate";
	
	Result = New Array;
	
	Sel = Query.Execute().Select();
	While Sel.Next() Do
		
		BalanceData = New Structure("Batch, Quantity");
		FillPropertyValues(BalanceData, Sel);
		Result.Add(BalanceData);
		
	EndDo;
	
	BalanceData = New Structure("Batch, Quantity", "", 999999999999);
	Result.Add(BalanceData);
	
	Return Result;
	
EndFunction

Procedure CheckExpiredBatches(Parameters, Cancel) Export
	
	If Not Parameters.Property("TableName") Then
		Parameters.Insert("TableName", "Inventory");
	EndIf;
	
	Query = New Query;
	
	Query.SetParameter("BatchesTable", Parameters.BatchesTable);
	
	Query.Text =
	"SELECT
	|	BatchesTable.LineNumber AS LineNumber,
	|	BatchesTable.Products AS Products,
	|	BatchesTable.Batch AS Batch,
	|	BatchesTable.DeliveryDate AS DeliveryDate
	|INTO TT_Batches
	|FROM
	|	&BatchesTable AS BatchesTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Batches.LineNumber AS LineNumber,
	|	TT_Batches.Batch AS Batch,
	|	TT_Batches.DeliveryDate AS DeliveryDate,
	|	CASE
	|		WHEN CatalogBatchSettings.ExpirationDatePrecision = VALUE(Enum.DatePrecision.Hour)
	|				OR CatalogBatchSettings.ExpirationDatePrecision = VALUE(Enum.DatePrecision.EmptyRef)
	|			THEN VALUE(Enum.DatePrecision.Day)
	|		ELSE CatalogBatchSettings.ExpirationDatePrecision
	|	END AS Precision,
	|	ProductsBatches.ExpirationDate AS ExpirationDate
	|FROM
	|	TT_Batches AS TT_Batches
	|		INNER JOIN Catalog.ProductsBatches AS ProductsBatches
	|		ON TT_Batches.Batch = ProductsBatches.Ref
	|			AND (ProductsBatches.ExpirationDate > DATETIME(1, 1, 1))
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON TT_Batches.Products = CatalogProducts.Ref
	|		INNER JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (ProductsCategories.UseBatches)
	|		INNER JOIN Catalog.BatchSettings AS CatalogBatchSettings
	|		ON (ProductsCategories.BatchSettings = CatalogBatchSettings.Ref)
	|			AND (CatalogBatchSettings.UseExpirationDate)";
	
	Sel = Query.Execute().Select();
	
	ExpiredFound = False;
	
	DocObject = Parameters.DocObject;
	DocMetadata = DocObject.Metadata();
	
	While Sel.Next() Do
		
		AdjustedDeliveryDate = DriveClientServer.AdjustDateByPrecision(Sel.DeliveryDate, Sel.Precision);
		
		If AdjustedDeliveryDate > Sel.ExpirationDate Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'On the ""%2"" tab, line %1 includes an expired batch.'; ru = 'В строке %1 вкладки ""%2"" содержится просроченная партия.';pl = 'Na karcie ""%2"", wiersz %1 zawiera przeterminowaną partię.';es_ES = 'En la pestaña ""%2"", la línea %1 contiene un lote caducado.';es_CO = 'En la pestaña ""%2"", la línea %1 contiene un lote caducado.';tr = '""%2"" sekmesinin %1 satırı süresi geçmiş bir parti içeriyor.';it = 'Nella scheda ""%2"", la riga %1 include un lotto scaduto.';de = 'Auf der Registerkarte „%2“ enthält Zeile %1 eine abgelaufene Charge.'"),
				Sel.LineNumber,
				DocMetadata.TabularSections[Parameters.TableName].Presentation());
			CommonClientServer.MessageToUser(MessageText,
				DocObject,
				CommonClientServer.PathToTabularSection(Parameters.TableName,
					Sel.LineNumber, "Batch"),
				, Cancel);
			
			ExpiredFound = True;
			
		EndIf;
		
	EndDo;
	
	If ExpiredFound 
		And DriveAccessManagementReUse.ExpiredBatchesInSalesDocumentsIsAllowed() Then
		
		MessageText = NStr("en = 'The document includes expired batches.
			|To be able to post the document, on the ""Additional information"" tab, select the ""Allow expired batches"" check box.'; 
			|ru = 'Документ содержит просроченные партии.
			|Чтобы провести документ, выберите ""Разрешить просроченные партии"" на вкладке ""Дополнительная информация"".';
			|pl = 'Dokument zawiera przeterminowane partie.
			|Aby mieć możliwość zatwierdzenia dokumentu, na karcie ""Informacje dodatkowe”, zaznacz pole wyboru Zezwalaj na przeterminowane partie.';
			|es_ES = 'El documento contiene los lotes caducados.
			|Para poder contabilizar el documento, en la pestaña ""Información adicional"", marque la casilla de verificación ""Permitir lotes caducados"".';
			|es_CO = 'El documento contiene los lotes caducados.
			|Para poder contabilizar el documento, en la pestaña ""Información adicional"", marque la casilla de verificación ""Permitir lotes caducados"".';
			|tr = 'Belge, süresi geçmiş partiler içeriyor.
			|Belgeyi kaydedebilmek için ""Ek bilgi"" sekmesinde ""Süresi geçmiş partilere izin ver"" onay kutusunu seçin.';
			|it = 'Il documento include lotti scaduti.
			| Per poter pubblicare il documento, selezionare la casella di controllo ""Consentire lotti scaduti"" nella scheda ""Informazioni aggiuntive"".';
			|de = 'Das Dokument enthält abgelaufene Chargen.
			|Um das Dokument buchen zu können, aktivieren Sie auf der Registerkarte „Zusätzliche Informationen“ das Kontrollkästchen „Abgelaufene Chargen zulassen“.'");
		CommonClientServer.MessageToUser(MessageText,
			DocObject,
			"AllowExpiredBatches",
			,
			Cancel);
		
	EndIf;
	
EndProcedure

Function GetEmptyBatch(Product, EmptyBatchMap) Export
	
	EmptyBatch = EmptyBatchMap[Product];
	
	If EmptyBatch = Undefined Then
		
		EmptyBatchDescription = NStr("en = 'Not defined'; ru = 'Не определена';pl = 'Nieokreślona';es_ES = 'No definido';es_CO = 'No definido';tr = 'Belirlenmedi';it = 'Non definito';de = 'Nicht definiert'");
		
		EmptyBatch = Catalogs.ProductsBatches.FindByDescription(EmptyBatchDescription, True, , Product);
		
		If Not ValueIsFilled(EmptyBatch) Then
			
			NewItem = Catalogs.ProductsBatches.CreateItem();
			NewItem.Owner = Product;
			NewItem.Description = EmptyBatchDescription;
			
			Try
				
				InfobaseUpdate.WriteObject(NewItem);
				
				EmptyBatch = NewItem.Ref;
				
			Except
				
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot save catalog ""%1"". Details: %2'; ru = 'Не удалось записать справочник ""%1"". Подробнее: %2';pl = 'Nie można zapisać katalogu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';tr = '""%1"" kataloğu saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il catalogo ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Katalogs ""%1"". Details: %2'"),
					NewItem,
					BriefErrorDescription(ErrorInfo()));
				
				WriteLogEvent(
					InfobaseUpdate.EventLogEvent(),
					EventLogLevel.Error,
					Metadata.Catalogs.ProductsBatches,
					,
					ErrorDescription);
				
			EndTry;
			
		EndIf;
		
		EmptyBatchMap.Insert(Product, EmptyBatch);
		
	EndIf;
	
	Return EmptyBatch;
	
EndFunction

#EndRegion

#Region Private

Function DocumentParameters(DocObject)
	
	DocManager = Common.ObjectManagerByRef(DocObject.Ref);
	
	IncomingParameters = DocManager.BatchCheckFillingParameters(DocObject);
	
	If TypeOf(IncomingParameters) = Type("Array") Then
		ParametersSet = IncomingParameters;
	Else
		ParametersSet = New Array;
		ParametersSet.Add(IncomingParameters);
	EndIf;
	
	DocMetadata = DocObject.Metadata();
	
	For Each Parameters In ParametersSet Do 
		
		Parameters.Insert("DocMetadata", DocMetadata);
		
		If Not Parameters.Property("TableName") Then
			Parameters.Insert("TableName", "Inventory");
		EndIf;
		
		If Not Parameters.Property("Warehouses") Then
			Parameters.Insert("Warehouses", New Array);
		EndIf;
		
	EndDo;
	
	Return ParametersSet;
	
EndFunction

Procedure GetCheckDataTable(Parameters, DocObject)
	
	DataTable = New ValueTable;
	DataTable.Columns.Add("LineNumber", New TypeDescription("Number"));
	DataTable.Columns.Add("Products", New TypeDescription("CatalogRef.Products"));
	DataTable.Columns.Add("Warehouse", New TypeDescription("CatalogRef.BusinessUnits"));
	DataTable.Columns.Add("TrackingArea", New TypeDescription("String"));
	
	For Each WarehouseData In Parameters.Warehouses Do
		
		If IsBlankString(Parameters.TableName) Then
			DocTableData = New Array;
			DocTableData.Add(DocObject);
		Else
			DocTableData = DocObject[Parameters.TableName];
		EndIf;
		
		For Each DocTableRow In DocTableData Do
			DataTableRow = DataTable.Add();
			FillPropertyValues(DataTableRow, DocTableRow);
			If TypeOf(WarehouseData.Warehouse) = Type("String") Then
				DataTableRow.Warehouse = DocTableRow[WarehouseData.Warehouse];
			Else
				DataTableRow.Warehouse = WarehouseData.Warehouse;
			EndIf;
			DataTableRow.TrackingArea = WarehouseData.TrackingArea;
		EndDo;
		
	EndDo;
	
	Query = New Query;
	Query.SetParameter("DataTable", DataTable);
	Query.Text =
	"SELECT
	|	DataTable.LineNumber AS LineNumber,
	|	DataTable.Products AS Products,
	|	DataTable.Warehouse AS Warehouse,
	|	DataTable.TrackingArea AS TrackingArea
	|INTO TT_DataTable
	|FROM
	|	&DataTable AS DataTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_DataTable.LineNumber AS LineNumber,
	|	TT_DataTable.Products AS Products,
	|	TT_DataTable.Warehouse AS Warehouse,
	|	TT_DataTable.TrackingArea AS TrackingArea,
	|	ProductsCategories.BatchSettings AS BatchSettings,
	|	BatchTrackingPolicy.Policy AS Policy,
	|	ISNULL(BatchTrackingPolicies.UseTrackingArea_Inbound_FromSupplier, FALSE) AS Inbound_FromSupplier,
	|	ISNULL(BatchTrackingPolicies.UseTrackingArea_Inbound_SalesReturn, FALSE) AS Inbound_SalesReturn,
	|	ISNULL(BatchTrackingPolicies.UseTrackingArea_Inbound_Transfer, FALSE) AS Inbound_Transfer,
	|	ISNULL(BatchTrackingPolicies.UseTrackingArea_Outbound_SalesToCustomer, FALSE) AS Outbound_SalesToCustomer,
	|	ISNULL(BatchTrackingPolicies.UseTrackingArea_Outbound_PurchaseReturn, FALSE) AS Outbound_PurchaseReturn,
	|	ISNULL(BatchTrackingPolicies.UseTrackingArea_Outbound_Transfer, FALSE) AS Outbound_Transfer,
	|	ISNULL(BatchTrackingPolicies.UseTrackingArea_PhysicalInventory, FALSE) AS PhysicalInventory,
	|	ISNULL(BatchTrackingPolicies.UseTrackingArea_InventoryIncrease, FALSE) AS InventoryIncrease,
	|	ISNULL(BatchTrackingPolicies.UseTrackingArea_InventoryWriteOff, FALSE) AS InventoryWriteOff
	|INTO TT_CheckDataTable
	|FROM
	|	TT_DataTable AS TT_DataTable
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON TT_DataTable.Products = CatalogProducts.Ref
	|			AND (CatalogProducts.UseBatches)
	|		INNER JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON TT_DataTable.Warehouse = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_CheckDataTable.LineNumber AS LineNumber,
	|	TT_CheckDataTable.Products AS Products,
	|	TT_CheckDataTable.Warehouse AS Warehouse,
	|	TT_CheckDataTable.TrackingArea AS TrackingArea,
	|	TT_CheckDataTable.Inbound_FromSupplier AS Inbound_FromSupplier,
	|	TT_CheckDataTable.Inbound_SalesReturn AS Inbound_SalesReturn,
	|	TT_CheckDataTable.Inbound_Transfer AS Inbound_Transfer,
	|	TT_CheckDataTable.Outbound_SalesToCustomer AS Outbound_SalesToCustomer,
	|	TT_CheckDataTable.Outbound_PurchaseReturn AS Outbound_PurchaseReturn,
	|	TT_CheckDataTable.Outbound_Transfer AS Outbound_Transfer,
	|	TT_CheckDataTable.PhysicalInventory AS PhysicalInventory,
	|	TT_CheckDataTable.InventoryIncrease AS InventoryIncrease,
	|	TT_CheckDataTable.InventoryWriteOff AS InventoryWriteOff
	|FROM
	|	TT_CheckDataTable AS TT_CheckDataTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TT_CheckDataTable.Warehouse AS Warehouse,
	|	TT_CheckDataTable.BatchSettings AS BatchSettings
	|FROM
	|	TT_CheckDataTable AS TT_CheckDataTable
	|WHERE
	|	TT_CheckDataTable.Policy IS NULL";
	
	Results = Query.ExecuteBatch();
	
	Parameters.Insert("CheckDataTable", Results[2].Unload());
	Parameters.Insert("PolicyNotSetTable", Results[3].Unload());
	
EndProcedure

Procedure PolicyNotSetErrors(Parameters, DocObject, Cancel)
	
	For Each PolicyNotSetError In Parameters.PolicyNotSetTable Do
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'For ""%1"", the batch tracking policy is required in ""%2"" batch settings.
				|Go to Company->Enterprise\All catalogs > Batch settings and define the policy.'; 
				|ru = 'Для ""%1"" в ""%2"" настройках партии требуется указать систему учета по партиям.
				|Перейдите в меню Организация->Предприятие\Все справочники > Настройки партий и задайте политику.';
				|pl = 'Dla ""%1"", wymagana jest polityka śledzenia w ustawieniach partii ""%2"".
				|Przejdź do Firma->Przedsiębiorstwo\Wszystkie katalogi > Ustawienia partia i zdefiniuj politykę.';
				|es_ES = 'Para ""%1"", la política de rastreo de lotes es necesaria en la configuración de lotes ""%2"". 
				|Ir a Empresa->Empresa\Todos los catálogos> Configurar los lotes y definir la política.';
				|es_CO = 'Para ""%1"", la política de rastreo de lotes es necesaria en la configuración de lotes ""%2"". 
				|Ir a Empresa->Empresa\Todos los catálogos> Configurar los lotes y definir la política.';
				|tr = '""%1"" için, ""%2"" parti ayarlarında parti takip politikası gerekli.
				|İş yeri >Kurum\Tüm kataloglar > Parti ayarları bölümünde takip politikasını belirleyin.';
				|it = 'La policy di tracciamento di ""%1"" è richiesta nelle impostazioni di lotto ""%2"".
				| Andare in Compagnia->Impresa\Tutti i cataloghi> Impostazioni di lotto e definire la policy.';
				|de = 'Für ""%1„ist die Charge-Tracking-Richtlinie in den Chargeneinstellungen""%2""erforderlich.
				|Gehen Sie zu Firma->Gesellschaft\ Alle Kataloge > Chargeneinstellungen und definieren Sie die Richtlinie.'"),
			PolicyNotSetError.Warehouse,
			PolicyNotSetError.BatchSettings);
		CommonClientServer.MessageToUser(MessageText, DocObject, , , Cancel);
		
	EndDo;
	
EndProcedure

Procedure FillingChecking(Parameters, DocObject, Cancel)
	
	If IsBlankString(Parameters.TableName) Then
		DocTableData = New Array;
		DocTableData.Add(New Structure("LineNumber, Batch", 0, DocObject.Batch));
	Else
		DocTableData = DocObject[Parameters.TableName];
	EndIf;
	
	// begin Drive.FullVersion
	IsWIP = (TypeOf(DocObject) = Type("DocumentObject.ManufacturingOperation"));
	Filter = New Structure("ConnectionKey");
	// end Drive.FullVersion
	
	For Each DocTableRow In DocTableData Do
		
		// begin Drive.FullVersion
		If IsWIP And Parameters.TableName = "Inventory" Then
			
			Filter.ConnectionKey = DocTableRow.ActivityConnectionKey;
			OperationsLines = DocObject.Activities.FindRows(Filter);
			If OperationsLines.Count() And (OperationsLines[0].StartDate = Date(1, 1, 1)) Then
				Continue;
			EndIf;
			
		EndIf;
		// end Drive.FullVersion
		
		Tracking = DocTableRowTracking(DocTableRow, Parameters);
		
		If Tracking = True And Not ValueIsFilled(DocTableRow.Batch)
			And Not Parameters.Property("CheckNotFilledOnly") Then
			
			If DocTableRow.LineNumber = 0 Then
				
				MessageText = NStr("en = 'The ""Batch"" field is required.'; ru = 'Заполните поле ""Партия"".';pl = 'Pole ""Partia"" jest wymagane.';es_ES = 'El campo ""Lote"" es obligatorio.';es_CO = 'El campo ""Lote"" es obligatorio.';tr = '""Parti"" alanı gerekli.';it = 'Il campo ""Lotto"" è richiesto.';de = 'Das ""Charge""-Feld ist erforderlich.'");
				CommonClientServer.MessageToUser(MessageText,
					DocObject,
					"Batch",
					,
					Cancel);
				
			Else
				
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'On the ""%2"" tab, in line %1, the ""Batch"" field is required.'; ru = 'Заполните поле ""Партия"" в строке %1 вкладки ""%2"".';pl = 'Na karcie ""%2"", w wierszu %1, wymagane jest pole ""Partia"".';es_ES = 'En la pestaña ""%2"", en la línea %1, el campo ""Lote"" es obligatorio.';es_CO = 'En la pestaña ""%2"", en la línea %1, el campo ""Lote"" es obligatorio.';tr = '""%2"" sekmesinin %1 satırında ""Parti"" alanı gerekli.';it = 'Nella scheda ""%2"", riga %1, è richiesto il campo ""Lotto"".';de = 'Auf der Registerkarte „%2“ in der Zeile %1 ist das ""Charge""-Feld erforderlich.'"),
					DocTableRow.LineNumber,
					Parameters.DocMetadata.TabularSections[Parameters.TableName].Presentation());
				If DocObject.AdditionalProperties.Property("MessagesDataPath") Then
					CommonClientServer.MessageToUser(MessageText,
						,
						CommonClientServer.PathToTabularSection(Parameters.TableName,
							DocTableRow.LineNumber, "Batch"),
						DocObject.AdditionalProperties.MessagesDataPath,
						Cancel);
				Else
					CommonClientServer.MessageToUser(MessageText,
						DocObject,
						CommonClientServer.PathToTabularSection(Parameters.TableName,
							DocTableRow.LineNumber, "Batch"),
						,
						Cancel);
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function DocTableRowTracking(DocTableRow, Parameters)
	
	Result = Undefined;
	
	CheckDataRows = Parameters.CheckDataTable.FindRows(New Structure("LineNumber", DocTableRow.LineNumber));
	
	For Each CheckDataRow In CheckDataRows Do
		
		Tracking = CheckDataRow[CheckDataRow.TrackingArea];
		If Tracking Or Parameters.Property("UnconditionalFillCheck") Then
			Result = True;
			Break;
		// ElsIf <if conditions requiring batch to be empty, e.g. Automatic FEFO method, are added> - Result = False
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion