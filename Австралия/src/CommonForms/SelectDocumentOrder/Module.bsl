
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.Company.Visible = Not Parameters.Filter.Property("Company");
	
	// begin Drive.FullVersion
	If Parameters.Filter.Property("IncludeProductionDocuments") And Parameters.Filter.IncludeProductionDocuments Then
		
		List.QueryText = List.QueryText + ProductionDocumentsQueryText();
		
	EndIf;
	// end Drive.FullVersion
	
	If Parameters.Filter.Property("Counterparty") Then
		List.Parameters.SetParameterValue("CounterpartyByDefault", Parameters.Filter.Counterparty);
	Else
		List.Parameters.SetParameterValue("CounterpartyByDefault", Catalogs.Counterparties.EmptyRef());
	EndIf;
	
	If Parameters.Filter.Property("Contract") Then
		List.Parameters.SetParameterValue("ContractByDefault", Parameters.Filter.Contract);
	Else
		List.Parameters.SetParameterValue("ContractByDefault", Catalogs.CounterpartyContracts.EmptyRef());
	EndIf;
	
	If Parameters.Filter.Property("Currency") Then
		List.Parameters.SetParameterValue("Currency", Parameters.Filter.Currency);
	ElsIf Parameters.Filter.Property("DocumentCurrency") Then
		List.Parameters.SetParameterValue("Currency", Parameters.Filter.DocumentCurrency);
	Else
		List.Parameters.SetParameterValue("Currency", Catalogs.Currencies.EmptyRef());
	EndIf;
	
	If Parameters.Filter.Property("IncludeTransferOrders") Then
		List.Parameters.SetParameterValue("IncludeTransferOrders", Parameters.Filter.IncludeTransferOrders);
	Else
		List.Parameters.SetParameterValue("IncludeTransferOrders", True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

// The procedure is called when clicking button "Select".
//
&AtClient
Procedure ChooseDocument(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		
		DocumentData = New Structure;
		DocumentData.Insert("Document", CurrentData.Ref);
		DocumentData.Insert("Contract", CurrentData.Contract);
		
		NotifyChoice(DocumentData);
	Else
		Close();
	EndIf;
	
EndProcedure

// The procedure is called when clicking button "Open document".
//
&AtClient
Procedure OpenDocument(Command)
	
	TableRow = Items.List.CurrentData;
	If TableRow <> Undefined Then
		ShowValue(Undefined,TableRow.Ref);
	EndIf;
	
EndProcedure

#EndRegion

#Region ListFormTableItemsEventHandlers

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentData = Items.List.CurrentData;
	
	DocumentData = New Structure;
	DocumentData.Insert("Document", CurrentData.Ref);
	DocumentData.Insert("Contract", CurrentData.Contract);
	
	NotifyChoice(DocumentData);
	
EndProcedure

#EndRegion

#Region Private

// begin Drive.FullVersion
Function ProductionDocumentsQueryText()
	
	ProductionDocumentsQueryText = DriveClientServer.GetQueryUnion() +
	"SELECT
	|	ProductionOrder.Ref AS Ref,
	|	ProductionOrder.Date AS Date,
	|	ProductionOrder.Number AS Number,
	|	ProductionOrder.Company AS Company,
	|	VALUE(Catalog.Counterparties.EmptyRef) AS Field1,
	|	VALUE(Catalog.CounterpartyContracts.EmptyRef) AS Field2,
	|	0 AS Field3,
	|	VALUE(Catalog.Currencies.EmptyRef) AS Field4,
	|	TYPE(Document.ProductionOrder) AS Field5,
	|	ProductionOrder.OrderState AS OrderState
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|WHERE
	|	(ProductionOrder.OperationKind = VALUE(Enum.OperationTypesProductionOrder.Assembly)
	|			OR ProductionOrder.OperationKind = VALUE(Enum.OperationTypesProductionOrder.Disassembly))
	|
	|UNION ALL
	|
	|SELECT
	|	ManufacturingOperation.Ref,
	|	ManufacturingOperation.Date,
	|	ManufacturingOperation.Number,
	|	ManufacturingOperation.Company,
	|	VALUE(Catalog.Counterparties.EmptyRef),
	|	VALUE(Catalog.CounterpartyContracts.EmptyRef),
	|	0,
	|	VALUE(Catalog.Currencies.EmptyRef),
	|	TYPE(Document.ManufacturingOperation),
	|	ManufacturingOperation.Status
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|		INNER JOIN Document.ProductionOrder AS ProductionOrder
	|		ON ManufacturingOperation.BasisDocument = ProductionOrder.Ref
	|			AND (VALUETYPE(ProductionOrder.BasisDocument) <> TYPE(Document.SubcontractorOrderReceived))";
	
	Return ProductionDocumentsQueryText;
	
EndFunction
// end Drive.FullVersion

#EndRegion
