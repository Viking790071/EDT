#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure checks the existence of retail price.
//
Procedure CheckExistenceOfRetailPrice(Cancel)
	
	If StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
	 OR StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
	 
		Query = New Query;
		Query.SetParameter("Date", Date);
		Query.SetParameter("DocumentTable", Inventory);
		Query.SetParameter("RetailPriceKind", StructuralUnit.RetailPriceKind);
		Query.SetParameter("ListProducts", Inventory.UnloadColumn("Products"));
		Query.SetParameter("ListCharacteristic", Inventory.UnloadColumn("Characteristic"));
		
		Query.Text =
		"SELECT
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.Products AS Products,
		|	DocumentTable.Characteristic AS Characteristic,
		|	DocumentTable.Batch AS Batch
		|INTO InventoryTransferInventory
		|FROM
		|	&DocumentTable AS DocumentTable
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	InventoryTransferInventory.LineNumber AS LineNumber,
		|	PRESENTATION(InventoryTransferInventory.Products) AS ProductsPresentation,
		|	PRESENTATION(InventoryTransferInventory.Characteristic) AS CharacteristicPresentation,
		|	PRESENTATION(InventoryTransferInventory.Batch) AS BatchPresentation
		|FROM
		|	InventoryTransferInventory AS InventoryTransferInventory
		|		LEFT JOIN InformationRegister.Prices.SliceLast(
		|				&Date,
		|				PriceKind = &RetailPriceKind
		|					AND Products IN (&ListProducts)
		|					AND Characteristic IN (&ListCharacteristic)) AS PricesSliceLast
		|		ON InventoryTransferInventory.Products = PricesSliceLast.Products
		|			AND InventoryTransferInventory.Characteristic = PricesSliceLast.Characteristic
		|WHERE
		|	ISNULL(PricesSliceLast.Price, 0) = 0";
		
		SelectionOfQueryResult = Query.Execute().Select();
		
		While SelectionOfQueryResult.Next() Do
			
			MessageText = StrTemplate(NStr("en = 'For products and services %1 in string %2 of the ""Inventory"" list the retail price is not set.'; ru = 'Для номенклатуры %1 в строке %2 списка ""Запасы"" не установлена розничная цена.';pl = 'Nie wybrano ceny detalicznej dla produktów i usług %1 w wierszu %2 listy ""Zapasy"".';es_ES = 'Para productos y servicios %1 en la línea %2 de la lista ""Inventario"" el precio de la venta al por menor no está establecido.';es_CO = 'Para productos y servicios %1 en la línea %2 de la lista ""Inventario"" el precio de la venta al por menor no está establecido.';tr = '""Stok"" listesindeki %2 dizgesindeki ürün ve hizmetler %1 için perakende fiyatı belirlenmemiş.';it = 'Per gli articoli %1 nella stringa %2 dell''elenco ""Scorte"" il prezzo al dettaglio non è impostato.';de = 'Für Produkte und Dienstleistungen %1 in Zeichenfolge %2 der Liste ""Bestand"" wird der Einzelhandelspreis nicht festgelegt.'"), 
			DriveServer.PresentationOfProducts(SelectionOfQueryResult.ProductsPresentation, 
														SelectionOfQueryResult.CharacteristicPresentation, 
														SelectionOfQueryResult.BatchPresentation),
			String(SelectionOfQueryResult.LineNumber));  
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Inventory",
				SelectionOfQueryResult.LineNumber,
				"Products",
				Cancel
			);
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region EventsHandlers

// IN the event handler of the FillingProcessor document
// - document filling by inventory reconciliation in the warehouse.
//
Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	Correspondence = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OtherIncome");
	
	If TypeOf(FillingData) = Type("DocumentRef.Stocktaking") AND ValueIsFilled(FillingData) Then
		
		BasisDocument = FillingData.Ref;
		Company = FillingData.Company;
		StructuralUnit = FillingData.StructuralUnit;
		Cell = FillingData.Cell;
		
		// FO Use Production subsystem.
		If Not Constants.UseProductionSubsystem.Get()
			AND StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Department Then
			Raise NStr("en = 'To allow generation of inventory increases from stocktakings, turn on Settings > Accounting settings > Production > Enable section use.'; ru = 'Нельзя создать оприходование запасов на основании инвентаризации запасов, т.к. недоступен вид деятельности ""Производство"".';pl = 'Aby umożliwić generowanie zwiększenia zapasów z inwentaryzacji, włącz Ustawienia > Ustawienia rachunkowości > Produkcja > Włącz użycie sekcji.';es_ES = 'Para permitir la generación de aumentos de inventario de los inventariados, activar Configuraciones > Configuraciones de la contabilidad > Producción > Activar el uso de sección.';es_CO = 'Para permitir la generación de aumentos de inventario de los inventariados, activar Configuraciones > Configuraciones de la contabilidad > Producción > Activar el uso de sección.';tr = 'Stok işlemlerinden stok artışlarının oluşturulmasına izin vermek için Ayarlar > Muhasebe ayarları > Üretim > Etkinleştir bölümünü kullanın.';it = 'Per consentire la generazione di aumento di scorte da inventario, attivare su Impostazioni > Impostazioni Contabili > Produzione > Attiva la sezione uso.';de = 'Um Bestandserhöhungen aus Inventuren zu generieren, aktivieren Sie Einstellungen > Buchhaltungseinstellungen > Produktion > Abschnitt Verwendung aktivieren.'");
		EndIf;
		
		Query = New Query(
		"SELECT ALLOWED
		|	MIN(Stocktaking.LineNumber) AS LineNumber,
		|	Stocktaking.Products AS Products,
		|	Stocktaking.Characteristic AS Characteristic,
		|	Stocktaking.Batch AS Batch,
		|	Stocktaking.MeasurementUnit AS MeasurementUnit,
		|	MAX(Stocktaking.Quantity - Stocktaking.QuantityAccounting) AS QuantityInventorytakingRejection,
		|	SUM(CASE
		|			WHEN InventoryIncrease.Quantity IS NULL
		|				THEN 0
		|			ELSE InventoryIncrease.Quantity
		|		END) AS QuantityDebited,
		|	Stocktaking.Price AS Price
		|FROM
		|	Document.Stocktaking.Inventory AS Stocktaking
		|		LEFT JOIN Document.InventoryIncrease.Inventory AS InventoryIncrease
		|		ON Stocktaking.Products = InventoryIncrease.Products
		|			AND Stocktaking.Characteristic = InventoryIncrease.Characteristic
		|			AND Stocktaking.Batch = InventoryIncrease.Batch
		|			AND Stocktaking.Ref = InventoryIncrease.Ref.BasisDocument
		|			AND (InventoryIncrease.Ref <> &DocumentRef)
		|			AND (InventoryIncrease.Ref.Posted)
		|		LEFT JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
		|		ON Stocktaking.Ownership = CatalogInventoryOwnership.Ref
		|WHERE
		|	Stocktaking.Ref = &BasisDocument
		|	AND Stocktaking.Quantity - Stocktaking.QuantityAccounting > 0
		|	AND CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.OwnInventory)
		|
		|GROUP BY
		|	Stocktaking.Products,
		|	Stocktaking.Characteristic,
		|	Stocktaking.Batch,
		|	Stocktaking.MeasurementUnit,
		|	Stocktaking.Price
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
				
				QuantityToReceive = Selection.QuantityInventorytakingRejection - Selection.QuantityDebited;
				If QuantityToReceive <= 0 Then
					Continue;
				EndIf;
				
				TabularSectionRow = Inventory.Add();
				TabularSectionRow.Products		= Selection.Products;
				TabularSectionRow.Characteristic		= Selection.Characteristic;
				TabularSectionRow.Batch				= Selection.Batch;
				TabularSectionRow.MeasurementUnit	= Selection.MeasurementUnit;
				TabularSectionRow.Quantity			= QuantityToReceive;
				TabularSectionRow.Price				= Selection.Price;
				TabularSectionRow.Amount				= TabularSectionRow.Quantity * TabularSectionRow.Price;
			
			EndDo;
			
		EndIf;
		
		If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
			GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
		EndIf;
		
		If Inventory.Count() = 0 Then
			
			Raise NStr("en = 'No data for capitalization registration.'; ru = 'Нет данных для оформления оприходования!';pl = 'Brak danych do rejestracji przychodu wewnętrznego.';es_ES = 'No hay datos para el registro de la capitalización.';es_CO = 'No hay datos para el registro de la capitalización.';tr = 'Sermayeleştirme kaydı için veri yok.';it = 'Non ci sono dati per la registrazione capitalizzazione.';de = 'Keine Daten für die Kapitalisierung der Registrierung.'");
			
		EndIf;
		
	EndIf;
	
	RegisterIncome = Not GetFunctionalOption("UseDefaultTypeOfAccounting")
		Or GLAccountsInDocuments.IsIncomeAndExpenseGLA(Correspondence);
	
	If RegisterIncome Then
		IncomeItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("OtherIncome");
	EndIf;

EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	CheckExistenceOfRetailPrice(Cancel);
	
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
	
	BatchesServer.CheckFilling(ThisObject, Cancel);
	
	If Not RegisterIncome Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "IncomeItem");
	EndIf;
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DocumentAmount = Inventory.Total("Amount");
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
	InventoryOwnershipServer.FillMainTableColumn(ThisObject, WriteMode, Cancel);
	
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
	Documents.InventoryIncrease.InitializeDocumentData(Ref, AdditionalProperties);
	
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
	
	// Offline registers
	DriveServer.ReflectInventoryCostLayer(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.InventoryIncrease.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	Documents.InventoryIncrease.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;
		
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