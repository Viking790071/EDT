#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure InitializeDocumentData(DocumentRef, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	ActualSalesVolume.Ref AS Ref,
	|	ActualSalesVolume.Date AS Date,
	|	ActualSalesVolume.Company AS Company,
	|	ActualSalesVolume.Department AS Department,
	|	ActualSalesVolume.Counterparty AS Counterparty,
	|	ActualSalesVolume.Contract AS Contract,
	|	ActualSalesVolume.CounterpartyAndContractPosition AS CounterpartyAndContractPosition,
	|	ActualSalesVolume.DeliveryStartDate AS DeliveryStartDate,
	|	ActualSalesVolume.DeliveryEndDate AS DeliveryEndDate
	|INTO DocumentHeader
	|FROM
	|	Document.ActualSalesVolume AS ActualSalesVolume
	|WHERE
	|	ActualSalesVolume.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Date AS Period,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.Department AS Department,
	|	DocumentHeader.DeliveryStartDate AS DeliveryStartDate,
	|	DocumentHeader.DeliveryEndDate AS DeliveryEndDate,
	|	CASE
	|		WHEN DocumentHeader.CounterpartyAndContractPosition = VALUE(Enum.AttributeStationing.InHeader)
	|			THEN DocumentHeader.Counterparty
	|		ELSE ActualSalesVolumeInventory.Counterparty
	|	END AS Counterparty,
	|	CASE
	|		WHEN DocumentHeader.CounterpartyAndContractPosition = VALUE(Enum.AttributeStationing.InHeader)
	|			THEN DocumentHeader.Contract
	|		ELSE ActualSalesVolumeInventory.Contract
	|	END AS Contract,
	|	ActualSalesVolumeInventory.Products AS Products,
	|	ActualSalesVolumeInventory.Characteristic AS Characteristic,
	|	ActualSalesVolumeInventory.Batch AS Batch,
	|	ActualSalesVolumeInventory.Quantity * ISNULL(CatalogUOM.Factor, 1) AS Quantity
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		INNER JOIN Document.ActualSalesVolume.Inventory AS ActualSalesVolumeInventory
	|		ON DocumentHeader.Ref = ActualSalesVolumeInventory.Ref
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (ActualSalesVolumeInventory.MeasurementUnit = CatalogUOM.Ref)";
	
	Query.SetParameter("Ref",                DocumentRef);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",         StructureAdditionalProperties.AccountingPolicy.UseBatches);
	
	Result = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableActualSalesVolume", Result.Unload());
	
EndProcedure

#Region LibrariesHandlers

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

#EndRegion

#EndIf