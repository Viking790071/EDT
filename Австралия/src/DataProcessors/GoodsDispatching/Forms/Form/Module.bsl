#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	UseCharacteristics = GetFunctionalOption("UseCharacteristics");
	
	BeginOfPeriod = CurrentSessionDate();
	
	If Parameters.Property("EndOfPeriod") Then
		EndOfPeriod = Parameters.EndOfPeriod;
	Else
		EndOfPeriod = CurrentSessionDate() + 7 * 86400;
	EndIf;
	
	ShowDetails = 0;
	
	If Parameters.Property("Company") Then
		Company = Parameters.Company;
	EndIf;
	
	If Not ValueIsFilled(Company) Then
		Company = DriveReUse.GetUserDefaultCompany();
	EndIf;
	
	If Not ValueIsFilled(Company) Then
		Company = DriveServer.GetPredefinedCompany();
	EndIf;
	
	Warehouse = DriveReUse.GetValueByDefaultUser(UsersClientServer.AuthorizedUser(), "MainWarehouse");
	If Not ValueIsFilled(Warehouse) Then
		Warehouse = Catalogs.BusinessUnits.MainWarehouse;
	EndIf;
	
	LoadUserSettings();
	
	FillOrderedProductsAtServer();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ShowHideDetails();
	
	SetGeneratedDocumentPageTitle();
	
	If UseCharacteristics Then
		Items.InventoryCounterparty.Title = StringFunctionsClientServer.SubstituteParametersToString("%1 / %2",
			NStr("en = 'Customer'; ru = 'Покупатель';pl = 'Nabywca';es_ES = 'Cliente';es_CO = 'Cliente';tr = 'Müşteri';it = 'Cliente';de = 'Kunde'"),
			NStr("en = 'Variant'; ru = 'Вариант';pl = 'Wariant';es_ES = 'Variante';es_CO = 'Variante';tr = 'Varyant';it = 'Variante';de = 'Variante'"));
	Else
		Items.InventoryCounterparty.Title = NStr("en = 'Customer'; ru = 'Покупатель';pl = 'Nabywca';es_ES = 'Cliente';es_CO = 'Cliente';tr = 'Müşteri';it = 'Cliente';de = 'Kunde'");
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Not Exit Then
		SaveSettings();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CompanyOnChange(Item)
	
	FillOrderedProducts();
	
EndProcedure

&AtClient
Procedure WarehouseOnChange(Item)
	
	FillOrderedProducts();
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	FillOrderedProducts();
	
EndProcedure

&AtClient
Procedure ProductOnChange(Item)
	
	FillOrderedProducts();
	
EndProcedure

&AtClient
Procedure BeginOfPeriodOnChange(Item)
	
	FillOrderedProducts();
	
EndProcedure

&AtClient
Procedure EndOfPeriodOnChange(Item)
	
	FillOrderedProducts();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersInventory

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentData = Item.CurrentData;
	
	If CurrentData <> Undefined Then
		
		If Field.Name = "InventoryProducts" Then
			
			StandardProcessing = False;
			
			If TypeOf(CurrentData.Products) = Type("DocumentRef.SalesOrder") Then
				OpenForm("Document.SalesOrder.ObjectForm", New Structure("Key", CurrentData.Products));
			ElsIf TypeOf(CurrentData.Products) = Type("CatalogRef.Products") Then
				OpenForm("Catalog.Products.ObjectForm", New Structure("Key", CurrentData.Products));
			EndIf;
			
		ElsIf Field.Name = "InventoryCounterparty" Then
			
			StandardProcessing = False;
			
			If TypeOf(CurrentData.Products) = Type("DocumentRef.SalesOrder") And ValueIsFilled(CurrentData.Counterparty) Then
				OpenForm("Catalog.Counterparties.ObjectForm", New Structure("Key", CurrentData.Counterparty));
			ElsIf TypeOf(CurrentData.Products) = Type("CatalogRef.Products") And ValueIsFilled(CurrentData.Counterparty) Then
				OpenForm("Catalog.ProductsCharacteristics.ObjectForm", New Structure("Key", CurrentData.Counterparty));
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryDispatchOnChange(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	
	If CurrentData <> Undefined Then
		CheckUncheckInventory(CurrentData.GetItems(), CurrentData.Dispatch)
	EndIf;
	
	RecalculateAvailableQuantity();
	
EndProcedure

&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	
	If CurrentData <> Undefined Then
		If CurrentData.Quantity > 0 Then
			CurrentData.Dispatch = True;
		EndIf;
		RecalculateAvailableQuantity();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersDocuments

&AtClient
Procedure DocumentsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Item.CurrentData;
	
	If CurrentData <> Undefined Then
		
		NotifyDescription = New NotifyDescription("DoAfterCloseDocumentForm",
			ThisObject,
			New Structure("SelectedRow", SelectedRow));
		
		If TypeOf(CurrentData.Document) = Type("DocumentRef.GoodsIssue") Then
			OpenForm("Document.GoodsIssue.ObjectForm", New Structure("Key", CurrentData.Document), , , , , NotifyDescription);
		ElsIf TypeOf(CurrentData.Document) = Type("DocumentRef.SalesInvoice") Then
			OpenForm("Document.SalesInvoice.ObjectForm", New Structure("Key", CurrentData.Document), , , , , NotifyDescription);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DoAfterCloseDocumentForm(Value, Parameters) Export
	
	If Parameters.Property("SelectedRow") Then
		DocumentRow = GeneratedDocuments.FindByID(Parameters.SelectedRow);
		DocumentRow.StatusPicture = GetStatusPictureNumber(DocumentRow.Document);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure RefreshProducts(Command)
	
	FillOrderedProducts();
	
EndProcedure

&AtClient
Procedure Generate(Command)
	
	GenerateDocuments();
	
EndProcedure

&AtClient
Procedure MarkToDelete(Command)
	
	DocumentsMap = New Map;
	
	For Each DocItem In Items.GeneratedDocuments.SelectedRows Do
		
		RowData = Items.GeneratedDocuments.RowData(DocItem);
		DocumentsMap.Insert(DocItem, RowData.Document);
		
	EndDo;
	
	ProcessedDocuments = MarkToDeleteDocumentAtServer(DocumentsMap);
	
	For Each DocKeyAndValue In ProcessedDocuments Do
		
		DocumentRow = GeneratedDocuments.FindByID(DocKeyAndValue.Key);
		DocumentRow.StatusPicture = DocKeyAndValue.Value;
		
		NotifyChanged(DocumentRow.Document);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure PostDocument(Command)
	
	DocumentsMap = New Map;
	
	For Each DocItem In Items.GeneratedDocuments.SelectedRows Do
		
		RowData = Items.GeneratedDocuments.RowData(DocItem);
		DocumentsMap.Insert(DocItem, RowData.Document);
		
	EndDo;
	
	ProcessedDocuments = PostDocumentAtServer(DocumentsMap);
	
	For Each DocKeyAndValue In ProcessedDocuments Do
		
		DocumentRow = GeneratedDocuments.FindByID(DocKeyAndValue.Key);
		DocumentRow.StatusPicture = DocKeyAndValue.Value;
		
		NotifyChanged(DocumentRow.Document);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure UndoPosting(Command)
	
	DocumentsMap = New Map;
	
	For Each DocItem In Items.GeneratedDocuments.SelectedRows Do
		
		RowData = Items.GeneratedDocuments.RowData(DocItem);
		DocumentsMap.Insert(DocItem, RowData.Document);
		
	EndDo;
	
	ProcessedDocuments = UndoPostingDocumentAtServer(DocumentsMap);
	
	For Each DocKeyAndValue In ProcessedDocuments Do
		
		DocumentRow = GeneratedDocuments.FindByID(DocKeyAndValue.Key);
		DocumentRow.StatusPicture = DocKeyAndValue.Value;
		
		NotifyChanged(DocumentRow.Document);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure RefreshDocuments(Command)
	
	UpdateDocumentsStatus();
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	CheckUncheckInventory(Inventory.GetItems(), False);
	RecalculateAvailableQuantity();
	
EndProcedure

&AtClient
Procedure CheckAll(Command)
	
	CheckUncheckInventory(Inventory.GetItems(), True);
	RecalculateAvailableQuantity();
	
EndProcedure

&AtClient
Procedure ExpandAll(Command)
	
	ShowDetails = 0;
	
	ShowHideDetails();
	
EndProcedure

&AtClient
Procedure CollapseAll(Command)
	
	ShowDetails = 1;
	
	ShowHideDetails();
	
EndProcedure

&AtClient
Procedure OpenDocumentsSettings(Command)
	
	FormParameters = New Structure("CreateGoodsIssue, PostDocuments", CreateGoodsIssue, PostDocuments);
	NotifyDescription = New NotifyDescription("OpenDocumentsSettingsEnd", ThisObject);
	OpenForm("DataProcessor.GoodsDispatching.Form.FormUserSettings", FormParameters, ThisObject, , , , NotifyDescription);
	
EndProcedure

&AtClient
Procedure SetPeriod(Command)
	
	Dialog = New StandardPeriodEditDialog();
	Dialog.Period.StartDate = BeginOfPeriod;
	Dialog.Period.EndDate = EndOfPeriod;
	
	Dialog.Show(New NotifyDescription("SetPeriodCompleted", ThisObject));
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure CheckUncheckInventory(InventoryItems, DispatchValue)
	
	For Each Item In InventoryItems Do
		
		Item.Dispatch = DispatchValue;
		
		CheckUncheckInventory(Item.GetItems(), DispatchValue);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillOrderedProductsAtServer()
	
	Inventory.GetItems().Clear();
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.Company AS Company,
	|	SalesOrder.Counterparty AS Counterparty,
	|	SalesOrder.StructuralUnitReserve AS StructuralUnit,
	|	SalesOrder.ShipmentDate AS ShipmentDate
	|INTO TT_SalesOrders
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.ShipmentDate BETWEEN &DateFrom AND &DateTo
	|	AND SalesOrder.Company = &Company
	|	AND (SalesOrder.Counterparty = &Counterparty
	|			OR &Counterparty = VALUE(Catalog.Counterparties.EmptyRef))
	|	AND (SalesOrder.StructuralUnitReserve = &Warehouse
	|			OR &Warehouse = VALUE(Catalog.BusinessUnits.EmptyRef))
	|	AND SalesOrder.OperationKind = VALUE(Enum.OperationTypesSalesOrder.OrderForSale)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SalesOrders.Ref AS Ref,
	|	TT_SalesOrders.Company AS Company,
	|	TT_SalesOrders.StructuralUnit AS StructuralUnit,
	|	TT_SalesOrders.Counterparty AS Counterparty,
	|	TT_SalesOrders.ShipmentDate AS ShipmentDate,
	|	SalesOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SalesOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic
	|INTO TT_Inventory
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|		INNER JOIN TT_SalesOrders AS TT_SalesOrders
	|		ON SalesOrderInventory.Ref = TT_SalesOrders.Ref
	|WHERE
	|	(SalesOrderInventory.Products = &Products
	|			OR &Products = VALUE(Catalog.Products.EmptyRef))
	|	AND SalesOrderInventory.Quantity > 0
	|
	|GROUP BY
	|	TT_SalesOrders.Ref,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SalesOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	TT_SalesOrders.Company,
	|	TT_SalesOrders.StructuralUnit,
	|	TT_SalesOrders.Counterparty,
	|	SalesOrderInventory.Products,
	|	TT_SalesOrders.ShipmentDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrdersBalance.Company AS Company,
	|	SalesOrdersBalance.SalesOrder AS SalesOrder,
	|	SalesOrdersBalance.Products AS Products,
	|	SalesOrdersBalance.Characteristic AS Characteristic,
	|	SalesOrdersBalance.QuantityBalance AS QuantityBalance
	|INTO UnshippedOrders
	|FROM
	|	AccumulationRegister.SalesOrders.Balance(
	|			,
	|			SalesOrder IN
	|				(SELECT
	|					TT_SalesOrders.Ref
	|				FROM
	|					TT_SalesOrders)) AS SalesOrdersBalance
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryInWarehousesBalance.Company AS Company,
	|	InventoryInWarehousesBalance.StructuralUnit AS StructuralUnit,
	|	InventoryInWarehousesBalance.Products AS Products,
	|	InventoryInWarehousesBalance.Characteristic AS Characteristic,
	|	SUM(InventoryInWarehousesBalance.QuantityBalance) AS Quantity
	|FROM
	|	AccumulationRegister.InventoryInWarehouses.Balance(
	|			,
	|			(Company, StructuralUnit, Products, Characteristic) IN
	|				(SELECT
	|					TT_Inventory.Company,
	|					TT_Inventory.StructuralUnit,
	|					TT_Inventory.Products,
	|					TT_Inventory.Characteristic
	|				FROM
	|					TT_Inventory)) AS InventoryInWarehousesBalance
	|
	|GROUP BY
	|	InventoryInWarehousesBalance.Characteristic,
	|	InventoryInWarehousesBalance.Products,
	|	InventoryInWarehousesBalance.Company,
	|	InventoryInWarehousesBalance.StructuralUnit
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.Ref AS Ref,
	|	TT_Inventory.Company AS Company,
	|	TT_Inventory.StructuralUnit AS StructuralUnit,
	|	TT_Inventory.Counterparty AS Counterparty,
	|	TT_Inventory.ShipmentDate AS ShipmentDate,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	ISNULL(UnshippedOrders.QuantityBalance, 0) AS UnshippedQuantity
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		LEFT JOIN UnshippedOrders AS UnshippedOrders
	|		ON TT_Inventory.Ref = UnshippedOrders.SalesOrder
	|			AND TT_Inventory.Company = UnshippedOrders.Company
	|			AND TT_Inventory.Products = UnshippedOrders.Products
	|			AND TT_Inventory.Characteristic = UnshippedOrders.Characteristic
	|WHERE
	|	ISNULL(UnshippedOrders.QuantityBalance, 0) > 0
	|
	|ORDER BY
	|	ShipmentDate,
	|	Ref
	|TOTALS BY
	|	ShipmentDate,
	|	Ref,
	|	Counterparty";
	
	Query.SetParameter("DateFrom", BegOfDay(BeginOfPeriod));
	Query.SetParameter("DateTo", EndOfDay(EndOfPeriod));
	Query.SetParameter("Company", Company);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Warehouse", Warehouse);
	Query.SetParameter("Products", Products);
	Query.SetParameter("UseCharacteristics", UseCharacteristics);
	
	QueryResult = Query.ExecuteBatch();
	
	AvailQtyTable = QueryResult[3].Unload();
	
	ValueToFormAttribute(AvailQtyTable, "InventoryInWarehouses");
	
	SelectionShipmentDate = QueryResult[4].Select(QueryResultIteration.ByGroups);
	While SelectionShipmentDate.Next() Do
		
		NewRow = Inventory.GetItems().Add();
		NewRow.Products = SelectionShipmentDate.ShipmentDate;
		
		SelectionRef = SelectionShipmentDate.Select(QueryResultIteration.ByGroups);
		While SelectionRef.Next() Do
			
			SelectionCounterparty = SelectionRef.Select(QueryResultIteration.ByGroups);
			While SelectionCounterparty.Next() Do
				
				NewOrderRow = NewRow.GetItems().Add();
				NewOrderRow.Products = SelectionRef.Ref;
				NewOrderRow.Counterparty = SelectionCounterparty.Counterparty;
				
				SelectionDetailRecords = SelectionCounterparty.Select();
				While SelectionDetailRecords.Next() Do
					
					NewRowDetails = NewOrderRow.GetItems().Add();
					FillPropertyValues(NewRowDetails, SelectionDetailRecords, , "Counterparty");
					NewRowDetails.Counterparty = SelectionDetailRecords.Characteristic;
					
					SeachStructure = New Structure("Company, StructuralUnit, Products, Characteristic");
					FillPropertyValues(SeachStructure, SelectionDetailRecords);
					
					AvailQtyArray = AvailQtyTable.FindRows(SeachStructure);
					
					If AvailQtyArray.Count() > 0 Then
						
						NewRowDetails.AvailableQuantity = AvailQtyArray[0].Quantity;
						NewRowDetails.Quantity = Min(NewRowDetails.AvailableQuantity, NewRowDetails.UnshippedQuantity);
						NewRowDetails.Dispatch = (NewRowDetails.Quantity > 0);
						
						AvailQtyArray[0].Quantity = AvailQtyArray[0].Quantity - NewRowDetails.Quantity;
						
					Else
						
						NewRowDetails.AvailableQuantity = 0;
						NewRowDetails.Quantity = 0;
						NewRowDetails.Dispatch = False;
						
					EndIf;
					
				EndDo;
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure RecalculateAvailableQuantity()
	
	AvailQtyTable = FormAttributeToValue("InventoryInWarehouses");
	
	For Each DateItem In Inventory.GetItems() Do
		
		For Each OrderItem In DateItem.GetItems() Do
			
			For Each ProductsItem In OrderItem.GetItems() Do
				
				SeachStructure = New Structure("Company, StructuralUnit, Products, Characteristic");
				FillPropertyValues(SeachStructure, ProductsItem);
				SeachStructure.Characteristic = ProductsItem.Counterparty;
				
				AvailQtyArray = AvailQtyTable.FindRows(SeachStructure);
				
				If AvailQtyArray.Count() > 0 Then
					
					ProductsItem.AvailableQuantity = AvailQtyArray[0].Quantity;
					
					If ProductsItem.Dispatch And ProductsItem.Quantity > 0 Then
						If AvailQtyArray[0].Quantity > ProductsItem.Quantity Then
							AvailQtyArray[0].Quantity = AvailQtyArray[0].Quantity - ProductsItem.Quantity;
						Else
							AvailQtyArray[0].Quantity = 0;
						EndIf;
					ElsIf Not ProductsItem.Dispatch Then
						AvailQtyArray[0].Quantity = 0;
					EndIf;
					
				Else
					ProductsItem.AvailableQuantity = 0;
				EndIf;
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ShowHideDetails()
	
	For Each Item In Inventory.GetItems() Do
		
		ItemID = Item.GetID();
		
		If ShowDetails = 0 Then
			Items.Inventory.Expand(ItemID, True);
		ElsIf ShowDetails = 1 Then
			Items.Inventory.Collapse(ItemID);
		Else
			Items.Inventory.Collapse(ItemID);
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure FillOrderedProducts()
	
	If ValueIsFilled(EndOfPeriod) Then
		FillOrderedProductsAtServer();
	Else
		Inventory.GetItems().Clear();
		DriveClient.ShowMessageAboutError(ThisObject,
			NStr("en = 'The end of the period is not specified'; ru = 'Конец периода не указан';pl = 'Koniec okresu nie jest określony';es_ES = 'El final del período no está especificado';es_CO = 'El final del período no está especificado';tr = 'Dönem sonu belirtilmedi';it = 'La fine del periodo non è specificata';de = 'Das Ende des Zeitraums ist nicht angegeben'"),
			,
			,
			"EndOfPeriod");
	EndIf;
	
	ShowHideDetails();
	
EndProcedure

&AtServer
Procedure UpdateDocumentsStatus()
	
	RowsToDelete = New Array;
	
	For Each DocumentRow In GeneratedDocuments Do
		If Common.RefExists(DocumentRow.Document) Then
			DocumentRow.StatusPicture = GetStatusPictureNumber(DocumentRow.Document);
		Else
			RowsToDelete.Add(DocumentRow);
		EndIf;
	EndDo;
	
	For Each Row In RowsToDelete Do
		GeneratedDocuments.Delete(Row);
	EndDo;
	
EndProcedure

&AtServerNoContext
Function PostDocumentAtServer(DocumentsForProcessing)
	
	ProcessedDocuments = New Map;
	
	For Each DocKeyAndValue In DocumentsForProcessing Do
		
		DocObject = DocKeyAndValue.Value.GetObject();
		
		If Not DocObject.DeletionMark Then
			
			If DocObject.CheckFilling() Then
				
				Try
					
					DocObject.Write(DocumentWriteMode.Posting);
					ProcessedDocuments.Insert(DocKeyAndValue.Key, 1);
					
				Except
					
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Cannot post the %1 document.'; ru = 'Не удалось провести документ: %1.';pl = 'Nie można zaksięgować %1 dokumentu.';es_ES = 'No se puede enviar el %1 documento.';es_CO = 'No se puede enviar el %1 documento.';tr = '%1 belgesi kaydedilemiyor.';it = 'Non è possibile pubblicare il documento %1.';de = 'Fehler beim Buchen des Dokuments %1.'"),
						String(DocObject.Ref));
					
					CommonClientServer.MessageToUser(MessageText);
					
				EndTry;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return ProcessedDocuments;
	
EndFunction

&AtServerNoContext
Function UndoPostingDocumentAtServer(DocumentsForProcessing)
	
	ProcessedDocuments = New Map;
	
	For Each DocKeyAndValue In DocumentsForProcessing Do
		
		DocObject = DocKeyAndValue.Value.GetObject();
		
		If Not DocObject.DeletionMark And DocObject.Posted Then
			
			Try
				
				DocObject.Write(DocumentWriteMode.UndoPosting);
				ProcessedDocuments.Insert(DocKeyAndValue.Key, 0);
				
			Except
				
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot undo posting the %1 document.'; ru = 'Не удалось отменить проводку документа %1.';pl = 'Nie można cofnąć zaksięgowania %1 dokumentu.';es_ES = 'No se puede anular el envío del %1documento.';es_CO = 'No se puede anular el envío del %1documento.';tr = '%1 belgesinin kaydedilmesi geri alınamıyor.';it = 'Impossibile annullare la pubblicazione del documento %1.';de = 'Kann die Buchung des %1 Dokumentes nicht rückgängig machen.'"),
					String(DocObject.Ref));
				
				CommonClientServer.MessageToUser(MessageText);
				
			EndTry;
			
		EndIf;
		
	EndDo;
	
	Return ProcessedDocuments;
	
EndFunction

&AtServerNoContext
Function MarkToDeleteDocumentAtServer(DocumentsForProcessing)
	
	ProcessedDocuments = New Map;
	
	For Each DocKeyAndValue In DocumentsForProcessing Do
		
		DocObject = DocKeyAndValue.Value.GetObject();
		
		Try
			
			DocObject.SetDeletionMark(NOT DocObject.DeletionMark);
			
			If DocObject.DeletionMark Then
				ProcessedDocuments.Insert(DocKeyAndValue.Key, 3);
			Else
				ProcessedDocuments.Insert(DocKeyAndValue.Key, 0);
			EndIf;
			
		Except
			
			If DocObject.DeletionMark Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot unmark for deletion the %1 document.'; ru = 'Не удалось снять пометку на удаление документа %1.';pl = 'Nie można usunąć zaznaczenia do usunięcia dokumentu %1.';es_ES = 'No se puede desmarcar para borrar el %1documento.';es_CO = 'No se puede desmarcar para borrar el %1documento.';tr = '%1 belgesinin silme işareti kaldırılamıyor.';it = 'Impossibile deselezionare il documento %1 per la cancellazione.';de = 'Kann Markierung des Dokumentes %1 zum Löschen nicht deaktivieren.'"),
					String(DocObject.Ref));
			Else
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot mark for deletion the %1 document.'; ru = 'Не удалось пометить документ %1 на удаление.';pl = 'Nie można zaznaczyć do usunięcia %1 dokumentu.';es_ES = 'No se puede marcar para borrar el %1documento.';es_CO = 'No se puede marcar para borrar el %1documento.';tr = '%1 belgesi silme için işaretlenemiyor.';it = 'Impossibile contrassegnare il documento %1 per la cancellazione.';de = 'Kann das Dokument %1 zum Löschen nicht markieren.'"),
					String(DocObject.Ref));
			EndIf;
			
			CommonClientServer.MessageToUser(MessageText);
			
		EndTry;
		
	EndDo;
	
	Return ProcessedDocuments;
	
EndFunction

&AtServerNoContext
Function GetStatusPictureNumber(DocumentRef)
	
	PictureNumber = 0;
	
	ObjectAttributes = Common.ObjectAttributesValues(DocumentRef, "Posted, DeletionMark");
	
	If ObjectAttributes.Posted Then
		PictureNumber = 1;
	ElsIf ObjectAttributes.DeletionMark Then
		PictureNumber = 3;
	EndIf;
	
	Return PictureNumber;
	
EndFunction

&AtServer
Procedure SaveSettings()
	
	Common.CommonSettingsStorageSave("DataProcessor.GoodsDispatching", "CreateGoodsIssue", CreateGoodsIssue);
	Common.CommonSettingsStorageSave("DataProcessor.GoodsDispatching", "PostDocuments", PostDocuments);
	
EndProcedure

&AtServer
Procedure LoadUserSettings()
	
	CreateGoodsIssue = Common.CommonSettingsStorageLoad("DataProcessor.GoodsDispatching", "CreateGoodsIssue", False);
	PostDocuments = Common.CommonSettingsStorageLoad("DataProcessor.GoodsDispatching", "PostDocuments", False);
	
EndProcedure

&AtClient
Procedure OpenDocumentsSettingsEnd(CloseResult, AdditionalParameters) Export
	
	If TypeOf(CloseResult) = Type("Structure") Then
		FillPropertyValues(ThisObject, CloseResult, "CreateGoodsIssue, PostDocuments");
	EndIf;
	
EndProcedure

&AtClient
Procedure SetGeneratedDocumentPageTitle()
	
	TitleCount = ?(GeneratedDocuments.Count() = 0,
		"",
		StringFunctionsClientServer.SubstituteParametersToString(" (%1)", GeneratedDocuments.Count()));
	
	Items.GeneratedDocumentsGroup.Title = NStr("en = 'Generated documents'; ru = 'Сформированные документы';pl = 'Wygenerowane dokumenty';es_ES = 'Documentos generados';es_CO = 'Documentos generados';tr = 'Oluşturulan belgeler';it = 'Documenti generati';de = 'Generierte Dokumente'") + TitleCount;
	
EndProcedure

&AtClient
Procedure SetPeriodCompleted(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		BeginOfPeriod = Result.StartDate;
		EndOfPeriod = Result.EndDate;
		
		FillOrderedProducts();
	EndIf;
	
EndProcedure

#Region BackgroundJobs

&AtClient
Procedure GenerateDocuments()
	
	ClearMessages();
	
	ExecutionResult = GenerateDocumentsAtServer();
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.MessageText = NStr("en = 'Documents generation.'; ru = 'Формирование документов.';pl = 'Generowanie dokumentu.';es_ES = 'Generar documentos.';es_CO = 'Generar documentos.';tr = 'Belge oluşturma.';it = 'Generazione documenti.';de = 'Generierung von Dokumenten.'");
	IdleParameters.OutputMessages = True;
	
	CompletionNotification = New NotifyDescription("OnCompleteGenerateDocuments", ThisObject);
	TimeConsumingOperationsClient.WaitForCompletion(ExecutionResult, CompletionNotification, IdleParameters);
	
EndProcedure

&AtClient
Procedure OnCompleteGenerateDocuments(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Completed" Then
		
		OperationResult = GetFromTempStorage(Result.ResultAddress);
		
		For Each DocItem In OperationResult.DocumentsArray Do
			
			NewRow = GeneratedDocuments.Add();
			NewRow.Document = DocItem;
			NewRow.StatusPicture = GetStatusPictureNumber(DocItem);
			
		EndDo;
		
		SetGeneratedDocumentPageTitle();
		
		If PostDocuments Then
			FillOrderedProducts();
		EndIf;
		
	ElsIf Result.Status = "Error" Then
		Raise Result.BriefErrorPresentation;
	EndIf;
	
EndProcedure

&AtServer
Function GenerateDocumentsAtServer()
	
	ProductsTable = New ValueTable;
	ProductsTable.Columns.Add("SalesOrder",		New TypeDescription("DocumentRef.SalesOrder"));
	ProductsTable.Columns.Add("Products",		New TypeDescription("CatalogRef.Products"));
	ProductsTable.Columns.Add("Characteristic",	New TypeDescription("CatalogRef.ProductsCharacteristics"));
	ProductsTable.Columns.Add("Quantity",		New TypeDescription("Number", New NumberQualifiers(15, 3)));
	
	OrdersArray = New Array;
	
	For Each DateItem In Inventory.GetItems() Do
		
		For Each OrderItem In DateItem.GetItems() Do
			
			For Each ProductsItem In OrderItem.GetItems() Do
				
				If ProductsItem.Dispatch And ProductsItem.Quantity > 0 Then
					
					NewRow = ProductsTable.Add();
					NewRow.SalesOrder = OrderItem.Products;
					NewRow.Products = ProductsItem.Products;
					NewRow.Characteristic = ProductsItem.Counterparty;
					NewRow.Quantity = ProductsItem.Quantity;
					
					If OrdersArray.Find(NewRow.SalesOrder) = Undefined Then
						OrdersArray.Add(NewRow.SalesOrder);
					EndIf;
					
				EndIf;
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
	ProcedureName = "DataProcessors.GoodsDispatching.GenerateDocuments";
	
	OperationParameters = New Structure;
	OperationParameters.Insert("ProductsTable", ProductsTable);
	OperationParameters.Insert("OrdersArray", OrdersArray);
	OperationParameters.Insert("CreateGoodsIssue", CreateGoodsIssue);
	OperationParameters.Insert("PostDocuments", PostDocuments);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Documents generation by ""Goods dispatching""'; ru = 'Формирование документов по ""Отгрузке товаров""';pl = 'Generowanie dokumentu przez ""Wysyłkę towarów""';es_ES = 'Generar documentos por ""Envío de mercancías""';es_CO = 'Generar documentos por ""Envío de mercancías""';tr = '''''Sevkiyat planlama'''' ile belge oluşturma';it = 'Generazione documenti per ""Distribuzione merci""';de = 'Generierung von Dokumenten von ""Warenversand""'");
	
	Return TimeConsumingOperations.ExecuteInBackground(ProcedureName, OperationParameters, ExecutionParameters);
	
EndFunction

#EndRegion

#EndRegion