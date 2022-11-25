#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure StartUpdate(Parameters, ResultAddress) Export
	
	NeedForDeletion = False;
	UseOldProduction = Constants.UseKitProcessing.Get();
	
	If UseOldProduction Then
	
		BeginTransaction(DataLockControlMode.Managed);
		
		Try
			
			// Lock on all production orders and old production documents
			
			Blocking = New DataLock;
			LockItem = Blocking.Add("Document.Production");
			LockItem = Blocking.Add("Document.ProductionOrder");
			LockItem.Mode = DataLockMode.Exclusive;
			Blocking.Lock();
			
			// Move statuses
			If Constants.UseProductionOrderStatuses.Get() Then
				Constants.UseKitOrderStatuses.Set(True);
			EndIf;
			
			StatusesMap = New Map;
			
			Query = New Query;
			Query.Text =
			"SELECT
			|	ProductionOrderStatuses.Ref AS Ref,
			|	ProductionOrderStatuses.Description AS Description,
			|	ProductionOrderStatuses.DeletionMark AS DeletionMark,
			|	ProductionOrderStatuses.OrderStatus AS OrderStatus,
			|	ProductionOrderStatuses.Color AS Color,
			|	ProductionOrderStatuses.DescriptionLanguage1 AS DescriptionLanguage1,
			|	ProductionOrderStatuses.DescriptionLanguage2 AS DescriptionLanguage2,
			|	ProductionOrderStatuses.DescriptionLanguage3 AS DescriptionLanguage3,
			|	ProductionOrderStatuses.DescriptionLanguage4 AS DescriptionLanguage4,
			|	ProductionOrderStatuses.Presentation AS Presentation
			|FROM
			|	Catalog.ProductionOrderStatuses AS ProductionOrderStatuses";
			
			QueryResult = Query.Execute();
			
			SelectionDetailRecords = QueryResult.Select();
			
			While SelectionDetailRecords.Next() Do
				
				KitOrderStatusRef = Catalogs.KitOrderStatuses.FindByDescription(SelectionDetailRecords.Description);
				
				If KitOrderStatusRef.IsEmpty() Then
					
					KitOrderStatus = Catalogs.KitOrderStatuses.CreateItem();
					FillPropertyValues(KitOrderStatus, SelectionDetailRecords);
					InfobaseUpdate.WriteObject(KitOrderStatus);
					
					KitOrderStatusRef = KitOrderStatus.Ref;
					
				EndIf;
					
				StatusesMap.Insert(SelectionDetailRecords.Ref, KitOrderStatusRef);
				
			EndDo;
			
			// Move additional attributes
			
			Query = New Query;
			Query.Text = 
			"SELECT
			|	AdditionalAttributesAndInfo.Ref AS Ref
			|FROM
			|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
			|WHERE
			|	AdditionalAttributesAndInfo.PropertySet = &PropertySet";
			
			Query.SetParameter("PropertySet", Catalogs.AdditionalAttributesAndInfoSets.Document_ProductionOrder);
			
			QueryResult = Query.Execute();
			
			SelectionDetailRecords = QueryResult.Select();
			
			While SelectionDetailRecords.Next() Do
				
				ProdOrderCharacteristic = SelectionDetailRecords.Ref.GetObject();
				ProdOrderCharacteristic.PropertySet = Catalogs.AdditionalAttributesAndInfoSets.Document_KitOrder;
				InfobaseUpdate.WriteObject(ProdOrderCharacteristic);
				
			EndDo;
			
			// Move all production orders
			
			Query = New Query;
			Query.Text = 
			"SELECT
			|	ProductionOrder.Ref AS Ref
			|FROM
			|	Document.ProductionOrder AS ProductionOrder
			|WHERE
			|	ProductionOrder.Posted
			|
			|ORDER BY
			|	ProductionOrder.Number";
			
			QueryResult = Query.Execute();
			
			If Not QueryResult.IsEmpty() Then
				
				NeedForDeletion = True;
				SelectionDetailRecords = QueryResult.Select();
				
				While SelectionDetailRecords.Next() Do
					
					ProductionOrderRef = SelectionDetailRecords.Ref;
					KitOrder = CreateKitOrderBasedOnProductionOrder(ProductionOrderRef, StatusesMap);
					
					// Change ref in documents
					ChangeRefInDocuments(ProductionOrderRef, KitOrder);
					
					// Set deletion mark
					ProductionOrder = ProductionOrderRef.GetObject();
					ProductionOrder.SetDeletionMark(True);
					ProductionOrder.Comment = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = '%1. The document has been changed to %2.'; ru = '%1. Документ был изменен на %2.';pl = '%1. Dokument został zmieniony na %2.';es_ES = '%1. El documento ha sido cambiado a %2.';es_CO = '%1. El documento ha sido cambiado a %2.';tr = '%1. Belge %2 olarak değiştirildi.';it = '%1. Il documento è stato modificato in %2.';de = '%1. Das Dokument wurde für das Folgende geändert %2.'", CommonClientServer.DefaultLanguageCode()),
						ProductionOrder.Comment,
						KitOrder);
					For Each RegisterRecord In ProductionOrder.RegisterRecords Do
						RegisterRecord.Clear();
					EndDo;
					InfobaseUpdate.WriteObject(ProductionOrder);
					
				EndDo;
				
			EndIf;
			
			// Other production docs
			
			Query = New Query;
			Query.Text = 
			"SELECT
			|	Production.Ref AS Ref
			|FROM
			|	Document.Production AS Production
			|WHERE
			|	Production.BasisDocument = VALUE(Document.ProductionOrder.EmptyRef)";
			
			QueryResult = Query.Execute();
			
			SelectionDetailRecords = QueryResult.Select();
			
			While SelectionDetailRecords.Next() Do
				Production = SelectionDetailRecords.Ref.GetObject();
				Production.BasisDocument = Undefined;
				InfobaseUpdate.WriteObject(Production,, True);
			EndDo;
			
			CommitTransaction();
			
			PutToTempStorage(NeedForDeletion, ResultAddress);
			
		Except
			
			RollbackTransaction();
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot update infobase. Details: %1'; ru = 'Не удалось обновить информационную базу. Подробнее: %1';pl = 'Nie można zaktualizować bazy informacyjnej. Szczegóły: %1';es_ES = 'Ha ocurrido un error al actualizar la base de información. Detalles: %1';es_CO = 'Ha ocurrido un error al actualizar la base de información. Detalles: %1';tr = 'Infobase güncellenemiyor. Ayrıntılar: %1';it = 'Impossibile aggiornare l''infobase. Dettagli: %1';de = 'Die Infobase kann nicht aktualisiert werden. Details: %1'", CommonClientServer.DefaultLanguageCode()),
				DetailErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				,
				,
				ErrorDescription);
			
			Raise;
			
		EndTry;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Function CreateKitOrderBasedOnProductionOrder(ProductionOrderRef, StatusesMap)
	
	KitOrder = Documents.KitOrder.CreateDocument();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ProductionOrder.Date AS Date,
	|	CASE
	|		WHEN ProductionOrder.OperationKind = VALUE(Enum.OperationTypesProductionOrder.Assembly)
	|			THEN VALUE(Enum.OperationTypesKitOrder.Assembly)
	|		ELSE VALUE(Enum.OperationTypesKitOrder.Disassembly)
	|	END AS OperationKind,
	|	ProductionOrder.Company AS Company,
	|	ProductionOrder.SalesOrder AS SalesOrder,
	|	ProductionOrder.Start AS Start,
	|	ProductionOrder.Finish AS Finish,
	|	ProductionOrder.StructuralUnit AS StructuralUnit,
	|	ProductionOrder.Comment AS Comment,
	|	ProductionOrder.BasisDocument AS BasisDocument,
	|	ProductionOrder.OrderState AS OrderState,
	|	ProductionOrder.Closed AS Closed,
	|	ProductionOrder.Responsible AS Responsible,
	|	ProductionOrder.Author AS Author,
	|	ProductionOrder.ProductsList AS ProductsList,
	|	ProductionOrder.Products.(
	|		Ref AS Ref,
	|		LineNumber AS LineNumber,
	|		Products AS Products,
	|		ProductsType AS ProductsType,
	|		Characteristic AS Characteristic,
	|		Quantity AS Quantity,
	|		MeasurementUnit AS MeasurementUnit,
	|		Specification AS Specification
	|	) AS Products,
	|	ProductionOrder.Inventory.(
	|		Ref AS Ref,
	|		LineNumber AS LineNumber,
	|		Products AS Products,
	|		Characteristic AS Characteristic,
	|		Quantity AS Quantity,
	|		MeasurementUnit AS MeasurementUnit,
	|		Specification AS Specification
	|	) AS Inventory,
	|	ProductionOrder.AdditionalAttributes.(
	|		Ref AS Ref,
	|		LineNumber AS LineNumber,
	|		Property AS Property,
	|		Value AS Value,
	|		TextString AS TextString
	|	) AS AdditionalAttributes
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|WHERE
	|	ProductionOrder.Ref = &ProductionOrderRef";
	
	Query.SetParameter("ProductionOrderRef", ProductionOrderRef);
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		
		FillPropertyValues(KitOrder, SelectionDetailRecords);
		KitOrder.OrderState = StatusesMap.Get(SelectionDetailRecords.OrderState);
		
		KitOrder.Products.Load(SelectionDetailRecords.Products.Unload());
		KitOrder.Inventory.Load(SelectionDetailRecords.Inventory.Unload());
		
		AddAttribute = SelectionDetailRecords.AdditionalAttributes.Select();
		While AddAttribute.Next() Do
			
			KitOrderAddAttribute = KitOrder.AdditionalAttributes.Add();
			FillPropertyValues(KitOrderAddAttribute, AddAttribute);
			
		EndDo;
		
		If ProductionOrderRef.Posted Then
			
			KitOrder.Write(DocumentWriteMode.Posting);
			
		Else
			
			KitOrder.Write(DocumentWriteMode.Write);
			
		EndIf;
		
	EndIf;
	
	Return KitOrder.Ref;
	
EndFunction

Procedure ChangeRefInDocuments(ProductionOrder, KitOrder)
	
	// Production
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Production.Ref AS Ref,
	|	Production.Posted AS Posted
	|FROM
	|	Document.Production AS Production
	|WHERE
	|	Production.BasisDocument = &ProductionOrder";
	
	Query.SetParameter("ProductionOrder", ProductionOrder);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		Production = SelectionDetailRecords.Ref.GetObject();
		Production.BasisDocument = KitOrder;
		
		WriteMode = DocumentWriteMode.Write;
		If SelectionDetailRecords.Posted Then
			WriteMode = DocumentWriteMode.Posting;
		EndIf;
		
		InfobaseUpdate.WriteObject(Production,, True, WriteMode);
		
	EndDo;
	
	// InventoryTransfer
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	InventoryTransfer.Ref AS Ref
	|FROM
	|	Document.InventoryTransfer AS InventoryTransfer
	|WHERE
	|	InventoryTransfer.BasisDocument = &ProductionOrder";
	
	Query.SetParameter("ProductionOrder", ProductionOrder);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		InventoryTransfer = SelectionDetailRecords.Ref.GetObject();
		InventoryTransfer.BasisDocument = KitOrder;
		
		InfobaseUpdate.WriteObject(InventoryTransfer);
		
	EndDo;
	
	// TransferOrder
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	TransferOrder.Ref AS Ref
	|FROM
	|	Document.TransferOrder AS TransferOrder
	|WHERE
	|	TransferOrder.BasisDocument = &ProductionOrder";
	
	Query.SetParameter("ProductionOrder", ProductionOrder);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		TransferOrder = SelectionDetailRecords.Ref.GetObject();
		TransferOrder.BasisDocument = KitOrder;
		
		InfobaseUpdate.WriteObject(TransferOrder);
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf