#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Procedure creates an empty temporary table of records change.
//
Procedure CreateEmptyTemporaryTableChange(AdditionalProperties) Export
	
	If Not AdditionalProperties.Property("ForPosting")
	 OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	Query = New Query(
	"SELECT TOP 0
	|	InventoryDemand.LineNumber AS LineNumber,
	|	InventoryDemand.Company AS Company,
	|	InventoryDemand.MovementType AS MovementType,
	|	InventoryDemand.SalesOrder AS SalesOrder,
	|	InventoryDemand.Products AS Products,
	|	InventoryDemand.Characteristic AS Characteristic,
	|	InventoryDemand.Quantity AS QuantityBeforeWrite,
	|	InventoryDemand.Quantity AS QuantityChange,
	|	InventoryDemand.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsInventoryDemandChange
	|FROM
	|	AccumulationRegister.InventoryDemand AS InventoryDemand");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsInventoryDemandChange", False);
	
EndProcedure

#EndRegion

// begin Drive.FullVersion

Function UpdateProductionDocumentData() Export
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	InventoryDemand.Recorder AS Ref
	|FROM
	|	AccumulationRegister.InventoryDemand AS InventoryDemand
	|WHERE
	|	InventoryDemand.ProductionDocument REFS Document.ProductionOrder 
	|	AND (InventoryDemand.SalesOrder REFS Document.SalesOrder
	|	AND Not InventoryDemand.SalesOrder = VALUE(Document.SalesOrder.EmptyRef))";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		DocObject = Selection.Ref.GetObject();
		DocObjectMetaData = DocObject.Metadata();
		
		BeginTransaction();
		
		DriveServer.InitializeAdditionalPropertiesForPosting(DocObject.Ref, DocObject.AdditionalProperties);
		
		// Accounting templates properties initialization.
		AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(DocObject.Ref, DocObject.AdditionalProperties, False);
		If DocObject.AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
			
			MessageText = NStr("en = 'Cannot post document ""%1"". 
				|The applicable Accounting transaction template is required.
				|Details: %2'; 
				|ru = '???? ?????????????? ???????????????? ???????????????? ""%1"". 
				|?????????????????? ?????????????????????????????? ???????????? ?????????????????????????? ????????????????.
				|??????????????????: %2';
				|pl = 'Nie mo??na zatwierdzi?? dokumentu ""%1"". 
				|Wymagany jest odpowiedni szablon transakcji ksi??gowej.
				|Szczeg????y: %2';
				|es_ES = 'No se ha podido contabilizar el documento ""%1"". 
				|Se requiere la plantilla de transacci??n contable aplicable. 
				|Detalles: ';
				|es_CO = 'No se ha podido contabilizar el documento ""%1"". 
				|Se requiere la plantilla de transacci??n contable aplicable. 
				|Detalles: ';
				|tr = '""%1"" belgesi kaydedilemiyor.
				|Uygulanabilir Muhasebe i??lemi ??ablonu gerekli.
				|Ayr??nt??lar: %2';
				|it = 'Impossibile pubblicare il documento ""%1"". 
				|?? richiesto il modello di transazione contabile applicabile.
				|Dettagli: %2';
				|de = 'Fehler beim Buchen des Dokuments ""%1"". 
				|Die verwendbare Buchhaltungstransaktionsvorlage is erforderlich.
				|Details: %2'", CommonClientServer.DefaultLanguageCode());
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				MessageText,
				DocObject.Ref,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				DocObjectMetaData,
				,
				ErrorDescription);
				
			Continue;
			
		EndIf;
		
		Documents[DocObjectMetaData.Name].InitializeDocumentData(DocObject.Ref, DocObject.AdditionalProperties);
		DriveServer.ReflectInventoryDemand(DocObject.AdditionalProperties, DocObject.RegisterRecords, False);
		
		Try

			InfobaseUpdate.WriteRecordSet(DocObject.RegisterRecords.InventoryDemand);
			
			DocObject.AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			MessageText = NStr("en = 'Cannot save document ""%1"". Details: %2'; ru = '???? ?????????????? ???????????????? ???????????????? ""%1"". ??????????????????: %2';pl = 'Nie mo??na zapisa?? dokumentu ""%1"". Szczeg????y: %2';es_ES = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi saklanam??yor. Ayr??nt??lar: %2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'", CommonClientServer.DefaultLanguageCode());
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				MessageText,
				DocObject.Ref,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(NStr("en = 'Infobase update'; ru = '???????????????????? ???????????????????????????? ????????';pl = 'Aktualizacja bazy informacyjnej';es_ES = 'Actualizaci??n de la infobase';es_CO = 'Actualizaci??n de la infobase';tr = 'Infobase g??ncellemesi';it = 'Aggiornamento del database';de = 'Infobase-Aktualisierung'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				DocObjectMetaData,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;

EndFunction

// end Drive.FullVersion

#EndIf