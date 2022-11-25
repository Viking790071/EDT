#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

Procedure CreateEmptyTemporaryTableChange(AdditionalProperties) Export
	
	If Not AdditionalProperties.Property("ForPosting")
		Or Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	Query = New Query(
	"SELECT TOP 0
	|	ProductionComponents.LineNumber AS LineNumber,
	|	ProductionComponents.Products AS Products,
	|	ProductionComponents.Characteristic AS Characteristic,
	|	ProductionComponents.ProductionDocument AS ProductionDocument,
	|	ProductionComponents.Quantity AS QuantityBeforeWrite,
	|	ProductionComponents.Quantity AS QuantityChange,
	|	ProductionComponents.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsProductionComponentsChange
	|FROM
	|	AccumulationRegister.ProductionComponents AS ProductionComponents");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsProductionComponentsChange", False);
	
EndProcedure

Function BalancesControlQueryText() Export
	
	Return
	"SELECT ALLOWED
	|	RegisterRecordsProductionComponentsChange.LineNumber AS LineNumber,
	|	RegisterRecordsProductionComponentsChange.ProductionDocument AS ProductionDocument,
	|	RegisterRecordsProductionComponentsChange.Products AS Products,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	RegisterRecordsProductionComponentsChange.Characteristic AS Characteristic,
	|	RegisterRecordsProductionComponentsChange.QuantityChange + ISNULL(ProductionComponentsBalances.QuantityBalance, 0) AS QuantityBalanceBeforeChange,
	|	ISNULL(ProductionComponentsBalances.QuantityBalance, 0) AS QuantityBalance
	|FROM
	|	RegisterRecordsProductionComponentsChange AS RegisterRecordsProductionComponentsChange
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON RegisterRecordsProductionComponentsChange.Products = CatalogProducts.Ref
	|		LEFT JOIN AccumulationRegister.ProductionComponents.Balance(&ControlTime, ) AS ProductionComponentsBalances
	|		ON RegisterRecordsProductionComponentsChange.ProductionDocument = ProductionComponentsBalances.ProductionDocument
	|			AND RegisterRecordsProductionComponentsChange.Products = ProductionComponentsBalances.Products
	|			AND RegisterRecordsProductionComponentsChange.Characteristic = ProductionComponentsBalances.Characteristic
	|WHERE
	|	ISNULL(ProductionComponentsBalances.QuantityBalance, 0) < 0
	|
	|ORDER BY
	|	LineNumber";
	
EndFunction

#Region InfobaseUpdate

Procedure FillRecords() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ProductionOrder.Ref AS Ref
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|		LEFT JOIN AccumulationRegister.ProductionComponents AS ProductionComponents
	|		ON ProductionOrder.Ref = ProductionComponents.Recorder
	|WHERE
	|	(ProductionOrder.OperationKind = VALUE(Enum.OperationTypesProductionOrder.Assembly)
	|			OR ProductionOrder.OperationKind = VALUE(Enum.OperationTypesProductionOrder.Disassembly))
	|	AND ProductionOrder.Posted
	|	AND ProductionComponents.Recorder IS NULL
	|
	|UNION ALL
	|
	|SELECT
	|	ManufacturingOperation.Ref
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|		LEFT JOIN AccumulationRegister.ProductionComponents AS ProductionComponents
	|		ON ManufacturingOperation.Ref = ProductionComponents.Recorder
	|WHERE
	|	ManufacturingOperation.Posted
	|	AND ProductionComponents.Recorder IS NULL
	|	AND (ManufacturingOperation.Status = VALUE(Enum.ManufacturingOperationStatuses.InProcess)
	|			OR ManufacturingOperation.Status = VALUE(Enum.ManufacturingOperationStatuses.Completed))
	|	AND ManufacturingOperation.ProductionMethod = VALUE(Enum.ProductionMethods.InHouseProduction)
	|
	|UNION ALL
	|
	|SELECT
	|	Manufacturing.Ref
	|FROM
	|	Document.Manufacturing AS Manufacturing
	|		LEFT JOIN AccumulationRegister.ProductionComponents AS ProductionComponents
	|		ON Manufacturing.Ref = ProductionComponents.Recorder
	|WHERE
	|	Manufacturing.Posted
	|	AND ProductionComponents.Recorder IS NULL";
	
	QueryResult = Query.Execute();
	
	SelectionDocument = QueryResult.Select();
	
	While SelectionDocument.Next() Do
		
		DocumentRef = SelectionDocument.Ref;
		
		BeginTransaction();
		
		Try
			
			DocumentObject = DocumentRef.GetObject();
			
			DocumentMetadata = DocumentObject.Metadata();
			
			DriveServer.InitializeAdditionalPropertiesForPosting(DocumentRef, DocumentObject.AdditionalProperties);
			Documents[DocumentMetadata.Name].InitializeDocumentData(DocumentRef, DocumentObject.AdditionalProperties);
			
			DriveServer.ReflectProductionComponents(DocumentObject.AdditionalProperties, DocumentObject.RegisterRecords, False);
			InfobaseUpdate.WriteRecordSet(DocumentObject.RegisterRecords.ProductionComponents);
			
			DocumentObject.AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
			
			InfobaseUpdate.WriteObject(DocumentObject);
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t save %1: %2'; ru = 'Не удалось записать %1: %2';pl = 'Nie udało się zapisać %1: %2';es_ES = 'No se ha podido guardar %1:%2';es_CO = 'No se ha podido guardar %1:%2';tr = '%1 saklanamadı: %2';it = 'Impossibile salvare %1: %2';de = 'Fehler beim Speichern von %1: %2'", CommonClientServer.DefaultLanguageCode()),
				DocumentRef,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				NStr("en = 'Infobase update'; ru = 'Обновление информационной базы';pl = 'Aktualizacja bazy informacyjnej';es_ES = 'Actualización de la infobase';es_CO = 'Actualización de la infobase';tr = 'Infobase güncellemesi';it = 'Aggiornamento del database';de = 'Infobase-Aktualisierung'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				DocumentMetadata,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf