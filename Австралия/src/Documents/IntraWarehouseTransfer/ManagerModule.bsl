#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region InventoryOwnership

Function InventoryOwnershipParameters(DocObject) Export
	
	Parameters = New Structure;
	
	AmountFields = New Array;
	Parameters.Insert("AmountFields", AmountFields);

	HeaderFields = New Structure;
	HeaderFields.Insert("Company", "Company");
	HeaderFields.Insert("StructuralUnit", "StructuralUnit");
	If DocObject.OperationKind = Enums.OperationTypesIntraWarehouseTransfer.FromOneToSeveral Then
		HeaderFields.Insert("_HeaderCell", "Cell");
		Parameters.Insert("CellFieldName", "_HeaderCell");
	EndIf;
	Parameters.Insert("HeaderFields", HeaderFields);
	
	// for consistency check between Inventory and Inventory ownership fields
	NotUsedFields = New Array;
	NotUsedFields.Add("ConnectionKey");
	NotUsedFields.Add("SerialNumbers");
	Parameters.Insert("NotUsedFields", NotUsedFields);

	Return Parameters;
	
EndFunction

#EndRegion

#Region Batches

Function BatchCheckFillingParameters(DocObject) Export
	
	Parameters = New Structure;
	
	Warehouses = New Array;
	
	WarehouseData = New Structure;
	WarehouseData.Insert("Warehouse", DocObject.StructuralUnit);
	WarehouseData.Insert("TrackingArea", "Outbound_Transfer");
	
	Warehouses.Add(WarehouseData);
	
	Parameters.Insert("Warehouses", Warehouses);
	
	Return Parameters;
	
EndFunction

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export
	
EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefIntraWarehouseTransfer, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	InventoryByCellsTransfer.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	InventoryByCellsTransfer.Ref.Date AS Period,
	|	&Company AS Company,
	|	InventoryByCellsTransfer.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN InventoryByCellsTransfer.Ref.OperationKind = VALUE(Enum.OperationTypesIntraWarehouseTransfer.FromOneToSeveral)
	|			THEN InventoryByCellsTransfer.Ref.Cell
	|		ELSE InventoryByCellsTransfer.Cell
	|	END AS Cell,
	|	CASE
	|		WHEN InventoryByCellsTransfer.Ref.OperationKind = VALUE(Enum.OperationTypesIntraWarehouseTransfer.FromOneToSeveral)
	|			THEN InventoryByCellsTransfer.Cell
	|		ELSE InventoryByCellsTransfer.Ref.Cell
	|	END AS CellPayee,
	|	InventoryByCellsTransfer.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryByCellsTransfer.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryByCellsTransfer.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	InventoryByCellsTransfer.Quantity AS Quantity,
	|	InventoryByCellsTransfer.Ownership AS Ownership
	|FROM
	|	Document.IntraWarehouseTransfer.InventoryOwnership AS InventoryByCellsTransfer
	|WHERE
	|	InventoryByCellsTransfer.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Ref.Date AS EventDate,
	|	VALUE(Enum.SerialNumbersOperations.Record) AS Operation,
	|	TableSerialNumbers.SerialNumber AS SerialNumber,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic
	|FROM
	|	Document.IntraWarehouseTransfer.Inventory AS TableInventory
	|		INNER JOIN Document.IntraWarehouseTransfer.SerialNumbers AS TableSerialNumbers
	|		ON TableInventory.Ref = TableSerialNumbers.Ref
	|			AND TableInventory.ConnectionKey = TableSerialNumbers.ConnectionKey
	|WHERE
	|	TableSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.SerialNumber AS SerialNumber,
	|	&Company AS Company,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN TableInventory.Ref.OperationKind = VALUE(Enum.OperationTypesIntraWarehouseTransfer.FromOneToSeveral)
	|			THEN TableInventory.Ref.Cell
	|		ELSE TableInventory.Cell
	|	END AS Cell,
	|	1 AS Quantity,
	|	TableInventory.Ownership AS Ownership
	|FROM
	|	Document.IntraWarehouseTransfer.InventoryOwnership AS TableInventory
	|WHERE
	|	TableInventory.Ref = &Ref
	|	AND &UseSerialNumbers
	|	AND TableInventory.SerialNumber <> VALUE(Catalog.SerialNumbers.EmptyRef)
	|
	|UNION ALL
	|
	|SELECT
	|	TableInventory.Ref.Date,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableInventory.SerialNumber,
	|	&Company,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ref.StructuralUnit,
	|	CASE
	|		WHEN TableInventory.Ref.OperationKind = VALUE(Enum.OperationTypesIntraWarehouseTransfer.FromOneToSeveral)
	|			THEN TableInventory.Cell
	|		ELSE TableInventory.Ref.Cell
	|	END,
	|	1,
	|	TableInventory.Ownership
	|FROM
	|	Document.IntraWarehouseTransfer.InventoryOwnership AS TableInventory
	|WHERE
	|	TableInventory.Ref = &Ref
	|	AND &UseSerialNumbers
	|	AND TableInventory.SerialNumber <> VALUE(Catalog.SerialNumbers.EmptyRef)");
	
	Query.SetParameter("Ref", DocumentRefIntraWarehouseTransfer);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", ResultsArray[0].Unload());
	
	Selection = ResultsArray[0].Select();
	While Selection.Next() Do
			
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
		FillPropertyValues(NewRow, Selection);
		NewRow.RecordType = AccumulationRecordType.Receipt;
		NewRow.Cell = Selection.CellPayee;
		
	EndDo;
	
	// Serial numbers
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", ResultsArray[1].Unload());
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", ResultsArray[2].Unload());
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefIntraWarehouseTransfer, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If the "InventoryTransferAtWarehouseChange", "RegisterRecordsInventoryChange"
	// temporary tables contain records, it is necessary to control the sales of goods.
	
	If StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		Or StructureTemporaryTables.RegisterRecordsSerialNumbersChange Then

		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryInWarehousesChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Ownership) AS OwnershipPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Cell) AS PresentationCell,
		|	InventoryInWarehousesOfBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	REFPRESENTATION(InventoryInWarehousesOfBalance.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryInWarehousesChange.QuantityChange, 0) + ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS BalanceInventoryInWarehouses,
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS QuantityBalanceInventoryInWarehouses
		|FROM
		|	RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange
		|		LEFT JOIN AccumulationRegister.InventoryInWarehouses.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, Products, Characteristic, Batch, Ownership, Cell) In
		|					(SELECT
		|						RegisterRecordsInventoryInWarehousesChange.Company AS Company,
		|						RegisterRecordsInventoryInWarehousesChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryInWarehousesChange.Products AS Products,
		|						RegisterRecordsInventoryInWarehousesChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryInWarehousesChange.Batch AS Batch,
		|						RegisterRecordsInventoryInWarehousesChange.Ownership AS Ownership,
		|						RegisterRecordsInventoryInWarehousesChange.Cell AS Cell
		|					FROM
		|						RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange)) AS InventoryInWarehousesOfBalance
		|		ON RegisterRecordsInventoryInWarehousesChange.Company = InventoryInWarehousesOfBalance.Company
		|			AND RegisterRecordsInventoryInWarehousesChange.StructuralUnit = InventoryInWarehousesOfBalance.StructuralUnit
		|			AND RegisterRecordsInventoryInWarehousesChange.Products = InventoryInWarehousesOfBalance.Products
		|			AND RegisterRecordsInventoryInWarehousesChange.Characteristic = InventoryInWarehousesOfBalance.Characteristic
		|			AND RegisterRecordsInventoryInWarehousesChange.Batch = InventoryInWarehousesOfBalance.Batch
		|			AND RegisterRecordsInventoryInWarehousesChange.Ownership = InventoryInWarehousesOfBalance.Ownership
		|			AND RegisterRecordsInventoryInWarehousesChange.Cell = InventoryInWarehousesOfBalance.Cell
		|WHERE
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsSerialNumbersChange.LineNumber AS LineNumber,
		|	RegisterRecordsSerialNumbersChange.SerialNumber AS SerialNumberPresentation,
		|	RegisterRecordsSerialNumbersChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsSerialNumbersChange.Products AS ProductsPresentation,
		|	RegisterRecordsSerialNumbersChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsSerialNumbersChange.Batch AS BatchPresentation,
		|	RegisterRecordsSerialNumbersChange.Ownership AS OwnershipPresentation,
		|	RegisterRecordsSerialNumbersChange.Cell AS PresentationCell,
		|	SerialNumbersBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	SerialNumbersBalance.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsSerialNumbersChange.QuantityChange, 0) + ISNULL(SerialNumbersBalance.QuantityBalance, 0) AS BalanceSerialNumbers,
		|	ISNULL(SerialNumbersBalance.QuantityBalance, 0) AS BalanceQuantitySerialNumbers
		|FROM
		|	RegisterRecordsSerialNumbersChange AS RegisterRecordsSerialNumbersChange
		|		INNER JOIN AccumulationRegister.SerialNumbers.Balance(&ControlTime, ) AS SerialNumbersBalance
		|		ON RegisterRecordsSerialNumbersChange.StructuralUnit = SerialNumbersBalance.StructuralUnit
		|			AND RegisterRecordsSerialNumbersChange.Products = SerialNumbersBalance.Products
		|			AND RegisterRecordsSerialNumbersChange.Characteristic = SerialNumbersBalance.Characteristic
		|			AND RegisterRecordsSerialNumbersChange.Batch = SerialNumbersBalance.Batch
		|			AND RegisterRecordsSerialNumbersChange.Ownership = SerialNumbersBalance.Ownership
		|			AND RegisterRecordsSerialNumbersChange.SerialNumber = SerialNumbersBalance.SerialNumber
		|			AND RegisterRecordsSerialNumbersChange.Cell = SerialNumbersBalance.Cell
		|			AND (ISNULL(SerialNumbersBalance.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");

		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			Or Not ResultsArray[1].IsEmpty() Then
			DocumentObjectIntraWarehouseTransfer = DocumentRefIntraWarehouseTransfer.GetObject();
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrorsAsList(DocumentObjectIntraWarehouseTransfer, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of serial numbers in the warehouse.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingSerialNumbersRegisterErrors(DocumentObjectIntraWarehouseTransfer, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;

EndProcedure

#Region LibrariesHandlers

#Region PrintInterface

// Procedure of generating
// tabular document
Procedure GenerateInventoryTransferInCells(CurrentDocument, SpreadsheetDocument, TemplateName, PrintParams)
	
	FillStructureSection = New Structure;
	
	Query = New Query;
	Query.SetParameter("CurrentDocument", CurrentDocument);
	Query.Text =
	"SELECT
	|	IntraWarehouseTransfer.Number AS DocumentNumber,
	|	IntraWarehouseTransfer.Date AS DocumentDate,
	|	IntraWarehouseTransfer.OperationKind AS OperationKind,
	|	IntraWarehouseTransfer.Company AS Company,
	|	IntraWarehouseTransfer.Company.Prefix AS Prefix,
	|	IntraWarehouseTransfer.StructuralUnit AS StructuralUnit,
	|	IntraWarehouseTransfer.StructuralUnit.FRP AS FRP,
	|	IntraWarehouseTransfer.Cell AS Cell
	|FROM
	|	Document.IntraWarehouseTransfer AS IntraWarehouseTransfer
	|WHERE
	|	IntraWarehouseTransfer.Ref = &CurrentDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryByCellsTransfer.LineNumber,
	|	InventoryByCellsTransfer.Cell,
	|	InventoryByCellsTransfer.Products.Code AS ProductsCode,
	|	InventoryByCellsTransfer.Products.SKU AS ProductsSKU,
	|	InventoryByCellsTransfer.Products,
	|	InventoryByCellsTransfer.Characteristic,
	|	PRESENTATION(InventoryByCellsTransfer.Batch) AS Batch,
	|	InventoryByCellsTransfer.Quantity,
	|	InventoryByCellsTransfer.MeasurementUnit,
	|	InventoryByCellsTransfer.ConnectionKey
	|FROM
	|	Document.IntraWarehouseTransfer.Inventory AS InventoryByCellsTransfer
	|WHERE
	|	InventoryByCellsTransfer.Ref = &CurrentDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryByCellsTransfer.Ref,
	|	MAX(InventoryByCellsTransfer.LineNumber) AS PositionsQuantity,
	|	SUM(InventoryByCellsTransfer.Quantity) AS TotalQuantity
	|FROM
	|	Document.IntraWarehouseTransfer.Inventory AS InventoryByCellsTransfer
	|WHERE
	|	InventoryByCellsTransfer.Ref = &CurrentDocument
	|
	|GROUP BY
	|	InventoryByCellsTransfer.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	IntraWarehouseTransferSerialNumbers.SerialNumber,
	|	IntraWarehouseTransferSerialNumbers.ConnectionKey
	|FROM
	|	Document.IntraWarehouseTransfer.SerialNumbers AS IntraWarehouseTransferSerialNumbers
	|WHERE
	|	IntraWarehouseTransferSerialNumbers.Ref = &CurrentDocument";
	
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
	
	ExecutionResult = Query.ExecuteBatch();
	
	DocumentHeader = ExecutionResult[0].Select();
	DocumentHeader.Next();
	
	TabularSection = ExecutionResult[1].Select();
	
	TotalsSelection = ExecutionResult[2].Select();
	TotalsSelection.Next();
	
	SelectionSerialNumbers = ExecutionResult[3].Select();
	
	SpreadsheetDocument.PrintParametersName = "PARAMETERS_PRINT_" + TemplateName + "_" + TemplateName;
	Template = PrintManagement.PrintFormTemplate("Document.IntraWarehouseTransfer." + TemplateName);
	
	// Title
	TemplateArea = Template.GetArea("Title");
	If DocumentHeader.DocumentDate < Date('20110101') Then
		
		DocumentNumber = DriveServer.GetNumberForPrinting(DocumentHeader.DocumentNumber, DocumentHeader.Prefix);
		
	Else
		
		DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(DocumentHeader.DocumentNumber, True, True);
		
	EndIf;
	
	HeaderText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Intra-warehouse transfer between storage bins #%1, %2'; ru = 'Перемещение внутри склада между складскими ячейками №%1, %2';pl = 'Przesunięcie wewnątrzmagazynowe między komórkami magazynowymi nr %1, %2';es_ES = 'Traslado dentro del almacén entre depósitos de almacenamiento#%1,%2';es_CO = 'Traslado dentro del almacén entre depósitos de almacenamiento#%1,%2';tr = '#%1, %2 depoları arasında ambar içi transfer';it = 'Trasferimento intra-magazzino tra contenitori di magazzino #%1, %2';de = 'Lagerinterner Transfer zwischen Lagerplätzen #%1, %2'"), 
		DocumentHeader.DocumentNumber,
		Format(DocumentHeader.DocumentDate, "DLF=D"));
	FillStructureSection.Insert("HeaderText", HeaderText);
	FillStructureSection.Insert("StructuralUnit", DocumentHeader.StructuralUnit);
	
	TemplateArea.Parameters.Fill(FillStructureSection);
	SpreadsheetDocument.Put(TemplateArea);
	
	// Table header
	TemplateArea = Template.GetArea("TableHeader");
	FillStructureSection.Clear();
	
	FillStructureSection.Insert("TransferKind", NStr("en = 'Transfer kind'; ru = 'Вид перечисления';pl = 'Rodzaj przesunięcia';es_ES = 'Tipo de traslado';es_CO = 'Tipo de traslado';tr = 'Transfer türü';it = 'Tipologia di trasferimento';de = 'Transferart'") + ": " + String(DocumentHeader.OperationKind));
	
	TemplateArea.Parameters.Fill(FillStructureSection);
	SpreadsheetDocument.Put(TemplateArea);
	
	// Table strings
	TemplateArea = Template.GetArea("TableRow");
	IsMoveFromOneToSeveral = (DocumentHeader.OperationKind = Enums.OperationTypesIntraWarehouseTransfer.FromOneToSeveral);
	While TabularSection.Next() Do
		
		FillStructureSection.Clear();
		FillStructureSection.Insert("LineNumber", TabularSection.LineNumber);
		
		CellSender = ?(IsMoveFromOneToSeveral,	DocumentHeader.Cell, TabularSection.Cell);
		CellReceive = ?(IsMoveFromOneToSeveral, 	TabularSection.Cell, DocumentHeader.Cell);
		
		FillStructureSection.Insert("CellSender", CellSender);
		FillStructureSection.Insert("CellReceive", CellReceive);
		
		StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(SelectionSerialNumbers, TabularSection.ConnectionKey);
		PresentationOfProducts = DriveServer.GetProductsPresentationForPrinting(
			TabularSection.Products,
			TabularSection.Characteristic,
			TabularSection.ProductsSKU,
			StringSerialNumbers);
		
		FillStructureSection.Insert("PresentationOfProducts", PresentationOfProducts);
		FillStructureSection.Insert("BatchPresentation", TabularSection.Batch);
		FillStructureSection.Insert("Quantity", TabularSection.Quantity);
		FillStructureSection.Insert("MeasurementUnit", TabularSection.MeasurementUnit);
		
		TemplateArea.Parameters.Fill(FillStructureSection);
		SpreadsheetDocument.Put(TemplateArea);
		
	EndDo;
	
	// Table footer
	TemplateArea = Template.GetArea("TableFooter");
	FillStructureSection.Clear();
	
	FillStructureSection.Insert("TotalQuantity", TotalsSelection.TotalQuantity);
	
	If TotalsSelection.TotalQuantity = 0 Then
		
		StockTransferredToThirdPartiesCountInWords = NStr("en = 'Inventory to move is not specified in the document.'; ru = 'В документе не указаны перемещаемые запасы.';pl = 'W dokumencie nie określono przemieszczanych zapasów.';es_ES = 'Inventario para mover no está especificado en el documento.';es_CO = 'Inventario para mover no está especificado en el documento.';tr = 'Taşınacak stok, belgede belirtilmemiş.';it = 'Il documento non specifica le scorte da spostare.';de = 'Der zu bewegende Bestand ist im Beleg nicht angegeben.'");
		
	ElsIf IsMoveFromOneToSeveral Then
		
		StockTransferredToThirdPartiesCountInWords = NStr("en = 'Positions withdrawn from cell ""%1"": %2.
		                                                  |General quantity: %3'; 
		                                                  |ru = 'Из ячейки ""%1"" изъято позиций: %2.
		                                                  |Общим количеством: %3.';
		                                                  |pl = 'Pozycje przeniesione z komórki ""%1"": %2.
		                                                  |Łączna ilość: %3';
		                                                  |es_ES = 'Posiciones retiradas de la celda ""%1"": %2.
		                                                  |Cantidad general: %3';
		                                                  |es_CO = 'Posiciones retiradas de la celda ""%1"": %2.
		                                                  |Cantidad general: %3';
		                                                  |tr = '""%1"" Hücreden çekilen pozisyonlar :%2.
		                                                  | Genel miktar:%3';
		                                                  |it = 'Posizioni ritirate dal contenitore ""%1"": %2.
		                                                  |Quantità generale: %3';
		                                                  |de = 'Positionen aus Zelle ""%1"" zurückgezogen: %2.
		                                                  |Allgemeine Menge: %3'");
		
	Else
		
		StockTransferredToThirdPartiesCountInWords = NStr("en = 'Positions delivered to cell ""%1"": %2.
		                                                  |General quantity: %3'; 
		                                                  |ru = 'В ячейку ""%1"" поступило позиций: %2.
		                                                  |Общим количеством: %3.';
		                                                  |pl = 'Pozycje dostarczone do komórki ""%1"": %2.
		                                                  |Łączna ilość: %3';
		                                                  |es_ES = 'Posiciones aportadas para la celda ""%1"": %2.
		                                                  |Cantidad general: %3';
		                                                  |es_CO = 'Posiciones aportadas para la celda ""%1"": %2.
		                                                  |Cantidad general: %3';
		                                                  |tr = '""%1"" Hücresine teslim edilen pozisyonlar: %2. 
		                                                  |Genel miktar:%3';
		                                                  |it = 'Posizioni consegnate al contenitore ""%1"": %2.
		                                                  |Quantità generale: %3';
		                                                  |de = 'Positionen, die an Zelle ""%1"" geliefert werden: %2.
		                                                  |Allgemeine Menge: %3'");
		
	EndIf;
	
	StockTransferredToThirdPartiesCountInWords = 
		StringFunctionsClientServer.SubstituteParametersToString(StockTransferredToThirdPartiesCountInWords
			,DocumentHeader.Cell
			,?(TotalsSelection.PositionsQuantity = Undefined, 0, TotalsSelection.PositionsQuantity)
			,NumberInWords(?(TotalsSelection.TotalQuantity = Undefined, 0, TotalsSelection.TotalQuantity), "L = en_US; FN = False", "unit, units,,, 0")
		);
	
	FillStructureSection.Insert("StockTransferredToThirdPartiesCountInWords", StockTransferredToThirdPartiesCountInWords);
	
	TemplateArea.Parameters.Fill(FillStructureSection);
	SpreadsheetDocument.Put(TemplateArea);
	
	// Signatures
	TemplateArea = Template.GetArea("Signatures");
	FillStructureSection.Clear();
	
	MRPPresentation = InformationRegisters.ChangeHistoryOfIndividualNames.IndividualDescriptionFull(DocumentHeader.DocumentDate, DocumentHeader.FRP);
	
	FillStructureSection.Insert("ResponsiblePresentation", MRPPresentation);
	FillStructureSection.Insert("ReceivedPresentation", MRPPresentation);
	
	TemplateArea.Parameters.Fill(FillStructureSection);
	SpreadsheetDocument.Put(TemplateArea);
	
EndProcedure

// Document printing procedure
//
Function DocumentPrinting(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	FirstDocument = True;
	FirstLineNumber = 0;
	
	For Each CurrentDocument In ObjectsArray Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		If TemplateName = "PF_MXL_IntraWarehouseTransfer" Then
			
			GenerateInventoryTransferInCells(CurrentDocument, SpreadsheetDocument, TemplateName, PrintParams);
			
		EndIf;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	Return SpreadsheetDocument;

EndFunction

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	FillInParametersOfElectronicMail = True;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "IntraWarehouseTransfer") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"IntraWarehouseTransfer",
			NStr("en = 'Intra-warehouse transfer between locations'; ru = 'Перемещение по ячейкам между площадками';pl = 'Przesunięcie wewnątrzmagazynowe między lokacjami';es_ES = 'Traslado dentro del almacén entre localidades';es_CO = 'Transferencia entre almacenes entre localidades';tr = 'Lokasyonlar arası ambar içi transfer';it = 'Trasferimento intra-magazzino tra ubicazioni';de = 'Lager interner Transfer zwischen Örtern'"),
			DocumentPrinting(ObjectsArray, PrintObjects, "PF_MXL_IntraWarehouseTransfer", PrintParameters.Result));
		
	EndIf;
	
	// parameters of sending printing forms by email
	If FillInParametersOfElectronicMail Then
		
		DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
		
	EndIf;
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "IntraWarehouseTransfer";
	PrintCommand.Presentation = NStr("en = 'Intra-warehouse transfer'; ru = 'Перемещение по ячейкам';pl = 'Przesunięcie wewnątrzmagazynowe';es_ES = 'Traslado dentro del almacén';es_CO = 'Transferencia entre almacenes';tr = 'Ambar içi transfer';it = 'Trasferimento interno di magazzino';de = 'Lager interner Transfer'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf