#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InfobaseUpdate

Procedure FillCurrencyInIntraTransferRecords() Export
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	Inventory.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS Inventory
	|		INNER JOIN Document.GoodsIssue AS GoodsIssue
	|		ON Inventory.Recorder = GoodsIssue.Ref
	|			AND (GoodsIssue.OperationType = VALUE(Enum.OperationTypesGoodsIssue.IntraCommunityTransfer))
	|			AND (Inventory.Currency = VALUE(Catalog.Currencies.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	Inventory.Recorder
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS Inventory
	|		INNER JOIN Document.GoodsReceipt AS GoodsReceipt
	|		ON Inventory.Recorder = GoodsReceipt.Ref
	|			AND (GoodsReceipt.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer))
	|			AND (Inventory.Currency = VALUE(Catalog.Currencies.EmptyRef))";
	
	Selection = Query.Execute().Select();
	
	Query.Text =
	"SELECT
	|	InventoryCostLayer.Period AS Period,
	|	InventoryCostLayer.Recorder AS Recorder,
	|	InventoryCostLayer.LineNumber AS LineNumber,
	|	InventoryCostLayer.Active AS Active,
	|	InventoryCostLayer.RecordType AS RecordType,
	|	InventoryCostLayer.Company AS Company,
	|	InventoryCostLayer.PresentationCurrency AS PresentationCurrency,
	|	InventoryCostLayer.Products AS Products,
	|	InventoryCostLayer.Characteristic AS Characteristic,
	|	InventoryCostLayer.Batch AS Batch,
	|	InventoryCostLayer.Ownership AS Ownership,
	|	InventoryCostLayer.StructuralUnit AS StructuralUnit,
	|	InventoryCostLayer.CostObject AS CostObject,
	|	InventoryCostLayer.CostLayer AS CostLayer,
	|	InventoryCostLayer.InventoryAccountType AS InventoryAccountType,
	|	InventoryCostLayer.Quantity AS Quantity,
	|	InventoryCostLayer.Amount AS Amount,
	|	InventoryCostLayer.SourceRecord AS SourceRecord,
	|	InventoryCostLayer.VATRate AS VATRate,
	|	InventoryCostLayer.Responsible AS Responsible,
	|	InventoryCostLayer.Department AS Department,
	|	InventoryCostLayer.SourceDocument AS SourceDocument,
	|	InventoryCostLayer.CorrSalesOrder AS CorrSalesOrder,
	|	InventoryCostLayer.CorrStructuralUnit AS CorrStructuralUnit,
	|	InventoryCostLayer.CorrGLAccount AS CorrGLAccount,
	|	InventoryCostLayer.RIMTransfer AS RIMTransfer,
	|	InventoryCostLayer.SalesRep AS SalesRep,
	|	InventoryCostLayer.Counterparty AS Counterparty,
	|	CASE
	|		WHEN InventoryCostLayer.Currency = VALUE(Catalog.Currencies.EmptyRef)
	|			THEN InventoryCostLayer.PresentationCurrency
	|		ELSE InventoryCostLayer.Currency
	|	END AS Currency,
	|	InventoryCostLayer.SalesOrder AS SalesOrder,
	|	InventoryCostLayer.CorrCostObject AS CorrCostObject,
	|	InventoryCostLayer.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	InventoryCostLayer.CorrProducts AS CorrProducts,
	|	InventoryCostLayer.GLAccount AS GLAccount,
	|	InventoryCostLayer.CorrCharacteristic AS CorrCharacteristic,
	|	InventoryCostLayer.CorrBatch AS CorrBatch,
	|	InventoryCostLayer.CorrOwnership AS CorrOwnership,
	|	InventoryCostLayer.CorrSpecification AS CorrSpecification,
	|	InventoryCostLayer.Specification AS Specification,
	|	InventoryCostLayer.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	InventoryCostLayer.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS InventoryCostLayer
	|WHERE
	|	InventoryCostLayer.Recorder = &Recorder";
	
	While Selection.Next() Do
		
		Query.SetParameter("Recorder", Selection.Recorder);
		
		RecordSet = AccumulationRegisters.InventoryCostLayer.CreateRecordSet();
		RecordSet.Filter.Recorder.Set(Selection.Recorder);
		RecordSet.Load(Query.Execute().Unload());
		
		Try
			
			InfobaseUpdate.WriteRecordSet(RecordSet);
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Error while saving record set %1: %2.'; ru = 'Ошибка при записи набора записей %1: %2.';pl = 'Błąd podczas zapisywania zestawu wpisów %1: %2.';es_ES = 'Error al guardar el conjunto de registros %1: %2';es_CO = 'Error al guardar el conjunto de registros %1: %2';tr = '%1 kayıt kümesi kaydedilirken hata oluştu: %2.';it = 'Si è verificato un errore durante il salvataggio dell''insieme di registrazioni %1: %2.';de = 'Fehler beim Speichern von Satz von Einträgen %1: %2.'", DefaultLanguageCode),
				Selection.Recorder,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.AccumulationRegisters.AccountsPayable,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

Procedure FillEmptyAttributesInRecords() Export
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	GoodsReceipt.Ref AS Ref
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS InventoryCostLayer
	|		INNER JOIN Document.GoodsReceipt AS GoodsReceipt
	|		ON InventoryCostLayer.Recorder = GoodsReceipt.Ref
	|			AND (InventoryCostLayer.Counterparty = VALUE(Catalog.Counterparties.EmptyRef))";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		DocumentObject = Selection.Ref.GetObject();
		If DocumentObject = Undefined Then
			Continue;
		EndIf;
		
		AdditionalProperties = DocumentObject.AdditionalProperties;
		RegisterRecords = DocumentObject.RegisterRecords;
		
		BeginTransaction();
		
		DriveServer.InitializeAdditionalPropertiesForPosting(Selection.Ref, AdditionalProperties);
		Documents.GoodsReceipt.InitializeDocumentData(Selection.Ref, AdditionalProperties);
		DriveServer.ReflectInventoryCostLayer(AdditionalProperties, DocumentObject.RegisterRecords, False);
		
		Try
			
			InfobaseUpdate.WriteRecordSet(RegisterRecords.InventoryCostLayer);
			AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Error while saving record set %1: %2.'; ru = 'Ошибка при записи набора записей %1: %2.';pl = 'Błąd podczas zapisywania zestawu wpisów %1: %2.';es_ES = 'Error al guardar el conjunto de registros %1: %2.';es_CO = 'Error al guardar el conjunto de registros %1: %2.';tr = '%1 kayıt kümesi kaydedilirken hata oluştu: %2.';it = 'Si è verificato un errore durante il salvataggio dell''insieme di registrazioni %1: %2.';de = 'Fehler beim Speichern von Satz von Einträgen %1: %2.'", DefaultLanguageCode),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.AccumulationRegisters.InventoryCostLayer,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf