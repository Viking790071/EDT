#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	Correspondence = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("Expenses");
	
	If TypeOf(FillingData) = Type("DocumentRef.Stocktaking") AND ValueIsFilled(FillingData) Then
		
		BasisDocument = FillingData.Ref;
		Company = FillingData.Company;
		StructuralUnit = FillingData.StructuralUnit;
		Cell = FillingData.Cell;
		
		Query = New Query(
		"SELECT ALLOWED
		|	MIN(Stocktaking.LineNumber) AS LineNumber,
		|	Stocktaking.Products AS Products,
		|	Stocktaking.Characteristic AS Characteristic,
		|	Stocktaking.Batch AS Batch,
		|	Stocktaking.MeasurementUnit AS MeasurementUnit,
		|	MAX(Stocktaking.QuantityAccounting - Stocktaking.Quantity) AS QuantityRejection,
		|	SUM(CASE
		|			WHEN InventoryWriteOff.Quantity IS NULL 
		|				THEN 0
		|			ELSE InventoryWriteOff.Quantity
		|		END) AS WrittenOffQuantity
		|FROM
		|	Document.Stocktaking.Inventory AS Stocktaking
		|		LEFT JOIN Document.InventoryWriteOff.Inventory AS InventoryWriteOff
		|		ON Stocktaking.Products = InventoryWriteOff.Products
		|			AND Stocktaking.Characteristic = InventoryWriteOff.Characteristic
		|			AND Stocktaking.Batch = InventoryWriteOff.Batch
		|			AND Stocktaking.Ref = InventoryWriteOff.Ref.BasisDocument
		|			AND (InventoryWriteOff.Ref <> &DocumentRef)
		|			AND (InventoryWriteOff.Ref.Posted)
		|		LEFT JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
		|		ON Stocktaking.Ownership = CatalogInventoryOwnership.Ref
		|WHERE
		|	Stocktaking.Ref = &BasisDocument
		|	AND Stocktaking.QuantityAccounting - Stocktaking.Quantity > 0
		|	AND CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.OwnInventory)
		|
		|GROUP BY
		|	Stocktaking.Products,
		|	Stocktaking.Characteristic,
		|	Stocktaking.Batch,
		|	Stocktaking.MeasurementUnit
		|
		|ORDER BY
		|	LineNumber");
		
		Query.SetParameter("BasisDocument", FillingData);
		Query.SetParameter("DocumentRef", Ref);
		
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			
			Selection = QueryResult.Select();
			
			// Filling document tabular section.
			Inventory.Clear();
			
			While Selection.Next() Do
				
				CountWriteOff = Selection.QuantityRejection - Selection.WrittenOffQuantity;
				
				If CountWriteOff <= 0 Then
					Continue;
				EndIf;
				
				TabularSectionRow = Inventory.Add();
				TabularSectionRow.Products			= Selection.Products;
				TabularSectionRow.Characteristic	= Selection.Characteristic;
				TabularSectionRow.Batch				= Selection.Batch;
				TabularSectionRow.MeasurementUnit	= Selection.MeasurementUnit;
				TabularSectionRow.Quantity			= CountWriteOff;
				
			EndDo;
			
		EndIf;
		
		If Inventory.Count() = 0 Then
			
			CommonClientServer.MessageToUser(NStr("en = 'No data to register write-off.'; ru = 'Нет данных для оформления списания!';pl = 'Brak danych do stworzenia rozchodu wewnętrznego.';es_ES = 'No hay datos para registrar la amortización.';es_CO = 'No hay datos para registrar la amortización.';tr = 'Stoktan düşmenin kaydı için veri yok.';it = 'Non ci sono dati al registro della cancellazione (write-off).';de = 'Keine Daten, um die Abschreibung zu registrieren.'"));
			
			StandardProcessing = False;
			
		EndIf;
		
	EndIf;
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
	EndIf;
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Serial numbers
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
	
	BatchesServer.CheckFilling(ThisObject, Cancel);
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	// Initialization of document data
	Documents.InventoryWriteOff.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	
	// SerialNumbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);

	// Control
	Documents.InventoryWriteOff.RunControl(Ref, AdditionalProperties, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);

	// Control
	Documents.InventoryWriteOff.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;
		
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
	InventoryOwnershipServer.FillMainTableColumn(ThisObject, WriteMode, Cancel);
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	If SerialNumbers.Count() Then
		
		For Each InventoryLine In Inventory Do
			InventoryLine.SerialNumbers = "";
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
			Ref, AdditionalProperties.WriteMode, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
		
EndProcedure

#EndRegion

#EndIf